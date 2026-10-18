# Vvewell DB Integration State

Updated: 2026-08-03

## Scope and Repository Identity

The current branch is `feature/cloud_database`, based on merge state `cfacd36`
from `feature/android_merge`, `feature/reasoning-r1`, and
`feature/recommender_v1`. The L0 implementation described below is the local
change set being committed after that merge.
The literal
`alloop_hackathon-main` directory contains only three tracked files and is not
a runnable app. The executable successor is `alloop-SDK`, created by the mass
rename in commit `ef982f6`; this state file audits and updates that successor.

The PRD was re-read from
`~/Downloads/PhysicalAI2026/vvewell-hackathon-prd.docx`. The requested Pandoc
and Python DOCX readers are unavailable in the `gradio` Conda environment, so
the L0 text was extracted read-only from `word/document.xml` in the DOCX.

## Current End-to-End Status

**The Android demo now executes L0, River-equivalent health analysis, and Matrix
V2 recommendations entirely on the phone.** Real sensor saves trigger a
serialized Dart isolate run. One SQLite v3 transaction persists fused metrics,
analysis run/state, health tags, the immutable decision, tasks, and an outbox.
Home and task actions use this local state and do not call Supabase, Python, or
NestJS.

This is not strict full-matrix PRD completion. Infrared/thermal cameras,
IEEE-11073 home medical devices, care peripherals, raw waveform
cross-correlation, and multi-sensor fall confirmation remain unavailable or
unimplemented. They cannot be honestly validated without hardware/vendor
streams and are tracked as external/residual work below.

The user-facing live flow is:

`sensor result -> SQLite vital_readings -> Dart L0 -> Dart health tags -> Dart
Matrix V2 -> SQLite decision/tasks/outbox -> Home`

Only after the user taps the cloud-upload icon does the app authenticate and
send the frozen local bundle through `sync_phone_analysis_bundle`; it then
downloads a minimal context snapshot through `get_phone_analysis_context` for
future local runs.

Only the explicit upload action sends data. Per-artifact acknowledgements mark
local rows synced; rejected or interrupted items remain pending and are safely
replayed using deterministic IDs and SHA-256 payload fingerprints. Debug/mock
records are excluded. No identity or credential details appear in the app UI.

## L0 Completion Assessment On `feature/cloud_database`

The PRD defines L0 as hardware ingestion plus trustworthy output, not simply
sensor connectivity. It requires: the core and peripheral sensor matrix;
source-specific SQI; four-state wear inference; UTC/drift alignment; SQI-weighted
adaptive Kalman fusion; conflict detection with interval/abstention behavior;
the structured fused-output contract; and one-minute coverage masks with a 40%
abstention gate.

