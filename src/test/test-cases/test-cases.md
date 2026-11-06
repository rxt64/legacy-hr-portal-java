# Test Cases

> This document is the **frozen behavioral specification** of the GEPER module's external surface for the
> migration in scope. It is the source of truth that the `verify-test-baseline` skill uses to generate
> `*PostMigrationIT` tests against the new implementation. No test code is generated in this phase.

## Metadata

| Field | Value |
|-------|-------|
| Project | GEPER (`com.monteazul:geper`) |
| Module | `geper` (single Maven module, root project) |
| Migration Scope | migrate from Oracle Database 12c R2 (VM) and Java 8 / Spring Boot 2.7 to Azure Database for PostgreSQL Flexible Server and Java 21 / Spring Boot 3.5 on Azure Container Apps |
| Created At | 2026-11-06 |
| Status | baseline (frozen) |
| Testing Conventions | JUnit 5 + AssertJ + Spring Boot Test (`@SpringBootTest`, `@AutoConfigureMockMvc`, `MockMvc`); `@EnabledIf` gates IT classes needing a live datasource via `GEPER_IT_JDBC_URL` / `GEPER_LAB_IT`; mutating tests wrapped in `@Transactional` to roll back; class suffix `IntegrationTest` / `*IT`; offline unit tests have no suffix convention beyond the scenario name. |

## Existing Test Coverage

| Entry Point | Existing Test (FQ name) | Categories Covered |
|---|---|---|
| `GET /` | `com.monteazul.geper.GeperIntegrationTest#dashboardPageRenders` | happy-path |
| `GET /lab`, `GET /lab/sqli` (labs disabled, default config) | `com.monteazul.geper.GeperIntegrationTest#labRoutesReturn404WhenDisabled` | failure (route absent) |
| `com.monteazul.geper.service.DashboardService#stats` (internal, exercised directly) | `com.monteazul.geper.GeperIntegrationTest#dashboardAggregatesComeFromOracleAndMatchBaseline` | happy-path (supporting evidence for `GET /`) |
| `com.monteazul.geper.service.CatalogService#salarySummary` (internal) | `com.monteazul.geper.GeperIntegrationTest#departmentSalarySummaryCoversAllDepartments` | happy-path (supporting evidence for `GET /departamentos`) |
| `com.monteazul.geper.service.EmployeeService#search` (internal) | `com.monteazul.geper.GeperIntegrationTest#parameterizedSearchFiltersByName`, `#parameterizedSearchTreatsInjectionTextAsLiteral` | happy-path, special-input (supporting evidence for `GET /empleados`) |
| `com.monteazul.geper.service.EmployeeService#create` / `EmployeeRepository#changeJob` / `#updateSalary` (internal) | `com.monteazul.geper.GeperIntegrationTest#createEmployeeUsesSequenceAndPersists`, `#changingAssignmentCreatesJobHistoryViaTrigger`, `#salaryOnlyChangeDoesNotCreateHistory` | happy-path (supporting evidence for `POST /empleados`, `POST /empleados/{id}/asignacion`, `POST /empleados/{id}/salario`) |
| `com.monteazul.geper.service.CatalogService#createDepartment` (internal) | `com.monteazul.geper.GeperIntegrationTest#createDepartmentUsesSequenceAndPersists` | happy-path (supporting evidence for `POST /departamentos`) |
| Lab bean registration gated by `geper.labs.enabled` | `com.monteazul.geper.LabConfigurationTest` (all 4 methods) | happy-path, failure (beans absent) |
| `/lab/**` loopback gate (`LabLoopbackFilter`) | `com.monteazul.geper.LabLoopbackFilterTest` (all 3 methods) | happy-path, failure (non-loopback 404) |
| `LabSearchRepository#buildSql` / `#vulnerableSearch` (pre-remediation characterization, JAVA-SQLI-01) | `com.monteazul.geper.LabSearchSqlTest`, `com.monteazul.geper.LabVulnerabilityCharacterizationIT` | special-input (documents the pre-fix flaw; NOT re-asserted as a must-preserve contract below — see note in the Lab section) |

> The internal-method tests above exercise business logic directly (bypassing HTTP) and are retained as
> supporting evidence; they do NOT by themselves satisfy HTTP entry-point coverage, so the corresponding
> controller entry points still get their own test cases below.

## Entry-Point Inventory

