from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.complaint import Complaint, ComplaintStatus, ComplaintType
from backend.models.user import User
from backend.api.dependencies import get_current_user, get_admin_user
from pydantic import BaseModel

router = APIRouter()


class ComplaintCreate(BaseModel):
    customer_name: str
    customer_phone: Optional[str] = None
    subject: str
    content: str
    complaint_type: Optional[str] = "complaint"


class ComplaintReply(BaseModel):
    reply: str


class ComplaintResponse(BaseModel):
    id: int
    customer_name: str
    subject: str
    content: str
    complaint_type: ComplaintType
    status: ComplaintStatus
    is_read: bool
    admin_reply: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/")
def submit_complaint(data: ComplaintCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    complaint = Complaint(
        customer_id=current_user.id,
        customer_name=data.customer_name,
        customer_phone=data.customer_phone or current_user.phone,
        subject=data.subject,
        content=data.content,
        complaint_type=data.complaint_type or ComplaintType.complaint,
    )
    db.add(complaint)
    db.commit()
    db.refresh(complaint)
    return {"message": "تم إرسال شكواك/اقتراحك بنجاح. سيطلع عليه المدير العام فقط.", "id": complaint.id}


@router.post("/guest")
def submit_complaint_guest(data: ComplaintCreate, db: Session = Depends(get_db)):
    complaint = Complaint(
        customer_name=data.customer_name,
        customer_phone=data.customer_phone,
        subject=data.subject,
        content=data.content,
        complaint_type=data.complaint_type or ComplaintType.complaint,
    )
    db.add(complaint)
    db.commit()
    return {"message": "تم إرسال شكواك/اقتراحك بنجاح. سيطلع عليه المدير العام فقط."}


@router.get("/", response_model=List[ComplaintResponse])
def list_complaints(
    status: Optional[str] = None,
    complaint_type: Optional[str] = None,
    unread_only: bool = False,
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    q = db.query(Complaint)
    if status:
        q = q.filter(Complaint.status == status)
    if complaint_type:
        q = q.filter(Complaint.complaint_type == complaint_type)
    if unread_only:
        q = q.filter(Complaint.is_read == False)
    return q.order_by(Complaint.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/unread-count")
def unread_count(db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    count = db.query(Complaint).filter(Complaint.is_read == False).count()
    return {"unread_count": count}


@router.get("/{complaint_id}")
def get_complaint(complaint_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    c = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="الشكوى غير موجودة")
    if not c.is_read:
        c.is_read = True
        db.commit()
    return c


@router.put("/{complaint_id}/reply")
def reply_to_complaint(
    complaint_id: int,
    data: ComplaintReply,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    c = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="الشكوى غير موجودة")
    c.admin_reply = data.reply
    c.replied_at = datetime.utcnow()
    c.replied_by_id = admin.id
    c.status = ComplaintStatus.reviewed
    db.commit()
    return {"message": "تم الرد على الشكوى"}


@router.put("/{complaint_id}/resolve")
def resolve_complaint(complaint_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    c = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="الشكوى غير موجودة")
    c.status = ComplaintStatus.resolved
    db.commit()
    return {"message": "تم حل الشكوى"}


@router.put("/{complaint_id}/archive")
def archive_complaint(complaint_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    c = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="الشكوى غير موجودة")
    c.status = ComplaintStatus.archived
    db.commit()
    return {"message": "تم أرشفة الشكوى"}


@router.delete("/{complaint_id}")
def delete_complaint(complaint_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    c = db.query(Complaint).filter(Complaint.id == complaint_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="الشكوى غير موجودة")
    db.delete(c)
    db.commit()
    return {"message": "تم حذف الشكوى"}
