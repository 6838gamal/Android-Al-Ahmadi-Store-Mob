from pydantic_settings import BaseSettings
import os


def _resolve_db_url() -> str:
    """يقرأ APP_DATABASE_URL من متغيرات البيئة فقط — لا قيمة مُضمَّنة في الكود."""
    url = os.getenv("APP_DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError(
            "[FATAL] متغير البيئة APP_DATABASE_URL غير مضبوط — "
            "أضفه من لوحة متغيرات البيئة في Replit."
        )
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    return url


def _resolve_api_url() -> str:
    """يقرأ BACKEND_API_URL من متغيرات البيئة فقط — لا قيمة مُضمَّنة في الكود."""
    url = os.getenv("BACKEND_API_URL", "").strip().rstrip("/")
    if not url:
        raise RuntimeError(
            "[FATAL] متغير البيئة BACKEND_API_URL غير مضبوط — "
            "أضفه من لوحة متغيرات البيئة في Replit."
        )
    return url


def _resolve_secret_key() -> str:
    """يقرأ SECRET_KEY من متغيرات البيئة فقط — لا قيمة مُضمَّنة في الكود."""
    key = os.getenv("SECRET_KEY", "").strip()
    if not key:
        raise RuntimeError(
            "[FATAL] متغير البيئة SECRET_KEY غير مضبوط — "
            "أضفه من لوحة متغيرات البيئة في Replit."
        )
    return key


class Settings(BaseSettings):
    DATABASE_URL: str = _resolve_db_url()
    BACKEND_API_URL: str = _resolve_api_url()
    SECRET_KEY: str = _resolve_secret_key()
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    UPLOAD_DIR: str = "uploads"
    MAX_IMAGE_SIZE_MB: int = 1

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
