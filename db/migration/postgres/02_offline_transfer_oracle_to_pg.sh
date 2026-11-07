#!/usr/bin/env bash
# ==============================================================================
# GEPER - Transferencia offline reproducible Oracle 12c R2 -> PostgreSQL 16
# y suite de validación pre/post migración.
#
# Características:
#   - Extrae de Oracle 12c R2 (12.2.0.1.0, GEPERPDB) en orden estricto de FK:
#     1) DEPARTMENTS -> 2) JOBS -> 3) EMPLOYEES -> 4) JOB_HISTORY
#   - Trata explícitamente tipos NUMBER/NUMERIC, VARCHAR2/UTF-8, DATE (ISO
#     YYYY-MM-DD sin deriva horaria) y valores NULL.
#   - Sincroniza secuencias en PostgreSQL (departments_seq, employees_seq) con
#     el estado real del origen en Oracle.
#   - Configura roles de mínimo privilegio (geper_app y geper_labro) en PG.
#   - Valida conteos, suma salarial, promedio salarial, desglose por
#     departamento, nulos, integridad referencial, secuencias y comportamiento
#     transaccional del trigger PL/pgSQL update_job_history (con ROLLBACK).
# ==============================================================================
set -euo pipefail

PG_HOST="${PG_HOST:?Defina PG_HOST (ej. pg-geper-kt2comvd.postgres.database.azure.com)}"
PG_DB="${PG_DB:-geper_rehearsal}"
PG_ADMIN_USER="${PG_ADMIN_USER:-geperpgadmin}"
PG_ADMIN_PASSWORD="${PG_ADMIN_PASSWORD:?Defina PG_ADMIN_PASSWORD}"
INSERT_WITNESS="${INSERT_WITNESS:-false}"
FREEZE_SOURCE="${FREEZE_SOURCE:-false}"

ORACLE_HOME="${ORACLE_HOME:-/u01/app/oracle/product/12.2.0/dbhome_1}"
PDB_NAME="${PDB_NAME:-GEPERPDB}"
CRED_FILE="/etc/geper/credentials.env"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="/tmp/geper_pg_migration_${PG_DB}"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
chmod 755 "$WORK_DIR"

# shellcheck disable=SC1090
source "$CRED_FILE"

START_TS=$(date +%s)

if [ "$INSERT_WITNESS" = "true" ]; then
  echo "==> [Paso 0] Insertando registro testigo reconocible en Oracle 12c R2 (${PDB_NAME})..."
  su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH; \
    sqlplus -s \"GEPER_APP/${ORA_APP_PW}@//127.0.0.1:1521/${PDB_NAME}\" <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER;
DECLARE
  v_cnt NUMBER;
  v_id  NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM EMPLOYEES WHERE EMAIL = 'ctestimig@monteazul.example';
  IF v_cnt = 0 THEN
    SELECT EMPLOYEES_SEQ.NEXTVAL INTO v_id FROM DUAL;
    INSERT INTO EMPLOYEES (EMPLOYEE_ID, FIRST_NAME, LAST_NAME, EMAIL, HIRE_DATE, JOB_ID, SALARY, DEPARTMENT_ID, ASSIGNMENT_START_DATE, OBSERVATIONS)
    VALUES (v_id, 'Camila', 'Testigo-Migracion', 'ctestimig@monteazul.example', DATE '2026-11-06', 'DESARR', 4150.00, 40, DATE '2026-11-06', 'Registro testigo creado antes de la pausa de escrituras.');
    COMMIT;
  END IF;
END;
/
EXIT;
EOSQL"
fi

if [ "$FREEZE_SOURCE" = "true" ]; then
  echo "==> [Paso 1] Pausa de escrituras: deteniendo geper.service..."
  systemctl stop geper.service
fi

echo "==> [Paso 2] Extrayendo dataset de Oracle 12c R2 (${PDB_NAME}) con formato determinista ISO-8601 y tratamiento explícito de NULL..."
su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH NLS_LANG=AMERICAN_AMERICA.AL32UTF8; \
  sqlplus -s \"GEPER_OWNER/${ORA_OWNER_PW}@//127.0.0.1:1521/${PDB_NAME}\" <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 4000 TRIMSPOOL ON VERIFY OFF

