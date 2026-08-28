package com.patriche.gymtracker.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * BCrypt with no length limit, so a user's password can be anything they choose.
 *
 * <p>BCrypt itself rejects anything longer than 72 bytes. Rather than impose that as a
 * rule on users, longer passwords are folded to a fixed-size Base64 SHA-256 digest first
 * - the standard pre-hash - and BCrypt is applied to that. Passwords within the limit are
 * passed through untouched, so hashes written before this class existed still verify.
 */
public final class UnboundedBCryptPasswordEncoder implements PasswordEncoder {

    private static final int BCRYPT_MAX_BYTES = 72;

    private final BCryptPasswordEncoder delegate = new BCryptPasswordEncoder();

    @Override
    public String encode(CharSequence rawPassword) {
        return delegate.encode(prepare(rawPassword));
    }

    @Override
    public boolean matches(CharSequence rawPassword, String encodedPassword) {
        return delegate.matches(prepare(rawPassword), encodedPassword);
    }

    @Override
    public boolean upgradeEncoding(String encodedPassword) {
        return delegate.upgradeEncoding(encodedPassword);
    }

    /** Returns the raw password, or its digest when BCrypt could not accept it whole. */
    private static String prepare(CharSequence rawPassword) {
        if (rawPassword == null) return null;
        String raw = rawPassword.toString();
        byte[] bytes = raw.getBytes(StandardCharsets.UTF_8);
        if (bytes.length <= BCRYPT_MAX_BYTES) return raw;
        return Base64.getEncoder().encodeToString(sha256(bytes));
    }

    private static byte[] sha256(byte[] input) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(input);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is required by every JVM", e);
        }
    }
}
