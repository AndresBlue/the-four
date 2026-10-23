# Step 1d: office geometry (`game/world/office/office_geometry.gd`) and the asset ingest it needs

Read first: `docs/OFICINAS.md` sections 2 (Las salas, Lo de arriba, Numeración y rótulos), 3 (the light of each planta), 8 (art direction), 10, 11.3, 11.7 (montacargas, ducto a gatas), 11.8, 13 and 15 (phase 1 verification); `source_assets/oficinas/RESUMEN.md`; the `registro.json` of each group. Floor 1 must stay byte-identical: every change to a hotel file in this step is a pure extraction or a hook whose default reproduces today's behaviour.

Companion specs: `spec_f1_generator.md` (1a to 1c: kind, palette, generator, validator) and `spec_f1_systems.md` (1e to 1i). Every manifest key and palette name below is the generator's. If a landed name differs, the landed name wins and the meaning stays; geometry never writes the manifest.

**Numbering.** As in the generator spec, code counts plantas from 0 like `wing`: 0 Personal, 1 Registro y Archivo, 2 Dirección. OFICINAS' "planta 1 to 3" are wings 0 to 2.

Line numbers are from `hotel_geometry.gd` as it was before step 0e. 0e split `build_room()` and 0d moved type lists to the palette, so search by function name, not by line.

---

## 0. Inputs this step assumes (and how to verify them before writing code)

| From | What | Verify by |
|---|---|---|
| 0c | `office_floor.gd` (1a) with `GEOMETRY`, `PALETTE`, `CREATURE` (null creature); `hotel_main.set_floor(2)` builds with `kind.GEOMETRY`; `--floor=2` | `grep GEOMETRY game/floors/*.gd`; switch `office_floor.GEOMETRY` to `office_geometry.gd` in this step |
| 0d | palettes, structural roles 0 start, 9 landing, 10 lobby, 11 corridor, 12 gallery, 19 refuge, 20 void; `FLOOR.palette(manifest)`; `room_dressing` reads `MODULE_SET`, `FUSE_ROOMS`, `ALARM_ROOMS`, `CLOCK_ROOMS`, `FAN_ROOMS` and `prop_factory` reads `SERVICE` through the palette | read the files |
| 0e | `build_room()` split into `floor_surface`, `ceiling`, `walls`, `wall_art`, `room_lamp`, `fittings`, `extras`; `hotel.lit(room_id)`, `set_room_power(room_id, on)`, `drain(room_id, amount)`, `ROOM_LAYERS.put_on_actor()` | read `build_room()`; **where this spec writes `(node, room)` use whatever 0e used** |
| 1a | `office_palette.gd` with the questions of 0.2, the lattice of 4.2, `FURNITURE` of 9.2 and `crawl_boxes()`/`shaft_box()` of 5.6 | read the file; anything missing is added here under these names |
| 1b | `office_generator.gd` manifest (0.1) | dump one manifest (`--floor=2 --seed=81`) and read the keys |
| 1c | `office_validator.validate_physics(world, data)` written, not yet run on a built floor | read it; this step switches it on (11.1 case 21) |

### 0.1 Manifest keys geometry reads (floor 2 only; hotel manifests never carry them)

```text
plenum      = {ceiling: 2.95, slab: 4.4, duct_y: 3.7, main: 1.2, duct: [1.0, 0.8], branch: [w, h]}   # PLENUM, metres over the planta floor py
ducts       = {nodes: [[x, y, z, room, kind], ...]              # world; kind trunk|branch|exit|hatch|main|shaft
               edges: [[a, b, metres, kind], ...]               # kind trunk|branch|bridge|loose|drop|main|cross
               exits: [{node, room, kind, point: [x, y, z], yaw}, ...]}   # kind ceiling|wall|duct|gap
archives    = [{rooms, axis, mobile, open, height, wall_gap, spine, rows, aisles}]   # rects world [x0, z0, x1, z1]
departments = [[{sector, name, colour}], x3]                     # colour: index into PALETTE.STRIPES
power       = {room, board, circuits: [{code, name, sector, colour, lever, rooms}], lift_lever, timers}
mail, tubes, air                                                 # read only for their wall spots and footprints (6.8)
air.shaft   = {point, node, side, rect: [cx, cz, sx, sz], floor_y, ladder: {point, yaw}}
arrival_lift = [dx, dz]                                          # optional
gates[2].kind = "shaft"                                          # no car, no exit door (7.8)
room.height    = PALETTE.height_of(room): 2.95; 3.25 boardroom; 4.4 service corridor, air room, plant
room.glazed    = ["north", ...]                                  # symmetric with the neighbour
room.furniture = [{kind, at: [x, z], turn: 0..3, size: [w, d], extra: {}}]   # room-local, from the cell centre (9.2)
room.sockets   = [[x, z] x 4]                                    # room-local corner sockets of room.props (H8)
room.sector, number, wing, kept, dark, hall, open_sides, doors, props, hides, lift, landing   # as the hotel
```

- **Duct kinds.** The kind of an edge is `edge[3]`; `edge[2]` is its metres. Of a node, `node[4]`; `node[3]` is its room.
- **Wall spot** (generator §2.5): `{wall, along, point, yaw}`. `yaw` faces into the room: `Basis(Vector3.UP, yaw).z` points away from the wall, the `FLOOR.hiding_yaw()` convention.
- **Gaps** (missing tiles) are the `ducts.exits` of kind `"gap"`: exactly one per drawn cell, `roundi(GAP_SHARE[planta] × eligible)` per planta. There is no `room.ceiling` key.
- **Supply or return** is not in the manifest: geometry picks it per ceiling exit with `vary()` (5.2).

### 0.2 Palette questions and constants geometry calls (`office_palette.gd`, defined in generator §1.2, written by 1a, covered by its parity test)

```gdscript
static func height_of(room: Dictionary) -> float
static func false_ceiling(room: Dictionary) -> bool        # height_of(room) < PLENUM.slab - 0.01
static func floor_finish(room: Dictionary) -> String       # "terrazzo" | "tile" | "carpet" | "concrete" | "vinyl"
static func wall_material(room: Dictionary) -> String      # "office_paint" | "block" | "veneer" (rule below)
static func lamp_of(room: Dictionary) -> String            # "troffer" | "batten" | "pendant" | "emergency"
static func plaque(room: Dictionary) -> String             # "P-114"; "" when unnumbered
static func stripe_color(manifest: Dictionary, room: Dictionary) -> Color   # STRIPES[colour] of room.sector's department on its wing
static func zone_label(manifest: Dictionary, room: Dictionary) -> String    # see below
static func hide_kind(room: Dictionary) -> String          # "locker"
const POWER := ["mains", "emergency", "none"]             # battery units only where != "none" (7.2)
const STRIPES, LETTERS, TYPE_LETTERS, PLENUM, FURNITURE_TOP, TILE
const MODULE_SET                                          # values set by 1d (9.5)
const FUSE_ROOMS := []                                    # no fuse boxes on floor 2 (OFICINAS 14 #13; 9.5)
```

- `wall_material`: `"veneer"` for types 5, 16 and 24 on wing 2; `"block"` for roles 11 and 12 and types 4, 7, 8, 14, 18, 22, 23 and 25; `"office_paint"` otherwise.
- `zone_label`: on wing 1 (Registro), `"%s %s" % [code, name]` of the `power.circuits` entry whose `sector == room.sector` ("R-2 ARCHIVO"); on wings 0 and 2, the `name` of the room's sector in `departments[wing]` ("NÓMINAS"); `""` if nothing matches. Spaces only, never "·" or "—".
- `always_lit(manifest, wing)` (generator §1.2, read by 1f and 1g) is not called here: geometry follows `lit()`.
- **Electrical room (18):** false ceiling at 2.95 (no exposed slab), `lamp_of == "emergency"`: no troffers, its room lamp is never powered, its only light is its battery unit (7.2). It is in no circuit.
- **Concrete floors** (types 8, 12, 18, 22, 23, 25) use the material key `concrete_floor` (10.2).

### 0.3 What this step needs the generator to keep (each is checked in 11.1)

1. `plenum.branch` exists. `duct_y - duct[1]/2 >= tallest false ceiling + 0.05` (BOARDROOM at 3.25: trunk bottom 3.3) and `duct_y + main/2 <= slab - 0.05`.
2. Ceiling exits and gaps sit on whole tiles of `PALETTE.free_tiles(room)` (4.2), after the origin shift: `point` is the tile centre at `py + room.height`.
3. The crossing stub is the `cross` edge, with positive length: from the crossing main node to the network end of the stub. With a zero-length `cross` edge there is no stub box (5.6) and 1g builds no stub.
4. `mail.reader` is a wall spot in planta 0's freight lobby (19), beside the stage gate door to the landing (9).
5. `air.shaft.rect`/`floor_y`/`ladder` exist, and the rect overlaps no room (a void cell or an off-grid strip at least 2.2 m deep).
6. `room.furniture` kinds are keys of `PALETTE.FURNITURE`; `room.glazed` is symmetric and only on 3, 16, 24 and 17 against a corridor, never on a wall that holds a wall spot, the gate door, a lift wall or lockers.
7. The physics validator's ceiling band (generator §3.2) leaves out `PALETTE.crawl_boxes(data)` grown by 0.05 (`SLEEVE`): the main duct's collider is on layer 1 and lies inside the band of every 4.4 m room it crosses (the plant always; the air room or a service corridor when the path runs through them).

---

## 1. Files

### Create

| File | What |
|---|---|
| `game/world/office/office_geometry.gd` | `extends "res://game/world/hotel/hotel_geometry.gd"`; sections 4 to 8 |
| `game/world/office/office_props.gd` | static builders for office furniture: corner kinds (9.3), `room.furniture` items (9.2), archive rows (9.4), dressing picks (9.5) |
| `game/world/office/scissor_gate.gd` | the freight car's collapsing gate (7.5) |
| `game/presentation/materials/office/*.tres` | one per key of `OFFICE_MATERIALS` (4.1) |
| `game/presentation/shaders/wired_glass.gdshader` | transparent glass with a 12.5 mm square wire mesh in the shader (RESUMEN: no wired-glass texture exists). 1e reuses it for the window counter |
| `game/presentation/shaders/venetian_blind.gdshader` | slats by alpha scissor on one quad per pane (6.4) |
| `tools/props/build_office_door.gd` | bakes `assets/props/office_door/leaf_vision.res`, `leaf_service.res`, `frame.res` (6.6) |
| `tools/props/build_locker.gd` | bakes the locker skin (9.7) |
| `tools/audio/prepare_office_sfx.py` | working copies of this step's sounds (10.3), same pattern as `tools/audio/prepare_lift_sfx.py` |
| `tests/office/office_geometry_test.gd` | section 11.1 |
| `tools/capture/office_capture.gd` | the shots of 11.3 (1i extends it) |

### Change (each is a no-op for floor 1)

| File | Change |
|---|---|
| `game/world/hotel/hotel_geometry.gd` | hooks H1 to H10 (section 3) |
| `game/world/hotel/room_dressing.gd` | hooks R1 to R4 (section 3) |
| `game/world/hotel/lighting.gd` | `"twin"` arm in `intensity()` (new match arm only) |
| `game/floors/palettes/office_palette.gd` | `MODULE_SET` values (9.5); lattice, `FURNITURE`, `crawl_boxes()`, `shaft_box()` only if 1a did not write them |
| `game/floors/office_floor.gd` | `GEOMETRY := preload("res://game/world/office/office_geometry.gd")` |
| `game/app/lifts.gd` | sound paths from `level.hotel.lift_sounds()`; an empty bell skips its cue (7.6) |
| `game/audio/world_audio.gd` | hum stream from `level.hotel.hum_path()`; hum only from lamps whose room `level.hotel.lit()` (8.4) |
| `game/world/interactables/hiding_place.gd` | optional `skin` (9.7) |
| `tools/props/ingest_models.py`, `tools/props/build_catalogue.gd`, `tools/textures/ingest_pbr.py`, `tools/textures/bake_lite_maps.gd` | office sources and targets (section 10) |
| `tests/office/office_test.gd` | section "física": three seeds built, `validate_physics() == []` (generator §3.5) |
| `tools/verify.ps1` | add `'office/office_geometry_test'` to `$tests` |
| `docs/DEVELOPMENT.md`, `docs/LURKER.md`, `docs/ASSETS.md`, `docs/asset_hashes.json` | section 12 |

### Not built here: the static pieces of each planta's system

Each system step builds its own static geometry. 1d gives them the ingest tooling (10.4), the materials (`galvanized`, `steel_frame`, `enamel`, `steel_olive`, `wired_glass`), the walls already cut for the main duct (5.6), their reserved wall spots kept clear (6.8) and the rules for pieces outside the rooms (8.5).

