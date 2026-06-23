from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional, List
from datetime import datetime, date, timedelta
from backend.core.database import get_db
from backend.models.daily_close import DailyClose, DailyExpense, DailyAward
from backend.models.order import Order, OrderStatus, OrderType
from backend.models.purchase_invoice import PurchaseInvoice
from backend.models.capital import CapitalTransaction, CapitalTransactionType
from backend.api.dependencies import get_admin_user, require_staff_or_above
from backend.api.routes.audit import log_action
from backend.models.audit_log import AuditAction
from pydantic import BaseModel

router = APIRouter()


# ── Daily Expense ──────────────────────────────────────────────────────────────

class ExpenseCreate(BaseModel):
    description: str
    amount: float
    category: Optional[str] = None
    expense_date: Optional[date] = None
    notes: Optional[str] = None


class AwardCreate(BaseModel):
    recipient_name: str
    recipient_phone: Optional[str] = None
    customer_id: Optional[int] = None
    amount: float
    reason: Optional[str] = None
    award_date: Optional[date] = None


@router.post("/expenses")
def add_expense(
    data: ExpenseCreate,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    if data.amount <= 0:
        raise HTTPException(400, "المبلغ يجب أن يكون أكبر من صفر")
    expense = DailyExpense(
        description=data.description,
        amount=data.amount,
        category=data.category,
        expense_date=data.expense_date or date.today(),
        notes=data.notes,
        recorded_by_id=admin.id,
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    log_action(db, admin, AuditAction.create, entity_type="expense", entity_id=expense.id,
               description=f"مصروف جديد: {data.description} — {data.amount} ريال")
    db.commit()
    return {"id": expense.id, "message": "تم تسجيل المصروف"}


@router.get("/expenses")
def list_expenses(
    expense_date: Optional[date] = None,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    q = db.query(DailyExpense)
    if expense_date:
        q = q.filter(DailyExpense.expense_date == expense_date)
    else:
        q = q.filter(DailyExpense.expense_date == date.today())
    expenses = q.order_by(DailyExpense.created_at.desc()).all()
    return [
        {
            "id": e.id,
            "description": e.description,
            "amount": e.amount,
            "category": e.category,
            "expense_date": str(e.expense_date),
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "notes": e.notes,
            "recorded_by": e.recorded_by.name if e.recorded_by else None,
        }
        for e in expenses
    ]


@router.delete("/expenses/{expense_id}")
def delete_expense(
    expense_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    expense = db.query(DailyExpense).filter(DailyExpense.id == expense_id).first()
    if not expense:
        raise HTTPException(404, "المصروف غير موجود")
    log_action(db, admin, AuditAction.delete, entity_type="expense", entity_id=expense_id,
               description=f"حذف مصروف: {expense.description} — {expense.amount} ريال")
    db.delete(expense)
    db.commit()
    return {"message": "تم حذف المصروف"}


# ── Daily Awards ───────────────────────────────────────────────────────────────

@router.post("/awards")
def add_award(
    data: AwardCreate,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    if data.amount <= 0:
        raise HTTPException(400, "مبلغ الجائزة يجب أن يكون أكبر من صفر")
    award = DailyAward(
        recipient_name=data.recipient_name,
        recipient_phone=data.recipient_phone,
        customer_id=data.customer_id,
        amount=data.amount,
        reason=data.reason,
        award_date=data.award_date or date.today(),
        recorded_by_id=admin.id,
    )
    db.add(award)
    db.commit()
    db.refresh(award)
    log_action(db, admin, AuditAction.create, entity_type="award", entity_id=award.id,
               description=f"جائزة لـ {data.recipient_name} — {data.amount} ريال — {data.reason or ''}")
    db.commit()
    return {"id": award.id, "message": "تم تسجيل الجائزة"}


@router.get("/awards")
def list_awards(
    award_date: Optional[date] = None,
    db: Session = Depends(get_db),
    admin=Depends(require_staff_or_above),
):
    q = db.query(DailyAward)
    if award_date:
        q = q.filter(DailyAward.award_date == award_date)
    else:
        q = q.filter(DailyAward.award_date == date.today())
    awards = q.order_by(DailyAward.created_at.desc()).all()
    return [
        {
            "id": a.id,
            "recipient_name": a.recipient_name,
            "recipient_phone": a.recipient_phone,
            "amount": a.amount,
            "reason": a.reason,
            "award_date": str(a.award_date),
        }
        for a in awards
    ]


# ── Daily Close ────────────────────────────────────────────────────────────────

class DailyCloseCreate(BaseModel):
    close_date: Optional[date] = None
    opening_balance: float = 0.0
    notes: Optional[str] = None


@router.post("/close")
def create_daily_close(
    data: DailyCloseCreate,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    """إغلاق الصندوق اليومي — يجمع تلقائياً كل حركات اليوم."""
    target_date = data.close_date or date.today()

    existing = db.query(DailyClose).filter(DailyClose.close_date == target_date).first()
    if existing and existing.is_finalized:
        raise HTTPException(400, f"الصندوق بتاريخ {target_date} مغلق بالفعل ونهائي — لا يمكن إعادة إغلاقه")

    # ── جمع المبيعات والصيانة ──
    start_dt = datetime.combine(target_date, datetime.min.time())
    end_dt = datetime.combine(target_date, datetime.max.time())

    sales_q = db.query(func.sum(Order.total)).filter(
        Order.order_type == OrderType.product,
        Order.status == OrderStatus.delivered,
        Order.created_at.between(start_dt, end_dt),
    )
    total_sales = sales_q.scalar() or 0.0

    maint_q = db.query(func.sum(Order.total)).filter(
        Order.order_type == OrderType.maintenance,
        Order.status == OrderStatus.delivered,
        Order.created_at.between(start_dt, end_dt),
    )
    total_maintenance = maint_q.scalar() or 0.0

    # ── جمع المرتجعات (الطلبات الملغاة بعد التسليم) ──
    total_returns = db.query(func.sum(Order.total)).filter(
        Order.status == OrderStatus.cancelled,
        Order.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    # ── جمع المصروفات ──
    total_expenses = db.query(func.sum(DailyExpense.amount)).filter(
        DailyExpense.expense_date == target_date,
    ).scalar() or 0.0

    # ── جمع الجوائز ──
    total_awards = db.query(func.sum(DailyAward.amount)).filter(
        DailyAward.award_date == target_date,
    ).scalar() or 0.0

    # ── جمع المشتريات من الدرج ──
    total_purchases = db.query(func.sum(PurchaseInvoice.cash_from_drawer)).filter(
        PurchaseInvoice.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    # ── رأس المال (إيداعات/سحوبات المالك اليوم) ──
    cap_deposits = db.query(func.sum(CapitalTransaction.amount)).filter(
        CapitalTransaction.transaction_type == CapitalTransactionType.deposit,
        CapitalTransaction.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    cap_withdrawals = db.query(func.sum(CapitalTransaction.amount)).filter(
        CapitalTransaction.transaction_type == CapitalTransactionType.withdrawal,
        CapitalTransaction.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    # ── حساب الرصيد الختامي والربح الصافي ──
    closing_balance = (
        data.opening_balance
        + total_sales
        + total_maintenance
        + cap_deposits
        - total_returns
        - total_expenses
        - total_awards
        - total_purchases
        - cap_withdrawals
    )
    net_profit = (
        total_sales + total_maintenance
        - total_returns
        - total_expenses
        - total_awards
        - total_purchases
    )

    if existing:
        dc = existing
    else:
        dc = DailyClose(close_date=target_date)
        db.add(dc)

    dc.opening_balance = data.opening_balance
    dc.total_sales = round(total_sales, 2)
    dc.total_maintenance = round(total_maintenance, 2)
    dc.total_returns = round(total_returns, 2)
    dc.total_expenses = round(total_expenses, 2)
    dc.total_awards = round(total_awards, 2)
    dc.total_purchases = round(total_purchases, 2)
    dc.capital_deposited = round(cap_deposits, 2)
    dc.owner_withdrawals = round(cap_withdrawals, 2)
    dc.closing_balance = round(closing_balance, 2)
    dc.net_profit = round(net_profit, 2)
    dc.notes = data.notes
    dc.is_finalized = True
    dc.finalized_by_id = admin.id
    dc.finalized_at = datetime.utcnow()

    db.commit()
    db.refresh(dc)
    log_action(db, admin, AuditAction.create, entity_type="daily_close", entity_id=dc.id,
               description=f"إغلاق صندوق يوم {target_date} — رصيد ختامي: {round(closing_balance,2)} ريال")
    db.commit()

    return {
        "id": dc.id,
        "close_date": str(dc.close_date),
        "opening_balance": dc.opening_balance,
        "total_sales": dc.total_sales,
        "total_maintenance": dc.total_maintenance,
        "total_returns": dc.total_returns,
        "total_expenses": dc.total_expenses,
        "total_awards": dc.total_awards,
        "total_purchases": dc.total_purchases,
        "capital_deposited": dc.capital_deposited,
        "owner_withdrawals": dc.owner_withdrawals,
        "closing_balance": dc.closing_balance,
        "net_profit": dc.net_profit,
        "is_finalized": dc.is_finalized,
        "message": f"✅ تم إغلاق صندوق يوم {target_date} بنجاح",
    }


@router.get("/close")
def list_daily_closes(
    limit: int = 30,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    closes = db.query(DailyClose).order_by(DailyClose.close_date.desc()).limit(limit).all()
    return [
        {
            "id": c.id,
            "close_date": str(c.close_date),
            "opening_balance": c.opening_balance,
            "total_sales": c.total_sales,
            "total_maintenance": c.total_maintenance,
            "total_expenses": c.total_expenses,
            "total_awards": c.total_awards,
            "total_purchases": c.total_purchases,
            "capital_deposited": c.capital_deposited,
            "owner_withdrawals": c.owner_withdrawals,
            "closing_balance": c.closing_balance,
            "net_profit": c.net_profit,
            "is_finalized": c.is_finalized,
            "finalized_by": c.finalized_by.name if c.finalized_by else None,
            "finalized_at": c.finalized_at.isoformat() if c.finalized_at else None,
        }
        for c in closes
    ]


@router.get("/close/preview")
def preview_daily_close(
    target_date: Optional[date] = None,
    opening_balance: float = 0.0,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    """معاينة أرقام إغلاق الصندوق قبل التأكيد النهائي."""
    target_date = target_date or date.today()
    start_dt = datetime.combine(target_date, datetime.min.time())
    end_dt = datetime.combine(target_date, datetime.max.time())

    total_sales = db.query(func.sum(Order.total)).filter(
        Order.order_type == OrderType.product,
        Order.status == OrderStatus.delivered,
        Order.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    total_maintenance = db.query(func.sum(Order.total)).filter(
        Order.order_type == OrderType.maintenance,
        Order.status == OrderStatus.delivered,
        Order.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    total_expenses = db.query(func.sum(DailyExpense.amount)).filter(
        DailyExpense.expense_date == target_date,
    ).scalar() or 0.0

    total_awards = db.query(func.sum(DailyAward.amount)).filter(
        DailyAward.award_date == target_date,
    ).scalar() or 0.0

    total_purchases = db.query(func.sum(PurchaseInvoice.cash_from_drawer)).filter(
        PurchaseInvoice.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    total_returns_preview = db.query(func.sum(Order.total)).filter(
        Order.status == OrderStatus.cancelled,
        Order.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    expenses_list = db.query(DailyExpense).filter(DailyExpense.expense_date == target_date).all()
    awards_list = db.query(DailyAward).filter(DailyAward.award_date == target_date).all()

    cap_deposits = db.query(func.sum(CapitalTransaction.amount)).filter(
        CapitalTransaction.transaction_type == CapitalTransactionType.deposit,
        CapitalTransaction.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    cap_withdrawals = db.query(func.sum(CapitalTransaction.amount)).filter(
        CapitalTransaction.transaction_type == CapitalTransactionType.withdrawal,
        CapitalTransaction.created_at.between(start_dt, end_dt),
    ).scalar() or 0.0

    closing_balance = (
        opening_balance + total_sales + total_maintenance
        + cap_deposits
        - total_returns_preview
        - total_expenses - total_awards - total_purchases
        - cap_withdrawals
    )
    net_profit = (
        total_sales + total_maintenance
        - total_returns_preview
        - total_expenses - total_awards - total_purchases
    )

    return {
        "date": str(target_date),
        "opening_balance": opening_balance,
        "total_sales": round(total_sales, 2),
        "total_maintenance": round(total_maintenance, 2),
        "total_returns": round(total_returns_preview, 2),
        "total_expenses": round(total_expenses, 2),
        "total_awards": round(total_awards, 2),
        "total_purchases": round(total_purchases, 2),
        "capital_deposited": round(cap_deposits, 2),
        "owner_withdrawals": round(cap_withdrawals, 2),
        "closing_balance": round(closing_balance, 2),
        "net_profit": round(net_profit, 2),
        "expenses_detail": [{"desc": e.description, "amount": e.amount, "category": e.category} for e in expenses_list],
        "awards_detail": [{"name": a.recipient_name, "amount": a.amount} for a in awards_list],
    }
