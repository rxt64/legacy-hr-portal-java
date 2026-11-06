package com.monteazul.geper;

import com.monteazul.geper.domain.DashboardStats;
import com.monteazul.geper.domain.Employee;
import com.monteazul.geper.domain.JobHistory;
import com.monteazul.geper.repository.EmployeeRepository;
import com.monteazul.geper.service.CatalogService;
import com.monteazul.geper.service.DashboardService;
import com.monteazul.geper.service.EmployeeService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.junit.jupiter.EnabledIf;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GROUP 1 - functional baseline against a REAL local Oracle instance, plus a
 * GROUP 2 web check that /lab routes are 404 while the labs are disabled.
 *
 * Runs only when GEPER_IT_JDBC_URL is set (a local instance seeded with
 * db/accounts + db/schema + db/data). All mutating tests run inside a
 * transaction that is rolled back, so the seeded baseline is preserved.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIf(expression = "#{systemEnvironment['GEPER_IT_JDBC_URL'] != null}", loadContext = true)
class GeperIntegrationTest {

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry reg) {
        reg.add("spring.datasource.url", () -> System.getenv("GEPER_IT_JDBC_URL"));
        reg.add("spring.datasource.username", () -> envOr("GEPER_IT_JDBC_USER", "GEPER_APP"));
        reg.add("spring.datasource.password", () -> System.getenv("GEPER_IT_JDBC_PASSWORD"));
        // Labs stay DISABLED here; this context exercises the normal app only.
        reg.add("geper.labs.enabled", () -> "false");
    }

    private static String envOr(String k, String d) {
        String v = System.getenv(k);
        return v == null ? d : v;
    }

    @Autowired DashboardService dashboard;
    @Autowired EmployeeService employees;
    @Autowired CatalogService catalog;
    @Autowired EmployeeRepository employeeRepository;
    @Autowired MockMvc mockMvc;

    @Test
    void dashboardAggregatesComeFromOracleAndMatchBaseline() {
        DashboardStats s = dashboard.stats();
        assertThat(s.getTotalEmployees()).isEqualTo(30);
        assertThat(s.getTotalDepartments()).isEqualTo(6);
        assertThat(s.getTotalJobs()).isEqualTo(10);
        assertThat(s.getTotalSalary()).isEqualByComparingTo("99800");
    }

    @Test
    void departmentSalarySummaryCoversAllDepartments() {
        assertThat(catalog.salarySummary()).hasSize(6);
    }

    @Test
    void parameterizedSearchFiltersByName() {
        List<Employee> r = employees.search("mora", null, null);
        assertThat(r).isNotEmpty();
        assertThat(r).allMatch(e -> (e.getFirstName() + " " + e.getLastName()).toLowerCase().contains("mora"));
    }

    @Test
    void parameterizedSearchTreatsInjectionTextAsLiteral() {
        // The normal (safe) search binds the term, so the SQLi payload matches
        // no surname and returns zero rows - the opposite of the lab endpoint.
        List<Employee> r = employees.search("x') OR 1=1 --", null, null);
        assertThat(r).isEmpty();
    }

    @Test
    @Transactional
    void createEmployeeUsesSequenceAndPersists() {
        Employee e = new Employee();
        e.setFirstName("Prueba");
        e.setLastName("Sintetica");
        e.setEmail("pruebasint@monteazul.example");
        e.setJobId("OPER");
        e.setSalary(new BigDecimal("1500"));
        e.setDepartmentId(60);
        int id = employees.create(e);
        assertThat(id).isGreaterThanOrEqualTo(1000);
        assertThat(employees.findById(id)).isNotNull();
    }

    @Test
    @Transactional
    void changingAssignmentCreatesJobHistoryViaTrigger() {
        int emp = 126; // OPER / dept 60
        int before = employeeRepository.findHistory(emp).size();
        employeeRepository.changeJob(emp, "SUPERV");
        List<JobHistory> after = employeeRepository.findHistory(emp);
        assertThat(after).hasSize(before + 1);
        // The newest closed assignment records the PRIOR job (OPER).
        assertThat(after.get(after.size() - 1).getJobId()).isEqualTo("OPER");
        // Rolled back by @Transactional, so the baseline is preserved.
    }

    @Test
    @Transactional
    void salaryOnlyChangeDoesNotCreateHistory() {
        int emp = 127;
        int before = employeeRepository.findHistory(emp).size();
        employeeRepository.updateSalary(emp, new BigDecimal("1999"));
        assertThat(employeeRepository.findHistory(emp)).hasSize(before);
    }

    @Test
    void dashboardPageRenders() throws Exception {
        mockMvc.perform(get("/"))
            .andExpect(status().isOk())
            .andExpect(content().string(org.hamcrest.Matchers.containsString("Indicadores")));
    }

    @Test
    void labRoutesReturn404WhenDisabled() throws Exception {
        mockMvc.perform(get("/lab/sqli")).andExpect(status().isNotFound());
        mockMvc.perform(get("/lab")).andExpect(status().isNotFound());
    }
}
