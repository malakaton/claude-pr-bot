---
name: setup
description: Configura e inicia bitbucket-pr-autofix (bot que aplica fixes al escribir @claude en comentarios de PRs de Bitbucket). Úsalo cuando el usuario quiera instalar, activar, reconfigurar o migrar el bot.
disable-model-invocation: true
---

# Setup de bitbucket-pr-autofix

Sigue estos pasos en orden, ejecutando los comandos con Bash. Informa brevemente del resultado de cada uno. No muestres nunca el contenido de `.env` ni el token.

1. **Wrapper disponible**: `command -v pr-autofix`. Si no existe, el hook del plugin aún no se ha ejecutado: pide al usuario que ejecute `/reload-plugins` (o reinicie Claude Code) y vuelva a lanzar `/bitbucket-pr-autofix:setup`. Para aquí.

2. **Sincronizar**: `pr-autofix sync`.

3. **Migración de instalación manual**: si existe `~/claude-pr-bot/state.json` o el unit `~/.config/systemd/user/claude-pr-bot.timer` (instalación previa sin plugin), ejecuta `pr-autofix migrate ~/claude-pr-bot` y dilo al usuario.

4. **Credenciales**: `pr-autofix whoami`.
   - Si falla porque falta el workspace, `.env` o por HTTP 401/403, explica que debe configurar workspace, email y API token con `/plugin configure bitbucket-pr-autofix@bitbucket-pr-tools` (el token se guarda en el keyring del sistema; nunca lo pidas por el chat). Scopes: `read:repository:bitbucket`, `read:pullrequest:bitbucket`, `write:pullrequest:bitbucket`. Después `/reload-plugins` y repetir setup. Para aquí.

5. **Requisitos**: comprueba `command -v git python3 claude systemctl` y que `ssh -T git@bitbucket.org` autentica (código de salida 0 o mensaje "authenticated"). Si algo falla, explica cómo arreglarlo.

6. **Timer**: `pr-autofix install-units`.

7. **Prueba**: `pr-autofix run --dry-run` y resume qué comentarios detectaría (normalmente ninguno).

8. **Explica el uso** en pocas líneas:
   - En una PR suya, comentar `@claude <instrucción>` (o responder al comentario de un revisor con `@claude arréglalo`). En ≤2 min Claude aplica el fix, hace commit + push y responde en el hilo.
   - `@claude --review …` aplica el fix pero NO hace commit ni push hasta que lo revise con `/bitbucket-pr-autofix:review`.
   - Estado y logs: `/bitbucket-pr-autofix:status`.
