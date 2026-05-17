# =========================================================
# ARGUS V3 — INSTALLATION MANUAL
# ClawSetup Monitoring System for OpenClaw AI Agents
# =========================================================
# Bash-based, lightweight, watch-only observer system
# Sends Telegram alerts for agent health, security, workspace, and token cost
# GitHub: https://github.com/tolgahangug/argus
# =========================================================


# =========================================================
# PREREQUISITES
# =========================================================

# - Ubuntu 24.04 VPS
# - Tailscale installed and connected (sudo tailscale up --ssh)
# - jq installed (setup.sh installs it automatically)
# - curl installed (setup.sh installs it automatically)
# - Git installed
# - OpenClaw running (bare metal only for now, no Docker support in token observer)


# =========================================================
# STEP 1 — CLONE AND INSTALL
# =========================================================

git clone https://github.com/tolgahangug/argus.git
cd argus
sudo bash setup.sh

# EXPECTED OUTPUT:
# ===============================
#  ClawSetup V3 Observer Installer
# ===============================
# Config installed. Edit before activating crons:
#   sudo nano /opt/clawsetup/etc/config.json
# ===============================
#  Done.
# ===============================

# POSSIBLE ERROR: "Config already exists, skipping"
# CAUSE: Previous install exists
# FIX: Edit existing config manually
#   sudo nano /opt/clawsetup/etc/config.json


# =========================================================
# STEP 2 — FIND WORKSPACE PATH
# =========================================================

sudo find / -name "SOUL.md" 2>/dev/null | grep -v "templates\|docs"

# EXPECTED: Path like /root/.openclaw/workspace/SOUL.md
# Your workspace_path = /root/.openclaw/workspace

# POSSIBLE: No output
# FIX: Try broader search
sudo find / -name ".openclaw" -type d 2>/dev/null


# =========================================================
# STEP 3 — EDIT CONFIG
# =========================================================

sudo tee /opt/clawsetup/etc/config.json << 'EOF'
{
  "vps_name": "CLIENT-VPS-NAME",
  "telegram": {
    "bot_token": "8673003552:AAEypQjSzmDTSAuGxtpIOIcs9Av9fOPpbBM",
    "chat_id": "8319975554"
  },
  "agents": [
    {
      "name": "AgentName",
      "workspace_path": "/root/.openclaw/workspace",
      "container_name": null
    }
  ],
  "hub": {
    "yellow_dedup_minutes": 30,
    "cost_alert_threshold": 5.00
  }
}
EOF

# container_name: null = bare metal (pgrep -f openclaw)
# container_name: "jenny" = Docker container (docker inspect)

# VERIFY CONFIG IS VALID JSON:
jq . /opt/clawsetup/etc/config.json

# POSSIBLE ERROR: jq parse error
# CAUSE: Missing comma, quote, or bracket in config
# FIX: Re-run the tee command above with correct values


# =========================================================
# STEP 4 — CREATE LOG FILE
# =========================================================

sudo touch /var/log/clawsetup/clawsetup.log


# =========================================================
# STEP 5 — TEST TELEGRAM
# =========================================================

curl -s -X POST "https://api.telegram.org/bot8673003552:AAEypQjSzmDTSAuGxtpIOIcs9Av9fOPpbBM/sendMessage" \
  -d chat_id=8319975554 \
  -d text="Argus test from CLIENT-VPS-NAME"

# EXPECTED: {"ok":true,...}
# POSSIBLE ERROR: {"ok":false,...}
# CAUSE: Wrong bot token or chat_id
# FIX: Verify credentials in config.json


# =========================================================
# STEP 6 — TEST HEALTH OBSERVER
# =========================================================

sudo bash /opt/clawsetup/bin/observer-health.sh
tail -5 /var/log/clawsetup/clawsetup.log

# EXPECTED: No output if agent is up (correct behavior)
# Force a test by simulating down state:
echo "down" | sudo tee /var/lib/clawsetup/state/health_AGENTNAME
sudo bash /opt/clawsetup/bin/observer-health.sh
sudo bash /opt/clawsetup/bin/hub-process.sh
tail -5 /var/log/clawsetup/clawsetup.log

# EXPECTED LOG: HEALTH: AgentName back online (info only, no Telegram)


# =========================================================
# STEP 7 — TEST WORKSPACE OBSERVER
# =========================================================

sudo bash /opt/clawsetup/bin/observer-workspace.sh
tail -5 /var/log/clawsetup/clawsetup.log

# EXPECTED: WORKSPACE: baseline stored for AgentName
# POSSIBLE: WORKSPACE: path not found for AgentName
# FIX: Check workspace_path in config.json matches actual path

