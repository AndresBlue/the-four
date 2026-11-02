# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

## Cómo se trabaja: tres niveles

Estas reglas son para la sesión principal (el director). Un agente lanzado por ella cumple su encargo y no lanza más agentes. Adaptadas de Homeworld (22 de octubre de 2026).

El autor pide de forma permanente la orquestación multiagente en este proyecto. No hace falta que la pida en cada mensaje ni que escriba «ultracode».

- **Director:** la sesión principal, en Opus 5.5 con esfuerzo xhigh. El esfuerzo de la sesión lo elige el autor en el menú de la app; una sesión no puede cambiarse el suyo.
  - Decide el diseño y los contratos, parte el trabajo en áreas y unidades, aprueba los encargos y resuelve lo que le escalan.
  - Es el único que hace commit y push.
  - Tiene la última palabra, pero solo interviene cuando hace falta.
- **Revisores:** agentes Opus 5.5 con esfuerzo high.
  - Los revisores de área leen el trabajo de los Haiku de su área, mandan correcciones y dan el área por buena.
  - Los críticos de diseño intentan tumbar cada decisión antes de repartirla.
  - Los revisores adversariales buscan defectos en las costuras al integrar.
  - También redactan los encargos a partir de la nota de diseño.
- **Batería:** agentes Haiku 5.5 con esfuerzo xhigh. Hacen el trabajo sustantivo: código, pruebas, fichas de hechos, descargas, capturas.
  - La lanza un Workflow; no se trabaja con subagentes sueltos de uno en uno.

La sesión principal solo trabaja a solas en lo trivial, lo conversacional o lo que no se puede partir. Sus turnos pesan (arrastra todo el contexto): pocos y cortos. Antes de llegar a un 60 % de contexto, deja la nota de relevo (`.claude/relevo.md`) y pide al autor seguir en una sesión nueva.

### Modelos y esfuerzo

- **Batería:** `model: 'haiku', effort: 'xhigh'`, explícito en cada `agent()`. Si se omite `model`, el agente hereda Opus y gasta la cuota demasiado rápido.
- **Revisores, críticos y quien redacta encargos:** `model: 'opus', effort: 'high'`.
- Cada entrada de `meta.phases` declara el modelo de su fase.
- Con la herramienta Agent rigen los mismos modelos.
- Otro reparto de modelos, solo si el autor lo pide de forma expresa.

### La máquina es lo escaso: Godot

- **`tools/verify.ps1`:**
  - tarda de 5 a 8 minutos y ya corre 8 trabajos a la vez;
  - **nunca dos a la vez**;
  - los escenarios de red usan puertos fijos: tampoco dos a la vez.
- **Las pruebas de Godot por unidad:**
  - solo las que nombre el encargo, cortas y sin interfaz (`--headless`);
  - las unidades que van en paralelo no ejecutan Godot: lo hace después su revisor, en serie.
- **Árboles de trabajo:** no se usan, porque cada uno importaría todos los assets de nuevo (`.godot/` no está en git). Las unidades en paralelo escriben archivos disjuntos en el árbol principal.
- **Capturas con ventana, exportaciones y el banco:** los lanza el director o un único agente a la vez.

### Carriles: no fases en fila

- **Diseño por delante.** Mientras la batería construye, el director diseña lo siguiente.
  - Antes de repartir, dos o tres críticos atacan la nota de diseño: qué falla, qué no se ha pensado, qué prueba lo demostraría.
  - Los encargos los redactan los revisores con fichas de hechos levantadas del código por Haiku (flujo `encargos`), y el director los aprueba.
- **Construcción.** La batería, por oleadas (flujo `frente`). Las unidades que comparten archivos o necesitan Godot van en serie.
- **Integración continua.** Cada área aprobada se integra enseguida, sin esperar a las demás:
  - `verify.ps1` en verde;
  - la revisión adversarial de sus costuras con lo ya hecho;
  - las capturas que la enseñan;
  - la auditoría de sus documentos contra el código.

  Solo entonces el director hace commit. Cerrar una fase es confirmar que todo eso está en verde, no empezar a mirarlo.
- **Relleno.** Trabajo siempre valioso que no pide decisiones, para cuando los otros carriles esperan: pruebas de lo decidido que no tiene prueba, revisión adversarial de lo ya hecho, inventario y preparación de assets.

### El regulador de la ventana

El autor quiere que cada ventana de cuota se use entera y que dure entera: ni parar a media ventana por haberla agotado, ni dejar cuota sin usar.

