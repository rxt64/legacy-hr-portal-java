-- =====================================================================
-- GEPER - 99_drop_all.sql  -- RUN AS GEPER_OWNER
--
-- Drops every GEPER object owned by the current schema. Use to fully reset
-- before re-running 02_schema.sql + 03_synthetic_data.sql. Does NOT drop the
-- database accounts (see db/accounts).
-- =====================================================================
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
COMMIT;
