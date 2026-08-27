# GymTracker Java Backend — Build & Deploy Guide

> **Status note - updated 2026-08-28.** Phases 1-7 of this guide are now built and
> passing in `backend-gym-tracker/`. Reality diverged from the original text in a few
> places; where they disagree, the code is right:
>
> | Guide said | Actually built | Why |
> |---|---|---|
> | Spring Boot 3.5.0 | **Spring Boot 4.1.1** | start.spring.io no longer serves 3.x - its compatibility range is >=4.0.0. Boot 4 renames the starters (`spring-boot-starter-webmvc`, per-starter `-test` artifacts) and ships Jackson 3 under `tools.jackson`. |
> | springdoc 2.8.0 | **springdoc 3.1.0** | 2.x targets Boot 3. |
> | `email CITEXT` | **`email TEXT` + `UNIQUE INDEX ON lower(email)`** | citext reports as `Types#OTHER` over JDBC, which `ddl-auto: validate` rejects against a `String` field. The functional index gives the same case-insensitive guarantee with no extension. |
> | `users.photo_url TEXT` | **`photo_seed INTEGER`** | The app's `User` carries a `photoSeed` int that seeds a generated avatar, not a URL. |
> | `users.salt` column | **dropped** | BCrypt embeds its own salt. |
> | Postgres on 5432, app on 8080 | **5433 / 8097 locally** | Another local stack already holds 5432 and 8080. Only defaults changed; `DATABASE_URL` and `PORT` still drive deployment. |
> | Catalog moves to the server | **still client-side** | Out of scope for this pass. `exercise_id` and `program_id` are unconstrained `TEXT` with no FK, so a workout log can never fail to sync because the server's catalog lags the app's bundled seeds. |
>
> Not yet built: custom-program sync, per-user exercise video sync, active-session sync,
> real password-reset email delivery, and the Flutter sync layer (phase 8 below).

A step-by-step plan for adding a Java backend to the GymTracker Flutter app and shipping it to production.

**Your machine already has:** Java 17.0.12 (Spring Boot 3 needs 17+ ✅), Docker ✅, Git ✅.
**You do NOT need to install:** Maven (the project ships a wrapper), Postgres (runs in Docker), or an IDE beyond what you use now.

---

## 0. The most important decision first

The Flutter app is **offline-first** today: Hive is the source of truth, every screen reads it synchronously, and workouts work in a gym basement with no signal.

The naive way to add a backend — replace each repository with HTTP calls — would **make the app worse**: every screen gets a loading spinner, and the app breaks without signal. That is the single biggest mistake to avoid.

**Do this instead:** keep Hive as the local source of truth and add a *sync layer* on top.

```
UI  →  Riverpod  →  Repository interface  →  Hive (instant reads/writes)
                                              ↓
                                        SyncService  ⇄  Java API  ⇄  Postgres
```

Every mutable record gets `updatedAt` + a local `dirty` flag. Sync pushes dirty records and pulls anything changed since the last cursor. The app stays fast and offline-capable; the server becomes the durable, multi-device copy.

This is why the app uses `uuidProvider` for IDs — **clients generate their own UUIDs**, so records created offline already have their final, permanent ID. No ID remapping on sync. Keep it that way.

---

## 1. Tech stack

| Concern | Choice | Why |
|---|---|---|
| Language | **Java 21 LTS** (17 also works) | 21 adds virtual threads; your installed 17 is fine to start |
| Framework | **Spring Boot 3.5.x** | The default for Java REST APIs; huge ecosystem |
| Build | **Maven** (wrapper included) | Ubiquitous; `./mvnw` needs no install. Gradle is fine if you prefer it |
| Database | **PostgreSQL 16** | Relational fits this data (users → workouts → exercises → sets) |
| ORM | **Spring Data JPA** (Hibernate) | Repository pattern maps cleanly to what the app already has |
| Migrations | **Flyway** | Versioned SQL. Never let Hibernate auto-create production schema |
| Auth | **Spring Security + JWT** (jjwt 0.12.x) | Stateless; no server session store |
| Passwords | **BCrypt** | Replaces the app's local SHA-256. Never ship SHA-256 to a server |
| Validation | **Jakarta Bean Validation** | Mirrors the app's `Validators` |
| API docs | **springdoc-openapi** | Free Swagger UI at `/swagger-ui.html` |
| Tests | **JUnit 5 + Testcontainers** | Tests run against a real Postgres in Docker |
| Container | **Docker** (multi-stage build) | Same artifact locally and in prod |