| L0 capability | Current implementation | Remaining work |
|---|---|---|
| PPG rings, phone rPPG, and mmWave ingestion | Real AIZO, Alloop, rPPG, and radar summaries reach local `vital_readings`; `L0FusionEngine.process` converts those SQLite rows into source-tagged metric observations. The authenticated raw RPC auto-registers supported devices and preserves trust metadata. | Preserve full raw-window object references and sampling metadata where vendor SDKs expose them. |
| Infrared, home medical devices, and care sensors | Device types/tables exist. Backend strings mention thermal data; medical reports support CRUD and externally supplied OCR JSON. | Implement actual thermal, IEEE-11073 medical-device, environment/door/presence, emergency-button, pillbox, and mattress adapters. Implement OCR execution and normalization rather than only accepting already-produced JSON. Hardware/vendor access is an external prerequisite. |
| Source-specific SQI | Real rows use bounded source/metric confidence, physiological plausibility, packet-loss, validity, ring motion, radar single-target, and radar SNR gates. Thresholds and fusion policy are versioned as `l0-adaptive-kalman-v1`. | Calibrate thresholds with synchronized real-device datasets; add raw PPG morphology and radar phase/posture features when raw streams are available. |
| Wear state | Four-state `WORN_GOOD`/`WORN_POOR`/`CHARGING`/`OFF` inference uses charging flags, validity, and skin temperature with the PRD's separate child threshold. `CHARGING`/`OFF` observations abstain; state is persisted on raw and fused rows. | Persist independent state-transition history in `device_status_sample`; calibrate battery-trend inference. |
| Time alignment | Known device clock offset is applied before deterministic UTC one-minute windowing; offset and packet loss are persisted. Session gaps bound replay and late rows are deterministically recomputed. | Add waveform cross-correlation/event anchors when simultaneous raw waveforms exist. |
| Coverage and missingness | Every metric window carries a per-source coverage mask. No interpolation is used for inference; `<40%` coverage produces `ABSTAINED/INSUFFICIENT_COVERAGE`, including source-empty missing windows. | Add display-only interpolation outside the inference path if the UI needs it. |
| Multi-source fusion | Per-metric policies restrict eligible sources; quality controls observation variance in a deterministic scalar Kalman update. HR uses rings/rPPG/radar, respiration prioritizes radar by variance, and SpO2/HRV/temperature are ring-only. | Multi-sensor fall confirmation requires real fall/posture inputs. |
| Conflict arbitration | Overlapping real sources use versioned absolute/relative tolerances. A divergence produces no point estimate, emits an interval, and persists the worst source pair in `signal_conflict`. | Add a user remeasurement workflow and calibrate tolerances with real synchronized captures. |
| Fused output contract and persistence | `L0FusedMetric`, `telemetry.l0_fused_metric`, and `public.sync_l0_fused_metric` preserve status, value/interval, unit, confidence, SQI, coverage mask, quality, contributors, wear state, age group, abstention reason, algorithm version, fingerprint, and evidence. | Decide whether downstream L1 consumes this table directly or through `inference.algorithm_output`. |
| Edge/offline operation | Processing runs on-device over local SQLite. Manual sync replays up to seven days; raw local markers plus fused fingerprints make retries idempotent and prevent fused writes before raw contributors are confirmed. | Add background backoff and priority safety queues only if product scope expands beyond explicit user-requested sync. |
| Validation and observability | Six Dart tests cover deterministic replay/fusion, conflict, coverage, wear/age, clock alignment, quality, and mock rejection. SQL tests cover replay, empty missing windows, ownership, RLS, metadata, device registration, and conflicts; hosted rollback tests exercise the new RPCs. | Add synchronized physical-device golden datasets and production distribution monitoring. |

### L0 Definition Of Done

L0 should be marked complete only when a real AIZO/Alloop/rPPG/mmWave capture can
travel through the canonical observation contract, quality/wear gates,
one-minute alignment and coverage processing, multi-source fusion/conflict
arbitration, and an idempotent hosted Supabase write; a replay test must prove
source traceability, `<40%` abstention, conflict interval/abstention behavior,
and offline retry. Strict full-PRD completion additionally requires physical or
vendor-simulated thermal and peripheral care devices. Until those dependencies
are available, the achievable milestone is **L0 core complete for available
sensors**, not strict sensor-matrix completion.

### Residual L0 Work

The approved core sequence is implemented and deployed. Remaining strict-PRD
work is hardware-dependent: thermal, home-medical and care adapters; raw-wave
cross-correlation; fall/posture fusion; device-status transition history; and
synchronized physical-device calibration/golden datasets. These items remain
explicitly incomplete rather than being simulated or claimed as production-ready.

## Dirty Demo Credential Bundle

**DIRTY_DEMO_EMBEDDED_CREDENTIALS_REMOVE_BEFORE_RELEASE**

This is an explicitly temporary hackathon workaround. A dedicated hosted
Supabase Auth user, matching `core.users`/family-member row, and `phone_camera`
device are provisioned. The project URL, publishable key, member UUID, and demo
user identity are stored as an AES-GCM encrypted dotenv payload in
`alloop-SDK/assets/demo_cloud_credentials.enc` and decrypted only in app memory.

