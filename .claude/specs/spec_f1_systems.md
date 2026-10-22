# Floor 2, phase 1: the three planta systems (steps 1e to 1i)

Spec for the implementing agents. Read `docs/OFICINAS.md` sections 3, 8, 10, 11.7 and 15 first. Floor 1 must stay byte-identical: every change to a shared file below is a no-op for the hotel kind (section 8 lists the guards).

Line numbers are from the tree at `d59cf8d` (after step 0a3). Later phase-0 steps move them: search by function name.

**Numbering.** Prose follows OFICINAS: plantas 1 to 3 (1 Personal, 2 Registro y Archivo, 3 Dirección). Code counts `wing` from 0, so planta 1 is wing 0.

## 0. What this spec assumes and what it decides

### 0.1 Phase 0 as specified in `oficinas_specs.md` (assume it exists exactly so)

- `level.creature` with the contract (`creature.gd`), `level.locust` alias. Phase 1 runs the office floor against `null_creature.gd` (step 1a), which never captures. This spec only needs `creature.hear(point, radius)` on it. **Add to `null_creature.gd` (if 1a did not)** `var heard: Array = []`, with `hear()` appending `[point, radius]` (cap 64). The tests read it.
- Objectives as handlers, `game/floors/objectives/objective.gd`: `static settle(manifest, survivors, kind) -> Dictionary`, `setup(level)`, `place()`, `reset()`, `progress(stage) -> {ready, done, needed, kind, lines, extra}`, `goal_points(stage) -> Array[Vector3]`, `tick(delta)`, `snapshot()`, `restore(data)`. `host_gate()` loops the stage's handlers (met = AND of `ready`). `lifts.stage_progress()` concatenates their `lines`. 0b's names (done, 22 October 2026): `level.objectives` is the Dictionary of the floor's handlers keyed by the String names of `kind.OBJECTIVES` (which holds res:// paths, loaded by `hotel_main.build_objectives()`, because preloading them makes a cycle through `tv_placement.gd`); `level.stage_objectives(stage := -1) -> Array` gives the stage's in `STAGES` order; `level.goal_points() -> Array[Vector3]`. Below, `level.objective(id)` means `level.objectives[id]`; do not add a second registry.
- `office_floor.gd` (1a) with `GENERATOR/GEOMETRY/VALIDATOR/PALETTE/CREATURE/CREATURE_KEY = &"lurker"/OBJECTIVES/PAPERS`, `floor_index.KINDS[2]`, `--floor=N`, `level.set_floor(n)`.
- Palettes with structural roles 0 start, 9 landing, 10 lobby, 11 corridor, 12 gallery, 19 refuge, 20 void. `FLOOR.palette(manifest)` returns the office palette for floor 2.
- `hotel.lit(room_id)`, `hotel.set_room_power(room_id, on)`, `hotel.drain(room_id, amount)`, `ROOM_LAYERS.put_on_actor(mesh, bits)`, and `build_room` split into steps (0e), among them `extras(node, room)`.
- `DIFFICULTY.CREATURE_PROFILES[&"lurker"][id]` merged by `DIFFICULTY.profile(id, creature_key)`; `level.tuning()` returns the merged dictionary (0f).
- Step 1d's `office_geometry.gd` (`spec_f1_geometry.md`): `PLENUM_LAYER := 8`, its `build(data)` override (`await super.build(data)`, then its own indexing), `put_away(here)` and `office_run()`.

### 0.2 Contract with the generator (1b) and geometry (1d)

**Keys.** The keys below are the generator's (`spec_f1_generator.md` §2.5 and §2.7, with the additions agreed for 1b: `mail.stand`, `mail.camera_target`, `mail.reader`, `tubes.rooms`, `power.timers` without `seconds`, `air.security.reader`, `air.unit`, `air.stop`, `air.main.stub`, `air.shaft.rect`/`floor_y`/`ladder`, and `PALETTE.always_lit()`). The handlers read them under these names and derive nothing the generator stores. If one is missing when 1e starts, add it in 1b first, with its validator group and mutation, and never compute it in a handler.

- Positions are `[x, y, z]` world floats, after the origin shift, rounded to 0.001. The manifest is hashed as JSON by `match_net.floor_built()` (line 120), so it holds no `Vector3`.
- Yaws are the literals `0.0`, `PI / 2`, `PI`, `-PI / 2`.
- A **wall spot** is `{wall, along, point, yaw}`. `yaw` faces into the room: it is the +Z of a node turned by it, `Basis(Vector3.UP, yaw).z`, the convention `hotel_geometry.assign_layers()` uses for doors. A body turned to `yaw` faces the wall, because its forward is -Z.

Helpers in `objective.gd`, used everywhere below:

```gdscript
static func v3(a) -> Vector3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
## Out of a wall spot, into its room.
static func facing(yaw: float) -> Vector3: return Basis(Vector3.UP, yaw).z
static func spot_xform(spot: Dictionary) -> Transform3D: return Transform3D(Basis(Vector3.UP, float(spot.yaw)), v3(spot.point))
## The floor point `metres` in front of a spot: where a body stands to use it.
static func before(spot: Dictionary, metres: float) -> Vector3
```

| Key | Shape | Read by |
|---|---|---|
| `mail` | `{window, desk, stand, camera, camera_target, map, stations, reader}`:<br>• `window`: the Ventanilla room id (17).<br>• `desk`: wall spot; `point` is the desk's centre on the floor, 0.55 m out from the wall.<br>• `stand: {point, yaw}`: the typist's feet, and the way it faces (the desk, back to the room). The generator writes it; the handler does not derive it.<br>• `camera: [x, y, z]`: a ceiling corner behind the typist, 0.15 under the ceiling.<br>• `camera_target: [x, y, z]`: about 1.3 m above the stand.<br>• `map`: wall spot at `py + 1.5`.<br>• `stations`: N.<br>• `reader`: wall spot on a closed wall of planta 1's freight lobby (19), beside the stage gate door to the landing (9), on the lobby side, at `py + 1.2`. | files |
| `tubes` | `{nodes, rooms, edges, exits, hub}`:<br>• `nodes: [[x, y, z]]`.<br>• `rooms: [int]`: the room of each node. `conduit_graph.mouths_in_room` needs it.<br>• `edges: [[a, b, metres, "tube"]]`.<br>• `exits: [{node, room, kind: "hub" or "station", number (stations only), point, yaw, tube (metres from the hub)}]`.<br>• `hub`: the index of the hub exit.<br>A station's mouth, and the tray where a capsule lies, is its `point`, at `py + STATION_Y` (1.25, palette). There are 8 to 14 stations, numbered 1..N, every one at least `STATION_TUBE_MIN` (25 m) of tube from the hub. | conduit_graph, files |
| `power` | `{room, board, circuits, lift_lever, timers}`:<br>• `room`: the electrical room.<br>• `board`: wall spot, `along` 0, `y = py`.<br>• `circuits: [{code: "R-2", name: "ARCHIVO", sector, colour, lever, rooms}]`.<br>• `lift_lever`: n, the red lever.<br>• `timers: [{rooms, point, yaw, sector}]`: `rooms` are the corridor cells a timer lights.<br>Timers carry no `seconds`: every minutero lasts `tuning().timer_switch`. | power |
| `PALETTE.always_lit(manifest, wing) -> Array` | The rooms that keep their lamps: the off-limits types (9, 10, 19) on wings 1 and 2, and SECURITY (21) on wing 2. ELECTRICAL (18) is in no circuit and not in this list: unpowered all the time, lit only by its emergency unit ("Foco de emergencia", OFICINAS 3). | power, air |
| `air` | `{security, room, plant, hatch, main, shaft, remains, unit, stop}`:<br>• `security: {room, door: "a:b", desk, reader}`. `desk` is a wall spot and **the post's console**. `reader` is a wall spot beside that door, on the corridor side, at `py + 1.2`.<br>• `room`: the air room (22). `plant`: the plant room (23).<br>• `hatch: {point, yaw, node}`: the duct's end in the plant; `yaw` faces out of the duct into the plant.<br>• `main: {nodes, length, bends, cross, stub: [dx, dz]}`: `nodes` index `ducts.nodes`; `stub` is the crossing's side direction.<br>• `shaft: {point, node, side, rect: [cx, cz, sx, sz], floor_y, ladder: {point, yaw}}`.<br>• `remains: {point, along}`.<br>• `unit`: wall spot in the plant, the air handler's back against the wall, `y = py`.<br>• `stop`: wall spot beside the unit, the isolator, at `py + 1.3`. | air, crawl, bots |
| `ducts` | `{nodes: [[x, y, z, room, kind]], edges: [[a, b, metres, kind]], exits: [{node, room, kind, point, yaw}]}` | main duct, conduit_graph (phases 2 and 3) |
| `plenum` | `{ceiling, slab, duct_y, main, duct}` | main duct |
| `gates` | Hotel format.<br>• Entries 0 and 1 are the stage gate doors of plantas 1 and 2: ordinary service doors between the freight lobby (19) and the landing (9), with `gate_stage`, locked until the stage's handlers are ready. `lifts.car_ready()` (line 302) needs them unlocked.<br>• The scissor gate is the freight car's own leaves (geometry 7.4 and 7.5), moved by `lifts.gd` like a hotel leaf. It is not a gate door.<br>• Entry 2 has `kind: "shaft"`: no car and no door. The shaft ladder ends the floor. | lifts |

**The main duct's height (one rule, written the same in the generator spec).**

- Main nodes are at `py + duct_y`, the centre line of the duct.
- The duct is `main` × `main` inside. Its floor is at `py + duct_y - main / 2` (3.1 m with the starting `PLENUM`), and its inner top at `py + duct_y + main / 2`.
- The hatch is the duct's end in the plant room (23: 4.4 m, no false ceiling), so it hangs in the air. A fixed ladder climbs from the plant's floor to its sill, worked with the key (4.4).
- The shaft's landing is level with the duct floor: `air.shaft.floor_y == py + duct_y - main / 2`.
- `crawling_at()`, the crouched-capsule test and the bots' `route` all take these heights from `main_duct_geometry.gd` (4.5), which reads `manifest.plenum`. None has a constant of its own.

**What the generator guarantees for 1g (its validator checks it, `office_test` repeats it on 40 seeds):**

- **The shaft has a footprint.**
  - The exit side faces a void cell, or an off-grid strip at least 2.2 m deep.
  - `rect` is at least 2 × 2 m. Its near edge lies on the outer face of the last main cell's wall.
  - No room overlaps it: `FLOOR.room_at()` is empty at its centre and its four corners on planta 3.
- **The crossing has a side.** `air.main.cross` is a main node whose cell's network node has a network edge (trunk, branch, bridge or loose) perpendicular to the main there. `stub` is that edge's direction.
- **Nothing else of the ceiling is near the main duct.** On planta 3, within `main / 2 + 1.2` m in plan of the main's centre line, there is no gap and no ceiling or duct exit. A gap's plenum cell spans ±1.2 m, and its side panels would cut the duct.
- **The plant cell has room for the climb and the unit.**
  - The ladder's foot (4.5, `foot()`) is at least 1.0 m from the unit's box, from every doorway band and from every locker.
  - The unit's box is `office_palette.AIR_UNIT := Vector3(3.0, 2.2, 1.5)` (width, height, depth), back to the wall at `air.unit`, inside the plant cell.
  - `air.stop` is within 1.5 m of the unit's side.
- **The physics validator exempts main-duct cells** (the plant and every cell of `air.main`) from its "ceiling band" box (`py + 2.25` to `height - 0.05`). The duct runs through that band in every 4.4 m room it crosses (always the plant, also the air room or a service corridor), and so do the plant's ladder and its round ducts.

**What 1g asks of 1d:**

- **The duct goes through walls.** `office_geometry.wall_holes(room, direction) -> Array` returns `[along0, along1, y0, y1]` rects (4.5), and `office_run()` leaves them open: wall pieces round them, as round a doorway, and no occluder over them. Only walls taller than the duct's floor get one: the 4.4 m rooms', and the shaft's near wall. A 2.95 m room's walls stop under the duct.
- **Network ducts stay out of the main duct.** Geometry §5.5 draws no part of a network duct inside a main-duct box (it clips every network edge against `MAIN_DUCT.boxes(manifest)`), and network ducts have no collider. Otherwise the crawl is blocked, or another duct shows running through the inside of this one.
- **The card reader is on the lobby wall.** The planta-1 reader is on the freight lobby's wall at `mail.reader`. 1d keeps that wall stretch clear (no notice board, poster spot or clock) and has no `car_fronts` mount.

**Who builds what.** 1d builds the rooms, the glass partitions and the freight lift. It does not build the planta systems. Each system step builds its own static pieces:

- **In the room's `extras` step.** Every room piece is built from `office_geometry`'s `extras(node, room)` step (0e). So it is batched with its room, put on its layer, in the navigation bake, seen by `validate_physics()` and culled with the room.
  - Each step adds one line to `office_geometry.extras()`, calling a static builder of its own: `MAIL_GEOMETRY.extras(self, node, room)`, `POWER_GEOMETRY...`, `AIR_GEOMETRY...`.
  - Manifest points are world: local = point - `node.position` (room nodes are not turned).
- **The main duct and the shaft are the exception** (4.5): one holder of their own, on the plenum layer, built after the navigation bake.
- **The handlers own only what moves or lights at runtime.** The usables, levers, lamps, rotors and the hatch leaf, as `hotel_television.gd` owns its screen and `hotel_panel.gd` its door. A handler makes them in `place()`, after the build. It parents them to the room node and passes them to `level.hotel.adopt(node)` (hotel_geometry.gd:2087), so they take the room's layer.
- **Placement is shared.** Each step's builder exposes the transforms its handler needs (`station_xform`, `lever_xform` and so on), so a handle and its box are placed from one function.

| Step | Builder (`game/world/office/`) | Static pieces |
|---|---|---|
| 1e | `mail_geometry.gd` (2.6) | The window counter and its glass; the typewriter desk and the typewriter body; the ceiling camera's housing; each station's receiver, tray and number plate; the visible tube runs along every `tubes` edge (by the ceilings and the walls); the hub's mouth; the card reader plates at `mail.reader` and, called by 1g, at `air.security.reader` |
| 1f | `power_geometry.gd` (3.4) | The board's back plate and frame, one lever box per circuit plus the red one, their painted codes; the conduit from the board up to the ceiling; the minutero boxes at each `power.timers` spot |
| 1g | `main_duct_geometry.gd`, `air_geometry.gd` (4.5) | The main duct, the crossing stub, the hatch frame, the plant ladder, the shaft with its landing and ladder, the remains; the air handler's housing with its collars and round ducts to the slab, the stop box, the post console |

