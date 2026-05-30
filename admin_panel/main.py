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
import shutil, uuid

from backend.core.database import SessionLocal, engine, Base
from backend.core.security import verify_password, get_password_hash
from backend.models.user import User, UserRole
from backend.models.product import Product, ProductCategory, ProductStatus
from backend.models.order import Order, OrderUpdate, OrderStatus, OrderType, MaintenanceStatus, PaymentMethod
from backend.models.reservation import Reservation, ReservationStatus

Base.metadata.create_all(bind=engine)

app = FastAPI(title="لوحة إدارة اندرويد الاحمدي", docs_url=None, redoc_url=None)
app.add_middleware(SessionMiddleware, secret_key=os.getenv("SECRET_KEY", "admin-alahmadi-panel-secret-2026"), max_age=86400)

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
    user = None
    if "@" in identifier:
        user = db.query(User).filter(User.email == identifier, User.role == UserRole.admin).first()
    else:
        user = db.query(User).filter(User.phone == identifier, User.role == UserRole.admin).first()

    if not user or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse(request, "login.html", {"error": "بيانات الدخول غير صحيحة"})

    request.session["admin_id"] = user.id
    request.session["admin_name"] = user.name
    return RedirectResponse("/dashboard", status_code=302)


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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("admin_panel.main:app", host="0.0.0.0", port=8080, reload=True)
