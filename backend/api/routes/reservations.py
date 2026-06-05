from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
from backend.core.database import get_db
from backend.models.reservation import Reservation, ReservationStatus, CancellationType
from backend.models.product import Product, ProductStatus
from backend.api.dependencies import get_admin_user, require_staff_or_above, get_current_user
from backend.models.user import User
from backend.models.wallet import WalletTransaction, TransactionType, WalletCurrency
from pydantic import BaseModel

router = APIRouter()

DEFAULT_RESERVATION_DAYS = 14
EXTENSION_DAYS = 3
DEFAULT_PENALTY = 2000.0


class ReservationCreate(BaseModel):
    customer_name: str
    customer_phone: str
    product_id: int
    notes: Optional[str] = None
    days: int = DEFAULT_RESERVATION_DAYS
    deposit_amount: Optional[float] = 0.0
    deposit_paid: Optional[bool] = False


class ReservationResponse(BaseModel):
    id: int
    reservation_number: str
    customer_name: str
    customer_phone: str
    product_id: int
    product_name: str
    price: float
    status: ReservationStatus
    expires_at: Optional[datetime]
    notes: Optional[str]
    deposit_amount: float
    deposit_paid: bool
    remaining_amount: float
    penalty_amount: float
    extension_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class CancelRequest(BaseModel):
    cancellation_type: str
    reason: Optional[str] = None


def gen_res_number(db):
    count = db.query(Reservation).count() + 1
    return f"RES-{datetime.now().year}-{count:04d}"


@router.get("/my", response_model=List[ReservationResponse])
def my_reservations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the authenticated customer's own reservations."""
    reservations = (
        db.query(Reservation)
        .filter(Reservation.customer_id == current_user.id)
        .order_by(Reservation.created_at.desc())
        .all()
    )
    if not reservations and current_user.phone:
        reservations = (
            db.query(Reservation)
            .filter(Reservation.customer_phone == current_user.phone)
            .order_by(Reservation.created_at.desc())
            .all()
        )
    return reservations


