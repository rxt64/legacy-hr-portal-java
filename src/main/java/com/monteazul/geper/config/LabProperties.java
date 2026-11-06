package com.monteazul.geper.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Binds the vulnerability-lab switches.
 *
 * {@code geper.labs.enabled} is wired in application.yml from the
 * ENABLE_VULNERABILITY_LABS environment variable and DEFAULTS TO FALSE.
 * When false, no lab bean is created and the /lab/** routes are never
 * registered (they return 404). Enabling the labs additionally requires the
 * request to arrive over the loopback interface (enforced by
 * {@link LabLoopbackFilter}); the environment/profile name alone is never
 * sufficient.
 */
@Component
@ConfigurationProperties(prefix = "geper.labs")
public class LabProperties {

    /** Master switch. Default false. Sourced from ENABLE_VULNERABILITY_LABS. */
    private boolean enabled = false;

    /** Read-only datasource used exclusively by SECURITY-LAB JAVA-SQLI-01. */
    private final DataSourceProps datasource = new DataSourceProps();

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }

    public DataSourceProps getDatasource() { return datasource; }

    public static class DataSourceProps {
        private String url;
        private String username;
        private String password;

        public String getUrl() { return url; }
        public void setUrl(String url) { this.url = url; }

        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }

        public String getPassword() { return password; }
        public void setPassword(String password) { this.password = password; }
    }
}
