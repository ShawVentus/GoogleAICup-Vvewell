BEGIN;

ALTER TABLE inference.health_tag
  ADD COLUMN IF NOT EXISTS analysis_id uuid,
  ADD COLUMN IF NOT EXISTS policy_version text,
  ADD COLUMN IF NOT EXISTS input_fingerprint text
    CHECK (input_fingerprint IS NULL OR input_fingerprint ~ '^[0-9a-f]{64}$'),
  ADD COLUMN IF NOT EXISTS evidence jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(evidence) = 'object'),
  ADD COLUMN IF NOT EXISTS demo_baseline boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_health_tag_analysis_fingerprint
  ON inference.health_tag(member_id, tag_key, input_fingerprint, policy_version)
  WHERE input_fingerprint IS NOT NULL AND policy_version IS NOT NULL;

CREATE TABLE IF NOT EXISTS inference.recommendation_catalog_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intent_code text NOT NULL UNIQUE CHECK (length(btrim(intent_code)) BETWEEN 3 AND 120),
  item_kind text NOT NULL CHECK (item_kind IN ('ADVICE', 'TASK', 'GOODS', 'SERVICE')),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 200),
  description text NOT NULL CHECK (length(btrim(description)) BETWEEN 1 AND 2000),
  presentation_category text NOT NULL CHECK (length(btrim(presentation_category)) BETWEEN 1 AND 80),
  content_version text NOT NULL CHECK (length(btrim(content_version)) BETWEEN 1 AND 80),
  target_tag_keys text[] NOT NULL DEFAULT ARRAY[]::text[],
  required_fact_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
  consent_scope text[] NOT NULL DEFAULT ARRAY[]::text[],
  safety_constraints jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(safety_constraints) = 'object'),
  commercial_disclosure text,
  resolver_metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(resolver_metadata) = 'object'),
  insurance_product_id uuid REFERENCES insurance.insurance_product(id) ON DELETE SET NULL,
  data_origin text NOT NULL CHECK (data_origin IN ('REAL', 'SIMULATION_ONLY')),
  approval_status text NOT NULL CHECK (approval_status IN ('DRAFT', 'APPROVED', 'RETIRED')),
  active_from timestamptz NOT NULL,
  active_to timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (active_to IS NULL OR active_to > active_from),
  CHECK (item_kind NOT IN ('GOODS', 'SERVICE') OR commercial_disclosure IS NOT NULL),
  CHECK (insurance_product_id IS NULL OR item_kind = 'SERVICE')
);

