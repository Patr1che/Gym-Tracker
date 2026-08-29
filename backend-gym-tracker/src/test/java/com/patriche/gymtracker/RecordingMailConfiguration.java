package com.patriche.gymtracker;

import com.patriche.gymtracker.mail.EmailSender;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/** Captures outgoing mail so a test can follow the verification link for real. */
@TestConfiguration
class RecordingMailConfiguration {

    static final List<String> sentBodies = new CopyOnWriteArrayList<>();

    @Bean
    @Primary
    EmailSender recordingEmailSender() {
        return (to, subject, htmlBody) -> sentBodies.add(htmlBody);
    }
}
