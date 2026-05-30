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

REFERRAL_TARGET = 50


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


@router.get("/my-stats", response_model=ReferralStatsResponse)
def my_referral_stats(request: Request, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    code = _ensure_referral_code(current_user, db)
    base_url = str(request.base_url).rstrip("/")
    total = db.query(Referral).filter(Referral.referrer_id == current_user.id).count()
    verified = db.query(Referral).filter(Referral.referrer_id == current_user.id, Referral.is_verified == True).count()
    return ReferralStatsResponse(
        referral_code=code,
        referral_link=f"{base_url}/register?ref={code}",
        total_referrals=total,
        verified_referrals=verified,
        target=REFERRAL_TARGET,
    )


@router.post("/register-referral")
def register_referral(
    referral_code: str,
    device_fingerprint: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    referrer = db.query(User).filter(User.referral_code == referral_code).first()
    if not referrer:
        raise HTTPException(404, "Invalid referral code")
    if referrer.id == current_user.id:
        raise HTTPException(400, "Cannot refer yourself")

    existing = db.query(Referral).filter(Referral.referred_id == current_user.id).first()
    if existing:
        raise HTTPException(400, "User already has a referral")

    if device_fingerprint:
        fp_existing = db.query(Referral).filter(Referral.device_fingerprint == device_fingerprint).first()
        if fp_existing:
            raise HTTPException(400, "Device already used for a referral")

    referral = Referral(
        referrer_id=referrer.id,
        referred_id=current_user.id,
        device_fingerprint=device_fingerprint,
        is_verified=True,
    )
    current_user.referred_by_id = referrer.id
    db.add(referral)
    db.commit()
    return {"message": "Referral registered successfully"}


@router.get("/all", response_model=List[ReferralResponse])
def all_referrals(current_user=Depends(require_admin), db: Session = Depends(get_db)):
    return db.query(Referral).order_by(Referral.created_at.desc()).all()
