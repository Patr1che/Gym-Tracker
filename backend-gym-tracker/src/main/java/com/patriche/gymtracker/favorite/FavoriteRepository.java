package com.patriche.gymtracker.favorite;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FavoriteRepository extends JpaRepository<Favorite, Favorite.Key> {

    List<Favorite> findByIdUserId(UUID userId);

    List<Favorite> findByIdUserIdAndDeletedAtIsNull(UUID userId);

    /** Includes tombstones so an unfavourite propagates to a device that was offline. */
    @Query("""
           SELECT f FROM Favorite f
           WHERE f.id.userId = :userId AND f.updatedAt > :since
           ORDER BY f.updatedAt ASC
           """)
    List<Favorite> findChangedSince(@Param("userId") UUID userId,
                                    @Param("since") Instant since);

    /** See WorkoutLogRepository#deleteTombstonesBefore. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("delete from Favorite f where f.deletedAt is not null and f.deletedAt < :before")
    int deleteTombstonesBefore(@Param("before") Instant before);
}
