-- =====================================================================
-- GEPER - Gestion de Personal y Puestos
-- 02_schema.sql  -- RUN AS GEPER_OWNER
--
-- Oracle schema for the legacy personnel registry. Deliberately uses
-- Oracle-specific features that a future database migration must account
-- for: NUMBER / VARCHAR2 types, sequences, and a PL/SQL row trigger
-- (UPDATE_JOB_HISTORY) that maintains the employment-history table.
-- =====================================================================

-- ------------------------------------------------------------------
-- Clean slate (safe to re-run). Order respects FK dependencies.
-- ------------------------------------------------------------------
BEGIN
  FOR r IN (SELECT trigger_name FROM user_triggers WHERE trigger_name = 'UPDATE_JOB_HISTORY') LOOP
    EXECUTE IMMEDIATE 'DROP TRIGGER ' || r.trigger_name;
  END LOOP;
  FOR r IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('JOB_HISTORY','EMPLOYEES','JOBS','DEPARTMENTS')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
  FOR r IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN ('DEPARTMENTS_SEQ','EMPLOYEES_SEQ')) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || r.sequence_name;
  END LOOP;
END;
/

-- ------------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------------
CREATE TABLE DEPARTMENTS (
  DEPARTMENT_ID    NUMBER(6)      NOT NULL,
  DEPARTMENT_NAME  VARCHAR2(60)   NOT NULL,
  LOCATION         VARCHAR2(80),
  CONSTRAINT PK_DEPARTMENTS PRIMARY KEY (DEPARTMENT_ID),
  CONSTRAINT UQ_DEPARTMENTS_NAME UNIQUE (DEPARTMENT_NAME)
);

CREATE TABLE JOBS (
  JOB_ID      VARCHAR2(12)   NOT NULL,
  JOB_TITLE   VARCHAR2(60)   NOT NULL,
  MIN_SALARY  NUMBER(9,2),
  MAX_SALARY  NUMBER(9,2),
  CONSTRAINT PK_JOBS PRIMARY KEY (JOB_ID),
  CONSTRAINT CK_JOBS_SALARY_RANGE CHECK (MAX_SALARY >= MIN_SALARY)
);

CREATE TABLE EMPLOYEES (
  EMPLOYEE_ID            NUMBER(6)      NOT NULL,
  FIRST_NAME             VARCHAR2(40)   NOT NULL,
  LAST_NAME              VARCHAR2(40)   NOT NULL,
  EMAIL                  VARCHAR2(80),
  HIRE_DATE              DATE           DEFAULT SYSDATE NOT NULL,
  JOB_ID                 VARCHAR2(12)   NOT NULL,
  SALARY                 NUMBER(9,2)    NOT NULL,
  DEPARTMENT_ID          NUMBER(6),
  -- Start of the CURRENT job/department assignment. Maintained by the
  -- UPDATE_JOB_HISTORY trigger so that JOB_HISTORY start/end dates line up.
  ASSIGNMENT_START_DATE  DATE           DEFAULT SYSDATE NOT NULL,
  -- Free-text operator notes. Rendered (escaped) on the normal employee
  -- card. Also the storage behind SECURITY-LAB JAVA-XSS-01.
  OBSERVATIONS           VARCHAR2(2000),
  CONSTRAINT PK_EMPLOYEES PRIMARY KEY (EMPLOYEE_ID),
  CONSTRAINT UQ_EMPLOYEES_EMAIL UNIQUE (EMAIL),
  CONSTRAINT FK_EMP_JOB  FOREIGN KEY (JOB_ID)        REFERENCES JOBS (JOB_ID),
  CONSTRAINT FK_EMP_DEPT FOREIGN KEY (DEPARTMENT_ID) REFERENCES DEPARTMENTS (DEPARTMENT_ID),
  CONSTRAINT CK_EMP_SALARY_POS CHECK (SALARY > 0)
);

CREATE INDEX IX_EMP_DEPT ON EMPLOYEES (DEPARTMENT_ID);
CREATE INDEX IX_EMP_JOB  ON EMPLOYEES (JOB_ID);
CREATE INDEX IX_EMP_LAST ON EMPLOYEES (LAST_NAME);

