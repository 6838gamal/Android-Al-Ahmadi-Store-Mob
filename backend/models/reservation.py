from sqlalchemy import Column, Integer, String, DateTime, Enum, Text, ForeignKey, Float, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class ReservationStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    cancelled = "cancelled"
    completed = "completed"
    expired = "expired"


class CancellationType(str, enum.Enum):
    with_penalty = "with_penalty"
    full_return = "full_return"
    cash_return = "cash_return"


class Reservation(Base):
    __tablename__ = "reservations"

    id = Column(Integer, primary_key=True, index=True)
    reservation_number = Column(String(20), unique=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    customer_name = Column(String(100), nullable=False)
    customer_phone = Column(String(20), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    product_name = Column(String(200), nullable=False)
    price = Column(Float, nullable=False)
    status = Column(Enum(ReservationStatus), default=ReservationStatus.pending)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    notes = Column(Text, nullable=True)

    # Deposit / Payment fields
    deposit_amount = Column(Float, default=0.0, nullable=False)
    deposit_paid = Column(Boolean, default=False, nullable=False)
    remaining_amount = Column(Float, default=0.0, nullable=False)

    # Penalty / Cancellation fields
    penalty_amount = Column(Float, default=2000.0, nullable=False)
    cancellation_type = Column(Enum(CancellationType), nullable=True)
    customer_credit_amount = Column(Float, default=0.0)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
    cancel_reason = Column(Text, nullable=True)

    # Extension fields
    extended_at = Column(DateTime(timezone=True), nullable=True)
    extended_until = Column(DateTime(timezone=True), nullable=True)
    extension_days = Column(Integer, default=0)
    extension_count = Column(Integer, default=0)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    product = relationship("Product")
    customer = relationship("User", foreign_keys=[customer_id])
