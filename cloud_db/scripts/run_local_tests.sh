#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
db_dir="$(cd "${script_dir}/.." && pwd)"
test_db="${CLOUD_DB_TEST_NAME:-vvewell_test}"

available_kb="$(df -Pk "${db_dir}" | awk 'NR == 2 {print $4}')"
if (( available_kb < 4 * 1024 * 1024 )); then
  printf 'Refusing to start: less than 4 GiB free disk space.\n' >&2
  exit 1
fi

docker compose --project-directory "${db_dir}" up --detach db

# Compose's `up --wait` can surface an image health transition before the
# PostgreSQL entrypoint has completed its first initialization on hosted CI.
# Probe the database service itself instead, so migrations start only after
# PostgreSQL accepts the exact connection they will use.
database_ready=0
for attempt in {1..60}; do
  if docker compose --project-directory "${db_dir}" exec -T db \
    pg_isready --username postgres --dbname postgres >/dev/null 2>&1; then
    database_ready=1
    break
  fi
  sleep 1
done
if (( database_ready == 0 )); then
  printf 'PostgreSQL did not become ready within 60 seconds.\n' >&2
  docker compose --project-directory "${db_dir}" logs db >&2 || true
  exit 1
fi

docker compose --project-directory "${db_dir}" exec -T db \
  psql --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
    --command "DROP DATABASE IF EXISTS ${test_db} WITH (FORCE)"
docker compose --project-directory "${db_dir}" exec -T db \
  psql --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
    --command "CREATE DATABASE ${test_db}"

"${script_dir}/apply_migrations.sh" "${test_db}"
printf 'Reapplying migrations to verify idempotency\n'
"${script_dir}/apply_migrations.sh" "${test_db}"

for test_file in "${db_dir}"/tests/*.sql; do
  test_name="$(basename "${test_file}")"
  printf 'Running %s\n' "${test_name}"
  docker compose --project-directory "${db_dir}" exec -T db \
    psql --username postgres --dbname "${test_db}" \
      --set ON_ERROR_STOP=1 --file "/workspace/tests/${test_name}"
done

for test_file in "${db_dir}"/live_tests/*.sql; do
  test_name="$(basename "${test_file}")"
  printf 'Validating live test SQL locally: %s\n' "${test_name}"
  docker compose --project-directory "${db_dir}" exec -T db \
    psql --username postgres --dbname "${test_db}" \
      --set ON_ERROR_STOP=1 --file "/workspace/live_tests/${test_name}"
done

printf 'All local cloud database tests passed.\n'
