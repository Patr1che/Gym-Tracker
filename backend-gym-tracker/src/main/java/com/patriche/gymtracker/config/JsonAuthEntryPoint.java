package com.patriche.gymtracker.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

/**
 * Without this, an unauthenticated request to a protected route gets Spring Security's
 * default 403. For a token API the honest answer is 401 - the caller may simply need to
 * refresh - and the Flutter ApiClient keys its refresh-and-retry on that status.
 *
 * <p>The body is written by hand rather than through an injected ObjectMapper: Boot 4
 * ships Jackson 3 under {@code tools.jackson}, so binding this filter to either Jackson
 * package would make it break on the next Jackson major.
 */
@Component
class JsonAuthEntryPoint implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());

        String body = "{\"timestamp\":\"" + Instant.now() + "\","
                + "\"status\":401,"
                + "\"error\":\"Unauthorized\","
                + "\"message\":\"Authentication required\","
                + "\"path\":\"" + safePath(request.getRequestURI()) + "\"}";

        response.getWriter().write(body);
    }

    /**
     * Drops anything that would need JSON escaping instead of escaping it. The value is
     * only echoed back for debugging, so losing an exotic character costs nothing and
     * removes any chance of emitting a malformed body.
     */
    private static String safePath(String value) {
        if (value == null) return "";
        StringBuilder out = new StringBuilder(value.length());
        for (int i = 0; i < value.length() && out.length() < 512; i++) {
            char c = value.charAt(i);
            boolean safe = c > 0x20 && c < 0x7F && c != '"' && c != 0x5C;
            out.append(safe ? c : '_');
        }
        return out.toString();
    }
}
