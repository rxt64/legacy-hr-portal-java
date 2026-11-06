#!/usr/bin/env bash
# =====================================================================
# GEPER - provision a LOCAL throwaway Oracle for development/testing.
#
# Starts an Oracle Free container (loopback only), creates the GEPER
# accounts, schema and synthetic data. For LOCAL LAB USE ONLY. The
# passwords here are throwaway lab values that match
# db/accounts/01_create_accounts.sql; they guard only synthetic data on a
# loopback database. Never use them anywhere real.
#
# Requirements: docker. Usage:  ./scripts/provision-local-db.sh
# =====================================================================
set -euo pipefail

CONTAINER="${CONTAINER:-geper-oracle}"
IMAGE="${IMAGE:-gvenzl/oracle-free:23-slim-faststart}"
ADMIN_PW="${ADMIN_PW:-LabRoot#2012pw}"
PDB="${PDB:-FREEPDB1}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Starting $CONTAINER (loopback 127.0.0.1:1521 only)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" -p 127.0.0.1:1521:1521 \
  -e ORACLE_PASSWORD="$ADMIN_PW" "$IMAGE" >/dev/null

echo "==> Waiting for the database to be ready..."
until docker logs "$CONTAINER" 2>&1 | grep -q "DATABASE IS READY TO USE!"; do
  sleep 3
done
sleep 2

echo "==> Copying SQL scripts into the container"
docker cp "$HERE/db" "$CONTAINER:/tmp/db" >/dev/null

run_sql() { # <user/pass> <script>
  docker exec "$CONTAINER" bash -lc \
    "sqlplus -s $1@localhost:1521/$PDB <<'EOF'
WHENEVER SQLERROR CONTINUE
SET DEFINE OFF
@$2
EXIT
EOF"
}

echo "==> 01 create accounts (as SYSTEM)"
run_sql "system/$ADMIN_PW" /tmp/db/accounts/01_create_accounts.sql | tail -4
echo "==> 02 schema (as GEPER_OWNER)"
run_sql "GEPER_OWNER/Owner#Lab2012" /tmp/db/schema/02_schema.sql | tail -4
echo "==> 03 synthetic data (as GEPER_OWNER)"
run_sql "GEPER_OWNER/Owner#Lab2012" /tmp/db/data/03_synthetic_data.sql | tail -3

echo
echo "Done. Connect strings (loopback only):"
echo "  app : jdbc:oracle:thin:@//localhost:1521/$PDB  user=GEPER_APP    pass=App#Lab2012"
echo "  lab : jdbc:oracle:thin:@//localhost:1521/$PDB  user=GEPER_LABRO  pass=LabRo#Lab2012"
