# GymTracker Frontend — Flutter Gym Workout Tracker MVP

Mobile-first workout tracker: programs, live sessions with rest timer, history, PRs, body measurements, progress charts. Local-only persistence (Hive CE) behind repository abstractions so cloud sync can be added later.

This is the **frontend** half of the `gym_tracker` monorepo. The Java API lives in `../backend-gym-tracker/`; the integration plan is in [../docs/BACKEND_GUIDE.md](../docs/BACKEND_GUIDE.md).

## Commands

Flutter is NOT on PATH, and all commands must run from this directory (`gym_tracker/frontend-gym-tracker`), not the monorepo root:

```bash
# Git Bash
cd /c/github/gym_tracker/frontend-gym-tracker
/c/src/flutter/bin/flutter analyze
/c/src/flutter/bin/flutter test
/c/src/flutter/bin/flutter test test/core/domain/streak_calculator_test.dart   # single file
/c/src/flutter/bin/flutter run -d chrome --web-port 5555   # pinned port keeps IndexedDB data stable
/c/src/flutter/bin/flutter build web --release             # headless full-compile proof
```

PowerShell equivalent: `C:\src\flutter\bin\flutter.bat`. No Visual Studio on this machine — the Windows desktop target is unavailable; verify on Chrome (web). Platforms enabled: web, android.

## Stack

Flutter 3.35 / Dart 3.9 · flutter_riverpod 3.x (Notifier API only — never `StateNotifier`/`StateProvider`/legacy imports) · go_router 17 (redirect guards + `StatefulShellRoute.indexedStack`) · hive_ce (works on web via IndexedDB) · fl_chart · google_fonts · crypto (salted SHA-256, local-only auth).

**No build_runner / codegen anywhere.** Entities are plain immutable classes with manual `toJson`/`fromJson`/`copyWith`, stored as JSON strings in `Box<String>` via the `JsonBox` helper ([lib/core/persistence/json_box.dart](lib/core/persistence/json_box.dart)).

## Architecture

Feature-first: `lib/features/<feature>/{domain,data,presentation}` + shared `lib/core/`.

- `lib/bootstrap.dart` — Hive init → open all boxes → seed → `runApp(ProviderScope)`. Boxes are pre-opened; read them synchronously everywhere after startup.
- `lib/core/domain/` — pure business logic (volume, calories, streak, PRs, validators, unit conversion). No Flutter imports. Every file here has a unit test in `test/core/domain/`.
- `lib/core/widgets/` — the custom design system (GlassCard, AppButton, StatTile, …). Screens compose these; don't hand-roll one-off styled containers in feature code.
- Abstract repository interfaces live in each feature's `domain/`; Hive implementations in `data/`. These interfaces are the future cloud-sync seam — presentation only ever sees the interface via a Riverpod provider.
- `PersonalRecord` is always computed from workout logs on read — never stored.
- Router redirect chain: signed out → `/login`; signed in without profile → `/onboarding`; otherwise shell tabs. `/session` sits on the root navigator (covers the bottom nav).

## Conventions

- **Units: kg and cm everywhere internally.** Convert to lb/inches only in formatters/parsers at the presentation edge (`lib/core/domain/unit_converter.dart`). Never store converted values.
- Emails are lowercased at register AND at every lookup.
- Enums serialize by `.name`; parse with a fallback default, never `firstWhere` without `orElse`.
- Flutter 3.35 APIs: `.withValues(alpha:)` not `withOpacity`; `WidgetState*` not `MaterialState*`; `CardThemeData`; `PopScope.onPopInvokedWithResult`.
- Time and IDs come from `clockProvider` / `uuidProvider` ([lib/core/providers/app_providers.dart](lib/core/providers/app_providers.dart)) so tests can override them — never call `DateTime.now()` or `Uuid()` directly in logic under test.
- Real `BackdropFilter` blur only on static surfaces (bottom nav, headers, overlays); list items use faux glass (translucent fill + hairline border) for web performance.
- Every fl_chart widget guards `< 2` data points with an `EmptyState`.

## Seed data

`lib/seed/` holds ~50 exercises and 3 programs as Dart map literals with stable human-readable IDs (`ex_bench_press`, `prog_ppl`, …). The seeder is versioned and idempotent: bump `kSeedVersion` in [lib/core/constants/app_constants.dart](lib/core/constants/app_constants.dart) after any seed change or it will not re-apply. Program `exerciseId`s must exist in the exercise seeds. Key-lift IDs used by PR detection are constants in `app_constants.dart` — don't rename those exercise IDs.

## Testing

- Domain logic: pure Dart tests, no Flutter binding.
- Repositories/seeder: `Hive.init(tempDir)` in `setUp`.
- Controllers: `ProviderContainer` with repository fakes + `clockProvider` overrides.
- Widgets: `ProviderScope(overrides: [...])` with fakes — never live Hive in widget tests.
