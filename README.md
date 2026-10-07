# Acquisitions API

Express + Drizzle API backed by [Neon Postgres](https://neon.tech).

## Contents

- [Requirements](#requirements)
- [Environment files](#environment-files)
- [Development (Neon Local)](#development-neon-local)
- [Production (Neon Cloud)](#production-neon-cloud)
- [How `DATABASE_URL` switches](#how-database_url-switches)
- [Migrations](#migrations)
- [Other commands](#other-commands)
- [Security notes](#security-notes)

## Requirements

- Docker + Docker Compose v2
- A [Neon account](https://console.neon.tech) with an API key — Neon Local is a
  proxy **in front of a Neon cloud branch**, not an offline Postgres, so
  development still needs Neon credentials.

## Environment files

| File                       | Purpose                         | Committed? |
| -------------------------- | ------------------------------- | ---------- |
| `.env`                     | Local runs outside Docker       | No         |
| `.env.development`         | Docker Compose dev (Neon Local) | No         |
| `.env.production`          | Deploy-time secrets             | No         |
| `.env.example`             | Template for `.env`             | Yes        |
| `.env.development.example` | Template for `.env.development` | Yes        |
| `.env.production.example`  | Template for `.env.production`  | Yes        |

All real `.env*` files are gitignored. Only the `.example` templates are tracked.

Copy the templates before your first run:

```sh
cp .env.example .env
cp .env.development.example .env.development
cp .env.production.example .env.production
```

Load order at runtime is `.env.$NODE_ENV` then `.env`, both with
`override:false`, so **real process environment variables always win** — that
is what lets Docker inject secrets without any file inside the container.

## Development (Neon Local)

Fill in `.env.development`:

| Variable           | Where to find it                                                         |
| ------------------ | ------------------------------------------------------------------------ |
| `NEON_API_KEY`     | Console → Account Settings → API Keys                                    |
| `NEON_PROJECT_ID`  | Console → Project Settings → General                                     |
| `PARENT_BRANCH_ID` | Branches page — branch to fork from. Leave empty for the project default |
| `DELETE_BRANCH`    | `true` (default) deletes the ephemeral branch on `down`                  |

Start everything:

```sh
docker compose -f docker-compose.dev.yml up --build
```

What this does:

1. Starts `neondatabase/neon_local:latest` on `localhost:5432`.
2. Neon Local forks a **fresh ephemeral branch** from `PARENT_BRANCH_ID`.
3. The app boots with `NEON_LOCAL=true`, which redirects the serverless driver
   to `http://neon-local:5432/sql`.
4. The entrypoint runs `npm run db:migrate` (retrying up to 10 times while the
   proxy warms up), then starts the server on `:3000`.
5. Source is bind-mounted, so `node --watch` reloads on edit.

```sh
docker compose -f docker-compose.dev.yml down    # deletes the ephemeral branch
docker compose -f docker-compose.dev.yml down -v # ...and any local state
```

Set `BRANCH_ID` instead of `PARENT_BRANCH_ID` to pin one branch across restarts,
or `DELETE_BRANCH=false` plus the volume mount shown in the Neon docs to keep a
branch per git branch.

## Production (Neon Cloud)

There is **no database service in `docker-compose.prod.yml`**. Neon Serverless
is a managed cloud service with no container to run; the app connects directly
to `*.neon.tech` over HTTPS.

Fill in `.env.production` (or export the variables from your secret manager):

- `DATABASE_URL` — pooled connection string from the Neon console
  (`postgresql://user:pass@ep-xxx-pooler.region.aws.neon.tech/neondb?sslmode=require`)
- `JWT_SECRET` — required, compose fails fast without it
- `ARCJET_KEY` — required for the security middleware to function

Deploy:

```sh
# export DATABASE_URL / JWT_SECRET / ARCJET_KEY from your secret manager,
# or copy .env.production.example -> .env.production and fill it in
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d
```

Apply schema changes as a one-off task rather than on every boot:

```sh
docker compose -f docker-compose.prod.yml run --rm \
  -e RUN_MIGRATIONS=true app npm run db:migrate
```

### Alternative: secrets straight from the orchestrator

`.env.production` is optional — the compose file reads the host environment
first, so on a PaaS or VM you can skip the file entirely:

```sh
export DATABASE_URL="postgresql://..."
export JWT_SECRET="..."
export ARCJET_KEY="..."
docker compose -f docker-compose.prod.yml up -d --build
```

Nothing secret is baked into the image: `.dockerignore` excludes every `.env*`
file, and `docker-compose.prod.yml` never literalises a credential.

## How `DATABASE_URL` switches

| Environment              | Value                                                        | Set by                                                            |
| ------------------------ | ------------------------------------------------------------ | ----------------------------------------------------------------- |
| Dev (Docker)             | `postgres://neon:npg@neon-local:5432/neondb?sslmode=require` | `environment:` in `docker-compose.dev.yml` (overrides `env_file`) |
| Dev (host `npm run dev`) | `postgres://neon:npg@localhost:5432/neondb?sslmode=require`  | `.env.development`                                                |
| Prod                     | `postgresql://...neon.tech/neondb?sslmode=require`           | Host environment / `.env.production`                              |

Same code, zero edits:

```js
// src/config/database.js
if (process.env.NEON_LOCAL === 'true') {
  neonConfig.fetchEndpoint =
    process.env.NEON_FETCH_ENDPOINT || 'http://neon-local:5432/sql';
  neonConfig.useSecureWebSocket = false;
  neonConfig.poolQueryViaFetch = true;
}
```

`NEON_LOCAL` is set to `'true'` only by `docker-compose.dev.yml`. In production
the branch is skipped and the driver talks straight to Neon Cloud.

## Migrations

`scripts/entrypoint.sh` runs them on container start, controlled by
`RUN_MIGRATIONS`:

| File                      | `RUN_MIGRATIONS` | Why                                    |
| ------------------------- | ---------------- | -------------------------------------- |
| `docker-compose.dev.yml`  | unset → `true`   | Every `up` is a brand-new empty branch |
| `docker-compose.prod.yml` | `false`          | Avoid racing a rolling deploy          |

`drizzle-kit` is a **runtime** dependency (moved out of `devDependencies`)
because the entrypoint needs it after `npm ci --omit=dev`.

Generate a migration after editing `src/models/*.js`:

```sh
docker compose -f docker-compose.dev.yml run --rm app npm run db:generate
```

## Other commands

```sh
npm run lint          # eslint
npm run format        # prettier
docker compose -f docker-compose.dev.yml logs -f app
docker compose -f docker-compose.dev.yml exec app sh   # shell in the container
```

## Security notes

**Rotate your Neon password.** `.env` was previously committed to this
repository containing a live `DATABASE_URL`. Untracking a file does not erase
history, so:

1. Rotate the database password in the Neon console.
2. If the repo is or was public, assume the credential is compromised.
3. To scrub history: `git filter-repo --path .env --invert-paths` (then
   force-push and coordinate with anyone who has cloned).

The current `.gitignore` correctly matches `.env` (the old `.env.*` pattern
never did) and every `.env.*` file, so no future env file can be committed.

Still outstanding — not part of this Docker work:

- `src/utils/jwt.js` falls back to `your-secret-key-please-change-in-production`
  if `JWT_SECRET` is unset. Production compose fails fast instead, but the
  fallback is still in the code.
- `logs/` is tracked in git; every request line shows up as a diff.