INSERT INTO inference.recommendation_catalog_item (
  id, intent_code, item_kind, title, description, presentation_category,
  content_version, target_tag_keys, required_fact_codes, consent_scope,
  safety_constraints, commercial_disclosure, resolver_metadata,
  data_origin, approval_status, active_from
) VALUES
  ('95000000-0000-4000-8000-000000000001', 'TASK.BREATH.SHORT', 'TASK',
   'Five-minute breathing task', 'Take five quiet minutes for slow, comfortable breathing. Stop if you feel unwell.',
   'wellness_task', 'v2', ARRAY['relative_hr_elevated','relative_resp_rate_elevated'], ARRAY[]::text[], ARRAY[]::text[],
   '{"not_medical_treatment":true}', NULL, '{"goal":{"type":"boolean","target":1}}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000002', 'TASK.WALK.LIGHT', 'TASK',
   'Light walking task', 'Complete a short, comfortable walk when your surroundings and mobility allow it.',
   'wellness_task', 'v2', ARRAY['low_activity'], ARRAY['CAN_WALK'], ARRAY[]::text[],
   '{"mobility_confirmation_required":true}', NULL, '{"goal":{"type":"duration_minutes","target":10}}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000003', 'TASK.SLEEP.BEFORE_23', 'TASK',
   'Wind down before 23:00', 'Aim to finish your wind-down routine and go to bed before 23:00 today.',
   'wellness_task', 'v2', ARRAY['poor_sleep','sleep_debt'], ARRAY[]::text[], ARRAY[]::text[],
   '{"sleep_source_required":true}', NULL, '{"goal":{"type":"boolean","target":1}}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000004', 'TASK.ALCOHOL_FREE_DAY', 'TASK',
   'Alcohol-free day', 'Follow your self-selected alcohol-free wellness goal for today. This is not suitable for managing alcohol dependence or withdrawal.',
   'wellness_task', 'v2', ARRAY[]::text[], ARRAY['ALCOHOL_GOAL'], ARRAY[]::text[],
   '{"explicit_goal_required":true,"withdrawal_risk_excluded":true}', NULL, '{"goal":{"type":"boolean","target":1}}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000005', 'TASK.APPROVED_VITAMIN_PLAN', 'TASK',
   'Complete your approved nutrition plan', 'Track the nutrition or vitamin step already recorded in your verified plan. No dose is generated here.',
   'wellness_task', 'v2', ARRAY[]::text[], ARRAY['VERIFIED_PLAN'], ARRAY[]::text[],
   '{"verified_plan_required":true,"dose_generation_forbidden":true}', NULL, '{"goal":{"type":"boolean","target":1}}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000006', 'ADVICE.SLEEP.ENVIRONMENT', 'ADVICE',
   'Prepare a quieter sleep environment', 'Reduce avoidable light and noise as part of your usual sleep routine.',
   'wellness_advice', 'v2', ARRAY['poor_sleep','sleep_debt'], ARRAY[]::text[], ARRAY[]::text[],
   '{"not_medical_treatment":true}', NULL, '{}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000007', 'ADVICE.RECOVERY.REST', 'ADVICE',
   'Take a recovery pause', 'Consider a short, low-effort rest period and reassess how you feel.',
   'wellness_advice', 'v2', ARRAY['relative_hrv_suppressed','relative_hr_elevated'], ARRAY[]::text[], ARRAY[]::text[],
   '{"not_medical_treatment":true}', NULL, '{}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000008', 'ADVICE.MEASUREMENT.RETRY', 'ADVICE',
   'Improve the next measurement', 'Adjust device contact, stay still, and retry when convenient.',
   'measurement_advice', 'v2', ARRAY['data_insufficient','low_data_coverage','source_conflict_observed'], ARRAY[]::text[], ARRAY[]::text[],
   '{"only_data_quality_claims":true}', NULL, '{}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000009', 'GOODS.MEASUREMENT_HARDWARE', 'GOODS',
   'Compatible measurement hardware', 'Review approved hardware options that may improve measurement coverage.',
   'hardware', 'v2', ARRAY['low_data_coverage','source_conflict_observed'], ARRAY[]::text[], ARRAY['commercial_recommendation'],
   '{"no_health_outcome_guarantee":true}', 'Commercial recommendation. Products are optional and do not replace medical care.', '{}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000010', 'GOODS.APPROVED_NUTRITION_SUPPORT', 'GOODS',
   'Products matching your verified plan', 'Review approved nutrition products that match an existing verified plan.',
   'nutrition_product', 'v2', ARRAY[]::text[], ARRAY['VERIFIED_PLAN'], ARRAY['commercial_recommendation'],
   '{"verified_plan_required":true,"dose_generation_forbidden":true}', 'Commercial recommendation. Check the verified plan and product label before use.', '{}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000011', 'SERVICE.GENERAL_CHECKUP', 'SERVICE',
   'General checkup information', 'Review general checkup services when your profile indicates one is due.',
   'medical_service', 'v2', ARRAY[]::text[], ARRAY['CHECKUP_DUE'], ARRAY['medical_service_recommendation'],
   '{"non_emergency_only":true}', 'Service information only. Availability, eligibility, and fees are determined by the provider.', '{}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000012', 'SERVICE.CHRONIC_FOLLOWUP', 'SERVICE',
   'Chronic-care follow-up information', 'Review follow-up services tied to an existing verified diagnosis or care plan.',
   'medical_service', 'v2', ARRAY[]::text[], ARRAY['VERIFIED_DIAGNOSIS'], ARRAY['medical_service_recommendation'],
   '{"verified_diagnosis_required":true,"non_emergency_only":true}', 'Service information only. This recommendation does not diagnose a condition.', '{}', 'REAL', 'APPROVED', '2026-01-01'),
  ('95000000-0000-4000-8000-000000000013', 'SERVICE.INSURANCE_REVIEW', 'SERVICE',
   'Health coverage review', 'Review general health-coverage information without using sensor tags for pricing or eligibility decisions.',
   'insurance_service', 'v2', ARRAY[]::text[], ARRAY[]::text[], ARRAY['insurance_recommendation'],
   '{"sensor_underwriting_forbidden":true}', 'Insurance information only. No coverage, underwriting, or pricing decision is made here.', '{}', 'REAL', 'APPROVED', '2026-01-01')
