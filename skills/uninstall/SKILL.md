---
name: uninstall
description: Detiene y desinstala el timer de bitbucket-pr-autofix. Úsalo cuando el usuario quiera parar o quitar el bot.
disable-model-invocation: true
---

# Desinstalar bitbucket-pr-autofix

1. `pr-autofix pending`. Si hay fixes pendientes, avisa de que sus worktrees se conservan y pregunta si quiere revisarlos antes (`/bitbucket-pr-autofix:review`).
2. Con confirmación del usuario, ejecuta `pr-autofix remove-units`.
3. Explica:
   - Para quitar también el plugin: `/plugin uninstall bitbucket-pr-autofix@bitbucket-pr-tools`. Esto borra los datos (`state.json`, log) salvo que elija conservarlos. Los worktrees viven en `~/.cache/bitbucket-pr-autofix/worktrees` y no se borran solos.
   - El wrapper `~/.local/bin/pr-autofix` y `~/.config/bitbucket-pr-autofix/` se pueden borrar a mano.
