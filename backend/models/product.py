from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class ProductCategory(str, enum.Enum):
    screen = "screen"
    battery = "battery"
    camera = "camera"
    speaker = "speaker"
    charger = "charger"
    device = "device"
    spare_part = "spare_part"
    other = "other"


class ProductStatus(str, enum.Enum):
    available = "available"
    reserved = "reserved"
    sold = "sold"
    unavailable = "unavailable"


class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False, index=True)
    name_ar = Column(String(200), nullable=True)
    category = Column(Enum(ProductCategory), nullable=False)
    brand = Column(String(100), nullable=True)
    model = Column(String(100), nullable=True)
    image_url = Column(String(500), nullable=True)
    price = Column(Float, nullable=False)
    quantity = Column(Integer, default=0)
    status = Column(Enum(ProductStatus), default=ProductStatus.available)
    description = Column(Text, nullable=True)
    barcode = Column(String(100), nullable=True, unique=True)
    qr_code = Column(String(500), nullable=True)
    notes = Column(Text, nullable=True)
    is_featured = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
