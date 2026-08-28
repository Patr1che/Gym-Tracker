package com.patriche.gymtracker.auth;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Deletes refresh tokens that can never be used again. Without this the table only
 * grows: {@code refresh()} rotates a token roughly every time an access token expires,
 * and revoking a row leaves it on disk forever.
 *
 * <p>Deliberately NOT {@code @Scheduled}. On Neon's free plan the compute suspends when
 * idle and every query wakes it, so a timer would burn compute hours purely to tidy up -
 * an hourly sweep would keep the database awake around the clock. Instead the sweep runs
 * at startup (the database is already awake for Flyway) and then rides existing traffic,
 * at most once a day. Cleanup therefore never causes a wake-up of its own.
 */
@Component
public class RefreshTokenCleaner {

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenCleaner.class);

    private static final Duration INTERVAL = Duration.ofHours(24);

    private final RefreshTokenRepository refreshTokens;

    /** Earliest time the next opportunistic sweep may run. */
    private final AtomicReference<Instant> nextSweep = new AtomicReference<>(Instant.EPOCH);

    RefreshTokenCleaner(RefreshTokenRepository refreshTokens) {
        this.refreshTokens = refreshTokens;
    }

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void sweepOnStartup() {
        nextSweep.set(Instant.now().plus(INTERVAL));
        sweep(Instant.now());
    }

    /**
     * Sweeps if a day has passed, otherwise returns immediately. Called from a request
     * that already holds a database connection, so a due sweep costs one extra statement
     * and no extra wake-up.
     */
    @Transactional
    public void sweepIfDue(Instant now) {
        Instant due = nextSweep.get();
        // compareAndSet so that concurrent requests cannot both decide they are the one.
        if (now.isBefore(due) || !nextSweep.compareAndSet(due, now.plus(INTERVAL))) return;
        sweep(now);
    }

    private void sweep(Instant now) {
        try {
            int removed = refreshTokens.deleteSpent(now);
            if (removed > 0) log.info("Purged {} spent refresh tokens", removed);
        } catch (RuntimeException e) {
            // Housekeeping must never fail the request that happened to trigger it.
            log.warn("Refresh token sweep failed; will retry on the next interval", e);
        }
    }
}
