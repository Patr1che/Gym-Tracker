package com.patriche.gymtracker.workout;

import com.patriche.gymtracker.user.CurrentUser;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.WorkoutResponse;
import com.patriche.gymtracker.workout.dto.WorkoutDtos.WorkoutUpsertRequest;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/workouts")
class WorkoutController {

    private final WorkoutService workouts;

    WorkoutController(WorkoutService workouts) {
        this.workouts = workouts;
    }

    @GetMapping
    List<WorkoutResponse> list(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant updatedSince) {
        UUID userId = CurrentUser.id();
        return updatedSince == null
                ? workouts.list(userId)
                : workouts.changedSince(userId, updatedSince);
    }

    @GetMapping("/{id}")
    WorkoutResponse get(@PathVariable UUID id) {
        return workouts.get(CurrentUser.id(), id);
    }

    /** PUT, not POST: the client owns the id, so a retry updates instead of duplicating. */
    @PutMapping("/{id}")
    WorkoutResponse upsert(@PathVariable UUID id,
                           @Valid @RequestBody WorkoutUpsertRequest req) {
        return workouts.upsert(CurrentUser.id(), id, req, Instant.now());
    }

    @DeleteMapping("/{id}")
    ResponseEntity<Void> delete(@PathVariable UUID id) {
        workouts.delete(CurrentUser.id(), id, Instant.now());
        return ResponseEntity.noContent().build();
    }
}
