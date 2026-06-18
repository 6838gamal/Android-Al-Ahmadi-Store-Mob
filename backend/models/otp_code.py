from sqlalchemy import Column, Integer, String, Float, Index
from backend.core.database import Base


class OtpCode(Base):
    __tablename__ = "otp_codes"

    id       = Column(Integer, primary_key=True, index=True)
    phone    = Column(String(30), nullable=False, index=True)
    code     = Column(String(10), nullable=False)
    expires  = Column(Float, nullable=False)
    sent_at  = Column(Float, nullable=False)

    __table_args__ = (
        Index("ix_otp_codes_phone_unique", "phone", unique=True),
    )
