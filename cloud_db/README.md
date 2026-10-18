# Vvewell Cloud Database

PostgreSQL/Supabase implementation of the architecture in
[`../CLOUD_DB_PLAN.md`](../CLOUD_DB_PLAN.md). It contains seventeen versioned
migrations, 61 application tables, local Docker tests, an idempotent Supabase
deployer, and non-destructive hosted live tests.

## Prerequisites

- Docker Desktop for local PostgreSQL;
- the `gradio` Conda environment with `python-dotenv` and `requests` for hosted
  deployment;
- at least 4 GiB free disk space before the local test runner recreates its
  isolated database.

## Start the local database

The first-time path also proves the database works:

```bash
cd cloud_db
df -h .
./scripts/run_local_tests.sh
```

This starts the `vvewell-cloud-db` container, drops and recreates only
`vvewell_test`, applies every migration twice, and runs all SQL and local live
tests. The local SQL suite does not contact Supabase, and Supabase credentials
are not passed into the PostgreSQL container. The migrated `vvewell_test`
database is left running for `webui_db`.

After initial setup, start the preserved database without recreating it:

```bash
cd cloud_db
docker compose up --detach --wait db
docker compose ps
```

The container listens on `127.0.0.1:55432` by default. Stop it without deleting
the named volume:

```bash
docker compose down
```

Do not add `--volumes` unless a full local data reset is intended.

## Migrations

| Migration | Purpose |
| --- | --- |
| `0001_foundation.sql` | Extensions, schemas, migration metadata, utilities |
| `0002_core.sql` | Accounts, families, members, devices, permissions, contacts |
| `0003_storage_ingest.sql` | `app_storage` object metadata and sync bookkeeping |
| `0004_telemetry.sql` | Phone-compatible and derived time-series data |
| `0005_inference.sql` | Digital twin, baseline, event, causal, intervention data |
| `0006_medical_care.sql` | OCR, clinical, medication, care and delivery workflows |
| `0007_security.sql` | Consent, emergency access, immutable audit, export, deletion |
| `0008_insurance.sql` | Product catalog, risk profiles, recommendations |
| `0009_access_views.sql` | Tenant context, RLS, grants, views, partitions |
| `0010_phone_measurement_sync.sql` | Authenticated phone vital-reading sync RPC |
| `0010_reasoning_foundation.sql` | WP2 output contract, registries, validation and drift |
| `0011_l0_fusion.sql` | L0 trust metadata, fused metrics, conflicts, and authenticated sync RPCs |
| `0011_multimodal_device_sources.sql` | WP2 source taxonomy for infrared and smart-glasses observations |
| `0012_health_tags_recommendations.sql` | River health-tag evidence, recommendation catalog, decisions, feedback, and tasks |
| `0012_reasoning_registry_seed.sql` | WP2 metric/feature/evidence/model/backlog registry seeds |
| `0013_phone_analysis_sync.sql` | Phone-produced analysis runs, provenance, context download, and authenticated artifact-bundle sync |
| `0014_observatory_analysis_triggers.sql` | Idempotent dashboard/manual-sync promotion from fused L0 metrics through descriptive L1-L3 artifacts |

The two `0010_*` files share their numeric prefix; the deployer keys migration
history on the full file stem and applies them in filename order.

Supabase owns the `storage` schema. Application object metadata therefore uses
`app_storage.object_ref`; migrations do not alter Supabase Storage tables or
permissions.

## Deploy and verify Supabase

Supabase is hosted, so there is no database process to start locally. Configure
the ignored `cloud_db/.env` with:

```dotenv
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_ACCESS_TOKEN=
```

The legacy aliases `SUPABASE_PUBLIC_KEY` and `SUPABASE_SECRET_KEY` remain
supported. `SUPABASE_ACCESS_TOKEN` must be a Management API personal access
token; anon and service-role project keys cannot execute DDL.

Deploy and run the strict hosted suite from the repository root:

```bash
cd cloud_db
conda run -n gradio python scripts/deploy.py
conda run -n gradio python scripts/live_test.py
```

`deploy.py` applies only missing migrations, rejects checksum drift, and
verifies all 61 application tables. It is safe to rerun after a successful
deployment. `live_test.py` verifies migration and RLS inventory, transactional
member isolation, public-key denial, and service-role REST access. Credential
values are loaded through `python-dotenv`, redacted from errors, and never
printed.

## Use with the web UI

After local setup or Supabase deployment:

```bash
cd ../webui_db
pnpm install --frozen-lockfile
pnpm dev
```

Open `http://127.0.0.1:4173` and choose `Local Docker` or `Supabase`. See
[`../webui_db/README.md`](../webui_db/README.md) for source-specific usage,
mock-data behavior, production startup, and UI tests.

`Run analysis` promotes available fused L0 metrics into normalized features,
descriptive health states, a digital-twin snapshot, personal baselines, and
baseline-deviation events. It deliberately does not manufacture causal edges,
clinical diagnoses, recommendations, or delivery actions.
