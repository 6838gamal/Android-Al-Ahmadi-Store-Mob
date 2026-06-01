import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, Request, Form, UploadFile, File
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware
from typing import Optional
from types import SimpleNamespace
from datetime import datetime
import httpx

# ── External Render.com API ────────────────────────────────────────────────────
API_BASE = os.getenv("API_BASE", "http://127.0.0.1:8000")

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

# ── Helpers ────────────────────────────────────────────────────────────────────

_DT_KEYS = frozenset({
    "created_at", "updated_at", "expires_at", "starts_at", "ends_at",
    "responded_at", "warranty_start", "warranty_end", "resolved_at",
})

def _parse_dt(v: str):
    try:
        return datetime.fromisoformat(v.replace("Z", "+00:00")).replace(tzinfo=None)
    except Exception:
        return v

def to_obj(data):
    """Recursively convert API dicts/lists to attribute-accessible SimpleNamespace objects."""
    if isinstance(data, list):
        return [to_obj(i) for i in data]
    if isinstance(data, dict):
        converted = {}
        for k, v in data.items():
            if isinstance(v, str) and k in _DT_KEYS:
                converted[k] = _parse_dt(v)
            else:
                converted[k] = to_obj(v)
        return SimpleNamespace(**converted)
    return data


async def api(method: str, path: str, token: str = None, **kwargs):
    """Call the Render.com API; returns parsed JSON on success, None on error."""
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        async with httpx.AsyncClient(timeout=25.0, follow_redirects=True) as client:
            resp = await getattr(client, method)(
                f"{API_BASE}{path}", headers=headers, **kwargs
            )
        if resp.status_code in (200, 201):
            return resp.json()
    except Exception as e:
        print(f"[admin] API error {method.upper()} {path}: {e}")
    return None


def _token(req: Request) -> str:
    return req.session.get("token", "")

def _name(req: Request) -> str:
    return req.session.get("admin_name", "المدير")

def _logged(req: Request) -> bool:
    return bool(req.session.get("admin_id"))

def _redirect_login():
    return RedirectResponse("/login", status_code=302)

# ── Auth ────────────────────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    return RedirectResponse("/dashboard" if _logged(request) else "/login", status_code=302)


@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    if _logged(request):
        return RedirectResponse("/dashboard", status_code=302)
    return templates.TemplateResponse(request, "login.html", {"error": None})


@app.post("/login", response_class=HTMLResponse)
async def login_post(request: Request, identifier: str = Form(...), password: str = Form(...)):
    identifier = identifier.strip()
    data = await api("post", "/api/auth/admin-login",
                     json={"identifier": identifier, "password": password})
    if data:
        user_data = data.get("user", {})
        if user_data.get("role") == "admin":
            request.session["admin_id"]   = user_data.get("id")
            request.session["admin_name"] = user_data.get("name", "المدير")
            request.session["token"]      = data.get("access_token")
            return RedirectResponse("/dashboard", status_code=303)
    return templates.TemplateResponse(request, "login.html",
                                      {"error": "بيانات الدخول غير صحيحة أو الخادم غير متاح حالياً"})


@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/login", status_code=302)


# ── Dashboard ───────────────────────────────────────────────────────────────────

@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request):
    if not _logged(request):
        return _redirect_login()

    stats = await api("get", "/api/dashboard/stats", token=_token(request)) or {}
    recent_orders = [to_obj(o) for o in stats.get("recent_orders", [])]

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
        "admin_name":        _name(request),
        "active":            "dashboard",
        "total_orders":      stats.get("total_orders", 0),
        "active_orders":     stats.get("active_orders", 0),
        "total_revenue":     stats.get("total_revenue", 0),
        "total_products":    stats.get("total_products", 0),
        "total_customers":   stats.get("total_customers", 0),
        "maintenance_count": stats.get("maintenance_count", 0),
        "low_stock":         stats.get("low_stock_count", 0),
        "available_products":stats.get("available_products", 0),
        "recent_orders":     recent_orders,
        "status_labels":     status_labels,
        "status_colors":     status_colors,
    })


# ── Products ────────────────────────────────────────────────────────────────────

