package com.monteazul.geper;

import com.monteazul.geper.repository.EmployeeRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.junit.jupiter.EnabledIf;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Regression test for the two-datasource wiring.
 *
 * When the labs are ENABLED a second (read-only, GEPER_LABRO) DataSource bean
 * exists. This test proves the application repositories still use the PRIMARY
 * GEPER_APP datasource: GEPER_LABRO has no SELECT on JOB_HISTORY, so if the
 * primary were mis-wired to the lab datasource, findHistory would fail with
 * ORA-00942. It must return the seeded history rows instead.
 *
 * Runs only with GEPER_LAB_IT=1 and a seeded local Oracle.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIf(expression = "#{systemEnvironment['GEPER_LAB_IT'] == '1'}", loadContext = true)
class LabsEnabledMainDatasourceIT {

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry reg) {
        reg.add("geper.labs.enabled", () -> "true");
        reg.add("spring.datasource.url", () -> System.getenv("GEPER_IT_JDBC_URL"));
        reg.add("spring.datasource.username", () -> env("GEPER_IT_JDBC_USER", "GEPER_APP"));
        reg.add("spring.datasource.password", () -> System.getenv("GEPER_IT_JDBC_PASSWORD"));
        reg.add("geper.labs.datasource.url", () -> System.getenv("GEPER_IT_JDBC_URL"));
        reg.add("geper.labs.datasource.username", () -> env("GEPER_LAB_JDBC_USER", "GEPER_LABRO"));
        reg.add("geper.labs.datasource.password", () -> System.getenv("GEPER_LAB_JDBC_PASSWORD"));
    }

    private static String env(String k, String d) {
        String v = System.getenv(k);
        return v == null ? d : v;
    }

    @Autowired EmployeeRepository employees;
    @Autowired MockMvc mockMvc;

    @Test
    void mainRepositoryUsesAppDatasourceNotLabDatasource() {
        // Employee 101 has seeded job history. GEPER_LABRO cannot read
        // JOB_HISTORY; GEPER_APP can. A non-empty result proves the primary
        // datasource is GEPER_APP even with the labs enabled.
        assertThat(employees.findHistory(101)).isNotEmpty();
    }

    @Test
    void sqliLabViewRendersResultsWithoutTemplateError() throws Exception {
        // A term that returns rows exercises the results loop; the view must
        // render (200) rather than fail template evaluation on the row maps.
        mockMvc.perform(get("/lab/sqli").param("term", "mora").with(req -> { req.setRemoteAddr("127.0.0.1"); return req; }))
            .andExpect(status().isOk())
            .andExpect(content().string(org.hamcrest.Matchers.containsString("Resultados")));
    }
}
