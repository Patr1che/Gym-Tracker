package com.patriche.gymtracker.measurement;

import com.patriche.gymtracker.measurement.MeasurementDtos.MeasurementResponse;
import com.patriche.gymtracker.measurement.MeasurementDtos.MeasurementUpsertRequest;
import com.patriche.gymtracker.user.CurrentUser;
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
@RequestMapping("/api/v1/measurements")
class MeasurementController {

    private final MeasurementService measurements;

    MeasurementController(MeasurementService measurements) {
        this.measurements = measurements;
    }

    @GetMapping
    List<MeasurementResponse> list(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant updatedSince) {
        UUID userId = CurrentUser.id();
        return updatedSince == null
                ? measurements.list(userId)
                : measurements.changedSince(userId, updatedSince);
    }

    @GetMapping("/{id}")
    MeasurementResponse get(@PathVariable UUID id) {
        return measurements.get(CurrentUser.id(), id);
    }

    @PutMapping("/{id}")
    MeasurementResponse upsert(@PathVariable UUID id,
                               @Valid @RequestBody MeasurementUpsertRequest req) {
        return measurements.upsert(CurrentUser.id(), id, req, Instant.now());
    }

    @DeleteMapping("/{id}")
    ResponseEntity<Void> delete(@PathVariable UUID id) {
        measurements.delete(CurrentUser.id(), id, Instant.now());
        return ResponseEntity.noContent().build();
    }
}
