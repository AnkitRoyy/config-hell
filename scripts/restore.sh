#!/usr/bin/env bash
# =============================================================
#  restore.sh — Restore Ubuntu system from git backup
#  Run this on a fresh Ubuntu machine after cloning your repo
# =============================================================
set -e

ROOT=$(dirname "$(realpath "$0")")/..

log()  { echo "[RESTORE] $(date '+%H:%M:%S') — $1"; }
warn() { echo "[RESTORE] ⚠️  $1"; }
ask()  { read -rp "[RESTORE] $1 [y/N] " ans; [[ "$ans" =~ ^[Yy]$ ]]; }

log "restore started"
log "Root: $ROOT"
warn "This will overwrite your current dotfiles and settings."
ask "Continue?" || { log "Aborted."; exit 0; }

if [ -f "$ROOT/packages/apt.txt" ]; then
  log "Installing APT packages..."
  sudo apt update -qq
  xargs -a "$ROOT/packages/apt.txt" sudo apt install -y --ignore-missing 2>/dev/null || warn "Some APT packages failed — check apt.txt."
  log "  ✓ APT packages installed"
fi

if [ -f "$ROOT/packages/snap.txt" ]; then
  log "Installing Snap packages..."
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "#"* ]] && continue
    sudo snap install "$pkg" 2>/dev/null || warn "snap install $pkg failed — skipped."
  done < "$ROOT/packages/snap.txt"
  log "  ✓ Snap packages installed"
fi

if [ -f "$ROOT/packages/flatpak.txt" ] && command -v flatpak >/dev/null 2>&1; then
  log "Installing Flatpak packages..."
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "#"* ]] && continue
    flatpak install -y "$pkg" 2>/dev/null || warn "flatpak install $pkg failed — skipped."
  done < "$ROOT/packages/flatpak.txt"
  log "  ✓ Flatpak packages installed"
fi

if [ -f "$ROOT/packages/pip.txt" ] && command -v pip3 >/dev/null 2>&1; then
  log "Installing pip packages..."
  pip3 install -r "$ROOT/packages/pip.txt" --break-system-packages 2>/dev/null || warn "Some pip packages failed."
  log "  ✓ pip packages installed"
fi

if [ -f "$ROOT/packages/vscode-extensions.txt" ] && command -v code >/dev/null 2>&1; then
  log "Installing VSCode extensions..."
  while IFS= read -r ext; do
    [[ -z "$ext" || "$ext" == "#"* ]] && continue
    code --install-extension "$ext" --force 2>/dev/null || warn "Extension $ext failed — skipped."
  done < "$ROOT/packages/vscode-extensions.txt"
  log "  ✓ VSCode extensions installed"
fi

log "Restoring dotfiles..."
mkdir -p "$HOME/.dotfiles_backup_$(date +%Y%m%d)"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d)"

for f in .bashrc .zshrc .bash_aliases .gitconfig .profile .p10k.zsh; do
  [ -f "$HOME/$f" ] && cp "$HOME/$f" "$BACKUP_DIR/" 2>/dev/null || true
done
log "  ✓ Old dotfiles backed up to $BACKUP_DIR"

rsync -a "$ROOT/dotfiles/" "$HOME/"
log "  ✓ Dotfiles restored"

VSCODE_USER="$HOME/.config/Code/User"
if [ -d "$ROOT/dotfiles/vscode" ] && command -v code >/dev/null 2>&1; then
  mkdir -p "$VSCODE_USER"
  cp "$ROOT/dotfiles/vscode/"* "$VSCODE_USER/" 2>/dev/null || true
  log "  ✓ VSCode settings restored"
fi

if [ -f "$ROOT/gnome/gnome.ini" ] && command -v dconf >/dev/null 2>&1; then
  log "Restoring GNOME settings..."
  dconf load /org/gnome/ < "$ROOT/gnome/gnome.ini"
  log "  ✓ dconf settings restored"
fi

if [ -f "$ROOT/gnome/extensions.txt" ] && command -v gnome-extensions >/dev/null 2>&1; then
  log "Enabling GNOME extensions..."
  sudo apt install -y gnome-shell-extensions 2>/dev/null || true
  while IFS= read -r ext; do
    gnome-extensions enable "$ext" 2>/dev/null || warn "Extension $ext failed — may need manual install."
  done < "$ROOT/gnome/extensions.txt"
  log "  ✓ Extensions enabled"
fi

if [ -f "$ROOT/misc/crontab.txt" ]; then
  log "Restoring crontab..."
  crontab "$ROOT/misc/crontab.txt" 2>/dev/null || warn "Crontab restore failed."
  log "  ✓ crontab restored"
fi

log "restore completed"
log ""
log "next steps:"
log "   1. log out and back in for GNOME to fully apply"
log "   2. re-source your shell: source ~/.bashrc or source ~/.zshrc"
log "   3. check SSH keys — private keys are NOT in backup (add manually)"
log "   4. re-authenticate git: gh auth login or set up SSH key"
