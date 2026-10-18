BEGIN;

-- WP2 source expansion.  Existing migrations remain immutable: this migration
-- only broadens registered device/source vocabularies for the five-device
-- collection topology (ring, mmWave, infrared, rPPG and smart glasses).
ALTER TABLE core.devices
  DROP CONSTRAINT IF EXISTS devices_type_check;
ALTER TABLE core.devices
  ADD CONSTRAINT devices_type_check CHECK (type IN (
    'aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar',
    'infrared_camera', 'infrared_sensor', 'ai_glasses',
    'blood_pressure_monitor', 'glucose_meter', 'body_scale',
    'emergency_button', 'door_sensor', 'environment_sensor',
    'smart_pillbox', 'smart_mattress'
  ));

ALTER TABLE ingest.sync_batch
  DROP CONSTRAINT IF EXISTS sync_batch_source_check;
ALTER TABLE ingest.sync_batch
  ADD CONSTRAINT sync_batch_source_check CHECK (source IN (
    'aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar',
    'infrared_sensor', 'ai_glasses'
  ));

ALTER TABLE ingest.sync_cursor
  DROP CONSTRAINT IF EXISTS sync_cursor_source_check;
ALTER TABLE ingest.sync_cursor
  ADD CONSTRAINT sync_cursor_source_check CHECK (source IN (
    'aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar',
    'infrared_sensor', 'ai_glasses'
  ));

ALTER TABLE telemetry.vital_readings
  DROP CONSTRAINT IF EXISTS vital_readings_source_check;
ALTER TABLE telemetry.vital_readings
  ADD CONSTRAINT vital_readings_source_check CHECK (source IN (
    'aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar',
    'infrared_sensor', 'ai_glasses'
  ));

COMMENT ON CONSTRAINT vital_readings_source_check ON telemetry.vital_readings IS
  'Source identity is not a metric claim. Infrared and smart-glasses readings require registered device-specific semantics, SQI and provenance before WP2 reasoning can use them.';

COMMIT;
