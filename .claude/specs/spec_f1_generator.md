# Phase 1, steps 1a, 1b, 1c: the office floor's kind, palette, null creature, generator, validator and metrics

Read first: docs/OFICINAS.md sections 2, 3, 8, 10, 11 (11.2, 11.3, 11.7) and 15. This spec covers:

- **1a**: `game/floors/office_floor.gd` (the kind), `game/floors/palettes/office_palette.gd` (room tables, every palette question the generator, geometry and the systems call, the ceiling lattice, the crawl spaces), `game/enemies/null_creature.gd` (+ `.tscn`), the floor index entry, and thin skeletons of the generator and validator so every preload resolves.
- **1b**: the office generator (`game/world/generation/office_generator.gd`), on top of `map_generator.gd`, plus the duct network, the tubes, the archives, the circuits, the main duct and the shaft, the furniture, the glass partitions and the corner sockets in the manifest; `conduit_metres.gd` and `office_layout.gd`.
- **1c**: `game/world/generation/office_validator.gd` (manifest checks now, physical checks written now and switched on in 1d) and `tools/dev/office_metrics.gd`.

Companion specs: `spec_f1_geometry.md` (1d) and `spec_f1_systems.md` (1e to 1i). Every manifest key and palette name they read is defined here; where this spec and theirs agreed on a name, it is used unchanged.

Nothing here changes floor 1. `manifest_golden_test` must stay byte-identical after every step, and so must `hotel_test`, `stages_test` and the net tests.

**Numbering convention.** OFICINAS counts plantas 1 to 3: 1 Personal, 2 Registro y Archivo, 3 Dirección. Code and this spec count from 0 like `wing` and `laying`: 0 Personal, 1 Registro, 2 Dirección.

---

## 0. What phase 0 gives, and what to check before starting

Assumed done exactly as in `scratchpad/oficinas_specs.md`:

- **0a**: `creature.gd` is the contract. `hotel_main.creature` is the alias (`locust` is the same body). `spawn_creature()` instantiates `kind.CREATURE`. The contract has `den_point(stage)`, `follow_to_planta(stage)`, `teleport()`, `save_state()`/`restore_state()`, `pack_state()`/`push_state()`, `validate_strike()`, `capture_style()`/`begin_capture()`/`end_capture()`, `debug_lines()`/`debug_state()`/`draw_gizmos()`, and the bots pick a threat model by `kind_id()`.
- **0b**: objectives are handlers (`game/floors/objectives/`). `hotel_floor.OBJECTIVES` maps objective ids to handler scripts. With no handlers in a stage, `met = session.can_depart()`.
- **0c**: kind scripts carry `GENERATOR`, `VALIDATOR`, `GEOMETRY`, `PALETTE`, `CREATURE`, `CREATURE_KEY`, `PAPERS` and `GENERATOR_VERSION`. `hotel_main.set_floor(n)` picks `level.kind` from `floor_index`, and `build_floor()` uses `kind.GENERATOR/GEOMETRY/VALIDATOR`, the standby floor included. `--floor=N` exists.
- **0d**: `game/floors/palettes/hotel_palette.gd` holds every room-type table and the generator's structural constants. Its questions are `hard_floor()`, `may_be_dark()`, `lamp_of()`, `height_of()`, `label()` and so on. `FLOOR.palette(manifest)` reads `manifest.get("floor", 1)`. `tests/hotel/palette_scan_test.gd` forbids loose type ints outside the palettes. Structural role ints are 0 start, 9 landing, 10 lobby, 11 corridor, 12 gallery, 19 refuge, 20 void.
- **0e**: `build_room()` is split into overridable steps, and `hotel.lit()`, `set_room_power()` and `drain()` exist.
- **0f**: `CREATURE_PROFILES[&"lurker"]` and `DIFFICULTY.profile(id, creature_key)` exist. The rules are filtered by creature.

**Check these first** (`git grep`, 10 minutes). Fix them in 1a as pure refactors, with the golden test as proof:

1. **The generator must read palette data through an instance member.** In GDScript a constant read inside a base-class method is bound to the base script. A subclass cannot shadow it, and redeclaring a parent constant is a parse error. So `map_generator.gd` must hold `var palette: GDScript = HOTEL_PALETTE`, and read every constant 0d moved through it (`palette.MODULE_SIZES`, `palette.DECKS`, `palette.TIDY_ROOMS`, `palette.WARDROBES` and the rest, plus the questions, for example `palette.may_be_dark(room)` in `light_rooms()`). If 0d used `const PALETTE := preload(...)` or `FLOOR.*` inside the generator, convert those reads to `palette.`. Do the same in `map_validator.gd`: `var palette: GDScript`, set at the top of `validate(data)` and of `validate_physics(world, data)` from `FLOOR.palette(data)`. In the validator that covers at least `fittings()` (`palette.WARDROBES`, `palette.may_be_dark()`, and the refuge test `palette.REFUGE`), `plantas()` (`palette.tv_rooms(area)`; the office returns 0) and `validate_physics()` (item 6). 0d has already done these in the hotel's validator, so 1a only checks them.
2. **Static functions are not virtual.** `map_generator.numbered(room)` is static, and `tests/hotel/hotel_test.gd:136` calls `GEN.numbered(room)`. Keep the static function as the hotel rule. Add an instance method `func numbers(room: Dictionary) -> bool: return palette.numbered(room)`, and use it in `number_rooms()` and `keep_to_hundred()`. `hotel_palette.numbered(room)` is today's body of `numbered()`.
3. **The generator must not hard-code its validator.** `generate()` calls `VALIDATOR.new().validate(result)` (line 185). Make that `validator().validate(result)`, with `func validator() -> RefCounted: return VALIDATOR.new()`.
4. **No hotel-sized array may be indexed by a type id.** Office type ids go up to 25. `grep -n "TYPES\[\|NAMES\[\|RECIPES\[" game tools tests` must show only palette-routed reads. The two examples were `hotel_geometry.gd` (a `TYPES` table read in node names, now `palette.TYPES`) and `map_generator.finish()` (`RECIPES`, now `palette.RECIPES`); 0d moved both.
5. **Off-limits rooms come from the palette.** `hotel_main.off_limits_rooms()` (line 1343) becomes `return FLOOR.palette(manifest).off_limits_rooms(manifest)`. `hotel_palette.off_limits_rooms(manifest)` keeps today's body, in today's order: exit, refuges, gate beyonds. `point_protected()` and `revival.stage_den()` already go through it.
6. **Physical checks ask the palette.** `map_validator.validate_physics()` (alcove list `[1,2,3,4,7,15,16]` at line 244, `type != 19` at line 250) and `hang_doors()` (`DOMESTIC`) must ask the palette (`palette.domestic(room)`, refuge role). Otherwise office type 4 (aseos) would be treated as a hotel bathroom with alcoves.

If any 0x name differs from what is written here (for example `PAPERS` holds a different type), follow 0x and keep the meaning.

---

### What 0d left (22 October 2026, work orders in .claude/specs/encargos_0d.json)

