BEGIN;

DO $$
DECLARE
  application_tables integer;
  protected_tables integer;
  partition_parents integer;
BEGIN
  SELECT count(*) INTO application_tables
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('core','ingest','telemetry','app_storage','inference','medical','insurance','care','security')
    AND c.relkind IN ('r','p') AND NOT c.relispartition;
  IF application_tables <> 61 THEN
    RAISE EXCEPTION 'expected 61 application tables, found %', application_tables;
  END IF;

  SELECT count(*) INTO protected_tables
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('core','ingest','telemetry','app_storage','inference','medical','insurance','care','security')
    AND c.relkind IN ('r','p') AND NOT c.relispartition
    AND c.relrowsecurity AND c.relforcerowsecurity;
  IF protected_tables <> 61 THEN
    RAISE EXCEPTION 'expected forced RLS on 61 tables, found %', protected_tables;
  END IF;

  SELECT count(*) INTO partition_parents
  FROM pg_partitioned_table pt
  JOIN pg_class c ON c.oid = pt.partrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('telemetry','inference','security');
  IF partition_parents <> 8 THEN
    RAISE EXCEPTION 'expected 8 partition parents, found %', partition_parents;
  END IF;
END;
$$;

CREATE TEMP TABLE live_ids AS
SELECT
  gen_random_uuid() AS owner_id,
  gen_random_uuid() AS outsider_id,
  gen_random_uuid() AS family_id,
  gen_random_uuid() AS member_id,
  gen_random_uuid() AS device_id,
  replace(gen_random_uuid()::text, '-', '') AS suffix;
GRANT SELECT ON live_ids TO authenticated;

INSERT INTO core.users (id, auth_uid, username)
SELECT owner_id, gen_random_uuid(), 'cloud-live-owner-' || suffix FROM live_ids
UNION ALL
SELECT outsider_id, gen_random_uuid(), 'cloud-live-outsider-' || suffix FROM live_ids;

INSERT INTO core.families (id, owner_user_id, name)
SELECT family_id, owner_id, 'Cloud DB Live Test' FROM live_ids;

INSERT INTO core.family_member (
  id, family_id, member_user_id, role, display_name, relation, age_group
)
SELECT member_id, family_id, owner_id, 'admin', 'Live Test', 'self', 'adult'
FROM live_ids;

INSERT INTO core.devices (id, member_id, device_id, name, type)
SELECT device_id, member_id, 'live-' || suffix, 'Live Test Ring', 'alloop_ring'
FROM live_ids;

DO $$
DECLARE
  fixture record;
  first_id uuid;
  replay_id uuid;
  reading_at timestamptz;
BEGIN
  SELECT * INTO fixture FROM live_ids;
  first_id := ingest.upsert_vital_reading(
    fixture.member_id, fixture.device_id, 'alloop_ring', clock_timestamp(),
    'live-event-' || fixture.suffix, 72, 98, 40, 15, 32, 0.2, 100,
    0.9, 0.95, true, false, '{"live_test":true}'::jsonb
  );
  SELECT recorded_at INTO STRICT reading_at
  FROM telemetry.vital_readings WHERE id = first_id;
  replay_id := ingest.upsert_vital_reading(
    fixture.member_id, fixture.device_id, 'alloop_ring', reading_at,
    'live-event-' || fixture.suffix, 72, 98, 40, 15, 32, 0.2, 100,
    0.9, 0.95, true, false, '{"live_test":true}'::jsonb
  );
  IF first_id IS DISTINCT FROM replay_id THEN
    RAISE EXCEPTION 'live idempotency test failed';
  END IF;
END;
$$;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('sub', owner_id, 'role', 'authenticated')::text, true)
FROM live_ids;
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  fixture record;
  phone_reading_id uuid;
  fused_id uuid;
  phone_run_id uuid := gen_random_uuid();
  phone_context jsonb;
  bundle_result jsonb;
  fused_at timestamptz := date_trunc('minute', clock_timestamp());
