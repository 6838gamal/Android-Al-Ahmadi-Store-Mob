---
name: Product grade column migration
description: The Product model's `grade` column (screen color: white/green/orange) was missing from migrations.py, causing every product creation to fail with a 500 error.
---

The `Product` SQLAlchemy model defines `grade` (screen quality/color grade — meaningful only when category=screen), but `backend/core/migrations.py`'s products-table ALTER TABLE list never included it. Any INSERT into `products` failed with `UndefinedColumn: column "grade" does not exist`, breaking **all** product creation (not just screen products), both locally and on the Render.com production DB, until the column existed.

**Why:** SQLAlchemy `create_all()` only creates new tables, not new columns on existing tables — new model fields always need an explicit ALTER TABLE entry in `run_migrations()` (see the existing "Migrations for new columns" memory note).

**How to apply:** Whenever a new column is added to an existing model (products, users, etc.), grep `backend/core/migrations.py` for that table's ALTER TABLE list and confirm the new column is present, not just declared on the model. The admin panel always calls the external Render.com backend (never a local one), so a schema fix here only takes effect on production once that backend is redeployed and its `run_migrations()` runs again.
