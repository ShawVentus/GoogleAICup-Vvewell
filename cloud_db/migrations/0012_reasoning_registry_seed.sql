BEGIN;

-- The original feature catalog predates WP2 feature-level fusion.  Keep the
-- existing taxonomy and add the explicit family instead of overloading a
-- trained deep-learning label onto a versioned model-input contract.
ALTER TABLE inference.feature_definition
  DROP CONSTRAINT IF EXISTS feature_definition_algorithm_family_check;
ALTER TABLE inference.feature_definition
  ADD CONSTRAINT feature_definition_algorithm_family_check CHECK (algorithm_family IN (
    'rule', 'robust_statistics', 'signal_processing', 'feature_fusion', 'gam_ebm',
    'mixed_effects', 'hmm', 'xgboost', 'deep_learning'
  ));

-- These registry rows are product/research metadata only.  They do not assert
-- clinical performance and deliberately preserve the synthetic/unlabelled
-- evidence boundaries documented by the WP2 service.
INSERT INTO inference.metric_definition (
  metric_code, display_name, description, canonical_unit, native_resolution_seconds,
  market_measurable, source_types, scenario_types, reference_standard,
  evidence_grade, maturity, version, data_requirements
) VALUES
  ('heart_rate', 'Heart rate', 'Quality-gated personal heart-rate trend.', 'bpm', 60,
   true, ARRAY['alloop_ring','aizo_ring','rppg_phone','mmwave_radar'],
   ARRAY['recovery_state','relative_physiological_load'], 'ECG reference when validating',
   'D', 'provisional', 'metric-catalog-1.0.0',
   '{"current_data":"SDK synthetic fixture plus anonymized rPPG exports","claim_boundary":"Wellness trend only."}'::jsonb),
  ('hrv_prv', 'HRV / PRV', 'SDK HRV or raw-PPG pulse-rate variability feature.', 'ms', 60,
   true, ARRAY['alloop_ring','aizo_ring'], ARRAY['recovery_state','relative_physiological_load'],
   'ECG NN intervals', 'D', 'research', 'metric-catalog-1.0.0',
   '{"current_data":"SDK HRV; raw PPG reference study pending","claim_boundary":"PRV is not ECG-HRV equivalence."}'::jsonb),
  ('spo2', 'Oxygen saturation', 'Quality-gated oxygen-saturation observation.', '%', 60,
   true, ARRAY['alloop_ring','aizo_ring'], ARRAY['recovery_state'], 'Reference pulse oximeter',
   'D', 'research', 'metric-catalog-1.0.0',
   '{"current_data":"SDK synthetic fixture","claim_boundary":"No hypoxemia diagnosis."}'::jsonb),
  ('respiratory_rate', 'Respiratory rate', 'SDK, rPPG or raw-wave respiratory-rate observation.', 'breaths/min', 30,
   true, ARRAY['alloop_ring','mmwave_radar','rppg_phone'],
   ARRAY['sleep_period','relative_physiological_load'], 'Respiratory belt or capnography',
   'E', 'research', 'metric-catalog-1.0.0',
   '{"current_data":"SDK semantics; anonymized rPPG exports; sparse mmWave phase log","claim_boundary":"Reject invalid values, low SQI and insufficient raw-wave coverage."}'::jsonb),
  ('skin_temperature', 'Skin temperature', 'Skin-adjacent temperature summary; not core body temperature.', 'degC', 900,
   true, ARRAY['alloop_ring','infrared_sensor'], ARRAY['sleep_period','female_health_context'],
   'Calibrated skin-temperature reference', 'E', 'research', 'metric-catalog-1.0.0',
   '{"current_data":"SDK activity temperature sequence","claim_boundary":"Infrared requires device-specific calibration and SQI."}'::jsonb),
  ('activity', 'Activity', 'Personal activity and step rhythm observation.', 'count', 60,
   true, ARRAY['alloop_ring','aizo_ring'], ARRAY['activity_rhythm','recovery_state'],
   'Actigraphy or reference annotation', 'D', 'provisional', 'metric-catalog-1.0.0',
   '{"current_data":"SDK synthetic fixture","claim_boundary":"Relative activity pattern only."}'::jsonb),
  ('sleep_period', 'Sleep period', 'Sleep-period proxy without sleep-stage classification.', 'h', 900,
   true, ARRAY['alloop_ring','mmwave_radar'], ARRAY['sleep_period','recovery_state'],
   'Diary or actigraphy; PSG for staging', 'E', 'provisional', 'metric-catalog-1.0.0',
   '{"current_data":"Rule prototype plus synthetic multimodal data","claim_boundary":"No Wake, REM or Deep staging."}'::jsonb),
  ('relative_physiological_load', 'Relative physiological load', 'Personal physiological-load proxy, not a psychological diagnosis.', 'relative_score', 120,
   true, ARRAY['alloop_ring','rppg_phone'], ARRAY['relative_physiological_load'],
   'Preregistered questionnaire plus protocol', 'E', 'provisional', 'metric-catalog-1.0.0',
   '{"current_data":"Anonymized unlabeled rPPG sessions","claim_boundary":"Not a psychological stress diagnosis."}'::jsonb),
  ('recovery_state', 'Recovery state', 'Personal recovery wellness signal.', 'relative_score', 86400,
   true, ARRAY['alloop_ring','aizo_ring'], ARRAY['recovery_state'],
   'Longitudinal labelled outcome protocol', 'E', 'provisional', 'metric-catalog-1.0.0',
   '{"current_data":"No labelled recovery reference","claim_boundary":"Wellness signal only."}'::jsonb),
  ('female_health', 'Female health context', 'Eligibility-gated context only; it does not infer cycle, pregnancy or disease.', 'context', 86400,
   true, ARRAY['alloop_ring','infrared_sensor'], ARRAY['female_health_context'],
   'Prospective cycle labels and appropriate reference', 'E', 'research', 'metric-catalog-1.0.0',
   '{"current_data":"No eligible labelled dataset","claim_boundary":"Remain abstained until consent, subgroup evidence and safety review."}'::jsonb)
