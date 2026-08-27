package com.patriche.gymtracker.workout;

import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "exercise_logs")
public class ExerciseLogEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_log_id", nullable = false)
    private WorkoutLog workoutLog;

    /**
     * Free TEXT with no foreign key on purpose: the exercise catalog lives in the app's
     * bundled seed data, so a log must not fail to sync because the server has never
     * heard of the exercise.
     */
    @Column(name = "exercise_id", nullable = false)
    private String exerciseId;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @OneToMany(mappedBy = "exerciseLog", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<SetLogEntry> sets = new ArrayList<>();

    protected ExerciseLogEntry() {}

    public ExerciseLogEntry(WorkoutLog parent, String exerciseId, int sortOrder) {
        this.workoutLog = parent;
        this.exerciseId = exerciseId;
        this.sortOrder = sortOrder;
    }

    public String getExerciseId() { return exerciseId; }
    public int getSortOrder() { return sortOrder; }
    public List<SetLogEntry> getSets() { return sets; }
    public void addSet(SetLogEntry set) { sets.add(set); }
}
