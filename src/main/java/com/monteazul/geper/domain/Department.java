package com.monteazul.geper.domain;

import java.math.BigDecimal;

/** A department. DEPARTMENT_ID is a PostgreSQL INTEGER fed by departments_seq. */
public class Department {
    private Integer departmentId;
    private String departmentName;
    private String location;

    // Populated only by the salary-summary query.
    private Integer headcount;
    private BigDecimal totalSalary;
    private BigDecimal avgSalary;

    public Department() { }

    public Integer getDepartmentId() { return departmentId; }
    public void setDepartmentId(Integer departmentId) { this.departmentId = departmentId; }

    public String getDepartmentName() { return departmentName; }
    public void setDepartmentName(String departmentName) { this.departmentName = departmentName; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public Integer getHeadcount() { return headcount; }
    public void setHeadcount(Integer headcount) { this.headcount = headcount; }

    public BigDecimal getTotalSalary() { return totalSalary; }
    public void setTotalSalary(BigDecimal totalSalary) { this.totalSalary = totalSalary; }

    public BigDecimal getAvgSalary() { return avgSalary; }
    public void setAvgSalary(BigDecimal avgSalary) { this.avgSalary = avgSalary; }
}
