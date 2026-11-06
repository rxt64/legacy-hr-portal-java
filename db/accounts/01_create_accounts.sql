-- =====================================================================
-- GEPER - Gestion de Personal y Puestos
-- Corporacion Regional Monte Azul (institucion ficticia)
--
-- 01_create_accounts.sql
--
-- Provisioning script. RUN THIS AS A DATABASE ADMINISTRATOR (for the
-- bundled local lab, the SYSTEM account of the pluggable database).
--
-- IMPORTANT: SYSTEM / SYS are used here ONLY to provision accounts, as a
-- DBA would. They are NEVER the application runtime account. The running
-- application connects as GEPER_APP, and the vulnerability lab connects as
-- the read-only GEPER_LABRO. Both are least-privilege accounts created
-- below. See docs/architecture.md.
--
-- Passwords below are LAB-ONLY placeholders for a loopback database with
-- synthetic data. Change them for any non-throwaway instance and never
-- commit real credentials.
-- =====================================================================

-- Connect to the application pluggable database before running, e.g.:
--   ALTER SESSION SET CONTAINER = FREEPDB1;

-- ---------------------------------------------------------------------
-- Schema owner: owns all objects and the synthetic data.
-- Not used as a runtime account.
-- ---------------------------------------------------------------------
CREATE USER GEPER_OWNER IDENTIFIED BY "Owner#Lab2012";
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER,
      CREATE VIEW, CREATE SYNONYM TO GEPER_OWNER;
ALTER USER GEPER_OWNER QUOTA UNLIMITED ON USERS;

-- ---------------------------------------------------------------------
-- Application runtime account: least privilege.
-- Can connect and perform DML through synonyms, but owns no objects and
-- cannot create or drop them. JOB_HISTORY rows are written by the
-- definer-rights trigger owned by GEPER_OWNER, so GEPER_APP is NOT
-- granted INSERT on JOB_HISTORY.
-- ---------------------------------------------------------------------
CREATE USER GEPER_APP IDENTIFIED BY "App#Lab2012";
GRANT CREATE SESSION TO GEPER_APP;

-- ---------------------------------------------------------------------
-- Vulnerability-lab read-only account.
-- Used ONLY by the SECURITY-LAB SQL-injection datasource. SELECT only,
-- on the synthetic personnel data. No DML, no DDL, no other objects.
-- ---------------------------------------------------------------------
CREATE USER GEPER_LABRO IDENTIFIED BY "LabRo#Lab2012";
GRANT CREATE SESSION TO GEPER_LABRO;

-- Object-level grants are issued by GEPER_OWNER in 02_schema.sql, after
-- the tables exist.
