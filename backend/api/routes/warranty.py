from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta
from backend.core.database import get_db
from backend.models.warranty import Warranty
from backend.models.user import User
from backend.schemas.warranty import WarrantyCreate, WarrantyResponse, ReturnRequest
from backend.api.dependencies import get_current_user, require_staff_or_above, require_admin

router = APIRouter()


@router.post("/", response_model=WarrantyResponse)
def create_warranty(data: WarrantyCreate, db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    starts = datetime.utcnow()
    ends = starts + timedelta(days=data.warranty_days)
    warranty = Warranty(
        order_id=data.order_id,
        customer_id=data.customer_id,
        product_name=data.product_name,
        product_serial=data.product_serial,
        purchase_price=data.purchase_price,
        warranty_days=data.warranty_days,
        starts_at=starts,
        ends_at=ends,
    )
    db.add(warranty)
    db.commit()
    db.refresh(warranty)
    return warranty


@router.get("/my", response_model=List[WarrantyResponse])
def my_warranties(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Warranty).filter(Warranty.customer_id == current_user.id).order_by(Warranty.created_at.desc()).all()


@router.get("/", response_model=List[WarrantyResponse])
def list_warranties(db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    return db.query(Warranty).order_by(Warranty.created_at.desc()).all()


@router.get("/{warranty_id}", response_model=WarrantyResponse)
def get_warranty(warranty_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    return w


@router.post("/{warranty_id}/request-return")
def request_return(warranty_id: int, data: ReturnRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    if w.customer_id != current_user.id:
        raise HTTPException(403, "Not your warranty")
    if datetime.utcnow() > w.ends_at:
        raise HTTPException(400, "Warranty period has expired")
    if w.is_return_requested:
        raise HTTPException(400, "Return already requested")
    w.is_return_requested = True
    w.return_reason = data.return_reason
    w.return_requested_at = datetime.utcnow()
    db.commit()
    return {"message": "Return request submitted"}


@router.post("/{warranty_id}/resolve-return")
def resolve_return(warranty_id: int, notes: str = "", db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    w.return_resolved = True
    w.return_notes = notes
    db.commit()
    return {"message": "Return resolved"}