SELECT '\set ON_ERROR_STOP on' FROM DUAL;
SELECT 'SET client_encoding = ''UTF8'';' FROM DUAL;
SELECT 'SET search_path TO geper_owner, public;' FROM DUAL;
SELECT 'BEGIN;' FROM DUAL;
SELECT 'TRUNCATE TABLE geper_owner.job_history, geper_owner.employees, geper_owner.jobs, geper_owner.departments CASCADE;' FROM DUAL;

-- 1. DEPARTMENTS (padre)
SELECT 'INSERT INTO geper_owner.departments (department_id, department_name, location) VALUES ('
       || DEPARTMENT_ID || ', '
       || '''' || REPLACE(DEPARTMENT_NAME, '''', '''''') || ''', '
       || CASE WHEN LOCATION IS NULL THEN 'NULL' ELSE '''' || REPLACE(LOCATION, '''', '''''') || '''' END
       || ');'
FROM DEPARTMENTS
ORDER BY DEPARTMENT_ID;

-- 2. JOBS (padre)
SELECT 'INSERT INTO geper_owner.jobs (job_id, job_title, min_salary, max_salary) VALUES ('
       || '''' || REPLACE(JOB_ID, '''', '''''') || ''', '
       || '''' || REPLACE(JOB_TITLE, '''', '''''') || ''', '
       || NVL(TO_CHAR(MIN_SALARY, 'FM999999990.00'), 'NULL') || ', '
       || NVL(TO_CHAR(MAX_SALARY, 'FM999999990.00'), 'NULL')
       || ');'
FROM JOBS
ORDER BY JOB_ID;

-- 3. EMPLOYEES (depende de DEPARTMENTS y JOBS)
SELECT 'INSERT INTO geper_owner.employees (employee_id, first_name, last_name, email, hire_date, job_id, salary, department_id, assignment_start_date, observations) VALUES ('
       || EMPLOYEE_ID || ', '
       || '''' || REPLACE(FIRST_NAME, '''', '''''') || ''', '
       || '''' || REPLACE(LAST_NAME, '''', '''''') || ''', '
       || CASE WHEN EMAIL IS NULL THEN 'NULL' ELSE '''' || REPLACE(EMAIL, '''', '''''') || '''' END || ', '
       || 'DATE ''' || TO_CHAR(HIRE_DATE, 'YYYY-MM-DD') || ''', '
       || '''' || REPLACE(JOB_ID, '''', '''''') || ''', '
       || TO_CHAR(SALARY, 'FM999999990.00') || ', '
       || CASE WHEN DEPARTMENT_ID IS NULL THEN 'NULL' ELSE TO_CHAR(DEPARTMENT_ID) END || ', '
       || 'DATE ''' || TO_CHAR(ASSIGNMENT_START_DATE, 'YYYY-MM-DD') || ''', '
       || CASE WHEN OBSERVATIONS IS NULL THEN 'NULL' ELSE '''' || REPLACE(OBSERVATIONS, '''', '''''') || '''' END
       || ');'
FROM EMPLOYEES
ORDER BY EMPLOYEE_ID;

-- 4. JOB_HISTORY (depende de EMPLOYEES, JOBS y DEPARTMENTS)
SELECT 'INSERT INTO geper_owner.job_history (employee_id, start_date, end_date, job_id, department_id) VALUES ('
       || EMPLOYEE_ID || ', '
       || 'DATE ''' || TO_CHAR(START_DATE, 'YYYY-MM-DD') || ''', '
       || 'DATE ''' || TO_CHAR(END_DATE, 'YYYY-MM-DD') || ''', '
       || '''' || REPLACE(JOB_ID, '''', '''''') || ''', '
       || CASE WHEN DEPARTMENT_ID IS NULL THEN 'NULL' ELSE TO_CHAR(DEPARTMENT_ID) END
       || ');'
FROM JOB_HISTORY
ORDER BY EMPLOYEE_ID, START_DATE;

