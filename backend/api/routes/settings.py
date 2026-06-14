from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from backend.core.database import get_db
from backend.api.dependencies import get_current_user
from backend.models.user import User, UserRole
from backend.models.app_setting import AppSetting

router = APIRouter()


def _require_admin(user: User):
    if user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="غير مصرح — المدير فقط")


@router.get("/")
def get_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)
    rows = db.query(AppSetting).all()
    return {r.key: r.value for r in rows}


class SettingUpdate(BaseModel):
    key: str
    value: str


@router.post("/")
def upsert_setting(
    body: SettingUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)
    row = db.query(AppSetting).filter(AppSetting.key == body.key).first()
    if row:
        row.value = body.value
    else:
        row = AppSetting(key=body.key, value=body.value)
        db.add(row)
    db.commit()
    return {"ok": True}


@router.delete("/{key}")
def delete_setting(
    key: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_admin(current_user)
    row = db.query(AppSetting).filter(AppSetting.key == key).first()
    if row:
        db.delete(row)
        db.commit()
    return {"ok": True}