ON CONFLICT (intent_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS inference.recommendation_decision (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  client_request_id text NOT NULL CHECK (length(btrim(client_request_id)) BETWEEN 1 AND 200),
  surface text NOT NULL CHECK (length(btrim(surface)) BETWEEN 1 AND 80),
  decided_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  context_snapshot jsonb NOT NULL CHECK (jsonb_typeof(context_snapshot) = 'object'),
  health_tag_snapshot jsonb NOT NULL CHECK (jsonb_typeof(health_tag_snapshot) = 'array'),
  candidate_snapshot jsonb NOT NULL CHECK (jsonb_typeof(candidate_snapshot) = 'array'),
  final_plan jsonb NOT NULL CHECK (jsonb_typeof(final_plan) = 'object'),
  feature_schema_version text NOT NULL,
  matrix_version text NOT NULL,
  registry_version text NOT NULL,
  policy_version text NOT NULL,
  safety_version text NOT NULL,
  data_origin text NOT NULL CHECK (data_origin IN ('REAL', 'SIMULATION_ONLY')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, client_request_id),
  CHECK (expires_at > decided_at)
);

CREATE TABLE IF NOT EXISTS inference.recommendation_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES inference.recommendation_decision(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  catalog_item_id uuid NOT NULL REFERENCES inference.recommendation_catalog_item(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type IN ('IMPRESSION', 'OPEN', 'START', 'COMPLETE', 'DISMISS')),
  occurred_at timestamptz NOT NULL,
  client_event_id text NOT NULL CHECK (length(btrim(client_event_id)) BETWEEN 1 AND 200),
  source text NOT NULL CHECK (length(btrim(source)) BETWEEN 1 AND 80),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, client_event_id)
);

CREATE TABLE IF NOT EXISTS care.health_task_instance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  decision_id uuid NOT NULL REFERENCES inference.recommendation_decision(id) ON DELETE CASCADE,
  catalog_item_id uuid NOT NULL REFERENCES inference.recommendation_catalog_item(id) ON DELETE RESTRICT,
  title_snapshot text NOT NULL,
  goal_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(goal_snapshot) = 'object'),
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'started', 'completed', 'dismissed', 'expired', 'cancelled')),
  progress numeric(6,5) NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 1),
  completed_at timestamptz,
  client_task_id text NOT NULL CHECK (length(btrim(client_task_id)) BETWEEN 1 AND 200),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, client_task_id),
  CHECK ((status = 'completed') = (completed_at IS NOT NULL)),
  CHECK (status <> 'completed' OR progress = 1)
);

CREATE INDEX IF NOT EXISTS idx_recommendation_catalog_active
  ON inference.recommendation_catalog_item(item_kind, approval_status, active_from, active_to);
