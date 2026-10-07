#!/bin/sh
set -eu

MIGRATE="${RUN_MIGRATIONS:-true}"
MIGRATE_ATTEMPTS="${MIGRATE_ATTEMPTS:-10}"
MIGRATE_WAIT="${MIGRATE_WAIT:-3}"

if [ "$MIGRATE" = "true" ]; then
  echo "==> Waiting for the database ($MIGRATE_ATTEMPTS attempts, ${MIGRATE_WAIT}s apart)"

  attempt=1
  while [ "$attempt" -le "$MIGRATE_ATTEMPTS" ]; do
    if npm run db:migrate; then
      echo "==> Migrations applied"
      break
    fi

    if [ "$attempt" -eq "$MIGRATE_ATTEMPTS" ]; then
      echo "==> Migrations failed after $MIGRATE_ATTEMPTS attempts" >&2
      exit 1
    fi

    echo "==> Database not ready yet (attempt $attempt/$MIGRATE_ATTEMPTS), retrying in ${MIGRATE_WAIT}s"
    sleep "$MIGRATE_WAIT"
    attempt=$((attempt + 1))
  done
else
  echo "==> RUN_MIGRATIONS=$MIGRATE - skipping migrations"
fi

exec "$@"
