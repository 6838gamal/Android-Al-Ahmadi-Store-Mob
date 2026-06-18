import random, string, time, os, secrets
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
from backend.models.otp_code import OtpCode
from backend.schemas.auth import (
    UserCreate, UserLogin, UserResponse, TokenResponse,
    PasswordReset, ProfileUpdate, RefreshTokenRequest,
)
from backend.api.dependencies import get_current_user

router = APIRouter()

STAFF_ROLES = [UserRole.staff, UserRole.branch_manager, UserRole.admin]

_rate_store: dict = defaultdict(list)

OTP_COOLDOWN_SECONDS = 60  # منع إعادة الإرسال لنفس الرقم قبل مرور هذه المدة


def _db_otp_get(db: Session, phone: str) -> OtpCode | None:
    return db.query(OtpCode).filter(OtpCode.phone == phone).first()


def _db_otp_set(db: Session, phone: str, code: str):
    now = time.time()
    row = db.query(OtpCode).filter(OtpCode.phone == phone).first()
    if row:
        row.code = code
        row.expires = now + 600
        row.sent_at = now
    else:
        row = OtpCode(phone=phone, code=code, expires=now + 600, sent_at=now)
        db.add(row)
    db.commit()


def _db_otp_delete(db: Session, phone: str):
    db.query(OtpCode).filter(OtpCode.phone == phone).delete()
    db.commit()


def _gen_otp() -> str:
    return f"{secrets.randbelow(1000000):06d}"


def _normalise_phone(p: str) -> list[str]:
    """Return all plausible local/international variants of a phone string."""
    p = p.strip().lstrip("+")
    variants = [p]
    for prefix in ("967", "00967"):
        if p.startswith(prefix):
            local = p[len(prefix):]
            variants += [local, "0" + local]
    if not p.startswith("0") and len(p) == 9:
        variants += ["0" + p, "967" + p, "+967" + p]
    return list(dict.fromkeys(variants))


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
        existing_email = db.query(User).filter(
            User.email == user_data.email,
            User.role == UserRole.customer,
        ).first()
        if existing_email:
            if not existing_email.is_verified:
                db.delete(existing_email)
                db.commit()
            else:
                raise HTTPException(status_code=400, detail="البريد الإلكتروني مسجل مسبقاً كعميل")

    if user_data.phone:
        existing_phone = db.query(User).filter(
            User.phone == user_data.phone,
            User.role == UserRole.customer,
        ).first()
        if existing_phone:
            if not existing_phone.is_verified:
                db.delete(existing_phone)
                db.commit()
            else:
                raise HTTPException(status_code=400, detail="رقم الهاتف مسجل مسبقاً كعميل")

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
    """
    تسجيل دخول العملاء فقط.
    الموظف الذي يريد التسجيل كعميل بنفس رقمه يمكنه ذلك من خلال إنشاء حساب عميل منفصل.
    """
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"login:{client_ip}", limit=10, window=60)

    identifier = login_data.identifier.strip()
    user = None

    if "@" in identifier:
        user = db.query(User).filter(
            User.email == identifier,
            User.role == UserRole.customer,
        ).first()
    else:
        user = db.query(User).filter(
            User.phone == identifier,
            User.role == UserRole.customer,
        ).first()

    # Phone/email not found as customer — check if it belongs to a staff account
    if not user:
        if "@" in identifier:
            staff_exists = db.query(User).filter(
                User.email == identifier,
                User.role.in_(STAFF_ROLES),
            ).first()
        else:
            staff_exists = db.query(User).filter(
                User.phone == identifier,
                User.role.in_(STAFF_ROLES),
            ).first()

        if staff_exists:
            raise HTTPException(
                status_code=401,
                detail="لا يوجد عميل مسجّل بهذا الرقم",
            )
        raise HTTPException(
            status_code=401,
            detail="رقم الجوال غير مسجّل — اضغط على «إنشاء حساب» في الأسفل للتسجيل",
        )

    # Unverified customer account → delete it so the user can re-register freely
    if not user.is_verified:
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


# ── Simple backend OTP ────────────────────────────────────────────────────────

class OtpSendRequest(BaseModel):
    phone: str
    resend: bool = False   # True → تجاوز الـ cooldown وأنشئ كوداً جديداً دائماً

class OtpVerifyRequest(BaseModel):
    phone: str
    code: str


def _get_sms_config(db: Session) -> tuple[str | None, str]:
    """Return (api_key, devices). Env var takes priority over DB setting."""
    from backend.models.app_setting import AppSetting
    api_key = os.getenv("SMS_API_KEY") or ""
    devices = os.getenv("SMS_DEVICES", "0")
    if not api_key:
        row = db.query(AppSetting).filter(AppSetting.key == "sms_api_key").first()
        if row and row.value:
            api_key = row.value
    if devices == "0":
        row = db.query(AppSetting).filter(AppSetting.key == "sms_devices").first()
        if row and row.value:
            devices = row.value
    return api_key or None, devices


def _send_sms(phone: str, message: str, api_key: str, devices: str = "") -> bool:
    """Send SMS via sms-gateway.app. Returns True on success."""
    import httpx
    payload = {
        "number": phone,
        "message": message,
        "key": api_key,
        "type": "sms",
    }
    # أضف devices فقط لو كان معرّف جهاز حقيقي (ليس "0" أو فارغ)
    # إذا كان هناك أكثر من جهاز (مفصولة بفاصلة) نأخذ الأول فقط لمنع إرسال رسائل متعددة
    # devices="0" يعني "أرسل من كل الأجهزة" → يسبب رسائل متعددة من أرقام مختلفة
    if devices and devices.strip() not in ("", "0"):
        first_device = devices.strip().split(",")[0].strip()
        if first_device:
            payload["devices"] = first_device
    try:
        resp = httpx.post(
            "https://app.sms-gateway.app/services/send.php",
            data=payload,
            timeout=15,
        )
        print(f"[SMS] {phone} → status={resp.status_code} body={resp.text[:200]}", flush=True)
        return resp.status_code == 200
    except Exception as e:
        print(f"[SMS] Error sending to {phone}: {e}", flush=True)
        return False