- The office manifest MUST carry "floor": 2. `map_generator.candidate()` returns the hotel's without the key (the golden needs it so), and `FLOOR.palette()`, the validator and every reader in play pick the palette by that key: an office generator that does not write it is validated and played with the hotel's palette. `office_test` checks `FLOOR.palette(office manifest) == OFFICE_PALETTE`.
- Code in play reaches the palette with `FLOOR.palette(level.manifest)`; static helpers without a manifest use `FLOOR.palette({})` only for structural roles (`exit_route_signs.circulation()` reads `CIRCULATION`).
- Changed signatures: `room_dressing.stretches(room, palette)` (R2's `wall_stretches` passes `palette`), `hint_placement.room_said(room, palette)`, `hotel_geometry.prop_transform(room, prop, room_palette: GDScript = null)`. Only `build_room()` passes a palette to `prop_transform()` today; in H8 the callers in game/ (document_placement, hint_placement, tv_placement) must pass `FLOOR.palette(manifest)`, or the office's toilets (type 4) get the hotel's domestic 0.85 scale.
- `numbered()`: each palette keeps its own (the hotel's: hall < 0, not corridor, not service, not in NO_NUMBER); 1.2's office definition stands.

## 1. Step 1a: the kind, the palette, the null creature

### 1.1 Files

| Action | Path |
|---|---|
| create | `game/floors/palettes/office_palette.gd` |
| create | `game/floors/office_floor.gd` |
| create | `game/enemies/null_creature.gd`, `game/enemies/null_creature.tscn` |
| create | `game/world/generation/office_generator.gd` (skeleton, see 1.6) |
| create | `game/world/generation/office_validator.gd` (skeleton, see 1.6) |
| create | `tests/office/office_test.gd` (sections "paleta", "tipo de piso", "generador mínimo") |
| change | `game/floors/floor_index.gd` (KINDS[2], RELEASED) |
| change | `game/floors/palettes/hotel_palette.gd` (`off_limits_rooms()`, `numbered()` if 0d did not already) |
| change | `game/world/generation/map_generator.gd`, `map_validator.gd` (section 0, items 1 to 3 and 6) |
| change | `game/app/hotel_main.gd` (`off_limits_rooms()` delegates) |
| change | `game/enemies/creature.gd` (document the `&"idle"` activity; see 1.5) |
| change | `game/floors/hotel_floor.gd` + `game/app/lifts.gd` (`title_of()`, see 1.3) |
| change | `tests/hotel/creature_contract_test.gd` (null creature section) |
| change | `tools/verify.ps1` (add `'office/office_test'` to `$tests`) |
| change | `docs/DEVELOPMENT.md` ("Un piso nuevo": the office kind, palette and null creature; Spanish) |

### 1.2 `office_palette.gd`

`extends RefCounted`, everything `static`/`const`, no instance state, **no preload of any geometry script** (the generator and the validator load it headless). It must define **every constant and static function that `hotel_palette.gd` defines, under the same name**. The office adds more. A parity check in `office_test` enforces this (1.7). This file is the one definition of every palette question geometry (`spec_f1_geometry.md` 0.2) and the systems (`spec_f1_systems.md` 0.2) call; 1a writes all of it.

**Room types.** Ids are indices, as in the hotel. Role ints are fixed. `TYPES` are keys, `NAMES` are what `label()` returns. `HEIGHTS[type]` is what `height_of()` returns.

| id | TYPES | NAMES | role | HEIGHTS | floor_finish | lamp_of | lockers (WARDROBES) | RECIPES (4 corners, "" = empty socket) |
|---|---|---|---|---|---|---|---|---|
| 0 | recepcion_interna | Recepción interna | start | 2.95 | terrazzo | troffer | 0 | reception, chairs, plant, coat_rack |
| 1 | oficina_abierta | Oficina abierta | (salon) | 2.95 | vinyl | troffer | 0 | desk, desk, filing, coat_rack |
| 2 | cubiculos | Cubículos | (salon) | 2.95 | vinyl | troffer | 0 | filing, desk, bin, coat_rack |
| 3 | despacho | Despacho | | 2.95 | vinyl | troffer | 0 | desk, filing, coat_rack, shelf |
| 4 | aseos | Aseos y vestuario | | 2.95 | tile | troffer | 2 | basin, basin, bench, bin |
| 5 | sala_juntas | Sala de juntas | | **3.25** | carpet on wing 2, else vinyl | pendant | 0 | sideboard, board, plant, projector |
| 6 | archivo | Archivo | | 2.95 | vinyl | batten | 0 | (none: shelving comes from `archives`) |
| 7 | reprografia | Reprografía y microfichas | | 2.95 | vinyl | troffer | 0 | copier, reader, shelf, cart |
| 8 | almacen | Almacén | | 2.95 | concrete | batten | 1 | shelf, shelf, cart, boxes |
| 9 | montacargas | Montacargas | landing | 2.95 | terrazzo | troffer | 0 | (none) |
| 10 | vestibulo_llegada | Vestíbulo de llegada | lobby | 2.95 | terrazzo | troffer | 0 | bench, bin, "", "" |
| 11 | pasillo | Pasillo | corridor | 2.95 | vinyl | troffer | 0 | (none) |
| 12 | pasillo_servicio | Pasillo de servicio | gallery | 4.4 (no false ceiling) | concrete | batten | 0 | (none) |
| 13 | archivo_movil | Archivo móvil | | 2.95 | vinyl | batten | 0 | (none: `archives`) |
| 14 | correo | Correo | | 2.95 | vinyl | troffer | 1 | sorter, sorter, cart, table |
| 15 | sala_descanso | Sala de descanso | | 2.95 | vinyl | troffer | 1 | vending, cooler, table, fridge |
| 16 | despacho_direccion | Despacho de dirección | | 2.95 | carpet on wing 2, else vinyl | troffer | 0 | desk, sideboard, coat_rack, armchair |
| 17 | ventanilla | Ventanilla de Personal | (special, wing 0) | 2.95 | vinyl | troffer | 0 | filing, shelf, chairs, bin |
| 18 | cuarto_electrico | Cuarto eléctrico | (special, wing 1) | 2.95 | concrete | emergency | 0 | cabinet, shelf, "", "" |
| 19 | vestibulo_montacargas | Vestíbulo del montacargas | refuge | 2.95 | terrazzo | troffer | 0 | bench, bin, "", "" |
| 20 | vacio | Vacío | void | 2.95 (unused) | vinyl | emergency | 0 | (none) |
| 21 | puesto_seguridad | Puesto de seguridad | (special, wing 2) | 2.95 | vinyl | troffer | 2 | gun_rack, filing, shelf, "" |
| 22 | sala_climatizacion | Sala de climatización | (wing 2 refuge slot) | 4.4 | concrete | batten | 0 | (none) |
| 23 | climatizadora | Climatizadora | (wing 2 landing slot) | 4.4 | concrete | batten | 0 | (none) |
| 24 | secretaria | Secretaría | | 2.95 | carpet on wing 2, else vinyl | troffer | 0 | desk, filing, coat_rack, plant |
| 25 | deposito | Depósito | (unnumbered overflow) | 2.95 | concrete | batten | 0 | shelf, boxes, shelf, cart |

- **Boardroom height 3.25**: the trunk duct (`duct_y - duct[1] / 2` = 3.3) must clear the tallest false ceiling by 0.05 (validator group 1). 3.4 cut it.
- **The electrical room (18)** keeps a 2.95 m false ceiling and `lamp_of == "emergency"`: no troffers, its room lamp is never powered, and its only light is its battery unit ("Foco de emergencia", OFICINAS 2). It is in no circuit and not in `always_lit()`.
- `floor_finish` values map to geometry's material keys (geometry 4.1 `FLOOR_MATERIAL`): `vinyl` to `vct`, `carpet` to `carpet_tile`, `concrete` to `concrete_floor` (types 8, 12, 18, 22, 23 and 25: materiales `concrete_slab_ceiling` / ambientCG Concrete006, CC0), `terrazzo` and `tile` unchanged.

Name the ids as constants too: `RECEPTION 0, OPEN_OFFICE 1, CUBICLES 2, OFFICE 3, TOILETS 4, BOARDROOM 5, ARCHIVE 6, COPY_ROOM 7, STORE 8, LANDING 9, LOBBY 10, CORRIDOR 11, GALLERY 12, MOBILE_ARCHIVE 13, MAIL 14, BREAK_ROOM 15, EXEC_OFFICE 16, WINDOW 17, ELECTRICAL 18, REFUGE 19, VOID 20, SECURITY 21, AIR_ROOM 22, AIR_PLANT 23, SECRETARY 24, DEPOT 25`. Office code uses these names only; the 0d scan test then stays green.

**Corner kinds.** The kinds new to `prop_factory` are `chairs, coat_rack, filing, bench, sideboard, board, projector, copier, reader, boxes, sorter, vending, cooler, fridge, armchair, cabinet, gun_rack`. Step 1d builds every one of them in `office_props.build()` (geometry 9.3), and `office_geometry_test` checks that every kind in the office `RECIPES` builds at least one node; `prop_factory.build()` builds nothing for an unknown kind, so a missing builder leaves a corner empty. `desk` and `table` keep their names on purpose: `document_placement.SURFACES` lays papers on them. Also `const WALL_KINDS := ["desk", "shelf", "filing", "sideboard", "board", "copier", "sorter", "vending", "cooler", "fridge", "cabinet", "gun_rack", "reception", "basin", "bench"]`: these turn their back to the wall (rotation 0 in slots 0 and 1, 2 in slots 2 and 3), as `map_generator.finish()` does for the hotel's list at line 1780.

**Values for the hotel-parity constants** (each name is whatever 0d used):

- `AREA`, `ROOMS`, `NUMBERED_MOST`, `rings()`, `rooms_window()`: same as the hotel.
- `tv_rooms(area)`: `0`, since the office has no television stage.
- `TV_ROOM := -1`, `EMPTY_SALON := -1`, `DOMESTIC := []`, `domestic(room)`: `false`.
- `MODULE_SIZES := [8.0, 9.0, 10.0, 10.0, 11.0, 12.0]`, `LANE_WIDTHS := [2.4, 2.6, 2.8, 3.0]` (OFICINAS 11.3).
- `DOOR_PLACES := [0.0, 0.0, 1.0, -1.0, 1.5, -1.5]`, `DOOR_PLACES_DOMESTIC := DOOR_PLACES`.
- `DECKS := [["spine", "twin", "ring", "comb"], ["comb", "blocks", "twin", "spine"], ["ring", "arms", "warren", "spine", "blocks"]]`. Personal is presentable. Registro is combs and blocks for the archives. Dirección is tidier, with suites opening onto suites (warren). The plantas are abandoned, not rotten, so there is no `rot`.
- `SERVED := {"spine": 0.5, "twin": 0.55, "ring": 0.55, "comb": 0.6, "blocks": 0.65, "arms": 0.5, "warren": 0.0}`, `APART := {}`, `ROOM_DOORS := {"warren": 1.8}`.
- `ORDER_BASE := [0.8, 0.62, 0.55]`, `KEPT`, `WEAR`: same as the hotel.
- `HALLS := Vector2i(4, 8)`. Offices have more salons: open offices, cubicles, archives.
- `EXPOSED := [0.0, 25.0, 35.0]`, `EXPOSED_CHANCE := [0.0, 0.5, 0.8]`, `SECOND_EXPOSED := 0.0`, `EXPOSED_LONGEST := 70.0`.
- `DARK_OWN := [0.23, 0.29, 0.36]`, `DARK_SPREAD := 0.45`, `DARK_CORRIDOR := Vector2(0.03, 0.05)`.
- `FIRST_DEPTH := DEPTHS[0]`, `DEPTH := DEPTHS[2]`, `FIRST_WALK := 110.0`. The office's modules are about 0.73 times the hotel's, so 150 m becomes 110 m.
- `NO_NUMBER := [0, 9, 10, 11, 12, 19, 20, 23, 25]`.
- `TIDY_ROOMS := [3, 3, 3, 4, 7, 14, 15]`, `UNRULY_ROOMS := [3, 8, 7, 15, 13]`, `SERVICE_ROOMS := [8, 8, 7, 4]`, `HALL_ROOMS := [1, 2]`. Only the 1a skeleton reads these, through the base `finish()`. 1b's own `finish()` uses the tables below.
- Hotel decor lists:
  - `SERVICE_CEILINGS := [8, 12, 18, 22, 23, 25]`
  - `SCONCE_ROOMS := []`
  - `SPRINKLER_ROOMS := [0, 1, 2, 3, 5, 7, 11, 14, 15, 16, 17, 24]`
  - `DECREPIT_WALLS := [8, 25]`
  - `ALARM_ROOMS := [0, 10, 11, 12]`
  - `FUSE_ROOMS := []`: there are no fuse boxes or panel spares on floor 2 (no key on this floor, OFICINAS 14 #13; geometry R3).
  - `FAN_ROOMS := []`
  - `CLOCK_ROOMS := []`
  - `MODULE_SET` (the `room_dressing` set per type; geometry 9.5 defines the sets): `"office_open"` for 0, 1, 2; `"office_private"` for 3, 5, 16, 17, 21, 24; `"mail"` for 14; `"copy"` for 7; `"break"` for 15; `"lockers"` for 4; `"store"` for 8 and 25; `"office_corridor"` for 11 and 12; `""` for 6, 9, 10, 13, 18, 19, 20, 22, 23 (archive rows run to the walls). 1a writes these values; `room_dressing` learns the set names in 1d, before any floor 2 is built.
  - prop `SERVICE` (metal instead of wood): every type except 5, 16 and 24.
- The "fluorescent" list or question (lamps that hum): `lamp_of(room) in ["troffer", "batten"]`.

**Office-only constants:**

```gdscript
const VERSION := 1                                   # manifest "version" of floor 2; kind.GENERATOR_VERSION
const SYSTEMS := ["mail", "power", "air"]            # what each planta is (OFICINAS 3)
const POWER := ["mains", "emergency", "none"]        # its light at the start; battery units only where != "none" (geometry 7.2)
const PLANTA_NAMES := ["PERSONAL", "REGISTRO Y ARCHIVO", "DIRECCIÓN"]
const LETTERS := ["P", "R", "D"]
const TYPE_LETTERS := {21: "S", 8: "M", 18: "M", 22: "M"}
const OFF_LIMITS := [9, 10, 19]                      # where she never goes and nobody is taken
const NEVER_DARK := [0, 9, 10, 17, 18, 19, 20, 21, 22, 23]
const CARPET := [5, 16, 24]                          # on wing 2 only
const HEIGHTS := [2.95, 2.95, 2.95, 2.95, 2.95, 3.25, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 4.4, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 4.4, 4.4, 2.95, 2.95]
const FINISHES := ["terrazzo", "tile", "carpet", "concrete", "vinyl"]
const WALLS := ["office_paint", "block", "veneer"]
const LAMPS := ["troffer", "batten", "pendant", "emergency"]
const DEPTHS := [Vector2(0.65, 0.9), Vector2(0.8, 0.97), Vector2(0.6, 0.9)]  # refuge slot per planta
const LEAST_WALKS := [110.0, 0.0, 0.0]               # times sqrt(area)
const WINDOW_DEPTH := Vector2(0.15, 0.45)
const ELECTRICAL_DEPTH := Vector2(0.4, 0.7)
const SECURITY_DEPTH := Vector2(0.25, 0.55)
## Metres over the planta's floor. duct = the trunk [width, height]; branch = the branches, bridges and
## loose links; main = the crawl duct's clear inside, square. Copied whole into manifest.plenum.
const PLENUM := {"ceiling": 2.95, "slab": 4.4, "duct_y": 3.7, "main": 1.2, "duct": [1.0, 0.8], "branch": [0.5, 0.3]}
const TUBE_Y := 2.8                                  # tube runs: between the door head (2.65) and the false ceiling
const STATION_Y := 1.25                              # a station's mouth and tray (its point); the hub's mouth too
const STATIONS := Vector2i(8, 14)
const STATION_APART := 15.0                          # walking metres between two stations, times sqrt(area)
const STATION_TUBE_MIN := 25.0                       # tube metres from the hub to any station
const MAIN_LENGTH := Vector2(25.0, 45.0)
const MAIN_IDEAL := 35.0
const MAIN_BENDS := 2
const HATCH := {"in": 1.5, "stand": 0.75}           # the hatch hangs `in` from the plant's wall; the ladder's foot is `stand` out from it
const STUB := 1.5                                    # the crossing's side stub, past the main's side wall
const MAIN_CLEAR := 1.2                              # no gap, ceiling or duct exit within main / 2 + this of the main or the stub, in plan
const SHAFT := Vector2(2.2, 2.2)                     # the shaft's landing: along the wall it opens from, out from it
const AIR_UNIT := Vector3(3.0, 2.2, 1.5)             # the air handler: width along its wall, height, depth
const REMAINS := Vector2(0.55, 0.8)                  # share of the main duct where the remains lie
const GAP_SHARE := [0.03, 0.045, 0.06]               # cells with a missing tile, per planta
const ARCHIVE := {"shelf": 2.1, "row": 0.6, "aisle": 1.0, "spine": 1.6, "end_min": 1.0, "door_depth": 1.5, "door_band": 1.0, "inset": 0.15, "wall_gap": [0.0, 0.9]}
const TIMER_COVER := 0.5                             # share of wing 1's corridor cells a timer lights
const GALLERY_SHARE := 0.15                          # corridor lines that are service corridors
const WALL_GRILLE_Y := 0.35
const WALL_APART := 1.5                              # along a wall, between a locker and a fixture or two fixtures
const SOCKET_INSET := 1.3                            # corner sockets: this far in from each wall's centre line
const FURNITURE_TOP := 2.2                           # nothing in a room is taller (OFICINAS 2)
const GLAZED_TYPES := [3, 16, 17, 24]                # rooms that may have a glass partition to a corridor
const STRIPES := [Color("8a7a3c"), Color("5f6b3a"), Color("8b5a3c"), Color("4f6470"), Color("7a6a55"), Color("a39a7a"), Color("6e3b3b"), Color("3f5a4c")]
## Departments per planta: [name, focus types]. The first is the one of the sector it is walked into from.
const DEPARTMENTS := [
	[["ALTAS", [3]], ["NÓMINAS", [3, 7]], ["EXPEDIENTES", [13, 3]], ["SELECCIÓN", [5, 3]], ["FORMACIÓN", [5, 15]], ["TRASLADOS", [3, 14]], ["BAJAS", [3, 8]]],
	[["REGISTRO", [3, 14]], ["ARCHIVO", [6, 13]], ["CORREO", [14]], ["MICROFICHAS", [7, 13]], ["REPROGRAFÍA", [7, 8]], ["ARCHIVO CENTRAL", [6]], ["CLASIFICACIÓN", [14, 6]]],
	[["SECRETARÍA GENERAL", [24, 16]], ["DIRECCIÓN", [16]], ["JUNTAS", [5]], ["GABINETE", [16, 24]], ["PROTOCOLO", [24, 5]], ["ASESORÍA", [16, 6]], ["SEGURIDAD", [3]], ["MANTENIMIENTO", [8]]],
]
const FOCUS := 3.0                                   # weight multiplier of a department's focus types
const PLANTA_MIX := [                                # module types by weight
	{3: 4.0, 7: 1.0, 15: 0.8, 4: 0.6, 5: 0.6, 14: 0.5, 13: 0.4, 8: 0.4},
	{6: 2.0, 3: 2.0, 13: 1.8, 14: 1.5, 7: 1.5, 8: 0.6, 4: 0.5, 15: 0.4},
	{16: 3.5, 24: 2.0, 5: 1.0, 4: 0.6, 6: 0.5, 15: 0.5, 8: 0.4},
]
const HALL_MIX := [{1: 3.0, 2: 3.0}, {6: 4.0, 2: 1.5, 1: 1.0}, {1: 1.5, 16: 1.5, 6: 0.5}]
const SERVICE_BY_PLANTA := [[4, 15, 8, 7], [8, 7, 4, 8], [8, 4, 15, 8]]
const MUSTS := [{15: 1, 5: 1}, {6: 2, 14: 1, 7: 1}, {5: 1, 16: 2, 24: 1}]
const BOARDROOM_SIDE := 10.0                         # a "módulo grande": both sides at least this
```

`STATION_Y`, `TUBE_Y`, `AIR_UNIT`, `HATCH.stand` and `STUB` are read by the systems' builders (`mail_geometry`, `air_geometry`, `main_duct_geometry`): they take them from here, so the generator's checks and their pieces cannot drift apart.

**Free-standing furniture** (`room.furniture`, 2.5h; geometry 9.2 builds it). Footprint `[w, d]` includes the chairs; `size[0]` of a partition is its length (1.2 to 4.8). Every height is under `FURNITURE_TOP`:

```gdscript
const FURNITURE := {
	"desk": {"size": Vector2(1.5, 1.4), "height": 1.3},          # desk 1.4 x 0.7, top 0.75, chair, desk lamp on 1 in 5
	"desk_pair": {"size": Vector2(1.5, 2.6), "height": 1.3},     # two desks face to face
	"partition": {"size": Vector2(0.0, 0.06), "height": 1.5},
	"meeting_table": {"size": Vector2(3.6, 1.2), "height": 0.9}, # chairs tucked within 0.27 of its long edges
	"pigeonholes": {"size": Vector2(1.8, 0.4), "height": 1.9},
	"copier": {"size": Vector2(1.3, 0.7), "height": 1.05},
	"vending": {"size": Vector2(0.9, 0.8), "height": 1.8},
	"card_index": {"size": Vector2(1.7, 0.5), "height": 1.2},
}
```

**Questions** (static; `room` is a manifest room dict and carries `wing`):

```gdscript
static func label(room) -> String                      # NAMES[type]
static func height_of(room) -> float                   # HEIGHTS[type]
static func false_ceiling(room) -> bool                # height_of(room) < PLENUM.slab - 0.01
static func hard_floor(room) -> bool                   # floor_finish(room) != "carpet"
static func floor_finish(room) -> String               # FINISHES, by the table
static func wall_material(room) -> String              # WALLS, rule below
static func may_be_dark(room) -> bool                  # not type in NEVER_DARK (salons MAY be dark: "zonas apagadas")
static func lamp_of(room) -> String                    # LAMPS, by the table
static func hide_kind(room) -> String                  # "locker"
static func numbered(room) -> bool                     # not corridor, type not in NO_NUMBER, hall < 0 or hall == id
static func plaque(room) -> String                     # "" if number == 0; else "%s-%d" % [TYPE_LETTERS.get(type, LETTERS[wing]), number]
static func off_limits(room) -> bool                   # type in OFF_LIMITS
static func off_limits_rooms(manifest) -> Array        # ids of non-void rooms with off_limits(), ascending
static func always_lit(manifest, wing: int) -> Array   # rule below
static func stripe_color(manifest, room) -> Color      # rule below
static func zone_label(manifest, room) -> String       # rule below
```

- `wall_material`: `"veneer"` for types 5, 16 and 24 on wing 2; `"block"` for roles 11 and 12 and types 4, 7, 8, 14, 18, 22, 23 and 25; `"office_paint"` otherwise.
- `always_lit(manifest, wing)`: the rooms that keep their lamps whatever the board or the air does, ascending ids. Wing 0 (`POWER[0] == "mains"`): every non-void room of the wing. Wings 1 and 2: the non-void rooms of the wing with `off_limits(room)` (types 9, 10 and 19: the arrival lobby, the freight lobby and the landing), plus `SECURITY` on wing 2 (the post has its own battery, OFICINAS 2). `ELECTRICAL` is never in it: it is unpowered all the time and shows only its emergency unit. The air room and the plant are not in it either (their light is "Nada").
- `stripe_color(manifest, room)`: the entry of `manifest.departments[wing]` whose `sector == room.sector`, `STRIPES[entry.colour]`; `Color("6f6a5e")` when none matches. The colour is per sector, so every zone of a planta has its own (OFICINAS 2: the stripes identify each zone).
- `zone_label(manifest, room)`: on wing 1, `"%s %s" % [code, name]` of the `manifest.power.circuits` entry whose `sector == room.sector` ("R-2 ARCHIVO", OFICINAS 3); on wings 0 and 2, the `name` of the room's sector in `departments[wing]` ("NÓMINAS"); `""` if nothing matches or the key is absent. Spaces only.

**The ceiling lattice** (one world-anchored rule for the generator, the validator and geometry; geometry 4.2 builds tiles from it). It reads only `px`, `pz`, `span_x`, `span_z`, `open_sides`, `type` and `wing`, so it must be called after the origin shift (`candidate()` line 253) and after `finish()` set `open_sides`:

```gdscript
const TILE := 0.6
const TROFFER_PITCH := 3.0
const WALL_HALF := 0.09
const GRILLE_CLEAR := 0.9          # a ceiling exit or a gap keeps this far from every troffer centre
const GRILLE_WALL := 1.0           # and, outside corridors (role 11), this far from every walled side
## World lattice: tile (i, j) covers x in [i*TILE, (i+1)*TILE], z in [j*TILE, (j+1)*TILE].
## The ceiling rectangle (world xz): the cell less WALL_HALF on every side not in open_sides.
static func ceiling_rect(room) -> Rect2
## Whole tiles inside ceiling_rect(): i from ceili(x0 / TILE) to floori(x1 / TILE) exclusive, j likewise.
static func full_tiles(room) -> Rect2i
## Troffers, [] unless lamp_of(room) == "troffer". Each {"tiles": [Vector2i, Vector2i], "along_z": bool, "centre": Vector2}.
static func troffers(room) -> Array
## Whole tiles that are no troffer tile, whose centre is at least GRILLE_CLEAR from every troffer centre and,
## for every role but corridor (11), at least GRILLE_WALL from every walled side of ceiling_rect(). Ascending (j, i).
static func free_tiles(room) -> Array[Vector2i]
static func tile_of(point: Vector3) -> Vector2i        # Vector2i(floori(point.x / TILE), floori(point.z / TILE))
static func tile_centre(tile: Vector2i, y: float) -> Vector3   # ((i + 0.5) * TILE, y, (j + 0.5) * TILE)
```

`troffers(room)`: the long axis L is the longer side of `ceiling_rect()` (x on ties); a troffer's 1.2 m side lies along L. Per axis with rect start `s` and length `len`: `n = maxi(1, roundi(len / TROFFER_PITCH))` and ideal centres `c_k = s + len * (k + 0.5) / n`. Along L the troffer takes tiles `t` and `t + 1` with `t = roundi(c_k / TILE) - 1` (its centre on a lattice line); across, tile `floori(c / TILE)`; both clamped into `full_tiles()`; duplicates dropped. `centre` is the middle of its two tiles. That gives 3 × 3 in an 8 m module, 4 × 4 in a 12 m one and one line along a 2.4 m lane. Modules of 9 and 11 m and lanes of 2.4 to 3.0 put room edges off the lattice: the edge rows and columns are cut tiles, never free tiles.

**The crawl spaces** (one definition for the validator, geometry's `crawl_space()` and 1g's `crawling_at()`, crouched-capsule test and bots' route):

```gdscript
## The clear inside of the crawlable main duct, world, unpadded: one box per "main" and "cross" edge of
## manifest.ducts, from node to node, plenum.main wide and tall, its floor at the nodes' y - main / 2
## (= py + duct_y - main / 2). Each end at an inner node (a bend, the crossing) is lengthened by main / 2
## so elbows and the stub close; the hatch end, the shaft mouth and the stub's far end are not.
## A zero-length edge gives no box.
static func crawl_boxes(manifest) -> Array[AABB]
## The shaft's standing room: air.shaft.rect from air.shaft.floor_y up to py + duct_y + main / 2.
static func shaft_box(manifest) -> AABB
```

Both cache by manifest identity (`is_same`, as `FLOOR.room_at()` does): `crawling_at()` runs every physics frame per body.

**Parity with the hotel (from 0d):** `office_palette.gd` defines every name `hotel_palette.gd` has, so office_test 1.7 holds. Besides the above, that means `area_for()`, `areas_for()` and `article(room)`, and the consts `ARTICLES`, `HARD_FLOORS` (the office answers `hard_floor()` from its finishes, but the const exists), `HALL_HEIGHT`, `CHANDELIER_HEIGHT`, `BATTEN_ROOMS`, `PUBLIC_ROOMS`, `SMEAR_ROOMS`, `CIRCULATION` (roles 0, 9, 10, 12; the office may copy it) and `SERVICE` (prop_factory's). Where the office has no use for one, it is empty or the hotel's value, with a `##` line saying so.

### 1.3 `office_floor.gd`

Same shape as `hotel_floor.gd`, with every constant and function the hotel kind has after 0b, 0c and 0f.

```gdscript
extends RefCounted
const NUMBER := 2
const NAME := "LAS OFICINAS"
const PAR := 2700.0           # 45 min; three plantas of errands. Tuned with bots (1i) and people (phase 5).
const PALETTE := preload("res://game/floors/palettes/office_palette.gd")
const GENERATOR := preload("res://game/world/generation/office_generator.gd")
const VALIDATOR := preload("res://game/world/generation/office_validator.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")   # office_geometry.gd in 1d
const CREATURE := "res://game/enemies/null_creature.tscn"              # the Lurker's scene in phase 3
const CREATURE_KEY := &"lurker"   # difficulty and rules are the Lurker's even while the null creature stands in
const OBJECTIVES := {}            # 1e adds "files", 1f "power", 1g "air" (and the shaft exit)
const PAPERS := ...               # the empty value of 0c's type: no papers until 1h
const GENERATOR_VERSION := PALETTE.VERSION
const STAGES := [
	{"objectives": [], "level": "NIVEL 1", "department": "PERSONAL", "errand": "PIDE TU FICHA",
	 "brief": "Pide tu ficha en la ventanilla de Personal, recógela en su estación y pásala por el lector del montacargas."},
	{"objectives": [], "level": "NIVEL 2", "department": "REGISTRO Y ARCHIVO", "errand": "ARRANCA EL MONTACARGAS",
	 "brief": "Da la corriente desde el cuadro, sube la palanca roja del montacargas y baja cuando acabe el reloj."},
	{"objectives": [], "level": "NIVEL 3", "department": "DIRECCIÓN", "errand": "SAL POR EL DUCTO",
	 "brief": "Enciende la climatización desde seguridad, abre la compuerta del ducto principal y llega al pozo."},
]
static func count() -> int
static func stage(number: int) -> Dictionary
static func asks(number: int, objective: String) -> bool
static func stages_asking(objective: String) -> Array
static func title_of(number: int) -> String    # "NIVEL %d"; hotel_floor gets the same returning "SECTOR %d"
```

- **Objectives stay empty in 1a.** With no handlers, 0b makes each stage end with everyone in the refuge slot. That is a usable stand-in until 1e, 1f and 1g each append their id and handler.
- **No cycle.** `office_generator.gd` must not preload `office_floor.gd`. Everything the generator needs per planta (`SYSTEMS`) is in the palette.
- **`title_of()` in lifts.** `lifts.announce_sector()` calls `level.kind.title_of(pending_brief)` instead of `"SECTOR %d" % pending_brief`. The hotel's text is unchanged.
- **If 0f added a kind identifier** to `hotel_floor.gd` (for "blackout is the hotel kind's"), add the office's: `&"office"`.

**MILESTONES.** They are written now. The floor index hides them until release (1.4). Same `{id, title, note, rule}` shape. Only rules that `run_score.meets()` knows today. No «·» or «—». Ids are unique; keys become `"2:<id>"`.

```gdscript
const MILESTONES := [
	{"id": "out", "title": "DADO DE ALTA", "note": "Salir de las oficinas.", "rule": ["won"]},
	{"id": "solo", "title": "SIN COMPAÑÍA", "note": "Salir de las oficinas sin nadie más.", "rule": ["solo"]},
	{"id": "clean", "title": "PLANTILLA COMPLETA", "note": "Salir en equipo sin que caiga nadie.", "rule": ["clean"]},
	{"id": "brave", "title": "NI UNA TAQUILLA", "note": "Salir sin que nadie se meta en una taquilla.", "rule": ["brave"]},
	{"id": "half", "title": "MEDIA JORNADA", "note": "Salir en menos de 30 minutos.", "rule": ["time_under", 1800]},
	{"id": "quick", "title": "SALIDA ANTICIPADA", "note": "Salir en menos de 20 minutos.", "rule": ["time_under", 1200]},
	{"id": "three", "title": "DEPARTAMENTO ENTERO", "note": "Salir tres o más, y todos.", "rule": ["team_out", 3]},
	{"id": "four", "title": "LOS CUATRO", "note": "Salir cuatro o más, y todos.", "rule": ["team_out", 4]},
	{"id": "again", "title": "SEGUNDA CONVOCATORIA", "note": "Salir de un piso que se derrumbó una vez.", "rule": ["restarted"]},
	{"id": "mvp", "title": "EMPLEADO DEL MES", "note": "Ser quien más aportó en un equipo que sale.", "rule": ["mvp"]},
	{"id": "first", "title": "EXPEDIENTE LIMPIO", "note": "Salir con nota A o mejor.", "rule": ["grade", "A"]},
	{"id": "master", "title": "EXPEDIENTE EJEMPLAR", "note": "Salir con nota S.", "rule": ["grade", "S"]},
]
```

Phase 5 adds the floor's own milestones (the face in your card, scares, the crossing at the red lever), the versus ones and their icons (`assets/ui/achievements/2_<id>.png`). Those need new ledger counters and are not part of 1a.

### 1.4 `floor_index.gd`

```gdscript
const KINDS := {1: preload("res://game/floors/hotel_floor.gd"), 2: preload("res://game/floors/office_floor.gd")}
## The floors anybody can see on the boards: a floor is built (KINDS) long before it is released
## (the continuation from floor 1, phase 5). Unreleased, it has no title of its own and no milestones.
const RELEASED := [1]
static func released(number: int) -> bool
static func title(number) -> String        # "PISO n: NAME" only if released, else "PISO n"
static func milestones(number) -> Array    # KINDS[n].MILESTONES only if released, else []
```

`kind()` and `built()` stay as they are, so `--floor=2`, the net and the tools can build floor 2. Records, achievements and Steam keys (`achievements_board.keys()`) stay exactly as today.

### 1.5 `null_creature.gd` and `null_creature.tscn`

The scene is a single `CharacterBody3D` root with the script. No children, no mesh, no collision shape. The script is `extends "res://game/enemies/creature.gd"`. It answers the whole contract and does nothing: it stands nowhere anybody can meet it, is never felt, heard or seen, and never captures.

```gdscript
var level                                     # set by spawn_creature
var heard: Array = []                         # [point, radius] of every hear() call, at most 64 (systems tests read it)
func _ready() -> void                         # collision_layer = 0; collision_mask = 0; set_physics_process(false); set_process(false); visible = false
func kind_id() -> StringName: return &"none"
func activity() -> StringName: return &"idle" # in none of creature.gd's lists, so every predicate is false
func mode_name() -> String: return "nula"
func can(_ability: StringName) -> bool: return false
func tune(_profile: Dictionary) -> void: pass
func hear(point: Vector3, radius: float) -> void  # appends [point, radius] to heard (drop the oldest past 64); nothing else
func travel_metres(_room_id: int) -> Dictionary: return {}     # the director's reach() is INF: no menace
static func den_room(manifest: Dictionary, stage: int) -> int  # see below
func den_point(stage: int)                    # same return type as 0a3's contract (room id or point), from den_room()
func follow_to_planta(stage: int) -> void     # teleport() to its den on that planta, reason &"lift"; no ride
func save_state() -> Dictionary: return {}
func restore_state(_data: Dictionary) -> void: pass
func pack_state() -> Array: return []
func push_state(_data: Array) -> void: pass
func play_call(_kind: String, _segment: int, _pitch: float) -> void: pass
func validate_strike(...) -> bool: return false # 0a5's signature
func capture_style(): return null
func begin_capture(_data) -> void: pass
func end_capture() -> void: pass
func capture_length() -> float: return 0.0
func hushed() -> bool: return true
func hallucinations() -> Variant: return null # the floor lies with its own doors and lockers
func debug_lines() -> Array[String]: return ["criatura nula: no hace nada"]
func draw_gizmos(_g) -> void: pass
```

- **`den_room(manifest, stage)`.** On planta `stage - 1`, the room farthest from that planta's entry by `FLOOR.route_metres(manifest, entry)`, among rooms that are not void and not in `FLOOR.palette(manifest).off_limits_rooms(manifest)`. Ties go to the lowest id. No RNG.
- **`creature.gd`.** Add `idle  does nothing at all (the null creature)` to the activity list in the comment of `activity()`.
- **Locust-only members in `spawn_creature()`.** If, after 0a, `spawn_creature()` still assigns a member the contract does not declare (today `locust.patrol_room = chosen`), add `func place_at(room_id: int) -> void: pass` to `creature.gd`. The Locust overrides it to set `patrol_room`, and `spawn_creature()` calls it. The null creature must need no dummy fields.

### 1.6 Skeletons (so preloads resolve and 1a's checks can run)

`office_generator.gd`:

```gdscript
extends "res://game/world/generation/map_generator.gd"
const OFFICE_PALETTE := preload("res://game/floors/palettes/office_palette.gd")
const OFFICE_VALIDATOR := preload("res://game/world/generation/office_validator.gd")
func _init() -> void: palette = OFFICE_PALETTE
func validator() -> RefCounted: return OFFICE_VALIDATOR.new()
```

In 1a the result also needs `"floor": 2` and `"version": OFFICE_PALETTE.VERSION`. Override `candidate()` only: call `super`, then set both keys on a non-empty result. `generate()` calls `candidate()` virtually, so it gets the keys before validating. Step 1b replaces this with `furnish()`.

`office_validator.gd`: `extends "res://game/world/generation/map_validator.gd"`, with nothing else yet.

### 1.7 Tests for 1a

**`tests/office/office_test.gd`** (`extends SceneTree`, same `check()`/evidence/`quit()` pattern as `manifest_golden_test.gd`, check titles in Spanish; writes `evidence/office_test.json`; prints `OFFICE_TEST_RESULT n/m`). Sections:

1. **Paleta.**
   - Every name in `hotel_palette.get_script_constant_map()` and every method in `hotel_palette.get_script_method_list()` exists in `office_palette`. So does every name of `const CONTRACT := ["false_ceiling", "floor_finish", "wall_material", "lamp_of", "plaque", "stripe_color", "zone_label", "hide_kind", "always_lit", "ceiling_rect", "full_tiles", "troffers", "free_tiles", "tile_of", "tile_centre", "crawl_boxes", "shaft_box", "POWER", "STRIPES", "LETTERS", "TYPE_LETTERS", "PLENUM", "FURNITURE", "FURNITURE_TOP", "TILE", "MODULE_SET", "FUSE_ROOMS", "TUBE_Y", "STATION_Y", "AIR_UNIT", "HATCH", "STUB"]` (what geometry and the systems call; copy the list into the test).
   - `TYPES`, `NAMES`, `RECIPES`, `HEIGHTS` and `MODULE_SET` have 26 entries.
   - Role ints point at the right types (`TYPES[9] == "montacargas"`, `TYPES[19] == "vestibulo_montacargas"`, `VOID == 20`).
   - Heights: 2.95 for types 3 and 18, 3.25 for 5, 4.4 for 12, 22 and 23. `false_ceiling` is false exactly for 12, 22 and 23.
   - For every type 0..25 on every wing (synthetic rooms): `floor_finish` in `FINISHES`, `wall_material` in `WALLS`, `lamp_of` in `LAMPS`, `MODULE_SET[type]` in the eight geometry set names or `""`.
   - Plenum: `duct_y - duct[1] / 2 >= max(false-ceiling HEIGHTS) + 0.05 - 0.001`; the same for `branch`; `duct_y - main / 2 >= ceiling + 0.1`; `duct_y + main / 2 <= slab - 0.05`; `TUBE_Y` between 2.65 and `ceiling - 0.1`.
   - `hard_floor`: false only for wing 2 with types 5, 16 or 24.
   - `may_be_dark`: false exactly for `NEVER_DARK`; true for a salon cell.
   - `WARDROBES` keys are exactly {4, 8, 14, 15, 21}.
   - Every `FURNITURE` height is under `FURNITURE_TOP`.
   - Plaques: wing 0, type 3, number 114 gives `"P-114"`; wing 2, type 21, number 322 gives `"S-322"`; wing 1, type 18, number 215 gives `"M-215"`; number 0 gives `""`.
   - `off_limits_rooms()` and `always_lit()` on a synthetic manifest: wing 1 gives its 9, 10 and 19 rooms and never its 18; wing 2 adds its 21.
   - `stripe_color()` and `zone_label()` on a synthetic manifest with two sectors: different colours; `"R-2 ARCHIVO"` on wing 1, the sector name on wings 0 and 2, `""` with no match.
   - Lattice, on synthetic rooms at `px` in {0.0, 0.37, 5.05} with spans 8, 9, 10, 12 and a 2.4 lane: every troffer tile is inside `full_tiles()`; a troffer's two tiles are adjacent along L; no tile is used twice; counts are 3 × 3 at 8 m, 4 × 4 at 12 m, one line on the lane; every free tile is whole, not a troffer tile, at least `GRILLE_CLEAR` from every troffer centre and, outside corridors, at least `GRILLE_WALL` from every walled side; a batten room has no troffers and free tiles.
   - Crawl boxes on a hand-written two-edge manifest (a straight run and a bend): the bend's boxes overlap by `main`, the end boxes stop at their nodes, the floor is `py + duct_y - main / 2`, and a zero-length edge gives no box.
   - No `·` (U+00B7) or `—` (U+2014) anywhere in the text of `office_palette.gd` or `office_floor.gd` (read with `FileAccess`).
2. **Tipo de piso.**
   - `floor_index.kind(2) == office_floor`, `built(2)`, `not released(2)`, `title(2) == "PISO 2"`, `milestones(2).is_empty()`.
   - `office_floor.count() == FLOOR.PLANTAS`.
   - Each stage has non-empty `errand`, `brief`, `level` and `department`; errands are 24 characters or fewer and upper case.
   - `MILESTONES` ids are unique and every `rule[0]` is in the list `run_score.meets()` handles (copy the list into the test).
   - `CREATURE` loads, instantiates and `is creature.gd`.
   - `CREATURE_KEY == &"lurker"`, `GENERATOR_VERSION == 1`, `title_of(2) == "NIVEL 2"`.
3. **Generador mínimo.** For seeds 1 to 10 at 2 survivors, `office_generator.new().generate(seed)`:
   - not a fallback;
   - `validator()` returns `[]`;
   - `floor == 2`;
   - every room type in `[0, 25]`;
   - every module span is in `office_palette.MODULE_SIZES` (catches a constant still read without `palette.`);
   - the hotel generator for the same seed gives the same JSON as before the office one ran (no leaked static state; compare `JSON.stringify`).

**`tests/hotel/creature_contract_test.gd`**, new section "La criatura nula":

- It is a `creature.gd`, `kind_id() == &"none"`, `activity() == &"idle"`.
- The six predicates are false and `alarm_level() == 0`.
- `can()` is false for `&"lifts"`, `&"tv_travel"`, `&"ducts"`, `&"wardrobes"` and `&"shriek"`.
- `travel_metres(any)` is empty, `capture_length() == 0`, `capture_style() == null`, `validate_strike(...) == false`.
- `pack_state() == []`, and `push_state([])` leaves it where it was.
- After `_ready()`, layer and mask are 0 and physics is off.
- `hushed()`, `presence_route()` is INF, `sound_route()` is inaudible, `hallucinations() == null`; `hear()` appends to `heard` and caps it at 64.
- `den_room()` on an office manifest is on the asked planta for stages 1 to 3 and never off-limits.

`manifest_golden_test`, `hotel_test`, `creature_contract_test`, `palette_scan_test` and the whole `verify.ps1` stay green.

### 1.8 Order of work and risks (1a)

**Order:**

1. The section 0 refactors (palette member, `numbers()`, `validator()`, `off_limits_rooms()` delegation, the validator's palette reads, physical checks through the palette). Run `manifest_golden_test`.
2. `office_palette.gd`: tables, questions, then the lattice and the crawl spaces.
3. `null_creature.*`, plus `place_at()` if needed.
4. `office_generator`/`office_validator` skeletons.
5. `office_floor.gd`, then `floor_index`, then `title_of()`.
6. Tests and `verify.ps1`. Then docs.

**Risks:**

- **Static binding.** Any constant still read without `palette.` silently uses hotel values on floor 2. The parity test does not catch this. The "generador mínimo" section does: rooms with hotel types (bedrooms) or 12 to 16 m modules fail.
- **Preload cycles.** `floor_index` preloads `office_floor`, which preloads the generator and validator, which preload `FLOOR`. If 0d made `FLOOR.palette()` preload `floor_index`, there is a cycle through `floor_definition.gd`. Break it by keeping the palette table in `floor_definition` (`{1: hotel_palette, 2: office_palette}`), never the kinds. The palette preloads nothing of geometry.
- **The null creature and consumers.** Its empty `save_state()`/`pack_state()` must be accepted by `floor_save` and `match_net`. Its `kind_id &"none"` must give the bots' factory a "no threat" model (null), not a crash. The 1i `bots_test --floor=2` proves it; in 1a read those two call sites and add guards if they index the arrays.
- **Building floor 2 for real.** Do not build floor 2 in a scene in 1a to 1c. The hotel geometry puts corner sockets at ±3.95 m, which do not fit 8 m modules. The office's physical test belongs to 1d.

---

## 2. Step 1b: the office generator

### 2.1 Two hooks in `map_generator.gd` (no-ops for the hotel)

1. **`place_specials`.** In `lay_planta()`, right after `if not standby: expose(f, planta, alive, arrival, refuge, rng)` (line 445) and before `var landing: int = refuge.landing`:

   ```gdscript
   if not place_specials(f, planta, alive, arrival, back, refuge, rng, standby): return {}
   ```

   Base: `func place_specials(_f, _planta, _alive, _arrival, _back, _refuge, _rng, _standby) -> bool: return true`. It draws nothing. The hook records its own reason with `fail("…")`. Placed here, the checks that follow (room window, rings, likeness, `in_depth`) judge the planta as the specials leave it.

2. **`furnish`.** In `candidate()`, after `light_rooms(f, wear)` (line 272):

   ```gdscript
   var extra := furnish(f, gates, doors, run_seed, attempt, standby)
   if extra.has("fail"): return fail(String(extra.fail))
   ```

   `doors` is the local that `hang_doors()` returned. `furnish` may change its specs, for the security lock. Then build the return literal into `var result := {…}`, then `if not extra.is_empty(): result.merge(extra, true)`, then `return result`. Base: `func furnish(_f, _gates, _doors, _seed, _attempt, _standby) -> Dictionary: return {}`. `furnish` runs after the origin shift (lines 253 to 256), so every position it writes is world.

The hotel manifest gets no new key, its key order does not change, and its RNG streams are untouched. `manifest_golden_test` proves it.

### 2.2 `office_generator.gd`: overrides

```gdscript
extends "res://game/world/generation/map_generator.gd"
const OFFICE_PALETTE := preload("res://game/floors/palettes/office_palette.gd")
const OFFICE_VALIDATOR := preload("res://game/world/generation/office_validator.gd")
const METRES := preload("res://game/world/generation/conduit_metres.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
## Generator-only tuning (not read by anything else).
const LOOSE_P := 0.3          # loose duct links between rooms (OFICINAS 11.3)
const CORRIDOR_EXIT_P := 0.5  # grilles on corridor cells
const WALL_EXIT_P := 0.15     # low wall grilles instead of ceiling ones
const TIMER_P := 0.65
const MAIN_TRIES := 64        # candidate paths ranked for the main duct
const GLAZED_P := 0.55        # each eligible wall of a despacho, exec office or secretaría
const READER_ALONG := 1.1     # a reader, from its door's centre along the wall (code_lock.gd:120's keypad)
const READER_Y := 1.2
const STOP_Y := 1.3
const CAMERA_DROP := 0.15     # the ceiling camera under the ceiling
const STAND_OUT := 0.6        # the typist's feet, out from the desk's point
const TABLE_OFFSET := 2.2     # the meeting table's centre from the boardroom's centre
const DESKS_MOST := 8         # free-standing items per cell
func _init() -> void: palette = OFFICE_PALETTE
func validator() -> RefCounted: return OFFICE_VALIDATOR.new()
func depth_wanted() -> Vector2: return OFFICE_PALETTE.DEPTHS[laying]
func least_walk() -> float: return OFFICE_PALETTE.LEAST_WALKS[laying] * sqrt(drawing)
func place_specials(f, planta, alive, arrival, back, refuge, rng, standby) -> bool
func finish(f, start, refuges, entries, decoration) -> void
func furnish(f, gates, doors, run_seed, attempt, standby) -> Dictionary
```

Everything else is the hotel engine as it is. That covers the grid (`lay_grid`/`pin`, so each freight car goes straight down to the arrival lobby), corridors, `join`, `make_halls`, `trim`, `loops`, `expose`, and `place_refuge`/`try_refuge`/`island`. The refuge slot is chosen exactly like the hotel refuge: hidden from the hand-on-the-wall walk, in its depth band, never in the bearing of another planta's. Also unchanged: `zones()`, `number_rooms()` (through `numbers()`), `hang_doors()`, `place_hides()` (lockers by `WARDROBES`) and `light_rooms()` (`DARK_OWN`, `may_be_dark`).

**What fills the refuge slot (`place_refuge`) on each planta:**

| planta | refuge (19 role) | landing (9 role) | depth (`DEPTHS`) | least walk |
|---|---|---|---|---|
| 0 Personal | freight lobby (19), with the card reader beside the stage gate door (`mail.reader`, 2.5c) | Montacargas (9), car behind the lift wall | 0.65 to 0.9 | 110 × sqrt(area) |
| 1 Registro | freight lobby (19), "al otro extremo" | Montacargas (9) | 0.8 to 0.97 | 0 |
| 2 Dirección | **Sala de climatización (22)**, not a refuge type | **Climatizadora (23)**, `landing` flag kept, merged with 22 | 0.6 to 0.9 | 0 |

Every RNG here is either `rng` (that planta's own, inside retries) or a named stream. **No trig in stored values.** Yaws are the literals `0.0`, `PI / 2`, `PI`, `-PI / 2`, and positions use only `+ - * /`, `floori`/`roundi`. The manifest is hashed on every machine (`match_net.manifest_hash`).

### 2.3 `place_specials()` per planta

All picks are among local cells of the planta in use. The result goes to `f.specials[planta]` in global ids (`base + local`), overwritten on every retry. Create `f["specials"] = [{}, {}, {}]` the first time. Shares are `route_metres(f, alive, arrival)[cell] / max(route_metres)`, the same measure as `in_depth()`. Positions here are before the origin shift: only lengths (differences) are used.

**Planta 0 (mail): the personnel window.**

- **Candidates:** module cells that are alive, `hall < 0`, not `service`, not `arrival`/`refuge.room`/`refuge.landing`, with at least one door to a corridor cell, and share within `WINDOW_DEPTH`.
- **Weight:** 2.0 if it has one or two doors, else 1.0.
- **Pick:** `weighted()`. In `standby`, take the candidate nearest the middle of the band, or the nearest share overall if the band is empty.
- **None:** `fail("window")` and return false.
- **Store:** `{window}`.

**Planta 1 (power): the electrical room.**

- **Candidates:** same filters, share within `ELECTRICAL_DEPTH`.
- **Weight:** ×3 with exactly one door ("el más expuesto"), ×1.5 if `service`.
- **None:** `fail("electrical")`.
- **Store:** `{electrical}`.

**Planta 2 (air): the air room, the security office, the main duct and its shaft.**

1. **Merge the air room with its plant.** `merge(f, base + refuge.room, base + refuge.landing)`. They were already linked by `try_refuge()`'s "lock's door" (line 1597). Now there is no wall: one salon of two modules with a single outside door (`refuge_doors` still holds; `hang_doors()` skips the merged pair, and the base `fittings()` skips merged pairs before its `gate_door` check, line 71).

2. **Security office.**
   - **Candidates:** module, `hall < 0`, not `service`, not arrival/refuge/landing, not grid-adjacent to `refuge.room` or `refuge.landing`, share within `SECURITY_DEPTH`.
   - **Weight:** ×4 if it already has exactly one door.
   - **Try up to 8 in weighted order.**
     - Save with `save(f)`.
     - If it has more than one door, keep one: the one to a corridor if any, else the first by id. Unlink the rest, then `join(f, alive, arrival, back, rng, [cell])`. Rooms cut off get doors elsewhere, never to it.
     - Accept only if all of these hold, else `restore()` and try the next:
       - `reach(f, arrival, alive).size() == alive.size()`;
       - `cycles(f, alive) >= palette.rings(drawing)`;
       - `in_depth(f, rooms_only, arrival, refuge.room)`, with `rooms_only` being alive minus the landing;
       - `WALKER.score(f.rooms, f.adjacency, base + arrival, base + refuge.room, population).hits == 0`;
       - the security share is still in band.
   - **None:** `fail("security")`.

3. **Main duct path** (cells only; nodes come in `furnish`).
   - **Search:** depth-first from `refuge.landing` (the plant cell) over grid neighbours (`step()`, the 4 `WAYS`). Allowed: alive cells, never `arrival` (the arrival lobby is off-limits), no revisits, at most 6 cells after the plant.
   - **A path ends** at its last cell `L` with a side `e` (not the side it was entered from) whose neighbour `V = step(L, e)` is `-1` (off the grid) or not alive (a cut-out cell, void later) and holds the shaft:
     - off the grid: always (nothing of planta 2 is built there, and the plantas above start at `py + 5.7`, see the shaft's head in 4);
     - a cut-out cell: its span along `e` is at least `SHAFT.y + 2 * WALL_HALF + 0.05`. Its span across is `L`'s (same row or column).
     - Either way `L`'s span across `e` is at least `SHAFT.x + 2 * WALL_HALF + 0.05` (2.43 m: every lane qualifies).
   - **Length** = `|hatch → first cell centre| + Σ centre-to-centre + |last centre → mouth|`. The hatch is the plant cell centre moved toward the first step by `span / 2 - HATCH.in`; the mouth is `L`'s centre moved along `e` by `span_e / 2 + WALL_HALF` (the outer face of `L`'s wall, where the duct opens onto the shaft's landing).
   - **Bends** = direction changes between consecutive steps, counting the final step out to the shaft.
   - **Keep paths** with length in `MAIN_LENGTH` and bends ≥ `MAIN_BENDS`. In standby: 15 to 70 m and 1 bend.
   - **Rank** by `-abs(length - MAIN_IDEAL) + rng.randf() * 4.0`, stop after `MAIN_TRIES` candidates, take the best.
   - **None:** `fail("main_duct")`.
   - **Store** `{air_room, air_plant, security, main_cells: [ids…], main_exit: [dx, dz], main_length}`. `main_cells` starts with the plant.

### 2.4 `finish()` override (types, heights, props)

Same responsibilities as the hotel's (`map_generator.finish`, lines 1717 to 1791), with its own tables. Order matters for determinism. Iterate rooms by ascending id and draw only from `decoration`.

1. **Zones first:** `zones(f, entries)`. It reads only adjacency and `type != VOID` (lines 1825 to 1850), so sectors exist before typing. It makes 5 to 7 sectors per planta; `DEPARTMENTS` has at least 7 names per planta.

2. **Corridor lines.** Per planta and lane line, `decoration.randf() < GALLERY_SHARE` makes the whole line `GALLERY` (12), else `CORRIDOR` (11). Same keys as the hotel (`"%d%s%d"`).

3. **Departments.** Per planta:
   - The sector of `entries[planta]` (reception on planta 0) gets `DEPARTMENTS[planta][0]`.
   - The others take the rest of that list, shuffled with `decoration`, no repeats.
   - Colours: `STRIPES` indices shuffled with `decoration`, one per sector.
   - Planta 2: the security office's sector is renamed `"SEGURIDAD"`, and the air room's sector `"MANTENIMIENTO"` unless it is the same sector.
   - Keep in `f.departments[planta] = [{sector, name, colour, focus}]`; `colour` is the `STRIPES` index (an int, so the manifest stays JSON).

4. **Specials and structure:**
   - `start` gets `RECEPTION`; `entries[1..2]` get `LOBBY`; cells with `landing` on plantas 0 and 1 get `LANDING`.
   - `refuges[0..1]` get `REFUGE`; `refuges[2]` gets `AIR_ROOM`, with `hall = -1` and `service = false` on all refuges.
   - Planta 2's landing gets `AIR_PLANT`, keeping `landing = true`.
   - `f.specials` give `WINDOW`, `ELECTRICAL` and `SECURITY`.

5. **Salons.** For each hall (members sharing `hall`), draw a type from `HALL_MIX[planta]`, with the members' sector department focus types ×`FOCUS`. Drop `ARCHIVE` from the draw if the hall is not a straight line (an L). All members take it.

6. **Other modules.**
   - `service` cells: a type from `SERVICE_BY_PLANTA[planta]`.
   - Other cells: a type from `PLANTA_MIX[planta]`, focus types ×`FOCUS`. A drawn `BOARDROOM` on a cell whose sides are under `BOARDROOM_SIDE` becomes `OFFICE`. On planta 2 a drawn `BOARDROOM` never lands on a `main_cells` cell (its 3.25 m ceiling is over the crawl duct's 3.1 m floor); redraw `OFFICE`.

7. **Musts** (`MUSTS[planta]`).
   - Convert plain module cells, not special, not structural, not service, `hall < 0`, lowest `order` first (ties by id). Archive musts may also take a straight salon. A must of type `BOARDROOM` follows the same side and main-cell rules as a drawn one.
   - Planta 1 must end with at least one archive salon if any straight salon exists there.
   - Then, in every sector with five or more non-corridor rooms and no `TOILETS`, convert one plain module that has a door to a corridor into `TOILETS`. This gives the lockers: at least two per sector.
   - `MOBILE_ARCHIVE` is only kept on a module whose doors all lie on two opposite walls. Otherwise it becomes `ARCHIVE`, since its compact rows need rails clear of doors.

8. **Per room, as the hotel does:**
   - `props = []`, `cover_slots = 0`, `variant = 0`, `layout = 0`, `height = palette.height_of(room)`.
   - Non-void rooms: `variant = decoration.randi_range(0, 3)`.
   - Corridors: done.
   - Others: `cover_slots = 4`. Recipe from `RECIPES[type]`, shuffled with `decoration`. Slots get the kinds in order, with `""` skipped (no prop entry). Rotation: `WALL_KINDS` give 0 in slots 0 and 1, 2 in slots 2 and 3; others `decoration.randi_range(0, 3)`.

9. **`open_sides`** from `f.merged`, the same loop as the hotel's.

10. **`cap_numbers(f, decoration)`.** The office version of `keep_to_hundred()`. For each planta, if more than `NUMBERED_MOST` rooms satisfy `numbers()`, the excess becomes `DEPOT` (25), with `service = true`. Pick by lowest `order`, minus 0.3 next to a service cell, ties by id. `DEPOT` is in `NO_NUMBER`.

Afterwards the base runs `number_rooms()`, `hang_doors()`, `place_hides()` and `light_rooms()` on these types, then `furnish()`.

### 2.5 `furnish()`: everything that needs doors and lockers

**Streams.** Each system has its own: `func stream(run_seed, attempt, name) -> RandomNumberGenerator` with seed `hash([run_seed, "office", name, attempt])`. The names are `"lobby"`, `"archives"`, `"tubes"`, `"power"`, `"air"`, `"glazed"`, `"furniture"` and `"ducts"`.

**Positions.** World (`px`, `pz` after the origin shift; `py + local y`), `[x, y, z]` arrays rounded to 0.001. Furniture and sockets are room-local `[x, z]` from the cell centre, as `hides` are.

**Wall spots.** A wall spot is `{wall, along, point, yaw}`: `wall` in `"west" | "east" | "north" | "south"`, `along` as `FLOOR.doorways()` gives it (z on west and east walls, x on north and south ones), `point` on the wall's inner face (`WALL_HALF` in from the cell edge) at the spot's height, `yaw` facing into the room: `Basis(Vector3.UP, yaw).z` points away from the wall (west wall `PI / 2`, east `-PI / 2`, north `0.0`, south `PI`; the `FLOOR.hiding_yaw()` convention). A body turned to `yaw` faces the wall.

**The wall registry.** `taken[room id] = [{wall, along, half}]`, seeded from `room.hides` (half 0.65) and filled by every wall spot placed below in the order of 2.5l. A spot is free when it is on a closed wall (not in `open_sides`), at least `HIDE_CLEAR` from every doorway centre on that wall (the locker rule, `place_hides()` line 1936), inside the wall (`|along| <= wall length / 2 - 0.4 - half`), and at least `WALL_APART` from the `along` of every registry entry on the same wall. Candidates are `HIDE_SPOTS` (-1.8, 0, 1.8) unless a rule below says otherwise.

**a) Lobby.** On the reception (`start`), pick a closed wall with no doorway. Prefer the one opposite `facing(f, start)`'s door. Store `"arrival_lift": [dx, dz]`: where 1d draws the hotel lift doors and phase 5 the continuation. If no wall qualifies, omit the key. Register its middle 3 m (half 1.5).

**b) Archives** (`"archives"`). Each archive unit is a straight hall of `ARCHIVE` cells, or a single `ARCHIVE` or `MOBILE_ARCHIVE` module.

- **Long axis A.** The hall's line; for a module, its longer side (x on ties; for mobile, the axis whose two end walls hold all the doors).
- **Inner rectangle.** The union footprint shrunk by `inset`.
- **Spine.** An aisle of width `spine` along A through the cells' centre line, so every cell centre is clear.
- **Rows.** Each side of the spine holds rows of depth `row` perpendicular to A, from the spine edge to the long wall minus `wall_gap` (0.0 or 0.9, one draw per unit). `wall_gap` 0 gives dead-end aisles. Pitch is `row + aisle`. End aisles at both short walls are at least `end_min`. The remainder of the length is split equally between the two end aisles.
- **Doors.** For every doorway of the unit's cells on a long wall, remove the rows whose A-interval meets `along ± door_band`. That leaves a cross aisle at least 2 m wide from the spine to the door. For a doorway on a short wall, its end aisle becomes at least `door_depth`; recompute the rows.
- **Mobile.** Rows on each side are packed with no aisles except one gap of `aisle`, whose index is drawn (`open: [left, right]`).
- **Store:** `{rooms: [ids], axis: "x"|"z", mobile: bool, open: [l, r] or [], height: shelf, wall_gap, spine: [x0, z0, x1, z1], rows: [[x0, z0, x1, z1], …], aisles: [[x0, z0, x1, z1], …]}`. Every rectangle is world, ordered min-max. `aisles` holds the narrow aisles between two rows (or a row and a wall): the Lurker's channels (OFICINAS 11.4). Geometry builds the shelving from `rows` and the battens over `aisles` (geometry 9.4); archives never carry `room.furniture`.

**c) Planta 0, mail** (`"mail"`, `"tubes"`).

- **Window fixtures.** On the window room's closed wall farthest from its doors that holds no doorway (none: `{"fail": "window_desk"}`):
  - `desk`: wall spot at `along` 0, `point` 0.55 m in from the inner face (the desk's centre on the floor), `y = py`; registered with half 0.9.
  - `stand`: `{point: desk.point + facing(desk.yaw) * STAND_OUT at y = py, yaw: desk.yaw}`: the typist's feet, facing the desk with the back to the room.
  - `camera`: `[x, py + height - CAMERA_DROP, z]` at the ceiling corner of the opposite wall, 0.3 m from both walls, on the side farther from the room's main door (behind the typist).
  - `camera_target`: `stand.point + (0, 1.3, 0)`.
  - `map`: wall spot on the desk wall at `along = ±1.2`, the side clear of doorways; `y = py + 1.5`.
  - `hub`: the sending mouth beside the desk at `along = ∓0.9`; `y = py + STATION_Y`.
- **The reader** (`mail.reader`). The keypad's place in the hotel (`code_lock.gd` lines 109 to 122): on the freight lobby's (`gates[0].room`, type 19) wall shared with the landing (`gates[0].beyond`), on the lobby side, `READER_ALONG` along the wall from the stage gate door's centre (`FLOOR.portal_between()`; that door is in the middle, `hang_doors()` line 1894) toward `Vector3(away.z, 0, -away.x)` with `away` the unit step from the lobby to the landing; if that side is within 0.4 m of the wall's end or of a hide, the other side. `y = py + READER_Y`, `yaw` facing into the lobby. Wall spot, registered. The stage gate door stays locked until the quota is swiped, so the reader must be on this side; nothing goes on the car's side.
- **Stations.**
  - **Count:** `clampi(roundi(11.0 * sqrt(area)) + rng.randi_range(-1, 1), STATIONS.x, STATIONS.y)`, using `f.areas[0]`.
  - **Eligible:** planta 0 cells that are not corridor, not off-limits, not the window, not the reception, not an archive; one station per room.
  - **Spot:** a free wall spot, preferring the wall opposite the room's doors (collecting puts your back to the door); `y = py + STATION_Y`.
  - **Pick** round-robin over sectors (sector order shuffled). In each sector take the room maximising the minimum walking metres to the hub room and to the stations already placed. Walking metres use `METRES.walk_within(f.rooms, f.adjacency, …)`. Add `rng.randf() * 4` as jitter. Require tube length to the hub ≥ `STATION_TUBE_MIN` and walking distance between stations ≥ `STATION_APART * sqrt(area)`.
  - **Short of the count:** relax the spacing ×0.8 once. Still under `STATIONS.x`: `{"fail": "stations"}`.
  - **Numbers:** 1..N assigned from a shuffled list (the number says nothing of where).
- **Tube network.** Same shape as `ducts` (11.7: one conduit graph).
  - Dijkstra parent tree over planta 0's door graph from the window room (centre-to-centre metres, ties by lower id). It never passes through off-limits rooms; they are dead ends.
  - Per station, the room chain from the hub to it. Polyline:
    - hub mouth;
    - up to `TUBE_Y`;
    - in each room, an orthogonal run from its entry doorway to its exit doorway. It leaves each wall perpendicular to it, 0.3 m in, with at most two corners, and goes through the room's middle line when the two walls are opposite;
    - through each doorway at `FLOOR.portal_between(a, b)` with `y = py + TUBE_Y` (over the door head);
    - in the station's room, to above the station, then straight down to the mouth.
  - Nodes are deduplicated by position rounded to 1 mm, which gives a tree. Edges are `[a, b, metres, "tube"]`.
  - `rooms`: one room id per node: the room whose run made it; a doorway node takes the room on the hub side; a mouth its own room.
  - Exits: `{"node", "room", "kind": "hub"|"station", "number" (stations), "point", "yaw", "tube" (metres from the hub)}`.
  - The runs are built by 1e with no collider (systems 2.6), so they never meet the validator's ceiling band.
- **Store:**
  - `"mail": {"window": id, "desk": spot, "stand": {point, yaw}, "camera": [x, y, z], "camera_target": [x, y, z], "map": spot, "reader": spot + {room}, "stations": N}`;
  - `"tubes": {"nodes": [[x, y, z], …], "rooms": [id, …], "edges": [[a, b, m, "tube"], …], "exits": [...], "hub": exit index}`.

**d) Planta 1, power** (`"power"`).

- **Board.** On the electrical room's closed wall farthest from its door, `along` 0, `y = py`, wall spot; registered with half 0.9.
- **Circuits.** One per sector of planta 1. Members: every non-void room of the sector except off-limits rooms and the electrical room, corridors included. Lever order is the sector list shuffled. `code = "R-%d" % (lever + 1)`; `name` is the sector's department; `colour` its `STRIPES` index.
- **The red lever** is `lift_lever = circuits.size()`.
- **Timers.**
  - Stretches: runs of planta 1 corridor `lane` cells along one lane line, split at `cross` cells. Each run gets the cross cells it opens onto.
  - Each stretch gets a timer with `TIMER_P`. Then add timers to the longest uncovered stretches until covered corridor cells ≥ `TIMER_COVER`.
  - Button: a wall spot on a side (long) wall of the stretch's end lane cell, at least 1.0 m along from every doorway edge on that wall (`|along - door along| >= PORTAL / 2 + 1.0`); `y = py + 1.2`; registered.
  - Timers carry no time: every minutero lasts `tuning().timer_switch` (systems 3).
- **Store:** `{"room": id, "board": spot, "circuits": [{code, name, sector, colour, lever, rooms: [ids]}], "lift_lever": n, "timers": [{rooms: [ids], sector, room, wall, along, point, yaw}]}`.

**e) Planta 2, air fixtures** (`"air"`; the duct's nodes come in j).

- **Security.**
  - `door`: the key `"a:b"` of its single door; `outside`: the room on its other side. Set `doors[key].open = false` and `doors[key]["lock"] = "card"`.
  - `desk` (the post's console): a wall spot on a closed wall of the security office with no locker within 1.5 m of `along` 0, else at a free `HIDE_SPOT`; `y = py`; registered with half 0.9. If no wall qualifies: `{"fail": "security_desk"}`.
  - `reader`: a wall spot in `outside`, on its wall shared with the security office, `READER_ALONG` along from the door's centre on its latch side (`-spec.hinge`, so the leaf never sweeps it), else the other side; `y = py + READER_Y`; registered in `outside`.
- **Air room and plant.** `room`, `plant`.
- **Hatch.** `point = [plant.px + d1.x * (span_x / 2 - HATCH.in), py + duct_y, plant.pz + d1.y * (span_z / 2 - HATCH.in)]` with `d1` the first step's direction; `yaw` faces out of the duct into the plant (the yaw of `-d1`). The duct's end hangs in the air, 3.1 to 4.3 m up, 1.5 m from the plant's wall. Its foot (1g's `foot()`) is the hatch's floor point plus `facing(yaw) * HATCH.stand`.
- **Unit** (`air.unit`, the air handler): a wall spot of the plant, `y = py`, its box `AIR_UNIT` (width along the wall, back against the inner face). Walls in order: the one opposite `d1`, then the two side walls (west/east or north/south order), never the open side to the air room; `along` in `[0, -1.5, 1.5]`. Accept the first whose box lies inside the plant's inner rectangle, keeps out of the 1.5 m square round the hatch's floor point (geometry 6.8) and of the duct's plan strip (from the hatch to the plant's wall, half width `main / 2 + 0.3`), and is at least 1.0 m from the foot. None: `{"fail": "unit"}`. Registered with half `AIR_UNIT.x / 2`.
- **Stop** (`air.stop`, the isolator): a wall spot on the unit's wall at `along = unit.along ± (AIR_UNIT.x / 2 + 0.5)`, `+` first, the first free one; `y = py + STOP_Y`. Within 1.5 m of the unit's side by construction.
- **Shaft** (`air.shaft`), from the last main cell `L` and its side `e` (`main_exit`):
  - `side: [dx, dz]` = `e`;
  - `point`: the mouth, `L`'s centre plus `e * (span_e / 2 + WALL_HALF)`, at `py + duct_y`;
  - `rect: [cx, cz, sx, sz]`: centre at the mouth plus `e * SHAFT.y / 2`, `SHAFT.x` across `e` and `SHAFT.y` along it (its near edge on the outer face of `L`'s wall);
  - `floor_y = py + duct_y - main / 2`: the landing is level with the duct's floor;
  - `ladder: {point, yaw}`: the manhole's centre, `rect` centre plus `e * (SHAFT.y / 2 - 0.45)` at `floor_y`, `yaw` facing back toward the mouth (a body turned to it faces the far wall and climbs down);
  - `node`: set in j.
- **Gate.** `gates[2]["kind"] = "shaft"`, and `f.rooms[int(gates[2].beyond)].erase("lift")`: no car there. The hotel's gates have no `kind`, which means `"lift"`.

**f) Sockets, and corner props that give way.**

- **`room.sockets`** for every non-void, non-corridor room: four room-local `[x, z]` in `prop_transform()`'s slot order (slot 0 at -x -z, 1 at +x -z, 2 at -x +z, 3 at +x +z), each at `±(span / 2 - SOCKET_INSET)` per axis; in a room with `lift`, the two sockets on the lift side are pulled in front of the lift wall by `prop_transform()`'s rule (`most = span · |lift| / 2 - FLOOR.LIFT_DEPTH - 0.9`, hotel_geometry.gd:1860). Geometry's H8 reads them instead of the hotel's ±3.95.
- **Props give way.** A corner piece occupies 2.3 × 1.4 round its socket, the 2.3 side along x when its `rotation` is even (geometry 9.3). Drop a prop from `room.props` (its slot stays empty) when that footprint meets a locker (1.3 × 0.7 at the hide, along its wall), the 1.2 × 1.2 clear rect in front of a registered wall spot, the hatch's floor square or the unit's box. The base validator needs `cover_slots == 4` and unique slots, not four props.

**g) Glass partitions** (`room.glazed`, stream `"glazed"`).

- **Eligible wall:** a side of a room of `GLAZED_TYPES` that is not an open side, whose neighbour across it (`FLOOR.beside()`) is a corridor or a gallery (roles 11 and 12, not void, not merged with it), is no lift wall of either room (`FLOOR.lift_wall()`), is no gate pair (`gates[i].room`/`beyond`), and holds no locker and no registered wall spot on either side.
- **The window room (17)** is always glazed on the eligible wall holding its door to a corridor (the lowest neighbour id if several): 1e's counter and its glass stand there (systems 2.6). If that wall is not eligible: `{"fail": "window_glass"}`.
- **Others** (3, 16, 24): each eligible wall with `GLAZED_P`, rooms by ascending id, walls in the order west, east, north, south.
- **Symmetric.** Write the side in the room's `glazed` and the opposite side in the neighbour's. Rooms with none get `glazed = []`.
- Wall exits (i) never go on a glazed wall.

**h) Free-standing furniture** (`room.furniture`, stream `"furniture"`).

Item: `{"kind", "at": [x, z] (room-local, from the cell centre), "turn": 0..3, "size": [w, d], "extra": {"height": h, "group": g}}`. `size` is `FURNITURE[kind].size` (a partition's `size[0]` is its length), `extra.height` is `FURNITURE[kind].height`, `group` ties the pieces of one cubicle (else the item's own index). The piece's back is local -Z; `turn` rotates it by quarter turns, so an odd turn swaps the footprint. Halls are furnished cell by cell. Rooms not listed below get `furniture = []`.

Every item must fit, as `office_layout.gd` (2.7) tests it: its footprint inside the room's inner rectangle, clear of every clear zone of `LAYOUT.clear_zones(room, fixtures, exempt)`, and at least `LAYOUT.ITEM_GAP` from items of other groups. Candidates are tried in the order given; each that fits is kept, up to `DESKS_MOST` items per cell.

| type | items | candidates |
|---|---|---|
| OPEN_OFFICE (1) | `desk_pair` | one `turn` per hall (0 when the hall runs along x, else 1); a lattice of centres from the inner rectangle's corner with pitch footprint + `ITEM_GAP`, rows then columns |
| CUBICLES (2) | pods: `desk` at the pod's origin; `partition` 1.8 long behind it (`(0, -0.73)`, same turn); `partition` 1.46 long at its side (`(±0.93, 0)`, turn + 1, the side alternating by lattice column) | the same lattice with a pod footprint of 1.92 × 1.49; a pod is kept whole or not at all |
| BOARDROOM (5) | one `meeting_table` | at `(0, ±TABLE_OFFSET)` turn 0, then `(±TABLE_OFFSET, 0)` turn 1, the axis across the room's longer span first, `+` before `-`; its clearance footprint is the table grown by 1.55 on the long sides (1c's two sweeps at ±1.2 with their capsule) and 0.6 on the ends |
| COPY_ROOM (7) | one `copier` | against a closed wall: each wall in order, `along` in `[0, -2.0, 2.0]`, back 0.05 off the inner face, turned to face into the room |
| MAIL (14) | up to two `pigeonholes` | as the copier |
| SECRETARY (24) | one `card_index` | as the copier |

`vending` is in `FURNITURE` for geometry's corner builder and later use; the generator places none in phase 1. In abandoned rooms the furniture is still there; geometry knocks chairs over by `vary()`.

**i) Ducts** (`"plenum"`, `"ducts"`; stream `"ducts"`). One graph for the three plantas; node indices are global and every node carries its room (and so its wing). **The ducts are a graph, not geometry.** Edges may overlap in plan; only the main duct and its stub are built as crawlable geometry (1g); the rest is seen through gaps, grilles and exposed ceilings (geometry 5.4, 5.5).

1. **Cells `C`** per planta: non-void rooms not in `OFF_LIMITS`. One node per cell at `(px, py + duct_y, pz)`, kind `"trunk"` for corridors and `"branch"` for the rest.
2. **Trunks.** An edge `"trunk"` for every door edge between two corridor cells of `C`.
3. **Branch tree.**
   - Visit the rest of `C` by breadth-first hops from corridor cells over door edges, ascending id within a level.
   - Each cell's parent is a door-adjacent cell of `C` already connected. Prefer a corridor, then fewer hops, then lower id.
   - Edge `"branch"`, length = centre distance.
   - Every such edge joins door-adjacent cells, so its duct metres equal its walking metres.
4. **Bridges.** If `C` is still in several pieces (an arrival lobby can be a cut vertex), join pieces with grid-adjacent pairs of `C` that have no door between them, in order of highest `L / walk(a, b)`, and only if that ratio is ≥ `SHORTCUT_MIN` (0.55). Edge kind `"bridge"`. If impossible: `{"fail": "duct_bridge"}`.
5. **Loose links.**
   - Candidates: grid-adjacent pairs of `C` with no door edge and no duct edge yet, shuffled.
   - Each is taken with `LOOSE_P`, and only if `L / walk(a, b) ≥ SHORTCUT_MIN`.
   - `walk` is `METRES.walk_within(f.rooms, f.adjacency, a, L / SHORTCUT_MIN)` over the full door graph (survivors walk through lobbies too). Unreached means rejected.
   - Edge kind `"loose"`.
   - **Why the band then holds everywhere.** Every duct path is door-equivalent segments plus loose or bridge links. For `L ≤ W`, `(A + L) / (A + W) ≥ L / W`, so any path's ratio to the shortest walk is ≥ the smallest link ratio ≥ 0.55. No teleports. The loose links are where the 0.55 to 0.9 shortcuts come from.
6. **The crossing and its stub** (planta 2; "con codos y un cruce").
   - **Candidates:** the main cells after the plant (every centre node strictly inside the chain) whose network node has a network edge (trunk, branch, bridge or loose) to the node of a grid-adjacent cell of `C` that is not a main cell, in a direction perpendicular to the main there: at a straight node, either side; at a bend, a direction the main does not use.
   - **Pick:** the candidate whose along-share of the main length is closest to `0.5 + rng.randf_range(-0.2, 0.2)`, ties by lower id. Its direction `stub`: a trunk edge first, then the lower neighbour id. None: `{"fail": "main_cross"}`.
   - **Split** that network edge `c–n` at the stub's far end `s = c + stub * (main / 2 + STUB)` (kind `"stub"`, at `py + duct_y`, its room the one of `c` or `n` that contains it): edges `c–s` and `s–n` keep the original kind and split the metres. The `"cross"` edge from the main node to `s` comes in j. So the crossing has a real side duct, crawlable for `STUB` past the main's side wall (systems 4.5), and her network meets the main there and only there.
7. **Exits.** Each exit is a separate node joined to its cell's node by a `"drop"` edge, whose length is the 3D distance.
   - **Room cells (non-corridor):** one exit.
     - With `WALL_EXIT_P`, and only outside archives: a low wall grille (kind `"wall"`) at a free wall spot that is not on a glazed wall and not within 1.0 m along of an item of `room.furniture` against that wall; `y = py + WALL_GRILLE_Y`; registered.
     - Otherwise a ceiling grille (kind `"ceiling"`): a tile of `palette.free_tiles(room)` drawn with `rng`, `point = palette.tile_centre(tile, py + height)`.
     - With no free tile left (after the main clearance below), a wall grille; with no wall spot either: `{"fail": "duct_exit"}`.
   - **Corridor cells:** a ceiling grille with `CORRIDOR_EXIT_P`. Then every lane run between crossings with none gets one in the cell nearest its middle that has a free tile; with none in the whole run, a wall grille in its middle cell.
   - **Cells without a false ceiling** (`not palette.false_ceiling(room)`: service corridors 12, air room 22, plant 23): the exit is kind `"duct"` instead, under the cell's own duct: at the node's x, z (moved 2.0 m across the main if that keeps it inside the cell, when the main crosses it), `y = py + duct_y - h / 2` with `h` the node's section height (`duct[1]` for a trunk, `branch[1]` for a branch). A cell where neither fits gets no exit; on planta 2 the validator allows that only for main cells.
   - **Main clearance** (planta 2): no `"ceiling"` or `"duct"` exit within `main / 2 + MAIN_CLEAR` in plan of the main's floor line (hatch, main cell centres, mouth) or of the stub (crossing node to `s`). A gap's plenum cell spans ±1.2 m, and its side panels would cut the duct (geometry 5.4).
   - **The hatch** is an exit too: `{node: hatch node, room: plant, kind: "hatch", point, yaw}` (added in j). She leaves the main duct by it into the plant.
   - **Store** `{"node", "room", "kind", "point": [x, y, z], "yaw"}`; yaw only for wall grilles and the hatch, else 0.
8. **Gaps** (missing tiles).
   - Eligible per planta: cells of `C` with `palette.false_ceiling(room)`.
   - Count = `roundi(GAP_SHARE[planta] × eligible)`. Cells are drawn without repeats, weighted `1 + kept`, so abandoned rooms shed more. A drawn cell with no valid tile is skipped and another drawn; if the pool runs out first: `{"fail": "gaps"}`.
   - One tile per cell: kind `"gap"`, a tile of `free_tiles(room)` that is not the cell's grille tile, its centre at least 1.2 m from that grille's, outside the main clearance; `point = tile_centre(tile, py + height)`; no drop edge.
   - The generator never writes `room.ceiling`: geometry reads the gaps from `ducts.exits` (geometry 0.1) and picks supply or return per grille with `vary()`.

**j) The main duct** (from `f.specials[2]`; stream `"air"`).