The AES key must also ship in the APK, split across two byte arrays. This is
obfuscation against casual plaintext extraction, **not secure secret storage**;
an APK analyst can recover it. No service-role key, Supabase Management token,
or database password is included. Search the repository for the marker above to
find every removal point. Before production, delete the encrypted asset and
provisioner, remove the loader/PointyCastle dependency, and replace
`ensureDemoSession` with real end-user Auth/OAuth.

## App Changes

Supabase client and configuration:

- [`pubspec.yaml`](../alloop-SDK/pubspec.yaml) includes `supabase_flutter` and
  `pointycastle`, bundles the encrypted asset, and no longer bundles `.env`.
- [`main.dart`](../alloop-SDK/lib/main.dart) initializes the temporary embedded
  demo configuration and carries the removal marker.
- [`embedded_demo_cloud_credentials.dart`](../alloop-SDK/lib/features/cloud_sync/data/embedded_demo_cloud_credentials.dart)
  decrypts and validates the AES-GCM dotenv payload in memory. It contains the
  intentionally recoverable split-key workaround and removal marker.
- [`provision_embedded_demo.py`](./scripts/provision_embedded_demo.py) creates the
  dedicated hosted Auth/application records and writes the encrypted asset
  without creating a plaintext credential file.
- [`verify_embedded_demo.py`](./scripts/verify_embedded_demo.py) verifies bundle
  decryption, hosted password Auth, member RLS, encrypted asset inclusion, and
  absence of plaintext bundle values or `.env` in the built APK.

Manual uploader:

- [`l0_fusion_engine.dart`](../alloop-SDK/lib/features/cloud_sync/domain/l0_fusion_engine.dart) `L0FusionEngine.process` (150-225) bridges real SQLite rows to observations; `_observationsFor` (227-271), `_processSession` (290-329), `_fuseWindow` (331-473), `_kalman` (508-527), `_worstConflict` (550-576), and `_RawRow.wearState` (700-721) implement the L0 quality, alignment, coverage, fusion, conflict, and wear contracts.
- [`cloud_measurement_sync_service.dart`](../alloop-SDK/lib/features/cloud_sync/data/cloud_measurement_sync_service.dart) `CloudMeasurementSyncService.syncPendingVitalReadings` (104-233) resolves the member age group, runs a seven-day deterministic replay, uploads up to 500 pending real rows, and then uploads only cloud-ready fused windows. The result reports raw, fused, conflict, abstention, skip, and failure counts.
- The service maps all existing normalized sources: `aizo_ring`, `alloop_ring`, `rppg_phone`, and `mmwave_radar`.
- [`local_health_database.dart`](../alloop-SDK/lib/core/database/local_health_database.dart:247) adds `onlyUnsynced`/`limit` filtering to `loadVitalReadings` at 247–282 and `markVitalReadingSynced` at 285–298.
- [`LocalHealthDatabaseBridge.kt`](../alloop-SDK/android/app/src/main/kotlin/com/alloop/blue/test/LocalHealthDatabaseBridge.kt:37) adds `cloud_synced_at` and `cloud_reading_id`, schema upgrade 1→2 at 164–174, pending loading at 290–324, and marker update at 327–340.
- [`home_page.dart`](../alloop-SDK/lib/features/main/home_page.dart:158) places [`CloudSyncButton`](../alloop-SDK/lib/features/cloud_sync/presentation/widgets/cloud_sync_button.dart) in every vvewell header. `_sync` performs silent demo authentication and reports only credential-neutral success/failure text; there are no identity fields or sign-in dialog.

## Health Analysis And Recommendation Integration

The deployed L4 demo path is now connected end to end:

`local vital_readings -> Dart L0 -> Dart River-equivalent analyzer -> local
health_tags -> Dart Matrix V2 -> local recommendation_decisions/health_tasks ->
Flutter Home`

The phone implementation preserves River 0.25.0 Mean/Var, EWMean/EWVar and
ADWIN semantics, including predict-before-update and the exact golden drift
index. The V2 matrix ranks 13 approved wellness intents over 25 versioned
features. Eligibility, consent, verified medical facts, care escalation,
commercial disclosure, and data-origin rules execute outside scoring and fail
closed. The Python service and NestJS recommender remain parity oracles, not
live-path dependencies. Flutter renders advice, tasks, goods, and services and
persists impressions and task state; it has no service credential.

