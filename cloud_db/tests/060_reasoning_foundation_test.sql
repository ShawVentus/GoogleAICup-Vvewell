BEGIN;

INSERT INTO core.users (id, auth_uid, username)
VALUES
  ('10000000-0000-0000-0000-000000000060', '11000000-0000-0000-0000-000000000060', 'reasoning-owner'),
  ('10000000-0000-0000-0000-000000000061', '11000000-0000-0000-0000-000000000061', 'reasoning-outsider');
INSERT INTO core.families (id, owner_user_id, name)
VALUES ('20000000-0000-0000-0000-000000000060', '10000000-0000-0000-0000-000000000060', 'Reasoning Family');
INSERT INTO core.family_member (id, family_id, member_user_id, role, display_name, relation, age_group)
VALUES (
  '30000000-0000-0000-0000-000000000060', '20000000-0000-0000-0000-000000000060',
  '10000000-0000-0000-0000-000000000060', 'admin', 'Reasoning Owner', 'self', 'adult'
);
INSERT INTO inference.model_version (id, model_type, version, parameter_hash)
VALUES ('60000000-0000-0000-0000-000000000060', 'reasoning_r1', 'r1-1.0.0', repeat('c', 64));

INSERT INTO inference.metric_definition (
  metric_code, display_name, description, canonical_unit, native_resolution_seconds,
  market_measurable, source_types, scenario_types, reference_standard,
  evidence_grade, maturity, version
) VALUES (
  'resting_heart_rate', 'Resting heart rate', 'Personal-baseline resting heart rate.',
  'bpm', 86400, true, ARRAY['alloop_ring'], ARRAY['recovery'],
  'Device SDK plus personal baseline', 'D', 'provisional', '1.0.0'
);
INSERT INTO inference.feature_definition (
  feature_code, metric_code, display_name, description, input_modalities,
  output_unit, window_seconds, algorithm_family, evidence_grade, maturity, version
) VALUES (
  'robust_z_14d', 'resting_heart_rate', '14-day robust z',
  'Median/MAD standardized deviation.', ARRAY['sdk_metric'], 'z', 1209600,
  'robust_statistics', 'D', 'provisional', '1.0.0'
);
INSERT INTO inference.evidence_profile (
  id, evidence_code, title, evidence_grade, evidence_type, summary, limitations
) VALUES (
  '61000000-0000-0000-0000-000000000060', 'R1-RULES-TEST-V1', 'R1 engineering evidence',
  'E', 'synthetic', 'Deterministic contract and rejection-path evidence.',
  ARRAY['Not clinical validation', 'Synthetic fixture only']
);

INSERT INTO inference.algorithm_output (
  id, member_id, output_type, state_value, status, lifecycle, probability, interval,
  source_observation_ids, source_summary, window_start, window_end,
  native_resolution_seconds, sqi, coverage_ratio, plausibility, context_fitness,
  overall_quality, uncertainty, evidence_grade, evidence_profile_ids, evidence_refs,
  algorithm_version, model_version_id, abstain_reason, data_origin, input_fingerprint
) VALUES (
  '62000000-0000-0000-0000-000000000060',
  '30000000-0000-0000-0000-000000000060', 'heart_rate_state',
  '{"state":"BASELINE_STABLE","value":72,"unit":"bpm"}', 'AVAILABLE', 'provisional',
  0.85, '{"lower":68,"upper":76,"method":"median_mad"}',
  ARRAY['63000000-0000-0000-0000-000000000060'::uuid],
  '[{"source":"alloop_ring","metric":"heart_rate"}]',
  '2026-08-01 00:00:00+00', '2026-08-03 00:00:00+00', 86400,
  0.9, 0.85, 0.95, 1.0, 0.72675,
  '{"method":"rule_margin","value":0.15}', 'E',
  ARRAY['61000000-0000-0000-0000-000000000060'::uuid],
  '[{"kind":"rule","ref":"rule://r1/robust-baseline-v1"}]',
  'r1-1.0.0', '60000000-0000-0000-0000-000000000060', NULL,
  'SYNTHETIC_MOCK', repeat('d', 64)
);

INSERT INTO inference.algorithm_output (
  member_id, output_type, state_value, status, lifecycle, probability, interval,
  source_observation_ids, source_summary, window_start, window_end,
  native_resolution_seconds, sqi, coverage_ratio, plausibility, context_fitness,
  overall_quality, uncertainty, evidence_grade, evidence_refs, algorithm_version,
  abstain_reason, data_origin, input_fingerprint
) VALUES (
  '30000000-0000-0000-0000-000000000060', 'respiratory_rate_state', NULL,
  'ABSTAINED', 'research', NULL, NULL,
  ARRAY['63000000-0000-0000-0000-000000000061'::uuid],
  '[{"source":"alloop_ring","metric":"respiratory_rate"}]',
  '2026-08-01 00:00:00+00', '2026-08-03 00:00:00+00', 86400,
  0.2, 0.3, 0.8, 1.0, 0.048,
  '{"method":"quality_gate","dominant_reason":"LOW_SQI"}', 'E',
  '[{"kind":"quality_gate","ref":"rule://r1/sqi-v1"}]', 'r1-1.0.0',
  'LOW_SQI', 'SYNTHETIC_MOCK', repeat('e', 64)
);

SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.algorithm_output WHERE member_id = '30000000-0000-0000-0000-000000000060') = 2,
  'AlgorithmOutput must persist available and abstained states'
);
SELECT cloud_db_test.expect_sqlstate(
  $$UPDATE inference.algorithm_output SET algorithm_version = 'tampered' WHERE id = '62000000-0000-0000-0000-000000000060'$$,
  '55000', 'AlgorithmOutput must be immutable'
);
SELECT cloud_db_test.expect_sqlstate(
  $$INSERT INTO inference.validation_run (
      run_code, algorithm_version, scenario_type, dataset_origin, split_strategy,
      subject_count, is_publishable, executed_at
    ) VALUES ('invalid-synthetic-publication', 'r1-1.0.0', 'r1', 'SYNTHETIC_MOCK',
      'engineering_replay', 10, true, clock_timestamp())$$,
  '23514', 'Synthetic validation must never be publishable evidence'
);

SELECT set_config('request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000060","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.algorithm_output) = 2,
  'member owner must read AlgorithmOutput rows'
);
RESET ROLE;

SELECT set_config('request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000061","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.algorithm_output) = 0,
  'outsider must not read AlgorithmOutput rows'
);
RESET ROLE;

ROLLBACK;
