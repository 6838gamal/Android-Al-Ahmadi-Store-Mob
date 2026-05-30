from sqlalchemy import text, inspect, create_engine
from sqlalchemy.pool import NullPool
from backend.core.database import engine


def _is_postgres():
    return engine.dialect.name == "postgresql"


def run_migrations():
    """Safely add new columns and enum values without losing data."""
    inspector = inspect(engine)
    existing_tables = inspector.get_table_names()

    # ── PostgreSQL: extend userrole enum BEFORE table ops ──────────────────
    # ALTER TYPE ... ADD VALUE cannot run inside a regular transaction.
    # We create a separate AUTOCOMMIT engine using engine.url (URL object,
    # not str — str() masks the password in SQLAlchemy 1.4+).
    if _is_postgres():
        raw_engine = create_engine(
            engine.url, isolation_level="AUTOCOMMIT", poolclass=NullPool
        )
        try:
            with raw_engine.connect() as conn:
                for val in ("staff", "branch_manager"):
                    try:
                        conn.execute(text(
                            f"ALTER TYPE userrole ADD VALUE IF NOT EXISTS '{val}'"
                        ))
                    except Exception:
                        pass  # value already exists or type not yet created
        except Exception:
            pass  # DB unreachable — tables may not be created yet
        finally:
            raw_engine.dispose()

    with engine.connect() as conn:
        # ── users table additions ──────────────────────────────────────────
        if "users" in existing_tables:
            users_cols = [c["name"] for c in inspector.get_columns("users")]
            new_user_cols = [
                ("branch_id",      "INTEGER"),
                ("referral_code",  "VARCHAR(20)"),
                ("referred_by_id", "INTEGER"),
                ("wallet_balance",  "FLOAT DEFAULT 0.0"),
                ("wallet_currency", "VARCHAR(3) DEFAULT 'YER'"),
            ]
            for col_name, col_def in new_user_cols:
                if col_name not in users_cols:
                    conn.execute(text(
                        f"ALTER TABLE users ADD COLUMN {col_name} {col_def}"
                    ))

        # ── products table additions ───────────────────────────────────────
        if "products" in existing_tables:
            prod_cols = [c["name"] for c in inspector.get_columns("products")]
            new_prod_cols = [
                ("warehouse_id", "INTEGER"),
                ("branch_id",    "INTEGER"),
            ]
            for col_name, col_def in new_prod_cols:
                if col_name not in prod_cols:
                    conn.execute(text(
                        f"ALTER TABLE products ADD COLUMN {col_name} {col_def}"
                    ))

        conn.commit()
    print("✅ Migrations applied successfully")
