#!/usr/bin/env bash
set -e

ROOT=$(dirname "$(realpath "$0")")/..

log()  { echo "[restore] $(date '+%H:%M:%S') $1"; }
warn() { echo "[restore] warn: $1"; }
ask()  { read -rp "[restore] $1 [y/n] " ans; [[ "$ans" =~ ^[Yy]$ ]]; }

log "starting"
ask "this will overwrite current settings. continue?" || { log "aborted"; exit 0; }

if [ -f "$ROOT/packages/apt.txt" ]; then
  sudo apt update -qq
  xargs -a "$ROOT/packages/apt.txt" sudo apt install -y --ignore-missing 2>/dev/null || warn "some apt packages failed"
fi

if [ -f "$ROOT/packages/snap.txt" ]; then
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "#"* ]] && continue
    sudo snap install "$pkg" 2>/dev/null || warn "snap: $pkg failed"
  done < "$ROOT/packages/snap.txt"
fi

if [ -f "$ROOT/packages/flatpak.txt" ] && command -v flatpak >/dev/null 2>&1; then
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == "#"* ]] && continue
    flatpak install -y "$pkg" 2>/dev/null || warn "flatpak: $pkg failed"
  done < "$ROOT/packages/flatpak.txt"
fi

if [ -f "$ROOT/packages/pip.txt" ] && command -v pip3 >/dev/null 2>&1; then
  pip3 install -r "$ROOT/packages/pip.txt" --break-system-packages 2>/dev/null || warn "some pip packages failed"
fi

if [ -f "$ROOT/packages/vscode-extensions.txt" ] && command -v code >/dev/null 2>&1; then
  while IFS= read -r ext; do
    [[ -z "$ext" || "$ext" == "#"* ]] && continue
    code --install-extension "$ext" --force 2>/dev/null || warn "vscode ext: $ext failed"
  done < "$ROOT/packages/vscode-extensions.txt"
fi

backup_dir="$HOME/.dotfiles_old_$(date +%Y%m%d)"
mkdir -p "$backup_dir"
for f in .bashrc .zshrc .bash_aliases .gitconfig .profile .p10k.zsh; do
  [ -f "$HOME/$f" ] && cp "$HOME/$f" "$backup_dir/" 2>/dev/null || true
done
log "old dotfiles saved to $backup_dir"

rsync -a "$ROOT/dotfiles/" "$HOME/"

if [ -d "$ROOT/dotfiles/vscode" ] && command -v code >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/Code/User"
  cp "$ROOT/dotfiles/vscode/"* "$HOME/.config/Code/User/" 2>/dev/null || true
fi

if [ -f "$ROOT/gnome/gnome.ini" ] && command -v dconf >/dev/null 2>&1; then
  dconf load /org/gnome/ < "$ROOT/gnome/gnome.ini"
fi

if [ -f "$ROOT/gnome/extensions.txt" ] && command -v gnome-extensions >/dev/null 2>&1; then
  sudo apt install -y gnome-shell-extensions 2>/dev/null || true
  while IFS= read -r ext; do
    gnome-extensions enable "$ext" 2>/dev/null || warn "extension $ext failed"
  done < "$ROOT/gnome/extensions.txt"
fi

if [ -f "$ROOT/misc/crontab.txt" ]; then
  crontab "$ROOT/misc/crontab.txt" 2>/dev/null || warn "crontab restore failed"
fi

log "done — log out and back in to apply gnome settings"