The hosted evidence is intentionally marked `SIMULATION_ONLY`: 36 deterministic
demo fused rows produced one `relative_hr_elevated` tag. Replaying both the
import and River analysis did not increase row/tag counts. No commercial consent
was seeded, so the hosted HTTP smoke selected advice/tasks and excluded goods
and services. Positive and prohibited goods/service cases are covered by the
canonical Matrix V2 test suite; no payment, order, insurance, or appointment
side effect exists.

## Database Changes

- All fourteen migrations through [`0013_phone_analysis_sync.sql`](./migrations/0013_phone_analysis_sync.sql) are deployed to the configured hosted Supabase project; 56 application tables are verified.
- `0013_phone_analysis_sync.sql` adds phone-producer provenance, `inference.phone_analysis_run`, authenticated context download, and ordered/idempotent bundle synchronization with per-artifact acknowledgements and cloud-side version/catalog/consent validation.
- `0011_l0_fusion.sql` adds `telemetry.l0_fused_metric` (10-51), source-to-device registration (63-127), authenticated age context (129-150), expanded idempotent raw sync (152-239), and authenticated fused/conflict persistence (241-349).
- It updates `cloud_db_meta.current_user_id()` to resolve either the Auth UUID or `core.users.auth_uid` to the application user UUID.
- `public.sync_vital_reading` checks write access, safely auto-registers only the four supported L0 device types, calls `ingest.upsert_vital_reading`, and stores age, coverage, quality, wear, clock, and packet metadata.
- `public.sync_l0_fused_metric` enforces ownership, deduplicates deterministic replays, derives age group server-side, and writes real conflict evidence to `telemetry.signal_conflict`.
- The existing service-role-only `ingest.upsert_vital_reading` remains unchanged for backend jobs. The phone never receives or stores a service-role key.

Hosted prerequisites for this demo are provisioned: the Supabase Auth user is
confirmed, `core.users.auth_uid` links it to the application user, its
`core.family_member` row is accessible through RLS, and its `core.devices` row
maps local `phone_camera` to `rppg_phone`. The app targets the hosted Supabase URL,
not the local Docker database.

## PRD Functionality Levels

The initial audit found no level fully implemented in the literal
`alloop_hackathon-main` tree. In `alloop-SDK`:

- **L0: Core complete for available sensors; strict matrix incomplete.** AIZO, Alloop, rPPG, and radar normalized measurements now traverse on-device trust processing and idempotent hosted raw/fused/conflict persistence. Missing hardware families and raw-wave/fall processing are listed in Residual L0 Work.
- **L1: Partial.** Local SQLite and native bridging are operational, and L0 cloud outputs are now available as L1 inputs; no complete L1 cleaning/imputation/feature pipeline consumes them yet.
- **L2: No.** Static twin UI is [`home_page.dart`](../alloop-SDK/lib/features/main/home_page.dart:319) 319–390 and 651–706; no EnKF, state vector, forecast, or counterfactual producer exists.
- **L3: Partial research foundation.** The merged reasoning service implements deterministic robust baselines, trends, change points, multivariate anomaly signals, quality gates, and OOD rejection on contract/mock inputs. It has no real telemetry worker, deployed hosted output path, personal DAG, causal effect estimator, counterfactual engine, or N-of-1 runtime.
- **L4: Integrated deterministic demo.** River consumes fused L0 metrics and persists auditable tags; Matrix V2 consumes those tags plus server-derived consent/verified facts, persists immutable decisions/events/tasks, and feeds the Flutter Home UI. The path is not clinically validated and does not yet include online preference learning, automated scheduling, purchasing, booking, underwriting, or production content operations.
- **L5: Partial UI shell.** Chat, insurance, emergency, and family UI are placeholders; no robot agent, hospital/FHIR loop, insurance calculator, or elder/child workflow exists.

## Cloud Pair Bridge State

