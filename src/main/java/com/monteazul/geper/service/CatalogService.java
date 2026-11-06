package com.monteazul.geper.service;

import com.monteazul.geper.domain.Department;
import com.monteazul.geper.domain.Job;
import com.monteazul.geper.repository.DepartmentRepository;
import com.monteazul.geper.repository.JobRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class CatalogService {

    private final DepartmentRepository departments;
    private final JobRepository jobs;

    public CatalogService(DepartmentRepository departments, JobRepository jobs) {
        this.departments = departments;
        this.jobs = jobs;
    }

    public List<Department> departments() { return departments.findAll(); }
    public Department department(int id) { return departments.findById(id); }
    public List<Department> salarySummary() { return departments.salarySummary(); }

    @Transactional
    public int createDepartment(Department d) { return departments.insert(d); }

    @Transactional
    public void updateDepartment(Department d) { departments.update(d); }

    public List<Job> jobs() { return jobs.findAll(); }
    public Job job(String id) { return jobs.findById(id); }

    @Transactional
    public void updateJob(Job j) { jobs.update(j); }
}
