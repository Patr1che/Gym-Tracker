package com.patriche.gymtracker.config;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.ServletException;
import java.io.IOException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RateLimitFilterTest {

    private static final String LOGIN = "/api/v1/auth/login";
    private static final String REGISTER = "/api/v1/auth/register";

    private static RateLimitFilter filter(boolean enabled, int perMinute, int perHour) {
        return new RateLimitFilter(new AppProperties(null, null, null, null,
                new AppProperties.RateLimit(enabled, perMinute, perHour, 1000)));
    }

    /** @return the status, having sent one request from the given address */
    private static MockHttpServletResponse send(RateLimitFilter filter, String path,
                                                String address)
            throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", path);
        request.setRemoteAddr(address);
        MockHttpServletResponse response = new MockHttpServletResponse();
        filter.doFilter(request, response, new MockFilterChain());
        return response;
    }

    @Test
    void spendsTheAllowanceThenRefusesWithARetryAfter() throws Exception {
        RateLimitFilter filter = filter(true, 2, 1000);

        assertThat(send(filter, LOGIN, "1.1.1.1").getStatus()).isEqualTo(200);
        assertThat(send(filter, LOGIN, "1.1.1.1").getStatus()).isEqualTo(200);

        MockHttpServletResponse refused = send(filter, LOGIN, "1.1.1.1");
        assertThat(refused.getStatus()).isEqualTo(429);
        // Never zero - that would invite an immediate retry certain to fail again.
        assertThat(Integer.parseInt(refused.getHeader("Retry-After"))).isPositive();
        assertThat(refused.getContentAsString())
                .contains("\"status\":429")
                .contains("Too many attempts")
                .contains("\"path\":\"" + LOGIN + "\"");
    }

    /**
     * The point of the second bucket. A per-minute cap alone never notices an account
     * farm that registers slowly, which is the abuse that actually costs the free tier.
     */
    @Test
    void registrationsAreCappedPerHourEvenWhenTheMinuteAllowanceIsUntouched()
            throws Exception {
        RateLimitFilter filter = filter(true, 1000, 2);

        assertThat(send(filter, REGISTER, "2.2.2.2").getStatus()).isEqualTo(200);
        assertThat(send(filter, REGISTER, "2.2.2.2").getStatus()).isEqualTo(200);
        assertThat(send(filter, REGISTER, "2.2.2.2").getStatus()).isEqualTo(429);

        // The hourly cap is registration-only; other auth calls still go through.
        assertThat(send(filter, LOGIN, "2.2.2.2").getStatus()).isEqualTo(200);
    }

    @Test
    void oneClientRunningOutDoesNotAffectAnother() throws Exception {
        RateLimitFilter filter = filter(true, 1, 1000);

        assertThat(send(filter, LOGIN, "3.3.3.3").getStatus()).isEqualTo(200);
        assertThat(send(filter, LOGIN, "3.3.3.3").getStatus()).isEqualTo(429);
        assertThat(send(filter, LOGIN, "4.4.4.4").getStatus()).isEqualTo(200);
    }

    /**
     * Only the open auth routes are limited. Everything else already needs a token, and
     * throttling sync would break the app's catch-up after a spell offline - exactly
     * when it has the most to send.
     */
    @Test
    void authenticatedRoutesAreNotLimited() throws Exception {
        RateLimitFilter filter = filter(true, 1, 1);

        for (int i = 0; i < 20; i++) {
            assertThat(send(filter, "/api/v1/workouts", "5.5.5.5").getStatus()).isEqualTo(200);
        }
    }

    @Test
    void disabledLetsEverythingThrough() throws Exception {
        RateLimitFilter filter = filter(false, 1, 1);

        for (int i = 0; i < 20; i++) {
            assertThat(send(filter, REGISTER, "6.6.6.6").getStatus()).isEqualTo(200);
        }
    }
}
