package com.monteazul.geper.lab;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * JAVA-SQLI-01 remediated: parameterized personnel search.
 *
 * The user-controlled {@code term} is bound as a {@code PreparedStatement}
 * parameter instead of being concatenated into the SQL text, eliminating the
 * SQL-injection vector that previously existed here.
 *
 * Scope of the exercise (see docs/security-labs.md):
 *   - Runs only against the read-only GEPER_LABRO datasource (SELECT only on
 *     synthetic data).
 *   - No data modification, no stored procedures, no multi-statement batch.
 */
@Repository
@ConditionalOnProperty(prefix = "geper.labs", name = "enabled", havingValue = "true")
public class LabSearchRepository {

    private final DataSource labDataSource;

    public LabSearchRepository(@Qualifier("labReadOnlyDataSource") DataSource labDataSource) {
        this.labDataSource = labDataSource;
    }

    /**
     * The parameterized SQL template that will be executed, exposed so the
     * lab page can show the learner exactly what statement reaches the
     * database (the actual value is bound separately, never concatenated).
     */
    public String buildSql(String term) {
        // JAVA-SQLI-01 remediated: template uses a bind variable, not concatenated input.
        return "SELECT e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME, j.JOB_TITLE, d.DEPARTMENT_NAME "
             + "FROM EMPLOYEES e "
             + "JOIN JOBS j ON j.JOB_ID = e.JOB_ID "
             + "LEFT JOIN DEPARTMENTS d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID "
             + "WHERE UPPER(e.LAST_NAME) LIKE UPPER(?) "
             + "ORDER BY e.LAST_NAME";
    }

    public List<Map<String, Object>> vulnerableSearch(String term) {
        String sql = buildSql(term);
        List<Map<String, Object>> out = new ArrayList<>();
        // JAVA-SQLI-01 remediated: PreparedStatement with a bound parameter.
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
            // Surface the DB error text to the learner; the read-only account
            // bounds the blast radius.
            Map<String, Object> err = new LinkedHashMap<>();
            err.put("error", ex.getMessage());
            out.add(err);
        }
        return out;
    }
}
