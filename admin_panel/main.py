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
from urllib.parse import quote as _q

# ── Backend API (Render.com) ──────────────────────────────────────────────────
API_BASE = "https://android-al-ahmadi-store-api.onrender.com"

app = FastAPI(title="لوحة إدارة اندرويد الاحمدي", docs_url=None, redoc_url=None)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    import traceback
    tb = traceback.format_exc()
    print(f"[UNHANDLED 500] {request.method} {request.url}\n{tb}")
    from fastapi.responses import HTMLResponse
    return HTMLResponse(
        f"<pre style='color:red;padding:20px'><b>500 Internal Server Error</b>\n\n{tb}</pre>",
        status_code=500,
    )

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

# Safe enum/string value: {{ item.status|v }} works for both plain str and enum-like object
templates.env.filters['v'] = lambda x: (getattr(x, 'value', x) if x is not None else '')

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


async def api(method: str, path: str, token: str = None, real_ip: str = None, **kwargs):
    """Call the backend API; returns parsed JSON on success, None on error."""
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if real_ip:
        headers["X-Real-IP"] = real_ip
        headers["X-Forwarded-For"] = real_ip
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


async def api_ex(method: str, path: str, token: str = None, **kwargs):
    """Extended API call — returns (data, error_msg). data=None means failure."""
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        async with httpx.AsyncClient(timeout=25.0, follow_redirects=True) as client:
            resp = await getattr(client, method)(
                f"{API_BASE}{path}", headers=headers, **kwargs
            )
        if resp.status_code in (200, 201):
            return resp.json(), None
        try:
            body = resp.json()
            if isinstance(body, dict):
                detail = body.get("detail", str(body))
                if isinstance(detail, list):
                    detail = "; ".join(
                        str(d.get("msg", d)) if isinstance(d, dict) else str(d)
                        for d in detail
                    )
            else:
                detail = str(body)
        except Exception:
            detail = resp.text[:300]
        print(f"[admin] {method.upper()} {path} → {resp.status_code}: {detail}")
        return None, f"خطأ {resp.status_code}: {detail}"
    except Exception as e:
        print(f"[admin] API error {method.upper()} {path}: {e}")
        return None, f"خطأ في الاتصال بالخادم: {str(e)[:120]}"


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
    client_ip = (
        request.headers.get("x-real-ip")
        or request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        or (request.client.host if request.client else "unknown")
    )
    async with httpx.AsyncClient(timeout=25.0, follow_redirects=True) as client:
        try:
            headers_req = {"X-Real-IP": client_ip, "X-Forwarded-For": client_ip}
            resp = await client.post(
                f"{API_BASE}/api/auth/admin-login",
                json={"identifier": identifier, "password": password},
                headers=headers_req,
            )
            print(f"[login] status={resp.status_code} body={resp.text[:200]}")
            if resp.status_code == 429:
                return templates.TemplateResponse(request, "login.html",
                    {"error": "محاولات كثيرة. انتظر دقيقة ثم أعد المحاولة."})
            if resp.status_code in (200, 201):
                data = resp.json()
                user_data = data.get("user", {})
                if user_data.get("role") == "admin":
                    request.session["admin_id"]   = user_data.get("id")
                    request.session["admin_name"] = user_data.get("name", "المدير")
                    request.session["token"]      = data.get("access_token")
                    return RedirectResponse("/dashboard", status_code=303)
        except Exception as e:
            print(f"[login] exception type={type(e).__name__} msg={e!r}")
            return templates.TemplateResponse(request, "login.html",
                {"error": "الخادم غير متاح حالياً. يرجى المحاولة لاحقاً."})
    return templates.TemplateResponse(request, "login.html",
                                      {"error": "بيانات الدخول غير صحيحة. تحقق من البريد وكلمة المرور."})


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


_CATEGORIES = [
    ("screen","شاشة"), ("battery","بطارية"), ("camera","كاميرا"),
    ("speaker","سماعة"), ("charger","شاحن"), ("device","جهاز"),
    ("spare_part","قطعة غيار"), ("other","أخرى"),
]

from backend.core.samsung_catalog import SAMSUNG_CATALOG as _SAMSUNG_CATALOG

