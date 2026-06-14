from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
from backend.core.database import get_db
from backend.models.warranty import Warranty
from backend.models.user import User
from backend.schemas.warranty import WarrantyCreate, WarrantyResponse, ReturnRequest, ResolveReturn
from backend.api.dependencies import get_current_user, require_staff_or_above
from backend.core.notifications_helper import push_notification, push_notification_to_admins
from backend.models.notification import NotificationType

router = APIRouter()


@router.post("/", response_model=WarrantyResponse)
def create_warranty(data: WarrantyCreate, db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    starts = datetime.utcnow()
    ends = starts + __import__('datetime').timedelta(days=data.warranty_days)
    from datetime import timedelta
    ends = starts + timedelta(days=data.warranty_days)
    warranty = Warranty(
        order_id=data.order_id,
        customer_id=data.customer_id,
        product_name=data.product_name,
        product_serial=data.product_serial,
        purchase_price=data.purchase_price,
        warranty_days=data.warranty_days,
        starts_at=starts,
        ends_at=ends,
    )
    db.add(warranty)
    db.flush()

    if data.customer_id:
        push_notification(
            db, data.customer_id,
            title="✅ تم تسجيل ضمانك",
            body=f"تم تسجيل ضمان المنتج: {data.product_name} لمدة {data.warranty_days} أيام",
            notif_type=NotificationType.warranty,
            is_important=True,
            reference_id=warranty.id,
            reference_type="warranty",
        )

    db.commit()
    db.refresh(warranty)
    return warranty


@router.get("/my", response_model=List[WarrantyResponse])
def my_warranties(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Warranty).filter(Warranty.customer_id == current_user.id).order_by(Warranty.created_at.desc()).all()


@router.get("/", response_model=List[WarrantyResponse])
def list_warranties(db: Session = Depends(get_db), current_user=Depends(require_staff_or_above)):
    return db.query(Warranty).order_by(Warranty.created_at.desc()).all()


@router.get("/{warranty_id}", response_model=WarrantyResponse)
def get_warranty(warranty_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    return w


@router.post("/{warranty_id}/request-return")
def request_return(warranty_id: int, data: ReturnRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    if w.customer_id != current_user.id:
        raise HTTPException(403, "Not your warranty")
    if datetime.utcnow() > w.ends_at:
        raise HTTPException(400, "انتهت مدة الضمان")
    if w.is_return_requested:
        raise HTTPException(400, "تم تقديم طلب الإرجاع مسبقاً")

    w.is_return_requested = True
    w.return_reason = data.return_reason
    w.return_requested_at = datetime.utcnow()

    push_notification_to_admins(
        db,
        title="🔔 طلب إرجاع ضمان جديد",
        body=f"العميل {current_user.name} يطلب إرجاع: {w.product_name}. السبب: {data.return_reason}",
        notif_type=NotificationType.warranty,
        is_important=True,
        reference_id=w.id,
        reference_type="warranty",
    )

    db.commit()
    return {"message": "تم تقديم طلب الإرجاع بنجاح"}


@router.post("/{warranty_id}/resolve-return")
def resolve_return(
    warranty_id: int,
    data: ResolveReturn,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above),
):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    if not w.is_return_requested:
        raise HTTPException(400, "لم يُقدَّم أي طلب إرجاع بعد")
    if w.return_resolved:
        raise HTTPException(400, "الطلب مُعالَج مسبقاً")

    w.return_resolved = True
    w.return_approved = data.approved
    w.return_notes = data.notes or ""
    w.resolved_by_id = current_user.id
    w.resolved_at = datetime.utcnow()

    if w.customer_id:
        if data.approved:
            push_notification(
                db, w.customer_id,
                title="✅ تمت الموافقة على طلب الإرجاع",
                body=f"تمت الموافقة على إرجاع منتجك: {w.product_name}. تواصل معنا لإتمام الإجراءات.",
                notif_type=NotificationType.warranty,
                is_important=True,
                reference_id=w.id,
                reference_type="warranty",
            )
        else:
            push_notification(
                db, w.customer_id,
                title="❌ تم رفض طلب الإرجاع",
                body=f"تم رفض طلب إرجاع منتجك: {w.product_name}. {data.notes or 'للاستفسار تواصل معنا.'}",
                notif_type=NotificationType.warranty,
                is_important=True,
                reference_id=w.id,
                reference_type="warranty",
            )

    db.commit()
    return {"message": "تم معالجة طلب الإرجاع", "approved": data.approved}


@router.put("/{warranty_id}")
def update_warranty(
    warranty_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above),
    product_name: str = None,
    product_serial: str = None,
    warranty_days: int = None,
):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    return w


@router.put("/{warranty_id}/update")
def update_warranty_full(
    warranty_id: int,
    data: dict,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above),
):
    from fastapi import Body
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    if "product_name" in data and data["product_name"]:
        w.product_name = data["product_name"]
    if "product_serial" in data:
        w.product_serial = data["product_serial"] or None
    if "warranty_days" in data and data["warranty_days"]:
        from datetime import timedelta
        days = int(data["warranty_days"])
        w.warranty_days = days
        w.ends_at = w.starts_at + timedelta(days=days)
    db.commit()
    db.refresh(w)
    return w


@router.delete("/{warranty_id}")
def delete_warranty(
    warranty_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(require_staff_or_above),
):
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if not w:
        raise HTTPException(404, "Warranty not found")
    db.delete(w)
    db.commit()
    return {"message": "تم حذف الضمان بنجاح"}
