# bitbucket-pr-autofix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Plugin de **Claude Code** que permite pedir cambios a Claude desde los comentarios de una Pull Request de **Bitbucket Cloud**. Funciona con cualquier workspace.

Escribes en tu PR un comentario como:

```
@claude renombra este método a findActiveCustomers
```

En menos de 2 minutos, Claude aplica el cambio en la rama de la PR, hace commit y push y responde en el hilo del comentario con un resumen y el enlace al commit. Si prefieres revisarlo antes, usa `@claude --review …`.

No necesita permisos de admin en Bitbucket (ni webhooks ni Pipelines) ni ser owner de los repos: basta con poder comentar y hacer push en tus PRs. Todo se ejecuta **en tu máquina**: un timer de systemd consulta la API de Bitbucket con tu token personal.

> **Uso en equipo**: cada persona instala el plugin con su propio token. Solo disparan los comentarios de quien lo tiene instalado, y cada fix se ejecuta en la máquina de esa persona.

---

## Instalación (plugin, recomendada)

### Requisitos

- Linux con systemd (sesión de usuario).
- `python3` 3.9 o superior y `git`, con acceso SSH a Bitbucket (`ssh -T git@bitbucket.org` debe funcionar; el push usa tu clave).
- [Claude Code](https://code.claude.com) instalado y con sesión iniciada.
- Los repos clonados bajo una misma carpeta, por ejemplo `~/code/<repo>`.
- Un **API token de Atlassian**:
  1. Entra en https://id.atlassian.com/manage-profile/security/api-tokens.
  2. Pulsa **Create API token with scopes** y elige la app **Bitbucket**.
  3. Marca los scopes `read:repository:bitbucket`, `read:pullrequest:bitbucket` y `write:pullrequest:bitbucket`.

  > Las App Passwords de Bitbucket están deprecadas; usa un API token.

### Pasos

No hace falta clonar este repo ni tener cuenta de GitHub: el repo es público y Claude Code lo descarga solo.

Dentro de Claude Code:

```
/plugin marketplace add malakaton/claude-pr-bot
/plugin install bitbucket-pr-autofix@bitbucket-pr-tools
```

Al instalarlo, Claude Code te pide:

| Opción | Valor |
|---|---|
| Workspace de Bitbucket | la parte `<workspace>` de `bitbucket.org/<workspace>/<repo>`, por ejemplo `mi-empresa` |
| Email de Atlassian | el email de tu cuenta |
| API token de Bitbucket | el token creado arriba (se guarda en el keyring del sistema, no pasa por el chat) |
| Carpeta de repos | donde tienes clonados los repos (por defecto `~/code`) |
| Modo por defecto | `auto` (commit + push directo) o `review` (revisas tú antes) |

Después:

```
/reload-plugins
/bitbucket-pr-autofix:setup
```

`setup` hace lo siguiente:

- valida las credenciales,
- comprueba los requisitos,
- instala y activa el timer,
- hace una pasada de prueba.

A partir de ahí el bot arranca solo cada vez que inicias sesión.

Para cambiar el token o las opciones: `/plugin configure bitbucket-pr-autofix@bitbucket-pr-tools`, luego `/reload-plugins`.
Para actualizar: `/plugin update bitbucket-pr-autofix@bitbucket-pr-tools`. El timer usa la versión nueva en la siguiente sesión, sin reinstalar nada.

### Comandos del plugin

| Comando | Qué hace |
|---|---|
| `/bitbucket-pr-autofix:setup` | Instala, valida y activa el bot (y migra una instalación manual previa) |
| `/bitbucket-pr-autofix:status` | Estado del timer, último poll, coste acumulado, errores recientes, pendientes |
| `/bitbucket-pr-autofix:review` | Revisa contigo los fixes `--review` pendientes: muestra el diff, da su valoración, permite retocar y aprueba o rechaza **solo con tu confirmación** |
| `/bitbucket-pr-autofix:uninstall` | Detiene y quita el timer |

---

## Uso en Bitbucket

| Quiero… | Escribe en la PR |
|---|---|
| Un cambio concreto | `@claude extrae esta lógica a un método privado` |
| Que arregle lo que dice un revisor | **Responde** a su comentario con `@claude arréglalo` |
| Que aplique el fix pero revisarlo yo antes del commit y push | `@claude --review …` ([ver modo revisión](#modo-revisión-claude---review)) |
| Push automático (si tu modo por defecto es review) | `@claude --push …` |

Si haces el comentario inline sobre una línea del diff, Claude recibe el fichero y la línea.

Claude responde en el hilo con uno de estos mensajes:

- ⏳ trabajando
- ✅ aplicado, con el enlace al commit
- 📝 pendiente de revisión
- ℹ️ sin cambios o le falta información
- ❌ error

> Si editas un comentario que ya se procesó, no se vuelve a ejecutar. Escribe un comentario nuevo o usa `pr-autofix forget <cid>`.

---

## Modo revisión: `@claude --review`

Si escribes `@claude --review …`, Claude **aplica el fix pero no hace commit ni push**. Antes de que nada llegue a la rama de la PR, **compruebas tú mismo que el cambio de Claude es correcto**.

```
@claude --review mueve esta validación al value object Email
```

Flujo:

1. Claude aplica los cambios en un worktree local, sin commit.
2. Recibes una notificación de escritorio y Claude responde en la PR con 📝 *"Cambios aplicados en local, pendientes de revisión antes del commit y push"*.
3. Revisas el cambio:
   - **Con Claude**: ejecuta `/bitbucket-pr-autofix:review`. Te enseña el diff, te da su opinión y puedes pedirle retoques.
   - **A mano**:
     ```bash
     pr-autofix pending              # lista los fixes pendientes (repo, PR, carpeta del worktree, resumen)
     pr-autofix show <cid>           # muestra el commit propuesto y el diff completo
     ```
     Puedes abrir la carpeta del worktree en tu IDE, retocar el código o ejecutar los tests.
4. Decides:
   ```bash
   pr-autofix approve <cid>        # commit (con tus retoques incluidos) + push + respuesta ✅ en la PR
   pr-autofix reject <cid> motivo  # descarta los cambios + respuesta 🚫 en la PR
   ```

Si quieres revisar siempre, elige el modo `review` en la configuración del plugin. Cuando quieras push directo en un caso concreto, usa `@claude --push …`.

---

## Cómo funciona

1. Cada 2 minutos, el bot lista tus PRs abiertas en el workspace (las que tú has creado).
2. Busca comentarios nuevos **escritos por ti** que contengan `@claude`.
3. Hace checkout de la rama de la PR en un `git worktree` aislado. Tu copia de trabajo no se toca.
4. Ejecuta `claude -p` (modo headless) con esta información:
   - el título y la descripción de la PR,
   - tu instrucción,
   - el comentario al que respondes, si existe,
   - el fichero y la línea, si el comentario es inline.
5. Si hay cambios, el script (no Claude) hace commit y push a la rama de la PR y responde en el hilo. Con `--review`, se para antes del commit.
6. Guarda el comentario como procesado en `state.json` y borra el worktree.

Arquitectura del plugin: un plugin no puede tener procesos en segundo plano, así que el polling lo hace un **timer de systemd de usuario** (`bitbucket-pr-autofix.timer`). Ese timer ejecuta una copia del bot guardada en el directorio de datos del plugin (`~/.claude/plugins/data/…`), que se conserva entre actualizaciones. Un hook `SessionStart` del plugin mantiene esa copia y las credenciales al día, y genera el comando `~/.local/bin/pr-autofix`.

### Seguridad

- Solo disparan los comentarios **de quien tiene el bot configurado**. Si otro miembro del equipo escribe `@claude`, no pasa nada en tu máquina.
- Claude solo puede leer y editar ficheros y usar `git diff/status/log/show`. No tiene shell genérico ni acceso a la red, y no puede hacer commit ni push.
- El texto de los revisores se pasa como contexto, no como órdenes.
- El token se guarda en el keyring del sistema y en un `.env` con permisos 600 dentro del directorio de datos, porque el timer corre fuera de Claude Code. Nunca se envía a Claude ni se escribe en los logs.

### Cuándo se ejecuta

- Arranca solo al iniciar sesión en el escritorio y se ejecuta cada 2 minutos mientras la sesión está abierta.
- Los comentarios que hagas con el ordenador apagado se procesan en la primera pasada después de iniciar sesión.
- El push usa el agente SSH de tu sesión gráfica, por eso el bot solo funciona con la sesión iniciada.

---

## Configuración avanzada

Las opciones del plugin cubren lo habitual. Para lo demás, edita `config.json` en el directorio de datos (la ruta la muestra `pr-autofix status`):

| Clave | Descripción | Por defecto |
|---|---|---|
| `workspace` | Workspace de Bitbucket (lo fija la opción del plugin) | — |
| `repos_root` | Carpeta con tus clones. El bot asocia cada repo por el remote `origin`. | `~/code` |
| `repo_paths` | Rutas manuales `{ "slug": "~/ruta" }` si un repo está en otra carpeta | `{}` |
| `extra_repos` | Repos en los que vigilar también PRs que **no** son tuyas (más llamadas a la API) | `[]` |
| `mode` | `auto` o `review` (lo sobrescribe la opción del plugin) | `auto` |
| `trigger` | Palabra que dispara el bot | `@claude` |
| `model` | Modelo a usar (vacío = el de tu configuración) | `""` |
| `max_turns` / `timeout_sec` | Límites de cada ejecución de Claude | `30` / `900` |
| `lookback_minutes` | Margen hacia atrás al buscar comentarios nuevos | `10` |
| `allowed_tools` | Herramientas permitidas a Claude | lectura/edición + `git diff/log/status/show` |
| `extra_allowed_tools` | Herramientas extra por repo, por ejemplo para ejecutar tests | `{}` |
| `disallowed_tools` | Herramientas prohibidas | `git push/commit/reset`, web |

Ejemplo para dejar que Claude ejecute los tests de un repo:

```json
"extra_allowed_tools": {
  "my-service": ["Bash(make test:*)", "Bash(npm test:*)"]
}
```

---

## Comando `pr-autofix`

```bash
pr-autofix status              # timer, último poll, coste, log reciente
pr-autofix run --dry-run       # ver qué detectaría, sin ejecutar nada
pr-autofix run                 # forzar una pasada ahora
pr-autofix whoami              # comprobar credenciales
pr-autofix pending | show <cid> | approve <cid> | reject <cid> [motivo] | forget <cid>
journalctl --user -u bitbucket-pr-autofix -f   # logs de systemd
```

---

## Instalación manual (sin plugin)

```bash
git clone https://github.com/malakaton/claude-pr-bot.git ~/claude-pr-bot && cd ~/claude-pr-bot
./install.sh      # crea ~/.bitbucket-pr-autofix/.env y config.json → rellena token, workspace y repos_root
./install.sh      # valida credenciales y activa el timer
```

Se usa igual, con el comando `pr-autofix`.

---

## Limitaciones y problemas habituales

- **Solo PRs propias**: por defecto solo vigila las PRs de las que eres autor. Para otras, añade el repo a `extra_repos`.
- **PRs desde fork**: no están soportadas.
- **"No encuentro clon local"**: el repo no está bajo la carpeta de repos. Clónalo o añádelo en `repo_paths`.
- **Error en el push** (non-fast-forward): el bot hace fetch, un rebase y reintenta una vez. Si vuelve a fallar, responde con el error.
- **Un comentario se quedó en `running`** (por ejemplo, apagaste a mitad): ejecuta `pr-autofix forget <cid>` para que se reprocese.
- **`pr-autofix` no existe tras instalar**: ejecuta `/reload-plugins` o reinicia Claude Code para que corra el hook del plugin. Comprueba también que `~/.local/bin` está en tu `PATH`.
- **Coste**: cada ejecución consume uso de Claude (unos 0,10–0,50 $ en cambios pequeños). Consulta el acumulado con `/bitbucket-pr-autofix:status`.
- **Rate limit de Bitbucket**: unas 1000 peticiones/hora por usuario. Con pocas PRs abiertas sobra margen.

---

## Estructura del repo

```
.claude-plugin/plugin.json       # manifiesto del plugin (+ opciones de usuario)
.claude-plugin/marketplace.json  # este repo es también su marketplace
hooks/hooks.json                 # SessionStart → scripts/sync.sh
skills/{setup,status,review,uninstall}/SKILL.md
lib/bot.py                       # el bot (solo stdlib)
scripts/sync.sh                  # sincroniza datos, units y genera `pr-autofix`
systemd/*.tmpl                   # plantillas de service y timer (cada 2 min)
config.example.json  .env.example  install.sh
```

---

## Contribuir

Issues y pull requests son bienvenidos en [github.com/malakaton/claude-pr-bot](https://github.com/malakaton/claude-pr-bot).

Antes de enviar cambios:

```bash
claude plugin validate .            # valida manifiestos, skills y hooks
claude --plugin-dir .               # prueba el plugin en local sin instalarlo
python3 -m py_compile lib/bot.py && bash -n scripts/sync.sh install.sh
```

Si cambias el comportamiento, sube `version` en `.claude-plugin/plugin.json` para que `/plugin update` lo detecte.

---

## Licencia

[MIT](LICENSE)