**Models.** Only registro entries marked `ok`:

- `equipos/pipes_modular_polyhaven` (1e): Poly Haven, CC0.
- `equipos/electric_cables_switches_polyhaven` (1f): Poly Haven, CC0.
- `equipos/duct_fans_circular_polyhaven` (1g): Poly Haven, CC0.
- `equipos/fire_escape_ladder_polyhaven` (1g): Poly Haven, CC0.
- `equipos/human_skull_oga` (1g): OpenGameArt, CC0.

Do not use `lever_switch_oga`: it is CC BY 3.0 and needs credits.

They go through 1d's pipeline: rows in `tools/props/ingest_models.py` (`PARTS`, `SCALE`), then `tools/props/build_catalogue.gd`, with the download rules of geometry §10 (staging folder, whitelisted files, no `.blend`, Python `-I`).

Primitives (the builder's `box()`, and a unit `CylinderMesh` scaled through `place()`) are used where no entry fits:

- the pneumatic station (`pneumatic_tube_station` is missing);
- the typewriter and the phone (login only);
- the counter;
- the board cabinet;
- the unit's housing;
- the hatch (`duct_access_hatch` is missing);
- the duct sheet;
- the plant ladder.

Every stand-in and every missing model goes to `docs/PLAN.md` section 4.

### 0.3 Decisions taken here (open in `docs/OFICINAS.md` 14; record them there as "decidido por los agentes, pendiente del autor")

1. **The card photo on the network:** each machine renders its own player's photo and sends it, as a JPEG of 320 x 240, through the host to everyone (section 2.4). Measured in 1i: size and arrival time are logged. The target is at most 24 KB and under 1 s on loopback.
2. **Cards are objects.**
   - A card is held by a seat. The reader counts cards, not people ("con las fichas de la cuota").
   - The quota is `session.minimum_survivors()` (game_session.gd:97).
   - A holder who dies drops their cards where they fall, and anybody can pick them up.
   - Only the owner takes their card out of a tray, unless the owner is dead.
3. **The freight lift of planta 2:** once the red lever's timer has run out the car is armed. Its button only works with at least the quota inside the car. It never leaves by itself, so the team can wait for whoever pulled the lever.
4. **The red lever is one-way.** Once up, it cannot be put down. The zone levers are dead while it runs and after.
5. **The planta-3 hatch is under the lockdown** until the fans have been started once from the post, so the three beats are mandatory. It never opens while they run.
6. **A stage given back is given back whole:**
   - planta 1: requests, capsules, cards and swipes;
   - planta 2: levers, minuteros and the red lever;
   - planta 3: charges, fans, post and hatch.

   Cards of planta 1 survive a planta-3 restart.
7. **The way up to the hatch is a ladder worked with the key** (ENTRAR, and BAJAR from inside), not climbable steps. The engine has no ladder physics, and a 3.1 m stair does not fit the plant beside the unit.
8. **The shaft has no lamp.** Planta 3 has no power and the shaft is outside the building: the torches light it.

---

## 1. Shared infrastructure (first part of step 1e)

### 1.1 Objective base: new no-op members (`game/floors/objectives/objective.gd`)

Add these with defaults, so the hotel's `televisions_objective.gd` and `code_objective.gd` are untouched. The helpers of 0.2 (`v3`, `facing`, `spot_xform`, `before`) also go here.

```gdscript
## The actions a guest may ask the host for (match_net.request_office checks the list).
const ACTIONS: Array[String] = []
## Host: whether `seat` (its body `body`) may do `action` on `index` now.
func allow(_action: String, _index: int, _seat: int, _body: Node3D) -> bool: return false
## Every machine: the action done. On the host `data` is empty and the handler
## decides the outcome and returns it; elsewhere `data` is that outcome. Idempotent.
## `quiet`: caught up (catch-up, Continuar), nothing heard.
func apply(_action: String, _index: int, _seat: int, _data: Dictionary, _quiet: bool) -> Dictionary: return {}
## Host: a guest's request refused, told back to it (the dead-button sound).
func refused(_action: String, _index: int, _seat: int) -> void: pass
## Whether a car may leave with these riders (lifts.press).
func allows_ride(_car: int, _riders: Array) -> bool: return true
## 0..1, how much of every sound at `point` is covered (air handler).
func sound_mask(_point: Vector3) -> float: return 0.0
## Host: a survivor fell at `point` (executions.gd:392).
func on_death(_seat: int, _point: Vector3) -> void: pass
## The papers this seat keeps (TUS NOTAS), as hint dictionaries (id, kind, ...).
func own_papers(_seat: int) -> Array: return []
## What a usable of this handler says and how long it is held (office_usable.gd).
func word_of(_node: Node3D, _seat: int) -> String: return ""
func hold_of(_node: Node3D, _seat: int) -> float: return 0.0
func begin_use(_node: Node3D, _seat: int) -> void: pass
func holding(_node: Node3D, _seat: int, _fraction: float) -> void: pass
func cancel_use(_node: Node3D, _seat: int) -> void: pass
## Whether a point is inside a crawl space of this handler (air only).
func crawling_at(_point: Vector3) -> bool: return false
## The test bots' errands (tools/bots/bot_team.gd), and the observer's lines.
func bot_errands(_team) -> Array: return []
func debug_lines() -> Array: return []
```

`restore(data)` gains `quiet := true`.

Delegates in `hotel_main.gd`, next to 0b's delegates (beside `off_limits_rooms()`, line 1343):

- `ride_allowed(car, riders) -> bool`: the AND of the stage's handlers.
- `sound_mask(point) -> float`: the max over all handlers.
- `own_papers() -> Array`: `code.own_hints()` followed by each handler's `own_papers(player.slot)`.
- `objectives_on_death(seat, point)`.
- `crawling_at(point) -> bool`.

For the hotel each returns what the code returns today: `true`, `0.0`, `code.own_hints()`, nothing, `false`.

### 1.2 The usable base (`game/world/interactables/office/office_usable.gd`)

One base for everything worked by hand on floor 2, so `interaction.gd` and the bots get one branch each instead of ten.

```gdscript
extends Area3D
## A thing of the offices worked by hand: its handler (files, power, air) says
## what the bracket reads and how long it is held; using it asks the host.
var level
var handler            ## its objective
var action := ""       ## what using it asks: "type", "take", "swipe", "pick", "lever", "red", "switch", "post", "start", "stop", "hatch", "climb", "ladder"
var index := 0         ## its place in its handler's list: its name on the wire
var stand := Vector3.INF   ## where the body is put while it is held (INF: where it is)
var face_yaw := NAN        ## which way it is turned to face meanwhile (a body's rotation.y)
var box := Vector3(0.6, 0.6, 0.4)   ## the focus box, in front of the node (+Z out)
func _ready() -> void   ## group "office_usables", collision_layer 16, mask 0, a BoxShape3D centred at (0, 0, box.z * 0.5)
func word(seat: int) -> String: return handler.word_of(self, seat)
func hold_time(seat: int) -> float: return handler.hold_of(self, seat)
func begin(seat: int) -> void      ## local seat: player.transit to `stand`/`face_yaw` (hotel_player.step_transit, lines 721 to 737); then handler.begin_use
func holding(seat: int, fraction: float) -> void: handler.holding(self, seat, fraction)
func cancel(seat: int) -> void: handler.cancel_use(self, seat)
func use(seat: int) -> void: level.match_net.use_office(handler.ID, action, index, seat)
func aim_point() -> Vector3: return global_transform * Vector3(0, 0, box.z * 0.5)   ## for the bots' reach check
```

It is parented to its room node like `code_lock.place_panels()` (lines 156 to 166) and `put_in_room()` (lines 280 to 283), and adopted (`level.hotel.adopt(node)`), so it is culled and layered with the room.

**`game/app/interaction.gd`:** one branch after the container branch (lines 262 to 275) and before the car branch (line 278):

```gdscript
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
var using = null        ## the usable being held, kept until the key is let go
var use_time := 0.0

var usable = aimed if aimed is USABLE else null
if is_instance_valid(using) and not Input.is_action_pressed("interact"):
	using.cancel(level.player.slot)
	using = null
	use_time = 0.0
if (is_instance_valid(usable) or is_instance_valid(using)) and not level.player.hidden:
	var target = using if is_instance_valid(using) else usable
	var word: String = target.word(level.player.slot)
	if not word.is_empty():
		var need: float = target.hold_time(level.player.slot)
		if need <= 0.0 and Input.is_action_just_pressed("interact"):
			target.use(level.player.slot)
			was_held = true
			return
		if need > 0.0 and Input.is_action_pressed("interact") and (is_instance_valid(using) or Input.is_action_just_pressed("interact")):
			if not is_instance_valid(using):
				using = target
				use_time = 0.0
				target.begin(level.player.slot)
			use_time += delta
			target.holding(level.player.slot, use_time / need)
			level.ui.hold(use_time / need)
			if use_time >= need:
				using = null
				use_time = 0.0
				target.use(level.player.slot)
			level.camcorder.focus(word)
			level.ui.hint.text = ""
			was_held = true
			return
```

`using` survives the aim drifting while the body is turned to the desk; only letting go cancels.

Other changes in `interaction.gd`:

- In the long focus expression (line 328), add `usable.word(level.player.slot) if is_instance_valid(usable) else` before the door case.
- Add `read_paper(paper: Dictionary)` beside `read_hint()` (lines 111 to 120). It sets `reading_hint = int(paper.id)` and `player.reading = true`, calls `level.ui.show_hint(paper, level.paper_walls(paper))`, and plays the paper sound. It does not call `code.note_read()`. `close_document()` (line 100) already clears `reading_hint`.
- `toggle_sheet()` (line 54) passes `level.own_papers()` instead of `level.code.own_hints()`.
- `level.paper_walls(paper)` returns `code.hint_walls()` when the paper has no `planta`, else the `hotel.plan_walls` of that planta: the same filter as `code_lock.hint_walls()` (lines 356 to 362).

Focus words (Spanish, short, no «·» or «—»): ESCRIBIR, OCUPADA, RECOGER, PASAR FICHA, COGER, SUBIR, BAJAR, PULSAR, ENCENDER, PARAR, ABRIR, ENTRAR. An empty word means there is nothing to do there now: no bracket (`ui-says-little`).

### 1.3 Network: one generic request and state pair (`game/net/match_net.gd`)

Modelled on `use_television` / `request_television` / `television_state` (lines 416 to 440) and `use_panel` (line 501): offline or host does it now; a guest asks; the host judges and tells everyone.

```gdscript
# --- The office floor's systems (game/floors/objectives) ----------------------
func use_office(objective: StringName, action: String, index: int, seat := -1) -> void:
	if seat < 0: seat = level.player.slot
	var handler = level.objective(objective)
	if handler == null: return
	if not in_match() or net.is_host:
		if not handler.allow(action, index, seat, level.body_of_seat(seat)):
			handler.refused(action, index, seat)
			return
		tell_office(objective, action, index, seat, handler.apply(action, index, seat, {}, false))
		return
	request_office.rpc_id(1, String(objective), action, index)

## The host's own events (a capsule arriving, a timer running out, a card
## dropped): applied here already, told to the rest.
func tell_office(objective: StringName, action: String, index: int, seat: int, data: Dictionary) -> void:
	if in_match() and net.is_host: office_state.rpc(String(objective), action, index, seat, data)

@rpc("any_peer", "call_remote", "reliable")
func request_office(objective: String, action: String, index: int) -> void:
	if not net.is_host: return
	var handler = level.objective(StringName(objective))
	var seat: int = net.seat_of_peer(multiplayer.get_remote_sender_id())
	if handler == null or not handler.ACTIONS.has(action): return
	var body := body_of(seat)
	if body == null or not handler.allow(action, index, seat, body):
		office_refused.rpc_id(multiplayer.get_remote_sender_id(), objective, action, index)
		return
	var data: Dictionary = handler.apply(action, index, seat, {}, false)
	office_state.rpc(objective, action, index, seat, data)

@rpc("authority", "call_remote", "reliable")
func office_state(objective: String, action: String, index: int, seat: int, data: Dictionary) -> void:
	var handler = level.objective(StringName(objective))
	if handler != null and floor_live: handler.apply(action, index, seat, data, false)

@rpc("authority", "call_remote", "reliable")
func office_refused(objective: String, action: String, index: int) -> void:
	var handler = level.objective(StringName(objective))
	if handler != null: handler.refused(action, index, net.local_seat)

## A card's photo (files_objective): sent by the machine that took it, kept and
## passed on by the host. Only JPEG, only the sender's own seat, at most PHOTO_MAX_BYTES.
@rpc("any_peer", "call_remote", "reliable")
func office_photo(seat: int, bytes: PackedByteArray) -> void
```

`office_photo` on the host:

1. Check that the sender's seat equals `seat`, that `bytes.size() <= files.PHOTO_MAX_BYTES`, and that `bytes[0] == 0xFF and bytes[1] == 0xD8`.
2. Then `files.keep_photo(seat, bytes)` and `relay(&"office_photo", [seat, bytes], sender)` (lines 286 to 291).

On a guest: `from_host()` (line 293), then keep it. The host's own photo goes out with `office_photo.rpc(seat, bytes)`.

**What every `allow()` checks:**

- the body is alive, not hidden, and not riding (`level.lifts.riding`);
- it is on the right planta;
- it is within `USE_REACH := 2.5` m of the usable. The host's copy of a guest runs behind, so add `RIDE_SLACK` (0.5, lifts.gd:251), as `lifts.inside()` does (line 308).

Bots go through `use_office(..., seat)` offline (bot_match), as they do with `use_container`.

**Protocol:** new RPC methods change the method table, so bump `net_session.PROTOCOL` (net_session.gd:39, today `"the-four-net-20"`) once for the floor-2 release, to `"the-four-net-21"`. If 0c already bumped it in this unreleased stretch, keep 0c's value.

### 1.4 Save and catch-up

- **Catch-up.**
  - `match_net.catch_up()` (lines 1045 onward) sets `progress["objectives"] = {String(id): handler.snapshot()}` for every handler of the floor. 0b may already do it for the hotel handlers; then only the office snapshots are new.
  - `hotel_main.catch_up_progress()` (line 1432) runs `for id in progress.get("objectives", {}): objective(StringName(id)).restore(progress.objectives[id], true)`, after the searched/panels part and before the stage change.
  - `world_audio.hush` is already true there (`match_net.restore()`, line 1079).
- **Save.** `floor_save.take()` writes `"objectives": {id: snapshot}`. `give()` restores them quiet right after `catch_up_progress`. Hotel saves without the key load as today, and hotel snapshots stay what 0b made them.
- **Photos** are in the files snapshot as `PackedByteArray`. Catch-up RPCs and `var_to_bytes` carry them; JSON is never used for snapshots.
- **Timers** are kept as `session.elapsed` values. The session pushes `elapsed` twice a second (`match_net.session_state`, line 359) and `floor_save` restores it, so a restored or caught-up timer goes on from where it was.

### 1.5 `game/world/generation/conduit_graph.gd` (shared by the tubes now and the ducts in phases 2 and 3)

1b creates `conduit_metres.gd` (generator §2.6: `adjacency()`, `metres()`, `pieces()`, a binary-heap Dijkstra). `conduit_graph` wraps it for the runtime and adds paths. If 1b or 1c already created a `conduit_graph.gd`, extend it to this API; otherwise create it with exactly this API.

```gdscript
extends RefCounted
## A network of conduits out of the manifest (the pneumatic tubes, her ducts):
## nodes, edges with their lengths, and the mouths sound comes out of. The same
## on every machine. Phase 2's duct_graph.gd extends it.
const METRES := preload("res://game/world/generation/conduit_metres.gd")
var nodes := PackedVector3Array()
var node_rooms := PackedInt32Array()     ## room of each node (-1: none)
var edges: Array = []                    ## [a, b, length, kind]
var adjacency: Array = []                ## node -> [[other, length, edge]]
var exits: Array = []                    ## {node, room, kind, number, position: Vector3, normal: Vector3}
var radiates := false                    ## true: sound leaves anywhere along it (tubes); false: only by its exits (ducts)
var closed := false                      ## phase 3: the fans close the ducts to her
static func from_manifest(data: Dictionary, radiate: bool) -> RefCounted
func connected() -> bool
func distances_from(node: int) -> PackedFloat32Array        ## METRES.metres(); INF where unreachable
func shortest(from: int, to: int) -> Dictionary               ## {path: PackedInt32Array, length: float}; empty path when none
func points_of(path: PackedInt32Array) -> PackedVector3Array
static func point_along(points: PackedVector3Array, metres: float) -> Vector3   ## clamped to the ends
func nearest_node(point: Vector3) -> int
func mouths_in_room(room: int) -> PackedInt32Array            ## radiates: every node with node_rooms == room; else exit nodes in the room
## How something travelling inside it at `source` (a point on it, with the
## node it is nearest along the way: `near_node`) reaches a listener: out of
## the mouth of the listener's room nearest it along the conduit, quieter
## with every metre inside. With no mouth in that room, out of the mouth
## nearest the listener within REACH and then by world_audio.route_source.
func sound_route(source: Vector3, near_node: int, listener: Vector3, room_of: Callable, world_audio) -> Dictionary
```

`from_manifest` reads both shapes:

- **Tubes:** `nodes: [[x, y, z]]` with `rooms: [int]`.
- **Ducts:** `nodes: [[x, y, z, room, kind]]`.
- **Edges** of both are `[a, b, metres, kind]`.
- **Exits** of both: `{node, room, kind, point, yaw}`. They become `position = v3(point)`, and `normal` is:
  - `facing(yaw)` for wall mouths (`hub`, `station`, `wall`);
  - `Vector3.DOWN` for `ceiling`, `gap` and `duct`;
  - zero otherwise (`hatch`).

`sound_route` returns the same shape as `world_audio.route_source()` (lines 428 to 474): `{audible, position, gain, cutoff, echo, distance}`.

Constants:

- `UNIT := 6.0`: the gain is `-20 * log10(1 + inside / UNIT)`.
- `REACH := 40.0` metres along the conduit. Beyond it, inaudible.
- `CUTOFF := Vector2(6000, 1400)`, lerped by `inside / REACH`.
- `LOSS := -3.0` dB for leaving the conduit.

A listener on another planta never hears it (`FLOOR.planta_of`). `room_of` is `func(p): return int(FLOOR.room_at(level.manifest.rooms, p).get("id", -1))`.

### 1.6 Moving sounds (`game/audio/world_audio.gd`)

A long cue that is re-routed by a callable instead of from a fixed point, for the capsule now and her in the ducts later:

```gdscript
## A long sound whose way to the listener is asked of `where` (a Callable taking
## the listener's position and returning a route like route_source) every
## MOVING_REROUTE. loop: replayed until stop_long.
const MOVING_REROUTE := 0.1
func play_moving(path: String, where: Callable, gain: float, loop := false, tag := "") -> AudioStreamPlayer3D
```

Implementation:

- It works as `play_long()` (line 298), with `cue["where"] = where` and `cue["loop"] = loop`.
- In `route_long()` (line 341), a cue with `where` calls it and goes through `apply_route()`.
- `update_long()` (line 363) re-routes such cues every `MOVING_REROUTE`.
- A looping cue replays on `finished`.

Nothing changes for cues without `where`.

**The sound mask (air handler, section 4):** `func mask_db(bus: String) -> float` returns `level.sound_mask(listener_position())` times:

- `MASK_EFFECTS_DB := -10.0` for `"Effects"`;
- `MASK_THREAT_DB := -18.0` for `"Threat"` and the creature buses.

It is added to the gain in `apply_route()` (line 493) and in `play_everywhere()` (line 263), except for cues tagged `"fans"`. The hotel's `sound_mask()` is 0, so nothing moves on floor 1. Bus volumes stay the settings' (settings_service.gd 424 to 431 owns them).

### 1.7 `game/app/photo_desk.gd`: `code_lock.develop_photo()` generalised

Take the rendering out of `code_lock.develop_photo()` (lines 300 to 345) without changing the Polaroid:

```gdscript
extends RefCounted
## A picture of the world as it is this instant, from a camera of its own on
## the same World3D: two frames drawn into a SubViewport with the rooms asked
## for shown just before each (the round of the rooms hides what the player
## does not see), then the image. Nothing on a headless machine.
const POLAROID := {"size": Vector2i(512, 512), "fov": 58.0, "flash": true, "grey": false, "fill_body": false}
const CCTV := {"size": Vector2i(320, 240), "fov": 74.0, "flash": false, "grey": true, "fill_body": true}
static func develop(level, eye: Vector3, target: Vector3, rooms: Array, style: Dictionary) -> Image   ## await it; null headless or if freed
static func to_jpeg(image: Image, quality := 0.7) -> PackedByteArray
static func texture_of(bytes: PackedByteArray) -> ImageTexture       ## null if not a JPEG
```

- **Layers.** The camera keeps Camera3D's default `cull_mask` (all 20 layers).
  - That includes layer 2, the local player's own first-person body (`avatar_visual.gd:88`, `mesh.layers = 2 if first_person else 1`), which the player's own camera leaves out (`player.tscn`, `cull_mask = 1048573`). So the typist's own back is in the picture with no layer juggling.
  - It also includes value 8, the plenum layer (geometry 8.1).
  - Remote bodies and the creature are on layer 1, or on a room layer under Muy bajo (0e's `put_on_actor`): also drawn.
- **`fill_body`.** On `level.hotel.static_light` (Muy bajo), lamps light only their room's layer (`room_layers.light_only`), so the layer-2 body would come out black.
  - For the two frames, add an `OmniLight3D` with `light_cull_mask = 2`, no shadow, `omni_range = 6.0`, `light_energy = 0.8`, at the window room's lamp height above the typist.
  - It lights only layer 2, which the player's own camera never draws, so nothing visible changes on screen.
- **`grey`.** The image is turned to luminance with a little contrast (`v = clamp((l - 0.5) * 1.25 + 0.52, 0, 1)`) on the CPU, which is cheap at 320 x 240: a security camera's print.
- **`code_lock.develop_photo(hint)`** keeps its signature and early returns. It computes `eye`/`target` as now and does `var image: Image = await PHOTO_DESK.develop(level, eye, target, [room_node], PHOTO_DESK.POLAROID)`. The rest (`hint.photo`, `show_photo` on the lying papers) is unchanged. The Polaroid must look the same: compare with `tools/capture/notes_capture.gd` before and after.

### 1.8 Numbers, noises and recordings

**Difficulty (`game/floors/difficulty.gd`, the Lurker's profile from 0f):** these are the office floor's systems, kept with its creature so `level.tuning()` hands them over.

| Key | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| `typing_time` (s) | 4.5 | 5.0 | 5.0 | 5.5 |
| `board_budget` (zones on at once, K) | 3 | 3 | 2 | 2 |
| `lift_timer` (s, red lever) | 45 | 60 | 75 | 90 |
| `timer_switch` (s, every minutero) | 90 | 75 | 60 | 45 |
| `fan_charges` | 2 | 2 | 1 | 1 |
| `fan_time` (s) | 90 | 80 | 70 | 60 |

`timer_switch` is the only source of a minutero's time: the manifest's timers carry no seconds. Add the keys to `difficulty_test`: every Lurker profile has all six, and the Locust's profiles have none of them.

**Noises (`game/audio/noise_kinds.gd`, `HEARD`, lines 28 to 40).** New keys only, no new `Kind`: a new Kind would need new entries in `echo_view.gd`'s PUFF arrays and on the wire.

| Key | Radius | Kind |
|---|---|---|
| `"typing"` | 30.0 | `Kind.HUM` |
| `"station"` | 9.0 | `Kind.DOOR` |
| `"lever"` | 40.0 | `Kind.DOOR` |
| `"red_lever"` | 62.0 | `Kind.DOOR` |
| `"switch"` | 12.0 | `Kind.DOOR` |
| `"hatch"` | 36.0 | `Kind.DOOR` |
| `"crawl"` | 14.0 | `Kind.FOOTSTEP` |
| `"ladder"` | 20.0 | `Kind.FOOTSTEP` |

**Recordings:**

- 1d creates `tools/audio/prepare_office_sfx.py` (geometry §10.3, modelled on `tools/audio/prepare_lift_sfx.py`: ffmpeg decode, mono, 44.1 kHz, trim, fade, common peak, deterministic) for its own sounds: the freight gate, descent and hum.
- 1e adds the rows below to that script, written to `assets/audio/sfx/office/`.
- Only entries marked `ok` in each group's `registro.json`, CC0 or Pixabay first.

| Copy | Source (registro slug, file) | Licence | Use |
|---|---|---|---|
| `typing.wav` (loopable 6 s of steady keys) | audio_oficina `maquina_escribir`, `bsb_2835_typewriter_2.wav` | CC0 | the hold at the desk |
| `typing_bell.wav` | `maquina_escribir`, `bsb_2844_typewriter_bell_1.wav` | CC0 | the request done |
| `tube_hiss.wav` (loop) | `tubo_neumatico`, `bsb_0138_compressed_air.wav` | CC0 | the capsule running (stand-in for NoiseCollector's real tube, which needs a login) |
| `tube_bell.wav` | `tubo_neumatico`, `bsb_1922_industrial_bell_2.wav` | CC0 | arrival at a station |
| `lever_1..3.wav` | audio_edificio `breaker_lever_clack`, `bsb_3061..3063_industrial_switch_*.flac` | CC0 | a lever thrown, the reader's clunk (shortest cut) |
| `breaker.wav` | `breaker_lever_clack`, `bsb_1092_electric_circuit_breaker.flac` | CC0 | the oldest zone dropping |
| `tick.wav` (loop) | `mechanical_timer_ticking`, `bsb_0082_timer_2_kitchen.flac` | CC0 | the red timer and the minuteros |
| `lift_motor.wav` | `freight_lift_motor`, `bsb_1712_elevator_6_floors.flac` (another cut than 1d's descent) | CC0 | the freight lift armed |
| `fans.wav` (loop) | `ventilation_fans_full`, `bsb_3598_ventilation_5.flac` | CC0 | the fans |
| `hatch.wav` | audio_oficina `taquillas_metalicas`, `bsb_0773_metal_filing_cabinet.wav` | CC0 | stand-in for the cam latches |
| `crawl_1..2.wav` | audio_edificio `crawl_sheet_metal`, the two Pixabay Ev-Dawg files | Pixabay | stand-in; the real crawl (Ultra-Edward) needs a login |
| `ladder.wav` | `metal_ladder_climb`, `pixabay_76052_ladder_aluminum_erik90.mp3` | Pixabay | the plant ladder and the shaft ladder |

Register them in `docs/ASSETS.md` and `docs/asset_hashes.json`, as the other `prepare_*` outputs are. The stand-ins and the missing recordings (real tube, real crawl, scissor gate) go to `docs/PLAN.md` section 4. No synthesised human sound anywhere: no beeps of a voice, no breathing.

---

## 2. Step 1e: planta 1, the post (`files`)

### 2.1 Files

- `game/floors/objectives/files_objective.gd` (`ID := &"files"`)
- `game/world/interactables/office/typewriter_desk.gd`, `tube_station.gd`, `capsule.gd`, `card_reader.gd`, `card_pickup.gd`
- `game/world/office/mail_geometry.gd` (2.6), and the `pipes_modular_polyhaven` rows in `tools/props/ingest_models.py`
- Changes:
  - `objective.gd`, `hotel_main.gd`, `interaction.gd`, `match_net.gd`, `net_session.gd`, `floor_save.gd`, `code_lock.gd`, `world_audio.gd`, `noise_kinds.gd`, `difficulty.gd`, `camcorder_osd.gd` (`date_parts`);
  - `executions.gd` (one call);
  - `revival.gd`: 0b did NOT route the restart through `reset()` (nobody calls it; revival.gd:154-166 still switches the stage's sets off, sends `television_state` and clears `goal.blackout` itself). 1e adds, in `apply_revival()` on every machine, `for h in level.stage_objectives(): h.reset()`, and leaves the hotel's own block as it is (the televisions handler's `reset()` stays a no-op, so floor 1 does not change);
  - `office_geometry.gd` (one line in `extras()`);
  - `office_floor.gd` (`OBJECTIVES` gets `"files"`).

### 2.2 State

```gdscript
enum Card { TRAVELLING, IN_TRAY, HELD, DROPPED }
## Seat -> the request typed for it this stage:
## {station:int, state:Card, holder:int, swiped:bool, number:String, sent:float (session.elapsed when the capsule left),
##  drop:Vector3 (DROPPED only), alta:[d, m, y]}
var requests := {}
var swiped: Array = []          ## owner seats whose card went through the reader, in order
var typing := {}                ## seat -> session.elapsed when it started typing (host and everyone, for the sound)
var photos := {}                ## owner seat -> PackedByteArray (JPEG)
var textures := {}              ## owner seat -> ImageTexture, made from photos on demand
var pending_photo := {}         ## local only: seat -> Image waiting for its request to be confirmed
var desk; var reader; var stations: Array = []; var pickups := {}   ## nodes
var station_exits: Array = []   ## the "station" entries of tubes.exits, in list order (station index = place here)
var tubes                       ## conduit_graph, radiates = true
var capsules := {}              ## owner seat -> capsule.gd node while travelling (every machine)
var noise_clock := 0.0          ## host: seconds to the next typing noise
var noise_log: Array = []       ## [point, radius] of the typing noises made (tests), at most 32
```

Constants:

- **Timing:** `TYPE_PHOTO_AT := 0.6` (share of the hold), `TYPE_NOISE_EVERY := 1.0`, `SEND_DELAY := 1.2` (the typing bell, then the capsule leaves), `CAPSULE_SPEED := 6.0`.
- **Holds:** `TAKE_TIME := 1.5`, `SWIPE_TIME := 0.5`, `PICK_TIME := 1.0`.
- **Photo:** `PHOTO_QUALITY := 0.7`, `PHOTO_MAX_BYTES := 24576`.
- **Papers:** `PAPER_BASE := 1000`. Paper ids are `PAPER_BASE + seat * 10 + 0` for the receipt and `+ 1` for the card, clear of the hint ids.
- **Gains:** `TUBE_HISS_DB := -8.0`, `BELL_DB := -2.0`, `TYPING_DB := -6.0`.

`ACTIONS := ["type_begin", "type_end", "type", "take", "swipe", "pick"]`. Host-only events: `"sent"`, `"arrived"`, `"drop"`, `"reset"`.

The generator guarantees every station is at least `STATION_TUBE_MIN` of tube from the hub, so the handler has no route minimum of its own.

### 2.3 Behaviour

- **`settle()`:** nothing to settle before the build beyond reading the manifest. Stations are assigned at typing time by the host.
- **`place()`:**
  - Build `tubes = CONDUIT.from_manifest(manifest.tubes, true)`.
  - One `typewriter_desk` at `MAIL_GEOMETRY.desk_xform(manifest)`, with stand `mail.stand.point` and face `mail.stand.yaw`.
  - One `tube_station` per entry of `station_exits`, at `MAIL_GEOMETRY.station_xform(exit)`.
  - One `card_reader` at `mail.reader`, with stand `before(mail.reader, 0.6)` and face `mail.reader.yaw`.
  - The network map paper (step 1h: a `hotel_hint`-style paper of kind `"red"`) at `mail.map`.
  - The ceiling camera's housing is static (2.6); the handler adds nothing there.
- **Typing.**
  - `desk.word` is `"ESCRIBIR"` for a living seat with no request this stage, `"OCUPADA"` while another seat types, and `""` otherwise. The hold is `tuning().typing_time`.
  - `begin_use`: the body steps to `mail.stand` turned to its yaw (facing the typewriter, back to the room), `player.reading = true` (no walking, no looking), and `use_office(files, "type_begin")`.
  - `holding(fraction >= TYPE_PHOTO_AT)`, once per attempt, local seat only: `snap()` (2.4).
  - `cancel_use`: `player.reading = false`, `"type_end"`.
  - Done: `player.reading = false`, `"type"`.
- **`apply("type_begin")`:** `typing[seat] = elapsed`. Start the `typing.wav` loop at the desk (`play_moving` with a fixed route, tag `"typing"`), unless quiet. `"type_end"` stops it.
- **Host `tick()`:** every `TYPE_NOISE_EVERY` while anybody types, `level.on_noise(desk point + 1 m up, NOISE.radius("typing"), NOISE.Kind.HUM)`, appended to `noise_log`.
- **`apply("type")` on the host chooses the station:**
  - Take the stations not assigned to a live request, shuffled by `hash([seed, "station", seat, restarts])`, and use the first. If all are taken, use the least used.
  - Data: `{station, number: "P-%04d" % (hash([seed, "ficha", seat]) % 9000 + 1000), alta: camcorder date_parts}`.
- **`apply("type")` everywhere:**
  - The request is `TRAVELLING`, with `sent = elapsed + SEND_DELAY`.
  - The typing loop stops and `typing_bell.wav` plays at the desk.
  - The receipt is added to the seat's papers and, for the local seat, held up (`interaction.read_paper`).
  - On the typist's own machine the pending photo is now sent (2.4).
- **The capsule** (`capsule.gd`, a `Node3D` under the hotel):
  - `setup(level, tubes, path_points, sent, speed)`. Every machine creates it from the same request, so nothing about where it is travels on the wire. The path is `tubes.shortest(tubes.exits[tubes.hub].node, station_exits[station].node)`.
  - `point()` is `CONDUIT.point_along(points, (elapsed - sent) * CAPSULE_SPEED)`.
  - Its hiss is `world_audio.play_moving("tube_hiss.wav", func(listener): return tubes.sound_route(point(), near_node(), listener, room_of, world_audio), TUBE_HISS_DB, true, "capsule")`. It starts when `elapsed >= sent` and stops at the end.
  - Arrival time is `sent + length / CAPSULE_SPEED`: 25 to 120 m of tube, so 4 to 20 s.
- **Arrival.**
  - Host `tick()`: a `TRAVELLING` request past its arrival becomes `IN_TRAY` and is told (`tell_office(files, "arrived", station, seat, {})`).
  - Everywhere on `"arrived"`: the station's lamp turns on, the capsule shows in its tray, `tube_bell.wav` plays at the station (`play_at`, `BELL_DB`), and the capsule node is freed.
  - A guest's local capsule that reaches its end first only stops its hiss. The bell and the lamp wait for the host's word (latency at most a few frames).
- **The station** (`tube_station.gd`), a usable with `action = "take"`:
  - Word `"RECOGER"` when its request is `IN_TRAY` and the seat is the owner or the owner is dead. Hold `TAKE_TIME`.
  - The body steps to `before(exit, 0.55)`, turned to `exit.yaw`: facing the wall, back to the room.
  - Lamp: an emissive bulb and an `OmniLight3D` (amber `Color(1.0, 0.62, 0.25)`, range 1.5, energy 0.6, no shadow, `ROOM_LAYERS.light_only(light, room bits)` when the rooms have layers). It is on only while a card waits.
  - `apply("take")`: the request becomes `HELD` with `holder = seat`; the lamp goes off; the capsule hides; the host makes the noise `"station"`. The card is added to the taker's papers and, for the local seat, held up.
  - A card is always the owner's card (its photo and name), whoever holds it.
- **The reader** (`card_reader.gd`), a usable with `action = "swipe"`:
  - Word `"PASAR FICHA"` while the seat holds an unswiped card. Hold `SWIPE_TIME`.
  - `apply("swipe")`: the first unswiped card held by that seat gets `swiped = true`, and its owner is appended to `swiped`. `lever_1.wav` clunks, and the pilot goes from red to green for 1.5 s.
  - One card per use.
  - It stands in the freight lobby (19), beside the stage gate door: that door is locked until the quota is swiped, so the reader must be on the lobby side.
- **Progress:**
  - `ready = swiped.size() >= session.minimum_survivors()`, `kind "files"`, `done = swiped.size()`, `needed = quota`, `lines [["FICHAS", "%d / %d"]]`.
  - `host_gate` then unlocks gate 0, the stage gate door 19↔9 (`hotel.open_gates`, hotel_geometry.gd 1936 to 1944, from `on_state`, hotel_main.gd 1031).
  - Then the car takes whoever is in it, as in the hotel (`lifts.ride_lifts`, lines 253 to 283).
- **Death.**
  - In `executions.gd` at line 392, right after `level.session.capture(seat)` (and at 396 for the partner), add `level.objectives_on_death(seat, body point)`.
  - `files.on_death`: every card `HELD` by that seat becomes `DROPPED` at the body point, snapped to what is under it by a ray (mask 1) from 0.5 m above. In the duct that is the duct's floor, not the planta's. Then `tell_office(files, "drop", owner, holder, {"at": point})`.
  - Everywhere: a `card_pickup` at that point: the card's far texture on a 0.2 x 0.13 plane, a usable with `action = "pick"`, word `"COGER"`, hold `PICK_TIME`.
  - `apply("pick")`: the card is `HELD` by the picker, and the pickup is freed.
  - Also call `objectives_on_death` from wherever `session.drop(seat)` is called for a seat gone for good, with the last known body position.
- **Restart** (`reset()`, called on every machine by `revival.apply_revival(places, restart, ...)` at line 125; 1e wires that call, see the `revival.gd` change above): all of this stage is cleared. Capsules and their sounds stop, lamps go off, pickups are freed, and this stage's photos are dropped. Gate 0 is relocked there already (`relock_gate`, revival.gd:154).
- **`goal_points(1)`:** the stand while somebody has no request, stations with a card in the tray, and the reader while cards are held unswiped.
- **`own_papers(seat)`:** the receipts and cards of this seat (2.5). Cards held by the seat are listed (with the owner's photo); receipts only for its own requests.
- **`snapshot()`:** `{requests, swiped, photos}`. Requests carry `sent`, so a capsule caught up mid-way is rebuilt at the right place.
- **`restore(data, quiet)`:** rebuild the requests; the capsules still travelling (hiss on, no bell); the lamps and tray capsules of `IN_TRAY`; the pickups of `DROPPED`; the textures from the photos.
- **`bot_errands(team)`:** see 6.4.
- **For planta 3:** `func held_cards(seat) -> Array` (owners) and `func has_card(seat) -> bool`.

### 2.4 The photo of the card

- **Where:** from `mail.camera`, looking at `mail.camera_target`. The ceiling band between the camera and the typist is in frame: where she would hang. The generator writes both points; there is no fallback.
- **When:** at `TYPE_PHOTO_AT` of each attempt, on the typist's own machine only: `var image = await PHOTO_DESK.develop(level, eye, target, [window room node], PHOTO_DESK.CCTV)`. It is kept in `pending_photo[seat]`, and a new attempt overwrites it. It is the world as it is at that moment, so in phase 3 whatever is behind the typist is in it, put there by nobody.
- **Sent:** when this machine applies `"type"` for its own seat.
  1. `bytes = PHOTO_DESK.to_jpeg(image, PHOTO_QUALITY)`.
  2. If that is over `PHOTO_MAX_BYTES`, use quality 0.55, and then 256 x 192.
  3. `keep_photo(seat, bytes)` locally, and `match_net.office_photo` (to the host as a guest, to everybody as the host).

  A photo for a seat without a request is ignored. Headless (tests, bots), there is no image and nothing is sent: the card's photo box stays empty.
- **Kept:** in `photos[seat]` and in the snapshot (catch-up, Continuar). It shows on the card (`form.photo = texture`) when read, and in TUS NOTAS.
- Log `PHOTO_BYTES seat=%d bytes=%d` once per photo: the measurement 1i asks for.

### 2.5 The papers of planta 1 (data here; how they look is step 1h)

```gdscript
## The receipt: kind "resguardo", form {paper: "resguardo", station: "7", number, time: [h, m]}
{"id": PAPER_BASE + seat * 10, "kind": "resguardo", "planta": 0, "form": {...}}
## The card: kind "ficha", form {paper: "ficha", name: level.seat_name(owner), number, department: "SERVICIOS GENERALES",
##   date: alta, level: "1", seed: owner, photo: textures.get(owner)}
{"id": PAPER_BASE + owner * 10 + 1, "kind": "ficha", "planta": 0, "form": {...}}
```

`camcorder_osd.start_tape()` (lines 140 to 147) also stores `date_parts = [day, month + 1, year % 100]`, so the card's ALTA is the tape's date. No «·» or «—» in any of it.

### 2.6 Static pieces (`game/world/office/mail_geometry.gd`)

```gdscript
extends RefCounted
## What of the post does not move, built with its room by office_geometry.extras().
## Materials are the builder's (1d's OFFICE_MATERIALS and the hotel's).
const COUNTER := {"depth": 0.5, "top": 1.05, "length": 2.4, "hole": 0.14, "tray": Vector2(0.36, 0.05)}
const DESK := "metal_office_desk"          ## 1d's catalogue model; its point is mail.desk
const TYPEWRITER := Vector3(0.46, 0.2, 0.38)
const CAMERA := Vector3(0.12, 0.1, 0.24)   ## housing; lens at its -Z end, a wall bracket to the nearest wall
const STATION := Vector3(0.36, 0.52, 0.24) ## receiver body: tray at the exit point, body from -0.12 to +0.4 about it
const PLATE := Vector2(0.16, 0.1)          ## number plate, under the tray
const TUBE_RADIUS := 0.055
const CLAMP_EVERY := 1.5
const READER := Vector3(0.12, 0.2, 0.06)
static func extras(builder, node: Node3D, room: Dictionary) -> void
static func desk_xform(manifest: Dictionary) -> Transform3D        ## the typewriter on the desk
static func station_xform(exit: Dictionary) -> Transform3D         ## the tray's centre, +Z into the room
static func reader(builder, node: Node3D, spot: Dictionary, words: String) -> void   ## 1g calls it for the post
```

- **Window counter and glass.**
  - The window room has its corridor side glazed (the generator's `glazed`: ventanilla against a corridor). `office_test` asserts it.
  - The counter runs along the inside of that glazed side, on its longer stretch beside the doorway: a laminate shelf `COUNTER.depth` deep with its top at `COUNTER.top`, `COUNTER.length` long, on two steel brackets, with a box collider.
  - Under the glass at the sill, a steel deal tray (`COUNTER.tray`) passes through to the corridor side.
  - In the pane over the counter's middle, a round speaking grille: a 0.14 m ring of 12 small `steel_frame` boxes.
  - On the corridor side over the glass, a `text()` "VENTANILLA DE PERSONAL" (size 22, ink `Color("e8e4d6")`).
- **Desk and typewriter.**
  - The desk is `metal_office_desk` (1d's catalogue) at `mail.desk`, its back to the wall, with a box collider.
  - The typewriter body sits on it from primitives: an olive enamel body box, a platen cylinder, and a key bank as a small multimesh of 0.012 boxes.
  - A paper tray and a stack of blank forms (`office_notepads_a4`, hotel catalogue) sit beside it.
  - The typewriter model goes to PLAN.md (only login candidates exist).
- **Ceiling camera.** At `mail.camera`, turned to look at `mail.camera_target` (`Transform3D.looking_at`; runtime only, never stored). A dark housing box with a lens cylinder, and a bracket to the nearest wall.
- **Stations.** For each station exit, at `station_xform(exit)`:
  - the receiver body box (`steel_frame` olive), with a hinged flap above the tray (static here);
  - the tray (an open half-cylinder of 4 boxes, where the handler shows the capsule);
  - the number plate (`PLATE`, enamel) under it, with `text("%d" % number)`;
  - a box collider on the body.
  - The tube rises from the body's top to `TUBE_Y` (part of the tube runs below).
- **Tube runs.**
  - An edge belongs to the room containing its midpoint (`FLOOR.room_at(rooms, mid)`), so each is built once.
  - Each straight is one unit `CylinderMesh` (radius `TUBE_RADIUS`, 12 sides) placed with `builder.place()`, scaled along its axis to the edge length less the bend allowances, in `galvanized`.
  - At a node with two non-collinear edges: the kit's 90° bend (the `modular_pipes` elbow part, scaled to `TUBE_RADIUS`). At a node with three: the kit's tee.
  - Clamps every `CLAMP_EVERY`: a ring and a 6 mm hanger rod up to the false ceiling on horizontal runs, a wall bracket on vertical drops.
  - Where an edge ends at a doorway portal (it crosses the wall header at `TUBE_Y`), a collar on each face of the wall.
  - No colliders: the runs are above 2.2 m or flat on a wall, and the validator's rays and ceiling band test colliders only.
- **Hub.** The sending mouth beside the desk, at the hub exit: the same receiver body with a brass bell box.
- **Reader plates.** `reader(builder, node, mail.reader, "SOLO PERSONAL REGISTRADO")`:
  - a steel box (`READER`) with a card slot (a black inset box) and two pilot sockets (the lamps are the handler's);
  - the stencil `text()` above it (size 16).

  1g calls it for `air.security.reader` with `""`.

---

## 3. Step 1f: planta 2, the power (`power`)

### 3.1 Files

- `game/floors/objectives/power_objective.gd` (`ID := &"power"`)
- `game/world/interactables/office/main_board.gd`, `timer_switch.gd`
- `game/world/office/power_geometry.gd` (3.4), and the `electric_cables_switches_polyhaven` rows in `tools/props/ingest_models.py`
- Changes: `lifts.gd` (`press`), `office_geometry.gd` (one line in `extras()`), `office_floor.gd` (`"power"`).

### 3.2 State and constants

```gdscript
enum Red { DOWN, RUNNING, ARMED }
var zones: Array = []           ## power.circuits, sorted by lever: {code, name, sector, colour, lever, rooms}
var lit_always: Array = []      ## PALETTE.always_lit(manifest, 1)
var on_order: Array = []        ## zone indices up, oldest first
var red := Red.DOWN
var red_started := 0.0          ## session.elapsed
var budget := 3                 ## tuning().board_budget, read in place(); tests may set it
var lift_timer := 60.0          ## tuning().lift_timer
var switch_time := 75.0         ## tuning().timer_switch, the same for every minutero
var switch_until: Array = []    ## per power.timers entry, session.elapsed when it goes out (0: out)
var applied := {}               ## room -> the power last given (set_room_power only on a change)
```

`ACTIONS := ["lever", "red", "switch"]`. Host events: `"armed"`, `"board"` (a full snapshot after each change), `"reset"`.

Constants: `LEVER_HOLD := 0.0` (a press), `RED_HOLD := 1.0`, `SWITCH_HOLD := 0.0`, `TICK_NEAR_DB := -6.0`, `TICK_EVERYWHERE_DB := -20.0`, `LEVER_DB := -4.0`, `MOTOR_DB := -6.0`.

### 3.3 Behaviour

- **`place()`:**
  - The board: one `main_board` node at `power.board`, holding `zones.size() + 1` lever usables. Indices `0..n-1` are the zones by `lever`; `n == power.lift_lever` is the red one.
  - The handles are separate `MeshInstance3D`s that swing 70 degrees about their pivots (`POWER_GEOMETRY.lever_xform(manifest, i)`), adopted onto the room's layers.
  - The legend memo (1h) beside the board.
  - One `timer_switch` per `power.timers` entry, at `POWER_GEOMETRY.timer_xform(entry)`: its round button and its pilot.
  - Then `refresh_power(true)`: every planta-2 room not in `lit_always` is unpowered.
- **The rule of a room** (planta 2). A room is powered if:
  - it is in `lit_always`; or
  - it is in the `rooms` of a minutero whose `switch_until > elapsed`; or
  - while `red == DOWN`, it is in the `rooms` of a zone in `on_order`.

  The electrical room is in none of these: it stays unpowered, under its emergency unit. `refresh_power()` calls `hotel.set_room_power(room, on)` only where `applied` differs. Emergency lamps and exit signs are not under it (1d keeps them apart).
- **`apply("lever", z)`.** Host and everyone do the same; the host sends the outcome as a board snapshot.
  - Refused unless `red == DOWN`.
  - Down → up: `on_order.append(z)`. If `on_order.size() > budget`, the head drops: `breaker.wav` at the board, and its handle falls.
  - Up → down: erased.
  - `lever_N.wav` at the board; host noise `"lever"`.
  - Word `"SUBIR"`/`"BAJAR"`; `""` once the red is up.
- **`apply("red")`:**
  - `red = RUNNING`, `red_started = elapsed`, `on_order.clear()`. Every handle falls together, with one `breaker.wav` and one `lever` sound. Host noise `"red_lever"`.
  - The planta goes dark but for `lit_always` and the minuteros.
  - The tick: `tick.wav` loops at the board (`TICK_NEAR_DB`), plus a `follow` cue (`play_long(..., follow = true)`, as the blackout does) at `TICK_EVERYWHERE_DB` while the listener is on planta 2, so it is heard over the whole planta.
  - The red one's word is `"SUBIR"` while `DOWN`; hold `RED_HOLD`.
- **Arming.**
  - Host `tick()`: `RUNNING` and `elapsed >= red_started + lift_timer` → `ARMED`, told.
  - Everywhere on `"armed"`: the tick stops, `lift_motor.wav` plays at the freight car, and from then on the progress is ready.
- **`apply("switch", i)`:**
  - `switch_until[i] = elapsed + switch_time`. Pressing a running one starts it again.
  - Its own tick loop plays at the switch, with a `lever_1.wav` click.
  - It goes out on every machine by the clock (each runs `tick()`), with a click.
  - It is allowed whatever the red lever is doing: the minuteros are the light of whoever crosses back.
- **Progress:** `ready = red == ARMED`; `kind "power"`; `done = on_order.size()`; `needed = budget`; `lines [["ZONAS", "%d / %d"]]` and, while running, `["MONTACARGAS", "%d s"]` left.
- **`allows_ride(1, riders)`:** `red == ARMED and riders.size() >= session.minimum_survivors()`.
  - `lifts.press(index)` (line 326) becomes `if car_ready(index) and level.ride_allowed(index, inside(index)): called[index] = true`.
  - Refused, it plays `lever_1.wav` at the car (the dead button) on that machine only.
  - Re-check in `ride_lifts()` before taking them.
  - Hotel: `ride_allowed` is true, nothing changes.
- **`reset()`:** everything down, red `DOWN`, minuteros out, ticks and motor stopped, `refresh_power(true)`.
- **`snapshot()`:** `{on, red, started, switches}`. `restore()` puts the handles where they were (no sound when quiet) and refreshes the power.
- **`goal_points(2)`:** the board while red is down, and the freight lobby (`manifest.refuges[1]`).

### 3.4 Static pieces (`game/world/office/power_geometry.gd`)

```gdscript
extends RefCounted
## The board and the minuteros' boxes of planta 2, built with their rooms by office_geometry.extras().
const BOARD := Vector3(2.6, 1.9, 0.12)     ## back plate (w, h, d) on the wall at power.board, bottom at 0.5
const LEVER_Y := 1.35                      ## pivot height over the floor
const LEVER_PITCH := 0.3
const RED_GAP := 0.2                       ## extra space before the red lever
const CONDUIT := 0.03                      ## radius of the runs to the ceiling
static func extras(builder, node: Node3D, room: Dictionary) -> void
static func lever_xform(manifest: Dictionary, i: int) -> Transform3D   ## pivot of lever i; shared with main_board.gd
static func timer_xform(entry: Dictionary) -> Transform3D
```

- **The board.**
  - A `steel_olive` back plate and frame (`BOARD`) in the electrical room.
  - Per lever, the cables kit's rusty switch box with a lever, body only. If the glTF separates the lever, `PARTS` keeps it apart and the handler uses it as the handle; otherwise the handle is procedural (a 0.25 m flat bar with a black grip).
  - Under each lever, its painted code and name via `text()` (`R-2`, size 18; `ARCHIVO`, size 10), from `power.circuits`.
  - The red lever's box is bigger (×1.3) and painted red (`Color("a3271f")`), with "MONTACARGAS" over it.
  - Box collider on the plate.
  - Levers are laid out from the left: `x = -BOARD.x / 2 + 0.25 + i * LEVER_PITCH`, plus `RED_GAP` for the red one. With 5 to 7 zones they fit in 2.6 m.
- **The conduits** from the plate's top up the wall to the false ceiling: the kit's conduit pieces, scaled.
- **The minuteros.** At each `power.timers` spot (`py + 1.2`), the kit's square switch box (0.08 × 0.08 × 0.04). The round button and its pilot are the handler's (the registro's note: no staircase timer exists, so adapt the square box).

---

## 4. Step 1g: planta 3, the air (`air`), the crawl and the ladders

### 4.1 Files

- `game/floors/objectives/air_objective.gd` (`ID := &"air"`)
- `game/world/interactables/office/air_handler.gd` (two usables: the post console's `"start"` and the unit's `"stop"`), `duct_hatch.gd` (the leaf and the release handle), `fixed_ladder.gd` (the plant ladder's two usables: the hatch's release, then the climb), `shaft_ladder.gd`. The post door's reader is a `card_reader.gd` in mode `"post"`.
- `game/world/office/main_duct_geometry.gd` and `air_geometry.gd` (4.5), and the `duct_fans_circular_polyhaven`, `fire_escape_ladder_polyhaven` and `human_skull_oga` rows in `tools/props/ingest_models.py`.
- Changes:
  - `hotel_player.gd`, `survivor_gait.gd`;
  - `tools/bots/bot_body.gd` (`crawling`);
  - `lifts.gd` (leaving by the ladder);
  - `hotel_main.gd` (the mask in `locust_hear`, or the name 0a gave it);
  - `sanity.gd` (`lit_at`);
  - `world_audio.gd` (the mask, 1.6);
  - `office_geometry.gd`: one line in `extras()`, the `build()` call, `wall_holes()`, `put_away()`, `follow_bodies()`;
  - `office_floor.gd` (`"air"`, `LEAVE := "ladder"`).

### 4.2 State and constants

```gdscript
var charges := 2                ## tuning().fan_charges
var fan_time := 80.0            ## tuning().fan_time
var running_until := 0.0        ## session.elapsed; 0 = stopped
var released := false           ## the lockdown lifted: the fans have been started once
var post_open := false
var hatch_open := false
var spin := 0.0                 ## 0..1 how far the fans are running, eased (every machine)
var lit_always: Array = []      ## PALETTE.always_lit(manifest, 2): the arrival lobby and the security post
```

`ACTIONS := ["post", "start", "stop", "hatch", "climb", "ladder"]`. Host events: `"stopped"`, `"reset"`.

Constants:

- **Fans:** `FAN_SPIN := 2.5` (s to full and to rest), `AIR_MASK := 0.65`.
- **Holds:** `POST_SWIPE := 0.5`, `START_HOLD := 1.0`, `STOP_HOLD := 1.0`, `HATCH_TIME := 2.0`, `CLIMB_HOLD := 0.5`, `LADDER_HOLD := 1.2`.
- **Climb:** `CLIMB_UP := 2.4`, `CLIMB_DOWN := 2.0` (transit seconds).
- **Gains:** `FAN_ROAR_DB := -6.0` (the follow cue on planta 3), `FAN_NEAR_DB := 0.0`.

### 4.3 Behaviour

- **`place()`:**
  - Every planta-3 room not in `lit_always` is unpowered (`set_room_power`).
  - The post door: the hotel door whose `doorway` is within 0.1 m of `FLOOR.portal_between()` of the two rooms of `air.security.door`. It is set `locked = true`, as the gates are.
  - Its reader (`card_reader`, mode `"post"`) at `air.security.reader`, with stand `before(spot, 0.6)`.
  - The console usable at `AIR_GEOMETRY.console_xform(manifest)`, the stop usable at `air.stop`, the hatch leaf at `air.hatch` and its release handle on the ladder, the plant ladder's two usables (4.4), the shaft ladder at `air.shaft.ladder`, the fan rotors at `AIR_GEOMETRY.fan_xforms(manifest)`, and the instructions memo (1h) in the post.
- **`apply("post")`:** allowed for a living seat with `files.has_card(seat)` near the reader. `post_open = true`; the door is unlocked and swung open (`set_state(true)`); the reader clunks. Word `"PASAR FICHA"`.
- **`apply("start")`** (the console in the post, word `"ENCENDER"`, hold `START_HOLD`):
  - Needs `charges > 0` and the fans not running.
  - `charges -= 1`, `running_until = elapsed + fan_time`, `released = true`.
  - `fans.wav` loops at the unit (`FAN_NEAR_DB`), and as a follow cue at `FAN_ROAR_DB` on planta 3; both are tagged `"fans"`.
  - The rotors of the unit and of the plant's in-line fans spin (`spin` eased by `FAN_SPIN`).
  - With no charges, the console's word is `""` and a forced request is refused: no fans.
- **`apply("stop")`** (the unit's isolator in the plant, word `"PARAR"`, hold `STOP_HOLD`): `running_until = 0`.
- **Host `tick()`:** running past `running_until` → `"stopped"`, told. Everywhere the loops fade over `FAN_SPIN`.
- **`sound_mask(point)`:** `AIR_MASK * spin` for a point on planta 3 (`FLOOR.planta_of(point.y) == 2`), else 0.
  - Players: `world_audio.mask_db()` (1.6).
  - The creature: in `hotel_main.locust_hear()` (line 1006), `radius *= 1.0 - sound_mask(point)` before it is heard or sent to a hunter (0 on floor 1).
  - Her ducts: `func ducts_closed() -> bool: return spin > 0.5`, which phase 3's duct graph reads to close itself and send her out by the nearest exit.
- **`apply("hatch")`** (the plant ladder's usable 0 while the hatch is shut: word `"ABRIR"`, hold `HATCH_TIME`):
  - **Why from the floor.** The hatch hangs at 3.1 to 4.3 m, out of `USE_REACH` and of the interaction's 2 m ray (interaction.gd:131). So it is opened from the floor by the release on the ladder's right rail: a lever at 1.3 m whose rod runs up the rail to the two cam latches (4.5).
  - Needs `released and spin == 0.0 and not hatch_open`. While the fans run its word is `""` and a request is refused.
  - The release handle drops. The leaf (`duct_hatch.gd`: a framed galvanised panel with two cam latches) swings 100° on its side hinge over 1 s, with `hatch.wav` and host noise `"hatch"`. It stays open, and its collider leaves.
  - On every machine, usable 0's `action` becomes `"climb"` (word `"ENTRAR"`, 4.4). `reset()` and `restore()` set it back from `hatch_open`.
- **Progress:** `ready = hatch_open`; `kind "air"`; `done = int(post_open) + int(released) + int(hatch_open)`; `needed = 3`; `lines [["CARGAS", "%d" % charges]]`.
- **The shaft ladder** (`shaft_ladder.gd`, at `air.shaft.ladder`, word `"BAJAR"`, hold `LADDER_HOLD`):
  - Allowed when at least `session.minimum_survivors()` living survivors stand in the shaft: inside `Rect2(cx - sx / 2, cz - sz / 2, sx, sz)` and `floor_y - 0.3 <= y <= floor_y + 2.0`.
  - `apply("ladder")` on the host calls `level.lifts.leave_floor()` (line 507).
  - `begin_leaving()` (lines 513 to 523) reads `level.kind.get("LEAVE")`. `"ladder"` holds the body, pitches the camera down, lowers it 1.4 m over `LEAVE_TIME`, and plays `ladder.wav` at the shaft instead of the car doors and the descent.
  - `ride_out()` (line 526) then ends the floor as the last car does (`finish_stage()` after `LEAVE_TIME`). The RPCs `leave_floor`/`floor_left` keep their signatures.
- **`reset()`:** charges back, fans stopped (no fade), the lockdown back, the post door shut and locked, the hatch shut, every body inside the duct put back at the plant ladder's foot (by its owner's machine).
- **`snapshot()`:** `{charges, running_until, released, post, hatch}`.
- **`goal_points(3)`:** the post reader, the console, the unit's stop while running, the hatch, the ladder's foot, and the shaft.

### 4.4 The crawl and the climb (player and bots)

**The capsule fits.** Measured on `game/player/player.tscn` and `survivor_gait.gd`:

- The capsule is radius 0.3, 1.8 tall standing.
- Crouched, it is 1.05 tall, centred at 0.54 (`HEIGHT_CROUCHED`, `MIDDLE_CROUCHED`, lines 32 to 35), so its top is at 1.065 m. That is 0.135 m under the duct's 1.2 m clear height, with 0.3 m clear on each side of its 1.2 m width.
- `can_stand()` (lines 46 to 56) refuses to stand where the standing capsule hits mask 1|8|128. So once in, the body stays crouched by itself.

**Where a body crawls.** `air.crawling_at(point)` is `MAIN_DUCT.inside(manifest, point, 0.1)`: inside any clear box of the duct line or of the stub, from the duct floor to floor + `main`, padded 0.1. The shaft's landing is standing room, not a crawl space, and so is the plant room under the duct.

**The climb.** `fixed_ladder.gd`: two usables, networked like the rest so everybody hears them.

| Index | Where | Action | Word | Allowed when |
|---|---|---|---|---|
| 0 | on the ladder's plane, 1.2 m up; stand `MAIN_DUCT.foot(manifest)` | `"hatch"`, then `"climb"` once the hatch is open (4.3) | `"ABRIR"`, then `"ENTRAR"` | for `"climb"`: `hatch_open`, and the body is in the plant, not crawling |
| 1 | at `MAIN_DUCT.mouth(manifest)`, facing back to the hatch | `"climb"` | `"BAJAR"` | the body is crawling within 1.0 m of the mouth |

`"climb"` holds `CLIMB_HOLD`.

`apply("climb", i)`:

- **On every machine:** `ladder.wav` at the ladder (not when quiet). On the host: the noise `"ladder"`.
- **On the machine that owns the body** (the local player's seat, or a bot body offline):
  - **Index 0:**
    - The player: `MOVEMENT.set_crouch(player, true)`, then `player.transit = {from: global_position, to: mouth.origin, yaw_from: rotation.y, yaw_to: mouth yaw, time: 0.0, length: CLIMB_UP}` (`step_transit()`, lines 721 to 737, eases it and walks the avatar).
    - A bot body: `body.place(mouth.origin, mouth yaw)` and `pace = CROUCH`.
  - **Index 1:** the reverse, to `foot()` over `CLIMB_DOWN`. The crouch is released on arrival only if `can_stand()`.
- Remote copies of the body slide up the ladder by the usual position sync. The avatar has no climb clip; that goes to PLAN.md.

**The gait** (`survivor_gait.gd`):

- `SPEED_CRAWL := 1.2`, `SPEED_CRAWL_BACK := 0.6`, `CRAWL_STRIDE := 0.55`.
- `speed(crouched, running, crawling := false, backwards := false)` returns the crawl speeds when crawling (running is impossible).
- `accelerate(body, ...)` passes `body.get("crawling")` and `body.get("crawl_back")`.
- `footfall` gets `"crawl"` when crawling.

**The player** (`hotel_player.gd`):

- `var crawling := false` and `var crawl_back := false`, set every physics frame from `level.crawling_at(global_position)`. The interaction sets them for the local player before `drive_local` returns.
- While crawling:
  - crouch is forced; no jump, no run, no lean;
  - `crawl_back` is set when the stick or the keys push back (`axis.y > 0`), and the speed is then `SPEED_CRAWL_BACK`;
  - `eye_height` goes to `CRAWL_EYE := 0.62`, in both places it is eased (lines 332 and 732);
  - each `CRAWL_STRIDE`, one of `crawl_1..2.wav` on the step voice at -30 dB, and the noise `"crawl"`.

**The bot body** (`tools/bots/bot_body.gd`): it gets `crawling` and `crawl_back`, set in `_physics_process` from `level.crawling_at(global_position)` before `MOVEMENT.accelerate()`.

**Looking back is slow.** `const CRAWL_TURN_RATE := 2.4` (rad/s).

- In `_physics_process`: `turn_budget = minf(turn_budget + CRAWL_TURN_RATE * delta, CRAWL_TURN_RATE * 0.1)`.
- In `look_by()` (lines 249 to 257), while crawling, the yaw part is clamped to `±turn_budget` and the budget is spent.
- Turning half round takes 1.3 s. Pitch is free. Outside a crawl space nothing changes.

**Inside the duct, the floor reports the room below** (risk 9). 1g handles the readers that matter now:

- `sanity.lit_at(point)` (line 158) returns false where `level.crawling_at(point)`: the duct is dark.
- `office_geometry.follow_bodies()` overrides `super()`: for a body where `MAIN_DUCT.inside(manifest, body point)`, it puts its meshes on no room bit (`ROOM_LAYERS.put_on(mesh, 0)`, layer 1 only). On `static_light`, the lamp of the room below then cannot light it through the false ceiling; the torch still does.

**Animation.** The avatar has no crawl clip: the crouch pose is used, and a teammate behind may see its head touch the duct's top. Accepted for phase 1, and noted in `docs/PLAN.md` section 4 (crawl and climb clips for the survivors).

### 4.5 Static pieces (`game/world/office/main_duct_geometry.gd`, `air_geometry.gd`)

#### `main_duct_geometry.gd`

```gdscript
extends RefCounted
## The main duct of planta 3, its crossing stub, the hatch's frame, the plant
## ladder up to it, the shaft at its far end and the remains in it. One holder
## of its own under the geometry root, built after the navigation bake, every
## mesh on the plenum layer (8) alone: no room lamp ever lights it, the torches do.
const SHEET := 0.03                ## the duct's sheet, outside the clear main x main
const SEAM_EVERY := 1.2            ## standing seams (a 0.02 rim)
const HANGER_EVERY := 1.5          ## 6 mm rods from the top to the slab
const STUB := 1.5                  ## the crossing's side stub, from the main's side wall
const MOUTH_IN := 0.6              ## where a climber is put inside the duct, along it from the hatch
const LADDER := {"width": 0.45, "rung": 0.28, "out": 0.12, "stand": 0.75, "grab": 1.0}   ## plant ladder: plane `out` from the hatch, foot `stand` out, grab handles `grab` over the sill
const SHAFT_HEAD := 2.6            ## clear height over the landing
const SHAFT_PIT := 6.5             ## how far the shaft goes down under the landing (black)
const MANHOLE := Vector2(0.7, 0.7)
const WALL_HALF := 0.09
static func floor_y(manifest: Dictionary) -> float          ## rooms[air.plant].py + duct_y - main / 2
static func floor_line(manifest: Dictionary) -> PackedVector3Array   ## the duct floor's centre line: the hatch, each main node, the outer face of the last cell's wall
static func stub_line(manifest: Dictionary) -> PackedVector3Array    ## from the cross node's floor point, main / 2 + STUB along air.main.stub
static func boxes(manifest: Dictionary) -> Array[AABB]      ## the clear inside of every straight piece (line and stub)
static func inside(manifest: Dictionary, point: Vector3, pad := 0.1) -> bool
static func mouth(manifest: Dictionary) -> Transform3D      ## MOUTH_IN in from the hatch, on the floor, facing along the duct (yaw = air.hatch.yaw)
static func foot(manifest: Dictionary) -> Transform3D       ## the ladder's foot: the hatch's floor point + facing(hatch.yaw) * LADDER.stand, facing the hatch
static func holes(manifest: Dictionary, room: Dictionary, direction: Vector2i) -> Array   ## [along0, along1, y0, y1] on that wall (office_geometry.wall_holes)
static func build(builder, manifest: Dictionary) -> Node3D  ## the holder "MainDuct"
```

**Geometry from the manifest.**

- The statics cache their results by manifest identity (`is_same`, as `FLOOR.room_at()` does), because `inside()` runs every physics frame per body.
- `floor_line` takes the main nodes from `ducts.nodes` by `air.main.nodes`, at `y = floor_y`. Its last point is not the shaft node: it is the outer face of the last cell's wall (`last centre + side × (half span + WALL_HALF)`), where the duct opens onto the landing.
- Every piece is axis-aligned (the generator follows the grid), so a box is enough. Yaws come from directions at runtime (`atan2(-d.x, -d.z)`), never stored.

**`build(builder, manifest)`** is called by `office_geometry.build(data)` right after `await super.build(data)`. That is after `flush()`, `assign_layers()` and `build_navigation()`, and before `build_floor()` runs `validate_physics()`, which sees it.

- **The holder.**
  - `MainDuct` is a child of the geometry root.
  - Every mesh is its own `MeshInstance3D`, one per material (`SurfaceTool` boxes merged), with `layers = builder.PLENUM_LAYER` set before `add_child` and `gi_mode` disabled.
  - `assign_layers()` has already run, and `ROOM_LAYERS.put_on()` never touches a mesh without layer 1, so no room bit reaches it.
  - Colliders: one `StaticBody3D` "MainDuctBody" with `collision_layer = 1`, `collision_mask = 0`, and one `BoxShape3D` per sheet, plate and wall. Seams, hangers, the skull and the bones have none.
- **The duct.**
  - Per straight piece: four sheets (`galvanized`, `SHEET` thick) round the clear `main` × `main` box. Each extends `main / 2 + SHEET` past an inner bend point, so the corners close.
  - Standing seams every `SEAM_EVERY`, and hangers every `HANGER_EVERY`.
  - The hatch end is open, behind the leaf. The shaft end is open onto the landing.
- **The crossing.**
  - At `air.main.cross`, the main's side wall facing `stub` is split round a `main` × `main` opening.
  - The stub is `STUB` long, of the same section, ending in a reducer: a plate with a `plenum.duct` (1.0 × 0.8) opening, a black box behind it (the network carrying on), and three bars across it with a collider. It is crawlable to the bars and no further.
- **The hatch frame.** A galvanised frame 0.06 wide round the duct's end at `air.hatch.point`, and the hinge knuckles. The leaf is `duct_hatch.gd`'s; while shut, its collider closes the end.
- **The plant ladder.**
  - Procedural, in the kit's black painted steel if `fire_escape_ladder` gives a material, else `steel_frame`.
  - Its plane is `LADDER.out` from the frame. Two 0.05 × 0.012 rails run from the plant's floor to the sill (`floor_y`), with rungs (r 0.012) every `LADDER.rung` and two stand-offs to the frame.
  - Two grab handles on the frame's sides rise `LADDER.grab` above the sill.
  - The hatch's release: a 12 mm rod up the right rail, from a lever bracket at 1.3 m to the two cam latches. The lever handle is `duct_hatch.gd`'s.
  - Collider: one thin box (0.5 × height × 0.06), so nobody walks through it.
- **The shaft.** Built from `air.shaft.rect` and `floor_y`.
  - Four `plenum_slab` concrete walls from `floor_y - SHAFT_PIT` to `floor_y + SHAFT_HEAD`, and a roof slab. The near wall lies on the building's outer face, with the duct's mouth cut in it.
  - The landing: a `steel_plate` floor at `floor_y` over the whole rect, except a `MANHOLE` at `shaft.ladder.point`, with a guard rail on three sides.
  - An invisible collider box over the manhole, so nobody can fall in.
  - The kit's vertical rung ladder (`modular_fire_escape_ladder_bottom`, 0.78 × 6.47 m) going down through the manhole into the pit, with its hoop rising 1.1 m over the landing.
  - A black pit floor at `floor_y - SHAFT_PIT`.
  - **Light:** none of its own (decision 8). `layer_at()` is 0 there (no room), and the holder is on the plenum layer. Every camera draws it, the torches (default cull mask, all layers) light it, and on `static_light` no room lamp does: right for a place outside every room on an unpowered planta.
  - **Body layer:** a body standing there keeps its last room bit (`follow_bodies()` skips `layer_at() == 0`). This is harmless: that room is dark.
- **The remains** (OFICINAS 3, "en el ducto, sus restos"; confirmed lore), at `air.remains.point`:
  - the skull (`human_skull_oga`, scaled to 0.14 m), five long bones (bone-white capsules), and a torn grey coverall strip;
  - laid against one side wall, 0.3 m off the centre line, with no collider.
  - The crouched capsule still passes; the test samples that point.
  - The notes of whoever it was are the author's texts: out of scope.
- **Wall holes.** `office_geometry.wall_holes(room, direction)` returns `MAIN_DUCT.holes(manifest, room, direction)`: the duct's outer section (`main + 2 × SHEET`, plus 0.02) where a box crosses that wall and the wall's top is above the duct's floor. 1d's `office_run()` leaves them open.
- **On other plantas.** `office_geometry.put_away(here)` override: `super(here)`, then `main_duct.visible = here == 2`.

#### `air_geometry.gd`

```gdscript
extends RefCounted
## The air handler and the post's console, built with their rooms by office_geometry.extras().
static func extras(builder, node: Node3D, room: Dictionary) -> void
static func console_xform(manifest: Dictionary) -> Transform3D        ## the start button on the console
static func fan_xforms(manifest: Dictionary) -> Array[Transform3D]    ## where the handler's rotors spin
```

- **The unit** (plant room, at `air.unit`):
  - A galvanised panel housing of `AIR_UNIT` (3.0 × 2.2 × 1.5, back to the wall), with standing seams, two access doors and a riveted nameplate `text()` "CLIMATIZADORA 2" (size 14).
  - On its face, two of the duct fans kit's square fan housings with round collars. Their rotors are the handler's: separate parts if the glTF has them, else a procedural six-blade disc.
  - From its top, the kit's spiral round ducts and an in-line axial fan rise to the slab. They lie inside the exempt plant cell.
  - Box collider on the housing; it is in the navigation bake.
- **The stop** at `air.stop`: an isolator box (0.2 × 0.3 × 0.12) with a red handle.
- **The console** on `air.security.desk`:
  - 1d's `metal_office_desk`, with a sloped steel panel box (0.6 × 0.25 × 0.4) on it.
  - A dial, two pilot sockets and a big round start button socket. The lamps and the button cap are the handler's.
  - A stencil "VENTILACIÓN" over it.

---

## 5. Step 1h: La Oficina's forms

### 5.1 `tools/textures/bake_oficina_forms.py`

Same shape as `tools/textures/bake_do_not_disturb.py`: numpy and Pillow, system fonts with a fallback, deterministic. Printed labels in a grotesque face from the system (`arial.ttf`, `LiberationSans-Regular.ttf`, Pillow's default), upper case, Spanish, no «·» or «—». It writes `assets/textures/oficina/` and `assets/textures/oficina/layouts.json`.

| Picture | Size | What is printed on it |
|---|---|---|
| `memo-original.png`, `memo-copia.png`, `memo-archivo.png` | 1024 x 1448 | • Pale water-green paper (`(214, 232, 220)`; the copies a hair greyer and yellower), two filing holes on the left (alpha, at 1/3 and 2/3 of the height).<br>• La Oficina's seal at the top left: a square split in four, no text.<br>• `MEMORÁNDUM INTERNO`, ruled fields `DE`, `PARA`, `ASUNTO`, `REF.`, `FECHA`, and a box for the entry stamp at the top right.<br>• Ruled body lines, and at the foot `ORIGINAL`, `COPIA` or `ARCHIVO`. |
| `ficha.png` | 1024 x 640 | • Beige card (`(222, 205, 165)`), a row of punched holes along the top (alpha), the seal small.<br>• The photo box on the left (`FOTO`, thin rule).<br>• Fields `NOMBRE`, `NÚMERO`, `DEPARTAMENTO`, `ALTA`, `NIVEL DE ACCESO`.<br>• A red band `(170, 30, 25)` with `PROVISIONAL` in the card's colour. |
| `resguardo.png` | 360 x 900 | • Thermal paper strip (`(240, 238, 230)`), torn zig-zag at both ends (alpha).<br>• `LA OFICINA`, `TUBO NEUMÁTICO`, `RESGUARDO`, `ENVIADA A ESTACIÓN` over an empty space for the big number, `N.º` and `HORA`. |
| `*-lejos.png` of each | a quarter of the size, grey lines where the typing goes | seen lying or hanging in the world |

`layouts.json`: `{paper: {size: [w, h], fields: {name: [x, baseline_y, width, size]}, photo: [x, y, w, h], big: {station: [x, y, w, size]}}}` in the picture's pixels, measured by the script from what it drew.

### 5.2 `game/ui/hotel_form.gd`: other papers, the hotel's unchanged

- `form.paper` defaults to `"hotel"`. For `"hotel"` everything is as today: the constants, `CARD`, and `_draw()` with `nota-hotel.png`.
- Other papers:
  - `card` is the layout's size.
  - `_draw()` draws that picture as it is: its alpha is its edge, with no rounded corners.
  - `draw_typed()` types each field the form has at its layout baseline, with `fitting()` and `type_line()` (the same ribbon). `big.station` is typed at its size.
  - `photo` (a `Texture2D` in `form.photo`) is drawn into the layout's photo box, turned by `HAND.jitter(seed, 7) * 0.06` rad, inset 6 px, with two strips of translucent tape across its top corners. With no photo, the box stays empty.
- Layouts are loaded once from `res://assets/textures/oficina/layouts.json` (a `static var`).

### 5.3 Showing them

- **`game/ui/hint_view.gd`.**
  - `FORMS` gains `"ficha"`, `"resguardo"` and `"memo"`. For them `card = sheet.card` (the sheet's own size); for the hotel kinds it stays `FORM.CARD`, as now.
  - New kind `"red"`, the tube network map, drawn like `"plano"`: the planta's walls, the tubes as double lines along `tubes.edges`, the stations as numbered circles, and the window room marked `VENTANILLA`.
- **`game/world/interactables/hotel_document.gd`.**
  - `FAR` gains `"memo"`, `"ficha"` and `"resguardo"` (the `-lejos` pictures).
  - Add `SHEETS := {"ficha": Vector2(0.2, 0.125), "resguardo": Vector2(0.058, 0.145), "memo": Vector2(0.21, 0.297)}`. `sheet_of(paper)` takes its size from `SHEETS`, and `FORM_SHEET` for the rest (the hotel's three are unchanged).
- **The game papers of floor 2.** All are diegetic, read in the world and kept in TUS NOTAS when read. The numbers on them come from the floor's own tuning.
  - The receipt and the card (planta 1, section 2.5).
  - The network map beside the window (`"red"`, at `mail.map`).
  - The board's legend, on a memo beside the board:
    - `ASUNTO: CUADRO GENERAL`;
    - a line per circuit, `"%s %s" % [code, name]` (`R-2 ARCHIVO`);
    - `NO MÁS DE %d ZONAS A LA VEZ`;
    - `PALANCA ROJA: MONTACARGAS. CORTA LA PLANTA. ARRANQUE CON RETARDO.`
  - The air instructions, on a memo in the post:
    - `1. PASE LA FICHA.`
    - `2. ARRANQUE DESDE ESTA CONSOLA. BATERÍA: %d CARGAS.`
    - `3. CON LOS VENTILADORES EN MARCHA NO SE ABRE LA COMPUERTA.`
- **Out of scope:**
  - the four lore documents of section 10 (the author's narrative; LORE.md only with his yes);
  - the notes of "alguien estuvo antes", which need the author's texts. They can use the memo once written.

---

## 6. Step 1i: tests, network, bots, captures

### 6.1 `tests/office/office_stages_test.gd` (new; added to `verify.ps1`'s `$tests`)

**Setup.**

- Build the office floor with `level.set_floor(2)` and `start_floor(81, false, [1, 2])`: two seats, so assignments differ.
- Park the null creature.
- Drive the player by placing it, and by `Input.action_press("interact")` where the hold path is under test, as `stages_test.cross_to_stage` (lines 106 to 130) drives the lift.
- A second seat acts through `match_net.use_office(..., 2)`; offline it is applied at once.
- Shorten timers by setting the handler fields after `place()`: `power.lift_timer = 3.0`, `power.switch_time = 2.0`, `air.fan_time = 3.0`.
- Stages are reached by the real flow (swipe the quota, ride; the red lever, ride).

| Planta | Case |
|---|---|
| 1 | The tube network is connected and every station is reachable from the hub's node. There are 8 to 14 stations, numbered 1..N without gaps. |
| 1 | The desk, every station and the reader are found by the interaction's ray from their stands, as in the containers' check of `stages_test` (lines 168 to 185). The reader is in planta 1's freight lobby (19), on the lobby side of the gate door. |
| 1 | Holding E at the desk for 2 s and letting go: no request, the typing sound stopped, `player.reading` false again. |
| 1 | Holding for the whole `typing_time`:<br>• a request is made, and the body was turned to `mail.stand.yaw`;<br>• at least `typing_time - 1` typing noises of radius `NOISE.radius("typing")` are in `noise_log` and in the null creature's `heard`;<br>• the receipt (kind `resguardo`) names that station in TUS NOTAS. |
| 1 | Seat 2 typing gets a different station; both are at least `STATION_TUBE_MIN` along the tubes from the hub. |
| 1 | The capsule:<br>• one second apart, its point has moved `CAPSULE_SPEED` within 10 %, always within 5 cm of a tube edge;<br>• it arrives at `length / speed` within 0.2 s;<br>• the station's lamp lights, and `world_audio.last_event` is the bell at the station. |
| 1 | Its hiss, heard from a room the tube passes through, comes from a tube node of that room (`tubes.rooms`). From another planta it is inaudible. |
| 1 | Seat 2 cannot take seat 1's card. Seat 1 can, once arrived (not before). The card (kind `ficha`) carries the name, the number and the station's papers. |
| 1 | The reader: with the card, one swipe. With a roster of 2 the quota is 1, so the goal is ready and gate 0 unlocks. `progress()` with `roster_count = 4` needs 2. |
| 1 | A holder captured (`session.capture` through the executions path, or the hook called directly): a pickup lies at the body; another seat takes it, and the reader counts it. |
| 1 | A stage given back: requests, capsules, cards, swipes and pickups are gone, and gate 0 is locked. |
| 1 | The photo is asked for at `TYPE_PHOTO_AT` (a counter in the handler). Headless there are no bytes. A synthetic JPEG (`Image.create(32, 24)` saved with `save_jpg_to_buffer`) kept through `keep_photo` shows on the card's form as a texture. |
| 1 | `floor_save` round trip in the middle of a capsule's travel: the same requests, the capsule at the same point, and equal swipes and photo bytes. |
| 1 | Into the car with the quota, the button: stage 2. |
| 2 | Levers = circuits + 1, in `lever` order. `budget` comes from the tuning (Apacible 3, Pesadilla 2, through `set_difficulty`). |
| 2 | Raising K + 1 levers drops the first raised: its rooms have `hotel.lit == false`, the others' true. Lowering one frees its place. The electrical room is never lit. |
| 2 | A minutero lights its rooms for `switch_time` and they go out after. Every minutero has the same time. |
| 2 | The red lever:<br>• every room of planta 2 outside `always_lit` goes out, and the `always_lit` ones stay lit;<br>• zone levers are refused while it runs;<br>• the car refuses before the timer ends;<br>• `ARMED` at the end, and gate 1 is unlocked;<br>• with fewer than the quota inside, the button does nothing; with it, stage 3. |
| 2 | A save taken with the timer half run: restored, it ends at the same `elapsed`. |
| 3 | The post is locked. A seat without a card is refused; with one it opens. |
| 3 | Pesadilla gives 1 charge, and a second start is refused. While running (after the spin-up):<br>• `sound_mask` is 0.65 on planta 3 and 0 on planta 2;<br>• `ducts_closed()` is true;<br>• a noise on planta 3 reaches the null creature with its radius reduced by the mask. |
| 3 | The hatch is refused before any start (lockdown), refused while running, and opens after the stop. |
| 3 | The ladder's word is `""` under the lockdown and while the fans run, and `"ABRIR"` after the stop. Once the hatch is open it reads `"ENTRAR"`: using it puts the player at `MAIN_DUCT.mouth()`, crouched, with `crawling` true. `"BAJAR"` brings it back to `foot()`, standing. The hatch is opened from the floor (the ray from `foot()` finds usable 0). |
| 3 | The duct, once the hatch is open:<br>• the crouched capsule (0.3 × 1.05, centred `MIDDLE_CROUCHED + 0.02` over the floor, mask 1\|8\|128) has no hit at points sampled every 0.5 m along `floor_line` and `stub_line`, the remains' point included;<br>• the standing capsule hits at each;<br>• `crawling_at` is true there, false 0.5 m under the duct floor (the room below), and false on the landing;<br>• the standing capsule fits at the landing's centre. |
| 3 | Walking forward (`Input.action_press("forward")`) from the mouth, the player crawls to the landing at no more than `SPEED_CRAWL + 0.05`, within `length / SPEED_CRAWL + 10` s. `look_by(Vector2(PI, 0))` while crawling turns at most `CRAWL_TURN_RATE * 0.1`. `sanity.lit_at()` is false all the way. |
| 3 | The shaft ladder is refused with fewer than the quota in the shaft. With it, the floor is WON after `LEAVE_TIME`. |
| all | No paper, word or line of the floor contains «·» or «—». |

### 6.2 `tests/office/office_test.gd` (1b to 1d own it; add a "sistemas" section)

On 40 seeds in the manifest, 3 of them built:

- **Tubes.**
  - The tubes are connected, and `tubes.rooms` has one entry per node.
  - Every station is reachable along the tubes and on foot from the start.
- **Planta 1.**
  - The window room has a glazed side to a corridor.
  - `mail.stand` lies inside the window room, at least 0.9 m from its doorways.
  - `mail.reader` is on a closed wall of planta 1's freight lobby (19), within 1.5 m of the stage gate door's jamb.
- **Planta 2.**
  - Circuits ∪ `always_lit(manifest, 1)` ∪ {electrical} cover every non-void room of wing 1, each once.
  - Every `power.timers` entry's rooms are corridor-role (11 or 12) cells of wing 1, its button is in one of them, and it has no `seconds`.
- **Planta 3.**
  - The board, plant room, post and shaft are reachable on foot (the shaft along `floor_line` from the hatch).
  - The post door exists and starts locked. `air.security.reader` is outside the post, on the corridor side.
  - The shaft `rect` is at least 2 × 2 m, and `FLOOR.room_at()` is empty at its centre and corners on planta 3.
  - `floor_y == py + duct_y - main / 2`.
  - No gap, ceiling exit or duct exit lies within `main / 2 + 1.2` m in plan of the main's line.
  - The ladder's foot is at least 1.0 m from the unit's box and from doorway bands.

The built seeds also pass `validate_physics()`, with the main duct present.

### 6.3 Network: scenario `office_coop`

- `tools/net_test.ps1`: `ValidateSet` gains `office_coop`, with roles `office_host`, `office_alpha` and `office_bravo`. `verify.ps1` adds it in batch 2, on port 24650.
- `tests/net/net_test.gd`: three new role functions on the pattern of `host()` / `guest()` (lines 209 onward):
  - The host sets `net.set_option("floor", 2)` (0c) and starts. All build the same floor (the hash check of `floor_built`).
  - Alpha types (`use_office(files, "type")`): the host has the request and its station, and Bravo applies it. The host forces the arrival (it sets the request's `sent` back); everyone sees the lamp lit.
  - Alpha sends a synthetic JPEG through `office_photo`: the host keeps it, and Bravo receives the same bytes (relay). `PHOTO_BYTES` and the arrival time are logged.
  - Alpha and Bravo take and swipe (quota 2 of 3): gate 0 opens on all three. Into the car: stage 2.
  - Alpha raises a zone: `hotel.lit` of a room of that zone is true on all three. Bravo raises K more: the first drops on all three.
  - Bravo drops and comes back (the `seat_returned` path): after `catch_up`, its board, cards and photo bytes are the host's.
  - Bravo pulls the red lever (the host's `lift_timer` is short): `ARMED` on all three. With the quota inside: stage 3.
  - Each role's checks go into `evidence/net_office_*.json`, as the others do.

### 6.4 Bots: `bots_test --floor=2`

- **`tools/bots/bot_brain.gd` `act()`** (lines 365 to 425): a kind `"use"`.
  - On reaching, `node.begin(seat)`.
  - Each frame, `node.holding(seat, (timer - 0.25) / need)`.
  - At `0.25 + node.hold_time(seat)`, `node.use(seat)`, then `finished`.
- **`move()`:** a task with `"route"` (a `PackedVector3Array`) is walked point to point with `pace = CROUCH`, arrival radius 0.35, without navigation (the duct is not in the navmesh).
- **`tools/bots/bot_team.gd` `objectives()`** (lines 147 to 167): for each handler of the stage (0b's accessor for the stage's handlers), `errands += handler.bot_errands(self)`. Every errand is made with `usable_task()` (line 485), so reach and stands work as for the sets.
- **Errands per handler** (phase 1, no threat):
  - **files:**
    - each bot without a request types;
    - with its card in a tray, it takes it (it knows the station from its receipt, as a player does);
    - holding an unswiped card, it swipes.
  - **power:**
    - the bot nearest the board keeps it, and raises up to K zones along the nav route from the arrival lobby to the freight lobby;
    - the others walk to the freight lobby;
    - when they are in, the keeper pulls the red lever and walks back, pressing the minuteros on its way;
    - when armed, the lift task.
  - **air:**
    - a card holder opens the post and starts the fans;
    - after `"stopped"` (or by the unit's stop), the hatch;
    - then each bot: the `"climb"` usable at the ladder's foot, then the route `MAIN_DUCT.floor_line(manifest)` from `mouth()` to the landing (points 0.05 above the floor);
    - at the landing, the shaft ladder once the quota is in.
- **`tests/hotel/bots_test.gd`** with `--floor=2` runs an `office_part()` instead of the hotel part (two oracle bots, seed 81):
  - each planta closed within 240 s of simulated time, and the floor WON;
  - no grave incident;
  - every errand reached (`sin_alcance` none).

  `verify.ps1` gets a second bots check with `--floor=2` (`verify_bots_test_office.log`, 600 s).

### 6.5 Captures (with a window; not in `verify.ps1`)

`tools/capture/office_capture.gd` (1d creates it for rooms; add `--part=systems`). Shots:

- the window from the typist's place, and the counter from the corridor;
- **the CCTV photo itself**, saved as a PNG, and the same frame with the player's avatar hidden. Print the mean difference inside the body's screen box (`PHOTO_BODY_DIFF`); it must be clearly above 0, which proves the player's own body is drawn;
- the card held up with its photo, the receipt, and the map;
- a station with its tube run;
- the board with levers up and down;
- a corridor by its minutero, lit and dark;
- the plant room with the fans running, and the plant ladder;
- inside the duct, looking ahead and back, and the crossing stub;
- the remains;
- the shaft by torchlight.

Run it at Alto and Muy bajo, and with `--rendering-method gl_compatibility`: under Muy bajo the body must be lit by the fill light, and no room lamp may light the duct; the SubViewport's `UPDATE_ONCE` must work in Compatibility.

### 6.6 `verify.ps1`

`$tests` gains `office/office_test` and `office/office_stages_test`. Add the bots check with `--floor=2`, and the net scenario `office_coop` (port 24650). The count of green lines grows accordingly.

---

## 7. Order of work

1. **1e, part A (shared, hotel identical).**
   - `photo_desk.gd`, and `code_lock.develop_photo()` on it, checked against the notes capture.
   - The objective base members and helpers, and the `hotel_main` delegates.
   - `office_usable.gd` and the interaction branch.
   - The `match_net` generic RPCs and the PROTOCOL bump.
   - `conduit_graph.gd` on `conduit_metres.gd`.
   - `world_audio.play_moving` and `mask_db`.
   - The noise keys and the difficulty keys.
   - The rows in `prepare_office_sfx.py` and their outputs.

   Run the whole `verify.ps1` here: everything green before any office system.
2. **1e, part B.**
   - The pipes ingest, and `mail_geometry.gd` with its line in `office_geometry.extras()`. Look at it in the room capture before any handler.
   - The files objective, desk, capsule, stations, reader, pickup, the photo and its RPC, save and catch-up.
   - The planta-1 cases of `office_stages_test`.
   - A temporary drawing of the receipt and the card in `hint_view` until 1h: a plain paper rectangle, `FORM.type_line` for the fields, and the photo.
3. **1f.**
   - The cables kit ingest and `power_geometry.gd`.
   - The power objective, the board, the minuteros, and the `lifts.press` gating.
   - The planta-2 cases.
4. **1g.**
   - The fans, ladder and skull ingest.
   - `main_duct_geometry.gd`, first its static functions (`floor_line`, `boxes`, `inside`, `holes`) with an `office_test` check on 40 manifests; then `wall_holes()` in `office_geometry`, then `build()` and the `put_away()` and `follow_bodies()` overrides.
   - `air_geometry.gd`.
   - The air objective: the console and the stop, the post reader, the hatch, the plant ladder and the climb, the shaft ladder and `begin_leaving` by ladder.
   - The mask in `locust_hear`.
   - The crawl in `survivor_gait`, `hotel_player` and `bot_body`, and `sanity.lit_at`.
   - The planta-3 cases.
5. **1h.** The bake script and pictures, the `hotel_form` layouts, and the `hint_view`/`hotel_document` papers. Replace the temporary drawing, and place the three game papers. The floor-1 notes capture must be unchanged.
6. **1i.** The `office_test` systems section, `office_coop`, the bots, the captures and `verify.ps1`. Then the docs.

**Docs** (Spanish, honest, per step):

- `docs/DEVELOPMENT.md`: the handlers' new members, the usable base, `use_office`, `photo_desk`, `conduit_graph`, the static builders and where they are called, the main duct's height rule, the crawl and the climb.
- `docs/OFICINAS.md`: the decisions of 0.3 recorded in 14, and the numbers of 1.8.
- `docs/ASSETS.md`: the recordings and the four models.
- `docs/PLAN.md` section 4:
  - the models of the typewriter, station, reader, ceiling camera, board, air handler and hatch;
  - the real recordings of the tube, the crawl and the scissor gate;
  - crawl and climb clips for the survivors.

New `.gd` files get their `.gd.uid` committed (Godot generates them on the first headless import).

---

## 8. Hotel identity guards (each must be a no-op on floor 1)

| Change | Why floor 1 does not move |
|---|---|
| `code_lock.develop_photo()` on `photo_desk` | The same camera, size, fov, flash, frames and room shown. Compare the notes capture. |
| Interaction usable branch | No `office_usable` exists on floor 1. |
| `toggle_sheet()` with `own_papers()` | The hotel's handlers return no papers, so the list is `code.own_hints()`. |
| `lifts.press()` gating | `ride_allowed()` is true for the hotel handlers. |
| `begin_leaving()` by ladder | Only when `kind.LEAVE == "ladder"`; the hotel kind has none. |
| `locust_hear()` and the `world_audio` mask | `sound_mask()` is 0. |
| `play_moving()` | Only cues created with it carry `where`. |
| `hotel_form`, `hint_view`, `hotel_document` | `paper` defaults to `"hotel"`; `FORM.CARD` and `FORM_SHEET` for the hotel kinds. |
| `executions.gd` death hook | The hotel handlers' `on_death` is empty. |
| `noise_kinds`, `difficulty` | New keys only; the Locust's profiles are untouched (`difficulty_test`). |
| `match_net` RPCs and PROTOCOL | The wire changes are new methods only; existing payloads are unchanged. |
| `floor_save`, catch-up | The `objectives` key is added; old saves without it load (continue_test fixture). |
| `hotel_player` and `bot_body` crawl, `sanity.lit_at` | `crawling_at()` is false everywhere on floor 1, so `crawling` is false and `lit_at` is unchanged. |
| Static builders, `wall_holes()`, `MainDuct`, `follow_bodies()`/`put_away()` overrides | All in `office_geometry.gd`, which only floor 2 uses. |

`manifest_golden_test`, `stages_test`, `continue_test`, `bots_test` (floor 1), the four net scenarios, `difficulty_test` and `sanity_test` stay green after every step.

---

## 9. Risks

1. **A key from 0.2 is missing in 1b.** Add it in 1b (the generator spec, its validator group and a mutation) before the handler that reads it. Never compute it in a handler, and never rename the generator's keys from here.
2. **Headless tests cannot see the photo.** Its logic is tested with a synthetic JPEG; the rendering (own body on layer 2, the Muy bajo fill, Compatibility) only in `office_capture`. Do not skip that capture.
3. **Room power and the bounce light.** `set_room_power(false)` must also take the room out of the baked bounce, as `blackout()` does (hotel_geometry.gd 932 to 952). If 0e did not, rooms of planta 2 glow in the dark. Check it in the minutero capture.
4. **Timers on guests** run from the synced `session.elapsed` (2 Hz). The host's events (`armed`, `stopped`, `arrived`) are the authority. A guest may see a timer end a few frames early, but nothing is decided on a guest.
5. **Reliable RPCs with bytes.** A 24 KB photo over Steam's reliable channel is fine (512 KB limit), but it goes once per player and once more in a catch-up. Never put photos in the 2 Hz session push.
6. **Design calls taken here** (section 0.3) change how the floor plays. They must be written in `docs/OFICINAS.md` 14 as agents' decisions for the author to confirm.
7. **Phase 3 constraints already shape phase 1.** A phantom capsule must never ring a bell with its lamp, a phantom tick never comes from the board, and phantom fans never mask (`sound_mask` reads only the real state). Keep the real cues tagged (`"capsule"`, `"fans"`, the tick) so phase 3 can tell them apart.
8. **Static pieces built too late.** A collider made in a handler's `place()` is not in the navmesh (bots get stuck on it) and is not seen by `validate_physics()`. Everything that stands in a room goes in `extras()`. Only `MainDuct` is built after the bake, on purpose: the duct and the landing must stay out of the navmesh.
9. **A body in the duct is in the room below** for everything that asks `FLOOR.room_at()` or `FLOOR.floor_point()` (floor_definition.gd 110 and 134). Both go by footprint and planta, not by height. This affects:
   - **`hotel.lit()` and `sanity.lit_at()`:** a crawler over the lit security post would count as lit. 4.4 makes `lit_at` false in the duct.
   - **`follow_bodies()`:** the avatar takes the room below's layer bit, so on `static_light` that room's unshadowed lamp lights it through the false ceiling. The 4.4 override fixes it.
   - **`world_audio.route_source()`:** sounds made in the duct leave from the room below, through `floor_point()`. This stays wrong until phase 3 routes them through `conduit_graph`.
   - **Card drops:** they are snapped by a ray (2.3), so they land on the duct floor.
   - **The director's room reads:** harmless with the null creature; phase 3 must ask `crawling_at()`.

   In the shaft, `room_at()` is `{}`: not lit, no room layer.
10. **Ducts that meet the main duct.** If a network duct, a gap's plenum cell or a duct exit crosses the main duct's box, the crawl is blocked or another duct shows through the inside of this one. The generator's guarantees (0.2) and geometry's clipping prevent it, and `office_test` (6.2) and the duct capsule test (6.1) catch it.
11. **The duct cuts walls.** Without `wall_holes()`, a 4.4 m room's wall stands across the duct. The capsule test fails at the first such wall; build the holes before the holder.
12. **Nothing but the handlers powers a room on floor 2.** The hotel's fuse boxes (`hotel_panel.gd`, hung by `room_dressing.fuse_boxes_left()` in `FUSE_ROOMS`) give a wing its lights back in the blackout, which is the hotel kind's. If the office palette keeps any fuse room, their switches must not call `set_room_power()`. Power on planta 2 is only `power_objective.refresh_power()`.
