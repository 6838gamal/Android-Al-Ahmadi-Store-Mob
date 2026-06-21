from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy.orm import Session
from typing import Optional, List
from backend.core.database import get_db
from backend.models.gallery import GalleryFolder, GalleryImage
from backend.api.dependencies import get_admin_user, get_current_user
from backend.models.user import User
from backend.core.samsung_catalog import SAMSUNG_CATALOG
import shutil, os, uuid
from datetime import datetime

router = APIRouter()

UPLOAD_DIR = "uploads/gallery"
os.makedirs(UPLOAD_DIR, exist_ok=True)


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

    grouped = {}
    for f in folders:
        if f.series_key not in grouped:
            series_info = SAMSUNG_CATALOG.get(f.series_key, {})
            grouped[f.series_key] = {
                "series_key": f.series_key,
                "label_ar": series_info.get("label_ar", f.series_key),
                "label_en": series_info.get("label_en", f.series_key),
                "folders": [],
            }
        # Count images for this folder
        count = db.query(GalleryImage).filter(GalleryImage.folder_id == f.id).count()
        cover = f.cover_image_url
        if not cover:
            first_img = db.query(GalleryImage).filter(
                GalleryImage.folder_id == f.id
            ).order_by(GalleryImage.sort_order).first()
            cover = first_img.image_url if first_img else None

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
    dest = os.path.join(UPLOAD_DIR, fname)
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Auto watermark number: series_key-model_key-NNN
    count = db.query(GalleryImage).filter(GalleryImage.folder_id == folder_id).count()
    watermark = f"{folder.series_key.upper()}-{folder.model_key.replace(' ', '')}-{count+1:03d}"

    img = GalleryImage(
        folder_id=folder_id,
        image_url=f"/uploads/gallery/{fname}",
        watermark_number=watermark,
        title=title,
        notes=notes,
        sort_order=count + 1,
        created_by_id=current_user.id,
    )
    db.add(img)

    if not folder.cover_image_url:
        folder.cover_image_url = f"/uploads/gallery/{fname}"

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

    for file in files:
        ext = os.path.splitext(file.filename or "img.jpg")[1].lower() or ".jpg"
        fname = f"{uuid.uuid4().hex}{ext}"
        dest = os.path.join(UPLOAD_DIR, fname)
        with open(dest, "wb") as f:
            import shutil as _shutil
            _shutil.copyfileobj(file.file, f)

        count += 1
        watermark = f"{folder.series_key.upper()}-{folder.model_key.replace(' ', '')}-{count:03d}"

        img = GalleryImage(
            folder_id=folder_id,
            image_url=f"/uploads/gallery/{fname}",
            watermark_number=watermark,
            sort_order=count,
            created_by_id=current_user.id,
        )
        db.add(img)
        results.append({"filename": fname, "watermark_number": watermark})

    if not folder.cover_image_url and results:
        folder.cover_image_url = f"/uploads/gallery/{results[0]['filename']}"

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

    local_path = img.image_url.lstrip("/")
    if os.path.exists(local_path):
        os.remove(local_path)

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
