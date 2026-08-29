package com.patriche.gymtracker.mail;

import com.patriche.gymtracker.config.AppProperties;
import jakarta.mail.internet.MimeMessage;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;

/**
 * Chooses how mail leaves the application, and says so at startup.
 *
 * <p>The choice is made in code rather than with {@code @ConditionalOnProperty} because
 * the host is bound as {@code ${MAIL_HOST:}}, so when the variable is unset the property
 * is present and empty rather than absent - and that condition matches. The result was
 * the worst possible one: a deploy with no SMTP configuration silently selected the real
 * sender, which then failed against an empty host with nothing in the log to say why.
 * A blank host now selects the logging sender explicitly, and both paths announce
 * themselves, so "no email arrived" is answerable from the startup log alone.
 */
@Configuration
class MailConfig {

    private static final Logger log = LoggerFactory.getLogger(MailConfig.class);

    /**
     * Sends on a small pool of its own, off the request thread.
     *
     * <p>This is not an optimisation, it is a containment boundary. Callers send from
     * inside a transaction, so a send that blocks holds a database connection while it
     * waits; enough of those and the pool is empty and every query in the application
     * queues behind an email server. Handing the work to a bounded executor means the
     * request commits and returns no matter how the provider behaves.
     *
     * <p>The queue is bounded and overflow is discarded on purpose. Mail is not worth
     * unbounded memory, and a user who never receives a code can ask for another.
     */
    @Bean(destroyMethod = "shutdown")
    ThreadPoolExecutor mailExecutor() {
        return new ThreadPoolExecutor(
                1, 2, 60, TimeUnit.SECONDS,
                new ArrayBlockingQueue<>(50),
                r -> {
                    Thread t = new Thread(r, "mail-sender");
                    t.setDaemon(true);
                    return t;
                },
                new ThreadPoolExecutor.DiscardPolicy());
    }

    @Bean
    EmailSender emailSender(JavaMailSender mailSender, AppProperties props,
                            ThreadPoolExecutor mailExecutor,
                            @Value("${spring.mail.host:}") String host,
                            @Value("${spring.mail.username:}") String username) {
        // Preferred when present: Render blocks outbound SMTP on free web services, so
        // the relay cannot deliver there at all and only HTTPS gets through.
        String apiKey = props.mail().brevoApiKey();
        if (apiKey != null && !apiKey.isBlank()) {
            log.info("Sending verification email via the Brevo API as {}",
                    props.mail().from());
            return new BrevoApiEmailSender(apiKey, props.mail(), mailExecutor);
        }

        if (host == null || host.isBlank()) {
            log.warn("No mail transport configured - verification codes will be written "
                    + "to this log instead of sent. Set BREVO_API_KEY (preferred, and the "
                    + "only option on hosts that block SMTP), or MAIL_HOST with "
                    + "MAIL_USERNAME and MAIL_PASSWORD.");
            return loggingSender();
        }
        if (username == null || username.isBlank()) {
            log.warn("MAIL_HOST is set to {} but MAIL_USERNAME is empty; the provider "
                    + "will almost certainly reject these sends.", host);
        }
        log.warn("Sending verification email over SMTP via {} as {}. Note that hosts "
                + "including Render's free tier block outbound SMTP ports; set "
                + "BREVO_API_KEY to send over HTTPS instead.", host, props.mail().from());
        return smtpSender(mailSender, props, mailExecutor);
    }

    private EmailSender smtpSender(JavaMailSender mailSender, AppProperties props,
                                   ThreadPoolExecutor mailExecutor) {
        Logger smtpLog = LoggerFactory.getLogger("com.patriche.gymtracker.mail.Smtp");
        return (to, subject, htmlBody) -> mailExecutor.execute(() -> {
            try {
                MimeMessage message = mailSender.createMimeMessage();
                MimeMessageHelper helper = new MimeMessageHelper(message, "UTF-8");
                helper.setTo(to);
                helper.setSubject(subject);
                helper.setText(htmlBody, true);
                helper.setFrom(props.mail().from(), props.mail().fromName());
                mailSender.send(message);
                smtpLog.info("Sent '{}' to {}", subject, to);
            } catch (Exception e) {
                // Nothing to propagate to - the request that asked for this returned
                // long ago - so this log line is the only evidence a send failed.
                // Logged at error precisely because it is otherwise invisible.
                smtpLog.error("Could not send '{}' to {}: {}", subject, to, e.toString());
            }
        });
    }

    private EmailSender loggingSender() {
        Logger noSmtp = LoggerFactory.getLogger("com.patriche.gymtracker.mail.Logging");
        return (to, subject, htmlBody) ->
                noSmtp.info("[no SMTP configured] would send '{}' to {}:\n{}",
                        subject, to, htmlBody);
    }
}
