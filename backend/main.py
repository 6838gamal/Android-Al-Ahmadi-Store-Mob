from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from typing import List as _WsList
import os
import logging
import traceback
import time

# ── Logging setup ──────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("alahmadi")

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
    otp_code,
)
from backend.models.announcement import Announcement  # noqa
from backend.models.stored_image import StoredImage  # noqa

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
    settings as settings_routes,
)


async def _keep_alive_task():
    """Ping self every 10 minutes to prevent sleep on free-tier hosting (e.g. Render)."""
    import asyncio, httpx, os as _os
    self_url = _os.getenv("KEEP_ALIVE_URL", "").strip().rstrip("/")
    if not self_url:
        # بناء الـ URL تلقائياً من REPLIT_DEV_DOMAIN أو RENDER_EXTERNAL_URL
        self_url = (
            _os.getenv("RENDER_EXTERNAL_URL", "").strip().rstrip("/")
            or (f"https://{_os.getenv('REPLIT_DEV_DOMAIN', '').strip()}" if _os.getenv("REPLIT_DEV_DOMAIN") else "")
        )
    if not self_url:
        return  # لا URL — لا داعي للـ keep-alive
    ping_url = f"{self_url}/api/health"
    print(f"[KeepAlive] سيبدأ ping كل 10 دقائق → {ping_url}", flush=True)
    await asyncio.sleep(60)  # انتظر دقيقة بعد الإطلاق
    while True:
        try:
            async with httpx.AsyncClient(timeout=10, verify=False) as client:
                r = await client.get(ping_url)
            print(f"[KeepAlive] ping → {r.status_code}", flush=True)
        except Exception as e:
            print(f"[KeepAlive] خطأ: {e}", flush=True)
        await asyncio.sleep(600)  # 10 دقائق


@asynccontextmanager
async def lifespan(app: FastAPI):
    import asyncio
    task = asyncio.create_task(_keep_alive_task())
    yield
    task.cancel()


app = FastAPI(
    title="اندرويد الاحمدي API",
    description="نظام إدارة محل الجوالات",
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    lifespan=lifespan,
)


# ── Global error & timing middleware ───────────────────────────────────────────
@app.middleware("http")
async def _error_and_timing_middleware(request: Request, call_next):
    t0 = time.time()
    try:
        response = await call_next(request)
        ms = int((time.time() - t0) * 1000)
        if response.status_code >= 400:
            logger.warning("HTTP %s — %s %s (%dms)",
                           response.status_code, request.method, request.url.path, ms)
        else:
            logger.info("HTTP %s — %s %s (%dms)",
                        response.status_code, request.method, request.url.path, ms)
        return response
    except Exception as exc:
        ms = int((time.time() - t0) * 1000)
        tb = traceback.format_exc()
        logger.error(
            "💥 UNHANDLED EXCEPTION — %s %s (%dms)\n%s",
            request.method, request.url.path, ms, tb
        )
        return JSONResponse(
            status_code=500,
            content={"detail": "خطأ داخلي في الخادم — تحقق من الكونسول"},
        )


# ── Exception handler for 500 errors ──────────────────────────────────────────
@app.exception_handler(Exception)
async def _global_exception_handler(request: Request, exc: Exception):
    tb = traceback.format_exc()
    logger.error(
        "💥 EXCEPTION — %s %s\n%s",
        request.method, request.url.path, tb
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "خطأ داخلي في الخادم — تحقق من الكونسول"},
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

# CORS — open to any origin (JWT Bearer auth; no cookies on the API)
# To lock down to specific origins, set ALLOWED_ORIGINS env var (comma-separated).
_raw_origins = os.getenv("ALLOWED_ORIGINS", "")
if _raw_origins:
    _allowed_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]
    _allow_credentials = True
else:
    _allowed_origins = ["*"]
    _allow_credentials = False   # required by CORS spec when origins=*

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=_allow_credentials,
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
app.include_router(settings_routes.router,          prefix="/api/settings",           tags=["Settings"])


@app.get("/health")
def health_check_root():
    """Root health check — used by load balancers and external monitors."""
    return {"status": "ok"}


@app.get("/api/health")
def health_check():
    return {"status": "ok", "app": "اندرويد الاحمدي", "version": "2.0.0"}




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
