BEGIN;

INSERT INTO core.users (id, auth_uid, username)
VALUES ('10000000-0000-0000-0000-000000000021', '11000000-0000-0000-0000-000000000021', 'domain-owner');
INSERT INTO core.families (id, owner_user_id, name)
VALUES ('20000000-0000-0000-0000-000000000021', '10000000-0000-0000-0000-000000000021', 'Domain Family');
INSERT INTO core.family_member (id, family_id, member_user_id, role, display_name, relation, age_group)
VALUES ('30000000-0000-0000-0000-000000000021', '20000000-0000-0000-0000-000000000021',
  '10000000-0000-0000-0000-000000000021', 'admin', 'Domain Owner', 'self', 'adult');
INSERT INTO core.devices (id, member_id, device_id, name, type)
VALUES ('40000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'domain-ring', 'Domain Ring', 'alloop_ring');
INSERT INTO app_storage.object_ref (
  id, member_id, object_type, bucket, object_key, content_type,
  content_size_bytes, content_sha256, retention_class
) VALUES (
  '50000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'ocr_document', 'medical', 'tests/domain-report.pdf', 'application/pdf', 1024,
  repeat('a',64), 'core'
);
INSERT INTO inference.model_version (id, model_type, version, parameter_hash)
VALUES ('60000000-0000-0000-0000-000000000021', 'health_state', 'test-1', repeat('b',64));

INSERT INTO inference.health_state (
  member_id, state_type, value, start_at, confidence, coverage_ratio, model_version_id
) VALUES ('30000000-0000-0000-0000-000000000021', 'recovery', '{"state":"stable"}',
  '2026-08-03 02:00:00+00', 0.9, 0.85, '60000000-0000-0000-0000-000000000021');
INSERT INTO inference.digital_twin_snapshot (
  member_id, twin_type, state_vector, model_version_id, captured_at
) VALUES ('30000000-0000-0000-0000-000000000021', 'cardiovascular',
  '{"load":0.3}', '60000000-0000-0000-0000-000000000021', '2026-08-03 02:00:00+00');
INSERT INTO inference.recovery_score (
  member_id, scored_at, physiological_score, psychological_score, overall_score,
  confidence, coverage_ratio, model_version_id
) VALUES ('30000000-0000-0000-0000-000000000021', '2026-08-03 02:00:00+00',
  75, 70, 73, 0.9, 0.85, '60000000-0000-0000-0000-000000000021');
INSERT INTO inference.personal_baseline (
  member_id, metric_type, window_days, median, mad, lower_bound, upper_bound,
  sample_count, calibrated_by, model_version_id
) VALUES ('30000000-0000-0000-0000-000000000021', 'heart_rate', 28, 70, 4, 58, 82,
  1000, 'personal_history', '60000000-0000-0000-0000-000000000021');
INSERT INTO inference.health_event (
  id, member_id, event_type, severity, start_at, event_source, quality_gate, model_version_id
) VALUES ('70000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'heart_rate_change', 'yellow', '2026-08-03 02:10:00+00', 'baseline', 'passed',
  '60000000-0000-0000-0000-000000000021');
INSERT INTO inference.attribution_edge (
  member_id, cause, effect, lag_seconds, effect_size, p_value, confidence, model_version_id
) VALUES ('30000000-0000-0000-0000-000000000021', 'late_sleep', 'higher_resting_hr',
  28800, 0.25, 0.04, 0.8, '60000000-0000-0000-0000-000000000021');
INSERT INTO inference.health_tag (
  member_id, tag_type, tag_key, tag_value, confidence, source, model_version_id
) VALUES ('30000000-0000-0000-0000-000000000021', 'behavior', 'late_sleep_responder',
  'true', 0.8, 'attribution', '60000000-0000-0000-0000-000000000021');
INSERT INTO inference.intervention_catalog (
  id, intervention_code, category, title, description, target_metrics,
  safety_constraints, version
) VALUES ('80000000-0000-0000-0000-000000000021', 'EARLY_SLEEP', 'lifestyle',
  'Earlier sleep', 'Move bedtime earlier', ARRAY['resting_heart_rate'], '{}', '1');
INSERT INTO inference.intervention_experiment (
  member_id, intervention_id, design, target_metric, expected_delta,
  observation_window, quality_threshold, status
) VALUES ('30000000-0000-0000-0000-000000000021',
  '80000000-0000-0000-0000-000000000021', '{"type":"n_of_1"}',
  'resting_heart_rate', -2, interval '7 days', 0.7, 'planned');
INSERT INTO inference.reasoning_trace (
  member_id, question, steps, tool_calls, conclusion, model_version_id
) VALUES ('30000000-0000-0000-0000-000000000021', 'Why did heart rate rise?',
  '[{"step":"baseline"}]', '[{"tool":"get_baseline"}]',
  '{"status":"evidence_available"}', '60000000-0000-0000-0000-000000000021');

INSERT INTO medical.medical_record_ocr (
  id, member_id, doc_type, object_id, document_date, confidence, status
) VALUES ('90000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'lab_report', '50000000-0000-0000-0000-000000000021', '2026-08-01', 0.9, 'pending');
INSERT INTO medical.clinical_entity (
  record_id, member_id, entity_type, standard_system, standard_code,
  entity_value, unit, confidence
) VALUES ('90000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'observation', 'LOINC', '8867-4', '72', 'bpm', 0.95);
INSERT INTO medical.medication_plan (
  id, member_id, drug_code_atc, drug_name, schedule, start_at
) VALUES ('a0000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'C07AB02', 'Example medicine', '{"times":["08:00"]}', '2026-08-03 00:00:00+00');
INSERT INTO medical.medication_event (
  plan_id, member_id, scheduled_at, status, source
) VALUES ('a0000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  '2026-08-03 08:00:00+00', 'scheduled', 'reminder');
INSERT INTO medical.medical_service_order (
  id, member_id, service_type, service_level, related_event_id, order_status
) VALUES ('b0000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'online_consultation', 'basic', '70000000-0000-0000-0000-000000000021', 'requested');

INSERT INTO care.reminder (member_id, reminder_type, title, due_at)
VALUES ('30000000-0000-0000-0000-000000000021', 'medication', 'Take medicine',
  '2026-08-03 08:00:00+00');
INSERT INTO care.care_event (
  id, member_id, event_type, trigger_source, severity, detected_at, related_health_event_id
) VALUES ('c0000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'health_followup', 'health_event', 'yellow', '2026-08-03 02:10:00+00',
  '70000000-0000-0000-0000-000000000021');

INSERT INTO security.consent (
  id, subject_member_id, granted_by_user_id, grantee_type, grantee_id,
  purpose, auth_scope, policy_version, expires_at
) VALUES ('d0000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  '10000000-0000-0000-0000-000000000021', 'insurer', 'test-insurer', 'recommendation',
  ARRAY['insurance_risk'], '1', clock_timestamp() + interval '1 day');
INSERT INTO insurance.insurance_product (
  id, carrier, product_code, product_type, name, active_from
) VALUES ('e0000000-0000-0000-0000-000000000021', 'Test Carrier', 'TEST-MED-1',
  'medical', 'Test Medical', '2026-01-01');
INSERT INTO insurance.insurance_risk_profile (
  member_id, risk_score, risk_level, data_coverage, model_version_id, calculated_at
) VALUES ('30000000-0000-0000-0000-000000000021', 20, 'A', 0.85,
  '60000000-0000-0000-0000-000000000021', '2026-08-03 03:00:00+00');
INSERT INTO insurance.insurance_recommendation (
  family_id, member_id, product_id, estimated_premium_min,
  estimated_premium_max, suggestion, consent_id, expires_at
) VALUES ('20000000-0000-0000-0000-000000000021', '30000000-0000-0000-0000-000000000021',
  'e0000000-0000-0000-0000-000000000021', 100, 150,
  'Reference only; final underwriting applies.', 'd0000000-0000-0000-0000-000000000021',
  clock_timestamp() + interval '1 day');

INSERT INTO security.data_export_job (
  requested_by_user_id, member_id, scope, format
) VALUES ('10000000-0000-0000-0000-000000000021',
  '30000000-0000-0000-0000-000000000021', ARRAY['health'], 'fhir');
INSERT INTO security.deletion_request (
  requested_by_user_id, member_id, scope
) VALUES ('10000000-0000-0000-0000-000000000021',
  '30000000-0000-0000-0000-000000000021', ARRAY['test_fixture']);

SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM inference.health_state WHERE member_id = '30000000-0000-0000-0000-000000000021') = 1,
  'digital health state workflow must persist'
);
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM medical.clinical_entity WHERE member_id = '30000000-0000-0000-0000-000000000021') = 1,
  'medical OCR entity workflow must persist'
);
SELECT cloud_db_test.assert_true(
  (SELECT count(*) FROM insurance.insurance_recommendation WHERE member_id = '30000000-0000-0000-0000-000000000021') = 1,
  'consented insurance recommendation workflow must persist'
);

ROLLBACK;
