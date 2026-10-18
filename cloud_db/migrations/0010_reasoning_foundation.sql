BEGIN;

CREATE TABLE IF NOT EXISTS inference.metric_definition (
  metric_code text PRIMARY KEY CHECK (length(btrim(metric_code)) BETWEEN 1 AND 100),
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 1 AND 160),
  description text NOT NULL,
  canonical_unit text NOT NULL CHECK (length(btrim(canonical_unit)) BETWEEN 1 AND 40),
  native_resolution_seconds integer NOT NULL CHECK (native_resolution_seconds > 0),
  market_measurable boolean NOT NULL DEFAULT false,
  source_types text[] NOT NULL DEFAULT ARRAY[]::text[],
  scenario_types text[] NOT NULL DEFAULT ARRAY[]::text[],
  reference_standard text,
  evidence_grade text NOT NULL CHECK (evidence_grade IN ('A', 'B', 'C', 'D', 'E')),
  maturity text NOT NULL CHECK (maturity IN ('research', 'provisional', 'validated', 'retired')),
  version text NOT NULL CHECK (length(btrim(version)) BETWEEN 1 AND 80),
  data_requirements jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(data_requirements) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS inference.feature_definition (
  feature_code text PRIMARY KEY CHECK (length(btrim(feature_code)) BETWEEN 1 AND 120),
  metric_code text REFERENCES inference.metric_definition(metric_code) ON DELETE RESTRICT,
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 1 AND 160),
  description text NOT NULL,
  input_modalities text[] NOT NULL DEFAULT ARRAY[]::text[],
  output_unit text,
  window_seconds integer NOT NULL CHECK (window_seconds > 0),
  algorithm_family text NOT NULL CHECK (algorithm_family IN (
    'rule', 'robust_statistics', 'signal_processing', 'gam_ebm',
    'mixed_effects', 'hmm', 'xgboost', 'deep_learning'
  )),
  evidence_grade text NOT NULL CHECK (evidence_grade IN ('A', 'B', 'C', 'D', 'E')),
  maturity text NOT NULL CHECK (maturity IN ('research', 'provisional', 'validated', 'retired')),
  version text NOT NULL CHECK (length(btrim(version)) BETWEEN 1 AND 80),
  failure_modes jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(failure_modes) = 'array'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS inference.evidence_profile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_code text NOT NULL UNIQUE CHECK (length(btrim(evidence_code)) BETWEEN 1 AND 120),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 240),
  evidence_grade text NOT NULL CHECK (evidence_grade IN ('A', 'B', 'C', 'D', 'E')),
  evidence_type text NOT NULL CHECK (evidence_type IN (
    'external_clinical', 'external_nonclinical', 'internal_labeled',
    'internal_unlabeled', 'synthetic', 'reference_standard', 'expert_rule'
  )),
  source_uri text,
  population jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(population) = 'object'),
  limitations text[] NOT NULL DEFAULT ARRAY[]::text[],
  summary text NOT NULL,
  valid_from date NOT NULL DEFAULT current_date,
  valid_to date,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE TABLE IF NOT EXISTS inference.research_backlog (
  item_code text PRIMARY KEY CHECK (length(btrim(item_code)) BETWEEN 1 AND 80),
  workstream text NOT NULL CHECK (workstream IN ('M0', 'R1', 'R2', 'R3', 'validation')),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 240),
  priority text NOT NULL CHECK (priority IN ('P0', 'P1', 'P2', 'P3')),
  status text NOT NULL CHECK (status IN ('backlog', 'ready', 'in_progress', 'blocked', 'done')),
  data_readiness text NOT NULL CHECK (data_readiness IN ('none', 'mock_only', 'unlabeled', 'labeled_internal', 'external')),
  reference_standard text,
  evidence_grade text NOT NULL CHECK (evidence_grade IN ('A', 'B', 'C', 'D', 'E')),
  dependencies text[] NOT NULL DEFAULT ARRAY[]::text[],
  acceptance_criteria text NOT NULL,
  owner_role text NOT NULL DEFAULT 'WP2',
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS inference.algorithm_output (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  output_type text NOT NULL CHECK (length(btrim(output_type)) BETWEEN 1 AND 120),
  state_value jsonb,
  status text NOT NULL CHECK (status IN ('AVAILABLE', 'ABSTAINED')),
  lifecycle text NOT NULL CHECK (lifecycle IN ('research', 'provisional', 'validated')),
  probability numeric(6,5) CHECK (probability IS NULL OR probability BETWEEN 0 AND 1),
  interval jsonb CHECK (interval IS NULL OR jsonb_typeof(interval) = 'object'),
  source_observation_ids uuid[] NOT NULL,
  source_summary jsonb NOT NULL CHECK (jsonb_typeof(source_summary) = 'array'),
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  native_resolution_seconds integer NOT NULL CHECK (native_resolution_seconds > 0),
  sqi numeric(6,5) NOT NULL CHECK (sqi BETWEEN 0 AND 1),
  coverage_ratio numeric(6,5) NOT NULL CHECK (coverage_ratio BETWEEN 0 AND 1),
  plausibility numeric(6,5) NOT NULL CHECK (plausibility BETWEEN 0 AND 1),
  context_fitness numeric(6,5) NOT NULL CHECK (context_fitness BETWEEN 0 AND 1),
  overall_quality numeric(6,5) NOT NULL CHECK (overall_quality BETWEEN 0 AND 1),
  uncertainty jsonb NOT NULL CHECK (jsonb_typeof(uncertainty) = 'object'),
  evidence_grade text NOT NULL CHECK (evidence_grade IN ('A', 'B', 'C', 'D', 'E')),
  evidence_profile_ids uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  evidence_refs jsonb NOT NULL CHECK (jsonb_typeof(evidence_refs) = 'array'),
  algorithm_version text NOT NULL CHECK (length(btrim(algorithm_version)) BETWEEN 1 AND 80),
  model_version_id uuid REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  abstain_reason text CHECK (abstain_reason IS NULL OR abstain_reason IN (
    'INSUFFICIENT_COVERAGE', 'LOW_SQI', 'NOT_WORN', 'INVALID_SOURCE',
    'INSUFFICIENT_BASELINE', 'OUT_OF_DISTRIBUTION', 'SOURCE_CONFLICT'
  )),
  data_origin text NOT NULL CHECK (data_origin IN ('REAL', 'ANONYMIZED', 'SYNTHETIC_MOCK')),
  input_fingerprint text NOT NULL CHECK (input_fingerprint ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, output_type, window_end, algorithm_version, input_fingerprint),
  CHECK (window_end >= window_start),
  CHECK (cardinality(source_observation_ids) > 0),
  CHECK (jsonb_array_length(source_summary) > 0),
  CHECK (jsonb_array_length(evidence_refs) > 0),
  CHECK (
    (status = 'AVAILABLE' AND state_value IS NOT NULL AND probability IS NOT NULL
      AND interval IS NOT NULL AND abstain_reason IS NULL)
    OR
    (status = 'ABSTAINED' AND state_value IS NULL AND probability IS NULL
      AND interval IS NULL AND abstain_reason IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS inference.validation_run (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_code text NOT NULL UNIQUE CHECK (length(btrim(run_code)) BETWEEN 1 AND 120),
  algorithm_version text NOT NULL,
  scenario_type text NOT NULL,
  dataset_origin text NOT NULL CHECK (dataset_origin IN ('REAL', 'ANONYMIZED', 'SYNTHETIC_MOCK')),
  split_strategy text NOT NULL CHECK (split_strategy IN (
    'subject', 'temporal', 'device_external', 'hospital_external', 'engineering_replay'
  )),
  subject_count integer NOT NULL CHECK (subject_count >= 0),
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metrics) = 'object'),
  subgroup_metrics jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(subgroup_metrics) = 'object'),
  limitations text[] NOT NULL DEFAULT ARRAY[]::text[],
  is_publishable boolean NOT NULL DEFAULT false,
  executed_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (dataset_origin <> 'SYNTHETIC_MOCK' OR NOT is_publishable)
);