CREATE TABLE JOB_HISTORY (
  EMPLOYEE_ID    NUMBER(6)    NOT NULL,
  START_DATE     DATE         NOT NULL,
  END_DATE       DATE         NOT NULL,
  JOB_ID         VARCHAR2(12) NOT NULL,
  DEPARTMENT_ID  NUMBER(6),
  CONSTRAINT PK_JOB_HISTORY PRIMARY KEY (EMPLOYEE_ID, START_DATE),
  CONSTRAINT FK_JH_EMP  FOREIGN KEY (EMPLOYEE_ID)   REFERENCES EMPLOYEES (EMPLOYEE_ID),
  CONSTRAINT FK_JH_JOB  FOREIGN KEY (JOB_ID)        REFERENCES JOBS (JOB_ID),
  CONSTRAINT FK_JH_DEPT FOREIGN KEY (DEPARTMENT_ID) REFERENCES DEPARTMENTS (DEPARTMENT_ID),
  CONSTRAINT CK_JH_DATES CHECK (END_DATE >= START_DATE)
);

-- ------------------------------------------------------------------
-- Sequences (Oracle-specific; a migration target without sequences must
-- replace these with identity columns or an equivalent mechanism).
-- Seeded departments occupy IDs 10..60, so DEPARTMENTS_SEQ starts at 70.
-- ------------------------------------------------------------------
CREATE SEQUENCE DEPARTMENTS_SEQ START WITH 70 INCREMENT BY 10 NOCACHE NOCYCLE;
CREATE SEQUENCE EMPLOYEES_SEQ   START WITH 1000 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ------------------------------------------------------------------
-- Trigger: UPDATE_JOB_HISTORY
--
-- When an employee's JOB_ID or DEPARTMENT_ID changes, the PRIOR
-- assignment is closed off into JOB_HISTORY (its original start date
-- through today) and the employee's ASSIGNMENT_START_DATE is advanced to
-- today. A plain salary change does NOT touch the history. This is the
-- transactional PL/SQL behaviour exercised by the test suite.
--
-- BEFORE UPDATE lets us both read :OLD and set :NEW on EMPLOYEES while
-- inserting into the separate JOB_HISTORY table (no mutating-table error).
-- The trigger is owned by GEPER_OWNER and runs with definer rights, so the
-- least-privilege GEPER_APP account needs no direct INSERT on JOB_HISTORY.
-- ------------------------------------------------------------------
CREATE OR REPLACE TRIGGER UPDATE_JOB_HISTORY
  BEFORE UPDATE OF JOB_ID, DEPARTMENT_ID ON EMPLOYEES
  FOR EACH ROW
  WHEN (
        NVL(OLD.JOB_ID, '~')        <> NVL(NEW.JOB_ID, '~')
     OR NVL(OLD.DEPARTMENT_ID, -1)  <> NVL(NEW.DEPARTMENT_ID, -1)
  )
BEGIN
  INSERT INTO JOB_HISTORY (EMPLOYEE_ID, START_DATE, END_DATE, JOB_ID, DEPARTMENT_ID)
  VALUES (:OLD.EMPLOYEE_ID, :OLD.ASSIGNMENT_START_DATE, TRUNC(SYSDATE),
          :OLD.JOB_ID, :OLD.DEPARTMENT_ID);

  :NEW.ASSIGNMENT_START_DATE := TRUNC(SYSDATE);
END;
/

-- ------------------------------------------------------------------
-- Least-privilege grants to the runtime and lab accounts.
-- ------------------------------------------------------------------
-- Runtime application account: DML on operational tables, SELECT on
-- history and catalogues, SELECT on the employee sequence. NOT granted
-- INSERT on JOB_HISTORY (the trigger handles it under owner rights).
GRANT SELECT, INSERT, UPDATE, DELETE ON EMPLOYEES   TO GEPER_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON DEPARTMENTS TO GEPER_APP;
GRANT SELECT, INSERT, UPDATE, DELETE ON JOBS        TO GEPER_APP;
GRANT SELECT                        ON JOB_HISTORY  TO GEPER_APP;
GRANT SELECT ON EMPLOYEES_SEQ   TO GEPER_APP;
GRANT SELECT ON DEPARTMENTS_SEQ TO GEPER_APP;

-- Vulnerability-lab account: read-only on the synthetic personnel data
-- consumed by SECURITY-LAB JAVA-SQLI-01. Nothing else.
GRANT SELECT ON EMPLOYEES   TO GEPER_LABRO;
GRANT SELECT ON DEPARTMENTS TO GEPER_LABRO;
GRANT SELECT ON JOBS        TO GEPER_LABRO;

-- ------------------------------------------------------------------
-- Object resolution for the runtime/lab accounts.
--
-- Rather than owning synonyms, GEPER_APP and GEPER_LABRO set
--   ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER
-- on connect (configured as the datasource connection-init SQL), so the
-- unqualified object names in the application SQL resolve to the objects
-- owned here. The grants above remain the only privileges those accounts
-- hold. See application.yml (spring.datasource.hikari.connection-init-sql).
-- ------------------------------------------------------------------
COMMIT;
