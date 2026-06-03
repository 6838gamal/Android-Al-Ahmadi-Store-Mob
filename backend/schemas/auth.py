import re
from pydantic import BaseModel, field_validator
from typing import Optional
from backend.models.user import UserRole


PHONE_RE = re.compile(r"^(\+967|00967|967)?[0-9]{9,10}$")


class UserCreate(BaseModel):
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    password: str
    role: Optional[str] = "customer"
    referral_code: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        cleaned = v.strip().replace(" ", "").replace("-", "")
        if not PHONE_RE.match(cleaned):
            raise ValueError("رقم الهاتف غير صحيح — يجب أن يكون رقماً يمنياً صحيحاً")
        return cleaned

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("كلمة المرور يجب أن تكون 6 أحرف على الأقل")
        return v


class UserLogin(BaseModel):
    identifier: str
    password: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


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
    is_verified: bool = False

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse


class PasswordReset(BaseModel):
    identifier: str
    new_password: str


class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    current_password: Optional[str] = None
    new_password: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return v
        cleaned = v.strip().replace(" ", "").replace("-", "")
        if not PHONE_RE.match(cleaned):
            raise ValueError("رقم الهاتف غير صحيح")
        return cleaned
