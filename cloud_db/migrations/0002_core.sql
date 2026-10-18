BEGIN;

CREATE TABLE IF NOT EXISTS core.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_uid uuid UNIQUE,
  username text NOT NULL UNIQUE CHECK (length(btrim(username)) BETWEEN 1 AND 100),
  display_name text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  CHECK ((status = 'deleted') = (deleted_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS core.families (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE RESTRICT,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  CHECK ((status = 'deleted') = (deleted_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS core.family_member (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES core.families(id) ON DELETE CASCADE,
  member_user_id uuid REFERENCES core.users(id) ON DELETE SET NULL,
  role text NOT NULL CHECK (role IN ('admin', 'member', 'dependent', 'readonly_guardian')),
  real_name text,
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 1 AND 120),
  relation text NOT NULL DEFAULT 'other',
  age_group text NOT NULL CHECK (age_group IN ('child', 'adult', 'elder')),
  date_of_birth date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'deleted')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  deleted_at timestamptz,
  UNIQUE (family_id, member_user_id),
  CHECK ((status = 'deleted') = (deleted_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS core.devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  device_id text NOT NULL CHECK (length(btrim(device_id)) BETWEEN 1 AND 200),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  type text NOT NULL CHECK (type IN (
    'aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar',
    'infrared_camera', 'blood_pressure_monitor', 'glucose_meter',
    'body_scale', 'emergency_button', 'door_sensor',
    'environment_sensor', 'smart_pillbox', 'smart_mattress'
  )),
  firmware_version text,
  battery_percent integer CHECK (battery_percent BETWEEN 0 AND 100),
  connected boolean NOT NULL DEFAULT false,
  last_sync_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, device_id)
);

CREATE TABLE IF NOT EXISTS core.member_permission (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES core.families(id) ON DELETE CASCADE,
  grantee_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE CASCADE,
  target_member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  permission_type text NOT NULL CHECK (permission_type IN ('owner', 'manage', 'read', 'emergency_read')),
  auth_scope text[] NOT NULL DEFAULT ARRAY['basic']::text[],
  granted_by_user_id uuid NOT NULL REFERENCES core.users(id) ON DELETE RESTRICT,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (grantee_user_id, target_member_id, permission_type),
  CHECK (cardinality(auth_scope) > 0),
  CHECK (expires_at IS NULL OR expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS core.emergency_contact (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  contact_user_id uuid REFERENCES core.users(id) ON DELETE SET NULL,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  phone_e164 text CHECK (phone_e164 IS NULL OR phone_e164 ~ '^\\+[1-9][0-9]{7,14}$'),
  priority smallint NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 20),
  channels text[] NOT NULL DEFAULT ARRAY['app']::text[],
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (cardinality(channels) > 0),
  CHECK (channels <@ ARRAY['app', 'sms', 'voice', 'email']::text[])
);

CREATE INDEX IF NOT EXISTS idx_family_member_family ON core.family_member(family_id, status);
CREATE INDEX IF NOT EXISTS idx_family_member_user ON core.family_member(member_user_id) WHERE member_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_devices_member ON core.devices(member_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_member_permission_target ON core.member_permission(target_member_id, grantee_user_id);
CREATE INDEX IF NOT EXISTS idx_emergency_contact_member ON core.emergency_contact(member_id, priority) WHERE is_active;

DROP TRIGGER IF EXISTS trg_users_updated_at ON core.users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON core.users
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_families_updated_at ON core.families;
CREATE TRIGGER trg_families_updated_at BEFORE UPDATE ON core.families
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_family_member_updated_at ON core.family_member;
CREATE TRIGGER trg_family_member_updated_at BEFORE UPDATE ON core.family_member
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_devices_updated_at ON core.devices;
CREATE TRIGGER trg_devices_updated_at BEFORE UPDATE ON core.devices
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_member_permission_updated_at ON core.member_permission;
CREATE TRIGGER trg_member_permission_updated_at BEFORE UPDATE ON core.member_permission
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_emergency_contact_updated_at ON core.emergency_contact;
CREATE TRIGGER trg_emergency_contact_updated_at BEFORE UPDATE ON core.emergency_contact
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();

COMMIT;
