from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
import os, uuid
from PIL import Image
import io
from backend.core.database import get_db
from backend.core.config import settings
from backend.api.dependencies import get_admin_user
from backend.models.user import User

router = APIRouter()

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024


@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    admin: User = Depends(get_admin_user)
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Only JPG, PNG, WEBP allowed")

    contents = await file.read()
    if len(contents) > MAX_SIZE:
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