CREATE INDEX IF NOT EXISTS idx_recommendation_decision_member_time
  ON inference.recommendation_decision(member_id, decided_at DESC);
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_decision_time
  ON inference.recommendation_feedback(decision_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_recommendation_feedback_member_type
  ON inference.recommendation_feedback(member_id, event_type, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_task_member_due
  ON care.health_task_instance(member_id, status, due_at);

DROP TRIGGER IF EXISTS trg_recommendation_catalog_updated_at ON inference.recommendation_catalog_item;
CREATE TRIGGER trg_recommendation_catalog_updated_at
BEFORE UPDATE ON inference.recommendation_catalog_item
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_health_task_updated_at ON care.health_task_instance;
CREATE TRIGGER trg_health_task_updated_at
BEFORE UPDATE ON care.health_task_instance
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();

ALTER TABLE inference.recommendation_catalog_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE inference.recommendation_catalog_item FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recommendation_catalog_read ON inference.recommendation_catalog_item;
CREATE POLICY recommendation_catalog_read ON inference.recommendation_catalog_item
FOR SELECT TO authenticated
USING (
  approval_status = 'APPROVED'
  AND active_from <= clock_timestamp()
  AND (active_to IS NULL OR active_to > clock_timestamp())
);

ALTER TABLE inference.recommendation_decision ENABLE ROW LEVEL SECURITY;
ALTER TABLE inference.recommendation_decision FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recommendation_decision_select ON inference.recommendation_decision;
CREATE POLICY recommendation_decision_select ON inference.recommendation_decision
FOR SELECT TO authenticated USING (cloud_db_meta.can_access_member(member_id, 'basic'));
DROP POLICY IF EXISTS recommendation_decision_insert ON inference.recommendation_decision;
CREATE POLICY recommendation_decision_insert ON inference.recommendation_decision
FOR INSERT TO authenticated WITH CHECK (cloud_db_meta.can_access_member(member_id, 'write'));

ALTER TABLE inference.recommendation_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE inference.recommendation_feedback FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recommendation_feedback_select ON inference.recommendation_feedback;
CREATE POLICY recommendation_feedback_select ON inference.recommendation_feedback
FOR SELECT TO authenticated USING (cloud_db_meta.can_access_member(member_id, 'basic'));
DROP POLICY IF EXISTS recommendation_feedback_insert ON inference.recommendation_feedback;
CREATE POLICY recommendation_feedback_insert ON inference.recommendation_feedback
FOR INSERT TO authenticated WITH CHECK (cloud_db_meta.can_access_member(member_id, 'write'));

ALTER TABLE care.health_task_instance ENABLE ROW LEVEL SECURITY;
ALTER TABLE care.health_task_instance FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS health_task_select ON care.health_task_instance;
CREATE POLICY health_task_select ON care.health_task_instance
FOR SELECT TO authenticated USING (cloud_db_meta.can_access_member(member_id, 'basic'));
DROP POLICY IF EXISTS health_task_insert ON care.health_task_instance;
CREATE POLICY health_task_insert ON care.health_task_instance
FOR INSERT TO authenticated WITH CHECK (cloud_db_meta.can_access_member(member_id, 'write'));
DROP POLICY IF EXISTS health_task_update ON care.health_task_instance;
CREATE POLICY health_task_update ON care.health_task_instance
FOR UPDATE TO authenticated
USING (cloud_db_meta.can_access_member(member_id, 'write'))
WITH CHECK (cloud_db_meta.can_access_member(member_id, 'write'));

CREATE OR REPLACE FUNCTION public.get_health_analysis_metrics(
  p_member_id uuid,
  p_as_of timestamptz
)
RETURNS TABLE (
  id uuid,
  metric_type text,
  window_start timestamptz,
  window_end timestamptz,
  status text,
  value numeric,
  unit text,
  confidence numeric,
  signal_quality numeric,
  coverage_ratio numeric,
  quality_flag text,
  conflict_flag boolean,
  abstain_reason text,
  algorithm_version text,
  input_fingerprint text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta, telemetry
AS $$
BEGIN
  IF p_as_of IS NULL OR NOT cloud_db_meta.can_access_member(p_member_id, 'basic') THEN
    RAISE EXCEPTION 'caller cannot read health-analysis metrics' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT m.id, m.metric_type, m.window_start, m.window_end, m.status, m.value,
         m.unit, m.confidence, m.signal_quality, m.coverage_ratio,
         m.quality_flag, m.conflict_flag, m.abstain_reason,
         m.algorithm_version, m.input_fingerprint
  FROM telemetry.l0_fused_metric m
  WHERE m.member_id = p_member_id AND m.window_end <= p_as_of
  ORDER BY m.window_start, m.metric_type, m.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.persist_health_analysis(p_result jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta, inference
AS $$
DECLARE
  resolved_analysis_id uuid := (p_result ->> 'analysis_id')::uuid;
  resolved_member_id uuid := (p_result ->> 'member_id')::uuid;
  resolved_model_id uuid;
  item jsonb;
  resolved_valid_from timestamptz;
BEGIN
  IF NOT cloud_db_meta.is_service() THEN
    RAISE EXCEPTION 'health analysis persistence requires service role' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_result -> 'tags') <> 'array' THEN
    RAISE EXCEPTION 'health analysis tags must be an array' USING ERRCODE = '22023';
  END IF;

  INSERT INTO inference.model_version (model_type, version)
  VALUES ('health_tag', p_result ->> 'model_version')
  ON CONFLICT (model_type, version) DO UPDATE SET version = EXCLUDED.version
  RETURNING id INTO resolved_model_id;

  FOR item IN SELECT value FROM jsonb_array_elements(p_result -> 'tags')
  LOOP
    resolved_valid_from := (item ->> 'valid_from')::timestamptz;
    UPDATE inference.health_tag
    SET valid_to = resolved_valid_from
    WHERE member_id = resolved_member_id
      AND tag_key = item ->> 'tag_key'
      AND valid_to IS NULL
      AND valid_from < resolved_valid_from;

    INSERT INTO inference.health_tag (
      member_id, tag_type, tag_key, tag_value, weight, confidence, source,
      model_version_id, valid_from, valid_to, analysis_id, policy_version,
      input_fingerprint, evidence, demo_baseline
    ) VALUES (
      resolved_member_id, item ->> 'tag_type', item ->> 'tag_key', item -> 'tag_value',
      (item ->> 'weight')::numeric, (item ->> 'confidence')::numeric,
      item ->> 'source', resolved_model_id, resolved_valid_from,
      nullif(item ->> 'valid_to', '')::timestamptz, resolved_analysis_id,
      p_result ->> 'policy_version', item ->> 'input_fingerprint',
      coalesce(item -> 'evidence', '{}'::jsonb),
      coalesce((item ->> 'demo_baseline')::boolean, false)
    ) ON CONFLICT DO NOTHING;
  END LOOP;
  RETURN resolved_analysis_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_recommendation_context(
  p_member_id uuid,
  p_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta, core, inference, security, medical
AS $$
DECLARE
  result jsonb;
BEGIN
  IF p_at IS NULL OR NOT cloud_db_meta.can_access_member(p_member_id, 'basic') THEN
    RAISE EXCEPTION 'caller cannot read recommendation context' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'member_id', p_member_id,
    'age_group', fm.age_group,
    'tags', coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.tag_key)
      FROM inference.health_tag t
      WHERE t.member_id = p_member_id AND t.valid_from <= p_at
        AND (t.valid_to IS NULL OR t.valid_to > p_at)), '[]'::jsonb),
    'consent_scopes', coalesce((SELECT jsonb_agg(DISTINCT scope)
      FROM security.consent c CROSS JOIN LATERAL unnest(c.auth_scope) scope
      WHERE c.subject_member_id = p_member_id AND c.status = 'active'
        AND (c.expires_at IS NULL OR c.expires_at > p_at)), '[]'::jsonb),
    'verified_diagnosis', EXISTS (SELECT 1 FROM medical.clinical_entity e
      JOIN medical.medical_record_ocr r ON r.id = e.record_id
      WHERE e.member_id = p_member_id AND e.entity_type = 'diagnosis' AND r.status = 'verified'),
    'verified_plan', EXISTS (SELECT 1 FROM medical.medication_plan p
      WHERE p.member_id = p_member_id AND p.status = 'active'),
    'verified_plan_id', (SELECT p.id FROM medical.medication_plan p
      WHERE p.member_id = p_member_id AND p.status = 'active'
      ORDER BY p.start_at DESC, p.id LIMIT 1),
    'checkup_due', fm.age_group = 'adult' AND NOT EXISTS (
      SELECT 1 FROM medical.medical_record_ocr r
      WHERE r.member_id = p_member_id AND r.status = 'verified'
        AND r.doc_type = 'physical_exam'
        AND r.document_date >= (p_at AT TIME ZONE 'UTC')::date - 365
    ),
    'care_escalation', EXISTS (SELECT 1 FROM inference.health_event h
      WHERE h.member_id = p_member_id AND h.severity IN ('orange', 'red')
        AND h.start_at <= p_at AND (h.end_at IS NULL OR h.end_at > p_at)
        AND NOT h.suppressed AND h.quality_gate = 'passed'),
    'catalog_items', coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY i.intent_code)
      FROM inference.recommendation_catalog_item i
      WHERE i.approval_status = 'APPROVED'
        AND i.active_from <= p_at
        AND (i.active_to IS NULL OR i.active_to > p_at)), '[]'::jsonb)
  ) INTO result
  FROM core.family_member fm WHERE fm.id = p_member_id;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.persist_recommendation_decision(p_decision jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta, inference, care
AS $$
DECLARE
  resolved_id uuid;
  resolved_member_id uuid := (p_decision ->> 'member_id')::uuid;
  item jsonb;
  catalog_id uuid;
BEGIN
  IF NOT cloud_db_meta.can_access_member(resolved_member_id, 'write') THEN
    RAISE EXCEPTION 'caller cannot write recommendation decision' USING ERRCODE = '42501';
  END IF;
  INSERT INTO inference.recommendation_decision (
    member_id, client_request_id, surface, decided_at, expires_at,
    context_snapshot, health_tag_snapshot, candidate_snapshot, final_plan,
    feature_schema_version, matrix_version, registry_version, policy_version,
    safety_version, data_origin
  ) VALUES (
    resolved_member_id, p_decision ->> 'client_request_id', p_decision ->> 'surface',
    (p_decision ->> 'decided_at')::timestamptz, (p_decision ->> 'expires_at')::timestamptz,
    p_decision -> 'context_snapshot', p_decision -> 'health_tag_snapshot',
    p_decision -> 'candidate_snapshot', p_decision -> 'final_plan',
    p_decision ->> 'feature_schema_version', p_decision ->> 'matrix_version',
    p_decision ->> 'registry_version', p_decision ->> 'policy_version',
    p_decision ->> 'safety_version', p_decision ->> 'data_origin'
  ) ON CONFLICT (member_id, client_request_id) DO UPDATE
    SET client_request_id = EXCLUDED.client_request_id
  RETURNING id INTO resolved_id;

  FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p_decision #> '{final_plan,items}', '[]'::jsonb))
  LOOP
    IF item ->> 'item_kind' = 'TASK' THEN
      catalog_id := (item ->> 'catalog_item_id')::uuid;
      INSERT INTO care.health_task_instance (
        member_id, decision_id, catalog_item_id, title_snapshot, goal_snapshot,
        due_at, client_task_id
      ) VALUES (
        resolved_member_id, resolved_id, catalog_id, item ->> 'title',
        coalesce(item -> 'task' -> 'goal', '{}'::jsonb),
        (item -> 'task' ->> 'due_at')::timestamptz,
        coalesce(item -> 'task' ->> 'client_task_id', resolved_id::text || ':' || catalog_id::text)
      ) ON CONFLICT (member_id, client_task_id) DO NOTHING;
    END IF;
  END LOOP;
  RETURN resolved_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_recommendation_event(
  p_decision_id uuid,
  p_member_id uuid,
  p_catalog_item_id uuid,
  p_event_type text,
  p_occurred_at timestamptz,
  p_client_event_id text,
  p_source text DEFAULT 'app',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta, inference
AS $$
DECLARE
  result_id uuid;
BEGIN
  IF NOT cloud_db_meta.can_access_member(p_member_id, 'write') THEN
    RAISE EXCEPTION 'caller cannot write recommendation event' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM inference.recommendation_decision d
    WHERE d.id = p_decision_id AND d.member_id = p_member_id
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(coalesce(d.final_plan -> 'items', '[]'::jsonb)) item
        WHERE item ->> 'catalog_item_id' = p_catalog_item_id::text
      )
  ) THEN
    RAISE EXCEPTION 'event item is not part of the member decision' USING ERRCODE = '23514';
  END IF;
  INSERT INTO inference.recommendation_feedback (
    decision_id, member_id, catalog_item_id, event_type, occurred_at,
    client_event_id, source, metadata
  ) VALUES (
    p_decision_id, p_member_id, p_catalog_item_id, p_event_type, p_occurred_at,
    p_client_event_id, p_source, p_metadata
  ) ON CONFLICT (member_id, client_event_id) DO UPDATE
    SET client_event_id = EXCLUDED.client_event_id
  RETURNING id INTO result_id;
  RETURN result_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_health_tasks_for_decision(p_decision_id uuid)
