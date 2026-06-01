import random, string
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from backend.core.database import get_db
from backend.models.user import User
from backend.models.referral import Referral
from backend.schemas.referral import ReferralResponse, ReferralStatsResponse
from backend.api.dependencies import get_current_user, require_admin
from typing import List

router = APIRouter()

LEVEL1_TARGET = 50   # referrals needed to complete level 1 and unlock level 2


def _generate_code(length=8) -> str:
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=length))


def _ensure_referral_code(user: User, db: Session) -> str:
    if not user.referral_code:
        code = _generate_code()
        while db.query(User).filter(User.referral_code == code).first():
            code = _generate_code()
        user.referral_code = code
        db.commit()
    return user.referral_code


def _update_referrer_level(referrer: User, db: Session):
    """Promote referrer to level 2 and lock level 1 once they hit 50 verified referrals."""
    if referrer.level1_locked:
        return  # already promoted, nothing to do
    verified_count = (
        db.query(Referral)
        .filter(Referral.referrer_id == referrer.id, Referral.is_verified == True)
        .count()
    )
    if verified_count >= LEVEL1_TARGET:
        referrer.referral_level = 2
        referrer.level1_locked = True
        db.commit()


@router.get("/my-stats", response_model=ReferralStatsResponse)
def my_referral_stats(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    code = _ensure_referral_code(current_user, db)
    base_url = str(request.base_url).rstrip("/")

    total = db.query(Referral).filter(Referral.referrer_id == current_user.id).count()
    verified = (
        db.query(Referral)
        .filter(Referral.referrer_id == current_user.id, Referral.is_verified == True)
        .count()
    )
    level1_count = (
        db.query(Referral)
        .filter(Referral.referrer_id == current_user.id, Referral.level == 1)
        .count()
    )
    level2_count = (
        db.query(Referral)
        .filter(Referral.referrer_id == current_user.id, Referral.level == 2)
        .count()
    )

    # Progress toward level 1 completion (capped at 50)
    progress = min(verified, LEVEL1_TARGET)

    return ReferralStatsResponse(
        referral_code=code,
        referral_link=f"{base_url}/register?ref={code}",
        total_referrals=total,
        verified_referrals=verified,
        target=LEVEL1_TARGET,
        current_level=current_user.referral_level,
        level1_locked=current_user.level1_locked,
        level1_count=level1_count,
        level2_count=level2_count,
        progress_to_next=progress,
    )


@router.post("/register-referral")
def register_referral(
    referral_code: str,
    device_fingerprint: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # ── 1. Validate referrer ────────────────────────────────────────────────
    referrer = db.query(User).filter(User.referral_code == referral_code).first()
    if not referrer:
        raise HTTPException(404, "رمز الإحالة غير صحيح")
    if referrer.id == current_user.id:
        raise HTTPException(400, "لا يمكنك إحالة نفسك")

    # ── 2. Strict: this user was never referred before (globally) ──────────
    already_referred = (
        db.query(Referral).filter(Referral.referred_id == current_user.id).first()
    )
    if already_referred:
        raise HTTPException(400, "هذا المستخدم مُحال مسبقاً — لا يمكن تكرار الإحالة")

    # ── 3. Strict: device fingerprint never used in any referral ───────────
    if device_fingerprint:
        fp_existing = (
            db.query(Referral)
            .filter(Referral.device_fingerprint == device_fingerprint)
            .first()
        )
        if fp_existing:
            raise HTTPException(400, "هذا الجهاز مُستخدم مسبقاً في إحالة أخرى")

    # ── 4. Strict: referrer hasn't already referred this user ──────────────
    pair_existing = (
        db.query(Referral)
        .filter(
            Referral.referrer_id == referrer.id,
            Referral.referred_id == current_user.id,
        )
        .first()
    )
    if pair_existing:
        raise HTTPException(400, "لقد قمت بإحالة هذا المستخدم من قبل")

    # ── 5. Determine which level this referral belongs to ───────────────────
    referral_level = referrer.referral_level  # 1 until locked, then 2

    # ── 6. Create referral record ───────────────────────────────────────────
    referral = Referral(
        referrer_id=referrer.id,
        referred_id=current_user.id,
        device_fingerprint=device_fingerprint,
        is_verified=True,
        level=referral_level,
    )
    current_user.referred_by_id = referrer.id
    db.add(referral)
    db.commit()

    # ── 7. Check level promotion after committing ───────────────────────────
    _update_referrer_level(referrer, db)

    # Refresh to get updated values
    db.refresh(referrer)

    # ── 8. Build response ───────────────────────────────────────────────────
    verified_now = (
        db.query(Referral)
        .filter(Referral.referrer_id == referrer.id, Referral.is_verified == True)
        .count()
    )

    msg: dict = {
        "message": "تمت الإحالة بنجاح",
        "referrer_level": referrer.referral_level,
        "level1_locked": referrer.level1_locked,
        "verified_count": verified_now,
    }
    if referrer.level1_locked and verified_now == LEVEL1_TARGET:
        msg["level_up"] = True
        msg["message"] = (
            "تمت الإحالة بنجاح! وصلت إلى 50 إحالة — "
            "تم إغلاق المستوى الأول وترقيتك للمستوى الثاني 🎉"
        )

    return msg


@router.get("/all", response_model=List[ReferralResponse])
def all_referrals(current_user=Depends(require_admin), db: Session = Depends(get_db)):
    return db.query(Referral).order_by(Referral.created_at.desc()).all()


@router.get("/user/{user_id}", response_model=List[ReferralResponse])
def user_referrals(
    user_id: int,
    current_user=Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin: get all referrals made by a specific user, grouped by level."""
    return (
        db.query(Referral)
        .filter(Referral.referrer_id == user_id)
        .order_by(Referral.level, Referral.created_at)
        .all()
    )
