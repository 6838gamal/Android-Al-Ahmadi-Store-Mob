from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from backend.models.product import ProductCategory, ProductStatus


class ProductCreate(BaseModel):
    name: str
    name_ar: Optional[str] = None
    category: ProductCategory
    brand: Optional[str] = None
    model: Optional[str] = None
    series: Optional[str] = None   # e.g. "s_series", "note_series"
    image_url: Optional[str] = None
    price: float
    quantity: int = 0
    status: ProductStatus = ProductStatus.available
    description: Optional[str] = None
    barcode: Optional[str] = None
    notes: Optional[str] = None
    is_featured: bool = False


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    name_ar: Optional[str] = None
    category: Optional[ProductCategory] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    series: Optional[str] = None
    price: Optional[float] = None
    quantity: Optional[int] = None
    status: Optional[ProductStatus] = None
    description: Optional[str] = None
    notes: Optional[str] = None
    is_featured: Optional[bool] = None
    is_active: Optional[bool] = None


class ProductResponse(BaseModel):
    id: int
    name: str
    name_ar: Optional[str]
    category: ProductCategory
    brand: Optional[str]
    model: Optional[str]
    series: Optional[str]
    image_url: Optional[str]
    price: float
    quantity: int
    status: ProductStatus
    description: Optional[str]
    barcode: Optional[str]
    is_featured: bool
    created_at: datetime

    class Config:
        from_attributes = True
