from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, Enum
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class AnnouncementType(str, enum.Enum):
    info = "info"
    offer = "offer"
    alert = "alert"
    warning = "warning"
    news = "news"
    event = "event"


class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)
    image_url = Column(String(500), nullable=True)
    action_url = Column(String(500), nullable=True)
    announcement_type = Column(Enum(AnnouncementType), default=AnnouncementType.info)
    is_active = Column(Boolean, default=True)
    is_pinned = Column(Boolean, default=False)
    starts_at = Column(DateTime(timezone=True), nullable=True)
    ends_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
