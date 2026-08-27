package com.patriche.gymtracker.user;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.math.BigDecimal;

/**
 * Mirrors UserProfile in the Flutter app. Heights are cm and weights kg - conversion
 * to inches/lb happens only at the app's presentation edge.
 */
@Embeddable
public class UserProfile {

    private String gender;
    private Integer age;

    @Column(name = "height_cm")
    private BigDecimal heightCm;

    @Column(name = "weight_kg")
    private BigDecimal weightKg;

    private String goal;
    private String experience;

    @Column(name = "weekly_frequency")
    private Integer weeklyFrequency;

    protected UserProfile() {}

    public UserProfile(String gender, Integer age, BigDecimal heightCm, BigDecimal weightKg,
                       String goal, String experience, Integer weeklyFrequency) {
        this.gender = gender;
        this.age = age;
        this.heightCm = heightCm;
        this.weightKg = weightKg;
        this.goal = goal;
        this.experience = experience;
        this.weeklyFrequency = weeklyFrequency;
    }

    public String getGender() { return gender; }
    public Integer getAge() { return age; }
    public BigDecimal getHeightCm() { return heightCm; }
    public BigDecimal getWeightKg() { return weightKg; }
    public String getGoal() { return goal; }
    public String getExperience() { return experience; }
    public Integer getWeeklyFrequency() { return weeklyFrequency; }
}
