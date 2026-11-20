#!/usr/bin/env bash
# Instala claude-pr-bot como timer de systemd de usuario. Debe clonarse en ~/claude-pr-bot.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$DIR" != "$HOME/claude-pr-bot" ]; then
  echo "Clona/mueve el bot a $HOME/claude-pr-bot (los units usan esa ruta)"; exit 1
fi
command -v claude >/dev/null || { echo "No encuentro 'claude' en PATH"; exit 1; }
command -v python3 >/dev/null || { echo "No encuentro python3"; exit 1; }
[ -f "$DIR/config.json" ] || { cp "$DIR/config.example.json" "$DIR/config.json"; echo "Creado config.json: revísalo"; }
if [ ! -f "$DIR/.env" ]; then
  cp "$DIR/.env.example" "$DIR/.env"; chmod 600 "$DIR/.env"
  echo "Creado .env: rellena BB_EMAIL y BB_API_TOKEN y vuelve a ejecutar ./install.sh"; exit 0
fi
chmod 600 "$DIR/.env"
python3 "$DIR/bot.py" whoami
mkdir -p "$HOME/.config/systemd/user"
cp "$DIR"/systemd/claude-pr-bot.{service,timer} "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now claude-pr-bot.timer
echo "OK. Timer activo:"; systemctl --user list-timers claude-pr-bot.timer --no-pager
