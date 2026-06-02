from sqlalchemy import text, inspect, create_engine
from sqlalchemy.pool import NullPool
from backend.core.database import engine


def _is_postgres():
    return engine.dialect.name == "postgresql"


def _is_sqlite():
    return engine.dialect.name == "sqlite"


def run_migrations():
    """Safely add new columns and enum values without losing data."""
    inspector = inspect(engine)
    existing_tables = inspector.get_table_names()

    # ── PostgreSQL: extend enums BEFORE table ops ──────────────────────────
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
                        pass
                for val in ("alert", "event"):
                    try:
                        conn.execute(text(
                            f"ALTER TYPE announcementtype ADD VALUE IF NOT EXISTS '{val}'"
                        ))
                    except Exception:
                        pass
        except Exception:
            pass
        finally:
            raw_engine.dispose()

    with engine.connect() as conn:
        # ── users table ────────────────────────────────────────────────────
        if "users" in existing_tables:
            users_cols = [c["name"] for c in inspector.get_columns("users")]
            new_user_cols = [
                ("branch_id",       "INTEGER"),
                ("referral_code",   "VARCHAR(20)"),
                ("referred_by_id",  "INTEGER"),
                ("wallet_balance",  "FLOAT DEFAULT 0.0"),
                ("wallet_currency", "VARCHAR(3) DEFAULT 'YER'"),
                ("referral_level",  "INTEGER DEFAULT 1 NOT NULL"),
                ("level1_locked",   "BOOLEAN DEFAULT FALSE NOT NULL"),
            ]
            for col_name, col_def in new_user_cols:
                if col_name not in users_cols:
                    conn.execute(text(
                        f"ALTER TABLE users ADD COLUMN {col_name} {col_def}"
                    ))

        # ── products table ─────────────────────────────────────────────────
        if "products" in existing_tables:
            prod_cols = [c["name"] for c in inspector.get_columns("products")]
            new_prod_cols = [
                ("warehouse_id", "INTEGER"),
                ("branch_id",    "INTEGER"),
                ("series",       "VARCHAR(50)"),
            ]
            for col_name, col_def in new_prod_cols:
                if col_name not in prod_cols:
                    conn.execute(text(
                        f"ALTER TABLE products ADD COLUMN {col_name} {col_def}"
                    ))

        # ── referrals table ────────────────────────────────────────────────
        if "referrals" in existing_tables:
            ref_cols = [c["name"] for c in inspector.get_columns("referrals")]
            if "level" not in ref_cols:
                conn.execute(text(
                    "ALTER TABLE referrals ADD COLUMN level INTEGER DEFAULT 1 NOT NULL"
                ))

        # ── warranty table (new approve/reject + resolve fields) ───────────
        ts_type = "TIMESTAMP" if _is_postgres() else "DATETIME"
        if "warranties" in existing_tables:
            war_cols = [c["name"] for c in inspector.get_columns("warranties")]
            new_war_cols = [
                ("return_approved",  "BOOLEAN"),
                ("return_notes",     "TEXT DEFAULT ''"),
                ("resolved_by_id",   "INTEGER"),
                ("resolved_at",      ts_type),
                ("return_resolved",  "BOOLEAN DEFAULT FALSE NOT NULL"),
            ]
            for col_name, col_def in new_war_cols:
                if col_name not in war_cols:
                    conn.execute(text(
                        f"ALTER TABLE warranties ADD COLUMN {col_name} {col_def}"
                    ))

        # ── inspection_requests table (responded_at field) ─────────────────
        if "inspection_requests" in existing_tables:
            ins_cols = [c["name"] for c in inspector.get_columns("inspection_requests")]
            new_ins_cols = [
                ("responded_at",    ts_type),
                ("response_images", "TEXT DEFAULT '[]'"),
            ]
            for col_name, col_def in new_ins_cols:
                if col_name not in ins_cols:
                    conn.execute(text(
                        f"ALTER TABLE inspection_requests ADD COLUMN {col_name} {col_def}"
                    ))

        # ── announcements table (new fields) ──────────────────────────────
        if "announcements" in existing_tables:
            ann_cols = [c["name"] for c in inspector.get_columns("announcements")]
            if "action_url" not in ann_cols:
                conn.execute(text(
                    "ALTER TABLE announcements ADD COLUMN action_url VARCHAR(500)"
                ))

        # ── inventory_items table (sold tracking) ──────────────────────────
        if "inventory_items" in existing_tables:
            inv_cols = [c["name"] for c in inspector.get_columns("inventory_items")]
            new_inv_cols = [
                ("sold_to_id",    "INTEGER"),
                ("sold_order_id", "INTEGER"),
            ]
            for col_name, col_def in new_inv_cols:
                if col_name not in inv_cols:
                    conn.execute(text(
                        f"ALTER TABLE inventory_items ADD COLUMN {col_name} {col_def}"
                    ))

        conn.commit()

    # ── Unique index on users.referral_code ─────────────────────────────────
    try:
        with engine.connect() as conn:
            if _is_sqlite():
                conn.execute(text(
                    "CREATE UNIQUE INDEX IF NOT EXISTS "
                    "ix_users_referral_code_uniq ON users (referral_code)"
                ))
            else:
                conn.execute(text(
                    "CREATE UNIQUE INDEX IF NOT EXISTS "
                    "ix_users_referral_code_uniq ON users (referral_code) "
                    "WHERE referral_code IS NOT NULL"
                ))
            conn.commit()
    except Exception:
        pass

    # ── Unique index on referrals.referred_id ──────────────────────────────
    try:
        with engine.connect() as conn:
            conn.execute(text(
                "CREATE UNIQUE INDEX IF NOT EXISTS "
                "ix_referrals_referred_id_uniq ON referrals (referred_id)"
            ))
            conn.commit()
    except Exception:
        pass

    # ── Index on referrals.device_fingerprint ──────────────────────────────
    try:
        with engine.connect() as conn:
            conn.execute(text(
                "CREATE INDEX IF NOT EXISTS "
                "ix_referrals_device_fingerprint ON referrals (device_fingerprint)"
            ))
            conn.commit()
    except Exception:
        pass

    print("✅ Migrations applied successfully")
