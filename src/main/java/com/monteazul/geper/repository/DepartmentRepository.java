package com.monteazul.geper.repository;

import com.monteazul.geper.domain.Department;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class DepartmentRepository {

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;

    public DepartmentRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
    }

    public List<Department> findAll() {
        return jdbc.query("SELECT DEPARTMENT_ID, DEPARTMENT_NAME, LOCATION FROM DEPARTMENTS " +
                "ORDER BY DEPARTMENT_ID", RowMappers.DEPARTMENT);
    }

    public Department findById(int id) {
        List<Department> rows = named.query(
            "SELECT DEPARTMENT_ID, DEPARTMENT_NAME, LOCATION FROM DEPARTMENTS WHERE DEPARTMENT_ID = :id",
            new MapSqlParameterSource("id", id), RowMappers.DEPARTMENT);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public int insert(Department d) {
        Integer id = jdbc.queryForObject("SELECT nextval('departments_seq')", Integer.class);
        named.update("INSERT INTO DEPARTMENTS (DEPARTMENT_ID, DEPARTMENT_NAME, LOCATION) " +
                "VALUES (:id, :name, :loc)",
            new MapSqlParameterSource().addValue("id", id)
                .addValue("name", d.getDepartmentName())
                .addValue("loc", d.getLocation()));
        return id;
    }

    public void update(Department d) {
        named.update("UPDATE DEPARTMENTS SET DEPARTMENT_NAME = :name, LOCATION = :loc " +
                "WHERE DEPARTMENT_ID = :id",
            new MapSqlParameterSource().addValue("name", d.getDepartmentName())
                .addValue("loc", d.getLocation()).addValue("id", d.getDepartmentId()));
    }

    /**
     * Salary summary per department. Aggregates (headcount, total and average
     * salary) are computed entirely in PostgreSQL; no figure is hard-coded.
     * Uses a LEFT JOIN so empty departments still appear with a zero headcount.
     */
    public List<Department> salarySummary() {
        return jdbc.query(
            "SELECT d.DEPARTMENT_ID, d.DEPARTMENT_NAME, d.LOCATION, " +
            "       COUNT(e.EMPLOYEE_ID) AS HEADCOUNT, " +
            "       COALESCE(SUM(e.SALARY), 0) AS TOTAL_SALARY, " +
            "       COALESCE(ROUND(AVG(e.SALARY), 2), 0) AS AVG_SALARY " +
            "FROM DEPARTMENTS d " +
            "LEFT JOIN EMPLOYEES e ON e.DEPARTMENT_ID = d.DEPARTMENT_ID " +
            "GROUP BY d.DEPARTMENT_ID, d.DEPARTMENT_NAME, d.LOCATION " +
            "ORDER BY TOTAL_SALARY DESC",
            (rs, i) -> {
                Department d = new Department();
                d.setDepartmentId(rs.getInt("DEPARTMENT_ID"));
                d.setDepartmentName(rs.getString("DEPARTMENT_NAME"));
                d.setLocation(rs.getString("LOCATION"));
                d.setHeadcount(rs.getInt("HEADCOUNT"));
                d.setTotalSalary(rs.getBigDecimal("TOTAL_SALARY"));
                d.setAvgSalary(rs.getBigDecimal("AVG_SALARY"));
                return d;
            });
    }
}
