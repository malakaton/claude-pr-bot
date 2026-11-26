---
name: review
description: Revisa con el usuario los fixes de bitbucket-pr-autofix entregados sin commit (comentarios @claude --review): muestra el diff, da una valoración y aplica retoques. Úsalo cuando el usuario quiera revisar cambios del bot.
---

# Revisión de fixes `--review`

Con `@claude --review` el bot deja los cambios **sin commit**:
- en la copia local del usuario, si estaba en la rama de la PR y limpia, o
- en un worktree `<repo>/.claude-review/pr<id>-c<cid>/` visible en el IDE (pestaña Commit en JetBrains, Source Control en VS Code). Su rama tiene como upstream `origin/<rama-PR>`.

El usuario aprueba haciendo commit + push desde el IDE, o descarta con rollback. El bot da por resueltos (y limpia) los worktrees y entregas locales en el siguiente poll.

1. `pr-autofix pending` lista los fixes sin resolver: worktrees y entregas en la copia local (marcadas `[copia local]`, con el repo y los ficheros tocados). Si `$ARGUMENTS` contiene un id de comentario, céntrate solo en ese. Si `pending` no lista nada pero el usuario dice que hay cambios (entregas anteriores a 0.5.2), usa `git status` y `git diff HEAD` en el repo de la PR.
2. Para cada uno:
   - Worktree: `git -C <worktree> diff HEAD` para ver el diff, incluidos los ficheros nuevos (están como intent-to-add).
   - Copia local: `git -C <repo> diff HEAD -- <ficheros>`. Si `git status` muestra otros cambios del usuario, dilo: no son del bot.
   - Lee el contexto necesario para valorar el cambio.
   - Presenta: repo, PR (enlace), qué pedía el comentario, resumen del cambio y tu **valoración honesta**: si es correcto, riesgos, tests que convendría ejecutar o posibles mejoras.
3. Si pide retoques, edita los ficheros dentro del worktree (o de su copia local) y vuelve a enseñar el diff.

**No hagas commit, push, rollback ni borres worktrees por tu cuenta**: eso lo decide el usuario desde su IDE. Si te lo pide explícitamente, el push desde un worktree es `git -C <worktree> push origin HEAD:<rama-PR>`.
