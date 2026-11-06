package com.monteazul.geper;

import com.monteazul.geper.config.LabLoopbackFilter;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import jakarta.servlet.Filter;
import jakarta.servlet.http.HttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * GROUP 2 - verifies the loopback gate: even if the labs were enabled, a
 * non-loopback request to /lab/** is answered with 404 and never reaches a
 * handler. Offline.
 */
class LabLoopbackFilterTest {

    private Filter filter() {
        return new LabLoopbackFilter().labLoopbackGate().getFilter();
    }

    @Test
    void nonLoopbackLabRequestGets404() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/lab/sqli");
        req.setRemoteAddr("10.0.0.5");
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter().doFilter(req, res, chain);

        assertThat(res.getStatus()).isEqualTo(HttpServletResponse.SC_NOT_FOUND);
        // Chain must NOT have been invoked (no handler reached).
        assertThat(chain.getRequest()).isNull();
    }

    @Test
    void loopbackLabRequestPassesThrough() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/lab/sqli");
        req.setRemoteAddr("127.0.0.1");
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter().doFilter(req, res, chain);

        assertThat(res.getStatus()).isEqualTo(HttpServletResponse.SC_OK);
        assertThat(chain.getRequest()).isNotNull();
    }

    @Test
    void nonLabPathIsIgnoredByTheGate() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/empleados");
        req.setRemoteAddr("10.0.0.5");
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter().doFilter(req, res, chain);

        // The gate only guards /lab/*, so this request passes through.
        assertThat(chain.getRequest()).isNotNull();
    }
}
