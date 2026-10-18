CREATE SCHEMA IF NOT EXISTS cloud_db_test;

CREATE OR REPLACE FUNCTION cloud_db_test.assert_true(condition boolean, message text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'assertion failed: %', message;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION cloud_db_test.expect_sqlstate(
  statement text,
  expected_state text,
  message text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  actual_state text;
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE;
      IF actual_state = expected_state THEN
        RETURN;
      END IF;
      RAISE EXCEPTION 'assertion failed: %, expected SQLSTATE %, got %',
        message, expected_state, actual_state;
  END;
  RAISE EXCEPTION 'assertion failed: %, statement did not fail', message;
END;
$$;

GRANT USAGE ON SCHEMA cloud_db_test TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cloud_db_test TO authenticated;
