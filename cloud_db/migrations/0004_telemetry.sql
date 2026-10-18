BEGIN;

CREATE TABLE IF NOT EXISTS telemetry.vital_readings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  device_id uuid REFERENCES core.devices(id) ON DELETE SET NULL,
  source text NOT NULL CHECK (source IN ('aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar')),
  recorded_at timestamptz NOT NULL,
  heart_rate double precision,
  spo2 double precision,
  hrv double precision,
  respiratory_rate double precision,
  temperature double precision,
  stress double precision,
  steps integer CHECK (steps IS NULL OR steps >= 0),
  signal_quality numeric(6,5) CHECK (signal_quality IS NULL OR signal_quality BETWEEN 0 AND 1),
  confidence numeric(6,5) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
  coverage_ratio numeric(6,5) CHECK (coverage_ratio IS NULL OR coverage_ratio BETWEEN 0 AND 1),
  quality_flag text NOT NULL DEFAULT 'unknown' CHECK (quality_flag IN ('good', 'degraded', 'poor', 'unknown')),
  conflict_flag boolean NOT NULL DEFAULT false,
  age_group text CHECK (age_group IS NULL OR age_group IN ('child', 'adult', 'elder')),
  is_valid boolean NOT NULL DEFAULT true,
  is_abnormal boolean NOT NULL DEFAULT false,
  raw_object_id uuid REFERENCES app_storage.object_ref(id) ON DELETE SET NULL,
  raw_data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(raw_data) = 'object'),
  client_event_id text NOT NULL CHECK (length(client_event_id) BETWEEN 1 AND 128),
  ingested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, recorded_at),
  UNIQUE (member_id, source, recorded_at, client_event_id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE IF NOT EXISTS telemetry.vital_readings_default
  PARTITION OF telemetry.vital_readings DEFAULT;

CREATE TABLE IF NOT EXISTS telemetry.feature_observation (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  device_id uuid REFERENCES core.devices(id) ON DELETE SET NULL,
  metric_type text NOT NULL CHECK (length(btrim(metric_type)) BETWEEN 1 AND 100),
  value numeric NOT NULL,
  unit text NOT NULL CHECK (length(btrim(unit)) BETWEEN 1 AND 40),
  source text NOT NULL CHECK (length(btrim(source)) BETWEEN 1 AND 60),
  confidence numeric(6,5) CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
  coverage_ratio numeric(6,5) CHECK (coverage_ratio IS NULL OR coverage_ratio BETWEEN 0 AND 1),
  quality_flag text NOT NULL DEFAULT 'unknown' CHECK (quality_flag IN ('good', 'degraded', 'poor', 'unknown')),
  is_valid boolean NOT NULL DEFAULT true,
  is_abnormal boolean NOT NULL DEFAULT false,
  recorded_at timestamptz NOT NULL,
  raw_object_id uuid REFERENCES app_storage.object_ref(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  client_event_id text NOT NULL CHECK (length(client_event_id) BETWEEN 1 AND 128),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, recorded_at),
  UNIQUE (member_id, metric_type, source, recorded_at, client_event_id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE IF NOT EXISTS telemetry.feature_observation_default
  PARTITION OF telemetry.feature_observation DEFAULT;

CREATE TABLE IF NOT EXISTS telemetry.ring_measurement_results (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES core.devices(id) ON DELETE CASCADE,
  recorded_at timestamptz NOT NULL,
  sdk_heart_rate integer,
  sdk_spo2 integer,
  algorithm_heart_rate double precision,
  algorithm_spo2 double precision,
  algorithm_hrv_rmssd double precision,
  signal_quality numeric(6,5) NOT NULL CHECK (signal_quality BETWEEN 0 AND 1),
  valid boolean NOT NULL,
  raw_object_id uuid REFERENCES app_storage.object_ref(id) ON DELETE SET NULL,
  raw_data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(raw_data) = 'object'),
  client_event_id text NOT NULL CHECK (length(client_event_id) BETWEEN 1 AND 128),
  ingested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, recorded_at),
  UNIQUE (member_id, device_id, recorded_at, client_event_id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE IF NOT EXISTS telemetry.ring_measurement_results_default
  PARTITION OF telemetry.ring_measurement_results DEFAULT;

CREATE TABLE IF NOT EXISTS telemetry.ring_daily_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES core.devices(id) ON DELETE CASCADE,
  recorded_at timestamptz NOT NULL,
  log_type text NOT NULL CHECK (log_type IN ('sport', 'activity')),
  heart_rate integer,
  steps integer CHECK (steps IS NULL OR steps >= 0),
  activity_count integer CHECK (activity_count IS NULL OR activity_count >= 0),
  battery_percent integer CHECK (battery_percent IS NULL OR battery_percent BETWEEN 0 AND 100),
  active_seconds integer CHECK (active_seconds IS NULL OR active_seconds >= 0),
  temperatures_c jsonb,
  raw_object_id uuid REFERENCES app_storage.object_ref(id) ON DELETE SET NULL,
  raw_data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(raw_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, device_id, recorded_at, log_type),
  CHECK (temperatures_c IS NULL OR jsonb_typeof(temperatures_c) = 'array')
);

CREATE TABLE IF NOT EXISTS telemetry.environment_reading (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES core.devices(id) ON DELETE CASCADE,
  sensor_type text NOT NULL CHECK (sensor_type IN ('temperature', 'humidity', 'air_quality', 'light', 'presence', 'door')),
  metric_type text NOT NULL,
  value numeric NOT NULL,
  unit text NOT NULL,
  quality numeric(6,5) CHECK (quality IS NULL OR quality BETWEEN 0 AND 1),
  recorded_at timestamptz NOT NULL,
  raw_object_id uuid REFERENCES app_storage.object_ref(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  client_event_id text NOT NULL CHECK (length(client_event_id) BETWEEN 1 AND 128),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, recorded_at),
  UNIQUE (device_id, metric_type, recorded_at, client_event_id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE IF NOT EXISTS telemetry.environment_reading_default
  PARTITION OF telemetry.environment_reading DEFAULT;

CREATE TABLE IF NOT EXISTS telemetry.device_status_sample (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  device_id uuid NOT NULL REFERENCES core.devices(id) ON DELETE CASCADE,
  recorded_at timestamptz NOT NULL,
  connected boolean NOT NULL,
  battery_percent integer CHECK (battery_percent IS NULL OR battery_percent BETWEEN 0 AND 100),
  firmware_version text,
  wear_state text CHECK (wear_state IS NULL OR wear_state IN ('WORN_GOOD', 'WORN_POOR', 'CHARGING', 'OFF')),
  signal_quality numeric(6,5) CHECK (signal_quality IS NULL OR signal_quality BETWEEN 0 AND 1),
  upload_success_rate numeric(6,5) CHECK (upload_success_rate IS NULL OR upload_success_rate BETWEEN 0 AND 1),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE IF NOT EXISTS telemetry.device_status_sample_default
  PARTITION OF telemetry.device_status_sample DEFAULT;

CREATE TABLE IF NOT EXISTS telemetry.signal_conflict (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  metric_type text NOT NULL,
  recorded_at timestamptz NOT NULL,
  source_a text NOT NULL,
  source_b text NOT NULL,
  value_a numeric NOT NULL,
  value_b numeric NOT NULL,
  tolerance numeric NOT NULL CHECK (tolerance >= 0),
  quality_flag text NOT NULL CHECK (quality_flag IN ('degraded', 'poor', 'unknown')),
  resolution text NOT NULL DEFAULT 'pending' CHECK (resolution IN ('pending', 'source_a', 'source_b', 'interval', 'discarded')),
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (source_a <> source_b)
);

CREATE INDEX IF NOT EXISTS idx_vital_member_recorded ON telemetry.vital_readings(member_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_vital_member_source_recorded ON telemetry.vital_readings(member_id, source, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_vital_device_recorded ON telemetry.vital_readings(device_id, recorded_at DESC) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_vital_recorded_brin ON telemetry.vital_readings USING brin(recorded_at);
CREATE INDEX IF NOT EXISTS idx_feature_member_type_recorded ON telemetry.feature_observation(member_id, metric_type, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_feature_recorded_brin ON telemetry.feature_observation USING brin(recorded_at);
CREATE INDEX IF NOT EXISTS idx_ring_result_member_device_recorded ON telemetry.ring_measurement_results(member_id, device_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_ring_daily_member_device_recorded ON telemetry.ring_daily_log(member_id, device_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_environment_member_recorded ON telemetry.environment_reading(member_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_status_device_recorded ON telemetry.device_status_sample(device_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_signal_conflict_member_recorded ON telemetry.signal_conflict(member_id, recorded_at DESC);

CREATE OR REPLACE FUNCTION ingest.upsert_vital_reading(
  p_member_id uuid,
  p_device_id uuid,
  p_source text,
  p_recorded_at timestamptz,
  p_client_event_id text DEFAULT NULL,
  p_heart_rate double precision DEFAULT NULL,
  p_spo2 double precision DEFAULT NULL,
  p_hrv double precision DEFAULT NULL,
  p_respiratory_rate double precision DEFAULT NULL,
  p_temperature double precision DEFAULT NULL,
  p_stress double precision DEFAULT NULL,
  p_steps integer DEFAULT NULL,
  p_signal_quality numeric DEFAULT NULL,
  p_confidence numeric DEFAULT NULL,
  p_is_valid boolean DEFAULT true,
  p_is_abnormal boolean DEFAULT false,
  p_raw_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core, telemetry, app_storage, extensions
AS $$
DECLARE
  resolved_event_id text;
  result_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM core.devices d
    WHERE d.id = p_device_id AND d.member_id = p_member_id
  ) THEN
    RAISE EXCEPTION 'device does not belong to member' USING ERRCODE = '23503';
  END IF;

  resolved_event_id := coalesce(
    nullif(p_client_event_id, ''),
    encode(extensions.digest(
      concat_ws('|', p_member_id::text, p_device_id::text, p_source,
        p_recorded_at::text, coalesce(p_raw_data, '{}'::jsonb)::text),
      'sha256'
    ), 'hex')
  );

  INSERT INTO telemetry.vital_readings (
    member_id, device_id, source, recorded_at, client_event_id,
    heart_rate, spo2, hrv, respiratory_rate, temperature, stress, steps,
    signal_quality, confidence, is_valid, is_abnormal, raw_data
  ) VALUES (
    p_member_id, p_device_id, p_source, p_recorded_at, resolved_event_id,
    p_heart_rate, p_spo2, p_hrv, p_respiratory_rate, p_temperature, p_stress,
    p_steps, p_signal_quality, p_confidence, p_is_valid, p_is_abnormal,
    coalesce(p_raw_data, '{}'::jsonb)
  )
  ON CONFLICT (member_id, source, recorded_at, client_event_id) DO NOTHING
  RETURNING id INTO result_id;

  IF result_id IS NULL THEN
    SELECT id INTO result_id
    FROM telemetry.vital_readings
    WHERE member_id = p_member_id
      AND source = p_source
      AND recorded_at = p_recorded_at
      AND client_event_id = resolved_event_id;
  END IF;

  RETURN result_id;
END;
$$;

REVOKE ALL ON FUNCTION ingest.upsert_vital_reading(
  uuid, uuid, text, timestamptz, text, double precision, double precision,
  double precision, double precision, double precision, double precision,
  integer, numeric, numeric, boolean, boolean, jsonb
) FROM PUBLIC;

COMMIT;
