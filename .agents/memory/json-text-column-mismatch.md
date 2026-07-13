---
name: JSON column mistakenly created as TEXT (Postgres)
description: SQLAlchemy Column(JSON) silently returns raw string instead of list/dict when the underlying Postgres column is actually TEXT, not json/jsonb.
---

If a migration adds a column via `ALTER TABLE ... ADD COLUMN x TEXT DEFAULT '[]'` but the
ORM model declares `Column(JSON)`, reads on Postgres return the raw string `'[]'` instead of
a parsed list/dict — SQLAlchemy assumes Postgres' native JSON support means the driver
already deserialized the value, so it skips `json.loads` for TEXT-typed columns.

**Why:** This crashed `GET /api/products` in the Android Al-Ahmadi Store project with a
`ResponseValidationError` (Pydantic expected `List[str]`, got the string `'[]'`), surfacing
as a generic "حدث خطأ" (error occurred) on the Flutter home screen — looked like a
connectivity issue but was a schema bug in the shared Postgres DB (same DB used by local
Replit dev and the deployed Render.com backend).

**How to apply:** When a "JSON" column returns a string instead of parsed data on Postgres,
check the actual column type (`information_schema.columns` or SQLAlchemy inspector) rather
than trusting the ORM model declaration. Fix by `ALTER COLUMN ... TYPE json USING <col>::json`
(after dropping any incompatible default first), not by changing the ORM type. Any future
migration that adds a JSON-shaped column must create it as `JSON`/`JSONB` at the SQL level,
never `TEXT DEFAULT '[]'`.
