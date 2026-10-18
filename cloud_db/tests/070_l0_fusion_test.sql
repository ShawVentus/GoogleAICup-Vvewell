BEGIN;

INSERT INTO core.users (id, auth_uid, username)
VALUES
  ('71000000-0000-0000-0000-000000000001', '71100000-0000-0000-0000-000000000001', 'l0-owner'),
  ('71000000-0000-0000-0000-000000000002', '71100000-0000-0000-0000-000000000002', 'l0-outsider');
INSERT INTO core.families (id, owner_user_id, name)
VALUES ('72000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'L0 Family');
INSERT INTO core.family_member (
  id, family_id, member_user_id, role, display_name, relation, age_group
) VALUES (
  '73000000-0000-0000-0000-000000000001',
  '72000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  'admin', 'L0 Owner', 'self', 'adult'
);

SELECT set_config('request.jwt.claims',
  '{"sub":"71100000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  reading_id uuid;
  first_fused_id uuid;
  replay_fused_id uuid;
  conflict_id uuid;
BEGIN
  PERFORM cloud_db_test.assert_true(
    public.get_l0_age_group('73000000-0000-0000-0000-000000000001') = 'adult',
    'L0 processing must resolve the member age group');
  reading_id := public.sync_vital_reading(
    '73000000-0000-0000-0000-000000000001', 'phone-camera-auto',
    'rppg_phone', '2026-08-03 05:00:10+00', 'l0-reading-1',
    72, NULL, NULL, 15, NULL, NULL, NULL, 0.82, 0.80, true, false,
    '{"session":"real"}'::jsonb, 1, 'good', NULL, 120, 0.02
  );
  PERFORM cloud_db_test.assert_true(reading_id IS NOT NULL,
    'L0 observation sync must return an id');
  PERFORM cloud_db_test.assert_true(
    (SELECT count(*) FROM core.devices
      WHERE member_id = '73000000-0000-0000-0000-000000000001'
        AND device_id = 'phone-camera-auto' AND type = 'rppg_phone') = 1,
    'allowed L0 source must auto-register its device');
  PERFORM cloud_db_test.assert_true(
    (SELECT coverage_ratio = 1 AND quality_flag = 'good'
      AND clock_offset_ms = 120 AND packet_loss_ratio = 0.02
      FROM telemetry.vital_readings WHERE id = reading_id),
    'observation trust metadata must be preserved');

  first_fused_id := public.sync_l0_fused_metric(
    '73000000-0000-0000-0000-000000000001', 'heart_rate',
    '2026-08-03 05:00:00+00', '2026-08-03 05:01:00+00',
    'AVAILABLE', 72.2, 'bpm', 0.84, 0.82, 1,
    '{"rppg_phone":true}'::jsonb, 'good', false, 69.5, 74.9,
    ARRAY['rppg_phone'], NULL, NULL, 'l0-adaptive-kalman-v1',
    repeat('a', 64), '{"policy":"heart_rate"}'::jsonb
  );
  replay_fused_id := public.sync_l0_fused_metric(
    '73000000-0000-0000-0000-000000000001', 'heart_rate',
    '2026-08-03 05:00:00+00', '2026-08-03 05:01:00+00',
    'AVAILABLE', 72.2, 'bpm', 0.84, 0.82, 1,
    '{"rppg_phone":true}'::jsonb, 'good', false, 69.5, 74.9,
    ARRAY['rppg_phone'], NULL, NULL, 'l0-adaptive-kalman-v1',
    repeat('a', 64), '{"policy":"heart_rate"}'::jsonb
  );
  PERFORM cloud_db_test.assert_true(first_fused_id = replay_fused_id,
    'fused metric replay must be idempotent');

  conflict_id := public.sync_l0_fused_metric(
    '73000000-0000-0000-0000-000000000001', 'heart_rate',
    '2026-08-03 05:01:00+00', '2026-08-03 05:02:00+00',
    'INTERVAL', NULL, 'bpm', 0.55, 0.70, 1,
    '{"alloop_ring":true,"mmwave_radar":true}'::jsonb, 'degraded', true,
    65, 92, ARRAY['alloop_ring','mmwave_radar'], 'WORN_GOOD',
    'SOURCE_CONFLICT', 'l0-adaptive-kalman-v1', repeat('b', 64),
    '{"resolution":"interval"}'::jsonb,
    'alloop_ring', 'mmwave_radar', 65, 92, 10
  );
  PERFORM cloud_db_test.assert_true(conflict_id IS NOT NULL,
    'conflict output must persist');
  PERFORM cloud_db_test.assert_true(
    (SELECT count(*) FROM telemetry.signal_conflict
      WHERE member_id = '73000000-0000-0000-0000-000000000001') = 1,
    'conflict evidence must persist exactly once');
  PERFORM public.sync_l0_fused_metric(
    '73000000-0000-0000-0000-000000000001', 'heart_rate',
    '2026-08-03 05:02:00+00', '2026-08-03 05:03:00+00',
    'ABSTAINED', NULL, 'bpm', 0, 0, 0,
    '{"rppg_phone":false}'::jsonb, 'poor', false, NULL, NULL,
    ARRAY[]::text[], NULL, 'INSUFFICIENT_COVERAGE',
    'l0-adaptive-kalman-v1', repeat('c', 64),
    '{"interpolationUsed":false}'::jsonb
  );
  PERFORM cloud_db_test.assert_true(
    (SELECT count(*) FROM telemetry.l0_fused_metric
      WHERE status = 'ABSTAINED' AND cardinality(contributing_sources) = 0) = 1,
    'a missing-data window must persist without invented contributors');
END;
$$;

RESET ROLE;
SELECT set_config('request.jwt.claims',
  '{"sub":"71100000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.expect_sqlstate(
  $$SELECT public.get_l0_age_group(
    '73000000-0000-0000-0000-000000000001'
  )$$,
  '42501', 'outsider must not read L0 member context'
);
SELECT cloud_db_test.expect_sqlstate(
  $$SELECT public.sync_l0_fused_metric(
    '73000000-0000-0000-0000-000000000001', 'heart_rate',
    '2026-08-03 05:02:00+00', '2026-08-03 05:03:00+00',
    'ABSTAINED', NULL, 'bpm', 0, 0.2, 0.2,
    '{"rppg_phone":false}'::jsonb, 'poor', false, NULL, NULL,
    ARRAY['rppg_phone'], NULL, 'INSUFFICIENT_COVERAGE',
    'l0-adaptive-kalman-v1', repeat('d', 64), '{}'::jsonb
  )$$,
  '42501', 'outsider must not write fused L0 output'
);
RESET ROLE;

ROLLBACK;
