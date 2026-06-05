from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class LoyaltyTransactionType(str, enum.Enum):
    earn = "earn"
    redeem = "redeem"
    adjust = "adjust"
    deduct = "deduct"


class LoyaltyTransaction(Base):
    __tablename__ = "loyalty_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    points = Column(Integer, nullable=False)
    transaction_type = Column(Enum(LoyaltyTransactionType), nullable=False)
    reason = Column(String(255), nullable=True)
    reference_id = Column(Integer, nullable=True)
    reference_type = Column(String(50), nullable=True)
    balance_after = Column(Integer, default=0)
    is_locked = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    user = relationship("User", foreign_keys=[user_id])
    created_by = relationship("User", foreign_keys=[created_by_id])


class LoyaltyAccount(Base):
    __tablename__ = "loyalty_accounts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False, index=True)
    total_points = Column(Integer, default=0, nullable=False)
    lifetime_points = Column(Integer, default=0, nullable=False)
    is_locked = Column(Boolean, default=False, nullable=False)
    free_screens_earned = Column(Integer, default=0, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", foreign_keys=[user_id])
