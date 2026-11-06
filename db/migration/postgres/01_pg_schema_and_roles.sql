-- =====================================================================
-- GEPER - Gestion de Personal y Puestos
-- 01_pg_schema_and_roles.sql  -- RUN AS A POSTGRESQL SUPERUSER / ADMIN ROLE
--
-- Azure Database for PostgreSQL Flexible Server schema for the personnel
-- registry, converted from the Oracle Database 12c R2 baseline:
--   NUMBER(6)    -> INTEGER
--   NUMBER(9,2)  -> NUMERIC(9,2)
--   VARCHAR2(n)  -> VARCHAR(n)
--   DATE         -> DATE (CURRENT_DATE default instead of SYSDATE)
--   DEPARTMENTS_SEQ / EMPLOYEES_SEQ Oracle sequences -> native PostgreSQL
--   sequences (departments_seq / employees_seq) in the geper_owner schema.
--
-- Creates the least-privilege roles (geper_owner, geper_app, geper_labro),
-- the geper_owner schema, tables, sequences and grants. The
-- UPDATE_JOB_HISTORY trigger equivalent lives in a separate file,
-- 02_pg_trigger_update_job_history.sql, because it must be created AFTER
-- the tables below exist.
--
-- Passwords below are LAB-ONLY placeholders for a loopback instance with
-- synthetic data. Change them for any non-throwaway instance (e.g. use
-- Azure AD / Microsoft Entra authentication in production) and never
-- commit real credentials.
-- =====================================================================

-- ------------------------------------------------------------------
-- Clean slate (safe to re-run). Order respects FK/ownership dependencies.
-- ------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_job_history ON geper_owner.employees;
DROP FUNCTION IF EXISTS geper_owner.fn_update_job_history();
DROP TABLE IF EXISTS geper_owner.job_history CASCADE;
DROP TABLE IF EXISTS geper_owner.employees CASCADE;
DROP TABLE IF EXISTS geper_owner.jobs CASCADE;
DROP TABLE IF EXISTS geper_owner.departments CASCADE;
DROP SEQUENCE IF EXISTS geper_owner.departments_seq;
DROP SEQUENCE IF EXISTS geper_owner.employees_seq;
DROP SCHEMA IF EXISTS geper_owner CASCADE;

-- ------------------------------------------------------------------
-- Least-privilege roles (idempotent).
-- ------------------------------------------------------------------
DO $do$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'geper_owner') THEN
    CREATE ROLE geper_owner LOGIN PASSWORD 'Owner#Lab2012';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'geper_app') THEN
    CREATE ROLE geper_app LOGIN PASSWORD 'App#Lab2012';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'geper_labro') THEN
    CREATE ROLE geper_labro LOGIN PASSWORD 'LabRo#Lab2012';
  END IF;
END
$do$;

-- geper_owner owns the schema and every object in it (mirrors the Oracle
-- GEPER_OWNER schema-owner account). geper_app and geper_labro resolve
-- unqualified object names to this schema via SET search_path (see
-- application.yml / LabDataSourceConfig connection-init-sql), the
-- PostgreSQL equivalent of Oracle's ALTER SESSION SET CURRENT_SCHEMA.
CREATE SCHEMA IF NOT EXISTS geper_owner AUTHORIZATION geper_owner;

-- ------------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------------
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
  employee_id            INTEGER       NOT NULL,
  first_name             VARCHAR(40)   NOT NULL,
  last_name              VARCHAR(40)   NOT NULL,
  email                  VARCHAR(80),
  hire_date              DATE          DEFAULT CURRENT_DATE NOT NULL,
  job_id                 VARCHAR(12)   NOT NULL,
  salary                 NUMERIC(9,2)  NOT NULL,
  department_id          INTEGER,
  -- Start of the CURRENT job/department assignment. Maintained by the
  -- fn_update_job_history() trigger so that job_history start/end dates
  -- line up.
  assignment_start_date  DATE          DEFAULT CURRENT_DATE NOT NULL,
  -- Free-text operator notes. Rendered (escaped) on the normal employee
  -- card. Also the storage behind SECURITY-LAB JAVA-XSS-01.
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

ALTER TABLE geper_owner.departments OWNER TO geper_owner;
ALTER TABLE geper_owner.jobs        OWNER TO geper_owner;
ALTER TABLE geper_owner.employees   OWNER TO geper_owner;
ALTER TABLE geper_owner.job_history OWNER TO geper_owner;

-- ------------------------------------------------------------------
-- Sequences (replace the Oracle DEPARTMENTS_SEQ / EMPLOYEES_SEQ sequences
-- one-for-one; PostgreSQL sequences support the same NEXTVAL semantics via
-- the nextval() function used in DepartmentRepository/EmployeeRepository).
-- Seeded departments occupy IDs 10..60, so departments_seq starts at 70.
-- ------------------------------------------------------------------
CREATE SEQUENCE geper_owner.departments_seq
  START WITH 70 INCREMENT BY 10 NO CYCLE OWNED BY geper_owner.departments.department_id;
CREATE SEQUENCE geper_owner.employees_seq
  START WITH 1000 INCREMENT BY 1 NO CYCLE OWNED BY geper_owner.employees.employee_id;

ALTER SEQUENCE geper_owner.departments_seq OWNER TO geper_owner;
ALTER SEQUENCE geper_owner.employees_seq   OWNER TO geper_owner;

-- ------------------------------------------------------------------
-- Least-privilege grants to the runtime and lab accounts.
-- ------------------------------------------------------------------
GRANT USAGE ON SCHEMA geper_owner TO geper_app, geper_labro;

-- Runtime application account: DML on operational tables, SELECT on
-- history and catalogues, SELECT on the employee/department sequences.
-- NOT granted INSERT on job_history (the SECURITY DEFINER trigger function
-- handles it under the owner's rights).
GRANT SELECT, INSERT, UPDATE, DELETE ON geper_owner.employees   TO geper_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON geper_owner.departments TO geper_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON geper_owner.jobs        TO geper_app;
GRANT SELECT                        ON geper_owner.job_history  TO geper_app;
GRANT SELECT ON geper_owner.employees_seq   TO geper_app;
GRANT SELECT ON geper_owner.departments_seq TO geper_app;

-- Vulnerability-lab account: read-only on the synthetic personnel data
-- consumed by SECURITY-LAB JAVA-SQLI-01. Nothing else.
GRANT SELECT ON geper_owner.employees   TO geper_labro;
GRANT SELECT ON geper_owner.departments TO geper_labro;
GRANT SELECT ON geper_owner.jobs        TO geper_labro;

-- ------------------------------------------------------------------
-- Object resolution for the runtime/lab accounts.
--
-- Rather than owning synonyms, geper_app and geper_labro set
--   SET search_path TO geper_owner, public
-- on connect (configured as the datasource connection-init SQL - see
-- application.yml spring.datasource.hikari.connection-init-sql and
-- LabDataSourceConfig), so the unqualified object names in the application
-- SQL resolve to the objects owned here. ALTER ROLE ... SET search_path
-- below provides the same default even for connections that skip the
-- connection-init SQL. The grants above remain the only privileges those
-- accounts hold.
-- ------------------------------------------------------------------
ALTER ROLE geper_app   SET search_path = geper_owner, public;
ALTER ROLE geper_labro SET search_path = geper_owner, public;
