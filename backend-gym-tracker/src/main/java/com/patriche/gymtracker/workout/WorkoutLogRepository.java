package com.patriche.gymtracker.workout;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, UUID> {

    /** Always scoped by user id, taken from the JWT - never from the request. */
    Optional<WorkoutLog> findByIdAndUserId(UUID id, UUID userId);

    List<WorkoutLog> findByUserIdAndDeletedAtIsNullOrderByStartedAtDesc(UUID userId);

    /**
     * The sync pull. Includes tombstones on purpose: a device that was offline when a
     * record was deleted only learns about the delete by receiving the tombstone.
     */
    @Query("""
           SELECT w FROM WorkoutLog w
           WHERE w.userId = :userId AND w.updatedAt > :since
           ORDER BY w.updatedAt ASC
           """)
    List<WorkoutLog> findChangedSince(@Param("userId") UUID userId,
                                      @Param("since") Instant since);

    /**
     * Reaps tombstones no device can still need. exercise_logs and set_logs go with
     * them: the delete is issued as SQL, so the ON DELETE CASCADE in V1 does the rest,
     * which is where the real space is - a workout's sets outnumber its parent row
     * roughly twenty-four to one.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("delete from WorkoutLog w where w.deletedAt is not null and w.deletedAt < :before")
    int deleteTombstonesBefore(@Param("before") Instant before);
}
