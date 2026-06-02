from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.inspection import InspectionRequest, InspectionStatus
from backend.models.user import User
from backend.schemas.inspection import InspectionCreate, InspectionResponse, InspectionItemResponse
from backend.api.dependencies import get_current_user, require_staff_or_above
from backend.core.notifications_helper import push_notification, push_notification_to_admins
from backend.models.notification import NotificationType

router = APIRouter()


@router.post("/", response_model=InspectionItemResponse)
def create_inspection(data: InspectionCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    req = InspectionRequest(
        customer_id=current_user.id,
        customer_name=data.customer_name,
        customer_phone=data.customer_phone,
        device_model=data.device_model,
        problem_description=data.problem_description,
        images=data.images or [],
        video_url=data.video_url,
    )
    db.add(req)
    db.flush()

    push_notification_to_admins(
        db,
        title="🔍 طلب فحص جديد",
        body=f"العميل {current_user.name} يطلب فحص: {data.device_model} — {data.problem_description[:80]}",
        notif_type=NotificationType.inspection,
        is_important=True,
        reference_id=req.id,
        reference_type="inspection",
    )

    db.commit()
    db.refresh(req)
    return req


@router.get("/my", response_model=List[InspectionItemResponse])
def my_inspections(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(InspectionRequest).filter(
        InspectionRequest.customer_id == current_user.id
    ).order_by(InspectionRequest.created_at.desc()).all()


@router.get("/", response_model=List[InspectionItemResponse])
def list_inspections(
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above)
):
    q = db.query(InspectionRequest)
    if status:
        q = q.filter(InspectionRequest.status == status)
    return q.order_by(InspectionRequest.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{req_id}", response_model=InspectionItemResponse)
def get_inspection(req_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    req = db.query(InspectionRequest).filter(InspectionRequest.id == req_id).first()
    if not req:
        raise HTTPException(404, "Inspection not found")
    return req


@router.post("/{req_id}/respond", response_model=InspectionItemResponse)
def respond_to_inspection(
    req_id: int,
    data: InspectionResponse,
    current_user: User = Depends(require_staff_or_above),
    db: Session = Depends(get_db)
):
    req = db.query(InspectionRequest).filter(InspectionRequest.id == req_id).first()
    if not req:
        raise HTTPException(404, "Inspection not found")
    if req.status == InspectionStatus.responded:
        raise HTTPException(400, "Already responded")

    req.staff_id = current_user.id
    req.diagnosis = data.diagnosis
    req.estimated_price = data.estimated_price
    req.response_notes = data.response_notes
    req.response_images = data.response_images or []
    req.status = InspectionStatus.responded
    req.responded_at = datetime.utcnow()

    if req.customer_id:
        price_text = f" — التكلفة المقدرة: {data.estimated_price} ريال" if data.estimated_price else ""
        push_notification(
            db, req.customer_id,
            title="💬 تم الرد على طلب الفحص",
            body=f"تم فحص جهازك {req.device_model} وإرسال التشخيص{price_text}. افتح التطبيق لمشاهدة التفاصيل.",
            notif_type=NotificationType.inspection,
            is_important=True,
            reference_id=req.id,
            reference_type="inspection",
        )

    db.commit()
    db.refresh(req)
    return req


@router.post("/{req_id}/close")
def close_inspection(req_id: int, db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    req = db.query(InspectionRequest).filter(InspectionRequest.id == req_id).first()
    if not req:
        raise HTTPException(404, "Inspection not found")
    req.status = InspectionStatus.closed
    db.commit()
    return {"message": "Inspection closed"}
