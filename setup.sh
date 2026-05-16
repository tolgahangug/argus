#!/usr/bin/env bash
# ClawSetup V3 - Installer
# Run as root: sudo bash setup.sh

set -e

echo "==============================="
echo " ClawSetup V3 Observer Installer"
echo "==============================="

for dep in jq curl; do
    if ! command -v "$dep" &>/dev/null; then
        echo "Installing: $dep"
        apt-get install -y "$dep" -q
    fi
done

mkdir -p /opt/clawsetup/{bin,etc,lib}
mkdir -p /var/lib/clawsetup/events/{queue,archive}
mkdir -p /var/lib/clawsetup/{state,dedup}
mkdir -p /var/log/clawsetup

cp lib/common.sh   /opt/clawsetup/lib/common.sh
cp bin/*.sh        /opt/clawsetup/bin/
chmod +x /opt/clawsetup/bin/*.sh
chmod 644 /opt/clawsetup/lib/common.sh

# Only copy config if it doesn't exist yet (don't overwrite on update)
if [ ! -f /opt/clawsetup/etc/config.json ]; then
    cp etc/config.json /opt/clawsetup/etc/config.json
    chmod 600 /opt/clawsetup/etc/config.json
    echo ""
    echo "Config installed. Edit before activating crons:"
    echo "  sudo nano /opt/clawsetup/etc/config.json"
else
    echo ""
    echo "Config already exists, skipping (edit manually if needed):"
    echo "  sudo nano /opt/clawsetup/etc/config.json"
fi

echo ""
echo "Add agents in config.json - example for 3 agents:"
cat << 'EXAMPLE'
  "agents": [
    { "name": "Jenny",  "workspace_path": "/opt/clients/john/jenny/workspace",  "container_name": "jc-assistant" },
    { "name": "Hailey", "workspace_path": "/opt/clients/john/hailey/workspace", "container_name": "jc-operations" },
    { "name": "Carl",   "workspace_path": "/opt/clients/layne/carl/workspace",  "container_name": "carl" }
  ]
EXAMPLE

echo ""
echo "Then activate crons:"
echo "  sudo cp cron/clawsetup /etc/cron.d/clawsetup"
echo ""
echo "Test manually first:"
echo "  sudo bash /opt/clawsetup/bin/observer-health.sh"
echo "  sudo bash /opt/clawsetup/bin/hub-process.sh"
echo ""
echo "==============================="
echo " Done."
echo "==============================="
