#!/usr/bin/env bash
# Argus V3 - Hub Processor

source /opt/clawsetup/lib/common.sh

mkdir -p "$DEDUP_DIR"

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=$1" \
        -d "parse_mode=Markdown" > /dev/null
}

is_deduped() {
    local SOURCE="$1" TYPE="$2"
    local DEDUP_FILE="$DEDUP_DIR/${SOURCE}.last"
    [ "$TYPE" = "red" ] && return 1
    [ "$TYPE" = "info" ] && return 0
    if [ -f "$DEDUP_FILE" ]; then
        local LAST NOW WINDOW
        LAST=$(cat "$DEDUP_FILE")
        NOW=$(date +%s)
        WINDOW=$(( YELLOW_DEDUP * 60 ))
        [ $(( NOW - LAST )) -lt "$WINDOW" ] && return 0
    fi
    return 1
}

mark_sent() { echo "$(date +%s)" > "$DEDUP_DIR/${1}.last"; }

emoji_for_type() {
    case "$1" in
        red)    echo "🚨" ;;
        yellow) echo "🟡" ;;
        info)   echo "ℹ️" ;;
        *)      echo "🔔" ;;
    esac
}

for EVENT_FILE in "$QUEUE_DIR"/evt_*.json; do
    [ -e "$EVENT_FILE" ] || continue

    TYPE=$(jq -r '.type' "$EVENT_FILE" 2>/dev/null)
    SOURCE=$(jq -r '.source' "$EVENT_FILE" 2>/dev/null)
    MSG=$(jq -r '.message' "$EVENT_FILE" 2>/dev/null)

    if [ -z "$TYPE" ] || [ "$TYPE" = "null" ] || [ -z "$MSG" ] || [ "$MSG" = "null" ]; then
        mv "$EVENT_FILE" "$ARCHIVE_DIR/"
        continue
    fi

    mv "$EVENT_FILE" "$ARCHIVE_DIR/"

    [ "$TYPE" = "info" ] && { log "HUB: info from $SOURCE logged only"; continue; }

    if is_deduped "$SOURCE" "$TYPE"; then
        log "HUB: deduped [$TYPE] $SOURCE"
        continue
    fi

    EMOJI=$(emoji_for_type "$TYPE")
    send_telegram "${EMOJI} *Argus Alert*
${MSG}"

    mark_sent "$SOURCE"
    log "HUB: sent [$TYPE] $SOURCE - $MSG"
done
