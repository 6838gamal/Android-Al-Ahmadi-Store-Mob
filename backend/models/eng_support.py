from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class EngPostStatus(str, enum.Enum):
    open = "open"
    answered = "answered"
    closed = "closed"


class EngSupportPost(Base):
    __tablename__ = "eng_support_posts"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(300), nullable=False)
    content = Column(Text, nullable=False)
    images = Column(JSON, default=list)
    device_type = Column(String(200), nullable=True)
    fault_type = Column(String(200), nullable=True)
    tags = Column(String(500), nullable=True)
    status = Column(Enum(EngPostStatus), default=EngPostStatus.open, index=True)
    is_subscription_required = Column(Boolean, default=False)
    price_per_consult = Column(Float, default=0.0)
    views = Column(Integer, default=0)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    author_name = Column(String(100), nullable=False)
    author_phone = Column(String(20), nullable=True)
    is_paid_post = Column(Boolean, default=False)
    is_pinned = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    author = relationship("User", foreign_keys=[author_id])
    responses = relationship("EngSupportResponse", back_populates="post")


class EngSupportResponse(Base):
    __tablename__ = "eng_support_responses"

    id = Column(Integer, primary_key=True, index=True)
    post_id = Column(Integer, ForeignKey("eng_support_posts.id"), nullable=False, index=True)
    author_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    author_name = Column(String(100), nullable=False)
    content = Column(Text, nullable=False)
    images = Column(JSON, default=list)
    is_accepted = Column(Boolean, default=False)
    is_paid = Column(Boolean, default=False)
    payment_amount = Column(Float, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    post = relationship("EngSupportPost", back_populates="responses")
    author = relationship("User", foreign_keys=[author_id])
