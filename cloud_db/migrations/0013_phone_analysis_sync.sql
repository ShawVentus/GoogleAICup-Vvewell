BEGIN;

ALTER TABLE telemetry.l0_fused_metric
  ADD COLUMN IF NOT EXISTS producer_runtime text,
  ADD COLUMN IF NOT EXISTS producer_device_id text,
  ADD COLUMN IF NOT EXISTS client_created_at timestamptz,
  ADD COLUMN IF NOT EXISTS received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN IF NOT EXISTS sync_validation_status text NOT NULL DEFAULT 'VALID'
    CHECK (sync_validation_status IN ('VALID', 'STALE_CONTEXT', 'REJECTED'));

ALTER TABLE inference.health_tag
  ADD COLUMN IF NOT EXISTS producer_runtime text,
  ADD COLUMN IF NOT EXISTS producer_device_id text,
  ADD COLUMN IF NOT EXISTS client_created_at timestamptz,
  ADD COLUMN IF NOT EXISTS received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN IF NOT EXISTS sync_validation_status text NOT NULL DEFAULT 'VALID'
    CHECK (sync_validation_status IN ('VALID', 'STALE_CONTEXT', 'REJECTED'));

ALTER TABLE inference.recommendation_decision
  ADD COLUMN IF NOT EXISTS producer_runtime text,
  ADD COLUMN IF NOT EXISTS producer_device_id text,
  ADD COLUMN IF NOT EXISTS client_created_at timestamptz,
  ADD COLUMN IF NOT EXISTS received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN IF NOT EXISTS sync_validation_status text NOT NULL DEFAULT 'VALID'
    CHECK (sync_validation_status IN ('VALID', 'STALE_CONTEXT', 'REJECTED'));

ALTER TABLE inference.recommendation_feedback
  ADD COLUMN IF NOT EXISTS producer_runtime text,
  ADD COLUMN IF NOT EXISTS producer_device_id text,
  ADD COLUMN IF NOT EXISTS client_created_at timestamptz,
  ADD COLUMN IF NOT EXISTS received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN IF NOT EXISTS sync_validation_status text NOT NULL DEFAULT 'VALID'
    CHECK (sync_validation_status IN ('VALID', 'STALE_CONTEXT', 'REJECTED'));

ALTER TABLE care.health_task_instance
  ADD COLUMN IF NOT EXISTS producer_runtime text,
  ADD COLUMN IF NOT EXISTS producer_device_id text,
  ADD COLUMN IF NOT EXISTS client_created_at timestamptz,
  ADD COLUMN IF NOT EXISTS received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  ADD COLUMN IF NOT EXISTS sync_validation_status text NOT NULL DEFAULT 'VALID'
    CHECK (sync_validation_status IN ('VALID', 'STALE_CONTEXT', 'REJECTED'));

CREATE TABLE IF NOT EXISTS inference.phone_analysis_run (
  id uuid PRIMARY KEY,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  as_of timestamptz NOT NULL,
  input_count integer NOT NULL CHECK (input_count >= 0),
  accepted_count integer NOT NULL CHECK (accepted_count BETWEEN 0 AND input_count),
  model_version text NOT NULL,
  policy_version text NOT NULL,
  input_fingerprint text NOT NULL CHECK (input_fingerprint ~ '^[0-9a-f]{64}$'),
  status text NOT NULL CHECK (status IN ('READY', 'INSUFFICIENT')),
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
  producer_runtime text NOT NULL DEFAULT 'flutter_dart',
  producer_device_id text,
  client_created_at timestamptz,
  received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  sync_validation_status text NOT NULL DEFAULT 'VALID'
    CHECK (sync_validation_status IN ('VALID', 'STALE_CONTEXT', 'REJECTED')),
  UNIQUE (member_id, input_fingerprint, as_of)
);

CREATE INDEX IF NOT EXISTS idx_phone_analysis_run_member_asof
  ON inference.phone_analysis_run(member_id, as_of DESC);

