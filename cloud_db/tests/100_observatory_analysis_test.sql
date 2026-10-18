BEGIN;

INSERT INTO core.users (id, auth_uid, username) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'a1100000-0000-0000-0000-000000000001', 'observatory-owner'),
  ('a1000000-0000-0000-0000-000000000002', 'a1100000-0000-0000-0000-000000000002', 'observatory-outsider');
INSERT INTO core.families (id, owner_user_id, name) VALUES
  ('a2000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'Observatory Family');
INSERT INTO core.family_member (
  id, family_id, member_user_id, role, display_name, relation, age_group
) VALUES (
  'a3000000-0000-0000-0000-000000000001',
  'a2000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'admin', 'Observatory Owner', 'self', 'adult'
);

INSERT INTO telemetry.l0_fused_metric (
  id, member_id, metric_type, window_start, window_end, status, value, unit,
  confidence, signal_quality, coverage_ratio, coverage_mask, quality_flag,
  conflict_flag, interval_lower, interval_upper, contributing_sources,
  age_group, algorithm_version, input_fingerprint, evidence
)
SELECT
  cloud_db_meta.deterministic_uuid('observatory-fixture-' || n::text),
  'a3000000-0000-0000-0000-000000000001', 'heart_rate',
  '2026-08-04 00:00:00+00'::timestamptz + n * interval '1 minute',
  '2026-08-04 00:01:00+00'::timestamptz + n * interval '1 minute',
  'AVAILABLE', CASE WHEN n = 12 THEN 110 ELSE 70 + (n % 3) END, 'bpm',
  .9, .9, .9, '{"alloop_ring":true}', 'good', false,
  CASE WHEN n = 12 THEN 108 ELSE 68 + (n % 3) END,
  CASE WHEN n = 12 THEN 112 ELSE 72 + (n % 3) END,
  ARRAY['alloop_ring'], 'adult', 'l0-adaptive-kalman-v1',
  lpad(to_hex(n), 64, '0'), '{}'
FROM generate_series(0, 12) n;

SELECT set_config('request.jwt.claims',
  '{"sub":"a1100000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  first_run jsonb;
  replay jsonb;
BEGIN
  first_run := public.run_observatory_analysis(
    'a3000000-0000-0000-0000-000000000001', '2026-08-04 00:30:00+00');
  replay := public.run_observatory_analysis(
    'a3000000-0000-0000-0000-000000000001', '2026-08-04 00:30:00+00');
  PERFORM cloud_db_test.assert_true(first_run ->> 'status' = 'COMPLETED',
    'observatory analysis must complete for fused input');
  PERFORM cloud_db_test.assert_true((first_run #>> '{inserted,features}')::integer = 13,
    'first analysis must promote every available fused row');
  PERFORM cloud_db_test.assert_true((replay #>> '{inserted,features}')::integer = 0,
    'analysis replay must not duplicate feature rows');
END;
$$;

SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM telemetry.feature_observation) = 13
  AND (SELECT count(*) FROM inference.health_state) = 13
  AND (SELECT count(*) FROM inference.digital_twin_snapshot) = 1
  AND (SELECT count(*) FROM inference.personal_baseline) = 1
  AND (SELECT count(*) FROM inference.health_event) = 1,
  'analysis must populate deterministic L1, L2, and descriptive L3 records');
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.attribution_edge) = 0,
  'descriptive analysis must not fabricate causal attribution');

RESET ROLE;
SELECT set_config('request.jwt.claims',
  '{"sub":"a1100000-0000-0000-000000000002","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.expect_sqlstate(
  $$SELECT public.run_observatory_analysis(
    'a3000000-0000-0000-0000-000000000001', clock_timestamp())$$,
  '42501', 'outsider must not trigger member analysis');
RESET ROLE;

ROLLBACK;