CREATE TABLE IF NOT EXISTS inference.drift_window (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  algorithm_version text NOT NULL,
  output_type text NOT NULL,
  device_type text,
  firmware_version text,
  subgroup jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(subgroup) = 'object'),
  window_start timestamptz NOT NULL,
  window_end timestamptz NOT NULL,
  sample_count integer NOT NULL CHECK (sample_count >= 0),
  coverage_ratio numeric(6,5) NOT NULL CHECK (coverage_ratio BETWEEN 0 AND 1),
  mean_sqi numeric(6,5) NOT NULL CHECK (mean_sqi BETWEEN 0 AND 1),
  abstain_rate numeric(6,5) NOT NULL CHECK (abstain_rate BETWEEN 0 AND 1),
  feature_drift jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(feature_drift) = 'object'),
  calibration_drift jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(calibration_drift) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (algorithm_version, output_type, device_type, firmware_version, window_start, window_end),
  CHECK (window_end > window_start)
);

CREATE INDEX IF NOT EXISTS idx_algorithm_output_member_window
  ON inference.algorithm_output(member_id, window_end DESC);
CREATE INDEX IF NOT EXISTS idx_algorithm_output_member_type_window
  ON inference.algorithm_output(member_id, output_type, window_end DESC);
CREATE INDEX IF NOT EXISTS idx_algorithm_output_abstain
  ON inference.algorithm_output(abstain_reason, window_end DESC) WHERE status = 'ABSTAINED';
