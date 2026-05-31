from pydantic import BaseModel, EmailStr
from typing import Optional
from backend.models.user import UserRole


class UserCreate(BaseModel):
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    password: str
    role: Optional[str] = "customer"


class UserLogin(BaseModel):
    identifier: str  # email or phone
    password: str


class UserResponse(BaseModel):
    id: int
    name: str
    email: Optional[str]
    phone: Optional[str]
    role: UserRole
    avatar_url: Optional[str]
    is_active: bool
    branch_id: Optional[int] = None
    referral_code: Optional[str] = None
    wallet_balance: Optional[float] = 0.0
    wallet_currency: Optional[str] = "YER"

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class PasswordReset(BaseModel):
    identifier: str
    new_password: str
