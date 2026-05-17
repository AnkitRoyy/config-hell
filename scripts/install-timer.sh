#!/usr/bin/env bash
set -e

REPO_DIR=$(dirname "$(realpath "$0")")/..
SYSTEMD_DIR="$HOME/.config/systemd/user"

mkdir -p "$SYSTEMD_DIR"

sed "s|/home/%u/config-hell|$REPO_DIR|g" "$REPO_DIR/systemd/dotbackup.service" \
  > "$SYSTEMD_DIR/dotbackup.service"

cp "$REPO_DIR/systemd/dotbackup.timer" "$SYSTEMD_DIR/dotbackup.timer"

chmod +x "$REPO_DIR/scripts/backup.sh"
chmod +x "$REPO_DIR/scripts/restore.sh"

systemctl --user daemon-reload
systemctl --user enable dotbackup.timer
systemctl --user start dotbackup.timer

loginctl enable-linger "$USER" 2>/dev/null || true

echo ""
echo "timer installed and active."
echo ""
echo "status:       systemctl --user status dotbackup.timer"
echo "run now:      systemctl --user start dotbackup.service"
echo "logs:         journalctl --user -u dotbackup.service -f"
echo "disable:      systemctl --user disable dotbackup.timer"
echo ""

systemctl --user list-timers dotbackup.timer --no-pager 2>/dev/null || true
