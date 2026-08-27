package com.patriche.gymtracker.workout;

import com.patriche.gymtracker.common.ApiException;
import com.patriche.gymtracker.user.User;
import com.patriche.gymtracker.user.UserRepository;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.ExerciseLogDto;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.SetLogDto;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.WorkoutResponse;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.WorkoutUpsertRequest;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class WorkoutService {

    private final WorkoutLogRepository workouts;
    private final UserRepository users;

    WorkoutService(WorkoutLogRepository workouts, UserRepository users) {
        this.workouts = workouts;
        this.users = users;
    }

    @Transactional(readOnly = true)
    public List<WorkoutResponse> list(UUID userId) {
        return workouts.findByUserIdAndDeletedAtIsNullOrderByStartedAtDesc(userId)
                .stream().map(WorkoutService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<WorkoutResponse> changedSince(UUID userId, Instant since) {
        return workouts.findChangedSince(userId, since)
                .stream().map(WorkoutService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public WorkoutResponse get(UUID userId, UUID id) {
        return toResponse(workouts.findByIdAndUserId(id, userId)
                .orElseThrow(() -> ApiException.notFound("Workout not found")));
    }

    /**
     * Idempotent upsert on the client's id. Applies last-write-wins: an incoming record
     * whose updatedAt is older than what is stored is ignored, so a stale device
     * replaying an old copy cannot clobber a newer edit.
     */
    @Transactional
    public WorkoutResponse upsert(UUID userId, UUID id, WorkoutUpsertRequest req, Instant now) {
        WorkoutLog log = workouts.findByIdAndUserId(id, userId).orElse(null);

        if (log != null && req.updatedAt() != null && log.getUpdatedAt() != null
                && req.updatedAt().isBefore(log.getUpdatedAt())) {
            return toResponse(log);
        }

        if (log == null) {
            log = new WorkoutLog(id, userId);
        } else {
            // Drop the old children and flush the DELETEs before the replacements are
            // inserted. Hibernate otherwise orders the INSERTs first and trips the
            // UNIQUE (workout_log_id, sort_order) constraint, which would make every
            // re-upload of an existing workout fail - including every ordinary re-sync.
            log.getEntries().clear();
            workouts.saveAndFlush(log);
        }

        log.setProgramId(req.programId());
        log.setDayName(req.dayName() == null || req.dayName().isBlank()
                ? "Workout" : req.dayName());
        log.setStartedAt(req.startedAt());
        log.setEndedAt(req.endedAt());
        log.replaceEntries(buildEntries(log, req.entries()));
        log.recomputeTotals(profileWeightKg(userId));
        log.restore(now);

        return toResponse(workouts.save(log));
    }

    /** Soft delete: the tombstone is what tells other devices the record is gone. */
    @Transactional
    public void delete(UUID userId, UUID id, Instant now) {
        workouts.findByIdAndUserId(id, userId).ifPresent(log -> {
            log.softDelete(now);
            workouts.save(log);
        });
    }

    private List<ExerciseLogEntry> buildEntries(WorkoutLog parent, List<ExerciseLogDto> dtos) {
        List<ExerciseLogEntry> result = new ArrayList<>();
        if (dtos == null) return result;

        for (int i = 0; i < dtos.size(); i++) {
            ExerciseLogDto dto = dtos.get(i);
            ExerciseLogEntry entry = new ExerciseLogEntry(parent, dto.exerciseId(), i);
            List<SetLogDto> sets = dto.sets() == null ? List.of() : dto.sets();
            for (int s = 0; s < sets.size(); s++) {
                SetLogDto set = sets.get(s);
                entry.addSet(new SetLogEntry(entry, set.weightKg(), set.reps(),
                        set.completed(), set.skipped(), s));
            }
            result.add(entry);
        }
        return result;
    }

    /** Calorie estimates use the user's profile weight, falling back to 70 kg. */
    private BigDecimal profileWeightKg(UUID userId) {
        return users.findById(userId)
                .map(User::getProfile)
                .map(p -> p == null ? null : p.getWeightKg())
                .orElse(null);
    }

    public static WorkoutResponse toResponse(WorkoutLog w) {
        List<ExerciseLogDto> entries = w.getEntries().stream()
                .map(e -> new ExerciseLogDto(e.getExerciseId(), e.getSets().stream()
                        .map(s -> new SetLogDto(s.getWeightKg(), s.getReps(),
                                s.isCompleted(), s.isSkipped()))
                        .toList()))
                .toList();

        return new WorkoutResponse(
                w.getId(), w.getUserId(), w.getProgramId(), w.getDayName(),
                w.getStartedAt(), w.getEndedAt(), w.getDurationSec(), entries,
                w.getTotalVolumeKg(), w.getTotalSets(), w.getCaloriesEst(),
                w.getUpdatedAt(), w.getDeletedAt());
    }
}