ON CONFLICT (metric_code) DO NOTHING;

INSERT INTO inference.feature_definition (
  feature_code, metric_code, display_name, description, input_modalities, output_unit,
  window_seconds, algorithm_family, evidence_grade, maturity, version, failure_modes
) VALUES
  ('personal_median_mad', 'heart_rate', 'Personal median and MAD', 'Robust personal baseline and uncertainty interval.', ARRAY['sdk_metric'], 'native_unit', 1209600, 'robust_statistics', 'E', 'provisional', 'r1-1.0.0', '["short history","degenerate MAD"]'::jsonb),
  ('robust_z', 'heart_rate', 'Robust z score', 'Current observation relative to personal robust baseline.', ARRAY['sdk_metric'], 'z', 86400, 'robust_statistics', 'E', 'provisional', 'r1-1.0.0', '["baseline shift","device change"]'::jsonb),
  ('trend_slope', 'heart_rate', 'Trend slope', 'Normalized linear trend over recent valid observations.', ARRAY['sdk_metric'], 'z_per_day', 604800, 'robust_statistics', 'E', 'provisional', 'r1-1.0.0', '["irregular sampling","seasonality"]'::jsonb),
  ('change_point', 'heart_rate', 'Change point', 'CUSUM change score over personal history.', ARRAY['sdk_metric'], 'score', 604800, 'rule', 'E', 'provisional', 'r1-1.0.0', '["artifact-induced shift"]'::jsonb),
  ('multivariate_robust_distance', 'relative_physiological_load', 'Multivariate robust distance', 'Quality-gated distance across at least two R1 metric states.', ARRAY['sdk_metric'], 'distance', 120, 'robust_statistics', 'E', 'research', 'r1-1.0.0', '["correlated features","missing covariance"]'::jsonb),
  ('raw_sqi', 'heart_rate', 'Raw-signal SQI', 'Coverage, clock, wear, target and signal-quality components.', ARRAY['PPG','ACC','MMWAVE','TEMPERATURE'], 'score', 30, 'signal_processing', 'E', 'research', 'r2-signal-features-1.0.0', '["saturation","unknown gain","NaN","clock drift"]'::jsonb),
  ('ppg_prv', 'hrv_prv', 'PPG PRV', 'RMSSD, SDNN and pNN50 from quality-gated PPG intervals.', ARRAY['PPG'], 'ms', 120, 'signal_processing', 'E', 'research', 'r2-signal-features-1.0.0', '["motion","ectopy","peak error"]'::jsonb),
  ('respiratory_rhythm', 'respiratory_rate', 'Respiratory rhythm', 'Respiratory rate and spectral concentration from suitable waveform.', ARRAY['MMWAVE','PPG'], 'breaths/min', 20, 'signal_processing', 'E', 'research', 'r2-signal-features-1.0.0', '["harmonics","multiple targets","movement"]'::jsonb),
  ('activity_rhythm', 'activity', 'Activity rhythm', 'Dynamic RMS and cadence from three-axis acceleration.', ARRAY['ACC'], 'count/min', 30, 'signal_processing', 'E', 'research', 'r2-signal-features-1.0.0', '["orientation","vehicle motion"]'::jsonb),
  ('skin_temperature_summary', 'skin_temperature', 'Skin-temperature summary', 'Median and range for raw skin-adjacent temperature.', ARRAY['TEMPERATURE'], 'degC', 3, 'signal_processing', 'E', 'research', 'r2-signal-features-1.0.0', '["sensor offset","ambient influence","not core temperature"]'::jsonb),
  ('multimodal_fusion_token', 'relative_physiological_load', 'Multimodal fusion token', 'Time-aligned quality-weighted R2 token and modality mask.', ARRAY['PPG','ACC','MMWAVE','TEMPERATURE'], 'token', 120, 'feature_fusion', 'E', 'research', 'multimodal-fusion-input-0.1.0', '["missing modality","clock mismatch","mixed origin","uncalibrated backbone"]'::jsonb)