| Step | Pieces | Assets (registro entries with status "ok", all CC0) | Rules from 1d |
|---|---|---|---|
| 1e | visible pneumatic tube runs along the `tubes` polylines (walls and ceilings at `TUBE_Y`), with brackets; the stations; the window counter with its glass; the ceiling camera stand-in; the card reader at `mail.reader` | equipos `pipes_modular_polyhaven` (Poly Haven Modular Pipes, Kuutti Siitonen) for straight and elbow pieces; primitives for stations, counter and reader; `wired_glass.gdshader` for the counter glass | tube pieces split at room boundaries and each parented to its room's node; no collider between `py + 2.25` and the ceiling (the validator's ceiling band) |
| 1f | the board cabinet and its lever handles; the timer switches; cable runs | equipos `electric_cables_switches_polyhaven` (Poly Haven Modular Electric Cables, Kuutti Siitonen): boxes, conduit, switches; primitives for the board body and levers (`lever_switch_oga` is CC BY 3.0: not used) | same |
| 1g | `main_duct_geometry`: the sheet duct, 1.2 × 1.2 inside, along `air.main` on exactly `PALETTE.crawl_boxes()`, collision layer 1; the crossing stub; the hatch frame and leaf; the plant's access climb from its floor to the hatch; the shaft (walls, floor, ladder); the air handler unit and its fans | equipos `fire_escape_ladder_polyhaven` (Poly Haven Modular Fire Escape, Juniix) for the shaft ladder and the climb; `duct_fans_circular_polyhaven` (Poly Haven Modular Airduct Circular 01, Riley Queen) for the unit's fans and round duct; primitives and `galvanized` for the sheet duct | 8.5 |
| 1g / 1h | the remains in the duct | equipos `human_skull_oga` (OpenGameArt, CDmir) | 8.5 |

Each step adds its rows to `ingest_models.py`'s `OFFICE` table and runs `build_catalogue.gd --office` (10.4); 1d ingests only its own rows (10.1).

---

## 2. Design decisions (why, in one line each)

1. **One shadowed `OmniLight3D` per room, as in the hotel.** `lights[id]` is read by index in a dozen tools and systems (`darkness_capture`, `corridor_look`, `leak_who`, `doors_capture`...), by `round_rooms()`, by `room_layers.assign()` (one lamp per room with `lamp_range(span)`), by the shadow-atlas budget (`lamps_cast`) and by 0e's `lit()`. The troffers are emissive meshes; the light is the room's one omni with the `"tube"` profile. A failing troffer flickers its own lens and moves the room light by its share (8.3).
2. **The false ceiling is the room's ceiling**: `room.height` is 2.95 (3.25 in the boardroom). Every consumer tuned to `room.height` (probes, bounce volumes, `exit_sign()` stems, `route_sign()`, the Lurker's ceiling patch later) gets it without knowing about plenums.
3. **The plenum is never drawn except inside a closed "plenum cell" over each gap** (5.4), on render layer 4 (value 8) that room lamps never light on `static_light`.
4. **One ceiling lattice, world-anchored, in the palette** (4.2): the scanned `officeceiling001` paints its 0.6 m joints at world multiples of 0.6, so the generator (exits, gaps) and geometry (tiles, troffers) use the same tiles. Tiles are merged runs, not 400 instances a room.
5. **No `Decal` carries information** (Compatibility draws none, `decals_drawn()`): marks that mean something (ink round a bent grille) are alpha-scissor cards; decorative grime keeps `room_dressing.decals()`.
6. **Glass partitions and their blinds are fixtures like doors**: built once, owned by the floor root, shown with the nearer of their two rooms and put on both rooms' layers.
7. **The freight lift is the hotel's car with another body**: `build_lifts()`, `in_car()`, `CAR_INSIDE`, `lifts.gd` timings and the leaf protocol stay; only the visual body, the lobby wall and the sounds change. The stage gate (19 to 9) is an ordinary service door; the scissor gate is the car's own leaves.
8. **The crawl spaces are outside every room**: the main duct and the shaft are built by 1g on render layer 4 only, in holders under the geometry root, lit by torches; a body inside carries no room bit (H10). Geometry owns their footprint (`crawl_boxes()` in the palette) and cuts its own walls and pieces round it.
9. **The static fixtures of the plantas are their systems'** (1e to 1g); 1d reserves their wall spots and gives them materials and tooling.

---

## 3. Hooks

Make all of them before any office code; run `manifest_golden_test`, `hotel_test`, `light_layers_scan`, `stages_test`; then continue.

### 3.1 In `hotel_geometry.gd` (H1 to H10)

- **H1 Door meshes.** Add
  ```gdscript
  func leaf_mesh(a: Dictionary, b: Dictionary) -> Mesh: return DOOR_LEAF
  func frame_mesh(a: Dictionary, b: Dictionary) -> Mesh: return DOOR_FRAME
  ```
  Use them in `build()`'s door loop (`leaf.mesh`, `casing.mesh`) and `build_exit_door()`. `light_seal(mesh: Mesh = DOOR_LEAF)` takes the leaf it seals. `door_stop()` keeps `DOOR_FRAME.surface_get_material(0)` unless given a frame. `make_halves()` calls `HALVES.of()` per door with that door's `Leaf.mesh` and casing mesh (`mesh_halves.gd` already caches by mesh) instead of once before the loop.
- **H2 Door plaques.** Extract `build()`'s plaque block (the `for which in 2:` loop, lines 1112-1129) into `func door_plaques(door: Node3D, a: Dictionary, b: Dictionary, center: Vector3, yaw: float) -> void`. Office overrides it (6.7).
- **H3 Navigation radius.** `func nav_agent_radius() -> float: return 0.4`, used in `build_navigation()`. Office returns `0.3`.
- **H4 Bounce exclusion.** In `flush()`, `if room != null and not only_kit and bounces(group): bounce.add(...)`, with `func bounces(group: String) -> bool: return true`.
- **H5 Flicker share.** In `_process()`'s flicker loop: `lamp.light_energy = entry.energy * (1.0 - float(entry.get("share", 1.0)) * (1.0 - level))`. The glow keeps `entry.glow * level` (the failing troffer's lens flickers fully; only the room light moves by its share). Default 1.0 is today's formula. If 0e already multiplies a drain factor here, keep it outermost.
- **H6 Lamp split.** Inside 0e's `room_lamp` step, separate the fixture from the light: `func lamp_fixture(node, room) -> Dictionary` (builds the dome, batten or chandelier visuals; returns `{profile, color, energy, position, specular, tube, failing_material}`) and `func lamp_light(node, room, spec: Dictionary) -> OmniLight3D` (today's lines 1319-1352: range, attenuation, size, bias, projector, fog, fade, `meta room`, `lights.append`, dark handling, `tubes`/`flickers` registration). Office overrides `lamp_fixture` only.
- **H7 Car body split.** Split `build_car()` into `func car_body(car: Node3D, room: Dictionary) -> Array` (lines 1639-1665: model, leaves, call buttons, display, digits; returns the `car_leaves` entries) and the rest (frame, colliders, plan walls, `box_light`). Office overrides `car_body`.
- **H8 Sockets.** In static `prop_transform()`: `if room.has("sockets"): at = Vector3(float(room.sockets[prop.slot][0]), 0, float(room.sockets[prop.slot][1]))`, keeping the turn and the scale that `palette.domestic(room)` gives (0.85 in a domestic room, 1.0 otherwise). Hotel rooms have no key. `prop_transform(room, prop, room_palette: GDScript = null)` takes the palette of the room's floor (0d), and a static cannot be overridden (a subclass static would not be reached), so the callers pass it. The three callers in game/ must pass `FLOOR.palette(manifest)` as the third argument: `document_placement.gd:49`, `hint_placement.gd:355` and `tv_placement.gd:63` (so they pass it since the 0d review). Without it, on a planta of offices, types 1, 2, 3, 4, 7, 15 and 16 are placed with the hotel's domestic table (scale 0.85, corner 4.35) while `build_room()` draws the office's: the paper would not match the furniture. The hotel-only callers in tools/ and tests/ (`catalog_capture`, `props_capture`, `lookdev_capture`, `loop_test`) keep the default.
- **H9 Lift and hum audio.** `func lift_sounds() -> Dictionary` returning `{"close": "res://assets/audio/sfx/lift/doors_close.wav", "open": ".../doors_open.wav", "descent": ".../descent.wav", "bell": ".../bell.wav"}` (move the four paths from `lifts.gd` lines 222-225; the gains stay there), and `func hum_path() -> String: return "res://assets/audio/dread/fluorescent_hum.wav"`.
- **H10 Body layer.** In `follow_bodies()` replace `var bit := layer_at((body as Node3D).global_position + Vector3(0, 0.9, 0))` with `var bit := body_bit((body as Node3D).global_position)`, add `func body_bit(at: Vector3) -> int: return layer_at(at + Vector3(0, 0.9, 0))`, and put the meshes with `ROOM_LAYERS.put_on(mesh, maxi(bit, 0))`. The `bit == 0` skip stays. A negative bit means "on no room's layer": `put_on(mesh, 0)` leaves the body on layer 1 alone, which no kept room lamp lights on `static_light`. The hotel never returns a negative bit, so floor 1 is unchanged. 0e's `put_on_actor()` for the creature (phase 2) goes through `body_bit()` too.

GDScript constraints that shape this design: a subclass cannot redeclare a parent constant or variable (every office constant has its own name), and static functions are not dispatched virtually (hence H8 and the instance hooks).

### 3.2 In `room_dressing.gd` (R1 to R4)

