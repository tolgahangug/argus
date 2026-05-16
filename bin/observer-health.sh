#!/usr/bin/env bash
# Argus V3 Observer - Health
source /opt/clawsetup/lib/common.sh
VPS_NAME=$(jq -r '.vps_name // empty' "$CONFIG" 2>/dev/null)
[ -z "$VPS_NAME" ] && VPS_NAME=$(hostname)
for (( i=0; i<AGENT_COUNT; i++ )); do
    NAME=$(agent_field $i name)
    CONTAINER=$(agent_field $i container_name)
    STATE_FILE="$STATE_DIR/health_${NAME}"
    if [ "$CONTAINER" != "null" ] && [ -n "$CONTAINER" ]; then
        STATUS=$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)
        [ "$STATUS" = "true" ] && CURRENT="up" || CURRENT="down"
    else
        pgrep -f "openclaw" > /dev/null 2>&1 && CURRENT="up" || CURRENT="down"
    fi
    LAST=$(cat "$STATE_FILE" 2>/dev/null || echo "up")
    if [ "$CURRENT" = "down" ] && [ "$LAST" != "down" ]; then
        /opt/clawsetup/bin/emit-event.sh "red" "HEALTH" "${VPS_NAME}
${NAME} is DOWN"
        echo "down" > "$STATE_FILE"
        log "HEALTH: $NAME went DOWN"
    elif [ "$CURRENT" = "up" ] && [ "$LAST" = "down" ]; then
        /opt/clawsetup/bin/emit-event.sh "info" "HEALTH" "${VPS_NAME}
${NAME} is back online"
        echo "up" > "$STATE_FILE"
        log "HEALTH: $NAME back online"
    fi
done
