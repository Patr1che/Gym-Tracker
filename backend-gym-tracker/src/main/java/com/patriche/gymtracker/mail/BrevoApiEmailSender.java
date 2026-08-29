package com.patriche.gymtracker.mail;

import com.patriche.gymtracker.config.AppProperties;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadPoolExecutor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;

/**
 * Sends through Brevo's HTTP API instead of SMTP.
 *
 * <p>This exists because Render blocks outbound traffic to SMTP ports 25, 465 and 587 on
 * free web services, so a mail library that speaks SMTP cannot deliver anything from
 * there however correct its credentials are - the connection simply times out. The HTTP
 * API is ordinary HTTPS on 443, which no host blocks.
 *
 * <p>Note the key is Brevo's API key ({@code xkeysib-...}), a different credential from
 * the SMTP key ({@code xsmtpsib-...}) the relay uses. They are not interchangeable.
 */
class BrevoApiEmailSender implements EmailSender {

    private static final Logger log = LoggerFactory.getLogger(BrevoApiEmailSender.class);

    private static final String ENDPOINT = "https://api.brevo.com/v3/smtp/email";

    private final RestClient http;
    private final AppProperties.Mail config;
    private final ThreadPoolExecutor executor;

    BrevoApiEmailSender(String apiKey, AppProperties.Mail config,
                        ThreadPoolExecutor executor) {
        // Built directly rather than injected: RestClient.Builder is contributed by an
        // autoconfiguration this application does not pull in, and one fixed endpoint
        // needs no shared configuration.
        this.http = RestClient.builder()
                .baseUrl(ENDPOINT)
                .defaultHeader("api-key", apiKey)
                .defaultHeader("accept", MediaType.APPLICATION_JSON_VALUE)
                .build();
        this.config = config;
        this.executor = executor;
    }

    @Override
    public void send(String to, String subject, String htmlBody) {
        // Off the request thread for the same reason SMTP was: callers send from inside a
        // transaction, and a slow provider must never hold a database connection.
        executor.execute(() -> {
            try {
                http.post()
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(Map.of(
                                "sender", Map.of("name", config.fromName(),
                                                 "email", config.from()),
                                "to", List.of(Map.of("email", to)),
                                "subject", subject,
                                "htmlContent", htmlBody))
                        .retrieve()
                        .toBodilessEntity();
                log.info("Sent '{}' to {} via Brevo API", subject, to);
            } catch (Exception e) {
                // The request that asked for this returned long ago, so this line is the
                // only evidence a send failed. Brevo puts the reason in the response body,
                // which RestClient includes in the exception message - a rejected sender
                // or a bad key both say so explicitly.
                log.error("Could not send '{}' to {} via Brevo API: {}",
                        subject, to, e.toString());
            }
        });
    }
}