- **R1 Office picks.** `furnish()`'s `_:` branch becomes `_: if not builder.furnish_pick(holder, pick, width, seed_pos, kept, room): <today's body>`, with `func furnish_pick(holder, pick, width, seed_pos, kept, room) -> bool: return false` in `hotel_geometry.gd`. No early return: the wall-clock and fuse-box code after the `match` still sees the pick. Office picks are not `CONTAINERS` (there is no code on floor 2).
- **R2 Stretches.** In `dress()`: `for stretch in builder.wall_stretches(room):`, with `func wall_stretches(room: Dictionary) -> Array: return DRESSING.stretches(room, palette)` in `hotel_geometry.gd`, where `palette` is the geometry's member (set in `build()`, 0d). Office overrides it (9.5).
- **R3 Fuse boxes.** Guard the block after the `match` (lines 363-365) with `builder.fuse_boxes()`, `func fuse_boxes() -> bool: return true` in `hotel_geometry.gd`; office returns `false`. Then no office room is a panel spare, `panel_spares` stays empty and `fuse_boxes_left()` does nothing. `FUSE_ROOMS == []` in the office palette as well.
- **R4 Decals.** `decals()` skips walls in `room.get("glazed", [])` (absent on the hotel).

---

## 4. `office_geometry.gd`: skeleton

```gdscript
extends "res://game/world/hotel/hotel_geometry.gd"
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const PROPS := preload("res://game/world/office/office_props.gd")
const GATE := preload("res://game/world/office/scissor_gate.gd")
const OFFICE_DOOR := "res://assets/props/office_door/"
```

### 4.1 Constants (starting values; metres unless said)

```gdscript
const PLENUM_LAYER := 8            # render layer 4: plenum cells, main duct, shaft (camera mask 1048573 includes it)
const TILE_THICK := 0.015
const TILE_FACE := 0.004           # tile face over the grid flange's underside
const TEE := Vector3(0.024, 0.004, 0.032)    # flange width, flange thickness, web height
const WALL_ANGLE := 0.022          # perimeter L trim
const TROFFER := Vector2(0.6, 1.2)
const TROFFER_BODY := 0.11         # housing depth over the tiles
const LENS_RECESS := 0.012
const LAMP_ENERGY := 3.6           # x LIGHTING.PROFILE_GAIN, as the hotel's dome
const LAMP_ATTENUATION := 0.9      # flatter than the hotel's 1.25: offices are evenly lit
const LAMP_DROP := 0.35            # omni under the ceiling, as the batten's
const FAILING := 0.12              # share of lit rooms with one failing troffer (vary salt 160)
const SUPPLY := 0.5                # share of ceiling exits drawn as supply diffusers (salt 168), the rest return grilles
const BENT := 0.08                 # x room.kept: share of grilles bent outwards (salt 165)
const HANG_ANGLE := Vector2(0.6, 1.2)   # radians, a hanging tile's drop range
const HANGING := 0.4               # share of gaps with the tile hanging (salt 161)
const FALLEN := 0.5                # share of gaps with the tile on the floor below (salt 162)
const PLENUM_REACH := 1.2          # half side of a plenum cell
const TRAY := Vector2(0.3, 0.06)   # cable tray width, side height
const TRAY_DROP := 0.22            # under the slab
const SLEEVE := 0.05               # clearance kept round a crawl box (5.6)
const CRAWL_PAD := 0.1             # crawl_space() tolerance, as spec_f1_systems' crawling_at padding
const GRILLE_FACE := 0.575         # a 60x60 grille's visible face in its tile
const WALL_GRILLE := Vector2(0.45, 0.25)     # width, height of a low wall grille (centre at the exit's y)
const GLASS_SILL := 0.95
const GLASS_HEAD := 2.65           # = OPENING_HIGH: transom line at door heads
const MULLION := 0.05
const MULLION_PITCH := 1.2
const GLASS_THICK := 0.008
const BLIND_PITCH := 0.022
const STRIPE := Vector2(1.05, 1.20)        # bottom and top of the department stripe
const STRIPE_SILL := Vector2(0.80, 0.92)   # the stripe on a glazed run, under the glass
const STRIPE_PROUD := 0.003
const SKIRT := Vector2(0.10, 0.006)        # cove base: height, thickness
const PLAQUE := Vector2(0.26, 0.09)
const PLAQUE_Y := 1.55
const PLAQUE_FROM_JAMB := 0.22
const SWITCH_Y := 1.15
const RESERVE_HALF := 0.6          # half width kept clear round a wall spot (desk, board, unit: 0.9)
const EMERGENCY_Y := 2.45
const EMERGENCY_REACH := 18.0
const EMERGENCY_CAST := 6
const EMERGENCY_CAST_COMPAT := 3
const EMERGENCY_ENERGY := 1.4
const EMERGENCY_RANGE := 9.0
const EMERGENCY_ANGLE := 55.0
const EMERGENCY_KELVIN := 2400.0
const AMBER_TINT := Color(1.0, 0.78, 0.45)
const FREIGHT_OPENING := Vector2(1.7, 2.3)  # fits CAR_INSIDE: the doorway's x is centred on 0, the car's inside ends at +0.893
const GATE_SHUT_X := 0.85
const GATE_OPEN_X := -0.62
const GATE_FIXED_X := -0.85
const NAV_RADIUS := 0.3
const FLOOR_MATERIAL := {"vinyl": "vct", "terrazzo": "terrazzo", "carpet": "carpet_tile", "concrete": "concrete_floor", "tile": "tile"}
const NO_SHADOW := ["tgrid", "troffer_body", "troffer_lens", "lens_off", "diffuser", "skirting", "plaque", "emergency_lens", "emergency_off", "ink_stain"]   # plus every "stripe_*" and "troffer_fail_*"
const OFFICE_MATERIALS := ["tgrid", "troffer_body", "troffer_lens", "lens_off", "plenum_slab", "plenum_dark", "plenum_duct", "plenum_tray", "galvanized", "diffuser", "grille_metal", "steel_frame", "wired_glass", "blind", "office_paint", "block", "veneer", "vct", "terrazzo", "carpet_tile", "concrete_floor", "partition_fabric", "cork", "cardboard", "skirting", "stripe", "plaque", "enamel", "emergency_lens", "emergency_off", "gate_steel", "cage_mesh", "steel_plate", "ink_stain", "steel_olive", "laminate", "bottle"]
```

Every size of the plenum (`ceiling`, `slab`, `duct_y`, `main`, `duct`, `branch`) is read from `manifest.plenum`; geometry has no fallback and no duct size of its own. Stripe materials are one per `OFFICE.STRIPES` index: `stripe_<i>`, made in `_init()` as duplicates of `stripe` with `albedo_color = STRIPES[i]`.

### 4.2 The ceiling lattice (static, in `office_palette.gd`; one rule for the generator and geometry)

```gdscript
const TILE := 0.6
const TROFFER_PITCH := 3.0
const WALL_HALF := 0.09
const GRILLE_CLEAR := 0.9          # a ceiling exit or a gap keeps this far from every troffer centre
const GRILLE_WALL := 1.0           # and, outside corridors, this far from every walled side
## World lattice: tile (i, j) covers x in [i*TILE, (i+1)*TILE], z in [j*TILE, (j+1)*TILE].
## The ceiling rectangle (world xz): the cell less WALL_HALF on every side not in open_sides.
static func ceiling_rect(room: Dictionary) -> Rect2
## Whole tiles inside ceiling_rect(): i from ceili(x0 / TILE) to floori(x1 / TILE) exclusive, j likewise.
static func full_tiles(room: Dictionary) -> Rect2i
## Troffers, [] unless lamp_of(room) == "troffer". Each {"tiles": [Vector2i, Vector2i], "along_z": bool, "centre": Vector2}.
static func troffers(room: Dictionary) -> Array
## Whole tiles that are no troffer tile, whose centre is at least GRILLE_CLEAR from every troffer centre and,
## for every role but corridor (11), at least GRILLE_WALL from every walled side of ceiling_rect().
static func free_tiles(room: Dictionary) -> Array[Vector2i]
static func tile_of(point: Vector3) -> Vector2i        # Vector2i(floori(point.x / TILE), floori(point.z / TILE))
static func tile_centre(tile: Vector2i, y: float) -> Vector3   # ((i + 0.5) * TILE, y, (j + 0.5) * TILE)
```

`troffers(room)`: the long axis L is the longer side of `ceiling_rect()` (x on ties); a troffer's 1.2 m side lies along L. Per axis with rect start `s` and length `len`: `n = maxi(1, roundi(len / TROFFER_PITCH))` and ideal centres `c_k = s + len * (k + 0.5) / n`. Along L the troffer takes tiles `t` and `t + 1` with `t = roundi(c_k / TILE) - 1` (its centre on a lattice line); across, tile `floori(c / TILE)`; both clamped into `full_tiles()`; duplicates dropped. That gives 3 × 3 in an 8 m module, 4 × 4 in a 12 m one and one line along a 2.4 m lane.

Why world-anchored: `face_uv()` returns `(wp.x, -wp.z)` on a down-facing face; `map_metres 3.6` and the 6 × 6 tile picture put a joint every 0.6 m from the world origin. Merged cells (corridors, salons) continue the lattice across their boundary with no seam. Each cell draws lattice lines with coordinate in `[min, max)` so a line on a shared boundary is drawn once. Room edges fall off the lattice (modules of 9 and 11 m, lanes of 2.4 to 3.0 m): the edge rows and columns are cut tiles, never exits.

The functions read only the room dictionary (`px`, `pz`, `span_x`, `span_z`, `open_sides`, `type`, `wing`), no geometry, so the generator and the validator call them without loading `office_geometry.gd`.

### 4.3 Variables

```gdscript
var plenum := {}                    # manifest.plenum
var building_room := {}             # the room build_room() is on
var exits_of := {}                  # room id -> Array of its ducts.exits entries
var pieces_of := {}                 # room id -> Array of [a: Vector3, b: Vector3, kind] duct segments touching it (5.5)
var reserved := {}                  # room id -> Array of {point: Vector3, normal: Vector3, half: float} (6.8)
var crawl: Array[AABB] = []         # OFFICE.crawl_boxes(manifest)
var shaft := AABB()                 # OFFICE.shaft_box(manifest)
var outside: Array[Dictionary] = [] # {node, planta}: holders outside every room (8.5)
var lens_of := {}                   # room id -> MultiMeshInstance3D "Mesh_troffer_lens" (after flush)
var lens_materials := {}            # room id -> its own duplicate of troffer_lens, made on first drain
var battens_of := {}                # room id -> Array of "Model_mounted_fluorescent_lights*" instances
var glass: Array[Dictionary] = []   # {node, rooms: [a, b], spot, planta, bits, blinds}
var glass_bodies: Array[RID] = []   # for sight queries that must see through glass (phase 2)
var emergency: Array[Dictionary] = []  # {light: SpotLight3D, room, spot, planta, lens: room id}
var emergency_state := PackedByteArray()
var plenum_cells: Array[Dictionary] = []  # {room, centre (world), size} for tests and the Lurker's shell
var poster_spots: Array[Dictionary] = []  # {room, transform} free wall spots for 1h's rule posters
```

### 4.4 `_init()`

`super._init()` (loads the hotel's `MATERIALS`), then for each key in `OFFICE_MATERIALS`: `load("res://game/presentation/materials/office/%s.tres" % key).duplicate()`, `set_meta("lite", key)`, `apply_scan(m, small_maps)`, store in `materials`; then the `stripe_<i>` duplicates. Generate once (static vars) three small procedural `ImageTexture`s: the prismatic lens pattern (64 px, little pyramids), the cage's expanded-metal diamond (alpha) and the ink splatter (alpha); assign them to `troffer_lens`/`lens_off` (emission and albedo, `uv1_triplanar` world, scale 1/0.02), `cage_mesh` and `ink_stain` (alpha scissor 0.5). Keep `troffer_lens`, `emergency_lens` and the battens' glass as `StandardMaterial3D` with `emission_enabled`: `held_glows()` only finds `BaseMaterial3D`, so a `ShaderMaterial` lens would stay lit through a `blackout()`. Make `emergency_on` (amber emission 2.2) a member, not in `materials`, so blackout never touches it. `ceiling_damp`: a duplicate of the hotel's `ceiling_service` with `stains 1.0` and a darker `stain_color`.

### 4.5 `build(data)` override

```gdscript
func build(data: Dictionary) -> void:
	prepare(data)            # plenum, crawl, shaft, exits_of, pieces_of, reserved (all from the manifest)
	await super.build(data)
	after_build()            # glass and emergency spots, emergency_state, power off for lamp_of == "emergency"