@app.get("/products", response_class=HTMLResponse)
async def products_list(request: Request, search: str = ""):
    if not _logged(request):
        return _redirect_login()
    params = {"limit": 500}
    if search:
        params["search"] = search
    raw = await api("get", "/api/products/", token=_token(request), params=params) or []
    products = to_obj(raw)
    status_map = {"available": "متوفر", "reserved": "محجوز", "sold": "مباع", "unavailable": "غير متوفر"}
    cat_map    = {"screen": "شاشة", "battery": "بطارية", "camera": "كاميرا", "speaker": "سماعة",
                  "charger": "شاحن", "device": "جهاز", "spare_part": "قطعة غيار", "other": "أخرى"}
    return templates.TemplateResponse(request, "products.html", {
        "admin_name": _name(request), "active": "products",
        "products": products, "search": search,
        "status_map": status_map, "cat_map": cat_map,
    })


@app.get("/products/add", response_class=HTMLResponse)
async def product_add_page(request: Request):
    if not _logged(request):
        return _redirect_login()
    return templates.TemplateResponse(request, "product_form.html", {
        "admin_name": _name(request), "product": None, "error": None,
        "categories": [("screen","شاشة"),("battery","بطارية"),("camera","كاميرا"),
                       ("speaker","سماعة"),("charger","شاحن"),("device","جهاز"),
                       ("spare_part","قطعة غيار"),("other","أخرى")],
    })


@app.post("/products/add", response_class=HTMLResponse)
async def product_add_post(
    request: Request,
    name: str = Form(...), name_ar: str = Form(""), brand: str = Form(""),
    model: str = Form(""), category: str = Form(...), price: float = Form(...),
    quantity: int = Form(0), description: str = Form(""), notes: str = Form(""),
    is_featured: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
):
    if not _logged(request):
        return _redirect_login()

    image_url = None
    if image and image.filename:
        img_data = await api(
            "post", "/api/uploads/image", token=_token(request),
            files={"file": (image.filename, await image.read(), image.content_type)},
        )
        if img_data:
            image_url = img_data.get("url")

    payload = {
        "name": name, "name_ar": name_ar or None, "brand": brand or None,
        "model": model or None, "category": category, "price": price,
        "quantity": quantity, "description": description or None,
        "notes": notes or None, "is_featured": bool(is_featured),
        "image_url": image_url,
    }
    await api("post", "/api/products/", token=_token(request), json=payload)
    return RedirectResponse("/products", status_code=302)


@app.get("/products/edit/{product_id}", response_class=HTMLResponse)
async def product_edit_page(product_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", f"/api/products/{product_id}", token=_token(request))
    if not raw:
        return RedirectResponse("/products", status_code=302)
    return templates.TemplateResponse(request, "product_form.html", {
        "admin_name": _name(request), "product": to_obj(raw), "error": None,
        "categories": [("screen","شاشة"),("battery","بطارية"),("camera","كاميرا"),
                       ("speaker","سماعة"),("charger","شاحن"),("device","جهاز"),
                       ("spare_part","قطعة غيار"),("other","أخرى")],
    })


@app.post("/products/edit/{product_id}", response_class=HTMLResponse)
async def product_edit_post(
    product_id: int, request: Request,
    name: str = Form(...), name_ar: str = Form(""), brand: str = Form(""),
    model: str = Form(""), category: str = Form(...), price: float = Form(...),
    quantity: int = Form(0), description: str = Form(""), notes: str = Form(""),
    is_featured: Optional[str] = Form(None), status: str = Form("available"),
    image: Optional[UploadFile] = File(None),
):
    if not _logged(request):
        return _redirect_login()

    image_url = None
    if image and image.filename:
        img_data = await api(
            "post", "/api/uploads/image", token=_token(request),
            files={"file": (image.filename, await image.read(), image.content_type)},
        )
        if img_data:
            image_url = img_data.get("url")

    payload = {
        "name": name, "name_ar": name_ar or None, "brand": brand or None,
        "model": model or None, "category": category, "price": price,
        "quantity": quantity, "description": description or None,
        "notes": notes or None, "is_featured": bool(is_featured), "status": status,
    }
    if image_url:
        payload["image_url"] = image_url
    await api("put", f"/api/products/{product_id}", token=_token(request), json=payload)
    return RedirectResponse("/products", status_code=302)


@app.post("/products/delete/{product_id}")
async def product_delete(product_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("delete", f"/api/products/{product_id}", token=_token(request))
    return RedirectResponse("/products", status_code=302)


# ── Orders ──────────────────────────────────────────────────────────────────────

@app.get("/orders", response_class=HTMLResponse)
async def orders_list(request: Request, status_filter: str = "", search: str = ""):
    if not _logged(request):
        return _redirect_login()
    params = {"limit": 300, "order_type": "product"}
    if status_filter:
        params["status"] = status_filter
    if search:
        params["search"] = search
    raw = await api("get", "/api/orders/", token=_token(request), params=params) or []
    orders = to_obj(raw)
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
        "admin_name": _name(request), "active": "orders",
        "orders": orders, "status_labels": status_labels, "status_colors": status_colors,
        "status_filter": status_filter, "search": search,
        "all_statuses": list(status_labels.items()),
    })


