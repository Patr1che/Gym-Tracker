package com.patriche.gymtracker.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** Binds the `app.*` block of application.yml. */
@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Cors cors, Housekeeping housekeeping, Mail mail) {

    /**
     * Verification email settings. {@code publicUrl} is this API's own base URL, because
     * the link is opened in a browser and must come back here - not to the app origin.
     */
    public record Mail(String from, String fromName, String publicUrl,
                       int codeTtlMinutes, int resendCooldownMinutes) {}

    public record Jwt(String secret, long accessTtlMinutes, long refreshTtlDays) {}

    public record Cors(List<String> allowedOrigins) {}

    /**
     * How long a tombstone is kept before the row is deleted outright.
     *
     * <p>A soft-deleted row is not waste, it is the only way an offline device ever
     * learns the record was deleted - it has to receive the tombstone in a pull. But
     * that is only true until every device has synced past the deletion. After that the
     * row is dead weight, and reaping it reclaims the space a hard delete would have
     * saved without the desynchronisation a hard delete causes.
     */
    public record Housekeeping(int tombstoneRetentionDays) {}
}
