from pydantic import BaseModel
from typing import Optional, Any
from datetime import datetime
from backend.models.audit_log import AuditAction


class AuditLogResponse(BaseModel):
    id: int
    user_id: Optional[int]
    user_role: Optional[str]
    action: AuditAction
    entity_type: Optional[str]
    entity_id: Optional[int]
    before_value: Optional[Any]
    after_value: Optional[Any]
    description: Optional[str]
    ip_address: Optional[str]
    device_info: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