BEGIN
  SELECT * INTO fixture FROM live_ids;
  IF (SELECT count(*) FROM telemetry.vital_readings) <> 1 THEN
    RAISE EXCEPTION 'owner RLS read test failed';
  END IF;
  phone_reading_id := public.sync_vital_reading(
    fixture.member_id, 'live-' || fixture.suffix, 'alloop_ring',
    clock_timestamp(), 'live-phone-' || fixture.suffix,
    73, 98, 41, 15, 32, 0.2, 101, 0.91, 0.94, true, false,
    '{"live_phone_test":true}'::jsonb
  );
  IF phone_reading_id IS NULL OR
      (SELECT count(*) FROM telemetry.vital_readings) <> 2 THEN
    RAISE EXCEPTION 'authenticated phone RPC test failed';
  END IF;
  IF public.get_l0_age_group(fixture.member_id) <> 'adult' THEN
    RAISE EXCEPTION 'authenticated L0 age context test failed';
  END IF;
  fused_id := public.sync_l0_fused_metric(
    fixture.member_id, 'heart_rate', fused_at, fused_at + interval '1 minute',
    'AVAILABLE', 72.5, 'bpm', 0.9, 0.9, 1,
    '{"alloop_ring":true}'::jsonb, 'good', false, 70, 75,
    ARRAY['alloop_ring'], 'WORN_GOOD', NULL, 'live-l0-v1', repeat('d', 64),
    '{"live_test":true}'::jsonb
  );
  IF fused_id IS NULL OR
      (SELECT count(*) FROM telemetry.l0_fused_metric) <> 1 THEN
    RAISE EXCEPTION 'authenticated L0 fused RPC test failed';
  END IF;
  phone_context := public.get_phone_analysis_context(fixture.member_id, clock_timestamp());
  IF NOT phone_context ?& ARRAY['context_version','expires_at','catalog_items'] THEN
    RAISE EXCEPTION 'authenticated phone context RPC test failed';
  END IF;
  bundle_result := public.sync_phone_analysis_bundle(
    fixture.member_id,
    jsonb_build_object('items', jsonb_build_array(jsonb_build_object(
      'outbox_id', 1, 'entity_type', 'ANALYSIS_RUN', 'local_id', phone_run_id,
      'payload_hash', repeat('e', 64), 'payload', jsonb_build_object(
        'analysis_id', phone_run_id, 'member_id', fixture.member_id,
        'as_of', clock_timestamp(), 'input_count', 0, 'accepted_count', 0,
        'model_version', 'river-health-stream-dart-v1',
        'policy_version', 'health-tag-policy-v1',
        'input_fingerprint', repeat('f', 64), 'tags', '[]'::jsonb,
        'data_origin', 'REAL'
      )
    )))
  );
  IF bundle_result ->> 'count' <> '1'
     OR bundle_result #>> '{acks,0,status}' <> 'VALID'
     OR NOT EXISTS (SELECT 1 FROM inference.phone_analysis_run WHERE id = phone_run_id) THEN
    RAISE EXCEPTION 'authenticated phone bundle RPC test failed';
  END IF;
END;
$$;
RESET ROLE;

SELECT set_config('request.jwt.claims',
  jsonb_build_object('sub', outsider_id, 'role', 'authenticated')::text, true)
FROM live_ids;
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  IF (SELECT count(*) FROM telemetry.vital_readings) <> 0 THEN
    RAISE EXCEPTION 'outsider RLS denial test failed';
  END IF;
  IF (SELECT count(*) FROM telemetry.l0_fused_metric) <> 0 THEN
    RAISE EXCEPTION 'outsider fused-output RLS denial test failed';
  END IF;
END;
$$;
RESET ROLE;

DO $$
DECLARE
  fixture record;
  audit_id uuid := gen_random_uuid();
BEGIN
  SELECT * INTO fixture FROM live_ids;
  PERFORM set_config('request.jwt.claims',
    jsonb_build_object('sub', fixture.owner_id, 'role', 'service_role')::text, true);
  INSERT INTO security.access_audit_log (
    id, actor_user_id, family_id, target_member_id, action, resource_type, purpose
  ) VALUES (
    audit_id, fixture.owner_id, fixture.family_id, fixture.member_id,
    'read', 'vital_reading', 'live_test'
  );
  IF (SELECT length(entry_hash) FROM security.access_audit_log WHERE id = audit_id) <> 64 THEN
    RAISE EXCEPTION 'audit hash test failed';
  END IF;
  BEGIN
    UPDATE security.access_audit_log SET purpose = 'tampered' WHERE id = audit_id;
    RAISE EXCEPTION 'audit mutation unexpectedly succeeded';
  EXCEPTION
    WHEN SQLSTATE '55000' THEN NULL;
  END;
END;
$$;

ROLLBACK;
