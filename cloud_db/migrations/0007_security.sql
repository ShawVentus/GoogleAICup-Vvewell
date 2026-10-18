BEGIN;

CREATE TABLE IF NOT EXISTS security.consent (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  granted_by_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE RESTRICT,
  grantee_type text NOT NULL CHECK (grantee_type IN ('family_user', 'hospital', 'insurer', 'research', 'service_provider')),
  grantee_id text NOT NULL,
  purpose text NOT NULL,
  auth_scope text[] NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
  policy_version text NOT NULL,
  granted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  revoked_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (cardinality(auth_scope) > 0),
  CHECK ((status = 'revoked') = (revoked_at IS NOT NULL)),
  CHECK (expires_at IS NULL OR expires_at > granted_at)
);

CREATE TABLE IF NOT EXISTS security.emergency_access_grant (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  contact_id uuid NOT NULL REFERENCES core.emergency_contact(id) ON DELETE CASCADE,
  care_event_id uuid NOT NULL REFERENCES care.care_event(id) ON DELETE CASCADE,
  scope text[] NOT NULL DEFAULT ARRAY['basic', 'alerts']::text[],
  reason text NOT NULL,
  granted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  UNIQUE (contact_id, care_event_id),
  CHECK (cardinality(scope) > 0),
  CHECK (expires_at > granted_at)
);

CREATE TABLE IF NOT EXISTS security.access_audit_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES core.users(id) ON DELETE SET NULL,
  family_id uuid REFERENCES core.families(id) ON DELETE SET NULL,
  target_member_id uuid REFERENCES core.family_member(id) ON DELETE SET NULL,
  action text NOT NULL,
  resource_type text NOT NULL,
  resource_id uuid,
  purpose text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  prev_hash text NOT NULL DEFAULT '',
  entry_hash text NOT NULL DEFAULT '',
  PRIMARY KEY (id, occurred_at),
  CHECK (prev_hash = '' OR prev_hash ~ '^[0-9a-f]{64}$'),
  CHECK (entry_hash = '' OR entry_hash ~ '^[0-9a-f]{64}$')
) PARTITION BY RANGE (occurred_at);

CREATE TABLE IF NOT EXISTS security.access_audit_log_default
  PARTITION OF security.access_audit_log DEFAULT;

CREATE TABLE IF NOT EXISTS security.data_export_job (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE RESTRICT,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  scope text[] NOT NULL,
  format text NOT NULL CHECK (format IN ('json', 'csv', 'fhir', 'cda', 'pdf')),
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'processing', 'completed', 'failed', 'expired')),
  object_id uuid REFERENCES app_storage.object_ref(id) ON DELETE SET NULL,
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  expires_at timestamptz,
  CHECK (cardinality(scope) > 0),
  CHECK (status <> 'completed' OR completed_at IS NOT NULL),
  CHECK (expires_at IS NULL OR expires_at > requested_at)
);

CREATE TABLE IF NOT EXISTS security.deletion_request (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE RESTRICT,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  scope text[] NOT NULL,
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'verified', 'processing', 'completed', 'rejected')),
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  verification_object_id uuid REFERENCES app_storage.object_ref(id) ON DELETE SET NULL,
  CHECK (cardinality(scope) > 0),
  CHECK (status <> 'completed' OR completed_at IS NOT NULL)
);

CREATE OR REPLACE FUNCTION security.hash_audit_entry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, security, extensions
AS $$
DECLARE
  previous text;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('security.access_audit_log'));
  SELECT entry_hash INTO previous
  FROM security.access_audit_log
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  NEW.prev_hash := coalesce(previous, '');
  NEW.entry_hash := encode(extensions.digest(concat_ws('|',
    NEW.id::text,
    coalesce(NEW.actor_user_id::text, ''),
    coalesce(NEW.family_id::text, ''),
    coalesce(NEW.target_member_id::text, ''),
    NEW.action,
    NEW.resource_type,
    coalesce(NEW.resource_id::text, ''),
    NEW.purpose,
    NEW.metadata::text,
    NEW.occurred_at::text,
    NEW.prev_hash
  ), 'sha256'), 'hex');
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION security.reject_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF coalesce(nullif(current_setting('app.maintenance', true), '')::boolean, false) THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;
  RAISE EXCEPTION 'audit records are append-only' USING ERRCODE = '55000';
END;
$$;

DROP TRIGGER IF EXISTS trg_access_audit_hash ON security.access_audit_log;
CREATE TRIGGER trg_access_audit_hash BEFORE INSERT ON security.access_audit_log
FOR EACH ROW EXECUTE FUNCTION security.hash_audit_entry();
DROP TRIGGER IF EXISTS trg_access_audit_immutable ON security.access_audit_log;
CREATE TRIGGER trg_access_audit_immutable BEFORE UPDATE OR DELETE ON security.access_audit_log
FOR EACH ROW EXECUTE FUNCTION security.reject_audit_mutation();

CREATE INDEX IF NOT EXISTS idx_consent_member_status ON security.consent(subject_member_id, status, expires_at);
CREATE INDEX IF NOT EXISTS idx_emergency_grant_member_expiry ON security.emergency_access_grant(member_id, expires_at) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_audit_member_occurred ON security.access_audit_log(target_member_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_occurred_brin ON security.access_audit_log USING brin(occurred_at);
CREATE INDEX IF NOT EXISTS idx_export_member_requested ON security.data_export_job(member_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_deletion_member_requested ON security.deletion_request(member_id, requested_at DESC);

DROP TRIGGER IF EXISTS trg_consent_updated_at ON security.consent;
CREATE TRIGGER trg_consent_updated_at BEFORE UPDATE ON security.consent
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();

COMMIT;
