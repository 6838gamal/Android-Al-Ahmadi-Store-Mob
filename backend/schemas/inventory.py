from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from backend.models.inventory_item import ItemGrade, ItemStatus


class InventoryItemCreate(BaseModel):
    serial_number: Optional[str] = None
    category: str
    brand: Optional[str] = None
    model: Optional[str] = None
    grade: ItemGrade = ItemGrade.a
    price: float
    images: Optional[List[str]] = []
    notes: Optional[str] = None
    product_id: Optional[int] = None
    branch_id: Optional[int] = None
    warehouse_id: Optional[int] = None


class InventoryItemUpdate(BaseModel):
    serial_number: Optional[str] = None
    category: Optional[str] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    grade: Optional[ItemGrade] = None
    status: Optional[ItemStatus] = None
    price: Optional[float] = None
    images: Optional[List[str]] = None
    notes: Optional[str] = None
    branch_id: Optional[int] = None
    warehouse_id: Optional[int] = None


class InventoryItemResponse(BaseModel):
    id: int
    serial_number: Optional[str]
    category: str
    brand: Optional[str]
    model: Optional[str]
    grade: ItemGrade
    status: ItemStatus
    price: float
    images: Optional[List[str]]
    notes: Optional[str]
    product_id: Optional[int]
    branch_id: Optional[int]
    warehouse_id: Optional[int]
    sold_to_id: Optional[int]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
