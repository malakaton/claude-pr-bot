#!/usr/bin/env bash
# bitbucket-pr-autofix: sincroniza el bot a un directorio de datos estable y gestiona los units de systemd.
#
#   sync.sh                 sincroniza (lo ejecuta el hook SessionStart del plugin; silencioso)
#   sync.sh quick           sincroniza solo si cambió la versión del plugin o sus opciones (hook UserPromptSubmit)
#   sync.sh install-units   instala/actualiza service+timer y los activa
#   sync.sh remove-units    desactiva y borra service+timer
#   sync.sh migrate [dir]   importa state/config/.env de una instalación manual (por defecto ~/claude-pr-bot)
#
# Dentro de Claude Code (hook) usa CLAUDE_PLUGIN_ROOT/CLAUDE_PLUGIN_DATA. Fuera, el wrapper
# ~/.local/bin/pr-autofix las fija a partir de ~/.config/bitbucket-pr-autofix/paths.
set -euo pipefail
trap 'echo "bitbucket-pr-autofix sync.sh: error (código $?) en la línea $LINENO" >&2' ERR

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.bitbucket-pr-autofix}"
UNIT_DIR="$HOME/.config/systemd/user"
PTR_DIR="$HOME/.config/bitbucket-pr-autofix"
WRAPPER="$HOME/.local/bin/pr-autofix"

opt() {  # valor de userConfig (acepta CLAUDE_PLUGIN_OPTION_KEY o _key)
  local up="CLAUDE_PLUGIN_OPTION_${1^^}" lo="CLAUDE_PLUGIN_OPTION_$1"
  printf '%s' "${!up:-${!lo:-}}"
}

stamp() {  # huella de versión + opciones; solo bash/coreutils para ser rápido
  { printf '%s\n' "$ROOT"; env | grep '^CLAUDE_PLUGIN_OPTION_' | sort || true; } | sha256sum | cut -d' ' -f1
}

sync_files() {
  mkdir -p "$DATA" "$PTR_DIR" "$(dirname "$WRAPPER")"
  cmp -s "$ROOT/lib/bot.py" "$DATA/bot.py" 2>/dev/null || install -m 755 "$ROOT/lib/bot.py" "$DATA/bot.py"
  [ -f "$DATA/config.json" ] || cp "$ROOT/config.example.json" "$DATA/config.json"

  # rutas para usarlas fuera de Claude Code (wrapper, skills)
  printf 'ROOT=%q\nDATA=%q\n' "$ROOT" "$DATA" > "$PTR_DIR/paths"
  cat > "$WRAPPER.tmp" <<'EOF'
#!/usr/bin/env bash
# Generado por el plugin bitbucket-pr-autofix. Uso: pr-autofix <run|pending|forget|whoami|status|install-units|remove-units|migrate>
set -euo pipefail
. "$HOME/.config/bitbucket-pr-autofix/paths"
export CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_DATA="$DATA" PR_AUTOFIX_HOME="$DATA"
case "${1:-}" in
  install-units|remove-units|migrate|sync) exec bash "$ROOT/scripts/sync.sh" "$@" ;;
  status)
    systemctl --user is-active bitbucket-pr-autofix.timer >/dev/null 2>&1 && echo "timer: activo" || echo "timer: INACTIVO"
    systemctl --user list-timers bitbucket-pr-autofix.timer --no-pager 2>/dev/null | sed -n 2p || true
    echo "datos: $DATA"
    python3 - "$DATA/state.json" <<'PY'
import json, sys, collections
try: s = json.load(open(sys.argv[1]))
except Exception: print("state: (vacío)"); sys.exit()
c = s.get("comments", {})
print("último poll:", s.get("last_poll"))
print("comentarios:", dict(collections.Counter(e.get("status") for e in c.values())))
print("coste total: %.2f $" % sum((e.get("cost") or 0) for e in c.values()))
PY
    echo "--- últimas líneas de bot.log"; tail -n 15 "$DATA/bot.log" 2>/dev/null || true ;;
  *) exec python3 "$DATA/bot.py" "$@" ;;
esac
EOF
  if ! cmp -s "$WRAPPER.tmp" "$WRAPPER" 2>/dev/null; then mv "$WRAPPER.tmp" "$WRAPPER"; chmod 755 "$WRAPPER"; else rm -f "$WRAPPER.tmp"; fi

  # userConfig -> config.json / .env
  local email token repos mode ws
  email="$(opt bb_email)"; token="$(opt bb_api_token)"; repos="$(opt repos_root)"; mode="$(opt mode)"; ws="$(opt workspace)"
  if [ -n "$repos$mode$ws" ]; then
    python3 - "$DATA/config.json" "$repos" "$mode" "$ws" <<'PY'
