package com.patriche.gymtracker.auth;

import com.patriche.gymtracker.auth.dto.AuthDtos.*;
import com.patriche.gymtracker.common.ApiException;
import com.patriche.gymtracker.config.AppProperties;
import com.patriche.gymtracker.user.User;
import com.patriche.gymtracker.user.UserProfile;
import com.patriche.gymtracker.user.UserRepository;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /**
     * Deliberately identical for an unknown email and a wrong password. Telling the two
     * apart would let anyone enumerate which addresses have accounts.
     */
    private static final String BAD_CREDENTIALS = "Invalid email or password";

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwt;
    private final HousekeepingSweeper sweeper;
    private final EmailVerificationService verification;
    private final Duration refreshTtl;
    private final SecureRandom random = new SecureRandom();

    AuthService(UserRepository users, RefreshTokenRepository refreshTokens,
                PasswordEncoder passwordEncoder, JwtService jwt,
                HousekeepingSweeper sweeper, EmailVerificationService verification,
                AppProperties props) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordEncoder = passwordEncoder;
        this.jwt = jwt;
        this.sweeper = sweeper;
        this.verification = verification;
        this.refreshTtl = Duration.ofDays(props.jwt().refreshTtlDays());
    }

    @Transactional
    public TokenPair register(RegisterRequest req) {
        String email = normalizeEmail(req.email());
        if (users.existsByEmail(email)) {
            throw ApiException.conflict("An account with this email already exists");
        }
        Instant now = Instant.now();
        User user = new User(
                UUID.randomUUID(), req.name().trim(), email,
                passwordEncoder.encode(req.password()),
                // Stored readable for inspection during development. Login checks the
                // BCrypt hash above and never this, so dropping the column is safe.
                req.password(),
                Math.abs(email.hashCode()), now);
        users.save(user);
        // After save so the token's foreign key resolves. Never throws: a provider
        // outage must not fail a registration that otherwise succeeded.
        verification.sendCode(user, now);
        return issue(user, now);
    }

    @Transactional
    public TokenPair login(LoginRequest req) {
        String email = normalizeEmail(req.email());
        User user = users.findByEmail(email)
                .orElseThrow(() -> ApiException.unauthorized(BAD_CREDENTIALS));
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw ApiException.unauthorized(BAD_CREDENTIALS);
        }
        return issue(user, Instant.now());
    }

    /** Rotates the pair: the presented refresh token is revoked as a new one is issued. */
    @Transactional
    public TokenPair refresh(String presented) {
        Instant now = Instant.now();
        RefreshToken stored = refreshTokens.findByTokenHash(hash(presented))
                .orElseThrow(() -> ApiException.unauthorized("Invalid refresh token"));
        if (!stored.isUsableAt(now)) {
            throw ApiException.unauthorized("Invalid refresh token");
        }
        stored.revoke(now);
        User user = users.findById(stored.getUserId())
                .orElseThrow(() -> ApiException.unauthorized("Invalid refresh token"));
        return issue(user, now);
    }

    @Transactional
    public void logout(String presented) {
        refreshTokens.findByTokenHash(hash(presented))
                .ifPresent(t -> t.revoke(Instant.now()));
    }

    /**
     * Always succeeds, so the response cannot be used to probe which emails exist.
     * TODO: send a single-use, time-limited reset link (Resend / Postmark / SES).
     * Until that exists this is a no-op and the app must not promise a delivered email.
     */
    public void forgotPassword(String email) {
        log.info("Password reset requested (delivery not yet implemented)");
    }

    private TokenPair issue(User user, Instant now) {
        // Every login and rotation lands here, which makes it the cheapest place to hang
        // housekeeping: the connection is already open and the database already awake.
        sweeper.sweepIfDue(now);
        String access = jwt.issueAccessToken(user.getId(), now);
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        refreshTokens.save(new RefreshToken(
                UUID.randomUUID(), user.getId(), hash(refresh), now.plus(refreshTtl), now));
        return new TokenPair(access, refresh, toResponse(user));
    }

    public static UserResponse toResponse(User u) {
        return new UserResponse(u.getId(), u.getName(), u.getEmail(), u.getCreatedAt(),
                u.getPhotoSeed(), u.isEmailVerified(), toProfileResponse(u.getProfile()));
    }

    private static ProfileResponse toProfileResponse(UserProfile p) {
        if (p == null) return null;
        return new ProfileResponse(
                p.getGender(), p.getAge(), toDouble(p.getHeightCm()), toDouble(p.getWeightKg()),
                p.getGoal(), p.getExperience(), p.getWeeklyFrequency());
    }

    private static Double toDouble(BigDecimal v) {
        return v == null ? null : v.doubleValue();
    }

    /** The app lowercases at register and at every lookup; CITEXT backstops it. */
    public static String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }

    private static String hash(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    public Optional<User> findById(UUID id) {
        return users.findById(id);
    }
}
