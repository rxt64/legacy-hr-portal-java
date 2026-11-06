# Baseline Summary — 000-setupBaseline

## Module Scoping

| Module | In Scope? | Reason |
|---|---|---|
| `geper` (root, single Maven module) | Yes | Directly accesses Oracle Database 12c R2 via `spring-boot-starter-jdbc` + `ojdbc8` (`EmployeeRepository`, `DepartmentRepository`, `JobRepository`, `LabSearchRepository`) — the resource being migrated to Azure Database for PostgreSQL Flexible Server. |

No other modules exist in this repository.

## Entry-Point Inventory (25 HTTP entry points)

All entry points are Spring MVC `@Controller` HTTP routes (no CLI, scheduled jobs, or message-queue listeners in this application):

- Dashboard: `GET /`
- Employees: `GET/POST /empleados`, `GET /empleados/{id}`, `GET /empleados/nuevo`, `GET/POST /empleados/{id}/editar|{id}`, `POST /empleados/{id}/salario`, `POST /empleados/{id}/asignacion`, `POST /empleados/{id}/observaciones`
- Departments: `GET/POST /departamentos`, `GET /departamentos/{id}`, `GET /departamentos/nuevo`, `GET/POST /departamentos/{id}/editar|{id}`
- Jobs: `GET /puestos`, `GET/POST /puestos/{id}/editar|{id}`
- Vulnerability labs (conditionally registered, `geper.labs.enabled`): `GET /lab`, `GET /lab/sqli`, `GET/POST /lab/xss`, `GET /lab/xss/view/{id}`, `POST /lab/xss/reset/{id}`

Full inventory with source file:symbol references is in `src/test/test-cases/test-cases.md`.

## Existing Test Inventory & Conventions (extracted)

| Existing Test Class | What it covers | Mode |
|---|---|---|
| `GeperIntegrationTest` | `GET /`, `GET /lab*` (disabled-404), plus internal service/repository calls (dashboard stats, catalog salary summary, employee search incl. SQLi-literal safety, employee/department create, job-history trigger, salary-only no-history) | Real Oracle, gated by `GEPER_IT_JDBC_URL` env var; `@Transactional` rollback for mutations |
| `LabConfigurationTest` | Lab bean registration gated by `geper.labs.enabled` | Offline (`ApplicationContextRunner`, mocked collaborators) |
| `LabLoopbackFilterTest` | `/lab/**` loopback restriction | Offline (`MockHttpServletRequest`/`MockFilterChain`) |
| `LabSearchSqlTest` | SQLi characterization at the string level (JAVA-SQLI-01) | Offline, no datasource |
| `LabVulnerabilityCharacterizationIT` | SQLi characterization via `LabSearchRepository.vulnerableSearch` (not through the HTTP controller) | Real Oracle read-only account, gated by `GEPER_LAB_IT=1` |

**Conventions extracted (binding for `verify-test-baseline`):** JUnit 5 + AssertJ; `@SpringBootTest` + `@AutoConfigureMockMvc` + `MockMvc` for HTTP-level tests; `@DynamicPropertySource` to inject datasource coordinates from environment variables; `@EnabledIf` SpEL gates on environment variables for tests needing a live datasource; mutating tests wrapped in `@Transactional` to auto-rollback; class suffix `IntegrationTest`/`*IT` for datasource-backed tests, plain class name for offline unit tests; one test class generally scoped per concern/controller area.

## New Test Cases vs. Existing Coverage (by category)

| Category | Covered-by-existing | New in `test-cases.md` |
|---|---|---|
| happy-path | 2 (dashboard page, lab-disabled config via `LabConfigurationTest`) | 24 |
| boundary | 0 | 3 |
| special-input | 1 (SQLi-literal search, referenced) | 4 |
| failure | 2 (lab routes 404 when disabled) | 16 |
| **Total test cases in `test-cases.md`** | — | **49** (TC-GEPER-001..049) |

All 25 entry points satisfy the coverage gate (≥1 happy-path + ≥1 failure case each, via existing and/or new cases).

## `testdata/` File Listing

```
testdata/
├── seed-data/
│   └── seed-summary.md
├── inputs/
│   ├── employee-create-valid.json
│   ├── employee-create-boundary-maxlength.json
│   ├── employee-create-blank-firstname.json
│   ├── employee-create-invalid-salary.json
│   ├── employee-update-valid.json
│   ├── employee-update-blank-lastname.json
│   ├── department-create.json
│   ├── department-update.json
│   ├── job-update.json
│   ├── lab-xss-observation.json
│   └── search-injection-term.txt
└── expectations/
    ├── dashboard-contains.txt
    ├── employee-list-search-mora-contains.txt
    ├── employee-detail-101-contains.txt
    ├── department-list-contains.txt
    └── job-list-contains.txt
```

## Infra Decision Table (summary; full detail in `infra-decision-table.md`)

| Dependency | Infra Match | Decision | Reason |
|---|---|---|---|
| Azure Database for PostgreSQL Flexible Server (target datastore) | No | **mock** | `infra/azure` only defines the legacy VM + Oracle stack (no PostgreSQL Flexible Server resource); migration task `004-integrationTest` explicitly requires Mock mode since no live instance is available. |

Integration Test Environment confirmed: **mock** (sourced from `.github/modernize/geper-java21-pg-aca/.metadata/tasks.json` task `004-integrationTest` requirement text — no `env.md` or `infra/infra-config.md` with a provisioned PostgreSQL resource exists).

## Freeze Validation

- Step 6 Required Field Checklist: **passed** for all 49 test cases (see checklist section inside `test-cases.md`).
- Coverage Gate: **passed** — all 25 entry points have ≥1 happy-path and ≥1 failure test case (existing or new).
- Banned phrasings self-check: **passed** — no vague phrasing found.
- `src/test/test-cases/` is now declared **FROZEN**. No further changes to `test-cases.md`, `infra-decision-table.md`, or `testdata/**` are permitted without an explicit re-freeze cycle.

## Build/Test Verification

Ran `mvn -o test` against the unmodified production source (no production code was touched by this task — only `src/test/test-cases/**` was added):

- `BUILD SUCCESS`
- `Tests run: 10, Failures: 0, Errors: 0, Skipped: 1` (the 1 skip is `GeperIntegrationTest`, gated by `@EnabledIf` on `GEPER_IT_JDBC_URL`, which is expected/by-design in this environment with no live Oracle instance).

## Final Status

- **finalStatus**: success
- **successCriteriaStatus**: `passBuild = true`, `passUnitTests = true`
- **Summary**: Captured a frozen behavioral specification (`src/test/test-cases/test-cases.md`, 49 test cases across all 25 HTTP entry points of the GEPER web app) plus supporting `testdata/` fixtures and an `infra-decision-table.md` confirming Mock-mode for the Oracle→PostgreSQL dependency, per the plan's `004-integrationTest` requirement. No production source code was modified. The existing offline/online test suite still builds and passes unchanged.
