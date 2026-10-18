BEGIN;

CREATE TABLE IF NOT EXISTS insurance.insurance_product (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  carrier text NOT NULL,
  product_code text NOT NULL UNIQUE,
  product_type text NOT NULL CHECK (product_type IN (
    'medical', 'critical_illness', 'cancer', 'term_life', 'whole_life',
    'accident', 'long_term_care', 'child_medical', 'education', 'family_bundle'
  )),
  name text NOT NULL,
  eligibility_rules jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(eligibility_rules) = 'object'),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  active_from date NOT NULL,
  active_to date,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (active_to IS NULL OR active_to >= active_from)
);

CREATE TABLE IF NOT EXISTS insurance.insurance_risk_profile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  risk_score numeric(5,2) NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
  risk_level text NOT NULL CHECK (risk_level IN ('A', 'B', 'C', 'D', 'E')),
  factor_details jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(factor_details) = 'array'),
  data_coverage numeric(6,5) NOT NULL CHECK (data_coverage BETWEEN 0 AND 1),
  model_version_id uuid NOT NULL REFERENCES inference.model_version(id) ON DELETE RESTRICT,
  calculated_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (member_id, calculated_at)
);

CREATE TABLE IF NOT EXISTS insurance.insurance_recommendation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES core.families(id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES core.family_member(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES insurance.insurance_product(id) ON DELETE RESTRICT,
  estimated_premium_min numeric(14,2) CHECK (estimated_premium_min IS NULL OR estimated_premium_min >= 0),
  estimated_premium_max numeric(14,2) CHECK (estimated_premium_max IS NULL OR estimated_premium_max >= 0),
  suggestion text NOT NULL,
  related_risk_factors jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(related_risk_factors) = 'array'),
  consent_id uuid NOT NULL REFERENCES security.consent(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  CHECK (estimated_premium_max IS NULL OR estimated_premium_min IS NULL OR estimated_premium_max >= estimated_premium_min),
  CHECK (expires_at > created_at)
);

CREATE INDEX IF NOT EXISTS idx_insurance_product_type_active ON insurance.insurance_product(product_type, active_from, active_to);
CREATE INDEX IF NOT EXISTS idx_risk_profile_member_calculated ON insurance.insurance_risk_profile(member_id, calculated_at DESC);
CREATE INDEX IF NOT EXISTS idx_recommendation_member_created ON insurance.insurance_recommendation(member_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_insurance_product_updated_at ON insurance.insurance_product;
CREATE TRIGGER trg_insurance_product_updated_at BEFORE UPDATE ON insurance.insurance_product
FOR EACH ROW EXECUTE FUNCTION cloud_db_meta.touch_updated_at();

COMMIT;
