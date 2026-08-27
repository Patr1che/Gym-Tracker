package com.patriche.gymtracker.measurement;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MeasurementRepository extends JpaRepository<Measurement, UUID> {

    /** Always scoped by user id, taken from the JWT - never from the request. */
    Optional<Measurement> findByIdAndUserId(UUID id, UUID userId);

    List<Measurement> findByUserIdAndDeletedAtIsNullOrderByDateDesc(UUID userId);

    /**
     * The sync pull. Includes tombstones on purpose: a device that was offline when a
     * record was deleted only learns about the delete by receiving the tombstone.
     */
    @Query("""
           SELECT m FROM Measurement m
           WHERE m.userId = :userId AND m.updatedAt > :since
           ORDER BY m.updatedAt ASC
           """)
    List<Measurement> findChangedSince(@Param("userId") UUID userId,
                                       @Param("since") Instant since);
}
