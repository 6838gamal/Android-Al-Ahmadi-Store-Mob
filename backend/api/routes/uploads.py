from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from fastapi.responses import Response
from sqlalchemy.orm import Session
import os, uuid, base64
from PIL import Image
import io
from backend.core.database import get_db
from backend.core.config import settings
from backend.api.dependencies import get_admin_user, get_current_user
from backend.models.user import User
from backend.models.stored_image import StoredImage

router = APIRouter()

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/webm"}
ALLOWED_MEDIA_TYPES = ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES
MAX_IMAGE_SIZE = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024
MAX_VIDEO_SIZE = 50 * 1024 * 1024  # 50 MB


def _save_image_to_db(db: Session, img_uuid: str, image_bytes: bytes, mime_type: str) -> None:
    """Store image bytes as base64 in PostgreSQL for persistent cross-restart access."""
    b64 = base64.b64encode(image_bytes).decode("utf-8")
    stored = StoredImage(uuid=img_uuid, data=b64, mime_type=mime_type)
    db.merge(stored)
    db.commit()


def _save_image_to_fs(filepath: str, image_bytes: bytes) -> None:
    """Save image to local filesystem (best-effort; may not persist on Render.com free tier)."""
    try:
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, "wb") as f:
            f.write(image_bytes)
    except Exception:
        pass


@router.get("/image/{img_uuid}")
def serve_image(img_uuid: str, db: Session = Depends(get_db)):
    """Serve a stored image by UUID — tries filesystem first, falls back to DB."""
    # Sanitise: strip any extension the caller may have appended
    base_uuid = img_uuid.split(".")[0]

    # 1) Filesystem (fast path — works locally and on Render.com if not restarted)
    for ext in (".jpg", ".png", ".webp"):
        fpath = os.path.join(settings.UPLOAD_DIR, f"{base_uuid}{ext}")
        if os.path.isfile(fpath):
            with open(fpath, "rb") as f:
                data = f.read()
            mime = "image/jpeg" if ext == ".jpg" else f"image/{ext[1:]}"
            return Response(content=data, media_type=mime,
                            headers={"Cache-Control": "public, max-age=86400"})

    # 2) Database (persistent — survives Render.com restarts)
    record = db.query(StoredImage).filter(StoredImage.uuid == base_uuid).first()
    if record:
        img_bytes = base64.b64decode(record.data)
        return Response(content=img_bytes, media_type=record.mime_type,
                        headers={"Cache-Control": "public, max-age=86400"})

    raise HTTPException(status_code=404, detail="Image not found")


@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    admin: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    if file.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Only JPG, PNG, WEBP allowed")

    contents = await file.read()
    if len(contents) > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=400, detail="File too large (max 1MB)")

    try:
        img = Image.open(io.BytesIO(contents))
        img.thumbnail((800, 800), Image.LANCZOS)
        output = io.BytesIO()
        fmt = "JPEG" if file.content_type == "image/jpeg" else "PNG"
        img.save(output, format=fmt, optimize=True, quality=85)
        output.seek(0)
        processed = output.read()

        ext = ".jpg" if fmt == "JPEG" else ".png"
        mime = "image/jpeg" if fmt == "JPEG" else "image/png"
        img_uuid = str(uuid.uuid4())
        filename = f"{img_uuid}{ext}"
        filepath = os.path.join(settings.UPLOAD_DIR, filename)

        # Save to filesystem (fast serving, may be ephemeral on Render.com)
        _save_image_to_fs(filepath, processed)

        # Save to DB (persistent across Render.com restarts)
        _save_image_to_db(db, img_uuid, processed, mime)

        # Return /api/uploads/image/{uuid} — served by the DB endpoint above
        return {"url": f"/api/uploads/image/{img_uuid}", "filename": filename}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@router.post("/media")
async def upload_media(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Upload image or video. Accessible by any authenticated user.
    Images: max 5 MB, resized to 1200×1200, quality 85, stored in DB + filesystem.
    Videos: max 50 MB, saved to filesystem only.
    """
    content_type = file.content_type or ""

    is_image = content_type in ALLOWED_IMAGE_TYPES
    is_video = content_type in ALLOWED_VIDEO_TYPES

    if not is_image and not is_video:
        raise HTTPException(
            status_code=400,
            detail="نوع الملف غير مدعوم. الأنواع المقبولة: JPG، PNG، WEBP، MP4، MOV"
        )

    contents = await file.read()
    max_size = MAX_VIDEO_SIZE if is_video else (5 * 1024 * 1024)
    if len(contents) > max_size:
        size_label = "50 MB" if is_video else "5 MB"
        raise HTTPException(status_code=400, detail=f"حجم الملف كبير جداً (الحد الأقصى {size_label})")

    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

    if is_video:
        ext_map = {
            "video/mp4": ".mp4",
            "video/quicktime": ".mov",
            "video/x-msvideo": ".avi",
            "video/mpeg": ".mpeg",
            "video/webm": ".webm",
        }
        ext = ext_map.get(content_type, ".mp4")
        filename = f"{uuid.uuid4()}{ext}"
        filepath = os.path.join(settings.UPLOAD_DIR, filename)
        with open(filepath, "wb") as f:
            f.write(contents)
        return {"url": f"/uploads/{filename}", "filename": filename, "type": "video"}

    # Image processing
    try:
        img = Image.open(io.BytesIO(contents))
        img.thumbnail((1200, 1200), Image.LANCZOS)
        output = io.BytesIO()
        fmt = "JPEG" if content_type == "image/jpeg" else "PNG"
        img.save(output, format=fmt, optimize=True, quality=85)
        output.seek(0)
        processed = output.read()

        ext = ".jpg" if fmt == "JPEG" else ".png"
        mime = "image/jpeg" if fmt == "JPEG" else "image/png"
        img_uuid = str(uuid.uuid4())
        filename = f"{img_uuid}{ext}"
        filepath = os.path.join(settings.UPLOAD_DIR, filename)

        _save_image_to_fs(filepath, processed)
        _save_image_to_db(db, img_uuid, processed, mime)

        return {"url": f"/api/uploads/image/{img_uuid}", "filename": filename, "type": "image"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"فشل رفع الملف: {str(e)}")
