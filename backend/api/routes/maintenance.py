from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.order import Order, OrderUpdate, OrderType, MaintenanceStatus, OrderStatus, PaymentMethod
from backend.models.notification import Notification, NotificationType
from backend.api.dependencies import get_admin_user, require_staff_or_above, get_current_user
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


class CustomerMaintenanceCreate(BaseModel):
    device_type: str
    problem_description: str
    media_urls: Optional[List[str]] = []
    notes: Optional[str] = None


class MaintenanceStatusUpdate(BaseModel):
    maintenance_status: str
    note: Optional[str] = None
    estimated_time: Optional[str] = None
    admin_notes: Optional[str] = None


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
    items: List
    created_at: datetime

    class Config:
        from_attributes = True


MAINT_STATUS_NOTIFICATIONS = {
    "received":     ("تم استلام جهازك ✅", "تم استلام جهازك بنجاح وسيبدأ الفحص قريباً"),
    "inspecting":   ("جاري فحص جهازك 🔍", "فريق الصيانة يفحص جهازك الآن"),
    "repairing":    ("جاري إصلاح جهازك 🔧", "بدأنا العمل على إصلاح جهازك"),
    "waiting_part": ("بانتظار قطعة الغيار ⏳", "جهازك بانتظار قطعة غيار. سيتم إعلامك عند توفرها"),
    "repaired":     ("تم إصلاح جهازك ✅", "تم إصلاح جهازك بنجاح"),
    "ready":        ("جهازك جاهز للاستلام 🎉", "جهازك جاهز، يمكنك استلامه من المتجر"),
    "delivered":    ("تم تسليم جهازك 🎉", "تم تسليم جهازك. شكراً لثقتك بنا"),
}


def _create_maintenance_notification(db: Session, order: Order, status_value: str):
    if status_value not in MAINT_STATUS_NOTIFICATIONS:
        return
    title, body = MAINT_STATUS_NOTIFICATIONS[status_value]

    customer_id = getattr(order, "customer_id", None)
    if not customer_id and order.customer_phone:
        customer = db.query(User).filter(User.phone == order.customer_phone).first()
        if customer:
            customer_id = customer.id

    if not customer_id:
        return

    notif = Notification(
        user_id=customer_id,
        title=title,
        body=f"{body} — رقم الطلب: {order.order_number}",
        notification_type=NotificationType.maintenance,
        is_important=status_value in ("ready", "delivered"),
        reference_id=order.id,
        reference_type="maintenance",
    )
    db.add(notif)


def gen_maint_number(db):
    count = db.query(Order).filter(Order.order_type == OrderType.maintenance).count() + 1
    return f"MAINT-{datetime.now().year}-{count:04d}"


@router.post("/", response_model=MaintenanceResponse)
def create_maintenance(
    data: MaintenanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff_or_above)
):
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
    _create_maintenance_notification(db, order, "received")
    db.commit()
    db.refresh(order)
    return order


@router.post("/customer-request", response_model=MaintenanceResponse)
def customer_submit_maintenance(
    data: CustomerMaintenanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Any authenticated customer can submit a maintenance request directly.
    Staff will be notified and follow up.
    """
    order = Order(
        order_number=gen_maint_number(db),
        customer_id=current_user.id,
        customer_name=current_user.name,
        customer_phone=current_user.phone or "",
        customer_email=current_user.email,
        order_type=OrderType.maintenance,
        status=OrderStatus.received,
        maintenance_status=MaintenanceStatus.received,
        items=[{"device": data.device_type, "problem": data.problem_description}],
        images=data.media_urls or [],
        total=0,
        subtotal=0,
        notes=data.notes,
        payment_method=PaymentMethod.cash,
    )
    db.add(order)
    db.flush()
    db.add(OrderUpdate(
        order_id=order.id,
        status="received",
        note="تم إرسال طلب الصيانة من التطبيق"
    ))
    _create_maintenance_notification(db, order, "received")
    db.commit()
    db.refresh(order)
    return order


@router.get("/my", response_model=List[MaintenanceResponse])
def get_my_maintenance(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return the authenticated customer's own maintenance orders."""
    orders = (
        db.query(Order)
        .filter(
            Order.order_type == OrderType.maintenance,
            Order.customer_id == current_user.id,
        )
        .order_by(Order.created_at.desc())
        .all()
    )
    # Fallback: also match by phone if no customer_id orders found
    if not orders and current_user.phone:
        orders = (
            db.query(Order)
            .filter(
                Order.order_type == OrderType.maintenance,
                Order.customer_phone == current_user.phone,
            )
            .order_by(Order.created_at.desc())
            .all()
        )
    return orders


@router.get("/", response_model=List[MaintenanceResponse])
def get_maintenance_orders(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff_or_above)
):
    return db.query(Order).filter(
        Order.order_type == OrderType.maintenance
    ).order_by(Order.created_at.desc()).offset(skip).limit(limit).all()


@router.put("/{order_id}/status", response_model=MaintenanceResponse)
def update_maintenance_status(
    order_id: int,
    data: MaintenanceStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff_or_above)
):
    order = db.query(Order).filter(
        Order.id == order_id, Order.order_type == OrderType.maintenance
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Maintenance order not found")

    order.maintenance_status = MaintenanceStatus(data.maintenance_status)
    if data.maintenance_status == "delivered":
        order.status = OrderStatus.delivered
    if data.admin_notes:
        order.admin_notes = data.admin_notes
    if data.estimated_time:
        order.estimated_time = data.estimated_time

    upd = OrderUpdate(
        order_id=order.id,
        status=data.maintenance_status,
        note=data.note,
        employee_name=current_user.name,
    )
    db.add(upd)
    _create_maintenance_notification(db, order, data.maintenance_status)
    db.commit()
    db.refresh(order)
    return order
