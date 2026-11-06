# Modernization Summary — 002-transform-oracle-to-postgresql

## finalStatus
**success**

## successCriteriaStatus
- passBuild: **true**
- passUnitTests: **true**

## Summary

Migrated the GEPER database layer from Oracle Database 12c R2 to Azure Database
for PostgreSQL Flexible Server, using skill `geper-oracle12c-to-postgresql-migration`
via `execute-modernization-task`.

### Schema, sequences & trigger
- Replaced `db/accounts/`, `db/schema/`, `db/data/`, `db/reset/` with a new
  canonical `db/migration/postgres/` set of scripts:
  - `01_pg_schema_and_roles.sql` — least-privilege roles (`geper_owner`,
    `geper_app`, `geper_labro`), `geper_owner` schema, tables with
    PostgreSQL-native types (`NUMBER`→`INTEGER`/`NUMERIC`, `VARCHAR2`→`VARCHAR`,
    `DATE`→`DATE`), and native sequences `departments_seq` (START 70) /
    `employees_seq` (START 1000).
  - `02_pg_trigger_update_job_history.sql` — `UPDATE_JOB_HISTORY` reimplemented
    as a `SECURITY DEFINER` PL/pgSQL function (`fn_update_job_history()`) with
    `SET search_path` pinned inside the function body, plus the
    `update_job_history` trigger, preserving the same definer-rights and
    conditional-firing semantics (fires only on `job_id`/`department_id`
    change, using `COALESCE` for NULL-safe comparison).
  - `03_pg_synthetic_data.sql`, `90_pg_reset_lab.sql`, `99_pg_drop_all.sql` —
    converted synthetic data and lab reset/drop scripts.

### JDBC dialect & driver
- `DashboardRepository`, `DepartmentRepository`: `NVL` → `COALESCE`.
- `DepartmentRepository`, `EmployeeRepository`: `SELECT *_SEQ.NEXTVAL FROM DUAL`
  → `SELECT nextval('*_seq')`.
- `LabDataSourceConfig`, `application.yml`: `ALTER SESSION SET CURRENT_SCHEMA`
  → `SET search_path TO geper_owner, public` (as `connection-init-sql`).
- `pom.xml`: removed `com.oracle.database.jdbc:ojdbc8` + `ojdbc.version`
  property; added `org.postgresql:postgresql` (version managed by the Spring
  Boot 3.5 BOM).
- Datasource URLs/usernames in `application.yml` and
  `config/application-local-lab.yml.example` updated to
  `jdbc:postgresql://...` with lowercase PostgreSQL role names.

### Offline data transfer plan
- Authored `docs/migration/oracle-to-postgresql-data-transfer-plan.md`
  covering scope, prerequisites, cutover steps (schema/role provisioning,
  data export/import options including `ora2pg`, sequence re-pointing via
  `setval`, post-load verification queries), and rollback guidance.

### Supporting changes
- `scripts/provision-local-db.sh` rewritten to provision a
  `postgres:16-alpine` container and apply the new `db/migration/postgres/*.sql`
  scripts (was `gvenzl/oracle-free`).
- Updated `README.md`, `docs/architecture.md`, `docs/data-dictionary.md`,
  `docs/demo-objectives.md`, `docs/security-labs.md`, `docs/functional-baseline.md`,
  and `ATTRIBUTIONS.md` to reflect PostgreSQL terminology, paths, and the
  `org.postgresql` driver; comments in domain/repository/controller classes and
  two Thymeleaf templates updated from Oracle to PostgreSQL wording.
- `GeperIntegrationTest` / `LabVulnerabilityCharacterizationIT` javadoc and a
  test method name updated for terminology only (no behavior change); both
  remain governed by the frozen `src/test/test-cases/` baseline, which was not
  modified.
- `infra/azure/**` (legacy Oracle VM Bicep/bootstrap) intentionally left
  untouched — explicitly reserved for task `005-deployment-azure-container-apps`
  per the modernization plan.

### Verification
- Consistency check (`validation-check-consistency`) reported **0 Critical, 0
  Major, 1 Minor** issue (hardcoded lab-only placeholder passwords in
  `01_pg_schema_and_roles.sql`, already documented in-file as lab-only and
  requiring change before any production use — accepted as-is, consistent with
  the pre-existing baseline convention).
- `mvn clean test` — **BUILD SUCCESS**. All unit tests pass (`LabConfigurationTest`,
  `LabLoopbackFilterTest`, `LabSearchSqlTest`); `GeperIntegrationTest`'s 10 live-DB
  tests correctly skip (no PostgreSQL instance provisioned in this environment),
  consistent with the project's existing `@EnabledIf` guard pattern.
- Changes committed to the current branch.