- **Nodes:**
  - the hatch at `air.hatch.point`, kind `"hatch"`; it is also the `"hatch"` exit;
  - one node per main cell after the plant, at its centre, `py + duct_y`, kind `"main"`;
  - the shaft node at `air.shaft.point` (the mouth), kind `"shaft"`.
- **Edges** `"main"` from node to node, and the `"cross"` edge from the crossing cell's main node to `s` (length `main / 2 + STUB`).
- **Remains:** a point on the duct's floor line at along-share `rng.randf_range(REMAINS.x, REMAINS.y)`, `y = air.shaft.floor_y`.
- **Store** into `air`: `"hatch": {point, yaw, node}`, `"main": {nodes: [hatch, …, shaft], cells: [plant, …], length, bends, cross: main node index, stub: [dx, dz]}`, `"shaft"` gets `node`, `"remains": {point, along}`.

**k) The crawl's height** (one rule for 1b, 1g and the bots; the systems spec 0.2 writes it the same):

- Main nodes are at `py + duct_y` (3.7), the duct's centre line. The duct is `main` × `main` inside. Its floor is at `py + duct_y - main / 2` (3.1), its inner top at `py + duct_y + main / 2` (4.3), under the 4.4 slab.
- The hatch's sill and the shaft's landing (`air.shaft.floor_y`) are at that floor.
- The plant (23: 4.4 m, no false ceiling) has a climb from its floor up to the hatch: a fixed steel ladder from `foot()` to the sill, worked with the key (`"ENTRAR"` up, `"BAJAR"` from inside; systems 4.4), and the bots get the climb as one more errand.
- `crawling_at()`, the crouched-capsule test and the bots' scripted route all take these heights from `palette.crawl_boxes()` (1.2), which reads `manifest.plenum` and `manifest.ducts`. None has a constant of its own.

