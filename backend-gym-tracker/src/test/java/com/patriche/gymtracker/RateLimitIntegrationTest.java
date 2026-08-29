package com.patriche.gymtracker;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;

/**
 * Proves the limiter is actually wired into the running application, which the filter's
 * own unit test cannot: a filter that works perfectly and was never added to the chain
 * looks identical from there.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "app.jwt.secret=test-secret-that-is-definitely-long-enough-32",
                "spring.jpa.hibernate.ddl-auto=validate",
                "app.rate-limit.enabled=true",
                "app.rate-limit.registrations-per-hour=2",
                // High enough that the hourly cap is unambiguously what refuses the
                // third request, rather than the two limits racing each other.
                "app.rate-limit.auth-per-minute=100"
        })
@Import({TestcontainersConfiguration.class, RecordingMailConfiguration.class})
class RateLimitIntegrationTest {

    @LocalServerPort
    int port;

    private final RestTemplate rest = new RestTemplate(new JdkClientHttpRequestFactory());

    private ResponseEntity<String> register(String email) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        var body = Map.of("name", "Test", "email", email, "password", "secret123");
        try {
            return rest.exchange("http://localhost:" + port + "/api/v1/auth/register",
                    HttpMethod.POST, new HttpEntity<>(body, headers), String.class);
        } catch (HttpStatusCodeException e) {
            return ResponseEntity.status(e.getStatusCode())
                    .headers(e.getResponseHeaders())
                    .body(e.getResponseBodyAsString());
        }
    }

    @Test
    void aThirdRegistrationFromTheSameAddressIsRefused() {
        assertThat(register("limit-one@example.com").getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(register("limit-two@example.com").getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<String> refused = register("limit-three@example.com");
        assertThat(refused.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(refused.getHeaders().getFirst("Retry-After")).isNotNull();
        assertThat(refused.getBody()).contains("Too many attempts");
    }
}
