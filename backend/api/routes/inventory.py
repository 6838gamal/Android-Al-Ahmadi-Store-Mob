from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from backend.core.database import get_db
from backend.models.inventory_item import InventoryItem, ItemStatus, ItemGrade
from backend.schemas.inventory import InventoryItemCreate, InventoryItemUpdate, InventoryItemResponse
from backend.api.dependencies import get_current_user, require_staff_or_above, require_admin
from backend.core.notifications_helper import push_notification
from backend.models.notification import NotificationType

router = APIRouter()


@router.get("/", response_model=List[InventoryItemResponse])
def list_items(
    status: Optional[str] = None,
    grade: Optional[str] = None,
    category: Optional[str] = None,
    branch_id: Optional[int] = None,
    search: Optional[str] = None,
    skip: int = 0, limit: int = 50,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above)
):
    q = db.query(InventoryItem).filter(InventoryItem.is_active == True)
    if status:
        q = q.filter(InventoryItem.status == status)
    if grade:
        q = q.filter(InventoryItem.grade == grade)
    if category:
        q = q.filter(InventoryItem.category == category)
    if branch_id:
        q = q.filter(InventoryItem.branch_id == branch_id)
    if search:
        q = q.filter(
            InventoryItem.serial_number.ilike(f"%{search}%") |
            InventoryItem.brand.ilike(f"%{search}%") |
            InventoryItem.model.ilike(f"%{search}%")
        )
    return q.order_by(InventoryItem.created_at.desc()).offset(skip).limit(limit).all()


@router.post("/", response_model=InventoryItemResponse)
def create_item(data: InventoryItemCreate, db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    if data.serial_number:
        existing = db.query(InventoryItem).filter(InventoryItem.serial_number == data.serial_number).first()
        if existing:
            raise HTTPException(400, "Serial number already exists")
    item = InventoryItem(**data.model_dump())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/stats/summary")
def inventory_stats(db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    total = db.query(InventoryItem).filter(InventoryItem.is_active == True).count()
    available = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.available).count()
    reserved = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.reserved).count()
    sold = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.sold).count()
    return {"total": total, "available": available, "reserved": reserved, "sold": sold}


@router.get("/{item_id}", response_model=InventoryItemResponse)
def get_item(item_id: int, db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(404, "Item not found")
    return item


@router.put("/{item_id}", response_model=InventoryItemResponse)
def update_item(item_id: int, data: InventoryItemUpdate, db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(404, "Item not found")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(item, k, v)
    db.commit()
    db.refresh(item)
    return item


@router.post("/{item_id}/sell")
def mark_sold(
    item_id: int,
    customer_id: Optional[int] = None,
    order_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above),
):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(404, "Item not found")
    if item.status == ItemStatus.sold:
        raise HTTPException(400, "Item already sold")

    item.status = ItemStatus.sold
    if customer_id:
        item.sold_to_id = customer_id
    if order_id:
        item.sold_order_id = order_id

    if customer_id:
        item_label = f"{item.brand or ''} {item.model or ''}".strip() or item.serial_number or "الجهاز"
        push_notification(
            db, customer_id,
            title="📦 تم بيع الجهاز",
            body=f"تم تسجيل بيع {item_label} بنجاح. شكراً لثقتك بنا!",
            notif_type=NotificationType.order,
            reference_id=item.id,
            reference_type="inventory_item",
        )

    db.commit()
    return {"message": "Item marked as sold"}


@router.post("/{item_id}/return-to-stock")
def return_to_stock(
    item_id: int,
    customer_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above),
):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(404, "Item not found")

    item.status = ItemStatus.available
    item.sold_to_id = None
    item.sold_order_id = None

    if customer_id:
        item_label = f"{item.brand or ''} {item.model or ''}".strip() or item.serial_number or "الجهاز"
        push_notification(
            db, customer_id,
            title="🔄 تم إرجاع الجهاز",
            body=f"تم قبول إرجاع {item_label} وإعادته للمخزون.",
            notif_type=NotificationType.order,
            reference_id=item.id,
            reference_type="inventory_item",
        )

    db.commit()
    return {"message": "Item returned to stock"}


@router.delete("/{item_id}")
def delete_item(item_id: int, db: Session = Depends(get_db), current_user=Depends(require_admin)):
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if not item:
        raise HTTPException(404, "Item not found")
    item.is_active = False
    db.commit()
    return {"message": "Item removed"}
