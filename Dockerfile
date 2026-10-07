# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Base: shared by every stage
# ---------------------------------------------------------------------------
FROM node:24-bookworm-slim AS base
ENV NODE_ENV=production
WORKDIR /app

# ---------------------------------------------------------------------------
# Dependencies
#
#   deps         -> full install (dev compose, lint/format/migrate tooling)
#   prod-deps    -> production only (drizzle-kit stays in prod because the
#                   entrypoint runs migrations before the server boots)
#
# bcrypt ships prebuilt linux-x64 glibc binaries, so no build toolchain
# is required in this image.
# ---------------------------------------------------------------------------
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci

FROM base AS prod-deps
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---------------------------------------------------------------------------
# Development image: full dependency set, source arrives via bind mount
# ---------------------------------------------------------------------------
FROM deps AS dev
ENV NODE_ENV=development
COPY . .
RUN mkdir -p logs
EXPOSE 3000
CMD ["npm", "run", "dev"]

# ---------------------------------------------------------------------------
# Production image: prod deps only, runs as the unprivileged `node` user
# ---------------------------------------------------------------------------
FROM base AS production
COPY --from=prod-deps /app/node_modules ./node_modules
COPY . .
RUN mkdir -p logs && chown -R node:node /app
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
ENTRYPOINT ["./scripts/entrypoint.sh"]
CMD ["npm", "start"]
