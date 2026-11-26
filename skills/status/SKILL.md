---
name: status
description: Muestra el estado de bitbucket-pr-autofix (timer, último poll, comentarios procesados, coste, log reciente y worktrees de revisión sin resolver).
---

# Estado de bitbucket-pr-autofix

1. Ejecuta `pr-autofix status` y `pr-autofix pending`.
   Si `pr-autofix` no existe, indica que hay que ejecutar `/bitbucket-pr-autofix:setup`.
2. Resume en pocas líneas:
   - si el timer está activo,
   - el último poll,
   - el número de comentarios por estado y el coste total,
   - los errores recientes del log (con su causa probable),
   - si en el log aparece `AVISO Slack`, que los avisos de Slack no se están enviando y cómo arreglarlo (conectar Slack en claude.ai o desactivar `slack_notify`),
   - los worktrees de revisión sin resolver (sugiere revisarlos en el IDE (pestaña Commit en JetBrains, Source Control en VS Code) o con `/bitbucket-pr-autofix:review`).
