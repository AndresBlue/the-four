# Nota de relevo

Lo que una sesión nueva tiene que saber para seguir. Se reescribe en cada relevo; lo que ya está en git o en los documentos no se repite aquí.

**Última actualización:** 22 de octubre de 2026, 13:10, al pasar al trabajo en tres niveles (`CLAUDE.md`, «Cómo se trabaja»).

## En qué estamos

**El piso 2, las oficinas secretas** ([docs/OFICINAS.md](../docs/OFICINAS.md)). Va por la fase 0 (los cimientos, con el hotel idéntico).

| Paso | Estado |
|---|---|
| 0a1 Prueba dorada del manifiesto, clase base `creature.gd`, alias | Hecho (`3b909f0`) |
| 0a2 Director, aura, audio, cordura y fantasmas por el contrato | Hecho (`1171788`) |
| 0a3 Ascensores, teles, reaparición y guardado; un teletransporte | Hecho (`d59cf8d`) |
| 0a4 Capturas como estrategia de cada criatura | Hecho (`a854b6f`) |
| 0a5 Red, observador y bots por el contrato | **En el árbol de trabajo, sin commit:** implementado y revisado, falta `verify.ps1` |
| 0b a 0f | Pendientes (`.claude/specs/fase0_pasos.md`) |
| Fases 1 a 5 | Pendientes |

**Lo primero al retomar:** cerrar 0a5.
1. `git status` debe mostrar solo sus archivos: `match_net.gd`, el observador, `run_ledger`, `interaction`, `presentation_rig`, `shader_warmup`, `creature.gd`, `hotel_locust.gd`, los bots, `tools/bots/bot_threats.gd` y las pruebas.
2. Pasar `verify.ps1` con un agente de la batería.
3. Si está en verde, hacer el commit. Si no, un frente corto de arreglos.

Hay 0 commits sin subir (el último subido es `a854b6f`).

## Especificaciones (en `.claude/specs/`)

| Archivo | Qué | Estado |
|---|---|---|
| `fase0_pasos.md` | Pasos 0a2 a 0f, en inglés (0a2 a 0a5 ya hechos) | Al día. El de 0d lleva el requisito de la paleta como miembro de instancia |
| `spec_f1_generator.md` | 1a a 1c: paleta, tipo de piso, criatura nula, generador, ductos, validador, métricas | Revisado por críticos |
| `spec_f1_geometry.md` | 1d: geometría de oficinas y plan de ingesta de assets | Revisado por críticos |
| `spec_f1_systems.md` | 1e a 1i: tubos y fichas, cuadro y minuteros, climatización y ducto, papeles, pruebas | Revisado por críticos |
| `spec_f2_movement.md` | 2a: cómo se mueve The Lurker | **Borrador sin revisar**: la cuota cortó la crítica |
| `spec_f2_mind.md` | 2b: sentidos, cerebro y la garantía del aviso de la espalda | **Borrador sin revisar** |
| `spec_f3_integration.md` | Fase 3: el piso jugable en solitario | **Borrador sin revisar** |

Las especificaciones son la nota de diseño de cada área. Con el trabajo en tres niveles, cada una pasa por el flujo `encargos`, que la parte en unidades cerradas para la batería, antes del flujo `frente`.

## Decisiones que esperan al autor

El borrador `spec_f2_mind.md` propone seis decisiones que no están en OFICINAS.md:

1. **También salva** a la víctima un compañero que mira a The Lurker en una sala con luz (no solo su linterna en la cara).
2. **La linterna cuenta según adónde apunta la cámara**, no según el haz, que va con retraso.
3. **La latencia en red** se suma a la ventana del aviso: ida y vuelta más 0,1 s, con un tope de 0,5 s.
4. **La captura puede llegar** hasta 0,6 s después de acabar la ventana.
5. **No abre taquillas**, y esconderse durante la ventana anula la captura.
6. **Beber la luz** nunca hace que una sala cuente como oscura.

## Assets del piso 2 (`source_assets/oficinas/`, fuera de git)

- `RESUMEN.md` y un `registro.json` por grupo: 98 se quedan, con su licencia auditada.
- **91 piden sesión** (44 modelos de Sketchfab, 47 sonidos de Freesound). El autor conectó la extensión de navegador con sus sesiones el 22 de octubre, pero **las descargas de Sketchfab se cortan hacia los 10 MB y no dejan archivo**. Se probaron dos caminos con el mismo resultado:
  - un iframe oculto;
  - `location.assign` del enlace firmado que da `/i/models/<uid>/download` → `latest.gltf[0].url` → JSON con `url`.

  El navegador es **Chromium** (no Chrome). Sospechas: su ajuste de descargas o el antivirus (Kaspersky). Freesound no se ha probado.
- `scratchpad/move_downloads.py` (de la sesión anterior) llevaba cada archivo de Descargas a su carpeta por su tamaño exacto. Si hace falta, se rehace.

## Herramientas de esta forma de trabajar

- **Flujos guardados** (`.claude/workflows/`):
  - `encargos`: de la nota de diseño a las unidades cerradas, con fichas Haiku, un redactor Opus y dos críticos;
  - `frente`: las unidades con Haiku, el revisor de área Opus, hasta dos rondas de correcciones, `verify.ps1` y la revisión adversarial de las costuras.
- **Regulador:** `mcp__ccd_session_mgmt__get_usage` en cada frontera de flujo. Al relevo, la ventana de 5 horas iba al 7 % (se renueva a las 17:40) y la semanal al 61 % (se renueva el 24 de octubre a las 05:00).
