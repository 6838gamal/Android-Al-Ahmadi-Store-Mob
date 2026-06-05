from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.secret_deal import SecretDeal, SecretDealImage, SecretDealStatus
from backend.api.dependencies import get_admin_user
from pydantic import BaseModel

router = APIRouter()


def _gen_deal_number(db):
    count = db.query(SecretDeal).count() + 1
    return f"DEAL-{datetime.now().year}-{count:04d}"


def _gen_watermark_number(db, deal_id: int, image_index: int) -> str:
    deal = db.query(SecretDeal).filter(SecretDeal.id == deal_id).first()
    deal_num = deal.deal_number if deal else f"D{deal_id}"
    return f"{deal_num}-{image_index+1:03d}"


class SecretDealCreate(BaseModel):
    title: str
    description: Optional[str] = None
    supplier_name: Optional[str] = None
    supplier_phone: Optional[str] = None
    total_quantity: Optional[int] = 0
    price_per_unit: Optional[float] = None
    total_price: Optional[float] = None
    admin_notes: Optional[str] = None


class AddImagesRequest(BaseModel):
    image_urls: List[str]


class SecretDealResponse(BaseModel):
    id: int
    deal_number: str
    title: str
    description: Optional[str]
    supplier_name: Optional[str]
    supplier_phone: Optional[str]
    total_quantity: int
    price_per_unit: Optional[float]
    total_price: Optional[float]
    status: SecretDealStatus
    admin_notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/")
def create_secret_deal(data: SecretDealCreate, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    deal = SecretDeal(
        deal_number=_gen_deal_number(db),
        title=data.title,
        description=data.description,
        supplier_name=data.supplier_name,
        supplier_phone=data.supplier_phone,
        total_quantity=data.total_quantity or 0,
        price_per_unit=data.price_per_unit,
        total_price=data.total_price,
        admin_notes=data.admin_notes,
        created_by_id=admin.id,
    )
    db.add(deal)
    db.commit()
    db.refresh(deal)
    return deal


@router.get("/", response_model=List[SecretDealResponse])
def list_secret_deals(
    status: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    q = db.query(SecretDeal)
    if status:
        q = q.filter(SecretDeal.status == status)
    return q.order_by(SecretDeal.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{deal_id}")
def get_secret_deal(deal_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    deal = db.query(SecretDeal).filter(SecretDeal.id == deal_id).first()
    if not deal:
        raise HTTPException(status_code=404, detail="الصفقة غير موجودة")
    images = db.query(SecretDealImage).filter(SecretDealImage.deal_id == deal_id).order_by(SecretDealImage.display_order).all()
    return {
        "id": deal.id,
        "deal_number": deal.deal_number,
        "title": deal.title,
        "description": deal.description,
        "supplier_name": deal.supplier_name,
        "supplier_phone": deal.supplier_phone,
        "total_quantity": deal.total_quantity,
        "price_per_unit": deal.price_per_unit,
        "total_price": deal.total_price,
        "status": deal.status,
        "admin_notes": deal.admin_notes,
        "images": [{"id": i.id, "url": i.image_url, "watermark_number": i.watermark_number, "order": i.display_order} for i in images],
        "created_at": deal.created_at,
    }


@router.post("/{deal_id}/images")
def add_images_to_deal(deal_id: int, data: AddImagesRequest, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    deal = db.query(SecretDeal).filter(SecretDeal.id == deal_id).first()
    if not deal:
        raise HTTPException(status_code=404, detail="الصفقة غير موجودة")
    existing_count = db.query(SecretDealImage).filter(SecretDealImage.deal_id == deal_id).count()

    added = []
    for i, url in enumerate(data.image_urls):
        idx = existing_count + i
        wm = _gen_watermark_number(db, deal_id, idx)
        img = SecretDealImage(
            deal_id=deal_id,
            image_url=url,
            watermark_number=wm,
            display_order=idx,
        )
        db.add(img)
        added.append({"url": url, "watermark_number": wm})

    deal.total_quantity = existing_count + len(data.image_urls)
    db.commit()
    return {"message": f"تمت إضافة {len(added)} صورة بترقيم مائي تلقائي", "images": added}


@router.put("/{deal_id}/status")
def update_deal_status(deal_id: int, status: str, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    deal = db.query(SecretDeal).filter(SecretDeal.id == deal_id).first()
    if not deal:
        raise HTTPException(status_code=404, detail="الصفقة غير موجودة")
    deal.status = status
    db.commit()
    return {"message": "تم تحديث حالة الصفقة"}


@router.delete("/{deal_id}")
def delete_secret_deal(deal_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    deal = db.query(SecretDeal).filter(SecretDeal.id == deal_id).first()
    if not deal:
        raise HTTPException(status_code=404, detail="الصفقة غير موجودة")
    db.query(SecretDealImage).filter(SecretDealImage.deal_id == deal_id).delete()
    db.delete(deal)
    db.commit()
    return {"message": "تم حذف الصفقة"}
