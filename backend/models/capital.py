from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class CapitalTransactionType(str, enum.Enum):
    deposit = "deposit"
    withdrawal = "withdrawal"


class CapitalTransaction(Base):
    """رأس المال: إيداعات وسحوبات المالك — لا تُحسب كأرباح."""
    __tablename__ = "capital_transactions"

    id = Column(Integer, primary_key=True, index=True)
    transaction_type = Column(Enum(CapitalTransactionType), nullable=False, index=True)
    amount = Column(Float, nullable=False)
    reason = Column(String(500), nullable=True)
    notes = Column(Text, nullable=True)
    reference_number = Column(String(100), nullable=True)
    recorded_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    recorded_by = relationship("User", foreign_keys=[recorded_by_id])
