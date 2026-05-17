
set -e

ROOT=$(dirname "$(realpath "$0")")/..

log()  { echo "[backup] $(date '+%H:%M:%S') — $1"; }
warn() { echo "[backup] $1"; }

log "=========================================="
log "Backup started"
log "Root: $ROOT"
log "=========================================="

log "Syncing dotfiles..."
mkdir -p "$ROOT/dotfiles"

FILES_TO_BACKUP=(
  "$HOME/.bashrc"
  "$HOME/.zshrc"
  "$HOME/.bash_aliases"
  "$HOME/.zsh_aliases"
  "$HOME/.gitconfig"
  "$HOME/.profile"
  "$HOME/.p10k.zsh"
)

for f in "${FILES_TO_BACKUP[@]}"; do
  [ -f "$f" ] && rsync -a "$f" "$ROOT/dotfiles/" && log "  ✓ $(basename $f)"
done

if [ -d "$HOME/.config/nvim" ]; then
  rsync -a --delete "$HOME/.config/nvim" "$ROOT/dotfiles/.config/"
  log "  ✓ nvim config"
fi

if [ -d "$HOME/.config/kitty" ]; then
  rsync -a --delete "$HOME/.config/kitty" "$ROOT/dotfiles/.config/"
  log "  ✓ kitty config"
fi

VSCODE_USER="$HOME/.config/Code/User"
if [ -d "$VSCODE_USER" ]; then
  mkdir -p "$ROOT/dotfiles/vscode"
  [ -f "$VSCODE_USER/settings.json" ]    && cp "$VSCODE_USER/settings.json"    "$ROOT/dotfiles/vscode/"
  [ -f "$VSCODE_USER/keybindings.json" ] && cp "$VSCODE_USER/keybindings.json" "$ROOT/dotfiles/vscode/"
  log "  ✓ VSCode settings"
fi

if [ -f "$HOME/.ssh/config" ]; then
  mkdir -p "$ROOT/dotfiles/ssh"
  cp "$HOME/.ssh/config" "$ROOT/dotfiles/ssh/config"
  log "  ✓ SSH config (no private keys)"
fi

log "Dotfiles synced."

log "Exporting package lists..."
mkdir -p "$ROOT/packages"

dpkg --get-selections | awk '{print $1}' > "$ROOT/packages/apt.txt"
log "  ✓ APT packages ($(wc -l < "$ROOT/packages/apt.txt") pkgs)"

if command -v snap >/dev/null 2>&1; then
  snap list | awk 'NR>1 {print $1}' > "$ROOT/packages/snap.txt"
  log "  ✓ Snap packages ($(wc -l < "$ROOT/packages/snap.txt") pkgs)"
fi

if command -v flatpak >/dev/null 2>&1; then
  flatpak list --app --columns=application > "$ROOT/packages/flatpak.txt"
  log "  ✓ Flatpak packages"
fi

if command -v pip3 >/dev/null 2>&1; then
  pip3 list --format=freeze > "$ROOT/packages/pip.txt" 2>/dev/null || true
  log "  ✓ pip packages"
fi

if command -v code >/dev/null 2>&1; then
  code --list-extensions > "$ROOT/packages/vscode-extensions.txt" 2>/dev/null || true
  log "  ✓ VSCode extensions ($(wc -l < "$ROOT/packages/vscode-extensions.txt") extensions)"
fi

log "Package lists saved."

if command -v dconf >/dev/null 2>&1; then
  log "Exporting GNOME settings..."
  mkdir -p "$ROOT/gnome"
  dconf dump /org/gnome/ > "$ROOT/gnome/gnome.ini"
  log "  ✓ dconf settings"

  if command -v gnome-extensions >/dev/null 2>&1; then
    gnome-extensions list > "$ROOT/gnome/extensions.txt"
    log "  ✓ GNOME extensions list"
  fi
  log "GNOME settings exported."
fi

if command -v ufw >/dev/null 2>&1; then
  log "Exporting UFW rules..."
  mkdir -p "$ROOT/ufw"
  sudo ufw status verbose > "$ROOT/ufw/rules.txt" 2>/dev/null || warn "UFW export needs sudo — skipped."
  log "  ✓ UFW rules"
fi

log "Backing up crontab..."
mkdir -p "$ROOT/misc"
crontab -l > "$ROOT/misc/crontab.txt" 2>/dev/null || echo "# No crontab" > "$ROOT/misc/crontab.txt"
log "  ✓ crontab"

log "Committing to git..."
cd "$ROOT"
git add .

CHANGED=$(git diff --cached --name-only | wc -l)
if [ "$CHANGED" -gt 0 ]; then
  git commit -m "auto-backup: $(date '+%Y-%m-%d %H:%M') — $CHANGED file(s) changed"
  log "  ✓ Committed ($CHANGED files changed)"

  git push && log "  ✓ Pushed to remote" || warn "Push failed — check your git remote/auth."
else
  log "nothing changed, skipping commit."
fi

log "backup completed successfully"