**Where to put it:** `c:\github\gym_tracker\backend-gym-tracker\` — the monorepo already has the folder waiting, alongside `frontend-gym-tracker/`.

---

## 2. Phase-by-phase build

Each phase ends with something you can run and verify. Don't skip the verification steps.

### Phase 1 — Scaffold the project

Generate from [start.spring.io](https://start.spring.io) (or the web UI) with these dependencies:

```
Web, Spring Data JPA, PostgreSQL Driver, Flyway Migration,
Spring Security, Validation, Lombok, Testcontainers, Actuator
```

Or via curl:

```bash
cd /c/github/gym_tracker
curl https://start.spring.io/starter.zip \
  -d type=maven-project -d language=java -d bootVersion=3.5.0 \
  -d javaVersion=17 -d groupId=com.patriche -d artifactId=backend-gym-tracker \
  -d name=backend-gym-tracker -d packageName=com.patriche.gymtracker \
  -d dependencies=web,data-jpa,postgresql,flyway,security,validation,lombok,testcontainers,actuator \
  -o backend.zip
unzip backend.zip -d backend-gym-tracker && rm backend.zip
```

Add to `pom.xml` what the initializr doesn't include:

```xml
<dependency>
  <groupId>io.jsonwebtoken</groupId><artifactId>jjwt-api</artifactId><version>0.12.6</version>
</dependency>
<dependency>
  <groupId>io.jsonwebtoken</groupId><artifactId>jjwt-impl</artifactId><version>0.12.6</version><scope>runtime</scope>
</dependency>
<dependency>
  <groupId>io.jsonwebtoken</groupId><artifactId>jjwt-jackson</artifactId><version>0.12.6</version><scope>runtime</scope>
</dependency>
<dependency>
  <groupId>org.springdoc</groupId>
  <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId><version>2.8.0</version>
</dependency>
<dependency>
  <groupId>org.flywaydb</groupId><artifactId>flyway-database-postgresql</artifactId>
