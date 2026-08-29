package com.patriche.gymtracker.common;

import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;

/**
 * Writes the same error body {@link GlobalExceptionHandler} produces, for the filters
 * that run before Spring MVC and so can never reach it.
 *
 * <p>Built by hand rather than through an injected ObjectMapper: Boot 4 ships Jackson 3
 * under {@code tools.jackson}, so binding a filter to either Jackson package would make
 * it break on the next Jackson major. The shape is small and fixed enough to be worth
 * the hand-rolling.
 */
public final class JsonErrors {

    private JsonErrors() {}

    public static void write(HttpServletResponse response, HttpStatus status,
                             String message, String path) throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"timestamp\":\"" + Instant.now() + "\","
                + "\"status\":" + status.value() + ","
                + "\"error\":\"" + safe(status.getReasonPhrase()) + "\","
                + "\"message\":\"" + safe(message) + "\","
                + "\"path\":\"" + safe(path) + "\"}");
    }

    /**
     * Drops anything that would need JSON escaping instead of escaping it. These values
     * are diagnostic echoes, so losing an exotic character costs nothing and removes any
     * chance of emitting a malformed body - or of a crafted path smuggling quotes into
     * the response.
     *
     * <p>The range starts at 0x20 rather than above it because a space needs no escaping
     * and these strings are read by people: an earlier cut at 0x21 was harmless on the
     * paths this began life on and turned every message into Too_many_attempts.
     */
    static String safe(String value) {
        if (value == null) return "";
        StringBuilder out = new StringBuilder(value.length());
        for (int i = 0; i < value.length() && out.length() < 512; i++) {
            char c = value.charAt(i);
            boolean ok = c >= 0x20 && c < 0x7F && c != '"' && c != 0x5C;
            out.append(ok ? c : '_');
        }
        return out.toString();
    }
}
