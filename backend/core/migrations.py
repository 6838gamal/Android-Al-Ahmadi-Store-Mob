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

    ts_type = "TIMESTAMP" if _is_postgres() else "DATETIME"

    with engine.connect() as conn:
        # ── users table ────────────────────────────────────────────────────
        if "users" in existing_tables:
            users_cols = [c["name"] for c in inspector.get_columns("users")]
            new_user_cols = [
                ("branch_id",               "INTEGER"),
                ("referral_code",            "VARCHAR(20)"),
                ("referred_by_id",           "INTEGER"),
                ("wallet_balance",           "FLOAT DEFAULT 0.0"),
                ("wallet_currency",          "VARCHAR(3) DEFAULT 'YER'"),
                ("referral_level",           "INTEGER DEFAULT 1 NOT NULL"),
                ("level1_locked",            "BOOLEAN DEFAULT FALSE NOT NULL"),
                ("is_verified",             "BOOLEAN DEFAULT FALSE NOT NULL"),
                ("tokens_invalidated_at",    ts_type),
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

        # ── reservations table (deposit + penalty fields) ──────────────────
        if "reservations" in existing_tables:
            res_cols = [c["name"] for c in inspector.get_columns("reservations")]
            new_res_cols = [
                ("deposit_amount",        "FLOAT DEFAULT 0.0 NOT NULL"),
                ("deposit_paid",          "BOOLEAN DEFAULT FALSE NOT NULL"),
                ("remaining_amount",      "FLOAT DEFAULT 0.0 NOT NULL"),
                ("penalty_amount",        "FLOAT DEFAULT 2000.0 NOT NULL"),
                ("cancellation_type",     "VARCHAR(20)"),
                ("customer_credit_amount","FLOAT DEFAULT 0.0"),
                ("cancelled_at",          ts_type),
                ("cancel_reason",         "TEXT"),
                ("extended_at",           ts_type),
                ("extended_until",        ts_type),
                ("extension_days",        "INTEGER DEFAULT 0"),
                ("extension_count",       "INTEGER DEFAULT 0"),
            ]
            for col_name, col_def in new_res_cols:
                if col_name not in res_cols:
                    conn.execute(text(f"ALTER TABLE reservations ADD COLUMN {col_name} {col_def}"))

        conn.commit()

    # ── Indexes for performance ──────────────────────────────────────────────
    _create_index(engine, "ix_users_referral_code_uniq",
                  "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_referral_code_uniq "
                  "ON users (referral_code)" +
                  (" WHERE referral_code IS NOT NULL" if _is_postgres() else ""))

    _create_index(engine, "ix_referrals_referred_id_uniq",
                  "CREATE UNIQUE INDEX IF NOT EXISTS ix_referrals_referred_id_uniq "
                  "ON referrals (referred_id)")

    _create_index(engine, "ix_referrals_device_fingerprint",
                  "CREATE INDEX IF NOT EXISTS ix_referrals_device_fingerprint "
                  "ON referrals (device_fingerprint)")

    _create_index(engine, "ix_notifications_user_id",
                  "CREATE INDEX IF NOT EXISTS ix_notifications_user_id "
                  "ON notifications (user_id)")

    _create_index(engine, "ix_notifications_is_read",
                  "CREATE INDEX IF NOT EXISTS ix_notifications_is_read "
                  "ON notifications (user_id, is_read)")

    if "orders" in inspector.get_table_names():
        _create_index(engine, "ix_orders_customer_id",
                      "CREATE INDEX IF NOT EXISTS ix_orders_customer_id "
                      "ON orders (customer_id)")

    if "inventory_items" in inspector.get_table_names():
        _create_index(engine, "ix_inventory_items_status",
                      "CREATE INDEX IF NOT EXISTS ix_inventory_items_status "
                      "ON inventory_items (status)")

    if "warranties" in inspector.get_table_names():
        _create_index(engine, "ix_warranties_customer_id",
                      "CREATE INDEX IF NOT EXISTS ix_warranties_customer_id "
                      "ON warranties (customer_id)")

    if "inspection_requests" in inspector.get_table_names():
        _create_index(engine, "ix_inspection_requests_customer_id",
                      "CREATE INDEX IF NOT EXISTS ix_inspection_requests_customer_id "
                      "ON inspection_requests (customer_id)")

    print("✅ Migrations applied successfully")


def _create_index(eng, name: str, sql: str):
    try:
        with eng.connect() as conn:
            conn.execute(text(sql))
            conn.commit()
    except Exception:
        pass
