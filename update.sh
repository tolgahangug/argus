#!/usr/bin/env bash
# Argus - Update Script
# Run from the cloned repo directory: sudo bash update.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==============================="
echo " Argus Update"
echo "==============================="

# Pull latest
echo "Pulling latest from GitHub..."
git -C "$REPO_DIR" pull

# Deploy bin
echo "Deploying bin..."
cp "$REPO_DIR"/bin/*.sh /opt/clawsetup/bin/
chmod +x /opt/clawsetup/bin/*.sh

# Deploy lib
echo "Deploying lib..."
cp "$REPO_DIR"/lib/common.sh /opt/clawsetup/lib/common.sh
chmod 644 /opt/clawsetup/lib/common.sh

# Deploy cron
echo "Deploying cron..."
cp "$REPO_DIR"/cron/clawsetup /etc/cron.d/clawsetup

echo ""
echo "Done. Config not touched -- edit manually if needed:"
echo "  sudo nano /opt/clawsetup/etc/config.json"
echo "==============================="
