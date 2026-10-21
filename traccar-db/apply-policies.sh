#!/bin/sh
# Applies TimescaleDB retention and compression policies to Traccar's
# hypertables. Configured by TRACCAR_RETENTION_DAYS and TRACCAR_COMPRESSION_DAYS
# (0 or empty disables that policy and removes an existing one).
#
# It cannot live in /docker-entrypoint-initdb.d: tc_positions and tc_events are
# converted to hypertables by Traccar's own migration on its first start, which
# happens after the database is initialized. So this waits for them, applies the
# policies idempotently and exits. It runs on every container start, so a
# changed value takes effect on restart.
set -eu

RETENTION_DAYS="${TRACCAR_RETENTION_DAYS:-90}"
COMPRESSION_DAYS="${TRACCAR_COMPRESSION_DAYS:-14}"
TABLES="tc_positions tc_events"

for v in "$RETENTION_DAYS" "$COMPRESSION_DAYS"; do
  case "$v" in
    '' | *[!0-9]*) echo "apply-policies: '$v' is not a whole number of days" >&2; exit 1 ;;
  esac
done

if [ "$RETENTION_DAYS" -gt 0 ] && [ "$COMPRESSION_DAYS" -ge "$RETENTION_DAYS" ]; then
  echo "apply-policies: compression (${COMPRESSION_DAYS}d) must be shorter than retention (${RETENTION_DAYS}d)" >&2
  exit 1
fi

psql_q() {
  psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c "$1"
}

# Hypertables appear only after Traccar first connects and migrates.
until [ "$(psql_q "SELECT count(*) FROM timescaledb_information.hypertables WHERE hypertable_name IN ('tc_positions','tc_events')" 2>/dev/null || true)" = "2" ]; do
  sleep 10
done

for t in $TABLES; do
  psql_q "SELECT remove_retention_policy('$t', if_exists => true)" >/dev/null
  psql_q "SELECT remove_compression_policy('$t', if_exists => true)" >/dev/null

  if [ "$COMPRESSION_DAYS" -gt 0 ]; then
    psql_q "ALTER TABLE $t SET (timescaledb.compress, timescaledb.compress_segmentby = 'deviceid')" >/dev/null
    psql_q "SELECT add_compression_policy('$t', INTERVAL '$COMPRESSION_DAYS days')" >/dev/null
  fi
  if [ "$RETENTION_DAYS" -gt 0 ]; then
    psql_q "SELECT add_retention_policy('$t', INTERVAL '$RETENTION_DAYS days')" >/dev/null
  fi
done

echo "apply-policies: retention=${RETENTION_DAYS}d compression=${COMPRESSION_DAYS}d applied to: $TABLES"
