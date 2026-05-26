from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime
from backend.models.order import OrderStatus, MaintenanceStatus, OrderType, PaymentMethod


class OrderItem(BaseModel):
    product_id: Optional[int] = None
    product_name: str
    quantity: int
    price: float


class OrderCreate(BaseModel):
    customer_name: str
    customer_phone: str
    customer_email: Optional[str] = None
    order_type: OrderType = OrderType.product
    items: List[OrderItem] = []
    payment_method: PaymentMethod = PaymentMethod.cash
    notes: Optional[str] = None
    address: Optional[str] = None
    device_type: Optional[str] = None
    problem_description: Optional[str] = None


class OrderUpdateStatus(BaseModel):
    status: Optional[OrderStatus] = None
    maintenance_status: Optional[MaintenanceStatus] = None
    note: Optional[str] = None
    employee_name: Optional[str] = None
    estimated_time: Optional[str] = None
    admin_notes: Optional[str] = None


class OrderUpdateResponse(BaseModel):
    id: int
    status: str
    note: Optional[str]
    employee_name: Optional[str]
    images: List[str]
    created_at: datetime

    class Config:
        from_attributes = True


class OrderResponse(BaseModel):
    id: int
    order_number: str
    customer_name: str
    customer_phone: str
    customer_email: Optional[str]
    order_type: OrderType
    status: OrderStatus
    maintenance_status: Optional[MaintenanceStatus]
    items: List[Any]
    subtotal: float
    discount: float
    total: float
    payment_method: PaymentMethod
    notes: Optional[str]
    admin_notes: Optional[str]
    images: List[str]
    estimated_time: Optional[str]
    employee_name: Optional[str]
    address: Optional[str]
    updates: List[OrderUpdateResponse] = []
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True
