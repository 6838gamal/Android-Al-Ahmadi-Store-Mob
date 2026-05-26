from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from backend.core.database import get_db
from backend.models.user import User, UserRole
from backend.schemas.auth import UserResponse
from backend.api.dependencies import get_admin_user

router = APIRouter()


@router.get("/", response_model=List[UserResponse])
def get_customers(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    return db.query(User).filter(User.role == UserRole.customer).offset(skip).limit(limit).all()
