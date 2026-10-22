# Nota de relevo

Lo que una sesión nueva tiene que saber para seguir. Se reescribe en cada relevo; lo que ya está en git o en los documentos no se repite aquí.

**Última actualización:** 22 de octubre de 2026, 16:35, con 0d confirmado y la ventana de 5 horas al 85 %.

## En qué estamos

**El piso 2, las oficinas secretas** ([docs/OFICINAS.md](../docs/OFICINAS.md)). Va por la fase 0 (los cimientos, con el hotel idéntico).

| Paso | Estado |
|---|---|
| 0a1 a 0a5 Contrato de criatura y sus migraciones | Hecho (`3b909f0` a `d32f23a`) |
| 0b Objetivos como manejadores | Hecho (`86a4333`) |
| 0c Tipo de piso elegible y número de piso | Hecho (`9f759db`) |
| 0d Paletas de sala | Hecho (`592dce2`) |
| 0f Dificultad y reglas por criatura | **Encargos aprobados** (`.claude/specs/encargos_0f.json`); falta el frente |
| 0e Pasos de `build_room`, luz por sala, `put_on_actor` | Pendiente: ni encargos ni frente (nota de diseño en `.claude/specs/fase0_pasos.md`) |
| Fases 1 a 5 | Pendientes |

**Lo primero al retomar:**
1. Leer el uso (`mcp__ccd_session_mgmt__get_usage`). **Tope del autor: detener el desarrollo al 80 % semanal** (vale para la semana que se renueva el 24 de octubre a las 05:00).
2. El frente de 0f, en serie (sus tres unidades comparten `hotel_main.gd` y ejecutan Godot): `Workflow({scriptPath: "E:/Projects/The Four/.claude/workflows/frente.js", args: {area: "0f dificultad y reglas por criatura", archivo: ".claude/specs/encargos_0f.json", paralelo: false, integrar: true, unidades: [{id: "U1-dificultad-por-criatura", archivos: [...]}, {id: "U2-reglas-por-criatura", ...}, {id: "U3-documentos", ...}]}})`. Los ids y archivos exactos están en el JSON.
3. Después, `encargos` de 0e (toca `hotel_geometry`, `sanity`, `phantom_sight`, los bots y `ROOM_LAYERS`) y su frente, si caben por debajo del 80 %.
4. Al confirmar 0f: poner al día la línea 3 de `docs/OFICINAS.md` (dice que 0e y 0f están por hacer).

## Cómo se lanzan los flujos (aprendido hoy)

- **Siempre por `scriptPath`** (`E:/Projects/The Four/.claude/workflows/frente.js` o `encargos.js`). Por nombre se ejecuta la copia que se cargó al abrir la sesión, y no ve los cambios de los archivos.
- `frente` admite `archivo` (lee contexto, aceptación, pruebas y el texto de cada unidad del JSON que dejó `encargos`; en `unidades` basta `{id, archivos}`) y `primero` (ids de unidades que van antes y solas, p. ej. la que crea el archivo que leen las demás).
- Coste medido: unos `encargos` gastan de 8 a 10 puntos de la ventana de 5 horas (son Opus); un frente, de 5 a 10. Cada paso de la fase 0, unos 2 o 3 puntos semanales. El autor quiere el modo completo en todos los pasos.
- Las capturas no van en los pasos que no cambian nada visible; basta la galería sin ventana (`tools/editor/build_gallery.gd`), que se compara normalizada (`evidence/gallery_twice.txt`).

## Especificaciones (en `.claude/specs/`)

| Archivo | Qué | Estado |
|---|---|---|
| `fase0_pasos.md` | Notas de diseño de 0a2 a 0f | Al día |
| `encargos_0b/0c/0d/0f.json` | Encargos de cada paso, con las decisiones del director al final del contexto | 0b, 0c y 0d construidos; 0f por construir |
| `spec_f1_generator.md` | 1a a 1c | Revisado por críticos; al día con lo que dejó 0d (sección 0, «What 0d left», y la paridad de paletas en 1.2) |
| `spec_f1_geometry.md` | 1d | Revisado por críticos; R2 y H8 al día con 0d |
| `spec_f1_systems.md` | 1e a 1i | Revisado por críticos; `reset()` lo cablea 1e en `revival.apply_revival()` |
| `spec_f2_movement.md` | 2a | Revisado por dos críticos hoy, **no aprobado**; §15 «Pending decisions» (13 para el autor) |
| `spec_f2_mind.md` | 2b | Revisado hoy, **no aprobado**; §14 «Pending decisions» |
| `spec_f3_integration.md` | Fase 3 | Revisado hoy, **no aprobado**; §15 (11 para el autor). No se parte en unidades hasta reconciliar 2a y 2b |

## Decisiones que esperan al autor

1. Las secciones «Pending decisions» de los tres borradores de las fases 2 y 3 (arriba). Incluyen las seis de `spec_f2_mind` que ya estaban: quién salva a la víctima, la linterna según la cámara, la latencia en la ventana del aviso, la captura hasta 0,6 s después, no abre taquillas, beber la luz.
2. **Dificultad de The Lurker** (0f deja fuera lo que OFICINAS no cuantifica): los asomos por dificultad, `sated`, `forget`, las seis claves de sistema de `spec_f1_systems` 1.8 y los ajustes del director.
3. **Las cuatro líneas de The Lurker en el menú de dificultad** (`TRAITS`): texto del juego, lo escribe el autor.

## Assets del piso 2 (`source_assets/oficinas/`, fuera de git)

- `RESUMEN.md` y un `registro.json` por grupo: 98 se quedan, con su licencia auditada.
- **91 piden sesión** (44 modelos de Sketchfab, 47 sonidos de Freesound). Las descargas de Sketchfab por la extensión se cortan hacia los 10 MB y no dejan archivo (navegador Chromium; sospechas: su ajuste de descargas o Kaspersky). Freesound no se ha probado.

## Pendientes menores

- `evidence/` tiene archivos de línea base de 0d sin seguimiento (`gallery_*.tscn`, `base_layers.out`, `gallery_twice.txt`): se pueden borrar.
- beads `four-7ly.2.1`: el número de piso en las grabaciones de bots, `presentation_rig` y la sala, y `tools/godot.ps1` sin `-Floor` para el observador (también en `docs/PLAN.md`).