**l) Order inside `furnish()`:** lobby (a), archives (b), mail (c), power (d), air fixtures (e), sockets and props (f), glass (g), furniture (h), ducts (i: nodes, trunks, branches, bridges, loose links, the crossing, exits, gaps), the main duct (j). Every step that places a wall spot registers it before the next. Return the keys `floor` (2), `version` (`VERSION`), `departments` (from `f.departments`, as `[[{sector, name, colour}], …]`), `plenum` (`PLENUM.duplicate(true)`), `ducts`, `archives`, `mail`, `tubes`, `power`, `air`, and `arrival_lift` when present. `sockets`, `glazed` and `furniture` are written into the rooms.

**Manifest keys of the ducts:** `"ducts": {"nodes": [[x, y, z, room, kind], …], "edges": [[a, b, metres, kind], …], "exits": [...]}`, with node kind in `trunk|branch|stub|exit|hatch|main|shaft` and edge kind in `trunk|branch|bridge|loose|drop|main|cross`. The kind of an edge is `edge[3]`; `edge[2]` is its metres.

### 2.6 `game/world/generation/conduit_metres.gd` (new, shared)

```gdscript
extends RefCounted
## Binary-heap Dijkstra over a conduit ({nodes, edges}: ducts or tubes) and bounded walking metres
## over the door graph. Used by the office generator, its validator, office_metrics and, in 1e,
## conduit_graph.gd.
static func adjacency(conduit: Dictionary, skip_kinds: Array = []) -> Array    # per node [[other, metres, kind], …]
static func metres(conduit: Dictionary, from: int, reach := INF, skip_kinds: Array = []) -> Dictionary  # node -> metres
static func pieces(conduit: Dictionary, nodes: Array, skip_kinds: Array = []) -> int
static func walk_within(rooms: Array, adjacency: Array, from: int, limit: float) -> Dictionary  # room -> metres <= limit
```

