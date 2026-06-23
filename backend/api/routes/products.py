from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from backend.core.database import get_db
from backend.models.product import Product, ProductStatus, ProductCategory
from backend.schemas.product import ProductCreate, ProductUpdate, ProductResponse
from backend.api.dependencies import get_admin_user, get_current_user
from backend.models.user import User
from backend.core.samsung_catalog import get_catalog_tree, MODEL_TO_SERIES, ALL_MODEL_KEYS
from backend.core.notifications_helper import push_notification
from backend.models.notification import NotificationType
from backend.api.routes.audit import log_action
from backend.models.audit_log import AuditAction

router = APIRouter()


@router.get("/catalog/samsung", tags=["Products"])
def samsung_catalog():
    """Return the full Samsung series → model folder structure."""
    return get_catalog_tree()


@router.get("/", response_model=List[ProductResponse])
def get_products(
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
    category: Optional[ProductCategory] = None,
    status: Optional[ProductStatus] = None,
    brand: Optional[str] = None,
    series: Optional[str] = None,
    model: Optional[str] = None,
    is_featured: Optional[bool] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Product).filter(Product.is_active == True)
    if search:
        query = query.filter(
            Product.name.ilike(f"%{search}%") |
            Product.name_ar.ilike(f"%{search}%") |
            Product.brand.ilike(f"%{search}%") |
            Product.model.ilike(f"%{search}%")
        )
    if category:
        query = query.filter(Product.category == category)
    if status:
        query = query.filter(Product.status == status)
    if brand:
        query = query.filter(Product.brand.ilike(f"%{brand}%"))
    if series:
        query = query.filter(Product.series == series)
    if model:
        query = query.filter(Product.model == model)
    if is_featured is not None:
        query = query.filter(Product.is_featured == is_featured)
    return query.offset(skip).limit(limit).all()


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.post("/", response_model=ProductResponse)
def create_product(
    product_data: ProductCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    data = product_data.dict()
    # Auto-detect series from model key if not explicitly set
    if not data.get("series") and data.get("model") in MODEL_TO_SERIES:
        data["series"] = MODEL_TO_SERIES[data["model"]]
    product = Product(**data)
    db.add(product)
    db.commit()
    db.refresh(product)
    log_action(db, admin, AuditAction.create, entity_type="product", entity_id=product.id,
               description=f"إضافة منتج: {product.name}")
    db.commit()
    return product


@router.put("/{product_id}", response_model=ProductResponse)
def update_product(
    product_id: int,
    product_data: ProductUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    data = product_data.dict(exclude_unset=True)
    # Auto-detect series when model is updated
    if "model" in data and not data.get("series") and data["model"] in MODEL_TO_SERIES:
        data["series"] = MODEL_TO_SERIES[data["model"]]
    for field, value in data.items():
        setattr(product, field, value)
    db.commit()
    db.refresh(product)
    log_action(db, admin, AuditAction.update, entity_type="product", entity_id=product.id,
               description=f"تعديل منتج: {product.name}")
    db.commit()
    return product


@router.delete("/{product_id}")
def delete_product(
    product_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user)
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    log_action(db, admin, AuditAction.delete, entity_type="product", entity_id=product.id,
               description=f"حذف منتج: {product.name}")
    product.is_active = False
    db.commit()
    return {"message": "Product deleted"}


@router.post("/{product_id}/restock-request")
def request_restock(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Customer requests restocking of a sold/unavailable product."""
    product = db.query(Product).filter(Product.id == product_id, Product.is_active == True).first()
    if not product:
        raise HTTPException(status_code=404, detail="المنتج غير موجود")
    admins = db.query(User).filter(User.role == "admin").all()
    for admin in admins:
        push_notification(
            db, admin.id,
            title="📦 طلب إعادة توفير منتج",
            body=f"طلب {current_user.name} إعادة توفير: {product.name}",
            notif_type=NotificationType.system,
            is_important=True,
            reference_id=product_id,
            reference_type="product",
        )
    db.commit()
    return {"message": "تم إرسال طلب إعادة التوفير بنجاح، سيتم إشعارك عند توفّره"}
