BEGIN;

INSERT INTO core.users (id, auth_uid, username) VALUES
  ('81000000-0000-0000-0000-000000000001', '81100000-0000-0000-0000-000000000001', 'recommend-owner'),
  ('81000000-0000-0000-0000-000000000002', '81100000-0000-0000-0000-000000000002', 'recommend-outsider');
INSERT INTO core.families (id, owner_user_id, name) VALUES
  ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'Recommendation Family');
INSERT INTO core.family_member (
  id, family_id, member_user_id, role, display_name, relation, age_group
) VALUES (
  '83000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000001',
  'admin', 'Recommendation Owner', 'self', 'adult'
);
INSERT INTO telemetry.l0_fused_metric (
  id, member_id, metric_type, window_start, window_end, status, value, unit,
  confidence, signal_quality, coverage_ratio, coverage_mask, quality_flag,
  conflict_flag, interval_lower, interval_upper, contributing_sources,
  age_group, algorithm_version, input_fingerprint, evidence
) VALUES (
  '84000000-0000-0000-0000-000000000001',
  '83000000-0000-0000-0000-000000000001', 'heart_rate',
  '2026-08-03 01:00:00+00', '2026-08-03 01:01:00+00', 'AVAILABLE', 72, 'bpm',
  .9, .9, 1, '{"rppg_phone":true}', 'good', false, 71, 73,
  ARRAY['rppg_phone'], 'adult', 'l0-adaptive-kalman-v1', repeat('1',64), '{}'
);
INSERT INTO inference.recommendation_catalog_item (
  id, intent_code, item_kind, title, description, presentation_category,
  content_version, target_tag_keys, consent_scope, safety_constraints,
  commercial_disclosure, resolver_metadata, data_origin, approval_status, active_from
) VALUES
  ('85000000-0000-0000-0000-000000000001', 'TEST.TASK.BREATH.SHORT', 'TASK',
   'Five minute breathing task', 'A short general-wellness breathing task.',
   'wellness', '1', ARRAY['relative_hr_elevated'], ARRAY[]::text[], '{}', NULL,
   '{"duration_minutes":5}', 'REAL', 'APPROVED', '2026-01-01'),
  ('85000000-0000-0000-0000-000000000002', 'TEST.GOODS.MEASUREMENT_HARDWARE', 'GOODS',
   'Measurement hardware options', 'Review compatible measurement hardware.',
   'hardware', '1', ARRAY['low_data_coverage'], ARRAY['commercial_recommendation'], '{}',
   'Commercial recommendation; availability and pricing may change.', '{}',
   'REAL', 'APPROVED', '2026-01-01'),
  ('85000000-0000-0000-0000-000000000003', 'DRAFT.HIDDEN', 'ADVICE',
   'Hidden draft', 'Must not be visible to authenticated users.', 'wellness', '1',
   ARRAY[]::text[], ARRAY[]::text[], '{}', NULL, '{}', 'SIMULATION_ONLY', 'DRAFT', '2026-01-01');

SELECT set_config('request.jwt.claims',
  '{"sub":"81100000-0000-0000-0000-000000000001","role":"service_role"}', true);
SET LOCAL ROLE service_role;
SELECT public.persist_health_analysis(jsonb_build_object(
  'analysis_id', '86000000-0000-0000-0000-000000000001',
  'member_id', '83000000-0000-0000-0000-000000000001',
  'model_version', 'river-health-stream-v1', 'policy_version', 'health-tag-policy-v1',
  'tags', jsonb_build_array(jsonb_build_object(
    'tag_type', 'state', 'tag_key', 'relative_hr_elevated',
    'tag_value', '{"active":true,"deviation":1.8}'::jsonb,
    'weight', .8, 'confidence', .8, 'source', 'river-health-stream-v1',
    'valid_from', '2026-08-03T01:01:00+00', 'valid_to', '2026-08-03T03:01:00+00',
    'input_fingerprint', repeat('2',64), 'evidence', '{}'::jsonb, 'demo_baseline', true
  ))
));
SELECT public.persist_health_analysis(jsonb_build_object(
  'analysis_id', '86000000-0000-0000-0000-000000000001',
  'member_id', '83000000-0000-0000-0000-000000000001',
  'model_version', 'river-health-stream-v1', 'policy_version', 'health-tag-policy-v1',
  'tags', jsonb_build_array(jsonb_build_object(
    'tag_type', 'state', 'tag_key', 'relative_hr_elevated',
    'tag_value', '{"active":true,"deviation":1.8}'::jsonb,
    'weight', .8, 'confidence', .8, 'source', 'river-health-stream-v1',
    'valid_from', '2026-08-03T01:01:00+00', 'valid_to', '2026-08-03T03:01:00+00',
    'input_fingerprint', repeat('2',64), 'evidence', '{}'::jsonb, 'demo_baseline', true
  ))
));
RESET ROLE;
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.health_tag WHERE member_id = '83000000-0000-0000-0000-000000000001') = 1,
  'health analysis replay must be idempotent');

