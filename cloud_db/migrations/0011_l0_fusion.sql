BEGIN;

ALTER TABLE telemetry.vital_readings
  ADD COLUMN IF NOT EXISTS wear_state text
    CHECK (wear_state IS NULL OR wear_state IN ('WORN_GOOD', 'WORN_POOR', 'CHARGING', 'OFF')),
  ADD COLUMN IF NOT EXISTS clock_offset_ms numeric,
  ADD COLUMN IF NOT EXISTS packet_loss_ratio numeric(6,5)
    CHECK (packet_loss_ratio IS NULL OR packet_loss_ratio BETWEEN 0 AND 1);

CREATE TABLE IF NOT EXISTS telemetry.l0_fused_metric (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  metric_type text NOT NULL CHECK (length(btrim(metric_type)) BETWEEN 1 AND 100),
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('AVAILABLE', 'INTERVAL', 'ABSTAINED')),
  value numeric,
  unit text NOT NULL CHECK (length(btrim(unit)) BETWEEN 1 AND 40),
  confidence numeric(6,5) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  signal_quality numeric(6,5) NOT NULL CHECK (signal_quality BETWEEN 0 AND 1),
  coverage_ratio numeric(6,5) NOT NULL CHECK (coverage_ratio BETWEEN 0 AND 1),
  coverage_mask jsonb NOT NULL CHECK (jsonb_typeof(coverage_mask) = 'object'),
  quality_flag text NOT NULL CHECK (quality_flag IN ('good', 'degraded', 'poor')),
  conflict_flag boolean NOT NULL DEFAULT false,
  interval_lower numeric,
  interval_upper numeric,
  contributing_sources text[] NOT NULL,
  wear_state text CHECK (wear_state IS NULL OR wear_state IN ('WORN_GOOD', 'WORN_POOR', 'CHARGING', 'OFF')),
  age_group text NOT NULL CHECK (age_group IN ('child', 'adult', 'elder')),
  abstain_reason text CHECK (abstain_reason IS NULL OR abstain_reason IN (
    'INSUFFICIENT_COVERAGE', 'LOW_SQI', 'NOT_WORN', 'SOURCE_CONFLICT'
  )),
  algorithm_version text NOT NULL CHECK (length(btrim(algorithm_version)) BETWEEN 1 AND 80),
  input_fingerprint text NOT NULL CHECK (input_fingerprint ~ '^[0-9a-f]{64}$'),
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, metric_type, window_start, algorithm_version, input_fingerprint),
  CHECK (window_end > window_start),
  CHECK (status = 'ABSTAINED' OR cardinality(contributing_sources) > 0),
  CHECK (interval_lower IS NULL OR interval_upper IS NULL OR interval_upper >= interval_lower),
  CHECK (
    (status = 'AVAILABLE' AND value IS NOT NULL AND interval_lower IS NOT NULL
      AND interval_upper IS NOT NULL AND abstain_reason IS NULL)
    OR
    (status = 'INTERVAL' AND value IS NULL AND interval_lower IS NOT NULL
      AND interval_upper IS NOT NULL AND conflict_flag AND abstain_reason = 'SOURCE_CONFLICT')
    OR
    (status = 'ABSTAINED' AND value IS NULL AND interval_lower IS NULL
      AND interval_upper IS NULL AND abstain_reason IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_l0_fused_member_metric_window
  ON telemetry.l0_fused_metric(member_id, metric_type, window_start DESC);
CREATE INDEX IF NOT EXISTS idx_l0_fused_quality
  ON telemetry.l0_fused_metric(member_id, quality_flag, window_start DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_signal_conflict_l0_pair
  ON telemetry.signal_conflict (
    member_id, metric_type, recorded_at,
    least(source_a, source_b), greatest(source_a, source_b)
  );

CREATE OR REPLACE FUNCTION cloud_db_meta.device_type_for_source(p_source text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE btrim(p_source)
    WHEN 'aizo_ring' THEN 'aizo_ring'
    WHEN 'alloop_ring' THEN 'alloop_ring'
    WHEN 'rppg_phone' THEN 'rppg_phone'
    WHEN 'mmwave_radar' THEN 'mmwave_radar'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.resolve_or_create_device(
  p_member_id uuid,
  p_device_identifier text,
  p_source text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta
AS $$
DECLARE
  resolved_id uuid;
  resolved_type text;
  expected_type text := cloud_db_meta.device_type_for_source(p_source);
BEGIN
  IF NOT cloud_db_meta.can_access_member(p_member_id, 'write') THEN
    RAISE EXCEPTION 'authenticated user cannot write this member' USING ERRCODE = '42501';
  END IF;
  IF expected_type IS NULL OR nullif(btrim(p_device_identifier), '') IS NULL THEN
    RAISE EXCEPTION 'unsupported L0 source or empty device identifier' USING ERRCODE = '22023';
  END IF;

  SELECT id, type INTO resolved_id, resolved_type
  FROM core.devices
  WHERE member_id = p_member_id AND device_id = btrim(p_device_identifier)
  LIMIT 1;

  IF resolved_id IS NOT NULL AND resolved_type <> expected_type THEN
    RAISE EXCEPTION 'device type does not match source' USING ERRCODE = '23514';
  END IF;
  IF resolved_id IS NOT NULL THEN
    RETURN resolved_id;
  END IF;

  INSERT INTO core.devices (member_id, device_id, name, type, connected, metadata)
  VALUES (
    p_member_id,
    btrim(p_device_identifier),
    'Auto-registered ' || replace(expected_type, '_', ' '),
    expected_type,
    true,
    jsonb_build_object('registered_by', 'l0_phone_sync')
  )
  ON CONFLICT (member_id, device_id) DO UPDATE
    SET updated_at = clock_timestamp()
  RETURNING id INTO resolved_id;

  RETURN resolved_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_l0_age_group(p_member_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta
AS $$
DECLARE
  resolved_age_group text;
BEGIN
  IF NOT cloud_db_meta.can_access_member(p_member_id, 'basic') THEN
    RAISE EXCEPTION 'authenticated user cannot read this member' USING ERRCODE = '42501';
  END IF;
  SELECT age_group INTO STRICT resolved_age_group
  FROM core.family_member WHERE id = p_member_id;
  RETURN resolved_age_group;
END;
$$;

REVOKE ALL ON FUNCTION public.get_l0_age_group(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_l0_age_group(uuid)
TO authenticated, service_role;

DROP FUNCTION IF EXISTS public.sync_vital_reading(
  uuid, text, text, timestamptz, text, double precision, double precision,
  double precision, double precision, double precision, double precision,
  integer, numeric, numeric, boolean, boolean, jsonb
);

CREATE OR REPLACE FUNCTION public.sync_vital_reading(
  p_member_id uuid,
  p_device_identifier text,
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
  p_raw_data jsonb DEFAULT '{}'::jsonb,
  p_coverage_ratio numeric DEFAULT NULL,
  p_quality_flag text DEFAULT NULL,
  p_wear_state text DEFAULT NULL,
  p_clock_offset_ms numeric DEFAULT NULL,
  p_packet_loss_ratio numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta, ingest, telemetry
AS $$
DECLARE
  resolved_device_id uuid;
  reading_id uuid;
  resolved_quality text;
  resolved_age_group text;
BEGIN
  resolved_device_id := cloud_db_meta.resolve_or_create_device(
    p_member_id, p_device_identifier, p_source
  );
  SELECT age_group INTO STRICT resolved_age_group
  FROM core.family_member WHERE id = p_member_id;
  resolved_quality := coalesce(
    p_quality_flag,
    CASE
      WHEN p_signal_quality >= 0.65 THEN 'good'
      WHEN p_signal_quality >= 0.40 THEN 'degraded'
      WHEN p_signal_quality IS NOT NULL THEN 'poor'
      ELSE 'unknown'
    END
  );

  reading_id := ingest.upsert_vital_reading(
    p_member_id, resolved_device_id, p_source, p_recorded_at,
    p_client_event_id, p_heart_rate, p_spo2, p_hrv, p_respiratory_rate,
    p_temperature, p_stress, p_steps, p_signal_quality, p_confidence,
    p_is_valid, p_is_abnormal, p_raw_data
  );

  UPDATE telemetry.vital_readings
  SET coverage_ratio = p_coverage_ratio,
      quality_flag = resolved_quality,
      wear_state = p_wear_state,
      clock_offset_ms = p_clock_offset_ms,
      packet_loss_ratio = p_packet_loss_ratio,
      age_group = resolved_age_group
  WHERE id = reading_id AND recorded_at = p_recorded_at;

  RETURN reading_id;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_vital_reading(
  uuid, text, text, timestamptz, text, double precision, double precision,
  double precision, double precision, double precision, double precision,
  integer, numeric, numeric, boolean, boolean, jsonb, numeric, text, text,
  numeric, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_vital_reading(
  uuid, text, text, timestamptz, text, double precision, double precision,
  double precision, double precision, double precision, double precision,
  integer, numeric, numeric, boolean, boolean, jsonb, numeric, text, text,
  numeric, numeric
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.sync_l0_fused_metric(
  p_member_id uuid,
  p_metric_type text,
  p_window_start timestamptz,
  p_window_end timestamptz,
  p_status text,
  p_value numeric,
  p_unit text,
  p_confidence numeric,
  p_signal_quality numeric,
  p_coverage_ratio numeric,
  p_coverage_mask jsonb,
  p_quality_flag text,
  p_conflict_flag boolean,
  p_interval_lower numeric,
  p_interval_upper numeric,
  p_contributing_sources text[],
  p_wear_state text,
  p_abstain_reason text,
  p_algorithm_version text,
  p_input_fingerprint text,
  p_evidence jsonb DEFAULT '{}'::jsonb,
  p_conflict_source_a text DEFAULT NULL,
  p_conflict_source_b text DEFAULT NULL,
  p_conflict_value_a numeric DEFAULT NULL,
  p_conflict_value_b numeric DEFAULT NULL,
  p_conflict_tolerance numeric DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta, telemetry
AS $$
DECLARE
  result_id uuid;
  resolved_age_group text;
BEGIN
  IF NOT cloud_db_meta.can_access_member(p_member_id, 'write') THEN
    RAISE EXCEPTION 'authenticated user cannot write this member' USING ERRCODE = '42501';
  END IF;
  SELECT age_group INTO STRICT resolved_age_group
  FROM core.family_member WHERE id = p_member_id;

  INSERT INTO telemetry.l0_fused_metric (
    member_id, metric_type, window_start, window_end, status, value, unit,
    confidence, signal_quality, coverage_ratio, coverage_mask, quality_flag,
    conflict_flag, interval_lower, interval_upper, contributing_sources,
    wear_state, age_group, abstain_reason, algorithm_version, input_fingerprint,
    evidence
  ) VALUES (
    p_member_id, p_metric_type, p_window_start, p_window_end, p_status, p_value,
    p_unit, p_confidence, p_signal_quality, p_coverage_ratio,
    coalesce(p_coverage_mask, '{}'::jsonb), p_quality_flag,
    coalesce(p_conflict_flag, false), p_interval_lower, p_interval_upper,
    p_contributing_sources, p_wear_state, resolved_age_group, p_abstain_reason,
    p_algorithm_version, p_input_fingerprint, coalesce(p_evidence, '{}'::jsonb)
  )
  ON CONFLICT (member_id, metric_type, window_start, algorithm_version, input_fingerprint)
  DO NOTHING
  RETURNING id INTO result_id;

  IF result_id IS NULL THEN
    SELECT id INTO STRICT result_id
    FROM telemetry.l0_fused_metric
    WHERE member_id = p_member_id
      AND metric_type = p_metric_type
      AND window_start = p_window_start
      AND algorithm_version = p_algorithm_version
      AND input_fingerprint = p_input_fingerprint;
  END IF;

  IF p_conflict_flag
      AND p_conflict_source_a IS NOT NULL AND p_conflict_source_b IS NOT NULL
      AND p_conflict_value_a IS NOT NULL AND p_conflict_value_b IS NOT NULL
      AND p_conflict_tolerance IS NOT NULL THEN
    INSERT INTO telemetry.signal_conflict (
      member_id, metric_type, recorded_at, source_a, source_b, value_a, value_b,
      tolerance, quality_flag, resolution, severity, evidence
    ) VALUES (
      p_member_id, p_metric_type, p_window_start,
      least(p_conflict_source_a, p_conflict_source_b),
      greatest(p_conflict_source_a, p_conflict_source_b),
      CASE WHEN p_conflict_source_a <= p_conflict_source_b
        THEN p_conflict_value_a ELSE p_conflict_value_b END,
      CASE WHEN p_conflict_source_a <= p_conflict_source_b
        THEN p_conflict_value_b ELSE p_conflict_value_a END,
      p_conflict_tolerance, p_quality_flag, 'interval', 'warning',
      jsonb_build_object('fused_metric_id', result_id) || coalesce(p_evidence, '{}'::jsonb)
    ) ON CONFLICT DO NOTHING;
  END IF;

  RETURN result_id;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_l0_fused_metric(
  uuid, text, timestamptz, timestamptz, text, numeric, text, numeric, numeric,
  numeric, jsonb, text, boolean, numeric, numeric, text[], text, text, text,
  text, jsonb, text, text, numeric, numeric, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_l0_fused_metric(
  uuid, text, timestamptz, timestamptz, text, numeric, text, numeric, numeric,
  numeric, jsonb, text, boolean, numeric, numeric, text[], text, text, text,
  text, jsonb, text, text, numeric, numeric, numeric
) TO authenticated, service_role;

ALTER TABLE telemetry.l0_fused_metric ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry.l0_fused_metric FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS l0_fused_metric_select ON telemetry.l0_fused_metric;
CREATE POLICY l0_fused_metric_select ON telemetry.l0_fused_metric
FOR SELECT TO authenticated
USING (cloud_db_meta.can_access_member(member_id, 'basic'));

REVOKE ALL ON TABLE telemetry.l0_fused_metric FROM PUBLIC;
GRANT SELECT ON TABLE telemetry.l0_fused_metric TO authenticated;
GRANT ALL ON TABLE telemetry.l0_fused_metric TO service_role;

COMMIT;
