from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from typing import List as _WsList
import os

from backend.core.database import engine, Base, SessionLocal
from backend.core.migrations import run_migrations

# Import all models so create_all sees them — branch must load before user
from backend.models.branch import Branch, Warehouse  # noqa — loaded first
from backend.models import (  # noqa
    user, product, order, reservation,
    inventory_item, referral, warranty,
    inspection, wallet, notification, audit_log,
    loyalty, shortage_request, auction, secret_deal,
    eng_support, complaint, purchase_invoice, gallery,
)
from backend.models.announcement import Announcement  # noqa

from backend.api.routes import (
    auth, products, orders, reservations, maintenance,
    customers, dashboard, uploads,
    branches, inventory, referrals, warranty as warranty_routes,
    inspection as inspection_routes, wallet as wallet_routes,
    notifications, search, reports, audit, staff,
    announcements as announcement_routes,
    loyalty as loyalty_routes,
    shortage_requests as shortage_requests_routes,
    auctions as auctions_routes,
    secret_deals as secret_deals_routes,
    eng_support as eng_support_routes,
    complaints as complaints_routes,
    purchase_invoices as purchase_invoices_routes,
    gallery as gallery_routes,
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
    import random, string

    def _gen_code(db):
        while True:
            code = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
            if not db.query(User).filter(User.referral_code == code).first():
                return code

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
                referral_code=_gen_code(db),
            )
            db.add(admin)
            db.commit()
            print("✅ Admin user created: admin@alahmadi.com / Admin@2026")
        else:
            print(f"ℹ️  Admin already exists: {existing.email}")
    finally:
        db.close()


_env = os.getenv("ENVIRONMENT", "development").lower()
if _env != "production":
    _seed_admin()
else:
    def _ensure_admin_production():
        from backend.models.user import User, UserRole
        from backend.core.security import get_password_hash
        import random, string

        def _gen_code(db):
            while True:
                code = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
                if not db.query(User).filter(User.referral_code == code).first():
                    return code

        db = SessionLocal()
        try:
            existing = db.query(User).filter(User.role == UserRole.admin).first()
            if not existing:
                admin_email = os.getenv("ADMIN_EMAIL", "admin@alahmadi.com")
                admin_pass = os.getenv("ADMIN_PASSWORD", "Admin@2026")
                admin = User(
                    name="مدير اندرويد الاحمدي",
                    email=admin_email,
                    phone="0501234567",
                    hashed_password=get_password_hash(admin_pass),
                    role=UserRole.admin,
                    is_active=True,
                    referral_code=_gen_code(db),
                )
                db.add(admin)
                db.commit()
        finally:
            db.close()
    _ensure_admin_production()

# CORS
_raw_origins = os.getenv("ALLOWED_ORIGINS", "")
if _raw_origins:
    _allowed_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]
else:
    _allowed_origins = ["https://android-al-ahmadi-store-mob.netlify.app"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Requested-With", "Accept"],
    expose_headers=["X-Phone"],
    max_age=3600,
)

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ── Routes ────────────────────────────────────────────────────────────────────
app.include_router(auth.router,               prefix="/api/auth",          tags=["Authentication"])
app.include_router(products.router,           prefix="/api/products",      tags=["Products"])
app.include_router(orders.router,             prefix="/api/orders",        tags=["Orders"])
app.include_router(reservations.router,       prefix="/api/reservations",  tags=["Reservations"])
app.include_router(maintenance.router,        prefix="/api/maintenance",   tags=["Maintenance"])
app.include_router(customers.router,          prefix="/api/customers",     tags=["Customers"])
app.include_router(dashboard.router,          prefix="/api/dashboard",     tags=["Dashboard"])
app.include_router(uploads.router,            prefix="/api/uploads",       tags=["Uploads"])
app.include_router(branches.router,           prefix="/api/branches",      tags=["Branches"])
app.include_router(inventory.router,          prefix="/api/inventory",     tags=["Inventory"])
app.include_router(referrals.router,          prefix="/api/referrals",     tags=["Referrals"])
app.include_router(warranty_routes.router,    prefix="/api/warranty",      tags=["Warranty"])
app.include_router(inspection_routes.router,  prefix="/api/inspection",    tags=["Inspection"])
app.include_router(wallet_routes.router,      prefix="/api/wallet",        tags=["Wallet"])
app.include_router(notifications.router,      prefix="/api/notifications", tags=["Notifications"])
app.include_router(search.router,             prefix="/api/search",        tags=["Search"])
app.include_router(reports.router,            prefix="/api/reports",       tags=["Reports"])
app.include_router(audit.router,              prefix="/api/audit",         tags=["Audit"])
app.include_router(staff.router,              prefix="/api/staff",         tags=["Staff"])
app.include_router(announcement_routes.router,       prefix="/api/announcements",      tags=["Announcements"])
app.include_router(loyalty_routes.router,            prefix="/api/loyalty",            tags=["Loyalty"])
app.include_router(shortage_requests_routes.router,  prefix="/api/shortage-requests",  tags=["ShortageRequests"])
app.include_router(auctions_routes.router,           prefix="/api/auctions",           tags=["Auctions"])
app.include_router(secret_deals_routes.router,       prefix="/api/secret-deals",       tags=["SecretDeals"])
app.include_router(eng_support_routes.router,        prefix="/api/eng-support",        tags=["EngSupport"])
app.include_router(complaints_routes.router,         prefix="/api/complaints",         tags=["Complaints"])
app.include_router(purchase_invoices_routes.router,  prefix="/api/purchase-invoices",  tags=["PurchaseInvoices"])
app.include_router(gallery_routes.router,            prefix="/api/gallery",            tags=["Gallery"])


@app.get("/health")
def health_check_root():
    """Root health check — used by load balancers and external monitors."""
    return {"status": "ok"}


@app.get("/api/health")
def health_check():
    return {"status": "ok", "app": "اندرويد الاحمدي", "version": "2.0.0"}


@app.get("/firebase-config")
def firebase_config():
    """
    Serve Firebase client config to the Flutter web app.
    Kept here (FastAPI) so it works from the Render.com API URL used in
    production builds — not just from the local Node proxy.
    Keys are read from environment variables, never hardcoded.
    """
    from fastapi.responses import JSONResponse
    config = {
        "apiKey":            os.getenv("FIREBASE_API_KEY", ""),
        "authDomain":        "android-al-ahmadi-store.firebaseapp.com",
        "projectId":         "android-al-ahmadi-store",
        "storageBucket":     "android-al-ahmadi-store.firebasestorage.app",
        "messagingSenderId": os.getenv("FIREBASE_MESSAGING_SENDER_ID", ""),
        "appId":             os.getenv("FIREBASE_APP_ID", ""),
    }
    return JSONResponse(content=config, headers={"Cache-Control": "no-store"})


# ── WebSocket real-time hub ────────────────────────────────────────────────────
class _WsManager:
    def __init__(self):
        self._connections: _WsList[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self._connections.append(ws)

    def disconnect(self, ws: WebSocket):
        if ws in self._connections:
            self._connections.remove(ws)

    async def broadcast(self, data: dict):
        dead = []
        for ws in self._connections:
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)


ws_manager = _WsManager()


@app.websocket("/api/ws")
async def ws_endpoint(ws: WebSocket):
    await ws_manager.connect(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect(ws)