SELECT set_config('request.jwt.claims',
  '{"sub":"81100000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM public.get_health_analysis_metrics(
    '83000000-0000-0000-0000-000000000001', '2026-08-03 02:00:00+00')) = 1,
  'owner must read fused metrics for analysis');
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.recommendation_catalog_item) = 15,
  'authenticated catalog must expose approved seeded and fixture content but hide drafts');
SELECT cloud_db_test.assert_true(
  public.get_recommendation_context(
    '83000000-0000-0000-0000-000000000001', '2026-08-03 02:00:00+00'
  ) -> 'tags' @> '[{"tag_key":"relative_hr_elevated"}]'::jsonb,
  'context must contain active tags');

DO $$
DECLARE
  resolved_decision_id uuid;
  replay_id uuid;
  event_id uuid;
  replay_event_id uuid;
  task_id uuid;
  decision jsonb := jsonb_build_object(
    'member_id', '83000000-0000-0000-0000-000000000001',
    'client_request_id', 'recommend-request-1', 'surface', 'health_home',
    'decided_at', '2026-08-03T02:00:00+00', 'expires_at', '2026-08-03T06:00:00+00',
    'context_snapshot', '{}'::jsonb, 'health_tag_snapshot', '[]'::jsonb,
    'candidate_snapshot', '[]'::jsonb,
    'final_plan', jsonb_build_object('items', jsonb_build_array(jsonb_build_object(
      'catalog_item_id', '85000000-0000-0000-0000-000000000001',
      'item_kind', 'TASK', 'title', 'Five minute breathing task',
      'task', jsonb_build_object('due_at', '2026-08-03T05:00:00+00',
        'client_task_id', 'breathing-task-1', 'goal', '{"type":"boolean"}'::jsonb)))),
    'feature_schema_version', 'health-tag-feature-schema-v2',
    'matrix_version', 'recommendation-affinity-matrix-v2',
    'registry_version', 'recommendation-intent-registry-v2',
    'policy_version', 'recommendation-policy-v2', 'safety_version', 'safety-v1',
    'data_origin', 'REAL');
BEGIN
  resolved_decision_id := public.persist_recommendation_decision(decision);
  replay_id := public.persist_recommendation_decision(decision);
  PERFORM cloud_db_test.assert_true(resolved_decision_id = replay_id, 'decision replay must be idempotent');
  SELECT t.id INTO task_id
  FROM care.health_task_instance t
  WHERE t.decision_id = resolved_decision_id;
  PERFORM cloud_db_test.assert_true(task_id IS NOT NULL, 'task plan must create a task');
  event_id := public.record_recommendation_event(
    resolved_decision_id, '83000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000001', 'IMPRESSION',
    '2026-08-03 02:00:01+00', 'recommend-event-1');
  replay_event_id := public.record_recommendation_event(
    resolved_decision_id, '83000000-0000-0000-0000-000000000001',
    '85000000-0000-0000-0000-000000000001', 'IMPRESSION',
    '2026-08-03 02:00:01+00', 'recommend-event-1');
  PERFORM cloud_db_test.assert_true(event_id = replay_event_id, 'event replay must be idempotent');
  PERFORM public.update_health_task(task_id, 'completed', 1, 'task-complete-1', '2026-08-03 02:05:00+00');
  PERFORM public.update_health_task(task_id, 'completed', 1, 'task-complete-1', '2026-08-03 02:05:00+00');
  PERFORM cloud_db_test.assert_true(
    (SELECT status = 'completed' AND progress = 1 FROM care.health_task_instance WHERE id = task_id),
    'task completion must be persisted');
END;
$$;
RESET ROLE;

SELECT set_config('request.jwt.claims',
  '{"sub":"81100000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true((SELECT count(*) FROM inference.recommendation_decision) = 0,
  'outsider must not read recommendation decisions');
SELECT cloud_db_test.assert_true((SELECT count(*) FROM care.health_task_instance) = 0,
  'outsider must not read health tasks');
SELECT cloud_db_test.expect_sqlstate(
  $$SELECT public.get_recommendation_context(
    '83000000-0000-0000-0000-000000000001', '2026-08-03 02:00:00+00')$$,
  '42501', 'outsider must not read recommendation context');
RESET ROLE;

ROLLBACK;
