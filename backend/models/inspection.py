from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, JSON, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class InspectionStatus(str, enum.Enum):
    pending = "pending"
    under_review = "under_review"
    responded = "responded"
    closed = "closed"


class InspectionRequest(Base):
    __tablename__ = "inspection_requests"

    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    customer_name = Column(String(100), nullable=False)
    customer_phone = Column(String(20), nullable=False)
    device_model = Column(String(200), nullable=False)
    problem_description = Column(Text, nullable=False)
    images = Column(JSON, default=list)
    video_url = Column(String(500), nullable=True)

    status = Column(Enum(InspectionStatus), default=InspectionStatus.pending)

    # Staff response
    staff_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    diagnosis = Column(Text, nullable=True)
    estimated_price = Column(String(200), nullable=True)
    response_notes = Column(Text, nullable=True)
    response_images = Column(JSON, default=list)
    responded_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    customer = relationship("User", foreign_keys=[customer_id])
    staff = relationship("User", foreign_keys=[staff_id])
