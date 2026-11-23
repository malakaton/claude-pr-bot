#!/usr/bin/env bash
# Instalación SIN plugin de Claude Code (alternativa manual).
# Datos en ~/.bitbucket-pr-autofix; comando `pr-autofix` en ~/.local/bin.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
DATA="$HOME/.bitbucket-pr-autofix"
for c in git python3 claude systemctl; do command -v "$c" >/dev/null || { echo "No encuentro '$c' en PATH"; exit 1; }; done
export CLAUDE_PLUGIN_ROOT="$DIR" CLAUDE_PLUGIN_DATA="$DATA"
bash "$DIR/scripts/sync.sh" sync
if [ ! -s "$DATA/.env" ]; then
  (umask 077; cp "$DIR/.env.example" "$DATA/.env")
  echo "Rellena BB_EMAIL y BB_API_TOKEN en $DATA/.env y revisa $DATA/config.json; luego vuelve a ejecutar ./install.sh"
  exit 0
fi
pr-autofix whoami
bash "$DIR/scripts/sync.sh" install-units
echo "OK. Uso: pr-autofix status | pending | show <cid> | approve <cid> | reject <cid>"
