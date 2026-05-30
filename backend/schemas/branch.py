from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class BranchCreate(BaseModel):
    name: str
    name_ar: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    manager_id: Optional[int] = None


class BranchUpdate(BaseModel):
    name: Optional[str] = None
    name_ar: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    manager_id: Optional[int] = None
    is_active: Optional[bool] = None


class BranchResponse(BaseModel):
    id: int
    name: str
    name_ar: Optional[str]
    address: Optional[str]
    phone: Optional[str]
    manager_id: Optional[int]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class WarehouseCreate(BaseModel):
    name: str
    name_ar: Optional[str] = None
    branch_id: Optional[int] = None
    address: Optional[str] = None


class WarehouseResponse(BaseModel):
    id: int
    name: str
    name_ar: Optional[str]
    branch_id: Optional[int]
    address: Optional[str]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