ON CONFLICT (feature_code) DO NOTHING;

INSERT INTO inference.evidence_profile (
  id, evidence_code, title, evidence_grade, evidence_type, source_uri, summary, limitations
) VALUES
  ('e1000000-0000-4000-8000-000000000001', 'R1-RULES-V1', 'R1 deterministic reasoning rules', 'E', 'synthetic',
   'repo://reasoning_service/docs/model_card_r1_rules_v1.md', 'Contract, rejection-path and deterministic replay evidence for R1.',
   ARRAY['No clinical accuracy claim','Synthetic fixtures do not establish effectiveness']),
  ('e1000000-0000-4000-8000-000000000002', 'R2-SIGNAL-FEATURES-V1', 'R2 signal feature extraction', 'E', 'internal_unlabeled',
   'repo://reasoning_service/docs/model_card_r2_signal_features_v1.md', 'Traceable raw-signal feature engineering with explicit SQI and coverage gates.',
   ARRAY['No ECG PRV bias study','No respiratory reference MAE study','No activity reference study']),
  ('e1000000-0000-4000-8000-000000000003', 'R3-SCENE-RULES-V0-3', 'R3 provisional scene rules', 'E', 'expert_rule',
   'repo://reasoning_service/docs/model_card_r3_scene_rules_v0_3.md', 'Provisional wellness scene rules and explicit female-health safety refusal.',
   ARRAY['No sleep staging agreement','No recovery outcome prediction','No psychological stress diagnosis','No female-health inference']),
  ('e1000000-0000-4000-8000-000000000004', 'ALLOOP-SDK-SYNTHETIC-FIXTURE-V1', 'Alloop SDK-shaped fixture', 'E', 'synthetic',
   'repo://02_alloop_hackathon-main/sample_data/README.md', 'Engineering replay fixture that preserves SDK success flags and respiratory x10 semantics.',
   ARRAY['Synthetic data','Not a real-person dataset','Not clinical evidence']),
  ('e1000000-0000-4000-8000-000000000005', 'ALLOOP-SECONDARY-EXPORTS-V1', 'Anonymized secondary exports', 'E', 'internal_unlabeled',
   'repo://02_alloop_hackathon-main/sample_data', 'Anonymized rPPG vital exports and sparse selected-bin mmWave phase log.',
   ARRAY['No reference labels','rPPG export is not raw PPG','Sparse mmWave log must pass coverage gate'])
ON CONFLICT (evidence_code) DO NOTHING;

INSERT INTO inference.model_version (model_type, version, artifact_uri, parameter_hash) VALUES
  ('reasoning_r1', 'r1-rules-1.0.0', 'repo://reasoning_service/src/vvewell_reasoning/r1.py', NULL),
  ('signal_features_r2', 'r2-signal-features-1.0.0', 'repo://reasoning_service/src/vvewell_reasoning/r2.py', NULL),
  ('scene_rules_r3', 'r3-scene-rules-0.3.0', 'repo://reasoning_service/src/vvewell_reasoning/r1.py#run_provisional_scenarios', NULL),
  ('multimodal_fusion_input', 'multimodal-fusion-input-0.1.0', 'repo://reasoning_service/src/vvewell_reasoning/fusion.py', NULL)
ON CONFLICT (model_type, version) DO NOTHING;

