# claude-pr-bot

Bot local que permite pedir cambios a **Claude Code** desde los comentarios de una Pull Request de Bitbucket.

Escribes en tu PR un comentario como:

```
@claude renombra este método a findActiveCustomers
```

En menos de 2 minutos, Claude aplica el cambio en la rama de la PR, hace commit y push y responde en el hilo del comentario con un resumen y el enlace al commit.

No necesita permisos de admin en Bitbucket (ni webhooks ni Pipelines). Todo se ejecuta **en tu máquina**: un timer de systemd consulta la API de Bitbucket con tu token personal.

---

## Cómo funciona

1. Cada 2 minutos, el bot lista tus PRs abiertas en el workspace (las que tú has creado).
2. Busca comentarios nuevos **escritos por ti** que contengan `@claude`.
3. Hace checkout de la rama de la PR en un `git worktree` aislado. Tu copia de trabajo no se toca.
4. Ejecuta `claude -p` (modo headless) con esta información:
   - el título y la descripción de la PR,
   - tu instrucción (el texto que va después de `@claude`),
   - el comentario al que respondes, si existe (por ejemplo, el de un revisor),
   - el fichero y la línea, si el comentario es inline.
5. Si hay cambios, el script (no Claude) hace commit y push a la rama de la PR y responde en el hilo. Con `--review`, se para antes del commit hasta que tú lo apruebes.
6. Borra el worktree y guarda el comentario como procesado en `state.json`.

### Seguridad

- Solo disparan los comentarios **de quien tiene el bot configurado**. Si otro miembro del equipo escribe `@claude`, no pasa nada en tu máquina.
- Claude solo puede leer y editar ficheros y usar `git diff/status/log/show`. No tiene shell genérico ni acceso a la red, y no puede hacer commit ni push.
- El texto de los revisores se pasa como contexto, no como órdenes.
- El token vive en `.env` con permisos 600 y nunca se envía a Claude ni se escribe en los logs.

---

## Requisitos

