---
name: geper-java8-to-java21-springboot35
description: Upgrade Java 8 and Spring Boot 2.7 application to Java 21 and Spring Boot 3.5 (Jakarta EE 10), remediate JAVA-SQLI-01 (PreparedStatement) and JAVA-XSS-01 (Thymeleaf th:text escaping), and containerize for Azure Container Apps
---

# GEPER Modernization Skill: Java 8 / Spring Boot 2.7 to Java 21 / Spring Boot 3.5

## Overview

This project-level skill guides the GitHub Copilot modernization agent (`modernize`) when upgrading **GEPER** (`com.monteazul:geper`) from **Java 8** and **Spring Boot 2.7.18** (`javax.*`) to **Java 21** and **Spring Boot 3.5.x** (`jakarta.*`), replacing the Oracle JDBC driver with the PostgreSQL JDBC driver (`org.postgresql:postgresql`), remediating `JAVA-SQLI-01` and `JAVA-XSS-01`, and containerizing for **Azure Container Apps**.

## Steps

1. **Upgrade `pom.xml` to Java 21 and Spring Boot 3.5**:
   - Update `spring-boot-starter-parent` from `2.7.18` to `3.5.0` (or latest `3.5.x`).
   - Set `<java.version>21</java.version>`, `<maven.compiler.source>21</maven.compiler.source>`, and `<maven.compiler.target>21</maven.compiler.target>`.
   - Replace `com.oracle.database.jdbc:ojdbc8` with `org.postgresql:postgresql`.

2. **Migrate `javax.*` Imports to `jakarta.*` (Jakarta EE 10)**:
   - Update `javax.servlet.*` in `LabLoopbackFilter.java` and `LabLoopbackFilterTest.java` to `jakarta.servlet.*`.
   - Update `javax.validation.*` in `Employee.java`, `Department.java`, `Job.java`, `EmployeeController.java`, `DepartmentController.java`, and `JobController.java` to `jakarta.validation.*`.

3. **Remediate Security Vulnerabilities (`JAVA-SQLI-01` and `JAVA-XSS-01`)**:
   - **`JAVA-SQLI-01` (`LabSearchRepository.java`)**: Replace raw `Statement.executeQuery` and string concatenation with `PreparedStatement` using a bound `?` parameter (`WHERE UPPER(e.LAST_NAME) LIKE UPPER(?)`).
   - **`JAVA-XSS-01` (`templates/lab/view.html`)**: Replace unescaped `th:utext="${employee.observations}"` with contextually escaped `th:text="${employee.observations}"`.

4. **Containerize for Azure Container Apps**:
   - Create a multi-stage `Dockerfile` using `eclipse-temurin:21-jdk-alpine` (build) and `eclipse-temurin:21-jre-alpine` (runtime) running as non-root user `geper` on port `8080`.

## Sample Code

### Remediated `LabSearchRepository` (`JAVA-SQLI-01`)

```java
public List<Map<String, Object>> safeSearch(String term) {
    String sql = "SELECT e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME, j.JOB_TITLE, d.DEPARTMENT_NAME "
               + "FROM EMPLOYEES e "
               + "JOIN JOBS j ON j.JOB_ID = e.JOB_ID "
               + "LEFT JOIN DEPARTMENTS d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID "
               + "WHERE UPPER(e.LAST_NAME) LIKE UPPER(?) "
               + "ORDER BY e.LAST_NAME";
    List<Map<String, Object>> out = new ArrayList<>();
    try (Connection c = labDataSource.getConnection();
         PreparedStatement ps = c.prepareStatement(sql)) {
        ps.setString(1, "%" + (term == null ? "" : term.trim()) + "%");
        try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("employeeId", rs.getInt("EMPLOYEE_ID"));
                row.put("firstName", rs.getString("FIRST_NAME"));
                row.put("lastName", rs.getString("LAST_NAME"));
                row.put("jobTitle", rs.getString("JOB_TITLE"));
                row.put("departmentName", rs.getString("DEPARTMENT_NAME"));
                out.add(row);
            }
        }
    } catch (Exception ex) {
        Map<String, Object> err = new LinkedHashMap<>();
        err.put("error", ex.getMessage());
        out.add(err);
    }
    return out;
}
```

## Verification Checks

- `mvn clean test package` succeeds on JDK 21 with 0 errors.
- All unit and integration tests pass against PostgreSQL (`GeperIntegrationTest`).
