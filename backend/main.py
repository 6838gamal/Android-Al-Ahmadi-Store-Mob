from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from backend.core.database import engine, Base, SessionLocal
from backend.api.routes import auth, products, orders, reservations, maintenance, customers, dashboard, uploads

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="اندرويد الاحمدي API",
    description="نظام إدارة محل الجوالات",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)


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

app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(products.router, prefix="/api/products", tags=["Products"])
app.include_router(orders.router, prefix="/api/orders", tags=["Orders"])
app.include_router(reservations.router, prefix="/api/reservations", tags=["Reservations"])
app.include_router(maintenance.router, prefix="/api/maintenance", tags=["Maintenance"])
app.include_router(customers.router, prefix="/api/customers", tags=["Customers"])
app.include_router(dashboard.router, prefix="/api/dashboard", tags=["Dashboard"])
app.include_router(uploads.router, prefix="/api/uploads", tags=["Uploads"])

@app.get("/api/health")
def health_check():
    return {"status": "ok", "app": "اندرويد الاحمدي"}
