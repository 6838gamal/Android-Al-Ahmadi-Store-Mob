import random, string, time, os
from datetime import datetime
from collections import defaultdict
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from backend.core.database import get_db
from backend.core.security import (
    verify_password, get_password_hash,
    create_access_token, create_refresh_token, decode_refresh_token,
)
from backend.models.user import User, UserRole
from backend.schemas.auth import (
    UserCreate, UserLogin, UserResponse, TokenResponse,
    PasswordReset, ProfileUpdate, RefreshTokenRequest,
)
from backend.api.dependencies import get_current_user

router = APIRouter()

STAFF_ROLES = [UserRole.staff, UserRole.branch_manager, UserRole.admin]

_rate_store: dict = defaultdict(list)


def _get_client_ip(request: Request) -> str:
    for header in ("x-real-ip", "x-forwarded-for", "cf-connecting-ip"):
        val = request.headers.get(header)
        if val:
            return val.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _check_rate_limit(key: str, limit: int = 10, window: int = 60):
    now = time.time()
    _rate_store[key] = [t for t in _rate_store[key] if now - t < window]
    if len(_rate_store[key]) >= limit:
        raise HTTPException(
            status_code=429,
            detail="محاولات كثيرة. يرجى الانتظار دقيقة ثم المحاولة مجدداً."
        )
    _rate_store[key].append(now)


def _gen_referral_code(db: Session) -> str:
    while True:
        code = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
        if not db.query(User).filter(User.referral_code == code).first():
            return code


def _build_token_response(user: User) -> TokenResponse:
    payload = {"sub": str(user.id), "role": user.role.value}
    return TokenResponse(
        access_token=create_access_token(payload),
        refresh_token=create_refresh_token(payload),
        user=UserResponse.from_orm(user),
    )


@router.post("/register", response_model=TokenResponse)
def register(user_data: UserCreate, request: Request, db: Session = Depends(get_db)):
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"register:{client_ip}", limit=5, window=60)

    if not user_data.email and not user_data.phone:
        raise HTTPException(status_code=400, detail="البريد الإلكتروني أو رقم الهاتف مطلوب")

    if user_data.email:
        if db.query(User).filter(User.email == user_data.email).first():
            raise HTTPException(status_code=400, detail="البريد الإلكتروني مسجل مسبقاً")

    if user_data.phone:
        if db.query(User).filter(User.phone == user_data.phone).first():
            raise HTTPException(status_code=400, detail="رقم الهاتف مسجل مسبقاً")

    referred_by_id = None
    if user_data.referral_code:
        referrer = db.query(User).filter(
            User.referral_code == user_data.referral_code.upper()
        ).first()
        if referrer:
            referred_by_id = referrer.id

    user = User(
        name=user_data.name,
        email=user_data.email,
        phone=user_data.phone,
        hashed_password=get_password_hash(user_data.password),
        role=UserRole.customer,
        referral_code=_gen_referral_code(db),
        referred_by_id=referred_by_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    if referred_by_id:
        from backend.models.referral import Referral
        ref_record = Referral(
            referrer_id=referred_by_id,
            referred_id=user.id,
            is_verified=True,
        )
        db.add(ref_record)
        db.commit()

    return _build_token_response(user)


@router.post("/login", response_model=TokenResponse)
def login(login_data: UserLogin, request: Request, db: Session = Depends(get_db)):
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"login:{client_ip}", limit=10, window=60)

    identifier = login_data.identifier.strip()
    user = None

    if "@" in identifier:
        user = db.query(User).filter(User.email == identifier).first()
    else:
        user = db.query(User).filter(User.phone == identifier).first()

    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="بيانات الدخول غير صحيحة")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="الحساب معطّل")

    return _build_token_response(user)


