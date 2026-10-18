BEGIN;

CREATE OR REPLACE FUNCTION cloud_db_meta.deterministic_uuid(p_seed text)
RETURNS uuid
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = pg_catalog
AS $$
  SELECT (
    substr(md5(p_seed), 1, 8) || '-' ||
    substr(md5(p_seed), 9, 4) || '-' ||
    '5' || substr(md5(p_seed), 14, 3) || '-' ||
    '8' || substr(md5(p_seed), 18, 3) || '-' ||
    substr(md5(p_seed), 21, 12)
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION public.run_observatory_analysis(
  p_member_id uuid,
  p_as_of timestamptz DEFAULT clock_timestamp()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, cloud_db_meta, core, telemetry, inference
AS $$
DECLARE
  analysis_at timestamptz;
  model_id uuid;
  feature_inserted integer := 0;
  state_inserted integer := 0;
  twin_changed integer := 0;
  baseline_changed integer := 0;
  event_inserted integer := 0;
BEGIN
  IF p_member_id IS NULL THEN
    RAISE EXCEPTION 'member id is required' USING ERRCODE = '22023';
  END IF;
  IF NOT cloud_db_meta.is_service()
     AND NOT cloud_db_meta.can_access_member(p_member_id, 'write')
     AND NOT (
       session_user IN ('postgres', 'supabase_admin')
       AND coalesce(nullif(current_setting('role', true), ''), 'none')
           IN ('none', 'postgres', 'supabase_admin')
     ) THEN
    RAISE EXCEPTION 'member write access denied' USING ERRCODE = '42501';
  END IF;

  SELECT date_trunc('minute', max(window_end))
  INTO analysis_at
  FROM telemetry.l0_fused_metric
  WHERE member_id = p_member_id AND window_end <= p_as_of;

  IF analysis_at IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'NO_INPUT', 'member_id', p_member_id,
      'message', 'Sync fused L0 metrics before running cloud analysis.',
      'levels', jsonb_build_object('L1', 0, 'L2', 0, 'L3', 0, 'L4', 0, 'L5', 0)
    );
  END IF;

  INSERT INTO inference.model_version (model_type, version, parameter_hash)
  VALUES (
    'observatory_descriptive_pipeline', 'observatory-descriptive-v1',
    encode(extensions.digest('observatory-descriptive-v1', 'sha256'), 'hex')
  )
  ON CONFLICT (model_type, version) DO UPDATE SET version = EXCLUDED.version
  RETURNING id INTO model_id;

  INSERT INTO telemetry.feature_observation (
    id, member_id, metric_type, value, unit, source, confidence, coverage_ratio,
    quality_flag, is_valid, is_abnormal, recorded_at, metadata, client_event_id
  )
  SELECT
    cloud_db_meta.deterministic_uuid('feature:' || fused.id::text), fused.member_id,
    fused.metric_type, fused.value, fused.unit, 'l0_fusion', fused.confidence,
    fused.coverage_ratio, fused.quality_flag, true, fused.quality_flag = 'poor',
    fused.window_end,
    jsonb_build_object(
      'l0_fused_metric_id', fused.id, 'algorithm_version', fused.algorithm_version,
      'input_fingerprint', fused.input_fingerprint, 'analysis_runtime', 'cloud_trigger_v1'
    ),
    'l0:' || fused.id::text
  FROM telemetry.l0_fused_metric fused
  WHERE fused.member_id = p_member_id
    AND fused.window_end <= analysis_at + interval '1 minute'
    AND fused.status = 'AVAILABLE' AND fused.value IS NOT NULL
  ON CONFLICT (member_id, metric_type, source, recorded_at, client_event_id) DO NOTHING;
  GET DIAGNOSTICS feature_inserted = ROW_COUNT;

  INSERT INTO inference.health_state (
    id, member_id, state_type, value, unit, start_at, end_at, confidence,
    coverage_ratio, model_version_id, evidence_ids
  )
  SELECT
    cloud_db_meta.deterministic_uuid('state:' || feature.id::text), feature.member_id,
    left(feature.metric_type || '_observed', 100),
    jsonb_build_object(
      'value', feature.value, 'quality_flag', feature.quality_flag,
      'descriptive_only', true
    ),
    feature.unit, feature.recorded_at, NULL, coalesce(feature.confidence, 0),
    coalesce(feature.coverage_ratio, 0), model_id, ARRAY[feature.id]
  FROM telemetry.feature_observation feature
  WHERE feature.member_id = p_member_id AND feature.source = 'l0_fusion'
    AND feature.recorded_at <= analysis_at + interval '1 minute'
  ON CONFLICT (id, start_at) DO NOTHING;
  GET DIAGNOSTICS state_inserted = ROW_COUNT;

  WITH latest AS (
    SELECT DISTINCT ON (feature.metric_type)
      feature.metric_type, feature.value, feature.unit, feature.confidence,
      feature.coverage_ratio, feature.recorded_at, feature.id
    FROM telemetry.feature_observation feature
    WHERE feature.member_id = p_member_id AND feature.source = 'l0_fusion'
      AND feature.recorded_at <= analysis_at + interval '1 minute'
    ORDER BY feature.metric_type, feature.recorded_at DESC
  ), vector AS (
    SELECT
      jsonb_object_agg(metric_type, jsonb_build_object(
        'value', value, 'unit', unit, 'observed_at', recorded_at,
        'confidence', confidence, 'coverage_ratio', coverage_ratio
      )) AS state_vector,
      jsonb_object_agg(metric_type, jsonb_build_object(
        'confidence', confidence, 'coverage_ratio', coverage_ratio
      )) AS uncertainty
    FROM latest
  )
  INSERT INTO inference.digital_twin_snapshot (
    id, member_id, twin_type, state_vector, parameter_set, uncertainty,
    model_version_id, captured_at
  )
  SELECT
    cloud_db_meta.deterministic_uuid('twin:' || p_member_id::text || ':' || analysis_at::text),
    p_member_id, 'health_risk', vector.state_vector,
    jsonb_build_object('method', 'latest_observation_snapshot', 'descriptive_only', true),
    vector.uncertainty, model_id, analysis_at
  FROM vector WHERE vector.state_vector IS NOT NULL
  ON CONFLICT (member_id, twin_type, captured_at) DO UPDATE SET
    state_vector = EXCLUDED.state_vector,
    parameter_set = EXCLUDED.parameter_set,
    uncertainty = EXCLUDED.uncertainty,
    model_version_id = EXCLUDED.model_version_id;
  GET DIAGNOSTICS twin_changed = ROW_COUNT;

  WITH source_rows AS (
    SELECT feature.metric_type, feature.value
    FROM telemetry.feature_observation feature
    WHERE feature.member_id = p_member_id AND feature.source = 'l0_fusion'
      AND feature.recorded_at > analysis_at - interval '7 days'
      AND feature.recorded_at <= analysis_at + interval '1 minute'
  ), medians AS (
    SELECT metric_type, percentile_cont(0.5) WITHIN GROUP (ORDER BY value) AS median,
      count(*)::integer AS sample_count
    FROM source_rows GROUP BY metric_type HAVING count(*) >= 3
  ), stats AS (
    SELECT medians.metric_type, medians.median, medians.sample_count,
      percentile_cont(0.5) WITHIN GROUP (
        ORDER BY abs(source_rows.value - medians.median)
      ) AS mad
    FROM medians JOIN source_rows USING (metric_type)
    GROUP BY medians.metric_type, medians.median, medians.sample_count
  )
  INSERT INTO inference.personal_baseline (
    id, member_id, metric_type, segment, window_days, median, mad, lower_bound,
    upper_bound, sample_count, calibrated_by, model_version_id, effective_from
  )
  SELECT
    cloud_db_meta.deterministic_uuid(
      'baseline:' || p_member_id::text || ':' || stats.metric_type || ':' || analysis_at::text
    ),
    p_member_id, stats.metric_type, 'all_day', 7, stats.median, stats.mad,
    stats.median - 3 * stats.mad, stats.median + 3 * stats.mad,
    stats.sample_count, 'personal_history', model_id, analysis_at
  FROM stats
  ON CONFLICT (member_id, metric_type, segment, effective_from) DO UPDATE SET
    median = EXCLUDED.median, mad = EXCLUDED.mad,
    lower_bound = EXCLUDED.lower_bound, upper_bound = EXCLUDED.upper_bound,
    sample_count = EXCLUDED.sample_count, model_version_id = EXCLUDED.model_version_id,
    updated_at = clock_timestamp();
  GET DIAGNOSTICS baseline_changed = ROW_COUNT;

  WITH latest AS (
    SELECT DISTINCT ON (feature.metric_type)
      feature.id, feature.metric_type, feature.value, feature.unit,
      feature.recorded_at, feature.confidence, feature.coverage_ratio
    FROM telemetry.feature_observation feature
    WHERE feature.member_id = p_member_id AND feature.source = 'l0_fusion'
      AND feature.recorded_at <= analysis_at + interval '1 minute'
    ORDER BY feature.metric_type, feature.recorded_at DESC
  ), candidates AS (
    SELECT latest.*, baseline.median, baseline.mad,
      CASE WHEN baseline.mad > 0 THEN abs(latest.value - baseline.median) / baseline.mad ELSE 0 END AS deviation
    FROM latest
    JOIN inference.personal_baseline baseline
      ON baseline.member_id = p_member_id AND baseline.metric_type = latest.metric_type
      AND baseline.segment = 'all_day' AND baseline.effective_from = analysis_at
    WHERE baseline.sample_count >= 12 AND baseline.mad > 0
      AND abs(latest.value - baseline.median) > 3 * baseline.mad
  )
  INSERT INTO inference.health_event (
    id, member_id, event_type, severity, start_at, metrics, evidence,
    event_source, quality_gate, suppressed, model_version_id
  )
  SELECT
    cloud_db_meta.deterministic_uuid('event:' || candidates.id::text || ':' || analysis_at::text),
    p_member_id, left('baseline_deviation_' || candidates.metric_type, 100),
    CASE WHEN candidates.deviation >= 6 THEN 'orange' ELSE 'yellow' END,
    candidates.recorded_at,
    jsonb_build_array(jsonb_build_object(
      'metric', candidates.metric_type, 'value', candidates.value,
      'unit', candidates.unit, 'baseline', candidates.median,
      'mad_deviation', candidates.deviation
    )),
    jsonb_build_object(
      'feature_observation_id', candidates.id, 'descriptive_only', true,
      'causal_claim', false
    ),
    'baseline', 'passed', false, model_id
  FROM candidates
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS event_inserted = ROW_COUNT;

  RETURN jsonb_build_object(
    'status', 'COMPLETED', 'member_id', p_member_id, 'analysis_at', analysis_at,
    'inserted', jsonb_build_object(
      'features', feature_inserted, 'states', state_inserted,
      'twin_snapshots', twin_changed, 'baselines', baseline_changed,
      'events', event_inserted
    ),
    'levels', jsonb_build_object(
      'L1', (SELECT count(*) FROM telemetry.feature_observation WHERE member_id = p_member_id),
      'L2', (SELECT count(*) FROM inference.health_state WHERE member_id = p_member_id) +
            (SELECT count(*) FROM inference.digital_twin_snapshot WHERE member_id = p_member_id) +
            (SELECT count(*) FROM inference.recovery_score WHERE member_id = p_member_id),
      'L3', (SELECT count(*) FROM inference.personal_baseline WHERE member_id = p_member_id) +
            (SELECT count(*) FROM inference.health_event WHERE member_id = p_member_id) +
            (SELECT count(*) FROM inference.attribution_edge WHERE member_id = p_member_id),
      'L4', (SELECT count(*) FROM inference.health_tag WHERE member_id = p_member_id) +
            (SELECT count(*) FROM inference.recommendation_decision WHERE member_id = p_member_id),
      'L5', (SELECT count(*) FROM care.health_task_instance WHERE member_id = p_member_id) +
            (SELECT count(*) FROM inference.recommendation_feedback WHERE member_id = p_member_id)
    ),
    'limitations', jsonb_build_array(
      'Descriptive pipeline only; no clinical diagnosis.',
      'No attribution edges are created without a causal estimator.'
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.run_observatory_analysis(uuid, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.run_observatory_analysis(uuid, timestamptz)
  TO authenticated, service_role;

COMMIT;
