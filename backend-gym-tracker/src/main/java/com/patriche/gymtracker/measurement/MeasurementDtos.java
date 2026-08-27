package com.patriche.gymtracker.measurement;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/** Field names mirror MeasurementEntry.toJson in the Flutter app. */
public final class MeasurementDtos {

    private MeasurementDtos() {}

    public record MeasurementUpsertRequest(
            @NotNull Instant date,
            BigDecimal weightKg,
            BigDecimal bodyFatPct,
            BigDecimal chestCm,
            BigDecimal waistCm,
            BigDecimal armsCm,
            BigDecimal legsCm,
            BigDecimal shouldersCm,
            BigDecimal neckCm,
            BigDecimal hipsCm,
            Instant updatedAt) {}

    public record MeasurementResponse(
            UUID id,
            UUID userId,
            Instant date,
            BigDecimal weightKg,
            BigDecimal bodyFatPct,
            BigDecimal chestCm,
            BigDecimal waistCm,
            BigDecimal armsCm,
            BigDecimal legsCm,
            BigDecimal shouldersCm,
            BigDecimal neckCm,
            BigDecimal hipsCm,
            Instant updatedAt,
            Instant deletedAt) {}
}