```

`prepare()` runs before any room is built because walls (5.6), dressing (6.8) and plenum cells (5.4) read its indices.

---

## 5. Floor, ceiling, plenum, crawl spaces

Override 0e's steps; keep the room in `building_room` (override `build_room()`: `building_room = room; super(node, room); building_room = {}`).

### 5.1 `floor_surface(node, room)`

As the hotel's (a 0.3 m solid slab under the cell), material `FLOOR_MATERIAL[OFFICE.floor_finish(room)]`. Toilets keep the hotel's `"tile"`.

### 5.2 `ceiling(node, room)`, rooms with a false ceiling (`OFFICE.false_ceiling(room)`)

1. **Collider**: `box(node, Vector3(0, h + TILE_FACE + 0.025, 0), Vector3(span.x, 0.05, span.y), "", true)` with `h = room.height`. The Lurker's hands (`lurker_limbs.gd`, `world_mask`) and every physical ray need a ceiling.
2. **Holes**: troffer tiles (`OFFICE.troffers(room)`), the tile of each `"ceiling"` exit and the tile of the room's `"gap"` exit (`OFFICE.tile_of(point)`).
3. **Tile runs**: for each lattice row `j` crossing `OFFICE.ceiling_rect(room)`, walk `i` across it; emit one `box(node, centre, Vector3(run_length, TILE_THICK, row_depth), "ceiling_service")` per maximal run between holes, clipped to the rect (edge rows and columns are cut tiles). Face at `h + TILE_FACE`. `ceiling_service` is the hotel's (`ceiling.gdshader`, scan `officeceiling001`, `map_metres 3.6`, `stains 0.8`): its blotches are the water stains. Rooms with `kept >= 1` get 1 to 3 single-tile runs in `ceiling_damp`, picked by `vary(tile_centre, 163)`.
4. **T-grid**: one flange box per lattice line inside the rect (`TEE.x` wide, `TEE.y` thick, bottom at `h`) plus a web box above it (`TEE.z` tall, 6 mm thick), material `tgrid`. Lines at open sides stop at the cell edge (half-open rule). Perimeter `WALL_ANGLE` L trim along each walled side.
5. **Troffers**: housing box `troffer_body` (0.6 × `TROFFER_BODY` × 1.2) over the two tiles; lens box `troffer_lens` (0.56 × 0.01 × 1.16) recessed `LENS_RECESS`; a 1.5 cm white flange ring of four thin boxes. Dark rooms (`dark_room(room)`) use `lens_off`, like the hotel's `light_off` dome. A failing room (`vary(node.position, 160) < FAILING` and not dark) gives one troffer, picked by `vary(..., 164)`, its own key `"troffer_fail_%d" % flickers.size()` = `materials.troffer_lens.duplicate()` (the hotel's `tube_%d` pattern, lines 1279-1283).
6. **Ceiling exits** (`exits_of[id]`, kind `"ceiling"`), on the tile of `point`: `vary(tile centre, 168) < SUPPLY` is a supply diffuser, a `diffuser` box (0.595 × 0.02 × 0.595; the `air_vent` scan with `map_metres 0.6`) with three stepped `grille_metal` frames; otherwise a return grille, a frame plus 12 louvres (`grille_metal`, turned 0.6 rad like `grille()`, lines 264-271) over a `black` box 0.15 deep (the dark of the duct, as in the hotel's grille). A grille with `vary(centre, 165) < BENT * room.kept` is **bent**: face hinged down 0.35 rad on one edge, two louvres missing, an `ink_stain` card (1.0 × 1.0, alpha scissor, 2 mm under the tiles) round it.
7. **Smoke detector and sprinkler**: override `ceiling_fittings()` to put them on the first two `OFFICE.free_tiles(room)` not used by an exit or the gap, sorted by `vary`, not at the hotel's fixed corner offsets.

### 5.3 `ceiling(node, room)`, rooms without a false ceiling (service corridors 12, air room 22, plant 23)

The hotel's slab box at `room.height` in `plenum_slab`, lit normally (these rooms are on layer 1 like any other). The network ducts that cross the room are drawn whole (5.5), one cable tray along the room's long axis at `slab - TRAY_DROP`, hangers every 1.5 m (6 mm rods); everything clipped round the crawl boxes (5.6). None of it has a collider (the validator's ceiling band). `"duct"` exits (5.5) open under the ducts. Lamp: battens (7.1).

### 5.4 Gaps and plenum cells

One per `"gap"` exit of the room (the generator writes at most one per cell, so no merging and no cap):

- **The hole.** With `vary(centre, 161) < HANGING` the tile hangs: a tile box rotated about the edge picked by `vary(..., 166)` by `lerp(HANG_ANGLE.x, HANG_ANGLE.y, vary(..., 167))`; its lowest point stays over 2.3 m; no collider. With `vary(..., 162) < FALLEN` a whole tile (or two halves) lies on the floor below, turned at random: a box 0.6 × 0.015 × 0.6, no collider (under 30 cm, like the hotel's litter).
- **The plenum cell**, under a holder `Node3D` named `Plenum_<i>_<j>` child of the room node, its square of half side `PLENUM_REACH` round the tile centre clipped to `OFFICE.ceiling_rect(room)`: a top `plenum_slab` box at `plenum.slab` (0.2 thick); four side panels `plenum_dark` from `room.height + TILE_FACE` to `plenum.slab` on the square's sides (0.05 thick); whatever network duct, boot or tray of the room passes within the square, clipped to it (5.5); two hanger rods. All groups `plenum_*`. Panels and pieces are cut round the crawl boxes (5.6); the main duct itself, seen through the hole, is 1g's.
- Record `{room, centre, size}` in `plenum_cells`.
- The cell's boxes batch with the room and so carry its `room_data` (its height); they sit above it, where `room_edge()` grime means nothing: give the `plenum_*` materials `grime 0`.

The side panels keep light and sight from running through the undrawn plenum into another room's hole: light that enters a hole lights its cell and nothing else.

### 5.5 Network ducts (generator §2.5f schema)

`prepare()` fills `pieces_of`: for every edge whose `edge[3]` is `trunk`, `branch`, `bridge` or `loose`, the segment between its two node points, clipped to the footprint of each room it crosses (`ROOM_LAYERS.rect_of(room)`), filed under that room. Every such edge is horizontal at `py + duct_y`, axis-aligned and joins grid-adjacent cells (validator group 11), so a segment touches two rooms.

- **Section**: `trunk` edges use `plenum.duct` (w × h); `branch`, `bridge` and `loose` use `plenum.branch`. A box centred on the segment, lengthened by half its width at each end so elbows and tees close.
- **Drop edges** (`edge[3] == "drop"`, from an exit node to its cell's node): a boot, vertical from the exit up to the duct's underside, then a `plenum.branch` run at `duct_y` to the cell node. For `"ceiling"` exits it starts over the grille's black box; for `"wall"` exits nothing is drawn (it is inside the wall).
- **Where it is drawn**: over a false-ceiling room only the parts inside one of its plenum cells (`plenum_duct`, layer 4); over an exposed room the whole clipped segment (`galvanized`, lit, casts shadows). `main` and `cross` edges and the `hatch`/`shaft` nodes are never drawn here (1g).
- **`"wall"` exits**: a low wall grille (`WALL_GRILLE`, the hotel `grille()` shape) centred on `point`, on the face of the wall behind it: the walled side opposite `Basis(Vector3.UP, yaw).z`, which must be the side nearest `point` (11.1 case 6), black box behind.
- **`"duct"` exits** (rooms of 4.0 m or more): a boot from the duct's underside down to `point.y`, ending in a 0.6 × 0.6 return grille facing down.
- No piece of this section has a collider.

### 5.6 Crawl spaces (the main duct and the shaft)

The palette holds the one definition, used by geometry, the validator and 1g (`crawling_at()`, the crouched-capsule test and the bots' route all use these heights):

```gdscript
## The inside of the crawlable main duct, world, unpadded: one box per "main" and "cross" edge of
## manifest.ducts, from node to node, plenum.main wide and tall, its floor at the nodes' y - main / 2
## (= py + duct_y - main / 2), lengthened by main / 2 at each end so elbows and the stub close.
## A zero-length "cross" edge gives no box.
static func crawl_boxes(manifest: Dictionary) -> Array[AABB]
## The shaft's standing room: air.shaft.rect from air.shaft.floor_y up to py + duct_y + main / 2.
static func shaft_box(manifest: Dictionary) -> AABB
```

What 1d does with them:

- **`crawl_space(at: Vector3) -> int`** (instance, office): 1 inside a crawl box grown by `CRAWL_PAD`, 2 inside `shaft` grown by `CRAWL_PAD`, else 0. 1g's `air.crawling_at(point)` should be `level.hotel.crawl_space(point) == 1`, so there is one test.
- **Walls**: in rooms taller than a crawl box's floor (the 4.4 m rooms on the main path: always the plant, often the air room, sometimes a service corridor), every `wall_core` piece and every `blocker()` quad that a crawl box crosses is cut round the box's section grown by `SLEEVE`: a rectangle difference in the boundary's (x, y) plane, up to four pieces each (`func cut_core(boundary, pos, size, inner)`, `func cut_blocker(frame, pos, size)`). False-ceiling rooms' walls stop at their height, under every crawl floor, and are never cut. `plan_wall()` is unchanged (the plan is at floor level).
- **Pieces**: every 1d piece above `py + 2.25` (network ducts, boots, trays, hangers, battens, plenum panels and slabs) is clipped against the crawl boxes grown by `SLEEVE`: ducts and trays are split along their run; panels by rectangle difference; hangers and battens are moved along their run in 0.6 m steps until clear, else dropped.
- **The exposed slab** of a 4.4 m room (the hotel's slab box, underside at `py + 4.4`) is over the duct's top (`py + 4.3` plus the sheet): untouched.
- **Navigation**: 1g builds the duct after `build_navigation()`, and 1.2 m is under `agent_height 1.8`: the crawl is never in the navmesh. 1g's bots follow a scripted route along the crawl boxes' centre lines at their floor height.

---

## 6. Walls, glass, doors, plaques, reserved spots

### 6.1 `walls(node, room)` override

Copy the structure of the hotel loop (lines 1168-1231): per direction, `FLOOR.beside()`, open pairs skip with the `room_edge` bits, the lift wall branch, doorway `door_at` from `FLOOR.door_offset()`, `JAMB_GAP`. Differences:

- Each straight stretch calls `office_run(boundary, x, length, height, inner, glazed)` instead of `wall_run()`.
- Header over a doorway: `cut_core(boundary, Vector3(door_at, (height + OPENING_HIGH) / 2, 0), Vector3(FLOOR.PORTAL + JAMB_GAP * 2, height - OPENING_HIGH, 0.18), inner)` (0.30 m at 2.95), no cornice.
- Light switch beside the casing (same side rule as lines 1209-1215) via a `switch_plate()` override: beige plastic rocker plate 0.08 × 0.12 at `SWITCH_Y`, skipped within `RESERVE_HALF` of a reserved spot.
- No paintings, no sconces: `wall_art()` override (6.5).
- `glazed = room.get("glazed", []).has(side)`, side "west"/"east"/"north"/"south" for direction (-x, +x, -z, +z).

### 6.2 `office_run(boundary, x, length, height, inner, glazed)`

- **Not glazed**: `cut_core()` (5.6; with no crawl box it is the hotel's `wall_core()`: collider the whole 0.18, this room's half drawn, occluder quad) with `wall_material = OFFICE.wall_material(room)`; cove base `skirting` box (`SKIRT`) on the inner face; `plan_wall()` as `wall_run()` does.
- **Glazed**: sill `wall_core` from 0 to `GLASS_SILL`, head `wall_core` from `GLASS_HEAD` to `height`; **no occluder quad** between them (`box(..., "", true)` for the collider and the halves with `box()` directly; `blocker()` only for sill and head); the glass band's collider comes from 6.3. `plan_wall()` still records the stretch.
- **Corridor rooms** (roles 11 and 12): a stripe box `stripe_<i>` (`i` = the colour index behind `OFFICE.stripe_color(manifest, room)`) on the inner face, `STRIPE` (or `STRIPE_SILL` on a glazed run), `STRIPE_PROUD` off the paint, the length of the run. Once per corridor cell, on its longest plain run clear of reserved spots, `text()` the `OFFICE.zone_label(manifest, room)` on the stripe (size 30, ink `Color("f1ead8")`, reach `NUMBER_REACH`). The colour comes from the room's sector, so every zone of a planta has its own.

### 6.3 Glass partitions

Built only by the room with the lower id of the pair (`plan_wall`'s dedupe idea), from `office_run` when `glazed` and `room.id < neighbour`:

- A holder `Node3D` "Glazing_<a>_<b>" **child of the geometry root** (it must not hide with one of its rooms), transform = the boundary's world transform.
- Mullions `steel_frame` every `MULLION_PITCH` and at both ends, head and sill rails; panes `wired_glass` (`GLASS_THICK`) between them, `cast_shadow` off.
- Collider: one `StaticBody3D` "Glass" (collision layer 1, mask 0) with one box per pane band; append its RID to `glass_bodies`. Layer 1 keeps it a wall for movement, the navigation bake (`geometry_collision_mask = 1`), the validator's rays (`map_validator.gd` masks 1 and 1|8) and route-based hearing (nothing passes walls: `docs/AUDIO.md`).
- Bounce: shut it in both rooms' stand-ins as `build()` does for doorways (lines 1068-1070): `bounce.add(room_nodes[r].get_instance_id(), "door", [slab])` for each pane band.
- Append `{node, rooms: [a, b], spot: world centre, planta}` to `glass`.

### 6.4 Venetian blinds

On each pane, on the side facing the room that is not a corridor (blinds hang on the office side): a headrail box (`steel_frame`, 0.04 × 0.04) under `GLASS_HEAD`, and one `QuadMesh` per pane with `venetian_blind.gdshader`: uniforms `pitch = BLIND_PITCH`, `open` 0..1 (gap fraction), `tilt`, `drop` (how far down the blind comes), all from `vary(pane_centre, 170..173)`: roughly a third fully down and shut, a third down and open, a third raised to a 0.25 m stack. Slats discard by `ALPHA_SCISSOR_THRESHOLD`; the material is double sided, casts shadows (light through the gaps in Forward+), and draws in Compatibility. Phase 2 reads `open` for sight: keep per-pane values in the `glass` entry (`blinds: [{open, drop}]`).

### 6.5 `wall_art()` override

On plain runs of 3 m or more, clear of reserved spots, by `vary`: a cork notice board (`cork` face, `steel_frame` edge, 1.2 × 0.9 at 1.5 m) in offices and corridors near doors; the hotel's `wall_clock` model (its hands turn with `tell_time()`) in offices, break room and archive; otherwise a `poster_spots` entry (1h puts the rule posters there). Nothing over a glazed run.

### 6.6 Doors

H1 hands the leaf and frame per pair:

- `leaf_service.res` (steel, panic bar) when either room is a service room (`room.service`), the electrical room, the air room or the plant, and for the **stage gate doors**: the 19 to 9 pair of plantas 0 and 1 (`gate_stage(data, a, b) > 0`). The gate is an ordinary hotel gate door in every other respect (locked, `gate_stage`, `open_gates()`).
- `leaf_vision.res` otherwise: flush painted leaf with a wired-glass vision panel 0.2 × 0.6 from 1.15 to 1.75.
- `frame.res`: pressed steel.

`tools/props/build_office_door.gd` bakes them procedurally (`SurfaceTool`) with **the hotel leaf's conventions and size**: hinge at the origin, leaf along +X, floor at y 0, centred on its thickness, the same AABB as `door_leaf.res` within 2 mm (so `light_seal()`, the leaf's collision box `Vector3(FLOOR.LEAF_WIDTH, 2.58, 0.07)`, `hotel_door.gd`'s swing and `mesh_halves` work unchanged); frame centred on the doorway, opening `FLOOR.PORTAL` × `OPENING_HIGH` (2.65). The vision panel is a separate surface with `wired_glass`. The seal slab still fills the leaf, so no light crosses a shut door through its glass (accepted; the hotel's no-leak guarantee wins).

### 6.7 Plaques (H2 override)

For each side of the door whose room behind has `OFFICE.plaque(behind) != ""`: on the **wall** of the room that side faces, latch side, `PLAQUE_FROM_JAMB` past the casing: a `plaque` box (`PLAQUE`, dark green laminate, 4 mm) at `PLAQUE_Y`, and `text()` with the plaque string (size 20, `NUMBER_REACH`, ink `Color("e8e4d6")`), both parented to that room's node so they batch and layer with it. If the latch side has less than 0.4 m of wall or a reserved spot within `RESERVE_HALF`, use the hinge side. Corridors and unnumbered rooms get none. The format `%s-%d` cannot produce "·" or "—".

### 6.8 Reserved spots

`prepare()` walks `manifest.mail`, `manifest.power`, `manifest.air` and `manifest.tubes.exits` recursively and files every dictionary with both `point` and `yaw` as a reserved spot: `room` from its own `room` key if it has one, else `FLOOR.room_at(rooms, point)`; `normal = Basis(Vector3.UP, yaw).z`; `half = 0.9` for keys `desk`, `board`, `unit` and `stop`, else `RESERVE_HALF`. This catches `mail.desk`, `mail.map`, the hub, `mail.reader`, the stations, `power.board`, every timer, `air.security.desk` (the console), the post reader, the unit, its stop and the hatch, whatever their final names, as long as they are wall spots or points. `arrival_lift` reserves the middle 3 m of its wall.

Nothing of 1d stands within `half` of a reserved spot along its wall, from the floor to `py + 2.25`: dressing stretches (9.5), wall art and poster spots (6.5), plaques (6.7), switch plates (6.1), emergency units (7.2), zone labels (6.2). Under the hatch, the floor square of 1.5 m round `air.hatch.point` is kept clear for 1g's climb.

---

## 7. Lamps, emergency lights, freight lift

### 7.1 `lamp_fixture(node, room)` override (H6)

| `lamp_of` | Fixture | Light spec |
|---|---|---|
| `troffer` | troffers already built by `ceiling()` (5.2) | profile `LIGHTING.profile("tube")`, colour `LIGHTING.light_color(LIGHTING.FLUORESCENT, LIGHTING.TUBE_TINT)`, energy `LAMP_ENERGY * PROFILE_GAIN`, position `(0, height - LAMP_DROP, 0)`, specular 0.45, `tube: true` |
| `batten` | `mounted_fluorescent_lights` models (10.1) on chains at `minf(height - 0.6, 2.9)`: in archives one per narrow aisle per cell, over the aisle's centre line (`archives[].aisles`); elsewhere 1 to 4 along the long axis | as troffer, energy × 0.85 |
| `pendant` | boardroom: two procedural opal-globe pendants on rods over the table | profile `"dome"`, `LIGHTING.light_color(3000.0)` |
| `emergency` | none (the electrical room's battery unit, 7.2, is its light) | the lamp is still made (`lights[id]` must exist): invisible, `meta off`, and its room is unpowered from `after_build()` (`set_room_power(id, false)`); 1f never powers it |

`lamp_light()` (unchanged hotel code) then sets range from `ROOM_LAYERS.lamp_range(span)`, attenuation (office overrides after the call: `LAMP_ATTENUATION`), shadows, fade, `tubes` (every troffer and batten room hums; this `tubes` is the hotel's list of humming lamps, not the manifest's pneumatic `tubes`), and the flicker entry. For the failing troffer add `"share": 1.0 / troffers.size()` and `"material": materials["troffer_fail_%d" % k]` to the entry (H5).

### 7.2 Emergency lights (twin-head battery units)

Built in 0e's `extras` step for rooms with roles 9, 10, 11 and 12 and for the electrical room, on wings where `OFFICE.POWER[wing] != "none"` (plantas 0 and 1; Dirección has none), one per cell, on the plain wall run nearest the cell middle that is not glazed and has no reserved spot within `RESERVE_HALF`: body `enamel` box 0.32 × 0.18 × 0.10 at `EMERGENCY_Y`, two heads (cylinders r 0.035, 0.08 long, turned 35° down and ±30° out), lenses `emergency_off` (per-room batch, swapped to `emergency_on` with `material_override`), a 4 mm red charge pip (a `MeshInstance3D` with a member material, not batched and not in `materials`, so `blackout()` leaves it lit). Light: **one `SpotLight3D`** per unit, along the wall, 35° down, `spot_angle EMERGENCY_ANGLE`, range `EMERGENCY_RANGE`, energy `EMERGENCY_ENERGY`, colour `LIGHTING.light_color(EMERGENCY_KELVIN, AMBER_TINT)`, `light_projector = LIGHTING.profile("twin")` (new arm in `lighting.intensity()`: two lobes 30° either side of forward, nothing behind), `light_bake_mode = BAKE_DISABLED`, `meta own_room`, `meta room`, invisible at build. Append to `emergency`.

Lit when: not `lit(room)` (0e), and within `EMERGENCY_REACH` (override `round_lamps()`: `super()` then this loop, from `round_at`). Shadows: the nearest `EMERGENCY_CAST` (`EMERGENCY_CAST_COMPAT` on `gl_compatibility`) cast with their profile; past those, if `layered` they fill without shadow on their room's mask (`kept_in()` already returns true for `own_room` lamps when layered: same as `set_sconce()`, lines 2968-2982), else they are off: an unshadowed lamp shines through walls. On `static_light`, `light_lamp()` handles them like every kept lamp. They are kept lamps through `lay()` (children of a room's wall boundary); in the `assign_layers()` override set `kept_lamps[id].looked_after = true` for each, as the hotel does for its own lists (lines 2067-2068), or every `apply_quality()` would reset their shadow behind the round's back. `put_away()` hides other plantas' units. Their lens follows the light.

### 7.3 Power hooks

Override 0e's `set_room_power(room_id, on)` and `drain(room_id, amount)`: `super(...)`, then:

- lens: power off or dark → `lens_of[id].material_override = materials.lens_off`; on → `null`; drain → the room's own duplicate in `lens_materials[id]` (made on first use) with `emission_energy_multiplier = base * (1 - amount)`; batten rooms do the same on their `battens_of[id]` instances;
- desk lamps (practicals of that room: `office_props` sets `meta room` on `practicals.back()` after each `builder.practical()`): hidden with the power. `round_lamps()` re-shows practicals by distance every pass (lines 2933-2937), so unless 0e's `set_room_power` covers them, the office `round_lamps()` override hides, after `super()`, every practical whose room is not `lit()`;
- emergency units of that room become eligible; `round_lamps()` lights them on its next pass.

Override `blackout(on)`: `super(on)`, then every per-room lens duplicate to 0 and back; emergency units are left to `round_lamps()` (battery, like `exit_lamps`). Which rooms 1f and 1g keep powered (`always_lit`) is theirs; geometry only follows `lit()`.

### 7.4 Freight car body (H7 override `car_body(car, room)`)

The car stands behind the lift wall of the landing (9); the stage gate door (6.6) is between the freight lobby (19) and that landing. Inside `CAR_INSIDE` exactly (the hotel constants, so `in_car()`, `lifts.gd`'s riding, arrivals and `room_layers.car_rect()` are untouched): checker `steel_plate` floor 0.02; side and back walls in two bands, `steel_plate` sheet to 1.1 m and `cage_mesh` (alpha-scissor expanded metal, double sided) to `CAR_INSIDE.end.y`; roof `steel_plate`; corner posts `gate_steel`; a bulb in a wire guard under the roof (emissive sphere r 0.05 and four 4 mm rods). No call buttons, display or digits. One scissor gate (7.5) at z = -0.03, which is the car's leaves; return `[{"node": gate, "shut": GATE_SHUT_X, "open": GATE_OPEN_X}]`. The lamp stays the hotel's `box_light()` (`car_lamps`, never out), made after `car_body()` by the common part, so warm it in an override of `build_car()`: `var at := super(room, facing); car_lamps.back().light_color = LIGHTING.light_color(2700.0); return at`.

Layers: `lay()` gives the lobby's bit only to a `GeometryInstance3D` that itself carries `meta lobby_side` (lines 2075-2083), so set that meta on every mesh the gate makes (stile, handle, lattice), not on the gate node.

### 7.5 `scissor_gate.gd`

```gdscript
extends Node3D
## The car's collapsing gate. lifts.gd moves this node's position.x between its shut and open x
## (move_doors(), lifts.gd line 413) as it does a hotel leaf; the gate keeps its far end at
## fixed_x and lays its lattice out between the two every time it moves.
@export var fixed_x := -0.85
@export var height := 2.25
@export var bays := 9
var material: Material
func _ready() -> void: set_notify_local_transform(true); build(); relayout()
func _notification(what: int) -> void: if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED: relayout()
func relayout() -> void   # span = max(position.x - fixed_x, 0.23); verticals (0.018 x height x 0.006) at even steps;
                          # X diagonals between neighbours (length and angle from span/bays and height/2); top and bottom
                          # rails; one MultiMeshInstance3D child at local x = fixed_x - position.x, transforms rewritten only here
