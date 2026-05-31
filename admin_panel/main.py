import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, Request, Form, Depends, HTTPException, UploadFile, File
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
import shutil, uuid, httpx
from datetime import datetime, timedelta

API_BASE = "https://android-al-ahmadi-store-api.onrender.com"

from backend.core.database import SessionLocal, engine, Base
from backend.core.security import verify_password, get_password_hash
from backend.core.migrations import run_migrations

# Load models in correct order (Branch before User)
from backend.models.branch import Branch, Warehouse
from backend.models.user import User, UserRole
from backend.models.product import Product, ProductCategory, ProductStatus
from backend.models.order import Order, OrderUpdate, OrderStatus, OrderType, MaintenanceStatus, PaymentMethod
from backend.models.reservation import Reservation, ReservationStatus
from backend.models.inventory_item import InventoryItem, ItemGrade, ItemStatus
from backend.models.referral import Referral
from backend.models.warranty import Warranty
from backend.models.inspection import InspectionRequest, InspectionStatus
from backend.models.wallet import WalletTransaction, TransactionType, WalletCurrency
from backend.models.notification import Notification
from backend.models.audit_log import AuditLog, AuditAction

run_migrations()
Base.metadata.create_all(bind=engine)

app = FastAPI(title="لوحة إدارة اندرويد الاحمدي", docs_url=None, redoc_url=None)
app.add_middleware(
    SessionMiddleware,
    secret_key=os.getenv("SECRET_KEY", "admin-alahmadi-panel-secret-2026"),
    max_age=86400,
    https_only=False,
    same_site="lax",
)

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
app.mount("/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")

templates = Jinja2Templates(directory=os.path.join(os.path.dirname(__file__), "templates"))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def require_admin(request: Request):
    if not request.session.get("admin_id"):
        raise HTTPException(status_code=302, headers={"Location": "/login"})
    return request.session["admin_id"]


def get_admin_or_redirect(request: Request):
    return request.session.get("admin_id")


# ─── Auth ────────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    if request.session.get("admin_id"):
        return RedirectResponse("/dashboard", status_code=302)
    return RedirectResponse("/login", status_code=302)


@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    if request.session.get("admin_id"):
        return RedirectResponse("/dashboard", status_code=302)
    return templates.TemplateResponse(request, "login.html", {"error": None})


@app.post("/login", response_class=HTMLResponse)
async def login_post(request: Request, identifier: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    identifier = identifier.strip()

    # Try external API first
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"{API_BASE}/api/admin-login",
                json={"identifier": identifier, "password": password},
            )
        if resp.status_code == 200:
            data = resp.json()
            user_data = data.get("user", {})
            if user_data.get("role") == "admin":
                request.session["admin_id"] = user_data.get("id")
                request.session["admin_name"] = user_data.get("name", "المدير")
                request.session["token"] = data.get("access_token")
                return RedirectResponse("/dashboard", status_code=303)
    except Exception:
        pass

    # Fallback: local database
    user = None
    if "@" in identifier:
        user = db.query(User).filter(User.email == identifier, User.role == UserRole.admin).first()
    else:
        user = db.query(User).filter(User.phone == identifier, User.role == UserRole.admin).first()

    if not user or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse(request, "login.html", {"error": "بيانات الدخول غير صحيحة"})

    request.session["admin_id"] = user.id
    request.session["admin_name"] = user.name
    return RedirectResponse("/dashboard", status_code=303)


@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/login", status_code=302)


# ─── Dashboard ────────────────────────────────────────────────────────────────

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    total_orders = db.query(Order).count()
    active_orders = db.query(Order).filter(Order.status.not_in([OrderStatus.delivered, OrderStatus.cancelled])).count()
    total_revenue = db.query(func.sum(Order.total)).filter(Order.status == OrderStatus.delivered).scalar() or 0
    total_products = db.query(Product).filter(Product.is_active == True).count()
    total_customers = db.query(User).filter(User.role == UserRole.customer).count()
    maintenance_count = db.query(Order).filter(Order.order_type == OrderType.maintenance).count()
    low_stock = db.query(Product).filter(Product.quantity <= 3, Product.is_active == True).count()
    available_products = db.query(Product).filter(Product.status == ProductStatus.available, Product.is_active == True).count()
    recent_orders = db.query(Order).order_by(Order.created_at.desc()).limit(8).all()

    status_labels = {
        "received": "مستلم", "reviewing": "قيد المراجعة", "confirmed": "مؤكد",
        "preparing": "جاري التحضير", "shipped": "تم الشحن", "on_the_way": "في الطريق",
        "delivered": "تم التسليم", "cancelled": "ملغي",
    }
    status_colors = {
        "received": "#6B7280", "reviewing": "#F59E0B", "confirmed": "#3B82F6",
        "preparing": "#8B5CF6", "shipped": "#06B6D4", "on_the_way": "#10B981",
        "delivered": "#22C55E", "cancelled": "#EF4444",
    }

    return templates.TemplateResponse(request, "dashboard.html", {
        "admin_name": request.session.get("admin_name", "المدير"),
        "total_orders": total_orders, "active_orders": active_orders,
        "total_revenue": round(total_revenue, 2), "total_products": total_products,
        "total_customers": total_customers, "maintenance_count": maintenance_count,
        "low_stock": low_stock, "available_products": available_products,
        "recent_orders": recent_orders, "status_labels": status_labels,
        "status_colors": status_colors,
    })