- En cada frontera de flujo se lee el uso real (`mcp__ccd_session_mgmt__get_usage`: la ventana de 5 horas y la semanal) y se compara con la recta que llega al 95 % al final de la ventana.
- **Por debajo de la recta:** ensanchar la batería y abrir el relleno.
- **Por encima:** cerrar el relleno y después bajar hondura (menos revisores, menos rondas). El carril principal no se corta a medias.
- Se reserva del 5 al 8 % para cerrar la ventana: comprobar, confirmar lo aprobado y dejar la nota de relevo.
- No se lanza un flujo que no quepa en lo que queda de ventana. Se vigila también el límite semanal.

### Encargos

La calidad con Haiku depende del encargo: cuanto menos le deje por decidir, mejor.

- **El diseño se resuelve antes de repartir.** Cada encargo es pequeño y cerrado:
  - qué archivos se escriben y cuáles no se tocan;
  - las firmas y los fragmentos literales del código que necesita (de las fichas);
  - con qué órdenes se verifica y qué resultado se espera.
- **Cada área lleva su prueba de aceptación**: lo que hay que ver funcionando (una cifra medida, una captura, un caso de punta a punta), no solo «pasan las pruebas».
- **Si el encargo no encaja con el código**, el agente lo informa y no rediseña por su cuenta.
- **Los minutos** que un agente dice haber tardado no valen: el reloj lo lleva el director.

### Revisión por área

Ningún paso se da por bueno por el informe del agente que lo hizo.

- **El revisor de área** recibe el encargo completo de su área y los informes de sus Haiku.
  - Lee el cambio real de cada unidad (el diff, no el resumen) y repite la verificación.
  - Acepta solo si está resuelto como lo habría resuelto el director: correcto, mínimo, fiel al diseño y en el estilo del código de alrededor.
- **Devuelve un veredicto estructurado:**
  - unidades aceptadas;
  - correcciones concretas para las que no llegan;
  - decisiones que no le corresponden;
  - un resumen del área.
- **No lanza agentes:** el flujo ejecuta sus correcciones con Haiku y le devuelve el resultado para otra ronda. Tras dos rondas sin cerrar, el área sube al director.
- Dentro de su área decide él. Sube al director lo que cambia el diseño o un contrato, lo que afecta a otra área o lo que no puede resolver.

### Reglas de este proyecto para todos los agentes

- **Godot:** `"D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" --headless --path . --script res://<script>.gd --log-file <archivo> -- --automation --test-profile --silent`.
  - **Siempre `--test-profile`.**
  - Después de cada ejecución: `git restore default_bus_layout.tres assets/audio/the_four_theme.mp3.import`.
  - Los errores de GDExtension de godotsteam son normales.
- **El usuario:** nunca matar un proceso `TheFour.exe` ni tocar su perfil real (`%APPDATA%\Godot\app_userdata\THE FOUR — Hotel`).
- **Git:** los agentes no hacen commit, push, stash ni reset, ni descartan cambios ajenos.
  - El director hace commit con rutas explícitas en `git add` y el mensaje en inglés.
  - El push, cada 3 o 4 commits.
- **Bash:** los heredocs con apóstrofos fallan en este equipo. Los guiones auxiliares se escriben a un archivo y se ejecutan.
- **Código:**
  - el estilo del de alrededor (comentarios `##` breves en inglés que dicen el porqué, tabulaciones, GDScript tipado);
  - tipos explícitos donde la inferencia falla (ternarios, Variant).
- **Textos:**
  - ningún texto del juego lleva «·» ni «—»;
  - los documentos van en español y dicen solo lo que es verdad.
- **Lore:** solo lo que el autor confirma.
- **Sonido:** nada de voces ni gritos humanos sintéticos.
- **Assets:** licencias que permitan vender el juego (nunca NC, ND ni SA), sin crear cuentas ni escribir contraseñas (`docs/OFICINAS.md` §12).
- **El piso 1 (el hotel) no cambia** salvo que el encargo lo diga: lo vigilan `manifest_golden_test` y `creature_contract_test`.

### Dónde está el estado

- `.claude/relevo.md`: la nota de relevo (qué se está haciendo, qué falta, qué decidió el autor). Una sesión nueva la lee primero.
- `docs/OFICINAS.md`: el diseño aprobado del piso 2.
- `.claude/specs/`: las especificaciones de implementación por fase.
- `.claude/workflows/`: los flujos guardados (`encargos` y `frente`).

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

_Add your build and test commands here_

```bash
# Example:
# npm install
# npm test
```

## Architecture Overview

_Add a brief overview of your project architecture_

## Conventions & Patterns

_Add your project-specific conventions here_