CREATE INDEX IF NOT EXISTS idx_validation_run_algorithm
  ON inference.validation_run(algorithm_version, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_drift_window_algorithm
  ON inference.drift_window(algorithm_version, output_type, window_end DESC);

CREATE OR REPLACE FUNCTION cloud_db_meta.reject_immutable_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  RAISE EXCEPTION 'immutable reasoning record cannot be changed' USING ERRCODE = '55000';
END;
$$;

DROP TRIGGER IF EXISTS trg_algorithm_output_immutable ON inference.algorithm_output;
CREATE TRIGGER trg_algorithm_output_immutable
BEFORE UPDATE OR DELETE ON inference.algorithm_output
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.reject_immutable_mutation();

DROP TRIGGER IF EXISTS trg_metric_definition_updated_at ON inference.metric_definition;
CREATE TRIGGER trg_metric_definition_updated_at BEFORE UPDATE ON inference.metric_definition
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_feature_definition_updated_at ON inference.feature_definition;
CREATE TRIGGER trg_feature_definition_updated_at BEFORE UPDATE ON inference.feature_definition
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_evidence_profile_updated_at ON inference.evidence_profile;
CREATE TRIGGER trg_evidence_profile_updated_at BEFORE UPDATE ON inference.evidence_profile
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_research_backlog_updated_at ON inference.research_backlog;
CREATE TRIGGER trg_research_backlog_updated_at BEFORE UPDATE ON inference.research_backlog
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();

ALTER TABLE inference.algorithm_output ENABLE ROW LEVEL SECURITY;
ALTER TABLE inference.algorithm_output FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS algorithm_output_select ON inference.algorithm_output;
CREATE POLICY algorithm_output_select ON inference.algorithm_output FOR SELECT TO authenticated
USING (cloud_db_meta.can_access_member(member_id, 'basic'));

DO $$
DECLARE
  catalog text;
BEGIN
  FOREACH catalog IN ARRAY ARRAY[
    'metric_definition', 'feature_definition', 'evidence_profile',
    'research_backlog', 'validation_run', 'drift_window'
  ]
  LOOP
    EXECUTE format('ALTER TABLE inference.%I ENABLE ROW LEVEL SECURITY', catalog);
    EXECUTE format('ALTER TABLE inference.%I FORCE ROW LEVEL SECURITY', catalog);
    EXECUTE format('DROP POLICY IF EXISTS catalog_read ON inference.%I', catalog);
    EXECUTE format(
      'CREATE POLICY catalog_read ON inference.%I FOR SELECT TO authenticated USING (true)',
      catalog
    );
  END LOOP;
END;
$$;

REVOKE ALL ON TABLE inference.metric_definition, inference.feature_definition,
  inference.evidence_profile, inference.research_backlog, inference.algorithm_output,
  inference.validation_run, inference.drift_window FROM PUBLIC;
GRANT SELECT ON TABLE inference.metric_definition, inference.feature_definition,
  inference.evidence_profile, inference.research_backlog, inference.validation_run,
  inference.drift_window TO authenticated;
GRANT SELECT ON TABLE inference.algorithm_output TO authenticated;
GRANT ALL ON TABLE inference.metric_definition, inference.feature_definition,
  inference.evidence_profile, inference.research_backlog, inference.algorithm_output,
  inference.validation_run, inference.drift_window TO service_role;

COMMIT;