# ─── Products ─────────────────────────────────────────────────────────────────

@app.get("/products", response_class=HTMLResponse)
async def products_list(request: Request, search: str = "", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    query = db.query(Product).filter(Product.is_active == True)
    if search:
        query = query.filter(
            Product.name.ilike(f"%{search}%") |
            Product.brand.ilike(f"%{search}%") |
            Product.model.ilike(f"%{search}%")
        )
    products = query.order_by(Product.created_at.desc()).all()
    categories = {c.value: c.value for c in ProductCategory}
    status_map = {"available": "متوفر", "reserved": "محجوز", "sold": "مباع", "unavailable": "غير متوفر"}
    cat_map = {"screen": "شاشة", "battery": "بطارية", "camera": "كاميرا", "speaker": "سماعة",
               "charger": "شاحن", "device": "جهاز", "spare_part": "قطعة غيار", "other": "أخرى"}
    return templates.TemplateResponse(request, "products.html", {
        "admin_name": request.session.get("admin_name"),
        "products": products, "search": search, "status_map": status_map, "cat_map": cat_map,
    })


@app.get("/products/add", response_class=HTMLResponse)
async def product_add_page(request: Request):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    return templates.TemplateResponse(request, "product_form.html", {
        "admin_name": request.session.get("admin_name"),
        "product": None, "error": None,
        "categories": [("screen", "شاشة"), ("battery", "بطارية"), ("camera", "كاميرا"),
                       ("speaker", "سماعة"), ("charger", "شاحن"), ("device", "جهاز"),
                       ("spare_part", "قطعة غيار"), ("other", "أخرى")],
    })


@app.post("/products/add", response_class=HTMLResponse)
async def product_add_post(
    request: Request,
    name: str = Form(...), name_ar: str = Form(""), brand: str = Form(""),
    model: str = Form(""), category: str = Form(...), price: float = Form(...),
    quantity: int = Form(0), description: str = Form(""), notes: str = Form(""),
    is_featured: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    image_url = None
    if image and image.filename:
        ext = os.path.splitext(image.filename)[1]
        fname = f"{uuid.uuid4().hex}{ext}"
        fpath = os.path.join(UPLOAD_DIR, fname)
        with open(fpath, "wb") as f:
            shutil.copyfileobj(image.file, f)
        image_url = f"/uploads/{fname}"

    product = Product(
        name=name, name_ar=name_ar or None, brand=brand or None, model=model or None,
        category=ProductCategory(category), price=price, quantity=quantity,
        description=description or None, notes=notes or None,
        is_featured=bool(is_featured), image_url=image_url,
    )
    db.add(product)
    db.commit()
    return RedirectResponse("/products", status_code=302)


@app.get("/products/edit/{product_id}", response_class=HTMLResponse)
async def product_edit_page(product_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        return RedirectResponse("/products", status_code=302)
    return templates.TemplateResponse(request, "product_form.html", {
        "admin_name": request.session.get("admin_name"),
        "product": product, "error": None,
        "categories": [("screen", "شاشة"), ("battery", "بطارية"), ("camera", "كاميرا"),
                       ("speaker", "سماعة"), ("charger", "شاحن"), ("device", "جهاز"),
                       ("spare_part", "قطعة غيار"), ("other", "أخرى")],
    })


@app.post("/products/edit/{product_id}", response_class=HTMLResponse)
async def product_edit_post(
    product_id: int, request: Request,
    name: str = Form(...), name_ar: str = Form(""), brand: str = Form(""),
    model: str = Form(""), category: str = Form(...), price: float = Form(...),
    quantity: int = Form(0), description: str = Form(""), notes: str = Form(""),
    is_featured: Optional[str] = Form(None), status: str = Form("available"),
    image: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        return RedirectResponse("/products", status_code=302)

    if image and image.filename:
        ext = os.path.splitext(image.filename)[1]
        fname = f"{uuid.uuid4().hex}{ext}"
        fpath = os.path.join(UPLOAD_DIR, fname)
        with open(fpath, "wb") as f:
            shutil.copyfileobj(image.file, f)
        product.image_url = f"/uploads/{fname}"

    product.name = name
    product.name_ar = name_ar or None
    product.brand = brand or None
    product.model = model or None
    product.category = ProductCategory(category)
    product.price = price
    product.quantity = quantity
    product.description = description or None
    product.notes = notes or None
    product.is_featured = bool(is_featured)
    product.status = ProductStatus(status)
    db.commit()
    return RedirectResponse("/products", status_code=302)


@app.post("/products/delete/{product_id}")
async def product_delete(product_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    product = db.query(Product).filter(Product.id == product_id).first()
    if product:
        product.is_active = False
        db.commit()
    return RedirectResponse("/products", status_code=302)


# ─── Orders ───────────────────────────────────────────────────────────────────

@app.get("/orders", response_class=HTMLResponse)
async def orders_list(request: Request, status_filter: str = "", search: str = "", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    query = db.query(Order).filter(Order.order_type == OrderType.product)
    if status_filter:
        query = query.filter(Order.status == OrderStatus(status_filter))
    if search:
        query = query.filter(
            Order.customer_name.ilike(f"%{search}%") |
            Order.order_number.ilike(f"%{search}%") |
            Order.customer_phone.ilike(f"%{search}%")
        )
    orders = query.order_by(Order.created_at.desc()).all()

    status_labels = {
        "received": "مستلم", "reviewing": "قيد المراجعة", "confirmed": "مؤكد",
        "preparing": "جاري التحضير", "shipped": "تم الشحن", "on_the_way": "في الطريق",
        "delivered": "تم التسليم", "cancelled": "ملغي",
    }
    status_colors = {
        "received": "#6B7280", "reviewing": "#F59E0B", "confirmed": "#3B82F6",
        "preparing": "#8B5CF6", "shipped": "#06B6D4", "on_the_way": "#10B981",
        "delivered": "#22C55E", "cancelled": "#EF4444",
    }
    return templates.TemplateResponse(request, "orders.html", {
        "admin_name": request.session.get("admin_name"),
        "orders": orders, "status_labels": status_labels, "status_colors": status_colors,
        "status_filter": status_filter, "search": search,
        "all_statuses": list(status_labels.items()),
    })


@app.get("/orders/{order_id}", response_class=HTMLResponse)
async def order_detail(order_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        return RedirectResponse("/orders", status_code=302)
    status_labels = {
        "received": "مستلم", "reviewing": "قيد المراجعة", "confirmed": "مؤكد",
        "preparing": "جاري التحضير", "shipped": "تم الشحن", "on_the_way": "في الطريق",
        "delivered": "تم التسليم", "cancelled": "ملغي",
    }
    return templates.TemplateResponse(request, "order_detail.html", {
        "admin_name": request.session.get("admin_name"),
        "order": order, "status_labels": status_labels,
        "all_statuses": list(status_labels.items()),
    })


@app.post("/orders/{order_id}/status")
async def update_order_status(
    order_id: int, request: Request,
    status: str = Form(...), note: str = Form(""), admin_notes: str = Form(""),
    estimated_time: str = Form(""), employee_name: str = Form(""),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    order = db.query(Order).filter(Order.id == order_id).first()
    if order:
        order.status = OrderStatus(status)
        if admin_notes:
            order.admin_notes = admin_notes
        if estimated_time:
            order.estimated_time = estimated_time
        if employee_name:
            order.employee_name = employee_name
        upd = OrderUpdate(
            order_id=order.id, status=status,
            note=note or None,
            employee_name=employee_name or request.session.get("admin_name"),
        )
        db.add(upd)
        db.commit()
    return RedirectResponse(f"/orders/{order_id}", status_code=302)


# ─── Maintenance ──────────────────────────────────────────────────────────────

@app.get("/maintenance", response_class=HTMLResponse)
async def maintenance_list(request: Request, search: str = "", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    query = db.query(Order).filter(Order.order_type == OrderType.maintenance)
    if search:
        query = query.filter(
            Order.customer_name.ilike(f"%{search}%") |
            Order.order_number.ilike(f"%{search}%") |
            Order.customer_phone.ilike(f"%{search}%")
        )
    orders = query.order_by(Order.created_at.desc()).all()

    maint_labels = {
        "received": "مستلم", "inspecting": "قيد الفحص", "repairing": "جاري الإصلاح",
        "waiting_part": "انتظار قطعة", "repaired": "تم الإصلاح", "ready": "جاهز للاستلام",
        "delivered": "تم التسليم",
    }
    maint_colors = {
        "received": "#6B7280", "inspecting": "#F59E0B", "repairing": "#8B5CF6",
        "waiting_part": "#EF4444", "repaired": "#06B6D4", "ready": "#10B981", "delivered": "#22C55E",
    }
    return templates.TemplateResponse(request, "maintenance.html", {
        "admin_name": request.session.get("admin_name"),
        "orders": orders, "maint_labels": maint_labels, "maint_colors": maint_colors,
        "search": search, "all_maint_statuses": list(maint_labels.items()),
    })


@app.post("/maintenance/add")
async def maintenance_add(
    request: Request,
    customer_name: str = Form(...), customer_phone: str = Form(...),
    customer_email: str = Form(""), device_type: str = Form(...),
    problem_description: str = Form(...), price: float = Form(0),
    notes: str = Form(""), db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    count = db.query(Order).filter(Order.order_type == OrderType.maintenance).count() + 1
    from datetime import datetime
    order_num = f"MAINT-{datetime.now().year}-{count:04d}"

    order = Order(
        order_number=order_num, customer_name=customer_name, customer_phone=customer_phone,
        customer_email=customer_email or None, order_type=OrderType.maintenance,
        status=OrderStatus.received, maintenance_status=MaintenanceStatus.received,
        items=[{"device": device_type, "problem": problem_description}],
        total=price, subtotal=price, notes=notes or None, payment_method=PaymentMethod.cash,
    )
    db.add(order)
    db.flush()
    db.add(OrderUpdate(order_id=order.id, status="received", note="تم استلام الجهاز"))
    db.commit()
    return RedirectResponse("/maintenance", status_code=302)


@app.post("/maintenance/{order_id}/status")
async def update_maintenance_status(
    order_id: int, request: Request,
    maintenance_status: str = Form(...), note: str = Form(""),
    admin_notes: str = Form(""), estimated_time: str = Form(""),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    order = db.query(Order).filter(Order.id == order_id).first()
    if order:
        order.maintenance_status = MaintenanceStatus(maintenance_status)
        if maintenance_status == "delivered":
            order.status = OrderStatus.delivered
        if admin_notes:
            order.admin_notes = admin_notes
        if estimated_time:
            order.estimated_time = estimated_time
        upd = OrderUpdate(
            order_id=order.id, status=maintenance_status,
            note=note or None,
            employee_name=request.session.get("admin_name"),
        )
        db.add(upd)
        db.commit()
    return RedirectResponse("/maintenance", status_code=302)


# ─── Reservations ─────────────────────────────────────────────────────────────

@app.get("/reservations", response_class=HTMLResponse)
async def reservations_list(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    reservations = db.query(Reservation).order_by(Reservation.created_at.desc()).all()
    status_labels = {"pending": "قيد الانتظار", "confirmed": "مؤكد", "cancelled": "ملغي", "completed": "مكتمل"}
    status_colors = {"pending": "#F59E0B", "confirmed": "#22C55E", "cancelled": "#EF4444", "completed": "#06B6D4"}
    available_products = db.query(Product).filter(Product.status == ProductStatus.available, Product.is_active == True).all()

    return templates.TemplateResponse(request, "reservations.html", {
        "admin_name": request.session.get("admin_name"),
        "reservations": reservations, "status_labels": status_labels, "status_colors": status_colors,
        "available_products": available_products,
    })


@app.post("/reservations/add")
async def reservation_add(
    request: Request,
    customer_name: str = Form(...), customer_phone: str = Form(...),
    product_id: int = Form(...), notes: str = Form(""), days: int = Form(3),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    product = db.query(Product).filter(Product.id == product_id).first()
    if product and product.status == ProductStatus.available:
        from datetime import datetime, timedelta
        product.status = ProductStatus.reserved
        count = db.query(Reservation).count() + 1
        res = Reservation(
            reservation_number=f"RES-{datetime.now().year}-{count:04d}",
            customer_name=customer_name, customer_phone=customer_phone,
            product_id=product_id, product_name=product.name, price=product.price,
            notes=notes or None, expires_at=datetime.utcnow() + timedelta(days=days),
        )
        db.add(res)
        db.commit()
    return RedirectResponse("/reservations", status_code=302)


@app.post("/reservations/{res_id}/cancel")
async def reservation_cancel(res_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if res:
        res.status = ReservationStatus.cancelled
        product = db.query(Product).filter(Product.id == res.product_id).first()
        if product:
            product.status = ProductStatus.available
        db.commit()
    return RedirectResponse("/reservations", status_code=302)


@app.post("/reservations/{res_id}/complete")
async def reservation_complete(res_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    res = db.query(Reservation).filter(Reservation.id == res_id).first()
    if res:
        res.status = ReservationStatus.completed
        product = db.query(Product).filter(Product.id == res.product_id).first()
        if product:
            product.status = ProductStatus.sold
        db.commit()
    return RedirectResponse("/reservations", status_code=302)


# ─── Customers ────────────────────────────────────────────────────────────────

@app.get("/customers", response_class=HTMLResponse)
async def customers_list(request: Request, search: str = "", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    query = db.query(User).filter(User.role == UserRole.customer)
    if search:
        query = query.filter(
            User.name.ilike(f"%{search}%") |
            User.phone.ilike(f"%{search}%") |
            User.email.ilike(f"%{search}%")
        )
    customers = query.order_by(User.created_at.desc()).all()
    return templates.TemplateResponse(request, "customers.html", {
        "admin_name": request.session.get("admin_name"),
        "customers": customers, "search": search,
    })


# ─── Inventory Items ───────────────────────────────────────────────────────────

@app.get("/inventory", response_class=HTMLResponse)
async def inventory_list(request: Request, search: str = "", status_filter: str = "", grade_filter: str = "", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    q = db.query(InventoryItem).filter(InventoryItem.is_active == True)
    if search:
        q = q.filter(
            InventoryItem.serial_number.ilike(f"%{search}%") |
            InventoryItem.brand.ilike(f"%{search}%") |
            InventoryItem.model.ilike(f"%{search}%")
        )
    if status_filter:
        q = q.filter(InventoryItem.status == ItemStatus(status_filter))
    if grade_filter:
        q = q.filter(InventoryItem.grade == grade_filter)
    items = q.order_by(InventoryItem.created_at.desc()).all()
    total = db.query(InventoryItem).filter(InventoryItem.is_active == True).count()
    available = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.available).count()
    reserved = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.reserved).count()
    sold = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.sold).count()
    return templates.TemplateResponse(request, "inventory.html", {
        "admin_name": request.session.get("admin_name"), "active": "inventory",
        "items": items, "search": search, "status_filter": status_filter, "grade_filter": grade_filter,
        "stats": {"total": total, "available": available, "reserved": reserved, "sold": sold},
    })


@app.post("/inventory/add")
async def inventory_add(
    request: Request,
    serial_number: str = Form(""), category: str = Form(...),
    brand: str = Form(""), model: str = Form(""), grade: str = Form("A"),
    price: float = Form(...), notes: str = Form(""),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    item = InventoryItem(
        serial_number=serial_number or None,
        category=category, brand=brand or None, model=model or None,
        grade=grade, price=price, notes=notes or None,
    )
    db.add(item)
    db.commit()
    return RedirectResponse("/inventory", status_code=302)


@app.post("/inventory/{item_id}/sell")
async def inventory_sell(item_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if item:
        item.status = ItemStatus.sold
        db.commit()
    return RedirectResponse("/inventory", status_code=302)


@app.post("/inventory/{item_id}/return-stock")
async def inventory_return_stock(item_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    item = db.query(InventoryItem).filter(InventoryItem.id == item_id).first()
    if item:
        item.status = ItemStatus.available
        item.sold_to_id = None
        db.commit()
    return RedirectResponse("/inventory", status_code=302)


# ─── Inspection ────────────────────────────────────────────────────────────────

@app.get("/inspection", response_class=HTMLResponse)
async def inspection_list(request: Request, status: str = "", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    q = db.query(InspectionRequest)
    if status:
        q = q.filter(InspectionRequest.status == InspectionStatus(status))
    requests = q.order_by(InspectionRequest.created_at.desc()).all()
    return templates.TemplateResponse(request, "inspection.html", {
        "admin_name": request.session.get("admin_name"), "active": "inspection",
        "requests": requests,
    })


@app.post("/inspection/{req_id}/respond")
async def inspection_respond(
    req_id: int, request: Request,
    diagnosis: str = Form(...), estimated_price: str = Form(""),
    response_notes: str = Form(""), db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    req = db.query(InspectionRequest).filter(InspectionRequest.id == req_id).first()
    if req:
        req.staff_id = request.session.get("admin_id")
        req.diagnosis = diagnosis
        req.estimated_price = estimated_price or None
        req.response_notes = response_notes or None
        req.status = InspectionStatus.responded
        req.responded_at = datetime.utcnow()
        db.commit()
    return RedirectResponse("/inspection", status_code=302)


@app.post("/inspection/{req_id}/close")
async def inspection_close(req_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    req = db.query(InspectionRequest).filter(InspectionRequest.id == req_id).first()
    if req:
        req.status = InspectionStatus.closed
        db.commit()
    return RedirectResponse("/inspection", status_code=302)


# ─── Referrals ─────────────────────────────────────────────────────────────────

@app.get("/referrals", response_class=HTMLResponse)
async def referrals_list(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    referrals = db.query(Referral).order_by(Referral.created_at.desc()).all()
    total = len(referrals)
    verified = sum(1 for r in referrals if r.is_verified)
    from sqlalchemy import func as sqlfunc
    top_referrers = (
        db.query(User, sqlfunc.count(Referral.id).label("count"))
        .join(Referral, Referral.referrer_id == User.id)
        .group_by(User.id)
        .order_by(sqlfunc.count(Referral.id).desc())
        .limit(10).all()
    )
    return templates.TemplateResponse(request, "referrals.html", {
        "admin_name": request.session.get("admin_name"), "active": "referrals",
        "referrals": referrals, "total": total, "verified": verified,
        "top_referrers": [type("R", (), {"referrer": u, "count": c})() for u, c in top_referrers],
    })


# ─── Warranty ──────────────────────────────────────────────────────────────────

@app.get("/warranty", response_class=HTMLResponse)
async def warranty_list(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    warranties = db.query(Warranty).order_by(Warranty.created_at.desc()).all()
    return_requests = sum(1 for w in warranties if w.is_return_requested and not w.return_resolved)
    return templates.TemplateResponse(request, "warranty.html", {
        "admin_name": request.session.get("admin_name"), "active": "warranty",
        "warranties": warranties, "return_requests": return_requests,
        "now_dt": datetime.utcnow(),
    })


@app.post("/warranty/add")
async def warranty_add(
    request: Request,
    product_name: str = Form(...), product_serial: str = Form(""),
    order_id: int = Form(None), warranty_days: int = Form(7),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    starts = datetime.utcnow()
    w = Warranty(
        product_name=product_name,
        product_serial=product_serial or None,
        order_id=order_id,
        warranty_days=warranty_days,
        starts_at=starts,
        ends_at=starts + timedelta(days=warranty_days),
    )
    db.add(w)
    db.commit()
    return RedirectResponse("/warranty", status_code=302)


@app.post("/warranty/{warranty_id}/resolve")
async def warranty_resolve(warranty_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    w = db.query(Warranty).filter(Warranty.id == warranty_id).first()
    if w:
        w.return_resolved = True
        w.return_notes = "تم الحل من لوحة الإدارة"
        db.commit()
    return RedirectResponse("/warranty", status_code=302)


# ─── Customer Management (Admin CRUD) ─────────────────────────────────────────

@app.post("/customers/add")
async def customer_add(
    request: Request,
    name: str = Form(...), phone: str = Form(...),
    email: str = Form(""), password: str = Form(...),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    import random, string
    code = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
    user = User(
        name=name, phone=phone or None, email=email or None,
        hashed_password=get_password_hash(password),
        role=UserRole.customer, is_active=True, referral_code=code,
    )
    db.add(user)
    db.commit()
    return RedirectResponse("/customers", status_code=302)


@app.post("/customers/{user_id}/toggle-active")
async def customer_toggle(user_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    user = db.query(User).filter(User.id == user_id, User.role == UserRole.customer).first()
    if user:
        user.is_active = not user.is_active
        db.commit()
    return RedirectResponse("/customers", status_code=302)


@app.post("/customers/{user_id}/delete")
async def customer_delete(user_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    user = db.query(User).filter(User.id == user_id, User.role == UserRole.customer).first()
    if user:
        db.delete(user)
        db.commit()
    return RedirectResponse("/customers", status_code=302)


# ─── Staff Management ──────────────────────────────────────────────────────────

@app.get("/staff", response_class=HTMLResponse)
async def staff_list(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    staff = db.query(User).filter(User.role.in_([UserRole.staff, UserRole.branch_manager, UserRole.admin])).order_by(User.created_at.desc()).all()
    return templates.TemplateResponse(request, "staff.html", {
        "admin_name": request.session.get("admin_name"), "active": "staff",
        "staff": staff,
    })


@app.post("/staff/add")
async def staff_add(
    request: Request,
    name: str = Form(...), phone: str = Form(""), email: str = Form(""),
    role: str = Form("staff"), password: str = Form(...),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    import random, string
    code = "".join(random.choices(string.ascii_uppercase + string.digits, k=8))
    user = User(
        name=name, phone=phone or None, email=email or None,
        hashed_password=get_password_hash(password),
        role=UserRole(role), is_active=True, referral_code=code,
    )
    db.add(user)
    db.commit()
    return RedirectResponse("/staff", status_code=302)


@app.post("/staff/{user_id}/toggle-active")
async def staff_toggle(user_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.is_active = not user.is_active
        db.commit()
    return RedirectResponse("/staff", status_code=302)


@app.post("/staff/{user_id}/edit")
async def staff_edit(
    user_id: int, request: Request,
    name: str = Form(...), phone: str = Form(""),
    email: str = Form(""), role: str = Form("staff"),
    password: str = Form(""), db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    user = db.query(User).filter(User.id == user_id).first()
    if user and user.role != UserRole.admin:
        user.name = name
        user.phone = phone or None
        user.email = email or None
        try:
            user.role = UserRole(role)
        except ValueError:
            pass
        if password:
            user.hashed_password = get_password_hash(password)
        db.commit()
    return RedirectResponse("/staff", status_code=302)


@app.post("/staff/{user_id}/delete")
async def staff_delete(user_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    user = db.query(User).filter(User.id == user_id).first()
    if user and user.role != UserRole.admin:
        db.delete(user)
        db.commit()
    return RedirectResponse("/staff", status_code=302)


# ─── Branches Management ───────────────────────────────────────────────────────

@app.get("/branches", response_class=HTMLResponse)
async def branches_list(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    branches = db.query(Branch).order_by(Branch.created_at.desc()).all()
    warehouses = db.query(Warehouse).all()
    return templates.TemplateResponse(request, "branches.html", {
        "admin_name": request.session.get("admin_name"), "active": "branches",
        "branches": branches, "warehouses": warehouses,
    })


@app.post("/branches/add")
async def branch_add(
    request: Request,
    name: str = Form(...), city: str = Form(""),
    address: str = Form(""), phone: str = Form(""),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    b = Branch(name=name, city=city or None, address=address or None, phone=phone or None)
    db.add(b)
    db.commit()
    return RedirectResponse("/branches", status_code=302)


@app.post("/branches/{branch_id}/edit")
async def branch_edit(
    branch_id: int, request: Request,
    name: str = Form(...), city: str = Form(""),
    address: str = Form(""), phone: str = Form(""),
    is_active: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    b = db.query(Branch).filter(Branch.id == branch_id).first()
    if b:
        b.name = name
        b.city = city or None
        b.address = address or None
        b.phone = phone or None
        b.is_active = bool(is_active)
        db.commit()
    return RedirectResponse("/branches", status_code=302)


@app.post("/branches/{branch_id}/delete")
async def branch_delete(branch_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    b = db.query(Branch).filter(Branch.id == branch_id).first()
    if b:
        db.delete(b)
        db.commit()
    return RedirectResponse("/branches", status_code=302)


# ─── Notifications ─────────────────────────────────────────────────────────────

@app.get("/notifications", response_class=HTMLResponse)
async def notifications_list(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    notifs = db.query(Notification).order_by(Notification.created_at.desc()).limit(300).all()
    total = len(notifs)
    unread = sum(1 for n in notifs if not n.is_read)
    customers = db.query(User).filter(User.role == UserRole.customer, User.is_active == True).all()
    return templates.TemplateResponse(request, "notifications.html", {
        "admin_name": request.session.get("admin_name"), "active": "notifications",
        "notifs": notifs, "total": total, "unread": unread, "customers": customers,
    })


@app.post("/notifications/send")
async def notification_send(
    request: Request,
    title: str = Form(...), message: str = Form(...),
    user_id: Optional[int] = Form(None), broadcast: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    if broadcast:
        users = db.query(User).filter(User.role == UserRole.customer, User.is_active == True).all()
        for u in users:
            db.add(Notification(user_id=u.id, title=title, message=message, type="info"))
    elif user_id:
        db.add(Notification(user_id=user_id, title=title, message=message, type="info"))
    db.commit()
    return RedirectResponse("/notifications", status_code=302)


@app.post("/notifications/{notif_id}/delete")
async def notification_delete(notif_id: int, request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    n = db.query(Notification).filter(Notification.id == notif_id).first()
    if n:
        db.delete(n)
        db.commit()
    return RedirectResponse("/notifications", status_code=302)


# ─── Reports ───────────────────────────────────────────────────────────────────

@app.get("/reports", response_class=HTMLResponse)
async def reports_page(request: Request, period: str = "month", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)

    now = datetime.utcnow()
    period_map = {"today": 0, "week": 7, "month": 30, "year": 365}
    days = period_map.get(period, 30)
    start = now.replace(hour=0, minute=0, second=0) if period == "today" else now - timedelta(days=days)

    from backend.models.order import OrderType as OT
    q = db.query(Order).filter(Order.status == OrderStatus.delivered)
    if days:
        q = q.filter(Order.created_at >= start)
    delivered = q.all()
    total_revenue = sum(o.total for o in delivered)
    total_discount = sum(o.discount or 0 for o in delivered)

    maint_q = db.query(Order).filter(Order.order_type == OT.maintenance)
    if days:
        maint_q = maint_q.filter(Order.created_at >= start)
    maint_orders = maint_q.all()
    maint_done = [o for o in maint_orders if o.status == OrderStatus.delivered]

    inv_total = db.query(InventoryItem).filter(InventoryItem.is_active == True).count()
    inv_avail = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.available).count()
    inv_sold = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.sold).count()
    inv_res = db.query(InventoryItem).filter(InventoryItem.is_active == True, InventoryItem.status == ItemStatus.reserved).count()
    low_stock = db.query(Product).filter(Product.is_active == True, Product.quantity <= 3).all()

    ref_total = db.query(Referral).count()
    ref_verified = db.query(Referral).filter(Referral.is_verified == True).count()

    war_total = db.query(Warranty).count()
    war_ret = db.query(Warranty).filter(Warranty.is_return_requested == True).count()
    war_res = db.query(Warranty).filter(Warranty.return_resolved == True).count()

    sales = {"total_orders": len(delivered), "total_revenue": round(total_revenue, 2),
             "average_order_value": round(total_revenue / len(delivered), 2) if delivered else 0}
    profit = {"net_revenue": round(total_revenue - total_discount, 2), "total_discount": round(total_discount, 2)}
    inv = {"total_items": inv_total, "available": inv_avail, "sold": inv_sold, "reserved": inv_res,
           "low_stock_products": low_stock}
    maint = {"total_requests": len(maint_orders), "completed": len(maint_done),
              "total_revenue": round(sum(o.total for o in maint_done), 2)}
    ref = {"total_referrals": ref_total, "verified_referrals": ref_verified}
    war = {"total_warranties": war_total, "return_requests": war_ret, "resolved_returns": war_res,
           "pending_returns": war_ret - war_res}

    return templates.TemplateResponse(request, "reports.html", {
        "admin_name": request.session.get("admin_name"), "active": "reports",
        "period": period, "sales": sales, "profit": profit,
        "inv": inv, "maint": maint, "ref": ref, "war": war,
    })


# ─── Audit Log ─────────────────────────────────────────────────────────────────

@app.get("/audit", response_class=HTMLResponse)
async def audit_list(request: Request, db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    logs = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(200).all()
    return templates.TemplateResponse(request, "audit.html", {
        "admin_name": request.session.get("admin_name"), "active": "audit",
        "logs": logs,
    })


# ─── Wallet Management ─────────────────────────────────────────────────────────

@app.get("/wallet", response_class=HTMLResponse)
async def wallet_list(request: Request, search: str = "", db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    q = db.query(User).filter(User.role == UserRole.customer)
    if search:
        q = q.filter(
            User.name.ilike(f"%{search}%") |
            User.phone.ilike(f"%{search}%") |
            User.email.ilike(f"%{search}%")
        )
    users = q.order_by(User.created_at.desc()).all()
    return templates.TemplateResponse(request, "wallet.html", {
        "admin_name": request.session.get("admin_name"), "active": "wallet",
        "users": users, "search": search,
    })


@app.post("/wallet/{user_id}/credit")
async def wallet_credit(user_id: int, request: Request, amount: float = Form(...), db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.wallet_balance = (user.wallet_balance or 0.0) + amount
        tx = WalletTransaction(user_id=user_id, amount=amount, currency="YER",
                               transaction_type=TransactionType.credit, reason="إضافة من لوحة الإدارة",
                               balance_after=user.wallet_balance)
        db.add(tx)
        db.commit()
    return RedirectResponse("/wallet", status_code=302)


@app.post("/wallet/{user_id}/debit")
async def wallet_debit(user_id: int, request: Request, amount: float = Form(...), db: Session = Depends(get_db)):
    if not request.session.get("admin_id"):
        return RedirectResponse("/login", status_code=302)
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.wallet_balance = (user.wallet_balance or 0.0) - amount
        tx = WalletTransaction(user_id=user_id, amount=amount, currency="YER",
                               transaction_type=TransactionType.debit, reason="خصم من لوحة الإدارة",
                               balance_after=user.wallet_balance)
        db.add(tx)
        db.commit()
    return RedirectResponse("/wallet", status_code=302)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("admin_panel.main:app", host="0.0.0.0", port=8080, reload=True)
