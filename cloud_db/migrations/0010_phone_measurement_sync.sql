BEGIN;

-- Resolve Supabase Auth UUIDs to the application's core.users UUID. Existing
-- fixtures use the same UUID in both places, while production may use auth_uid.
CREATE OR REPLACE FUNCTION cloud_db_meta.current_user_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta
AS $$
DECLARE
  raw_value text;
  raw_uuid uuid;
  resolved_id uuid;
BEGIN
  raw_value := nullif(current_setting('request.jwt.claim.sub', true), '');
  IF raw_value IS NULL THEN
    raw_value := nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub';
  END IF;
  IF raw_value IS NULL THEN
    raw_value := nullif(current_setting('app.user_id', true), '');
  END IF;
  raw_uuid := nullif(raw_value, '')::uuid;

  SELECT u.id INTO resolved_id
  FROM core.users u
  WHERE u.id = raw_uuid OR u.auth_uid = raw_uuid
  ORDER BY (u.id = raw_uuid) DESC
  LIMIT 1;

  RETURN coalesce(resolved_id, raw_uuid);
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$;

-- Public PostgREST entry point for the phone app. It accepts the stable device
-- identifier stored by the Android app and resolves the cloud UUID server-side.
CREATE OR REPLACE FUNCTION public.sync_vital_reading(
  p_member_id uuid,
  p_device_identifier text,
  p_source text,
  p_recorded_at timestamptz,
  p_client_event_id text DEFAULT NULL,
  p_heart_rate double precision DEFAULT NULL,
  p_spo2 double precision DEFAULT NULL,
  p_hrv double precision DEFAULT NULL,
  p_respiratory_rate double precision DEFAULT NULL,
  p_temperature double precision DEFAULT NULL,
  p_stress double precision DEFAULT NULL,
  p_steps integer DEFAULT NULL,
  p_signal_quality numeric DEFAULT NULL,
  p_confidence numeric DEFAULT NULL,
  p_is_valid boolean DEFAULT true,
  p_is_abnormal boolean DEFAULT false,
  p_raw_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, core, cloud_db_meta, ingest
AS $$
DECLARE
  resolved_device_id uuid;
BEGIN
  IF NOT cloud_db_meta.can_access_member(p_member_id, 'write') THEN
    RAISE EXCEPTION 'authenticated user cannot write this member' USING ERRCODE = '42501';
  END IF;

  SELECT d.id INTO resolved_device_id
  FROM core.devices d
  WHERE d.member_id = p_member_id
    AND d.device_id = btrim(p_device_identifier)
  LIMIT 1;

  IF resolved_device_id IS NULL THEN
    RAISE EXCEPTION 'cloud device is not registered for this member' USING ERRCODE = '23503';
  END IF;

  RETURN ingest.upsert_vital_reading(
    p_member_id, resolved_device_id, p_source, p_recorded_at,
    p_client_event_id, p_heart_rate, p_spo2, p_hrv, p_respiratory_rate,
    p_temperature, p_stress, p_steps, p_signal_quality, p_confidence,
    p_is_valid, p_is_abnormal, p_raw_data
  );
END;
$$;

REVOKE ALL ON FUNCTION public.sync_vital_reading(
  uuid, text, text, timestamptz, text, double precision, double precision,
  double precision, double precision, double precision, double precision,
  integer, numeric, numeric, boolean, boolean, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_vital_reading(
  uuid, text, text, timestamptz, text, double precision, double precision,
  double precision, double precision, double precision, double precision,
  integer, numeric, numeric, boolean, boolean, jsonb
) TO authenticated, service_role;

COMMIT;
