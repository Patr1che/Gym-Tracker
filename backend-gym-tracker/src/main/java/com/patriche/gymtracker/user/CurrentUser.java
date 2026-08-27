package com.patriche.gymtracker.user;

import com.patriche.gymtracker.common.ApiException;
import java.util.UUID;
import org.springframework.security.core.context.SecurityContextHolder;

/** The authenticated user id, taken from the JWT subject and nowhere else. */
public final class CurrentUser {

    private CurrentUser() {}

    public static UUID id() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof UUID userId)) {
            throw ApiException.unauthorized("Not authenticated");
        }
        return userId;
    }
}