# Reset baseline for re-testing:
sudo rm /var/lib/clawsetup/state/workspace_hash_AGENTNAME


# =========================================================
# STEP 8 — TEST TOKEN OBSERVER
# =========================================================

sudo bash /opt/clawsetup/bin/observer-tokens.sh
tail -5 /var/log/clawsetup/clawsetup.log

# EXPECTED: TOKENS: AgentName cost last 60min = $0
# POSSIBLE: TOKENS: agents dir not found for AgentName
# FIX: Workspace path is wrong or agent hasn't run any sessions yet
# POSSIBLE: jq parse errors
# FIX: Config JSON is invalid — re-run tee command in Step 3


# =========================================================
# STEP 9 — ACTIVATE CRONS
# =========================================================

sudo cp ~/argus/cron/clawsetup /etc/cron.d/clawsetup
cat /etc/cron.d/clawsetup

# EXPECTED:
# * * * * * root /opt/clawsetup/bin/observer-health.sh
# * * * * * root /opt/clawsetup/bin/observer-security.sh
# * * * * * root /opt/clawsetup/bin/observer-workspace.sh
# */15 * * * * root /opt/clawsetup/bin/observer-tokens.sh
# * * * * * root /opt/clawsetup/bin/hub-process.sh
# 0 8 * * * root /opt/clawsetup/bin/hub-daily.sh


# =========================================================
# STEP 10 — ENABLE PASSWORDLESS SUDO FOR REMOTE UPDATES
# =========================================================

echo "USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/argus-update

# Replace USERNAME with the actual SSH user (clawsetup, user, etc.)


# =========================================================
# VERIFY EVERYTHING IS WORKING
# =========================================================

# Watch live log:
tail -f /var/log/clawsetup/clawsetup.log

# Check queue (should be empty if hub-process ran):
ls /var/lib/clawsetup/events/queue/

# Check dedup state:
ls -la /var/lib/clawsetup/dedup/

# Trigger daily summary now:
sudo bash /opt/clawsetup/bin/hub-daily.sh


# =========================================================
# UPDATE FLOW (after initial install)
# =========================================================

# On the server:
cd ~/argus && git pull && sudo bash update.sh

# Remote (from local machine, no password needed after Step 10):
ssh USERNAME@TAILSCALE_IP "cd ~/argus && git pull && sudo bash update.sh"

# Update all servers at once:
ssh clawsetup@100.72.164.25 "cd ~/argus && git pull && sudo bash update.sh" && \
ssh user@100.79.20.22 "cd ~/argus && git pull && sudo bash update.sh" && \
ssh clawsetup@100.79.58.80 "cd ~/argus && git pull && sudo bash update.sh"


# =========================================================
# DEBUG COMMANDS
# =========================================================

# Run any observer with full debug:
sudo bash -x /opt/clawsetup/bin/observer-health.sh 2>&1

# Reset security dedup (force next alert to send):
sudo rm /var/lib/clawsetup/dedup/SECURITY.last

# Reset workspace baseline (re-learn current state):
sudo rm /var/lib/clawsetup/state/workspace_hash_AGENTNAME

# Reset SSH line counter (re-scan auth.log from this point):
sudo rm /var/lib/clawsetup/state/ssh_last_line

# Clear archive (wipe daily summary history):
sudo rm /var/lib/clawsetup/events/archive/evt_*.json

# Clear all state (full reset):
sudo rm -rf /var/lib/clawsetup/state/*
sudo rm -rf /var/lib/clawsetup/dedup/*
sudo rm -rf /var/lib/clawsetup/events/archive/*


# =========================================================
# KNOWN ISSUES
# =========================================================

# 1. Log file missing on fresh install
#    SYMPTOM: tail: cannot open '/var/log/clawsetup/clawsetup.log'
#    FIX: sudo touch /var/log/clawsetup/clawsetup.log

# 2. Config JSON parse error
#    SYMPTOM: jq: parse error: Expected separator between values
#    FIX: Missing comma in config.json hub block — re-run tee command

# 3. Health shows agent as up but it's actually down
#    SYMPTOM: No alert firing
#    FIX: Check state file: cat /var/lib/clawsetup/state/health_AGENTNAME
#    FIX: Make sure openclaw process is running: pgrep -f openclaw

# 4. Workspace not detecting changes
#    SYMPTOM: No WORKSPACE alert after editing .md file
#    FIX: Check dedup window: sudo rm /var/lib/clawsetup/dedup/WORKSPACE.last
#    FIX: Reset baseline: sudo rm /var/lib/clawsetup/state/workspace_hash_AGENTNAME

# 5. Token observer shows $0 always
#    SYMPTOM: TOKENS: AgentName cost last 60min = $0
#    CAUSE: No sessions in last 60 minutes, or wrong agents dir path
#    FIX: Check path: find /root /home -path "*/.openclaw/agents" -type d

