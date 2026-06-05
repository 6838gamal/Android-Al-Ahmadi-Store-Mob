from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class InvoiceStatus(str, enum.Enum):
    draft = "draft"
    confirmed = "confirmed"
    cancelled = "cancelled"


class PurchaseInvoice(Base):
    __tablename__ = "purchase_invoices"

    id = Column(Integer, primary_key=True, index=True)
    invoice_number = Column(String(30), unique=True, index=True)
    supplier_name = Column(String(200), nullable=False)
    supplier_phone = Column(String(20), nullable=True)
    total_amount = Column(Float, nullable=False)
    cash_from_drawer = Column(Float, default=0.0, nullable=False)
    capital_from_owner = Column(Float, default=0.0, nullable=False)
    status = Column(Enum(InvoiceStatus), default=InvoiceStatus.confirmed)
    notes = Column(Text, nullable=True)
    receipt_printed = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    created_by = relationship("User", foreign_keys=[created_by_id])
    items = relationship("PurchaseInvoiceItem", back_populates="invoice", cascade="all, delete-orphan")


class PurchaseInvoiceItem(Base):
    __tablename__ = "purchase_invoice_items"

    id = Column(Integer, primary_key=True, index=True)
    invoice_id = Column(Integer, ForeignKey("purchase_invoices.id"), nullable=False, index=True)
    product_name = Column(String(200), nullable=False)
    brand = Column(String(100), nullable=True)
    model = Column(String(100), nullable=True)
    series = Column(String(100), nullable=True)
    category = Column(String(50), nullable=True)
    quantity = Column(Integer, default=1)
    unit_price = Column(Float, nullable=False)
    total_price = Column(Float, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    invoice = relationship("PurchaseInvoice", back_populates="items")
