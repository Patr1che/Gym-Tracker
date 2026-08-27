package com.patriche.gymtracker.favorite;

import com.patriche.gymtracker.common.SyncableEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Embeddable;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

/**
 * A favourited exercise, keyed by (user, exercise). Unfavouriting is a soft delete so the
 * removal propagates to other devices instead of silently reappearing on the next sync.
 */
@Entity
@Table(name = "favorites")
public class Favorite extends SyncableEntity {

    @Embeddable
    public static class Key implements Serializable {

        @Column(name = "user_id")
        private UUID userId;

        @Column(name = "exercise_id")
        private String exerciseId;

        protected Key() {}

        public Key(UUID userId, String exerciseId) {
            this.userId = userId;
            this.exerciseId = exerciseId;
        }

        public UUID getUserId() { return userId; }
        public String getExerciseId() { return exerciseId; }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key other)) return false;
            return Objects.equals(userId, other.userId)
                    && Objects.equals(exerciseId, other.exerciseId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, exerciseId);
        }
    }

    @EmbeddedId
    private Key id;

    protected Favorite() {}

    public Favorite(UUID userId, String exerciseId, Instant now) {
        this.id = new Key(userId, exerciseId);
        touch(now);
    }

    public Key getId() { return id; }
    public String getExerciseId() { return id.getExerciseId(); }
}