# 6. Git pull permission denied
#    SYMPTOM: error: cannot open '.git/FETCH_HEAD': Permission denied
#    CAUSE: Repo cloned as root, running as non-root user
#    FIX: sudo chown -R USERNAME:USERNAME ~/argus


# =========================================================
# CURRENT CLIENT SERVERS
# =========================================================

# mike-vps   | Agent: Laura  | SSH: clawsetup@100.72.164.25
# server2    | Agent: Watson | SSH: user@100.79.20.22
# cathy-vps  | Agent: Teddy  | SSH: clawsetup@100.79.58.80


# =========================================================
# NEW CHAT CONTEXT PROMPT
# =========================================================
# Paste this at the start of a new session to resume Argus development:
#
# I am building Argus, a bash-based AI agent monitoring system for my ClawSetup business.
# GitHub: https://github.com/tolgahangug/argus
#
# WHAT ARGUS IS:
# Lightweight bash observer system running on Ubuntu VPS servers. Watches OpenClaw AI agents
# and sends Telegram alerts via my dedicated watchdog bot. Watch-only, no actors yet.
#
# FILE STRUCTURE:
# /opt/clawsetup/
# ├── bin/
# │   ├── observer-health.sh      # checks if openclaw process is running
# │   ├── observer-security.sh    # watches auth.log for accepted SSH logins
# │   ├── observer-workspace.sh   # hashes .md files, alerts on change
# │   ├── observer-tokens.sh      # reads JSONL session files, alerts if cost > $5/hr
# │   ├── emit-event.sh           # writes events to queue
# │   ├── hub-process.sh          # processes queue, sends Telegram, handles dedup
# │   ├── hub-daily.sh            # daily summary at 08:00 UTC
# │   └── update.sh               # git pull + deploy (in repo root)
# ├── lib/
# │   └── common.sh               # shared config loader
# └── etc/
#     └── config.json             # main config, protected 600
#
# RUNTIME DIRS:
# /var/lib/clawsetup/events/queue/    # incoming events
# /var/lib/clawsetup/events/archive/  # processed events (used by daily summary)
# /var/lib/clawsetup/state/           # per-agent state files
# /var/lib/clawsetup/dedup/           # dedup timestamps
# /var/log/clawsetup/clawsetup.log    # all activity log
#
# ALERT TYPES:
# red    = never deduped, always sent (agent down)
# yellow = deduped per source, 30 min window (SSH login, workspace change)
# info   = never sent to Telegram, daily summary only (back online, brute force)
#
# CRON SCHEDULE:
# * * * * *    observer-health, observer-security, observer-workspace, hub-process
# */15 * * * * observer-tokens
# 0 8 * * *    hub-daily
#
# TELEGRAM:
# Bot token: 8673003552:AAEypQjSzmDTSAuGxtpIOIcs9Av9fOPpbBM
# Chat ID: 8319975554
# Bot: @clawsetup_watchdog_bot
#
# ALERT FORMAT (no header, clean):
# 🟡 mike-vps
# SSH login: Tolga from 10.0.0.15
#
# 🚨 server2
# Watson is DOWN
#
# TOKEN COST DATA:
# Stored in ~/.openclaw/agents/*/sessions/*.jsonl (not .trajectory.jsonl)
# Cost field: .message.usage.cost.total
# Observer reads files modified in last 60 min, sums cost, alerts if > $5
#
# CURRENT CLIENT SERVERS:
# mike-vps  | Agent: Laura  | SSH: clawsetup@100.72.164.25  | bare metal
# server2   | Agent: Watson | SSH: user@100.79.20.22         | bare metal
# cathy-vps | Agent: Teddy  | SSH: clawsetup@100.79.58.80   | bare metal
#
# UPDATE ALL SERVERS (one command, no password):
# ssh clawsetup@100.72.164.25 "cd ~/argus && git pull && sudo bash update.sh" && \
# ssh user@100.79.20.22 "cd ~/argus && git pull && sudo bash update.sh" && \
# ssh clawsetup@100.79.58.80 "cd ~/argus && git pull && sudo bash update.sh"
#
# WHAT IS NOT BUILT YET:
# - Monthly PDF report (raw data in archive, can generate anytime)
# - Container pause/unpause actors (shelved)
# - Daily summary cost tracking (observer-tokens.sh logs cost but doesn't store for reporting)
#
# STYLE RULES FOR THIS PROJECT:
# - No em dashes
# - Plain English, short and direct
# - ADHD-friendly: max 3 bullets, one step at a time
# - Never overwrite config.json during updates
# =========================================================
