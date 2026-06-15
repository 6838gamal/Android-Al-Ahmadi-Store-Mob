from pydantic_settings import BaseSettings
import os

# ─────────────────────────────────────────────────────────────────────────────
# قاعدة البيانات المقفولة — Render.com PostgreSQL
# لا تُغيَّر إلا عبر متغير البيئة APP_DATABASE_URL في Replit Secrets.
# DATABASE_URL مُتجاهَل عمداً (Replit يضبطه تلقائياً لقاعدته المُدارة).
# ─────────────────────────────────────────────────────────────────────────────
_LOCKED_DB_URL = (
    "postgresql://gamalalmaqtary:QPg3qlwP31n4QNczLjG1C3XpdXdZj29D"
    "@dpg-d8egmfv40ujc73dj2ggg-a.ohio-postgres.render.com"
    "/android_al_ahmadi_store_db"
)

# ─────────────────────────────────────────────────────────────────────────────
# رابط الـ API المقفول — Render.com
# لا يُغيَّر إلا عبر متغير البيئة BACKEND_API_URL.
# ─────────────────────────────────────────────────────────────────────────────
_LOCKED_API_URL = "https://android-al-ahmadi-store-api.onrender.com"


def _resolve_db_url() -> str:
    """
    يقرأ APP_DATABASE_URL فقط. يتجاهل DATABASE_URL (Replit managed).
    لا تُمرَّر قيم من خارج هذه الدالة.
    """
    url = os.getenv("APP_DATABASE_URL", "").strip()
    if url:
        # postgres:// → postgresql:// (SQLAlchemy 1.4+)
        if url.startswith("postgres://"):
            url = "postgresql://" + url[len("postgres://"):]
        return url
    return _LOCKED_DB_URL


def _resolve_api_url() -> str:
    url = os.getenv("BACKEND_API_URL", "").strip()
    return url if url else _LOCKED_API_URL


class Settings(BaseSettings):
    DATABASE_URL: str = _resolve_db_url()
    BACKEND_API_URL: str = _resolve_api_url()
    SECRET_KEY: str = os.getenv(
        "SECRET_KEY", "android-alahmadi-secret-key-2026-very-secure"
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    UPLOAD_DIR: str = "uploads"
    MAX_IMAGE_SIZE_MB: int = 1

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
