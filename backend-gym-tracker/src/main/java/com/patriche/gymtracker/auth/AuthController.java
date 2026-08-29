package com.patriche.gymtracker.auth;

import com.patriche.gymtracker.auth.dto.AuthDtos.*;
import com.patriche.gymtracker.user.CurrentUser;
import jakarta.validation.Valid;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
class AuthController {

    private final AuthService auth;
    private final EmailVerificationService verification;

    AuthController(AuthService auth, EmailVerificationService verification) {
        this.auth = auth;
        this.verification = verification;
    }

    @PostMapping("/register")
    TokenPair register(@Valid @RequestBody RegisterRequest req) {
        return auth.register(req);
    }

    @PostMapping("/login")
    TokenPair login(@Valid @RequestBody LoginRequest req) {
        return auth.login(req);
    }

    @PostMapping("/refresh")
    TokenPair refresh(@Valid @RequestBody RefreshRequest req) {
        return auth.refresh(req.refreshToken());
    }

    @PostMapping("/logout")
    ResponseEntity<Void> logout(@Valid @RequestBody RefreshRequest req) {
        auth.logout(req.refreshToken());
        return ResponseEntity.noContent().build();
    }

    /**
     * Checked from inside the app, not from a browser, which is the point of a code
     * rather than a link: the response carries the updated user, so the app knows
     * immediately and can drop its banner and start syncing. A link would have been
     * opened elsewhere, leaving the app unaware until its next token refresh.
     */
    @PostMapping("/verify")
    UserResponse verify(@Valid @RequestBody VerifyEmailRequest req) {
        return AuthService.toResponse(
                verification.verify(CurrentUser.id(), req.code(), Instant.now()));
    }

    /** Throttled in the service; 429 tells the app to stop asking for a while. */
    @PostMapping("/verify/resend")
    @ResponseStatus(HttpStatus.ACCEPTED)
    void resendVerification() {
        verification.resend(CurrentUser.id(), Instant.now());
    }

    /** Always 202, even for an unknown address - see AuthService.forgotPassword. */
    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.ACCEPTED)
    void forgotPassword(@Valid @RequestBody ForgotPasswordRequest req) {
        auth.forgotPassword(AuthService.normalizeEmail(req.email()));
    }
}
