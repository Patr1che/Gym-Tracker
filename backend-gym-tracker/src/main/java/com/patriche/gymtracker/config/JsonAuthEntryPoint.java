package com.patriche.gymtracker.config;

import com.patriche.gymtracker.common.JsonErrors;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

/**
 * Without this, an unauthenticated request to a protected route gets Spring Security's
 * default 403. For a token API the honest answer is 401 - the caller may simply need to
 * refresh - and the Flutter ApiClient keys its refresh-and-retry on that status.
 */
@Component
class JsonAuthEntryPoint implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        JsonErrors.write(response, HttpStatus.UNAUTHORIZED,
                "Authentication required", request.getRequestURI());
    }
}
