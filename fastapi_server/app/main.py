# main.py
from fastapi import FastAPI
from app.router import router
import torch
import logging
from app.detector import model, device

logger = logging.getLogger(__name__)
app = FastAPI()

@app.on_event("startup")
def warmup_model():
    logger.info(f"Warming up YOLO model on {device}...")
    # Dummy run to compile cuDNN kernels
    dummy = torch.zeros((1, 3, 640, 640), device=device, dtype=torch.float16)
    with torch.no_grad():
        _ = model(dummy, conf=0.1, iou=0.5)
    logger.info("YOLO model warmup complete.")

app.include_router(router)
