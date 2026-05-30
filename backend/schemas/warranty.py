from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class WarrantyCreate(BaseModel):
    order_id: Optional[int] = None
    customer_id: Optional[int] = None
    product_name: str
    product_serial: Optional[str] = None
    purchase_price: Optional[float] = None
    warranty_days: int = 7


class ReturnRequest(BaseModel):
    return_reason: str


class WarrantyResponse(BaseModel):
    id: int
    order_id: Optional[int]
    customer_id: Optional[int]
    product_name: str
    product_serial: Optional[str]
    purchase_price: Optional[float]
    warranty_days: int
    starts_at: datetime
    ends_at: datetime
    is_return_requested: bool
    return_reason: Optional[str]
    return_requested_at: Optional[datetime]
    return_resolved: bool
    return_notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
