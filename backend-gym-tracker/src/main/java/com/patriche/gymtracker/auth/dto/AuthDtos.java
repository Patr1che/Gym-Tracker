package com.patriche.gymtracker.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class AuthDtos {

    private AuthDtos() {}

    public record RegisterRequest(
            @NotBlank @Size(max = 80) String name,
            @NotBlank @Email @Size(max = 254) String email,
            @NotBlank @Size(min = 8, max = 128) String password) {}

    public record LoginRequest(
            @NotBlank @Email String email,
            @NotBlank String password) {}

    public record RefreshRequest(@NotBlank String refreshToken) {}

    public record ForgotPasswordRequest(@NotBlank @Email String email) {}

    public record TokenPair(String accessToken, String refreshToken, UserResponse user) {}

    public record ProfileResponse(
            String gender, Integer age, Double heightCm, Double weightKg,
            String goal, String experience, Integer weeklyFrequency) {}

    public record UserResponse(
            UUID id, String name, String email, Instant createdAt,
            int photoSeed, ProfileResponse profile) {}
}
