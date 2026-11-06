package com.monteazul.geper.repository;

import com.monteazul.geper.domain.Job;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class JobRepository {

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;

    public JobRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
    }

    public List<Job> findAll() {
        return jdbc.query("SELECT JOB_ID, JOB_TITLE, MIN_SALARY, MAX_SALARY FROM JOBS " +
                "ORDER BY JOB_TITLE", RowMappers.JOB);
    }

    public Job findById(String id) {
        List<Job> rows = named.query(
            "SELECT JOB_ID, JOB_TITLE, MIN_SALARY, MAX_SALARY FROM JOBS WHERE JOB_ID = :id",
            new MapSqlParameterSource("id", id), RowMappers.JOB);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public void update(Job j) {
        named.update("UPDATE JOBS SET JOB_TITLE = :t, MIN_SALARY = :min, MAX_SALARY = :max " +
                "WHERE JOB_ID = :id",
            new MapSqlParameterSource().addValue("t", j.getJobTitle())
                .addValue("min", j.getMinSalary()).addValue("max", j.getMaxSalary())
                .addValue("id", j.getJobId()));
    }
}
