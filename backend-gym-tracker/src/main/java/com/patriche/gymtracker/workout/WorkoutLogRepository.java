package com.patriche.gymtracker.workout;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
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
}
