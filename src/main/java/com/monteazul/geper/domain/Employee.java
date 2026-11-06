package com.monteazul.geper.domain;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Positive;
import javax.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * An employee. Also carries joined JOB_TITLE / DEPARTMENT_NAME for display.
 * Mutable bean so Thymeleaf can bind create/edit forms.
 */
public class Employee {
    private Integer employeeId;

    @NotBlank @Size(max = 40)
    private String firstName;

    @NotBlank @Size(max = 40)
    private String lastName;

    @Size(max = 80)
    private String email;

    private LocalDate hireDate;

    @NotBlank
    private String jobId;

    @NotNull @Positive
    private BigDecimal salary;

    private Integer departmentId;

    private LocalDate assignmentStartDate;

    @Size(max = 2000)
    private String observations;

    // Joined, read-only display fields.
    private String jobTitle;
    private String departmentName;

    public Employee() { }

    public Integer getEmployeeId() { return employeeId; }
    public void setEmployeeId(Integer employeeId) { this.employeeId = employeeId; }

    public String getFirstName() { return firstName; }
    public void setFirstName(String firstName) { this.firstName = firstName; }

    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { this.lastName = lastName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public LocalDate getHireDate() { return hireDate; }
    public void setHireDate(LocalDate hireDate) { this.hireDate = hireDate; }

    public String getJobId() { return jobId; }
    public void setJobId(String jobId) { this.jobId = jobId; }

    public BigDecimal getSalary() { return salary; }
    public void setSalary(BigDecimal salary) { this.salary = salary; }

    public Integer getDepartmentId() { return departmentId; }
    public void setDepartmentId(Integer departmentId) { this.departmentId = departmentId; }

    public LocalDate getAssignmentStartDate() { return assignmentStartDate; }
    public void setAssignmentStartDate(LocalDate assignmentStartDate) { this.assignmentStartDate = assignmentStartDate; }

    public String getObservations() { return observations; }
    public void setObservations(String observations) { this.observations = observations; }

    public String getJobTitle() { return jobTitle; }
    public void setJobTitle(String jobTitle) { this.jobTitle = jobTitle; }

    public String getDepartmentName() { return departmentName; }
    public void setDepartmentName(String departmentName) { this.departmentName = departmentName; }

    public String getFullName() {
        return (firstName == null ? "" : firstName) + " " + (lastName == null ? "" : lastName);
    }
}
