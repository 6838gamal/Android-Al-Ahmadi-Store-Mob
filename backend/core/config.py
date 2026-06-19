from pydantic_settings import BaseSettings
import os
import secrets


def _resolve_db_url() -> str:
    url = os.getenv("DATABASE_URL", os.getenv("APP_DATABASE_URL", "")).strip()
    if not url:
        raise RuntimeError("DATABASE_URL environment variable is not set")
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://"):]
    return url


def _resolve_api_url() -> str:
    return os.getenv("BACKEND_API_URL", "http://localhost:8000").strip().rstrip("/")


def _resolve_secret_key() -> str:
    key = os.getenv("SECRET_KEY", "").strip()
    if not key:
        key = secrets.token_hex(32)
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
