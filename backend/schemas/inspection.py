from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from backend.models.inspection import InspectionStatus


class InspectionCreate(BaseModel):
    customer_name: str
    customer_phone: str
    device_model: str
    problem_description: str
    images: Optional[List[str]] = []
    video_url: Optional[str] = None


class InspectionResponse(BaseModel):
    diagnosis: str
    estimated_price: Optional[str] = None
    response_notes: Optional[str] = None
    response_images: Optional[List[str]] = []


class InspectionItemResponse(BaseModel):
    id: int
    customer_id: Optional[int]
    customer_name: str
    customer_phone: str
    device_model: str
    problem_description: str
    images: Optional[List[str]]
    video_url: Optional[str]
    status: InspectionStatus
    staff_id: Optional[int]
    diagnosis: Optional[str]
    estimated_price: Optional[str]
    response_notes: Optional[str]
    response_images: Optional[List[str]]
    responded_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True
