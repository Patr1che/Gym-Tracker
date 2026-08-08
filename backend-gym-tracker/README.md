# GymTracker Backend

Java / Spring Boot API for the GymTracker app. **Not built yet — this folder is a placeholder.**

The complete build and deployment plan lives in [../docs/BACKEND_GUIDE.md](../docs/BACKEND_GUIDE.md): schema, endpoints, auth, the sync design, tests, and free hosting.

## Planned stack

| Concern | Choice |
|---|---|
| Language | Java 21 LTS (17 works — that's what's installed) |
| Framework | Spring Boot 3.5.x |
| Build | Maven (wrapper included, no install needed) |
| Database | PostgreSQL 16 |
| Migrations | Flyway |
| Auth | Spring Security + JWT, BCrypt passwords |
| Tests | JUnit 5 + Testcontainers |
| Hosting | Render (app) + Neon (Postgres) — both free tier |

## Getting started

Scaffold into **this folder** (see the guide's Phase 1 for the full dependency list):

```bash
cd /c/github/gym_tracker
curl https://start.spring.io/starter.zip \
  -d type=maven-project -d language=java -d bootVersion=3.5.0 \
  -d javaVersion=17 -d groupId=com.patriche -d artifactId=backend-gym-tracker \
  -d packageName=com.patriche.gymtracker \
  -d dependencies=web,data-jpa,postgresql,flyway,security,validation,lombok,testcontainers,actuator \
  -o backend.zip
unzip backend.zip -d backend-gym-tracker && rm backend.zip
```

Then start a local Postgres and run it:

```bash
cd backend-gym-tracker
docker compose up -d
./mvnw spring-boot:run
curl localhost:8080/actuator/health
```

## Non-negotiables

These are the mistakes that cause real damage — the guide explains each:

- Scope every query by the user id **from the JWT**, never from the request body
- Use idempotent `PUT` with the client's UUID, not `POST` (mobile networks retry)
- Recompute volume and calorie totals server-side; never trust client numbers
- Soft-delete only (`deleted_at`) — hard deletes get resurrected by offline devices
- `ddl-auto: validate` in production; Flyway owns the schema
- Store weights in **kg**, lengths in **cm** — matching the app
- Treat exercise IDs (`ex_bench_press`) as permanent; existing logs reference them by string
