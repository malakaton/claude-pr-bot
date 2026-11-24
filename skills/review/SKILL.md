---
name: review
description: Revisa con el usuario los fixes de bitbucket-pr-autofix entregados sin commit (comentarios @claude --review): muestra el diff, da una valoración y aplica retoques. Úsalo cuando el usuario quiera revisar cambios del bot.
---

# Revisión de fixes `--review`

Con `@claude --review` el bot deja los cambios **sin commit**:
- en la copia local del usuario, si estaba en la rama de la PR y limpia, o
- en un worktree `<repo>/.claude-review/pr<id>-c<cid>/` visible en el IDE (pestaña Commit en JetBrains, Source Control en VS Code). Su rama tiene como upstream `origin/<rama-PR>`.

El usuario aprueba haciendo commit + push desde el IDE, o descarta con rollback. El bot limpia solo los worktrees resueltos en el siguiente poll.

1. `pr-autofix pending` lista los worktrees sin resolver. Si `$ARGUMENTS` contiene un id de comentario, céntrate solo en ese. Si el usuario habla de cambios ya aplicados en su copia local, usa `git status` y `git diff` en ese repo.
2. Para cada uno:
   - `git -C <worktree> diff HEAD` para ver el diff, incluidos los ficheros nuevos (están como intent-to-add).
   - Lee el contexto necesario para valorar el cambio.
   - Presenta: repo, PR (enlace), qué pedía el comentario, resumen del cambio y tu **valoración honesta**: si es correcto, riesgos, tests que convendría ejecutar o posibles mejoras.
3. Si pide retoques, edita los ficheros dentro del worktree (o de su copia local) y vuelve a enseñar el diff.

**No hagas commit, push, rollback ni borres worktrees por tu cuenta**: eso lo decide el usuario desde su IDE. Si te lo pide explícitamente, el push desde un worktree es `git -C <worktree> push origin HEAD:<rama-PR>`.
