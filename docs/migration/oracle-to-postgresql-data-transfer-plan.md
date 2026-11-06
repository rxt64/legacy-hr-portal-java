# GEPER — Offline Data Transfer Plan (Oracle 12c R2 → Azure Database for PostgreSQL Flexible Server)

> Fictitious demonstration application. This plan describes the **offline**
> (maintenance-window) data migration path for moving GEPER's existing
> synthetic personnel data from the Oracle Database 12c R2 baseline to the
> converted PostgreSQL schema in `db/migration/postgres/`. It complements,
> and does not replace, the schema/trigger/SQL-dialect conversion already
> applied to the application code and DDL.

## 1. Scope

| Item | Source (Oracle 12c R2) | Target (PostgreSQL 16 / Azure Database for PostgreSQL Flexible Server) |
|------|-------------------------|---------------------------------------------------------------------|
| Schema owner | `GEPER_OWNER` | `geper_owner` schema, owned by role `geper_owner` |
| Tables | `DEPARTMENTS`, `JOBS`, `EMPLOYEES`, `JOB_HISTORY` | `geper_owner.departments`, `geper_owner.jobs`, `geper_owner.employees`, `geper_owner.job_history` |
| Sequences | `DEPARTMENTS_SEQ`, `EMPLOYEES_SEQ` | `geper_owner.departments_seq`, `geper_owner.employees_seq` |
| Trigger | `UPDATE_JOB_HISTORY` (PL/SQL) | `geper_owner.fn_update_job_history()` + `update_job_history` trigger (PL/pgSQL) |
| Row counts (synthetic baseline) | 6 departments, 10 jobs, 30 employees, 4 job_history rows | same (see `docs/functional-baseline.md`) |

