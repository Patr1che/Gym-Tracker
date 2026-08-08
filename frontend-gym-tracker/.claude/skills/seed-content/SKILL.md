---
name: seed-content
description: Add or edit seeded exercises and workout programs in GymTracker. Use when asked to add exercises, change program days, or fix seed content.
---

# Editing seed content

Seed data lives in Dart literals (compile-checked, no assets):

- [lib/seed/exercise_seed_data.dart](lib/seed/exercise_seed_data.dart) — `exerciseSeeds`: 50+ exercise maps
- [lib/seed/program_seed_data.dart](lib/seed/program_seed_data.dart) — `programSeeds`: program → days → `{exerciseId, sets, repsText, restSeconds}`
- [lib/seed/seeder.dart](lib/seed/seeder.dart) — versioned idempotent upsert into Hive

Rules:

1. **Always bump `kSeedVersion`** in [lib/core/constants/app_constants.dart](lib/core/constants/app_constants.dart) after any seed change — otherwise existing installs never receive it. The seeder upserts by stable ID and never touches user boxes (logs, favorites, measurements).
2. IDs are stable and human-readable (`ex_bench_press`, `prog_ppl`). Never rename an existing ID — workout logs and favorites reference them. New exercises: `ex_<snake_case_name>`.
3. Every `exerciseId` referenced by a program day MUST exist in `exerciseSeeds` (program detail resolves it; a missing ID renders a broken row). Grep before saving: `grep -o "ex_[a-z_]*" lib/seed/program_seed_data.dart | sort -u` and check each against exercise_seed_data.dart.
4. The PR feature tracks the key-lift IDs listed in `app_constants.dart` (`ex_bench_press`, `ex_squat`, `ex_deadlift`, `ex_shoulder_press`, `ex_pull_up`) — these five must always exist.
5. Exercise map schema (all keys required): `id, name, muscleGroup (chest|back|shoulders|arms|legs|core|cardio), targetMuscles [..], equipment, difficulty (beginner|intermediate|advanced), description, tips [3], commonMistakes [3], imagePlaceholder (= muscleGroup)`. Optional: `videoId`.

6. **Adding a demo video** — set `'videoId'` to the **11-character YouTube id**, not a full URL:
   ```
   https://www.youtube.com/watch?v=dQw4w9WgXcQ   →   'videoId': 'dQw4w9WgXcQ'
   https://youtu.be/dQw4w9WgXcQ                  →   'videoId': 'dQw4w9WgXcQ'
   ```
   With a `videoId`, the detail screen embeds a player. Without one it falls back to a YouTube search for the exercise name — so leaving it out is always safe. Never paste a search URL or a playlist id; the embedded player only accepts a single video (YouTube removed `listType=search` in 2020).

   Check the video is embeddable before committing it — some uploaders disable embedding, which shows an error inside the player. Open `https://www.youtube.com/embed/<videoId>` in a browser; if it plays there, it will play in the app.
6. After editing: run the `verify` skill; `seeder_test.dart` re-checks idempotency and program→exercise referential integrity.
