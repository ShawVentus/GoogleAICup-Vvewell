BEGIN;

SELECT set_config('request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT public.ios_sync_profiles('[{
  "id":"profile-shared-id","name":"Owner A","relationship":"owner",
  "birth_year":1990,"gender":"other","height_cm":170,"weight_kg":65,
  "blood_type":"O","updated_at":1788940800
}]'::jsonb);

DO $$
DECLARE
  first_result jsonb;
  replay_result jsonb;
  conflict_result jsonb;
  rollback_result jsonb;
  first_sync_id text;
BEGIN
  first_result := public.ios_sync_health_readings(
    'batch-a-1', 'ios-device-a', '[{
      "id":"reading-shared-id","schema_version":1,"profile_id":"profile-shared-id",
      "metric_type":"heartRate","source":"phone","source_name":"iPhone rPPG",
      "timestamp":1788940800,"received_at":1788940801,"value":72,"unit":"bpm",
      "accuracy":1,"payload_type":null,"payload":null
    }]'::jsonb
  );
  replay_result := public.ios_sync_health_readings(
    'batch-a-2', 'ios-device-a', '[{
      "id":"reading-shared-id","schema_version":1,"profile_id":"profile-shared-id",
      "metric_type":"heartRate","source":"phone","source_name":"iPhone rPPG",
      "timestamp":1788940800,"received_at":1788940801,"value":72,"unit":"bpm",
      "accuracy":1,"payload_type":null,"payload":null
    }]'::jsonb
  );
  first_sync_id := first_result #>> '{results,0,sync_id}';
  PERFORM cloud_db_test.assert_true(first_result ->> 'accepted' = '1',
    'first iOS reading must be accepted');
  PERFORM cloud_db_test.assert_true(first_sync_id = replay_result #>> '{results,0,sync_id}',
    'replay under a new batch id must return the same sync id');

  conflict_result := public.ios_sync_health_readings(
    'batch-a-3', 'ios-device-a', '[{
      "id":"reading-shared-id","schema_version":1,"profile_id":"profile-shared-id",
      "metric_type":"heartRate","source":"phone","source_name":"iPhone rPPG",
      "timestamp":1788940800,"received_at":1788940801,"value":75,"unit":"bpm",
      "accuracy":1,"payload_type":null,"payload":null
    }]'::jsonb
  );
  PERFORM cloud_db_test.assert_true(conflict_result #>> '{results,0,reason}' = 'reading_id_conflict',
    'same reading id with different content must be rejected');

  rollback_result := public.ios_sync_health_readings(
    'batch-a-4', 'ios-device-a', '[{
      "id":"reading-negative-steps","schema_version":1,"profile_id":"profile-shared-id",
      "metric_type":"steps","source":"phone","source_name":"iPhone rPPG",
      "timestamp":1788940860,"received_at":1788940861,"value":-1,"unit":"steps",
      "accuracy":1,"payload_type":null,"payload":null
    }]'::jsonb
  );
  PERFORM cloud_db_test.assert_true(rollback_result ->> 'rejected' = '1',
    'projection failure must reject the item');
  PERFORM cloud_db_test.assert_true(NOT EXISTS (
    SELECT 1 FROM app_storage.ios_health_reading WHERE client_reading_id = 'reading-negative-steps'
  ), 'projection failure must roll back the raw insert');
END;
$$;

SELECT public.ios_sync_health_readings(
  'batch-a-5', 'ios-device-a', '[{
    "id":"reading-raw-only","schema_version":1,"profile_id":"profile-shared-id",
    "metric_type":"bloodGlucose","source":"unknown","source_name":"Imported",
    "timestamp":1788940920,"received_at":1788940921,"value":5.1,"unit":"mmol/L",
    "accuracy":1,"payload_type":null,"payload":null
  }]'::jsonb
);

SELECT cloud_db_test.assert_true(
  (public.ios_list_health_readings(1, 0) #>> '{count}')::integer = 2,
  'read list count must include both committed readings'
);
SELECT cloud_db_test.assert_true(
  public.ios_list_health_readings(1, 0) #>> '{readings,0,id}' = 'reading-raw-only',
  'readback must preserve the stable client reading id'
);
SELECT cloud_db_test.assert_true(
  public.ios_list_health_readings(1, 0) #>> '{readings,0,id}' <>
  public.ios_list_health_readings(1, 1) #>> '{readings,0,id}',
  'bounded pagination must not repeat rows'
);

RESET ROLE;
SELECT set_config('request.jwt.claims',
  '{"sub":"91000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT public.ios_sync_profiles('[{
  "id":"profile-shared-id","name":"Owner B","relationship":"owner",
  "birth_year":1985,"updated_at":1788940800
}]'::jsonb);
SELECT public.ios_sync_health_readings(
  'batch-b-1', 'ios-device-b', '[{
    "id":"reading-shared-id","schema_version":1,"profile_id":"profile-shared-id",
    "metric_type":"heartRate","source":"unknown","source_name":"Imported",
    "timestamp":1788940800,"received_at":1788940801,"value":80,"unit":"bpm",
    "accuracy":1,"payload_type":null,"payload":null
  }]'::jsonb
);

SELECT cloud_db_test.assert_true(
  (public.ios_list_health_readings(100, 0) #>> '{count}')::integer = 1,
  'accounts must only read their own iOS records'
);
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM app_storage.ios_health_reading WHERE client_reading_id = 'reading-shared-id') = 1,
  'RLS must hide another account row even when client ids match'
);

RESET ROLE;
ROLLBACK;
