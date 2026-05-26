from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime
from backend.core.database import get_db
from backend.models.order import Order, OrderUpdate, OrderStatus, OrderType
from backend.schemas.order import OrderCreate, OrderUpdateStatus, OrderResponse
from backend.api.dependencies import get_admin_user, get_current_user
from backend.models.user import User
import random

router = APIRouter()


def generate_order_number(db: Session) -> str:
    year = datetime.now().year
    count = db.query(Order).count() + 1
    return f"ORD-{year}-{count:04d}"


@router.post("/", response_model=OrderResponse)
def create_order(
    order_data: OrderCreate,
    db: Session = Depends(get_db),
):
    order_number = generate_order_number(db)
    items_list = [item.dict() for item in order_data.items]
    subtotal = sum(item.price * item.quantity for item in order_data.items)

    order = Order(
        order_number=order_number,
        customer_name=order_data.customer_name,
        customer_phone=order_data.customer_phone,
        customer_email=order_data.customer_email,
        order_type=order_data.order_type,
        items=items_list,
        subtotal=subtotal,
        total=subtotal,
        payment_method=order_data.payment_method,
        notes=order_data.notes,
        address=order_data.address,
    )
    db.add(order)
    db.flush()

    update = OrderUpdate(
        order_id=order.id,
        status=OrderStatus.received.value,
        note="تم استلام الطلب بنجاح",
    )
    db.add(update)
    db.commit()
    db.refresh(order)
    return order


@router.get("/", response_model=List[OrderResponse])
def get_orders(
    skip: int = 0,
    limit: int = 50,
    status: Optional[OrderStatus] = None,
    order_type: Optional[OrderType] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    query = db.query(Order)
    if status:
        query = query.filter(Order.status == status)
    if order_type:
        query = query.filter(Order.order_type == order_type)
    if search:
        query = query.filter(
            Order.customer_name.ilike(f"%{search}%") |
            Order.order_number.ilike(f"%{search}%") |
            Order.customer_phone.ilike(f"%{search}%")
        )
    return query.order_by(Order.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/my/{phone}", response_model=List[OrderResponse])
def get_my_orders(phone: str, db: Session = Depends(get_db)):
    return db.query(Order).filter(Order.customer_phone == phone).order_by(Order.created_at.desc()).all()


@router.get("/{order_id}", response_model=OrderResponse)
def get_order(order_id: int, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.get("/track/{order_number}", response_model=OrderResponse)
def track_order(order_number: str, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.order_number == order_number).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.put("/{order_id}/status", response_model=OrderResponse)
def update_order_status(
    order_id: int,
    update_data: OrderUpdateStatus,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if update_data.status:
        order.status = update_data.status
    if update_data.maintenance_status:
        order.maintenance_status = update_data.maintenance_status
    if update_data.admin_notes:
        order.admin_notes = update_data.admin_notes
    if update_data.estimated_time:
        order.estimated_time = update_data.estimated_time

    status_label = update_data.status.value if update_data.status else (
        update_data.maintenance_status.value if update_data.maintenance_status else "updated"
    )
    upd = OrderUpdate(
        order_id=order.id,
        status=status_label,
        note=update_data.note,
        employee_name=update_data.employee_name or (admin.name if admin else None),
    )
    db.add(upd)
    db.commit()
    db.refresh(order)
    return order
