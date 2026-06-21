from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Text, ForeignKey, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base


class DailyExpense(Base):
    """مصروفات يومية تُخصم من الصندوق."""
    __tablename__ = "daily_expenses"

    id = Column(Integer, primary_key=True, index=True)
    description = Column(String(500), nullable=False)
    amount = Column(Float, nullable=False)
    category = Column(String(100), nullable=True)
    expense_date = Column(Date, nullable=False, index=True)
    recorded_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    recorded_by = relationship("User", foreign_keys=[recorded_by_id])


class DailyAward(Base):
    """جوائز يومية تُصرف من الصندوق."""
    __tablename__ = "daily_awards"

    id = Column(Integer, primary_key=True, index=True)
    recipient_name = Column(String(200), nullable=False)
    recipient_phone = Column(String(20), nullable=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    amount = Column(Float, nullable=False)
    reason = Column(String(500), nullable=True)
    award_date = Column(Date, nullable=False, index=True)
    recorded_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    customer = relationship("User", foreign_keys=[customer_id])
    recorded_by = relationship("User", foreign_keys=[recorded_by_id])


class DailyClose(Base):
    """إغلاق الصندوق اليومي — ملخص كامل للحركات."""
    __tablename__ = "daily_closes"

    id = Column(Integer, primary_key=True, index=True)
    close_date = Column(Date, nullable=False, unique=True, index=True)

    opening_balance = Column(Float, default=0.0, nullable=False)
    total_sales = Column(Float, default=0.0, nullable=False)
    total_maintenance = Column(Float, default=0.0, nullable=False)
    total_returns = Column(Float, default=0.0, nullable=False)
    total_deposits = Column(Float, default=0.0, nullable=False)
    total_expenses = Column(Float, default=0.0, nullable=False)
    total_awards = Column(Float, default=0.0, nullable=False)
    total_commissions = Column(Float, default=0.0, nullable=False)
    total_purchases = Column(Float, default=0.0, nullable=False)
    capital_deposited = Column(Float, default=0.0, nullable=False)
    owner_withdrawals = Column(Float, default=0.0, nullable=False)

    closing_balance = Column(Float, default=0.0, nullable=False)
    net_profit = Column(Float, default=0.0, nullable=False)

    notes = Column(Text, nullable=True)
    is_finalized = Column(Boolean, default=False, nullable=False)
    finalized_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    finalized_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    finalized_by = relationship("User", foreign_keys=[finalized_by_id])
