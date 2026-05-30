from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from backend.models.wallet import TransactionType, WalletCurrency


class WalletTransactionCreate(BaseModel):
    user_id: int
    amount: float
    currency: WalletCurrency = WalletCurrency.YER
    transaction_type: TransactionType
    reason: Optional[str] = None
    reference_id: Optional[str] = None
    reference_type: Optional[str] = None
    notes: Optional[str] = None


class WalletTransactionResponse(BaseModel):
    id: int
    user_id: int
    amount: float
    currency: WalletCurrency
    transaction_type: TransactionType
    reason: Optional[str]
    reference_id: Optional[str]
    balance_after: Optional[float]
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class WalletResponse(BaseModel):
    balance: float
    currency: str
    transactions: List[WalletTransactionResponse]
