from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base


class Warranty(Base):
    __tablename__ = "warranties"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=True)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    product_name = Column(String(200), nullable=False)
    product_serial = Column(String(100), nullable=True)
    purchase_price = Column(Float, nullable=True)
    warranty_days = Column(Integer, default=7)
    starts_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    ends_at = Column(DateTime(timezone=True), nullable=False)

    is_return_requested = Column(Boolean, default=False)
    return_reason = Column(Text, nullable=True)
    return_requested_at = Column(DateTime(timezone=True), nullable=True)
    return_resolved = Column(Boolean, default=False)
    return_notes = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    order = relationship("Order", foreign_keys=[order_id])
    customer = relationship("User", foreign_keys=[customer_id])