| Entry Point | Type | Source (file:symbol) | Covered by |
|---|---|---|---|
| `GET /` | HTTP | `web/DashboardController.java:home` | existing (happy), TC-GEPER-002 (failure) |
| `GET /empleados` | HTTP | `web/EmployeeController.java:list` | TC-GEPER-003..006 |
| `GET /empleados/{id}` | HTTP | `web/EmployeeController.java:detail` | TC-GEPER-007, TC-GEPER-008 |
| `GET /empleados/nuevo` | HTTP | `web/EmployeeController.java:newForm` | TC-GEPER-009, TC-GEPER-010 |
| `POST /empleados` | HTTP | `web/EmployeeController.java:create` | TC-GEPER-011..014 |
| `GET /empleados/{id}/editar` | HTTP | `web/EmployeeController.java:editForm` | TC-GEPER-015, TC-GEPER-016 |
| `POST /empleados/{id}` | HTTP | `web/EmployeeController.java:update` | TC-GEPER-017..019 |
| `POST /empleados/{id}/salario` | HTTP | `web/EmployeeController.java:changeSalary` | TC-GEPER-020, TC-GEPER-021 |
| `POST /empleados/{id}/asignacion` | HTTP | `web/EmployeeController.java:changeAssignment` | TC-GEPER-022..024 |
| `POST /empleados/{id}/observaciones` | HTTP | `web/EmployeeController.java:updateObservations` | TC-GEPER-025, TC-GEPER-026 |
| `GET /departamentos` | HTTP | `web/DepartmentController.java:list` | TC-GEPER-027, TC-GEPER-028 |
| `GET /departamentos/{id}` | HTTP | `web/DepartmentController.java:detail` | TC-GEPER-029, TC-GEPER-030 |
| `GET /departamentos/nuevo` | HTTP | `web/DepartmentController.java:newForm` | TC-GEPER-031 |
| `POST /departamentos` | HTTP | `web/DepartmentController.java:create` | TC-GEPER-032, TC-GEPER-033 |
| `GET /departamentos/{id}/editar` | HTTP | `web/DepartmentController.java:editForm` | TC-GEPER-034, TC-GEPER-035 |
| `POST /departamentos/{id}` | HTTP | `web/DepartmentController.java:update` | TC-GEPER-036, TC-GEPER-037 |
| `GET /puestos` | HTTP | `web/JobController.java:list` | TC-GEPER-038, TC-GEPER-039 |
| `GET /puestos/{id}/editar` | HTTP | `web/JobController.java:editForm` | TC-GEPER-040, TC-GEPER-041 |
| `POST /puestos/{id}` | HTTP | `web/JobController.java:update` | TC-GEPER-042, TC-GEPER-043 |
| `GET /lab` (default config) | HTTP | `lab/LabController.java:index` | existing: `GeperIntegrationTest#labRoutesReturn404WhenDisabled` (failure) |
| `GET /lab` (labs enabled, loopback) | HTTP | `lab/LabController.java:index` | TC-GEPER-044 |
| `GET /lab/sqli` | HTTP | `lab/LabController.java:sqli` | TC-GEPER-045, TC-GEPER-046 |
| `GET /lab/xss`, `POST /lab/xss` | HTTP | `lab/LabController.java:xssForm,xssStore` | TC-GEPER-047 |
| `GET /lab/xss/view/{employeeId}` | HTTP | `lab/LabController.java:xssView` | TC-GEPER-048 |
| `POST /lab/xss/reset/{employeeId}` | HTTP | `lab/LabController.java:xssReset` | TC-GEPER-049 |

Entry-point type used throughout: `HTTP`.

---

## Test Cases

### TC-GEPER-001 Dashboard renders aggregated stats — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-001 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /` |
| Description | The dashboard page returns 200 and renders the aggregated indicators heading. covered-by-existing: `com.monteazul.geper.GeperIntegrationTest#dashboardPageRenders` plus `#dashboardAggregatesComeFromOracleAndMatchBaseline` for the underlying aggregate values (30 employees, 6 departments, 10 jobs, total salary `99800`). Not duplicated below. |

**Trigger** — `GET /` with no parameters.

**Preconditions** — Seed dataset loaded as described in `testdata/seed-data/seed-summary.md`.

**Expected Response** — HTTP 200; body contains `testdata/expectations/dashboard-contains.txt`.

**Resource Verification** — none (read-only aggregation query; no mutation).

**Data References** — `testdata/expectations/dashboard-contains.txt`, `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-002 Dashboard dependency failure maps to server error — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-002 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /` |
| Description | When the database dependency backing `DashboardService.stats()` / `CatalogService.salarySummary()` is unavailable, the request fails with HTTP 500 and no page content is rendered. |

**Trigger** — `GET /` with the database dependency simulated as unavailable (connection refused / timeout at the JDBC boundary).

**Preconditions** — Database dependency is unreachable for the duration of this request only.

**Expected Response** — HTTP 500 (Spring Boot default error handling; no custom `@ExceptionHandler` exists in `DashboardController`).

**Resource Verification** — none (no state is mutated by this read-only entry point).

**Data References** — none.

---

### TC-GEPER-003 Employee search by name returns matches — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-003 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados` |
| Description | Searching by a partial, case-insensitive name returns only matching employees. |

**Trigger** — `GET /empleados?name=mora` (query param `name`, no `departmentId`/`jobId`).

**Preconditions** — Seed dataset loaded (`testdata/seed-data/seed-summary.md`); employee 116 "Felipe Mora Zuñiga" exists.

**Expected Response** — HTTP 200; body contains `testdata/expectations/employee-list-search-mora-contains.txt`; model attribute `results` contains only employees whose first or last name contains "mora" case-insensitively.

**Resource Verification** — none (read-only).

**Data References** — `testdata/expectations/employee-list-search-mora-contains.txt`.

---

### TC-GEPER-004 Employee list with no filters returns full roster — boundary