</dependency>
```

**Package layout** — mirror the app's feature-first structure so the two codebases read alike:

```
src/main/java/com/patriche/gymtracker/
├── GymTrackerApiApplication.java
├── common/          # error handling, base entities, pagination, sync DTOs
├── config/          # SecurityConfig, CorsConfig, OpenApiConfig, JacksonConfig
├── auth/            # controller, service, JwtService, JwtAuthFilter, dtos
├── user/            # User entity, profile + settings endpoints
├── catalog/         # Exercise + Program entities (seeded, read-only to clients)
├── workout/         # WorkoutLog, ExerciseLog, SetLog
├── measurement/     # MeasurementEntry
└── sync/            # the batch sync endpoint
```

**Verify:** `./mvnw spring-boot:run` starts and `curl localhost:8080/actuator/health` returns `{"status":"UP"}`.

---

### Phase 2 — Database and schema

Local Postgres via Docker — create `docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: gymtracker
      POSTGRES_USER: gym
      POSTGRES_PASSWORD: gym
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]
volumes: { pgdata: }
```

```bash
docker compose up -d
```

`src/main/resources/application.yml`:

```yaml
spring:
  datasource:
    url: ${DATABASE_URL:jdbc:postgresql://localhost:5432/gymtracker}
    username: ${DB_USER:gym}
    password: ${DB_PASSWORD:gym}
  jpa:
    hibernate.ddl-auto: validate   # Flyway owns the schema — never 'update' in prod
    open-in-view: false
  flyway:
    enabled: true
app:
  jwt:
    secret: ${JWT_SECRET:change-me-locally-only-min-32-bytes-long}
    access-ttl-minutes: 15
    refresh-ttl-days: 30
  cors:
    allowed-origins: ${CORS_ORIGINS:http://localhost:5555}
```

**Schema** — `src/main/resources/db/migration/V1__init.sql`. Key design points:

- **Exercise and program IDs stay TEXT** (`ex_bench_press`, `prog_ppl`). Workout logs and favorites in existing installs already reference those strings — changing them to numeric IDs would orphan every user's history.
- **User data IDs are UUIDs generated by the client**, so offline-created rows keep their identity.
- Every syncable table carries `updated_at` and a nullable `deleted_at` (soft delete, so deletions propagate to other devices).

```sql
CREATE EXTENSION IF NOT EXISTS "citext";

CREATE TABLE users (
    id                UUID PRIMARY KEY,
    name              TEXT        NOT NULL,
    email             CITEXT      NOT NULL UNIQUE,   -- case-insensitive, matches app behavior
    password_hash     TEXT        NOT NULL,
    photo_url         TEXT,
    -- profile (all NULL until onboarding completes)
    gender            TEXT,
    age               INT,
    height_cm         NUMERIC(5,1),
    weight_kg         NUMERIC(5,1),
    goal              TEXT,
    experience        TEXT,
    weekly_frequency  INT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE exercises (
    id               TEXT PRIMARY KEY,          -- 'ex_bench_press'
    name             TEXT NOT NULL,
    muscle_group     TEXT NOT NULL,
    equipment        TEXT NOT NULL,
    difficulty       TEXT NOT NULL,
    description      TEXT NOT NULL,
    image_url        TEXT,
    target_muscles   JSONB NOT NULL DEFAULT '[]',
    tips             JSONB NOT NULL DEFAULT '[]',
    common_mistakes  JSONB NOT NULL DEFAULT '[]',
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE programs (
    id                     TEXT PRIMARY KEY,   -- 'prog_ppl'
    name                   TEXT NOT NULL,
    description            TEXT NOT NULL,
    difficulty             TEXT NOT NULL,
    days_per_week          INT  NOT NULL,
    estimated_duration_min INT  NOT NULL,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE program_days (
    id         TEXT PRIMARY KEY,               -- 'ppl_push'
    program_id TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    sort_order INT  NOT NULL
);

CREATE TABLE program_exercises (
    id            BIGSERIAL PRIMARY KEY,
    day_id        TEXT NOT NULL REFERENCES program_days(id) ON DELETE CASCADE,
    exercise_id   TEXT NOT NULL REFERENCES exercises(id),
    sets          INT  NOT NULL,
    reps_text     TEXT NOT NULL,
    rest_seconds  INT  NOT NULL,
    sort_order    INT  NOT NULL
);

CREATE TABLE workout_logs (
    id              UUID PRIMARY KEY,          -- client-generated
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    program_id      TEXT REFERENCES programs(id),
    day_name        TEXT        NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ NOT NULL,
    duration_sec    INT         NOT NULL,
    total_volume_kg NUMERIC(10,2) NOT NULL,
    total_sets      INT         NOT NULL,
    calories_est    INT         NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ
);
CREATE INDEX idx_workout_logs_user_updated ON workout_logs(user_id, updated_at);

CREATE TABLE exercise_logs (
    id             BIGSERIAL PRIMARY KEY,
    workout_log_id UUID NOT NULL REFERENCES workout_logs(id) ON DELETE CASCADE,
    exercise_id    TEXT NOT NULL REFERENCES exercises(id),
    sort_order     INT  NOT NULL
);

CREATE TABLE set_logs (
    id              BIGSERIAL PRIMARY KEY,
    exercise_log_id BIGINT NOT NULL REFERENCES exercise_logs(id) ON DELETE CASCADE,
    weight_kg       NUMERIC(6,2) NOT NULL,
    reps            INT     NOT NULL,
    completed       BOOLEAN NOT NULL,
    skipped         BOOLEAN NOT NULL,
    sort_order      INT     NOT NULL
);

CREATE TABLE measurements (
    id           UUID PRIMARY KEY,             -- client-generated
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date         TIMESTAMPTZ NOT NULL,
    weight_kg    NUMERIC(5,1), body_fat_pct NUMERIC(4,1),
    chest_cm     NUMERIC(5,1), waist_cm     NUMERIC(5,1),
    arms_cm      NUMERIC(5,1), legs_cm      NUMERIC(5,1),
    shoulders_cm NUMERIC(5,1), neck_cm      NUMERIC(5,1),
    hips_cm      NUMERIC(5,1),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ
);
CREATE INDEX idx_measurements_user_updated ON measurements(user_id, updated_at);

CREATE TABLE user_settings (
    user_id                   UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    units                     TEXT    NOT NULL DEFAULT 'metric',
    dark_mode                 BOOLEAN NOT NULL DEFAULT true,
    notifications_enabled     BOOLEAN NOT NULL DEFAULT true,
    workout_reminders_enabled BOOLEAN NOT NULL DEFAULT true,
    reminder_time             TEXT    NOT NULL DEFAULT '18:00',
    rest_timer_sound          BOOLEAN NOT NULL DEFAULT true,
    language                  TEXT    NOT NULL DEFAULT 'English',
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE favorites (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, exercise_id)
);

CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT        NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ
);
```

Store weights in **kg and cm**, exactly like the app. Unit conversion stays a presentation concern — never persist converted values.

**Verify:** `./mvnw spring-boot:run` — Flyway logs `Successfully applied 1 migration`. Confirm with `docker compose exec db psql -U gym -d gymtracker -c '\dt'`.

---

### Phase 3 — Auth with JWT

Three pieces: a `JwtService` that signs/parses tokens, a `JwtAuthFilter` that reads the `Authorization` header, and a `SecurityConfig` that wires it up.

```java
@Service
public class JwtService {
    private final SecretKey key;
    private final long accessTtlMinutes;

    public JwtService(@Value("${app.jwt.secret}") String secret,
                      @Value("${app.jwt.access-ttl-minutes}") long accessTtlMinutes) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTtlMinutes = accessTtlMinutes;
    }

    public String issueAccessToken(UUID userId) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(userId.toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTtlMinutes, ChronoUnit.MINUTES)))
                .signWith(key)
                .compact();
    }

    public UUID parseUserId(String token) {
        String sub = Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload().getSubject();
        return UUID.fromString(sub);
    }
}
```

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, JwtAuthFilter jwtFilter) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)          // safe: stateless JWT, no cookies
            .cors(Customizer.withDefaults())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**", "/actuator/health",
                                 "/v3/api-docs/**", "/swagger-ui/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/exercises/**", "/api/v1/programs/**").permitAll()
                .anyRequest().authenticated())
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }

    @Bean PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(); }
}
```

