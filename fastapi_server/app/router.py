from fastapi import APIRouter, UploadFile, File, Form, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse
from app.schemas import DetectionResponse, DetectionBox
from app.detector import detect_objects, get_class_name
from app.deepsort_tracker import track_objects, tracker, create_tracker, smoothers
import traceback
import cv2
import numpy as np
import io
import gc  # For garbage collection
import os
from tempfile import NamedTemporaryFile
from typing import List
import json
from starlette.background import BackgroundTask
import time
import logging
import base64

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()

# Maximum dimensions for image processing to prevent OOM errors
# Resize images to a maximum of 640x640
MAX_WIDTH = 640
MAX_HEIGHT = 640

# Maximum number of detections to process
MAX_DETECTIONS = 100

# Add WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def send_message(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

manager = ConnectionManager()

def resize_image_if_needed(image):
    """Resize image if it exceeds maximum dimensions while maintaining aspect ratio"""
    height, width = image.shape[:2]
    
    if width <= MAX_WIDTH and height <= MAX_HEIGHT:
        return image
    
    # Calculate new dimensions while maintaining aspect ratio
    if width > height:
        new_width = MAX_WIDTH
        new_height = int(height * (MAX_WIDTH / width))
    else:
        new_height = MAX_HEIGHT
        new_width = int(width * (MAX_HEIGHT / height))
    
    print(f"📏 Resizing image from {width}x{height} to {new_width}x{new_height}")
    return cv2.resize(image, (new_width, new_height))

def compute_iou(box1, box2):
    """Compute IoU between two boxes [x1,y1,x2,y2]"""
    x1, y1, x2, y2 = box1
    x1_, y1_, x2_, y2_ = box2
    xi1, yi1 = max(x1, x1_), max(y1, y1_)
    xi2, yi2 = min(x2, x2_), min(y2, y2_)
    inter_area = max(0, xi2 - xi1) * max(0, yi2 - yi1)
    box1_area = (x2 - x1) * (y2 - y1)
    box2_area = (x2_ - x1_) * (y2_ - y1_)
    union_area = box1_area + box2_area - inter_area
    return inter_area / union_area if union_area > 0 else 0

@router.post("/detect", response_model=DetectionResponse)
async def detect(file: UploadFile = File(...), focus_id: int = Form(None)):
    try:
        # Read image bytes
        image_bytes = await file.read()
        
        # Convert bytes to OpenCV image
        np_arr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        
        if image is None:
            return JSONResponse(status_code=400, content={"error": "Failed to decode image"})
        
        # Resize image to max 640x640 for memory management
        image = resize_image_if_needed(image)
        
        # Run detection on resized image
        detections, processed_image = detect_objects(image)
        logger.info(f"📸 Received image of shape: {image.shape}")
        logger.info(f"📦 Detections: {len(detections)}")
        
        # Limit the number of detections processed
        if len(detections) > MAX_DETECTIONS:
            logger.warning(f"⚠️ Limiting detections from {len(detections)} to {MAX_DETECTIONS}")
            detections = detections[:MAX_DETECTIONS]
        
        # Track only 'person' detections
        track_results = track_objects(
            detections,
            processed_image,
            focus_id,
            return_raw_detections=True
        )
        
        # Build response with only person boxes using IoU matching
        detection_boxes = []
        for x1, y1, x2, y2, track_id, class_id in track_results:
            track_box = [x1, y1, x2, y2]
            conf = 0.0
            
            # Find best matching detection using IoU
            if detections.size > 0:
                ious = [compute_iou(track_box, det[:4]) for det in detections]
                if ious:
                    max_iou_idx = np.argmax(ious)
                    if ious[max_iou_idx] > 0.5:  # IoU threshold
                        conf = float(detections[max_iou_idx][4])
            
            h, w = processed_image.shape[:2]
            detection_boxes.append(
                DetectionBox(
                    id=int(track_id),
                    label="person",
                    confidence=conf,
                    x1=x1 / w,   # normalize by image width
                    y1=y1 / h,   # normalize by image height
                    x2=x2 / w,
                    y2=y2 / h
                )
            )
        
        # Cleanup
        del processed_image, image
        gc.collect()
        
        logger.info(f"✅ Processed image with {len(detection_boxes)} tracked detections")
        return DetectionResponse(results=detection_boxes)
    except Exception as e:
        logger.error(f"❌ Error in /detect endpoint: {e}", exc_info=True)
        return JSONResponse(status_code=500, content={"error": str(e)})

