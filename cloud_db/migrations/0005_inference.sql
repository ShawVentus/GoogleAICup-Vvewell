BEGIN;

CREATE TABLE IF NOT EXISTS inference.model_version (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_type text NOT NULL CHECK (length(btrim(model_type)) BETWEEN 1 AND 100),
  version text NOT NULL CHECK (length(btrim(version)) BETWEEN 1 AND 80),
  artifact_uri text,
  parameter_hash text CHECK (parameter_hash IS NULL OR parameter_hash ~ '^[0-9a-f]{64}$'),
  released_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (model_type, version),
  CHECK (retired_at IS NULL OR retired_at > released_at)
);

CREATE TABLE IF NOT EXISTS inference.health_state (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  state_type text NOT NULL CHECK (length(btrim(state_type)) BETWEEN 1 AND 100),
  value jsonb NOT NULL,
  unit text,
  start_at timestamptz NOT NULL,
  end_at timestamptz,
  confidence numeric(6,5) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  coverage_ratio numeric(6,5) NOT NULL CHECK (coverage_ratio BETWEEN 0 AND 1),
  model_version_id uuid NOT NULL REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  evidence_ids uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, start_at),
  CHECK (end_at IS NULL OR end_at >= start_at)
) PARTITION BY RANGE (start_at);

CREATE TABLE IF NOT EXISTS inference.health_state_default
  PARTITION OF inference.health_state DEFAULT;

CREATE TABLE IF NOT EXISTS inference.digital_twin_snapshot (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  twin_type text NOT NULL CHECK (twin_type IN (
    'cardiovascular', 'respiratory', 'autonomic', 'sleep_wake', 'female_cycle',
    'pharmacology', 'psychological', 'elder_chronic', 'child_growth', 'health_risk'
  )),
  state_vector jsonb NOT NULL CHECK (jsonb_typeof(state_vector) = 'object'),
  parameter_set jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(parameter_set) = 'object'),
  uncertainty jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(uncertainty) = 'object'),
  model_version_id uuid NOT NULL REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  captured_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (id, captured_at),
  UNIQUE (member_id, twin_type, captured_at)
) PARTITION BY RANGE (captured_at);

CREATE TABLE IF NOT EXISTS inference.digital_twin_snapshot_default
  PARTITION OF inference.digital_twin_snapshot DEFAULT;

CREATE TABLE IF NOT EXISTS inference.recovery_score (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  scored_at timestamptz NOT NULL,
  physiological_score numeric(5,2) NOT NULL CHECK (physiological_score BETWEEN 0 AND 100),
  psychological_score numeric(5,2) NOT NULL CHECK (psychological_score BETWEEN 0 AND 100),
  overall_score numeric(5,2) NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
  confidence numeric(6,5) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  coverage_ratio numeric(6,5) NOT NULL CHECK (coverage_ratio BETWEEN 0 AND 1),
  model_version_id uuid NOT NULL REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  evidence_ids uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, scored_at)
);

CREATE TABLE IF NOT EXISTS inference.personal_baseline (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  metric_type text NOT NULL,
  segment text NOT NULL DEFAULT 'all_day',
  window_days integer NOT NULL CHECK (window_days BETWEEN 1 AND 365),
  median numeric NOT NULL,
  mad numeric NOT NULL CHECK (mad >= 0),
  lower_bound numeric,
  upper_bound numeric,
  sample_count integer NOT NULL CHECK (sample_count >= 0),
  calibrated_by text NOT NULL CHECK (calibrated_by IN ('personal_history', 'clinical_gold', 'population_fallback')),
  model_version_id uuid NOT NULL REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  effective_from timestamptz NOT NULL DEFAULT clock_timestamp(),
  effective_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, metric_type, segment, effective_from),
  CHECK (upper_bound IS NULL OR lower_bound IS NULL OR upper_bound >= lower_bound),
  CHECK (effective_to IS NULL OR effective_to > effective_from)
);