The original 43-table database audit covered 86 FK-related pairs. The merged
reasoning migration adds seven tables and new relationships, so 86 is no longer
the complete current relationship count. Its `insert_algorithm_output` adapter
bridges an in-memory `AlgorithmOutput` to `inference.algorithm_output`, but no
runtime supplies real observations or a database connection. The status below
retains the original audit and calls out the new disconnected bridge.

### Implemented after this integration

- `core.family_member` ↔ `telemetry.vital_readings`: **Yes, for normalized phone upload** through `public.sync_vital_reading`; app caller is `CloudMeasurementSyncService.syncPendingVitalReadings`.
- `core.devices` ↔ `telemetry.vital_readings`: **Yes**; the wrapper resolves or safely registers supported devices and validates member ownership.
- `core.family_member` ↔ `telemetry.l0_fused_metric`: **Yes** through `L0FusionEngine` and `public.sync_l0_fused_metric`.
- `telemetry.l0_fused_metric` ↔ `telemetry.signal_conflict`: **Yes, processing bridge without a direct FK**; real source divergence writes the fused ID and evidence JSON into the deduplicated conflict row.
- `core.family_member` ↔ `inference.algorithm_output`: **Partial/research only** through `vvewell_reasoning.persistence.insert_algorithm_output`; there is no scheduled or API-connected real-data caller.

### Schema-only or still unimplemented

The following pairs have no app-side processing bridge. `AUTH`, `VALIDATE`, and
`VIEW` are DB access/integrity/read features only; `FK` is referential wiring:

- Core: `families-users` (FK/AUTH); `families-family_member` (FK/AUTH/VIEW); `family_member-users` (FK/AUTH); `devices-family_member` (FK/AUTH); `families-member_permission` (FK/VALIDATE/AUTH); `member_permission-users` (FK/AUTH); `family_member-member_permission` (FK/VALIDATE/AUTH); `emergency_contact-family_member` (FK/AUTH); `emergency_contact-users` (FK/AUTH).
- Storage/ingest: `object_ref-family_member` (FK); `sync_batch-family_member` (FK); `sync_batch-devices` (FK); `sync_cursor-devices` (FK/AUTH); `sync_cursor-sync_batch` (FK).
- Telemetry: `vital_readings-object_ref` (FK); `feature_observation-family_member` (FK/VIEW); `feature_observation-devices` (FK); `feature_observation-object_ref` (FK); `ring_measurement_results-family_member` (FK); `ring_measurement_results-devices` (FK); `ring_measurement_results-object_ref` (FK); `ring_daily_log-family_member` (FK); `ring_daily_log-devices` (FK); `ring_daily_log-object_ref` (FK); `environment_reading-family_member` (FK); `environment_reading-devices` (FK); `environment_reading-object_ref` (FK); `device_status_sample-devices` (FK/AUTH, no transition updater). `signal_conflict-family_member` now has a real L0 detector/writer.
- Inference: `health_tag-family_member/model_version` now has the River producer and recommendation consumer. Recommendation catalog/decision/feedback and care task bridges are implemented. `health_state`, digital twin, recovery, personal baseline, attribution, experiments, and reasoning-trace pairs remain schema/research only.
- Medical/care: `medical_record_ocr-family_member` (FK/VIEW); `medical_record_ocr-object_ref`; `medical_record_ocr-users`; `clinical_entity-medical_record_ocr`; `clinical_entity-family_member`; `medication_plan-family_member`; `medication_plan-medical_record_ocr`; `medication_event-medication_plan`; `medication_event-family_member`; `medical_service_order-family_member`; `medical_service_order-health_event` plus reverse health-event order FK; `care_event-family_member`; `care_event-health_event`; `care_event_notification-care_event`; `care_event_notification-emergency_contact`; `reminder-family_member` (FK/VIEW). All lack producer/scheduler/router methods.
- Security: `consent-family_member`; `consent-users`; `emergency_access_grant-family_member` (FK/VALIDATE/AUTH); `emergency_access_grant-emergency_contact` (FK/VALIDATE/AUTH); `emergency_access_grant-care_event` (FK/VALIDATE); `access_audit_log-users/families/family_member` (FK/hash trigger, no producer); `data_export_job-users/family_member/object_ref`; `deletion_request-users/family_member/object_ref` (all remaining FK only).
- Insurance: `insurance_risk_profile-family_member`; `insurance_risk_profile-model_version`; `insurance_recommendation-families`; `insurance_recommendation-family_member`; `insurance_recommendation-insurance_product`; `insurance_recommendation-consent` (all FK only; no risk/recommendation engine).

