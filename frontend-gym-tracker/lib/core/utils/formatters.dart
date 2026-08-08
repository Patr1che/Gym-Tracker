import 'package:intl/intl.dart';

/// '4:32' or '1:04:32' — clock-style, for live timers.
String formatClock(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// '48 min' or '1h 12m' — for history rows and summaries.
String formatDurationText(int totalSeconds) {
  final minutes = (totalSeconds / 60).round();
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
}

/// 'Mon, Aug 3' this year, 'Aug 3, 2025' otherwise.
String formatShortDate(DateTime date, DateTime today) {
  if (date.year == today.year) return DateFormat('EEE, MMM d').format(date);
  return DateFormat('MMM d, y').format(date);
}

/// 'Today', 'Yesterday', or a short date.
String formatRelativeDate(DateTime date, DateTime today) {
  final day = DateTime(date.year, date.month, date.day);
  final anchor = DateTime(today.year, today.month, today.day);
  final diff = anchor.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return formatShortDate(date, today);
}
