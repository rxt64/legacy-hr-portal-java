# Modernization Summary: 001-upgrade-java21-springboot35

- **finalStatus**: success

## successCriteriaStatus
- passBuild: true
- generateNewUnitTests: false
- passUnitTests: true

## Summary

Upgraded GEPER from Java 8 / Spring Boot 2.7.18 to Java 21 / Spring Boot 3.5.0 and
migrated `javax.*` usages to `jakarta.*` (Jakarta EE 10):

- `pom.xml`: `spring-boot-starter-parent` bumped to `3.5.0`; `java.version`,
  `maven.compiler.source`, `maven.compiler.target` set to `21`.
- `javax.servlet.*` → `jakarta.servlet.*` in `LabLoopbackFilter.java` and
  `LabLoopbackFilterTest.java`.
- `javax.validation.*` → `jakarta.validation.*` in `Employee.java` and
  `EmployeeController.java`.
- `javax.sql.DataSource` imports were left unchanged (JDBC `javax.sql` is not
  part of the Jakarta EE namespace migration).

Remediated the two targeted security findings:

- **JAVA-SQLI-01** (`LabSearchRepository.java`): replaced the raw
  `Statement.executeQuery` over a concatenated SQL string with a
  `PreparedStatement` using a bound `?` parameter
  (`WHERE UPPER(e.LAST_NAME) LIKE UPPER(?)`); `buildSql()` now returns the
  parameterized template instead of embedding the user-supplied term.
  Updated the accompanying offline characterization test
  (`LabSearchSqlTest`) and the `lab/sqli.html` lab page copy to reflect the
  remediated, parameterized behavior (per `test-cases.md`, this
  characterization test was explicitly called out as not a must-preserve
  contract).
- **JAVA-XSS-01** (`templates/lab/view.html`): replaced the unescaped
  `th:utext="${employee.observations}"` with contextually-escaped
  `th:text="${employee.observations}"`. Updated related comments in
  `LabController.java` and the lab page copy for consistency.

No changes were made to REST/web contracts, endpoint paths, or request/response
shapes; existing application behavior (routes, templates structure, DB
connectivity, Oracle JDBC driver) was preserved outside of the above
remediations, per the task's scope (DB migration/containerization are out of
scope for this task).

## Verification

- `mvn clean package` (equivalent, via the Java upgrade build tool) succeeded
  on JDK 21 with 0 build errors.
- Full test suite (via the Java upgrade test tool) passed with 0
  failures/errors.
- Verified no remaining `javax.servlet`/`javax.validation` imports and no
  remaining `th:utext` usages in the codebase.
