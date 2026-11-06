-- =====================================================================
-- GEPER - 99_pg_drop_all.sql  -- RUN AS A SUPERUSER/ADMIN ROLE (or
-- geper_owner, which owns every object below)
--
-- Drops every GEPER object owned by geper_owner. Use to fully reset before
-- re-running 01_pg_schema_and_roles.sql + 02_pg_trigger_update_job_history.sql
-- + 03_pg_synthetic_data.sql. Does NOT drop the geper_owner/geper_app/
-- geper_labro roles or the geper_owner schema itself.
-- =====================================================================

DROP TRIGGER IF EXISTS update_job_history ON geper_owner.employees;
DROP FUNCTION IF EXISTS geper_owner.fn_update_job_history();
DROP TABLE IF EXISTS geper_owner.job_history CASCADE;
DROP TABLE IF EXISTS geper_owner.employees CASCADE;
DROP TABLE IF EXISTS geper_owner.jobs CASCADE;
DROP TABLE IF EXISTS geper_owner.departments CASCADE;
DROP SEQUENCE IF EXISTS geper_owner.departments_seq;
DROP SEQUENCE IF EXISTS geper_owner.employees_seq;
