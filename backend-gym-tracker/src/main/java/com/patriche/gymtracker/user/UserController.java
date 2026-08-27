package com.patriche.gymtracker.user;

import com.patriche.gymtracker.auth.AuthService;
import com.patriche.gymtracker.auth.dto.AuthDtos.UserResponse;
import com.patriche.gymtracker.common.ApiException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/me")
class UserController {

    /** Every field optional: onboarding sends the profile, the profile screen sends a name. */
    record UpdateMeRequest(
            @Size(max = 80) String name,
            String gender,
            @Min(10) @Max(120) Integer age,
            BigDecimal heightCm,
            BigDecimal weightKg,
            String goal,
            String experience,
            @Min(1) @Max(14) Integer weeklyFrequency) {

        boolean hasProfileFields() {
            return gender != null || age != null || heightCm != null || weightKg != null
                    || goal != null || experience != null || weeklyFrequency != null;
        }
    }

    private final UserRepository users;

    UserController(UserRepository users) {
        this.users = users;
    }

    @GetMapping
    UserResponse me() {
        return AuthService.toResponse(load());
    }

    @PatchMapping
    @Transactional
    UserResponse updateMe(@Valid @RequestBody UpdateMeRequest req) {
        User user = load();
        if (req.name() != null && !req.name().isBlank()) {
            user.setName(req.name().trim());
        }
        if (req.hasProfileFields()) {
            UserProfile existing = user.getProfile();
            user.setProfile(new UserProfile(
                    pick(req.gender(), existing == null ? null : existing.getGender()),
                    pick(req.age(), existing == null ? null : existing.getAge()),
                    pick(req.heightCm(), existing == null ? null : existing.getHeightCm()),
                    pick(req.weightKg(), existing == null ? null : existing.getWeightKg()),
                    pick(req.goal(), existing == null ? null : existing.getGoal()),
                    pick(req.experience(), existing == null ? null : existing.getExperience()),
                    pick(req.weeklyFrequency(),
                         existing == null ? null : existing.getWeeklyFrequency())));
        }
        user.touch(Instant.now());
        return AuthService.toResponse(user);
    }

    private static <T> T pick(T incoming, T existing) {
        return incoming != null ? incoming : existing;
    }

    private User load() {
        return users.findById(CurrentUser.id())
                .orElseThrow(() -> ApiException.notFound("User not found"));
    }
}