-- 5. Sincronización de secuencias con el estado de Oracle
SELECT 'SELECT setval(''geper_owner.departments_seq'', GREATEST((SELECT COALESCE(MAX(department_id), 60) FROM geper_owner.departments), 60), true);' FROM DUAL;
SELECT 'SELECT setval(''geper_owner.employees_seq'', GREATEST((SELECT COALESCE(MAX(employee_id), 1000) FROM geper_owner.employees), 999), true);' FROM DUAL;

SELECT 'COMMIT;' FROM DUAL;
EXIT;
EOSQL" > "${WORK_DIR}/generate_pg_load.sql"

echo "==> [Paso 3] Aplicando DDL convertido y trigger PL/pgSQL en Azure Database for PostgreSQL (${PG_HOST}/${PG_DB})..."
export PGPASSWORD="$PG_ADMIN_PASSWORD"
export PGSSLMODE="require"

psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/01_pg_schema_and_plpgsql_trigger.sql" >/dev/null

echo "==> [Paso 4] Configurando roles de mínimo privilegio (geper_app y geper_labro) en PostgreSQL..."
psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 <<EOSQL >/dev/null
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'geper_app') THEN
    CREATE ROLE geper_app LOGIN PASSWORD '${ORA_APP_PW}';
  ELSE
    ALTER ROLE geper_app WITH LOGIN PASSWORD '${ORA_APP_PW}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'geper_labro') THEN
    CREATE ROLE geper_labro LOGIN PASSWORD '${ORA_LABRO_PW}';
  ELSE
    ALTER ROLE geper_labro WITH LOGIN PASSWORD '${ORA_LABRO_PW}';
  END IF;
END
\$\$;

GRANT USAGE ON SCHEMA geper_owner TO geper_app, geper_labro;
GRANT SELECT, INSERT, UPDATE, DELETE ON geper_owner.employees, geper_owner.departments, geper_owner.jobs TO geper_app;
GRANT SELECT ON geper_owner.job_history TO geper_app;
GRANT USAGE, SELECT ON SEQUENCE geper_owner.employees_seq, geper_owner.departments_seq TO geper_app;
GRANT SELECT ON geper_owner.employees, geper_owner.departments, geper_owner.jobs TO geper_labro;
ALTER ROLE geper_app SET search_path TO geper_owner, public;
ALTER ROLE geper_labro SET search_path TO geper_owner, public;
EOSQL

echo "==> [Paso 5] Cargando datos transferidos y sincronizando secuencias en ${PG_DB}..."
psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 -f "${WORK_DIR}/generate_pg_load.sql" >/dev/null

echo "==> [Paso 6] Ejecutando validaciones post-migración y prueba transaccional del trigger PL/pgSQL..."
export PGPASSWORD="$ORA_APP_PW"
psql -h "$PG_HOST" -U "geper_app" -d "$PG_DB" -v ON_ERROR_STOP=1 <<'EOSQL'
SELECT
  (SELECT COUNT(*) FROM geper_owner.departments) AS departments_cnt,
  (SELECT COUNT(*) FROM geper_owner.jobs) AS jobs_cnt,
  (SELECT COUNT(*) FROM geper_owner.employees) AS employees_cnt,
  (SELECT COUNT(*) FROM geper_owner.employees WHERE observations IS NULL) AS null_observations_cnt,
  (SELECT COUNT(*) FROM geper_owner.job_history) AS job_history_cnt,
  (SELECT COALESCE(SUM(salary), 0) FROM geper_owner.employees) AS total_salary,
  (SELECT COALESCE(ROUND(AVG(salary), 2), 0) FROM geper_owner.employees) AS avg_salary;

-- Prueba transaccional del trigger update_job_history con ROLLBACK
BEGIN;
UPDATE geper_owner.employees SET job_id = 'SUPERV' WHERE employee_id = 126;
SELECT employee_id, start_date, end_date, job_id, department_id
FROM geper_owner.job_history
WHERE employee_id = 126;
ROLLBACK;
EOSQL

END_TS=$(date +%s)
echo "==> Transferencia y validación completadas en $((END_TS - START_TS))s."
rm -rf "$WORK_DIR"
