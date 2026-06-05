from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base


class GalleryFolder(Base):
    __tablename__ = "gallery_folders"

    id = Column(Integer, primary_key=True, index=True)
    series_key = Column(String(50), nullable=False, index=True)
    model_key = Column(String(50), nullable=False, index=True)
    label_ar = Column(String(100), nullable=False)
    label_en = Column(String(100), nullable=False)
    cover_image_url = Column(String(500), nullable=True)
    sort_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    images = relationship("GalleryImage", back_populates="folder", cascade="all, delete-orphan",
                          order_by="GalleryImage.sort_order")

    @property
    def image_count(self):
        return len(self.images)


class GalleryImage(Base):
    __tablename__ = "gallery_images"

    id = Column(Integer, primary_key=True, index=True)
    folder_id = Column(Integer, ForeignKey("gallery_folders.id"), nullable=False, index=True)
    image_url = Column(String(500), nullable=False)
    watermark_number = Column(String(30), nullable=True)
    title = Column(String(200), nullable=True)
    notes = Column(Text, nullable=True)
    sort_order = Column(Integer, default=0)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    folder = relationship("GalleryFolder", back_populates="images")
    created_by = relationship("User", foreign_keys=[created_by_id])
