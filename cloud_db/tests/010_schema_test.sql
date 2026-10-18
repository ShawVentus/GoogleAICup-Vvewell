DO $$
DECLARE
  application_table_count integer;
  rls_table_count integer;
  missing_tables text;
  partition_parent_count integer;
  current_partition_count integer;
  view_count integer;
BEGIN
  SELECT count(*) INTO application_table_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('core', 'ingest', 'telemetry', 'app_storage', 'inference', 'medical', 'insurance', 'care', 'security')
    AND c.relkind IN ('r', 'p')
    AND NOT c.relispartition;
  PERFORM cloud_db_test.assert_true(application_table_count = 61,
    format('expected 61 application tables, found %s', application_table_count));

  WITH expected(schema_name, table_name) AS (VALUES
    ('core','users'), ('core','families'), ('core','family_member'),
    ('core','devices'), ('core','member_permission'), ('core','emergency_contact'),
    ('ingest','sync_batch'), ('ingest','sync_cursor'),
    ('telemetry','vital_readings'), ('telemetry','feature_observation'),
    ('telemetry','ring_measurement_results'), ('telemetry','ring_daily_log'),
    ('telemetry','environment_reading'), ('telemetry','device_status_sample'),
    ('telemetry','signal_conflict'), ('telemetry','l0_fused_metric'),
    ('app_storage','object_ref'), ('app_storage','ios_profile_mapping'),
    ('app_storage','ios_health_reading'), ('app_storage','ios_chat_session'),
    ('app_storage','ios_chat_feedback'), ('app_storage','ios_ocr_report'),
    ('inference','model_version'), ('inference','health_state'),
    ('inference','digital_twin_snapshot'), ('inference','recovery_score'),
    ('inference','personal_baseline'), ('inference','health_event'),
    ('inference','attribution_edge'), ('inference','health_tag'),
    ('inference','intervention_catalog'), ('inference','intervention_experiment'),
    ('inference','reasoning_trace'), ('inference','metric_definition'),
    ('inference','feature_definition'), ('inference','evidence_profile'),
    ('inference','research_backlog'), ('inference','algorithm_output'),
    ('inference','validation_run'), ('inference','drift_window'),
    ('inference','recommendation_catalog_item'),
    ('inference','recommendation_decision'),
    ('inference','recommendation_feedback'),
    ('medical','medical_record_ocr'),
    ('medical','clinical_entity'), ('medical','medication_plan'),
    ('medical','medication_event'), ('medical','medical_service_order'),
    ('insurance','insurance_product'), ('insurance','insurance_risk_profile'),
    ('insurance','insurance_recommendation'), ('care','care_event'),
    ('care','health_task_instance'),
    ('care','care_event_notification'), ('care','reminder'),
    ('security','consent'), ('security','emergency_access_grant'),
    ('security','access_audit_log'), ('security','data_export_job'),
    ('security','deletion_request')
  ), missing AS (
    SELECT format('%I.%I', e.schema_name, e.table_name) AS name
    FROM expected e
    WHERE to_regclass(format('%I.%I', e.schema_name, e.table_name)) IS NULL
  )
  SELECT string_agg(name, ', ') INTO missing_tables FROM missing;
  PERFORM cloud_db_test.assert_true(missing_tables IS NULL,
    'missing planned tables: ' || coalesce(missing_tables, 'none'));

  SELECT count(*) INTO rls_table_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('core', 'ingest', 'telemetry', 'app_storage', 'inference', 'medical', 'insurance', 'care', 'security')
    AND c.relkind IN ('r', 'p')
    AND NOT c.relispartition
    AND c.relrowsecurity
    AND c.relforcerowsecurity;
  PERFORM cloud_db_test.assert_true(rls_table_count = 61,
    format('expected forced RLS on 61 tables, found %s', rls_table_count));

  SELECT count(*) INTO partition_parent_count
  FROM pg_partitioned_table pt
  JOIN pg_class c ON c.oid = pt.partrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname IN ('telemetry', 'inference', 'security');
  PERFORM cloud_db_test.assert_true(partition_parent_count = 8,
    format('expected 8 partition parents, found %s', partition_parent_count));

  SELECT count(*) INTO current_partition_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relispartition
    AND c.relname LIKE '%' || to_char(current_date, 'YYYY_MM');
  PERFORM cloud_db_test.assert_true(current_partition_count = 8,
    format('expected 8 current-month partitions, found %s', current_partition_count));

  SELECT count(*) INTO view_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('vvewell_health_metric', 'vvewell_health_device',
      'vvewell_family_member', 'vvewell_health_reminder', 'vvewell_medical_report')
    AND c.relkind = 'v';
  PERFORM cloud_db_test.assert_true(view_count = 5,
    format('expected 5 compatibility views, found %s', view_count));

  PERFORM cloud_db_test.assert_true(
    cloud_db_meta.epoch_ms_to_timestamptz(0) = '1970-01-01 00:00:00+00'::timestamptz,
    'epoch conversion must preserve UTC');
END;
$$;

SELECT cloud_db_test.assert_true(
  cloud_db_meta.create_future_partitions(3) = 32,
  'partition maintenance must process 8 tables across 4 months'
);
