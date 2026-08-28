package com.patriche.gymtracker;

import static org.assertj.core.api.Assertions.assertThat;

import com.patriche.gymtracker.auth.RefreshToken;
import com.patriche.gymtracker.auth.RefreshTokenCleaner;
import com.patriche.gymtracker.auth.RefreshTokenRepository;
import com.patriche.gymtracker.user.User;
import com.patriche.gymtracker.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest(properties = "app.jwt.secret=test-secret-that-is-definitely-long-enough-32")
@Import(TestcontainersConfiguration.class)
class RefreshTokenCleanerTest {

    @Autowired RefreshTokenRepository refreshTokens;
    @Autowired UserRepository users;
    @Autowired RefreshTokenCleaner cleaner;

    private User newUser() {
        String email = UUID.randomUUID() + "@example.com";
        return users.save(new User(UUID.randomUUID(), "Sweep", email, "hash", null,
                1, Instant.now()));
    }

    /** Returns the id, which RefreshToken does not expose a getter for. */
    private UUID token(UUID userId, Instant expiresAt, Instant revokedAt) {
        UUID id = UUID.randomUUID();
        RefreshToken t = new RefreshToken(id, userId,
                UUID.randomUUID().toString(), expiresAt, Instant.now());
        if (revokedAt != null) t.revoke(revokedAt);
        refreshTokens.save(t);
        return id;
    }

    // The bulk delete flushes the persistence context, which needs a real transaction.
    @Test
    @Transactional
    void removesExpiredAndRevokedTokensButKeepsLiveOnes() {
        UUID userId = newUser().getId();
        Instant now = Instant.now();

        UUID live = token(userId, now.plus(Duration.ofDays(30)), null);
        UUID expired = token(userId, now.minus(Duration.ofDays(1)), null);
        UUID revoked = token(userId, now.plus(Duration.ofDays(30)), now);

        int removed = refreshTokens.deleteSpent(now);

        assertThat(removed).isEqualTo(2);
        assertThat(refreshTokens.findById(live)).isPresent();
        assertThat(refreshTokens.findById(expired)).isEmpty();
        assertThat(refreshTokens.findById(revoked)).isEmpty();
    }

    @Test
    void opportunisticSweepRunsOnceThenBacksOffUntilItsIntervalElapses() {
        UUID userId = newUser().getId();
        Instant now = Instant.now();
        token(userId, now.minus(Duration.ofDays(1)), null);

        // Startup already armed the interval, so an immediate call must be a no-op.
        cleaner.sweepIfDue(now);
        assertThat(refreshTokens.count()).isPositive();

        // A day later the sweep is due and clears the expired row.
        cleaner.sweepIfDue(now.plus(Duration.ofHours(25)));
        assertThat(refreshTokens.findAll())
                .noneMatch(t -> t.getExpiresAt().isBefore(now));
    }
}
