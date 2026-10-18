BEGIN;

INSERT INTO core.users (id, auth_uid, username)
VALUES ('10000000-0000-0000-0000-000000000031', '11000000-0000-0000-0000-000000000031', 'plan-owner');
INSERT INTO core.families (id, owner_user_id, name)
VALUES ('20000000-0000-0000-0000-000000000031', '10000000-0000-0000-0000-000000000031', 'Plan Family');
INSERT INTO core.family_member (id, family_id, member_user_id, role, display_name, relation, age_group)
VALUES ('30000000-0000-0000-0000-000000000031', '20000000-0000-0000-0000-000000000031',
  '10000000-0000-0000-0000-000000000031', 'admin', 'Plan Owner', 'self', 'adult');
INSERT INTO core.devices (id, member_id, device_id, name, type)
VALUES ('40000000-0000-0000-0000-000000000031', '30000000-0000-0000-0000-000000000031',
  'plan-ring', 'Plan Ring', 'alloop_ring');

INSERT INTO telemetry.vital_readings (
  member_id, device_id, source, recorded_at, heart_rate, client_event_id
)
SELECT
  '30000000-0000-0000-0000-000000000031',
  '40000000-0000-0000-0000-000000000031',
  'alloop_ring',
  '2026-08-03 00:00:00+00'::timestamptz + make_interval(mins => n),
  60 + (n % 30),
  'plan-' || n
FROM generate_series(1, 300) AS n;

SET LOCAL enable_seqscan = off;

DO $$
DECLARE
  plan_text text;
BEGIN
  EXECUTE $query$
    EXPLAIN (FORMAT JSON)
    SELECT recorded_at, heart_rate
    FROM telemetry.vital_readings
    WHERE member_id = '30000000-0000-0000-0000-000000000031'
      AND recorded_at >= '2026-08-03 01:00:00+00'
      AND recorded_at < '2026-08-03 03:00:00+00'
    ORDER BY recorded_at DESC
  $query$ INTO plan_text;
  PERFORM cloud_db_test.assert_true(
    plan_text LIKE '%Index Scan%' OR plan_text LIKE '%Bitmap Index Scan%',
    'member/time query must use an index-backed plan'
  );
END;
$$;

ROLLBACK;
