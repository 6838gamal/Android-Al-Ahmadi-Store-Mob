from sqlalchemy import Column, String, Text, DateTime
from sqlalchemy.sql import func
from backend.core.database import Base


class StoredImage(Base):
    __tablename__ = "stored_images"

    uuid = Column(String(36), primary_key=True, index=True)
    data = Column(Text, nullable=False)
    mime_type = Column(String(50), nullable=False, default="image/jpeg")
    created_at = Column(DateTime, server_default=func.now())