Still missing between tables are sync-batch/cursor updates, telemetry-to-inference fan-out, OCR/entity
extraction, medication scheduling, event-to-care routing, notifications,
export/deletion workers, audit-event production, device-status updates, and
insurance risk-to-product recommendation.

## Verification

Verification completed on 2026-08-03 after the phone-side migration:

- The isolated PostgreSQL database applied all fourteen migrations twice and
  passed every ordered SQL test through `090_phone_analysis_sync_test.sql` plus
  the live SQL suite. Coverage includes owner/outsider RLS, replay, version and
  catalog rejection, context, decision/task/event lineage, and task updates.
- Hosted Supabase deployment applied `0013_phone_analysis_sync.sql`; fourteen
  checksums and 56 application tables were verified. The deployed migration
  checksum is `2729c4a5674ffe6485200fc079cef03b3da8f250b7c9598be9ff60fbc88ea072`.
- Hosted rollback-only tests exercised the phone context and bundle RPCs,
  public-key denial, user Auth/member RLS, and secret-key administrative access.
- River service tests passed: 15. Recommender tests passed: 22 suites / 149
  tests. The full Flutter suite passed all 45 tests, including health parity,
  all 13 Matrix intents and safety gates, the zero-network coordinator, local
  task behavior, UI, and the pre-existing app tests.
- Android production Kotlin and Android instrumentation source compiled with
  `:app:compileDebugKotlin :app:compileDebugAndroidTestKotlin`. No Android target
  or emulator image was available, so the migration instrumentation could not
  be executed on hardware in this environment.
- The debug APK built at `alloop-SDK/build/app/outputs/flutter-apk/app-debug.apk`
  with SHA-256 `8b0ab7e67fd404e6aaaf7f5d6e34b8c53abe9076cdada7ae4fe62a6359a9c31f`.
  It passed encrypted-bundle inspection, hosted Auth login and member RLS;
  plaintext bundle values and `.env` assets are absent.
- `flutter analyze` remains unavailable because its analysis server emits
  truncated JSON on this Unicode workspace path. Flutter tests and both Android
  compilation targets provide the compile checks used for this demo.
- Physical flight-mode, process-kill/restart, performance and SQLite-size checks
  remain manual device acceptance items; the durable schema/reopen path is
  implemented and its instrumentation source compiles.

## Analysis Trigger Update (2026-08-04)

- `0014_observatory_analysis_triggers.sql` is deployed. The authorized,
  replay-safe `run_observatory_analysis` RPC promotes available fused L0 rows
  into L1 feature observations, L2 descriptive health states and a health-risk
  twin snapshot, and L3 robust personal baselines/deviation events.
- The RPC intentionally creates no attribution edge, clinical diagnosis, L4
  recommendation, or L5 delivery record without a corresponding producer and
  evidence contract. Phone-produced health tags, decisions, and tasks continue
  to sync through `0013_phone_analysis_sync.sql` only on explicit user Sync.
- The web observatory exposes `Run analysis` for Local Docker and Supabase. The
  app runs local analysis invisibly after each real rPPG/BLE measurement block;
  bursty history imports settle for 750 ms and continuous streams are analyzed
  at least every five seconds. Explicit Sync uploads local artifacts and then
  invokes the same cloud promotion RPC.
- Verification passed with all seventeen migrations applied twice locally,
  SQL tests through `100_observatory_analysis_test.sql`, 90 Flutter tests, 9 web
  tests, production web build, local and hosted dashboard trigger tests, and
  the full hosted Supabase RLS/REST verifier. Supabase reports 56 application
  tables and all migration checksums present.
