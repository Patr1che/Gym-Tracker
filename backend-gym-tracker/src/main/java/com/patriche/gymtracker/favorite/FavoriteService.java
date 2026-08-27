package com.patriche.gymtracker.favorite;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FavoriteService {

    private final FavoriteRepository favorites;

    FavoriteService(FavoriteRepository favorites) {
        this.favorites = favorites;
    }

    @Transactional(readOnly = true)
    public List<String> list(UUID userId) {
        return favorites.findByIdUserIdAndDeletedAtIsNull(userId).stream()
                .map(Favorite::getExerciseId)
                .sorted()
                .toList();
    }

    /** Rows changed since the cursor, tombstones included, for the sync pull. */
    @Transactional(readOnly = true)
    public List<Favorite> changedSince(UUID userId, Instant since) {
        return favorites.findChangedSince(userId, since);
    }

    /**
     * Replaces the whole favourite set. Anything currently stored but absent from the
     * incoming list is tombstoned rather than deleted, so the removal reaches other
     * devices; anything new or previously removed is (re)stored.
     */
    @Transactional
    public List<String> replaceAll(UUID userId, List<String> exerciseIds, Instant now) {
        Set<String> desired = new HashSet<>(exerciseIds == null ? List.of() : exerciseIds);
        List<Favorite> stored = favorites.findByIdUserId(userId);
        Set<String> seen = new HashSet<>();

        for (Favorite f : stored) {
            seen.add(f.getExerciseId());
            boolean wanted = desired.contains(f.getExerciseId());
            if (wanted && f.isDeleted()) {
                f.restore(now);
            } else if (!wanted && !f.isDeleted()) {
                f.softDelete(now);
            }
        }
        favorites.saveAll(stored);

        for (String exerciseId : desired) {
            if (!seen.contains(exerciseId)) {
                favorites.save(new Favorite(userId, exerciseId, now));
            }
        }
        return list(userId);
    }
}