@app.get("/orders/{order_id}", response_class=HTMLResponse)
async def order_detail(order_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", f"/api/orders/{order_id}", token=_token(request))
    if not raw:
        return RedirectResponse("/orders", status_code=302)
    status_labels = {
        "received": "مستلم", "reviewing": "قيد المراجعة", "confirmed": "مؤكد",
        "preparing": "جاري التحضير", "shipped": "تم الشحن", "on_the_way": "في الطريق",
        "delivered": "تم التسليم", "cancelled": "ملغي",
    }
    return templates.TemplateResponse(request, "order_detail.html", {
        "admin_name": _name(request), "active": "orders",
        "order": to_obj(raw), "status_labels": status_labels,
        "all_statuses": list(status_labels.items()),
    })


@app.post("/orders/{order_id}/status")
async def update_order_status(
    order_id: int, request: Request,
    status: str = Form(...), note: str = Form(""), admin_notes: str = Form(""),
    estimated_time: str = Form(""), employee_name: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    payload = {
        "status": status, "note": note or None,
        "admin_notes": admin_notes or None,
        "estimated_time": estimated_time or None,
        "employee_name": employee_name or _name(request),
    }
    await api("put", f"/api/orders/{order_id}/status", token=_token(request), json=payload)
    return RedirectResponse(f"/orders/{order_id}", status_code=302)


# ── Maintenance ─────────────────────────────────────────────────────────────────

@app.get("/maintenance", response_class=HTMLResponse)
async def maintenance_list(request: Request, search: str = ""):
    if not _logged(request):
        return _redirect_login()
    params = {"limit": 300}
    if search:
        params["search"] = search
    raw = await api("get", "/api/maintenance/", token=_token(request), params=params) or []
    orders = to_obj(raw)
    maint_labels = {
        "received": "مستلم", "inspecting": "قيد الفحص", "repairing": "جاري الإصلاح",
        "waiting_part": "انتظار قطعة", "repaired": "تم الإصلاح",
        "ready": "جاهز للاستلام", "delivered": "تم التسليم",
    }
    maint_colors = {
        "received": "#6B7280", "inspecting": "#F59E0B", "repairing": "#8B5CF6",
        "waiting_part": "#EF4444", "repaired": "#06B6D4",
        "ready": "#10B981", "delivered": "#22C55E",
    }
    return templates.TemplateResponse(request, "maintenance.html", {
        "admin_name": _name(request), "active": "maintenance",
        "orders": orders, "maint_labels": maint_labels, "maint_colors": maint_colors,
        "search": search, "all_maint_statuses": list(maint_labels.items()),
    })


@app.post("/maintenance/add")
async def maintenance_add(
    request: Request,
    customer_name: str = Form(...), customer_phone: str = Form(...),
    customer_email: str = Form(""), device_type: str = Form(...),
    problem_description: str = Form(...), price: float = Form(0),
    notes: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    payload = {
        "customer_name": customer_name, "customer_phone": customer_phone,
        "customer_email": customer_email or None,
        "device_type": device_type, "problem_description": problem_description,
        "price": price, "notes": notes or None,
    }
    await api("post", "/api/maintenance/", token=_token(request), json=payload)
    return RedirectResponse("/maintenance", status_code=302)


@app.post("/maintenance/{order_id}/status")
async def update_maintenance_status(
    order_id: int, request: Request,
    maintenance_status: str = Form(...), note: str = Form(""),
    admin_notes: str = Form(""), estimated_time: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    payload = {
        "maintenance_status": maintenance_status, "note": note or None,
        "admin_notes": admin_notes or None,
        "estimated_time": estimated_time or None,
        "employee_name": _name(request),
    }
    await api("put", f"/api/maintenance/{order_id}/status", token=_token(request), json=payload)
    return RedirectResponse("/maintenance", status_code=302)


# ── Reservations ────────────────────────────────────────────────────────────────

@app.get("/reservations", response_class=HTMLResponse)
async def reservations_list(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw_res  = await api("get", "/api/reservations/", token=_token(request), params={"limit": 300}) or []
    raw_prod = await api("get", "/api/products/", token=_token(request), params={"status": "available", "limit": 200}) or []
    reservations       = to_obj(raw_res)
    available_products = to_obj(raw_prod)
    status_labels = {"pending":"قيد الانتظار","confirmed":"مؤكد","cancelled":"ملغي","completed":"مكتمل"}
    status_colors = {"pending":"#F59E0B","confirmed":"#22C55E","cancelled":"#EF4444","completed":"#06B6D4"}
    return templates.TemplateResponse(request, "reservations.html", {
        "admin_name": _name(request), "active": "reservations",
        "reservations": reservations, "status_labels": status_labels,
        "status_colors": status_colors, "available_products": available_products,
    })


@app.post("/reservations/add")
async def reservation_add(
    request: Request,
    customer_name: str = Form(...), customer_phone: str = Form(...),
    product_id: int = Form(...), notes: str = Form(""), days: int = Form(3),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/reservations/", token=_token(request),
              json={"customer_name": customer_name, "customer_phone": customer_phone,
                    "product_id": product_id, "notes": notes or None, "days": days})
    return RedirectResponse("/reservations", status_code=302)


@app.post("/reservations/{res_id}/cancel")
async def reservation_cancel(res_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("put", f"/api/reservations/{res_id}/cancel", token=_token(request))
    return RedirectResponse("/reservations", status_code=302)


@app.post("/reservations/{res_id}/complete")
async def reservation_complete(res_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("put", f"/api/reservations/{res_id}/complete", token=_token(request))
    return RedirectResponse("/reservations", status_code=302)


# ── Customers ───────────────────────────────────────────────────────────────────

@app.get("/customers", response_class=HTMLResponse)
async def customers_list(request: Request, search: str = ""):
    if not _logged(request):
        return _redirect_login()
    params = {"limit": 300}
    if search:
        params["search"] = search
    raw = await api("get", "/api/customers/", token=_token(request), params=params) or []
    customers = to_obj(raw)
    return templates.TemplateResponse(request, "customers.html", {
        "admin_name": _name(request), "active": "customers",
        "customers": customers, "search": search,
    })


@app.post("/customers/add")
async def customer_add(
    request: Request,
    name: str = Form(...), phone: str = Form(...),
    email: str = Form(""), password: str = Form(...),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/customers/", token=_token(request),
              json={"name": name, "phone": phone or None,
                    "email": email or None, "password": password})
    return RedirectResponse("/customers", status_code=302)


@app.post("/customers/{user_id}/toggle-active")
async def customer_toggle(user_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/customers/{user_id}/toggle-active", token=_token(request))
    return RedirectResponse("/customers", status_code=302)


@app.post("/customers/{user_id}/delete")
async def customer_delete(user_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("delete", f"/api/customers/{user_id}", token=_token(request))
    return RedirectResponse("/customers", status_code=302)


# ── Inventory ───────────────────────────────────────────────────────────────────

@app.get("/inventory", response_class=HTMLResponse)
async def inventory_list(request: Request, search: str = "", status_filter: str = "", grade_filter: str = ""):
    if not _logged(request):
        return _redirect_login()
    params = {"limit": 300}
    if search:
        params["search"] = search
    if status_filter:
        params["status"] = status_filter
    if grade_filter:
        params["grade"] = grade_filter
    raw   = await api("get", "/api/inventory/", token=_token(request), params=params) or []
    stats = await api("get", "/api/inventory/stats/summary", token=_token(request)) or {}
    items = to_obj(raw)
    return templates.TemplateResponse(request, "inventory.html", {
        "admin_name": _name(request), "active": "inventory",
        "items": items, "search": search,
        "status_filter": status_filter, "grade_filter": grade_filter,
        "stats": stats,
    })


@app.post("/inventory/add")
async def inventory_add(
    request: Request,
    serial_number: str = Form(""), category: str = Form(...),
    brand: str = Form(""), model: str = Form(""), grade: str = Form("A"),
    price: float = Form(...), notes: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/inventory/", token=_token(request),
              json={"serial_number": serial_number or None, "category": category,
                    "brand": brand or None, "model": model or None,
                    "grade": grade, "price": price, "notes": notes or None})
    return RedirectResponse("/inventory", status_code=302)


@app.post("/inventory/{item_id}/sell")
async def inventory_sell(item_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/inventory/{item_id}/sell", token=_token(request))
    return RedirectResponse("/inventory", status_code=302)


@app.post("/inventory/{item_id}/return-stock")
async def inventory_return_stock(item_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/inventory/{item_id}/return-to-stock", token=_token(request))
    return RedirectResponse("/inventory", status_code=302)


# ── Inspection ──────────────────────────────────────────────────────────────────

@app.get("/inspection", response_class=HTMLResponse)
async def inspection_list(request: Request, status: str = ""):
    if not _logged(request):
        return _redirect_login()
    params = {"limit": 200}
    if status:
        params["status"] = status
    raw = await api("get", "/api/inspection/", token=_token(request), params=params) or []
    return templates.TemplateResponse(request, "inspection.html", {
        "admin_name": _name(request), "active": "inspection",
        "requests": to_obj(raw),
    })


@app.post("/inspection/{req_id}/respond")
async def inspection_respond(
    req_id: int, request: Request,
    diagnosis: str = Form(...), estimated_price: str = Form(""),
    response_notes: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/inspection/{req_id}/respond", token=_token(request),
              json={"staff_id": request.session.get("admin_id"),
                    "diagnosis": diagnosis,
                    "estimated_price": estimated_price or None,
                    "response_notes": response_notes or None})
    return RedirectResponse("/inspection", status_code=302)


@app.post("/inspection/{req_id}/close")
async def inspection_close(req_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/inspection/{req_id}/close", token=_token(request))
    return RedirectResponse("/inspection", status_code=302)


# ── Referrals ───────────────────────────────────────────────────────────────────

@app.get("/referrals", response_class=HTMLResponse)
async def referrals_list(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/referrals/all", token=_token(request), params={"limit": 300}) or []
    referrals = to_obj(raw)
    total    = len(referrals)
    verified = sum(1 for r in referrals if getattr(r, "is_verified", False))
    return templates.TemplateResponse(request, "referrals.html", {
        "admin_name": _name(request), "active": "referrals",
        "referrals": referrals, "total": total, "verified": verified,
        "top_referrers": [],
    })


# ── Warranty ────────────────────────────────────────────────────────────────────

@app.get("/warranty", response_class=HTMLResponse)
async def warranty_list(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/warranty/", token=_token(request), params={"limit": 200}) or []
    warranties = to_obj(raw)
    return_requests = sum(
        1 for w in warranties
        if getattr(w, "is_return_requested", False) and not getattr(w, "return_resolved", False)
    )
    return templates.TemplateResponse(request, "warranty.html", {
        "admin_name": _name(request), "active": "warranty",
        "warranties": warranties, "return_requests": return_requests,
        "now_dt": datetime.utcnow(),
    })


@app.post("/warranty/add")
async def warranty_add(
    request: Request,
    product_name: str = Form(...), product_serial: str = Form(""),
    order_id: Optional[int] = Form(None), warranty_days: int = Form(7),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/warranty/", token=_token(request),
              json={"product_name": product_name,
                    "product_serial": product_serial or None,
                    "order_id": order_id,
                    "warranty_days": warranty_days})
    return RedirectResponse("/warranty", status_code=302)


@app.post("/warranty/{warranty_id}/resolve")
async def warranty_resolve(warranty_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/warranty/{warranty_id}/resolve-return", token=_token(request),
              json={"notes": "تم الحل من لوحة الإدارة"})
    return RedirectResponse("/warranty", status_code=302)


# ── Staff ───────────────────────────────────────────────────────────────────────

@app.get("/staff", response_class=HTMLResponse)
async def staff_list(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/staff/", token=_token(request)) or []
    return templates.TemplateResponse(request, "staff.html", {
        "admin_name": _name(request), "active": "staff",
        "staff": to_obj(raw),
    })


@app.post("/staff/add")
async def staff_add(
    request: Request,
    name: str = Form(...), phone: str = Form(""), email: str = Form(""),
    role: str = Form("staff"), password: str = Form(...),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/staff/", token=_token(request),
              json={"name": name, "phone": phone or None,
                    "email": email or None, "role": role, "password": password})
    return RedirectResponse("/staff", status_code=302)


@app.post("/staff/{user_id}/toggle-active")
async def staff_toggle(user_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/staff/{user_id}/toggle-active", token=_token(request))
    return RedirectResponse("/staff", status_code=302)


@app.post("/staff/{user_id}/edit")
async def staff_edit(
    user_id: int, request: Request,
    name: str = Form(...), phone: str = Form(""),
    email: str = Form(""), role: str = Form("staff"),
    password: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    await api("put", f"/api/staff/{user_id}", token=_token(request),
              json={"name": name, "phone": phone or None,
                    "email": email or None, "role": role,
                    "password": password or None})
    return RedirectResponse("/staff", status_code=302)


@app.post("/staff/{user_id}/delete")
async def staff_delete(user_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("delete", f"/api/staff/{user_id}", token=_token(request))
    return RedirectResponse("/staff", status_code=302)


# ── Branches ────────────────────────────────────────────────────────────────────

@app.get("/branches", response_class=HTMLResponse)
async def branches_list(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw_b = await api("get", "/api/branches/", token=_token(request)) or []
    raw_w = await api("get", "/api/branches/warehouses/all", token=_token(request)) or []
    return templates.TemplateResponse(request, "branches.html", {
        "admin_name": _name(request), "active": "branches",
        "branches": to_obj(raw_b), "warehouses": to_obj(raw_w),
    })


@app.post("/branches/add")
async def branch_add(
    request: Request,
    name: str = Form(...), city: str = Form(""),
    address: str = Form(""), phone: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/branches/", token=_token(request),
              json={"name": name, "city": city or None,
                    "address": address or None, "phone": phone or None})
    return RedirectResponse("/branches", status_code=302)


@app.post("/branches/{branch_id}/edit")
async def branch_edit(
    branch_id: int, request: Request,
    name: str = Form(...), city: str = Form(""),
    address: str = Form(""), phone: str = Form(""),
    is_active: Optional[str] = Form(None),
):
    if not _logged(request):
        return _redirect_login()
    await api("put", f"/api/branches/{branch_id}", token=_token(request),
              json={"name": name, "city": city or None,
                    "address": address or None, "phone": phone or None,
                    "is_active": bool(is_active)})
    return RedirectResponse("/branches", status_code=302)


@app.post("/branches/{branch_id}/delete")
async def branch_delete(branch_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("delete", f"/api/branches/{branch_id}", token=_token(request))
    return RedirectResponse("/branches", status_code=302)


# ── Notifications ───────────────────────────────────────────────────────────────

@app.get("/notifications", response_class=HTMLResponse)
async def notifications_list(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw_notifs   = await api("get", "/api/notifications/all", token=_token(request)) or []
    raw_customers = await api("get", "/api/customers/", token=_token(request), params={"limit": 300}) or []
    notifs    = to_obj(raw_notifs)
    customers = to_obj(raw_customers)
    total  = len(notifs)
    unread = sum(1 for n in notifs if not getattr(n, "is_read", True))
    return templates.TemplateResponse(request, "notifications.html", {
        "admin_name": _name(request), "active": "notifications",
        "notifs": notifs, "total": total, "unread": unread,
        "customers": customers,
    })


@app.post("/notifications/send")
async def notification_send(
    request: Request,
    title: str = Form(...), message: str = Form(...),
    user_id: Optional[int] = Form(None), broadcast: Optional[str] = Form(None),
):
    if not _logged(request):
        return _redirect_login()
    if broadcast:
        await api("post", "/api/notifications/broadcast", token=_token(request),
                  params={"title": title, "body": message})
    elif user_id:
        await api("post", "/api/notifications/send", token=_token(request),
                  json={"user_id": user_id, "title": title, "body": message})
    return RedirectResponse("/notifications", status_code=302)


@app.post("/notifications/{notif_id}/delete")
async def notification_delete(notif_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("delete", f"/api/notifications/{notif_id}", token=_token(request))
    return RedirectResponse("/notifications", status_code=302)


# ── Reports ─────────────────────────────────────────────────────────────────────

@app.get("/reports", response_class=HTMLResponse)
async def reports_page(request: Request, period: str = "month"):
    if not _logged(request):
        return _redirect_login()
    params = {"period": period}
    sales   = await api("get", "/api/reports/sales",      token=_token(request), params=params) or {}
    maint   = await api("get", "/api/reports/maintenance", token=_token(request), params=params) or {}
    inv_r   = await api("get", "/api/reports/inventory",   token=_token(request)) or {}
    ref_r   = await api("get", "/api/reports/referrals",   token=_token(request)) or {}
    war_r   = await api("get", "/api/reports/warranty",    token=_token(request)) or {}
    return templates.TemplateResponse(request, "reports.html", {
        "admin_name": _name(request), "active": "reports",
        "period": period,
        "total_revenue":   sales.get("total_revenue", 0),
        "total_discount":  sales.get("total_discount", 0),
        "total_orders":    sales.get("total_orders", 0),
        "avg_order_value": sales.get("avg_order_value", 0),
        "maint_total":     maint.get("total", 0),
        "maint_done":      maint.get("completed", 0),
        "inv_total":       inv_r.get("total", 0),
        "inv_avail":       inv_r.get("available", 0),
        "inv_sold":        inv_r.get("sold", 0),
        "ref_total":       ref_r.get("total", 0),
        "ref_verified":    ref_r.get("verified", 0),
        "war_total":       war_r.get("total", 0),
        "war_returns":     war_r.get("return_requests", 0),
    })


# ── Wallet ──────────────────────────────────────────────────────────────────────

@app.get("/wallet", response_class=HTMLResponse)
async def wallet_page(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw_customers = await api("get", "/api/customers/", token=_token(request), params={"limit": 300}) or []
    customers = to_obj(raw_customers)
    return templates.TemplateResponse(request, "wallet.html", {
        "admin_name": _name(request), "active": "wallet",
        "customers": customers,
    })


@app.post("/wallet/{user_id}/credit")
async def wallet_credit(
    user_id: int, request: Request,
    amount: float = Form(...), note: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/wallet/credit", token=_token(request),
              json={"user_id": user_id, "amount": amount,
                    "description": note or "إضافة رصيد من لوحة التحكم"})
    return RedirectResponse("/wallet", status_code=302)


@app.post("/wallet/{user_id}/debit")
async def wallet_debit(
    user_id: int, request: Request,
    amount: float = Form(...), note: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    await api("post", "/api/wallet/debit", token=_token(request),
              json={"user_id": user_id, "amount": amount,
                    "description": note or "خصم رصيد من لوحة التحكم"})
    return RedirectResponse("/wallet", status_code=302)


# ── Audit Log ───────────────────────────────────────────────────────────────────

@app.get("/audit", response_class=HTMLResponse)
async def audit_page(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/audit/", token=_token(request), params={"limit": 200}) or []
    return templates.TemplateResponse(request, "audit.html", {
        "admin_name": _name(request), "active": "audit",
        "logs": to_obj(raw),
    })
