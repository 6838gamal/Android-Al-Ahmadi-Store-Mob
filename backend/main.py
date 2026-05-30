from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import asyncio
import os

from backend.core.database import engine, Base, SessionLocal
from backend.core.migrations import run_migrations

# Import all models so create_all sees them — branch must load before user
from backend.models.branch import Branch, Warehouse  # noqa — loaded first
from backend.models import (  # noqa
    user, product, order, reservation,
    inventory_item, referral, warranty,
    inspection, wallet, notification, audit_log,
)

from backend.api.routes import (
    auth, products, orders, reservations, maintenance,
    customers, dashboard, uploads,
    branches, inventory, referrals, warranty as warranty_routes,
    inspection as inspection_routes, wallet as wallet_routes,
    notifications, search, reports, audit,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield


app = FastAPI(
    title="اندرويد الاحمدي API",
    description="نظام إدارة محل الجوالات",
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    lifespan=lifespan,
)

# Run safe migrations first (adds new columns to existing tables)
run_migrations()

# Create all new tables
Base.metadata.create_all(bind=engine)


def _seed_admin():
    from backend.models.user import User, UserRole
    from backend.core.security import get_password_hash
    db = SessionLocal()
    try:
        existing = db.query(User).filter(User.role == UserRole.admin).first()
        if not existing:
            admin = User(
                name="مدير اندرويد الاحمدي",
                email="admin@alahmadi.com",
                phone="0501234567",
                hashed_password=get_password_hash("Admin@2026"),
                role=UserRole.admin,
                is_active=True,
            )
            db.add(admin)
            db.commit()
            print("✅ Admin user created: admin@alahmadi.com / Admin@2026")
        else:
            print(f"ℹ️  Admin already exists: {existing.email}")
    finally:
        db.close()


_seed_admin()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ── Existing routes (preserved) ───────────────────────────────────────────────
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(products.router, prefix="/api/products", tags=["Products"])
app.include_router(orders.router, prefix="/api/orders", tags=["Orders"])
app.include_router(reservations.router, prefix="/api/reservations", tags=["Reservations"])
app.include_router(maintenance.router, prefix="/api/maintenance", tags=["Maintenance"])
app.include_router(customers.router, prefix="/api/customers", tags=["Customers"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["Dashboard"])
app.include_router(uploads.router, prefix="/api/uploads", tags=["Uploads"])

# ── New routes ────────────────────────────────────────────────────────────────
app.include_router(branches.router, prefix="/api/branches", tags=["Branches"])
app.include_router(inventory.router, prefix="/api/inventory", tags=["Inventory"])
app.include_router(referrals.router, prefix="/api/referrals", tags=["Referrals"])
app.include_router(warranty_routes.router, prefix="/api/warranty", tags=["Warranty"])
app.include_router(inspection_routes.router, prefix="/api/inspection", tags=["Inspection"])
app.include_router(wallet_routes.router, prefix="/api/wallet", tags=["Wallet"])
app.include_router(notifications.router, prefix="/api/notifications", tags=["Notifications"])
app.include_router(search.router, prefix="/api/search", tags=["Search"])
app.include_router(reports.router, prefix="/api/reports", tags=["Reports"])
app.include_router(audit.router, prefix="/api/audit", tags=["Audit"])


@app.get("/api/health")
def health_check():
    return {"status": "ok", "app": "اندرويد الاحمدي", "version": "2.0.0"}
