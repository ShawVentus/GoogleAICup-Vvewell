BEGIN;

INSERT INTO core.users (id, auth_uid, username, display_name)
VALUES
  ('10000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', 'phone-owner', 'Phone Owner'),
  ('10000000-0000-0000-0000-000000000002', '11000000-0000-0000-0000-000000000002', 'phone-other', 'Phone Other');

INSERT INTO core.families (id, owner_user_id, name)
VALUES ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Phone Family');

INSERT INTO core.family_member (
  id, family_id, member_user_id, role, display_name, relation, age_group
) VALUES (
  '30000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'admin', 'Owner', 'self', 'adult'
);

INSERT INTO core.devices (
  id, member_id, device_id, name, type, firmware_version, battery_percent, connected
) VALUES (
  '40000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'ring-phone-001', 'Alloop Ring', 'alloop_ring', '2.2.4', 85, true
);

SELECT cloud_db_test.expect_sqlstate(
  $$INSERT INTO core.devices (member_id, device_id, name, type, battery_percent)
    VALUES ('30000000-0000-0000-0000-000000000001', 'bad-battery', 'Bad', 'alloop_ring', 101)$$,
  '23514', 'battery percentage above 100 must fail'
);

INSERT INTO ingest.sync_batch (
  id, member_id, device_id, source, client_batch_id, item_count
) VALUES (
  '50000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  'alloop_ring', 'phone-batch-001', 3
);

INSERT INTO ingest.sync_cursor (device_id, source, last_batch_id)
VALUES (
  '40000000-0000-0000-0000-000000000001', 'alloop_ring',
  '50000000-0000-0000-0000-000000000001'
);

DO $$
DECLARE
  first_id uuid;
  replay_id uuid;
  reading_count integer;
BEGIN
  first_id := ingest.upsert_vital_reading(
    '30000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    'alloop_ring', '2026-08-03 00:00:00+00', 'phone-event-001',
    72, 98, 42, 15, 32.1, 0.2, 1200, 0.9, 0.95, true, false,
    '{"sdk":"2.2.4"}'::jsonb
  );
  replay_id := ingest.upsert_vital_reading(
    '30000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    'alloop_ring', '2026-08-03 00:00:00+00', 'phone-event-001',
    72, 98, 42, 15, 32.1, 0.2, 1200, 0.9, 0.95, true, false,
    '{"sdk":"2.2.4"}'::jsonb
  );
  SELECT count(*) INTO reading_count
  FROM telemetry.vital_readings
  WHERE client_event_id = 'phone-event-001';
  PERFORM cloud_db_test.assert_true(first_id = replay_id, 'replay must return the original reading id');
  PERFORM cloud_db_test.assert_true(reading_count = 1, 'replay must not create a duplicate reading');
END;
$$;

-- The phone-facing wrapper must work for an authenticated owner and remain
-- idempotent without exposing the service-role key to the client.
SELECT set_config('request.jwt.claims',
  '{"sub":"11000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
  first_id uuid;
  replay_id uuid;
BEGIN
  first_id := public.sync_vital_reading(
    '30000000-0000-0000-0000-000000000001', 'ring-phone-001',
    'alloop_ring', '2026-08-03 00:02:00+00', 'phone-wrapper-001',
    73, 98, 43, 15, 32.1, 0.2, 1201, 0.9, 0.95, true, false,
    '{"source":"phone_wrapper"}'::jsonb
  );
  replay_id := public.sync_vital_reading(
    '30000000-0000-0000-0000-000000000001', 'ring-phone-001',
    'alloop_ring', '2026-08-03 00:02:00+00', 'phone-wrapper-001',
    73, 98, 43, 15, 32.1, 0.2, 1201, 0.9, 0.95, true, false,
    '{"source":"phone_wrapper"}'::jsonb
  );
  PERFORM cloud_db_test.assert_true(first_id = replay_id,
    'authenticated phone wrapper must be idempotent');
END;
$$;
RESET ROLE;

INSERT INTO telemetry.ring_measurement_results (
  member_id, device_id, recorded_at, sdk_heart_rate, sdk_spo2,
  algorithm_heart_rate, algorithm_spo2, algorithm_hrv_rmssd,
  signal_quality, valid, client_event_id
) VALUES (
  '30000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  '2026-08-03 00:01:00+00', 71, 98, 72.1, 98.2, 41.5, 0.92, true,
  'ring-result-001'
);

INSERT INTO telemetry.ring_daily_log (
  member_id, device_id, recorded_at, log_type, heart_rate, steps,
  activity_count, battery_percent, active_seconds, temperatures_c
) VALUES (
  '30000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  '2026-08-03 00:00:00+00', 'activity', 72, 8000, 34, 80, 3600,
  '[32.0,32.1]'::jsonb
);

INSERT INTO telemetry.feature_observation (
  member_id, device_id, metric_type, value, unit, source, confidence,
  coverage_ratio, quality_flag, recorded_at, client_event_id
) VALUES (
  '30000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  'heart_rate', 72, 'bpm', 'alloop_ring', 0.95, 1, 'good',
  '2026-08-03 00:00:00+00', 'metric-001'
);

SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM public.vvewell_health_metric WHERE metric_type = 'heart_rate') = 1,
  'health_metric compatibility view must expose feature observations'
);

ROLLBACK;
