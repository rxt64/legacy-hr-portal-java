# Infra Decision Table

> This document is part of the **frozen baseline bundle**. It records, for every external dependency the
> migrated application talks to, whether the post-migration tests will exercise it as a **real** provisioned
> resource, a **testcontainer**-backed emulator/dependency, or a **mock** at the SDK / HTTP boundary. The
> decision is made once here and reused as-is by the `verify-test-baseline` skill.

## Metadata

| Field | Value |
|-------|-------|
| Project | GEPER (`com.monteazul:geper`) |
| Module | `geper` (single Maven module, root project) |
| Migration Scope | migrate from Oracle Database 12c R2 (VM) and Java 8 / Spring Boot 2.7 to Azure Database for PostgreSQL Flexible Server and Java 21 / Spring Boot 3.5 on Azure Container Apps |
| Integration Test Environment | mock |
| Created At | 2026-11-06 |
| `infra/` Snapshot | infra-missing (repository's `infra/azure` Bicep targets the legacy VM + Oracle 12c stack only; it defines no Azure Database for PostgreSQL Flexible Server resource) |
| Status | baseline (frozen) |

## Decision Table

| Dependency | Infra Match | Decision | Auth Method | Reason |
|---|---|---|---|---|
| Azure Database for PostgreSQL Flexible Server (target datastore replacing Oracle 12c R2; no instance name assigned yet) | No | mock | n/a | `infra/azure` contains no Azure Database for PostgreSQL Flexible Server resource (legacy VM + Oracle Bicep only) and no live instance is available to this project; per migration task `004-integrationTest`, post-migration integration tests run in Mock mode against mocked database dependencies at the Spring `DataSource` / JDBC boundary (`infra-missing`). |

> Only one external dependency exists in this module's migration scope: the relational database (Oracle
> 12c R2 today, Azure Database for PostgreSQL Flexible Server after migration). There are no other
> cross-module service calls, message brokers, caches, or third-party HTTP APIs in GEPER's entry-point
> inventory (see `test-cases.md`), so no additional rows are required.

### Decision rules applied

- `Integration Test Environment = mock` (confirmed via migration task `004-integrationTest`'s requirement:
  "Since no live Azure Database for PostgreSQL Flexible Server instance is currently available to this
  project, run integration tests in Mock mode using mocked database dependencies"), so the Decision for
  every row is `mock` regardless of `Infra Match`, per the skill's mandatory rule.
- `infra/` exists but has no matching resource for the target dependency (`Infra Match = No`), which is
  consistent with (and reinforces) the `mock` decision.
- `Auth Method = n/a` is used because `Decision = mock`.
