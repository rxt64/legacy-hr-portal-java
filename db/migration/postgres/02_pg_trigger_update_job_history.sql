-- =====================================================================
-- GEPER - Gestion de Personal y Puestos
-- 02_pg_trigger_update_job_history.sql  -- RUN AS A SUPERUSER/ADMIN ROLE
-- (creates objects owned by geper_owner; requires 01_pg_schema_and_roles.sql
-- to have been applied first)
--
-- PL/pgSQL equivalent of the Oracle UPDATE_JOB_HISTORY PL/SQL trigger.
--
-- When an employee's job_id or department_id changes, the PRIOR assignment
-- is closed off into job_history (its original start date through today)
-- and the employee's assignment_start_date is advanced to today. A plain
-- salary change does NOT touch the history. This is the same transactional
-- behaviour exercised by the test suite against the Oracle baseline.
--
-- fn_update_job_history() is LANGUAGE plpgsql SECURITY DEFINER, so it runs
-- with the privileges of its owner (geper_owner) regardless of which role
-- invokes the triggering UPDATE. This preserves the exact least-privilege,
-- definer-rights boundary from Oracle: geper_app needs no direct INSERT
-- privilege on job_history (granted only SELECT in
-- 01_pg_schema_and_roles.sql), yet the trigger can still insert into it.
--
-- The function also pins search_path to geper_owner, public so that the
-- unqualified table names below always resolve to the intended schema
-- regardless of the caller's own search_path, which is a required
-- hardening practice for SECURITY DEFINER functions in PostgreSQL.
-- =====================================================================

CREATE OR REPLACE FUNCTION geper_owner.fn_update_job_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = geper_owner, public
AS $$
BEGIN
  INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id)
  VALUES (OLD.employee_id, OLD.assignment_start_date, CURRENT_DATE,
          OLD.job_id, OLD.department_id);

  NEW.assignment_start_date := CURRENT_DATE;
  RETURN NEW;
END;
$$;

ALTER FUNCTION geper_owner.fn_update_job_history() OWNER TO geper_owner;

DROP TRIGGER IF EXISTS update_job_history ON geper_owner.employees;

CREATE TRIGGER update_job_history
  BEFORE UPDATE OF job_id, department_id ON geper_owner.employees
  FOR EACH ROW
  WHEN (
        COALESCE(OLD.job_id, '~')       <> COALESCE(NEW.job_id, '~')
     OR COALESCE(OLD.department_id, -1) <> COALESCE(NEW.department_id, -1)
  )
  EXECUTE FUNCTION geper_owner.fn_update_job_history();
