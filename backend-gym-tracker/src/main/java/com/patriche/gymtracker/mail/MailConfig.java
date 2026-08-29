package com.patriche.gymtracker.mail;

import com.patriche.gymtracker.config.AppProperties;
import jakarta.mail.internet.MimeMessage;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;

/**
 * Picks a sender from configuration. With {@code spring.mail.host} set the real SMTP
 * sender is used; without it - local development, tests, and any deploy where the
 * credentials have not been filled in - the message is written to the log instead, so
 * the flow is exercisable end to end without an email provider.
 */
@Configuration
class MailConfig {

    /**
     * Sends on a small pool of its own, off the request thread.
     *
     * <p>This is not an optimisation, it is a containment boundary. Callers send from
     * inside a transaction, so a send that blocks holds a database connection while it
     * waits; enough of those and the pool is empty and every query in the application
     * queues behind an email server. Handing the work to a bounded executor means the
     * request commits and returns no matter how the provider behaves, and the worst a
     * dead provider can cost is this pool and some undelivered mail.
     *
     * <p>The queue is bounded and overflow is discarded on purpose. Mail is not worth
     * unbounded memory, and a user who never receives a code can ask for another.
     */
    @Bean(destroyMethod = "shutdown")
    @ConditionalOnProperty(name = "spring.mail.host")
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
    @ConditionalOnProperty(name = "spring.mail.host")
    EmailSender smtpEmailSender(JavaMailSender mailSender, AppProperties props,
                                ThreadPoolExecutor mailExecutor) {
        Logger log = LoggerFactory.getLogger("com.patriche.gymtracker.mail.Smtp");
        return (to, subject, htmlBody) -> mailExecutor.execute(() -> {
            try {
                MimeMessage message = mailSender.createMimeMessage();
                MimeMessageHelper helper = new MimeMessageHelper(message, "UTF-8");
                helper.setTo(to);
                helper.setSubject(subject);
                helper.setText(htmlBody, true);
                helper.setFrom(props.mail().from(), props.mail().fromName());
                mailSender.send(message);
            } catch (Exception e) {
                // Nothing to propagate to - the request that asked for this has long
                // since returned. The user can request another code.
                log.warn("Could not send '{}' to {}: {}", subject, to, e.toString());
            }
        });
    }

    @Bean
    @ConditionalOnMissingBean(EmailSender.class)
    EmailSender loggingEmailSender() {
        Logger log = LoggerFactory.getLogger("com.patriche.gymtracker.mail.Logging");
        return (to, subject, htmlBody) ->
                log.info("[no SMTP configured] would send '{}' to {}:\n{}",
                        subject, to, htmlBody);
    }
}
