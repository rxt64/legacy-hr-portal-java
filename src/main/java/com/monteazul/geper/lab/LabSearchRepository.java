package com.monteazul.geper.lab;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * SECURITY-LAB: JAVA-SQLI-01 — vulnerabilidad intencional para demostracion local.
 *
 * Deliberately vulnerable personnel search. The user-controlled {@code term}
 * is concatenated directly into a SQL string and executed with a plain
 * {@link Statement}. This is the textbook SQL-injection anti-pattern and is
 * the artifact a modernization/security agent is expected to find.
 *
 * Scope of the exercise (see docs/security-labs.md):
 *   - Runs only against the read-only GEPER_LABRO datasource (SELECT only on
 *     synthetic data), so injection can only broaden/alter the SELECT filter.
 *   - No data modification, no stored procedures, no multi-statement batch.
 *
 * The future fix is to use a PreparedStatement with a bind variable (as the
 * normal EmployeeRepository.search already does). DO NOT "fix" this method in
 * place; it is the before-state for the lab.
 */
@Repository
@ConditionalOnProperty(prefix = "geper.labs", name = "enabled", havingValue = "true")
public class LabSearchRepository {

    private final DataSource labDataSource;

    public LabSearchRepository(@Qualifier("labReadOnlyDataSource") DataSource labDataSource) {
        this.labDataSource = labDataSource;
    }

    /**
     * The raw SQL that will be executed, exposed so the lab page can show the
     * learner exactly what reached the database.
     */
    public String buildSql(String term) {
        // SECURITY-LAB JAVA-SQLI-01: user input concatenated straight into SQL.
        return "SELECT e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME, j.JOB_TITLE, d.DEPARTMENT_NAME "
             + "FROM EMPLOYEES e "
             + "JOIN JOBS j ON j.JOB_ID = e.JOB_ID "
             + "LEFT JOIN DEPARTMENTS d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID "
             + "WHERE UPPER(e.LAST_NAME) LIKE UPPER('%" + term + "%') "
             + "ORDER BY e.LAST_NAME";
    }

    public List<Map<String, Object>> vulnerableSearch(String term) {
        String sql = buildSql(term);
        List<Map<String, Object>> out = new ArrayList<>();
        // SECURITY-LAB JAVA-SQLI-01: Statement.executeQuery on concatenated SQL.
        try (Connection c = labDataSource.getConnection();
             Statement st = c.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            while (rs.next()) {
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("employeeId", rs.getInt("EMPLOYEE_ID"));
                row.put("firstName", rs.getString("FIRST_NAME"));
                row.put("lastName", rs.getString("LAST_NAME"));
                row.put("jobTitle", rs.getString("JOB_TITLE"));
                row.put("departmentName", rs.getString("DEPARTMENT_NAME"));
                out.add(row);
            }
        } catch (Exception ex) {
            // Surface the DB error text to the learner; the read-only account
            // bounds the blast radius.
            Map<String, Object> err = new LinkedHashMap<>();
            err.put("error", ex.getMessage());
            out.add(err);
        }
        return out;
    }
}
