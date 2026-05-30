from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from backend.core.database import get_db
from backend.models.audit_log import AuditLog, AuditAction
from backend.models.user import User
from backend.schemas.audit_log import AuditLogResponse
from backend.api.dependencies import require_admin

router = APIRouter()


@router.get("/", response_model=List[AuditLogResponse])
def list_audit_logs(
    user_id: Optional[int] = None,
    action: Optional[str] = None,
    entity_type: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin)
):
    q = db.query(AuditLog)
    if user_id:
        q = q.filter(AuditLog.user_id == user_id)
    if action:
        q = q.filter(AuditLog.action == action)
    if entity_type:
        q = q.filter(AuditLog.entity_type == entity_type)
    return q.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit).all()


def log_action(
    db: Session,
    user: Optional[User],
    action: AuditAction,
    entity_type: str = None,
    entity_id: int = None,
    before: dict = None,
    after: dict = None,
    description: str = None,
    ip_address: str = None,
    device_info: str = None,
):
    entry = AuditLog(
        user_id=user.id if user else None,
        user_role=user.role.value if user else None,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        before_value=before,
        after_value=after,
        description=description,
        ip_address=ip_address,
        device_info=device_info,
    )
    db.add(entry)
