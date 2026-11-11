package com.monteazul.geper.lab;

import com.monteazul.geper.config.LabProperties;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;

/**
 * Builds the SEPARATE, READ-ONLY datasource used only by the SQL-injection
 * lab (SECURITY-LAB JAVA-SQLI-01). It connects as GEPER_LABRO, an account
 * granted nothing but SELECT on the synthetic personnel tables, so the
 * exercise can only read synthetic data and cannot modify anything.
 *
 * This bean exists only when geper.labs.enabled=true. With the labs off it
 * is never created and the lab routes are never registered.
 */
@Configuration
public class LabDataSourceConfig {

    @Primary
    @Bean(name = "dataSource")
    public DataSource dataSource(DataSourceProperties properties) {
        HikariConfig cfg = new HikariConfig();
        cfg.setJdbcUrl(properties.determineUrl());
        cfg.setUsername(properties.determineUsername());
        cfg.setPassword(properties.determinePassword());
        cfg.setMaximumPoolSize(5);
        cfg.setPoolName("geper-app");
        cfg.setConnectionInitSql("ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER");
        return new HikariDataSource(cfg);
    }

    @Bean(name = "labReadOnlyDataSource")
    @ConditionalOnProperty(prefix = "geper.labs", name = "enabled", havingValue = "true")
    public DataSource labReadOnlyDataSource(LabProperties labs) {
        LabProperties.DataSourceProps p = labs.getDatasource();
        HikariConfig cfg = new HikariConfig();
        cfg.setJdbcUrl(p.getUrl());
        cfg.setUsername(p.getUsername());
        cfg.setPassword(p.getPassword());
        cfg.setMaximumPoolSize(2);
        cfg.setPoolName("geper-lab-ro");
        cfg.setReadOnly(true);
        // Resolve unqualified object names to the owning schema; the account
        // still holds only the SELECT grants issued in 02_schema.sql.
        cfg.setConnectionInitSql("ALTER SESSION SET CURRENT_SCHEMA = GEPER_OWNER");
        return new HikariDataSource(cfg);
    }
}
