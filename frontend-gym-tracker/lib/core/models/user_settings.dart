import 'enums.dart';

class UserSettings {
  const UserSettings({
    this.units = Units.metric,
    this.darkMode = true,
    this.notificationsEnabled = true,
    this.workoutRemindersEnabled = true,
    this.reminderTime = '18:00',
    this.restTimerSound = true,
    this.language = 'English',
  });

  final Units units;
  final bool darkMode;
  final bool notificationsEnabled;
  final bool workoutRemindersEnabled;

  /// 'HH:mm' 24h format.
  final String reminderTime;
  final bool restTimerSound;
  final String language;

  UserSettings copyWith({
    Units? units,
    bool? darkMode,
    bool? notificationsEnabled,
    bool? workoutRemindersEnabled,
    String? reminderTime,
    bool? restTimerSound,
    String? language,
  }) =>
      UserSettings(
        units: units ?? this.units,
        darkMode: darkMode ?? this.darkMode,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        workoutRemindersEnabled:
            workoutRemindersEnabled ?? this.workoutRemindersEnabled,
        reminderTime: reminderTime ?? this.reminderTime,
        restTimerSound: restTimerSound ?? this.restTimerSound,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => {
        'units': units.name,
        'darkMode': darkMode,
        'notificationsEnabled': notificationsEnabled,
        'workoutRemindersEnabled': workoutRemindersEnabled,
        'reminderTime': reminderTime,
        'restTimerSound': restTimerSound,
        'language': language,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        units: Units.fromName(json['units'] as String?),
        darkMode: json['darkMode'] as bool? ?? true,
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        workoutRemindersEnabled:
            json['workoutRemindersEnabled'] as bool? ?? true,
        reminderTime: json['reminderTime'] as String? ?? '18:00',
        restTimerSound: json['restTimerSound'] as bool? ?? true,
        language: json['language'] as String? ?? 'English',
      );
}
