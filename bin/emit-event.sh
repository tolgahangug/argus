#!/usr/bin/env bash
# ClawSetup V3 - Event Emitter
# Usage: emit-event.sh <type> <source> <message>
# Types: red | yellow | info
#
# Writes a single JSON event file to the queue.
# hub-process.sh picks it up and sends to Telegram.

source /opt/clawsetup/lib/common.sh

TYPE="${1:-info}"
SOURCE="${2:-unknown}"
MSG="${3:-No message}"
TS=$(date +%s)
FILE="$QUEUE_DIR/evt_${TS}_${SOURCE}.json"

# Use jq to build JSON safely - handles quotes, special chars in MSG
jq -n \
    --arg type "$TYPE" \
    --arg source "$SOURCE" \
    --arg message "$MSG" \
    --argjson timestamp "$TS" \
    '{"type": $type, "source": $source, "message": $message, "timestamp": $timestamp}' \
    > "$FILE"

log "Event queued: [$TYPE] $SOURCE - $MSG"
