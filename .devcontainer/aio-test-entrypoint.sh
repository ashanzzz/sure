#!/usr/bin/env bash
# Sure AIO test/debug entrypoint.
# Boots PostgreSQL + Redis + SSHD inside the single container, prepares the
# test database, then hands control to CMD (default: sleep infinity so you can
# SSH in and run `bin/rails test` interactively).
set -euo pipefail

APP_DIR="${APP_DIR:-/workspace}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PGBIN="$(ls -d /usr/lib/postgresql/*/bin | head -1)"
PGPASS="${POSTGRES_PASSWORD:-postgres}"

log() { echo "[aio-entrypoint] $*"; }

# PostgreSQL
mkdir -p "$PGDATA"
chown -R postgres:postgres "$PGDATA"
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  log "initializing postgres cluster"
  su postgres -c "$PGBIN/initdb -D $PGDATA --auth-local=trust --auth-host=md5" >/dev/null
fi
log "starting postgres"
su postgres -c "$PGBIN/pg_ctl -D $PGDATA -o '-c listen_addresses=127.0.0.1 -p 5432' -w start" >/dev/null
su postgres -c "psql -v ON_ERROR_STOP=1 -c \"ALTER USER postgres WITH PASSWORD '${PGPASS}';\"" >/dev/null 2>&1 || true

# Redis
log "starting redis"
redis-server --daemonize yes --bind 127.0.0.1 --port 6379 >/dev/null

# SSHD
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  log "generating sshd host keys"
  ssh-keygen -A >/dev/null
fi
log "starting sshd"
/usr/sbin/sshd

# App env for the test DB
cd "$APP_DIR"
export DATABASE_URL="postgres://postgres:${PGPASS}@127.0.0.1:5432"
export REDIS_URL="redis://127.0.0.1:6379/1"

log "preparing test database (best-effort)"
if su dev -c "cd $APP_DIR && DATABASE_URL='$DATABASE_URL' REDIS_URL='$REDIS_URL' RAILS_ENV=test bin/rails db:create db:schema:load" >/tmp/db-prepare.log 2>&1; then
  log "test database ready"
else
  log "db prepare had warnings (see /tmp/db-prepare.log) - continuing"
fi

log "===================================================="
log "Sure AIO test container ready."
log "  SSH:   ssh dev@<host> -p <mapped 22>   (key-only)"
log "  Tests: cd $APP_DIR && bin/rails test"
log "  DB:    $DATABASE_URL"
log "  REDIS: $REDIS_URL"
log "===================================================="

exec "$@"
