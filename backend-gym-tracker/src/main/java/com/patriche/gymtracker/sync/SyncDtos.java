package com.patriche.gymtracker.sync;

import com.patriche.gymtracker.measurement.MeasurementDtos.MeasurementResponse;
import com.patriche.gymtracker.measurement.MeasurementDtos.MeasurementUpsertRequest;
import com.patriche.gymtracker.settings.SettingsService.SettingsDto;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.WorkoutResponse;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.WorkoutUpsertRequest;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class SyncDtos {

    private SyncDtos() {}

    /** A pushed record carries its own id, since the client minted it. */
    public record WorkoutPush(UUID id, WorkoutUpsertRequest record, Instant deletedAt) {}

    public record MeasurementPush(UUID id, MeasurementUpsertRequest record, Instant deletedAt) {}

    /**
     * One round trip: everything dirty goes up, everything changed since the cursor
     * comes back.
     *
     * @param since null on a first sync, which means "send me everything"
     */
    public record SyncRequest(
            Instant since,
            List<WorkoutPush> workouts,
            List<MeasurementPush> measurements,
            List<String> favorites,
            SettingsDto settings) {}

    /**
     * @param serverTime the client's next cursor. Clients must use this and never their
     *                   own clock: phone clocks drift, and skew silently drops records.
     */
    public record SyncResponse(
            Instant serverTime,
            List<WorkoutResponse> workouts,
            List<MeasurementResponse> measurements,
            List<FavoriteState> favorites,
            SettingsDto settings) {}

    /** deleted carries the tombstone, so an unfavourite reaches an offline device. */
    public record FavoriteState(String exerciseId, boolean deleted, Instant updatedAt) {}
}
