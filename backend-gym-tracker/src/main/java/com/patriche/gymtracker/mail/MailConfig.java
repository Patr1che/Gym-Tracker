package com.patriche.gymtracker.mail;

import com.patriche.gymtracker.config.AppProperties;
import jakarta.mail.internet.MimeMessage;
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
 * credentials have not been filled in - the link is written to the log instead, so the
 * flow is exercisable end to end without an email provider.
 */
@Configuration
class MailConfig {

    @Bean
    @ConditionalOnProperty(name = "spring.mail.host")
    EmailSender smtpEmailSender(JavaMailSender mailSender, AppProperties props) {
        Logger log = LoggerFactory.getLogger("com.patriche.gymtracker.mail.Smtp");
        return (to, subject, htmlBody) -> {
            try {
                MimeMessage message = mailSender.createMimeMessage();
                MimeMessageHelper helper = new MimeMessageHelper(message, "UTF-8");
                helper.setTo(to);
                helper.setSubject(subject);
                helper.setText(htmlBody, true);
                helper.setFrom(props.mail().from(), props.mail().fromName());
                mailSender.send(message);
            } catch (Exception e) {
                // Swallowed on purpose. A provider outage must not fail a registration:
                // the account exists, and the user can ask for another link.
                log.warn("Could not send '{}' to {}: {}", subject, to, e.toString());
            }
        };
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
