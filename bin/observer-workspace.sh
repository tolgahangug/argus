#!/usr/bin/env bash
# Argus V3 Observer - Workspace
source /opt/clawsetup/lib/common.sh
VPS_NAME=$(jq -r '.vps_name // empty' "$CONFIG" 2>/dev/null)
[ -z "$VPS_NAME" ] && VPS_NAME=$(hostname)
for (( i=0; i<AGENT_COUNT; i++ )); do
    NAME=$(agent_field $i name)
    WORKSPACE=$(agent_field $i workspace_path)
    HASH_FILE="$STATE_DIR/workspace_hash_${NAME}"
    FILE_LIST="$STATE_DIR/workspace_files_${NAME}"
    if [ ! -d "$WORKSPACE" ]; then
        log "WORKSPACE: path not found for $NAME: $WORKSPACE"
        continue
    fi
    CUR_LIST=$(find "$WORKSPACE" -maxdepth 2 -type f -name "*.md" | sort | xargs md5sum 2>/dev/null)
    CUR_HASH=$(echo "$CUR_LIST" | md5sum | awk '{print $1}')
    if [ -z "$CUR_HASH" ]; then
        log "WORKSPACE: no .md files found for $NAME"
        continue
    fi
    OLD_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")
    if [ -z "$OLD_HASH" ]; then
        echo "$CUR_HASH" > "$HASH_FILE"
        echo "$CUR_LIST" > "$FILE_LIST"
        log "WORKSPACE: baseline stored for $NAME"
        continue
    fi
    if [ "$CUR_HASH" != "$OLD_HASH" ]; then
        OLD_LIST=$(cat "$FILE_LIST" 2>/dev/null || echo "")
        CHANGES=""
        while IFS= read -r line; do
            HASH=$(echo "$line" | awk '{print $1}')
            FILE=$(echo "$line" | awk '{print $2}')
            FNAME=$(basename "$FILE")
            if echo "$OLD_LIST" | grep -q "$FILE"; then
                OLD_HASH_FILE=$(echo "$OLD_LIST" | grep "$FILE" | awk '{print $1}')
                [ "$HASH" != "$OLD_HASH_FILE" ] && CHANGES="${CHANGES}modified:${FNAME} "
            else
                CHANGES="${CHANGES}created:${FNAME} "
            fi
        done <<< "$CUR_LIST"
        while IFS= read -r line; do
            FILE=$(echo "$line" | awk '{print $2}')
            FNAME=$(basename "$FILE")
            echo "$CUR_LIST" | grep -q "$FILE" || CHANGES="${CHANGES}deleted:${FNAME} "
        done <<< "$OLD_LIST"
        CHANGES=$(echo "$CHANGES" | xargs)
        /opt/clawsetup/bin/emit-event.sh "yellow" "WORKSPACE" "${VPS_NAME}
${NAME}: ${CHANGES}"
        echo "$CUR_HASH" > "$HASH_FILE"
        echo "$CUR_LIST" > "$FILE_LIST"
        log "WORKSPACE: $NAME - $CHANGES"
    fi
done
