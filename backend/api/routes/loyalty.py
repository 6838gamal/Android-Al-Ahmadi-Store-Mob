from fastapi import APIRouter, Depends, HTTPException
from backend.api.routes.audit import log_action
from backend.models.audit_log import AuditAction
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.loyalty import LoyaltyAccount, LoyaltyTransaction, LoyaltyTransactionType
from backend.models.user import User
from backend.api.dependencies import get_current_user, get_admin_user, require_staff_or_above
from pydantic import BaseModel

router = APIRouter()

POINTS_PER_SALE = 1
POINTS_FOR_FREE_SCREEN = 25


def _get_or_create_account(db: Session, user_id: int) -> LoyaltyAccount:
    acc = db.query(LoyaltyAccount).filter(LoyaltyAccount.user_id == user_id).first()
    if not acc:
        acc = LoyaltyAccount(user_id=user_id, total_points=0, lifetime_points=0)
        db.add(acc)
        db.commit()
        db.refresh(acc)
    return acc


class AddPointsRequest(BaseModel):
    user_id: int
    points: int
    reason: Optional[str] = "بيع شاشة"
    reference_id: Optional[int] = None
    reference_type: Optional[str] = "order"


class AdjustPointsRequest(BaseModel):
    user_id: int
    points: int
    reason: str


class ResetAccountRequest(BaseModel):
    user_id: int
    reason: Optional[str] = "تسليم شاشة مجانية"


class LoyaltyAccountResponse(BaseModel):
    id: int
    user_id: int
    total_points: int
    lifetime_points: int
    is_locked: bool
    free_screens_earned: int
    notes: Optional[str]

    class Config:
        from_attributes = True


class LoyaltyTransactionResponse(BaseModel):
    id: int
    user_id: int
    points: int
    transaction_type: LoyaltyTransactionType
    reason: Optional[str]
    balance_after: int
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("/my", response_model=LoyaltyAccountResponse)
def get_my_loyalty(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _get_or_create_account(db, current_user.id)


@router.get("/account/{user_id}", response_model=LoyaltyAccountResponse)
def get_user_loyalty(user_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    acc = _get_or_create_account(db, user_id)
    return acc


@router.get("/all")
def list_all_loyalty(skip: int = 0, limit: int = 200, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    accounts = db.query(LoyaltyAccount).order_by(LoyaltyAccount.total_points.desc()).offset(skip).limit(limit).all()
    result = []
    for acc in accounts:
        user = db.query(User).filter(User.id == acc.user_id).first()
        result.append({
            "id": acc.id,
            "user_id": acc.user_id,
            "user_name": user.name if user else "غير معروف",
            "user_phone": user.phone if user else "",
            "total_points": acc.total_points,
            "lifetime_points": acc.lifetime_points,
            "is_locked": acc.is_locked,
            "free_screens_earned": acc.free_screens_earned,
        })
    return result


@router.post("/add-points")
def add_points(data: AddPointsRequest, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    acc = _get_or_create_account(db, data.user_id)
    if acc.is_locked:
        raise HTTPException(status_code=400, detail="الحساب مقفل — يجب على المدير تسليم الشاشة المجانية وإعادة تعيين النقاط أولاً")

    before_pts = acc.total_points
    acc.total_points += data.points
    acc.lifetime_points += data.points
    balance_after = acc.total_points

    tx = LoyaltyTransaction(
        user_id=data.user_id,
        points=data.points,
        transaction_type=LoyaltyTransactionType.earn,
        reason=data.reason,
        reference_id=data.reference_id,
        reference_type=data.reference_type,
        balance_after=balance_after,
    )
    db.add(tx)

    # Lock account when reaching threshold
    if acc.total_points >= POINTS_FOR_FREE_SCREEN and not acc.is_locked:
        acc.is_locked = True

    log_action(db, admin, AuditAction.update, entity_type="loyalty_account", entity_id=data.user_id,
               before={"points": before_pts}, after={"points": acc.total_points},
               description=f"إضافة {data.points} نقطة ولاء — {data.reason or ''}")
    db.commit()
    return {
        "message": f"تمت إضافة {data.points} نقطة",
        "total_points": acc.total_points,
        "is_locked": acc.is_locked,
    }


@router.post("/reset")
def reset_account(data: ResetAccountRequest, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    acc = db.query(LoyaltyAccount).filter(LoyaltyAccount.user_id == data.user_id).first()
    if not acc:
        raise HTTPException(status_code=404, detail="حساب النقاط غير موجود")

    old_points = acc.total_points
    acc.total_points = 0
    acc.is_locked = False
    acc.free_screens_earned += 1

    tx = LoyaltyTransaction(
        user_id=data.user_id,
        points=-old_points,
        transaction_type=LoyaltyTransactionType.redeem,
        reason=data.reason or "تسليم شاشة مجانية وتصفير العداد",
        balance_after=0,
        created_by_id=admin.id,
    )
    db.add(tx)
    log_action(db, admin, AuditAction.update, entity_type="loyalty_account", entity_id=data.user_id,
               before={"points": old_points, "is_locked": True},
               after={"points": 0, "is_locked": False, "free_screens_earned": acc.free_screens_earned},
               description=f"تسليم شاشة مجانية وتصفير نقاط الولاء — {data.reason or ''}")
    db.commit()
    return {"message": "تم تسليم الشاشة المجانية وتصفير العداد بنجاح", "free_screens_earned": acc.free_screens_earned}


@router.post("/adjust")
def adjust_points(data: AdjustPointsRequest, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    acc = _get_or_create_account(db, data.user_id)
    acc.total_points = max(0, acc.total_points + data.points)
    if data.points > 0:
        acc.lifetime_points += data.points

    tx_type = LoyaltyTransactionType.adjust if data.points > 0 else LoyaltyTransactionType.deduct
    tx = LoyaltyTransaction(
        user_id=data.user_id,
        points=data.points,
        transaction_type=tx_type,
        reason=data.reason,
        balance_after=acc.total_points,
        created_by_id=admin.id,
    )
    db.add(tx)
    if acc.is_locked and acc.total_points < POINTS_FOR_FREE_SCREEN:
        acc.is_locked = False
    db.commit()
    return {"message": "تم تعديل النقاط", "total_points": acc.total_points}


@router.get("/transactions/{user_id}", response_model=List[LoyaltyTransactionResponse])
def get_transactions(user_id: int, limit: int = 50, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    return db.query(LoyaltyTransaction).filter(
        LoyaltyTransaction.user_id == user_id
    ).order_by(LoyaltyTransaction.created_at.desc()).limit(limit).all()
