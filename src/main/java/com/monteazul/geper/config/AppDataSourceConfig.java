package com.monteazul.geper.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;

/**
 * Explicit PRIMARY application datasource (least-privilege GEPER_APP).
 *
 * This must be defined explicitly because the vulnerability lab registers a
 * second DataSource bean (labReadOnlyDataSource). Once any DataSource bean
 * exists, Spring Boot's auto-configuration no longer creates the default one,
 * and an unqualified JdbcTemplate could otherwise bind to the read-only lab
 * datasource. Marking this bean @Primary guarantees the application's
 * repositories always use GEPER_APP, while the lab code injects the lab
 * datasource by its @Qualifier.
 */
@Configuration
public class AppDataSourceConfig {

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource")
    public DataSourceProperties dataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource.hikari")
    public DataSource dataSource(DataSourceProperties properties) {
        return properties.initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }
}
