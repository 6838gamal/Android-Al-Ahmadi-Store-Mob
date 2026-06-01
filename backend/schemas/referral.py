from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ReferralResponse(BaseModel):
    id: int
    referrer_id: int
    referred_id: int
    is_verified: bool
    level: int
    created_at: datetime

    class Config:
        from_attributes = True


class ReferralStatsResponse(BaseModel):
    referral_code: str
    referral_link: str
    total_referrals: int
    verified_referrals: int
    target: int = 50
    current_level: int
    level1_locked: bool
    level1_count: int
    level2_count: int
    progress_to_next: int
