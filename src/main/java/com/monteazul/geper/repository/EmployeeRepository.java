package com.monteazul.geper.repository;

import com.monteazul.geper.domain.Employee;
import com.monteazul.geper.domain.JobHistory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.sql.Date;
import java.util.ArrayList;
import java.util.List;

/**
 * Data access for employees. Every statement here is PARAMETERIZED (bind
 * variables / NamedParameterJdbcTemplate). The deliberately unsafe variant
 * lives only in {@code com.monteazul.geper.lab} and is never used by this
 * class or by any normal screen.
 */
@Repository
public class EmployeeRepository {

    private static final String BASE_SELECT =
        "SELECT e.EMPLOYEE_ID, e.FIRST_NAME, e.LAST_NAME, e.EMAIL, e.HIRE_DATE, " +
        "       e.JOB_ID, e.SALARY, e.DEPARTMENT_ID, e.ASSIGNMENT_START_DATE, e.OBSERVATIONS, " +
        "       j.JOB_TITLE, d.DEPARTMENT_NAME " +
        "FROM EMPLOYEES e " +
        "JOIN JOBS j ON j.JOB_ID = e.JOB_ID " +
        "LEFT JOIN DEPARTMENTS d ON d.DEPARTMENT_ID = e.DEPARTMENT_ID ";

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;