@router.post("/", response_model=ReservationResponse)
def create_reservation(data: ReservationCreate, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    product = db.query(Product).filter(Product.id == data.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.status != ProductStatus.available:
        raise HTTPException(status_code=400, detail="Product not available")

    product.status = ProductStatus.reserved
    expires = datetime.utcnow() + timedelta(days=data.days)
    deposit = data.deposit_amount or 0.0

    res = Reservation(
        reservation_number=gen_res_number(db),
        customer_name=data.customer_name,
        customer_phone=data.customer_phone,
        product_id=data.product_id,
        product_name=product.name,
        price=product.price,
        notes=data.notes,
        expires_at=expires,
        deposit_amount=deposit,
        deposit_paid=data.deposit_paid or False,
        remaining_amount=max(0.0, product.price - deposit),
        penalty_amount=DEFAULT_PENALTY,
    )
    db.add(res)
    db.commit()
    db.refresh(res)
    return res


@router.get("/", response_model=List[ReservationResponse])
def get_reservations(
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    return db.query(Reservation).order_by(Reservation.created_at.desc()).offset(skip).limit(limit).all()


@router.put("/{res_id}/cancel")
def cancel_reservation(
    res_id: int,
    data: CancelRequest,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if not res:
        raise HTTPException(status_code=404, detail="Not found")
    if res.status not in [ReservationStatus.pending, ReservationStatus.confirmed]:
        raise HTTPException(status_code=400, detail="الحجز لا يمكن إلغاؤه في هذه الحالة")

    cancel_type = data.cancellation_type
    res.status = ReservationStatus.cancelled
    res.cancelled_at = datetime.utcnow()
    res.cancel_reason = data.reason
    res.cancellation_type = cancel_type

    # Release the product back to available
    product = db.query(Product).filter(Product.id == res.product_id).first()
    if product:
        product.status = ProductStatus.available

    if cancel_type == CancellationType.with_penalty:
        # خصم 2000 غرامة وترحيل الباقي للمحفظة
        penalty = res.penalty_amount or DEFAULT_PENALTY
        refund = max(0.0, res.deposit_amount - penalty)
        res.customer_credit_amount = refund
        if refund > 0 and res.customer_id:
            # Credit remaining to wallet
            user = db.query(User).filter(User.id == res.customer_id).first()
            if user:
                user.wallet_balance = (user.wallet_balance or 0.0) + refund
                tx = WalletTransaction(
                    user_id=user.id,
                    amount=refund,
                    currency=WalletCurrency.YER,
                    transaction_type=TransactionType.credit,
                    reason=f"متبقيات إلغاء حجز {res.reservation_number} بعد خصم الغرامة",
                    reference_id=res.id,
                    reference_type="reservation_cancel",
                    balance_after=user.wallet_balance,
                )
                db.add(tx)
        message = f"تم الإلغاء. تم خصم غرامة {penalty:,.0f} ريال. المبلغ المرحّل للعميل: {refund:,.0f} ريال"

    elif cancel_type == CancellationType.full_return:
        # إرجاع المبلغ كاملاً أمانة للمحفظة
        res.customer_credit_amount = res.deposit_amount
        if res.deposit_amount > 0 and res.customer_id:
            user = db.query(User).filter(User.id == res.customer_id).first()
            if user:
                user.wallet_balance = (user.wallet_balance or 0.0) + res.deposit_amount
                tx = WalletTransaction(
                    user_id=user.id,
                    amount=res.deposit_amount,
                    currency=WalletCurrency.YER,
                    transaction_type=TransactionType.credit,
                    reason=f"إرجاع أمانة حجز {res.reservation_number} كاملاً",
                    reference_id=res.id,
                    reference_type="reservation_cancel_full",
                    balance_after=user.wallet_balance,
                )
                db.add(tx)
        message = f"تم الإلغاء. تم إرجاع المبلغ كاملاً ({res.deposit_amount:,.0f} ريال) كأمانة في محفظة العميل"

    elif cancel_type == CancellationType.cash_return:
        # صرف المبلغ كاش مباشرة
        res.customer_credit_amount = 0.0
        message = f"تم الإلغاء. تم صرف المبلغ ({res.deposit_amount:,.0f} ريال) كاش للعميل مباشرة"

    else:
        res.customer_credit_amount = 0.0
        message = "تم إلغاء الحجز"

    db.commit()
    return {"message": message, "reservation_number": res.reservation_number}


@router.put("/{res_id}/extend")
def extend_reservation(res_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if not res:
        raise HTTPException(status_code=404, detail="Not found")
    if res.status not in [ReservationStatus.pending, ReservationStatus.confirmed]:
        raise HTTPException(status_code=400, detail="لا يمكن تمديد هذا الحجز")
    if res.extension_count >= 1:
        raise HTTPException(status_code=400, detail="تم استخدام التمديد الاستثنائي مرة واحدة بالفعل — لا يسمح بتمديد آخر")

    base = res.expires_at or datetime.utcnow()
    new_expiry = base + timedelta(days=EXTENSION_DAYS)
    res.extended_at = datetime.utcnow()
    res.extended_until = new_expiry
    res.expires_at = new_expiry
    res.extension_count += 1
    res.extension_days += EXTENSION_DAYS
    db.commit()
    return {"message": f"تم تمديد الحجز {EXTENSION_DAYS} أيام استثنائية. ينتهي في {new_expiry.strftime('%Y-%m-%d')}"}


@router.put("/{res_id}/complete")
def complete_reservation(res_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if not res:
        raise HTTPException(status_code=404, detail="Not found")
    res.status = ReservationStatus.completed
    product = db.query(Product).filter(Product.id == res.product_id).first()
    if product:
        product.status = ProductStatus.sold
    db.commit()
    return {"message": "تم استكمال الحجز وبيع المنتج"}


@router.put("/{res_id}/expire")
def expire_reservation(res_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if not res:
        raise HTTPException(status_code=404, detail="Not found")
    res.status = ReservationStatus.expired
    product = db.query(Product).filter(Product.id == res.product_id).first()
    if product:
        product.status = ProductStatus.available
    db.commit()
    return {"message": "تم تسجيل انتهاء مهلة الحجز"}


@router.get("/expired-check")
def check_expired_reservations(db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    """Returns reservations that have passed their expiry date."""
    now = datetime.utcnow()
    expired = db.query(Reservation).filter(
        Reservation.status.in_([ReservationStatus.pending, ReservationStatus.confirmed]),
        Reservation.expires_at < now,
    ).all()
    return [
        {
            "id": r.id,
            "reservation_number": r.reservation_number,
            "customer_name": r.customer_name,
            "customer_phone": r.customer_phone,
            "product_name": r.product_name,
            "expires_at": r.expires_at,
            "extension_count": r.extension_count,
            "can_extend": r.extension_count < 1,
        }
        for r in expired
    ]
