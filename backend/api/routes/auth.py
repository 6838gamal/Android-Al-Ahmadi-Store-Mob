import random, string, time, os
from datetime import datetime
from collections import defaultdict
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
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
        existing_email = db.query(User).filter(User.email == user_data.email).first()
        if existing_email:
            # Allow re-registration if the account is unverified (incomplete signup)
            if existing_email.role == UserRole.customer and not existing_email.is_verified:
                db.delete(existing_email)
                db.commit()
            else:
                raise HTTPException(status_code=400, detail="البريد الإلكتروني مسجل مسبقاً")

    if user_data.phone:
        existing_phone = db.query(User).filter(User.phone == user_data.phone).first()
        if existing_phone:
            # Allow re-registration if the account is unverified (incomplete signup)
            if existing_phone.role == UserRole.customer and not existing_phone.is_verified:
                db.delete(existing_phone)
                db.commit()
            else:
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
        is_verified=False,
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


def _delete_user_cascade(user_id: int, db: Session):
    """Delete a user and clear/remove all FK references first to avoid constraint errors."""
    from sqlalchemy import text
    db.execute(text("UPDATE users SET referred_by_id = NULL WHERE referred_by_id = :uid"), {"uid": user_id})
    db.execute(text("DELETE FROM referrals WHERE referrer_id = :uid OR referred_id = :uid"), {"uid": user_id})
    db.execute(text("DELETE FROM notifications WHERE user_id = :uid"), {"uid": user_id})
    db.execute(text("DELETE FROM loyalty_transactions WHERE user_id = :uid"), {"uid": user_id})
    db.execute(text("DELETE FROM loyalty_accounts WHERE user_id = :uid"), {"uid": user_id})
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
    user_obj = db.query(User).filter(User.id == user_id).first()
    if user_obj:
        db.delete(user_obj)
        db.commit()


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

    # Phone/email not registered at all
    if not user:
        raise HTTPException(
            status_code=401,
            detail="رقم الجوال غير مسجّل — اضغط على «إنشاء حساب» في الأسفل للتسجيل",
        )

    # Unverified customer account → delete it so the user can re-register freely
    if user.role == UserRole.customer and not user.is_verified:
        user_id = user.id
        _delete_user_cascade(user_id, db)
        raise HTTPException(
            status_code=401,
            detail="هذا الحساب لم يتم تفعيله — تم حذفه تلقائياً. يمكنك إنشاء حساب جديد بنفس الرقم",
        )

    if not user.is_active:
        raise HTTPException(status_code=403, detail="الحساب معطّل — تواصل مع الدعم")

    if not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="كلمة المرور غير صحيحة")

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


# ── Firebase Phone OTP verification ──────────────────────────────────────────

class PhoneVerifyRequest(BaseModel):
    firebase_id_token: str


@router.post("/verify-phone")
def verify_phone(
    body: PhoneVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Verify a Firebase phone-auth ID token and mark the user's phone as verified.
    Flutter sends the Firebase ID token after successful OTP confirmation.
    We verify it against Firebase REST API then set is_verified=True.
    """
    import httpx as _httpx

    project_id = os.getenv("FIREBASE_PROJECT_ID", "android-al-ahmadi-store")
    url = (
        f"https://identitytoolkit.googleapis.com/v1/accounts:lookup"
        f"?key={os.getenv('FIREBASE_API_KEY', '')}"
    )
    try:
        r = _httpx.post(url, json={"idToken": body.firebase_id_token}, timeout=10)
        data = r.json()
        if r.status_code != 200 or "users" not in data:
            raise HTTPException(status_code=400, detail="رمز Firebase غير صالح")
        firebase_phone = data["users"][0].get("phoneNumber", "")
    except _httpx.RequestError:
        raise HTTPException(status_code=503, detail="تعذر التواصل مع Firebase")

    # Normalise phone: strip leading + and country code prefix for comparison
    def _normalise(p: str) -> str:
        p = p.strip().lstrip("+")
        for prefix in ("967", "00967"):
            if p.startswith(prefix):
                p = p[len(prefix):]
        return p.lstrip("0")

    user_phone = _normalise(current_user.phone or "")
    fb_phone   = _normalise(firebase_phone)

    if not fb_phone or user_phone not in (fb_phone, firebase_phone.lstrip("+")):
        if user_phone != fb_phone:
            raise HTTPException(
                status_code=400,
                detail=f"رقم الهاتف غير مطابق ({firebase_phone})"
            )

    current_user.is_verified = True
    db.commit()
    db.refresh(current_user)
    return {"message": "تم التحقق من رقم الهاتف بنجاح", "is_verified": True}


@router.post("/verify-phone-login")
def verify_phone_login(
    body: PhoneVerifyRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Login via Firebase phone OTP (no password needed).
    Finds user by Firebase-verified phone number and returns app token.
    """
    import httpx as _httpx

    client_ip = _get_client_ip(request)
    _check_rate_limit(f"phone_login:{client_ip}", limit=10, window=60)

    url = (
        f"https://identitytoolkit.googleapis.com/v1/accounts:lookup"
        f"?key={os.getenv('FIREBASE_API_KEY', '')}"
    )
    try:
        r = _httpx.post(url, json={"idToken": body.firebase_id_token}, timeout=10)
        data = r.json()
        if r.status_code != 200 or "users" not in data:
            raise HTTPException(status_code=400, detail="رمز Firebase غير صالح")
        firebase_phone = data["users"][0].get("phoneNumber", "")
    except _httpx.RequestError:
        raise HTTPException(status_code=503, detail="تعذر التواصل مع Firebase")

    if not firebase_phone:
        raise HTTPException(status_code=400, detail="رقم الهاتف غير موجود في Firebase")

    # Try to find user by phone (various formats)
    def _variants(phone: str):
        phone = phone.strip()
        variants = {phone}
        p = phone.lstrip("+")
        variants.add(p)
        for prefix in ("967", "00967"):
            if p.startswith(prefix):
                local = p[len(prefix):]
                variants.add(local)
                variants.add("0" + local)
        return variants

    user = None
    for variant in _variants(firebase_phone):
        user = db.query(User).filter(User.phone == variant).first()
        if user:
            break

    if not user:
        raise HTTPException(
            status_code=404,
            detail="لا يوجد حساب مرتبط بهذا الرقم. يرجى التسجيل أولاً."
        )

    if not user.is_active:
        raise HTTPException(status_code=403, detail="الحساب معطّل")

    # Mark as verified automatically
    if not user.is_verified:
        user.is_verified = True
        db.commit()
        db.refresh(user)

    return _build_token_response(user)


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
