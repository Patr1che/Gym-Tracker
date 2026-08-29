package com.patriche.gymtracker.auth;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

/** A six-digit email-verification code. Single use, short lived, attempt limited. */
@Entity
@Table(name = "verification_codes")
public class VerificationCode {

    /** Six digits is a million guesses, which is nothing without this cap. */
    public static final int MAX_ATTEMPTS = 5;

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "consumed_at")
    private Instant consumedAt;

    @Column(nullable = false)
    private int attempts;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected VerificationCode() {}

    public VerificationCode(UUID id, UUID userId, String codeHash, Instant expiresAt,
                            Instant now) {
        this.id = id;
        this.userId = userId;
        this.codeHash = codeHash;
        this.expiresAt = expiresAt;
        this.createdAt = now;
    }

    public UUID getUserId() { return userId; }
    public Instant getCreatedAt() { return createdAt; }
    public int getAttempts() { return attempts; }

    public boolean isUsableAt(Instant now) {
        return consumedAt == null && attempts < MAX_ATTEMPTS && now.isBefore(expiresAt);
    }

    public boolean matches(String candidateHash) {
        return codeHash.equals(candidateHash);
    }

    /** Counts a wrong guess, and burns the code once the budget is spent. */
    public void recordFailure(Instant now) {
        attempts++;
        if (attempts >= MAX_ATTEMPTS) consume(now);
    }

    public void consume(Instant now) {
        if (consumedAt == null) this.consumedAt = now;
    }
}
