from fastapi import APIRouter, Depends, HTTPException
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


class StaffCreate(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    password: str
    role: str = "staff"


class StaffUpdate(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    role: str = "staff"
    password: Optional[str] = None


STAFF_ROLES = [UserRole.staff, UserRole.branch_manager, UserRole.admin]


@router.get("/", response_model=List[UserResponse])
def list_staff(
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    return db.query(User).filter(
        User.role.in_(STAFF_ROLES)
    ).order_by(User.created_at.desc()).all()


@router.post("/", response_model=UserResponse)
def add_staff(
    data: StaffCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    code = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
    try:
        role = UserRole(data.role)
    except ValueError:
        role = UserRole.staff
    user = User(
        name=data.name,
        phone=data.phone or None,
        email=data.email or None,
        hashed_password=get_password_hash(data.password),
        role=role,
        is_active=True,
        referral_code=code,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.put("/{user_id}", response_model=UserResponse)
def edit_staff(
    user_id: int,
    data: StaffUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.role == UserRole.customer:
        raise HTTPException(404, "Staff not found")
    if user.role == UserRole.admin and admin.id != user_id:
        raise HTTPException(403, "Cannot edit another admin")
    user.name = data.name
    user.phone = data.phone or None
    user.email = data.email or None
    try:
        user.role = UserRole(data.role)
    except ValueError:
        pass
    if data.password:
        user.hashed_password = get_password_hash(data.password)
    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/toggle-active")
def toggle_staff_active(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.role == UserRole.customer:
        raise HTTPException(404, "Staff not found")
    user.is_active = not user.is_active
    db.commit()
    return {"message": "Updated", "is_active": user.is_active}


@router.delete("/{user_id}")
def delete_staff(
    user_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.role == UserRole.admin:
        raise HTTPException(403, "Cannot delete admin")
    db.delete(user)
    db.commit()
    return {"message": "Deleted"}
