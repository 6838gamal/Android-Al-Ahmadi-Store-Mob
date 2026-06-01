from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from backend.core.database import get_db
from backend.models.notification import Notification
from backend.models.user import User, UserRole
from backend.schemas.notification import NotificationCreate, NotificationResponse
from backend.api.dependencies import get_current_user, require_admin

router = APIRouter()


@router.get("/my", response_model=List[NotificationResponse])
def my_notifications(
    unread_only: bool = False,
    important_only: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    q = db.query(Notification).filter(Notification.user_id == current_user.id)
    if unread_only:
        q = q.filter(Notification.is_read == False)
    if important_only:
        q = q.filter(Notification.is_important == True)
    return q.order_by(Notification.created_at.desc()).limit(100).all()


@router.get("/my/unread-count")
def unread_count(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    count = db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).count()
    return {"unread_count": count}


@router.get("/all", response_model=List[NotificationResponse])
def all_notifications(
    limit: int = 300,
    db: Session = Depends(get_db),
    admin=Depends(require_admin)
):
    return db.query(Notification).order_by(
        Notification.created_at.desc()
    ).limit(limit).all()


@router.post("/{notif_id}/read")
def mark_read(notif_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    n = db.query(Notification).filter(Notification.id == notif_id, Notification.user_id == current_user.id).first()
    if not n:
        raise HTTPException(404, "Notification not found")
    n.is_read = True
    db.commit()
    return {"message": "Marked as read"}


@router.post("/read-all")
def mark_all_read(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).update({"is_read": True})
    db.commit()
    return {"message": "All notifications marked as read"}


@router.post("/send", response_model=NotificationResponse)
def send_notification(data: NotificationCreate, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    n = Notification(**data.model_dump())
    db.add(n)
    db.commit()
    db.refresh(n)
    return n


@router.post("/broadcast")
def broadcast_notification(title: str, body: str, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    users = db.query(User).filter(User.is_active == True).all()
    for user in users:
        n = Notification(user_id=user.id, title=title, body=body)
        db.add(n)
    db.commit()
    return {"message": f"Notification sent to {len(users)} users"}


@router.delete("/{notif_id}")
def delete_notification(notif_id: int, db: Session = Depends(get_db), admin=Depends(require_admin)):
    n = db.query(Notification).filter(Notification.id == notif_id).first()
    if not n:
        raise HTTPException(404, "Not found")
    db.delete(n)
    db.commit()
    return {"message": "Deleted"}