@router.post("/process_image")
async def process_image(file: UploadFile = File(...)):
    try:
        # Read image bytes
        image_bytes = await file.read()
        
        # Convert bytes to OpenCV image
        np_arr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        
        if image is None:
            return JSONResponse(status_code=400, content={"error": "Failed to decode image"})
        
        # Resize image to max 640x640 for memory management
        image = resize_image_if_needed(image)
        
        # Start timing
        start_time = time.time()
        
        # Run detection on resized image
        detections, _ = detect_objects(image)
        
        # Calculate processing time
        processing_time = int((time.time() - start_time) * 1000)  # Convert to milliseconds
        
        # Calculate statistics
        total_detections = len(detections)
        avg_confidence = float(np.mean([det[4] for det in detections])) if total_detections > 0 else 0
        
        logger.info(f"Processing time: {processing_time}ms, Detections: {total_detections}")
        
        # Draw boxes and labels directly from YOLO detections
        for x1, y1, x2, y2, conf, cls in detections:
            if cls == 0:  # Only draw person detections
                # Draw bounding box
                cv2.rectangle(image, 
                            (int(x1), int(y1)), 
                            (int(x2), int(y2)), 
                            (0, 255, 0), 2)
                
                # Add label with confidence
                label = f"person {conf:.2f}"
                cv2.putText(image, 
                          label, 
                          (int(x1), int(y1)-10),
                          cv2.FONT_HERSHEY_SIMPLEX, 
                          0.5, 
                          (0, 255, 0), 
                          2)
        
        # Write to temp file
        tmp = NamedTemporaryFile(suffix=".jpg", delete=False)
        cv2.imwrite(tmp.name, image)
        
        # Cleanup
        del image
        gc.collect()
        
        # Create response with statistics headers
        response = FileResponse(
            tmp.name,
            media_type="image/jpeg",
            headers={
                "X-Total-Detections": str(total_detections),
                "X-Avg-Confidence": f"{avg_confidence:.2f}",
                "X-Processing-Time": str(processing_time)
            }
        )
        
        return response
    except Exception as e:
        logger.error(f"Error in /process_image endpoint: {e}", exc_info=True)
        return JSONResponse(status_code=500, content={"error": str(e)})

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Handle incoming messages if needed
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@router.post("/process_video")
async def process_video(
    file: UploadFile = File(...), 
    skip_frames: int = Form(0),  # Default to processing every 3rd frame
    full_resolution: bool = Form(True)  # Changed default to True
):
    in_tmp = None
    out_tmp = None
    try:
        # Validate skip_frames
        skip_frames = max(0, min(skip_frames, 5))  # Limit to 0-5 range
        logger.info(f"Processing video with frame skip: {skip_frames} (processing every {skip_frames + 1}th frame)")
        
        # Save incoming video
        contents = await file.read()
        in_tmp = NamedTemporaryFile(suffix=".mp4", delete=False)
        in_tmp.write(contents)
        in_tmp.flush()
        in_tmp.close()  # Release the OS lock
        
        cap = cv2.VideoCapture(in_tmp.name)

        if not cap.isOpened():
            raise RuntimeError("❌ Failed to open input video")

        # Get video properties
        original_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        original_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        # Calculate expected processing frames and time
        expected_processed_frames = total_frames // (skip_frames + 1) + 1
        estimated_time = expected_processed_frames * 0.4  # Assuming 400ms per frame

        # Use smaller dimensions for detection to improve performance
        MAX_DETECTION_WIDTH = 384
        MAX_DETECTION_HEIGHT = 384
        
        logger.info(f"✅ Input video: {original_width}x{original_height} @ {fps}fps")
        logger.info(f"Total frames: {total_frames}, Expected to process: {expected_processed_frames}")
        logger.info(f"Estimated processing time: {estimated_time:.1f} seconds")

        # Initialize statistics
        processed_frames = 0
        unique_track_ids = set()  # Track unique IDs instead of total detections
        start_time = time.time()
        
        # Read first frame to get resized size
        ret, frame = cap.read()
        if not ret:
            raise RuntimeError("❌ Failed to read first frame")

        # Get resized dimensions for detection
        resized = resize_image_if_needed(frame.copy()) if not full_resolution else frame
        resized_height, resized_width = resized.shape[:2]
        logger.info(f"✅ Processing dimensions: {resized_width}x{resized_height}")
        
        # Calculate scale factors
        scale_x = original_width / resized_width if full_resolution else 1.0
        scale_y = original_height / resized_height if full_resolution else 1.0
        
        logger.info(f"✅ Output dimensions: {original_width}x{original_height} (scale: {scale_x}x, {scale_y}y)")

        # Create video writer with appropriate dimensions
        out_tmp = NamedTemporaryFile(suffix=".mp4", delete=False)
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        writer = cv2.VideoWriter(
            out_tmp.name, 
            fourcc, 
            fps, 
            (original_width, original_height) if full_resolution else (resized_width, resized_height)
        )
        
        if not writer.isOpened():
            raise RuntimeError("❌ Failed to create video writer")

        # Reset tracker and smoothing state is now handled by factory
        # tracker.reset_tracks() -- removed

        # Initialize processing variables
        frame_i = 0
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        last_track_results = []  # Store last known tracking results
        
        # For websocket progress updates
        for websocket in manager.active_connections:
            await websocket.send_text(json.dumps({
                "type": "progress",
                "progress": 0.0,
                "total_frames": total_frames
            }))
        
        # Main processing loop
        while True:
            ret, frame = cap.read()
            if not ret:
                break
                
            # Update progress every 10 frames
            if frame_i % 10 == 0:
                progress = frame_i / max(total_frames, 1)
                elapsed_time = time.time() - start_time
                estimated_total = elapsed_time / max(progress, 0.01)
                remaining_time = max(0, estimated_total - elapsed_time)
                
                progress_info = {
                    "type": "progress",
                    "progress": progress,
                    "frame": frame_i,
                    "total_frames": total_frames,
                    "elapsed_time": f"{elapsed_time:.1f}s",
                    "remaining_time": f"{remaining_time:.1f}s",
                    "processed_frames": processed_frames,
                    "unique_tracks": len(unique_track_ids)
                }
                
                for websocket in manager.active_connections:
                    await websocket.send_text(json.dumps(progress_info))
            
            # Process frame at appropriate resolution
            img_small = resize_image_if_needed(frame.copy()) if not full_resolution else frame
            
            # Further downsize for detection if needed
            if img_small.shape[1] > MAX_DETECTION_WIDTH or img_small.shape[0] > MAX_DETECTION_HEIGHT:
                detection_scale = min(MAX_DETECTION_WIDTH / img_small.shape[1], 
                                     MAX_DETECTION_HEIGHT / img_small.shape[0])
                detection_width = int(img_small.shape[1] * detection_scale)
                detection_height = int(img_small.shape[0] * detection_scale)
                detection_img = cv2.resize(img_small, (detection_width, detection_height))
            else:
                detection_img = img_small
                
            # Run detection on selected frames
            dets, _ = detect_objects(detection_img)
            processed_frames += 1
            
            # Get tracking results
            track_results = track_objects(dets, detection_img, return_raw_detections=True)
            
            # Update unique track IDs
            for _, _, _, _, track_id, _ in track_results:
                unique_track_ids.add(track_id)
            
            # Store last known good tracking results
            if track_results:
                last_track_results = track_results
            
            # Always draw on original frame for perfect alignment
            draw_frame = frame
            
            # Draw boxes for confirmed tracks
            for x1, y1, x2, y2, track_id, _ in track_results:
                # Always map from detection_img → original frame
                det_w = detection_img.shape[1]
                det_h = detection_img.shape[0]
                scale_x = original_width / det_w
                scale_y = original_height / det_h
                x1 = int(x1 * scale_x)
                y1 = int(y1 * scale_y)
                x2 = int(x2 * scale_x)
                y2 = int(y2 * scale_y)
                
                # Draw bounding box
                cv2.rectangle(draw_frame, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 2)
                label = f"person {track_id}"
                cv2.putText(draw_frame, label, (int(x1), int(y1)-10),
                          cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
            
            # Write the processed frame
            writer.write(draw_frame)
            frame_i += 1
            
            # Log progress periodically
            if frame_i % 30 == 0:
                current_time = time.time()
                elapsed = current_time - start_time
                fps_processing = processed_frames / elapsed if elapsed > 0 else 0
                logger.info(
                    f"Frame {frame_i}/{total_frames} "
                    f"({processed_frames} processed, "
                    f"{len(unique_track_ids)} unique tracks, "
                    f"~{fps_processing:.1f} FPS)"
                )

            # Clean up memory
            del dets
            gc.collect()

        # Release resources
        cap.release()
        writer.release()
        
        # Final progress update
        for websocket in manager.active_connections:
            await websocket.send_text(json.dumps({
                "type": "progress",
                "progress": 1.0
            }))
        
        # ── FULLY RE-INIT TRACKER BETWEEN RUNS ──
        # throw away the old one and its EMA history
        tracker = create_tracker()
        smoothers.clear()
        
        # Calculate final statistics
        processing_time = time.time() - start_time
        avg_detections = len(unique_track_ids) / processed_frames if processed_frames > 0 else 0
        effective_fps = processed_frames / processing_time if processing_time > 0 else 0
        
        # Verify output
        file_size = os.path.getsize(out_tmp.name)
        logger.info(f"✅ Finished writing video: {out_tmp.name}, size: {file_size} bytes")
        
        if file_size < 1000:
            raise RuntimeError("❌ Output video file is too small or empty")

        # Return video stream with statistics
        def video_iterator(path):
            with open(path, "rb") as f:
                for chunk in iter(lambda: f.read(1024*1024), b""):
                    yield chunk
            # Close file explicitly before attempting deletion
            # We don't use a background task for deletion to avoid permission issues
            try:
                os.remove(path)
            except Exception as e:
                logger.warning(f"Could not remove output temp file: {e}")
        
        # Return without background task to avoid permission errors
        return StreamingResponse(
            video_iterator(out_tmp.name), 
            media_type="video/mp4",
            headers={
                "X-Total-Frames": str(total_frames),
                "X-Processed-Frames": str(processed_frames),
                "X-Total-Detections": str(len(unique_track_ids)),  # Now shows unique tracks
                "X-Avg-Detections": f"{avg_detections:.2f}",
                "X-Processing-Time": f"{processing_time:.1f}",
                "X-Frame-Rate": f"{effective_fps:.1f}"
            }
        )
    except Exception as e:
        logger.error(f"Error in /process_video endpoint: {e}", exc_info=True)
        return JSONResponse(status_code=500, content={"error": str(e)})
    finally:
        if in_tmp is not None:
            try:
                os.remove(in_tmp.name)
            except Exception as ex:
                logger.warning(f"Could not remove input temp file: {ex}")
        
        # Make sure to close and release all video resources
        try:
            if 'cap' in locals():
                cap.release()
            if 'writer' in locals():
                writer.release()
        except Exception as ex:
            logger.warning(f"Error closing video resources: {ex}")

@router.websocket("/ws/track")
async def ws_track(websocket: WebSocket):
    await websocket.accept()
    while True:
        # 1) receive raw JPEG bytes
        frame_bytes = await websocket.receive_bytes()
        # 2) decode to OpenCV image
        nparr = np.frombuffer(frame_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            continue
        h, w = img.shape[:2]
        # 3) detect & get absolute boxes
        dets, _ = detect_objects(img)
        # 4) normalize and build JSON
        boxes = []
        for idx, (x1, y1, x2, y2, conf, cls) in enumerate(dets):
            boxes.append({
              "id": idx,
              "x1": x1 / w,
              "y1": y1 / h,
              "x2": x2 / w,
              "y2": y2 / h,
              "conf": conf
            })
        # 5) send back a JSON text message
        await websocket.send_json({"type": "track", "boxes": boxes})

@router.post("/detect_batch")
async def detect_batch(files: List[UploadFile] = File(...)):
    try:
        # 1) Decode & resize all incoming frames
        images = []
        for f in files:
            data = await f.read()
            arr = np.frombuffer(data, np.uint8)
            img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            if img is None:
                raise ValueError(f"Failed to decode image from {f.filename}")
            images.append(resize_image_if_needed(img))

        logger.info(f"📸 Processing batch of {len(images)} images")

        # 2) Run batched YOLO
        batch_dets = detect_objects_batch(images)

        # 3) Run a single tracker pass over the sequence
        tracker.reset_tracks()
        all_frames = []
        for i, (img, dets) in enumerate(zip(images, batch_dets)):
            tracks = track_objects(dets, img, return_raw_detections=True)
            
            # 4) build serializable list of boxes
            frame_boxes = []
            for x1, y1, x2, y2, tid, _ in tracks:
                # Find matching detection with highest IoU for confidence score
                conf = 0.0
                if dets.size > 0:
                    ious = [compute_iou([x1,y1,x2,y2], det[:4]) for det in dets]
                    if ious:
                        max_iou_idx = np.argmax(ious)
                        if ious[max_iou_idx] > 0.5:  # IoU threshold
                            conf = float(dets[max_iou_idx][4])
                
                h, w = img.shape[:2]
                frame_boxes.append({
                    "id": int(tid),
                    "label": "person",
                    "confidence": conf,
                    "x1": x1 / w,
                    "y1": y1 / h,
                    "x2": x2 / w,
                    "y2": y2 / h
                })
            all_frames.append(frame_boxes)
            
            logger.info(f"Frame {i}: {len(frame_boxes)} tracked objects")

        # Cleanup
        del images, batch_dets
        gc.collect()

        return {"frames": all_frames}
    except Exception as e:
        logger.error(f"❌ Error in /detect_batch endpoint: {e}", exc_info=True)
        return JSONResponse(status_code=500, content={"error": str(e)})

@router.websocket("/ws/batch")
async def ws_batch(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # Receive batch message
            data = await websocket.receive_json()
            
            if data['type'] == 'batch_frames':
                frames = []
                # Decode frames from base64
                for frame_data in data['frames']:
                    frame_bytes = base64.b64decode(frame_data)
                    np_arr = np.frombuffer(frame_bytes, np.uint8)
                    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
                    if frame is not None:
                        frames.append(frame)
                
                if not frames:
                    continue
                
                # Process frames in batch
                batch_results = []
                for frame in frames:
                    # Run detection
                    dets, _ = detect_objects(frame)
                    
                    # Run tracking
                    track_results = track_objects(dets, frame, return_raw_detections=True)
                    
                    # Convert results to normalized coordinates
                    frame_height, frame_width = frame.shape[:2]
                    normalized_results = []
                    
                    for x1, y1, x2, y2, track_id, _ in track_results:
                        normalized_results.append({
                            'id': int(track_id),
                            'x1': float(x1 / frame_width),
                            'y1': float(y1 / frame_height),
                            'x2': float(x2 / frame_width),
                            'y2': float(y2 / frame_height)
                        })
                    
                    batch_results.append(normalized_results)
                
                # Send batch results
                await websocket.send_json({
                    'type': 'batch_results',
                    'results': batch_results,
                    'timestamp': data['timestamp']
                })
                
    except WebSocketDisconnect:
        print("WebSocket batch client disconnected")
    except Exception as e:
        print(f"Error in batch processing: {e}")
        traceback.print_exc()
        try:
            await websocket.close()
        except:
            pass
