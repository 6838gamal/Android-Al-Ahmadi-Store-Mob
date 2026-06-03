from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum, Float, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class UserRole(str, enum.Enum):
    customer = "customer"
    staff = "staff"
    branch_manager = "branch_manager"
    admin = "admin"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=True)
    phone = Column(String(20), unique=True, index=True, nullable=True)
    hashed_password = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.customer)
    avatar_url = Column(String(500), nullable=True)
    is_active = Column(Boolean, default=True)
    fcm_token = Column(String(500), nullable=True)

    # Branch linkage
    branch_id = Column(Integer, ForeignKey("branches.id"), nullable=True)

    # Referral — unique so no two users share the same code
    referral_code = Column(String(20), unique=True, nullable=True, index=True)
    referred_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    # Referral levels — level 1 locks after reaching 50 verified referrals
    referral_level = Column(Integer, default=1, nullable=False)
    level1_locked = Column(Boolean, default=False, nullable=False)

    # Wallet
    wallet_balance = Column(Float, default=0.0)
    wallet_currency = Column(String(3), default="YER")

    # Account verification badge (set manually by admin)
    is_verified = Column(Boolean, default=False, nullable=False)

    # Token revocation — tokens issued before this timestamp are invalid
    tokens_invalidated_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    branch = relationship("Branch", foreign_keys=[branch_id])
    referred_by = relationship("User", foreign_keys=[referred_by_id], remote_side="User.id")
