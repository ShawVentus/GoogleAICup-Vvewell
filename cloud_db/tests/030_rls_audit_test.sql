BEGIN;

INSERT INTO core.users (id, auth_uid, username)
VALUES
  ('10000000-0000-0000-0000-000000000011', '11000000-0000-0000-0000-000000000011', 'rls-owner'),
  ('10000000-0000-0000-0000-000000000012', '11000000-0000-0000-0000-000000000012', 'rls-outsider');
INSERT INTO core.families (id, owner_user_id, name)
VALUES ('20000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000011', 'RLS Family');
INSERT INTO core.family_member (id, family_id, member_user_id, role, display_name, relation, age_group)
VALUES ('30000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000011',
  '10000000-0000-0000-0000-000000000011', 'admin', 'RLS Owner', 'self', 'adult');
INSERT INTO core.devices (id, member_id, device_id, name, type)
VALUES ('40000000-0000-0000-0000-000000000011', '30000000-0000-0000-0000-000000000011',
  'rls-device', 'RLS Ring', 'alloop_ring');
INSERT INTO telemetry.vital_readings (
  member_id, device_id, source, recorded_at, heart_rate, client_event_id
) VALUES ('30000000-0000-0000-0000-000000000011', '40000000-0000-0000-0000-000000000011',
  'alloop_ring', '2026-08-03 01:00:00+00', 70, 'rls-reading');

SELECT set_config('request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000011","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM telemetry.vital_readings WHERE client_event_id = 'rls-reading') = 1,
  'family owner must read member telemetry'
);
RESET ROLE;

SELECT set_config('request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000012","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM telemetry.vital_readings WHERE client_event_id = 'rls-reading') = 0,
  'outsider must not read member telemetry'
);
SELECT cloud_db_test.expect_sqlstate(
  $$INSERT INTO telemetry.vital_readings
    (member_id, device_id, source, recorded_at, heart_rate, client_event_id)
    VALUES ('30000000-0000-0000-0000-000000000011',
      '40000000-0000-0000-0000-000000000011', 'alloop_ring',
      '2026-08-03 01:01:00+00', 71, 'forbidden-reading')$$,
  '42501', 'outsider must not insert member telemetry'
);
RESET ROLE;

INSERT INTO core.emergency_contact (
  id, member_id, contact_user_id, name, priority, channels
) VALUES (
  '60000000-0000-0000-0000-000000000011',
  '30000000-0000-0000-0000-000000000011',
  '10000000-0000-0000-0000-000000000012',
  'Emergency Contact', 1, ARRAY['app','sms','voice']
);
INSERT INTO care.care_event (
  id, member_id, event_type, trigger_source, severity, detected_at
) VALUES (
  '70000000-0000-0000-0000-000000000011',
  '30000000-0000-0000-0000-000000000011',
  'fall_confirmed', 'mmwave_radar', 'red', clock_timestamp()
);
INSERT INTO security.emergency_access_grant (
  member_id, contact_id, care_event_id, scope, reason, expires_at
) VALUES (
  '30000000-0000-0000-0000-000000000011',
  '60000000-0000-0000-0000-000000000011',
  '70000000-0000-0000-0000-000000000011',
  ARRAY['basic','alerts'], 'red fall event', clock_timestamp() + interval '30 minutes'
);

SELECT set_config('request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000012","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM telemetry.vital_readings WHERE client_event_id = 'rls-reading') = 1,
  'active emergency grant must permit scoped telemetry access'
);
RESET ROLE;

SELECT set_config('request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000011","role":"service_role"}', true);
INSERT INTO security.access_audit_log (
  id, actor_user_id, family_id, target_member_id, action,
  resource_type, resource_id, purpose
) VALUES
  ('80000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000011',
   '20000000-0000-0000-0000-000000000011', '30000000-0000-0000-0000-000000000011',
   'read', 'vital_reading', NULL, 'care'),
  ('80000000-0000-0000-0000-000000000012', '10000000-0000-0000-0000-000000000011',
   '20000000-0000-0000-0000-000000000011', '30000000-0000-0000-0000-000000000011',
   'read', 'health_event', NULL, 'care');

SELECT cloud_db_test.assert_true(
  (SELECT bool_and(length(entry_hash) = 64) FROM security.access_audit_log
    WHERE id IN ('80000000-0000-0000-0000-000000000011','80000000-0000-0000-0000-000000000012')),
  'audit entries must be SHA-256 chained'
);
SELECT cloud_db_test.assert_true(
  (SELECT second.prev_hash = first.entry_hash
   FROM security.access_audit_log first
   JOIN security.access_audit_log second ON second.id = '80000000-0000-0000-0000-000000000012'
   WHERE first.id = '80000000-0000-0000-0000-000000000011'),
  'second audit entry must reference the first hash'
);
SELECT cloud_db_test.expect_sqlstate(
  $$UPDATE security.access_audit_log SET purpose = 'tampered'
    WHERE id = '80000000-0000-0000-0000-000000000011'$$,
  '55000', 'audit log updates must be rejected'
);

ROLLBACK;
