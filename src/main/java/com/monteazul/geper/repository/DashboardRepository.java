package com.monteazul.geper.repository;

import com.monteazul.geper.domain.DashboardStats;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Dashboard indicators. Every number is read from Oracle via aggregate
 * queries; nothing is hard-coded in the application tier.
 */
@Repository
public class DashboardRepository {

    private final JdbcTemplate jdbc;

    public DashboardRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public DashboardStats load() {
        DashboardStats s = new DashboardStats();
        s.setTotalEmployees(jdbc.queryForObject("SELECT COUNT(*) FROM EMPLOYEES", Integer.class));
        s.setTotalDepartments(jdbc.queryForObject("SELECT COUNT(*) FROM DEPARTMENTS", Integer.class));
        s.setTotalJobs(jdbc.queryForObject("SELECT COUNT(*) FROM JOBS", Integer.class));
        s.setTotalSalary(jdbc.queryForObject("SELECT NVL(SUM(SALARY),0) FROM EMPLOYEES", java.math.BigDecimal.class));
        s.setAvgSalary(jdbc.queryForObject("SELECT NVL(ROUND(AVG(SALARY),2),0) FROM EMPLOYEES", java.math.BigDecimal.class));
        return s;
    }
}
