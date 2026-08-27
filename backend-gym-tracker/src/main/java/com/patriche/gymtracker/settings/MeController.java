package com.patriche.gymtracker.settings;

import com.patriche.gymtracker.favorite.FavoriteService;
import com.patriche.gymtracker.settings.SettingsService.SettingsDto;
import com.patriche.gymtracker.user.CurrentUser;
import java.time.Instant;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Settings and favourites, both scoped to the authenticated user. */
@RestController
@RequestMapping("/api/v1")
class MeController {

    private final SettingsService settings;
    private final FavoriteService favorites;

    MeController(SettingsService settings, FavoriteService favorites) {
        this.settings = settings;
        this.favorites = favorites;
    }

    @GetMapping("/me/settings")
    SettingsDto getSettings() {
        return settings.load(CurrentUser.id(), Instant.now());
    }

    @PutMapping("/me/settings")
    SettingsDto putSettings(@RequestBody SettingsDto req) {
        return settings.save(CurrentUser.id(), req, Instant.now());
    }

    @GetMapping("/favorites")
    List<String> getFavorites() {
        return favorites.list(CurrentUser.id());
    }

    /** Whole-set replace - the app holds favourites as one Set per user. */
    @PutMapping("/favorites")
    List<String> putFavorites(@RequestBody List<String> exerciseIds) {
        return favorites.replaceAll(CurrentUser.id(), exerciseIds, Instant.now());
    }
}
