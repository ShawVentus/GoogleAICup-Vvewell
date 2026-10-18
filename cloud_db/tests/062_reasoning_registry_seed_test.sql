BEGIN;

SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.metric_definition WHERE version = 'metric-catalog-1.0.0') = 10,
  'WP2 metric matrix must be registered in the database'
);
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.feature_definition WHERE version IN ('r1-1.0.0', 'r2-signal-features-1.0.0', 'multimodal-fusion-input-0.1.0')) = 11,
  'WP2 feature registry must be registered in the database'
);
SELECT cloud_db_test.assert_true(
  (SELECT algorithm_family FROM inference.feature_definition WHERE feature_code = 'multimodal_fusion_token') = 'feature_fusion',
  'Multimodal fusion input must not be mislabeled as a trained deep model'
);
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.evidence_profile WHERE evidence_code LIKE '%-V1' OR evidence_code = 'R3-SCENE-RULES-V0-3') >= 5,
  'WP2 evidence profiles must be registered in the database'
);
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.model_version WHERE model_type IN ('reasoning_r1', 'signal_features_r2', 'scene_rules_r3', 'multimodal_fusion_input')) = 4,
  'WP2 model and input-contract versions must be registered in the database'
);
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.research_backlog WHERE owner_role = '数据 Reasoning 与场景算法负责人 @ yeye') = 20,
  'WP2 Research Backlog must be registered in the database'
);

ROLLBACK;
