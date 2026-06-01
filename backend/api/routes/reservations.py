from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
from backend.core.database import get_db
from backend.models.reservation import Reservation, ReservationStatus
from backend.models.product import Product, ProductStatus
from backend.api.dependencies import get_admin_user
from backend.models.user import User
from pydantic import BaseModel

router = APIRouter()


class ReservationCreate(BaseModel):
    customer_name: str
    customer_phone: str
    product_id: int
    notes: Optional[str] = None
    days: int = 3


class ReservationResponse(BaseModel):
    id: int
    reservation_number: str
    customer_name: str
    customer_phone: str
    product_id: int
    product_name: str
    price: float
    status: ReservationStatus
    expires_at: Optional[datetime]
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


def gen_res_number(db):
    count = db.query(Reservation).count() + 1
    return f"RES-{datetime.now().year}-{count:04d}"


@router.post("/", response_model=ReservationResponse)
def create_reservation(data: ReservationCreate, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == data.product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    if product.status != ProductStatus.available:
        raise HTTPException(status_code=400, detail="Product not available")

    product.status = ProductStatus.reserved
    expires = datetime.utcnow() + timedelta(days=data.days)

    res = Reservation(
        reservation_number=gen_res_number(db),
        customer_name=data.customer_name,
        customer_phone=data.customer_phone,
        product_id=data.product_id,
        product_name=product.name,
        price=product.price,
        notes=data.notes,
        expires_at=expires,
    )
    db.add(res)
    db.commit()
    db.refresh(res)
    return res


@router.get("/", response_model=List[ReservationResponse])
def get_reservations(
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    return db.query(Reservation).order_by(Reservation.created_at.desc()).offset(skip).limit(limit).all()


@router.put("/{res_id}/cancel")
def cancel_reservation(res_id: int, db: Session = Depends(get_db), admin: User = Depends(get_admin_user)):
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if not res:
        raise HTTPException(status_code=404, detail="Not found")
    res.status = ReservationStatus.cancelled
    product = db.query(Product).filter(Product.id == res.product_id).first()
    if product:
        product.status = ProductStatus.available
    db.commit()
    return {"message": "Cancelled"}


@router.put("/{res_id}/complete")
def complete_reservation(res_id: int, db: Session = Depends(get_db), admin: User = Depends(get_admin_user)):
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if not res:
        raise HTTPException(status_code=404, detail="Not found")
    res.status = ReservationStatus.completed
    product = db.query(Product).filter(Product.id == res.product_id).first()
    if product:
        product.status = ProductStatus.sold
    db.commit()
    return {"message": "Completed"}
