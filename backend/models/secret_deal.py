from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class SecretDealStatus(str, enum.Enum):
    draft = "draft"
    active = "active"
    negotiating = "negotiating"
    closed = "closed"


class SecretDeal(Base):
    __tablename__ = "secret_deals"

    id = Column(Integer, primary_key=True, index=True)
    deal_number = Column(String(30), unique=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    supplier_name = Column(String(100), nullable=True)
    supplier_phone = Column(String(20), nullable=True)
    total_quantity = Column(Integer, default=0)
    price_per_unit = Column(Float, nullable=True)
    total_price = Column(Float, nullable=True)
    status = Column(Enum(SecretDealStatus), default=SecretDealStatus.draft, index=True)
    images = Column(JSON, default=list)
    admin_notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    created_by = relationship("User", foreign_keys=[created_by_id])


class SecretDealImage(Base):
    __tablename__ = "secret_deal_images"

    id = Column(Integer, primary_key=True, index=True)
    deal_id = Column(Integer, ForeignKey("secret_deals.id"), nullable=False, index=True)
    image_url = Column(String(500), nullable=False)
    watermark_number = Column(String(20), nullable=True)
    display_order = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    deal = relationship("SecretDeal", foreign_keys=[deal_id])