RETURNS TABLE (
  id uuid,
  catalog_item_id uuid,
  client_task_id text,
  status text,
  progress numeric,
  due_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta, care, inference
AS $$
DECLARE
  resolved_member_id uuid;
BEGIN
  SELECT d.member_id INTO resolved_member_id
  FROM inference.recommendation_decision d WHERE d.id = p_decision_id;
  IF resolved_member_id IS NULL OR NOT cloud_db_meta.can_access_member(resolved_member_id, 'basic') THEN
    RAISE EXCEPTION 'caller cannot read health tasks' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT t.id, t.catalog_item_id, t.client_task_id, t.status, t.progress, t.due_at
  FROM care.health_task_instance t
  WHERE t.decision_id = p_decision_id
  ORDER BY t.created_at, t.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_health_task(
  p_task_id uuid,
  p_status text,
  p_progress numeric,
  p_client_event_id text,
  p_occurred_at timestamptz DEFAULT clock_timestamp()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta, care, inference
AS $$
DECLARE
  task care.health_task_instance%ROWTYPE;
BEGIN
  SELECT * INTO task FROM care.health_task_instance WHERE id = p_task_id;
  IF task.id IS NULL OR NOT cloud_db_meta.can_access_member(task.member_id, 'write') THEN
    RAISE EXCEPTION 'caller cannot update health task' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM inference.recommendation_feedback
             WHERE member_id = task.member_id AND client_event_id = p_client_event_id) THEN
    RETURN task.id;
  END IF;
  IF task.status IN ('completed', 'dismissed', 'expired', 'cancelled') THEN
    RAISE EXCEPTION 'terminal health task cannot transition' USING ERRCODE = '23514';
  END IF;
  IF p_status NOT IN ('started', 'completed', 'dismissed', 'cancelled')
     OR (task.status = 'started' AND p_status = 'started') THEN
    RAISE EXCEPTION 'invalid health task transition' USING ERRCODE = '23514';
  END IF;
  UPDATE care.health_task_instance
  SET status = p_status,
      progress = p_progress,
      completed_at = CASE WHEN p_status = 'completed' THEN p_occurred_at ELSE NULL END
  WHERE id = p_task_id;
  INSERT INTO inference.recommendation_feedback (
    decision_id, member_id, catalog_item_id, event_type, occurred_at,
    client_event_id, source, metadata
  ) VALUES (
    task.decision_id, task.member_id, task.catalog_item_id,
    CASE p_status WHEN 'started' THEN 'START' WHEN 'completed' THEN 'COMPLETE' ELSE 'DISMISS' END,
    p_occurred_at, p_client_event_id, 'app', jsonb_build_object('progress', p_progress)
  );
  RETURN task.id;
END;
$$;

REVOKE ALL ON TABLE inference.recommendation_catalog_item,
  inference.recommendation_decision, inference.recommendation_feedback,
  care.health_task_instance FROM PUBLIC;
GRANT SELECT ON inference.recommendation_catalog_item TO authenticated;
GRANT SELECT, INSERT ON inference.recommendation_decision,
  inference.recommendation_feedback TO authenticated;
GRANT SELECT, INSERT, UPDATE ON care.health_task_instance TO authenticated;
GRANT ALL ON inference.recommendation_catalog_item,
  inference.recommendation_decision, inference.recommendation_feedback,
  care.health_task_instance TO service_role;

REVOKE ALL ON FUNCTION public.get_health_analysis_metrics(uuid, timestamptz),
  public.persist_health_analysis(jsonb), public.get_recommendation_context(uuid, timestamptz),
  public.persist_recommendation_decision(jsonb),
  public.record_recommendation_event(uuid, uuid, uuid, text, timestamptz, text, text, jsonb),
  public.get_health_tasks_for_decision(uuid),
  public.update_health_task(uuid, text, numeric, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_health_analysis_metrics(uuid, timestamptz),
  public.get_recommendation_context(uuid, timestamptz),
  public.persist_recommendation_decision(jsonb),
  public.record_recommendation_event(uuid, uuid, uuid, text, timestamptz, text, text, jsonb),
  public.get_health_tasks_for_decision(uuid),
  public.update_health_task(uuid, text, numeric, text, timestamptz) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.persist_health_analysis(jsonb) TO service_role;

COMMIT;
