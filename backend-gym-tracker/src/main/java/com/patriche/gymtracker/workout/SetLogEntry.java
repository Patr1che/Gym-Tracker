package com.patriche.gymtracker.workout;

import jakarta.persistence.*;
import java.math.BigDecimal;

/** One set. sort_order is persisted because the Dart model relies on list position. */
@Entity
@Table(name = "set_logs")
public class SetLogEntry {

    /**
     * SEQUENCE, not IDENTITY: identity ids come back one row at a time, which stops
     * Hibernate batching inserts. allocationSize must equal the sequence's INCREMENT BY
     * in V3__minimize_free_tier_footprint.sql.
     */
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "set_logs_seq")
    @SequenceGenerator(name = "set_logs_seq", sequenceName = "set_logs_id_seq",
                       allocationSize = 50)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "exercise_log_id", nullable = false)
    private ExerciseLogEntry exerciseLog;

    @Column(name = "weight_kg", nullable = false)
    private BigDecimal weightKg = BigDecimal.ZERO;

    @Column(nullable = false)
    private int reps;

    @Column(nullable = false)
    private boolean completed;

    @Column(nullable = false)
    private boolean skipped;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    protected SetLogEntry() {}

    public SetLogEntry(ExerciseLogEntry parent, BigDecimal weightKg, int reps,
                       boolean completed, boolean skipped, int sortOrder) {
        this.exerciseLog = parent;
        this.weightKg = weightKg == null ? BigDecimal.ZERO : weightKg;
        this.reps = reps;
        this.completed = completed;
        this.skipped = skipped;
        this.sortOrder = sortOrder;
    }

    /** Mirrors SetLog.counts in the Dart model. */
    public boolean counts() { return completed && !skipped; }

    public BigDecimal getWeightKg() { return weightKg; }
    public int getReps() { return reps; }
    public boolean isCompleted() { return completed; }
    public boolean isSkipped() { return skipped; }
    public int getSortOrder() { return sortOrder; }
}
