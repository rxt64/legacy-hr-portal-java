#!/usr/bin/env bash
# ==============================================================================
# GEPER - Restablecimiento explícito e independiente del dataset sintético
#
# Uso:
#   sudo ./reset-dataset-geper.sh [--mode full|lab-only]
#
# - full     : Recrea esquema + trigger UPDATE_JOB_HISTORY + datos sintéticos
#              (30 empleados, 6 departamentos, 10 puestos, suma salarial 99800).
# - lab-only : Ejecuta únicamente db/reset/90_reset_lab.sql (restaura OBSERVATIONS).
# ==============================================================================
set -euo pipefail

MODE="full"
if [ "${1:-}" = "--mode" ] && [ -n "${2:-}" ]; then
  MODE="$2"
fi

STAGE_DIR="${STAGE_DIR:-/var/opt/geper/stage}"
ORACLE_HOME="${ORACLE_HOME:-/u01/app/oracle/product/12.2.0/dbhome_1}"
PDB_NAME="${PDB_NAME:-GEPERPDB}"
CRED_FILE="/etc/geper/credentials.env"

if [ ! -f "$CRED_FILE" ]; then
  echo "ERROR: No se encontró ${CRED_FILE}" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CRED_FILE"

if [ "$MODE" = "lab-only" ]; then
  echo "==> Restableciendo observaciones de laboratorio (90_reset_lab.sql)..."
  su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH; \
    sqlplus -s \"GEPER_OWNER/${ORA_OWNER_PW}@//127.0.0.1:1521/${PDB_NAME}\" <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF
@${STAGE_DIR}/db/reset/90_reset_lab.sql
EXIT;
EOSQL"
else
  echo "==> Restableciendo esquema completo y dataset sintético de GEPER..."
  su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH; \
    sqlplus -s \"GEPER_OWNER/${ORA_OWNER_PW}@//127.0.0.1:1521/${PDB_NAME}\" <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET DEFINE OFF
@${STAGE_DIR}/db/schema/02_schema.sql
@${STAGE_DIR}/db/data/03_synthetic_data.sql
EXIT;
EOSQL"
fi

echo "==> Verificación del baseline de GEPER tras restablecimiento:"
su - oracle -c "export ORACLE_HOME=${ORACLE_HOME} PATH=${ORACLE_HOME}/bin:\$PATH; \
  sqlplus -s \"GEPER_APP/${ORA_APP_PW}@//127.0.0.1:1521/${PDB_NAME}\" <<'EOSQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER;
SET PAGESIZE 50 LINESIZE 120 FEEDBACK OFF
SELECT
  (SELECT COUNT(*) FROM EMPLOYEES) AS EMPLOYEES,
  (SELECT COUNT(*) FROM DEPARTMENTS) AS DEPARTMENTS,
  (SELECT COUNT(*) FROM JOBS) AS JOBS,
  (SELECT COUNT(*) FROM JOB_HISTORY) AS JOB_HISTORY,
  (SELECT SUM(SALARY) FROM EMPLOYEES) AS TOTAL_SALARY
FROM DUAL;
EXIT;
EOSQL"
