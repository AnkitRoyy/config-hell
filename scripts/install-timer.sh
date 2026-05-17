#!/usr/bin/env bash
# =============================================================
#  install-timer.sh — Set up the daily auto-backup systemd timer
#  Run this ONCE after cloning your dotbackup repo
# =============================================================
set -e

REPO_DIR=$(dirname "$(realpath "$0")")/..
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "[SETUP] Installing daily backup timer..."

# Create systemd user directory
mkdir -p "$SYSTEMD_USER_DIR"

# Copy unit files (with your actual repo path substituted in)
sed "s|/home/%u/dotbackup|$REPO_DIR|g" "$REPO_DIR/systemd/dotbackup.service" \
  > "$SYSTEMD_USER_DIR/dotbackup.service"

cp "$REPO_DIR/systemd/dotbackup.timer" "$SYSTEMD_USER_DIR/dotbackup.timer"

echo "[SETUP]  ✓ Unit files installed to $SYSTEMD_USER_DIR"

# Make backup.sh executable
chmod +x "$REPO_DIR/scripts/backup.sh"
chmod +x "$REPO_DIR/scripts/restore.sh"
echo "[SETUP]  ✓ Scripts made executable"

# Reload systemd user daemon
systemctl --user daemon-reload

# Enable and start the timer
systemctl --user enable dotbackup.timer
systemctl --user start dotbackup.timer

# Enable lingering so timer runs even when not logged in
loginctl enable-linger "$USER" 2>/dev/null || true

echo ""
echo "[SETUP] ✅ Done! Timer is active."
echo ""
echo "Useful commands:"
echo "  Check timer status:    systemctl --user status dotbackup.timer"
echo "  See all timers:        systemctl --user list-timers"
echo "  Run backup manually:   systemctl --user start dotbackup.service"
echo "  View backup logs:      journalctl --user -u dotbackup.service -f"
echo "  Disable timer:         systemctl --user disable dotbackup.timer"
echo ""

# Show when next backup will run
echo "Next scheduled run:"
systemctl --user list-timers dotbackup.timer --no-pager 2>/dev/null || true
