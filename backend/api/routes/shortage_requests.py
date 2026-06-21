from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.shortage_request import ShortageRequest, ShortageRequestStatus
from backend.models.user import User
from backend.api.dependencies import get_current_user, get_admin_user, require_staff_or_above
from pydantic import BaseModel

router = APIRouter()


class ShortageRequestCreate(BaseModel):
    customer_name: str
    customer_phone: str
    brand: str
    model: str
    series: Optional[str] = None
    category: Optional[str] = None
    notes: Optional[str] = None


class ShortageRequestResponse(BaseModel):
    id: int
    customer_name: str
    customer_phone: str
    brand: str
    model: str
    series: Optional[str]
    category: Optional[str]
    notes: Optional[str]
    status: ShortageRequestStatus
    created_at: datetime

    class Config:
        from_attributes = True


class NotifyRequest(BaseModel):
    request_ids: List[int]
    message: Optional[str] = None


@router.post("/", response_model=ShortageRequestResponse)
def create_shortage_request(
    data: ShortageRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = db.query(ShortageRequest).filter(
        ShortageRequest.customer_id == current_user.id,
        ShortageRequest.brand.ilike(data.brand),
        ShortageRequest.model.ilike(data.model),
        ShortageRequest.status == ShortageRequestStatus.pending,
    ).first()
    if existing:
        raise HTTPException(400, "لديك طلب مماثل قيد الانتظار بالفعل لهذا الجهاز")

    req = ShortageRequest(
        customer_id=current_user.id,
        customer_name=data.customer_name,
        customer_phone=data.customer_phone,
        brand=data.brand,
        model=data.model,
        series=data.series,
        category=data.category,
        notes=data.notes,
    )
    db.add(req)
    db.commit()
    db.refresh(req)
    return req


@router.post("/guest")
def create_shortage_request_guest(data: ShortageRequestCreate, db: Session = Depends(get_db)):
    existing = db.query(ShortageRequest).filter(
        ShortageRequest.customer_phone == data.customer_phone,
        ShortageRequest.brand.ilike(data.brand),
        ShortageRequest.model.ilike(data.model),
        ShortageRequest.status == ShortageRequestStatus.pending,
    ).first()
    if existing:
        return {"message": "لديك طلب مماثل قيد الانتظار بالفعل لهذا الجهاز. سيتم إعلامك عند توفره.", "id": existing.id}

    req = ShortageRequest(
        customer_name=data.customer_name,
        customer_phone=data.customer_phone,
        brand=data.brand,
        model=data.model,
        series=data.series,
        category=data.category,
        notes=data.notes,
    )
    db.add(req)
    db.commit()
    db.refresh(req)
    return {"message": "تم تسجيل طلبك بنجاح. سيتم إعلامك عند توفر الشاشة.", "id": req.id}


@router.get("/", response_model=List[ShortageRequestResponse])
def list_shortage_requests(
    status: Optional[str] = None,
    brand: Optional[str] = None,
    model: Optional[str] = None,
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    q = db.query(ShortageRequest)
    if status:
        q = q.filter(ShortageRequest.status == status)
    if brand:
        q = q.filter(ShortageRequest.brand.ilike(f"%{brand}%"))
    if model:
        q = q.filter(ShortageRequest.model.ilike(f"%{model}%"))
    return q.order_by(ShortageRequest.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/grouped")
def list_shortage_requests_grouped(db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    """Group shortage requests by brand+model for batch notification."""
    all_req = db.query(ShortageRequest).filter(
        ShortageRequest.status == ShortageRequestStatus.pending
    ).all()
    groups = {}
    for req in all_req:
        key = f"{req.brand} {req.model}"
        if key not in groups:
            groups[key] = {"brand": req.brand, "model": req.model, "series": req.series, "requests": []}
        groups[key]["requests"].append({
            "id": req.id,
            "customer_name": req.customer_name,
            "customer_phone": req.customer_phone,
            "notes": req.notes,
        })
    return list(groups.values())


@router.put("/{req_id}/notify")
def notify_customer(req_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    req = db.query(ShortageRequest).filter(ShortageRequest.id == req_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    req.status = ShortageRequestStatus.notified
    req.notified_at = datetime.utcnow()
    req.notified_by_id = admin.id
    db.commit()
    return {"message": f"تم تحديث حالة طلب {req.customer_name} إلى 'تم الإشعار'", "phone": req.customer_phone}


@router.put("/batch-notify")
def batch_notify(data: NotifyRequest, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    updated = 0
    phones = []
    for req_id in data.request_ids:
        req = db.query(ShortageRequest).filter(ShortageRequest.id == req_id).first()
        if req and req.status == ShortageRequestStatus.pending:
            req.status = ShortageRequestStatus.notified
            req.notified_at = datetime.utcnow()
            req.notified_by_id = admin.id
            req.notification_message = data.message
            phones.append(req.customer_phone)
            updated += 1
    db.commit()
    return {"message": f"تم إشعار {updated} عميل", "phones": phones}


@router.put("/{req_id}/purchased")
def mark_purchased(req_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    req = db.query(ShortageRequest).filter(ShortageRequest.id == req_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    req.status = ShortageRequestStatus.purchased
    req.purchased_at = datetime.utcnow()
    db.commit()
    return {"message": "تم تحديث حالة الطلب إلى 'تم الشراء'"}


@router.put("/{req_id}/close")
def close_request(req_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    req = db.query(ShortageRequest).filter(ShortageRequest.id == req_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="الطلب غير موجود")
    req.status = ShortageRequestStatus.closed
    db.commit()
    return {"message": "تم إغلاق الطلب"}


@router.get("/my")
def my_shortage_requests(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(ShortageRequest).filter(
        ShortageRequest.customer_id == current_user.id
    ).order_by(ShortageRequest.created_at.desc()).all()
