package com.patriche.gymtracker.auth;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface VerificationCodeRepository extends JpaRepository<VerificationCode, UUID> {

    /** Newest first: only the most recent code for an account is ever live. */
    List<VerificationCode> findByUserIdOrderByCreatedAtDesc(UUID userId);

    /** Expired or already redeemed: nothing can be done with either again. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("delete from VerificationCode c "
            + "where c.expiresAt < :now or c.consumedAt is not null")
    int deleteSpent(@Param("now") Instant now);
}
