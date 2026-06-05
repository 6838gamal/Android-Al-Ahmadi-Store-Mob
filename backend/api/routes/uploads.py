from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
import os, uuid
from PIL import Image
import io
from backend.core.database import get_db
from backend.core.config import settings
from backend.api.dependencies import get_admin_user, get_current_user
from backend.models.user import User

router = APIRouter()

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/x-msvideo", "video/mpeg", "video/webm"}
ALLOWED_MEDIA_TYPES = ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES
MAX_IMAGE_SIZE = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024
MAX_VIDEO_SIZE = 50 * 1024 * 1024  # 50 MB


@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    admin: User = Depends(get_admin_user)
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

        ext = ".jpg" if fmt == "JPEG" else ".png"
        filename = f"{uuid.uuid4()}{ext}"
        filepath = os.path.join(settings.UPLOAD_DIR, filename)

        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        with open(filepath, "wb") as f:
            f.write(output.read())

        return {"url": f"/uploads/{filename}", "filename": filename}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@router.post("/media")
async def upload_media(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """
    Upload image or video. Accessible by any authenticated user.
    Images: max 5 MB, resized to 1200×1200, quality 85.
    Videos: max 50 MB, saved as-is.
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
        ext = ".jpg" if fmt == "JPEG" else ".png"
        filename = f"{uuid.uuid4()}{ext}"
        filepath = os.path.join(settings.UPLOAD_DIR, filename)
        with open(filepath, "wb") as f:
            f.write(output.read())
        return {"url": f"/uploads/{filename}", "filename": filename, "type": "image"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"فشل رفع الملف: {str(e)}")
