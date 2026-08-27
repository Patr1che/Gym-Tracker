package com.patriche.gymtracker.workout;

import com.patriche.gymtracker.common.SyncableEntity;
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * A finished workout. The id arrives from the client, so PUT with the same id is
 * idempotent - a retried upload on a flaky connection updates rather than duplicating.
 *
 * <p>Totals are denormalized like the Dart model, but always recomputed server-side.
 */
@Entity
@Table(name = "workout_logs")
public class WorkoutLog extends SyncableEntity {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "program_id")
    private String programId;

    /** Denormalized text, not a foreign key - matches WorkoutLog.dayName in the app. */
    @Column(name = "day_name", nullable = false)
    private String dayName;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "ended_at", nullable = false)
    private Instant endedAt;

    @Column(name = "duration_sec", nullable = false)
    private int durationSec;

    @Column(name = "total_volume_kg", nullable = false)
    private BigDecimal totalVolumeKg = BigDecimal.ZERO;

    @Column(name = "total_sets", nullable = false)
    private int totalSets;

    @Column(name = "calories_est", nullable = false)
    private int caloriesEst;

    @OneToMany(mappedBy = "workoutLog", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<ExerciseLogEntry> entries = new ArrayList<>();

    protected WorkoutLog() {}

    public WorkoutLog(UUID id, UUID userId) {
        this.id = id;
        this.userId = userId;
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public String getProgramId() { return programId; }
    public String getDayName() { return dayName; }
    public Instant getStartedAt() { return startedAt; }
    public Instant getEndedAt() { return endedAt; }
    public int getDurationSec() { return durationSec; }
    public BigDecimal getTotalVolumeKg() { return totalVolumeKg; }
    public int getTotalSets() { return totalSets; }
    public int getCaloriesEst() { return caloriesEst; }
    public List<ExerciseLogEntry> getEntries() { return entries; }

    public void setProgramId(String programId) { this.programId = programId; }
    public void setDayName(String dayName) { this.dayName = dayName; }
    public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }
    public void setEndedAt(Instant endedAt) { this.endedAt = endedAt; }

    public void replaceEntries(List<ExerciseLogEntry> replacement) {
        entries.clear();
        entries.addAll(replacement);
    }

    /** Totals are never taken from the request - always derived from the stored sets. */
    public void recomputeTotals(BigDecimal userWeightKg) {
        this.durationSec = WorkoutCalculator.durationSec(startedAt, endedAt);
        this.totalVolumeKg = WorkoutCalculator.totalVolumeKg(entries);
        this.totalSets = WorkoutCalculator.totalCompletedSets(entries);
        this.caloriesEst = WorkoutCalculator.estimateCalories(durationSec, userWeightKg);
    }
}