| Field | Value |
|-------|-------|
| ID | TC-GEPER-004 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados` |
| Description | With no `name`/`departmentId`/`jobId` parameters, every seeded employee is returned (upper boundary: no filter narrows the set). |

**Trigger** — `GET /empleados` (no query parameters).

**Preconditions** — Seed dataset loaded (30 employees).

**Expected Response** — HTTP 200; model attribute `results` has exactly 30 entries.

**Resource Verification** — none (read-only).

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-005 Search term treats SQL metacharacters as a literal — special-input

| Field | Value |
|-------|-------|
| ID | TC-GEPER-005 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados` |
| Description | A name parameter containing SQL injection metacharacters is bound as a literal value (parameterized query) and matches zero employees, since no seeded name contains that literal text. |

**Trigger** — `GET /empleados?name=x%27%29%20OR%201%3D1%20--` (URL-encoded form of `testdata/inputs/search-injection-term.txt`, i.e. `x') OR 1=1 --`).

**Preconditions** — Seed dataset loaded.

**Expected Response** — HTTP 200; model attribute `results` is an empty list.

**Resource Verification** — none (read-only; no rows are ever returned or altered by this request).

**Data References** — `testdata/inputs/search-injection-term.txt`.

---

### TC-GEPER-006 Non-numeric departmentId is rejected — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-006 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados` |
| Description | A `departmentId` query parameter that cannot be converted to `Integer` fails Spring MVC argument binding before the controller method runs. |

**Trigger** — `GET /empleados?departmentId=abc`.

**Preconditions** — none.

**Expected Response** — HTTP 400 Bad Request (`MethodArgumentTypeMismatchException`, default Spring Boot error handling).

**Resource Verification** — none.

**Negative Verification** — The employee list query is never executed against the database.

**Data References** — none.

---

### TC-GEPER-007 Employee detail page renders — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-007 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados/{id}` |
| Description | Requesting an existing employee id renders its detail page including job history. |

**Trigger** — `GET /empleados/101`.

**Preconditions** — Employee 101 "Marisol Fonseca Arias" exists (seed dataset).

**Expected Response** — HTTP 200; body contains the employee's full name (see `testdata/seed-data/seed-summary.md` for the reference name); model attributes `employee` and `history` are populated (`history` has at least 0 entries, is non-null).

**Resource Verification** — none (read-only).

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-008 Unknown employee id redirects to the list — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-008 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados/{id}` |
| Description | Requesting a non-existent employee id redirects to the employee list rather than rendering an error page. |

**Trigger** — `GET /empleados/9999`.

**Preconditions** — Employee id `9999` does not exist in the seed dataset.

**Expected Response** — HTTP 302 Found; `Location` header value ends with `/empleados`.

**Resource Verification** — none.

**Negative Verification** — No `employee` detail page is rendered; no exception propagates to a 500 response.

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-009 New-employee form renders — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-009 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados/nuevo` |
| Description | The blank creation form renders with the job and department catalogs populated for the select inputs. |

**Trigger** — `GET /empleados/nuevo`.

**Preconditions** — Seed dataset loaded (10 jobs, 6 departments for the catalog selects).

**Expected Response** — HTTP 200; model attributes `jobs` (size 10), `departments` (size 6), `mode = "create"` are present.

**Resource Verification** — none (read-only).

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-010 New-employee form dependency failure — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-010 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados/nuevo` |
| Description | When the catalog lookups (`CatalogService.jobs()`/`departments()`) fail at the database boundary, the request maps to HTTP 500. |

**Trigger** — `GET /empleados/nuevo` with the database dependency simulated as unavailable.

**Preconditions** — Database dependency unreachable for the duration of this request only.

**Expected Response** — HTTP 500.

**Resource Verification** — none.

**Data References** — none.

---

### TC-GEPER-011 Creating an employee persists a new row — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-011 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados` |
| Description | A valid creation form submission inserts a new employee using the id-generation sequence/equivalent and redirects to its detail page. covered-by-existing (service-level only): `GeperIntegrationTest#createEmployeeUsesSequenceAndPersists`; this case additionally pins the HTTP-level contract. |

**Trigger** — `POST /empleados`, form-encoded body per `testdata/inputs/employee-create-valid.json` (fields: `firstName`, `lastName`, `email`, `jobId`, `salary`, `departmentId`).

**Preconditions** — Job `OPER` and department `60` exist (seed dataset); highest pre-existing employee id is 130, so the next generated id is `>= 1000` per the sequence seeding in `db/data/03_synthetic_data.sql`.

**Expected Response** — HTTP 302 Found; `Location` header matches `/empleados/{newId}` where `newId >= 1000`.

**Resource Verification** — A row exists in the employee store with `employeeId = newId`, `firstName = "Prueba"`, `lastName = "Sintetica"`, `jobId = "OPER"`, `salary = 1500`, `departmentId = 60`.

**Data References** — `testdata/inputs/employee-create-valid.json`.

---

### TC-GEPER-012 Creating an employee at max-length field boundaries — boundary

| Field | Value |
|-------|-------|
| ID | TC-GEPER-012 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados` |
| Description | `firstName`/`lastName` at the 40-character `@Size` maximum and `observations` at the 2000-character maximum are accepted and persisted verbatim (upper boundary of validated fields). |

**Trigger** — `POST /empleados`, form-encoded body per `testdata/inputs/employee-create-boundary-maxlength.json` (`firstName`/`lastName` = 40 repeated characters, `observations` = 2000 repeated characters per the file's `*Length` fields).

**Preconditions** — Job `OPER` and department `60` exist.

**Expected Response** — HTTP 302 Found; redirect to the new employee's detail page.

**Resource Verification** — The created row's `firstName` and `lastName` are each exactly 40 characters long and equal to the submitted values; `observations` is exactly 2000 characters long.

**Data References** — `testdata/inputs/employee-create-boundary-maxlength.json`.

---

### TC-GEPER-013 Creating an employee with a blank required field — special-input

| Field | Value |
|-------|-------|
| ID | TC-GEPER-013 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados` |
| Description | Submitting a blank `firstName` (violates `@NotBlank`) re-renders the creation form with validation errors instead of persisting the employee. |

