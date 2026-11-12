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
--   ALTER SESSION SET CONTAINER = GEPERPDB;

DECLARE
  v_cnt NUMBER;
BEGIN
  -- Ensure GEPER_OWNER exists (idempotent on Oracle 12c R2 / 19c / 23c).
  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'GEPER_OWNER';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER GEPER_OWNER IDENTIFIED BY "Owner#Lab2012" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP';
  END IF;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE TRIGGER, CREATE VIEW, CREATE SYNONYM TO GEPER_OWNER';
  EXECUTE IMMEDIATE 'ALTER USER GEPER_OWNER QUOTA UNLIMITED ON USERS';

  -- Application runtime account: least privilege.
  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'GEPER_APP';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER GEPER_APP IDENTIFIED BY "App#Lab2012" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP';
  END IF;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO GEPER_APP';

  -- Vulnerability-lab read-only account.
  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'GEPER_LABRO';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER GEPER_LABRO IDENTIFIED BY "LabRo#Lab2012" DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP';
  END IF;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO GEPER_LABRO';

  -- Dictionary/metadata-only grants so GEPER_LABRO can also be used as the
  -- source account for the Oracle-to-PostgreSQL schema conversion wizard
  -- (VS Code PostgreSQL extension + Microsoft Foundry). These grants expose
  -- ONLY schema metadata (object definitions, dependencies), never row
  -- data; required privileges per the official tutorial prerequisites:
  -- CONNECT, SELECT_CATALOG_ROLE, SELECT ANY DICTIONARY, SELECT on
  -- SYS.ARGUMENT$ and SYS.V_$RESOURCE_LIMIT.
  EXECUTE IMMEDIATE 'GRANT SELECT_CATALOG_ROLE TO GEPER_LABRO';
  EXECUTE IMMEDIATE 'GRANT SELECT ANY DICTIONARY TO GEPER_LABRO';
  EXECUTE IMMEDIATE 'GRANT SELECT ON SYS.ARGUMENT$ TO GEPER_LABRO';
  EXECUTE IMMEDIATE 'GRANT SELECT ON SYS.V_$RESOURCE_LIMIT TO GEPER_LABRO';
END;
/

-- Object-level grants are issued by GEPER_OWNER in 02_schema.sql, after
-- the tables exist.
