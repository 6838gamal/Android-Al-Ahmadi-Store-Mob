from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.order import Order, OrderUpdate, OrderType, MaintenanceStatus, OrderStatus, PaymentMethod
from backend.api.dependencies import get_admin_user
from backend.models.user import User
from pydantic import BaseModel

router = APIRouter()


class MaintenanceCreate(BaseModel):
    customer_name: str
    customer_phone: str
    customer_email: Optional[str] = None
    device_type: str
    problem_description: str
    price: Optional[float] = 0
    notes: Optional[str] = None


class MaintenanceResponse(BaseModel):
    id: int
    order_number: str
    customer_name: str
    customer_phone: str
    order_type: OrderType
    status: OrderStatus
    maintenance_status: Optional[MaintenanceStatus]
    notes: Optional[str]
    admin_notes: Optional[str]
    images: List[str]
    estimated_time: Optional[str]
    total: float
    created_at: datetime

    class Config:
        from_attributes = True


def gen_maint_number(db):
    count = db.query(Order).filter(Order.order_type == OrderType.maintenance).count() + 1
    return f"MAINT-{datetime.now().year}-{count:04d}"


@router.post("/", response_model=MaintenanceResponse)
def create_maintenance(data: MaintenanceCreate, db: Session = Depends(get_db), admin: User = Depends(get_admin_user)):
    order = Order(
        order_number=gen_maint_number(db),
        customer_name=data.customer_name,
        customer_phone=data.customer_phone,
        customer_email=data.customer_email,
        order_type=OrderType.maintenance,
        status=OrderStatus.received,
        maintenance_status=MaintenanceStatus.received,
        items=[{"device": data.device_type, "problem": data.problem_description}],
        total=data.price or 0,
        subtotal=data.price or 0,
        notes=data.notes,
        payment_method=PaymentMethod.cash,
    )
    db.add(order)
    db.flush()
    db.add(OrderUpdate(order_id=order.id, status="received", note="تم استلام الجهاز"))
    db.commit()
    db.refresh(order)
    return order


@router.get("/", response_model=List[MaintenanceResponse])
def get_maintenance_orders(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    return db.query(Order).filter(
        Order.order_type == OrderType.maintenance
    ).order_by(Order.created_at.desc()).offset(skip).limit(limit).all()
