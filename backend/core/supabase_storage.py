"""
Supabase Storage helper — يُستخدم لرفع الصور وخدمتها من Supabase Storage CDN.
يضمن بقاء الصور حتى بعد إعادة تشغيل السيرفر.
"""
import os
import logging

logger = logging.getLogger("alahmadi.supabase")

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")
BUCKET_NAME = "store-images"

_client = None


def _get_client():
    global _client
    if _client is not None:
        return _client
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        logger.warning("Supabase not configured — SUPABASE_URL or SUPABASE_SERVICE_KEY missing")
        return None
    try:
        from supabase import create_client
        _client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
        return _client
    except Exception as e:
        logger.error(f"Failed to init Supabase client: {e}")
        return None


def ensure_bucket() -> bool:
    """Create the storage bucket if it doesn't exist. Returns True on success."""
    client = _get_client()
    if not client:
        return False
    try:
        buckets = client.storage.list_buckets()
        existing = [b.name for b in buckets]
        if BUCKET_NAME not in existing:
            client.storage.create_bucket(
                BUCKET_NAME,
                options={"public": True, "file_size_limit": 10485760}  # 10 MB
            )
            logger.info(f"✅ Supabase bucket '{BUCKET_NAME}' created")
        else:
            logger.info(f"ℹ️  Supabase bucket '{BUCKET_NAME}' already exists")
        return True
    except Exception as e:
        logger.error(f"Failed to ensure Supabase bucket: {e}")
        return False


def upload_image(img_uuid: str, image_bytes: bytes, mime_type: str) -> str | None:
    """
    رفع صورة إلى Supabase Storage باستخدام UUID.
    يُعيد الـ public URL أو None عند الفشل.
    """
    ext_map = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/gif": ".gif",
    }
    ext = ext_map.get(mime_type, ".jpg")
    return upload_file(f"{img_uuid}{ext}", image_bytes, mime_type)


def upload_file(storage_path: str, file_bytes: bytes, mime_type: str) -> str | None:
    """
    رفع ملف إلى Supabase Storage بمسار محدد.
    يُعيد الـ public URL أو None عند الفشل.
    """
    client = _get_client()
    if not client:
        return None
    try:
        client.storage.from_(BUCKET_NAME).upload(
            path=storage_path,
            file=file_bytes,
            file_options={"content-type": mime_type, "upsert": "true"},
        )
        public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{storage_path}"
        logger.info(f"✅ Supabase upload: {public_url}")
        return public_url
    except Exception as e:
        logger.error(f"Supabase upload failed ({storage_path}): {e}")
        return None


def delete_image(img_uuid: str) -> bool:
    """حذف صورة من Supabase Storage بواسطة UUID."""
    for ext in (".jpg", ".png", ".webp", ".gif"):
        delete_file(f"{img_uuid}{ext}")
    return True


def delete_file(storage_path: str) -> bool:
    """حذف ملف من Supabase Storage بمساره الكامل."""
    client = _get_client()
    if not client:
        return False
    try:
        client.storage.from_(BUCKET_NAME).remove([storage_path])
        return True
    except Exception as e:
        logger.debug(f"Supabase delete ({storage_path}): {e}")
        return False


def is_configured() -> bool:
    return bool(SUPABASE_URL and SUPABASE_SERVICE_KEY)