**CORS** — the Flutter web build runs on a different origin, so this is required or every browser request fails:

```java
@Bean
CorsConfigurationSource corsConfigurationSource(
        @Value("${app.cors.allowed-origins}") List<String> origins) {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(origins);            // exact origins, not "*", once you send auth headers
    config.setAllowedMethods(List.of("GET","POST","PUT","PATCH","DELETE","OPTIONS"));
    config.setAllowedHeaders(List.of("Authorization","Content-Type"));
    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

**Endpoints:**

| Method | Path | Body → Response |
|---|---|---|
| POST | `/api/v1/auth/register` | `{name,email,password}` → `{accessToken, refreshToken, user}` |
| POST | `/api/v1/auth/login` | `{email,password}` → same |
| POST | `/api/v1/auth/refresh` | `{refreshToken}` → new pair |
| POST | `/api/v1/auth/logout` | revokes the refresh token |
| POST | `/api/v1/auth/forgot-password` | `{email}` → always 202, even for unknown emails |

Rules that matter:
- **Lowercase the email on register *and* every lookup** — the `CITEXT` column enforces this at the DB level too.
- **Return an identical response for unknown vs. wrong password** (`401 Invalid email or password`). Distinguishing them leaks which emails have accounts.
- **`forgot-password` always returns 202**, whether or not the email exists — same reason. Send a real, single-use, time-limited reset link by email (Resend, Postmark, or SES). This finally replaces the app's local name-matching reset.
- Rate-limit login and forgot-password (Bucket4j, or your host's rate limiter).

**Verify:**
```bash
curl -X POST localhost:8080/api/v1/auth/register -H 'Content-Type: application/json' \
  -d '{"name":"Alex","email":"alex@example.com","password":"secret123"}'
