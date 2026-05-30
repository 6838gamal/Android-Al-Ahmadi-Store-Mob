from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ReferralResponse(BaseModel):
    id: int
    referrer_id: int
    referred_id: int
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ReferralStatsResponse(BaseModel):
    referral_code: str
    referral_link: str
    total_referrals: int
    verified_referrals: int
    target: int = 50
