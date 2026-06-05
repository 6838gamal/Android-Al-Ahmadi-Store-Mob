from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum, Text, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class ComplaintStatus(str, enum.Enum):
    pending = "pending"
    reviewed = "reviewed"
    resolved = "resolved"
    archived = "archived"


class ComplaintType(str, enum.Enum):
    complaint = "complaint"
    suggestion = "suggestion"
    report = "report"


class Complaint(Base):
    __tablename__ = "complaints"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    customer_name = Column(String(100), nullable=False)
    customer_phone = Column(String(20), nullable=True)
    subject = Column(String(300), nullable=False)
    content = Column(Text, nullable=False)
    complaint_type = Column(Enum(ComplaintType), default=ComplaintType.complaint)
    status = Column(Enum(ComplaintStatus), default=ComplaintStatus.pending, index=True)
    is_read = Column(Boolean, default=False)
    admin_reply = Column(Text, nullable=True)
    replied_at = Column(DateTime(timezone=True), nullable=True)
    replied_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    customer = relationship("User", foreign_keys=[customer_id])
    replied_by = relationship("User", foreign_keys=[replied_by_id])
