package com.patriche.gymtracker.measurement;

import com.patriche.gymtracker.common.ApiException;
import com.patriche.gymtracker.measurement.MeasurementDtos.MeasurementResponse;
import com.patriche.gymtracker.measurement.MeasurementDtos.MeasurementUpsertRequest;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MeasurementService {

    private final MeasurementRepository measurements;

    MeasurementService(MeasurementRepository measurements) {
        this.measurements = measurements;
    }

    @Transactional(readOnly = true)
    public List<MeasurementResponse> list(UUID userId) {
        return measurements.findByUserIdAndDeletedAtIsNullOrderByDateDesc(userId)
                .stream().map(MeasurementService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<MeasurementResponse> changedSince(UUID userId, Instant since) {
        return measurements.findChangedSince(userId, since)
                .stream().map(MeasurementService::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public MeasurementResponse get(UUID userId, UUID id) {
        return toResponse(measurements.findByIdAndUserId(id, userId)
                .orElseThrow(() -> ApiException.notFound("Measurement not found")));
    }

    /** Idempotent upsert on the client's id, with last-write-wins by updatedAt. */
    @Transactional
    public MeasurementResponse upsert(UUID userId, UUID id,
                                      MeasurementUpsertRequest req, Instant now) {
        Measurement entry = measurements.findByIdAndUserId(id, userId).orElse(null);

        if (entry != null && req.updatedAt() != null && entry.getUpdatedAt() != null
                && req.updatedAt().isBefore(entry.getUpdatedAt())) {
            return toResponse(entry);
        }

        if (entry == null) {
            entry = new Measurement(id, userId);
        }

        entry.setDate(req.date());
        entry.setWeightKg(req.weightKg());
        entry.setBodyFatPct(req.bodyFatPct());
        entry.setChestCm(req.chestCm());
        entry.setWaistCm(req.waistCm());
        entry.setArmsCm(req.armsCm());
        entry.setLegsCm(req.legsCm());
        entry.setShouldersCm(req.shouldersCm());
        entry.setNeckCm(req.neckCm());
        entry.setHipsCm(req.hipsCm());
        entry.restore(now);

        return toResponse(measurements.save(entry));
    }

    /** Soft delete: the tombstone is what tells other devices the record is gone. */
    @Transactional
    public void delete(UUID userId, UUID id, Instant now) {
        measurements.findByIdAndUserId(id, userId).ifPresent(entry -> {
            entry.softDelete(now);
            measurements.save(entry);
        });
    }

    public static MeasurementResponse toResponse(Measurement m) {
        return new MeasurementResponse(
                m.getId(), m.getUserId(), m.getDate(),
                m.getWeightKg(), m.getBodyFatPct(), m.getChestCm(), m.getWaistCm(),
                m.getArmsCm(), m.getLegsCm(), m.getShouldersCm(), m.getNeckCm(),
                m.getHipsCm(), m.getUpdatedAt(), m.getDeletedAt());
    }
}
