from sqlalchemy import Column, Integer, String, Float, DateTime, Enum, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class OrderType(str, enum.Enum):
    product = "product"
    maintenance = "maintenance"


class OrderStatus(str, enum.Enum):
    received = "received"
    reviewing = "reviewing"
    confirmed = "confirmed"
    preparing = "preparing"
    shipped = "shipped"
    on_the_way = "on_the_way"
    delivered = "delivered"
    cancelled = "cancelled"


class MaintenanceStatus(str, enum.Enum):
    received = "received"
    inspecting = "inspecting"
    repairing = "repairing"
    waiting_part = "waiting_part"
    repaired = "repaired"
    ready = "ready"
    delivered = "delivered"
    unrepairable_visit = "unrepairable_visit"
    unrepairable_other = "unrepairable_other"


class PaymentMethod(str, enum.Enum):
    cash = "cash"
    transfer = "transfer"
    card = "card"


class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_number = Column(String(20), unique=True, index=True, nullable=False)
    customer_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    customer_name = Column(String(100), nullable=False)
    customer_phone = Column(String(20), nullable=False)
    customer_email = Column(String(255), nullable=True)
    order_type = Column(Enum(OrderType), default=OrderType.product)
    status = Column(Enum(OrderStatus), default=OrderStatus.received)
    maintenance_status = Column(Enum(MaintenanceStatus), nullable=True)
    items = Column(JSON, default=list)
    subtotal = Column(Float, default=0.0)
    discount = Column(Float, default=0.0)
    total = Column(Float, default=0.0)
    payment_method = Column(Enum(PaymentMethod), default=PaymentMethod.cash)
    notes = Column(Text, nullable=True)
    admin_notes = Column(Text, nullable=True)
    images = Column(JSON, default=list)
    estimated_time = Column(String(100), nullable=True)
    employee_name = Column(String(100), nullable=True)
    address = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    updates = relationship("OrderUpdate", back_populates="order", cascade="all, delete-orphan")
    customer = relationship("User", foreign_keys=[customer_id])


class OrderUpdate(Base):
    __tablename__ = "order_updates"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    status = Column(String(50), nullable=False)
    note = Column(Text, nullable=True)
    images = Column(JSON, default=list)
    employee_name = Column(String(100), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    order = relationship("Order", back_populates="updates")
