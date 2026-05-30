from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from backend.models.notification import NotificationType


class NotificationCreate(BaseModel):
    user_id: int
    title: str
    body: str
    notification_type: NotificationType = NotificationType.system
    is_important: bool = False
    reference_id: Optional[int] = None
    reference_type: Optional[str] = None


class NotificationResponse(BaseModel):
    id: int
    user_id: int
    title: str
    body: str
    notification_type: NotificationType
    is_read: bool
    is_important: bool
    reference_id: Optional[int]
    reference_type: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
