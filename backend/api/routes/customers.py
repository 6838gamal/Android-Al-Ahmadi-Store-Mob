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
        raise HTTPException(404, "Customer not found")
    db.delete(user)
    db.commit()
    return {"message": "Deleted"}