```

The moving stile (0.04 × `height` × 0.04, `gate_steel`) and a handle are plain children (they move with the node). No collider: hotel car leaves have none either. The builder passes `materials.gate_steel` before `add_child`; `_ready()` runs during `build()` (the rooms are in the tree), so the lattice exists before `assign_layers()`.

### 7.6 Lift wall and sounds

- Override `lift_wall(node, room, direction, length)`: same placement (`half - FLOOR.LIFT_DEPTH + 0.09`, lines 1691-1713), `office_run()` either side of a `FREIGHT_OPENING` doorway, `wall_core` header, `steel_frame` casing 0.06 round the opening, a stencil `text()` "MONTACARGAS" (size 34, ink `Color("d9c25a")`) over it at 2.55 and "CARGA MÁXIMA 1500 KG" (size 16) beside it at 1.5, a call box (0.12 × 0.2, round `enamel` button) at `CALL_AT`. No paintings. The card reader is not here: it is 1e's, at `mail.reader` in the freight lobby beside the gate door, behind which this wall stands.
- Override `lift_sounds()`: `{"close": "res://assets/audio/sfx/freight/gate_close.wav", "open": ".../gate_open.wav", "descent": ".../descent.wav", "bell": ""}`. In `lifts.gd`, replace `DOORS_CLOSE`/`DOORS_OPEN`/`DESCENT`/`LIFT_DING` uses (car_doors default path, open_arrival, apply_ride, ride_along, begin_leaving) with `level.hotel.lift_sounds()[key]`, and skip the bell cue when the path is empty. Gains and timings stay.

### 7.7 The arrival lift on the reception (`arrival_lift`)

On the reception's wall named by `arrival_lift` (`[dx, dz]`, the outward direction), centred: the hotel lift's front as a facade, shut: `LIFT_LEAVES` at their shut positions, a `steel_frame` casing, `LIFT_CALL` and `LIFT_SCREEN` with `car_digits()` dark. No car behind, no collider beyond the wall, no interaction (phase 5 makes it the continuation). Without the key, nothing.

### 7.8 Dirección (wing 2): the shaft gate (`gates[2].kind == "shaft"`)

- Override `build_lifts(data)`: a gate with `kind == "shaft"` gets the empty entries of the hotel's `lobby < 0` and `arrive < 0` branches (`Vector3.ZERO`, `Transform3D()`, `[]`), so `lifts`, `car_frames`, `depart_leaves`, `arrivals`, `arrive_leaves`, `arrival_cars` and `arrival_facing` keep one entry per gate. Other gates call the hotel code.
- Override `build_exit_door(data)`: return without building when the last gate's kind is `"shaft"` (the air room and the plant are one salon; the exit is 1g's ladder). `hotel.gates` then holds the two stage gate doors; `lifts.gd` (line 112, line 304) and `observer_view.gd` already guard by size.

### 7.9 Navigation

H3: `nav_agent_radius()` returns `NAV_RADIUS` (0.3). With `cell_size 0.1` that is three voxels; a 0.95 m archive aisle keeps a 0.35 m walkable strip (with 0.4 it kept 0.15 and broke into pieces). `agent_height 1.8`, `agent_max_climb 0.1`, `keep_floor()` (`FLOOR_ISLAND 0.35`) unchanged: desk tops, filing cabinets and shelving tops drop out as islands, as beds do in the hotel. The crawl is out of the navmesh (5.6).

---

## 8. Light, layers, visibility round

### 8.1 Render layers

| Layer (value) | Office use |
|---|---|
| 1 (1) | everything drawn in rooms, as the hotel |
| 2 (2) | player's own body (unchanged) |
| 3 (4) | the Lurker (unchanged) |
| **4 (8)** | **plenum cells, the main duct, the hatch climb's top, the shaft**: everything outside a room's volume. The camera (`player.tscn` and `remote_player.gd`: cull mask 1048573 = 0xFFFFD) draws it; room lamps on `static_light`, and fill lamps past `lamps_cast`, light room bits only (`light_cull_mask` = room mask), so layer 4 is lit by torches (default cull mask) and, on presets with shadows, by shadow-casting lamps through holes and the hatch. 1e's photo camera and phase 4's Lurker view must include value 8. |
| 5-20 (16..0x80000) | room layers (unchanged, `room_layers.gd`) |

Plenum cells: override `flush()`: `super()`, then for every room node's `MultiMeshInstance3D` children (`box()` batches everything under a room, the `Plenum_*` holders included, into the room node itself, and `flush()` names each `"Mesh_" + group`, line 599; the emptied holders are freed by `drop_empty()`), and for each `glass` holder's children (`Mesh_wired_glass` → `cast_shadow` off): names `Mesh_plenum_*` → `layers = PLENUM_LAYER`, `gi_mode` disabled; groups in `NO_SHADOW`, starting with `stripe_` or `troffer_fail_` → `cast_shadow` off; `Mesh_troffer_lens` (absent in dark rooms) → `lens_of[room_id]`; `Model_mounted_fluorescent_lights*` → `battens_of`. This runs before `assign_layers()` (`build()` calls `flush()` then `assign_layers()`), and `ROOM_LAYERS.put_on()` never touches a geometry without layer 1, so layer 4 never gets a room bit and is never moved by `follow_bodies`. H4 keeps `plenum_*` groups out of the bounce stand-ins (`bounces(group)` returns `not group.begins_with("plenum_")`).

### 8.2 Glass on two rooms' layers

Override `assign_layers()`: `super()`, then for each `glass` entry compute `bits = layer_at(spot + n*0.7 + up) | layer_at(spot - n*0.7 + up)` (as `assign_layers()` does for doors, lines 2057-2063) and `ROOM_LAYERS.put_on()` every `GeometryInstance3D` under it with those bits (the hide/change/show protocol is inside `put_on`). Store `bits` in the entry. Do not add glass to `door_halves`: a pane has no faces to split, and the blind quad lit from the far side shows its back (N·L < 0), so nothing leaks.

### 8.3 Visibility round

- `round_rooms()` is untouched (one lamp per room). Override it as `super()` then show each `glass` holder while either room's centre is within `round_at.reach` (both rooms' `room_spots` are already indexed).
- `round_lamps()`: `super()` then emergency units (7.2) and the practicals of unpowered rooms (7.3).
- `put_away(here)`: `super(here)` then hide glass, emergency units and `outside` holders of other plantas.
- Index office arrays once in `after_build()` (4.5): `glass`/`emergency` spots and `emergency_state`.
- Occluders: walls and sill/head bands only; never over glass, never for plenum cells or anything outside the rooms.
- Probes and bounce volumes come from `room.height` as in the hotel.
- Failing troffer: the hotel `flickers` loop with `share` (H5). Drain (0e) and the flicker must multiply, never overwrite each other.

### 8.4 Hum

`world_audio.update_ambient_sources()` filters `level.hotel.tubes` by distance only and stops on the floor-wide `dark`. Add `and level.hotel.lit(int(entry.light.get_meta("room", -1)))` to the filter (on floor 1 humming lamps are only in service rooms, which are never dark: same set) and load `level.hotel.hum_path()` into the two hum players when it differs from the loaded one (office: `res://assets/audio/sfx/office/fluorescent_hum.wav`, colder than the hotel's).

