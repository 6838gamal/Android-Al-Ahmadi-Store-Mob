from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
from datetime import datetime, date
from backend.core.database import get_db
from backend.models.capital import CapitalTransaction, CapitalTransactionType
from backend.api.dependencies import get_admin_user
from pydantic import BaseModel
from backend.api.routes.audit import log_action
from backend.models.audit_log import AuditAction

router = APIRouter()


class CapitalTransactionCreate(BaseModel):
    transaction_type: CapitalTransactionType
    amount: float
    reason: Optional[str] = None
    notes: Optional[str] = None
    reference_number: Optional[str] = None


class CapitalTransactionResponse(BaseModel):
    id: int
    transaction_type: CapitalTransactionType
    amount: float
    reason: Optional[str]
    notes: Optional[str]
    reference_number: Optional[str]
    recorded_by_id: Optional[int]
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/", response_model=CapitalTransactionResponse)
def record_capital_transaction(
    data: CapitalTransactionCreate,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    if data.amount <= 0:
        raise HTTPException(400, "المبلغ يجب أن يكون أكبر من صفر")
    tx = CapitalTransaction(
        transaction_type=data.transaction_type,
        amount=data.amount,
        reason=data.reason,
        notes=data.notes,
        reference_number=data.reference_number,
        recorded_by_id=admin.id,
    )
    db.add(tx)
    db.flush()
    log_action(db, admin, AuditAction.create, entity_type="capital_transaction", entity_id=tx.id,
               after={"type": str(data.transaction_type), "amount": data.amount,
                      "reason": data.reason},
               description=f"رأس مال — {data.transaction_type.value}: {data.amount:,.0f} ريال | {data.reason or ''}")
    db.commit()
    db.refresh(tx)
    return tx


@router.get("/")
def list_capital_transactions(
    transaction_type: Optional[CapitalTransactionType] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    q = db.query(CapitalTransaction)
    if transaction_type:
        q = q.filter(CapitalTransaction.transaction_type == transaction_type)
    transactions = q.order_by(CapitalTransaction.created_at.desc()).offset(skip).limit(limit).all()
    return transactions


@router.get("/summary")
def capital_summary(db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    """ملخص رأس المال: إجمالي الإيداعات والسحوبات وصافي رأس المال المتاح."""
    total_deposits = db.query(func.sum(CapitalTransaction.amount)).filter(
        CapitalTransaction.transaction_type == CapitalTransactionType.deposit
    ).scalar() or 0.0

    total_withdrawals = db.query(func.sum(CapitalTransaction.amount)).filter(
        CapitalTransaction.transaction_type == CapitalTransactionType.withdrawal
    ).scalar() or 0.0

    net_capital = total_deposits - total_withdrawals

    return {
        "total_deposits": round(total_deposits, 2),
        "total_withdrawals": round(total_withdrawals, 2),
        "net_capital": round(net_capital, 2),
    }


@router.delete("/{tx_id}")
def delete_capital_transaction(
    tx_id: int,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    tx = db.query(CapitalTransaction).filter(CapitalTransaction.id == tx_id).first()
    if not tx:
        raise HTTPException(404, "السجل غير موجود")
    log_action(db, admin, AuditAction.delete, entity_type="capital_transaction", entity_id=tx.id,
               before={"type": str(tx.transaction_type), "amount": tx.amount, "reason": tx.reason},
               description=f"حذف معاملة رأس مال: {tx.transaction_type.value} {tx.amount:,.0f} ريال")
    db.delete(tx)
    db.commit()
    return {"message": "تم حذف السجل"}
