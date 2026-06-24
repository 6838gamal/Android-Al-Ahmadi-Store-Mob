from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from backend.core.database import get_db
from backend.models.gallery import GalleryFolder, GalleryImage
from backend.models.product import Product
from backend.api.dependencies import get_admin_user, get_current_user
from backend.models.user import User
from backend.core.samsung_catalog import SAMSUNG_CATALOG
from backend.core import supabase_storage
from backend.api.routes.uploads import _store_image
import os, uuid
from datetime import datetime

router = APIRouter()

UPLOAD_DIR = "uploads/gallery"
os.makedirs(UPLOAD_DIR, exist_ok=True)

_MIME_TO_EXT = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}


def _save_gallery_image(db: Session, fname: str, file_bytes: bytes, content_type: str) -> str:
    """
    رفع صورة المعرض مع ضمان الاستمرارية:
    1. Supabase Storage (CDN دائم) — إذا مُهيَّأ
    2. قاعدة البيانات كـ base64 + filesystem (fallback دائم لا يختفي بعد إعادة التشغيل)
    يُعيد الـ URL المناسب المخزَّن في قاعدة البيانات.
    """
    img_uuid = os.path.splitext(fname)[0]
    mime = content_type or "image/jpeg"
    ext = _MIME_TO_EXT.get(mime, ".jpg")
    filepath = os.path.join(UPLOAD_DIR, f"{img_uuid}{ext}")

    return _store_image(db, img_uuid, file_bytes, mime, filepath)


def _delete_gallery_file(image_url: str) -> None:
    """حذف صورة المعرض من Supabase والـ filesystem."""
    if image_url.startswith("http"):
        # Supabase URL — extract path after bucket name
        try:
            marker = f"/{supabase_storage.BUCKET_NAME}/"
            idx = image_url.find(marker)
            if idx != -1:
                storage_path = image_url[idx + len(marker):]
                supabase_storage.delete_file(storage_path)
        except Exception:
            pass
    else:
        # Local filesystem path
        local_path = image_url.lstrip("/")
        if os.path.exists(local_path):
            try:
                os.remove(local_path)
            except Exception:
                pass


# ── Seed folders from catalog ──────────────────────────────────────────────────
def seed_gallery_folders(db: Session):
    """Auto-create GalleryFolder rows from the Samsung catalog if missing."""
    sort_series = 0
    for series_key, series in SAMSUNG_CATALOG.items():
        sort_series += 10
        sort_model = 0
        for model in series["models"]:
            sort_model += 1
            exists = db.query(GalleryFolder).filter(
                GalleryFolder.series_key == series_key,
                GalleryFolder.model_key == model["key"],
            ).first()
            if not exists:
                db.add(GalleryFolder(
                    series_key=series_key,
                    model_key=model["key"],
                    label_ar=model["label_ar"],
                    label_en=model["label_en"],
                    sort_order=sort_series * 100 + sort_model,
                ))
    db.commit()


# ── GET /api/gallery/folders  (grouped by series) ─────────────────────────────
@router.get("/folders")
def list_folders(db: Session = Depends(get_db)):
    seed_gallery_folders(db)
    folders = db.query(GalleryFolder).filter(GalleryFolder.is_active == True).order_by(
        GalleryFolder.sort_order
    ).all()

    # جلب صور المنتجات كـ fallback للغلافات عند غياب صور المعرض
    product_images = (
        db.query(Product.image_url, Product.name)
        .filter(Product.image_url.isnot(None), Product.image_url != "")
        .order_by(Product.created_at.desc())
        .limit(30)
        .all()
    )
    product_cover_cycle = [r[0] for r in product_images if r[0]]

    grouped = {}
    cover_idx = 0
    for f in folders:
        if f.series_key not in grouped:
            series_info = SAMSUNG_CATALOG.get(f.series_key, {})
            grouped[f.series_key] = {
                "series_key": f.series_key,
                "label_ar": series_info.get("label_ar", f.series_key),
                "label_en": series_info.get("label_en", f.series_key),
                "folders": [],
            }
        count = db.query(GalleryImage).filter(GalleryImage.folder_id == f.id).count()
        cover = f.cover_image_url
        # تجاهل الروابط المحلية المؤقتة التي لم تعد متاحة
        if cover and not (cover.startswith("http") or cover.startswith("/api/uploads/image/")):
            cover = None
        if not cover:
            first_img = db.query(GalleryImage).filter(
                GalleryImage.folder_id == f.id
            ).order_by(GalleryImage.sort_order).first()
            if first_img and (first_img.image_url.startswith("http") or first_img.image_url.startswith("/api/uploads/image/")):
                cover = first_img.image_url
            else:
                cover = None

        # استخدام صورة منتج كغلاف بديل إذا لم توجد صورة مخصصة
        if not cover and product_cover_cycle:
            cover = product_cover_cycle[cover_idx % len(product_cover_cycle)]
            cover_idx += 1

        grouped[f.series_key]["folders"].append({
            "id": f.id,
            "series_key": f.series_key,
            "model_key": f.model_key,
            "label_ar": f.label_ar,
            "label_en": f.label_en,
            "cover_image_url": cover,
            "image_count": count,
            "sort_order": f.sort_order,
            "created_at": f.created_at.isoformat() if f.created_at else None,
            "updated_at": f.updated_at.isoformat() if f.updated_at else None,
        })

    return list(grouped.values())


