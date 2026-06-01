from pydantic_settings import BaseSettings
from typing import Optional
import os


def _resolve_db_url() -> str:
    # Priority: APP_DATABASE_URL (external Postgres) → DATABASE_URL → SQLite fallback
    url = os.getenv("APP_DATABASE_URL") or os.getenv("DATABASE_URL", "")
    if url:
        # Render.com sometimes returns postgres:// — normalise to postgresql://
        if url.startswith("postgres://"):
            url = "postgresql://" + url[len("postgres://"):]
        return url
    return "sqlite:///./android_alahmadi.db"


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
