# app/schemas.py
from pydantic import BaseModel
from typing import List, Optional

class DetectionBox(BaseModel):
    id: int
    label: str
    confidence: float
    x1: float  # normalized [0,1]
    y1: float  # normalized [0,1]
    x2: float  # normalized [0,1]
    y2: float  # normalized [0,1]

class DetectionResponse(BaseModel):
    results: List[DetectionBox]
