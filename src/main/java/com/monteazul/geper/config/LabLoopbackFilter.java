package com.monteazul.geper.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.net.InetAddress;

/**
 * Defense-in-depth gate for the vulnerability-lab routes.
 *
 * Even when the labs are enabled, any request to {@code /lab/**} that does
 * not originate from the loopback interface is answered with 404 and never
 * reaches a lab handler. This filter is always installed; it is cheap and
 * only inspects the /lab/ prefix. It does NOT by itself enable the labs:
 * the routes exist only when geper.labs.enabled=true.
 */
@Configuration
public class LabLoopbackFilter {

    @Bean
    public FilterRegistrationBean<Filter> labLoopbackGate() {
        FilterRegistrationBean<Filter> reg = new FilterRegistrationBean<>();
        reg.setFilter(new Filter() {
            @Override
            public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
                    throws IOException, ServletException {
                HttpServletRequest http = (HttpServletRequest) request;
                String path = http.getRequestURI();
                if (path != null && path.startsWith("/lab/") && !isLoopback(http)) {
                    ((HttpServletResponse) response).sendError(HttpServletResponse.SC_NOT_FOUND);
                    return;
                }
                chain.doFilter(request, response);
            }
        });
        reg.addUrlPatterns("/lab/*");
        reg.setName("labLoopbackGate");
        reg.setOrder(1);
        return reg;
    }

    private static boolean isLoopback(HttpServletRequest http) {
        try {
            String remote = http.getRemoteAddr();
            if (remote == null) {
                return false;
            }
            // Common loopback literals plus a resolved check.
            if (remote.equals("127.0.0.1") || remote.equals("0:0:0:0:0:0:0:1") || remote.equals("::1")) {
                return true;
            }
            InetAddress addr = InetAddress.getByName(remote);
            return addr.isLoopbackAddress();
        } catch (Exception e) {
            return false;
        }
    }
}
