#!/bin/bash
# Pterodactyl wrapper for the official OpenBot image. Wings runs the container as its own user with
# /home/container as the only persistent folder, so the official start script gets those paths here.
# Console commands go to the `openbot` CLI, because Pterodactyl has no `docker exec`.
set -uo pipefail
export HOME=/home/container
export XDG_RUNTIME_DIR="/tmp/openbot-run-$(id -u)"
# Wings mounts /tmp as a small tmpfs (100 MB by default). Chromium falls back to TMPDIR for shared memory.
export TMPDIR=/home/container/.tmp
export LANG=C.UTF-8
mkdir -p "$TMPDIR" && chmod 700 "$TMPDIR"
cd /home/container

log() { echo "[OpenBot] $*"; }
usage() { log "Commands: login | status | mobile-connect | name <name> | logout | version"; }

/opt/OpenBot/app/resources/hosting/openbot-container &
APP=$!
stop() { log "Stopping (agents and database close first)..."; kill -TERM "$APP" 2>/dev/null; wait "$APP"; exit $?; }
trap stop TERM INT

for _ in $(seq 1 180); do
    [ -S "$XDG_RUNTIME_DIR/control.sock" ] && break
    if ! kill -0 "$APP" 2>/dev/null; then
        wait "$APP"; code=$?
        log "OpenBot stopped during start (exit $code). If the message above is about a user namespace,"
        log "the node's Docker needs the OpenBot seccomp profile (see the egg description)."
        exit "$code"
    fi
    sleep 1
done
log "Ready."
openbot status || true
usage

while kill -0 "$APP" 2>/dev/null; do
    read -r -t 1 -a args; rc=$?
    if [ $rc -gt 128 ]; then continue; fi   # timeout: check OpenBot again
    if [ $rc -ne 0 ] && [ ${#args[@]} -eq 0 ]; then sleep 1; continue; fi   # no console attached
    case "${args[0]:-}" in
        login|status|mobile-connect|logout|name|version) openbot "${args[@]}" ;;
        '') ;;
        *) usage ;;
    esac
done
wait "$APP"
