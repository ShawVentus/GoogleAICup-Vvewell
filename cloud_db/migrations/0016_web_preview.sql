-- Browser reads reuse the existing member ACL; no service-role key enters the client.
BEGIN;
CREATE OR REPLACE FUNCTION public.web_list_profiles()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, core, app_storage, cloud_db_meta
AS $$
DECLARE
  request_user uuid := cloud_db_meta.ensure_ios_user();
BEGIN
  RETURN jsonb_build_object('profiles', coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'id', fm.id, 'name', fm.display_name, 'relationship', fm.relation,
      'birth_year', extract(year FROM fm.date_of_birth)::integer,
      'gender', coalesce(mapping.profile_data ->> 'gender', 'unknown'),
      'client_profile_id', mapping.client_profile_id
    ) ORDER BY fm.created_at)
    FROM core.family_member fm
    LEFT JOIN app_storage.ios_profile_mapping mapping
      ON mapping.member_id = fm.id AND mapping.owner_user_id = request_user
      AND mapping.deleted_at IS NULL
    WHERE fm.status = 'active' AND cloud_db_meta.can_access_member(fm.id, 'basic')
  ), '[]'::jsonb));
END;
$$;
CREATE OR REPLACE FUNCTION public.web_list_readings(p_member_id uuid, p_limit integer DEFAULT 1000)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, telemetry, cloud_db_meta
AS $$
BEGIN
  IF p_limit NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'invalid limit' USING ERRCODE = '22023';
  END IF;
  IF NOT cloud_db_meta.can_access_member(p_member_id, 'basic') THEN
    RAISE EXCEPTION 'member access denied' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object('readings', coalesce((
    SELECT jsonb_agg(to_jsonb(row) ORDER BY row.recorded_at DESC) FROM (
      SELECT id, member_id, metric_type, value, unit, source, confidence,
             is_valid, is_abnormal, recorded_at
      FROM telemetry.feature_observation
      WHERE member_id = p_member_id
        AND metadata ->> 'mock_run_id' IS NULL
        AND metadata ->> 'is_mock' IS DISTINCT FROM 'true'
        AND source NOT IN ('mock', 'demo')
      ORDER BY recorded_at DESC LIMIT p_limit
    ) row
  ), '[]'::jsonb));
END;
$$;
REVOKE ALL ON FUNCTION public.web_list_profiles() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.web_list_readings(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.web_list_profiles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.web_list_readings(uuid, integer) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
