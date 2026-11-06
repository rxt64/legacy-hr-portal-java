package com.monteazul.geper;

import com.monteazul.geper.config.LabProperties;
import com.monteazul.geper.lab.LabController;
import com.monteazul.geper.lab.LabSearchRepository;
import com.monteazul.geper.service.EmployeeService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

/**
 * GROUP 2 - verifies the vulnerability-lab routes are DISABLED BY DEFAULT.
 *
 * Fully offline. Asserts that the lab beans (LabSearchRepository,
 * LabController) are registered only when geper.labs.enabled=true, so with
 * the default configuration the /lab/** routes are never created and
 * therefore return 404.
 */
class LabConfigurationTest {

    /** Supplies the collaborators the conditional lab beans depend on. */
    @Configuration
    @EnableConfigurationProperties(LabProperties.class)
    static class Collaborators {
        @Bean
        DataSource labReadOnlyDataSource() { return mock(DataSource.class); }

        @Bean
        EmployeeService employeeService() { return mock(EmployeeService.class); }
    }

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
        // Registering the component classes (not withBean) lets Spring evaluate
        // their class-level @ConditionalOnProperty gate.
        .withUserConfiguration(Collaborators.class, LabSearchRepository.class, LabController.class);

    @Test
    void labBeansAbsentByDefault() {
        runner.run(ctx -> {
            assertThat(ctx).doesNotHaveBean(LabSearchRepository.class);
            assertThat(ctx).doesNotHaveBean(LabController.class);
        });
    }

    @Test
    void labBeansAbsentWhenExplicitlyFalse() {
        runner.withPropertyValues("geper.labs.enabled=false").run(ctx -> {
            assertThat(ctx).doesNotHaveBean(LabSearchRepository.class);
            assertThat(ctx).doesNotHaveBean(LabController.class);
        });
    }

    @Test
    void labBeansPresentOnlyWhenEnabled() {
        runner.withPropertyValues("geper.labs.enabled=true").run(ctx -> {
            assertThat(ctx).hasSingleBean(LabSearchRepository.class);
            assertThat(ctx).hasSingleBean(LabController.class);
        });
    }

    @Test
    void labPropertiesDefaultIsFalse() {
        assertThat(new LabProperties().isEnabled()).isFalse();
    }
}
