package com.patriche.gymtracker.auth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class UnboundedBCryptPasswordEncoderTest {

    private final UnboundedBCryptPasswordEncoder encoder = new UnboundedBCryptPasswordEncoder();

    @Test
    void acceptsAnyPasswordTheUserChooses() {
        for (String raw : new String[] {"a", " ", "12345678", "no-digits-here", "p".repeat(5000)}) {
            String hash = encoder.encode(raw);
            assertThat(encoder.matches(raw, hash)).as(raw.length() + "-char password").isTrue();
        }
    }

    @Test
    void rejectsTheWrongPasswordBeyondTheBcryptLimit() {
        String hash = encoder.encode("x".repeat(200));
        assertThat(encoder.matches("y".repeat(200), hash)).isFalse();
    }

    @Test
    void staysCompatibleWithHashesWrittenByPlainBcrypt() {
        String legacy = new BCryptPasswordEncoder().encode("secret123");
        assertThat(encoder.matches("secret123", legacy)).isTrue();
        assertThat(encoder.matches("wrong", legacy)).isFalse();
    }
}
