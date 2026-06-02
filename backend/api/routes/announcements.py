from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel
from backend.core.database import get_db
from backend.models.announcement import Announcement, AnnouncementType
from backend.api.dependencies import require_admin, get_current_user_optional

router = APIRouter()


class AnnouncementCreate(BaseModel):
    title: str
    body: str
    image_url: Optional[str] = None
    action_url: Optional[str] = None
    announcement_type: AnnouncementType = AnnouncementType.info
    is_active: bool = True
    is_pinned: bool = False
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None


class AnnouncementUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
    image_url: Optional[str] = None
    action_url: Optional[str] = None
    announcement_type: Optional[AnnouncementType] = None
    is_active: Optional[bool] = None
    is_pinned: Optional[bool] = None
    starts_at: Optional[datetime] = None
    ends_at: Optional[datetime] = None


class AnnouncementResponse(BaseModel):
    id: int
    title: str
    body: str
    image_url: Optional[str]
    action_url: Optional[str]
    announcement_type: AnnouncementType
    is_active: bool
    is_pinned: bool
    starts_at: Optional[datetime]
    ends_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("/", response_model=List[AnnouncementResponse])
def list_announcements(
    active_only: bool = True,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user_optional),
):
    """Public: list active announcements. Admins can see all."""
    q = db.query(Announcement)
    now = datetime.utcnow()
    if active_only and (current_user is None or not hasattr(current_user, 'role') or current_user.role == 'customer'):
        q = q.filter(Announcement.is_active == True)
        q = q.filter(
            (Announcement.starts_at == None) | (Announcement.starts_at <= now)
        )
        q = q.filter(
            (Announcement.ends_at == None) | (Announcement.ends_at >= now)
        )
    return q.order_by(Announcement.is_pinned.desc(), Announcement.created_at.desc()).all()


@router.post("/", response_model=AnnouncementResponse)
def create_announcement(
    data: AnnouncementCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin),
):
    ann = Announcement(**data.model_dump())
    db.add(ann)
    db.commit()
    db.refresh(ann)
    return ann


@router.put("/{ann_id}", response_model=AnnouncementResponse)
def update_announcement(
    ann_id: int,
    data: AnnouncementUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin),
):
    ann = db.query(Announcement).filter(Announcement.id == ann_id).first()
    if not ann:
        raise HTTPException(404, "Announcement not found")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(ann, k, v)
    db.commit()
    db.refresh(ann)
    return ann


@router.delete("/{ann_id}")
def delete_announcement(
    ann_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin),
):
    ann = db.query(Announcement).filter(Announcement.id == ann_id).first()
    if not ann:
        raise HTTPException(404, "Announcement not found")
    db.delete(ann)
    db.commit()
    return {"message": "Announcement deleted"}


@router.post("/{ann_id}/toggle")
def toggle_announcement(
    ann_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin),
):
    ann = db.query(Announcement).filter(Announcement.id == ann_id).first()
    if not ann:
        raise HTTPException(404, "Announcement not found")
    ann.is_active = not ann.is_active
    db.commit()
    return {"message": "Toggled", "is_active": ann.is_active}
