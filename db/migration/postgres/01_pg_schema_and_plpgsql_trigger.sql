-- =====================================================================
-- GEPER - 01_pg_schema_and_plpgsql_trigger.sql
--
-- Esquema convertido de Oracle Database 12c R2 (12.2.0.1.0) a
-- Azure Database for PostgreSQL Flexible Server (PostgreSQL 16).
--
-- Mapeo de tipos y objetos Oracle -> PostgreSQL:
--   NUMBER(6)           -> INTEGER
--   NUMBER(9,2)         -> NUMERIC(9,2)
--   VARCHAR2(n)         -> VARCHAR(n)
--   DATE (sin hora)     -> DATE (DEFAULT CURRENT_DATE en lugar de SYSDATE)
--   DEPARTMENTS_SEQ     -> SEQUENCE geper_owner.departments_seq
--   EMPLOYEES_SEQ       -> SEQUENCE geper_owner.employees_seq
--   UPDATE_JOB_HISTORY  -> FUNCTION + TRIGGER PL/pgSQL con SECURITY DEFINER
-- =====================================================================
\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS geper_owner;
SET search_path TO geper_owner, public;

DROP TRIGGER IF EXISTS update_job_history ON geper_owner.employees;
DROP FUNCTION IF EXISTS geper_owner.fn_update_job_history();
DROP TABLE IF EXISTS geper_owner.job_history CASCADE;
DROP TABLE IF EXISTS geper_owner.employees CASCADE;
DROP TABLE IF EXISTS geper_owner.jobs CASCADE;
DROP TABLE IF EXISTS geper_owner.departments CASCADE;
DROP SEQUENCE IF EXISTS geper_owner.departments_seq;
DROP SEQUENCE IF EXISTS geper_owner.employees_seq;

CREATE TABLE geper_owner.departments (
  department_id    INTEGER       NOT NULL,
  department_name  VARCHAR(60)   NOT NULL,
  location         VARCHAR(80),
  CONSTRAINT pk_departments PRIMARY KEY (department_id),
  CONSTRAINT uq_departments_name UNIQUE (department_name)
);

CREATE TABLE geper_owner.jobs (
  job_id      VARCHAR(12)    NOT NULL,
  job_title   VARCHAR(60)    NOT NULL,
  min_salary  NUMERIC(9,2),
  max_salary  NUMERIC(9,2),
  CONSTRAINT pk_jobs PRIMARY KEY (job_id),
  CONSTRAINT ck_jobs_salary_range CHECK (max_salary >= min_salary)
);

CREATE TABLE geper_owner.employees (
  employee_id            INTEGER        NOT NULL,
  first_name             VARCHAR(40)    NOT NULL,
  last_name              VARCHAR(40)    NOT NULL,
  email                  VARCHAR(80),
  hire_date              DATE           DEFAULT CURRENT_DATE NOT NULL,
  job_id                 VARCHAR(12)    NOT NULL,
  salary                 NUMERIC(9,2)   NOT NULL,
  department_id          INTEGER,
  assignment_start_date  DATE           DEFAULT CURRENT_DATE NOT NULL,
  observations           VARCHAR(2000),
  CONSTRAINT pk_employees PRIMARY KEY (employee_id),
  CONSTRAINT uq_employees_email UNIQUE (email),
  CONSTRAINT fk_emp_job  FOREIGN KEY (job_id)        REFERENCES geper_owner.jobs (job_id),
  CONSTRAINT fk_emp_dept FOREIGN KEY (department_id) REFERENCES geper_owner.departments (department_id),
  CONSTRAINT ck_emp_salary_pos CHECK (salary > 0)
);

CREATE INDEX ix_emp_dept ON geper_owner.employees (department_id);
CREATE INDEX ix_emp_job  ON geper_owner.employees (job_id);
CREATE INDEX ix_emp_last ON geper_owner.employees (last_name);

CREATE TABLE geper_owner.job_history (
  employee_id    INTEGER      NOT NULL,
  start_date     DATE         NOT NULL,
  end_date       DATE         NOT NULL,
  job_id         VARCHAR(12)  NOT NULL,
  department_id  INTEGER,
  CONSTRAINT pk_job_history PRIMARY KEY (employee_id, start_date),
  CONSTRAINT fk_jh_emp  FOREIGN KEY (employee_id)   REFERENCES geper_owner.employees (employee_id),
  CONSTRAINT fk_jh_job  FOREIGN KEY (job_id)        REFERENCES geper_owner.jobs (job_id),
  CONSTRAINT fk_jh_dept FOREIGN KEY (department_id) REFERENCES geper_owner.departments (department_id),
  CONSTRAINT ck_jh_dates CHECK (end_date >= start_date)
);

CREATE SEQUENCE geper_owner.departments_seq START WITH 70 INCREMENT BY 10 NO CYCLE;
CREATE SEQUENCE geper_owner.employees_seq   START WITH 1000 INCREMENT BY 1 NO CYCLE;

-- ------------------------------------------------------------------
-- Trigger PL/pgSQL equivalente a UPDATE_JOB_HISTORY de Oracle 12c R2
--
-- Se declara SECURITY DEFINER para conservar exactamente el modelo de
-- permisos de definidor de Oracle: la cuenta de ejecución geper_app
-- NO tiene privilegio INSERT directo sobre job_history, pero el trigger
-- inserta la fila de historial dentro de la misma transacción.
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION geper_owner.fn_update_job_history()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = geper_owner, public
AS $$
BEGIN
  INSERT INTO geper_owner.job_history (employee_id, start_date, end_date, job_id, department_id)
  VALUES (OLD.employee_id, OLD.assignment_start_date, CURRENT_DATE, OLD.job_id, OLD.department_id);

  NEW.assignment_start_date := CURRENT_DATE;
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_job_history
  BEFORE UPDATE OF job_id, department_id ON geper_owner.employees
  FOR EACH ROW
  WHEN (
        COALESCE(OLD.job_id, '~')       <> COALESCE(NEW.job_id, '~')
     OR COALESCE(OLD.department_id, -1) <> COALESCE(NEW.department_id, -1)
  )
  EXECUTE FUNCTION geper_owner.fn_update_job_history();
