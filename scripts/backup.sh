#!/usr/bin/env bash
set -e

ROOT=$(dirname "$(realpath "$0")")/..

log()  { echo "[backup] $(date '+%H:%M:%S') $1"; }
warn() { echo "[backup] warn: $1"; }

log "starting"

mkdir -p "$ROOT/dotfiles"

files=(
  "$HOME/.bashrc"
  "$HOME/.zshrc"
  "$HOME/.bash_aliases"
  "$HOME/.zsh_aliases"
  "$HOME/.gitconfig"
  "$HOME/.profile"
  "$HOME/.p10k.zsh"
)

for f in "${files[@]}"; do
  [ -f "$f" ] && rsync -a "$f" "$ROOT/dotfiles/" && log "  $(basename $f)"
done

[ -d "$HOME/.config/nvim" ]  && rsync -a --delete "$HOME/.config/nvim"  "$ROOT/dotfiles/.config/"
[ -d "$HOME/.config/kitty" ] && rsync -a --delete "$HOME/.config/kitty" "$ROOT/dotfiles/.config/"

vscode_user="$HOME/.config/Code/User"
if [ -d "$vscode_user" ]; then
  mkdir -p "$ROOT/dotfiles/vscode"
  [ -f "$vscode_user/settings.json" ]    && cp "$vscode_user/settings.json"    "$ROOT/dotfiles/vscode/"
  [ -f "$vscode_user/keybindings.json" ] && cp "$vscode_user/keybindings.json" "$ROOT/dotfiles/vscode/"
fi

if [ -f "$HOME/.ssh/config" ]; then
  mkdir -p "$ROOT/dotfiles/ssh"
  cp "$HOME/.ssh/config" "$ROOT/dotfiles/ssh/config"
fi

mkdir -p "$ROOT/packages"

dpkg --get-selections | awk '{print $1}' > "$ROOT/packages/apt.txt"

command -v snap    >/dev/null 2>&1 && snap list | awk 'NR>1 {print $1}' > "$ROOT/packages/snap.txt"
command -v flatpak >/dev/null 2>&1 && flatpak list --app --columns=application > "$ROOT/packages/flatpak.txt"
command -v pip3    >/dev/null 2>&1 && pip3 list --format=freeze > "$ROOT/packages/pip.txt" 2>/dev/null || true
command -v code    >/dev/null 2>&1 && code --list-extensions > "$ROOT/packages/vscode-extensions.txt" 2>/dev/null || true

if command -v dconf >/dev/null 2>&1; then
  mkdir -p "$ROOT/gnome"
  dconf dump /org/gnome/ > "$ROOT/gnome/gnome.ini"
  command -v gnome-extensions >/dev/null 2>&1 && gnome-extensions list > "$ROOT/gnome/extensions.txt"
fi

if command -v ufw >/dev/null 2>&1; then
  mkdir -p "$ROOT/ufw"
  sudo ufw status verbose > "$ROOT/ufw/rules.txt" 2>/dev/null || warn "ufw needs sudo"
fi

mkdir -p "$ROOT/misc"
crontab -l > "$ROOT/misc/crontab.txt" 2>/dev/null || echo "no crontab" > "$ROOT/misc/crontab.txt"

cd "$ROOT"
git add .

changed=$(git diff --cached --name-only | wc -l)
if [ "$changed" -gt 0 ]; then
  git commit -m "backup: $(date '+%Y-%m-%d %H:%M') — $changed file(s)"
  git push || warn "push failed"
else
  log "nothing changed"
fi

log "done"
