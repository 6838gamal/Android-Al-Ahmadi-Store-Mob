from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from backend.core.config import _resolve_db_url

# Use _resolve_db_url() directly so APP_DATABASE_URL (Render) always takes priority
# over Replit's own DATABASE_URL env-var which Pydantic BaseSettings would otherwise
# auto-inject into settings.DATABASE_URL.
DATABASE_URL = _resolve_db_url()

if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

connect_args = {}
if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
elif "render.com" in DATABASE_URL or (not DATABASE_URL.startswith("sqlite") and "helium" not in DATABASE_URL):
    connect_args = {"sslmode": "require", "connect_timeout": 30}

engine = create_engine(DATABASE_URL, connect_args=connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
