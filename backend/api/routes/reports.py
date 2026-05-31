from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
from datetime import datetime, timedelta
from backend.core.database import get_db
from backend.models.order import Order, OrderStatus, OrderType
from backend.models.product import Product
from backend.models.user import User, UserRole
from backend.models.inventory_item import InventoryItem, ItemStatus
from backend.models.referral import Referral
from backend.models.warranty import Warranty
from backend.api.dependencies import require_branch_manager_or_above

router = APIRouter()


def _date_range(period: str):
    now = datetime.utcnow()
    if period == "today":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "week":
        start = now - timedelta(days=7)
    elif period == "month":
        start = now - timedelta(days=30)
    elif period == "year":
        start = now - timedelta(days=365)
    else:
        start = None
    return start, now


def _apply_branch_filter(query, model, current_user):
    """Filter query to branch_manager's branch when applicable."""
    if current_user.role == UserRole.branch_manager and current_user.branch_id:
        if hasattr(model, "branch_id"):
            query = query.filter(model.branch_id == current_user.branch_id)
    return query


@router.get("/sales")
def sales_report(
    period: str = "month",
    db: Session = Depends(get_db),
    current_user=Depends(require_branch_manager_or_above)
):
    start, end = _date_range(period)
    q = db.query(Order).filter(Order.order_type == OrderType.product, Order.status == OrderStatus.delivered)
    q = _apply_branch_filter(q, Order, current_user)
    if start:
        q = q.filter(Order.created_at >= start)
    orders = q.all()
    total_revenue = sum(o.total for o in orders)
    total_orders = len(orders)
    avg_order = total_revenue / total_orders if total_orders else 0
    return {
        "period": period,
        "branch_id": current_user.branch_id if current_user.role == UserRole.branch_manager else None,
        "total_orders": total_orders,
        "total_revenue": round(total_revenue, 2),
        "average_order_value": round(avg_order, 2),
        "orders": [{"id": o.id, "order_number": o.order_number, "customer_name": o.customer_name,
                    "total": o.total, "created_at": str(o.created_at)} for o in orders[:50]],
    }


@router.get("/profit")
def profit_report(
    period: str = "month",
    db: Session = Depends(get_db),
    current_user=Depends(require_branch_manager_or_above)
):
    start, end = _date_range(period)
    q = db.query(Order).filter(Order.status == OrderStatus.delivered)
    q = _apply_branch_filter(q, Order, current_user)
    if start:
        q = q.filter(Order.created_at >= start)
    orders = q.all()
    total_revenue = sum(o.total for o in orders)
    total_discount = sum(o.discount or 0 for o in orders)
    return {
        "period": period,
        "branch_id": current_user.branch_id if current_user.role == UserRole.branch_manager else None,
        "total_revenue": round(total_revenue, 2),
        "total_discount": round(total_discount, 2),
        "net_revenue": round(total_revenue - total_discount, 2),
        "total_transactions": len(orders),
    }


@router.get("/inventory")
def inventory_report(
    db: Session = Depends(get_db),
    current_user=Depends(require_branch_manager_or_above)
):
    q = db.query(InventoryItem).filter(InventoryItem.is_active == True)
    q = _apply_branch_filter(q, InventoryItem, current_user)

    total = q.count()
    available = q.filter(InventoryItem.status == ItemStatus.available).count()
    sold = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.sold)
    sold = _apply_branch_filter(sold, InventoryItem, current_user)
    reserved = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.reserved)
    reserved = _apply_branch_filter(reserved, InventoryItem, current_user)

    low_stock_q = db.query(Product).filter(Product.is_active == True, Product.quantity <= 3)
    if current_user.role == UserRole.branch_manager and current_user.branch_id:
        low_stock_q = low_stock_q.filter(Product.branch_id == current_user.branch_id)
    low_stock_products = low_stock_q.all()

    return {
        "branch_id": current_user.branch_id if current_user.role == UserRole.branch_manager else None,
        "total_items": total,
        "available": available,
        "sold": sold.count(),
        "reserved": reserved.count(),
        "low_stock_products": [{"id": p.id, "name": p.name, "quantity": p.quantity} for p in low_stock_products],
    }


@router.get("/maintenance")
def maintenance_report(
    period: str = "month",
    db: Session = Depends(get_db),
    current_user=Depends(require_branch_manager_or_above)
):
    start, end = _date_range(period)
    q = db.query(Order).filter(Order.order_type == OrderType.maintenance)
    q = _apply_branch_filter(q, Order, current_user)
    if start:
        q = q.filter(Order.created_at >= start)
    orders = q.all()
    completed = [o for o in orders if o.status == OrderStatus.delivered]
    total_revenue = sum(o.total for o in completed)
    return {
        "period": period,
        "branch_id": current_user.branch_id if current_user.role == UserRole.branch_manager else None,
        "total_requests": len(orders),
        "completed": len(completed),
        "total_revenue": round(total_revenue, 2),
    }


@router.get("/referrals")
def referral_report(db: Session = Depends(get_db), current_user=Depends(require_branch_manager_or_above)):
    total = db.query(Referral).count()
    verified = db.query(Referral).filter(Referral.is_verified == True).count()
    top_referrers = (
        db.query(User.name, User.phone, func.count(Referral.id).label("count"))
        .join(Referral, Referral.referrer_id == User.id)
        .group_by(User.id)
        .order_by(func.count(Referral.id).desc())
        .limit(10)
        .all()
    )
    return {
        "total_referrals": total,
        "verified_referrals": verified,
        "top_referrers": [{"name": r.name, "phone": r.phone, "count": r.count} for r in top_referrers],
    }


@router.get("/warranty")
def warranty_report(db: Session = Depends(get_db), current_user=Depends(require_branch_manager_or_above)):
    total = db.query(Warranty).count()
    return_requests = db.query(Warranty).filter(Warranty.is_return_requested == True).count()
    resolved = db.query(Warranty).filter(Warranty.return_resolved == True).count()
    return {
        "total_warranties": total,
        "return_requests": return_requests,
        "resolved_returns": resolved,
        "pending_returns": return_requests - resolved,
    }
