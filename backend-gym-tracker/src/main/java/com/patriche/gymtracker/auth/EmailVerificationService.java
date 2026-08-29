package com.patriche.gymtracker.auth;

import com.patriche.gymtracker.common.ApiException;
import com.patriche.gymtracker.config.AppProperties;
import com.patriche.gymtracker.mail.EmailSender;
import com.patriche.gymtracker.user.User;
import com.patriche.gymtracker.user.UserRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Issues and checks six-digit email-verification codes.
 *
 * <p>Verification gates sync, never sign-in - see V4__email_verification.sql. An
 * unverified user has the entire offline app; what they do not have is server storage.
 */
@Service
public class EmailVerificationService {

    private static final Logger log = LoggerFactory.getLogger(EmailVerificationService.class);

    private final UserRepository users;
    private final VerificationCodeRepository codes;
    private final EmailSender email;
    private final AppProperties.Mail config;
    private final SecureRandom random = new SecureRandom();

    EmailVerificationService(UserRepository users, VerificationCodeRepository codes,
                             EmailSender email, AppProperties props) {
        this.users = users;
        this.codes = codes;
        this.email = email;
        this.config = props.mail();
    }

    /** Issues a code and mails it. Failures are logged, never thrown at the caller. */
    @Transactional
    public void sendCode(User user, Instant now) {
        if (user.isEmailVerified()) return;

        // Any older code stops working the moment a new one is sent, so a code that was
        // forwarded or read over a shoulder cannot be used after the user asks again.
        codes.findByUserIdOrderByCreatedAtDesc(user.getId())
                .forEach(c -> c.consume(now));

        String code = newCode();
        codes.save(new VerificationCode(UUID.randomUUID(), user.getId(), hash(code),
                now.plus(Duration.ofMinutes(config.codeTtlMinutes())), now));

        email.send(user.getEmail(), "Your GymTracker verification code",
                body(user.getName(), code));
    }

    /**
     * Checks a code for the signed-in account and marks it verified.
     *
     * <p>The account comes from the caller's JWT, never from the code, so a code is only
     * ever tested against the one user it was issued for - there is no way to try one
     * guess against every account at once.
     */
    @Transactional
    public User verify(UUID userId, String submitted, Instant now) {
        User user = users.findById(userId)
                .orElseThrow(() -> ApiException.notFound("Account not found"));
        if (user.isEmailVerified()) return user;

        VerificationCode code = codes.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .findFirst()
                .orElseThrow(() -> ApiException.badRequest(
                        "Ask for a new code - this one is no longer valid."));

        if (!code.isUsableAt(now)) {
            throw ApiException.badRequest(
                    "That code has expired or was tried too many times. Ask for a new one.");
        }

        if (!code.matches(hash(submitted.trim()))) {
            code.recordFailure(now);
            int left = VerificationCode.MAX_ATTEMPTS - code.getAttempts();
            throw ApiException.badRequest(left > 0
                    ? "That code is not right. " + left + " attempts left."
                    : "Too many attempts. Ask for a new code.");
        }

        code.consume(now);
        user.markEmailVerified();
        log.info("Email verified for user {}", userId);
        return user;
    }

    /**
     * Re-sends a code, throttled. Without a cooldown a bored client could spend the
     * provider's daily allowance in a minute and leave real sign-ups unable to verify.
     */
    @Transactional
    public void resend(UUID userId, Instant now) {
        User user = users.findById(userId)
                .orElseThrow(() -> ApiException.notFound("Account not found"));
        if (user.isEmailVerified()) return;

        Duration cooldown = Duration.ofMinutes(config.resendCooldownMinutes());
        List<VerificationCode> issued = codes.findByUserIdOrderByCreatedAtDesc(userId);
        if (!issued.isEmpty() && issued.get(0).getCreatedAt().isAfter(now.minus(cooldown))) {
            throw ApiException.tooManyRequests(
                    "A code was just sent. Check your inbox, then try again in a few minutes.");
        }
        sendCode(user, now);
    }

    /** Six digits, zero padded, from a source suitable for secrets. */
    private String newCode() {
        return String.format("%06d", random.nextInt(1_000_000));
    }

    private static String hash(String code) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(code.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is required by every JVM", e);
        }
    }

    private String body(String name, String code) {
        return """
               <div style="font-family:system-ui,sans-serif;line-height:1.6;color:#111">
                 <h2>Your verification code</h2>
                 <p>Hi %s, enter this code in GymTracker to confirm your email:</p>
                 <p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:24px 0">
                    %s</p>
                 <p style="color:#666;font-size:14px">The code expires in %d minutes.
                    You can keep training either way - confirming is what lets your data
                    sync across devices.</p>
               </div>
               """.formatted(name, code, config.codeTtlMinutes());
    }
}
