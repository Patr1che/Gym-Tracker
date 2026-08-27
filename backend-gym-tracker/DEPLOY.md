# Deploying the GymTracker API

Render runs the app, Neon runs Postgres. Both free, no credit card.

Neon is deliberately not Render's own Postgres: Render's free database expires after
30 days and takes the data with it.

---

## 1. Get the Neon connection details

You already provisioned Neon through the Vercel integration. The connection string is in
two places — the Neon console (Dashboard → your project → Connection Details), or the
Vercel project's environment variables (`DATABASE_URL` / `POSTGRES_URL`).

Neon hands you a URL in libpq form:

```
postgresql://myuser:mypassword@ep-cool-name-123456.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
```

JDBC needs it split into three values, and the `jdbc:` prefix added:

| Render env var | Value from the Neon URL |
|---|---|
| `DATABASE_URL` | `jdbc:postgresql://ep-cool-name-123456.ap-southeast-1.aws.neon.tech/neondb?sslmode=require` |
| `DB_USER` | `myuser` |
| `DB_PASSWORD` | `mypassword` |

Keep `?sslmode=require` — Neon rejects unencrypted connections. Drop the `user:password@`
part from the URL itself; it goes in the two separate variables.

> A Vercel–Neon integration may hand you a **pooled** host (it contains `-pooler`). Either
> works. The pooled one suits serverless; a long-lived JVM with its own HikariCP pool is
> fine on the direct host. `maximum-pool-size` is already capped at 5 in
> `application.yml` to stay inside Neon's free connection limit.

## 2. Push the repo to GitHub

Render builds from a connected GitHub repo, so the backend has to be pushed before it can
deploy. The remote is already `https://github.com/Patr1che/Gym-Tracker.git`.

## 3. Create the service

**Option A — Blueprint (fewer clicks).** `render.yaml` at the repo root already describes
the service. In Render: **New → Blueprint**, pick the repo, and it reads the config. You
will be prompted for the three values marked `sync: false` (`DATABASE_URL`, `DB_USER`,
`DB_PASSWORD`) plus `CORS_ORIGINS`. `JWT_SECRET` is generated for you.

**Option B — manual.** New → Web Service → connect the repo, then:

| Setting | Value |
|---|---|
| Root directory | `backend-gym-tracker` |
| Runtime | Docker (auto-detected from the Dockerfile) |
| Instance type | Free |
| Health check path | `/actuator/health` |
| Region | Singapore (closest free region to the Philippines) |

Environment variables:

```
DATABASE_URL   jdbc:postgresql://ep-xxx...neon.tech/neondb?sslmode=require
DB_USER        <from Neon>
DB_PASSWORD    <from Neon>
JWT_SECRET     <openssl rand -base64 48>
CORS_ORIGINS   <where the Flutter web build is served, e.g. https://your-app.vercel.app>
```

`PORT` is set by Render automatically; the app reads it.

## 4. First boot

Flyway creates the schema on startup. Watch the deploy log for:

```
Migrating schema "public" to version "1 - init"
Successfully applied 1 migration
```

Then verify from your machine:

```bash
API=https://gymtracker-api.onrender.com

curl -sS $API/actuator/health
# {"status":"UP", ...}

curl -sS -X POST $API/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Patriche","email":"you@example.com","password":"a-real-password"}'
# 200 with accessToken, refreshToken, user
```

The API docs are at `$API/swagger-ui.html`.

## 5. Keep it awake

Free services spin down after ~15 minutes idle, and a JVM waking on 0.1 CPU is slow.
`.github/workflows/keepalive.yml` pings `/actuator/health` every 10 minutes. Add the
service URL as a repository secret named `API_URL` (Settings → Secrets and variables →
Actions) or the workflow no-ops.

750 instance-hours/month against roughly 720 hours in a month means a permanently-awake
free service just fits.

## 6. Where free stops

- Neon free storage is 0.5 GB. Thousands of workouts is a long way off.
- Sustained traffic makes Render's 0.1 CPU the bottleneck before anything else.
- Neither tier gives real point-in-time backups. Schedule your own `pg_dump` and
  **restore it once** — an untested backup is not a backup.

The first paid step is Render Starter at about $7/month. It is a settings change, not a
migration.

## Production checklist

- [ ] `JWT_SECRET` comes from the environment, is at least 32 bytes, and is not in git
- [ ] `ddl-auto` is `validate` — Flyway owns the schema
- [ ] Actuator exposes only `health` and `info`, never `env` or `heapdump`
- [ ] `CORS_ORIGINS` lists exact origins, never `*`
- [ ] A `pg_dump` backup has been taken **and restored once**
- [ ] `forgot-password` still has no email delivery — it accepts and logs, nothing more