ALTER TABLE inference.phone_analysis_run ENABLE ROW LEVEL SECURITY;
ALTER TABLE inference.phone_analysis_run FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS phone_analysis_run_select ON inference.phone_analysis_run;
CREATE POLICY phone_analysis_run_select ON inference.phone_analysis_run
FOR SELECT TO authenticated USING (cloud_db_meta.can_access_member(member_id, 'basic'));
DROP POLICY IF EXISTS phone_analysis_run_insert ON inference.phone_analysis_run;
CREATE POLICY phone_analysis_run_insert ON inference.phone_analysis_run
FOR INSERT TO authenticated WITH CHECK (cloud_db_meta.can_access_member(member_id, 'write'));

CREATE OR REPLACE FUNCTION public.get_phone_analysis_context(
  p_member_id uuid,
  p_at timestamptz DEFAULT clock_timestamp()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, cloud_db_meta
AS $$
DECLARE
  result jsonb;
BEGIN
  IF p_at IS NULL OR NOT cloud_db_meta.can_access_member(p_member_id, 'basic') THEN
    RAISE EXCEPTION 'caller cannot read phone analysis context' USING ERRCODE = '42501';
  END IF;
  result := public.get_recommendation_context(p_member_id, p_at);
  RETURN result || jsonb_build_object(
    'context_version', 'phone-analysis-context-v1',
    'fetched_at', p_at,
    'expires_at', p_at + interval '24 hours'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_phone_analysis_bundle(
  p_member_id uuid,
  p_bundle jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, cloud_db_meta, core, telemetry, inference, care
AS $$
DECLARE
  item jsonb;
  payload jsonb;
  phase text;
  entity_type text;
  local_id text;
  cloud_id uuid;
  outbox_id bigint;
  validation text;
  reason text;
  age_group text;
  model_id uuid;
  current_context jsonb;
  consent_scopes text[];
  acks jsonb := '[]'::jsonb;
  item_count integer;
BEGIN
  IF NOT cloud_db_meta.can_access_member(p_member_id, 'write') THEN
    RAISE EXCEPTION 'caller cannot write phone analysis bundle' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_bundle -> 'items') <> 'array' THEN
    RAISE EXCEPTION 'bundle items must be an array' USING ERRCODE = '22023';
  END IF;
  item_count := jsonb_array_length(p_bundle -> 'items');
  IF item_count > 200 THEN
    RAISE EXCEPTION 'bundle exceeds 200 items' USING ERRCODE = '54000';
  END IF;
  SELECT fm.age_group INTO STRICT age_group FROM core.family_member fm WHERE fm.id = p_member_id;
  current_context := public.get_phone_analysis_context(p_member_id, clock_timestamp());
  consent_scopes := ARRAY(
    SELECT jsonb_array_elements_text(coalesce(current_context -> 'consent_scopes', '[]'::jsonb))
  );

  FOREACH phase IN ARRAY ARRAY['FUSED_METRIC','ANALYSIS_RUN','HEALTH_TAG','DECISION','TASK','FEEDBACK']
  LOOP
    FOR item IN SELECT value FROM jsonb_array_elements(p_bundle -> 'items')
    LOOP
      entity_type := item ->> 'entity_type';
      CONTINUE WHEN entity_type <> phase;
      payload := item -> 'payload';
      local_id := item ->> 'local_id';
      outbox_id := (item ->> 'outbox_id')::bigint;
      cloud_id := NULL;
      validation := 'VALID';
      reason := NULL;
      BEGIN
        IF entity_type NOT IN ('FUSED_METRIC','ANALYSIS_RUN','HEALTH_TAG','DECISION','TASK','FEEDBACK')
           OR jsonb_typeof(payload) <> 'object'
           OR nullif(local_id, '') IS NULL
           OR coalesce(item ->> 'payload_hash', '') !~ '^[0-9a-f]{64}$' THEN
          RAISE EXCEPTION 'invalid artifact envelope' USING ERRCODE = '22023';
        END IF;

        IF entity_type = 'FUSED_METRIC' THEN
          IF payload ->> 'algorithm_version' <> 'l0-adaptive-kalman-v1' THEN
            RAISE EXCEPTION 'unsupported L0 version' USING ERRCODE = '23514';
          END IF;
          INSERT INTO telemetry.l0_fused_metric (
            id, member_id, metric_type, window_start, window_end, status, value,
            unit, confidence, signal_quality, coverage_ratio, coverage_mask,
            quality_flag, conflict_flag, interval_lower, interval_upper,
            contributing_sources, wear_state, age_group, abstain_reason,
            algorithm_version, input_fingerprint, evidence, producer_runtime,
            client_created_at, sync_validation_status
          ) VALUES (
            local_id::uuid, p_member_id, payload ->> 'metric_type',
            (payload ->> 'window_start')::timestamptz, (payload ->> 'window_end')::timestamptz,
            payload ->> 'status', nullif(payload ->> 'value','')::numeric,
            payload ->> 'unit', (payload ->> 'confidence')::numeric,
            (payload ->> 'signal_quality')::numeric, (payload ->> 'coverage_ratio')::numeric,
            coalesce(payload -> 'coverage_mask','{}'::jsonb), payload ->> 'quality_flag',
            coalesce((payload ->> 'conflict_flag')::boolean,false),
            nullif(payload ->> 'interval_lower','')::numeric,
            nullif(payload ->> 'interval_upper','')::numeric,
            ARRAY(SELECT jsonb_array_elements_text(coalesce(payload -> 'contributing_sources','[]'::jsonb))),
            nullif(payload ->> 'wear_state',''), age_group, nullif(payload ->> 'abstain_reason',''),
            payload ->> 'algorithm_version', payload ->> 'input_fingerprint',
            coalesce(payload -> 'evidence','{}'::jsonb), 'flutter_dart',
            clock_timestamp(), validation
          ) ON CONFLICT (member_id, metric_type, window_start, algorithm_version, input_fingerprint)
          DO UPDATE SET received_at = telemetry.l0_fused_metric.received_at
          RETURNING id INTO cloud_id;

        ELSIF entity_type = 'ANALYSIS_RUN' THEN
          IF payload ->> 'model_version' <> 'river-health-stream-dart-v1'
             OR payload ->> 'policy_version' <> 'health-tag-policy-v1' THEN
            RAISE EXCEPTION 'unsupported phone analysis version' USING ERRCODE = '23514';
          END IF;
          INSERT INTO inference.phone_analysis_run (
            id, member_id, as_of, input_count, accepted_count, model_version,
            policy_version, input_fingerprint, status, payload, client_created_at
          ) VALUES (
            local_id::uuid, p_member_id, (payload ->> 'as_of')::timestamptz,
            (payload ->> 'input_count')::integer, (payload ->> 'accepted_count')::integer,
            payload ->> 'model_version', payload ->> 'policy_version',
            payload ->> 'input_fingerprint',
            CASE WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(payload -> 'tags') t
                              WHERE t ->> 'tag_key' = 'data_insufficient')
                 THEN 'INSUFFICIENT' ELSE 'READY' END,
            payload, clock_timestamp()
          ) ON CONFLICT (id) DO UPDATE SET received_at = inference.phone_analysis_run.received_at
          RETURNING id INTO cloud_id;

        ELSIF entity_type = 'HEALTH_TAG' THEN
          IF payload ->> 'source' <> 'river-health-stream-dart-v1' THEN
            RAISE EXCEPTION 'unsupported health tag source' USING ERRCODE = '23514';
          END IF;
          INSERT INTO inference.model_version (model_type, version)
          VALUES ('health_tag', payload ->> 'source')
          ON CONFLICT (model_type, version) DO UPDATE SET version = EXCLUDED.version
          RETURNING id INTO model_id;
          INSERT INTO inference.health_tag (
            id, member_id, tag_type, tag_key, tag_value, weight, confidence,
            source, model_version_id, valid_from, valid_to, analysis_id,
            policy_version, input_fingerprint, evidence, demo_baseline,
            producer_runtime, client_created_at, sync_validation_status
          ) VALUES (
            local_id::uuid, p_member_id, payload ->> 'tag_type', payload ->> 'tag_key',
            payload -> 'tag_value', (payload ->> 'weight')::numeric,
            (payload ->> 'confidence')::numeric, payload ->> 'source', model_id,
            (payload ->> 'valid_from')::timestamptz,
            nullif(payload ->> 'valid_to','')::timestamptz,
            (payload ->> 'analysis_id')::uuid, 'health-tag-policy-v1',
            payload ->> 'input_fingerprint', coalesce(payload -> 'evidence','{}'::jsonb),
            coalesce((payload ->> 'demo_baseline')::boolean,false), 'flutter_dart',
            clock_timestamp(), validation
          ) ON CONFLICT (id) DO UPDATE SET received_at = inference.health_tag.received_at
          RETURNING id INTO cloud_id;

        ELSIF entity_type = 'DECISION' THEN
          IF payload ->> 'policy_version' <> 'recommendation-policy-dart-v2'
             OR payload ->> 'matrix_version' <> 'recommendation-affinity-matrix-v2'
             OR payload ->> 'registry_version' <> 'recommendation-intent-registry-v2'
             OR payload ->> 'feature_schema_version' <> 'health-tag-feature-schema-v2'
             OR payload ->> 'safety_version' <> 'recommendation-safety-v2' THEN
            RAISE EXCEPTION 'unsupported recommendation version' USING ERRCODE = '23514';
          END IF;
          IF coalesce((payload #>> '{context_snapshot,context_expires_at}')::timestamptz, '-infinity') <= clock_timestamp() THEN
            validation := 'STALE_CONTEXT';
            reason := 'LOCAL_CONTEXT_EXPIRED';
          END IF;
          IF EXISTS (
            SELECT 1 FROM jsonb_array_elements(coalesce(payload #> '{final_plan,items}','[]'::jsonb)) selected
            JOIN inference.recommendation_catalog_item catalog
              ON catalog.id = (selected ->> 'catalog_item_id')::uuid
            WHERE NOT (catalog.consent_scope <@ consent_scopes)
               OR catalog.approval_status <> 'APPROVED'
               OR catalog.data_origin <> 'REAL'
          ) THEN
            validation := 'REJECTED';
            reason := 'CURRENT_CONSENT_OR_CATALOG_REJECTED';
          END IF;
          INSERT INTO inference.recommendation_decision (
            id, member_id, client_request_id, surface, decided_at, expires_at,
            context_snapshot, health_tag_snapshot, candidate_snapshot, final_plan,
            feature_schema_version, matrix_version, registry_version, policy_version,
            safety_version, data_origin, producer_runtime, client_created_at,
            sync_validation_status
          ) VALUES (
            local_id::uuid, p_member_id, payload ->> 'client_request_id', payload ->> 'surface',
            (payload ->> 'decided_at')::timestamptz, (payload ->> 'expires_at')::timestamptz,
            payload -> 'context_snapshot', payload -> 'health_tag_snapshot',
            payload -> 'candidate_snapshot', payload -> 'final_plan',
            payload ->> 'feature_schema_version', payload ->> 'matrix_version',
            payload ->> 'registry_version', payload ->> 'policy_version',
            payload ->> 'safety_version', payload ->> 'data_origin', 'flutter_dart',
            clock_timestamp(), validation
          ) ON CONFLICT (member_id, client_request_id)
          DO UPDATE SET received_at = inference.recommendation_decision.received_at
          RETURNING id INTO cloud_id;

        ELSIF entity_type = 'TASK' THEN
          SELECT d.sync_validation_status INTO validation
          FROM inference.recommendation_decision d
          WHERE d.id = (payload ->> 'decision_id')::uuid AND d.member_id = p_member_id;
          IF validation IS NULL OR validation = 'REJECTED' THEN
            RAISE EXCEPTION 'task decision is absent or rejected' USING ERRCODE = '23514';
          END IF;
          IF EXISTS (SELECT 1 FROM care.health_task_instance t
                     WHERE t.id = local_id::uuid AND t.member_id = p_member_id) THEN
            UPDATE care.health_task_instance SET
              status = payload ->> 'status',
              progress = (payload ->> 'progress')::numeric,
              completed_at = CASE WHEN payload ->> 'status' = 'completed'
                THEN coalesce((payload ->> 'updated_at')::timestamptz, clock_timestamp())
                ELSE NULL END,
              sync_validation_status = validation
            WHERE id = local_id::uuid AND member_id = p_member_id
            RETURNING id INTO cloud_id;
          ELSE
            INSERT INTO care.health_task_instance (
              id, member_id, decision_id, catalog_item_id, title_snapshot,
              goal_snapshot, due_at, status, progress, completed_at, client_task_id,
              producer_runtime, client_created_at, sync_validation_status
            ) VALUES (
              local_id::uuid, p_member_id, (payload ->> 'decision_id')::uuid,
              (payload ->> 'catalog_item_id')::uuid, payload ->> 'title_snapshot',
              coalesce(payload -> 'goal_snapshot','{}'::jsonb),
              (payload ->> 'due_at')::timestamptz, coalesce(payload ->> 'status','pending'),
              coalesce((payload ->> 'progress')::numeric,0),
              nullif(payload ->> 'completed_at','')::timestamptz,
              payload ->> 'client_task_id', 'flutter_dart', clock_timestamp(), validation
            ) RETURNING id INTO cloud_id;
          END IF;

        ELSIF entity_type = 'FEEDBACK' THEN
          INSERT INTO inference.recommendation_feedback (
            id, decision_id, member_id, catalog_item_id, event_type, occurred_at,
            client_event_id, source, metadata, producer_runtime, client_created_at
          ) VALUES (
            local_id::uuid, (payload ->> 'decision_id')::uuid, p_member_id,
            (payload ->> 'catalog_item_id')::uuid, payload ->> 'event_type',
            (payload ->> 'occurred_at')::timestamptz, payload ->> 'client_event_id',
            payload ->> 'source', coalesce(payload -> 'metadata','{}'::jsonb),
            'flutter_dart', clock_timestamp()
          ) ON CONFLICT (member_id, client_event_id)
          DO UPDATE SET received_at = inference.recommendation_feedback.received_at
          RETURNING id INTO cloud_id;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        validation := 'REJECTED';
        reason := SQLERRM;
      END;
      acks := acks || jsonb_build_array(jsonb_build_object(
        'outbox_id', outbox_id,
        'entity_type', entity_type,
        'local_id', local_id,
        'cloud_id', cloud_id,
        'status', validation,
        'reason', reason
      ));
    END LOOP;
  END LOOP;
  RETURN jsonb_build_object('acks', acks, 'count', jsonb_array_length(acks));
END;
$$;

REVOKE ALL ON TABLE inference.phone_analysis_run FROM PUBLIC;
GRANT SELECT, INSERT ON inference.phone_analysis_run TO authenticated;
GRANT ALL ON inference.phone_analysis_run TO service_role;

REVOKE ALL ON FUNCTION public.get_phone_analysis_context(uuid, timestamptz),
  public.sync_phone_analysis_bundle(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_phone_analysis_context(uuid, timestamptz),
  public.sync_phone_analysis_bundle(uuid, jsonb) TO authenticated, service_role;

COMMIT;
