---
name: Replit DATABASE_URL conflict with Pydantic BaseSettings
description: Replit auto-sets DATABASE_URL env var (local PostgreSQL); Pydantic BaseSettings field named DATABASE_URL picks it up, overriding APP_DATABASE_URL (Render). Fix is in database.py.
---

## The Rule
`backend/core/database.py` must call `_resolve_db_url()` directly — never use `settings.DATABASE_URL`.

## Why
Replit sets a `DATABASE_URL` env var pointing to its own local PostgreSQL (`postgresql://postgres:password@helium/...`). Pydantic `BaseSettings` auto-injects any env var matching a field name. The `Settings` class has `DATABASE_URL: str = _resolve_db_url()` — so Pydantic silently overwrites the default with Replit's local DB, ignoring `APP_DATABASE_URL` (the Render PostgreSQL).

Result: backend stores OTP codes and user data to Replit local DB, while Flutter (and any external client) reads from Render — different databases, so OTP verification always fails.

## How to Apply
In `database.py`:
```python
from backend.core.config import _resolve_db_url
DATABASE_URL = _resolve_db_url()   # reads APP_DATABASE_URL → Render DB
```
Do NOT use `settings.DATABASE_URL`.

`_resolve_db_url()` reads `APP_DATABASE_URL` first, falls back to `_DEFAULT_DB_URL` (Render external URL) — it deliberately ignores Replit's `DATABASE_URL`.