`walk_within` uses the same metric as `FLOOR.route_metres` (centre to centre per door) but with a heap and a bound. The generator calls it hundreds of times per planta; `route_metres` is O(n²) per call.

### 2.7 `game/world/generation/office_layout.gd` (new, shared by the generator and the validator)

```gdscript
extends RefCounted
## Plan geometry of a room's floor, room-local (x, z) from the cell centre: what free-standing furniture
## must keep clear, so the generator places and the validator checks with one rule. The zones are the
## paths of map_validator.validate_physics() (its capsule is radius 0.32) with a margin.
const CENTRE_CLEAR := 0.6
const SWEEP_CLEAR := 0.45      # capsule 0.32 plus a margin
const DOOR_BAND := 1.5         # out from a doorway's wall (the leaf sweeps 1.2)
const DOOR_SIDE := 0.3         # past each jamb along the wall
const FIXTURE_CLEAR := Vector2(1.2, 1.2)
const LOCKER := Vector2(1.3, 0.7)
const ITEM_GAP := 0.9
const INNER_PAD := 0.02
static func inner(room: Dictionary) -> Rect2                       # ±(span / 2 - WALL_HALF - INNER_PAD)
static func footprint(item: Dictionary) -> Rect2                   # at, size, turn (odd turns swap the size)
static func cover_reach(room: Dictionary) -> float                 # minf(2.2, minf(span.x, span.y) * 0.5 - 2.5)
static func fixtures(manifest: Dictionary, room_id: int) -> Array  # room-local {wall, along, half} of every wall spot in the room
static func clear_zones(manifest: Dictionary, room: Dictionary, exempt_cover: bool) -> Array  # [{"a", "b", "r"}] capsules and [{"rect"}]
static func blocked(rect: Rect2, zones: Array) -> bool
static func segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float
static func rect_minus(rects: Array, cut: Rect2) -> Array          # each rect less cut, as at most 4 rects (used by 3.2)
```

