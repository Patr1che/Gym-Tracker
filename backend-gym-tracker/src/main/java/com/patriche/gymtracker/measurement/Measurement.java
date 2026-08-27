package com.patriche.gymtracker.measurement;

import com.patriche.gymtracker.common.SyncableEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * A body-measurement entry. Every metric is nullable: the app lets you record just a
 * weight one day and a full set the next.
 *
 * <p>Weights are kg and lengths cm, matching the app's storage. Conversion to lb/inches
 * happens only at the presentation edge.
 */
@Entity
@Table(name = "measurements")
public class Measurement extends SyncableEntity {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private Instant date;

    @Column(name = "weight_kg")
    private BigDecimal weightKg;

    @Column(name = "body_fat_pct")
    private BigDecimal bodyFatPct;

    @Column(name = "chest_cm")
    private BigDecimal chestCm;

    @Column(name = "waist_cm")
    private BigDecimal waistCm;

    @Column(name = "arms_cm")
    private BigDecimal armsCm;

    @Column(name = "legs_cm")
    private BigDecimal legsCm;

    @Column(name = "shoulders_cm")
    private BigDecimal shouldersCm;

    @Column(name = "neck_cm")
    private BigDecimal neckCm;

    @Column(name = "hips_cm")
    private BigDecimal hipsCm;

    protected Measurement() {}

    public Measurement(UUID id, UUID userId) {
        this.id = id;
        this.userId = userId;
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public Instant getDate() { return date; }
    public BigDecimal getWeightKg() { return weightKg; }
    public BigDecimal getBodyFatPct() { return bodyFatPct; }
    public BigDecimal getChestCm() { return chestCm; }
    public BigDecimal getWaistCm() { return waistCm; }
    public BigDecimal getArmsCm() { return armsCm; }
    public BigDecimal getLegsCm() { return legsCm; }
    public BigDecimal getShouldersCm() { return shouldersCm; }
    public BigDecimal getNeckCm() { return neckCm; }
    public BigDecimal getHipsCm() { return hipsCm; }

    public void setDate(Instant date) { this.date = date; }
    public void setWeightKg(BigDecimal v) { this.weightKg = v; }
    public void setBodyFatPct(BigDecimal v) { this.bodyFatPct = v; }
    public void setChestCm(BigDecimal v) { this.chestCm = v; }
    public void setWaistCm(BigDecimal v) { this.waistCm = v; }
    public void setArmsCm(BigDecimal v) { this.armsCm = v; }
    public void setLegsCm(BigDecimal v) { this.legsCm = v; }
    public void setShouldersCm(BigDecimal v) { this.shouldersCm = v; }
    public void setNeckCm(BigDecimal v) { this.neckCm = v; }
    public void setHipsCm(BigDecimal v) { this.hipsCm = v; }
}
