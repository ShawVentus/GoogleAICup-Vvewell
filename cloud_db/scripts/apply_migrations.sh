#!/usr/bin/env bash
set -euo pipefail

db_name="${1:?database name is required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
db_dir="$(cd "${script_dir}/.." && pwd)"

for migration in "${db_dir}"/migrations/*.sql; do
  migration_name="$(basename "${migration}")"
  printf 'Applying %s\n' "${migration_name}"
  docker compose --project-directory "${db_dir}" exec -T db \
    psql --username postgres --dbname "${db_name}" \
      --set ON_ERROR_STOP=1 --file "/workspace/migrations/${migration_name}"
done
