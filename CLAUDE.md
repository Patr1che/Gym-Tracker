# GymTracker — Monorepo

A mobile-first gym workout tracker: workout programs, live sessions with a rest timer, history, personal records, body measurements, and progress charts.

```
gym_tracker/
├── frontend-gym-tracker/   Flutter app (Dart) — the shipped MVP
├── backend-gym-tracker/    Java / Spring Boot API — not built yet
└── docs/BACKEND_GUIDE.md   How to build, connect, and deploy the backend for $0
```

**Work inside one project at a time.** Each has its own toolchain, its own CLAUDE.md, and its own commands. There is no root-level build — nothing at this level compiles or runs.

| I want to… | Go to |
|---|---|
| Change a screen, add an exercise, fix app logic | [frontend-gym-tracker/](frontend-gym-tracker/) — see its [CLAUDE.md](frontend-gym-tracker/CLAUDE.md) |
| Build the API, schema, or auth | [backend-gym-tracker/](backend-gym-tracker/) — see [docs/BACKEND_GUIDE.md](docs/BACKEND_GUIDE.md) |

## Frontend quick reference

Flutter 3.35 / Dart 3.9, Riverpod 3 (Notifier API only), go_router, Hive CE, fl_chart. No codegen anywhere. Flutter is **not on PATH**:

```bash
cd /c/github/gym_tracker/frontend-gym-tracker
/c/src/flutter/bin/flutter analyze && /c/src/flutter/bin/flutter test
```

Full conventions — architecture, units discipline, seed-data rules, testing patterns — are in [frontend-gym-tracker/CLAUDE.md](frontend-gym-tracker/CLAUDE.md). Read that before touching Dart code.

## Backend status

Not started. The folder holds a README pointing at the guide. Planned stack: Java 17+/21, Spring Boot 3.5, PostgreSQL, Flyway, Spring Security + JWT, deployed free on Render + Neon.

## The one architectural rule that spans both

The app is **offline-first**: Hive is the local source of truth and every screen reads it synchronously. When the backend arrives it must be added as a **sync layer**, never as a replacement for local reads — turning repository calls into blocking HTTP requests would put a spinner on every screen and break the app without signal.

Clients generate their own UUIDs (`uuidProvider`), so records created offline already carry their permanent IDs and need no remapping on sync. Keep it that way.

Weights and lengths are **kg and cm everywhere** in storage and domain logic, in both codebases. Convert to lb/inches only at the presentation edge.