_SAMSUNG_SERIES = [
    {"key": k, "label_ar": v["label_ar"], "models": v["models"]}
    for k, v in _SAMSUNG_CATALOG.items()
]


@app.get("/products/add", response_class=HTMLResponse)
async def product_add_page(request: Request):
    if not _logged(request):
        return _redirect_login()
    return templates.TemplateResponse(request, "product_form.html", {
        "admin_name": _name(request), "product": None, "error": None,
        "categories": _CATEGORIES, "samsung_series": _SAMSUNG_SERIES,
    })


@app.post("/products/add", response_class=HTMLResponse)
async def product_add_post(
    request: Request,
    name: str = Form(...), name_ar: str = Form(""), brand: str = Form(""),
    model: str = Form(""), series: str = Form(""), category: str = Form(...),
    price: float = Form(...), quantity: int = Form(0),
    description: str = Form(""), notes: str = Form(""),
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
        "model": model or None, "series": series or None,
        "category": category, "price": price,
        "quantity": quantity, "description": description or None,
        "notes": notes or None, "is_featured": bool(is_featured),
        "image_url": image_url,
    }
    _, err = await api_ex("post", "/api/products/", token=_token(request), json=payload)
    if err:
        return RedirectResponse(f"/products?error={_q(err)}", status_code=302)
    return RedirectResponse("/products?success=تم+إضافة+المنتج+بنجاح", status_code=302)


