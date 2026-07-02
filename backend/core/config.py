from pydantic_settings import BaseSettings
import os

_DEFAULT_API_URL   = "http://localhost:8000"
_DEFAULT_SECRET    = "android-alahmadi-replit-secret-key-2026-very-secure-random-string"


def _resolve_db_url() -> str:
    # Priority: APP_DATABASE_URL (explicit override) → DATABASE_URL (Replit built-in) → SQLite fallback
    url = (
        os.getenv("APP_DATABASE_URL", "").strip()
        or os.getenv("DATABASE_URL", "").strip()
        or "sqlite:///./alahmadi.db"
    )
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    return url


def _resolve_api_url() -> str:
    return os.getenv("BACKEND_API_URL", _DEFAULT_API_URL).strip().rstrip("/")


def _resolve_secret_key() -> str:
    return os.getenv("SECRET_KEY", _DEFAULT_SECRET).strip()


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
