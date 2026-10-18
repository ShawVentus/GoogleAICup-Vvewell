BEGIN;

INSERT INTO core.users (id, auth_uid, username) VALUES
  ('91000000-0000-0000-0000-000000000001', '91100000-0000-0000-0000-000000000001', 'phone-sync-owner'),
  ('91000000-0000-0000-0000-000000000002', '91100000-0000-0000-0000-000000000002', 'phone-sync-outsider');
INSERT INTO core.families (id, owner_user_id, name) VALUES
  ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'Phone Sync Family');
INSERT INTO core.family_member (
  id, family_id, member_user_id, role, display_name, relation, age_group
) VALUES (
  '93000000-0000-0000-0000-000000000001',
  '92000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000001',
  'admin', 'Phone Sync Owner', 'self', 'adult'
);

SELECT set_config('request.jwt.claims',
  '{"sub":"91100000-0000-0000-0000-000000000001","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT cloud_db_test.assert_true(
  public.get_phone_analysis_context(
    '93000000-0000-0000-0000-000000000001', clock_timestamp()
  ) ?& ARRAY['context_version','expires_at','catalog_items','consent_scopes'],
  'phone context must include version, expiry, catalog, and consent scopes');

DO $$
DECLARE
  member_id uuid := '93000000-0000-0000-0000-000000000001';
  run_id uuid := '94000000-0000-4000-8000-000000000001';
  fused_id uuid := '94000000-0000-4000-8000-000000000002';
  tag_id uuid := '94000000-0000-4000-8000-000000000003';
  decision_id uuid := '94000000-0000-4000-8000-000000000004';
  task_id uuid := '94000000-0000-4000-8000-000000000005';
  bundle jsonb;
  first_result jsonb;
  replay_result jsonb;