INSERT INTO inference.research_backlog (
  item_code, workstream, title, priority, status, data_readiness, reference_standard,
  evidence_grade, dependencies, acceptance_criteria, owner_role
) VALUES
  ('M0-CONTRACT', 'M0', 'AlgorithmOutput v1 contract', 'P0', 'done', 'mock_only', NULL, 'E', ARRAY['WP1 Observation semantics'], 'Schema, SQL constraints and tests are aligned.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R1-BASELINE', 'R1', 'Personal baseline, trend and change detection', 'P0', 'done', 'mock_only', NULL, 'E', ARRAY['AlgorithmOutput v1'], 'Deterministic replay and expected fixtures pass.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R1-QUALITY', 'R1', 'Coverage, SQI, OOD and refusal taxonomy', 'P0', 'done', 'mock_only', NULL, 'E', ARRAY['WP1 quality fields'], 'All fixed rejection branches are tested.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R1-SERVICE', 'R1', 'Contract-bound R1 HTTP service', 'P0', 'done', 'mock_only', NULL, 'E', ARRAY['Observation v1','AlgorithmOutput v1'], 'Loopback HTTP route rejects uncontracted input and returns complete outputs.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('VALIDATION-RUNNER', 'validation', 'Versioned validation report runner', 'P0', 'done', 'mock_only', NULL, 'E', ARRAY['ValidationRecord v1 contract'], 'Subject, temporal, device and hospital split/report tests pass.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('DATA-CONCURRENT', 'validation', 'Thirty-minute concurrent multi-device capture', 'P0', 'blocked', 'none', 'Clock-aligned multi-device reference protocol', 'E', ARRAY['WP1','hardware owners'], 'Replay reports coverage loss, drift and target count.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('DATA-NIGHT', 'validation', 'One full-night replay package', 'P0', 'blocked', 'none', 'Sleep diary or actigraphy; PSG for staging', 'E', ARRAY['WP1','participant protocol'], 'Clock-aligned data, exclusions and reference plan exist.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R2-RAW-CONTRACT', 'R2', 'Raw wave-batch contract', 'P0', 'done', 'unlabeled', NULL, 'E', ARRAY['hardware sampling semantics'], 'PPG, ACC, mmWave and temperature fixtures plus secondary adapters validate.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R2-SECONDARY-ADAPTER', 'R2', 'rPPG and sparse mmWave export adapters', 'P0', 'done', 'unlabeled', NULL, 'E', ARRAY['declared source provenance and timestamps'], 'R1 replay and R2 coverage abstention are reproducible.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R2-SQI', 'R2', 'Device-specific SQI calibration', 'P1', 'in_progress', 'unlabeled', 'Artifact annotations', 'E', ARRAY['real concurrent capture'], 'Thresholds calibrated on real artifact annotations.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R2-PRV', 'R2', 'PPG interval and PRV validation', 'P1', 'blocked', 'none', 'ECG NN intervals', 'E', ARRAY['raw PPG','ECG reference'], 'Bias and MAE reported by subject and device.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R2-RHYTHM', 'R2', 'Respiratory and activity rhythm validation', 'P1', 'blocked', 'none', 'Respiratory belt/capnography and activity labels', 'E', ARRAY['raw waveform','reference'], 'MAE, bias, coverage and reject rate reported.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R3-SLEEP', 'R3', 'Sleep period and quality-aware HMM', 'P1', 'blocked', 'unlabeled', 'Diary/actigraphy; PSG for staging', 'E', ARRAY['full-night replay','diary or PSG'], 'Period metrics first; staging only after PSG.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R3-RECOVERY', 'R3', 'Interpretable recovery model', 'P1', 'blocked', 'none', 'Longitudinal labelled outcome protocol', 'E', ARRAY['longitudinal labels','protocol'], 'Calibration and subgroup performance reported.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R3-LOAD', 'R3', 'Relative physiological load protocol', 'P1', 'blocked', 'unlabeled', 'Preregistered questionnaire plus protocol', 'E', ARRAY['questionnaire labels'], 'PPV, false alarms, calibration and delay reported.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R3-ACTIVITY', 'R3', 'Personal activity rhythm', 'P2', 'backlog', 'unlabeled', 'Actigraphy/reference annotation', 'E', ARRAY['ACC','reference annotations'], 'Time-external validation completed.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R3-FEMALE', 'R3', 'Female-health research gate', 'P2', 'blocked', 'none', 'Prospective cycle labels and safety review', 'E', ARRAY['prospective labels','safety review'], 'No output before eligibility and subgroup criteria.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('R3-MULTIMODAL-FUSION', 'R3', 'Quality-aware multimodal temporal fusion challenger', 'P2', 'blocked', 'none', 'Clock-aligned labelled PPG/ACC/mmWave/temperature windows', 'E', ARRAY['labelled multi-device windows'], 'Compare TCN, BiGRU and Transformer against rules and interpretable baselines on identical external splits.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('VALIDATION-EXTERNAL', 'validation', 'Time, device and hospital external validation', 'P2', 'blocked', 'none', 'Labelled multi-site datasets', 'E', ARRAY['labelled multisite dataset'], 'Full validation report and model cards are completed.', '数据 Reasoning 与场景算法负责人 @ yeye'),
  ('DRIFT-RUNNER', 'validation', 'Operational drift window runner', 'P1', 'done', 'mock_only', NULL, 'E', ARRAY['AlgorithmOutput v1 contract'], 'Coverage, SQI, abstain reason mix and origin are monitored.', '数据 Reasoning 与场景算法负责人 @ yeye')
ON CONFLICT (item_code) DO NOTHING;

COMMIT;
