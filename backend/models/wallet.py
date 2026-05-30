from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class TransactionType(str, enum.Enum):
    credit = "credit"
    debit = "debit"


class WalletCurrency(str, enum.Enum):
    YER = "YER"
    SAR = "SAR"
    USD = "USD"


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount = Column(Float, nullable=False)
    currency = Column(Enum(WalletCurrency), default=WalletCurrency.YER)
    transaction_type = Column(Enum(TransactionType), nullable=False)
    reason = Column(String(255), nullable=True)
    reference_id = Column(String(100), nullable=True)
    reference_type = Column(String(50), nullable=True)
    balance_after = Column(Float, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", foreign_keys=[user_id])
