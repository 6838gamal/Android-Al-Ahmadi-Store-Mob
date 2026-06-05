from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
from backend.core.database import get_db
from backend.models.auction import Auction, AuctionBid, AuctionStatus
from backend.models.user import User
from backend.api.dependencies import get_current_user, get_admin_user, get_current_user_optional
from pydantic import BaseModel

router = APIRouter()


def _gen_auction_number(db):
    count = db.query(Auction).count() + 1
    return f"AUC-{datetime.now().year}-{count:04d}"


class AuctionCreate(BaseModel):
    seller_name: str
    seller_phone: str
    device_type: str
    problem_description: str
    images: Optional[List[str]] = []
    starting_bid: Optional[float] = 0.0


class BidCreate(BaseModel):
    bidder_name: str
    bidder_phone: str
    amount: float
    notes: Optional[str] = None


class AuctionResponse(BaseModel):
    id: int
    auction_number: str
    seller_name: str
    seller_phone: str
    device_type: str
    problem_description: str
    images: Optional[List]
    starting_bid: float
    current_bid: float
    status: AuctionStatus
    ends_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/")
def create_auction(data: AuctionCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    auction = Auction(
        auction_number=_gen_auction_number(db),
        seller_id=current_user.id,
        seller_name=data.seller_name,
        seller_phone=data.seller_phone,
        device_type=data.device_type,
        problem_description=data.problem_description,
        images=data.images or [],
        starting_bid=data.starting_bid or 0.0,
        current_bid=data.starting_bid or 0.0,
    )
    db.add(auction)
    db.commit()
    db.refresh(auction)
    return {"message": "تم رفع طلب المزاد بنجاح. سيتم مراجعته من قِبل الإدارة.", "id": auction.id}


@router.get("/")
def list_auctions(
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    q = db.query(Auction)
    if status:
        q = q.filter(Auction.status == status)
    else:
        q = q.filter(Auction.status == AuctionStatus.active)
    auctions = q.order_by(Auction.created_at.desc()).offset(skip).limit(limit).all()
    result = []
    for a in auctions:
        bid_count = db.query(AuctionBid).filter(AuctionBid.auction_id == a.id).count()
        result.append({
            "id": a.id,
            "auction_number": a.auction_number,
            "seller_name": a.seller_name,
            "device_type": a.device_type,
            "problem_description": a.problem_description,
            "images": a.images,
            "starting_bid": a.starting_bid,
            "current_bid": a.current_bid,
            "status": a.status,
            "bid_count": bid_count,
            "ends_at": a.ends_at,
            "created_at": a.created_at,
        })
    return result


@router.get("/admin/all")
def list_all_auctions(
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    q = db.query(Auction)
    if status:
        q = q.filter(Auction.status == status)
    return q.order_by(Auction.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{auction_id}")
def get_auction(auction_id: int, db: Session = Depends(get_db)):
    a = db.query(Auction).filter(Auction.id == auction_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="المزاد غير موجود")
    bids = db.query(AuctionBid).filter(AuctionBid.auction_id == auction_id).order_by(AuctionBid.amount.desc()).all()
    return {
        "id": a.id,
        "auction_number": a.auction_number,
        "seller_name": a.seller_name,
        "seller_phone": a.seller_phone,
        "device_type": a.device_type,
        "problem_description": a.problem_description,
        "images": a.images,
        "starting_bid": a.starting_bid,
        "current_bid": a.current_bid,
        "status": a.status,
        "ends_at": a.ends_at,
        "admin_notes": a.admin_notes,
        "commission_amount": a.commission_amount,
        "bids": [{"id": b.id, "bidder_name": b.bidder_name, "bidder_phone": b.bidder_phone, "amount": b.amount, "notes": b.notes, "is_winning": b.is_winning, "created_at": b.created_at} for b in bids],
        "created_at": a.created_at,
    }


@router.post("/{auction_id}/bid")
def place_bid(auction_id: int, data: BidCreate, db: Session = Depends(get_db)):
    a = db.query(Auction).filter(Auction.id == auction_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="المزاد غير موجود")
    if a.status != AuctionStatus.active:
        raise HTTPException(status_code=400, detail="المزاد غير نشط")
    if data.amount < a.current_bid:
        raise HTTPException(status_code=400, detail=f"المزايدة يجب أن تكون أعلى من العرض الحالي: {a.current_bid}")

    bid = AuctionBid(
        auction_id=auction_id,
        bidder_name=data.bidder_name,
        bidder_phone=data.bidder_phone,
        amount=data.amount,
        notes=data.notes,
    )
    db.add(bid)
    a.current_bid = data.amount
    db.commit()
    return {"message": "تم تسجيل مزايدتك بنجاح", "amount": data.amount}


@router.put("/{auction_id}/activate")
def activate_auction(auction_id: int, days: int = 7, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    a = db.query(Auction).filter(Auction.id == auction_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="المزاد غير موجود")
    a.status = AuctionStatus.active
    a.ends_at = datetime.utcnow() + timedelta(days=days)
    db.commit()
    return {"message": "تم تفعيل المزاد"}


@router.put("/{auction_id}/close")
def close_auction(auction_id: int, winning_bid_id: Optional[int] = None, commission: float = 0.0, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    a = db.query(Auction).filter(Auction.id == auction_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="المزاد غير موجود")
    a.status = AuctionStatus.sold if winning_bid_id else AuctionStatus.ended
    a.commission_amount = commission
    if winning_bid_id:
        a.winning_bid_id = winning_bid_id
        winning_bid = db.query(AuctionBid).filter(AuctionBid.id == winning_bid_id).first()
        if winning_bid:
            winning_bid.is_winning = True
    db.commit()
    return {"message": "تم إغلاق المزاد"}


@router.delete("/{auction_id}")
def reject_auction(auction_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    a = db.query(Auction).filter(Auction.id == auction_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="المزاد غير موجود")
    a.status = AuctionStatus.rejected
    db.commit()
    return {"message": "تم رفض المزاد"}
