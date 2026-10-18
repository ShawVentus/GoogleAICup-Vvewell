BEGIN;

CREATE TABLE IF NOT EXISTS app_storage.ios_profile_mapping (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
  client_profile_id text NOT NULL CHECK (length(btrim(client_profile_id)) BETWEEN 1 AND 128),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE RESTRICT,
  profile_data jsonb NOT NULL CHECK (jsonb_typeof(profile_data) = 'object'),
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (owner_user_id, client_profile_id)
);

CREATE TABLE IF NOT EXISTS app_storage.ios_health_reading (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE RESTRICT,
  client_reading_id text NOT NULL CHECK (length(btrim(client_reading_id)) BETWEEN 1 AND 128),
  content_hash text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
  metric_type text NOT NULL,
  source text NOT NULL,
  recorded_at timestamptz NOT NULL,
  raw_payload jsonb NOT NULL CHECK (jsonb_typeof(raw_payload) = 'object'),
  projected_reading_id uuid,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (owner_user_id, client_reading_id)
);

CREATE INDEX IF NOT EXISTS idx_ios_health_owner_recorded
  ON app_storage.ios_health_reading(owner_user_id, recorded_at DESC, client_reading_id);

CREATE TABLE IF NOT EXISTS app_storage.ios_chat_session (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
  client_session_id text NOT NULL CHECK (length(btrim(client_session_id)) BETWEEN 1 AND 128),
  revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
  messages jsonb NOT NULL CHECK (jsonb_typeof(messages) = 'array'),
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (owner_user_id, client_session_id)
);

CREATE TABLE IF NOT EXISTS app_storage.ios_chat_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
  client_session_id text NOT NULL,
  message_id text NOT NULL,
  version_id text NOT NULL,
  feedback text NOT NULL CHECK (feedback IN ('up', 'down')),
  revision integer,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (owner_user_id, client_session_id, message_id, version_id)
);

