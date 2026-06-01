---
name: Admin panel API architecture
description: Admin panel now calls Render.com API (not SQLAlchemy); architectural decisions and gotchas
---

**Rule:** `admin_panel/main.py` calls `https://android-al-ahmadi-store-api.onrender.com` for ALL data — no SQLAlchemy, no direct DB connection.

**Why:** The PostgreSQL database is only reliably accessible through the Render.com backend. The admin panel's local SQLAlchemy connection was showing empty data (or connecting to the wrong DB). Making the admin panel an API client (like Flutter) ensures both apps see the same live data.

**How to apply:**
- All routes use `await api(method, path, token=_token(request), ...)` helper (httpx)
- API dicts are converted to attribute-accessible objects via `to_obj()` (SimpleNamespace recursively)
- Datetime strings ending in `_at`, `expires_at`, etc. are auto-parsed to `datetime` objects in `to_obj()`
- Token from session (`request.session["token"]`) is passed as `Authorization: Bearer` header

**New backend endpoints added (require redeploy to Render.com):**
- `GET/POST /api/customers/` — customer CRUD (search, add)
- `POST /api/customers/{id}/toggle-active` — toggle customer active
- `DELETE /api/customers/{id}` — delete customer
- `GET/POST/PUT/DELETE /api/staff/` — full staff management
- `POST /api/staff/{id}/toggle-active`
- `GET /api/notifications/all` — admin sees all notifications (limit 300)
- `DELETE /api/notifications/{id}` — delete notification
- `PUT /api/reservations/{id}/complete` — complete a reservation

**Render.com free tier note:** Sleeps after ~15min inactivity. First request wakes it up (30–60s). This is expected; the login shows an error if Render.com is sleeping and takes too long.
