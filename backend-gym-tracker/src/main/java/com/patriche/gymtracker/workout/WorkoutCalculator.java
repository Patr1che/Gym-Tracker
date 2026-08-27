package com.patriche.gymtracker.workout;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Port of lib/core/domain/workout_calculator.dart and calorie_calculator.dart.
 *
 * <p>These run server-side on every write because the client's totals cannot be trusted:
 * an old app build, a tampered request, or a rounding difference would otherwise put a
 * wrong number in the user's history permanently.
 *
 * <p>Only sets that were completed and not skipped count, matching SetLog.counts.
 */
public final class WorkoutCalculator {

    /** AppConstants.strengthTrainingMet */
    private static final BigDecimal STRENGTH_TRAINING_MET = new BigDecimal("5.0");

    /** AppConstants.fallbackWeightKg - used when the user has no profile weight yet. */
    private static final BigDecimal FALLBACK_WEIGHT_KG = new BigDecimal("70.0");

    private static final BigDecimal SECONDS_PER_HOUR = new BigDecimal("3600");

    private WorkoutCalculator() {}

    public static BigDecimal totalVolumeKg(List<ExerciseLogEntry> entries) {
        BigDecimal volume = BigDecimal.ZERO;
        for (ExerciseLogEntry entry : entries) {
            for (SetLogEntry set : entry.getSets()) {
                if (set.counts()) {
                    volume = volume.add(
                            set.getWeightKg().multiply(BigDecimal.valueOf(set.getReps())));
                }
            }
        }
        return volume.setScale(2, RoundingMode.HALF_UP);
    }

    public static int totalCompletedSets(List<ExerciseLogEntry> entries) {
        int count = 0;
        for (ExerciseLogEntry entry : entries) {
            for (SetLogEntry set : entry.getSets()) {
                if (set.counts()) count++;
            }
        }
        return count;
    }

    /** Never negative, even if a device clock reports an end before the start. */
    public static int durationSec(Instant startedAt, Instant endedAt) {
        long diff = Duration.between(startedAt, endedAt).toSeconds();
        return diff < 0 ? 0 : (int) Math.min(diff, Integer.MAX_VALUE);
    }

    /** MET-based estimate: kcal = MET * weightKg * hours. */
    public static int estimateCalories(int durationSec, BigDecimal userWeightKg) {
        if (durationSec <= 0) return 0;
        BigDecimal weight = (userWeightKg == null || userWeightKg.signum() <= 0)
                ? FALLBACK_WEIGHT_KG
                : userWeightKg;
        return STRENGTH_TRAINING_MET
                .multiply(weight)
                .multiply(BigDecimal.valueOf(durationSec))
                .divide(SECONDS_PER_HOUR, 4, RoundingMode.HALF_UP)
                .setScale(0, RoundingMode.HALF_UP)
                .intValue();
    }
}
