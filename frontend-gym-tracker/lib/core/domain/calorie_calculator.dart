import '../constants/app_constants.dart';

/// MET-based estimate: kcal = MET × weightKg × hours. Documented in the UI as
/// an estimate.
abstract final class CalorieCalculator {
  static int estimate({
    required int durationSec,
    double? weightKg,
    double met = AppConstants.strengthTrainingMet,
  }) {
    if (durationSec <= 0) return 0;
    final weight = (weightKg == null || weightKg <= 0)
        ? AppConstants.fallbackWeightKg
        : weightKg;
    return (met * weight * (durationSec / 3600)).round();
  }
}