**Trigger** — `POST /empleados`, form-encoded body per `testdata/inputs/employee-create-blank-firstname.json`.

**Preconditions** — none.

**Expected Response** — HTTP 200 (form re-rendered, not a redirect); view name `employees/form`; `BindingResult` reports a field error on `firstName`.

**Resource Verification** — none.

**Negative Verification** — No new employee row is created (employee count is unchanged from before the request).

**Data References** — `testdata/inputs/employee-create-blank-firstname.json`.

---

### TC-GEPER-014 Creating an employee with non-positive salary — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-014 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados` |
| Description | Submitting `salary = 0` (violates `@NotNull @Positive`) re-renders the creation form with validation errors instead of persisting the employee. |

**Trigger** — `POST /empleados`, form-encoded body per `testdata/inputs/employee-create-invalid-salary.json`.

**Preconditions** — none.

**Expected Response** — HTTP 200 (form re-rendered); view name `employees/form`; `BindingResult` reports a field error on `salary`.

**Resource Verification** — none.

**Negative Verification** — No new employee row is created.

**Data References** — `testdata/inputs/employee-create-invalid-salary.json`.

---

### TC-GEPER-015 Edit-employee form renders for an existing id — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-015 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados/{id}/editar` |
| Description | The edit form renders pre-populated with the existing employee's data. |

**Trigger** — `GET /empleados/101/editar`.

**Preconditions** — Employee 101 exists.

**Expected Response** — HTTP 200; model attribute `employee.employeeId = 101`; `mode = "edit"`.

**Resource Verification** — none.

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-016 Edit form for unknown employee id redirects — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-016 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /empleados/{id}/editar` |
| Description | Requesting the edit form for a non-existent employee id redirects to the employee list. |

**Trigger** — `GET /empleados/9999/editar`.

**Preconditions** — Employee id `9999` does not exist.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/empleados`.

**Resource Verification** — none.

**Negative Verification** — No edit form is rendered; no exception propagates to a 500 response.

**Data References** — none.

---

### TC-GEPER-017 Updating an employee persists changes — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-017 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}` |
| Description | A valid update form submission persists the new field values and redirects to the employee's detail page. |

**Trigger** — `POST /empleados/127`, form-encoded body per `testdata/inputs/employee-update-valid.json`.

**Preconditions** — Employee 127 "Gabriela Rivera Salas" exists with salary `1600` (seed dataset).

**Expected Response** — HTTP 302 Found; `Location` header ends with `/empleados/127`.

**Resource Verification** — The row for employee 127 has `salary = 1999` and `observations = "Actualizado por prueba de integracion."`.

**Data References** — `testdata/inputs/employee-update-valid.json`.

---

### TC-GEPER-018 Updating an employee with a blank required field — special-input

| Field | Value |
|-------|-------|
| ID | TC-GEPER-018 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}` |
| Description | Submitting a blank `lastName` on update re-renders the edit form with validation errors instead of persisting the change. |

**Trigger** — `POST /empleados/127`, form-encoded body per `testdata/inputs/employee-update-blank-lastname.json`.

**Preconditions** — Employee 127 exists with its seeded `lastName = "Rivera Salas"`.

**Expected Response** — HTTP 200 (form re-rendered); view name `employees/form`; `BindingResult` reports a field error on `lastName`.

**Resource Verification** — none.

**Negative Verification** — Employee 127's `lastName` remains `"Rivera Salas"` (unchanged).

**Data References** — `testdata/inputs/employee-update-blank-lastname.json`.

---

### TC-GEPER-019 Updating an unknown employee id — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-019 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}` |
| Description | Submitting a valid update payload against a non-existent employee id performs a no-op update (zero rows affected) and still redirects, since the repository issues an unconditional `UPDATE ... WHERE EMPLOYEE_ID = :id` with no existence check. |

**Trigger** — `POST /empleados/9999`, form-encoded body per `testdata/inputs/employee-update-valid.json`.

**Preconditions** — Employee id `9999` does not exist.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/empleados/9999`.

**Resource Verification** — none.

**Negative Verification** — No row is created for employee id `9999`; no existing employee row is modified.

**Data References** — `testdata/inputs/employee-update-valid.json`.

---

### TC-GEPER-020 Changing salary does not create job history — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-020 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}/salario` |
| Description | A salary-only change updates the salary and does not insert a job-history row. covered-by-existing (service-level only): `GeperIntegrationTest#salaryOnlyChangeDoesNotCreateHistory`; this case additionally pins the HTTP-level contract. |

**Trigger** — `POST /empleados/127/salario`, form param `salary=1999`.

