from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime
from backend.core.database import get_db
from backend.models.order import Order, OrderUpdate, OrderStatus, OrderType
from backend.models.notification import Notification, NotificationType
from backend.models.loyalty import LoyaltyAccount, LoyaltyTransaction, LoyaltyTransactionType
from backend.schemas.order import OrderCreate, OrderUpdateStatus, OrderResponse
from backend.api.dependencies import get_admin_user, get_current_user, get_current_user_optional, require_staff_or_above
from backend.models.user import User, UserRole
import random

router = APIRouter()


def generate_order_number(db: Session) -> str:
    year = datetime.now().year
    count = db.query(Order).count() + 1
    return f"ORD-{year}-{count:04d}"


ORDER_STATUS_NOTIFICATIONS = {
    "received":   ("تم استلام طلبك ✅", "تم استلام طلبك بنجاح وسيتم مراجعته قريباً"),
    "reviewing":  ("طلبك قيد المراجعة 🔍", "جاري مراجعة طلبك والتحقق من التفاصيل"),
    "confirmed":  ("تم تأكيد طلبك ✅", "تم تأكيد طلبك وسيبدأ التجهيز近"),
    "preparing":  ("جاري تجهيز طلبك 📦", "فريقنا يجهّز طلبك الآن"),
    "shipped":    ("تم شحن طلبك 🚚", "طلبك في طريقه إليك"),
    "on_the_way": ("طلبك في الطريق 🛵", "المندوب في طريقه إليك"),
    "delivered":  ("تم تسليم طلبك 🎉", "تم تسليم طلبك بنجاح. شكراً لثقتك بنا"),
    "cancelled":  ("تم إلغاء طلبك ❌", "تم إلغاء طلبك. للاستفسار تواصل معنا"),
}


def _create_order_notification(db: Session, order: Order, status_value: str):
    """Push a notification to the order customer when status changes."""
    if status_value not in ORDER_STATUS_NOTIFICATIONS:
        return
    title, body = ORDER_STATUS_NOTIFICATIONS[status_value]

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
        notification_type=NotificationType.order,
        is_important=status_value in ("delivered", "cancelled"),
        reference_id=order.id,
        reference_type="order",
    )
    db.add(notif)


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
    _create_order_notification(db, order, "received")
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
    current_user: User = Depends(require_staff_or_above)
):
    query = db.query(Order)

    # Branch manager sees only their branch's orders
    if current_user.role == UserRole.branch_manager and current_user.branch_id:
        query = query.filter(Order.branch_id == current_user.branch_id)

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


@router.get("/my", response_model=List[OrderResponse])
def get_my_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Authenticated customer sees only their own orders."""
    return (
        db.query(Order)
        .filter(Order.customer_phone == current_user.phone)
        .order_by(Order.created_at.desc())
        .all()
    )


@router.get("/my/{phone}", response_model=List[OrderResponse])
def get_orders_by_phone(
    phone: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns orders for a phone number.
    Customers may only view their own phone's orders.
    Staff and above may view any phone.
    """
    if current_user.role == UserRole.customer:
        if current_user.phone != phone:
            raise HTTPException(status_code=403, detail="غير مصرح: لا يمكنك الاطلاع على طلبات هاتف آخر")
    return (
        db.query(Order)
        .filter(Order.customer_phone == phone)
        .order_by(Order.created_at.desc())
        .all()
    )


@router.get("/{order_id}", response_model=OrderResponse)
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_optional),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Customers can only see their own orders
    if current_user and current_user.role == UserRole.customer:
        if order.customer_phone != current_user.phone:
            raise HTTPException(status_code=403, detail="غير مصرح: هذا الطلب لا ينتمي إلى حسابك")

    # Unauthenticated users cannot view orders by ID
    if not current_user:
        raise HTTPException(status_code=401, detail="يجب تسجيل الدخول لعرض تفاصيل الطلب")

    return order


@router.get("/track/{order_number}")
def track_order(order_number: str, db: Session = Depends(get_db)):
    """Public order tracking by order number — returns safe fields only (no PII)."""
    order = db.query(Order).filter(Order.order_number == order_number).first()
    if not order:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    masked_phone = ""
    if order.customer_phone:
        p = order.customer_phone
        masked_phone = p[:3] + "****" + p[-3:] if len(p) >= 6 else "***"
    return {
        "order_number": order.order_number,
        "status": order.status,
        "maintenance_status": order.maintenance_status,
        "order_type": order.order_type,
        "created_at": order.created_at,
        "customer_name_masked": order.customer_name[:2] + "***" if order.customer_name else "",
        "customer_phone_masked": masked_phone,
        "estimated_time": order.estimated_time,
    }


@router.put("/{order_id}/status", response_model=OrderResponse)
def update_order_status(
    order_id: int,
    update_data: OrderUpdateStatus,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_staff_or_above)
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
        employee_name=update_data.employee_name or current_user.name,
    )
    db.add(upd)

    # Auto-notify customer on order status change
    if update_data.status:
        _create_order_notification(db, order, update_data.status.value)

    # ── خصم نقاط الولاء تلقائياً عند الإلغاء ──
    if update_data.status == OrderStatus.cancelled and order.customer_id:
        acc = db.query(LoyaltyAccount).filter(LoyaltyAccount.user_id == order.customer_id).first()
        if acc and acc.total_points > 0:
            deduct = min(acc.total_points, 1)
            acc.total_points = max(0, acc.total_points - deduct)
            if acc.total_points < 25:
                acc.is_locked = False
            revoke_tx = LoyaltyTransaction(
                user_id=order.customer_id,
                points=-deduct,
                transaction_type=LoyaltyTransactionType.redeem,
                reason=f"خصم نقاط بسبب إلغاء الطلب {order.order_number}",
                reference_id=order.id,
                reference_type="order",
                balance_after=acc.total_points,
            )
            db.add(revoke_tx)

    db.commit()
    db.refresh(order)
    return order