@router.post("/send-otp")
def send_otp(body: OtpSendRequest, request: Request, db: Session = Depends(get_db)):
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"send_otp:{client_ip}", limit=5, window=60)

    phone = body.phone.strip()
    if not phone:
        raise HTTPException(status_code=400, detail="رقم الجوال مطلوب")

    # ── منع الإرسال المتكرر — يُراجع قاعدة البيانات ──────────────────────────
    if not body.resend:
        existing = _db_otp_get(db, phone)
        if existing:
            elapsed = time.time() - existing.sent_at
            remaining = int(OTP_COOLDOWN_SECONDS - elapsed)
            if remaining > 0:
                raise HTTPException(
                    status_code=429,
                    detail=f"الرجاء الانتظار {remaining} ثانية قبل إعادة الإرسال",
                )

    # إنشاء كود جديد (يُحدّث أو يُنشئ السجل في DB)
    code = _gen_otp()
    _db_otp_set(db, phone, code)

    api_key, devices = _get_sms_config(db)
    if api_key:
        message = f"رمز التحقق الخاص بك في أندرويد الأحمدي هو: {code}\nصالح لمدة 10 دقائق"
        sent = _send_sms(phone, message, api_key, devices)
        if not sent:
            print(f"[OTP] SMS failed — code for {phone}: {code}", flush=True)
        return {"message": "تم إرسال رمز التحقق"}
    else:
        # Dev mode — no SMS key configured, print and return code in response
        print(f"[OTP-DEV] {phone} → {code}", flush=True)
        return {"message": "تم إرسال رمز التحقق", "dev_code": code}


@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(body: OtpVerifyRequest, request: Request, db: Session = Depends(get_db)):
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"verify_otp:{client_ip}", limit=10, window=60)

    phone = body.phone.strip()
    code = body.code.strip()

    entry = _db_otp_get(db, phone)
    if not entry:
        raise HTTPException(status_code=400, detail="لم يتم إرسال رمز لهذا الرقم — اطلب رمزاً جديداً")
    if time.time() > entry.expires:
        _db_otp_delete(db, phone)
        raise HTTPException(status_code=400, detail="انتهت صلاحية الرمز — اطلب رمزاً جديداً")
    if entry.code != code:
        raise HTTPException(status_code=400, detail="الرمز غير صحيح")

    _db_otp_delete(db, phone)

    # Find user by any phone variant
    user = None
    for variant in _normalise_phone(phone):
        user = db.query(User).filter(User.phone == variant).first()
        if user:
            break

    if not user:
        raise HTTPException(status_code=404, detail="لا يوجد حساب مرتبط بهذا الرقم")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="الحساب معطّل")

    user.is_verified = True
    db.commit()
    db.refresh(user)
    return _build_token_response(user)


# ── Forgot Password — reset via OTP ───────────────────────────────────────────

class ResetPasswordRequest(BaseModel):
    phone: str
    code: str
    new_password: str


@router.post("/reset-password")
def reset_password(body: ResetPasswordRequest, request: Request, db: Session = Depends(get_db)):
    """
    الخطوة 3 من تدفق "نسيت كلمة المرور":
    - يتحقق من رمز OTP
    - يجد المستخدم بالرقم
    - يغيّر كلمة المرور ويلغي جميع الجلسات السابقة
    - يُعيد {message, is_staff} لتحديد صفحة الدخول المناسبة
    """
    client_ip = _get_client_ip(request)
    _check_rate_limit(f"reset_password:{client_ip}", limit=5, window=60)

    phone = body.phone.strip()
    code = body.code.strip()

    if len(body.new_password) < 6:
        raise HTTPException(status_code=400, detail="كلمة المرور يجب أن تكون 6 أحرف على الأقل")

    # التحقق من رمز OTP
    entry = _db_otp_get(db, phone)
    if not entry:
        raise HTTPException(status_code=400, detail="لم يتم إرسال رمز لهذا الرقم — اطلب رمزاً جديداً")
    if time.time() > entry.expires:
        _db_otp_delete(db, phone)
        raise HTTPException(status_code=400, detail="انتهت صلاحية الرمز — اطلب رمزاً جديداً")
    if entry.code != code:
        raise HTTPException(status_code=400, detail="الرمز غير صحيح")

    _db_otp_delete(db, phone)

    # البحث عن المستخدم بمختلف صيغ الرقم
    user = None
    for variant in _normalise_phone(phone):
        user = db.query(User).filter(User.phone == variant).first()
        if user:
            break

    if not user:
        raise HTTPException(status_code=404, detail="لا يوجد حساب مرتبط بهذا الرقم")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="الحساب معطّل — تواصل مع الإدارة")

    # تحديث كلمة المرور وإلغاء جميع الجلسات السابقة
    user.hashed_password = get_password_hash(body.new_password)
    user.tokens_invalidated_at = datetime.utcnow()
    db.commit()

    is_staff = user.role in STAFF_ROLES
    return {"message": "تم تغيير كلمة المرور بنجاح", "is_staff": is_staff}


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