@app.get("/products/edit/{product_id}", response_class=HTMLResponse)
async def product_edit_page(product_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", f"/api/products/{product_id}", token=_token(request))
    if not raw:
        return RedirectResponse("/products", status_code=302)
    return templates.TemplateResponse(request, "product_form.html", {
        "admin_name": _name(request), "product": to_obj(raw), "error": None,
        "categories": _CATEGORIES, "samsung_series": _SAMSUNG_SERIES,
    })


@app.post("/products/edit/{product_id}", response_class=HTMLResponse)
async def product_edit_post(
    product_id: int, request: Request,
    name: str = Form(...), name_ar: str = Form(""), brand: str = Form(""),
    model: str = Form(""), series: str = Form(""), category: str = Form(...),
    price: float = Form(...), quantity: int = Form(0),
    description: str = Form(""), notes: str = Form(""),
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
        "model": model or None, "series": series or None,
        "category": category, "price": price,
        "quantity": quantity, "description": description or None,
        "notes": notes or None, "is_featured": bool(is_featured), "status": status,
    }
    if image_url:
        payload["image_url"] = image_url
    _, err = await api_ex("put", f"/api/products/{product_id}", token=_token(request), json=payload)
    if err:
        return RedirectResponse(f"/products?error={_q(err)}", status_code=302)
    return RedirectResponse("/products?success=تم+تحديث+المنتج+بنجاح", status_code=302)


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
    _, err = await api_ex("post", "/api/maintenance/", token=_token(request), json=payload)
    if err:
        return RedirectResponse(f"/maintenance?error={_q(err)}", status_code=302)
    return RedirectResponse("/maintenance?success=تم+إضافة+طلب+الصيانة+بنجاح", status_code=302)


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
    _, err = await api_ex("post", "/api/reservations/", token=_token(request),
                          json={"customer_name": customer_name, "customer_phone": customer_phone,
                                "product_id": product_id, "notes": notes or None, "days": days})
    if err:
        return RedirectResponse(f"/reservations?error={_q(err)}", status_code=302)
    return RedirectResponse("/reservations?success=تم+إضافة+الحجز+بنجاح", status_code=302)


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
    _, err = await api_ex("post", "/api/customers/", token=_token(request),
                          json={"name": name, "phone": phone or None,
                                "email": email or None, "password": password})
    if err:
        return RedirectResponse(f"/customers?error={_q(err)}", status_code=302)
    return RedirectResponse("/customers?success=تم+إضافة+العميل+بنجاح", status_code=302)


@app.post("/customers/{user_id}/toggle-active")
async def customer_toggle(user_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/customers/{user_id}/toggle-active", token=_token(request))
    return RedirectResponse("/customers", status_code=302)


@app.post("/customers/{user_id}/verify")
async def customer_verify(user_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/customers/{user_id}/verify", token=_token(request))
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
    _, err = await api_ex("post", "/api/inventory/", token=_token(request),
                          json={"serial_number": serial_number or None, "category": category,
                                "brand": brand or None, "model": model or None,
                                "grade": grade, "price": price, "notes": notes or None})
    if err:
        return RedirectResponse(f"/inventory?error={_q(err)}", status_code=302)
    return RedirectResponse("/inventory?success=تم+إضافة+العنصر+للمخزون+بنجاح", status_code=302)


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
    response_images: list[UploadFile] = File(default=[]),
):
    if not _logged(request):
        return _redirect_login()
    # Upload any attached images to the uploads folder
    image_urls: list[str] = []
    for img in response_images:
        if img.filename:
            import uuid, shutil
            ext = os.path.splitext(img.filename)[-1].lower() or ".jpg"
            fname = f"insp_{req_id}_{uuid.uuid4().hex[:8]}{ext}"
            dest = os.path.join(UPLOAD_DIR, fname)
            with open(dest, "wb") as f:
                shutil.copyfileobj(img.file, f)
            image_urls.append(f"/uploads/{fname}")
    await api("post", f"/api/inspection/{req_id}/respond", token=_token(request),
              json={"staff_id": request.session.get("admin_id"),
                    "diagnosis": diagnosis,
                    "estimated_price": estimated_price or None,
                    "response_notes": response_notes or None,
                    "response_images": image_urls})
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
    _, err = await api_ex("post", "/api/warranty/", token=_token(request),
                          json={"product_name": product_name,
                                "product_serial": product_serial or None,
                                "order_id": order_id,
                                "warranty_days": warranty_days})
    if err:
        return RedirectResponse(f"/warranty?error={_q(err)}", status_code=302)
    return RedirectResponse("/warranty?success=تم+إضافة+الضمان+بنجاح", status_code=302)


@app.post("/warranty/{warranty_id}/resolve")
async def warranty_resolve(
    warranty_id: int, request: Request,
    approved: Optional[str] = Form(None),
    notes: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()
    is_approved = approved == "true"
    await api("post", f"/api/warranty/{warranty_id}/resolve-return", token=_token(request),
              json={"approved": is_approved, "notes": notes or "تم الحل من لوحة الإدارة"})
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
    _, err = await api_ex("post", "/api/staff/", token=_token(request),
                          json={"name": name, "phone": phone or None,
                                "email": email or None, "role": role, "password": password})
    if err:
        return RedirectResponse(f"/staff?error={_q(err)}", status_code=302)
    return RedirectResponse("/staff?success=تم+إضافة+الموظف+بنجاح", status_code=302)


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
    _, err = await api_ex("put", f"/api/staff/{user_id}", token=_token(request),
                          json={"name": name, "phone": phone or None,
                                "email": email or None, "role": role,
                                "password": password or None})
    if err:
        return RedirectResponse(f"/staff?error={_q(err)}", status_code=302)
    return RedirectResponse("/staff?success=تم+تحديث+بيانات+الموظف+بنجاح", status_code=302)


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
    _, err = await api_ex("post", "/api/branches/", token=_token(request),
                          json={"name": name, "city": city or None,
                                "address": address or None, "phone": phone or None})
    if err:
        return RedirectResponse(f"/branches?error={_q(err)}", status_code=302)
    return RedirectResponse("/branches?success=تم+إضافة+الفرع+بنجاح", status_code=302)


@app.post("/branches/{branch_id}/edit")
async def branch_edit(
    branch_id: int, request: Request,
    name: str = Form(...), city: str = Form(""),
    address: str = Form(""), phone: str = Form(""),
    is_active: Optional[str] = Form(None),
):
    if not _logged(request):
        return _redirect_login()
    _, err = await api_ex("put", f"/api/branches/{branch_id}", token=_token(request),
                          json={"name": name, "city": city or None,
                                "address": address or None, "phone": phone or None,
                                "is_active": bool(is_active)})
    if err:
        return RedirectResponse(f"/branches?error={_q(err)}", status_code=302)
    return RedirectResponse("/branches?success=تم+تحديث+الفرع+بنجاح", status_code=302)


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
    sales  = to_obj(await api("get", "/api/reports/sales",       token=_token(request), params=params) or {})
    profit = to_obj(await api("get", "/api/reports/profit",      token=_token(request), params=params) or {})
    inv    = to_obj(await api("get", "/api/reports/inventory",   token=_token(request)) or {})
    maint  = to_obj(await api("get", "/api/reports/maintenance", token=_token(request), params=params) or {})
    ref    = to_obj(await api("get", "/api/reports/referrals",   token=_token(request)) or {})
    war    = to_obj(await api("get", "/api/reports/warranty",    token=_token(request)) or {})
    return templates.TemplateResponse(request, "reports.html", {
        "admin_name": _name(request), "active": "reports",
        "period": period,
        "sales": sales, "profit": profit, "inv": inv,
        "maint": maint, "ref": ref, "war": war,
    })


# ── Wallet ──────────────────────────────────────────────────────────────────────

@app.get("/wallet", response_class=HTMLResponse)
async def wallet_page(request: Request, search: str = ""):
    if not _logged(request):
        return _redirect_login()
    params: dict = {"limit": 300}
    if search:
        params["search"] = search
    raw_customers = await api("get", "/api/customers/", token=_token(request), params=params) or []
    users = to_obj(raw_customers)
    if search and users:
        q = search.lower()
        users = [u for u in users if q in (getattr(u, "name", "") or "").lower()
                 or q in (getattr(u, "phone", "") or "").lower()]
    return templates.TemplateResponse(request, "wallet.html", {
        "admin_name": _name(request), "active": "wallet",
        "users": users,
        "search": search,
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
                    "transaction_type": "credit",
                    "reason": note or "إضافة رصيد من لوحة التحكم"})
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
                    "transaction_type": "debit",
                    "reason": note or "خصم رصيد من لوحة التحكم"})
    return RedirectResponse("/wallet", status_code=302)


# ── Admin Profile ───────────────────────────────────────────────────────────────

@app.get("/profile", response_class=HTMLResponse)
async def profile_page(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/auth/me", token=_token(request)) or {}
    admin = to_obj(raw) if raw else None
    return templates.TemplateResponse(request, "profile.html", {
        "admin_name": _name(request),
        "active": "profile",
        "admin": admin,
        "success": request.query_params.get("success"),
        "error": request.query_params.get("error"),
    })


@app.post("/profile", response_class=HTMLResponse)
async def profile_update(
    request: Request,
    name: str = Form(...),
    email: str = Form(""),
    phone: str = Form(""),
    current_password: str = Form(""),
    new_password: str = Form(""),
    confirm_password: str = Form(""),
):
    if not _logged(request):
        return _redirect_login()

    if new_password and new_password != confirm_password:
        return RedirectResponse("/profile?error=كلمتا+المرور+غير+متطابقتين", status_code=302)

    payload: dict = {"name": name}
    if email.strip():
        payload["email"] = email.strip()
    else:
        payload["email"] = None
    if phone.strip():
        payload["phone"] = phone.strip()
    else:
        payload["phone"] = None
    if new_password:
        if not current_password:
            return RedirectResponse("/profile?error=كلمة+المرور+الحالية+مطلوبة", status_code=302)
        payload["current_password"] = current_password
        payload["new_password"] = new_password

    result = await api("put", "/api/auth/profile", token=_token(request), json=payload)
    if result:
        request.session["admin_name"] = result.get("name", _name(request))
        return RedirectResponse("/profile?success=1", status_code=302)
    return RedirectResponse("/profile?error=فشل+التحديث.+تحقق+من+البيانات", status_code=302)


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


# ── Announcements ────────────────────────────────────────────────────────────

@app.get("/announcements", response_class=HTMLResponse)
async def announcements_list(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/announcements/", token=_token(request),
                    params={"active_only": "false"}) or []
    return templates.TemplateResponse(request, "announcements.html", {
        "admin_name": _name(request), "active": "announcements",
        "announcements": to_obj(raw),
    })


@app.post("/announcements/add")
async def announcement_add(
    request: Request,
    title: str = Form(...), body: str = Form(...),
    announcement_type: str = Form("info"),
    image_url: str = Form(""), action_url: str = Form(""),
    is_pinned: Optional[str] = Form(None),
    is_active: Optional[str] = Form(None),
):
    if not _logged(request):
        return _redirect_login()
    _, err = await api_ex("post", "/api/announcements/", token=_token(request),
                          json={
                              "title": title, "body": body,
                              "announcement_type": announcement_type,
                              "image_url": image_url or None,
                              "action_url": action_url or None,
                              "is_pinned": bool(is_pinned),
                              "is_active": bool(is_active),
                          })
    if err:
        return RedirectResponse(f"/announcements?error={_q(err)}", status_code=302)
    return RedirectResponse("/announcements?success=تم+إضافة+الإعلان+بنجاح", status_code=302)


@app.post("/announcements/{ann_id}/toggle")
async def announcement_toggle(ann_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("post", f"/api/announcements/{ann_id}/toggle", token=_token(request))
    return RedirectResponse("/announcements", status_code=302)


@app.post("/announcements/{ann_id}/delete")
async def announcement_delete(ann_id: int, request: Request):
    if not _logged(request):
        return _redirect_login()
    await api("delete", f"/api/announcements/{ann_id}", token=_token(request))
    return RedirectResponse("/announcements", status_code=302)


# ── Export to Excel ───────────────────────────────────────────────────────────
import io
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter
from fastapi.responses import StreamingResponse
from datetime import date as _date


def _make_wb(title: str):
    wb = Workbook()
    ws = wb.active
    ws.title = title
    ws.sheet_view.rightToLeft = True
    return wb, ws


def _style_header(ws, headers: list):
    fill = PatternFill("solid", fgColor="1A73E8")
    font = Font(bold=True, color="FFFFFF", size=12, name="Cairo")
    for col, h in enumerate(headers, 1):
        cell = ws.cell(row=1, column=col, value=h)
        cell.fill = fill
        cell.font = font
        cell.alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[1].height = 22


def _set_widths(ws, widths: list):
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w


def _wb_response(wb, filename: str):
    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.get("/export/customers")
async def export_customers(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/customers/", token=_token(request), params={"limit": 5000}) or []
    wb, ws = _make_wb("العملاء")
    _style_header(ws, ["#", "الاسم", "رقم الجوال", "البريد الإلكتروني", "رصيد المحفظة", "الحالة", "التوثيق", "تاريخ التسجيل"])
    _set_widths(ws, [6, 25, 18, 30, 15, 12, 12, 20])
    for i, c in enumerate(raw, 1):
        created = (c.get("created_at") or "")[:16].replace("T", " ")
        ws.append([i, c.get("name",""), c.get("phone",""), c.get("email",""),
                   c.get("wallet_balance", 0),
                   "نشط" if c.get("is_active") else "موقوف",
                   "موثّق" if c.get("is_verified") else "غير موثّق", created])
    return _wb_response(wb, f"customers_{_date.today()}.xlsx")


@app.get("/export/staff")
async def export_staff_excel(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/staff/", token=_token(request)) or []
    wb, ws = _make_wb("الموظفون")
    _style_header(ws, ["#", "الاسم", "رقم الجوال", "البريد الإلكتروني", "الدور", "الحالة", "تاريخ الإضافة"])
    _set_widths(ws, [6, 25, 18, 30, 15, 12, 20])
    roles = {"staff": "موظف", "branch_manager": "مدير فرع", "admin": "مدير عام"}
    for i, s in enumerate(raw, 1):
        created = (s.get("created_at") or "")[:16].replace("T", " ")
        ws.append([i, s.get("name",""), s.get("phone",""), s.get("email",""),
                   roles.get(s.get("role",""), s.get("role","")),
                   "نشط" if s.get("is_active") else "معطّل", created])
    return _wb_response(wb, f"staff_{_date.today()}.xlsx")


@app.get("/export/products")
async def export_products_excel(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/products/", token=_token(request), params={"limit": 5000}) or []
    wb, ws = _make_wb("المنتجات")
    _style_header(ws, ["#", "الاسم", "الاسم بالعربي", "الماركة", "الموديل", "الفئة", "السعر", "الكمية", "الحالة", "تاريخ الإضافة"])
    _set_widths(ws, [6, 25, 25, 15, 18, 15, 12, 10, 12, 20])
    status_labels = {"available":"متوفر","reserved":"محجوز","sold":"مباع","unavailable":"غير متوفر"}
    for i, p in enumerate(raw, 1):
        created = (p.get("created_at") or "")[:16].replace("T", " ")
        ws.append([i, p.get("name",""), p.get("name_ar",""), p.get("brand",""), p.get("model",""),
                   p.get("category",""), p.get("price",0), p.get("quantity",0),
                   status_labels.get(p.get("status",""), p.get("status","")), created])
    return _wb_response(wb, f"products_{_date.today()}.xlsx")


@app.get("/export/orders")
async def export_orders_excel(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/orders/", token=_token(request), params={"limit": 5000}) or []
    wb, ws = _make_wb("الطلبات")
    _style_header(ws, ["#", "رقم الطلب", "اسم العميل", "الجوال", "المنتج", "السعر", "الحالة", "ملاحظات", "تاريخ الطلب"])
    _set_widths(ws, [6, 10, 25, 18, 25, 12, 15, 30, 20])
    status_labels = {"received":"مستلم","reviewing":"قيد المراجعة","confirmed":"مؤكد",
                     "preparing":"جاري التحضير","shipped":"تم الشحن","on_the_way":"في الطريق",
                     "delivered":"تم التسليم","cancelled":"ملغي"}
    for i, o in enumerate(raw, 1):
        created = (o.get("created_at") or "")[:16].replace("T", " ")
        product = o.get("product") or {}
        user = o.get("user") or {}
        ws.append([i, o.get("id",""),
                   o.get("customer_name") or user.get("name",""),
                   o.get("customer_phone") or user.get("phone",""),
                   product.get("name","") if isinstance(product, dict) else "",
                   o.get("total_price", o.get("price", 0)),
                   status_labels.get(o.get("status",""), o.get("status","")),
                   o.get("admin_notes",""), created])
    return _wb_response(wb, f"orders_{_date.today()}.xlsx")


@app.get("/export/maintenance")
async def export_maintenance_excel(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/maintenance/", token=_token(request), params={"limit": 5000}) or []
    wb, ws = _make_wb("الصيانة")
    _style_header(ws, ["#", "رقم الطلب", "اسم العميل", "الجوال", "نوع الجهاز", "المشكلة", "السعر", "الحالة", "تاريخ الاستلام"])
    _set_widths(ws, [6, 10, 25, 18, 20, 35, 12, 18, 20])
    maint_labels = {"received":"مستلم","inspecting":"قيد الفحص","repairing":"جاري الإصلاح",
                    "waiting_part":"انتظار قطعة","repaired":"تم الإصلاح",
                    "ready":"جاهز للاستلام","delivered":"تم التسليم"}
    for i, o in enumerate(raw, 1):
        created = (o.get("created_at") or "")[:16].replace("T", " ")
        status = o.get("maintenance_status", o.get("status",""))
        ws.append([i, o.get("id",""), o.get("customer_name",""), o.get("customer_phone",""),
                   o.get("device_type",""), o.get("problem_description",""),
                   o.get("price",0), maint_labels.get(status, status), created])
    return _wb_response(wb, f"maintenance_{_date.today()}.xlsx")


@app.get("/export/inventory")
async def export_inventory_excel(request: Request):
    if not _logged(request):
        return _redirect_login()
    raw = await api("get", "/api/inventory/", token=_token(request), params={"limit": 5000}) or []
    wb, ws = _make_wb("المخزون")
    _style_header(ws, ["#", "الرقم التسلسلي", "الفئة", "الماركة", "الموديل", "الدرجة", "السعر", "الحالة", "الفرع", "تاريخ الإضافة"])
    _set_widths(ws, [6, 22, 15, 15, 18, 10, 12, 12, 18, 20])
    status_labels = {"available":"متوفر","reserved":"محجوز","sold":"مباع"}
    for i, item in enumerate(raw, 1):
        created = (item.get("created_at") or "")[:16].replace("T", " ")
        branch = item.get("branch") or {}
        ws.append([i, item.get("serial_number",""), item.get("category",""),
                   item.get("brand",""), item.get("model",""), item.get("grade",""),
                   item.get("price",0),
                   status_labels.get(item.get("status",""), item.get("status","")),
                   branch.get("name","") if isinstance(branch, dict) else "",
                   created])
    return _wb_response(wb, f"inventory_{_date.today()}.xlsx")
