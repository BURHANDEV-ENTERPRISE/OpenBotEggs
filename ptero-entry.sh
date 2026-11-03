#!/bin/bash
# Pterodactyl entry point for the official OpenBot image. Wings runs the container as its own user
# with /home/container as the only persistent folder, gives no way to change seccomp per server, and
# has no `docker exec`. So this starts OpenBot the way the official openbot-container script does,
# with these differences:
#   - paths under /home/container, and TMPDIR there because Wings mounts /tmp as a small tmpfs;
#   - --no-sandbox, because Docker's default seccomp refuses the user namespaces the Electron sandbox
#     needs. The container stays the boundary: agents cannot leave it;
#   - console lines go to the `openbot` CLI (login, status, ...).
set -uo pipefail
umask 077
export HOME=/home/container
export XDG_RUNTIME_DIR="/tmp/openbot-run-$(id -u)"
export OPENBOT_CONTROL_SOCKET="$XDG_RUNTIME_DIR/control.sock"
export TMPDIR=/home/container/.tmp
export LANG=C.UTF-8
cd /home/container

log() { echo "[OpenBot] $*"; }
die() { echo "[OpenBot ERROR] $*" >&2; exit 1; }
usage() {
    cat <<'HELP'
[OpenBot] Console commands:
  help              Show this list
  login             Sign in to your OpenBot account (email, then the code sent to it)
  status            Show the server and account status
  mobile-connect    Show a code to connect the OpenBot phone app
  name <name>       Rename this server
  logout            Sign out of this server
  version           Show the OpenBot version

How to use OpenBot after login:
  1. Open the OpenBot desktop app or https://openbot.run/app with the same email.
  2. Select this server in the server list.
  3. Connect an AI provider (Claude, ChatGPT/Codex, Grok, ...) in the app.
     OpenBot downloads the provider here and signs it in; nothing to install in this console.
  4. Create agents and give them work. They run only inside this container.
Phone: type mobile-connect and scan the code with the OpenBot phone app.
HELP
}

mkdir -p "$TMPDIR" "$XDG_RUNTIME_DIR"

# Give the Wings UID a user name. nss_wrapper reads these files only for this process tree.
if ! getent passwd "$(id -u)" >/dev/null; then
    grep -v '^container:' /etc/passwd >"$XDG_RUNTIME_DIR/passwd"
    echo "container:x:$(id -u):$(id -g):container:/home/container:/bin/bash" >>"$XDG_RUNTIME_DIR/passwd"
    cp /etc/group "$XDG_RUNTIME_DIR/group"
    getent group "$(id -g)" >/dev/null || echo "container:x:$(id -g):" >>"$XDG_RUNTIME_DIR/group"
    export NSS_WRAPPER_PASSWD="$XDG_RUNTIME_DIR/passwd" NSS_WRAPPER_GROUP="$XDG_RUNTIME_DIR/group"
    export LD_PRELOAD=/usr/local/lib/libnss_wrapper.so USER=container LOGNAME=container
fi
chmod 0700 "$TMPDIR" "$XDG_RUNTIME_DIR"
rm -f "$XDG_RUNTIME_DIR/control.sock"

# D-Bus session, for the keyring.
session=$(dbus-launch --sh-syntax) || die "dbus-launch failed."
eval "$session"

# OpenBot's window on :0, the agents' display on :1.
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 /tmp/.X1-lock /tmp/.X11-unix/X1
size="${OPENBOT_DISPLAY_SIZE:-1280x800}"
[[ $size =~ ^[1-9][0-9]{2,3}x[1-9][0-9]{2,3}$ ]] || size=1280x800
(Xvfb :0 -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &)
(Xvfb :1 -screen 0 "${size}x24" -nolisten tcp >/dev/null 2>&1 &)
export DISPLAY=:0 OPENBOT_AGENT_DISPLAY=:1
for display in :0 :1; do
    for _ in $(seq 1 300); do xdpyinfo -display "$display" >/dev/null 2>&1 && break; sleep 0.1; done
    xdpyinfo -display "$display" >/dev/null 2>&1 || die "Virtual display $display did not start."
done

# Keyring: its password file and the keyring always stay together in /home/container.
state="$HOME/.config/openbot-container"
keyrings="$HOME/.local/share/keyrings"
mkdir -p "$state" "$keyrings"
if [ ! -s "$state/keyring-password" ] && [ -e "$keyrings/login.keyring" ]; then
    die "The keyring exists, but its password file $state/keyring-password is missing."
fi
if [ ! -s "$state/keyring-password" ]; then
    tmp=$(mktemp "$state/keyring-password.XXXXXX")
    head -c 32 /dev/urandom | base64 | tr -d '\n' >"$tmp"
    mv -f "$tmp" "$state/keyring-password"
fi
printf login >"$keyrings/default"
unlocked=$(gnome-keyring-daemon --unlock --components=secrets <"$state/keyring-password") || die "Keyring unlock failed."
eval "$unlocked"
started=$(gnome-keyring-daemon --start --components=secrets) || die "Keyring start failed."
eval "$started"
export GNOME_KEYRING_CONTROL

export OPENBOT_SERVER=1
/opt/OpenBot/app/openbot --password-store=gnome-libsecret --no-sandbox --disable-dev-shm-usage &
APP=$!
stop() { log "Stopping (agents and database close first)..."; kill -TERM "$APP" 2>/dev/null; wait "$APP"; exit $?; }
trap stop TERM INT

for _ in $(seq 1 180); do
    [ -S "$XDG_RUNTIME_DIR/control.sock" ] && break
    if ! kill -0 "$APP" 2>/dev/null; then
        wait "$APP"; code=$?
        die "OpenBot stopped during start (exit $code). See the log above."
    fi
    sleep 1
done
log "Ready."
openbot status || true
log "Type 'help' for the list of commands."

while kill -0 "$APP" 2>/dev/null; do
    read -r -t 1 -a args; rc=$?
    if [ $rc -gt 128 ]; then continue; fi                                   # timeout
    if [ $rc -ne 0 ] && [ ${#args[@]} -eq 0 ]; then sleep 1; continue; fi   # no console
    case "${args[0]:-}" in
        login|status|mobile-connect|logout|name|version) openbot "${args[@]}" ;;
        help) usage ;;
        '') ;;
        *) log "Unknown command: ${args[0]}. Type 'help' for the list of commands." ;;
    esac
done
wait "$APP"
