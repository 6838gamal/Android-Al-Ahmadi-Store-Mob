from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.eng_support import EngSupportPost, EngSupportResponse, EngPostStatus
from backend.models.user import User
from backend.api.dependencies import get_current_user, get_admin_user, require_staff_or_above, get_current_user_optional
from pydantic import BaseModel

router = APIRouter()


class PostCreate(BaseModel):
    title: str
    content: str
    device_type: Optional[str] = None
    fault_type: Optional[str] = None
    tags: Optional[str] = None
    images: Optional[List[str]] = []
    author_name: str
    author_phone: Optional[str] = None
    is_paid_post: Optional[bool] = False
    price_per_consult: Optional[float] = 0.0


class ResponseCreate(BaseModel):
    content: str
    images: Optional[List[str]] = []
    author_name: str
    is_paid: Optional[bool] = False
    payment_amount: Optional[float] = 0.0


class PostUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    is_subscription_required: Optional[bool] = None
    price_per_consult: Optional[float] = None
    is_pinned: Optional[bool] = None


@router.get("/")
def list_posts(
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    q = db.query(EngSupportPost)
    if status:
        q = q.filter(EngSupportPost.status == status)
    posts = q.order_by(EngSupportPost.is_pinned.desc(), EngSupportPost.created_at.desc()).offset(skip).limit(limit).all()
    result = []
    for p in posts:
        resp_count = db.query(EngSupportResponse).filter(EngSupportResponse.post_id == p.id).count()
        result.append({
            "id": p.id,
            "title": p.title,
            "device_type": p.device_type,
            "fault_type": p.fault_type,
            "tags": p.tags,
            "status": p.status,
            "author_name": p.author_name,
            "views": p.views,
            "response_count": resp_count,
            "is_subscription_required": p.is_subscription_required,
            "price_per_consult": p.price_per_consult,
            "is_pinned": p.is_pinned,
            "created_at": p.created_at,
        })
    return result


@router.get("/{post_id}")
def get_post(post_id: int, db: Session = Depends(get_db)):
    p = db.query(EngSupportPost).filter(EngSupportPost.id == post_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="المنشور غير موجود")
    p.views += 1
    db.commit()
    responses = db.query(EngSupportResponse).filter(EngSupportResponse.post_id == post_id).order_by(EngSupportResponse.created_at).all()
    return {
        "id": p.id,
        "title": p.title,
        "content": p.content,
        "device_type": p.device_type,
        "fault_type": p.fault_type,
        "tags": p.tags,
        "images": p.images,
        "status": p.status,
        "author_name": p.author_name,
        "author_phone": p.author_phone,
        "views": p.views,
        "is_subscription_required": p.is_subscription_required,
        "price_per_consult": p.price_per_consult,
        "is_pinned": p.is_pinned,
        "created_at": p.created_at,
        "responses": [{"id": r.id, "author_name": r.author_name, "content": r.content, "images": r.images, "is_accepted": r.is_accepted, "is_paid": r.is_paid, "payment_amount": r.payment_amount, "created_at": r.created_at} for r in responses],
    }


@router.post("/")
def create_post(data: PostCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = EngSupportPost(
        title=data.title,
        content=data.content,
        device_type=data.device_type,
        fault_type=data.fault_type,
        tags=data.tags,
        images=data.images or [],
        author_id=current_user.id,
        author_name=data.author_name,
        author_phone=data.author_phone,
        is_paid_post=data.is_paid_post or False,
        price_per_consult=data.price_per_consult or 0.0,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return {"message": "تم نشر الاستفسار بنجاح", "id": post.id}


@router.post("/{post_id}/respond")
def add_response(post_id: int, data: ResponseCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    p = db.query(EngSupportPost).filter(EngSupportPost.id == post_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="المنشور غير موجود")
    resp = EngSupportResponse(
        post_id=post_id,
        author_id=current_user.id,
        author_name=data.author_name,
        content=data.content,
        images=data.images or [],
        is_paid=data.is_paid or False,
        payment_amount=data.payment_amount or 0.0,
    )
    db.add(resp)
    if p.status == EngPostStatus.open:
        p.status = EngPostStatus.answered
    db.commit()
    return {"message": "تم إرسال ردك بنجاح"}


@router.put("/{post_id}/accept-response/{response_id}")
def accept_response(post_id: int, response_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    resp = db.query(EngSupportResponse).filter(EngSupportResponse.id == response_id, EngSupportResponse.post_id == post_id).first()
    if not resp:
        raise HTTPException(status_code=404, detail="الرد غير موجود")
    resp.is_accepted = True
    p = db.query(EngSupportPost).filter(EngSupportPost.id == post_id).first()
    if p:
        p.status = EngPostStatus.closed
    db.commit()
    return {"message": "تم قبول الرد وإغلاق الاستفسار"}


@router.put("/{post_id}", dependencies=[Depends(get_admin_user)])
def update_post(post_id: int, data: PostUpdate, db: Session = Depends(get_db)):
    p = db.query(EngSupportPost).filter(EngSupportPost.id == post_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="المنشور غير موجود")
    if data.title is not None:
        p.title = data.title
    if data.content is not None:
        p.content = data.content
    if data.is_subscription_required is not None:
        p.is_subscription_required = data.is_subscription_required
    if data.price_per_consult is not None:
        p.price_per_consult = data.price_per_consult
    if data.is_pinned is not None:
        p.is_pinned = data.is_pinned
    db.commit()
    return {"message": "تم تحديث المنشور"}


@router.delete("/{post_id}", dependencies=[Depends(get_admin_user)])
def delete_post(post_id: int, db: Session = Depends(get_db)):
    p = db.query(EngSupportPost).filter(EngSupportPost.id == post_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="المنشور غير موجود")
    db.query(EngSupportResponse).filter(EngSupportResponse.post_id == post_id).delete()
    db.delete(p)
    db.commit()
    return {"message": "تم حذف المنشور"}