# ── GET /api/gallery/images  (كل صور المعرض مع فلاتر اختيارية) ──────────────
@router.get("/images")
def get_all_gallery_images(
    series_key: Optional[str] = Query(None),
    model_key: Optional[str]  = Query(None),
    db: Session = Depends(get_db),
):
    """جلب كل صور المعرض مع فلاتر اختيارية. عند غياب صور المعرض تُستخدم صور المنتجات كـ fallback."""
    q = (
        db.query(GalleryImage)
        .join(GalleryFolder, GalleryImage.folder_id == GalleryFolder.id)
        .filter(GalleryFolder.is_active == True)
    )
    if series_key:
        q = q.filter(GalleryFolder.series_key == series_key)
    if model_key:
        q = q.filter(GalleryFolder.model_key == model_key)

    images = q.order_by(
        GalleryFolder.sort_order,
        GalleryImage.sort_order,
        GalleryImage.created_at,
    ).all()

    def _is_valid_url(url: str | None) -> bool:
        """تحقق من أن الرابط صالح (ليس مساراً محلياً مؤقتاً)."""
        if not url:
            return False
        return url.startswith("http") or url.startswith("/api/uploads/image/")

    result = [
        {
            "id": img.id,
            "image_url": img.image_url,
            "watermark_number": img.watermark_number,
            "title": img.title,
            "folder_id": img.folder_id,
            "folder_label_ar": img.folder.label_ar,
            "series_key": img.folder.series_key,
            "model_key": img.folder.model_key,
            "created_at": img.created_at.isoformat() if img.created_at else None,
        }
        for img in images
        if _is_valid_url(img.image_url)
    ]

    # Fallback: عند غياب صور المعرض الصالحة وبدون فلتر مجلد محدد، تُعرض صور المنتجات
    if not result and not series_key and not model_key:
        products = (
            db.query(Product)
            .filter(Product.image_url.isnot(None), Product.image_url != "")
            .order_by(Product.created_at.desc())
            .limit(60)
            .all()
        )
        for p in products:
            result.append({
                "id": f"product_{p.id}",
                "image_url": p.image_url,
                "watermark_number": None,
                "title": p.name,
                "folder_id": None,
                "folder_label_ar": p.category.value if hasattr(p.category, 'value') else str(p.category),
                "series_key": None,
                "model_key": None,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            })

    return result


# ── GET /api/gallery/folders/{folder_id}  (images in folder) ──────────────────
@router.get("/folders/{folder_id}")
def get_folder_images(folder_id: int, db: Session = Depends(get_db)):
    folder = db.query(GalleryFolder).filter(GalleryFolder.id == folder_id).first()
    if not folder:
        raise HTTPException(status_code=404, detail="المجلد غير موجود")

    images = db.query(GalleryImage).filter(
        GalleryImage.folder_id == folder_id
    ).order_by(GalleryImage.sort_order, GalleryImage.created_at).all()

    return {
        "id": folder.id,
        "series_key": folder.series_key,
        "model_key": folder.model_key,
        "label_ar": folder.label_ar,
        "label_en": folder.label_en,
        "cover_image_url": folder.cover_image_url,
        "created_at": folder.created_at.isoformat() if folder.created_at else None,
        "updated_at": folder.updated_at.isoformat() if folder.updated_at else None,
        "images": [
            {
                "id": img.id,
                "image_url": img.image_url,
                "watermark_number": img.watermark_number,
                "title": img.title,
                "notes": img.notes,
                "sort_order": img.sort_order,
                "created_at": img.created_at.isoformat() if img.created_at else None,
                "created_by": img.created_by.name if img.created_by else None,
            }
            for img in images
        ],
    }


# ── POST /api/gallery/folders/{folder_id}/images  (upload — admin only) ──────
@router.post("/folders/{folder_id}/images")
async def upload_image(
    folder_id: int,
    file: UploadFile = File(...),
    title: Optional[str] = Form(None),
    notes: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user),
):
    folder = db.query(GalleryFolder).filter(GalleryFolder.id == folder_id).first()
    if not folder:
        raise HTTPException(status_code=404, detail="المجلد غير موجود")

    ext = os.path.splitext(file.filename or "img.jpg")[1].lower() or ".jpg"
    fname = f"{uuid.uuid4().hex}{ext}"
    file_bytes = await file.read()
    mime = file.content_type or "image/jpeg"

    image_url = _save_gallery_image(db, fname, file_bytes, mime)

    count = db.query(GalleryImage).filter(GalleryImage.folder_id == folder_id).count()
    watermark = f"{folder.series_key.upper()}-{folder.model_key.replace(' ', '')}-{count+1:03d}"

    img = GalleryImage(
        folder_id=folder_id,
        image_url=image_url,
        watermark_number=watermark,
        title=title,
        notes=notes,
        sort_order=count + 1,
        created_by_id=current_user.id,
    )
    db.add(img)

    if not folder.cover_image_url:
        folder.cover_image_url = image_url
    folder.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(img)

    return {
        "id": img.id,
        "image_url": img.image_url,
        "watermark_number": img.watermark_number,
        "created_at": img.created_at.isoformat() if img.created_at else None,
        "message": "تم رفع الصورة بنجاح",
    }


