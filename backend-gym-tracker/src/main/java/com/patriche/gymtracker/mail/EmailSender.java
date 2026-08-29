package com.patriche.gymtracker.mail;

/** Sending an email must never be able to fail the request that triggered it. */
public interface EmailSender {

    void send(String to, String subject, String htmlBody);
}