    public EmployeeRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
    }

    public List<Employee> findAll() {
        return jdbc.query(BASE_SELECT + "ORDER BY e.LAST_NAME, e.FIRST_NAME", RowMappers.EMPLOYEE);
    }

    public Employee findById(int id) {
        List<Employee> rows = named.query(
            BASE_SELECT + "WHERE e.EMPLOYEE_ID = :id",
            new MapSqlParameterSource("id", id), RowMappers.EMPLOYEE);
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * Normal personnel search. SAFE: all user input is bound, never
     * concatenated. {@code name} matches first or last name (case-insensitive).
     */
    public List<Employee> search(String name, Integer departmentId, String jobId) {
        StringBuilder sql = new StringBuilder(BASE_SELECT + "WHERE 1 = 1 ");
        MapSqlParameterSource p = new MapSqlParameterSource();
        if (name != null && !name.trim().isEmpty()) {
            sql.append("AND (UPPER(e.FIRST_NAME) LIKE UPPER('%' || :name || '%') " +
                       "OR UPPER(e.LAST_NAME) LIKE UPPER('%' || :name || '%')) ");
            p.addValue("name", name.trim());
        }
        if (departmentId != null) {
            sql.append("AND e.DEPARTMENT_ID = :dept ");
            p.addValue("dept", departmentId);
        }
        if (jobId != null && !jobId.trim().isEmpty()) {
            sql.append("AND e.JOB_ID = :job ");
            p.addValue("job", jobId.trim());
        }
        sql.append("ORDER BY e.LAST_NAME, e.FIRST_NAME");
        return named.query(sql.toString(), p, RowMappers.EMPLOYEE);
    }

    /** Inserts a new employee, taking the id from employees_seq (PostgreSQL sequence). */
    public int insert(Employee e) {
        Integer id = jdbc.queryForObject("SELECT nextval('employees_seq')", Integer.class);
        named.update(
            "INSERT INTO EMPLOYEES (EMPLOYEE_ID, FIRST_NAME, LAST_NAME, EMAIL, HIRE_DATE, " +
            "JOB_ID, SALARY, DEPARTMENT_ID, ASSIGNMENT_START_DATE, OBSERVATIONS) " +
            "VALUES (:id, :fn, :ln, :em, :hd, :job, :sal, :dept, :hd, :obs)",
            new MapSqlParameterSource()
                .addValue("id", id)
                .addValue("fn", e.getFirstName())
                .addValue("ln", e.getLastName())
                .addValue("em", emptyToNull(e.getEmail()))
                .addValue("hd", e.getHireDate() == null ? new Date(System.currentTimeMillis())
                                                         : Date.valueOf(e.getHireDate()))
                .addValue("job", e.getJobId())
                .addValue("sal", e.getSalary())
                .addValue("dept", e.getDepartmentId())
                .addValue("obs", emptyToNull(e.getObservations())));
        return id;
    }

    /**
     * Full update of the editable identity/compensation fields. Because this
     * may change JOB_ID or DEPARTMENT_ID, the UPDATE_JOB_HISTORY trigger may
     * fire and record the prior assignment.
     */
    public void update(Employee e) {
        named.update(
            "UPDATE EMPLOYEES SET FIRST_NAME = :fn, LAST_NAME = :ln, EMAIL = :em, " +
            "JOB_ID = :job, SALARY = :sal, DEPARTMENT_ID = :dept, OBSERVATIONS = :obs " +
            "WHERE EMPLOYEE_ID = :id",
            new MapSqlParameterSource()
                .addValue("fn", e.getFirstName())
                .addValue("ln", e.getLastName())
                .addValue("em", emptyToNull(e.getEmail()))
                .addValue("job", e.getJobId())
                .addValue("sal", e.getSalary())
                .addValue("dept", e.getDepartmentId())
                .addValue("obs", emptyToNull(e.getObservations()))
                .addValue("id", e.getEmployeeId()));
    }

    /** Salary-only change. Does NOT create job history (trigger is job/dept only). */
    public void updateSalary(int id, BigDecimal salary) {
        named.update("UPDATE EMPLOYEES SET SALARY = :sal WHERE EMPLOYEE_ID = :id",
            new MapSqlParameterSource().addValue("sal", salary).addValue("id", id));
    }

    /** Job change. Fires UPDATE_JOB_HISTORY, closing the prior assignment. */
    public void changeJob(int id, String jobId) {
        named.update("UPDATE EMPLOYEES SET JOB_ID = :job WHERE EMPLOYEE_ID = :id",
            new MapSqlParameterSource().addValue("job", jobId).addValue("id", id));
    }

    /** Department change. Fires UPDATE_JOB_HISTORY, closing the prior assignment. */
    public void changeDepartment(int id, Integer departmentId) {
        named.update("UPDATE EMPLOYEES SET DEPARTMENT_ID = :dept WHERE EMPLOYEE_ID = :id",
            new MapSqlParameterSource().addValue("dept", departmentId).addValue("id", id));
    }

    /** Observations-only update used by the normal employee card (bound, safe). */
    public void updateObservations(int id, String observations) {
        named.update("UPDATE EMPLOYEES SET OBSERVATIONS = :obs WHERE EMPLOYEE_ID = :id",
            new MapSqlParameterSource().addValue("obs", emptyToNull(observations)).addValue("id", id));
    }

    public List<JobHistory> findHistory(int employeeId) {
        return named.query(
            "SELECT h.EMPLOYEE_ID, h.START_DATE, h.END_DATE, h.JOB_ID, h.DEPARTMENT_ID, " +
            "       j.JOB_TITLE, d.DEPARTMENT_NAME " +
            "FROM JOB_HISTORY h " +
            "JOIN JOBS j ON j.JOB_ID = h.JOB_ID " +
            "LEFT JOIN DEPARTMENTS d ON d.DEPARTMENT_ID = h.DEPARTMENT_ID " +
            "WHERE h.EMPLOYEE_ID = :id ORDER BY h.START_DATE",
            new MapSqlParameterSource("id", employeeId), RowMappers.JOB_HISTORY);
    }

    public List<Employee> findByDepartment(int departmentId) {
        return named.query(BASE_SELECT + "WHERE e.DEPARTMENT_ID = :dept ORDER BY e.LAST_NAME",
            new MapSqlParameterSource("dept", departmentId), RowMappers.EMPLOYEE);
    }

    private static String emptyToNull(String s) {
        return (s == null || s.trim().isEmpty()) ? null : s;
    }

    /** Small helper for the lab reset endpoint: list ids with current observations. */
    public List<Integer> allIds() {
        List<Integer> ids = new ArrayList<>();
        ids.addAll(jdbc.queryForList("SELECT EMPLOYEE_ID FROM EMPLOYEES ORDER BY EMPLOYEE_ID", Integer.class));
        return ids;
    }
}