### 8.5 Outside the rooms: the main duct, the hatch climb, the shaft

`FLOOR.room_at()` returns `{}` in the shaft and the room below in the duct, so neither has a room lamp or a room layer of its own. 1g builds them; geometry gives the rule:

```gdscript
## A holder for something outside every room, not yet in the tree. Build its subtree, then add_outside().
func outside_holder(title: String, planta: int) -> Node3D
## Marks every descendant before it enters the tree (late_arrival() skips nodes with meta "laid";
## adopt() would put a whole holder on one room's layer): GeometryInstance3D -> layers = PLENUM_LAYER,
## gi_mode disabled, meta "laid"; Light3D -> meta "laid", light_cull_mask = PLENUM_LAYER. Then adds the
## holder as a child of the geometry root and files it in `outside` for put_away().
func add_outside(holder: Node3D) -> void
func crawl_space(at: Vector3) -> int          # 5.6
func body_bit(at: Vector3) -> int             # H10: -1 when crawl_space(at) != 0, else super(at)
```

- **Who lights them: nobody but the torches.** Dirección (wing 2) has no power (`POWER[2] == "none"`), the air room and the plant are not in `always_lit` (their OFICINAS light is "Nada"), and the shaft is outside every room. The player's torch has the default cull mask and lights layer 4. No lamp is planned in phase 1; one added later goes through `add_outside()` and casts shadows.
- **Render layer**: layer 4 only (value 8), never layer 1, so `ROOM_LAYERS.put_on()` never changes them and no kept room lamp lights them on `static_light`. Shown while their planta is shown (`put_away()`), untouched by `round_rooms()` (a few dozen meshes).
- **Bodies inside**: H10 puts them on no room layer while `crawl_space()` is not 0, so the lamp of the lit room under the duct does not light a crawling teammate through the false ceiling on `static_light`.
- **Collision**: 1g's bodies on layer 1, mask 0 (walking and `can_stand()`); the validator's ceiling band leaves them out (0.3 item 7).

---

## 9. Furniture

### 9.1 What decides what

