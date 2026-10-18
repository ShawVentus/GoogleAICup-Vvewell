BEGIN;

CREATE SCHEMA IF NOT EXISTS app_storage;

CREATE TABLE IF NOT EXISTS app_storage.object_ref (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  object_type text NOT NULL CHECK (object_type IN (
    'raw_signal', 'ocr_document', 'medical_attachment', 'export',
    'deletion_proof', 'model_artifact', 'other'
  )),
  bucket text NOT NULL CHECK (length(btrim(bucket)) BETWEEN 1 AND 100),
  object_key text NOT NULL CHECK (length(btrim(object_key)) BETWEEN 1 AND 1024),
  content_type text NOT NULL,
  content_size_bytes bigint NOT NULL CHECK (content_size_bytes >= 0),
  content_sha256 text NOT NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
  encryption_key_ref text,
  retention_class text NOT NULL CHECK (retention_class IN ('hot', 'warm', 'cold', 'audit', 'core')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz,
  deleted_at timestamptz,
  UNIQUE (bucket, object_key),
  CHECK (expires_at IS NULL OR expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS ingest.sync_batch (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES core.devices(id) ON DELETE CASCADE,
  source text NOT NULL CHECK (source IN ('aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar')),
  client_batch_id text NOT NULL CHECK (length(btrim(client_batch_id)) BETWEEN 1 AND 200),
  recorded_from timestamptz,
  recorded_to timestamptz,
  item_count integer NOT NULL CHECK (item_count BETWEEN 0 AND 1000),
  accepted_count integer NOT NULL DEFAULT 0 CHECK (accepted_count >= 0),
  rejected_count integer NOT NULL DEFAULT 0 CHECK (rejected_count >= 0),
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'processing', 'completed', 'partial', 'failed')),
  error_summary jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(error_summary) = 'array'),
  received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (device_id, client_batch_id),
  CHECK (recorded_to IS NULL OR recorded_from IS NULL OR recorded_to >= recorded_from),
  CHECK (accepted_count + rejected_count <= item_count),
  CHECK ((status IN ('completed', 'partial', 'failed')) = (completed_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS ingest.sync_cursor (
  device_id uuid NOT NULL REFERENCES core.devices(id) ON DELETE CASCADE,
  source text NOT NULL CHECK (source IN ('aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar')),
  last_recorded_at timestamptz,
  last_server_cursor text,
  last_batch_id uuid REFERENCES ingest.sync_batch(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (device_id, source)
);

CREATE INDEX IF NOT EXISTS idx_object_ref_member_created ON app_storage.object_ref(member_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_object_ref_retention ON app_storage.object_ref(retention_class, expires_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sync_batch_member_received ON ingest.sync_batch(member_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_batch_status ON ingest.sync_batch(status, received_at) WHERE status NOT IN ('completed', 'failed');

COMMIT;