@router.post("/staff-login", response_model=TokenResponse)
def staff_login(login_data: UserLogin, request: Request, db: Session = Depends(get_db)):
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"staff_login:{client_ip}", limit=10, window=60)

    identifier = login_data.identifier.strip()
    user = None

    if "@" in identifier:
        user = db.query(User).filter(User.email == identifier, User.role.in_(STAFF_ROLES)).first()
    else:
        user = db.query(User).filter(User.phone == identifier, User.role.in_(STAFF_ROLES)).first()

    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="بيانات الدخول غير صحيحة")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="الحساب معطّل")

    return _build_token_response(user)


@router.post("/admin-login", response_model=TokenResponse)
def admin_login(login_data: UserLogin, request: Request, db: Session = Depends(get_db)):
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"admin_login:{client_ip}", limit=30, window=60)

    identifier = login_data.identifier.strip()
    user = None

    if "@" in identifier:
        user = db.query(User).filter(User.email == identifier, User.role == UserRole.admin).first()
    else:
        user = db.query(User).filter(User.phone == identifier, User.role == UserRole.admin).first()

    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="بيانات الدخول غير صحيحة")

    return _build_token_response(user)


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(data: RefreshTokenRequest, db: Session = Depends(get_db)):
    """Exchange a valid refresh token for a new access + refresh token pair."""
    payload = decode_refresh_token(data.refresh_token)
    if not payload:
        raise HTTPException(status_code=401, detail="Refresh token غير صالح أو منتهي الصلاحية")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Token غير صالح")

    user = db.query(User).filter(User.id == int(user_id), User.is_active == True).first()
    if not user:
        raise HTTPException(status_code=401, detail="المستخدم غير موجود أو الحساب معطّل")

    return _build_token_response(user)


@router.post("/logout")
def logout(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Invalidate all existing tokens for this user."""
    current_user.tokens_invalidated_at = datetime.utcnow()
    db.commit()
    return {"message": "تم تسجيل الخروج بنجاح"}


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/profile", response_model=UserResponse)
def update_profile(
    update_data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if update_data.new_password:
        if not update_data.current_password:
            raise HTTPException(status_code=400, detail="كلمة المرور الحالية مطلوبة لتغيير كلمة المرور")
        if not verify_password(update_data.current_password, current_user.hashed_password):
            raise HTTPException(status_code=400, detail="كلمة المرور الحالية غير صحيحة")
        current_user.hashed_password = get_password_hash(update_data.new_password)
        # Invalidate all existing tokens after password change
        current_user.tokens_invalidated_at = datetime.utcnow()

    if update_data.name is not None and update_data.name.strip():
        current_user.name = update_data.name.strip()

    if update_data.email is not None:
        new_email = update_data.email.strip() or None
        if new_email and new_email != current_user.email:
            existing = db.query(User).filter(User.email == new_email, User.id != current_user.id).first()
            if existing:
                raise HTTPException(status_code=400, detail="البريد الإلكتروني مستخدم بالفعل")
        current_user.email = new_email

    if update_data.phone is not None:
        new_phone = update_data.phone.strip() or None
        if new_phone and new_phone != current_user.phone:
            existing = db.query(User).filter(User.phone == new_phone, User.id != current_user.id).first()
            if existing:
                raise HTTPException(status_code=400, detail="رقم الجوال مستخدم بالفعل")
        current_user.phone = new_phone

    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/seed-admin")
def seed_admin(db: Session = Depends(get_db)):
    env = os.getenv("ENVIRONMENT", "development").lower()
    if env == "production":
        raise HTTPException(status_code=404, detail="Not found")

    existing = db.query(User).filter(User.role == UserRole.admin).first()
    if existing:
        return {"message": "Admin already exists", "email": existing.email}
    admin = User(
        name="مدير اندرويد الاحمدي",
        email="admin@alahmadi.com",
        phone="0501234567",
        hashed_password=get_password_hash("Admin@2026"),
        role=UserRole.admin,
        referral_code=_gen_referral_code(db),
    )
    db.add(admin)
    db.commit()
    return {"message": "Admin created", "email": "admin@alahmadi.com", "password": "Admin@2026"}