- **Manifest, placed by 1b and validated by 1c**: everything that shapes movement or sight in the middle of a room. `room.furniture` items (desk rows, cubicle partitions, the meeting table, pigeonholes, the copier, the vending machine, card indexes; 9.2); archive shelving, from `archives[].rows` (9.4), never from `room.furniture`; glazing (`room.glazed`, 6.3); corner sockets (`room.sockets`, H8).
- **room_dressing** (geometry, `vary()`, never the generator's RNG): what stands against walls in the stretches and what lies on tops (9.5, 9.6). Big pieces get a box collider, nothing under 30 cm collides, nothing over `FURNITURE_TOP` (2.2).
- **Corner props** (`room.props` at `room.sockets`): the office `RECIPES` kinds (9.3), so `document_placement` finds desks and tables.

### 9.2 `room.furniture` and `office_props.build_item(builder, holder, item)`

Item: `{kind, at: [x, z] (room-local, from the cell centre), turn: 0..3 (quarter turns), size: [w, d], extra: {}}`. The holder `Furniture_<k>` is a child of the room node at `at`, turned `turn * PI / 2`; the piece's back is local -Z. The footprint table lives in the palette so the generator places and the validator checks with the same numbers:

```gdscript
## Free-standing furniture (room.furniture): footprint [w, d] with its chairs, top height. size[0] of a
## partition is its length. Every height is under FURNITURE_TOP.
const FURNITURE := {
	"desk": {"size": Vector2(1.5, 1.4), "height": 1.3},          # desk 1.4 x 0.7, top 0.75, chair, desk lamp on 1 in 5
	"desk_pair": {"size": Vector2(1.5, 2.6), "height": 1.3},     # two desks face to face
	"partition": {"size": Vector2(0.0, 0.06), "height": 1.5},    # length from item.size[0], 1.2 to 4.8
	"meeting_table": {"size": Vector2(3.6, 1.2), "height": 0.9}, # the table; chairs tucked within 0.27 of its long edges
	"pigeonholes": {"size": Vector2(1.8, 0.4), "height": 1.9},
	"copier": {"size": Vector2(1.3, 0.7), "height": 1.05},
	"vending": {"size": Vector2(0.9, 0.8), "height": 1.8},
	"card_index": {"size": Vector2(1.7, 0.5), "height": 1.2},
}
```

| kind | Built as | Collider |
|---|---|---|
| `desk` | `metal_office_desk` model + `school_chair_01` pulled up, `office_notepads_pad` / `stationery_supplies` / `clipboard` (hotel catalogue) on top by `vary`; a desk lamp (procedural, `builder.practical()`, warm 2700 K, 0.3 energy, `meta room`) on 1 in 5 | desk box, chair seat box |
| `desk_pair` | two `desk` face to face | two each |
| `partition` | procedural screen: `partition_fabric` box `[len, 1.5, 0.05]`, `steel_frame` cap and feet | box |
| `meeting_table` | procedural: `veneer` top 3.6 × 1.2 × 0.04 at 0.74 on two panel legs; 8 to 10 `school_chair_01` tucked (back edge at most 0.27 past the table edge, so 1c's two boardroom sweeps at ±(0.6 + 0.6) pass) | table box, seat boxes |
| `pigeonholes` | procedural grid of `laminate` cubbies 1.8 × 1.9 × 0.4 | box |
| `copier` | procedural 1970s console: `enamel` body 1.3 × 0.95 × 0.7, dark glass top, lid, paper trays; no text | box |
| `vending` | procedural cabinet 0.9 × 1.8 × 0.8, `enamel`, dark glass front with a lit strip (emissive, out with the room's power); no brand, no text. The break room's hum source later | box |
| `card_index` | `vintage_wooden_drawer_01` model, scaled to 1.7 wide | box |

### 9.3 Corner kinds (`room.props`) and `build_prop()`

Override `build_prop(node, kind)`: `if not PROPS.build(self, node, kind): super(node, kind)`. `office_props.build()` returns `false` only for the hotel kinds it leaves to `prop_factory.build()` (`plant`, `bin`, `basin`, `cart`); `prop_factory` builds nothing for an unknown kind, so every other office kind has a builder here. Every piece fits the hotel desk's footprint (2.3 × 1.4 round the socket, back at local -Z) and stays under `FURNITURE_TOP`.

| kind | Built as | Top |
|---|---|---|
| `reception` | counter 2.2 × 1.1 × 0.9: `laminate` top, `enamel` front panel, a pad and a clipboard, the hotel reception's warm practical; no till | 1.12 |
| `desk` | as the 9.2 desk with the model scaled so its top is at 0.84 (`document_placement.SURFACES`) | 0.84 (lamp 1.3) |
| `table` | `laminate` table 1.6 × 0.9, top at 0.84 (`SURFACES`), steel legs, 2 to 4 `school_chair_01` | 0.84 |
| `shelf` | procedural slotted-angle shelving, two bays 1.0 wide, 0.4 deep, six shelves to 2.1, `cardboard` boxes (the hotel's `shelf` is 2.45 tall: too tall here) | 2.1 |
| `filing` | two `filing4` side by side (9.5) | 1.32 |
| `chairs` | three `school_chair_01` in a row, 0.55 apart (waiting chairs) | 0.85 |
| `coat_rack` | procedural bentwood pole, six hooks, a coat on 1 in 3 | 1.85 |
| `bench` | slatted bench 1.5 × 0.45 × 0.4 on steel legs | 0.45 |
| `sideboard` | `veneer` sideboard 1.8 × 0.8 × 0.48, things on top (9.6) | 0.8 |
| `board` | mobile whiteboard: `enamel` face 1.5 × 1.0 from 0.8 to 1.8 on a `steel_frame` stand with castors, aluminium tray | 1.9 |
| `projector` | overhead projector (`enamel` body, arm, head) on a steel trolley 0.6 × 0.75 × 0.45 | 1.25 |
| `copier` | the 9.2 copier | 1.05 |
| `reader` | microfiche reader: hooded `enamel` body 0.45 × 0.55 × 0.5 with a dark screen, on a steel table 1.2 × 0.72 × 0.7, a `school_chair_01` | 1.3 |
| `boxes` | `cardboard` archive boxes stacked (`room_dressing.stack()` pattern) | 1.2 |
| `sorter` | mail sorting frame: 9.2 pigeonholes over a counter at 0.9 | 1.9 |
| `vending` | the 9.2 machine | 1.8 |
| `cooler` | water cooler: `enamel` cabinet 0.32 × 1.0 × 0.32, an upturned `bottle` (pale blue, transparent) | 1.45 |
| `fridge` | `enamel` fridge 0.6 × 1.6 × 0.65, chrome handle | 1.6 |
| `armchair` | the hotel catalogue's `ArmChair_01` (as `room_dressing.furnish()`'s "armchair") | 1.1 |
| `cabinet` | `steel_olive` cabinet 1.0 × 2.0 × 0.5, two doors | 2.0 |
| `gun_rack` | the empty armoury: `steel_olive` cabinet 1.0 × 1.9 × 0.45, open front, six empty cradles and a hanging chain | 1.9 |
| `plant`, `bin`, `basin`, `cart` | `prop_factory` (`cart` metal or not by the palette's `SERVICE`) | |

Each builder gives its big parts a box collider (`builder.box(..., "", true)`), sets `meta room` on its practicals and uses only `builder.box`/`cylinder`/`place` so it batches with the room.

### 9.4 Archives (`archives[]`)

For each unit, each rectangle of `rows` (world, min-max) is split at the boundaries of the unit's cells and each piece built under the cell it lies in (room-local), so it batches, culls and layers with that cell:

- **Fixed rows** (`mobile == false`): procedural slotted-angle shelving `archives[].height` tall (2.1): `steel_olive` 0.03 angles every 1.0 m, six shelves, `cardboard` archive boxes 0.33 × 0.25 × 0.39 filling 60 to 90 % by `vary`. One box collider per piece `[len, height, depth]`.
- **Mobile rows** (`mobile == true`): the same shelving on a carriage 0.1 high with a crank wheel on the aisle end, floor rails (two `steel_frame` strips, no collider) under every row; the `open` gaps are left as rows are written.
- **Battens** over `aisles` (7.1). Nothing is placed in `spine` or `aisles`; archive cells have no corner props and no dressing set (9.5).

### 9.5 room_dressing office sets

Add to `room_dressing.SETS` (picks are stretch contents; "" leaves it bare):

```
"office_open":     ["filing4", "filing2", "coat_rack", "bins", "", "filing4"]
"office_private":  ["filing2", "card_index", "coat_rack", "", "chairs_stack"]
"mail":            ["mail_cart", "hand_truck", "boxes_archive", ""]
"copy":            ["boxes_archive", "filing2", "", "bins"]
"break":           ["chairs_stack", "bins", "", "coat_rack"]
"lockers":         ["bench", "", "bins"]
"store":           ["boxes_archive", "filing4", "", "boxes_archive", "hand_truck"]
"office_corridor": ["bins", "chairs_stack", "", "", "filing2"]
```

1d sets the office palette's `MODULE_SET`: `"office_open"` for 0, 1, 2; `"office_private"` for 3, 5, 16, 17, 21, 24; `"mail"` for 14; `"copy"` for 7; `"break"` for 15; `"lockers"` for 4; `"store"` for 8 and 25; `"office_corridor"` for 11 and 12; `""` for 6, 9, 10, 13, 18, 19, 20, 22, 23 (archives' rows run to the walls).

- **R1**: `furnish_pick()` handles `filing4` (procedural `steel_olive` 0.47 × 1.32 × 0.62, four drawer fronts with handles and label holders), `filing2` (0.71 tall), `coat_rack`, `chairs_stack` (3 to 5 `school_chair_01` stacked 0.07 apart), `boxes_archive` (`cardboard` stacks), `mail_cart` (`tool_cart`), `hand_truck`, `card_index`, `bench`; anything else returns false.
- **R2**: `wall_stretches(room)` returns `DRESSING.stretches(room, palette)` less every stretch on a glazed side and every stretch within `half` of a reserved spot (6.8), with `FAR` brought in to `length / 2 - 1.6` on walls shorter than 12 m so no stretch meets a corner socket.
- **R3**: no fuse boxes, no panel spares (`fuse_boxes()` false, `FUSE_ROOMS == []`): `fuse_boxes_left()` does nothing and `panels` stays empty on floor 2.
- **R4**: `decals()` decorative only, skipping glazed walls.

### 9.6 Things on tops

Reuse `dress_top()`/`fill_shelves()` with office choices: `office_notepads_a4`, `office_notepads_pad`, `clipboard`, `stationery_supplies`, `cardboard_box_01`, `alarm_clock_01` (all in the hotel catalogue).

### 9.7 Lockers (hiding places)

`room.hides` in office rooms come from 1b (`WARDROBES`, `hide_kind() == "locker"`). Minimum for 1d: `hiding_place.gd` gains `var skin := &"wardrobe"`; office sets `&"locker"` before `add_child`, and the locker skin loads `assets/props/locker/locker_body.res`, `locker_leaf_left.res`, `locker_leaf_right.res` and their `_inside` meshes, baked by `tools/props/build_locker.gd` (two-door steel uniform cabinet, louvred slots at eye height), keeping the wardrobe's `WIDTH`, `HEIGHT`, `DEPTH` and `HINGE` exactly so the interaction, peeking and occupancy code is untouched. If time runs out, office lockers stay wardrobes and a line goes to `docs/PLAN.md` section 3; do not ship a half skin.

---

## 10. Asset ingest for this step

Only `status: "ok"` entries of the registros, plus `metal_office_desk` (already downloaded and audited for the hotel, named in OFICINAS 12). Everything marked "needs_login" stays out; where it is the only fit, the piece is procedural (below). Downloads are untrusted: extract archives with Python `zipfile` (or 7-Zip for `.7z`) into a new empty folder under `source_assets/oficinas/_staging/<slug>/`, only the whitelisted files, never a `.blend`, `.cs` or `.dts`; run Python with `-I`.

### 10.1 Models (`tools/props/ingest_models.py` then `tools/props/build_catalogue.gd`)

| Piece | Asset (registro slug) | Licence | Catalogue id | Notes |
|---|---|---|---|---|
| Stacking chair | muebles_a `silla_apilable_school_chair_01` (Poly Haven School Chair 01) | CC0 | `school_chair_01` | `SCALE 0.82` (1.006 m tall, a real one about 0.83); tint the shell olive or mustard in its `.tres` (`TINT` table) |
| Card index / archive drawers | muebles_a `fichero_vintage_wooden_drawer_01` | CC0 | `vintage_wooden_drawer_01` | 1.7 m wide: a full stretch (`FAR - NEAR` = 1.7) or a 9.2 item |
| Mail cart | muebles_b `mail_cart_steel_utility_cart` (Tool Cart) | CC0 | `tool_cart` | 29.4k tris over the 20k budget: bake the base from the LOD under 20k (`DECIMATE`, 10.4) |
| Hand truck | muebles_b `mail_cart_hand_truck` | CC0 | `hand_truck` | 13.2k, fine |
| Battens (archives, service corridors, exposed ceilings) | equipos `fluorescent_battens_polyhaven` (Mounted Fluorescent Lights) | CC0 | `mounted_fluorescent_lights_<n>` | `PARTS` split by node name (list the nodes with a dry run), keep one or two; scale to 1.2 m; the glTF's emission texture needs emissive support (10.4) |
| Office desk | `source_assets/props/metal_office_desk` (Poly Haven) | CC0 | `metal_office_desk` | remove from both `SKIP` lists |

Rows that later steps add with the same tooling (named here so the catalogue ids agree): `pipes_modular_polyhaven` → `modular_pipes` (1e); `electric_cables_switches_polyhaven` → `modular_electric_cables` (1f); `duct_fans_circular_polyhaven` → `modular_airduct_circular_01` and `fire_escape_ladder_polyhaven` → `modular_fire_escape` (1g); `human_skull_oga` → `human_skull` (1g/1h; OBJ, scale about 0.07, relink its textures).

Procedural, because the only fitting candidates need a login (RESUMEN): troffers 60 × 120, emergency twin heads, venetian blinds, freight car and scissor gate, coat rack, filing cabinets, lockers, meeting table, vending machine, water cooler, copier (none exists), pigeonholes. Procedural by choice: archive shelving (the ok Pixabay rack is 58k tris and a fixed size; aisles need exact runs), cubicle partitions (the ok 3TD screens are 96 tris and diffuse only), return grilles (the ok `wall_grille_oga` is CC BY, non-PBR and a 7z).

### 10.2 Materials (`tools/textures/ingest_pbr.py`)

| Material key | Registro entry | Source | Set name | Use |
|---|---|---|---|---|
| `vct` | materiales `vct_floor_tiles` / `acg_tiles110` | ambientCG Tiles110, CC0 | `tiles110` | vinyl floors (tile.gdshader, `tile_count` to the scan's tiles) |
| `terrazzo` | `terrazzo` / `acg_tiles043` | ambientCG Tiles043, CC0 | `tiles043` | reception, lobbies, landing |
| `concrete_floor` | `concrete_slab_ceiling` / `acg_concrete006` (its second option) | ambientCG Concrete006, CC0 | `concrete006` | floors with `floor_finish == "concrete"` (types 8, 12, 18, 22, 23, 25) |
| `block` | `painted_concrete_block` / `acg_bricks019` | ambientCG Bricks019, CC0 | `bricks019` | corridors, service rooms (finish.gdshader, recolour; block 0.4 × 0.2) |
| `veneer` | `wood_veneer_paneling` / `ph_walnut_veneer` | Poly Haven walnut_veneer, CC0 | `walnut_veneer` | Dirección walls (wood.gdshader so `lacquer()` covers it) |
| `carpet_tile` | `office_carpet_tiles` / `acg_carpet006` | ambientCG Carpet006, CC0 | `carpet006` | Dirección offices (carpet.gdshader, tinted) |
| `partition_fabric` | `partition_fabric` / `ph_hessian_380` | Poly Haven hessian_380, CC0 | `hessian_380` | cubicle screens (`map_metres 0.27`) |
| `galvanized`, `plenum_duct`, `plenum_tray` | `galvanized_steel` / `cgb_galvanizedsteel02` | cgbookcase Galvanized Steel 02, CC0 | `galvanized_steel02` | ducts, trays; 1g's main duct (normal is DirectX: flip green) |
| `cork` | `cork_board` / `acg_cork003` | ambientCG Cork003, CC0 | `cork003` | notice boards |
| `plenum_slab` | `concrete_slab_ceiling` / `ph_concrete_wall_008` | Poly Haven concrete_wall_008, CC0 | `concrete_wall_008` | slab underside, exposed ceilings |
| `cardboard` | `cardboard_manila_paper` / `acg_cardboard004` | ambientCG Cardboard004, CC0 | `cardboard004` | archive boxes |
| `diffuser` | equipos `ceiling_diffuser_oga` (Air_Vent.png, Air_Vent_Normal_Map.png from `air_vent.zip`) | OpenGameArt GeekGirl.Joy, CC0 | `air_vent` | supply diffusers, `map_metres 0.6` |

`ceiling_service` (officeceiling001) is already in. Wired glass and thermal paper have no texture (RESUMEN "Falta"): glass is `wired_glass.gdshader`; paper is 1h's.

### 10.3 Audio (`tools/audio/prepare_office_sfx.py`, like `prepare_lift_sfx.py`: ffmpeg via `tools/trailer3d/audio/dsp.py`, mono 44.1 kHz, cut, fades, common peak, deterministic)

| Output | Registro entry (ok) | Licence | Cut |
|---|---|---|---|
| `assets/audio/sfx/office/fluorescent_hum.wav` | audio_edificio `fluorescent_hum` (Pixabay 92449, kbnevel) | Pixabay (original CC0) | seamless loop of about 6 s |
| `assets/audio/sfx/freight/gate_close.wav` | audio_edificio `freight_lift_scissor_gate` (BigSoundBank 2358) | CC0 | to `lifts.DOOR_CLOSING` 1.7 s |
| `assets/audio/sfx/freight/gate_open.wav` | same, BigSoundBank 2355 | CC0 | to `DOOR_OPENING` 1.6 s, sound starting `DOORS_HEARD` early |
| `assets/audio/sfx/freight/descent.wav` | audio_edificio `freight_lift_motor` (BigSoundBank 1712) | CC0 | the hotel `descent.wav`'s length (the ride is timed on it, `RIDE_*`); listen for modern beeps first; if present use WWS Hoist (CC BY 4.0: credit in `hotel_ui.CREDITS` and ASSETS.md) |

No blind, panic-bar or locker sounds in 1d.

### 10.4 Tool changes

- `ingest_models.py`: an `OFFICE = {id: path under source_assets/}` table (later steps append their rows); target `assets/props/office/<id>/`; read `.glb` as well as `.gltf` (embedded images written out from the buffer views) and `.obj` with its `.mtl`; `emissiveTexture` and `emissiveFactor` → `emission_enabled`, `emission_texture`, `emission`; a `TINT` table; register rows from each `registro.json` (author, licence, url) between new `<!-- OFFICE_MODELS -->` markers in ASSETS.md (the current `register()` writes Poly Haven CC0 only).
- `build_catalogue.gd`: `--office` switches `SOURCE` to `res://source_assets/oficinas/` with the same id → folder table and `TARGET` to `res://assets/props/office/`; `SCALE["school_chair_01"] = 0.82`; `DECIMATE := {"tool_cart": 20000}` (after `generate_lods`, save the LOD whose triangle count first falls under the target as the base); `PARTS["mounted_fluorescent_lights"]`. `room_dressing.mesh(name)` gets a second root: names found in `assets/props/office/` load from there.
- `ingest_pbr.py`: optional folder per `SETS` entry (`source_assets/oficinas/materiales/<group>/<sub>`); a `cgbookcase(zip)` reader (BaseColor, Normal with green flipped, Roughness, Metallic; AO white); a `loose_pngs(zip, albedo, normal, roughness, metal)` reader for `air_vent`; for 1K sources write both sizes at 1024; register rows in the SCANS block (sources other than Poly Haven and ambientCG get their own source and url).
- `bake_lite_maps.gd`: also iterate `office_geometry.OFFICE_MATERIALS` (needs a window); run after the materials exist.
- After ingest: `godot --headless --path . --import`, then `build_catalogue.gd --office`, then the lite maps; `git restore default_bus_layout.tres assets/audio/the_four_theme.mp3.import` after every Godot run (project rule); `docs/asset_hashes.json` gets the new files.

---

## 11. Tests and captures

### 11.1 `tests/office/office_geometry_test.gd` (`extends SceneTree`, `check(title, passed)` as `hotel_test.gd`; `--automation --test-profile --silent --floor=2`; seeds 81, 404, 7)

Build each floor through `hotel_main` with `--floor=2` (the real kind, palette and geometry) and check:

1. **Lamps**: `hotel.lights.size() == manifest.rooms.size()`; `lights[i].get_meta("room") == i` for every non-void room; every room with `lamp_of == "emergency"` is not `lit()` after build and has one battery unit.
2. **Ceiling cover**: for every false-ceiling room, area of tile runs + troffer tiles + exit tiles + gap tile == `OFFICE.ceiling_rect(room).get_area()` within 1e-3; no two runs overlap.
3. **Lattice**: every run edge not on the rect's edge is a multiple of 0.6 (within 1e-4).
4. **Gaps**: one plenum cell per `"gap"` exit, centred on `OFFICE.tile_of(point)`; no tile run over it; per room, `Mesh_plenum_slab` instances == its gaps and `Mesh_plenum_dark` has four per gap (or more where a crawl box cut a panel); every `Mesh_plenum_*` instance has `layers == PLENUM_LAYER` after `assign_layers()`.
5. **Troffers**: count per room == `OFFICE.troffers(room).size()`; none on an exit or gap tile; dark rooms' lens instance uses `lens_off`.
6. **Exits**: every `"ceiling"` exit's `point` is the centre of a tile of `OFFICE.free_tiles(room)` within 1 mm, at `py + room.height`, with one grille there; every `"wall"` exit's yaw faces away from the walled side nearest its point; every `"duct"` exit is in a room of 4.0 m or more (0.3 item 2).
7. **Glass**: every pair in `room.glazed` (both sides agree) has exactly one `glass` entry; its body is on collision layer 1 and its RID in `glass_bodies`; its panes cast no shadow; its meshes carry both rooms' bits; no glazed side holds a reserved spot, the gate door or a lift wall.
8. **Doors**: every leaf's `CollisionShape3D` is `Vector3(1.2, 2.58, 0.07)`; leaf mesh AABB equals `door_leaf.res`'s within 2 mm; opening height 2.65; both stage gate doors use `leaf_service`.
9. **Plaques**: every numbered room has a plaque `Label3D` on the far side of each of its doors matching `^[PRDSM]-\d{3}$`; no label anywhere on the floor contains "·" or "—".
10. **Stripes**: only in role 11 and 12 rooms; each run's material is `stripe_<colour>` of the room's sector (`departments[wing]`), so two sectors of a planta never share one; on wing 1 every zone label equals `"%s %s" % [code, name]` of its sector's circuit.
11. **Navigation**: region `agent_radius == 0.3`; for every `archives[].aisles` centre the closest navmesh point is within 0.15 m and a path from the planta entry reaches it.
12. **Lift**: `lifts`, `arrivals`, `depart_leaves` sizes equal the gates; `in_car(i, lifts[i])` true for gates 0 and 1; each of those cars' leaves is one `scissor_gate` node; setting its `position.x` from `GATE_SHUT_X` to `GATE_OPEN_X` shrinks its lattice span under 0.25 m; `lift_sounds().bell == ""`. Gate 2: `lifts[2] == Vector3.ZERO`, no `ExitDoor` node, `hotel.gates.size() == 2`.
13. **Power**: `set_room_power(r, false)` on a lit corridor of wing 1: its lens override becomes `lens_off`, its emergency unit lights on the next `update_visibility()`; `drain(r, 0.5)` halves its lens emission only; `blackout(true)` zeroes every lens and keeps emergency units eligible; wing 2 has no battery unit.
14. **Flicker**: the failing troffer's entry has `share == 1 / troffers`; its room light never drops under `(1 - share) * energy`.
15. **No information in decals**: every `Decal` on the floor carries the `rank` meta of `hotel_geometry.decal()` (only `room_dressing.decals()` makes them), none lies within 0.5 m of a glazed wall, and the `ink_stain` batch instance count equals the number of bent grilles. Compatibility itself is checked by the captures (11.3).
16. **Layers**: after `apply_quality(Muy bajo)`, no room lamp's cull mask has the `PLENUM_LAYER` bit; `room_layers.clashes == 0` on this floor (report seams).
17. **Props**: for every kind in the office `RECIPES` and every key of `FURNITURE`, `office_props` (or `prop_factory` for the four hotel kinds) builds at least one node or batch entry into an empty holder, and the built AABB stays under `FURNITURE_TOP`; built `room.furniture` pieces stay inside their `FURNITURE` footprint plus 0.05; a ray down at each `desk`/`table` socket centre hits at 0.84 ± 0.01.
18. **Reserved spots**: no dressing stretch, wall art, poster spot, plaque, switch plate, emergency unit or zone label within the `half` of a reserved spot (6.8) on its wall.
19. **Crawl spaces**: `hotel.crawl.size()` equals the `main` edges plus the non-zero `cross` edges; every box's floor is at `py + duct_y - main / 2` within 1 mm; a shape query with each box shrunk by 0.05 on mask 1 finds nothing of 1d's; a ray along each box's axis at its centre crosses every wall without a hit on layer 1; `body_bit()` returns -1 inside each box and in `shaft`, a room bit elsewhere; a box built with `outside_holder()`/`add_outside()` keeps `layers == PLENUM_LAYER` after `assign_layers()` and hides with `put_away()` of another planta.
20. **Fuse boxes**: `hotel.panels.is_empty()` and `panel_spares.is_empty()` after build.
21. **Physics validator**: `kind.VALIDATOR.new().validate_physics(world, data) == []` (1c §3.2, with the crawl exemption of 0.3 item 7).

Add `'office/office_geometry_test'` to `tools/verify.ps1` `$tests`, and the "física" section (case 21 on three seeds) to `tests/office/office_test.gd`.

### 11.2 Floor 1 regression (must stay green, unchanged)

`manifest_golden_test`, `hotel_test`, `stages_test`, `loop_test`, `capture_test`, `hotel_audio_test`, `spatial_audio_test`, `light_layers_scan`, the net scenarios. H1 to H10 and R1 to R4 are the only hotel edits; `tools/dev/light_leak.gd --quality=4` on seed 81 must read the same as before.

### 11.3 `tools/capture/office_capture.gd` (window; 1i extends it)

Shots, each on Alto, Muy bajo and with `--rendering-method gl_compatibility`: open office with troffers; corridor with stripes and zone label (wing 1); a glazed despacho from the corridor (blinds shut, open, raised); archive aisle; a gap looked up into from below and from 3 m (the plenum cell must close: no void); a hanging tile; a bent grille with its ink; the freight lobby with the gate door, the gate shut and open; a powered and an unpowered wing-1 corridor (emergency units); the plant with its exposed ducts and the wall opening for the main duct. Also run `tools/dev/zfight_scan.gd` on a floor-2 floor (tiles over flanges, troffer lenses, stripes, plaques).

---

## 12. Docs (Spanish, no "·" or "—" in anything shown in the game)

- `docs/DEVELOPMENT.md`: a "Geometría de las oficinas" paragraph: one lamp per room and why; the false ceiling as the room's ceiling; the lattice in the palette; plenum cells and render layer 4; the crawl spaces outside the rooms (`crawl_boxes()`, cut walls, `body_bit()`); glass as fixtures on two layers; the hooks H1 to H10 and R1 to R4; the scissor gate protocol; who builds the fixtures of each planta.
- `docs/LURKER.md` line on render layers: add "capa 4, el plénum, el ducto principal y el pozo".
- `docs/ASSETS.md`: OFFICE_MODELS block, SCANS rows, the audio rows; credits only if WWS Hoist is used.
- `docs/asset_hashes.json`.

---

## 13. Order of work

1. Read 0c/0d/0e/1a/1b/1c as they landed; dump one floor-2 manifest; write down the real key and step names (adapt sections 0, 5, 6 to them). Add to the palette whatever of 4.2, 9.2 and 5.6 1a did not write.
2. Hotel hooks H1 to H10 and room_dressing R1 to R4 (+ the `lighting.gd` arm, `lifts.gd` and `world_audio.gd` reads). Run floor 1's tests (11.2). Commit-ready on its own.
3. Ingest: materials (10.2), models (10.1), audio (10.3); import; register. Run `bake_lite_maps.gd` last.
4. `office_geometry.gd` skeleton: `_init` materials, `prepare()`, `floor_surface`, plain `office_run` walls, a troffer-less ceiling, the shaft gate overrides (7.8); switch `office_floor.GEOMETRY`; a floor 2 builds headless without errors.
5. Tile runs, T-grid, troffers, lamp (H6), ceiling exits; tests 1 to 3, 5, 6, 14.
6. Gaps, hanging and fallen tiles, plenum cells, network ducts and trays, exposed ceilings, the crawl cuts (5.6), the flush post-pass and layer 4, `outside_holder()`/`add_outside()`/`body_bit()`; tests 4, 16, 19.
7. Walls: finishes, cove base, stripes, zone labels, switches, reserved spots, glazing, blinds, glass layering and round; tests 7, 10, 18.
8. Doors (`build_office_door.gd`, H1) and plaques (H2); tests 8, 9.
9. Emergency units, power hooks, blackout, hum; tests 13, 15.
10. Freight lift: `car_body`, `scissor_gate.gd`, `lift_wall`, sounds; arrival lift facade; test 12.
11. Furniture: `office_props.gd` (corner kinds, `room.furniture`, archives, picks), sockets (H8), room_dressing sets; navigation radius; tests 11, 17, 20.
12. Lockers skin (or the PLAN.md line).
13. Physics validator on (test 21 and `office_test` "física"), captures (11.3), zfight scan, light leak scan on floor 2, `verify.ps1` whole; docs.

---

## 14. Risks

- **0e/1a/1b shapes differ from what is written here.** Mitigation: step 13.1; the spec's names are for content, the landed names win. The generator spec is corrected in parallel; check 0.3's seven items against it first.
- **Static dispatch**: overriding a static function in `office_geometry.gd` is not seen by callers that go through `GEOMETRY.` (the hotel script). Everything that must vary per floor is an instance hook (H1 to H10, R1 to R4), manifest data (H8) or a palette function (4.2, 5.6, 9.2).
- **A body in the duct is "in" the room below it.** `FLOOR.room_at()` and `floor_point()` report the room under the duct (and `{}` in the shaft), which feeds `lit()`, sanity's darkness, the director and room layers. Geometry handles layers (H10); 1g must make sanity and `lit()` consumers ask `crawl_space()` first (in the duct it is dark whatever the room below), and phase 2's creature in a duct goes through `body_bit()`.
- **The shaft has no room.** No room lamp, no room layer, no navmesh, `adopt()` does nothing there: everything in it must go through `add_outside()`, or it lands on whatever room `layer_at()` finds (none) and is lit by nobody on `static_light` except torches, which is intended.
- **Crawl boxes against everything else.** A wall, panel, tray, batten or 1e/1f piece left inside a crawl box blocks the crawl or shows inside it; case 19 queries mask 1 inside every box, and the systems steps must keep their pieces out (no tube or cable crosses `crawl` at its height).
- **The validator's ceiling band** fails on the main duct's collider unless it leaves `crawl_boxes()` out (0.3 item 7); if 1c landed without it, fix 1c, not the collider layer.
- **The world lattice and the generator.** If 1b's exits or gaps are not on `free_tiles()` (an old room-local troffer rule, or tiles computed before the origin shift), grilles land on troffers or across T-grid lines; cases 5 and 6 catch it; fix 1b.
- **Light leaks**: gaps (closed by plenum cells), glass (light crossing glass in Forward+ is correct; on `static_light` it stops at the room layer), emergency spots without shadow (only when layered). Measure with `tools/dev/light_leak.gd` on floor 2 and `light_layers_scan` over many seeds: office cells are 8 to 12 m, so more rooms fall within `lamp_range()`'s 10 m minimum and `LATE_REACH`; if clashes appear, the fix is a smaller office lamp range passed to `room_layers.assign()` (manifest `lamp_min`), not more layers.
- **Shadow budget**: planta 0 is fully lit like a hotel planta; emergency spots add at most `EMERGENCY_CAST` maps. In Compatibility every shadowed lamp is another pass (PERFORMANCE.md: 1,580 draw calls walking on Bajo): keep `EMERGENCY_CAST_COMPAT` at 3 and measure with `run_bench.ps1 -Compatibility` on floor 2.
- **Compatibility**: no projectors (the `tube` and `twin` profiles are ignored: plain lights, as the hotel already accepts), no decals, no FogVolume, no bounce; transparency sorting of glass within one holder; avoid `instance uniform` (unused in the project and unverified on GL): lens dimming is material swaps.
- **Z-fighting**: tile faces 4 mm over flanges, lenses 12 mm recessed, stripes 3 mm proud, plaques 4 mm; `zfight_scan.gd`.
- **Navmesh 0.3**: more small pockets round furniture; `keep_floor()` drops them; check aisles in case 11 and bots on floor 2 (1i).
- **Draw calls and instances**: per room about 15 batches; tiles are runs (about 20 to 30 boxes a room, not 400). Measure a planta 0 walk against a hotel planta on Bajo.
- **Untrusted downloads**: whitelist extraction, no `.blend`/`.cs`, Python `-I`; licences per registro (all picks CC0 or Pixabay; only WWS Hoist would need a credit).
- **Time**: lockers (9.7) and the office door bake (6.6) are the separable parts; ship H1 with the hotel leaf if the bake is late, never a mismatched leaf size.

## Notes from the hooks (23 October 2026, done by the director without work orders)

- H1 to H10 and R1 to R4 are in, with floor 1 unchanged: the module gallery built before and after is the same once normalized (evidence/gallery_twice.txt's sed), and the golden, stages_test, room_light_test and the contract test pass. light_layers_scan reads only manifests, which the hooks do not touch.
- H5 keeps the hotel's product exactly: a lamp with no `share` (or 1.0) uses `level` itself, not `1 - (1 - level)`.
- H8 returns the socket as it is when `room.sockets` exists: the generator has already pulled the lift-side sockets clear (2.5f).
- H9 gives `lift_sounds()` and `hum_path()` only. lifts.gd keeps its four constants and world_audio its hum path until the office sounds are ingested; the hum is made in world_audio's setup, before any floor, so it will have to be swapped when a floor is built.
- The creature contract step (before this one) named the presence sound `presence_sound()`, not `sound_profile()`: The Locust's `sound_profile` is a variable.
- `office_geometry.gd` begins as the hotel's with `nav_agent_radius()` 0.3 and the palette's finishes (`vinyl`, `terrazzo`, `concrete`, `office_paint`, `block`, `veneer`) under their own names, loaded from `materials/office/<key>.tres` when it exists and otherwise a hotel material marked `stand_in` (the hotel builds with the finish name as its material key). `office_floor.GEOMETRY` is it. Floor 2 then builds (seed 7: 507 lights, the null creature placed through the contract), and the 1c physics rejects it: archive aisles, the ceiling band (the hotel's taller wardrobes standing in for lockers, and the hotel's tall props), a few passages and leaf arcs. A child `_init()` must call `super()`: the hotel's materials are loaded there.
- hotel_main's physical-rejection warning formatted an Array with `%`: it now prints `str(errors)`.
- office_props.gd builds the procedural corner kinds of 9.3 (reception, shelf, coat_rack, bench, sideboard, table without chairs, board, projector, cooler, fridge, cabinet, gun_rack, boxes) with stand-in materials (laminate, enamel, steel_olive, steel_frame, cardboard, bottle). Not yet: desk, filing, chairs, armchair, copier, reader, sorter, vending (models or 9.2). Archives get no wall stretches (9.5).
- Director's decisions found by building floor 2: the generator drops a corner prop whose footprint meets a door's leaf band (`wall_rect(PORTAL / 2 + DOOR_SIDE, DOOR_BAND)`) and the validator's `props_<id>` checks it (a desk, shelf or table there stopped the door's sweep); the archive aisle sweep stops a capsule radius plus 0.05 short of its far end (the long wall's face); the ceiling band leaves out the hiding places (2.3 m, which 9.7 keeps for the lockers). With these, seeds 7, 21 and 33 built pass `validate_physics()`, and office_test checks it.