- Linux con systemd (sesión de usuario).
- `python3` (3.9 o superior; solo usa la librería estándar).
- `git`, con acceso SSH a Bitbucket configurado (el push usa tu clave).
- [Claude Code](https://docs.claude.com/en/docs/claude-code) instalado y con sesión iniciada: el comando `claude` tiene que estar en el `PATH` y funcionar.
- Los repos clonados localmente bajo una misma carpeta, por ejemplo `~/DeporVillage/<repo>`.

---

## Instalación

### 1. Clonar en `~/claude-pr-bot`

```bash
git clone <url-de-este-repo> ~/claude-pr-bot
cd ~/claude-pr-bot
```

> La ruta `~/claude-pr-bot` es obligatoria porque los units de systemd la usan.

### 2. Crear un API token de Atlassian

1. Entra en https://id.atlassian.com/manage-profile/security/api-tokens.
2. Pulsa **Create API token with scopes** y elige la app **Bitbucket**.
3. Marca estos scopes:
   - `read:repository:bitbucket`
   - `read:pullrequest:bitbucket`
   - `write:pullrequest:bitbucket`
4. Copia el token.

> Las App Passwords de Bitbucket están deprecadas; usa un API token.

### 3. Primera ejecución del instalador

```bash
./install.sh
```

Crea `config.json` y `.env` a partir de las plantillas y se detiene.

### 4. Rellenar credenciales

Edita `.env`:

```
BB_EMAIL=tu.email@deporvillage.com
BB_API_TOKEN=el-token-que-has-creado
```

### 5. Revisar `config.json`

Como mínimo, comprueba `repos_root`, la carpeta donde tienes clonados los repos. Ver [Configuración](#configuración).

### 6. Segunda ejecución del instalador

```bash
./install.sh
```

Valida las credenciales (muestra tu nombre), instala el timer y lo activa. A partir de aquí arranca solo cada vez que inicies sesión.

### 7. Probarlo

1. Abre una PR de prueba.
2. Comenta `@claude --review añade un comentario en la línea X`.
3. Espera unos 2 minutos.
4. Ejecuta `./bot.py pending` y luego `./bot.py approve <cid>`.

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

> Si editas un comentario que ya se procesó, no se vuelve a ejecutar. Escribe un comentario nuevo o usa `./bot.py forget <cid>`.

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
   ```bash
   ./bot.py pending              # lista los fixes pendientes (repo, PR, carpeta del worktree, resumen)
   ./bot.py show <cid>           # muestra el commit propuesto y el diff completo
   ```
   Si quieres, abre la carpeta del worktree en tu IDE, retoca el código o ejecuta los tests.
4. Decides:
   ```bash
   ./bot.py approve <cid>        # commit (con tus retoques incluidos) + push + respuesta ✅ en la PR
   ./bot.py reject <cid> motivo  # descarta los cambios + respuesta 🚫 en la PR
   ```

Si quieres revisar siempre, sin tener que poner `--review` en cada comentario, pon `"mode": "review"` en `config.json`. Cuando quieras push directo en un caso concreto, usa `@claude --push …`.

---

## Configuración

`config.json` es personal y no se versiona. Las claves principales:

| Clave | Descripción | Por defecto |
|---|---|---|
| `workspace` | Workspace de Bitbucket | `deporvillage` |
| `repos_root` | Carpeta con tus clones. El bot asocia cada repo por el remote `origin`. | `~/DeporVillage` |
| `repo_paths` | Rutas manuales `{ "slug": "~/ruta" }` si un repo está en otra carpeta | `{}` |
| `extra_repos` | Repos en los que vigilar también PRs que **no** son tuyas (más llamadas a la API) | `[]` |
| `mode` | `auto` (commit + push directo) o `review` (revisas tú antes del commit y push) | `auto` |
| `trigger` | Palabra que dispara el bot | `@claude` |
| `claude_bin` | Binario de Claude Code | `claude` |
| `model` | Modelo a usar (vacío = el de tu configuración) | `""` |
| `max_turns` / `timeout_sec` | Límites de cada ejecución de Claude | `30` / `900` |
| `lookback_minutes` | Margen hacia atrás al buscar comentarios nuevos | `10` |
| `allowed_tools` | Herramientas permitidas a Claude | lectura/edición + `git diff/log/status/show` |
| `extra_allowed_tools` | Herramientas extra por repo, por ejemplo para ejecutar tests | `{}` |
| `disallowed_tools` | Herramientas prohibidas | `git push/commit/reset`, web |

Ejemplo para dejar que Claude ejecute los tests de un repo:

```json
"extra_allowed_tools": {
  "customer-service": ["Bash(make test:*)", "Bash(vendor/bin/phpunit:*)"]
}
```

---

## Operación

```bash
systemctl --user status claude-pr-bot.timer      # ¿está activo?
journalctl --user -u claude-pr-bot -f            # logs de systemd
tail -f ~/claude-pr-bot/bot.log                  # log del bot
./bot.py run --dry-run                           # ver qué detectaría, sin ejecutar nada
./bot.py run                                     # forzar una pasada ahora
./bot.py whoami                                  # comprobar credenciales
```

Detener o desinstalar:

```bash
systemctl --user disable --now claude-pr-bot.timer
rm ~/.config/systemd/user/claude-pr-bot.{service,timer} && systemctl --user daemon-reload
```

### Cuándo se ejecuta

- Arranca solo al iniciar sesión en el escritorio y se ejecuta cada 2 minutos mientras la sesión está abierta.
- Los comentarios que hagas con el ordenador apagado se procesan en la primera pasada después de iniciar sesión.
- El push usa el agente SSH de tu sesión gráfica, por eso el bot solo funciona con la sesión iniciada.

---

## Limitaciones y problemas habituales

- **Solo PRs propias**: por defecto solo vigila las PRs de las que eres autor. Para otras, añade el repo a `extra_repos`.
- **PRs desde fork**: no están soportadas.
- **"No encuentro clon local"**: el repo no está bajo `repos_root`. Clónalo o añádelo en `repo_paths`.
- **Error en el push** (non-fast-forward): el bot hace fetch, un rebase y reintenta una vez. Si vuelve a fallar, responde con el error.
- **Un comentario se quedó en `running`** (por ejemplo, apagaste a mitad): ejecuta `./bot.py forget <cid>` para que se reprocese.
- **Coste**: cada ejecución consume uso de Claude (unos 0,10–0,50 $ en cambios pequeños). El coste de cada fix queda en `state.json`.
- **Rate limit de Bitbucket**: unas 1000 peticiones/hora por usuario. Con pocas PRs abiertas sobra margen.

---

## Ficheros

```
bot.py                 # el bot (solo stdlib)
install.sh             # instalador / validador
config.example.json    # plantilla de configuración  → config.json (personal)
.env.example           # plantilla de credenciales   → .env (personal, 600)
systemd/               # service + timer (cada 2 min)
state.json             # comentarios procesados (generado)
worktrees/             # worktrees temporales / pendientes de revisión (generado)
bot.log                # log (generado)
```