CREATE TABLE IF NOT EXISTS inference.health_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (length(btrim(event_type)) BETWEEN 1 AND 100),
  severity text NOT NULL CHECK (severity IN ('info', 'yellow', 'orange', 'red')),
  start_at timestamptz NOT NULL,
  end_at timestamptz,
  metrics jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(metrics) = 'array'),
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence) = 'object'),
  event_source text NOT NULL CHECK (event_source IN ('rule', 'baseline', 'model', 'care_sensor', 'manual')),
  quality_gate text NOT NULL CHECK (quality_gate IN ('passed', 'insufficient', 'conflict')),
  suppressed boolean NOT NULL DEFAULT false,
  suppression_reason text,
  related_order_id uuid,
  model_version_id uuid REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (end_at IS NULL OR end_at >= start_at),
  CHECK (NOT suppressed OR suppression_reason IS NOT NULL),
  CHECK (event_source IN ('rule', 'manual') OR model_version_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS inference.attribution_edge (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  cause text NOT NULL,
  effect text NOT NULL,
  lag_seconds bigint NOT NULL CHECK (lag_seconds >= 0),
  effect_size numeric NOT NULL,
  p_value numeric(8,7) CHECK (p_value IS NULL OR p_value BETWEEN 0 AND 1),
  confidence numeric(6,5) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  evidence_ref jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(evidence_ref) = 'array'),
  model_version_id uuid NOT NULL REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  valid_from timestamptz NOT NULL DEFAULT clock_timestamp(),
  valid_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (cause <> effect),
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE TABLE IF NOT EXISTS inference.health_tag (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  tag_type text NOT NULL CHECK (tag_type IN ('attribute', 'state', 'behavior', 'risk', 'causal_response', 'insurance', 'population')),
  tag_key text NOT NULL,
  tag_value jsonb NOT NULL,
  weight numeric(8,5) NOT NULL DEFAULT 1 CHECK (weight BETWEEN 0 AND 1),
  confidence numeric(6,5) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  source text NOT NULL,
  model_version_id uuid REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  valid_from timestamptz NOT NULL DEFAULT clock_timestamp(),
  valid_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, tag_type, tag_key, valid_from),
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE TABLE IF NOT EXISTS inference.intervention_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intervention_code text NOT NULL UNIQUE,
  category text NOT NULL CHECK (category IN ('lifestyle', 'medication_adherence', 'care_safety', 'medical_service', 'insurance')),
  title text NOT NULL,
  description text NOT NULL,
  target_metrics text[] NOT NULL DEFAULT ARRAY[]::text[],
  safety_constraints jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(safety_constraints) = 'object'),
  version text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS inference.intervention_experiment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  intervention_id uuid NOT NULL REFERENCES inference.intervention_catalog(id) ON DELETE RESTRICT,
  design jsonb NOT NULL CHECK (jsonb_typeof(design) = 'object'),
  blocks jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(blocks) = 'array'),
  target_metric text NOT NULL,
  expected_delta numeric,
  observation_window interval NOT NULL CHECK (observation_window > interval '0'),
  quality_threshold numeric(6,5) NOT NULL CHECK (quality_threshold BETWEEN 0 AND 1),
  effect_size numeric,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'running', 'completed', 'cancelled', 'inconclusive')),
  result jsonb CHECK (result IS NULL OR jsonb_typeof(result) = 'object'),
  started_at timestamptz,
  ended_at timestamptz,
  model_version_id uuid REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (ended_at IS NULL OR started_at IS NOT NULL),
  CHECK (ended_at IS NULL OR ended_at >= started_at),
  CHECK (status NOT IN ('completed', 'inconclusive') OR result IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS inference.reasoning_trace (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  question text NOT NULL,
  steps jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(steps) = 'array'),
  tool_calls jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(tool_calls) = 'array'),
  evidence_ids uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  conclusion jsonb NOT NULL CHECK (jsonb_typeof(conclusion) = 'object'),
  model_version_id uuid NOT NULL REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz,
  CHECK (expires_at IS NULL OR expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_health_state_member_type_start ON inference.health_state(member_id, state_type, start_at DESC);
CREATE INDEX IF NOT EXISTS idx_twin_member_type_captured ON inference.digital_twin_snapshot(member_id, twin_type, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_recovery_member_scored ON inference.recovery_score(member_id, scored_at DESC);
CREATE INDEX IF NOT EXISTS idx_baseline_member_metric ON inference.personal_baseline(member_id, metric_type, effective_from DESC);
CREATE INDEX IF NOT EXISTS idx_health_event_member_start ON inference.health_event(member_id, start_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_event_active_red ON inference.health_event(member_id, severity, start_at DESC) WHERE end_at IS NULL AND NOT suppressed;
CREATE INDEX IF NOT EXISTS idx_attribution_member_effect ON inference.attribution_edge(member_id, effect, valid_from DESC);
CREATE INDEX IF NOT EXISTS idx_health_tag_member_key ON inference.health_tag(member_id, tag_key, valid_from DESC);
CREATE INDEX IF NOT EXISTS idx_intervention_experiment_member ON inference.intervention_experiment(member_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reasoning_trace_member ON inference.reasoning_trace(member_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_personal_baseline_updated_at ON inference.personal_baseline;
CREATE TRIGGER trg_personal_baseline_updated_at BEFORE UPDATE ON inference.personal_baseline
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_health_event_updated_at ON inference.health_event;
CREATE TRIGGER trg_health_event_updated_at BEFORE UPDATE ON inference.health_event
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_health_tag_updated_at ON inference.health_tag;
CREATE TRIGGER trg_health_tag_updated_at BEFORE UPDATE ON inference.health_tag
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_intervention_catalog_updated_at ON inference.intervention_catalog;
CREATE TRIGGER trg_intervention_catalog_updated_at BEFORE UPDATE ON inference.intervention_catalog
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_intervention_experiment_updated_at ON inference.intervention_experiment;
CREATE TRIGGER trg_intervention_experiment_updated_at BEFORE UPDATE ON inference.intervention_experiment
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();

COMMIT;
