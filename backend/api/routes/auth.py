from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from backend.core.database import get_db
from backend.core.security import verify_password, get_password_hash, create_access_token
from backend.models.user import User, UserRole
from backend.schemas.auth import UserCreate, UserLogin, UserResponse, TokenResponse, PasswordReset
from backend.api.dependencies import get_current_user

router = APIRouter()


@router.post("/register", response_model=TokenResponse)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    if not user_data.email and not user_data.phone:
        raise HTTPException(status_code=400, detail="Email or phone required")

    if user_data.email:
        existing = db.query(User).filter(User.email == user_data.email).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered")

    if user_data.phone:
        existing = db.query(User).filter(User.phone == user_data.phone).first()
        if existing:
            raise HTTPException(status_code=400, detail="Phone already registered")

    user = User(
        name=user_data.name,
        email=user_data.email,
        phone=user_data.phone,
        hashed_password=get_password_hash(user_data.password),
        role=UserRole.customer,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return TokenResponse(access_token=token, user=UserResponse.from_orm(user))


@router.post("/login", response_model=TokenResponse)
def login(login_data: UserLogin, db: Session = Depends(get_db)):
    identifier = login_data.identifier.strip()
    user = None

    if "@" in identifier:
        user = db.query(User).filter(User.email == identifier).first()
    else:
        user = db.query(User).filter(User.phone == identifier).first()

    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account disabled")

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return TokenResponse(access_token=token, user=UserResponse.from_orm(user))


@router.post("/admin-login", response_model=TokenResponse)
def admin_login(login_data: UserLogin, db: Session = Depends(get_db)):
    identifier = login_data.identifier.strip()
    user = None

    if "@" in identifier:
        user = db.query(User).filter(User.email == identifier, User.role == UserRole.admin).first()
    else:
        user = db.query(User).filter(User.phone == identifier, User.role == UserRole.admin).first()

    if not user or not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="بيانات الدخول غير صحيحة")

    token = create_access_token({"sub": str(user.id), "role": user.role.value})
    return TokenResponse(access_token=token, user=UserResponse.from_orm(user))


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.get("/seed-admin")
def seed_admin(db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.role == UserRole.admin).first()
    if existing:
        return {"message": "Admin already exists", "email": existing.email}
    admin = User(
        name="مدير اندرويد الاحمدي",
        email="admin@alahmadi.com",
        phone="0501234567",
        hashed_password=get_password_hash("Admin@2026"),
        role=UserRole.admin,
    )
    db.add(admin)
    db.commit()
    return {"message": "Admin created", "email": "admin@alahmadi.com", "password": "Admin@2026"}
