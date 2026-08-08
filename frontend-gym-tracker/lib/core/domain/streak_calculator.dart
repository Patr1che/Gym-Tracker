/// Consecutive-day workout streak.
///
/// Anchor is today if the user trained today, otherwise yesterday — a rest
/// day today shouldn't break the streak before it's over. Walks backwards
/// over calendar days (date arithmetic via day-component math, DST-safe).
abstract final class StreakCalculator {
  static int currentStreak({
    required Iterable<DateTime> workoutDates,
    required DateTime today,
  }) {
    final days = workoutDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
    if (days.isEmpty) return 0;

    var anchor = DateTime(today.year, today.month, today.day);
    if (!days.contains(anchor)) {
      anchor = DateTime(anchor.year, anchor.month, anchor.day - 1);
      if (!days.contains(anchor)) return 0;
    }

    var streak = 0;
    var cursor = anchor;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }
}
