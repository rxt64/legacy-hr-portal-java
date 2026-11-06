package com.monteazul.geper.repository;

import com.monteazul.geper.domain.Department;
import com.monteazul.geper.domain.Employee;
import com.monteazul.geper.domain.Job;
import com.monteazul.geper.domain.JobHistory;
import org.springframework.jdbc.core.RowMapper;

import java.sql.Date;

/** Shared JDBC row mappers. */
public final class RowMappers {

    private RowMappers() { }

    private static java.time.LocalDate toLocal(Date d) {
        return d == null ? null : d.toLocalDate();
    }

    public static final RowMapper<Department> DEPARTMENT = (rs, i) -> {
        Department d = new Department();
        d.setDepartmentId(rs.getInt("DEPARTMENT_ID"));
        d.setDepartmentName(rs.getString("DEPARTMENT_NAME"));
        d.setLocation(rs.getString("LOCATION"));
        return d;
    };

    public static final RowMapper<Job> JOB = (rs, i) -> {
        Job j = new Job();
        j.setJobId(rs.getString("JOB_ID"));
        j.setJobTitle(rs.getString("JOB_TITLE"));
        j.setMinSalary(rs.getBigDecimal("MIN_SALARY"));
        j.setMaxSalary(rs.getBigDecimal("MAX_SALARY"));
        return j;
    };

    public static final RowMapper<Employee> EMPLOYEE = (rs, i) -> {
        Employee e = new Employee();
        e.setEmployeeId(rs.getInt("EMPLOYEE_ID"));
        e.setFirstName(rs.getString("FIRST_NAME"));
        e.setLastName(rs.getString("LAST_NAME"));
        e.setEmail(rs.getString("EMAIL"));
        e.setHireDate(toLocal(rs.getDate("HIRE_DATE")));
        e.setJobId(rs.getString("JOB_ID"));
        e.setSalary(rs.getBigDecimal("SALARY"));
        int deptId = rs.getInt("DEPARTMENT_ID");
        e.setDepartmentId(rs.wasNull() ? null : deptId);
        e.setAssignmentStartDate(toLocal(rs.getDate("ASSIGNMENT_START_DATE")));
        e.setObservations(rs.getString("OBSERVATIONS"));
        // Optional joined columns (present in list/detail queries).
        try { e.setJobTitle(rs.getString("JOB_TITLE")); } catch (Exception ignore) { }
        try { e.setDepartmentName(rs.getString("DEPARTMENT_NAME")); } catch (Exception ignore) { }
        return e;
    };

    public static final RowMapper<JobHistory> JOB_HISTORY = (rs, i) -> {
        JobHistory h = new JobHistory();
        h.setEmployeeId(rs.getInt("EMPLOYEE_ID"));
        h.setStartDate(toLocal(rs.getDate("START_DATE")));
        h.setEndDate(toLocal(rs.getDate("END_DATE")));
        h.setJobId(rs.getString("JOB_ID"));
        h.setDepartmentId(rs.getInt("DEPARTMENT_ID"));
        try { h.setJobTitle(rs.getString("JOB_TITLE")); } catch (Exception ignore) { }
        try { h.setDepartmentName(rs.getString("DEPARTMENT_NAME")); } catch (Exception ignore) { }
        return h;
    };
}
