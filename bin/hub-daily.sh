#!/usr/bin/env bash
# Argus V3 - Daily Summary

source /opt/clawsetup/lib/common.sh

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=$1" \
        -d "parse_mode=Markdown" > /dev/null
}

SINCE=$(date -d '24 hours ago' +%s 2>/dev/null || date -v-24H +%s)
COUNT=0; RED=0; YELLOW=0
LINES=""

for f in "$ARCHIVE_DIR"/evt_*.json; do
    [ -e "$f" ] || continue
    TS=$(jq -r '.timestamp' "$f" 2>/dev/null)
    TYPE=$(jq -r '.type' "$f" 2>/dev/null)
    SOURCE=$(jq -r '.source' "$f" 2>/dev/null)
    MSG=$(jq -r '.message' "$f" 2>/dev/null)
    [ -z "$TS" ] || [ "$TS" = "null" ] && continue
    ! [[ "$TS" =~ ^[0-9]+$ ]] && continue
    [ "$TS" -lt "$SINCE" ] && continue
    COUNT=$((COUNT+1))
    [ "$TYPE" = "red" ] && RED=$((RED+1))
    [ "$TYPE" = "yellow" ] && YELLOW=$((YELLOW+1))
    T=$(date -d "@$TS" '+%H:%M' 2>/dev/null || echo "??:??")
    LINES="${LINES}
${T} [${TYPE^^}] ${MSG}"
done

# Agent status
STATUS=""
for (( i=0; i<AGENT_COUNT; i++ )); do
    NAME=$(agent_field $i name)
    STATE=$(cat "$STATE_DIR/health_${NAME}" 2>/dev/null || echo "up")
    [ "$STATE" = "up" ] && ICON="✅" || ICON="🔴"
    STATUS="${STATUS} ${ICON}${NAME}"
done

[ "$COUNT" -eq 0 ] && EVENTS="All quiet." || EVENTS="${RED}🚨 ${YELLOW}🟡${LINES}"

TEXT="📊 *Argus Daily* — $(date '+%b %d')
${STATUS}

${EVENTS}"

send_telegram "$TEXT"
log "DAILY: sent ($COUNT events)"
