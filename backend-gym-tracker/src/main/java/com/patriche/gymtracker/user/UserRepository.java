package com.patriche.gymtracker.user;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, UUID> {

    /** Callers must pass a normalized (lowercased) address - see AuthService.normalizeEmail. */
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);
}
