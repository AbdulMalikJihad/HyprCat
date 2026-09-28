#!/usr/bin/env bash

THEME="$HOME/.config/rofi/docker.rasi"

# Folder containing your docker-compose.yml for n8n.
# Update this path if your compose file lives somewhere else.
COMPOSE_DIR="/home/jihad/n8n"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
HASH_FILE="$COMPOSE_DIR/.last-applied-hash"

# ngrok settings -- must match the domain used in docker-compose.yml's
# WEBHOOK_URL / N8N_HOST / N8N_EDITOR_BASE_URL.
NGROK_DOMAIN="deferred-conjuror-atonable.ngrok-free.dev"
NGROK_PORT="5678"
NGROK_LOG="$COMPOSE_DIR/.ngrok.log"
NGROK_PID_FILE="$COMPOSE_DIR/.ngrok.pid"

# Show a result message: prefer a non-blocking desktop notification, fall
# back to a rofi dialog if notify-send isn't installed.
show_result() {
    local title="$1" body="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body"
    else
        rofi -theme "$THEME" -e "$title: $body"
    fi
}

if [ ! -f "$COMPOSE_FILE" ]; then
    show_result "Docker" "No docker-compose.yml found at $COMPOSE_DIR"
    exit 1
fi

# ---- ngrok helpers ----------------------------------------------------

ngrok_is_running() {
    if [ -f "$NGROK_PID_FILE" ]; then
        local pid
        pid=$(cat "$NGROK_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "yes"
            return
        fi
    fi
    echo "no"
}

start_ngrok() {
    if [ "$(ngrok_is_running)" == "yes" ]; then
        return
    fi
    nohup ngrok http --domain="$NGROK_DOMAIN" "$NGROK_PORT" > "$NGROK_LOG" 2>&1 &
    echo $! > "$NGROK_PID_FILE"
    # Give it a moment to establish the tunnel before n8n starts hitting it.
    sleep 2
}

stop_ngrok() {
    if [ "$(ngrok_is_running)" == "yes" ]; then
        local pid
        pid=$(cat "$NGROK_PID_FILE")
        kill "$pid" 2>/dev/null
    fi
    rm -f "$NGROK_PID_FILE"
}

# ---- container discovery / status --------------------------------------

# Locate the n8n container by name/image match, rather than assuming an
# exact name — works whether it was started with `docker run --name n8n ...`
# or via docker-compose (which often suffixes the name, e.g. n8n-n8n-1).
container=$(docker ps -a --format '{{.Names}}' | grep -i n8n | head -n1)

is_running="false"
if [ -n "$container" ]; then
    is_running=$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)
fi

ngrok_status_label="ngrok 🔴"
if [ "$(ngrok_is_running)" == "yes" ]; then
    ngrok_status_label="ngrok 🟢"
fi

if [ "$is_running" == "true" ]; then
    menu="n8n: Running 🟢 ($ngrok_status_label)\nStop\nOpen n8n (localhost:5678)"
else
    menu="n8n: Stopped 🔴 ($ngrok_status_label)\nStart"
fi

chosen=$(echo -e "$menu" | rofi -dmenu -p "Docker" -theme "$THEME")

# Compares a fresh hash of docker-compose.yml against the hash saved after
# the last time we actually applied it. If they differ (or nothing was
# saved yet), the compose file has unapplied changes -- meaning env vars,
# ports, volumes etc. would be stale if we just resumed the old container.
needs_recreate() {
    local current_hash
    current_hash=$(sha256sum "$COMPOSE_FILE" | awk '{print $1}')

    if [ ! -f "$HASH_FILE" ]; then
        echo "yes"
        return
    fi

    local saved_hash
    saved_hash=$(cat "$HASH_FILE")

    if [ "$current_hash" != "$saved_hash" ]; then
        echo "yes"
    else
        echo "no"
    fi
}

save_hash() {
    sha256sum "$COMPOSE_FILE" | awk '{print $1}' > "$HASH_FILE"
}

case "$chosen" in
    "Start")
        start_ngrok

        if [ "$(needs_recreate)" == "yes" ]; then
            # Compose file changed since we last applied it (or first run) --
            # do a full recreate so new env vars / config actually take effect.
            result=$(cd "$COMPOSE_DIR" && docker compose down && docker compose up -d 2>&1)
            status=$?
            if [ "$status" -eq 0 ]; then
                save_hash
                show_result "Docker" "n8n + ngrok started (config changes applied)"
            else
                show_result "Docker" "Failed to start n8n: $result"
            fi
        else
            # No config changes -- fast path, just resume the existing container.
            result=$(cd "$COMPOSE_DIR" && docker compose start 2>&1)
            status=$?
            if [ "$status" -eq 0 ]; then
                show_result "Docker" "n8n + ngrok started"
            else
                show_result "Docker" "Failed to start n8n: $result"
            fi
        fi
        ;;
    "Stop")
        result=$(cd "$COMPOSE_DIR" && docker compose stop 2>&1)
        status=$?
        stop_ngrok
        if [ "$status" -eq 0 ]; then
            show_result "Docker" "n8n + ngrok stopped"
        else
            show_result "Docker" "Failed to stop n8n: $result"
        fi
        ;;
    "Open n8n (localhost:5678)")
        xdg-open "http://localhost:5678" >/dev/null 2>&1 &
        ;;
esac