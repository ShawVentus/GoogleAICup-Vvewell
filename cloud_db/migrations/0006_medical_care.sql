BEGIN;

CREATE TABLE IF NOT EXISTS medical.medical_record_ocr (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  doc_type text NOT NULL CHECK (doc_type IN ('lab_report', 'imaging_report', 'prescription', 'discharge_summary', 'physical_exam', 'medical_record', 'other')),
  object_id uuid NOT NULL REFERENCES app_storage.object_ref(id) ON DELETE RESTRICT,
  document_date date,
  raw_text text,
  structured_data jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(structured_data) = 'object'),
  confidence numeric(6,5) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'needs_review', 'verified', 'rejected')),
  source text NOT NULL DEFAULT 'upload' CHECK (source IN ('upload', 'camera', 'hospital_api', 'manual')),
  reviewed_by_user_id uuid REFERENCES core.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((status = 'verified') = (reviewed_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS medical.clinical_entity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id uuid NOT NULL REFERENCES medical.medical_record_ocr(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  entity_type text NOT NULL CHECK (entity_type IN ('observation', 'diagnosis', 'procedure', 'medication', 'allergy', 'family_history', 'other')),
  standard_system text CHECK (standard_system IS NULL OR standard_system IN ('LOINC', 'ICD-11', 'SNOMED-CT', 'ATC', 'FHIR', 'LOCAL')),
  standard_code text,
  entity_value jsonb NOT NULL,
  unit text,
  reference_range text,
  abnormal_flag boolean,
  confidence numeric(6,5) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  source_anchor jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(source_anchor) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((standard_system IS NULL) = (standard_code IS NULL))
);

CREATE TABLE IF NOT EXISTS medical.medication_plan (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  drug_code_atc text,
  drug_name text NOT NULL,
  dose_text text,
  schedule jsonb NOT NULL CHECK (jsonb_typeof(schedule) = 'object'),
  start_at timestamptz NOT NULL,
  end_at timestamptz,
  prescriber text,
  source_record_id uuid REFERENCES medical.medical_record_ocr(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('planned', 'active', 'paused', 'completed', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (end_at IS NULL OR end_at >= start_at)
);

CREATE TABLE IF NOT EXISTS medical.medication_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES medical.medication_plan(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  taken_at timestamptz,
  status text NOT NULL CHECK (status IN ('scheduled', 'taken', 'missed', 'skipped', 'unknown')),
  source text NOT NULL CHECK (source IN ('manual', 'smart_pillbox', 'reminder', 'import')),
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence) = 'object'),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (plan_id, scheduled_at),
  CHECK ((status = 'taken') = (taken_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS medical.medical_service_order (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  service_type text NOT NULL,
  service_level text NOT NULL CHECK (service_level IN ('basic', 'expert', 'specialized', 'global_referral', 'emergency')),
  related_event_id uuid REFERENCES inference.health_event(id) ON DELETE SET NULL,
  order_status text NOT NULL DEFAULT 'requested' CHECK (order_status IN ('requested', 'authorized', 'scheduled', 'completed', 'cancelled')),
  appointment_time timestamptz,
  provider text,
  location jsonb CHECK (location IS NULL OR jsonb_typeof(location) = 'object'),
  authorized_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((order_status IN ('authorized', 'scheduled', 'completed')) = (authorized_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS care.care_event (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  trigger_source text NOT NULL CHECK (trigger_source IN ('mmwave_radar', 'emergency_button', 'door_sensor', 'environment_sensor', 'health_event', 'manual')),
  severity text NOT NULL CHECK (severity IN ('info', 'yellow', 'orange', 'red')),
  handle_status text NOT NULL DEFAULT 'detected' CHECK (handle_status IN ('detected', 'notifying', 'acknowledged', 'resolved', 'false_alarm')),
  detected_at timestamptz NOT NULL,
  acknowledged_at timestamptz,
  resolved_at timestamptz,
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence) = 'object'),
  related_health_event_id uuid REFERENCES inference.health_event(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (acknowledged_at IS NULL OR acknowledged_at >= detected_at),
  CHECK (resolved_at IS NULL OR resolved_at >= detected_at)
);

CREATE TABLE IF NOT EXISTS care.care_event_notification (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  care_event_id uuid NOT NULL REFERENCES care.care_event(id) ON DELETE CASCADE,
  contact_id uuid NOT NULL REFERENCES core.emergency_contact(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('app', 'sms', 'voice', 'email')),
  attempt_no smallint NOT NULL DEFAULT 1 CHECK (attempt_no BETWEEN 1 AND 20),
  status text NOT NULL CHECK (status IN ('queued', 'sent', 'delivered', 'acknowledged', 'failed')),
  sent_at timestamptz,
  acknowledged_at timestamptz,
  provider_message_id text,
  error text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (care_event_id, contact_id, channel, attempt_no),
  CHECK (status = 'queued' OR sent_at IS NOT NULL),
  CHECK (status <> 'acknowledged' OR acknowledged_at IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS care.reminder (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  reminder_type text NOT NULL,
  title text NOT NULL,
  description text,
  priority smallint NOT NULL DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'completed', 'dismissed', 'cancelled')),
  related_entity_type text,
  related_entity_id uuid,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'health_event_related_order_fk'
      AND conrelid = 'inference.health_event'::regclass
  ) THEN
    ALTER TABLE inference.health_event
      ADD CONSTRAINT health_event_related_order_fk
      FOREIGN KEY (related_order_id) REFERENCES medical.medical_service_order(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_medical_record_member_date ON medical.medical_record_ocr(member_id, document_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_clinical_entity_member_code ON medical.clinical_entity(member_id, standard_system, standard_code);
CREATE INDEX IF NOT EXISTS idx_medication_plan_member_status ON medical.medication_plan(member_id, status, start_at DESC);
CREATE INDEX IF NOT EXISTS idx_medication_event_member_scheduled ON medical.medication_event(member_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_medical_order_member_created ON medical.medical_service_order(member_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_care_event_member_detected ON care.care_event(member_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_care_event_open ON care.care_event(severity, detected_at) WHERE handle_status NOT IN ('resolved', 'false_alarm');
CREATE INDEX IF NOT EXISTS idx_care_notification_event ON care.care_event_notification(care_event_id, status, created_at);
CREATE INDEX IF NOT EXISTS idx_reminder_member_due ON care.reminder(member_id, status, due_at);

DROP TRIGGER IF EXISTS trg_medical_record_updated_at ON medical.medical_record_ocr;
CREATE TRIGGER trg_medical_record_updated_at BEFORE UPDATE ON medical.medical_record_ocr
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_medication_plan_updated_at ON medical.medication_plan;
CREATE TRIGGER trg_medication_plan_updated_at BEFORE UPDATE ON medical.medication_plan
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_medical_order_updated_at ON medical.medical_service_order;
CREATE TRIGGER trg_medical_order_updated_at BEFORE UPDATE ON medical.medical_service_order
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_care_event_updated_at ON care.care_event;
CREATE TRIGGER trg_care_event_updated_at BEFORE UPDATE ON care.care_event
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();
DROP TRIGGER IF EXISTS trg_reminder_updated_at ON care.reminder;
CREATE TRIGGER trg_reminder_updated_at BEFORE UPDATE ON care.reminder
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();

COMMIT;
