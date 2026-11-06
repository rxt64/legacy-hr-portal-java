#!/usr/bin/env bash
# =====================================================================
# GEPER - provision a LOCAL throwaway PostgreSQL instance for
# development/testing.
#
# Starts a PostgreSQL container (loopback only), creates the GEPER roles,
# schema, trigger and synthetic data. For LOCAL LAB USE ONLY. The passwords
# here are throwaway lab values that match
# db/migration/postgres/01_pg_schema_and_roles.sql; they guard only
# synthetic data on a loopback database. Never use them anywhere real.
#
# Requirements: docker. Usage:  ./scripts/provision-local-db.sh
# =====================================================================
set -euo pipefail

CONTAINER="${CONTAINER:-geper-postgres}"
IMAGE="${IMAGE:-postgres:16-alpine}"
ADMIN_PW="${ADMIN_PW:-LabRoot#2012pw}"
DB_NAME="${DB_NAME:-geper}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Starting $CONTAINER (loopback 127.0.0.1:5432 only)"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" -p 127.0.0.1:5432:5432 \
  -e POSTGRES_PASSWORD="$ADMIN_PW" -e POSTGRES_DB="$DB_NAME" "$IMAGE" >/dev/null

echo "==> Waiting for the database to be ready..."
until docker exec "$CONTAINER" pg_isready -U postgres -d "$DB_NAME" >/dev/null 2>&1; do
  sleep 1
done
sleep 1

echo "==> Copying SQL scripts into the container"
docker cp "$HERE/db" "$CONTAINER:/tmp/db" >/dev/null

run_sql() { # <script>
  docker exec -e PGPASSWORD="$ADMIN_PW" "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U postgres -d "$DB_NAME" -f "$1"
}

echo "==> 01 schema and roles (as postgres superuser)"
run_sql /tmp/db/migration/postgres/01_pg_schema_and_roles.sql | tail -4
echo "==> 02 UPDATE_JOB_HISTORY trigger (as postgres superuser)"
run_sql /tmp/db/migration/postgres/02_pg_trigger_update_job_history.sql | tail -4
echo "==> 03 synthetic data (as postgres superuser, inserted into geper_owner's objects)"
run_sql /tmp/db/migration/postgres/03_pg_synthetic_data.sql | tail -3

echo
echo "Done. Connect strings (loopback only):"
echo "  app : jdbc:postgresql://localhost:5432/$DB_NAME  user=geper_app    pass=App#Lab2012"
echo "  lab : jdbc:postgresql://localhost:5432/$DB_NAME  user=geper_labro  pass=LabRo#Lab2012"
