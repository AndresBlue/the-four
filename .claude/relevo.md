# Nota de relevo

Lo que una sesión nueva tiene que saber para seguir. Se reescribe en cada relevo; lo que ya está en git o en los documentos no se repite aquí.

**Última actualización:** 22 de octubre de 2026, por la noche, con el contexto de la sesión al 51 %. La semana va al 78 %: el tope del autor es el 80 % hasta que se renueve, el 24 de octubre a las 05:00.

**Última instrucción del autor:** seguir el desarrollo **sin workflows, solo con el agente principal**. U1 a U5 de 1b se hicieron así, leyendo cada unidad de `encargos_1b.json` y verificándola con su sonda.

## En qué estamos

**El piso 2, las oficinas secretas** ([docs/OFICINAS.md](../docs/OFICINAS.md)). La fase 0 está cerrada y la fase 1 ha empezado.

| Paso | Estado |
|---|---|
| Fase 0 (0a a 0f) | Hecha: 0a `3b909f0`..`d32f23a`, 0b `86a4333`, 0c `9f759db`, 0d `592dce2`, 0f `1f09795`, 0e `db7eca1` |
| 1a Tipo de piso de oficina, paleta, criatura nula | Hecho (`54e99d9`): construido, sin publicar (`floor_index.RELEASED = [1]`) |
| 1b Generador de oficinas | **U1 a U5 hechos** (ganchos en `map_generator`, `conduit_metres.gd`, `office_layout.gd`, `place_specials` y `finish`); faltan U6 a U12 (`furnish` y sus sistemas, `office_test`, documentos) |
| Contrato para montar el piso 2 en escena | Paso propio antes de 1d, sin encargos (lo describe `spec_f1_generator.md`, notas finales de 1a) |
| 1c a 1i, fases 2 a 5 | Pendientes |

**Lo primero al retomar:**
1. Leer el uso (`mcp__ccd_session_mgmt__get_usage`). Si la semana sigue sin renovarse, el tope del autor es el 80 %.
2. Seguir 1b por U6, en serie, como se hicieron U1 a U5: leer la unidad en `encargos_1b.json` (`python -c` con `PYTHONIOENCODING=utf-8`), escribir el código (bloques largos con Write a un archivo, nunca heredocs con apóstrofos), su sonda `evidence/1b_probe_U<n>.gd` y las pruebas con `scratchpad/gt.sh` o una orden equivalente (Godot con `--test-profile` y `git restore` después). Al acabar U12, `verify.ps1` y commit.
   - Lo que dejaron U4 y U5: con 100 semillas a 2 supervivientes, 0 pisos de respaldo, 0 inválidos, mediana de 175 ms; con 32 pisos a 2, 4 y 5, 0 de respaldo y DEPOT en 4 y 5. Dos pisos de 5 supervivientes (semillas 41 y 42) quedan sin sala de juntas en la planta 1 porque no hay módulo grande: el encargo lo admite (se convierten las candidatas que haya).
   - `f.specials` y `f.departments` están en el trabajo del generador, no en el manifiesto: los escribe `furnish()` (U6 en adelante).
3. Al cerrar 1b: corregir en `spec_f1_generator.md` las líneas de código que cita y que ya no casan (punto 1 de `al_director_resuelto` en el JSON).
4. Después: los encargos de 1c (validador y `office_metrics`, sección 3 de la misma especificación) y el paso del contrato.

## Cómo se trabaja con los flujos (aprendido el 22 de octubre)

- **Siempre por `scriptPath`** (`E:/Projects/The Four/.claude/workflows/frente.js` o `encargos.js`). Por nombre se ejecuta la copia cargada al abrir la sesión.
- `frente` admite `archivo` (lee del JSON de `encargos` el contexto, la aceptación, las pruebas y el texto de cada unidad; en `unidades` basta `{id, archivos}`) y `primero` (unidades que van antes y solas).
- Antes de un frente que no debe cambiar nada visible, el director saca la línea base sin ventana: la galería (`tools/editor/build_gallery.gd`, comparada normalizada con el sed de `evidence/gallery_twice.txt`) y `light_layers_scan` con 40 semillas (todo menos `slowest_ms`).
- Las decisiones del director sobre lo que escala un redactor se añaden al final del `contexto` del JSON («DECISIONES DEL DIRECTOR…») y lo escalado pasa a `al_director_resuelto`.
- Coste medido hoy: unos `encargos`, de 1 a 2 puntos semanales; un frente, de 1 a 2. El autor quiere el modo completo en todos los pasos.

## Especificaciones (en `.claude/specs/`)

| Archivo | Estado |
|---|---|
| `fase0_pasos.md` | Fase 0 hecha |
| `encargos_0b` a `encargos_1a.json` | Construidos; `encargos_1b.json` aprobado, por construir |
| `spec_f1_generator.md` | Revisado por críticos; al día con 0d y 1a (notas al final) |
| `spec_f1_geometry.md` | Revisado; R2 y H8 al día con 0d |
| `spec_f1_systems.md` | Revisado; notas de 0e al final (corriente de sala, rebote, sonda, `death_tape` y `floor_map`) |
| `spec_f2_movement.md`, `spec_f2_mind.md` | Revisados por críticos el 22 de octubre, **no aprobados**; decisiones pendientes al final de cada uno; nombres de claves de dificultad: los de `spec_f2_mind` 4.1 |
| `spec_f3_integration.md` | Revisado, **no aprobado**; no se parte en unidades hasta reconciliar 2a y 2b; nota de 1a sobre el departamento en la tarjeta de planta |

## Decisiones que esperan al autor

1. Las secciones «Pending decisions» de `spec_f2_movement` (§15, 13 para el autor), `spec_f2_mind` (§14, con las seis de siempre: quién salva a la víctima, la linterna según la cámara, la latencia en la ventana del aviso, la captura hasta 0,6 s después, no abre taquillas, beber la luz) y `spec_f3_integration` (§15, 11 para el autor).
2. **Dificultad de The Lurker:** los asomos por dificultad, `sated`, `forget`, las seis claves de sistema de `spec_f1_systems` 1.8 y los ajustes del director (0f dejó solo las ocho claves con valor en OFICINAS §4).
3. **Textos:** las cuatro líneas de The Lurker en el menú de dificultad (`TRAITS`), y una revisión de los textos del piso 2 que entraron con 1a desde la especificación (nombres de sala, departamentos, hitos, encargos de planta) y de los artículos (`ARTICLES`), que se sacaron por gramática.

## Assets del piso 2 (`source_assets/oficinas/`, fuera de git)

- `RESUMEN.md` y un `registro.json` por grupo: 98 se quedan, con su licencia auditada.
- **91 piden sesión** (44 modelos de Sketchfab, 47 sonidos de Freesound). Las descargas de Sketchfab por la extensión se cortan hacia los 10 MB (navegador Chromium; sospechas: su ajuste de descargas o Kaspersky). Freesound no se ha probado. Hacen falta en 1d.

## Pendientes menores

- `evidence/` tiene líneas base y registros sin seguimiento: se pueden borrar.
- `assets/props/comprobante.pdf` apareció sin seguimiento durante la sesión y no es de ningún paso: no se ha tocado.
- Los scripts nuevos (`objectives_test`, `palette_scan_test`, `room_light_test`, `hotel_palette`, los del piso 2) no tienen `.uid`: Godot los creará al abrir el editor; entonces se confirman.
- beads `four-7ly.2.1` y `docs/PLAN.md`: el piso en las grabaciones de bots, `presentation_rig`, el control de piso en la sala y `tools/godot.ps1 -Floor`.
