from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from backend.core.database import get_db
from backend.models.user import User, UserRole
from backend.schemas.auth import UserResponse
from backend.api.dependencies import get_admin_user
from backend.core.security import get_password_hash
import random, string

router = APIRouter()


class CustomerCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    password: str


@router.get("/", response_model=List[UserResponse])
def get_customers(
    skip: int = 0,
    limit: int = 200,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    q = db.query(User).filter(User.role == UserRole.customer)
    if search:
        q = q.filter(
            User.name.ilike(f"%{search}%") |
            User.phone.ilike(f"%{search}%") |
            User.email.ilike(f"%{search}%")
        )
    return q.order_by(User.created_at.desc()).offset(skip).limit(limit).all()


@router.post("/{user_id}/verify")
def toggle_verify_customer(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user),
):
    user = db.query(User).filter(
        User.id == user_id, User.role == UserRole.customer
    ).first()
    if not user:
        raise HTTPException(404, "العميل غير موجود")
    user.is_verified = not getattr(user, "is_verified", False)
    db.commit()
    return {"is_verified": user.is_verified}


@router.post("/", response_model=UserResponse)
def add_customer(
    data: CustomerCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    code = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
    user = User(
        name=data.name,
        phone=data.phone or None,
        email=data.email or None,
        hashed_password=get_password_hash(data.password),
        role=UserRole.customer,
        is_active=True,
        referral_code=code,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/toggle-active")
def toggle_customer_active(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    user = db.query(User).filter(User.id == user_id, User.role == UserRole.customer).first()
    if not user:
        raise HTTPException(404, "Customer not found")
    user.is_active = not user.is_active
    db.commit()
    return {"message": "Updated", "is_active": user.is_active}


@router.delete("/{user_id}")
def delete_customer(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    user = db.query(User).filter(User.id == user_id, User.role == UserRole.customer).first()
    if not user:
        raise HTTPException(404, "العميل غير موجود")

    try:
        from sqlalchemy import text

        # Clear self-referential FK: other users referred by this customer
        db.execute(text("UPDATE users SET referred_by_id = NULL WHERE referred_by_id = :uid"), {"uid": user_id})

        # Delete referral records for this user (as referrer or referred)
        db.execute(text("DELETE FROM referrals WHERE referrer_id = :uid OR referred_id = :uid"), {"uid": user_id})

        # Delete notifications owned by this user
        db.execute(text("DELETE FROM notifications WHERE user_id = :uid"), {"uid": user_id})

        # Delete loyalty data
        db.execute(text("DELETE FROM loyalty_transactions WHERE user_id = :uid"), {"uid": user_id})
        db.execute(text("DELETE FROM loyalty_accounts WHERE user_id = :uid"), {"uid": user_id})

        # Null out customer_id in tables that allow NULL (preserve records, just disassociate)
        for tbl, col in [
            ("orders", "customer_id"),
            ("reservations", "customer_id"),
            ("complaints", "customer_id"),
            ("inspection_requests", "customer_id"),
            ("inventory_items", "sold_to_id"),
            ("auction_bids", "bidder_id"),
            ("audit_logs", "user_id"),
            ("wallet_transactions", "user_id"),
            ("warranties", "customer_id"),
            ("shortage_requests", "customer_id"),
        ]:
            try:
                db.execute(text(f"UPDATE {tbl} SET {col} = NULL WHERE {col} = :uid"), {"uid": user_id})
            except Exception:
                db.rollback()

        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"خطأ أثناء الحذف: {str(e)}")

    db.delete(user)
    db.commit()
    return {"message": "تم حذف العميل بنجاح"}
