import os
import numpy as np
import gc
import traceback
from deep_sort_realtime.deepsort_tracker import DeepSort
from app.schemas import DetectionBox
from app.detector import get_class_name   # YOLO class lookup

# Load configuration from environment variables
SMOOTH_ALPHA = float(os.getenv("SMOOTH_ALPHA", "1.0"))  # Increased from 0.2 to 0.8 for less lag
MAX_AGE = int(os.getenv("MAX_AGE", "30"))  # Maximum frames to keep track
NMS_MAX_OVERLAP = float(os.getenv("NMS_MAX_OVERLAP", "0.8"))  # NMS threshold
MAX_COSINE_DISTANCE = float(os.getenv("MAX_COSINE_DISTANCE", "0.25"))  # Feature similarity threshold
NN_BUDGET = int(os.getenv("NN_BUDGET", "150"))  # Maximum size of feature database

# Initialize DeepSORT tracker with optimized settings for person tracking
def create_tracker():
    return DeepSort(
        max_age=MAX_AGE,
        n_init=1,                  # Reduced to 1 for immediate track confirmation
        nms_max_overlap=NMS_MAX_OVERLAP,
        max_cosine_distance=MAX_COSINE_DISTANCE,
        nn_budget=NN_BUDGET,
        override_track_class=None,
        embedder="mobilenet",      # Lightweight embedder for speed
        half=True,                 # FP16 for faster inference
        bgr=True,
        embedder_gpu=True          # Use GPU for embeddings
    )

# original global for backwards-compatibility
tracker = create_tracker()

# Box smoothing parameters
smoothers = {}  # track_id → [x1,y1,x2,y2]

def _warmup_tracker():
    """Warm up the tracker's embedder to reduce first-frame lag"""
    dummy = np.zeros((128, 128, 3), dtype=np.uint8)
    try:
        tracker.update_tracks([], frame=dummy)
    except Exception:
        pass

_warmup_tracker()

def reset_tracks():
    """Reset all tracks in the tracker and clear smoothing history."""
    global tracker
    tracker = create_tracker()
    smoothers.clear()  # Clear EMA history

tracker.reset_tracks = reset_tracks

def smooth_box(raw_box, prev_box):
    """Apply exponential moving average smoothing to bounding box"""
    if prev_box is None:
        return raw_box
    return [int(SMOOTH_ALPHA * r + (1 - SMOOTH_ALPHA) * p) 
            for r, p in zip(raw_box, prev_box)]

def is_valid_bbox(bbox: list, image: np.ndarray = None) -> bool:
    """
    Enhanced bbox validation with aspect ratio and size checks.
    """
    if len(bbox) != 4:
        return False
    
    l, t, r, b = bbox
    width = r - l
    height = b - t
    
    # Basic validity checks
    if not (r > l and b > t):
        return False
        
    # Minimum size check (in pixels)
    if width < 10 or height < 20:  # People are usually taller than wide
        return False
        
    # Aspect ratio check (typical human proportions)
    aspect_ratio = height / width if width > 0 else 0
    if not (1.0 <= aspect_ratio <= 3.0):  # Typical human aspect ratios
        return False
        
    # Dynamic maximum size check based on image dimensions
    if image is not None:
        h, w = image.shape[:2]
        if width > 0.8 * w or height > 0.8 * h:
            return False
    
    return True

def track_objects(
    detections: np.ndarray,
    image: np.ndarray,
    focus_id: int = None,
    return_raw_detections: bool = False
) -> list:
    """
    Enhanced tracking with better filtering and motion prediction.
    """
    # Even if there are no new detections, let DeepSORT predict motion
    if detections is None:
        detections = np.empty((0, 6))
    
    # Get original image dimensions for possible rescaling later
    img_height, img_width = image.shape[:2]
    
    # Keep only person detections and valid-size boxes
    person_detections = detections[detections[:, 5] == 0] if len(detections) > 0 else detections
    filtered = []
    
    for det in person_detections:
        bbox = det[:4].tolist()
        if is_valid_bbox(bbox, image):
            filtered.append(det)

    # Convert to DeepSORT input format with confidence scores
    detection_list = []
    if filtered:
        for x1, y1, x2, y2, conf, cls in filtered:
            # compute width and height for DeepSORT input
            w = x2 - x1
            h = y2 - y1
            detection_list.append(([x1, y1, w, h], float(conf), 'person'))  # Use XYWH for DeepSORT

    # Update tracker with motion prediction
    tracks = tracker.update_tracks(detection_list, frame=image)

    results = []
    confirmed_ids = set()
    
    # Process confirmed tracks first
    for trk in tracks:
        if not trk.is_confirmed():
            continue
            
        tid = int(trk.track_id)
        confirmed_ids.add(tid)
        
        if focus_id is not None and tid != focus_id:
            continue
            
        raw = list(map(int, trk.to_ltrb()))
        
        # Apply exponential moving average smoothing
        sm = smooth_box(raw, smoothers.get(tid))
        smoothers[tid] = sm
        
        l, t, r, b = sm
        
        # Ensure coordinates are within image boundaries
        l = max(0, min(l, img_width - 1))
        t = max(0, min(t, img_height - 1))
        r = max(l + 1, min(r, img_width))
        b = max(t + 1, min(b, img_height))
        
        # Additional validation on track box
        if is_valid_bbox([l, t, r, b], image):
            results.append([l, t, r, b, tid, 0])

    # Add raw detections as fallback if requested
    if return_raw_detections and len(results) < len(filtered):
        next_id = max(confirmed_ids, default=0) + 1
        for det in filtered:
            x1, y1, x2, y2 = det[:4]
            
            # Skip if too close to existing track
            if any(abs(x1 - l) < 20 and abs(y1 - t) < 20 for l, t, *_ in results):
                continue
                
            # Validate raw detection box
            if is_valid_bbox([x1, y1, x2, y2], image):
                results.append([x1, y1, x2, y2, next_id, 0])
                next_id += 1

    # Cleanup old tracks from smoothers
    active_ids = {r[4] for r in results}
    smoothers_to_remove = [tid for tid in smoothers if tid not in active_ids]
    for tid in smoothers_to_remove:
        del smoothers[tid]

    # Cleanup
    del tracks
    gc.collect()
    
    return results
