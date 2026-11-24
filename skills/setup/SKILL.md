---
name: setup
description: Configura e inicia bitbucket-pr-autofix (bot que aplica fixes al escribir @claude en comentarios de PRs de Bitbucket). Úsalo cuando el usuario quiera instalar, activar, reconfigurar o migrar el bot.
disable-model-invocation: true
---

# Setup de bitbucket-pr-autofix

Sigue estos pasos en orden, ejecutando los comandos con Bash. Informa brevemente del resultado de cada uno. No muestres nunca el contenido de `.env` ni el token.

0. **Plan mode**: si la sesión está en plan mode no puedes instalar nada. Pide al usuario que salga de plan mode (Shift+Tab) y vuelva a lanzar `/bitbucket-pr-autofix:setup`. Para aquí.

1. **Wrapper disponible**: `command -v pr-autofix || ls ~/.local/bin/pr-autofix`.
   - Si existe solo en `~/.local/bin` pero no en el PATH, usa la ruta completa en el resto de pasos y avisa de que añada `~/.local/bin` al PATH.
   - Si no existe, los hooks del plugin aún no se han cargado. Pide al usuario que ejecute `/reload-plugins` y vuelva a lanzar `/bitbucket-pr-autofix:setup`; solo si sigue sin aparecer, que reinicie Claude Code. Para aquí.

2. **Sincronizar**: `pr-autofix sync`.

3. **Scope de instalación**: lee `~/.claude/plugins/installed_plugins.json`. Si `bitbucket-pr-autofix@bitbucket-pr-tools` está instalado solo con `"scope": "project"`, avisa: funciona, pero los cambios de `/plugin configure` y las actualizaciones solo se sincronizan al usar Claude Code en ese proyecto. Recomienda reinstalarlo con scope **user**. No bloquees el setup por esto.

4. **Migración de instalación manual**: si existe `~/claude-pr-bot/state.json` o el unit `~/.config/systemd/user/claude-pr-bot.timer` (instalación previa sin plugin), ejecuta `pr-autofix migrate ~/claude-pr-bot` y dilo al usuario.

5. **Configuración**: lee `workspace`, `repos_root` y `mode` del `config.json` del directorio de datos (la ruta `DATA` está en `~/.config/bitbucket-pr-autofix/paths`).
   - `workspace` vacío → pedir que lo configure (ver paso 6).
   - Expande `~` en `repos_root` y comprueba que **la carpeta existe**. Si no existe, busca en el directorio padre una carpeta con el mismo nombre ignorando mayúsculas/minúsculas (por ejemplo `ls -d ~/* | grep -i`) y propón ese valor exacto. El usuario lo corrige con `/plugin configure bitbucket-pr-autofix@bitbucket-pr-tools` → "Carpeta de repos". Después `/reload-plugins` y repetir setup. Para aquí.
   - Comprueba que dentro hay al menos un repo git cuyo `origin` apunte a `bitbucket.org[:/]<workspace>/`. Si no hay ninguno, avisa (posible workspace o carpeta incorrectos), pero no bloquees.

6. **Credenciales**: `pr-autofix whoami`.
   - Si falla porque falta el workspace, `.env` o por HTTP 401/403, explica que debe configurar workspace, email y API token con `/plugin configure bitbucket-pr-autofix@bitbucket-pr-tools`. El token se guarda en el keyring del sistema; nunca lo pidas por el chat.
   - Scopes necesarios: `read:repository:bitbucket`, `read:pullrequest:bitbucket`, `write:pullrequest:bitbucket`.
   - Después `/reload-plugins` y repetir setup. Para aquí.

7. **Requisitos**: comprueba `command -v git python3 claude systemctl` y que `ssh -T git@bitbucket.org` autentica (código de salida 0 o mensaje "authenticated"). Si algo falla, explica cómo arreglarlo.

8. **Timer**: `pr-autofix install-units`.

9. **Prueba**: `pr-autofix run --dry-run`. Resume qué comentarios detectaría (normalmente ninguno) y confirma que no hay errores.

10. **Explica el uso** en pocas líneas:
    - En una PR suya, comentar `@claude <instrucción>` (o responder al comentario de un revisor con `@claude arréglalo`). En ≤2 min Claude aplica el fix, hace commit + push y responde en el hilo.
    - `@claude --review …` aplica el fix SIN commit: en su copia local si está en la rama de la PR y limpia, o si no, en un worktree `.claude-review/…` que aparece en la pestaña Commit del IDE (JetBrains). Lo revisa, retoca y hace commit + push desde el IDE (o rollback).
    - Estado y logs: `/bitbucket-pr-autofix:status`.