BEGIN
  bundle := jsonb_build_object('items', jsonb_build_array(
    jsonb_build_object(
      'outbox_id', 1, 'entity_type', 'FUSED_METRIC', 'local_id', fused_id,
      'payload_hash', repeat('1',64), 'payload', jsonb_build_object(
        'metric_type','heart_rate','window_start',clock_timestamp() - interval '1 minute',
        'window_end',clock_timestamp(),'status','AVAILABLE','value',72,'unit','bpm',
        'confidence',.9,'signal_quality',.9,'coverage_ratio',1,
        'coverage_mask','{"alloop_ring":true}'::jsonb,'quality_flag','good',
        'conflict_flag',false,'interval_lower',70,'interval_upper',74,
        'contributing_sources',jsonb_build_array('alloop_ring'),'wear_state','WORN_GOOD',
        'abstain_reason',NULL,'algorithm_version','l0-adaptive-kalman-v1',
        'input_fingerprint',repeat('2',64),'evidence','{}'::jsonb,'data_origin','REAL')),
    jsonb_build_object(
      'outbox_id', 2, 'entity_type', 'ANALYSIS_RUN', 'local_id', run_id,
      'payload_hash', repeat('3',64), 'payload', jsonb_build_object(
        'analysis_id',run_id,'member_id',member_id,'as_of',clock_timestamp(),
        'input_count',1,'accepted_count',1,'model_version','river-health-stream-dart-v1',
        'policy_version','health-tag-policy-v1','input_fingerprint',repeat('4',64),
        'tags','[]'::jsonb,'data_origin','REAL')),
    jsonb_build_object(
      'outbox_id', 3, 'entity_type', 'HEALTH_TAG', 'local_id', tag_id,
      'payload_hash', repeat('5',64), 'payload', jsonb_build_object(
        'analysis_id',run_id,'tag_type','state','tag_key','data_insufficient',
        'tag_value','{"active":true}'::jsonb,'weight',1,'confidence',1,
        'source','river-health-stream-dart-v1','valid_from',clock_timestamp(),
        'valid_to',clock_timestamp() + interval '2 hours','input_fingerprint',repeat('6',64),
        'evidence','{}'::jsonb,'demo_baseline',false,'data_origin','REAL')),
    jsonb_build_object(
      'outbox_id', 4, 'entity_type', 'DECISION', 'local_id', decision_id,
      'payload_hash', repeat('7',64), 'payload', jsonb_build_object(
        'id',decision_id,'member_id',member_id,'client_request_id','phone-request-1',
        'surface','health_home','decided_at',clock_timestamp(),
        'expires_at',clock_timestamp() + interval '24 hours',
        'context_snapshot',jsonb_build_object('context_expires_at',clock_timestamp() + interval '1 hour'),
        'health_tag_snapshot','[]'::jsonb,'candidate_snapshot','[]'::jsonb,
        'final_plan',jsonb_build_object('status','READY','items',jsonb_build_array(jsonb_build_object(
          'catalog_item_id','95000000-0000-4000-8000-000000000001','item_kind','TASK'))),
        'feature_schema_version','health-tag-feature-schema-v2',
        'matrix_version','recommendation-affinity-matrix-v2',
        'registry_version','recommendation-intent-registry-v2',
        'policy_version','recommendation-policy-dart-v2',
        'safety_version','recommendation-safety-v2','data_origin','REAL')),
    jsonb_build_object(
      'outbox_id', 5, 'entity_type', 'TASK', 'local_id', task_id,
      'payload_hash', repeat('8',64), 'payload', jsonb_build_object(
        'id',task_id,'decision_id',decision_id,
        'catalog_item_id','95000000-0000-4000-8000-000000000001',
        'title_snapshot','Five-minute breathing task','goal_snapshot','{"type":"boolean","target":1}'::jsonb,
        'due_at',clock_timestamp() + interval '1 day','status','pending','progress',0,
        'client_task_id','phone-task-1')),
    jsonb_build_object(
      'outbox_id', 6, 'entity_type', 'TASK', 'local_id', task_id,
      'payload_hash', repeat('9',64), 'payload', jsonb_build_object(
        'id',task_id,'decision_id',decision_id,
        'catalog_item_id','95000000-0000-4000-8000-000000000001',
        'status','completed','progress',1,'updated_at',clock_timestamp())),
    jsonb_build_object(
      'outbox_id', 7, 'entity_type', 'FEEDBACK',
      'local_id','94000000-0000-4000-8000-000000000006',
      'payload_hash', repeat('a',64), 'payload', jsonb_build_object(
        'id','94000000-0000-4000-8000-000000000006','decision_id',decision_id,
        'catalog_item_id','95000000-0000-4000-8000-000000000001',
        'event_type','COMPLETE','occurred_at',clock_timestamp(),
        'client_event_id','phone-task-complete-1','source','flutter_home_local','metadata','{}'::jsonb))
  ));
  first_result := public.sync_phone_analysis_bundle(member_id, bundle);
  replay_result := public.sync_phone_analysis_bundle(member_id, bundle);
  PERFORM cloud_db_test.assert_true((first_result ->> 'count')::integer = 7,
    'phone sync must acknowledge every artifact');
  PERFORM cloud_db_test.assert_true(
    NOT EXISTS (SELECT 1 FROM jsonb_array_elements(first_result -> 'acks') ack
                WHERE ack ->> 'status' = 'REJECTED'),
    'valid phone artifacts must not be rejected');
  PERFORM cloud_db_test.assert_true((replay_result ->> 'count')::integer = 7,
    'phone sync replay must return the same acknowledgements');
  PERFORM cloud_db_test.assert_true(
    (SELECT count(*) FROM inference.phone_analysis_run WHERE id = run_id) = 1
    AND (SELECT count(*) FROM telemetry.l0_fused_metric WHERE id = fused_id) = 1
    AND (SELECT count(*) FROM inference.health_tag WHERE id = tag_id) = 1
    AND (SELECT count(*) FROM inference.recommendation_decision WHERE id = decision_id) = 1
    AND (SELECT count(*) FROM care.health_task_instance WHERE id = task_id AND status = 'completed') = 1
    AND (SELECT count(*) FROM inference.recommendation_feedback
         WHERE client_event_id = 'phone-task-complete-1') = 1,
    'phone sync replay must be idempotent');
END;
$$;
RESET ROLE;

SELECT set_config('request.jwt.claims',
  '{"sub":"91100000-0000-0000-0000-000000000002","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true((SELECT count(*) FROM inference.phone_analysis_run) = 0,
  'outsider must not read phone analysis runs');
SELECT cloud_db_test.expect_sqlstate(
  $$SELECT public.get_phone_analysis_context(
    '93000000-0000-0000-0000-000000000001', clock_timestamp())$$,
  '42501', 'outsider must not read phone analysis context');
SELECT cloud_db_test.expect_sqlstate(
  $$SELECT public.sync_phone_analysis_bundle(
    '93000000-0000-0000-0000-000000000001', '{"items":[]}'::jsonb)$$,
  '42501', 'outsider must not upload phone analysis artifacts');
RESET ROLE;

ROLLBACK;