# ── POST /api/gallery/folders/{folder_id}/images/url  (add by URL — admin) ───
@router.post("/folders/{folder_id}/images/url")
def add_image_by_url(
    folder_id: int,
    image_url: str = Form(...),
    title: Optional[str] = Form(None),
    notes: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user),
):
    folder = db.query(GalleryFolder).filter(GalleryFolder.id == folder_id).first()
    if not folder:
        raise HTTPException(status_code=404, detail="المجلد غير موجود")

    count = db.query(GalleryImage).filter(GalleryImage.folder_id == folder_id).count()
    watermark = f"{folder.series_key.upper()}-{folder.model_key.replace(' ', '')}-{count+1:03d}"

    img = GalleryImage(
        folder_id=folder_id,
        image_url=image_url,
        watermark_number=watermark,
        title=title,
        notes=notes,
        sort_order=count + 1,
        created_by_id=current_user.id,
    )
    db.add(img)

    if not folder.cover_image_url:
        folder.cover_image_url = image_url
    folder.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(img)
    return {"id": img.id, "watermark_number": img.watermark_number, "message": "تمت الإضافة"}


# ── POST /api/gallery/folders/{folder_id}/images/batch  (رفع جماعي — admin) ──
@router.post("/folders/{folder_id}/images/batch")
async def batch_upload_images(
    folder_id: int,
    files: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user),
):
    """رفع حتى 150 صورة دفعة واحدة مع ترقيم مائي تلقائي لكل صورة."""
    if len(files) > 150:
        raise HTTPException(status_code=400, detail="الحد الأقصى للرفع الجماعي هو 150 صورة")

    folder = db.query(GalleryFolder).filter(GalleryFolder.id == folder_id).first()
    if not folder:
        raise HTTPException(status_code=404, detail="المجلد غير موجود")

    count = db.query(GalleryImage).filter(GalleryImage.folder_id == folder_id).count()
    results = []
    first_url = None

    for file in files:
        ext = os.path.splitext(file.filename or "img.jpg")[1].lower() or ".jpg"
        fname = f"{uuid.uuid4().hex}{ext}"
        file_bytes = await file.read()
        mime = file.content_type or "image/jpeg"

        image_url = _save_gallery_image(db, fname, file_bytes, mime)

        count += 1
        watermark = f"{folder.series_key.upper()}-{folder.model_key.replace(' ', '')}-{count:03d}"

        img = GalleryImage(
            folder_id=folder_id,
            image_url=image_url,
            watermark_number=watermark,
            sort_order=count,
            created_by_id=current_user.id,
        )
        db.add(img)
        results.append({"filename": fname, "watermark_number": watermark, "url": image_url})

        if first_url is None:
            first_url = image_url

    if not folder.cover_image_url and first_url:
        folder.cover_image_url = first_url
    folder.updated_at = datetime.utcnow()

    db.commit()
    return {
        "uploaded": len(results),
        "folder_id": folder_id,
        "images": results,
        "message": f"✅ تم رفع {len(results)} صورة بنجاح",
    }


# ── DELETE /api/gallery/images/{image_id}  (admin only) ───────────────────────
@router.delete("/images/{image_id}")
def delete_image(
    image_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user),
):
    img = db.query(GalleryImage).filter(GalleryImage.id == image_id).first()
    if not img:
        raise HTTPException(status_code=404, detail="الصورة غير موجودة")

    # Delete from Supabase or local filesystem
    _delete_gallery_file(img.image_url)

    folder_id = img.folder_id
    db.delete(img)
    db.commit()

    folder = db.query(GalleryFolder).filter(GalleryFolder.id == folder_id).first()
    if folder and (not folder.cover_image_url or folder.cover_image_url == img.image_url):
        first = db.query(GalleryImage).filter(
            GalleryImage.folder_id == folder_id
        ).order_by(GalleryImage.sort_order).first()
        folder.cover_image_url = first.image_url if first else None
        db.commit()

    return {"message": "تم الحذف"}


# ── PUT /api/gallery/folders/{folder_id}/cover  (set cover — admin) ──────────
@router.put("/folders/{folder_id}/cover")
def set_cover(
    folder_id: int,
    image_id: int = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user),
):
    img = db.query(GalleryImage).filter(
        GalleryImage.id == image_id,
        GalleryImage.folder_id == folder_id,
    ).first()
    if not img:
        raise HTTPException(status_code=404, detail="الصورة غير موجودة")

    folder = db.query(GalleryFolder).filter(GalleryFolder.id == folder_id).first()
    folder.cover_image_url = img.image_url
    db.commit()
    return {"message": "تم تحديث الغلاف"}
