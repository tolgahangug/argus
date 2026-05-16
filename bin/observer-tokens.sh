#!/usr/bin/env bash
# Argus V3 Observer - Token Cost Monitor
source /opt/clawsetup/lib/common.sh

VPS_NAME=$(jq -r '.vps_name // empty' "$CONFIG" 2>/dev/null)
[ -z "$VPS_NAME" ] && VPS_NAME=$(hostname)

THRESHOLD=$(jq -r '.hub.cost_alert_threshold // 5.00' "$CONFIG" 2>/dev/null)

WINDOW=3600
NOW=$(date +%s)
CUTOFF=$(( NOW - WINDOW ))

TOTAL_COST=0

for (( i=0; i<AGENT_COUNT; i++ )); do
    NAME=$(agent_field $i name)
    CONTAINER=$(agent_field $i container_name)
    [ "$CONTAINER" != "null" ] && [ -n "$CONTAINER" ] && continue

    WORKSPACE=$(agent_field $i workspace_path)
    OPENCLAW_DIR=$(echo "$WORKSPACE" | sed 's|/workspace||')
    AGENTS_DIR="${OPENCLAW_DIR}/agents"

    if [ ! -d "$AGENTS_DIR" ]; then
        AGENTS_DIR=$(find /root /home -path "*/.openclaw/agents" -type d 2>/dev/null | head -1)
    fi

    if [ ! -d "$AGENTS_DIR" ]; then
        log "TOKENS: agents dir not found for $NAME"
        continue
    fi

    AGENT_COST=0

    while IFS= read -r JSONL_FILE; do
        FILE_MOD=$(stat -c %Y "$JSONL_FILE" 2>/dev/null || echo 0)
        [ "$FILE_MOD" -lt "$CUTOFF" ] && continue

        while IFS= read -r line; do
            TS_RAW=$(echo "$line" | jq -r '.timestamp // empty' 2>/dev/null)
            [ -z "$TS_RAW" ] && continue
            TS=$(date -d "$TS_RAW" +%s 2>/dev/null || echo 0)
            [ "$TS" -lt "$CUTOFF" ] && continue
            COST=$(echo "$line" | jq -r '.message.usage.cost.total // empty' 2>/dev/null)
            [ -z "$COST" ] && continue
            [[ "$COST" =~ ^[0-9]+(\.[0-9]+)?$ ]] || continue
            AGENT_COST=$(echo "$AGENT_COST + $COST" | bc 2>/dev/null || echo "$AGENT_COST")
        done < "$JSONL_FILE"
    done < <(find "$AGENTS_DIR" -name "*.jsonl" -not -name "*.trajectory.jsonl" 2>/dev/null)

    log "TOKENS: $NAME cost last 60min = \$$AGENT_COST"
    TOTAL_COST=$(echo "$TOTAL_COST + $AGENT_COST" | bc 2>/dev/null || echo "$TOTAL_COST")

    OVER=$(echo "$AGENT_COST > $THRESHOLD" | bc 2>/dev/null || echo 0)
    if [ "$OVER" = "1" ]; then
        /opt/clawsetup/bin/emit-event.sh "red" "TOKENS" "${VPS_NAME}
${NAME}: cost spike \$${AGENT_COST} in last 60min"
        log "TOKENS: ALERT - $NAME exceeded threshold (\$$AGENT_COST > \$$THRESHOLD)"
    fi
done
