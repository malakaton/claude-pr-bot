---
name: review
description: Revisa con el usuario los fixes de bitbucket-pr-autofix pendientes (comentarios @claude --review) y los aprueba (commit + push) o rechaza. Úsalo cuando el usuario quiera revisar, aprobar o rechazar cambios pendientes del bot.
---

# Revisión de fixes pendientes

El usuario pidió `@claude --review`: los cambios están aplicados en un worktree local **sin commit ni push**. Tu trabajo es ayudarle a decidir.

1. `pr-autofix pending`. Si no hay pendientes, dilo y termina. Si `$ARGUMENTS` contiene un id de comentario, céntrate solo en ese.

2. Para cada pendiente (`c<id>`):
   - `pr-autofix show <id>` para ver el commit propuesto y el diff.
   - Lee el contexto necesario dentro del worktree (ruta que muestra `pending`) para valorar el cambio.
   - Presenta: repo, PR (enlace), qué pedía el comentario, resumen del cambio y tu **valoración honesta**: si es correcto, riesgos, tests que convendría ejecutar o posibles mejoras.

3. Pregunta al usuario qué hacer con cada uno:
   - **Aprobar** → `pr-autofix approve <id>`. Hace commit (incluye retoques manuales) + push + respuesta en la PR.
   - **Retocar** → edita los ficheros dentro del worktree según lo que pida, vuelve a enseñar el diff y pregunta otra vez.
   - **Rechazar** → `pr-autofix reject <id> <motivo>`.

**Nunca ejecutes `approve` ni `reject` sin confirmación explícita del usuario para ese id concreto.** No hagas commit ni push por tu cuenta; usa solo esos comandos.
