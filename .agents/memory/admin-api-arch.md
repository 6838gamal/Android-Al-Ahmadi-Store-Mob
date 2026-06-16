---
name: Admin panel API architecture
description: Admin panel calls LOCAL backend (port 8000), not Render.com; uses to_obj() helper for SimpleNamespace
---

**Rule:** `admin_panel/main.py` `API_BASE` now reads from `BACKEND_API_URL` env var, defaulting to `http://127.0.0.1:8000` (local backend).

**Why changed:** Originally hardcoded to Render.com API. In Replit all services run locally, so settings saved via admin panel were going to Render.com DB while local backend read from the same Render.com PostgreSQL — but the JWT tokens signed with the local SECRET_KEY were rejected by Render.com API (different secret), causing settings saves to silently fail. Fix: admin panel now calls local backend, which reads from APP_DATABASE_URL (shared Render.com PostgreSQL).

**How to apply:**
- All routes use `await api(method, path, token=_token(request), ...)` helper (httpx)
- API dicts are converted to attribute-accessible objects via `to_obj()` (SimpleNamespace recursively)
- Datetime strings ending in `_at`, `expires_at`, etc. are auto-parsed to `datetime` objects in `to_obj()`
- Token from session (`request.session["token"]`) is passed as `Authorization: Bearer` header
- If deploying admin panel separately from the local backend, set `BACKEND_API_URL` env var to the target API URL
