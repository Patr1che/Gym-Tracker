package com.patriche.gymtracker.sync;

import com.patriche.gymtracker.favorite.FavoriteService;
import com.patriche.gymtracker.measurement.MeasurementService;
import com.patriche.gymtracker.settings.SettingsService;
import com.patriche.gymtracker.sync.SyncDtos.FavoriteState;
import com.patriche.gymtracker.sync.SyncDtos.MeasurementPush;
import com.patriche.gymtracker.sync.SyncDtos.SyncRequest;
import com.patriche.gymtracker.sync.SyncDtos.SyncResponse;
import com.patriche.gymtracker.sync.SyncDtos.WorkoutPush;
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

    SyncService(WorkoutService workouts, MeasurementService measurements,
                FavoriteService favorites, SettingsService settings) {
        this.workouts = workouts;
        this.measurements = measurements;
        this.favorites = favorites;
        this.settings = settings;
    }

    @Transactional
    public SyncResponse sync(UUID userId, SyncRequest req, Instant now) {
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