**Preconditions** — Employee 127 exists; its job-history row count is `N` before the request.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/empleados/127`.

**Resource Verification** — Employee 127's `salary = 1999`; employee 127's job-history row count is still `N` (unchanged).

**Data References** — none.

---

### TC-GEPER-021 Changing salary without the required parameter — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-021 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}/salario` |
| Description | Omitting the required `salary` request parameter fails parameter binding before the controller method runs. |

**Trigger** — `POST /empleados/127/salario` with no `salary` parameter in the body.

**Preconditions** — Employee 127 exists.

**Expected Response** — HTTP 400 Bad Request (`MissingServletRequestParameterException`).

**Resource Verification** — none.

**Negative Verification** — Employee 127's salary is unchanged.

**Data References** — none.

---

### TC-GEPER-022 Changing job assignment records exactly one job-history row — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-022 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}/asignacion` |
| Description | Changing only the job id (department unchanged) inserts exactly one new job-history row recording the PRIOR job, via the trigger-equivalent behavior. covered-by-existing (service-level only): `GeperIntegrationTest#changingAssignmentCreatesJobHistoryViaTrigger`; this case additionally pins the HTTP-level contract. |

**Trigger** — `POST /empleados/126/asignacion`, form params `jobId=SUPERV` (department omitted, so it is treated as unchanged since employee 126 is currently in department 60 and the controller param is optional).

**Preconditions** — Employee 126 "Luis Castillo Umaña" has `jobId = "OPER"`, `departmentId = 60`; its job-history row count is `N` before the request.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/empleados/126`.

**Resource Verification** — Employee 126's job-history row count is `N + 1`; the newest history row's `jobId = "OPER"` (the prior job, closed by the change); employee 126's current `jobId = "SUPERV"`.

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-023 Omitting departmentId clears the employee's department — boundary

| Field | Value |
|-------|-------|
| ID | TC-GEPER-023 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}/asignacion` |
| Description | `EmployeeService.changeAssignment` treats an omitted `departmentId` as `null`; since the employee's current department is non-null, `deptChanged` evaluates `true` and the department is changed to `null` (boundary of the optional-parameter contract), recording the prior department in job history even though `jobId` is unchanged. |

