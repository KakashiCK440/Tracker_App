# detector.py
import os
import cv2
import numpy as np
import torch
import torch.backends.cudnn as cudnn
import gc
import logging
from ultralytics import YOLO
from typing import List

logger = logging.getLogger(__name__)
# Enable cuDNN autotuner for fastest GPU convolution kernels
cudnn.benchmark = True

# Load the model weights
model_path = os.path.join(os.path.dirname(__file__), "best.pt")
if not os.path.exists(model_path):
    raise FileNotFoundError(f"Model not found at {model_path}")

# Choose device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
# Instantiate and prepare model
model = YOLO(model_path)
model.to(device)
model.half()
model.fuse()
model.eval()

# Log device info
if torch.cuda.is_available():
    logger.info(f"Using GPU: {torch.cuda.get_device_name(0)}")
else:
    logger.warning("No GPU detected; running on CPU")

# Constants
PERSON_CLASS_ID = 0
CONF_THRESHOLD = float(os.getenv("YOLO_CONF_THRESHOLD", "0.40"))
IOU_THRESHOLD = float(os.getenv("YOLO_IOU_THRESHOLD", "0.60"))


def detect_objects(image: np.ndarray):
    """
    Detect persons in a single image and return array of [x1,y1,x2,y2,conf,cls].
    """
    if image is None:
        raise ValueError("Invalid image provided")
    try:
        # Inference (Ultralytics will automatically letterbox & send to GPU)
        with torch.no_grad():
            results = model(
                image,                # H×W×3 uint8 BGR or RGB
                conf=CONF_THRESHOLD,  # confidence threshold
                iou=IOU_THRESHOLD,    # IoU threshold
                device=device         # 'cuda' or 'cpu'
            )

        # Parse detections
        detections = []
        for res in results:
            for box in res.boxes:
                cls_id = int(box.cls[0].cpu().item())
                if cls_id != PERSON_CLASS_ID:
                    continue
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().tolist()
                conf = float(box.conf[0].cpu().item())
                detections.append([x1, y1, x2, y2, conf, cls_id])

        det_array = np.array(detections, dtype=float) if detections else np.empty((0,6), dtype=float)

        # optional cleanup
        del results
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()

        return det_array, image

    except Exception:
        logger.exception("Error during detect_objects")
        return np.empty((0,6), dtype=float), image



def detect_objects_batch(images: List[np.ndarray]) -> List[np.ndarray]:
    """
    Batch-detect persons in a list of images, returning list of detection arrays.
    """
    try:
        # Preprocess all images
        tensors = []
        for img in images:
            rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            t = (
                torch.from_numpy(rgb)
                     .to(device, dtype=torch.float16)
                     .permute(2, 0, 1)
                     .unsqueeze(0)
                     .div(255.0)
            )
            tensors.append(t)
        batch = torch.cat(tensors, dim=0)
        with torch.no_grad():
            results = model(batch, conf=CONF_THRESHOLD, iou=IOU_THRESHOLD)
        outputs = []
        for res in results:
            frame_dets = []
            for box in res.boxes:
                cls_id = int(box.cls[0].cpu().item())
                if cls_id != PERSON_CLASS_ID:
                    continue
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy().tolist()
                conf = float(box.conf[0].cpu().item())
                frame_dets.append([x1, y1, x2, y2, conf, cls_id])
            outputs.append(np.array(frame_dets) if frame_dets else np.empty((0,6)))
        del results, batch
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        return outputs
    except Exception:
        logger.exception("Error during detect_objects_batch")
        return [np.empty((0,6)) for _ in images]


def get_class_name(class_id: int) -> str:
    return 'person' if class_id == PERSON_CLASS_ID else 'unknown'


def get_boxes_from_detections(detections: np.ndarray) -> List[List[float]]:
    return detections.tolist()