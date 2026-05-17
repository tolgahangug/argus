#!/usr/bin/env bash
# Argus V3 Observer - Security
source /opt/clawsetup/lib/common.sh

VPS_NAME=$(jq -r '.vps_name // empty' "$CONFIG" 2>/dev/null)
[ -z "$VPS_NAME" ] && VPS_NAME=$(hostname)

LOG_FILE="/var/log/auth.log"
[ ! -f "$LOG_FILE" ] && LOG_FILE="/var/log/secure"
if [ ! -f "$LOG_FILE" ]; then
    log "SECURITY: auth log not found"
    exit 0
fi

LINE_FILE="$STATE_DIR/ssh_last_line"
CURRENT_LINE=$(wc -l < "$LOG_FILE")
LAST_LINE=$(cat "$LINE_FILE" 2>/dev/null || echo "$CURRENT_LINE")
echo "$CURRENT_LINE" > "$LINE_FILE"

if [ "$CURRENT_LINE" -gt "$LAST_LINE" ]; then
    NEW_LINES=$(sed -n "$((LAST_LINE + 1)),${CURRENT_LINE}p" "$LOG_FILE")

    # Standard SSH accepted login
    NEW_LOGINS=$(echo "$NEW_LINES" | grep "Accepted")
    if [ -n "$NEW_LOGINS" ]; then
        IP=$(echo "$NEW_LOGINS" | head -1 | grep -oP 'from \K\S+' || echo "unknown")
        /opt/clawsetup/bin/emit-event.sh "yellow" "SECURITY" "${VPS_NAME}
SSH login: Tolga from ${IP}"
        log "SECURITY: SSH login - Tolga from $IP"
    fi

    # Root login refused (brute force attempt) - info only, no Telegram
    ROOT_ATTEMPTS=$(echo "$NEW_LINES" | grep "ROOT LOGIN REFUSED FROM")
    if [ -n "$ROOT_ATTEMPTS" ]; then
        IP=$(echo "$ROOT_ATTEMPTS" | head -1 | grep -oP 'FROM \K\S+' || echo "unknown")
        COUNT=$(echo "$ROOT_ATTEMPTS" | wc -l)
        /opt/clawsetup/bin/emit-event.sh "info" "SECURITY" "${VPS_NAME}
Root attack: ${COUNT}x from ${IP}"
        log "SECURITY: Root attack - ${COUNT}x from $IP"
    fi
fi
