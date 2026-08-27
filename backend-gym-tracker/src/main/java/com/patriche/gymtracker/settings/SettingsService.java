package com.patriche.gymtracker.settings;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SettingsService {

    /** Mirrors UserSettings.toJson in the Flutter app. */
    public record SettingsDto(
            String units,
            Boolean darkMode,
            Boolean notificationsEnabled,
            Boolean workoutRemindersEnabled,
            String reminderTime,
            Boolean restTimerSound,
            String language,
            Instant updatedAt) {}

    private final UserSettingsRepository repo;

    SettingsService(UserSettingsRepository repo) {
        this.repo = repo;
    }

    /** Returns app defaults when the user has never saved settings. */
    @Transactional
    public SettingsDto load(UUID userId, Instant now) {
        return toDto(repo.findById(userId).orElseGet(() -> new UserSettings(userId, now)));
    }

    /**
     * Whole-object replace with last-write-wins. Null fields keep the stored value, so a
     * partial payload from an older app build cannot blank out newer settings.
     */
    @Transactional
    public SettingsDto save(UUID userId, SettingsDto req, Instant now) {
        UserSettings s = repo.findById(userId).orElseGet(() -> new UserSettings(userId, now));

        if (req.updatedAt() != null && s.getUpdatedAt() != null
                && req.updatedAt().isBefore(s.getUpdatedAt())) {
            return toDto(s);
        }

        if (req.units() != null) s.setUnits(req.units());
        if (req.darkMode() != null) s.setDarkMode(req.darkMode());
        if (req.notificationsEnabled() != null) s.setNotificationsEnabled(req.notificationsEnabled());
        if (req.workoutRemindersEnabled() != null) s.setWorkoutRemindersEnabled(req.workoutRemindersEnabled());
        if (req.reminderTime() != null) s.setReminderTime(req.reminderTime());
        if (req.restTimerSound() != null) s.setRestTimerSound(req.restTimerSound());
        if (req.language() != null) s.setLanguage(req.language());
        s.touch(now);

        return toDto(repo.save(s));
    }

    public static SettingsDto toDto(UserSettings s) {
        return new SettingsDto(
                s.getUnits(), s.isDarkMode(), s.isNotificationsEnabled(),
                s.isWorkoutRemindersEnabled(), s.getReminderTime(),
                s.isRestTimerSound(), s.getLanguage(), s.getUpdatedAt());
    }
}
