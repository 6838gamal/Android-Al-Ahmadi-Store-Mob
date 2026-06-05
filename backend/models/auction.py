from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, Enum, Text, ForeignKey, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from backend.core.database import Base
import enum


class AuctionStatus(str, enum.Enum):
    pending = "pending"
    active = "active"
    ended = "ended"
    sold = "sold"
    rejected = "rejected"


class Auction(Base):
    __tablename__ = "auctions"

    id = Column(Integer, primary_key=True, index=True)
    auction_number = Column(String(30), unique=True, index=True)
    seller_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    seller_name = Column(String(100), nullable=False)
    seller_phone = Column(String(20), nullable=False)
    device_type = Column(String(200), nullable=False)
    problem_description = Column(Text, nullable=False)
    images = Column(JSON, default=list)
    starting_bid = Column(Float, default=0.0)
    current_bid = Column(Float, default=0.0)
    status = Column(Enum(AuctionStatus), default=AuctionStatus.pending, index=True)
    winning_bid_id = Column(Integer, ForeignKey("auction_bids.id"), nullable=True)
    ends_at = Column(DateTime(timezone=True), nullable=True)
    admin_notes = Column(Text, nullable=True)
    commission_amount = Column(Float, default=0.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    seller = relationship("User", foreign_keys=[seller_id])
    bids = relationship("AuctionBid", foreign_keys="AuctionBid.auction_id", back_populates="auction")


class AuctionBid(Base):
    __tablename__ = "auction_bids"

    id = Column(Integer, primary_key=True, index=True)
    auction_id = Column(Integer, ForeignKey("auctions.id"), nullable=False, index=True)
    bidder_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    bidder_name = Column(String(100), nullable=False)
    bidder_phone = Column(String(20), nullable=False)
    amount = Column(Float, nullable=False)
    notes = Column(Text, nullable=True)
    is_winning = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    auction = relationship("Auction", foreign_keys=[auction_id], back_populates="bids")
    bidder = relationship("User", foreign_keys=[bidder_id])
