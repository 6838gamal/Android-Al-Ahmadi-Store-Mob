# Android Al-Ahmadi Store

A comprehensive mobile phone shop management system consisting of:
- **Flutter Web App** — customer-facing storefront (served on port 5000)
- **FastAPI Backend** — REST API for data management (port 8000)
- **Admin Panel** — Jinja2-based admin dashboard (port 8080)

## Project Structure

- `lib/` — Flutter frontend source (Clean Architecture)
- `backend/` — Python FastAPI REST API
- `admin_panel/` — Server-side rendered admin dashboard (Jinja2 + FastAPI)
- `build/web/` — Pre-compiled Flutter web output
- `server.js` — Node.js static server + API proxy (port 5000)
- `run_backend.py` — Starts the FastAPI backend on port 8000
- `run_admin.py` — Starts the admin panel on port 8080

## Running the App

Three workflows run in parallel:
1. **Start application** — `node server.js` (serves Flutter web + proxies /api to backend)
2. **Backend API** — `python run_backend.py` (FastAPI on port 8000)
3. **Admin Panel** — `python run_admin.py` (Admin dashboard on port 8080)

## Default Admin Credentials

- Email: `admin@alahmadi.com`
- Password: `Admin@2026`

## Tech Stack

- **Frontend**: Flutter 3.x (Dart)
- **Backend**: Python FastAPI + SQLAlchemy
- **Database**: PostgreSQL on Render.com via `APP_DATABASE_URL` env var
- **Admin**: FastAPI + Jinja2 templates

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `APP_DATABASE_URL` | Render.com PostgreSQL URL | قاعدة البيانات الرئيسية |
| `BACKEND_API_URL` | `https://android-al-ahmadi-store-api.onrender.com` | عنوان الـ API الخارجي |
| `SECRET_KEY` | secret string | مفتاح JWT |

## Architecture Flow

```
Flutter (port 5000)
  └→ server.js proxy
       └→ https://android-al-ahmadi-store-api.onrender.com  (Render.com)

Admin Panel (port 8080)
  └→ https://android-al-ahmadi-store-api.onrender.com  (Render.com)
```

## User Preferences

- Do not replace external URLs (e.g. the Render.com backend API) with local ones, and do not change other existing configuration/details when doing setup work — keep everything as imported.

## Setup Notes

Python dependencies (uvicorn, jinja2, itsdangerous, etc.) were missing after import and were installed via `uv add` from the existing `requirements.txt` list; `bcrypt` was re-pinned to `4.0.1` (required for passlib compatibility). No URLs, endpoints, or other configuration were changed. All three workflows (Start application, Backend API, Admin Panel) are running.
