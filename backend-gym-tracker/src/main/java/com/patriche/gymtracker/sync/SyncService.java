package com.patriche.gymtracker.sync;

import com.patriche.gymtracker.common.ApiException;
import com.patriche.gymtracker.favorite.FavoriteService;
import com.patriche.gymtracker.measurement.MeasurementService;
import com.patriche.gymtracker.settings.SettingsService;
import com.patriche.gymtracker.sync.SyncDtos.FavoriteState;
import com.patriche.gymtracker.sync.SyncDtos.MeasurementPush;
import com.patriche.gymtracker.sync.SyncDtos.SyncRequest;
import com.patriche.gymtracker.sync.SyncDtos.SyncResponse;
import com.patriche.gymtracker.sync.SyncDtos.WorkoutPush;
import com.patriche.gymtracker.user.UserRepository;
import com.patriche.gymtracker.workout.WorkoutService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The whole sync protocol: push everything dirty, pull everything changed since the
 * client's cursor, in one round trip.
 *
 * <p>Conflict resolution is last-write-wins per record by updatedAt, applied inside each
 * feature service. That is enough here because workout logs are append-mostly - two
 * devices editing the same finished workout simultaneously is not a real scenario.
 */
@Service
public class SyncService {

    private final WorkoutService workouts;
    private final MeasurementService measurements;
    private final FavoriteService favorites;
    private final SettingsService settings;
    private final UserRepository users;

    SyncService(WorkoutService workouts, MeasurementService measurements,
                FavoriteService favorites, SettingsService settings,
                UserRepository users) {
        this.workouts = workouts;
        this.measurements = measurements;
        this.favorites = favorites;
        this.settings = settings;
        this.users = users;
    }

    @Transactional
    public SyncResponse sync(UUID userId, SyncRequest req, Instant now) {
        requireVerifiedEmail(userId);
        push(userId, req, now);

        // A null cursor means a first sync: hand back the entire account.
        Instant since = req.since() == null ? Instant.EPOCH : req.since();

        return new SyncResponse(
                now,
                workouts.changedSince(userId, since),
                measurements.changedSince(userId, since),
                pullFavorites(userId, since),
                settings.load(userId, now));
    }

    /**
     * Sync is the one thing an unverified account cannot do. Sign-in is untouched, so
     * the app stays fully usable offline - it simply keeps everything on the device
     * until the address is confirmed. Nothing is lost in the meantime: the client
     * leaves its records dirty on a failed sync and pushes them all once this passes.
     *
     * <p>403 rather than 401 deliberately. A 401 makes the client burn a token refresh
     * before failing again; this is a permission problem, not an expired session.
     */
    private void requireVerifiedEmail(UUID userId) {
        boolean verified = users.findById(userId)
                .map(u -> u.isEmailVerified())
                .orElse(false);
        if (!verified) {
            throw ApiException.forbidden(
                    "Confirm your email address to sync. Your data is saved on this device "
                    + "and will upload as soon as you do.");
        }
    }

    private void push(UUID userId, SyncRequest req, Instant now) {
        if (req.workouts() != null) {
            for (WorkoutPush push : req.workouts()) {
                if (push == null || push.id() == null) continue;
                if (push.deletedAt() != null) {
                    workouts.delete(userId, push.id(), now);
                } else if (push.record() != null) {
                    workouts.upsert(userId, push.id(), push.record(), now);
                }
            }
        }

        if (req.measurements() != null) {
            for (MeasurementPush push : req.measurements()) {
                if (push == null || push.id() == null) continue;
                if (push.deletedAt() != null) {
                    measurements.delete(userId, push.id(), now);
                } else if (push.record() != null) {
                    measurements.upsert(userId, push.id(), push.record(), now);
                }
            }
        }

        // Favourites and settings are whole-object replaces, so a null means
        // "nothing to push" rather than "clear it".
        if (req.favorites() != null) {
            favorites.replaceAll(userId, req.favorites(), now);
        }
        if (req.settings() != null) {
            settings.save(userId, req.settings(), now);
        }
    }

    private List<FavoriteState> pullFavorites(UUID userId, Instant since) {
        return favorites.changedSince(userId, since).stream()
                .map(f -> new FavoriteState(f.getExerciseId(), f.isDeleted(), f.getUpdatedAt()))
                .toList();
    }
}
