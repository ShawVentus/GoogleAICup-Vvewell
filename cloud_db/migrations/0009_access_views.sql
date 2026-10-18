BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN BYPASSRLS;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.create_month_partition(
  p_schema text,
  p_table text,
  p_month date
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  month_start date := date_trunc('month', p_month)::date;
  month_end date := (date_trunc('month', p_month) + interval '1 month')::date;
  partition_name text := p_table || '_' || to_char(month_start, 'YYYY_MM');
BEGIN
  IF p_schema NOT IN ('telemetry', 'inference', 'security') THEN
    RAISE EXCEPTION 'schema is not partition-managed';
  END IF;
  IF to_regclass(format('%I.%I', p_schema, p_table)) IS NULL THEN
    RAISE EXCEPTION 'partition parent does not exist: %.%', p_schema, p_table;
  END IF;
  IF to_regclass(format('%I.%I', p_schema, partition_name)) IS NULL THEN
    EXECUTE format(
      'CREATE TABLE %I.%I PARTITION OF %I.%I FOR VALUES FROM (%L) TO (%L)',
      p_schema, partition_name, p_schema, p_table, month_start, month_end
    );
  END IF;
  RETURN format('%I.%I', p_schema, partition_name);
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.create_future_partitions(months_ahead integer DEFAULT 2)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, cloud_db_meta
AS $$
DECLARE
  spec record;
  month_offset integer;
  created_count integer := 0;
BEGIN
  IF months_ahead NOT BETWEEN 0 AND 24 THEN
    RAISE EXCEPTION 'months_ahead must be between 0 and 24';
  END IF;

  FOR spec IN
    SELECT * FROM (VALUES
      ('telemetry', 'vital_readings'),
      ('telemetry', 'feature_observation'),
      ('telemetry', 'ring_measurement_results'),
      ('telemetry', 'environment_reading'),
      ('telemetry', 'device_status_sample'),
      ('inference', 'health_state'),
      ('inference', 'digital_twin_snapshot'),
      ('security', 'access_audit_log')
    ) AS managed(schema_name, table_name)
  LOOP
    FOR month_offset IN 0..months_ahead LOOP
      PERFORM cloud_db_meta.create_month_partition(
        spec.schema_name,
        spec.table_name,
        (date_trunc('month', current_date) + make_interval(months => month_offset))::date
      );
      created_count := created_count + 1;
    END LOOP;
  END LOOP;
  RETURN created_count;
END;
$$;

SELECT cloud_db_meta.create_future_partitions(2);

CREATE OR REPLACE FUNCTION security.set_request_context(
  p_user_id uuid,
  p_member_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  PERFORM set_config('app.user_id', coalesce(p_user_id::text, ''), true);
  PERFORM set_config('app.member_id', coalesce(p_member_id::text, ''), true);
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.can_access_member(
  p_member_id uuid,
  p_required_scope text DEFAULT 'basic'
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, core, security, cloud_db_meta
AS $$
DECLARE
  request_user uuid := cloud_db_meta.current_user_id();
BEGIN
  IF cloud_db_meta.is_service() THEN
    RETURN true;
  END IF;
  IF request_user IS NULL OR p_member_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM core.family_member fm
    JOIN core.families f ON f.id = fm.family_id
    WHERE fm.id = p_member_id
      AND fm.status = 'active'
      AND (fm.member_user_id = request_user OR f.owner_user_id = request_user)
  ) OR EXISTS (
    SELECT 1
    FROM core.member_permission mp
    WHERE mp.target_member_id = p_member_id
      AND mp.grantee_user_id = request_user
      AND mp.revoked_at IS NULL
      AND (mp.expires_at IS NULL OR mp.expires_at > clock_timestamp())
      AND (p_required_scope = ANY(mp.auth_scope) OR '*' = ANY(mp.auth_scope))
  ) OR EXISTS (
    SELECT 1
    FROM security.emergency_access_grant eag
    JOIN core.emergency_contact ec ON ec.id = eag.contact_id
    WHERE eag.member_id = p_member_id
      AND ec.contact_user_id = request_user
      AND ec.is_active
      AND eag.revoked_at IS NULL
      AND eag.expires_at > clock_timestamp()
      AND (p_required_scope = ANY(eag.scope) OR '*' = ANY(eag.scope))
  );
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.can_access_device(
  p_device_id uuid,
  p_required_scope text DEFAULT 'basic'
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta
AS $$
  SELECT EXISTS (
    SELECT 1 FROM core.devices d
    WHERE d.id = p_device_id
      AND cloud_db_meta.can_access_member(d.member_id, p_required_scope)
  );
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.validate_member_permission()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, core
AS $$
DECLARE
  actual_family uuid;
BEGIN
  SELECT family_id INTO actual_family FROM core.family_member WHERE id = NEW.target_member_id;
  IF actual_family IS DISTINCT FROM NEW.family_id THEN
    RAISE EXCEPTION 'permission family does not match target member' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_member_permission_family ON core.member_permission;
CREATE TRIGGER trg_member_permission_family BEFORE INSERT OR UPDATE ON core.member_permission
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.validate_member_permission();

CREATE OR REPLACE FUNCTION cloud_db_meta.validate_emergency_grant()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, core, care
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM core.emergency_contact ec
    JOIN care.care_event ce ON ce.id = NEW.care_event_id
    WHERE ec.id = NEW.contact_id
      AND ec.member_id = NEW.member_id
      AND ce.member_id = NEW.member_id
      AND ce.severity = 'red'
  ) THEN
    RAISE EXCEPTION 'emergency grant must match a red care event and contact' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_emergency_grant_consistency ON security.emergency_access_grant;
CREATE TRIGGER trg_emergency_grant_consistency BEFORE INSERT OR UPDATE ON security.emergency_access_grant
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.validate_emergency_grant();

DO $$
DECLARE
  target record;
BEGIN
  FOR target IN
    SELECT * FROM (VALUES
      ('core', 'devices', 'member_id'),
      ('core', 'member_permission', 'target_member_id'),
      ('core', 'emergency_contact', 'member_id'),
      ('ingest', 'sync_batch', 'member_id'),
      ('telemetry', 'vital_readings', 'member_id'),
      ('telemetry', 'feature_observation', 'member_id'),
      ('telemetry', 'ring_measurement_results', 'member_id'),
      ('telemetry', 'ring_daily_log', 'member_id'),
      ('telemetry', 'environment_reading', 'member_id'),
      ('telemetry', 'signal_conflict', 'member_id'),
      ('app_storage', 'object_ref', 'member_id'),
      ('inference', 'health_state', 'member_id'),
      ('inference', 'digital_twin_snapshot', 'member_id'),
      ('inference', 'recovery_score', 'member_id'),
      ('inference', 'personal_baseline', 'member_id'),
      ('inference', 'health_event', 'member_id'),
      ('inference', 'attribution_edge', 'member_id'),
      ('inference', 'health_tag', 'member_id'),
      ('inference', 'intervention_experiment', 'member_id'),
      ('inference', 'reasoning_trace', 'member_id'),
      ('medical', 'medical_record_ocr', 'member_id'),
      ('medical', 'clinical_entity', 'member_id'),
      ('medical', 'medication_plan', 'member_id'),
      ('medical', 'medication_event', 'member_id'),
      ('medical', 'medical_service_order', 'member_id'),
      ('care', 'care_event', 'member_id'),
      ('care', 'reminder', 'member_id'),
      ('security', 'consent', 'subject_member_id'),
      ('security', 'emergency_access_grant', 'member_id'),
      ('security', 'data_export_job', 'member_id'),
      ('security', 'deletion_request', 'member_id'),
      ('insurance', 'insurance_risk_profile', 'member_id'),
      ('insurance', 'insurance_recommendation', 'member_id')
    ) AS member_tables(schema_name, table_name, member_column)
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', target.schema_name, target.table_name);
    EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', target.schema_name, target.table_name);
    EXECUTE format('DROP POLICY IF EXISTS member_select ON %I.%I', target.schema_name, target.table_name);
    EXECUTE format('DROP POLICY IF EXISTS member_insert ON %I.%I', target.schema_name, target.table_name);
    EXECUTE format('DROP POLICY IF EXISTS member_update ON %I.%I', target.schema_name, target.table_name);
    EXECUTE format('DROP POLICY IF EXISTS member_delete ON %I.%I', target.schema_name, target.table_name);
    EXECUTE format(
      'CREATE POLICY member_select ON %I.%I FOR SELECT TO authenticated USING (cloud_db_meta.can_access_member(%I, ''basic''))',
      target.schema_name, target.table_name, target.member_column
    );
    EXECUTE format(
      'CREATE POLICY member_insert ON %I.%I FOR INSERT TO authenticated WITH CHECK (cloud_db_meta.can_access_member(%I, ''write''))',
      target.schema_name, target.table_name, target.member_column
    );
    EXECUTE format(
      'CREATE POLICY member_update ON %I.%I FOR UPDATE TO authenticated USING (cloud_db_meta.can_access_member(%I, ''write'')) WITH CHECK (cloud_db_meta.can_access_member(%I, ''write''))',
      target.schema_name, target.table_name, target.member_column, target.member_column
    );
    EXECUTE format(
      'CREATE POLICY member_delete ON %I.%I FOR DELETE TO authenticated USING (cloud_db_meta.can_access_member(%I, ''write''))',
      target.schema_name, target.table_name, target.member_column
    );
  END LOOP;
END;
$$;

ALTER TABLE core.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.users FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS users_self_select ON core.users;
CREATE POLICY users_self_select ON core.users FOR SELECT TO authenticated
USING (id = cloud_db_meta.current_user_id() OR cloud_db_meta.is_service());
DROP POLICY IF EXISTS users_self_update ON core.users;
CREATE POLICY users_self_update ON core.users FOR UPDATE TO authenticated
USING (id = cloud_db_meta.current_user_id())
WITH CHECK (id = cloud_db_meta.current_user_id());

ALTER TABLE core.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.families FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS families_select ON core.families;
CREATE POLICY families_select ON core.families FOR SELECT TO authenticated
USING (
  owner_user_id = cloud_db_meta.current_user_id()
  OR EXISTS (
    SELECT 1 FROM core.family_member fm
    WHERE fm.family_id = id AND fm.member_user_id = cloud_db_meta.current_user_id()
  )
  OR cloud_db_meta.is_service()
);
DROP POLICY IF EXISTS families_insert ON core.families;
CREATE POLICY families_insert ON core.families FOR INSERT TO authenticated
WITH CHECK (owner_user_id = cloud_db_meta.current_user_id());
DROP POLICY IF EXISTS families_update ON core.families;
CREATE POLICY families_update ON core.families FOR UPDATE TO authenticated
USING (owner_user_id = cloud_db_meta.current_user_id())
WITH CHECK (owner_user_id = cloud_db_meta.current_user_id());

ALTER TABLE core.family_member ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.family_member FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS family_member_select ON core.family_member;
CREATE POLICY family_member_select ON core.family_member FOR SELECT TO authenticated
USING (cloud_db_meta.can_access_member(id, 'basic'));
DROP POLICY IF EXISTS family_member_insert ON core.family_member;
CREATE POLICY family_member_insert ON core.family_member FOR INSERT TO authenticated
WITH CHECK (EXISTS (
  SELECT 1 FROM core.families f
  WHERE f.id = family_id AND f.owner_user_id = cloud_db_meta.current_user_id()
));
DROP POLICY IF EXISTS family_member_update ON core.family_member;
CREATE POLICY family_member_update ON core.family_member FOR UPDATE TO authenticated
USING (cloud_db_meta.can_access_member(id, 'write'))
WITH CHECK (cloud_db_meta.can_access_member(id, 'write'));

ALTER TABLE ingest.sync_cursor ENABLE ROW LEVEL SECURITY;
ALTER TABLE ingest.sync_cursor FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sync_cursor_access ON ingest.sync_cursor;
CREATE POLICY sync_cursor_access ON ingest.sync_cursor TO authenticated
USING (cloud_db_meta.can_access_device(device_id, 'basic'))
WITH CHECK (cloud_db_meta.can_access_device(device_id, 'write'));

ALTER TABLE telemetry.device_status_sample ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemetry.device_status_sample FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS device_status_access ON telemetry.device_status_sample;
CREATE POLICY device_status_access ON telemetry.device_status_sample TO authenticated
USING (cloud_db_meta.can_access_device(device_id, 'basic'))
WITH CHECK (cloud_db_meta.can_access_device(device_id, 'write'));

ALTER TABLE care.care_event_notification ENABLE ROW LEVEL SECURITY;
ALTER TABLE care.care_event_notification FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS care_notification_access ON care.care_event_notification;
CREATE POLICY care_notification_access ON care.care_event_notification TO authenticated
USING (EXISTS (
  SELECT 1 FROM care.care_event ce
  WHERE ce.id = care_event_id
    AND cloud_db_meta.can_access_member(ce.member_id, 'alerts')
));

ALTER TABLE security.access_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE security.access_audit_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_select ON security.access_audit_log;
CREATE POLICY audit_select ON security.access_audit_log FOR SELECT TO authenticated
USING (
  actor_user_id = cloud_db_meta.current_user_id()
  OR cloud_db_meta.can_access_member(target_member_id, 'audit')
);

DO $$
DECLARE
  catalog record;
BEGIN
  FOR catalog IN
    SELECT * FROM (VALUES
      ('inference', 'model_version'),
      ('inference', 'intervention_catalog'),
      ('insurance', 'insurance_product')
    ) AS catalogs(schema_name, table_name)
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', catalog.schema_name, catalog.table_name);
    EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', catalog.schema_name, catalog.table_name);
    EXECUTE format('DROP POLICY IF EXISTS catalog_read ON %I.%I', catalog.schema_name, catalog.table_name);
    EXECUTE format('CREATE POLICY catalog_read ON %I.%I FOR SELECT TO authenticated USING (true)', catalog.schema_name, catalog.table_name);
  END LOOP;
END;
$$;

REVOKE ALL ON SCHEMA core, ingest, telemetry, app_storage, inference, medical, insurance, care, security FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA core, ingest, telemetry, app_storage, inference, medical, insurance, care, security FROM PUBLIC;
GRANT USAGE ON SCHEMA cloud_db_meta TO authenticated, service_role;
GRANT USAGE ON SCHEMA core, ingest, telemetry, app_storage, inference, medical, insurance, care, security TO authenticated, service_role;

DO $$
DECLARE
  relation record;
BEGIN
  FOR relation IN
    SELECT n.nspname AS schema_name, c.relname AS relation_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('core', 'ingest', 'telemetry', 'app_storage', 'inference', 'medical', 'insurance', 'care', 'security')
      AND c.relkind IN ('r', 'p')
      AND NOT c.relispartition
  LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I.%I TO authenticated', relation.schema_name, relation.relation_name);
    EXECUTE format('GRANT ALL ON %I.%I TO service_role', relation.schema_name, relation.relation_name);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION security.set_request_context(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION security.set_request_context(uuid, uuid) TO service_role;
REVOKE ALL ON FUNCTION cloud_db_meta.create_month_partition(text, text, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION cloud_db_meta.create_future_partitions(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cloud_db_meta.create_month_partition(text, text, date) TO service_role;
GRANT EXECUTE ON FUNCTION cloud_db_meta.create_future_partitions(integer) TO service_role;
GRANT EXECUTE ON FUNCTION cloud_db_meta.epoch_ms_to_timestamptz(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cloud_db_meta.can_access_member(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION cloud_db_meta.can_access_device(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION ingest.upsert_vital_reading(
  uuid, uuid, text, timestamptz, text, double precision, double precision,
  double precision, double precision, double precision, double precision,
  integer, numeric, numeric, boolean, boolean, jsonb
) TO service_role;

CREATE OR REPLACE VIEW public.vvewell_health_metric
WITH (security_invoker = true)
AS
SELECT
  id,
  member_id AS user_id,
  metric_type,
  value,
  unit,
  source AS data_source,
  round(coalesce(confidence, 0) * 100)::integer AS confidence,
  recorded_at,
  is_abnormal,
  CASE WHEN is_abnormal THEN 'warning'::text ELSE NULL::text END AS abnormal_level
FROM telemetry.feature_observation;

CREATE OR REPLACE VIEW public.vvewell_health_device
WITH (security_invoker = true)
AS
SELECT
  id,
  member_id AS user_id,
  type AS device_type,
  name AS device_name,
  metadata ->> 'model' AS model,
  device_id AS serial_number,
  firmware_version,
  CASE WHEN connected THEN 'online'::text ELSE 'offline'::text END AS status,
  battery_percent AS battery_level,
  last_sync_at,
  created_at AS bound_at,
  created_at,
  updated_at
FROM core.devices;

CREATE OR REPLACE VIEW public.vvewell_family_member
WITH (security_invoker = true)
AS
SELECT
  fm.id,
  f.owner_user_id AS primary_user_id,
  fm.member_user_id,
  fm.relation,
  fm.role,
  fm.age_group,
  fm.status,
  fm.created_at,
  fm.updated_at
FROM core.family_member fm
JOIN core.families f ON f.id = fm.family_id;

CREATE OR REPLACE VIEW public.vvewell_health_reminder
WITH (security_invoker = true)
AS SELECT * FROM care.reminder;

CREATE OR REPLACE VIEW public.vvewell_medical_report
WITH (security_invoker = true)
AS SELECT * FROM medical.medical_record_ocr;

DO $$
BEGIN
  IF to_regclass('public.health_metric') IS NULL THEN
    EXECUTE 'CREATE VIEW public.health_metric WITH (security_invoker = true) AS SELECT * FROM public.vvewell_health_metric';
  END IF;
  IF to_regclass('public.health_device') IS NULL THEN
    EXECUTE 'CREATE VIEW public.health_device WITH (security_invoker = true) AS SELECT * FROM public.vvewell_health_device';
  END IF;
  IF to_regclass('public.family_member') IS NULL THEN
    EXECUTE 'CREATE VIEW public.family_member WITH (security_invoker = true) AS SELECT * FROM public.vvewell_family_member';
  END IF;
END;
$$;

GRANT SELECT ON public.vvewell_health_metric, public.vvewell_health_device,
  public.vvewell_family_member, public.vvewell_health_reminder,
  public.vvewell_medical_report TO authenticated, service_role;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.health_metric'::regclass AND relkind = 'v') THEN
    GRANT SELECT ON public.health_metric TO authenticated, service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.health_device'::regclass AND relkind = 'v') THEN
    GRANT SELECT ON public.health_device TO authenticated, service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.family_member'::regclass AND relkind = 'v') THEN
    GRANT SELECT ON public.family_member TO authenticated, service_role;
  END IF;
END;
$$;

COMMIT;
