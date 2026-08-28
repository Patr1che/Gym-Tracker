package com.patriche.gymtracker.auth;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /**
     * Removes tokens that can never authenticate again - expired, or revoked by a logout
     * or a rotation. A revoked token is safe to delete rather than keep: presenting one
     * already fails, and it fails with the same "Invalid refresh token" whether the row
     * is revoked or absent, so nothing observable changes.
     *
     * <p>A single bulk statement, not a load-then-delete, so the work stays on the
     * database and does not scale with the number of rows removed.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("delete from RefreshToken t where t.expiresAt < :now or t.revokedAt is not null")
    int deleteSpent(@Param("now") Instant now);
}
