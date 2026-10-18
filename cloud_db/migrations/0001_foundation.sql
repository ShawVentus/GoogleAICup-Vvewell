BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin NOLOGIN SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS;
  END IF;
END;
$$;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS cloud_db_meta;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS ingest;
CREATE SCHEMA IF NOT EXISTS telemetry;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS inference;
CREATE SCHEMA IF NOT EXISTS medical;
CREATE SCHEMA IF NOT EXISTS insurance;
CREATE SCHEMA IF NOT EXISTS care;
CREATE SCHEMA IF NOT EXISTS security;

CREATE TABLE IF NOT EXISTS cloud_db_meta.schema_migrations (
  version text PRIMARY KEY,
  checksum text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION cloud_db_meta.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.epoch_ms_to_timestamptz(epoch_ms bigint)
RETURNS timestamptz
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
  SELECT to_timestamp(epoch_ms::double precision / 1000.0);
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.current_user_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  raw_value text;
BEGIN
  raw_value := nullif(current_setting('request.jwt.claim.sub', true), '');
  IF raw_value IS NULL THEN
    raw_value := nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub';
  END IF;
  IF raw_value IS NULL THEN
    raw_value := nullif(current_setting('app.user_id', true), '');
  END IF;
  RETURN nullif(raw_value, '')::uuid;
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_meta.is_service()
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  role_value text;
BEGIN
  role_value := nullif(current_setting('request.jwt.claim.role', true), '');
  IF role_value IS NULL THEN
    role_value := nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role';
  END IF;
  RETURN role_value = 'service_role';
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN false;
END;
$$;

COMMIT;
