package com.patriche.gymtracker.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** Binds the `app.*` block of application.yml. */
@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Cors cors) {

    public record Jwt(String secret, long accessTtlMinutes, long refreshTtlDays) {}

    public record Cors(List<String> allowedOrigins) {}
}