This is an **offline** migration: GEPER is taken out of service for the
duration of the cutover window (expected well under a minute for this
dataset's volume), because `JOB_HISTORY` rows are written by a
database-side trigger and must not be mutated concurrently with the export.

## 2. Pre-requisites

1. The target Azure Database for PostgreSQL Flexible Server instance exists
   and `db/migration/postgres/01_pg_schema_and_roles.sql` and
   `02_pg_trigger_update_job_history.sql` have already been applied (empty
   schema, roles and trigger in place, no data yet).
2. Network connectivity (via VPN/private endpoint or a bastion host) from
   the operator's workstation to both the source Oracle instance and the
   target PostgreSQL Flexible Server.
3. `ora2pg` (or a similar Oracle→PostgreSQL extraction tool) and the
   PostgreSQL client tools (`psql`) are installed on the operator's
   workstation or migration jump box. For this fictitious dataset's small
   volume, a hand-maintained CSV/INSERT export (see §3, step 2 option B) is
   also sufficient and avoids an extra tool dependency.
4. A verified, recent Oracle export/backup exists in case rollback is
   required (RMAN backup or `expdp` of `GEPER_OWNER`).

## 3. Cutover window steps

1. **Freeze writes.** Stop the GEPER application instance(s) (or scale to
   zero) so no new INSERT/UPDATE/DELETE reaches `EMPLOYEES`, `DEPARTMENTS`,
   `JOBS`, or `JOB_HISTORY`. Because `UPDATE_JOB_HISTORY` is a row trigger,
   data must be static during export so the point-in-time snapshot is
   internally consistent (e.g. no in-flight job change that has updated
   `EMPLOYEES.ASSIGNMENT_START_DATE` without yet committing the matching
   `JOB_HISTORY` insert).
2. **Export from Oracle** (read-only; does not modify source data), in FK
   order: `DEPARTMENTS` → `JOBS` → `EMPLOYEES` → `JOB_HISTORY`.
   - *Option A — `ora2pg`*: run `ora2pg` in `COPY` or `INSERT` export mode
     scoped to the `GEPER_OWNER` schema and these four tables, producing a
     PostgreSQL-compatible data file (`ora2pg` handles `NUMBER`→`INTEGER`/
     `NUMERIC`, `VARCHAR2`→`VARCHAR`, and `DATE`→`DATE` type mapping
     automatically, matching `01_pg_schema_and_roles.sql`).
   - *Option B — manual `expdp`/`SELECT` + generated `INSERT`s*: for a
     dataset this size, export each table with `SELECT * FROM <table> ORDER
     BY <pk>` and generate `INSERT INTO geper_owner.<table> (...) VALUES
     (...)` statements (this is the same shape as
     `db/migration/postgres/03_pg_synthetic_data.sql`, which already
     contains this fictitious baseline dataset pre-converted for the local
     lab / test environment).
3. **Load into PostgreSQL**, in the same FK order, authenticated as
   `geper_owner` (or another role with `INSERT` on the four tables):
   `departments` → `jobs` → `employees` → `job_history`. Use a single
   transaction per table (or one transaction for the whole load) so a
   failure does not leave a partially-loaded table.
4. **Re-point the sequences** so new inserts after cutover do not collide
   with migrated primary keys:
   ```sql
   SELECT setval('geper_owner.departments_seq', (SELECT MAX(department_id) FROM geper_owner.departments) + 10, false);
   SELECT setval('geper_owner.employees_seq',   (SELECT MAX(employee_id)   FROM geper_owner.employees)   + 1,  false);
   ```
   (`+10`/`+1` mirror the original `INCREMENT BY` step sizes so the first
   post-cutover `nextval()` lands on the next free id, exactly as the
   Oracle sequences would have.)
5. **Verify** (see §4) before resuming traffic.
6. **Cut the application over**: update `GEPER_DB_URL` (and
   `GEPER_LAB_DB_URL` if the labs are used) to the PostgreSQL Flexible
   Server connection string and restart/redeploy the GEPER application
   instances (see `src/main/resources/application.yml`).
7. **Resume writes** by bringing the application back online.

## 4. Post-load verification

Run these checks against the target before declaring the cutover complete
(the exact row counts below are the fictitious synthetic baseline; replace
with the real source counts for non-demo data):

```sql
SELECT count(*) FROM geper_owner.departments;   -- expected: 6
SELECT count(*) FROM geper_owner.jobs;          -- expected: 10
SELECT count(*) FROM geper_owner.employees;     -- expected: 30
SELECT count(*) FROM geper_owner.job_history;   -- expected: 4

-- No orphaned foreign keys:
SELECT count(*) FROM geper_owner.employees e
  LEFT JOIN geper_owner.jobs j ON j.job_id = e.job_id WHERE j.job_id IS NULL;        -- expected: 0
SELECT count(*) FROM geper_owner.job_history h
  LEFT JOIN geper_owner.employees e ON e.employee_id = h.employee_id WHERE e.employee_id IS NULL; -- expected: 0

-- Aggregate parity with the Oracle baseline (see docs/functional-baseline.md):
SELECT COALESCE(SUM(salary),0), COALESCE(ROUND(AVG(salary),2),0) FROM geper_owner.employees; -- 99800 / 3326.67
```

Also re-run the `UPDATE_JOB_HISTORY` trigger-equivalence checks from the
skill's verification section against the newly-loaded data (update an
employee's `job_id`, confirm exactly one new `job_history` row with the
prior job/department and `end_date = CURRENT_DATE`, and that a salary-only
update creates no history row) before resuming application traffic.

## 5. Rollback

If verification fails, the application stays pointed at Oracle (step 6 is
only performed after step 5 passes), so rollback is simply: do not cut the
connection string over, truncate the partially-loaded PostgreSQL tables
(`TRUNCATE geper_owner.job_history, geper_owner.employees, geper_owner.jobs,
geper_owner.departments;`), fix the extraction/load issue, and repeat from
step 2.

## 6. Current project status

No live Azure Database for PostgreSQL Flexible Server instance or live
Oracle instance is provisioned for this repository at the time of this
migration (per the modernization plan's open questions and the Phase 1
infra-decision-table, which runs integration tests in Mock mode). This
document defines the transfer procedure to execute once both instances
exist; the local lab/test dataset itself is already available in
PostgreSQL-ready form at `db/migration/postgres/03_pg_synthetic_data.sql`.
