package com.patriche.gymtracker.workout.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Field names mirror the Dart toJson output exactly, so the app's existing
 * WorkoutLog.toJson is already the wire format.
 */
public final class WorkoutDtos {

    private WorkoutDtos() {}

    public record SetLogDto(
            BigDecimal weightKg,
            int reps,
            boolean completed,
            boolean skipped) {}

    public record ExerciseLogDto(
            @NotNull @Size(max = 100) String exerciseId,
            @Valid List<SetLogDto> sets) {}

    /**
     * totalVolumeKg, totalSets and caloriesEst are deliberately absent: the client may
     * send them, but the server recomputes, so any submitted value would be ignored.
     */
    public record WorkoutUpsertRequest(
            String programId,
            @Size(max = 120) String dayName,
            @NotNull Instant startedAt,
            @NotNull Instant endedAt,
            @Valid List<ExerciseLogDto> entries,
            Instant updatedAt) {}

    public record WorkoutResponse(
            UUID id,
            UUID userId,
            String programId,
            String dayName,
            Instant startedAt,
            Instant endedAt,
            int durationSec,
            List<ExerciseLogDto> entries,
            BigDecimal totalVolumeKg,
            int totalSets,
            int caloriesEst,
            Instant updatedAt,
            Instant deletedAt) {}
}
