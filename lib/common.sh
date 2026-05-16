#!/usr/bin/env bash
# ClawSetup V3 - Shared library
# Sourced by all bin/ scripts. Do not run directly.

CONFIG="/opt/clawsetup/etc/config.json"

if [ ! -f "$CONFIG" ]; then
    echo "[clawsetup] ERROR: config not found at $CONFIG" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "[clawsetup] ERROR: jq is required but not installed" >&2
    exit 1
fi

# Telegram credentials
TG_TOKEN=$(jq -r '.telegram.bot_token' "$CONFIG")
TG_CHAT_ID=$(jq -r '.telegram.chat_id' "$CONFIG")

# Hub settings
YELLOW_DEDUP=$(jq -r '.hub.yellow_dedup_minutes' "$CONFIG")

# Agent count
AGENT_COUNT=$(jq '.agents | length' "$CONFIG")

# Directories
QUEUE_DIR="/var/lib/clawsetup/events/queue"
ARCHIVE_DIR="/var/lib/clawsetup/events/archive"
STATE_DIR="/var/lib/clawsetup/state"
DEDUP_DIR="/var/lib/clawsetup/dedup"
LOG_DIR="/var/log/clawsetup"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/clawsetup.log"
}

# Helper: get agent field by index
# Usage: agent_field 0 name
agent_field() {
    local IDX=$1
    local FIELD=$2
    jq -r ".agents[$IDX].$FIELD" "$CONFIG"
}
