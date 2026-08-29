package com.patriche.gymtracker.auth;

import com.patriche.gymtracker.config.AppProperties;
import com.patriche.gymtracker.favorite.FavoriteRepository;
import com.patriche.gymtracker.measurement.MeasurementRepository;
import com.patriche.gymtracker.workout.WorkoutLogRepository;
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
 * Deletes rows nothing can use again: spent refresh tokens, and tombstones old enough
 * that every device has certainly synced past them.
 *
 * <p>Both exist because deleting immediately would be wrong, and both stop being needed
 * after a while. A refresh token is revoked rather than removed so a rotation is atomic;
 * a deleted record is tombstoned rather than removed because a pull is the only way an
 * offline device learns of a deletion - drop the row outright and that device keeps its
 * copy forever and may re-upload it. Once the window has passed, neither is worth
 * storing, and reaping them reclaims exactly the space an immediate hard delete would
 * have saved, without the desynchronisation it would have caused.
 *
 * <p>V3__minimize_free_tier_footprint.sql refers to this class by its former name,
 * RefreshTokenCleaner. The name is stale but the file must not be corrected: that
 * migration has been applied, and editing an applied migration changes its checksum and
 * fails Flyway validation on the next startup.
 *
 * <p>Deliberately NOT {@code @Scheduled}. On Neon's free plan the compute suspends when
 * idle and every query wakes it, so a timer would burn compute hours purely to tidy up.
 * Instead the sweep runs at startup (the database is already awake for Flyway) and then
 * rides existing traffic, at most once a day, so it never causes a wake-up of its own.
 */
@Component
public class HousekeepingSweeper {

    private static final Logger log = LoggerFactory.getLogger(HousekeepingSweeper.class);

    private static final Duration INTERVAL = Duration.ofHours(24);

    private final RefreshTokenRepository refreshTokens;
    private final WorkoutLogRepository workouts;
    private final MeasurementRepository measurements;
    private final FavoriteRepository favorites;
    private final Duration tombstoneRetention;

    /** Earliest time the next opportunistic sweep may run. */
    private final AtomicReference<Instant> nextSweep = new AtomicReference<>(Instant.EPOCH);

    HousekeepingSweeper(RefreshTokenRepository refreshTokens, WorkoutLogRepository workouts,
                        MeasurementRepository measurements, FavoriteRepository favorites,
                        AppProperties props) {
        this.refreshTokens = refreshTokens;
        this.workouts = workouts;
        this.measurements = measurements;
        this.favorites = favorites;
        this.tombstoneRetention =
                Duration.ofDays(props.housekeeping().tombstoneRetentionDays());
    }

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void sweepOnStartup() {
        Instant now = Instant.now();
        nextSweep.set(now.plus(INTERVAL));
        sweep(now);
    }

    /**
     * Sweeps if a day has passed, otherwise returns immediately. Called from a request
     * that already holds a database connection, so a due sweep costs a few extra
     * statements and no extra wake-up.
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
            int tokens = refreshTokens.deleteSpent(now);

            Instant before = now.minus(tombstoneRetention);
            int reaped = workouts.deleteTombstonesBefore(before)
                    + measurements.deleteTombstonesBefore(before)
                    + favorites.deleteTombstonesBefore(before);

            if (tokens > 0 || reaped > 0) {
                log.info("Housekeeping: purged {} spent refresh tokens, reaped {} tombstones "
                        + "older than {} days", tokens, reaped, tombstoneRetention.toDays());
            }
        } catch (RuntimeException e) {
            // Housekeeping must never fail the request that happened to trigger it.
            log.warn("Housekeeping sweep failed; will retry on the next interval", e);
        }
    }
}
