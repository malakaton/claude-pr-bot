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

Cuando pregunte el ámbito, elige **user** (para ti en todos los proyectos). Con `project`, los cambios de configuración y las actualizaciones solo se aplican al usar Claude Code en esa carpeta.

Al instalarlo, Claude Code te pide:

| Opción | Valor |
|---|---|
| Workspace de Bitbucket | la parte `<workspace>` de `bitbucket.org/<workspace>/<repo>`, por ejemplo `mi-empresa` |
| Email de Atlassian | el email de tu cuenta |
| API token de Bitbucket | el token creado arriba (se guarda en el keyring del sistema, no pasa por el chat) |
| Carpeta de repos | donde tienes clonados los repos (por defecto `~/code`). Escríbela exactamente igual, mayúsculas incluidas: `~/MiEmpresa` y `~/Miempresa` son carpetas distintas |
| Modo por defecto | `auto` (commit + push directo) o `review` (revisas tú antes) |
| Avisos por Slack | `activado` para avisar por DM a los revisores cuando sus cambios se suben ([ver abajo](#avisos-por-slack)). Por defecto `desactivado` |

Después, en la misma sesión (no hace falta reiniciar):

```
/reload-plugins
/bitbucket-pr-autofix:setup
```

> Ejecuta `setup` fuera de plan mode: en plan mode Claude no puede instalar nada.

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
| `/bitbucket-pr-autofix:review` | Revisa contigo los fixes `--review` sin resolver: muestra el diff, da su valoración y aplica retoques que le pidas |
| `/bitbucket-pr-autofix:uninstall` | Detiene y quita el timer |

---

## Uso en Bitbucket

| Quiero… | Escribe en la PR |
|---|---|
| Un cambio concreto | `@claude extrae esta lógica a un método privado` |
| Que arregle lo que dice un revisor | **Responde** a su comentario con `@claude arréglalo` |
| Que aplique el fix pero revisarlo yo antes del commit y push | `@claude --review …` ([ver modo revisión](#modo-revisión-claude---review)) |
| Push automático (si tu modo por defecto es review) | `@claude --push …` |
| Pedir otra vuelta sobre un fix | **Responde** en el mismo hilo: `@claude no, mejor con un enum` (retoma la sesión anterior de Claude) |
| Atender todos los comentarios pendientes | `@claude --all` en un comentario general: resuelve en un solo commit los hilos sin resolver y responde en cada uno |
| Una pregunta, sin tocar código | `@claude --ask ¿tiene razón el revisor?` |
| Elegir modelo | `--opus`, `--sonnet`, `--haiku` o `--model <id>` |

Claude recibe el hilo completo de comentarios y, si es inline, el código alrededor de la línea comentada.

Varios `@claude --review` seguidos en la misma PR se encadenan: el siguiente se aplica encima de los cambios aún sin commit del anterior (en tu copia local o en su worktree de revisión).

Claude responde en el hilo con uno de estos mensajes:

- ✅ aplicado, con el enlace al commit
- 📝 aplicado sin commit, para que lo revises en tu IDE
- ℹ️ sin cambios o le falta información
- 💬 respuesta a una pregunta (`--ask`)
- ❌ error (también si una ejecución se interrumpió, p. ej. al apagar el equipo)

> Si editas un comentario que ya se procesó, no se vuelve a ejecutar. Escribe un comentario nuevo o usa `pr-autofix forget <cid>`.

---

## Modo revisión: `@claude --review`

Si escribes `@claude --review …`, Claude **aplica el fix pero no hace commit ni push**. Los cambios te llegan como cambios locales sin commit, para revisarlos en tu IDE (**pestaña Commit** en JetBrains, **Source Control** en VS Code) igual que si los hubieras hecho tú.

```
@claude --review mueve esta validación al value object Email
```

Claude genera el cambio en un worktree aislado y luego lo entrega de una de estas dos formas:

| Situación de tu clon local | Dónde aparecen los cambios |
|---|---|
| Está en la rama de la PR y sin cambios sin commit | **Directamente en tu copia de trabajo.** Si tu rama iba por detrás de origin, antes hace `git pull --ff-only`. |
| Está en otra rama o tiene cambios a medias | En un worktree dentro del repo, `.claude-review/pr<id>-c<cid>/`. No tienes que cambiar de rama y puedes tener varios fixes a la vez. |

En el segundo caso, si el repo tiene proyecto de **JetBrains** (`.idea/`), el bot registra el worktree como repositorio git del proyecto. Aparece en la pestaña Commit como un repo más (`pr1240-c…`) y la carpeta `.claude-review` se excluye del índice para que no haya clases duplicadas. También se añade a `.git/info/exclude`, así que tu `git status` no la ve.

En **VS Code**, el worktree aparece en Source Control como un repo más si está activado `git.detectWorktrees`. `/bitbucket-pr-autofix:setup` lo activa y oculta `.claude-review` del explorador para evitar ficheros duplicados. A mano, en tus settings de usuario:

```jsonc
"git.detectWorktrees": true,
"files.exclude": { "**/.claude-review": true }
```

Después:

- **Aprobar**: retoca lo que quieras y haz commit y push desde el IDE (JetBrains o VS Code). El push va a la rama de la PR, porque la rama del worktree tiene como upstream `origin/<rama-PR>`. Claude te deja un mensaje de commit sugerido en la PR.
- **Descartar**: haz Rollback de los cambios.
- **Con ayuda**: `/bitbucket-pr-autofix:review` te enseña el diff, te da su opinión y aplica los retoques que le pidas.

En el siguiente poll, el bot detecta los worktrees resueltos (sin cambios y con todo subido o descartado), los borra y quita su registro del IDE. Las entregas en la copia local se dan por resueltas cuando sus ficheros quedan sin cambios (y, si hubo commit, subido). `pr-autofix pending` lista ambos mientras sigan abiertos.

Si quieres revisar siempre, elige el modo `review` en la configuración del plugin. Cuando quieras push directo en un caso concreto, usa `@claude --push …`.

---

## Cómo funciona

1. Cada 2 minutos, el bot lista tus PRs abiertas en el workspace (las que tú has creado).
2. Busca comentarios nuevos **escritos por ti** que contengan `@claude`.
3. Hace checkout de la rama de la PR en un `git worktree` aislado. Tu copia de trabajo no se toca.
4. Ejecuta `claude -p` (modo headless) con esta información:
   - el título y la descripción de la PR,
   - tu instrucción,
   - el hilo completo al que respondes, si existe,
   - el fichero, la línea y el código de alrededor, si el comentario es inline.

   Si el hilo ya tuvo una ejecución anterior, la retoma con `--resume`.
5. Si hay cambios, el script (no Claude) hace commit y push a la rama de la PR y responde en el hilo. Con `--review`, se para antes del commit y te entrega los cambios para revisarlos en el IDE.
6. Guarda el comentario como procesado en `state.json` y borra el worktree.

Arquitectura del plugin: un plugin no puede tener procesos en segundo plano, así que el polling lo hace un **timer de systemd de usuario** (`bitbucket-pr-autofix.timer`). Ese timer ejecuta una copia del bot guardada en el directorio de datos del plugin (`~/.claude/plugins/data/…`), que se conserva entre actualizaciones. Los hooks `SessionStart` y `UserPromptSubmit` del plugin mantienen esa copia y las credenciales al día (el segundo solo actúa si cambió la versión o las opciones), y genera el comando `~/.local/bin/pr-autofix`.

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
| `resolve_threads` | Tras un push correcto, marca como resuelto el hilo del revisor (y los hilos arreglados con `--all`) | `false` |
| `max_batch_items` | Máximo de hilos que atiende un `--all` | `20` |
| `verify_cmd` | Comando de verificación por repo que ejecuta **el script** tras el fix, en el worktree. `{files}` se sustituye por los ficheros cambiados. Si falla en modo `auto`, no hace push y lo entrega como `review` | `{}` |
| `verify_timeout_sec` | Límite del comando de verificación | `300` |
| `slack_notify` | (lo fija la opción del plugin *Avisos por Slack*) Tras subir un fix (push del bot, o tu push desde un worktree de `--review`), avisa por DM de Slack a los revisores cuyos comentarios se atendieron. Usa el conector de Slack de claude.ai ([ver abajo](#avisos-por-slack)) | `false` |
| `slack_users` | Mapa manual Bitbucket → Slack para quien no se encuentre por nombre: `{ "<account_id, nickname o nombre visible>": "<ID de Slack, U…>" }` | `{}` |
| `slack_connector` | Nombre del conector de Slack tal como aparece en `claude mcp list` | `claude.ai Slack` |
| `slack_model` | Modelo del `claude -p` que envía los avisos | `haiku` |
| `worktrees_dir` | Carpeta de los worktrees. No puede estar dentro de `~/.claude`: Claude Code deniega ahí la escritura (si se configura así, el bot usa el valor por defecto) | `~/.cache/bitbucket-pr-autofix/worktrees` |
| `allowed_tools` | Herramientas permitidas a Claude | lectura/edición + `git diff/log/status/show` |
| `extra_allowed_tools` | Herramientas extra por repo, por ejemplo para ejecutar tests | `{}` |
| `disallowed_tools` | Herramientas prohibidas | `git push/commit/reset`, web |

Ejemplo para dejar que Claude ejecute los tests de un repo:

```json
"extra_allowed_tools": {
  "my-service": ["Bash(make test:*)", "Bash(npm test:*)"]
}
```

Ejemplo de verificación de sintaxis PHP con Docker (el worktree no tiene `vendor/`, así que mejor comprobaciones que no dependan de él):

```json
"verify_cmd": {
  "my-php-service": "docker run --rm -v \"$PWD\":/app -w /app php:8.3-cli sh -c 'for f in \"$@\"; do case \"$f\" in *.php) php -l \"$f\" || exit 1;; esac; done' _ {files}"
}
```

---

### Avisos por Slack

Con la opción **Avisos por Slack** en `activado` (o `"slack_notify": true`), cuando los cambios de un comentario de revisión llegan a la rama de la PR, el bot manda a cada revisor afectado (nunca a ti) un DM breve con el enlace a su comentario y al commit:

- **Modo auto / `--push`**: justo después del push del bot.
- **`--review`**: cuando subes tú los cambios desde el worktree de revisión (se detecta en la siguiente pasada). Si se aplicaron directamente en tu copia local, no se detecta y no se avisa.
- **`--all`**: solo a los autores de los hilos que Claude marcó como arreglados.

No necesita token ni app de Slack: el envío lo hace un `claude -p` (por defecto con `haiku`, unos céntimos por aviso) que solo puede usar `slack_search_users` y `slack_send_message` del conector de Slack de claude.ai. El mensaje sale **en tu nombre**. Requisitos: tener el conector de Slack conectado en claude.ai con la misma cuenta con la que usas Claude Code.

Si activas `slack_notify` sin tener el conector conectado, el bot no gasta tokens: lo comprueba antes con `claude mcp list`, escribe `AVISO Slack` en el log (aparece en `/bitbucket-pr-autofix:status`) y muestra una notificación de escritorio como mucho una vez al día. Los fixes siguen funcionando con normalidad. `/bitbucket-pr-autofix:setup` también lo comprueba.

El revisor se busca en Slack por su nombre visible de Bitbucket, y solo se le escribe si hay una única coincidencia exacta. Si no aparece, añádelo a `slack_users`. Los IDs encontrados se guardan en `state.json`. Comprueba que funciona con `pr-autofix slack-test` (te envía el aviso a ti mismo).

## Comando `pr-autofix`

```bash
pr-autofix status              # timer, último poll, coste, log reciente
pr-autofix run --dry-run       # ver qué detectaría, sin ejecutar nada
pr-autofix run                 # forzar una pasada ahora
pr-autofix whoami              # comprobar credenciales
pr-autofix slack-test          # te envía a ti mismo el aviso de Slack
pr-autofix pending            # fixes de revisión (--review) aún sin resolver: worktrees y copia local
pr-autofix forget <cid>        # olvidar un comentario para reprocesarlo
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
- **"No encuentro clon local"** o **"La carpeta de repos no existe"**: revisa la opción *Carpeta de repos* (`/plugin configure`), incluidas mayúsculas y minúsculas. Si es un repo concreto, clónalo ahí o añádelo en `repo_paths`.
- **Error en el push** (non-fast-forward): el bot hace fetch, un rebase y reintenta una vez. Si vuelve a fallar, responde con el error.
- **Una ejecución se cortó** (por ejemplo, apagaste a mitad): la siguiente pasada la marca como fallida y lo avisa en el hilo. Vuelve a pedirlo o usa `pr-autofix forget <cid>`.
- **`pr-autofix` no existe tras instalar**: ejecuta `/reload-plugins` y vuelve a lanzar `setup`; el hook del plugin crea el comando en tu siguiente mensaje. Si aún no aparece, reinicia Claude Code. Comprueba también que `~/.local/bin` está en tu `PATH`.
- **Coste**: cada ejecución consume uso de Claude (unos 0,10–0,50 $ en cambios pequeños). Consulta el acumulado con `/bitbucket-pr-autofix:status`.
- **Rate limit de Bitbucket**: unas 1000 peticiones/hora por usuario. Con pocas PRs abiertas sobra margen.

---

## Estructura del repo

```
.claude-plugin/plugin.json       # manifiesto del plugin (+ opciones de usuario)
.claude-plugin/marketplace.json  # este repo es también su marketplace
hooks/hooks.json                 # SessionStart / UserPromptSubmit → scripts/sync.sh
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
