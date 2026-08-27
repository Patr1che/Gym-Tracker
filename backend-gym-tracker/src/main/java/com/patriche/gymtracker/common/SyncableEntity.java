package com.patriche.gymtracker.common;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import java.time.Instant;

/**
 * Shared sync bookkeeping. deleted_at makes deletes soft: a hard delete is invisible to
 * a device that was offline when it happened, so that device would re-upload the row it
 * still has and the record would come back from the dead.
 */
@MappedSuperclass
public abstract class SyncableEntity {

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    public Instant getUpdatedAt() { return updatedAt; }
    public Instant getDeletedAt() { return deletedAt; }
    public boolean isDeleted() { return deletedAt != null; }

    public void touch(Instant now) { this.updatedAt = now; }

    public void softDelete(Instant now) {
        this.deletedAt = now;
        this.updatedAt = now;
    }

    public void restore(Instant now) {
        this.deletedAt = null;
        this.updatedAt = now;
    }
}
