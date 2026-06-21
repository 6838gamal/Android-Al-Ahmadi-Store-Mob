from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from backend.core.database import get_db
from backend.models.purchase_invoice import PurchaseInvoice, PurchaseInvoiceItem, InvoiceStatus
from backend.models.capital import CapitalTransaction, CapitalTransactionType
from backend.models.user import User
from backend.api.dependencies import get_admin_user, require_staff_or_above
from pydantic import BaseModel

router = APIRouter()


def _gen_invoice_number(db):
    count = db.query(PurchaseInvoice).count() + 1
    return f"PUR-{datetime.now().year}-{count:04d}"


class InvoiceItemCreate(BaseModel):
    product_name: str
    brand: Optional[str] = None
    model: Optional[str] = None
    series: Optional[str] = None
    category: Optional[str] = None
    quantity: int = 1
    unit_price: float
    notes: Optional[str] = None


class PurchaseInvoiceCreate(BaseModel):
    supplier_name: str
    supplier_phone: Optional[str] = None
    cash_from_drawer: float = 0.0
    capital_from_owner: float = 0.0
    notes: Optional[str] = None
    items: List[InvoiceItemCreate]


class InvoiceItemResponse(BaseModel):
    id: int
    product_name: str
    brand: Optional[str]
    model: Optional[str]
    series: Optional[str]
    category: Optional[str]
    quantity: int
    unit_price: float
    total_price: float

    class Config:
        from_attributes = True


class PurchaseInvoiceResponse(BaseModel):
    id: int
    invoice_number: str
    supplier_name: str
    supplier_phone: Optional[str]
    total_amount: float
    cash_from_drawer: float
    capital_from_owner: float
    status: InvoiceStatus
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("/")
def create_invoice(data: PurchaseInvoiceCreate, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    total = sum(item.unit_price * item.quantity for item in data.items)
    declared_total = data.cash_from_drawer + data.capital_from_owner

    if abs(total - declared_total) > 0.01 and declared_total > 0:
        raise HTTPException(
            status_code=400,
            detail=f"مجموع مصادر التمويل ({declared_total:.2f}) لا يساوي إجمالي الفاتورة ({total:.2f})"
        )

    invoice = PurchaseInvoice(
        invoice_number=_gen_invoice_number(db),
        supplier_name=data.supplier_name,
        supplier_phone=data.supplier_phone,
        total_amount=total,
        cash_from_drawer=data.cash_from_drawer,
        capital_from_owner=data.capital_from_owner,
        notes=data.notes,
        created_by_id=admin.id,
    )
    db.add(invoice)
    db.flush()

    for item_data in data.items:
        item = PurchaseInvoiceItem(
            invoice_id=invoice.id,
            product_name=item_data.product_name,
            brand=item_data.brand,
            model=item_data.model,
            series=item_data.series,
            category=item_data.category,
            quantity=item_data.quantity,
            unit_price=item_data.unit_price,
            total_price=item_data.unit_price * item_data.quantity,
            notes=item_data.notes,
        )
        db.add(item)

    if data.capital_from_owner > 0:
        cap_tx = CapitalTransaction(
            transaction_type=CapitalTransactionType.withdrawal,
            amount=data.capital_from_owner,
            reason=f"مشتريات من المالك — {data.supplier_name}",
            reference_number=invoice.invoice_number,
            recorded_by_id=admin.id,
        )
        db.add(cap_tx)

    db.commit()
    db.refresh(invoice)
    return {
        "message": "تم تسجيل فاتورة المشتريات بنجاح",
        "invoice_number": invoice.invoice_number,
        "total_amount": invoice.total_amount,
        "cash_from_drawer": invoice.cash_from_drawer,
        "capital_from_owner": invoice.capital_from_owner,
        "id": invoice.id,
    }


@router.get("/", response_model=List[PurchaseInvoiceResponse])
def list_invoices(
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    admin=Depends(get_admin_user),
):
    return db.query(PurchaseInvoice).order_by(PurchaseInvoice.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/summary")
def invoice_summary(db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    invoices = db.query(PurchaseInvoice).filter(PurchaseInvoice.status == InvoiceStatus.confirmed).all()
    total_purchased = sum(i.total_amount for i in invoices)
    total_from_drawer = sum(i.cash_from_drawer for i in invoices)
    total_from_owner = sum(i.capital_from_owner for i in invoices)
    return {
        "total_invoices": len(invoices),
        "total_purchased": total_purchased,
        "total_from_drawer": total_from_drawer,
        "total_from_owner": total_from_owner,
    }


@router.get("/{invoice_id}")
def get_invoice(invoice_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == invoice_id).first()
    if not inv:
        raise HTTPException(status_code=404, detail="الفاتورة غير موجودة")
    items = db.query(PurchaseInvoiceItem).filter(PurchaseInvoiceItem.invoice_id == invoice_id).all()
    return {
        "id": inv.id,
        "invoice_number": inv.invoice_number,
        "supplier_name": inv.supplier_name,
        "supplier_phone": inv.supplier_phone,
        "total_amount": inv.total_amount,
        "cash_from_drawer": inv.cash_from_drawer,
        "capital_from_owner": inv.capital_from_owner,
        "status": inv.status,
        "notes": inv.notes,
        "created_at": inv.created_at,
        "items": [{"id": i.id, "product_name": i.product_name, "brand": i.brand, "model": i.model, "quantity": i.quantity, "unit_price": i.unit_price, "total_price": i.total_price} for i in items],
    }


@router.put("/{invoice_id}/mark-printed")
def mark_printed(invoice_id: int, db: Session = Depends(get_db), admin=Depends(require_staff_or_above)):
    inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == invoice_id).first()
    if not inv:
        raise HTTPException(status_code=404, detail="الفاتورة غير موجودة")
    inv.receipt_printed = True
    db.commit()
    return {"message": "تم تسجيل طباعة الفاتورة"}


@router.delete("/{invoice_id}")
def delete_invoice(invoice_id: int, db: Session = Depends(get_db), admin=Depends(get_admin_user)):
    inv = db.query(PurchaseInvoice).filter(PurchaseInvoice.id == invoice_id).first()
    if not inv:
        raise HTTPException(status_code=404, detail="الفاتورة غير موجودة")
    db.query(PurchaseInvoiceItem).filter(PurchaseInvoiceItem.invoice_id == invoice_id).delete()
    db.delete(inv)
    db.commit()
    return {"message": "تم حذف الفاتورة"}
