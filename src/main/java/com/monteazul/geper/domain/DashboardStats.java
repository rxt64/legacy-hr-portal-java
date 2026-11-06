package com.monteazul.geper.domain;

import java.math.BigDecimal;

/** Aggregate indicators for the dashboard. Every value is computed in PostgreSQL. */
public class DashboardStats {
    private int totalEmployees;
    private int totalDepartments;
    private int totalJobs;
    private BigDecimal totalSalary;
    private BigDecimal avgSalary;

    public int getTotalEmployees() { return totalEmployees; }
    public void setTotalEmployees(int totalEmployees) { this.totalEmployees = totalEmployees; }

    public int getTotalDepartments() { return totalDepartments; }
    public void setTotalDepartments(int totalDepartments) { this.totalDepartments = totalDepartments; }

    public int getTotalJobs() { return totalJobs; }
    public void setTotalJobs(int totalJobs) { this.totalJobs = totalJobs; }

    public BigDecimal getTotalSalary() { return totalSalary; }
    public void setTotalSalary(BigDecimal totalSalary) { this.totalSalary = totalSalary; }

    public BigDecimal getAvgSalary() { return avgSalary; }
    public void setAvgSalary(BigDecimal avgSalary) { this.avgSalary = avgSalary; }
}
