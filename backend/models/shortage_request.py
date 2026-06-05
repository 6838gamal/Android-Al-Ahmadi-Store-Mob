from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum, Text, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class ShortageRequestStatus(str, enum.Enum):
    pending = "pending"
    notified = "notified"
    purchased = "purchased"
    closed = "closed"


class ShortageRequest(Base):
    __tablename__ = "shortage_requests"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    customer_name = Column(String(100), nullable=False)
    customer_phone = Column(String(20), nullable=False)
    brand = Column(String(100), nullable=False)
    model = Column(String(100), nullable=False)
    series = Column(String(100), nullable=True)
    category = Column(String(50), nullable=True)
    notes = Column(Text, nullable=True)
    status = Column(Enum(ShortageRequestStatus), default=ShortageRequestStatus.pending, index=True)
    notified_at = Column(DateTime(timezone=True), nullable=True)
    notified_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    notification_message = Column(Text, nullable=True)
    purchased_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    customer = relationship("User", foreign_keys=[customer_id])
    notified_by = relationship("User", foreign_keys=[notified_by_id])