**`clear_zones()`**, in this order:

1. The centre: a capsule from (0, 0) to (0, 0), radius `CENTRE_CLEAR`.
2. The cover sweeps (unless `exempt_cover`: archives and the boardroom): a capsule from (0, 0) to each `(±c, ±c)`, `c = cover_reach(room)`, radius `SWEEP_CLEAR`.
3. The passages: for every neighbour in `adjacency` (doors and open sides), with `d` the doorway point (`FLOOR.portal_between()` less the room's position; an open side's middle) and `t` the unit step toward the neighbour: capsules (0, 0) to `d - t` and `d - t` to `d`, radius `SWEEP_CLEAR` (the base validator's passage path, lines 273 to 282).
4. Doorway bands: for every doorway (not open sides), the rect along its wall over `along ± (PORTAL / 2 + DOOR_SIDE)`, `DOOR_BAND` deep from the inner face.
5. Lockers: per hide, the `LOCKER` rect at it along its wall, and capsules (0, 0) to `FLOOR.hiding_approach(hide)` and on to the hide, radius `SWEEP_CLEAR`.
6. Corner sockets of the room's props: the 2.3 × 1.4 piece footprint of 2.5f.
7. Wall spots (`fixtures()`: every entry with `point` and `yaw` under `mail`, `power` and `air`, every station exit and every wall exit, as geometry 6.8 walks them, whose point is in this room within 0.6 m of a wall's inner face; its wall from `yaw`, its `along` from `point`): the `FIXTURE_CLEAR` rect in front of each.
8. The lift wall, if any: the band from the lift wall's line (`half - FLOOR.LIFT_DEPTH`) 1.2 m into the room, full width.

`cover_reach()` is also the office's cover sweep (3.2): with `SOCKET_INSET` 1.3 an 8 m module sweeps to 1.5, and a 2.3 × 1.4 corner piece stays 0.5 m clear of the capsule.

### 2.8 Manifest additions at a glance (floor 2 only)

```text
floor: 2, version: 1
plenum: {ceiling, slab, duct_y, main, duct, branch}
departments: [[{sector, name, colour}], ×3]          colour: index into PALETTE.STRIPES
archives: [{rooms, axis, mobile, open, height, wall_gap, spine, rows, aisles}]
mail: {window, desk, stand, camera, camera_target, map, reader, stations}
tubes: {nodes, rooms, edges, exits, hub}
power: {room, board, circuits: [{code, name, sector, colour, lever, rooms}], lift_lever, timers: [{rooms, sector, room, wall, along, point, yaw}]}
air: {security: {room, door, outside, desk, reader}, room, plant, hatch: {point, yaw, node}, unit, stop,
      main: {nodes, cells, length, bends, cross, stub}, shaft: {point, node, side, rect, floor_y, ladder: {point, yaw}}, remains: {point, along}}
ducts: {nodes: [[x, y, z, room, kind]], edges: [[a, b, metres, kind]], exits: [{node, room, kind, point, yaw}]}
arrival_lift: [dx, dz] (optional)
gates[2].kind = "shaft"; doors["a:b"].lock = "card" (security door only)
rooms: as the hotel's (types from the office palette, heights 2.95, 3.25 and 4.4, hides = lockers),
       plus sockets [[x, z] ×4] (non-corridor rooms), glazed [sides], furniture [{kind, at, turn, size, extra}]
```

### 2.9 Tests for 1b (`tests/office/office_test.gd`, section "generador")

Seeds 1 to 40 at 2 survivors, plus seeds 41 to 46 at each of 1, 4 and 5 survivors. Fresh `office_generator.new()` per floor.

- **Planta checks.** At most one fallback in 40. Room windows and plantas as the base validator says (`super` part). `floor == 2`, `version == 1`.
- **Specials.** Exactly one window on planta 0, one electrical room on planta 1, one security office, one air room and one plant on planta 2. Each one's share is in its band, with ±0.01 slack for the depth shares.
- **Freight lift.** Planta 1's freight lobby share ≥ 0.8. Planta 0's walk ≥ 110 × sqrt(area). `mail.reader` is in `gates[0].room`, on its wall shared with `gates[0].beyond`, within 1.5 m of that doorway's centre.
- **Gates and locks.** `gates[2].kind == "shaft"` and its beyond has no `lift`. The security office has exactly one door, locked `"card"` and shut; `air.security.reader` is in `outside`.
- **Stations.** Count in [8, 14]; every station room on planta 0 and distinct; every station's `tube` ≥ 25; the tube graph is one piece with nodes = edges + 1; `tubes.rooms.size() == tubes.nodes.size()`.
- **Circuits.** They cover every non-off-limits, non-electrical room of planta 1 exactly once, and with `always_lit(manifest, 1)` and the electrical room they cover the wing. Timer coverage ≥ 0.5. No timer has a `seconds` key.
- **Main duct.** Length in [25, 45], bends ≥ 2, exactly one `"cross"` edge of length `main / 2 + STUB`. `FLOOR.room_at(rooms, p).is_empty()` at the shaft rect's centre and four corners at `floor_y`. The unit's box is at least 1.0 m from the foot.
- **Ducts.**
  - One piece per planta (`METRES.pieces`).
  - Every non-corridor cell of `C` has an exit (planta 2 main cells without a false ceiling excepted, as in 3.1 group 11).
  - No node in an off-limits room.
  - For every `loose`/`bridge` edge, `L / walk ≥ 0.55`.
  - Gap count per planta as `GAP_SHARE`; every ceiling exit and gap is on a free tile, at its centre.
- **Archives.** Planta 1 has at least 2 archive units. Every narrow aisle is ≥ 0.95 wide; no row crosses a door band.
- **Rooms.** Every non-corridor room has four sockets; the window room is glazed; every `glazed` side has its mirror; every furniture item passes `office_layout`; the median open-office cell holds at least 2 items (evidence: the distribution).
- **Determinism.** Seed 7 generated twice (fresh instances) gives an equal `JSON.stringify`. Generating hotel seed 7 in between changes neither.
- **Standby.** `candidate(404, 0, true)` produces an office with all the keys above.
- **Time.** Record the ms per floor in the evidence. Fail if the median is over 1500 ms. That is a loose bound; the real budget is in `office_metrics`.

Keep `manifest_golden_test`, `hotel_test` and the net tests green; that is the proof the hooks are inert.

### 2.10 Order of work and risks (1b)

**Order:**

1. The two hooks in `map_generator.gd`. Run the golden test.
2. `conduit_metres.gd`, then `office_layout.gd`.
3. `depth_wanted`/`least_walk`.
4. `place_specials` (window, electrical, security, main path with its shaft side). Measure redraws with a quick 100-seed loop.
5. `finish()`.
6. `furnish()` in the order of 2.5l.
7. Tests.
8. `docs/DEVELOPMENT.md`: the office generator next to "Generador de plantas"; what each planta holds; the manifest keys.

**Risks:**

- **Redraws.** Planta 1's refuge band (0.8 to 0.97) plus the bearing rule plus hidden-from-walker, the main duct path search with its shaft side, the window's glass and the unit can multiply redraws. If more than 2 % of floors fall back in a 200-seed loop, widen in this order: `DEPTHS[1].x` to 0.78, `MAIN_LENGTH.y` to 50, `MAIN_TRIES`. Report the change, since OFICINAS 3 says "más allá del 80 %".
- **The security single-door change** can undo `expose()`'s detour promise or make the air room findable by the walker. It is checked; if it fails too often, prefer candidates that already have one door (weight ×4) and raise the tries.
- **A body inside the duct is in the room under it.** `FLOOR.room_at()` and `floor_point()` go by x, z and the planta's band (`planta_of()`, floor_definition.gd:103), so a crawler at 3.1 m is reported in the room below. That room's `lit()`, sanity's dark test (`sanity.lit_at`), the room layers (`layer_at()`, `follow_bodies()`) and the director's room all read it. 1g answers it (systems 4.4: the duct is dark for sanity, a crawler's meshes carry no room bit; geometry H10 `body_bit()`), always through `crawl_boxes()`. Do not "fix" it in `room_at()`.
- **The shaft is in no room.** `room_at()` returns `{}` there: no room lamp, no room layer, `adopt()` gives bit 0. The main duct and the shaft are built on the plenum layer (8) alone, outside every room (geometry 8.5, systems 4.5), and lit by nobody but the torches: Dirección has no power. A body standing there keeps its last room bit.
- **Static state.** `FLOOR.room_at()` caches by array identity, which is safe. Do not add static caches keyed by seed; `crawl_boxes()` caches by manifest identity only.
- **Hook leaks into the hotel.** `result.merge(extra)` must not run with an empty `extra` in a way that reorders keys, and `place_specials` must not touch `rng` in the base. The golden test is the guard.
- **Generation time.** `walk_within` must be bounded; never call `route_metres` per pair. Watch `office_metrics`' p99 (1c).
- **Consumers of the refuge list.** Planta 2's refuge slot is not a refuge: `point_protected` and the dens use the palette's off-limits list, which excludes it. `session.can_depart()` makes stage 3 end with everyone in the air room until 1g's exit handler. `hotel_geometry.build_lifts()`/`build_exit_door()` and `lifts.gd` branch on `gates[i].get("kind", "lift")` in 1d/1g (geometry 7.8). Until then floor 2 is not played.
- **Dark salons.** The office allows salon cells to be dark ("zonas apagadas"). The hotel never did. Light leaking across open sides is for 1d's `light_layers_scan --floor=2`.
- **Furniture density.** 8 m cells with doors in the middle of two walls hold few items once the passages and cover sweeps are kept. That is by design (the sweeps are the floor's guarantees); `office_metrics` reports the distribution. If open offices look bare, add a second, smaller lattice of single `desk`s in the same zones, never a narrower zone.

---

## 3. Step 1c: the validator and `office_metrics`

### 3.1 `office_validator.gd`

```gdscript
extends "res://game/world/generation/map_validator.gd"
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const METRES := preload("res://game/world/generation/conduit_metres.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
## The validator's own promises (OFICINAS 11.3), not read from the generator.
const SHORTCUT_MIN := 0.55
const AISLE_MIN := 0.95
const SLACK := 0.01
const SLEEVE := 0.05          # round a crawl box in the ceiling band (geometry 4.1)
func validate(data: Dictionary) -> Array[String]       # super.validate(data) + office(data)
func office(data: Dictionary) -> Array[String]         # the groups below, in this order
func validate_physics(world: World3D, data: Dictionary) -> Array[String]  # see 3.2
```

**Error codes and checks.** Like the base: a short name, plus the id where useful.

`lenient = data.get("fallback", false)`. A lenient manifest skips the depth bands and widens the main length to 15 to 70 m. Everything else applies.

1. **`office_floor` / `office_version` / `plenum`.**
   - `floor == 2` and `version == OFFICE.VERSION`.
   - Plenum keys present (`ceiling, slab, duct_y, main, duct, branch`).
   - `duct_y - main / 2 ≥ ceiling + 0.1` and `duct_y + main / 2 ≤ slab - 0.05`.
   - `duct_y - duct[1] / 2 ≥ tallest + 0.05 - 0.001` and the same for `branch`, with `tallest` the largest `height` among the manifest's non-void rooms with a false ceiling (the boardroom's 3.25).
2. **`type_<id>`, `height_<id>`, `dark_<id>`.**
   - Every type is in `[0, 25]`.
   - Height equals `height_of(room)`.
   - `dark` only where `may_be_dark`.
   - Archive and mobile-archive cells have no props and no furniture.
   - No `BOARDROOM` in `air.main.cells`.
3. **`special_<name>`.** Exactly one each:
   - `WINDOW` on wing 0;
   - `ELECTRICAL` on wing 1;
   - `SECURITY`, `AIR_ROOM` (== `refuges[2]`) and `AIR_PLANT` (== `gates[2].beyond`, `landing` true, merged with the air room) on wing 2.
   - `REFUGE` == `refuges[0..1]`; `LANDING` == `gates[0..1].beyond`; `LOBBY` == `entries[1..2]`.
4. **`depth_<name>_<planta>`** (not lenient).
   - Shares by `FLOOR.route_metres(data, entry)` over the planta's reachable rooms, with the landing excluded from the max.
   - Window within `WINDOW_DEPTH`, electrical within `ELECTRICAL_DEPTH`, security within `SECURITY_DEPTH`, each refuge slot within `DEPTHS[planta]`, all ± `SLACK`.
   - Planta 0's refuge walk ≥ `110 × sqrt(areas[0]) - 0.5`.
5. **`departments_<planta>`.**
   - One entry per sector, names unique within the planta, colours unique and in `[0, STRIPES.size())`.
   - Planta 2 has `"SEGURIDAD"` on the security office's sector.
6. **`lockers_<id>`.**
   - Hides only in `WARDROBES` types; the base already caps the count.
   - Every hide is at least `WALL_APART` along from every wall spot on the same wall.
7. **`archive_<i>` / `aisle_<i>`.**
   - Rooms are archive types, one connected straight unit.
   - Rows lie inside the union footprint minus `inset`; rows do not overlap; spine width ≥ 1.6.
   - Every cell centre lies in the spine.
   - Every narrow aisle ≥ `AISLE_MIN` wide.
   - For every doorway on a long wall, no row meets `along ± 1.0`.
   - For every doorway on a short wall, the end aisle ≥ 1.5.
   - Mobile: `open` gaps ≥ `AISLE_MIN`.
   - `height ≤ FURNITURE_TOP`.
8. **`mail` / `mail_reader` / `station_<n>` / `tube_*`.**
   - `desk`, `map`, `hub` on closed walls of the window room, the desk wall with no doorway; `stand` 0.5 to 0.8 m from `desk.point` at `py`; `camera` in the window room at `py + height - 0.15`, at least 2 m from the desk; `camera_target` 1.3 m over the stand.
   - `mail_reader`: in `gates[0].room`, on its wall shared with `gates[0].beyond` (on the lobby's inner face, ±0.01), within 1.5 m along of that doorway's centre, at `py + 1.2`.
   - Station count within `STATIONS`.
   - Each station in a distinct planta 0 room that is not corridor, off-limits, the window or the reception.
   - Each station point on a closed wall of its room, at least `HIDE_CLEAR` from any doorway centre on that wall, at `py + STATION_Y`.
   - Numbers are 1..N exactly once.
   - Tube graph: one piece, a tree. The hub is in the window room. `tubes.rooms` has one valid room per node.
   - Every horizontal tube segment is axis-aligned, at `py + TUBE_Y`, and inside the footprint of the room it runs through (sample every 0.5 m with `FLOOR.room_at`). Where it changes room, the crossing point is within `PORTAL / 2` of that pair's doorway.
   - `tube` metres by `METRES.metres` from the hub equal the stored value (±0.01) and are ≥ `STATION_TUBE_MIN`.
   - Walking distance between any two stations ≥ `STATION_APART × sqrt(areas[0]) × 0.8`.
9. **`power` / `circuit_*` / `timer_<i>`.**
   - The board is on a closed wall of the electrical room.
   - Circuits: one per sector of wing 1. Codes `"R-1".."R-n"` match lever order. Their rooms are exactly the wing's non-void rooms minus off-limits rooms and the electrical room, each once (`circuit_cover`).
   - `lift_lever == circuits.size()`.
   - Each timer's rooms are corridor cells of wing 1; its button is a wall spot on a side wall of one of them, at least 1.0 m along from every doorway edge on that wall; it has no `seconds`.
   - Covered corridor cells ≥ `TIMER_COVER`.
10. **`air` / `security_*` / `hatch` / `unit` / `stop` / `main_*` / `shaft` / `remains`.**
    - The security office has exactly one door (`security_doors`), keyed `air.security.door`, with `lock == "card"` and `open == false`; `outside` is its other room.
    - `security_desk` on a closed wall of the security office; `security_reader` in `outside`, on its wall shared with the security office, within 1.5 m along of the doorway, at `py + 1.2`.
    - `gates[2].kind == "shaft"`, and its beyond has no `lift`.
    - `hatch`: inside the plant, `HATCH.in` from the plant's wall toward `main.cells[1]`, at `py + duct_y`, yaw facing away from that wall.
    - `unit`: a wall spot on a closed wall of the plant (not the open side), `y = py`, its `AIR_UNIT` box inside the plant's inner rectangle, out of the hatch's 1.5 m floor square and at least 1.0 m from the foot (`hatch floor point + facing(yaw) * HATCH.stand`). `stop`: on the unit's wall, within `AIR_UNIT.x / 2 + 1.5` of its `along`, at `py + 1.3`.
    - Main nodes chain from the hatch to the shaft by `"main"` edges; `main.cells` has one cell per node but the shaft's, the plant first, each inner node at its cell's centre; no main cell is off-limits.
    - Length (the sum of main edges) is within `MAIN_LENGTH` and equals `main.length`. `bends ≥ MAIN_BENDS`, recounted from the node directions.
    - `main_cross`: exactly one `"cross"` edge, from `main.cross` (a main node strictly inside the chain) to a `"stub"` node at `main / 2 + STUB` along `main.stub`, perpendicular to the main there (at a bend, not along either main direction); the stub node lies on a network edge to a grid-adjacent cell of `C` that is not a main cell.
    - `shaft`: `rect` is at least 2.0 × 2.0; its near edge lies on the outer face of the last main cell's wall on `side` (±0.01) and contains `point`; no non-void room of wing 2 overlaps it (footprints less 0.01), and `FLOOR.room_at()` is empty at its centre and four corners at `floor_y`; `floor_y == py + duct_y - main / 2` (±0.001); `ladder.point` inside the rect at `floor_y`.
    - The remains point lies on the main's floor line.
11. **`duct_*`.**
    - Index ranges valid. Edge metres equal node distance ±0.01. Edge endpoints are on the same wing.
    - `trunk`, `branch`, `bridge` and `loose` edges join the nodes of two grid-adjacent cells (`|dx| + |dz| == 1` in grid coordinates), or a cell's node and the stub node on the segment between them; they are horizontal at `py + duct_y` and axis-aligned in plan.
    - `trunk` joins two corridors with a door edge; `branch` joins two door-adjacent cells; `bridge` and `loose` join cells with no door edge.
    - `duct_off_limits_<n>`: no node of any kind in an off-limits room.
    - `duct_split_<planta>`: each wing's nodes are one piece (`METRES.pieces`).
    - `duct_room_exit_<id>`: every non-corridor, non-off-limits cell has an exit that is not a gap; on wing 2 a main cell without a false ceiling may have none.
    - Every lane run between crossings has an exit (`duct_corridor_<id>`).
    - `duct_band_<a>_<b>`: for every `loose`/`bridge` edge, `L / walk(a, b) ≥ SHORTCUT_MIN`, with `walk` from `METRES.walk_within(rooms, adjacency, a, L / SHORTCUT_MIN)`. This local check implies the global band (2.5i).
    - `duct_shortcuts_<planta>`: at least one `loose` edge per planta, so the ducts do give shortcuts.
    - Exits:
      - inside their room, more than 0.3 m from its edge;
      - `exit_tile_<id>`: ceiling exits and gaps on a tile of `OFFICE.free_tiles(room)`, `point == tile_centre(tile, py + height)` (±0.001); a gap not on its cell's grille tile and at least 1.2 m from it; at most one gap per cell;
      - `"duct"` exits only in rooms without a false ceiling, under their node's duct;
      - wall exits at `py + WALL_GRILLE_Y` on a closed, unglazed wall, at least `HIDE_CLEAR` from doorways;
      - `main_clear_<id>`: no ceiling exit, duct exit or gap within `main / 2 + MAIN_CLEAR` in plan of the main's floor line or the stub;
      - no exit in archive rows (plan check);
      - `exit_off_limits_<id>`.
    - `gaps_<planta>`: the count equals `roundi(GAP_SHARE × eligible)`.
12. **`arrival_lift`** (if present): that wall of the reception has no doorway and is not an open side.
13. **`sockets_<id>` / `props_<id>`.** Every non-void, non-corridor room has four sockets by the rule of 2.5f (±0.001); no corner piece footprint meets a locker, a wall spot's clear rect, the hatch square or the unit.
14. **`glazed_<id>` / `glazed_window`.** Every side in a room's `glazed` has its mirror in the neighbour's; one of the pair is of `GLAZED_TYPES` and the other a corridor or gallery; the side is not open, not a lift wall, not a gate pair, and holds no locker and no wall spot on either face. The window room has a glazed side holding its door to a corridor.
15. **`furniture_<id>`.** Kinds are keys of `FURNITURE`, only in the types of 2.5h; `size` and `extra.height` match `FURNITURE` (a partition's length 1.2 to 4.8), and `extra.height ≤ FURNITURE_TOP`; every footprint lies inside `LAYOUT.inner(room)`, is not `LAYOUT.blocked()` by `LAYOUT.clear_zones(data, room, exempt)`, and keeps `ITEM_GAP` from items of other groups.

### 3.2 `validate_physics()` (written in 1c; called from `build_floor` and switched on in 1d)

`super.validate_physics(world, data)` is called with three adjustments, made through small overridable helpers in the base. Factor `room_sweeps(room)` and `passage_path(a, b)` out of `map_validator.validate_physics()` (lines 232 to 282) first, as a pure refactor.

- **`cover_access` sweeps.** In the office they go to `(±c, ±c)` with `c = LAYOUT.cover_reach(room)`. They are skipped for archive cells and the boardroom (its table).
- **Passages for archive cells.** The path is orthogonal: centre, then the spine point at the doorway's `along`, then 1 m before the doorway, then through it. The base's straight diagonal would cross shelving.
- **No alcove sweeps** (`palette.domestic()` is false for every office type).

Added sweeps (capsule radius 0.32, height 1.8, mask 1):

- **Archive aisles.** Along the centre line of every narrow aisle, from its spine end to its far end: `cast_motion ≥ 0.99`.
- **Rays from every exit.** Mask 1, so closed leaves on layer 8 do not count.
  - Ceiling and duct exits: from 0.05 m under the exit straight down to `py + 2.25`, no hit (nothing over 2.2 under a grille). Then from that point to the room centre at `py + 2.6`, no hit ("el techo de cada sala es un camino libre").
  - Wall exits: 1.0 m out along their yaw, no hit.
- **Ceiling band** (`ceiling_band_<id>`). Per non-off-limits room, a box from `py + 2.25` to `py + height - 0.05`, inset 0.25 from the walls: `intersect_shape` empty. The main duct's collider is on layer 1 and lies inside that band in every 4.4 m room it crosses (the plant always; the air room or a service corridor when the path runs through them), so:
  - the plant is skipped (its hatch end, its ladder and the unit's round ducts stand in the band);
  - in every other cell of `air.main.cells` the band is the box less the plan footprint of every `OFFICE.crawl_boxes(data)` grown by `SLEEVE` (`LAYOUT.rect_minus()`, at most four boxes per cut), each queried on its own.
- **Boardroom.** Two sweeps along the long sides of its `meeting_table` item at `±(0.6 + 0.6)` from the table's centre line, its length plus 0.6 each end.

The crouched-capsule sweep of the duct itself is 1g's (`office_stages_test`, systems 6), on `crawl_boxes()`.

### 3.3 `tools/dev/office_metrics.gd`

`extends SceneTree`, modelled on `map_metrics.gd`, with the same `judge()`/`quantile()` helpers. Only manifests; nothing is built.

```text
godot --headless --script tools/dev/office_metrics.gd -- 1000 [--survivors=N]
```

It prints `PASS`/`FAIL` per measure with its threshold, writes `evidence/office_metrics.json` (`office_metrics_N.json` for other sizes), and ends with `OFFICE_METRICS PASS|FAIL n/m`, exiting 1 on any failure. It is not in `verify.ps1`; run it on demand.

It exposes `static func floor_measures(data: Dictionary) -> Dictionary` (every per-floor number below). `office_test` calls it on 3 seeds so the tool cannot rot.

| Measure | Threshold |
|---|---|
| Fallback floors | < 0.5 % |
| Floors the office validator rejects | 0 |
| Plantas drawn again (by `stats` reason) | informative |
| Rooms per planta outside the window; numbered > 96 | 0; 0 |
| Refuge-slot share per planta, min/max | inside `DEPTHS[p]` |
| Walk to planta 0's freight lobby, min | ≥ 110 × sqrt(area) |
| Window, electrical, security shares, min/max | inside their bands |
| Stations per floor, min/max; tube metres to a station, p5 | 8 to 14; ≥ 25 |
| Floors where every planta 0 sector has a station | ≥ 95 % |
| Sectors per planta | 5 to 7 |
| Timer coverage of planta 1 corridors, p5 | ≥ 0.5 |
| Archive units on planta 1, p5; narrow aisles per archive salon, median | ≥ 2; informative |
| Narrowest archive aisle | ≥ 0.95 |
| Lockers per planta, p5 | ≥ 8 × area |
| Main duct length, min/max; bends, min; crossings | 25 to 45; ≥ 2; exactly 1 |
| Shaft beyond a cut-out cell or off the grid | informative |
| Duct network in one piece per planta; rooms with an exit | 100 %; 100 % |
| Shortcut ratio over 40 random exit pairs per planta (duct metres without main/cross edges over walking metres, pairs walking ≥ 12 m), min | ≥ 0.55 |
| Share of those pairs with a ratio in [0.55, 0.9], median | ≥ 0.10 |
| Loose links per planta, median | informative |
| Gaps per planta | as `GAP_SHARE` |
| Dark share per planta, mean | about 0.23, 0.29, 0.36 (informative) |
| Items per open-office cell, median; boardrooms with a table | informative; ≥ 80 % |
| Glazed walls per planta, median; corner props dropped per floor, median | informative |
| Generation p50 / p99 (ms) | informative / ≤ 700 × max(1, area²) |

### 3.4 Tests for 1c (`tests/office/office_test.gd`, section "validador")

- **Clean manifests.** The 40 manifests from section "generador" give `validate() == []`. The base validator still accepts every hotel manifest of `manifest_golden.json`'s seeds; `hotel_test` covers this.
- **Mutations.** Deep-copy seed 7's manifest, apply one change, and expect the named code:

| Mutation | Expected code |
|---|---|
| Remove a room's only exit | `duct_room_exit_<id>` |
| Add a node inside planta 0's freight lobby, with a drop edge | `duct_off_limits_*` |
| Delete a trunk edge that disconnects a wing (find one by `pieces`) | `duct_split_*` |
| Add a loose edge on a grid-adjacent pair with `L / walk < 0.55` (search for one) | `duct_band_*` |
| Narrow one aisle to 0.9 | `aisle_*` |
| Keep 7 stations | `station*` count |
| Move the shaft node 12 m further | `main_*` length |
| Link the security office to a second neighbour | `security_doors` |
| Move an exit into a lobby | `exit_off_limits_*` |
| Remove one gap exit | `gaps_*` |
| Move a ceiling exit 0.3 m along x | `exit_tile_*` |
| Move a ceiling exit onto a troffer tile | `exit_tile_*` |
| Move a planta 2 gap onto the main's floor line | `main_clear_*` |
| Put a timer's button 0.5 m from a doorway edge | `timer_*` |
| Drop one room from a circuit | `circuit_cover` |
| Swap the window's type with a room at share 0.9 | `depth_window_0` |
| Set `gates[2].kind = "lift"` | the shaft check |
| Set the boardroom's height to 3.4 | `height_*` and `plenum` |
| Shrink the shaft rect to 1.8 × 1.8 | `shaft` |
| Move the shaft rect 3 m back into the grid | `shaft` |
| Move `mail.reader` into the landing | `mail_reader` |
| Move the unit onto the hatch's floor square | `unit` |
| Put the cross edge's stub node on the main node (length 0) | `main_cross` |
| Move a `desk_pair` to the room centre | `furniture_<id>` |
| Set a partition's `extra.height` to 2.4 | `furniture_<id>` |
| Glaze one side of a pair only | `glazed_<id>` |
| Glaze a wall that holds a locker | `glazed_<id>` |
| Clear the window room's `glazed` | `glazed_window` |
| Move a socket 0.5 m | `sockets_<id>` |

- **Lenient.** A copy marked `fallback` with the window out of band is accepted.
- **Metrics.** `OFFICE_METRICS.floor_measures()` on seeds 1 to 3 returns every key of the table without error.

Then run `office_metrics.gd -- 1000` (and `--survivors=1`, `--survivors=5`) once by hand, and put the results line in the step's report.

### 3.5 Order of work and risks (1c)

**Order:**

1. Factor `room_sweeps()`/`passage_path()` out of the base's physics. Run the golden and `hotel_test`.
2. `office_validator.validate()`, group by group, against the 40 seeds.
3. The mutation tests.
4. `validate_physics()` (no test until 1d; the main-duct parts once 1g builds the duct).
5. `office_metrics.gd`, then the 1000-seed runs.
6. Docs: `docs/DEVELOPMENT.md`, how to run `office_metrics`.

**Risks:**

- **Rejections loop back into the generator.** A validator stricter than the generator turns into redraws, because `generate()` retries rejected candidates. Read `stats` (`invalid_*`) in `office_metrics` and fix the generator, not the threshold, unless OFICINAS allows it.
- **Shares differ by measure.** The generator measures over `alive`; the validator over the final manifest with the landing excluded. Keep `SLACK` and compute both the same way.
- **Shared rules hide shared bugs.** The generator and the validator both call `office_layout.gd` and the palette's lattice; a wrong rule passes both. The mutation table and 1d's physical test (the base sweeps on the built furniture) are the independent checks.
- **The physical part is untested** until office geometry exists. 1d calls `kind.VALIDATOR.new().validate_physics()` in `build_floor` (as today) and adds three seeds to `office_test` in physics; with the main duct built (1g) the same seeds must still pass.

---

## 4. What later steps read and build from this

Each system step builds its own static pieces (systems 0.2, geometry 1): 1d builds the rooms, the glass and the freight lift, not the planta systems. Models only from registro entries with status "ok" (all CC0: `pipes_modular_polyhaven`, `electric_cables_switches_polyhaven`, `duct_fans_circular_polyhaven`, `fire_escape_ladder_polyhaven`), primitives where none fits.

- **1d (geometry):**
  - `height`, `false_ceiling()`, `floor_finish()`, `wall_material()`, `lamp_of()` (the electrical room's `"emergency"`: no troffers, never powered), the lattice (`ceiling_rect`, `troffers`, `free_tiles`, `tile_of`, `tile_centre`), every size from `manifest.plenum` (no size of its own);
  - `ducts`: the kind of an edge is `edge[3]`; `bridge` and `loose` edges drawn like branches with `plenum.branch`; ceiling exits and gaps by `tile_of(point)`; wall grilles by `yaw`; supply or return by `vary()`; network ducts clipped out of `crawl_boxes()`;
  - the gaps from `ducts.exits` (one per drawn cell, so no merging);
  - `archives` (rows at `height`, battens over `aisles`);
  - `departments` (stripes by sector colour, `stripe_color()`), `zone_label()`, `plaque()`;
  - `arrival_lift`; lockers (`hides` with `hide_kind`); `sockets` (H8), `glazed`, `furniture`;
  - the reserved wall spots (`mail`, `power`, `air`, stations; `mail.reader` stays clear on the freight lobby's wall, no `car_fronts` mount);
  - `gates[2].kind == "shaft"` (no car, no exit door);
  - a builder for every office `RECIPES` kind and every `FURNITURE` kind;
  - the walls of 4.4 m rooms on the main path cut round the duct.
- **1e:** `mail` (desk, stand, camera, camera_target, map, reader), `tubes` (conduit_graph from `conduit_metres`; `tubes.rooms`), station numbers, the freight gate on planta 0. Builds the window counter with its glass, the desk and typewriter, the camera housing, the stations, the hub, the visible tube runs along the `tubes` edges at `TUBE_Y` (no collider) and the reader plates.
- **1f:** `power` (board, circuits, `lift_lever`, timers), `palette.POWER`, `always_lit(manifest, 1)`. Builds the board cabinet with its levers and codes, the conduit to the ceiling and the minutero boxes.
- **1g:** `air` (security door lock, console `air.security.desk`, post reader, unit, stop, hatch, main chain with its crossing and `stub`, shaft, remains), `always_lit(manifest, 2)`, `gates[2]` exit handler, `title_of()` on the ride card. Builds `main_duct_geometry` (the sheet duct `main` × `main` along `air.main` on exactly `crawl_boxes()`, collision layer 1; the crossing stub `STUB` long; the hatch frame; the plant ladder from `foot()` to the sill; the shaft from `air.shaft.rect`, `floor_y` and `ladder`) and `air_geometry` (the unit `AIR_UNIT` with its fans, the stop box, the console), all from the palette's constants. The shaft's walls and roof must stay under the floor slab of the planta above at `py + PITCH - 0.3` (5.7 m): with `floor_y` at 3.1, a head of at most 2.55 (the systems spec's `SHAFT_HEAD` 2.6 reaches 5.7 and z-fights that slab where planta 1 has a room over the shaft).
- **Phase 2:** `ducts` (the duct graph, the stub node included), `archives.aisles` (channels), `off_limits_rooms()`, `plenum.duct_y`, `crawl_boxes()`.

## Notes from the work orders of 1a (22 October 2026, .claude/specs/encargos_1a.json)

- The archive's shelving dictionary is `ARCHIVE_LAYOUT` (the id `ARCHIVE` is 6). 1b uses that name.
- `numbered()` of the office stays as 1.2 (no `service` clause). The base `keep_to_hundred()` turns numbered rooms beyond NUMBERED_MOST into `service` ones that stay numbered with the office palette, so with 4 or 5 survivors every attempt fails `numbered_<planta>_<n>`. 1b solves it with the DEPOT (25, unnumbered) for the surplus; office_test of 1a runs with 2 survivors.
- NOT in 1a, a step of its own before 1d: the creature contract gains `place_at(room_id)`, `start_room(stage) -> int`, `arm(onslaught: bool)` and `sound_profile() -> Resource` (null for the null creature), and hotel_main's `spawn_creature()` (`den_room(1)`, `patrol_room`), `arm_creature()` (`reach_scale`, `ONSLAUGHT_REACH`, `relentless`) and populate (`sound_profile`) ask only those; versus's `camera`, `driver` and `mark_blackout()` too. Until then `--floor=2` builds the office manifest with the hotel's geometry and fails at `spawn_creature()`; and `built(2)` is true, so a floor-2 checkpoint made outside `--test-profile` would be offered by Continue.
- At release (phase 5): tape_report's SECTOR column and «SECTOR %d CERRADO», FIRST_LEAD, and records_service sealing every tape with FLOOR.VERSION instead of the kind's GENERATOR_VERSION.
- For 1f: `always_lit(manifest, 0)` lights every non-void room of Personal's wing but the electrical room; spec_f1_systems 0.2 names only wings 1 and 2.

## Notes from step 1b (23 October 2026, .claude/specs/encargos_1b.json)

- Line numbers quoted in sections 1 and 2 are of the code before 1b, and U1 moved `map_generator.gd`: go by the names. `al_director_resuelto` in the JSON lists where each quoted place was when the work orders were written.
- Duct bridges (2.5i step 4): the branch tree hangs each room from one parent, so two rooms with a door between them can end up in different pieces. Those doors are joined first (as good as walking, lowest pair first), then grid neighbours with no door at `L / walk >= SHORTCUT_MIN`. Without it, 19 of 20 seeds fell to the floor of last resort.
- Loose links (2.5i step 5): with `SHORTCUT_MIN` 0.55 measured centre to centre, none comes out in 20 seeds (two neighbours with no door are some 2 m of walking per metre of line apart). Pending with the author.
- Tube runs (2.5c) keep 0.3 m off a wall's inner face, not off the cell edge, so a doorway and a mouth on the same wall line up.
- On the floor of last resort, where every wall can be a doorway, the window desk, the board and the security desk may stand on a wall with a doorway, clear of it as a locker is.
- `place_musts()` locks the rooms each must counts on (its first units by lowest id, a salon as one) and the toilets already there: the toilets step and `cap_numbers()` took a boardroom or toilets the mix had drawn, and the must went short.
- office_test asks for toilets only in sectors with a plain room on a corridor, and a boardroom only where a large module is free (the generator's own rules). The open-office median is 1 item per cell, not 2: the test keeps «1 or more» while the author decides (zones, lattice or threshold).
- Free tiles and the main duct's line are cached per floor; the median is about 1.4 s a floor, half of it in `furnish_ducts`.

## Notes from step 1c, first part (23 October 2026, done by the director without work orders)

- `office_validator.validate()` has the 15 groups of 3.1 but `duct_shortcuts_<planta>`: with the loose links pending (notes of 1b), it would reject every floor. A `bridge` may join two rooms with a door (1b's notes).
- The stand, the map and the hub are checked on the window's walls; the desk's point is 0.55 m in from its wall (2.5c), and the tube runs are sampled at the middles of 0.5 m steps, since a doorway node stands on two rooms.
- office_test's «validador» section has 28 of the 29 mutations of 3.4 (not the boardroom's height: seed 7 may have none) and the lenient copy. `validate_physics()` (3.2) and `office_metrics.gd` (3.3) are still to do; the base's `room_sweeps()` and `passage_path()` are factored out.
- Loose links, by the author (23 October): `L / walk` takes the walk from door to door (`METRES.door_metres()`: the middle of the room to a doorway's middle, straight across each room from doorway to doorway, and on to the other's middle), not `walk_within()`'s centre to centre, with `SHORTCUT_MIN` still 0.55. Bridges without a door and the validator's `duct_band` use it too. Few pairs pass (0 to 6 of some 70 a planta): a planta the draw leaves without one gets the best that passes, and one with none in reach goes without; `duct_shortcuts_<planta>` is not checked (asking it threw 4 floors in 40 to the last resort). office_test asks three plantas in four or more to have one.
- office_test's time check is 2000 ms: verify.ps1 runs it beside seven other tests (1554 ms there against 1267 alone). The 1500 ms budget is office_metrics' (alone).
- office_metrics on 20 floors (23 October): 50 of 52. FAIL the share of exit pairs whose ducts take 0.55 to 0.9 of the walk (median 0, minimum ratio 1.0: the ducts follow the door tree and the few loose links do not cut walks) and the p99 time (2248 ms against 700; median 1157). Both wait on the author.
- Straight trunks, by the author (23 October): edge kind `express`, from a drawn cell to the farthest cell 2 to 12 along a row or column, over non-void, non-off-limits cells of its planta, joined at its two ends only, at 0.55 to 0.9 of the walk door to door (`door_metres_all()` over a `door_graph()`); 30 a planta, 80 starts tried. The validator checks them (`duct_express_<a>_<b>`). office_metrics now measures ducts node to node (no drops) against that walk: 5.8 % of pairs cut it (60 trunks: 7.8 %, at about 1800 ms a floor); the 10 % target waits on the author.
