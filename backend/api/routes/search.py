from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from backend.core.database import get_db
from backend.models.product import Product
from backend.models.order import Order
from backend.models.user import User, UserRole
from backend.models.inventory_item import InventoryItem
from backend.api.dependencies import get_current_user_optional, require_staff_or_above

router = APIRouter()


@router.get("/")
def global_search(
    q: str = Query(..., min_length=2),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional)
):
    is_staff = bool(current_user and current_user.role in [UserRole.staff, UserRole.branch_manager, UserRole.admin])
    results = {}

    # Products — visible to all
    products = db.query(Product).filter(
        Product.is_active == True,
        (Product.name.ilike(f"%{q}%") | Product.name_ar.ilike(f"%{q}%") |
         Product.brand.ilike(f"%{q}%") | Product.model.ilike(f"%{q}%"))
    ).limit(10).all()
    results["products"] = [{"id": p.id, "name": p.name, "brand": p.brand, "model": p.model,
                            "price": p.price, "status": p.status.value, "image_url": p.image_url} for p in products]

    if is_staff:
        # Orders
        orders = db.query(Order).filter(
            Order.order_number.ilike(f"%{q}%") |
            Order.customer_name.ilike(f"%{q}%") |
            Order.customer_phone.ilike(f"%{q}%")
        ).limit(10).all()
        results["orders"] = [{"id": o.id, "order_number": o.order_number,
                              "customer_name": o.customer_name, "status": o.status.value,
                              "total": o.total} for o in orders]

        # Customers
        customers = db.query(User).filter(
            User.role == UserRole.customer,
            (User.name.ilike(f"%{q}%") | User.phone.ilike(f"%{q}%") | User.email.ilike(f"%{q}%"))
        ).limit(10).all()
        results["customers"] = [{"id": c.id, "name": c.name, "phone": c.phone, "email": c.email} for c in customers]

        # Inventory
        items = db.query(InventoryItem).filter(
            InventoryItem.is_active == True,
            (InventoryItem.serial_number.ilike(f"%{q}%") |
             InventoryItem.brand.ilike(f"%{q}%") |
             InventoryItem.model.ilike(f"%{q}%"))
        ).limit(10).all()
        results["inventory"] = [{"id": i.id, "serial_number": i.serial_number,
                                 "brand": i.brand, "model": i.model,
                                 "grade": i.grade.value, "status": i.status.value} for i in items]
    elif current_user:
        # Logged-in customer: show own orders only
        orders = db.query(Order).filter(
            Order.customer_id == current_user.id,
            (Order.order_number.ilike(f"%{q}%"))
        ).limit(5).all()
        results["orders"] = [{"id": o.id, "order_number": o.order_number,
                              "status": o.status.value} for o in orders]

    return results