curl localhost:8080/api/v1/me -H "Authorization: Bearer <accessToken>"
```

---

### Phase 4 — Catalog endpoints and seeding

The 50 exercises and 3 programs currently live in `lib/seed/*.dart`. Move that to the server so content updates ship without an app release.

Convert the Dart seed literals to `V2__seed_catalog.sql` (a short script can generate the INSERTs from the Dart files — or paste them, it's a one-time job). Use `INSERT ... ON CONFLICT (id) DO UPDATE` so re-running is idempotent, exactly like `runSeeder`.

```
GET /api/v1/exercises?updatedSince=2026-08-01T00:00:00Z
GET /api/v1/programs?updatedSince=...
```

Both are public and cacheable (`Cache-Control`, `ETag`). The app keeps its bundled seed data as the first-run fallback so a fresh install works offline before its first sync.

---

### Phase 5 — User data endpoints

```
GET    /api/v1/me                      PATCH /api/v1/me
GET    /api/v1/me/settings             PUT   /api/v1/me/settings
GET    /api/v1/workouts?updatedSince=  PUT   /api/v1/workouts/{id}    DELETE /api/v1/workouts/{id}
GET    /api/v1/measurements?...        PUT   /api/v1/measurements/{id} DELETE /api/v1/measurements/{id}
GET    /api/v1/favorites               PUT   /api/v1/favorites
```

**Use `PUT` with the client's UUID, not `POST`.** The write is then idempotent: if the network drops after the server commits but before the app sees the response, the retry is harmless. With `POST` that same retry creates a duplicate workout.

Two rules to enforce in every handler:
1. **Scope by the authenticated user.** Read the id from the JWT, never from the request body or a query param, or user A can read user B's workouts by guessing a UUID.
2. **Recompute derived totals server-side.** `totalVolumeKg`, `totalSets`, and `caloriesEst` arrive from the client but must be recalculated from the submitted sets — a client can send anything, and PR leaderboards later depend on these being trustworthy. Port `WorkoutCalculator` and `CalorieCalculator` to Java (they're ~20 lines each and already have unit tests to copy).

**Personal records stay computed, never stored** — same as the app. A `GET /api/v1/me/records` can derive them with a SQL window function.

---

### Phase 6 — The sync endpoint

One round trip: push local changes, pull remote ones.

```
POST /api/v1/sync
{
  "since": "2026-08-06T12:00:00Z",       // null on first sync = full download
  "workouts":     [ ...dirty records... ],
  "measurements": [ ... ],
  "favorites":    ["ex_bench_press"],
  "settings":     { ... }
}
→
{
  "serverTime": "2026-08-07T09:31:02Z",  // becomes the client's next cursor
  "workouts":     [ ...changed since 'since', including tombstones... ],
  "measurements": [ ... ],
  "favorites":    [ ... ],
  "settings":     { ... }
}
```

Conflict resolution: **last-write-wins per record, by `updatedAt`.** Skip an incoming record if the stored `updated_at` is newer. This is sufficient here because workout logs are append-mostly — two devices rarely edit the same finished workout. Don't reach for CRDTs.

Deletes are **soft** (`deleted_at` set, row retained). A hard delete is invisible to a device that was offline when it happened, so that device would happily re-upload the record it still has.

Use `serverTime` from the response as the next `since`, never the device clock — phone clocks drift and skew silently drops records.

---

### Phase 7 — Tests

```java
@SpringBootTest
@Testcontainers
class WorkoutSyncIntegrationTest {
    @Container @ServiceConnection
    static PostgreSQLContainer<?> db = new PostgreSQLContainer<>("postgres:16-alpine");
    // Spring wires the datasource to the container automatically via @ServiceConnection
}
```

Cover at minimum:
- Register → duplicate email rejected case-insensitively → login → `/me` (mirrors `hive_auth_repository_test.dart`)
- User A cannot read or write user B's workouts (**the security test that matters most**)
- `PUT` the same workout twice creates one row, not two
- Sync: push, pull, tombstone propagation, and older-`updatedAt` records being ignored
- Server-side volume/calorie math matches the Dart unit tests

Run: `./mvnw verify`

---

### Phase 8 — Containerize

```dockerfile
# Build
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline          # cached layer: deps re-download only when pom changes
COPY src ./src
RUN mvn -B clean package -DskipTests

# Run
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=build /app/target/*.jar app.jar
USER app                                   # never run as root
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-jar","app.jar"]
```

```bash
docker build -t gym-tracker-api .
docker run -p 8080:8080 --env-file .env gym-tracker-api
```

---

## 3. Deploy — for $0

Free deployment is achievable, but the free-tier landscape changed a lot through 2025–26 and several old recommendations are now dead. **Verified August 2026 — re-check before you commit, these terms move constantly.**

### What died

| Platform | Status |
|---|---|
| **Fly.io** | Free tier **eliminated** (2024). Now a ~2 VM-hour / 7-day trial, then card required |
| **Koyeb** | Acquired by Mistral AI in early 2026; free Starter tier **closed to new users** |
| **Railway** | Effectively not free — $1/month credit covers a few hours; $5 one-time trial |
| **Render free Postgres** | **Expires after 30 days** and must be recreated — unusable for real data |
| **Heroku** | Free dynos gone since 2022 |

### The trick that makes free tiers actually work: GraalVM native image

This is the single highest-leverage thing you can do. Free tiers give you ~512 MB RAM and a fraction of a CPU, which is where a normal JVM app struggles.

| | JVM (default) | GraalVM native image |
|---|---|---|
| Cold start | 3–10 s (much worse on 0.1 CPU — can exceed 60 s) | **~50–100 ms** |
| Memory | 300–512 MB | **~64–128 MB** |
| Fits a free tier? | Barely, painfully | Comfortably |

Spring Boot 3 supports this natively — no extra framework:

```bash
./mvnw -Pnative native:compile     # ~5–10 min build
```

```dockerfile
FROM ghcr.io/graalvm/native-image-community:21 AS build
WORKDIR /app
COPY . .
RUN ./mvnw -B -Pnative native:compile -DskipTests

FROM gcr.io/distroless/base-debian12
COPY --from=build /app/target/gym-tracker-api /app/api
EXPOSE 8080
ENTRYPOINT ["/app/api"]
```

Costs: builds take 5–10 minutes and need ~4 GB RAM (build in CI, not on the free host), and reflection-heavy libraries occasionally need hints. Spring's AOT processing handles Hibernate and Jackson for you. **Build the JVM version first, get it working, then switch** — don't debug native-image issues and business logic at the same time.

With a native image, cold starts stop being a real problem and every option below becomes comfortable.

### Recommended free stack: Render (app) + Neon (database)

Free forever, **no credit card**, and the two genuinely-free pieces from different providers — because Render's own free Postgres expires after 30 days while Neon's doesn't.

**Database — [Neon](https://neon.com):** 0.5 GB storage, 100 compute-hours/month, scale-to-zero, permanent free tier. Real managed Postgres with a normal connection string.

1. Create a project → copy the connection string
2. Convert it to JDBC form:
   ```
   DATABASE_URL=jdbc:postgresql://ep-xxx.region.aws.neon.tech/gymtracker?sslmode=require
   ```
   `sslmode=require` is mandatory — Neon rejects unencrypted connections.

**App — Render free web service:** 512 MB, 0.1 CPU, 750 instance-hours/month, no card required.

1. Push `gym_tracker_api` to GitHub
2. New → Web Service → connect the repo (auto-detects the `Dockerfile`)
3. Instance type: **Free**
4. Environment variables:
   ```
   DATABASE_URL=jdbc:postgresql://ep-xxx...neon.tech/gymtracker?sslmode=require
   DB_USER=<neon user>
   DB_PASSWORD=<neon password>
   JWT_SECRET=<openssl rand -base64 48>
   CORS_ORIGINS=https://your-flutter-app-domain
   ```
5. Health check path: `/actuator/health`
6. Deploy — Flyway migrates on first boot

**The spin-down caveat:** free services sleep after ~15 minutes idle. 750 hours/month is just over the ~720 hours in a month, so a keep-alive ping every 10 minutes (free GitHub Actions cron, or cron-job.org) hitting `/actuator/health` keeps it awake within budget. With a native image you may not even bother — the cold start is under a second.

Also add connection pool limits, because Neon's free tier caps connections:

```yaml
spring.datasource.hikari:
  maximum-pool-size: 5
  minimum-idle: 1
```

### Alternatives, ranked

**Google Cloud Run + Neon** — the most generous free compute: 2 million requests, 180k vCPU-seconds and 360k GiB-seconds per month, Always Free (not a trial), scaling to zero. Requires a linked billing account, but stays exactly $0 within those limits. Pair it with Neon rather than Cloud SQL — **Cloud SQL has no free tier** and is the expensive part (this corrects the pairing suggested in older guides). Best choice if you're comfortable putting a card on file; set a $1 budget alert for peace of mind.

**Oracle Cloud Always Free** — an always-on ARM VM, no cold starts, and you run Spring Boot + Postgres + Caddy via Docker Compose on one box. The allocation was **halved in June 2026** from 4 OCPU/24 GB to **2 OCPU/12 GB**, which is still far more than any PaaS free tier. Two real catches: ARM instances are frequently "out of capacity" in popular regions, and you own backups, TLS renewal, and patching yourself. Best if you want maximum power and don't mind sysadmin work.

**Supabase** as the database — 500 MB, but **pauses after 7 days of inactivity**, so it's worse than Neon for a low-traffic app. **Aiven** also has a permanent free Postgres tier and is a reasonable second choice.

### Where free stops being enough

Free tiers are fine for development, a portfolio piece, and early real users. Move to paid when you hit any of these: Neon's 0.5 GB (thousands of workouts — a long way off), sustained traffic that makes 0.1 CPU the bottleneck, or a need for point-in-time-restore backups. The first paid step is roughly $7/month for a Render Starter instance, and it's a settings change, not a migration.

### Non-negotiables before real users

- `JWT_SECRET` from the environment, minimum 32 bytes, **never committed**
- `ddl-auto: validate` in production (Flyway owns the schema)
- **Automated Postgres backups**, and one practice restore — an untested backup is not a backup. Free tiers give you limited or no PITR, so schedule your own `pg_dump` to object storage
- HTTPS only (all the managed hosts do this automatically)
- Structured JSON logs; never log tokens, passwords, or full request bodies
- Error handler that returns generic messages — stack traces leak your internals
- Actuator: expose `health` and `info` only, never `env` or `heapdump`

### Why the offline-first design pays off here

Scale-to-zero and cold starts would normally be a bad user experience. They aren't, in this architecture: the app reads and writes Hive locally and syncs in the background, so a sleeping backend waking up is invisible. The user opens the app, sees their data instantly, and sync catches up whenever the server is ready. **Offline-first is what makes a free, scale-to-zero backend viable.**

### Non-negotiables before real users

- `JWT_SECRET` from the environment, minimum 32 bytes, **never committed**
- `ddl-auto: validate` in production (Flyway owns the schema)
- **Automated daily Postgres backups**, and one practice restore — an untested backup is not a backup
- HTTPS only (managed hosts do this automatically)
- Structured JSON logs; never log tokens, passwords, or full request bodies
- Error handler that returns generic messages — stack traces leak your internals
- Actuator: expose `health` and `info` only, never `env` or `heapdump`

---

## 4. Wiring the Flutter app to it

The payoff for the existing architecture: **no screen or widget changes.** You add implementations of the interfaces the app already depends on.

1. **Add packages:** `dio` (HTTP + interceptors), `flutter_secure_storage` (tokens — not Hive, which is unencrypted).

2. **`ApiClient`** with an interceptor that attaches `Authorization: Bearer <token>` and, on `401`, refreshes once and retries.

3. **New repository implementations** in each feature's `data/`:
   - `ApiAuthRepository implements AuthRepository` — register/login hit the API; `resetPassword` becomes a real email flow.
   - `SyncingWorkoutLogRepository implements WorkoutLogRepository` — a **decorator** over the Hive one: writes go to Hive first (instant), then mark dirty and enqueue a sync.
   - Same for measurements, settings, favorites.

4. **`SyncService`** — runs on app start, on resume, after finishing a workout, and on a timer. Reads `lastSyncedAt` from the `meta` box; calls `POST /sync`; merges the response into Hive.

5. **Swap the providers** — one line each in `auth_controller.dart`, `session_controller.dart`, etc. Everything above the repository layer is untouched:
   ```dart
   final authRepositoryProvider = Provider<AuthRepository>(
     (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
   );
   ```

6. **Schema additions to local models:** add `updatedAt` and `dirty` to `WorkoutLog`, `MeasurementEntry`, `UserSettings`, and bump `kSeedVersion`.

7. **Migrating existing local data:** on first login after the update, push every local record the user already has (they all have UUIDs and are trivially marked dirty), then pull. Nobody loses their history.

**Keep `PasswordHasher` out of the new path** — hashing belongs on the server now. Delete the local login path once the API is live, or you'll have two sources of truth for credentials.

---

## 5. Suggested order of work

| Step | Outcome | Rough effort |
|---|---|---|
| 1 | Scaffold + Docker Postgres + health check | half a day |
| 2 | Schema + Flyway + JPA entities | 1 day |
| 3 | Auth (register/login/refresh) + JWT + CORS | 1 day |
| 4 | Catalog endpoints + seed migration | half a day |
| 5 | Workouts / measurements / settings / favorites | 1–2 days |
| 6 | Sync endpoint | 1 day |
| 7 | Testcontainers integration tests | 1 day |
| 8 | Dockerfile + deploy to Render | half a day |
| 9 | Flutter: ApiClient, repositories, SyncService | 2–3 days |

Roughly **8–11 focused days**. Steps 1–4 alone give you a working authenticated API you can hit from Postman, which is a good place to pause and confirm the shape before building the sync layer.

---

## 6. Things that will bite you

1. **`ddl-auto: update` in production.** It silently drops or alters columns. Use `validate` and let Flyway migrate.
2. **Forgetting CORS.** The Flutter web build fails every request with an opaque browser error that looks like a server outage.
3. **Trusting client-supplied totals.** Recompute volume and calories server-side.
4. **Filtering by a user id from the request instead of the JWT.** This is the classic broken-access-control bug — it looks fine in testing because you only ever use one account.
5. **`POST` instead of idempotent `PUT`.** Flaky mobile networks retry; you get duplicate workouts.
6. **Hard deletes.** Offline devices resurrect deleted records on their next sync.
7. **Trusting the device clock for sync cursors.** Always use the server's `serverTime`.
8. **`open-in-view: true`** (the Spring default). It holds a DB connection for the whole request and hides lazy-loading bugs until you're under load. Turn it off — it's already off in the config above.
9. **Storing JWTs in Hive.** Use `flutter_secure_storage` (Keychain/Keystore).
10. **Renaming exercise IDs.** Every existing workout log and favorite references `ex_bench_press` by string. Treat those IDs as permanent.
