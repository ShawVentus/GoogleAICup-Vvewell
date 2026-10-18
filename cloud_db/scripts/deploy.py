from remote_lib import (
    checksum,
    extract_rows,
    management_sql,
    migration_files,
    run_safely,
    sql_literal,
)


def migration_table_exists() -> bool:
    result = management_sql(
        "SELECT to_regclass('cloud_db_meta.schema_migrations')::text AS relation_name",
        "Checking migration metadata",
        read_only=True,
    )
    return any(row.get("relation_name") for row in extract_rows(result))


def remote_checksum(version: str) -> str | None:
    if not migration_table_exists():
        return None
    result = management_sql(
        "SELECT checksum FROM cloud_db_meta.schema_migrations "
        f"WHERE version = {sql_literal(version)}",
        f"Checking migration {version}",
        read_only=True,
    )
    rows = extract_rows(result)
    return rows[0].get("checksum") if rows else None


def main() -> None:
    management_sql(
        "SELECT current_database() AS database_name",
        "Validating Supabase database access",
        read_only=True,
    )
    print("Supabase database access validated.")

    for name, version, sql in migration_files():
        local_checksum = checksum(sql)
        applied_checksum = remote_checksum(version)
        if applied_checksum == local_checksum:
            print(f"Skipping {name}: checksum already applied.")
            continue
        if applied_checksum:
            raise RuntimeError(
                f"Checksum drift detected for {name}; refusing to overwrite remote history."
            )

        print(f"Applying {name}.")
        management_sql(sql, f"Applying {name}")
        management_sql(
            "INSERT INTO cloud_db_meta.schema_migrations (version, checksum) "
            f"VALUES ({sql_literal(version)}, {sql_literal(local_checksum)}) "
            "ON CONFLICT (version) DO UPDATE SET checksum = EXCLUDED.checksum, "
            "applied_at = clock_timestamp()",
            f"Recording {name}",
        )

    result = management_sql(
        "SELECT count(*)::integer AS table_count "
        "FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace "
        "WHERE n.nspname IN "
        "('core','ingest','telemetry','app_storage','inference','medical','insurance','care','security') "
        "AND c.relkind IN ('r','p') AND NOT c.relispartition",
        "Verifying deployed table inventory",
        read_only=True,
    )
    rows = extract_rows(result)
    table_count = int(rows[0].get("table_count", 0)) if rows else 0
    if table_count != 61:
        raise RuntimeError(
            f"Remote deployment has {table_count} application tables; expected 61."
        )
    print("Supabase migrations deployed: 61 application tables verified.")


if __name__ == "__main__":
    run_safely(main)
