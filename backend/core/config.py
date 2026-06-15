from pydantic_settings import BaseSettings
from typing import Optional
import os


_DEFAULT_DB_URL = "postgresql://gamalalmaqtary:QPg3qlwP31n4QNczLjG1C3XpdXdZj29D@dpg-d8egmfv40ujc73dj2ggg-a.ohio-postgres.render.com/android_al_ahmadi_store_db"


def _resolve_db_url() -> str:
    # Only APP_DATABASE_URL can override the default Render.com URL.
    # DATABASE_URL is intentionally ignored — Replit auto-sets it to its own
    # managed DB, but this project uses the external Render.com database.
    url = os.getenv("APP_DATABASE_URL", "")
    if url:
        if url.startswith("postgres://"):
            url = "postgresql://" + url[len("postgres://"):]
        return url
    return _DEFAULT_DB_URL


class Settings(BaseSettings):
    DATABASE_URL: str = _resolve_db_url()
    SECRET_KEY: str = os.getenv("SECRET_KEY", "android-alahmadi-secret-key-2026-very-secure")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    UPLOAD_DIR: str = "uploads"
    MAX_IMAGE_SIZE_MB: int = 1

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
