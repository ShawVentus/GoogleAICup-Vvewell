from remote_lib import (
    DB_DIR,
    SUPABASE_PUBLIC_KEY,
    SUPABASE_SECRET_KEY,
    extract_rows,
    management_sql,
    registered_api_key_roles,
    rest_request,
    run_safely,
)


def main() -> None:
    expected_migration_count = len(list((DB_DIR / "migrations").glob("*.sql")))
    live_sql = (DB_DIR / "live_tests" / "001_live_verification.sql").read_text(
        encoding="utf-8"
    )
    management_sql(live_sql, "Running transactional live database tests")
    print("Transactional live database tests passed.")

    result = management_sql(
        "SELECT "
        "(SELECT count(*) FROM cloud_db_meta.schema_migrations)::integer AS migration_count, "
        "(SELECT count(*) FROM pg_policies WHERE schemaname IN "
        "('core','ingest','telemetry','app_storage','inference','medical','insurance','care','security'))"
        "::integer AS policy_count",
        "Checking live migration and policy inventory",
        read_only=True,
    )
    rows = extract_rows(result)
    inventory = rows[0] if rows else {}
    if int(inventory.get("migration_count", 0)) != expected_migration_count or int(
        inventory.get("policy_count", 0)
    ) < 100:
        raise RuntimeError(
            "Live migration or RLS policy inventory is incomplete "
            f"(expected {expected_migration_count} migration checksums)."
        )

    public_roles = registered_api_key_roles(SUPABASE_PUBLIC_KEY)
    secret_roles = registered_api_key_roles(SUPABASE_SECRET_KEY)
    if not ({"anon:legacy"} & public_roles or any(role.endswith(":publishable") for role in public_roles)):
        raise RuntimeError("SUPABASE_ANON_KEY does not match a project anon or publishable key.")
    if "anon:legacy" in secret_roles and "service_role:legacy" not in secret_roles:
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY matches the project anon key, not service_role.")
    if not (
        {"service_role:legacy"} & secret_roles
        or any(role.endswith(":secret") for role in secret_roles)
    ):
        raise RuntimeError("SUPABASE_SERVICE_ROLE_KEY does not match a project service or secret key.")

    status, body = rest_request(
        SUPABASE_PUBLIC_KEY, "vvewell_health_metric", "?select=id&limit=1"
    )
    if status == 200 and body != "[]":
        raise RuntimeError("Public key unexpectedly returned protected health data.")
    if status not in (200, 401, 403, 404):
        raise RuntimeError(f"Unexpected public-key REST status {status}.")
    print("Public-key protected-data access test passed.")

    status, _ = rest_request(
        SUPABASE_SECRET_KEY, "vvewell_health_metric", "?select=id&limit=1"
    )
    if status != 200:
        raise RuntimeError(f"Unexpected secret-key REST status {status}.")
    print("Secret-key REST service access test passed.")

    print("All live Supabase tests passed.")


if __name__ == "__main__":
    run_safely(main)
