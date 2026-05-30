from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from backend.core.database import get_db
from backend.models.user import User
from backend.models.wallet import WalletTransaction, TransactionType, WalletCurrency
from backend.schemas.wallet import WalletTransactionCreate, WalletTransactionResponse, WalletResponse
from backend.api.dependencies import get_current_user, require_admin

router = APIRouter()


def _apply_transaction(db: Session, user: User, amount: float, currency: str,
                        tx_type: TransactionType, reason: str = None,
                        ref_id: str = None, ref_type: str = None) -> WalletTransaction:
    if tx_type == TransactionType.credit:
        user.wallet_balance = (user.wallet_balance or 0.0) + amount
    else:
        user.wallet_balance = (user.wallet_balance or 0.0) - amount

    tx = WalletTransaction(
        user_id=user.id,
        amount=amount,
        currency=currency,
        transaction_type=tx_type,
        reason=reason,
        reference_id=ref_id,
        reference_type=ref_type,
        balance_after=user.wallet_balance,
    )
    db.add(tx)
    return tx


@router.get("/my", response_model=WalletResponse)
def my_wallet(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    txs = db.query(WalletTransaction).filter(
        WalletTransaction.user_id == current_user.id
    ).order_by(WalletTransaction.created_at.desc()).limit(50).all()
    return WalletResponse(
        balance=current_user.wallet_balance or 0.0,
        currency=current_user.wallet_currency or "YER",
        transactions=txs,
    )


@router.post("/credit")
def credit_wallet(data: WalletTransactionCreate, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    user = db.query(User).filter(User.id == data.user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    _apply_transaction(db, user, data.amount, data.currency.value, TransactionType.credit, data.reason, data.reference_id, data.reference_type)
    db.commit()
    return {"message": "Wallet credited", "new_balance": user.wallet_balance}


@router.post("/debit")
def debit_wallet(data: WalletTransactionCreate, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    user = db.query(User).filter(User.id == data.user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    _apply_transaction(db, user, data.amount, data.currency.value, TransactionType.debit, data.reason, data.reference_id, data.reference_type)
    db.commit()
    return {"message": "Wallet debited", "new_balance": user.wallet_balance}


@router.get("/user/{user_id}", response_model=WalletResponse)
def user_wallet(user_id: int, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")
    txs = db.query(WalletTransaction).filter(
        WalletTransaction.user_id == user_id
    ).order_by(WalletTransaction.created_at.desc()).limit(100).all()
    return WalletResponse(balance=user.wallet_balance or 0.0, currency=user.wallet_currency or "YER", transactions=txs)
