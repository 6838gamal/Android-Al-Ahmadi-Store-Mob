from sqlalchemy import Column, Integer, String, Text
from backend.core.database import Base


class AppSetting(Base):
    __tablename__ = "app_settings"

    id    = Column(Integer, primary_key=True, index=True)
    key   = Column(String(100), unique=True, nullable=False, index=True)
    value = Column(Text, nullable=True)