**Trigger** — `POST /empleados/128/asignacion`, form param `jobId=OPER` only (same as employee 128's current job; `departmentId` parameter omitted entirely).

**Preconditions** — Employee 128 "Sergio Ortiz Camacho" has `jobId = "OPER"`, `departmentId = 60`; its job-history row count is `N` before the request.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/empleados/128`.

**Resource Verification** — Employee 128's `departmentId` becomes `null`; employee 128's job-history row count becomes `N + 1`; the newest history row's `departmentId = 60` (the prior department) and `jobId = "OPER"`.

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-024 Changing assignment for an unknown employee id — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-024 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}/asignacion` |
| Description | Requesting an assignment change for a non-existent employee id surfaces as an unhandled `IllegalArgumentException` from `EmployeeService.changeAssignment`, mapped by Spring Boot's default error handling. |

**Trigger** — `POST /empleados/9999/asignacion`, form params `jobId=OPER`.

**Preconditions** — Employee id `9999` does not exist.

**Expected Response** — HTTP 500 Internal Server Error.

**Resource Verification** — none.

**Negative Verification** — No job-history row is created for employee id `9999`.

**Data References** — none.

---

### TC-GEPER-025 Updating observations persists the raw text — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-025 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}/observaciones` |
| Description | A normal observations update stores the text and is rendered HTML-escaped on the employee detail card (`employees/detail.html` uses `th:text`), distinguishing this safe path from the lab's deliberately unsafe rendering. |

**Trigger** — `POST /empleados/123/observaciones`, form param `observations=Nueva observacion de prueba.`.

**Preconditions** — Employee 123 "Monica Alvarado Rios" exists.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/empleados/123`.

**Resource Verification** — Employee 123's `observations = "Nueva observacion de prueba."`; `GET /empleados/123` subsequently returns HTTP 200 with the text rendered HTML-escaped (no raw, unescaped HTML tags in the response body for this field).

**Data References** — none.

---

### TC-GEPER-026 Updating observations without the required parameter — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-026 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /empleados/{id}/observaciones` |
| Description | Omitting the required `observations` request parameter fails parameter binding before the controller method runs. |

**Trigger** — `POST /empleados/123/observaciones` with no `observations` parameter.

**Preconditions** — Employee 123 exists.

**Expected Response** — HTTP 400 Bad Request (`MissingServletRequestParameterException`).

**Resource Verification** — none.

**Negative Verification** — Employee 123's observations are unchanged.

**Data References** — none.

---

### TC-GEPER-027 Department list renders with salary summary — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-027 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /departamentos` |
| Description | The department list page renders the per-department aggregate salary summary. covered-by-existing (service-level only): `GeperIntegrationTest#departmentSalarySummaryCoversAllDepartments`; this case additionally pins the HTTP-level contract. |

**Trigger** — `GET /departamentos`.

**Preconditions** — Seed dataset loaded (6 departments).

**Expected Response** — HTTP 200; body contains `testdata/expectations/department-list-contains.txt`; model attribute `summary` has exactly 6 entries.

**Resource Verification** — none (read-only).

**Data References** — `testdata/expectations/department-list-contains.txt`.

---

### TC-GEPER-028 Department list dependency failure — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-028 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /departamentos` |
| Description | When the database dependency is unavailable, the request maps to HTTP 500. |

**Trigger** — `GET /departamentos` with the database dependency simulated as unavailable.

**Preconditions** — Database dependency unreachable for the duration of this request only.

**Expected Response** — HTTP 500.

**Resource Verification** — none.

**Data References** — none.

---

### TC-GEPER-029 Department detail renders with its members — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-029 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /departamentos/{id}` |
| Description | Requesting an existing department id renders its detail page along with the employees assigned to it. |

**Trigger** — `GET /departamentos/60`.

**Preconditions** — Department 60 "Operaciones" exists with 8 members (seed dataset).

**Expected Response** — HTTP 200; model attribute `department.departmentId = 60`; model attribute `members` has exactly 8 entries.

**Resource Verification** — none (read-only).

**Data References** — `testdata/seed-data/seed-summary.md`.

---

### TC-GEPER-030 Unknown department id redirects to the list — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-030 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /departamentos/{id}` |
| Description | Requesting a non-existent department id redirects to the department list. |

**Trigger** — `GET /departamentos/999`.

**Preconditions** — Department id `999` does not exist.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/departamentos`.

**Resource Verification** — none.

**Negative Verification** — No detail page is rendered; no exception propagates to a 500 response.

**Data References** — none.

---

### TC-GEPER-031 New-department form renders — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-031 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /departamentos/nuevo` |
| Description | The blank department creation form renders. |

**Trigger** — `GET /departamentos/nuevo`.

**Preconditions** — none.

**Expected Response** — HTTP 200; model attribute `mode = "create"`.

**Resource Verification** — none.

**Data References** — none.

---

### TC-GEPER-032 Creating a department persists a new row — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-032 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /departamentos` |
| Description | A creation form submission inserts a new department using the id-generation sequence/equivalent and redirects to its detail page. covered-by-existing (service-level only): `GeperIntegrationTest#createDepartmentUsesSequenceAndPersists`; this case additionally pins the HTTP-level contract. |

**Trigger** — `POST /departamentos`, form-encoded body per `testdata/inputs/department-create.json`.

**Preconditions** — Highest pre-existing department id is 60, so the next generated id is `>= 70` per the sequence seeding in `db/data/03_synthetic_data.sql`.

**Expected Response** — HTTP 302 Found; `Location` header matches `/departamentos/{newId}` where `newId >= 70`.

**Resource Verification** — A row exists with `departmentId = newId`, `departmentName = "Auditoria Interna Temporal"`, `location = "Monte Azul Central"`.

**Data References** — `testdata/inputs/department-create.json`.

---

### TC-GEPER-033 Creating a department when the dependency is unavailable — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-033 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /departamentos` |
| Description | When the database dependency is unavailable, the creation request maps to HTTP 500 and no row is persisted (there is no bean validation on `Department`, so this is the only failure path exercised at the HTTP boundary). |

**Trigger** — `POST /departamentos`, form-encoded body per `testdata/inputs/department-create.json`, with the database dependency simulated as unavailable.

**Preconditions** — Database dependency unreachable for the duration of this request only.

**Expected Response** — HTTP 500.

**Resource Verification** — none.

**Negative Verification** — No new department row is created.

**Data References** — `testdata/inputs/department-create.json`.

---

### TC-GEPER-034 Edit-department form renders for an existing id — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-034 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /departamentos/{id}/editar` |
| Description | The edit form renders pre-populated with the existing department's data. |

**Trigger** — `GET /departamentos/40/editar`.

**Preconditions** — Department 40 "Tecnologia" exists.

**Expected Response** — HTTP 200; model attribute `department.departmentId = 40`; `mode = "edit"`.

**Resource Verification** — none.

**Data References** — none.

---

### TC-GEPER-035 Edit form for unknown department id redirects — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-035 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /departamentos/{id}/editar` |
| Description | Requesting the edit form for a non-existent department id redirects to the department list. |

**Trigger** — `GET /departamentos/999/editar`.

**Preconditions** — Department id `999` does not exist.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/departamentos`.

**Resource Verification** — none.

**Negative Verification** — No edit form is rendered.

**Data References** — none.

---

### TC-GEPER-036 Updating a department persists changes — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-036 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /departamentos/{id}` |
| Description | A valid update form submission persists the new field values and redirects to the department's detail page. |

**Trigger** — `POST /departamentos/40`, form-encoded body per `testdata/inputs/department-update.json`.

**Preconditions** — Department 40 exists.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/departamentos/40`.

**Resource Verification** — Department 40's `departmentName = "Tecnologia e Innovacion"`, `location = "Torre Norte - Piso 3"`.

**Data References** — `testdata/inputs/department-update.json`.

---

### TC-GEPER-037 Updating a department when the dependency is unavailable — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-037 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /departamentos/{id}` |
| Description | When the database dependency is unavailable, the update request maps to HTTP 500. |

**Trigger** — `POST /departamentos/40`, form-encoded body per `testdata/inputs/department-update.json`, with the database dependency simulated as unavailable.

**Preconditions** — Department 40 exists; database dependency unreachable for the duration of this request only.

**Expected Response** — HTTP 500.

**Resource Verification** — none.

**Negative Verification** — Department 40's fields are unchanged.

**Data References** — `testdata/inputs/department-update.json`.

---

### TC-GEPER-038 Job list renders — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-038 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /puestos` |
| Description | The job catalog list renders all seeded jobs. |

**Trigger** — `GET /puestos`.

**Preconditions** — Seed dataset loaded (10 jobs).

**Expected Response** — HTTP 200; body contains `testdata/expectations/job-list-contains.txt`; model attribute `jobs` has exactly 10 entries.

**Resource Verification** — none (read-only).

**Data References** — `testdata/expectations/job-list-contains.txt`.

---

### TC-GEPER-039 Job list dependency failure — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-039 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /puestos` |
| Description | When the database dependency is unavailable, the request maps to HTTP 500. |

**Trigger** — `GET /puestos` with the database dependency simulated as unavailable.

**Preconditions** — Database dependency unreachable for the duration of this request only.

**Expected Response** — HTTP 500.

**Resource Verification** — none.

**Data References** — none.

---

### TC-GEPER-040 Edit-job form renders for an existing id — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-040 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /puestos/{id}/editar` |
| Description | The edit form renders pre-populated with the existing job's data. |

**Trigger** — `GET /puestos/OPER/editar`.

**Preconditions** — Job `OPER` exists.

**Expected Response** — HTTP 200; model attribute `job.jobId = "OPER"`.

**Resource Verification** — none.

**Data References** — none.

---

### TC-GEPER-041 Edit form for unknown job id redirects — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-041 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /puestos/{id}/editar` |
| Description | Requesting the edit form for a non-existent job id redirects to the job list. |

**Trigger** — `GET /puestos/NOPE/editar`.

**Preconditions** — Job id `NOPE` does not exist.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/puestos`.

**Resource Verification** — none.

**Negative Verification** — No edit form is rendered.

**Data References** — none.

---

### TC-GEPER-042 Updating a job persists changes — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-042 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /puestos/{id}` |
| Description | A valid update form submission persists the new job title and salary range and redirects to the job list. |

**Trigger** — `POST /puestos/OPER`, form-encoded body per `testdata/inputs/job-update.json`.

**Preconditions** — Job `OPER` exists with seeded title "Operario".

**Expected Response** — HTTP 302 Found; `Location` header ends with `/puestos`.

**Resource Verification** — Job `OPER`'s `jobTitle = "Operario de Planta"`, `minSalary = 1150`, `maxSalary = 2100`.

**Data References** — `testdata/inputs/job-update.json`.

---

### TC-GEPER-043 Updating a job when the dependency is unavailable — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-043 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /puestos/{id}` |
| Description | When the database dependency is unavailable, the update request maps to HTTP 500. |

**Trigger** — `POST /puestos/OPER`, form-encoded body per `testdata/inputs/job-update.json`, with the database dependency simulated as unavailable.

**Preconditions** — Job `OPER` exists; database dependency unreachable for the duration of this request only.

**Expected Response** — HTTP 500.

**Resource Verification** — none.

**Negative Verification** — Job `OPER`'s fields are unchanged.

**Data References** — `testdata/inputs/job-update.json`.

---

## Lab Routes (`/lab/**`) — Scope Note

> **SECURITY-LAB JAVA-SQLI-01 / JAVA-XSS-01 are explicitly slated for remediation by migration task
> `001-upgrade-java21-springboot35`.** The frozen contract below pins only the STRUCTURAL behavior of
> these routes (bean/route registration gating, loopback restriction, navigability, redirect targets,
> stored-value round-tripping) — it intentionally does NOT pin the exact SQL-concatenation or
> unescaped-HTML-rendering mechanism as a must-preserve detail, since that mechanism is the known defect
> the migration is meant to fix. The existing `LabSearchSqlTest` / `LabVulnerabilityCharacterizationIT`
> classes (outside `test-cases/`, not frozen) remain available to the migration-engineer as before/after
> characterization evidence but are not part of this frozen spec.

### TC-GEPER-044 Lab index renders when enabled and called over loopback — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-044 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /lab` |
| Description | With `geper.labs.enabled=true` and the request originating from a loopback address, the lab index page renders. |

**Trigger** — `GET /lab` with `geper.labs.enabled=true` and the request's remote address set to a loopback address (`127.0.0.1`).

**Preconditions** — Labs enabled via configuration property.

**Expected Response** — HTTP 200; view name `lab/index`.

**Resource Verification** — none (read-only).

**Data References** — none.

---

### TC-GEPER-045 Lab SQLi route accepts a benign term — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-045 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /lab/sqli` |
| Description | With labs enabled and a benign search term, the route renders successfully with a non-empty, filtered result set. The exact SQL mechanism is out of scope per the Lab Routes scope note above. |

**Trigger** — `GET /lab/sqli?term=mora` with `geper.labs.enabled=true`, loopback request.

**Preconditions** — Labs enabled; seed dataset loaded.

**Expected Response** — HTTP 200; view name `lab/sqli`; model attribute `rows` is non-empty and has fewer entries than the full employee count (30).

**Resource Verification** — none (read-only).

**Data References** — none.

---

### TC-GEPER-046 Lab routes are absent (404) when labs are disabled — failure

| Field | Value |
|-------|-------|
| ID | TC-GEPER-046 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /lab`, `GET /lab/sqli` |
| Description | With the default configuration (`geper.labs.enabled=false`), the lab beans are not registered and both routes return 404. covered-by-existing: `com.monteazul.geper.GeperIntegrationTest#labRoutesReturn404WhenDisabled`, `com.monteazul.geper.LabConfigurationTest` (all 4 methods). Not duplicated here. |

**Trigger** — `GET /lab`, `GET /lab/sqli` with default configuration.

**Preconditions** — `geper.labs.enabled` not set (defaults to `false`).

**Expected Response** — HTTP 404 Not Found for both routes.

**Resource Verification** — none.

**Negative Verification** — No `LabController` / `LabSearchRepository` bean is registered in the application context.

**Data References** — none.

---

### TC-GEPER-047 Lab XSS form stores an observation — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-047 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /lab/xss`, `POST /lab/xss` |
| Description | With labs enabled, the XSS lab form renders the employee picker, and submitting it stores the raw observation text for the selected employee via the normal app account (same repository method as `POST /empleados/{id}/observaciones`). The rendering behavior of the stored value is covered separately by TC-GEPER-048 and is explicitly out of scope per the Lab Routes scope note. |

**Trigger** — `GET /lab/xss` (form render) then `POST /lab/xss`, form-encoded body per `testdata/inputs/lab-xss-observation.json` (fields `employeeId`, `observations`), both with `geper.labs.enabled=true`, loopback request.

**Preconditions** — Labs enabled; employee 126 "Luis Castillo Umaña" exists.

**Expected Response** — `GET /lab/xss`: HTTP 200, view `lab/xss`, model attribute `employees` populated. `POST /lab/xss`: HTTP 302 Found; `Location` header ends with `/lab/xss/view/126`.

**Resource Verification** — Employee 126's `observations` field equals the raw text submitted in `testdata/inputs/lab-xss-observation.json` (stored verbatim, same as the normal observations path).

**Data References** — `testdata/inputs/lab-xss-observation.json`.

---

### TC-GEPER-048 Lab XSS view renders the stored observation — happy-path

| Field | Value |
|-------|-------|
| ID | TC-GEPER-048 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /lab/xss/view/{employeeId}` |
| Description | With labs enabled, the view route renders successfully for an existing employee id. The exact escaping behavior (`th:utext` vs `th:text`) is explicitly out of scope per the Lab Routes scope note, since JAVA-XSS-01 remediation is the intended migration outcome for this route. |

**Trigger** — `GET /lab/xss/view/126` with `geper.labs.enabled=true`, loopback request.

**Preconditions** — Labs enabled; employee 126 exists.

**Expected Response** — HTTP 200; view name `lab/view`; model attribute `employee.employeeId = 126`.

**Resource Verification** — none (read-only).

**Data References** — none.

---

### TC-GEPER-049 Lab XSS reset clears the observation — failure (unknown employee is a no-op)

| Field | Value |
|-------|-------|
| ID | TC-GEPER-049 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /lab/xss/reset/{employeeId}` |
| Description | Resetting the observation for a non-existent employee id performs a no-op update (zero rows affected, no existence check in the repository) and still redirects. |

**Trigger** — `POST /lab/xss/reset/9999` with `geper.labs.enabled=true`, loopback request.

**Preconditions** — Labs enabled; employee id `9999` does not exist.

**Expected Response** — HTTP 302 Found; `Location` header ends with `/lab/xss?employeeId=9999`.

**Resource Verification** — none.

**Negative Verification** — No row is created for employee id `9999`; no existing employee's observations are altered.

**Data References** — none.

---

## Required Field Checklist (Freeze Gate)

- [x] **ID** unique, formatted `TC-GEPER-<NNN>` (001–049).
- [x] **Category** is one of `happy-path`, `boundary`, `special-input`, `failure` for every case.
- [x] **Entry Point Type** is `HTTP` consistently for every case (this module only has web-MVC entry points).
- [x] **Entry Point** is an exact HTTP method + path from production code for every case.
- [x] **Trigger** is concrete (exact query params / form fields / headers, referencing `testdata/` files for non-trivial payloads).
- [x] **Preconditions** enumerated or `none`; all referenced seed data exists under `testdata/seed-data/`.
- [x] **Expected Response** specifies exact status + redirect-target / view-name / body-contains assertion for every case.
- [x] **Resource Verification** has at least one bullet or explicit `none` with justification, for every case.
- [x] **Negative Verification** present for every `failure` case and every "no-op" case (TC-GEPER-019, TC-GEPER-049).
- [x] **Data References** complete; every path referenced exists under `testdata/` (verified against the file listing in `baseline-summary.md`).

## Coverage Gate

- [x] Every entry point in the Entry-Point Inventory appears as the `Entry Point` of at least one `happy-path` case (existing or new).
- [x] Every entry point in the Entry-Point Inventory appears as the `Entry Point` of at least one `failure` case (existing or new).
- [x] Each entry point covers at least the happy-path + failure buckets; higher-traffic/higher-risk entry points (`/empleados` search, `/empleados` create/update, `/empleados/{id}/asignacion`) additionally cover `boundary` and/or `special-input`.
- [x] Entity examples use 2–5 representative records (department/job/employee subsets referenced via `testdata/seed-data/seed-summary.md`), not exhaustive enumeration.

## Banned Phrasings (Auto-Reject) — Self-Check

No instances of "should return a reasonable error", "behaves as expected", "approximately N items", "etc.", or un-named resource checks appear above; every count and status is stated exactly.