import json, sys
p, repos, mode, ws = sys.argv[1:]
c = json.load(open(p)); old = dict(c)
if ws: c["workspace"] = ws
if repos: c["repos_root"] = repos
if mode in ("auto", "review"): c["mode"] = mode
if c != old: json.dump(c, open(p, "w"), indent=2, ensure_ascii=False)
PY
  fi
  if [ -n "$email" ] && [ -n "$token" ]; then
    local new; new="$(printf 'BB_EMAIL=%s\nBB_API_TOKEN=%s\n' "$email" "$token")"
    if [ ! -f "$DATA/.env" ] || [ "$(cat "$DATA/.env")" != "$new" ]; then
      (umask 077; printf '%s\n' "$new" > "$DATA/.env")
    fi
  fi
  [ -f "$DATA/.env" ] && chmod 600 "$DATA/.env"

  stamp > "$DATA/.sync-stamp"; chmod 600 "$DATA/.sync-stamp"

  # si los units son nuestros, mantenerlos al día con la ruta actual
  if grep -qs "managed-by: bitbucket-pr-autofix plugin" "$UNIT_DIR/bitbucket-pr-autofix.service"; then
    render_units quiet
  fi
}

render_units() {
  local path claude_dir changed=0
  claude_dir="$(dirname "$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")")"
  path="$claude_dir:$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin"
  mkdir -p "$UNIT_DIR"
  for u in service timer; do
    sed -e "s#@DATA@#$DATA#g" -e "s#@PATH@#$path#g" "$ROOT/systemd/bitbucket-pr-autofix.$u.tmpl" > "$UNIT_DIR/.bitbucket-pr-autofix.$u.new"
    if cmp -s "$UNIT_DIR/.bitbucket-pr-autofix.$u.new" "$UNIT_DIR/bitbucket-pr-autofix.$u"; then
      rm -f "$UNIT_DIR/.bitbucket-pr-autofix.$u.new"
    else
      mv "$UNIT_DIR/.bitbucket-pr-autofix.$u.new" "$UNIT_DIR/bitbucket-pr-autofix.$u"; changed=1
    fi
  done
  if [ "$changed" = 1 ]; then systemctl --user daemon-reload; fi
  [ "${1:-}" = quiet ] || echo "units en $UNIT_DIR (datos: $DATA)"
}

case "${1:-sync}" in
  sync) sync_files ;;
  quick)
    if [ -x "$WRAPPER" ] && [ -f "$DATA/.sync-stamp" ] && [ "$(stamp)" = "$(cat "$DATA/.sync-stamp")" ]; then exit 0; fi
    sync_files ;;
  install-units)
    sync_files
    [ -f "$DATA/.env" ] || { echo "Falta $DATA/.env: configura bb_email y bb_api_token con /plugin configure"; exit 1; }
    render_units
    systemctl --user enable --now bitbucket-pr-autofix.timer
    systemctl --user list-timers bitbucket-pr-autofix.timer --no-pager | sed -n 1,2p ;;
  remove-units)
    systemctl --user disable --now bitbucket-pr-autofix.timer 2>/dev/null || true
    rm -f "$UNIT_DIR/bitbucket-pr-autofix.service" "$UNIT_DIR/bitbucket-pr-autofix.timer"
    systemctl --user daemon-reload
    echo "Timer desactivado y units eliminados. Datos conservados en $DATA" ;;
  migrate)
    OLD="${2:-$HOME/claude-pr-bot}"
    mkdir -p "$DATA"
    # desactivar el timer de la instalación manual antigua para que no compita con el nuevo
    if [ -f "$UNIT_DIR/claude-pr-bot.timer" ]; then
      systemctl --user disable --now claude-pr-bot.timer 2>/dev/null || true
      rm -f "$UNIT_DIR/claude-pr-bot.service" "$UNIT_DIR/claude-pr-bot.timer"
      systemctl --user daemon-reload
      echo "desactivado timer antiguo claude-pr-bot"
    fi
    for f in state.json bot.log; do
      if [ -f "$OLD/$f" ] && [ ! -s "$DATA/$f" ]; then cp "$OLD/$f" "$DATA/$f" && echo "migrado $f"; fi
    done
    if [ -f "$OLD/config.json" ]; then
      python3 - "$OLD/config.json" "$DATA/config.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1])); c["worktrees_dir"] = ""   # usar el valor por defecto (~/.cache/bitbucket-pr-autofix/worktrees)
json.dump(c, open(sys.argv[2], "w"), indent=2, ensure_ascii=False); print("migrado config.json")
PY
    fi
    if [ -f "$OLD/.env" ] && [ ! -f "$DATA/.env" ]; then (umask 077; cp "$OLD/.env" "$DATA/.env"); echo "migrado .env"; fi
    if [ -d "$OLD/worktrees" ] && [ -n "$(ls -A "$OLD/worktrees" 2>/dev/null)" ]; then
      echo "AVISO: hay worktrees pendientes en $OLD/worktrees (state.json sigue apuntando ahí; revísalos y bórralos a mano)"
    fi ;;
  *) echo "uso: sync.sh [sync|quick|install-units|remove-units|migrate [dir]]"; exit 2 ;;
esac
