from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from backend.core.database import get_db
from backend.models.order import Order, OrderStatus, OrderType
from backend.models.product import Product, ProductStatus
from backend.models.reservation import Reservation
from backend.models.user import User, UserRole
from backend.api.dependencies import get_admin_user

router = APIRouter()


@router.get("/stats")
def get_dashboard_stats(db: Session = Depends(get_db), admin: User = Depends(get_admin_user)):
    total_orders = db.query(Order).count()
    delivered_orders = db.query(Order).filter(Order.status == OrderStatus.delivered).count()
    active_orders = db.query(Order).filter(
        Order.status.not_in([OrderStatus.delivered, OrderStatus.cancelled])
    ).count()
    total_revenue = db.query(func.sum(Order.total)).filter(Order.status == OrderStatus.delivered).scalar() or 0
    maintenance_count = db.query(Order).filter(Order.order_type == OrderType.maintenance).count()
    active_reservations = db.query(Reservation).count()
    total_products = db.query(Product).filter(Product.is_active == True).count()
    available_products = db.query(Product).filter(Product.status == ProductStatus.available).count()
    low_stock = db.query(Product).filter(Product.quantity <= 3, Product.is_active == True).count()
    total_customers = db.query(User).filter(User.role == UserRole.customer).count()

    recent_orders = db.query(Order).order_by(Order.created_at.desc()).limit(5).all()

    return {
        "total_orders": total_orders,
        "delivered_orders": delivered_orders,
        "active_orders": active_orders,
        "total_revenue": round(total_revenue, 2),
        "maintenance_count": maintenance_count,
        "active_reservations": active_reservations,
        "total_products": total_products,
        "available_products": available_products,
        "low_stock_count": low_stock,
        "total_customers": total_customers,
        "recent_orders": [
            {
                "id": o.id,
                "order_number": o.order_number,
                "customer_name": o.customer_name,
                "status": o.status.value,
                "total": o.total,
                "created_at": o.created_at.isoformat() if o.created_at else None,
            }
            for o in recent_orders
        ],
    }
