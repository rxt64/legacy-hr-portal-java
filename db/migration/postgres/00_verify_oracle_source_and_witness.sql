-- =====================================================================
-- GEPER - 00_verify_oracle_source_and_witness.sql
--
-- Verifica la versión real del motor Oracle origen (12.2.0.1.0), el
-- contenedor PDB (GEPERPDB), los objetos del esquema GEPER_OWNER y
-- los conteos/agregados antes de la pausa de escrituras.
-- =====================================================================
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET PAGESIZE 100 LINESIZE 140 FEEDBACK OFF
ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER;

PROMPT === 1. Version real de Oracle Database ===
SELECT banner FROM v$version;

PROMPT === 2. Contenedor PDB actual ===
SELECT sys_context('USERENV', 'CON_NAME') AS CURRENT_CONTAINER,
       sys_context('USERENV', 'CURRENT_SCHEMA') AS CURRENT_SCHEMA
FROM dual;

PROMPT === 3. Objetos de esquema en Oracle (Tablas, Secuencias, Trigger) ===
SELECT table_name, num_rows FROM all_tables WHERE owner = 'GEPER_OWNER' ORDER BY table_name;
SELECT sequence_name, min_value, increment_by, last_number FROM all_sequences WHERE sequence_owner = 'GEPER_OWNER' ORDER BY sequence_name;
SELECT trigger_name, trigger_type, triggering_event, table_name, status FROM all_triggers WHERE owner = 'GEPER_OWNER';

PROMPT === 4. Conteos y agregados en Oracle origen ===
SELECT
  (SELECT COUNT(*) FROM DEPARTMENTS) AS DEPARTMENTS_CNT,
  (SELECT COUNT(*) FROM JOBS) AS JOBS_CNT,
  (SELECT COUNT(*) FROM EMPLOYEES) AS EMPLOYEES_CNT,
  (SELECT COUNT(*) FROM EMPLOYEES WHERE OBSERVATIONS IS NULL) AS NULL_OBSERVATIONS_CNT,
  (SELECT COUNT(*) FROM JOB_HISTORY) AS JOB_HISTORY_CNT,
  (SELECT NVL(SUM(SALARY), 0) FROM EMPLOYEES) AS TOTAL_SALARY,
  (SELECT NVL(ROUND(AVG(SALARY), 2), 0) FROM EMPLOYEES) AS AVG_SALARY
FROM DUAL;

PROMPT === 5. Resumen salarial por departamento en Oracle origen ===
SELECT d.DEPARTMENT_ID,
       d.DEPARTMENT_NAME,
       COUNT(e.EMPLOYEE_ID) AS HEADCOUNT,
       NVL(SUM(e.SALARY), 0) AS TOTAL_SALARY,
       NVL(ROUND(AVG(e.SALARY), 2), 0) AS AVG_SALARY
FROM DEPARTMENTS d
LEFT JOIN EMPLOYEES e ON e.DEPARTMENT_ID = d.DEPARTMENT_ID
GROUP BY d.DEPARTMENT_ID, d.DEPARTMENT_NAME
ORDER BY TOTAL_SALARY DESC;

EXIT;
