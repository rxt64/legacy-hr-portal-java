package com.monteazul.geper.service;

import com.monteazul.geper.domain.Employee;
import com.monteazul.geper.domain.JobHistory;
import com.monteazul.geper.repository.EmployeeRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
public class EmployeeService {

    private final EmployeeRepository employees;

    public EmployeeService(EmployeeRepository employees) {
        this.employees = employees;
    }

    public List<Employee> findAll() { return employees.findAll(); }

    public Employee findById(int id) { return employees.findById(id); }

    public List<Employee> search(String name, Integer departmentId, String jobId) {
        return employees.search(name, departmentId, jobId);
    }

    public List<JobHistory> history(int id) { return employees.findHistory(id); }

    @Transactional
    public int create(Employee e) { return employees.insert(e); }

    @Transactional
    public void update(Employee e) { employees.update(e); }

    @Transactional
    public void changeSalary(int id, BigDecimal salary) { employees.updateSalary(id, salary); }

    /**
     * Changing job and/or department runs inside a single transaction, so the
     * JOB_HISTORY row written by the UPDATE_JOB_HISTORY trigger is committed or
     * rolled back atomically with the employee change.
     */
    @Transactional
    public void changeAssignment(int id, String jobId, Integer departmentId) {
        Employee current = employees.findById(id);
        if (current == null) {
            throw new IllegalArgumentException("Empleado inexistente: " + id);
        }
        if (jobId != null && !jobId.equals(current.getJobId())) {
            employees.changeJob(id, jobId);
        }
        boolean deptChanged = (departmentId == null)
            ? current.getDepartmentId() != null
            : !departmentId.equals(current.getDepartmentId());
        if (deptChanged) {
            employees.changeDepartment(id, departmentId);
        }
    }

    @Transactional
    public void updateObservations(int id, String observations) {
        employees.updateObservations(id, observations);
    }
}
