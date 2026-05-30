from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class ItemGrade(str, enum.Enum):
    a_plus = "A+"
    a = "A"
    b = "B"
    c = "C"


class ItemStatus(str, enum.Enum):
    available = "available"
    reserved = "reserved"
    sold = "sold"


class InventoryItem(Base):
    __tablename__ = "inventory_items"

    id = Column(Integer, primary_key=True, index=True)
    serial_number = Column(String(100), unique=True, index=True, nullable=True)
    category = Column(String(50), nullable=False)
    brand = Column(String(100), nullable=True)
    model = Column(String(100), nullable=True)
    grade = Column(Enum(ItemGrade), default=ItemGrade.a)
    status = Column(Enum(ItemStatus), default=ItemStatus.available)
    price = Column(Float, nullable=False)
    images = Column(JSON, default=list)
    notes = Column(Text, nullable=True)

    product_id = Column(Integer, ForeignKey("products.id"), nullable=True)
    branch_id = Column(Integer, ForeignKey("branches.id"), nullable=True)
    warehouse_id = Column(Integer, ForeignKey("warehouses.id"), nullable=True)
    sold_to_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    sold_order_id = Column(Integer, ForeignKey("orders.id"), nullable=True)

    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    product = relationship("Product", foreign_keys=[product_id])
    branch = relationship("Branch", foreign_keys=[branch_id])
    warehouse = relationship("Warehouse", foreign_keys=[warehouse_id])
    sold_to = relationship("User", foreign_keys=[sold_to_id])
