set -e

REPO_DIR=$(dirname "$(realpath "$0")")/..
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "[setup] Installing daily backup timer..."

mkdir -p "$SYSTEMD_USER_DIR"

sed "s|/home/%u/dotbackup|$REPO_DIR|g" "$REPO_DIR/systemd/dotbackup.service" \
  > "$SYSTEMD_USER_DIR/dotbackup.service"

cp "$REPO_DIR/systemd/dotbackup.timer" "$SYSTEMD_USER_DIR/dotbackup.timer"

echo "[setup]  ✓ Unit files installed to $SYSTEMD_USER_DIR"

chmod +x "$REPO_DIR/scripts/backup.sh"
chmod +x "$REPO_DIR/scripts/restore.sh"
echo "[setup]  ✓ scripts made executable"

systemctl --user daemon-reload

systemctl --user enable dotbackup.timer
systemctl --user start dotbackup.timer

loginctl enable-linger "$USER" 2>/dev/null || true

echo ""
echo "[setup] done! Timer is active."
echo ""
echo "Useful commands:"
echo "  Check timer status:    systemctl --user status dotbackup.timer"
echo "  See all timers:        systemctl --user list-timers"
echo "  Run backup manually:   systemctl --user start dotbackup.service"
echo "  View backup logs:      journalctl --user -u dotbackup.service -f"
echo "  Disable timer:         systemctl --user disable dotbackup.timer"
echo ""

echo "Next scheduled run:"
systemctl --user list-timers dotbackup.timer --no-pager 2>/dev/null || true
