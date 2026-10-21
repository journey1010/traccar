#!/bin/sh
# Starts the policy applier in the background, then hands over to the upstream
# entrypoint so postgres stays PID 1 and keeps its normal signal handling.
set -eu

/usr/local/bin/apply-policies.sh &

exec docker-entrypoint.sh "$@"