CREATE TABLE IF NOT EXISTS app_storage.ios_ocr_report (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
  report_date date,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION cloud_db_meta.ensure_ios_user()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta
AS $$
DECLARE
  request_user_id uuid := cloud_db_meta.current_user_id();
  resolved_user_id uuid;
BEGIN
  IF request_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM core.users u WHERE u.id = request_user_id OR u.auth_uid = request_user_id) THEN
    INSERT INTO core.users (id, auth_uid, username, display_name)
    VALUES (request_user_id, request_user_id, 'ios-' || request_user_id::text, 'iOS User')
    ON CONFLICT (auth_uid) DO NOTHING;
  END IF;
  SELECT u.id INTO resolved_user_id FROM core.users u
  WHERE u.id = request_user_id OR u.auth_uid = request_user_id
  ORDER BY (u.id = request_user_id) DESC LIMIT 1;
  IF resolved_user_id IS NULL THEN
    RAISE EXCEPTION 'user mapping conflict' USING ERRCODE = '23505';
  END IF;
  RETURN resolved_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.ensure_ios_family(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core
AS $$
DECLARE
  family_id uuid;
BEGIN
  SELECT id INTO family_id FROM core.families
  WHERE owner_user_id = p_user_id AND status = 'active'
  ORDER BY created_at LIMIT 1;
  IF family_id IS NULL THEN
    INSERT INTO core.families (owner_user_id, name)
    VALUES (p_user_id, 'My Family') RETURNING id INTO family_id;
  END IF;
  RETURN family_id;
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.ios_age_group(p_birth_year integer)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN p_birth_year IS NULL THEN 'adult'
    WHEN p_birth_year > extract(year FROM current_date)::integer - 18 THEN 'child'
    WHEN p_birth_year <= extract(year FROM current_date)::integer - 65 THEN 'elder'
    ELSE 'adult'
  END;
$$;

CREATE OR REPLACE FUNCTION public.ios_sync_profiles(p_profiles jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core, app_storage, cloud_db_meta
AS $$
DECLARE
  user_id uuid := cloud_db_meta.ensure_ios_user();
  resolved_family_id uuid := cloud_db_meta.ensure_ios_family(user_id);
  profile jsonb;
  member_id uuid;
  client_id text;
  relation text;
  birth_year integer;
BEGIN
  IF jsonb_typeof(p_profiles) <> 'array' OR jsonb_array_length(p_profiles) > 100 THEN
    RAISE EXCEPTION 'profiles must be an array of at most 100 items' USING ERRCODE = '22023';
  END IF;
  FOR profile IN SELECT value FROM jsonb_array_elements(p_profiles)
  LOOP
    client_id := nullif(btrim(profile ->> 'id'), '');
    relation := profile ->> 'relationship';
    birth_year := nullif(profile ->> 'birth_year', '')::integer;
    IF client_id IS NULL OR length(client_id) > 128
       OR nullif(btrim(profile ->> 'name'), '') IS NULL
       OR relation NOT IN ('owner', 'spouse', 'parent', 'child', 'other')
       OR (birth_year IS NOT NULL AND birth_year NOT BETWEEN 1900 AND extract(year FROM current_date)::integer) THEN
      RAISE EXCEPTION 'invalid profile' USING ERRCODE = '22023';
    END IF;

    SELECT m.member_id INTO member_id FROM app_storage.ios_profile_mapping m
    WHERE m.owner_user_id = user_id AND m.client_profile_id = client_id;
    IF member_id IS NULL AND relation = 'owner' THEN
      SELECT fm.id INTO member_id FROM core.family_member fm
      WHERE fm.family_id = resolved_family_id AND fm.member_user_id = user_id LIMIT 1;
    END IF;
    IF member_id IS NULL THEN
      INSERT INTO core.family_member (
        family_id, member_user_id, role, display_name, relation, age_group, date_of_birth
      ) VALUES (
        resolved_family_id, CASE WHEN relation = 'owner' THEN user_id ELSE NULL END,
        CASE WHEN relation = 'owner' THEN 'admin' ELSE 'dependent' END,
        btrim(profile ->> 'name'), CASE WHEN relation = 'owner' THEN 'self' ELSE relation END,
        cloud_db_meta.ios_age_group(birth_year),
        CASE WHEN birth_year IS NULL THEN NULL ELSE make_date(birth_year, 1, 1) END
      ) RETURNING id INTO member_id;
    ELSE
      UPDATE core.family_member fm SET
        display_name = btrim(profile ->> 'name'),
        relation = CASE WHEN relation = 'owner' THEN 'self' ELSE relation END,
        age_group = cloud_db_meta.ios_age_group(birth_year),
        date_of_birth = CASE WHEN birth_year IS NULL THEN NULL ELSE make_date(birth_year, 1, 1) END
      WHERE fm.id = member_id AND fm.family_id = resolved_family_id;
    END IF;

    INSERT INTO app_storage.ios_profile_mapping (
      owner_user_id, client_profile_id, member_id, profile_data
    ) VALUES (user_id, client_id, member_id, profile)
    ON CONFLICT (owner_user_id, client_profile_id) DO UPDATE SET
      profile_data = EXCLUDED.profile_data, deleted_at = NULL, updated_at = clock_timestamp();
  END LOOP;
  RETURN public.ios_list_profiles(100);
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_list_profiles(p_limit integer DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE
  user_id uuid := cloud_db_meta.ensure_ios_user();
BEGIN
  IF p_limit NOT BETWEEN 0 AND 100 THEN
    RAISE EXCEPTION 'invalid limit' USING ERRCODE = '22023';
  END IF;
  RETURN jsonb_build_object('profiles', coalesce((
    SELECT jsonb_agg(profile_data ORDER BY updated_at DESC, client_profile_id)
    FROM (SELECT profile_data, updated_at, client_profile_id
          FROM app_storage.ios_profile_mapping
          WHERE owner_user_id = user_id AND deleted_at IS NULL
          ORDER BY updated_at DESC, client_profile_id LIMIT p_limit) profiles
  ), '[]'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_delete_profile(p_client_profile_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE
  user_id uuid := cloud_db_meta.ensure_ios_user();
  changed integer;
BEGIN
  UPDATE app_storage.ios_profile_mapping
  SET deleted_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE owner_user_id = user_id AND client_profile_id = p_client_profile_id
    AND deleted_at IS NULL;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed = 0 THEN RAISE EXCEPTION 'profile not found' USING ERRCODE = 'P0002'; END IF;
  RETURN jsonb_build_object('status', 'deleted', 'id', p_client_profile_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_sync_health_readings(
  p_batch_id text,
  p_device_id text,
  p_readings jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta, public, extensions
AS $$
DECLARE
  user_id uuid := cloud_db_meta.ensure_ios_user();
  reading jsonb;
  client_id text;
  profile_id text;
  member_id uuid;
  metric text;
  source_name text;
  source_kind text;
  recorded_at timestamptz;
  content_hash text;
  existing app_storage.ios_health_reading%ROWTYPE;
  sync_id uuid;
  projection_id uuid;
  results jsonb := '[]'::jsonb;
  accepted integer := 0;
  rejected integer := 0;
BEGIN
  IF nullif(btrim(p_batch_id), '') IS NULL OR length(p_batch_id) > 128
     OR nullif(btrim(p_device_id), '') IS NULL OR length(p_device_id) > 200
     OR jsonb_typeof(p_readings) <> 'array'
     OR jsonb_array_length(p_readings) NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'invalid batch' USING ERRCODE = '22023';
  END IF;

  FOR reading IN SELECT value FROM jsonb_array_elements(p_readings)
  LOOP
    client_id := coalesce(reading ->> 'id', '');
    BEGIN
      profile_id := reading ->> 'profile_id';
      metric := reading ->> 'metric_type';
      source_kind := reading ->> 'source';
      source_name := reading ->> 'source_name';
      IF length(client_id) NOT BETWEEN 1 AND 128
         OR metric NOT IN ('heartRate','spo2','bloodPressure','bodyTemperature','stress','hrv','ecg','bloodGlucose','bodyComposition','emotion','uv','steps','calories','distance','sleep','sport')
         OR source_kind NOT IN ('ring','phone','watch','band','medical','unknown')
         OR nullif(source_name, '') IS NULL
         OR (reading ->> 'accuracy')::integer NOT BETWEEN 1 AND 3
         OR jsonb_typeof(reading -> 'value') <> 'number'
         OR jsonb_typeof(reading -> 'timestamp') <> 'number' THEN
        RAISE EXCEPTION 'invalid reading fields' USING ERRCODE = '22023';
      END IF;
      SELECT m.member_id INTO member_id FROM app_storage.ios_profile_mapping m
      WHERE m.owner_user_id = user_id AND m.client_profile_id = profile_id
        AND m.deleted_at IS NULL;
      IF member_id IS NULL THEN
        RAISE EXCEPTION 'profile not found' USING ERRCODE = '42501';
      END IF;
      recorded_at := to_timestamp((reading ->> 'timestamp')::double precision);
      content_hash := encode(extensions.digest(convert_to(reading::text, 'UTF8'), 'sha256'), 'hex');
      SELECT * INTO existing FROM app_storage.ios_health_reading r
      WHERE r.owner_user_id = user_id AND r.client_reading_id = client_id;
      IF FOUND THEN
        IF existing.content_hash <> content_hash THEN
          RAISE EXCEPTION 'reading id conflicts with existing content' USING ERRCODE = '23505';
        END IF;
        sync_id := existing.id;
      ELSE
        projection_id := NULL;
        INSERT INTO app_storage.ios_health_reading (
          owner_user_id, member_id, client_reading_id, content_hash,
          metric_type, source, recorded_at, raw_payload
        ) VALUES (
          user_id, member_id, client_id, content_hash, metric, source_kind,
          recorded_at, reading
        ) RETURNING id INTO sync_id;

        IF source_kind = 'phone' AND lower(source_name) LIKE '%rppg%'
           AND metric IN ('heartRate','spo2','bodyTemperature','stress','hrv','steps') THEN
          projection_id := public.sync_vital_reading(
            p_member_id => member_id,
            p_device_identifier => p_device_id,
            p_source => 'rppg_phone',
            p_recorded_at => recorded_at,
            p_client_event_id => client_id,
            p_heart_rate => CASE WHEN metric = 'heartRate' THEN (reading ->> 'value')::double precision END,
            p_spo2 => CASE WHEN metric = 'spo2' THEN (reading ->> 'value')::double precision END,
            p_hrv => CASE WHEN metric = 'hrv' THEN (reading ->> 'value')::double precision END,
            p_temperature => CASE WHEN metric = 'bodyTemperature' THEN (reading ->> 'value')::double precision END,
            p_stress => CASE WHEN metric = 'stress' THEN (reading ->> 'value')::double precision END,
            p_steps => CASE WHEN metric = 'steps' THEN (reading ->> 'value')::integer END,
            p_raw_data => reading
          );
          UPDATE app_storage.ios_health_reading SET projected_reading_id = projection_id
          WHERE id = sync_id;
        END IF;
      END IF;
      accepted := accepted + 1;
      results := results || jsonb_build_array(jsonb_build_object(
        'id', client_id, 'sync_id', sync_id, 'status', 'accepted', 'reason', NULL
      ));
    EXCEPTION WHEN OTHERS THEN
      rejected := rejected + 1;
      results := results || jsonb_build_array(jsonb_build_object(
        'id', client_id, 'sync_id', NULL, 'status', 'rejected',
        'reason', CASE SQLSTATE
          WHEN '23505' THEN 'reading_id_conflict'
          WHEN '42501' THEN 'profile_not_available'
          ELSE 'invalid_reading'
        END
      ));
    END;
  END LOOP;
  RETURN jsonb_build_object(
    'status', CASE WHEN rejected = 0 THEN 'ok' ELSE 'partial' END,
    'batch_id', p_batch_id, 'accepted', accepted, 'rejected', rejected, 'results', results
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_list_health_readings(
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE
  user_id uuid := cloud_db_meta.ensure_ios_user();
  total integer;
  items jsonb;
BEGIN
  IF p_limit NOT BETWEEN 0 AND 200 OR p_offset NOT BETWEEN 0 AND 100000 THEN
    RAISE EXCEPTION 'invalid pagination' USING ERRCODE = '22023';
  END IF;
  SELECT count(*) INTO total FROM app_storage.ios_health_reading
  WHERE owner_user_id = user_id;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', client_reading_id, 'user_id', user_id, 'results', raw_payload,
    'created_at', created_at
  ) ORDER BY recorded_at DESC, client_reading_id), '[]'::jsonb)
  INTO items
  FROM (SELECT * FROM app_storage.ios_health_reading
        WHERE owner_user_id = user_id
        ORDER BY recorded_at DESC, client_reading_id
        LIMIT p_limit OFFSET p_offset) page;
  RETURN jsonb_build_object('readings', items, 'count', total);
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_save_chat_history(
  p_client_session_id text,
  p_revision integer,
  p_messages jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE
  user_id uuid := cloud_db_meta.ensure_ios_user();
  session_id text := coalesce(nullif(btrim(p_client_session_id), ''), gen_random_uuid()::text);
  row app_storage.ios_chat_session%ROWTYPE;
BEGIN
  IF length(session_id) > 128 OR jsonb_typeof(p_messages) <> 'array'
     OR jsonb_array_length(p_messages) > 200 OR coalesce(p_revision, 1) < 1 THEN
    RAISE EXCEPTION 'invalid chat session' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO row FROM app_storage.ios_chat_session
  WHERE owner_user_id = user_id AND client_session_id = session_id;
  IF FOUND AND p_revision IS NOT NULL AND p_revision <> row.revision + 1 THEN
    RAISE EXCEPTION 'revision conflict' USING ERRCODE = '40001';
  END IF;
  INSERT INTO app_storage.ios_chat_session (
    owner_user_id, client_session_id, revision, messages
  ) VALUES (user_id, session_id, coalesce(p_revision, 1), p_messages)
  ON CONFLICT (owner_user_id, client_session_id) DO UPDATE SET
    revision = coalesce(p_revision, app_storage.ios_chat_session.revision + 1),
    messages = EXCLUDED.messages, deleted_at = NULL, updated_at = clock_timestamp()
  RETURNING * INTO row;
  RETURN jsonb_build_object(
    'id', row.id, 'client_session_id', row.client_session_id,
    'revision', row.revision, 'created_at', row.created_at,
    'updated_at', row.updated_at, 'deleted_at', row.deleted_at,
    'messages', row.messages
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_list_chat_history(p_limit integer DEFAULT 20)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE user_id uuid := cloud_db_meta.ensure_ios_user();
BEGIN
  IF p_limit NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'invalid limit' USING ERRCODE = '22023'; END IF;
  RETURN jsonb_build_object('sessions', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'client_session_id', client_session_id, 'revision', revision,
      'created_at', created_at, 'updated_at', updated_at, 'deleted_at', deleted_at,
      'messages', messages
    ) ORDER BY updated_at DESC, id)
    FROM (SELECT * FROM app_storage.ios_chat_session
          WHERE owner_user_id = user_id AND deleted_at IS NULL
          ORDER BY updated_at DESC, id LIMIT p_limit) sessions
  ), '[]'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_delete_chat_history(p_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE user_id uuid := cloud_db_meta.ensure_ios_user(); changed integer;
BEGIN
  UPDATE app_storage.ios_chat_session SET deleted_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE owner_user_id = user_id AND id::text = p_id AND deleted_at IS NULL;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed = 0 THEN RAISE EXCEPTION 'session not found' USING ERRCODE = 'P0002'; END IF;
  RETURN jsonb_build_object('status', 'deleted', 'id', p_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_delete_chat_session(
  p_client_session_id text,
  p_revision integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE user_id uuid := cloud_db_meta.ensure_ios_user(); row app_storage.ios_chat_session%ROWTYPE;
BEGIN
  UPDATE app_storage.ios_chat_session SET deleted_at = clock_timestamp(), updated_at = clock_timestamp()
  WHERE owner_user_id = user_id AND client_session_id = p_client_session_id
    AND deleted_at IS NULL AND (p_revision IS NULL OR revision = p_revision)
  RETURNING * INTO row;
  IF NOT FOUND THEN RAISE EXCEPTION 'session not found or revision conflict' USING ERRCODE = 'P0002'; END IF;
  RETURN jsonb_build_object(
    'status', 'deleted', 'id', row.id, 'client_session_id', row.client_session_id,
    'revision', row.revision, 'deleted_at', row.deleted_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_save_chat_feedback(
  p_client_session_id text,
  p_message_id text,
  p_version_id text,
  p_feedback text,
  p_revision integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE user_id uuid := cloud_db_meta.ensure_ios_user(); row app_storage.ios_chat_feedback%ROWTYPE;
BEGIN
  IF p_feedback NOT IN ('up', 'down') OR NOT EXISTS (
    SELECT 1 FROM app_storage.ios_chat_session
    WHERE owner_user_id = user_id AND client_session_id = p_client_session_id AND deleted_at IS NULL
  ) THEN RAISE EXCEPTION 'invalid feedback target' USING ERRCODE = '22023'; END IF;
  INSERT INTO app_storage.ios_chat_feedback (
    owner_user_id, client_session_id, message_id, version_id, feedback, revision
  ) VALUES (user_id, p_client_session_id, p_message_id, p_version_id, p_feedback, p_revision)
  ON CONFLICT (owner_user_id, client_session_id, message_id, version_id) DO UPDATE SET
    feedback = EXCLUDED.feedback, revision = EXCLUDED.revision, updated_at = clock_timestamp()
  RETURNING * INTO row;
  RETURN jsonb_build_object(
    'id', row.id, 'client_session_id', row.client_session_id,
    'message_id', row.message_id, 'version_id', row.version_id,
    'feedback', row.feedback, 'revision', row.revision,
    'created_at', row.created_at, 'updated_at', row.updated_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_save_ocr_report(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE user_id uuid := cloud_db_meta.ensure_ios_user(); row app_storage.ios_ocr_report%ROWTYPE;
BEGIN
  IF jsonb_typeof(p_payload) <> 'object' OR jsonb_array_length(coalesce(p_payload -> 'items', '[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'invalid OCR report' USING ERRCODE = '22023';
  END IF;
  INSERT INTO app_storage.ios_ocr_report (owner_user_id, payload, report_date)
  VALUES (
    user_id, p_payload,
    CASE WHEN coalesce(p_payload ->> 'report_date', '') ~ '^\d{4}-\d{2}-\d{2}$'
      THEN (p_payload ->> 'report_date')::date ELSE NULL END
  ) RETURNING * INTO row;
  RETURN jsonb_build_object('id', row.id, 'payload', row.payload,
    'report_date', row.report_date, 'created_at', row.created_at);
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_list_ocr_reports(p_limit integer DEFAULT 20)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE user_id uuid := cloud_db_meta.ensure_ios_user();
BEGIN
  IF p_limit NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'invalid limit' USING ERRCODE = '22023'; END IF;
  RETURN jsonb_build_object('reports', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'payload', payload, 'report_date', report_date, 'created_at', created_at
    ) ORDER BY created_at DESC, id)
    FROM (SELECT * FROM app_storage.ios_ocr_report
          WHERE owner_user_id = user_id AND deleted_at IS NULL
          ORDER BY created_at DESC, id LIMIT p_limit) reports
  ), '[]'::jsonb));
END;
$$;

CREATE OR REPLACE FUNCTION public.ios_delete_ocr_report(p_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app_storage, cloud_db_meta
AS $$
DECLARE user_id uuid := cloud_db_meta.ensure_ios_user(); changed integer;
BEGIN
  UPDATE app_storage.ios_ocr_report SET deleted_at = clock_timestamp()
  WHERE owner_user_id = user_id AND id::text = p_id AND deleted_at IS NULL;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed = 0 THEN RAISE EXCEPTION 'report not found' USING ERRCODE = 'P0002'; END IF;
  RETURN jsonb_build_object('status', 'deleted', 'id', p_id);
END;
$$;

DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'ios_profile_mapping', 'ios_health_reading', 'ios_chat_session',
    'ios_chat_feedback', 'ios_ocr_report'
  ] LOOP
    EXECUTE format('ALTER TABLE app_storage.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE app_storage.%I FORCE ROW LEVEL SECURITY', table_name);
    EXECUTE format('DROP POLICY IF EXISTS ios_owner_access ON app_storage.%I', table_name);
    EXECUTE format(
      'CREATE POLICY ios_owner_access ON app_storage.%I TO authenticated USING (owner_user_id = cloud_db_meta.current_user_id()) WITH CHECK (owner_user_id = cloud_db_meta.current_user_id())',
      table_name
    );
  END LOOP;
END;
$$;

REVOKE ALL ON TABLE app_storage.ios_profile_mapping, app_storage.ios_health_reading,
  app_storage.ios_chat_session, app_storage.ios_chat_feedback,
  app_storage.ios_ocr_report FROM PUBLIC;
GRANT USAGE ON SCHEMA app_storage TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE app_storage.ios_profile_mapping,
  app_storage.ios_health_reading, app_storage.ios_chat_session,
  app_storage.ios_chat_feedback, app_storage.ios_ocr_report TO authenticated;
GRANT ALL ON TABLE app_storage.ios_profile_mapping, app_storage.ios_health_reading,
  app_storage.ios_chat_session, app_storage.ios_chat_feedback,
  app_storage.ios_ocr_report TO service_role;

REVOKE ALL ON FUNCTION cloud_db_meta.ensure_ios_user(),
  cloud_db_meta.ensure_ios_family(uuid), cloud_db_meta.ios_age_group(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ios_sync_profiles(jsonb), public.ios_list_profiles(integer),
  public.ios_delete_profile(text), public.ios_sync_health_readings(text, text, jsonb),
  public.ios_list_health_readings(integer, integer),
  public.ios_save_chat_history(text, integer, jsonb), public.ios_list_chat_history(integer),
  public.ios_delete_chat_history(text), public.ios_delete_chat_session(text, integer),
  public.ios_save_chat_feedback(text, text, text, text, integer),
  public.ios_save_ocr_report(jsonb), public.ios_list_ocr_reports(integer),
  public.ios_delete_ocr_report(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ios_sync_profiles(jsonb), public.ios_list_profiles(integer),
  public.ios_delete_profile(text), public.ios_sync_health_readings(text, text, jsonb),
  public.ios_list_health_readings(integer, integer),
  public.ios_save_chat_history(text, integer, jsonb), public.ios_list_chat_history(integer),
  public.ios_delete_chat_history(text), public.ios_delete_chat_session(text, integer),
  public.ios_save_chat_feedback(text, text, text, text, integer),
  public.ios_save_ocr_report(jsonb), public.ios_list_ocr_reports(integer),
  public.ios_delete_ocr_report(text) TO authenticated, service_role;

COMMIT;
