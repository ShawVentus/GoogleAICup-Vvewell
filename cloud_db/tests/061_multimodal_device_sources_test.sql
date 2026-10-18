BEGIN;

INSERT INTO core.users (id, auth_uid, username)
VALUES ('10000000-0000-0000-0000-000000000061', '11000000-0000-0000-0000-000000000061', 'multimodal-owner');
INSERT INTO core.families (id, owner_user_id, name)
VALUES ('20000000-0000-0000-0000-000000000061', '10000000-0000-0000-0000-000000000061', 'Multimodal Family');
INSERT INTO core.family_member (id, family_id, member_user_id, role, display_name, relation, age_group)
VALUES (
  '30000000-0000-0000-0000-000000000061', '20000000-0000-0000-0000-000000000061',
  '10000000-0000-0000-0000-000000000061', 'admin', 'Multimodal Owner', 'self', 'adult'
);
INSERT INTO core.devices (id, member_id, device_id, name, type)
VALUES
  ('40000000-0000-0000-0000-000000000061', '30000000-0000-0000-0000-000000000061', 'ir-001', 'Infrared sensor', 'infrared_sensor'),
  ('40000000-0000-0000-0000-000000000062', '30000000-0000-0000-0000-000000000061', 'glasses-001', 'AI glasses', 'ai_glasses');

INSERT INTO ingest.sync_batch (member_id, device_id, source, client_batch_id, item_count)
VALUES
  ('30000000-0000-0000-0000-000000000061', '40000000-0000-0000-0000-000000000061', 'infrared_sensor', 'infrared-batch-001', 1),
  ('30000000-0000-0000-0000-000000000061', '40000000-0000-0000-0000-000000000062', 'ai_glasses', 'glasses-batch-001', 1);

INSERT INTO telemetry.vital_readings (
  member_id, device_id, source, recorded_at, signal_quality, confidence,
  coverage_ratio, raw_data, client_event_id
) VALUES
  ('30000000-0000-0000-0000-000000000061', '40000000-0000-0000-0000-000000000061', 'infrared_sensor',
   '2026-08-03 00:00:00+00', 0.80, 0.80, 0.80,
   '{"semantic_status":"pending_registration"}', 'infrared-event-001'),
  ('30000000-0000-0000-0000-000000000061', '40000000-0000-0000-0000-000000000062', 'ai_glasses',
   '2026-08-03 00:01:00+00', 0.80, 0.80, 0.80,
   '{"semantic_status":"pending_registration"}', 'glasses-event-001');

SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM telemetry.vital_readings WHERE source IN ('infrared_sensor', 'ai_glasses')) = 2,
  'WP2 registered infrared and smart-glasses provenance sources must be ingestible'
);

ROLLBACK;
