package com.patriche.gymtracker.settings;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * One row per user. Defaults match UserSettings in the Flutter app, so a user who has
 * never opened the settings screen syncs the same values the app would have shown.
 *
 * <p>Not a SyncableEntity: settings are a single row that is always overwritten whole,
 * so there is nothing to tombstone.
 */
@Entity
@Table(name = "user_settings")
public class UserSettings {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(nullable = false)
    private String units = "metric";

    @Column(name = "dark_mode", nullable = false)
    private boolean darkMode = true;

    @Column(name = "notifications_enabled", nullable = false)
    private boolean notificationsEnabled = true;

    @Column(name = "workout_reminders_enabled", nullable = false)
    private boolean workoutRemindersEnabled = true;

    /** 'HH:mm' 24h, stored as text to match the app exactly. */
    @Column(name = "reminder_time", nullable = false)
    private String reminderTime = "18:00";

    @Column(name = "rest_timer_sound", nullable = false)
    private boolean restTimerSound = true;

    @Column(nullable = false)
    private String language = "English";

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.EPOCH;

    protected UserSettings() {}

    public UserSettings(UUID userId, Instant now) {
        this.userId = userId;
        this.updatedAt = now;
    }

    public UUID getUserId() { return userId; }
    public String getUnits() { return units; }
    public boolean isDarkMode() { return darkMode; }
    public boolean isNotificationsEnabled() { return notificationsEnabled; }
    public boolean isWorkoutRemindersEnabled() { return workoutRemindersEnabled; }
    public String getReminderTime() { return reminderTime; }
    public boolean isRestTimerSound() { return restTimerSound; }
    public String getLanguage() { return language; }
    public Instant getUpdatedAt() { return updatedAt; }

    public void setUnits(String v) { this.units = v; }
    public void setDarkMode(boolean v) { this.darkMode = v; }
    public void setNotificationsEnabled(boolean v) { this.notificationsEnabled = v; }
    public void setWorkoutRemindersEnabled(boolean v) { this.workoutRemindersEnabled = v; }
    public void setReminderTime(String v) { this.reminderTime = v; }
    public void setRestTimerSound(boolean v) { this.restTimerSound = v; }
    public void setLanguage(String v) { this.language = v; }
    public void touch(Instant now) { this.updatedAt = now; }
}
