# Phase 3: floor 2 played alone with The Lurker (and the data formats phase 4 inherits)

Read first: `docs/OFICINAS.md` sections 1, 3 (each planta's own lies), 4, 5, 6, 7, 9, 11 (11.1 and 11.4 to 11.8), 13 and 15; `docs/LURKER.md`; `docs/EXECUTION.md` (the capture's rules: cause yes, impact no; half a second clean; never two alike). Companion specs, whose names this one uses unchanged:

- `spec_f1_generator.md`: manifest keys (`ducts`, `plenum`, `archives`, `power`, `air`, `tubes`, `mail`), palette questions and ids (`office_palette.gd`: `OPEN_OFFICE 1`, `CUBICLES 2`, `OFFICE 3`, `BOARDROOM 5`, `ARCHIVE 6`, `COPY_ROOM 7`, `MOBILE_ARCHIVE 13`, `EXEC_OFFICE 16`, `WINDOW 17`, `ELECTRICAL 18`, `REFUGE 19`, `SECURITY 21`, `AIR_ROOM 22`, `AIR_PLANT 23`, `SECRETARY 24`), `null_creature.gd`, `office_floor.gd`.
- `spec_f1_geometry.md`: render layers (8.1: the Lurker on value 4, plenum on value 8), power hooks (7.3), the hum (8.4), `outside_holder()`/`add_outside()` (8.5), `crawl_space()` and `body_bit()` (H10).
- `spec_f1_systems.md`: `conduit_graph.gd` (1.5), `world_audio.play_moving()` and the sound mask (1.6), the objective base (1.1), noises and recordings (1.8), the crawl (4.4: `CRAWL_TURN_RATE 2.4`), `air.ducts_closed()`.
- `spec_f2_movement.md` and `spec_f2_mind.md` (phase 2, written in parallel with this one). Where they name something differently from section 0.2 below, **their name wins and the behaviour asked here stays**.

Floor 1 stays identical through every step of this spec: every change to a shared file is a no-op for the hotel kind, and section 13 lists the guards. Line numbers are from the tree at `a854b6f` with step 0a5 half landed (its working copy already has `creature.draw_gizmos(g)` with `g.layer`, `apply_quality()`, `quarry()`, `saw_enter()`, `validate_strike() -> float`, `wardrobe_steps()` and `tools/bots/bot_threats.gd` as the threat factory). Search by function name.

**Numbering.** Code counts plantas as `wing` 0, 1, 2 (Personal, Registro y Archivo, Dirección); prose says "planta 1 to 3" as OFICINAS does.

**Steps.** 3a the Lurker on the floor; 3b her sound; 3c her lies; 3d her capture; 3e the observer and the data formats; 3f the bots and the balance batch; 3g performance. Each is one commit, green on `tools/verify.ps1`.

---

## 0. What this spec assumes and what it decides

### 0.1 Phase 0 and phase 1 (as specified in `oficinas_specs.md` and the phase 1 specs)

- `level.creature` (alias `level.locust`), the contract in `game/enemies/creature.gd`, `level.kind` (0c), `level.set_floor(n)` and `--floor=N`, `level.objective(id)` (0b's accessor), `level.tuning()` returning `DIFFICULTY.profile(id, kind.CREATURE_KEY)` merged (0f), `FLOOR.palette(manifest)` (0d).
- 0e: `hotel.lit(room_id)` (power, not dark, not drained), `hotel.set_room_power(room_id, on)`, `hotel.drain(room_id, amount)`, `ROOM_LAYERS.put_on_actor(mesh, bits)` used by `follow_bodies()` for actor meshes not on layer 1.
- 1a: `office_floor.gd` with `CREATURE := "res://game/enemies/null_creature.tscn"` and `CREATURE_KEY := &"lurker"`; `null_creature.gd` with `heard`.
- 1d: `office_geometry.gd` (troffers, `lens_of`, `battens_of`, per-room lens duplicates for drain, the failing-troffer flicker entry with `share`), `hum_path()`, `PLENUM_LAYER := 8`.
- 1e to 1g: `conduit_graph.gd`, `play_moving()`, `mask_db()`, `level.sound_mask(point)`, `level.crawling_at(point)`, `air.ducts_closed()`, the objectives `files`, `power`, `air` with `snapshot()/restore()`, `floor_save` writing `"objectives"`.

### 0.2 Phase 2 (the names this spec calls; adapt to phase 2's if they differ)

| Used here | What it is |
|---|---|
| `game/enemies/lurker/lurker.gd` | the creature, `extends "res://game/enemies/creature.gd"` |
| `game/enemies/lurker/lurker_creature.tscn` | its scene: root `CharacterBody3D` named `Lurker` with `lurker.gd`, `collision_layer = 0`, `collision_mask = 0` (kinematic, no capsule, OFICINAS 11.4), child `Visual` = instance of the existing `lurker.tscn` (presentation, `lurker_visual.gd`) |
| `lurker.brain` (`lurker_brain.gd`) | `state: StringName`, one of `STATES` (0.3); signals `cue_started(cue_id: int, seat: int, window: float)`, `cue_ended(cue_id: int, outcome: StringName)` (`&"caught"`, `&"scared"`, `&"cancel"`), `scared(by_seat: int, how: StringName)` (`&"torch"`, `&"turn"`, `&"mate"`, `&"light"`), `state_changed(from: StringName, to: StringName)` |
| `lurker.shell` (`lurker_shell.gd`) | `state() -> Dictionary {patch, u, v, heading, hang}`, `place(state: Dictionary)`, `snap(point: Vector3, normal_hint: Vector3) -> Dictionary`, `medium() -> StringName` (`&"room"`, `&"plenum"`, `&"duct"`), `patch_kind() -> StringName` (`&"floor"`, `&"wall"`, `&"ceiling"`, `&"channel"`, `&"lintel"`), `normal() -> Vector3`, `room_id() -> int`, `outline(patch: int) -> PackedVector3Array` |
| `lurker.ducts` (`duct_graph.gd`, extends `conduit_graph.gd`) | `closed: bool`, `at() -> Dictionary {edge, along}`, `place(edge: int, along: float)`, `point_of(edge, along) -> Vector3`, `nearest_node(point) -> int`, `nearest_exit(node: int) -> int` (index into `exits`), `path_points() -> PackedVector3Array` (her way ahead), inherited `sound_route(source, near_node, listener, room_of, world_audio)` and `distances_from(node)` |
| `lurker.routes` (`lurker_routes.gd`) | `path_points() -> PackedVector3Array`; room costs read `hotel.lit()` |
| `lurker.capture_log` | `Array` of `{cue_id: int, seat: int, cue_at: float, caught_at: float, window: float, forced: bool}` (session.elapsed seconds); every capture appends one |
| `lurker.force_state(state: StringName, quarry_seat := -1)` | the arena's keys; used by tests |
| `lurker.tune(profile)` | reads the keys of 0.4 |

If phase 2 lacks one of these, add it in 3a as a thin member of the owner script, written on top of what phase 2 has (never bypassing the shell or the duct graph).

### 0.3 Her states in the contract's words (3a makes `activity()` exactly this)

`const STATES: Array[StringName] = [&"roam", &"listen", &"stalk", &"peek", &"still", &"approach", &"cue", &"capture", &"scared", &"above"]` (the index is the wire value of 6.3).

| State (OFICINAS 4) | `activity()` | hostile | engaged | accepts leads | `alarm_level()` (override) | `hushed()` |
|---|---|---|---|---|---|---|
| roam (Rondar) | `&"roam"` | no | no | yes | 0 | no |
| listen (Escuchar) | `&"investigate"` | no | no | no | 0 | yes |
| stalk (Acechar) | `&"chase"` | yes | no | no | 1 | no |
| peek (Asomarse) | `&"search"` | no | no | yes, refused while it lasts | 0 | no |
| still (Quieta) | `&"alert"` | yes | no | no | 1 | yes |
| approach (Acercarse) | `&"chase"` | yes | no | no | 2 | no |
| cue (Aviso) | `&"strike"` | yes | yes | no | 2 | no |
| capture (Coger) | `&"capture"` | yes | yes | no | 2 | no |
| scared (Espantarse) | `&"investigate"` | no | no | no | 0 | no |
| above (Encima) | `&"wait"` | yes | yes | no | 1 | yes |

`is_attacking()` is then true in stalk, still, approach, cue and capture: no phantom sight while she is on somebody (`phantom_sight.allowed()`), which keeps the face lies away from the real face. `can()`: `&"ducts"` true, everything else false (no lifts, no sets, no wardrobes, no shriek of the Locust's kind, no echo).

### 0.4 Difficulty: `CREATURE_PROFILES[&"lurker"]` (0f writes the table; these are the names and values)

| Key | Apacible | Equilibrada | Desafiante | Pesadilla | Read by |
|---|---|---|---|---|---|
| `cue_window` (s) | 2.2 | 1.8 | 1.5 | 1.2 | brain (phase 2), bots |
| `lit_capture` | false | true | true | true | brain |
| `duct_speed` (m/s) | 1.2 | 1.6 | 2.0 | 2.4 | shell/ducts, voice (knock cadence) |
| `stalk_distance` (m) | 12 | 10 | 8 | 6 | brain |
| `still_time` (s) | 2 | 3 | 4 | 6 | brain |
| `scare_calm` (s) | 60 | 45 | 35 | 25 | brain (per prey), save |
| `approach_scale` | 0.8 | 0.9 | 1.0 | 1.15 | brain |
| `drain_reach` (m) | 3.0 | 3.0 | 3.5 | 4.0 | `lurker_drain.gd` (2.5) |
| `peek_rate` (×, "Muchos/Muchos/Normales/Pocos") | 1.6 | 1.6 | 1.0 | 0.6 | brain, director |
| director `encounter_every` (s) | 120 | 120 | 150 | 180 | `pacing_director.tune()` |
| director `cross` | 2.0 | 2.0 | 1.0 | 0.5 | `pacing_director.tune()` |
| director `raps` | 0.0 | 0.0 | 0.0 | 0.0 | `pacing_director.tune()` (2.4) |

Everything else (grace, lifts, restarts, the director's other keys, the phase-1 systems keys `typing_time`, `board_budget`, `lift_timer`, `timer_switch`, `fan_charges`, `fan_time`) comes from the base profile. If 0f already wrote any of these keys under another name, keep 0f's name and fix this spec's readers. `difficulty_test` gains: every Lurker profile has all twelve keys with these values; no Locust profile has any of them.

### 0.5 Decisions taken here (write them in `docs/OFICINAS.md` 14 as "decidido por los agentes, pendiente del autor")

1. **Lie cadence.** OFICINAS 5 compares "40 to 90 s" with a hotel "1.5 to 3 min", but the hotel's code waits 13 to 42 s (`sanity.HALLUCINATION_WAIT`, scaled 0.7 to 1.3). To keep "more frequent than the hotel", the Lurker's wait is the hotel's times `WAIT_SCALE := 0.7` (about 9 to 38 s). Section 5 of OFICINAS is corrected to say so.
2. **Lies never put a caption on screen** (the interface never lies, OFICINAS 5). The hotel's lies have none either.
3. **No breath and no jaw click in any lie, and none in the dread aura.** The cue is "an exhalation and two jaw clicks"; nothing else of the floor may sound like it. Her breathing is only her presence, from where she is.
4. **The director's knuckles on a door (`raps`) are off on floor 2**: a duct knock or a creaking tile is her tell, and the director must not make one up. Its weight is a profile key (0.4).
5. **A crawler's cue window is longer**: in the main duct a half turn takes 1.3 s (`CRAWL_TURN_RATE 2.4`), more than Pesadilla's 1.2 s. While the victim `level.crawling_at()`, the window is `cue_window + CRAWL_CUE_EXTRA` with `CRAWL_CUE_EXTRA := 1.1` (brain reads it; fairness tests of phase 2 add a crawler case).
6. **She enters the main duct only behind the last crawler**: through the crossing stub, only when every survivor in the duct is past the crossing towards the shaft ("por detrás puede venir ella").
7. **The camera falls looking up** (OFICINAS 6): a camera on its back, lens up at 55 to 84 degrees. The body's fall is kept out of its picture.
8. **A tile swings over every capture under a false ceiling**: she knocks one loose as she pulls; it stays for the stage.
9. **Lights she drinks count as dark** for `hotel.lit()` from a drain of 0.5 (lamps at 50 %), with hysteresis to 0.45 (2.5).

---

## 1. Files

### Create

| File | Step | What |
|---|---|---|
| `game/enemies/lurker/lurker_voice.gd` | 3b | everything she sounds like: footfalls by surface, duct travel, the cue, the shriek, tile and dust, the car |
| `game/enemies/lurker/lurker_drain.gd` | 3a | the lights she drinks |
| `game/audio/profiles/lurker.tres` | 3b | her `CreatureAudioProfile` |
| `tools/audio/prepare_lurker_sfx.py` | 3b | working copies of her recordings (3.1) |
| `assets/audio/sfx/lurker/*.wav` (+ `.import`) | 3b | its output |
| `game/app/hallucinations/lurker_hallucinations.gd` | 3c | her lies |
| `game/app/hallucinations/lurker_poser.gd` | 3c | poses her phantom (peek, stare) |
| `game/app/capture_styles/lurker_score.gd` | 3d | her capture, beat by beat (standalone: a script cannot override a parent's constants) |
| `game/app/capture_styles/lurker_capture.gd` | 3d | `extends "res://game/app/capture_styles/locust_capture.gd"`: lift and drop |
| `tools/bots/bot_threat_lurker.gd` | 3f | the bots' model of her |
| `tools/art/lurker/bake_ink_noise.gd` | 3g | bakes the 64³ ink noise |
| `assets/enemies/lurker/ink_noise.res` | 3g | its output (ImageTexture3D, R8) |
| `tests/office/office_survival_test.gd` | 3a | section 9.1 |
| `tests/office/office_audio_test.gd` | 3b | section 9.4 |
| `tests/office/office_capture_test.gd` | 3d | section 9.2 |

### Change

| File | Step | Change (each a no-op for floor 1) |
|---|---|---|
| `game/floors/office_floor.gd` | 3a | `CREATURE := "res://game/enemies/lurker/lurker_creature.tscn"` |
| `game/app/hotel_main.gd` | 3a | `creature_scene_override` and `--null-creature`; `arm_creature()` guard; `lurker` gets `level` before `_ready` like the Locust |
| `game/enemies/creature.gd` | 3a, 3d, 3e | `turn_for_capture()`, `on_event()`, `tally()`, `record_fields()`/`record_row()` (if 0a5 did not) |
| `game/enemies/lurker/lurker.gd` | all | contract members of sections 2 to 7 |
| `game/enemies/lurker/lurker_visual.gd`, `lurker_limbs.gd`, `lurker_darkness.gdshader` | 3d, 3g | grips, `upright`, footfall normal, LOD, quality, hiding, `layer_meshes()` |
| `game/director/pacing_director.gd` | 3a | `raps_weight` |
| `game/world/hotel/hotel_geometry.gd` | 3a, 3c, 3g | `lamp_points()`, `drain()` third argument, `drain_of()`, `follow_bodies()`/`light_body()` use `layer_meshes()` |
| `game/world/office/office_geometry.gd` | 3a, 3c | `lamp_points()` override, `flicker_one()` |
| `game/audio/world_audio.gd` | 3b | `ensure_duct_bus()`, routes may carry `bus`, hum pitch under drain |
| `game/audio/creature_audio_profile.gd` | 3b | aura fields |
| `game/audio/dread_aura.gd` | 3b | `use_profile()` |
| `game/app/sanity.gd` | 3b, 3c | own lies, `fright()` |
| `game/app/phantom_sight.gd` | 3c | `sight_spots()` |
| `game/app/executions.gd`, `death_tape.gd`, `blood.gd`, `camera_fall.gd`, `capture_styles/locust_capture.gd`, `game/player/avatars/avatar_visual.gd` | 3d | the score per style, `stage_extra()`, framing hooks, look-up rests, blood hooks, the hanging pose |
| `game/app/observer_gizmos.gd`, `observer_view.gd` | 3e | layer 7 `ducts`, colours |
| `game/net/match_net.gd`, `game/net/net_session.gd` | 3e | `creature_event`, PROTOCOL |
| `tools/bots/bot_threats.gd`, `bot_brain.gd`, `bot_watchdog.gd`, `bot_match.gd`, `bot_recorder.gd`, `tools/bots.ps1`, `tests/hotel/bots_test.gd` | 3f | section 7 |
| `tools/dev/body_clip_probe.gd` | 3d | `--floor=2` |
| `tests/hotel/sanity_test.gd` | 3c | `--floor=2` part |
| `tests/hotel/creature_contract_test.gd`, `difficulty_test.gd` | 3a to 3e | sections 9.6 and 0.4 |
| `tools/benchmarks/hotel_benchmark.gd` | 3g | `--lurker` |
| `tools/audio/prepare_office_sfx.py` | 3c | four rows (3.1) |
| `tools/verify.ps1` | each | section 10 |
| `game/ui/hotel_ui.gd` (`CREDITS`), `docs/*` | 3b, 3c, end | section 11 |

---

## 2. Step 3a: the Lurker on the floor

### 2.1 Spawning by `kind.CREATURE`

- `office_floor.CREATURE` becomes the Lurker's scene. `hotel_main.spawn_creature()` (0c) already instantiates `load(kind.CREATURE)`; it must set `creature.level = self` before `add_child` (as it does for the Locust today, `hotel_main.gd:1393`) and call `place_at(room)` (1a) instead of writing `patrol_room`.
- **The null creature stays for the phase 1 tests.** `hotel_main.gd`:
  ```gdscript
  ## A creature scene used instead of the kind's (tests of the floor's systems
  ## that must not be hunted): set before start_floor, or --null-creature.
  var creature_scene_override := ""
  const NULL_CREATURE := "res://game/enemies/null_creature.tscn"
  ```
  `spawn_creature()` uses the override when not empty; `_enter_tree()` sets it to `NULL_CREATURE` when the user args have `--null-creature`. `office_test`, `office_stages_test`, `office_geometry_test` and the phase-1 part of `bots_test --floor=2` get `--null-creature` (in `verify.ps1`) or set the variable before `start_floor`; the net scenario `office_coop` sets it on every role. On floor 1 the variable is empty: unchanged.
- `arm_creature()` (`hotel_main.gd:163`): if it still writes `reach_scale` and `relentless`, move those two writes into a contract method `func apply_rules(onslaught: bool) -> void: pass` (Locust: the same two writes; Lurker: nothing; onslaught is the Locust's rule per 0f).
- `world_audio.set_creature(creature.sound_profile)`: `lurker.gd` has `@export var sound_profile: Resource = preload("res://game/audio/profiles/lurker.tres")`.
- **Where she starts** (`place_at(room)`, `den_point(stage)`): inside the duct, at the duct node of `den_room(stage)`, hidden. `den_room(stage)` is the Locust's rule (`hotel_locust.den_room()`, 50 to 80 % of the planta's reach from its entry, not within 2 hops of the refuge, not off-limits) with the floor's seed draw `hash([seed, "den", stage])`; move that body into a static `FLOOR.den_rooms(manifest, stage, shut_out: Array) -> Array` used by both (the Locust's order of draws unchanged: the creature contract test pins `den_room()` before and after on 10 seeds). On floor 2 drop candidates with no duct node (`ducts.nodes` with that room). `den_point()` returns the node's point; `place_at()` calls `ducts.place(edge, 0.0)` on an edge of that node.

### 2.2 Contract members of `lurker.gd` that the rest of the floor uses

```gdscript
func kind_id() -> StringName: return &"lurker"
func can(ability: StringName) -> bool: return ability == &"ducts"
func activity() -> StringName              # table 0.3
func alarm_level() -> int                  # table 0.3 (overrides the base)
func hushed() -> bool                      # table 0.3
func eye_point() -> Vector3                # her head (visual head bone), not global_position + 1.7
func face_point() -> Vector3               # the face: head bone + its +Z * 0.12 * visual.size
func gaze() -> Vector3                     # visual.look_point - face_point() when set, else the head's forward
func quarry() -> Node3D                    # the body of brain's quarry seat, or null
func travel_metres(room_id: int) -> Dictionary   # lurker_routes: metres to every room by her own ways (ducts included)
func in_transit() -> bool                  # between plantas (2.3)
func lead_to(point, radius, seconds, kind, once := false, avoid := [], sniff := false) -> bool
func teleport(point: Vector3, yaw: float, reason := &"") -> void
func forget_journey(point: Vector3, reason: StringName) -> void
func relocate(point: Vector3, rest: float) -> void
func search_from(point: Vector3, heading: Vector3) -> void
func follow_to_planta(stage: int, fresh := false) -> void
func den_point(stage: int) -> Vector3
func place_at(room_id: int) -> void
func save_state() -> Dictionary            # 2.7
func restore_state(state: Dictionary, rest: float) -> void
func turn_for_capture(_yaw: float) -> void: pass   # her orientation is the capture style's (5.4)
func on_event(kind: String, data: Array) -> void   # 6.4
func tally() -> Dictionary                 # 7.4
```

- `lead_to()` refuses (returns false) while she is in peek, scared, cue, capture or above, and for a point in an off-limits room. With `kind == "cruce"` (the director's encounter, OFICINAS 4 "El director, adaptado") the lead becomes a peek at the edge of the target's view or a ceiling crossing of a room the target can see (`brain.lead_encounter(point, seconds)` in phase 2's brain; if phase 2 has none, it forces `&"peek"` with the room as goal). Every other kind is a roam lead.
- `teleport()`: `super()` then puts her where the point is: `ducts.place()` on the nearest edge when the point is a duct node (within 0.05 of one), else `shell.place(shell.snap(point, Vector3.DOWN))`. `forget_journey(point, reason)` drops her route and her duct path for every reason; `relocate()` also forgets her quarry, every calm, any cue (ended with `&"cancel"`) and sets `grace = maxf(grace, rest)`.
- `turn_for_capture(yaw)` is new in the contract: `func turn_for_capture(yaw: float) -> void: rotation.y = yaw` in `creature.gd`, and `executions.apply_execution()` calls it instead of `creature.rotation.y = yaw` (`executions.gd:267`). Locust inherits the default: identical.

### 2.3 Between plantas (OFICINAS 4, Ductos)

- `follow_to_planta(stage, fresh)`: if she is already in transit to `stage`, or on that planta, nothing. Else `transit = {"stage": stage, "left": seconds}` with `seconds = TRANSIT_BASE + metres / duct_speed`, `TRANSIT_BASE := 6.0` (the 6 m of slab between plantas at 1 m/s through a riser), `metres` = her duct metres to the nearest duct node of her planta's freight landing wall (`ducts.distances_from(ducts.nearest_node(global_position))`, min over the nodes of rooms adjacent to `gates[wing].room`), and she is hidden in her duct meanwhile (`visual.set_hidden("duct")`). When `left` reaches 0 she `teleport()`s to `den_point(stage)` with reason `&"planta"`, and `search_from()` there.
- `in_transit()` is true while `transit` is not empty: the director leaves her alone (`pacing_director.silent()` already reads it).
- **Heard outside the car.** While in transit, if this machine's player is riding a car (`level.lifts.boarding.get("car", -1) >= 0`), `voice.outside_car(car)` every `CAR_SCRATCH := Vector2(0.6, 1.3)` seconds (3.8). Nothing else of her happens in the car: she is never placed there.

### 2.4 The director with her keys

- `pacing_director.tune(profile)`: `raps_weight = float(profile.get("raps", 0.7))`. In `build()`, the move list uses `["golpes", raps_weight]` instead of the literal `0.7`, and the stalled branch uses `[["golpes", 1.0]]` only when `raps_weight > 0.0` (else `[["quieto", 3.0]]`). `raps(target)` returns false at once when `raps_weight <= 0.0` (the `"quieto"` move then prowls without knuckles). Hotel profiles have no `raps` key: 0.7, identical.
- `encounter_every` and `cross` come from 0.4 through the merged profile (no code change).
- `reach()` already asks `creature.travel_metres()` (0a2): her metres include the ducts, so menace counts them (OFICINAS 4).

### 2.5 The lights she drinks (`lurker_drain.gd`)

OFICINAS 1 and 4: within `drain_reach` of a lamp the room's lamps go down together to 30 to 60 % and come back as she goes; the tubes flicker; the hum drops in pitch. It is a promise: never faked (3c), and computed on every machine from where she is.

```gdscript
extends RefCounted
const DRAIN := Vector2(0.4, 0.7)       # the amount at the edge of her reach and right under the lamp (lamps at 60 % and 30 %)
const DARK := 0.5                      # from this amount the room counts as not lit (hotel.lit)
const LIT_AGAIN := 0.45                # and lit again under this (hysteresis)
const RISE := 4.0                      # amount per second going down
const RELEASE := 1.5                   # and coming back
const TITILATE := 0.08                 # the flicker laid over it, only on the lamps (not in drain_of)
const TITILATE_HZ := Vector2(9.0, 14.0) # per room, from hash(room id)
const LOOK := 12.0                     # rooms whose lamps are within this of her are looked at
var level
var reach := 3.0                       # tuning().drain_reach
var amounts := {}                      # room id -> base amount now
var clock := 0.0
func setup(owner_level) -> void
func step(from: Vector3, delta: float) -> void
func clear() -> void                   # every room back to 0 (despawn, floor torn down)
```

- `step(from, delta)` (called from `lurker._process`, on every machine, also while she is in a duct or the plenum: a lamp 0.75 m under the duct drains, which is how the lights tremble "a su paso" overhead): for each room on her planta with a lamp point within `LOOK`, `d` = the distance from `from` (her face point) to the nearest of `level.hotel.lamp_points(room_id)`; `target = lerpf(DRAIN.x, DRAIN.y, 1.0 - d / reach) if d < reach else 0.0`; the amount eases to it (`RISE` down, `RELEASE` back); `level.hotel.drain(room, amount, wobble)` with `wobble = TITILATE * sin(TAU * f_room * clock)` while `amount > 0`; only rooms whose amount changed by more than 0.005 or that are wobbling are written.
- `hotel_geometry.gd` (0e owns `drain()`): add the optional third argument `wobble := 0.0` (multiplied into the lamps only), and `func drain_of(room_id: int) -> float` returning the base amount. `lit()` reads it with the hysteresis above (keep a `drained_dark := {}` set: enters at `DARK`, leaves at `LIT_AGAIN`). If 0e already defines `lit()` differently, this is the reading it must have (OFICINAS 11.3).
- `hotel_geometry.lamp_points(room_id) -> PackedVector3Array`: hotel: the positions of that room's lamps (`lights` with `meta room == room_id`); `office_geometry` override: troffer centres (`OFFICE.troffers(room)` centres at `py + height - 0.05`), batten positions (`battens_of[room_id]`), the two pendants of a boardroom; empty for `emergency` rooms. Cached per manifest.
- **The hum** (`world_audio.update_hum_levels()`, line 701): `hum.pitch_scale = 1.0 - HUM_DRAIN_PITCH * level.hotel.drain_of(int(entry.light.get_meta("room", -1)))`, `HUM_DRAIN_PITCH := 0.08`. Hotel: `drain_of()` is 0, pitch 1.0 as now (the hum players' pitch is never set elsewhere).
- Unpowered rooms: `drain()` on them changes nothing visible (0e); `drain_of()` still reports the amount, so `lit()` stays false either way.

### 2.6 The floor's systems and her (OFICINAS 3)

- **Light herds her (planta 2).** Her brain reads `hotel.lit()` at every decision (phase 2). 3a adds: every `0.25 s`, if the room she is in (or over, in the plenum) became lit while she is in `roam`, `stalk` or `approach`, the brain is told `light_on(room_id)`: she leaves by the nearest exit into the ducts (`ducts.nearest_exit()`), and the move is heard: `voice.tile_shift(exit point)` and the knocks of 3.4 (OFICINAS 3: "se va por los ductos a la oscuridad, y se oye adónde").
- **Fans close the ducts (planta 3).** Every brain tick: `ducts.closed_wings = [2] if air != null and air.ducts_closed() else []` (`air = level.objective(&"air")`). If she is in a duct of a closed wing she leaves by the nearest exit by duct metres within `1.0 s` and does not enter one again while closed; routes give closed duct edges `INF`. Her hearing is already masked (1g: `locust_hear` scales the radius by `1 - sound_mask`). When the fans stop she goes back in: the first exit within `stalk_distance` of her, or the nearest.
- **The main duct** (decision 0.5.6): duct edges of kind `main` and `cross` are hers, but she takes the `cross` edge into the main only when no survivor crawling in the main (`level.crawling_at(body)`) is between the hatch and the crossing node along `air.main.nodes`.
- **The crawler's cue** (decision 0.5.5): `CRAWL_CUE_EXTRA := 1.1` added to the window while the victim `level.crawling_at()`.
- **Lockers (Encima).** No new code if phase 2 did it; 3a checks it in 9.1 case K: she waits on top of a locker with somebody inside, never opens it, and leaves through the ceiling with a duct knock when she tires.

### 2.7 What is kept with a floor (`save_state()`, `restore_state()`)

```text
{"at": Vector3, "yaw": float,                       # the Locust's keys, kept for the observer and old readers
 "kind": "lurker",
 "medium": "room" | "plenum" | "duct",
 "shell": {"patch": int, "u": float, "v": float, "heading": float, "hang": float},
 "duct": {"edge": int, "along": float},             # only with medium "duct"
 "calm": {seat (int): seconds left (float)},        # scare_calm still owed to each prey
 "transit": {"stage": int, "left": float}}          # {} when not between plantas
```

`restore_state(state, rest)`: `relocate(state.at, rest)`; then by `medium`, `ducts.place(edge, along)` or `shell.place(state.shell)` (if the patch id is not in the shell, `shell.place(shell.snap(at, Vector3.DOWN))`); `calm` and `transit` back. Her quarry, a cue and a peek are never kept: the cue ends `&"cancel"` and nothing is owed (floor_save GRACE 8 s still applies). `floor_save.gd` is unchanged: it already calls the contract (0a3) and keeps `"objectives"` (1e).

---

## 3. Step 3b: her sound

### 3.1 The recordings (`tools/audio/prepare_lurker_sfx.py`)

Modelled on `tools/audio/prepare_lift_sfx.py` (ffmpeg through `tools/trailer3d/audio/dsp.py`, mono, 44.1 kHz, 16 bit, deterministic). Sources under `source_assets/oficinas/audio_criatura/<slug>/`, only entries with `"status": "ok"` in its `registro.json`. Output `assets/audio/sfx/lurker/`. Helpers: `load(path)`, `trim(x, keep)`, `fade(x, fin, fout)`, `peak(x, level)`, `pitch(x, ratio)` (ffmpeg `asetrate` + `aresample`), `lowpass(x, hz)` (ffmpeg `lowpass`), `onsets(x, count, gap, pre, post)` (envelope over 5 ms, peaks above -24 dB of the maximum and at least `gap` apart, the `count` loudest, returned in time order, each cut `pre` before to `post` after), `mix(a, b, at, gain_db)`. Every output gets a 4 ms fade in, 30 ms fade out, peak 0.7 unless said.

| Output | Source (slug: file) | Licence | Processing | Use |
|---|---|---|---|---|
| `tile_1..6.wav` | `ceiling_claws_cardboard_scratch`: `freesound_community-scratching-on-box-40160.mp3` | Pixabay | `onsets(6, 0.15, 0.02, 0.22)` | claws on a ceiling tile (under the false ceiling, or on it in the plenum) |
| `tile_creak_1..3.wav` | `tile_grid_metal_rattle`: `freesound_community-air-conditioner-vent-metal-ring-clank-26871.mp3` | Pixabay | `onsets(3, 1.0, 0.03, 0.5)`, pitch 0.9 | the grid creaking as a tile moves |
| `tile_grind.wav` | `tile_styrofoam_grind`: `freesound_community-grinding-styrofoam-46849.mp3` | Pixabay | its loudest 1.2 s | the tile edge rubbing |
| `dust_1.wav`, `dust_2.wav` | `debris_sandfall`: `freesound_community-sandfall5-83468.mp3`; `debris_gravel_dirt_small`: `freesound_community-gravel-stone-dirt-debris-falling-small-1-3-36216.mp3` | Pixabay | whole; first 2.5 s; peak 0.5 | dust falling from a tile |
| `metal_1..4.wav`, `scrape_1.wav` | `metal_fingernail_elevator_ceiling`: `freesound_community-20131209_fingernail-on-elevator-ceiling_olympusls10_xy-87239.mp3` | Pixabay | taps: `onsets(4, 0.12, 0.01, 0.18)` in its first 1.8 s; scrape: its last 0.9 s | claws on sheet metal |
| `knock_1..6.wav` | `duct_impacts_metal_box`: `freesound_community-duct-impacts-76170.mp3` | Pixabay | `onsets(6, 0.4, 0.02, 0.35)`, pitch 0.85 | moving inside a duct |
| `knock_7.wav`, `knock_8.wav` | `duct_heater_vent_hits`: `freesound_community-heater-vent-hit-lower-part-83044.mp3`, `...-higher-part-103305.mp3` | Pixabay | whole, pitch 0.8 | same |
| `hard_1..8.wav` | `wall_claws_smooth_rock`: `freesound_community-claws-on-smooth-rock-65642.mp3` | Pixabay | `onsets(8, 0.15, 0.01, 0.16)` | plaster and block walls, hard floors: the tick-tock |
| `drag_1.wav`, `drag_2.wav` | `plaster_tool_scrape`: `freesound_community-plaster-screaming-55526.mp3` | Pixabay | its two loudest 0.7 s, lowpass 5 kHz, pitch 0.9 | a claw dragged down a wall |
| `wood_1..8.wav` | `wood_claws_skittering_dog`: `freesound_community-skittering-dog-33523.mp3` | Pixabay | `onsets(8, 0.15, 0.01, 0.16)` | wood veneer (Dirección) |
| `wood_scratch_1.wav`, `_2.wav` | `wood_fingernail_scratch`: `freesound_community-scratching-with-fingernails-79478.mp3` | Pixabay | two 0.8 s cuts at its loudest | same, dragged |
| `presence.wav` | `breath_cow_bodot`: `freesound_community-breath-of-cow-78843.mp3` | Pixabay | 20 s from 10 s, pitch 0.85, lowpass 3.5 kHz, 0.5 s crossfaded loop, peak 0.6 | her presence loop (slow, wet, from where she is) |
| `cue_1.wav` | `breath_horse_bsb`: `bsb_1543_breath_horse_4.mp3` + `bone_knuckles_crack`: `freesound_community-knuckles-cracking-98331.mp3` | CC0 + Pixabay | breath pitch 0.88, lowpass 2.5 kHz; the knuckles' onsets 1 and 2 (70 ms each) mixed at +0.42 s and +0.62 s, -3 dB; peak 0.9, at most 0.9 s | **the back cue, and nothing else** |
| `cue_2.wav` | `bsb_0285_breath_of_a_horse_1.mp3` + onsets 3 and 4 of the knuckles | CC0 + Pixabay | pitch 0.85; clicks at +0.38 s and +0.60 s | same |
| `scare_1..3.wav` | `shriek_barn_owl_bsb`: `bsb_1403_barn_owl_2.mp3` + `shriek_bat_screeches_oga`: `flac/bat_01.flac`..`bat_03.flac` | CC0 | the owl's three loudest screeches at least 1.5 s apart, 1.2 s each, pitch 0.82, each mixed with one bat at -8 dB, pitch 0.7; peak 0.9 | her shriek when frightened (animal, never human) |
| `bite_1.wav`, `bite_2.wav` | `bone_celery_bsb`: `bsb_1408_bones_cracking_2.mp3`, `bsb_1409_bones_cracking_3.mp3` + knuckles onset 5 | CC0 + Pixabay | whole, pitch 0.8, the click at +0.05 s, -6 dB | the kill beat of her capture |

Rows appended to 1d's `tools/audio/prepare_office_sfx.py` (output `assets/audio/sfx/office/`), for the lies of 3c:

| Output | Source | Licence | Processing |
|---|---|---|---|
| `phone_ring.wav` | `audio_oficina/telefono_antiguo/bsb_3532_socotel_discreet_rings.wav` | CC0 (Joseph SARDIN, BigSoundBank) | first two rings, about 4 s; loopable |
| `copier.wav` | `audio_oficina/fotocopiadora/soundbible_2169_photocopy_machine.wav` | CC BY 3.0, "Photocopy Machine" by Daniel Simion, SoundBible.com | first 4 s (warm-up and first copy); listen for digital beeps (registro note) and cut them |
| `chair_roll.wav` | `audio_oficina/silla_oficina_ruedas/oga_nicolemariet_office_chair_roll.wav` | CC BY 4.0, Nicole Marie T (OpenGameArt) | whole (3 s) |
| `starter.wav` | `audio_edificio/fluorescent_starter_flicker/pixabay_61228_faulty_fluorescent_starter_hum_everydaysounds.mp3` | Pixabay (CC0 original by EverydaySounds) | first 3 s (the starter's clicks) |

Already made by phase 1 and reused, no new file: `office/typing.wav`, `tube_hiss.wav`, `lever_1..3.wav`, `tick.wav`, `fans.wav`.

Run the scripts, import headless (`godot --headless --import`), commit the `.wav` and `.import` files, register every output in `docs/ASSETS.md` (source, author, licence, link) and `docs/asset_hashes.json`, and add Daniel Simion (CC BY 3.0) and Nicole Marie T (CC BY 4.0) to `hotel_ui.gd` `CREDITS`. Section 14 lists what waits for the author.

### 3.2 Her profile (`game/audio/profiles/lurker.tres`, `creature_audio_profile.gd`)

`creature_audio_profile.gd` gains fields whose defaults are today's aura:

```gdscript
@export var aura_start := 30.0          # dread_aura.start_distance
@export var aura_full := 4.0            # dread_aura.full_distance
@export var aura_breath := true         # the aura's DreadBreath layer
@export var aura_clicks: Array[AudioStream] = []   # empty: dread_aura.CHITTERS
```

`lurker.tres`: `presence = sfx/lurker/presence.wav`, `volume_db = -14.0`, `audible_distance = 14.0`, `caption = "[Algo respira cerca]"`, `aura_start = 22.0`, `aura_full = 3.0`, `aura_breath = false` (decision 0.5.3), `aura_clicks = [hard_2, tile_3, metal_2, wood_5]`. `locust.tres` is not touched.

### 3.3 The duct bus (`world_audio.gd`)

Made at runtime when her floor needs it, never on floor 1 (`default_bus_layout.tres` is not edited: Godot rewrites it, and the loop restores it):

```gdscript
const DUCT_BUS := &"Ducts"
## Her sounds through the ducts: a sheet-metal box (a narrow boost round 1 kHz,
## no lows, a short bright reflection), then into the creature's binaural bus.
func ensure_duct_bus() -> void
```

- Added at the end; `send = &"Creature"` (so the "Ears" delay places it, `update_ears()`).
- Effects: `AudioEffectEQ6` with band gains `[-12, -6, 0, +5, +2, -4]` dB (32, 100, 320, 1000, 3200, 10000 Hz); `AudioEffectReverb` `room_size 0.18`, `damping 0.15`, `spread 0.3`, `predelay_msec 8`, `predelay_feedback 0.5`, `hipass 0.2`, `dry 1.0`, `wet 0.28`.
- Called from `lurker._ready()` (`level.world_audio.ensure_duct_bus()`). Its volume follows the threat slider through the send chain; the observer's `mute_threat` mutes it with `Threat`.
- **Routes may name their bus.** `apply_route(player, route, gain, dry_bus, creature)`: after the creature branch, `if route.has("bus"): player.bus = route.bus`. The presence (line 604): `presence.bus = presence_route.get("bus", CREATURE_BUS[presence_route.get("echo", false)])`. Hotel routes never carry `bus`.

### 3.4 `lurker_voice.gd`

A child Node of the creature; its players hang under `world_audio`, as the Locust's voice does (`hotel_locust._ready()`, lines 426 to 438), and are freed in `_exit_tree()`.

```gdscript
extends Node
const BASE := "res://assets/audio/sfx/lurker/"
const SETS := {"tile": 6, "metal": 4, "hard": 8, "wood": 8}      # tile_N, metal_N, hard_N, wood_N
const KNOCKS := 8
const STEP_DB := {"tile": -11.0, "metal": -8.0, "hard": -12.0, "wood": -11.0, "soft": -20.0}
const SOFT_CUTOFF := 1200.0          # carpet: the hard set, dulled
const STEP_GAP := 0.09               # at most one claw this often
const STEP_VOICES := 3
const KNOCK_DB := -6.0
const SCRAPE_EVERY := Vector2(2.0, 4.0)
const CREAK_DB := -10.0
const DUST_DB := -16.0
const CUE_DB := 2.0                  # on the victim's machine
const CUE_OTHERS_DB := -4.0
const CUE_DUCK := 0.9
const SCARE_DB := 0.0
const CAR_DB := -8.0
const CAPTIONS := {"cue": "[Una respiración en la nuca]", "scare": "[Un chillido]", "ducts": "[Algo se arrastra por los conductos]", "tile": "[Cruje el falso techo]"}
const CAPTION_NEAR := {"scare": 16.0, "ducts": 10.0, "tile": 8.0}
var creature
var level
func setup(owner) -> void
func material_at(point: Vector3, normal: Vector3, medium: StringName) -> StringName
func footfall(point: Vector3, strength: float, normal: Vector3) -> void
func travel(delta: float) -> void
func tile_shift(point: Vector3, dust := true) -> void
func cue(cue_id: int, victim_seat: int, face: Vector3) -> void
func shriek(point: Vector3) -> void
func outside_car(car: int) -> void
func play_routed(path: String, point: Vector3, gain: float, cutoff := 20000.0) -> void
func play_direct(path: String, point: Vector3, gain: float, bus := &"Creature") -> void
var last := {}                       # {"path", "point", "bus", "material"} of the last sound, for tests (world_audio.enabled false included)
```

**`material_at(point, normal, medium)`** (the surface under a hand; `palette = FLOOR.palette(level.manifest)`, `room = FLOOR.room_at(level.manifest.rooms, point)`):

| Where | Material |
|---|---|
| `medium == &"duct"` | `metal` |
| `medium == &"plenum"` | `tile` |
| ceiling (`normal.y < -0.7`) | `tile` if `palette.false_ceiling(room)`, else `hard` (exposed slab) |
| wall (`absf(normal.y) <= 0.7`) inside an archive (`manifest.archives[]`, the point within 0.25 m of one of its `rows` rects) | `metal` (steel shelving) |
| wall, `palette.wall_material(room) == "veneer"` | `wood` |
| wall, any other | `hard` (painted plaster, block) |
| floor (`normal.y > 0.7`), `palette.floor_finish(room) == "carpet"` | `soft` |
| floor, any other | `hard` (vinyl, terrazzo, tile, concrete) |
| no room (shaft) | `metal` |

**`footfall(point, strength, normal)`**: connected to `visual.footfall` (3g adds the `normal` argument to `lurker_limbs.footfall` and `lurker_visual.footfall`; nothing else connects to them). Skips: within `STEP_GAP` of the last; `level.session.state != PLAYING`; the listener in an off-limits room (`level.point_protected(listener_position())`, OFICINAS 4: "Allí no se oye nada"). Picks the set by `material_at()`, never the same file twice running, gain `STEP_DB[material] + lerpf(-6.0, 0.0, strength) + world_audio.duck_db()`, `soft` also `cutoff = SOFT_CUTOFF` and the `hard` set; `play_routed()`. Pitch `randf_range(0.9, 1.08)`.

**`travel(delta)`** (from `lurker._physics_process` while `shell.medium() != &"room"`, when the visual is hidden and no hand lands): in a duct, a knock every `maxf(0.18, 0.5 / speed)` s (speed: her duct speed now), `knock_1..8` round-robin without repeats, gain `KNOCK_DB`, and `scrape_1` every `SCRAPE_EVERY` s; in the plenum, a `tile_N` every `0.6 / maxf(speed, 0.5)` s at `CREAK_DB` and, crossing a gap tile (`ducts.exits` of kind `"gap"` within 0.6 m), `tile_shift(gap point)`. Caption `"ducts"` within its distance, with world_audio's caption cooldown.

**`play_routed(path, point, gain, cutoff)`**: the route is `creature.sound_route_from(point, listener)` (3.5): in a duct through the exits (`bus = &"Ducts"`), in the plenum through the tile under her, in a room `world_audio.route_source(point, creature.get_rid())`. Not audible: nothing. Then `world_audio.apply_route(player, route, gain, "Threat", true)` (binaural; the route's `bus` wins), `attenuation_filter_cutoff_hz = minf(it, cutoff)`. `world_audio.last_event` is written as `play_at()` does, so tests see it.

**`tile_shift(point, dust)`**: `tile_creak_N` at `CREAK_DB` and, with `dust`, `dust_N` at `DUST_DB` 0.15 s later, and a dust puff: a `CPUParticles3D` (one shot, 40 particles, 1.6 s, grey, emitting from a 0.5 m square under the tile, gravity -1.5, not on any room layer of its own: `level.hotel.adopt()` it) freed after 3 s. Called when she goes in or out through a ceiling exit or a gap (her `entered_duct`/`left_duct` with an exit of kind `ceiling` or `gap`), and by `travel()` over gaps. Caption `"tile"` within its distance.

### 3.5 Where she is heard from (`sound_route`, `presence_route`)

```gdscript
const PLENUM_LOSS := -6.0
const PLENUM_CUTOFF := 1800.0
func sound_route(listener: Vector3) -> Dictionary: return sound_route_from(face_point(), listener)
func sound_route_from(point: Vector3, listener: Vector3) -> Dictionary
func presence_route(listener: Vector3) -> Array
```

- `sound_route_from(point, listener)`: `{"audible": false}` when the listener is in an off-limits room or on another planta. In a duct: `ducts.sound_route(point, ducts.nearest_node(point), listener, room_of, level.world_audio)` (1.5) with `bus = &"Ducts"` added; its `distance` must be metres inside plus the mouth's route to the listener (assert it in 9.4). In the plenum over room R: a point `p` under her at `R`'s ceiling minus 0.05; listener in R: `{audible, position: p, gain: PLENUM_LOSS, cutoff: PLENUM_CUTOFF, echo: false, distance}`; elsewhere `world_audio.route_source(p, RID(), listener)` with `PLENUM_LOSS` added and the cutoff capped. In a room: `world_audio.route_source(point, get_rid(), listener)`.
- `presence_route(listener)`: in a room, `level.world_audio.aura.route_to(listener, FLOOR.floor_point(global_position))` (the Locust's way); in a duct or the plenum, `[route.distance, route.position]` of `sound_route(listener)` when audible, else `[INF, Vector3.INF]`. The aura's cue point is then the grille she would come out of.
- **Never through a wall** (OFICINAS 9, AUDIO.md): every route ends at a point the listener can see (the mouth in their room, or the opening `route_source` finds). 9.4 case 6 holds it.
- Cost: `sound_route` is asked four times a second by `world_audio` and by each footfall; memoize the duct part per `(node, listener cell)` for 0.25 s like `world_audio.walked_route()` does (`ROUTE_MEMO`).

### 3.6 The dread aura (`dread_aura.gd`)

- `world_audio.set_creature(profile)` calls `aura.use_profile(profile)` (null: the defaults): `start_distance = profile.aura_start`, `full_distance = profile.aura_full`, `breath_enabled = profile.aura_breath`, `chitter_streams` = loaded `profile.aura_clicks` or `CHITTERS`.
- `apply_levels()`: the breath player plays only with `breath_enabled` (stopped otherwise). Nothing else changes: `alarm_level()` (her table 0.3), `hushed()` (×`HUSHED`), the phantom point (her lies never set `world_audio.phantom_point`: decision 0.5.3 keeps the aura true).
- Hotel: `locust.tres` has the defaults: identical (`hotel_audio_test`, `spatial_audio_test` green).

### 3.7 The cue, the shriek, the mind's fright

- **Cue** (`brain.cue_started`): `lurker.on_event("cue", [cue_id, seat, window, face_point()])` on the machine that drives her, then `match_net.creature_event()` (6.4). `voice.cue(cue_id, seat, face)`:
  - on the victim's machine (`seat == level.player.slot` and not a bot match): `cue_1`/`cue_2` alternating per victim, from her real face point: the route if audible, else straight from the point at -6 dB with cutoff 2500 Hz (it must never be lost); bus `Creature`; `world_audio.update_ears(face, 1.0)` first so the ears point at her; `world_audio.duck_under(CUE_DUCK)`; caption `CAPTIONS.cue` (subtitles setting, as `show_caption()` does);
  - elsewhere: `play_routed(path, face, CUE_OTHERS_DB)`, no caption;
  - `voice.last` and `world_audio.last_event` record it even with sound off.
- **Shriek** (`brain.scared`): `on_event("scare", [by_seat, how, global_position])`; `voice.shriek()`: `scare_N` routed at `SCARE_DB`, caption within 16 m. On the authority, `sanity.fright(body, SANITY_SHRIEK)` for each survivor within 12 m on her planta with a clear line to her face: new in `sanity.gd`,
  ```gdscript
  const SANITY_SHRIEK := 6.0
  ## A fright that is not a sight of it (her shriek): one per SANITY_SIGHT_REST, like the sights.
  func fright(body: Node3D, cost: float) -> void
  ```
  using the same rest and paid bookkeeping as `wear()` (lines 92 to 101). Never called on floor 1.

### 3.8 The car

`voice.outside_car(car)`: `metal_N` or `scrape_1` at `level.hotel.lifts[car] + side * 1.3 + Vector3.UP * randf_range(1.0, 2.4)` (`side` the car's lateral axis, alternating sides), `play_direct()` on `Creature` at `CAR_DB`: it is through the car's sheet on purpose, the one sound of hers not routed.

---

## 4. Step 3c: her lies

### 4.1 `lurker_hallucinations.gd`

Keeps the base API sanity and phantom_sight already call (`setup`, `false_call`, `quiet`, `walk_past`, `walk_start`, `sight_model`, `sight_poser`, `HEAD`, `BODY_BONES`) and adds what lets the creature choose its own lies:

```gdscript
extends Node
const OWN_LIES := true
const WAIT_SCALE := 0.7
const HEAD := "head"
const BODY_BONES := ["body", "abdomen", "upperarm_a.L", "upperarm_a.R", "forearm_a.L", "forearm_a.R"]
const VISUAL := preload("res://game/enemies/lurker/lurker.tscn")
const POSER := preload("res://game/app/hallucinations/lurker_poser.gd")
## Her own sounds no lie may play (decision 0.5.3): breath, jaw, shriek, bite, and the station's bell.
const NEVER := ["res://assets/audio/sfx/lurker/cue_1.wav", "res://assets/audio/sfx/lurker/cue_2.wav", "res://assets/audio/sfx/lurker/presence.wav", "res://assets/audio/sfx/lurker/scare_1.wav", "res://assets/audio/sfx/lurker/scare_2.wav", "res://assets/audio/sfx/lurker/scare_3.wav", "res://assets/audio/sfx/lurker/bite_1.wav", "res://assets/audio/sfx/lurker/bite_2.wav", "res://assets/audio/sfx/office/tube_bell.wav"]
var level
var rng := RandomNumberGenerator.new()      # randomized in setup(); tests seed it
var told: Array = []                        # the last 32: {kind, point, time}
func setup(owner_level) -> void
func wait_scale() -> float: return WAIT_SCALE
func lie(point: Vector3, gone: float) -> Dictionary      # one lie chosen and told: {kind, point}; {} when none fits
func kinds_here(gone: float) -> Dictionary               # kind -> weight, after the conditions of 4.3
func false_call(point: Vector3) -> void                  # the base API: claws over `point` (never a voice)
func quiet(delta: float) -> void                         # ends the phone on approach and the moving lies
func walk_past() -> bool                                 # a duct lie (4.3 "ducto"); true when it started
func walk_start() -> Vector3
func sight_model(host: Node) -> Node3D                   # VISUAL instance, crawling false, look_point INF
func sight_poser(model: Node3D)                          # POSER.new(model)
func sight_spots(sight, camera: Camera3D) -> Array       # 4.5
func say(path: String, point: Vector3, gain: float) -> void        # routed play; refuses (push_error) a path in NEVER
func say_moving(path: String, points: PackedVector3Array, conduit, speed: float, stop_share := 1.0) -> void
```

`lie()` always records `told` (tests run silent), and plays only with `level.world_audio.enabled`. It never calls `world_audio.show_caption()`, `hotel.drain()`, `hotel.set_room_power()`, an objective's `apply()`, `play_long(..., follow = true)` or anything that sends on the net.

### 4.2 `sanity.gd` hooks (the hotel's order of random draws unchanged)

- `hallucinate()`: right after `hallucination_wait -= delta` and its early return, and **before any random draw**:
  ```gdscript
  if lies_tell_own():
  	var own := creature_lies()
  	var gone_own: float = 1.0 - level.player.sanity / SANITY_UNEASY
  	hallucination_wait = lerpf(HALLUCINATION_WAIT.y, HALLUCINATION_WAIT.x, gone_own) * randf_range(0.7, 1.3) * float(own.wait_scale())
  	last_lie = own.lie(hallucination_point(randf_range(4.0, 14.0)), gone_own)
  	last_lie["time"] = Time.get_ticks_msec() / 1000.0
  	return
  ```
  `func lies_tell_own() -> bool`: the creature is valid, its `hallucinations()` is not null and `kind.get_script_constant_map().get("OWN_LIES", false)`. No draw, no node made, for the Locust.
- `lit_at()` asks `level.hotel.lit()` (0e does it; 3c checks it).
- `fright()` of 3.7.

### 4.3 The lies she tells (OFICINAS 5 and each planta's of section 3)

`kinds_here(gone)` keeps a kind only where its condition holds; `lie()` draws one by weight with `rng`. "Near" is walking metres (`world_audio.walked_route` length) unless said.

| Kind | Planta | Condition | What happens (local, this machine only) | Sound | Weight |
|---|---|---|---|---|---|
| `garras` | all | the player's room has a false ceiling | 3 to 6 claws on the ceiling within 1.5 m over the player in 1.2 s; 40 % of the time a creak, dust and a dust puff at a free tile within 2 m | `tile_N`, `tile_creak_N`, `dust_N` | 3 |
| `ducto` | all; on wing 2 only with the fans stopped (`air.spin == 0`) | a duct path of 3 to 6 edges whose nearest node is within 12 m, not through her real duct position | knocks travelling along it at 1.6 m/s, routed out of the exits like hers (`say_moving` with `level.creature.ducts` as conduit) | `knock_N` | 2 (wing 2: 4) |
| `telefono` | all | a room of type 3, 16 or 24 at 6 to 20 m, not the player's | a phone rings at its desk (room centre, 0.75 m up) until the player is within 4 m of it, or 8 s | `office/phone_ring.wav` | 1.5 (wing 0: 2.5) |
| `maquina` | all | a room of type 3, 16, 17 or 24 at 6 to 15 m | 2 to 3 s of keys | `office/typing.wav` | 1 |
| `tubo` | wing 0 | a tube path from the hub to a station, its nearest node 6 to 20 m off | the capsule's hiss runs 60 to 80 % of the way and stops; no bell, no station lamp | `office/tube_hiss.wav` on the tube conduit (`level.objective(&"files")`'s graph) | 2 |
| `fotocopiadora` | all | a room of type 7 at 6 to 20 m | a copier starts | `office/copier.wav` | 0.7 |
| `silla` | all | a room with `desk` or `desk_pair` furniture at 5 to 15 m | a chair rolls | `office/chair_roll.wav` | 0.7 |
| `persiana` | all | a glazed partition (`level.hotel.glass`) 4 to 12 m off, its pane within 50 degrees of the view, the room behind it not lit | a shadow (a black quad 0.5 × 1.4, alpha 0.8, soft edges) slides behind the blind across the pane in 0.8 s | none (the blind's rattle waits for the author, 14) | 1 |
| `lampara` | all | a lit room with two or more lamps within 15 m, a lamp in view | exactly one lamp fails for 1.2 s (`level.hotel.flicker_one(room_id, 1.2, rng.randi())`, 4.6) | `office/starter.wav` at that lamp | 1.5 |
| `palanca` | wing 1 | `power.red == DOWN` | a lever thrown at the board (no handle moves, no light changes) | `office/lever_N.wav` at `manifest.power.board.point` | 1.5 |
| `tictac` | wing 1 | `power.red == DOWN` (never while the real one runs or is armed); a corridor wall point 6 m or more from every `power.timers` button | 3 to 5 s of ticking from there, routed, never a follow cue | `office/tick.wav` | 1.5 |
| `ventiladores` | wing 2 | fans stopped (`air.spin == 0`) | the fans start (2.5 s rise, 1 s held, 1.5 s fade) from the plant; never touches `sound_mask` | `office/fans.wav` at `air.unit.point` | 1.5 |

`false_call(point)` (sanity's voice branch, only reached if `OWN_LIES` were false) plays `garras` over `point`. `walk_past()` starts a `ducto`.

### 4.4 What never lies (checked in 9.5)

The cue (its clips are in `NEVER`); the lights of a room trembling together (`lie()` never calls `drain()`; the `lampara` lie is one lamp); the interface, the sheet and the map (no captions, no UI); a station's bell with its lamp (`tube_bell.wav` in `NEVER`, no station lamp touched); the freight lift's tick (no follow cue, no tick while the red runs); the real fans (no `sound_mask`).

### 4.5 Her face where she is not (`phantom_sight.gd`, `lurker_poser.gd`)

- `phantom_sight.place(camera)`: `if lies.has_method("sight_spots"):` try `place_spot(spot, camera)` for each spot of `lies.sight_spots(self, camera)` in their order, and return; else the hotel's doors and corridor ends, unchanged.
- `sight_spots()` returns up to six spots, shuffled with `rng`, of three kinds (OFICINAS 5):
  - `"peek"`: the jamb of an open door 10 to 35 m off whose far room is not lit: on the far room's wall beside the jamb, 1.9 to 2.3 m up, facing the camera; pose `pose_peek()`.
  - `"partition"`: a cubicle `partition` (`room.furniture`, kind `"partition"`) 10 to 25 m off: over its top, head 0.25 m above it, body behind it; pose `pose_stare()`.
  - `"corner"`: a ceiling corner of a room 8 to 20 m off in view: hanging upside down (model `basis.y = Vector3.DOWN`), face 0.35 m under the ceiling; pose `pose_stare()`.
  Each `{kind, point, yaw, up}`. `place_spot()` puts the model there, poses it, and accepts it when `clear(eye, face)`, `lit(face, camera)` (the room it hangs in lit, or the torch on it) and, for `"peek"` and `"partition"`, `hidden_body(eye)`.
- `lurker_poser.gd`:
  ```gdscript
  extends RefCounted
  var model: Node3D; var skeleton: Skeleton3D; var animator: AnimationPlayer
  func _init(m: Node3D) -> void
  func point(bone: String) -> Vector3                       # skeleton.global_transform * get_bone_global_pose(find_bone(bone)).origin
  func pose_peek(lean: float, twitch: float, side: float) -> void   # clip "peek" held at lerpf(0.6, 1.6, lean / 0.6) s (+0.05 s on a twitch); side < 0 mirrors scale.x
  func pose_stare(twitch: float) -> void                   # clip "idle" held at 0.8 s (+0.05 s on a twitch)
  ```
  (`animator.play(clip); animator.seek(t, true); animator.pause()`.)
- `hotel_geometry.light_body(model)`: for meshes not on layer 1 use `ROOM_LAYERS.put_on_actor()`; if the body has `layer_meshes()`, only those (3g), so her phantom face is lit on Muy bajo like the real one.

### 4.6 One lamp failing (`office_geometry.flicker_one()`)

```gdscript
## A lie (lurker_hallucinations, "lampara"): one lamp of a lit room fails for `seconds`, on this machine
## only, as a failing troffer does (the flicker entry with share 1 / lamps): the room's light dips by
## that share at most, the other lamps' lenses do not change. False when the room has fewer than two.
func flicker_one(room_id: int, seconds: float, seed_value: int) -> bool
```

It adds a temporary entry to `flickers` (the H5 mechanism of 1d) with its own lens duplicate and removes it after `seconds`, restoring the lens. It never calls `drain()`.

---

## 5. Step 3d: her capture (`lurker_capture.gd`)

### 5.1 The score belongs to the style (pure refactor first, the hotel byte-identical)

- `locust_capture.gd` gains `func score(): return SCORE` (capture_score.gd).
- `executions.gd`: `func score(): return style().score()`; every `SCORE.` inside a function becomes `score().` (or a local `var beat = score()`): `stage_capture`, `apply_execution` (`HOLD_FAR`, `LIE_ROOM`), `scream`, `update_execution` (`ARM_TIME`, `KILL_TIME`, `DROP_TIME`, `FALL_LENGTH`, `END_TIME`), `place_victim` (`lift`, `limp`, `fall`, `turned`, `LIE_ROOM`), `move_camcorder`, `move_torch`. The file constants `ARM_TIME`, `KILL_TIME`, `SIGNAL_TIME`, `DROP_TIME` and `ARM_SWING` stay (the Locust's) but no function reads them.
- `death_tape.gd` and `blood.gd`: the same, through `level.executions.score()`. `avatar_visual.gd` keeps `capture_score.gd` (it only reads curves of a fall fraction, the same in both scores).
- `executions.gd` sounds: `style().kill_sound()` replaces `KILL_BLOW` (Locust: `KILL_BLOW`); `BODY_FALL` stays shared.
- `body_clip_probe.gd`: its `until` from `level.executions.score()`.
- Proof: `capture_test`, `creature_contract_test` and `body_clip_probe --strict` print the same lines before and after (keep both logs in the commit message's verification).

### 5.2 `lurker_score.gd`

Standalone (a script cannot override a parent's constants): every constant and static function of `capture_score.gd`, same names, so a parity check (9.6) can compare the two maps. Values (seconds from the grab):

| Name | Value | Meaning here |
|---|---|---|
| `ENTRIES` | `["back", "above"]` | from behind (the main one); from above in front of somebody who did not look up |
| `GRAB` (new) | 0.3 | the two hands close on the shoulders |
| `BACK_TURN_FROM`, `BACK_TURN_TO` | 0.35, 0.8 | the body turned round on her hands |
| `FACE_TIME`, `BACK_FACE_TIME` | 2.33, 2.33 | the face, upside down, until the camera is let go |
| `SCREAM_AFTER` | 0.05 | |
| `ARRIVE` | 0.25 | (above) the face comes down into the picture |
| `JERK_TIME`, `JERK_LENGTH` | 0.9, 0.06 | |
| `SWIPE_REACH`, `SWIPE_LENGTH` | 0.07, 0.2 | the camera is let go at 2.4 |
| `LIFT_FROM`, `LIFT_TO` | 1.6, 2.6 | she pulls up: the picture rises into the dark |
| `ARM_TIME`, `KILL_TIME` | 3.0, 3.15 | the bite, out of the picture |
| `DROP_TIME` | 3.6 | the body let fall |
| `FALL_LENGTH`, `FALL_AIR`, `FALL_SINK`, `FALL_BACK` | 0.9, 0.5, (0.5, 0.66), (0.62, 0.88) | as the hotel's |
| `GLANCE_FROM`, `GLANCE_COCK` | 4.4, 4.68 | she looks at the fallen camera from the ceiling |
| `CUT_TIME`, `END_TIME` | 5.4, 5.7 | |
| `HOLD_FAR`, `HOLD_NEAR` | (0.35, 0.55), 0.45 | how far from her the body is held (horizontally) |
| `LIFT_HEIGHT` | 1.0 | the most; each capture's own is `extra.lift` (5.3) |
| `HOLD_STAND` | 0.0 | |
| `LIE_ROOM`, `FLAT`, `SEAT_HEIGHT` | 1.4, 1.57, 0.13 | as the hotel's |

Functions as `capture_score.gd`'s, except `closing(time) -> 0.0` (never drawn in), `thrust(time)` = `ramp(time, ARM_TIME, KILL_TIME)`, `swipe(entry, time)` = `ramp(time, face_end(entry), face_end(entry) + SWIPE_LENGTH)` (the release), `face_start("above") = 0.0`, and the new `static func grab(time: float) -> float: return smooth(ramp(time, 0.0, GRAB))`. `lurker.capture_length()` returns `CUT_TIME` (5.4).

### 5.3 What the host decides (`stage_extra`, the payload)

- `executions.stage_capture()`: after building `data`, `var extra: Dictionary = style().stage_extra(body, placed)`; `if not extra.is_empty(): data["extra"] = extra`. `apply_execution()`: `if data.has("extra"): execution["extra"] = data.extra`. The Locust's `stage_extra()` returns `{}`: its payload and its `execution` are unchanged.
- The Lurker's `extra`:
  ```text
  {"hang": Vector3,     # where she hangs: on the ceiling over the shoulder line, 0.45 m behind the victim (back) or in front (above)
   "ceiling": float,    # the ceiling's y there (a ray up from the head, mask 1 | 8, up to 2.6 m), or head + 2.6 with none
   "lift": float,       # clampf(free above the head - 0.12, 0.0, LIFT_HEIGHT): under a 2.65 m lintel about 0.7, under 2.95 about 1.0
   "tile": [i, j]}      # the lattice tile over the hang (OFFICE.tile_of) for the swinging tile; [] without a false ceiling
  ```
  `free above the head` is the least of five rays straight up (mask 1 | 8, excluding her and the victim) from the head top (`body.global_position.y + 1.85`) at the head and ±0.2 m along both axes.

### 5.4 `lurker_capture.gd` (extends `locust_capture.gd`)

Inherited unchanged: `fall_room`, `clear_along`, `fall_way`, `fall_dir`, `body_rest`, `head_rest`, `head_away`, `torch_rest`. Overridden:

```gdscript
const LURKER_SCORE := preload("res://game/app/capture_styles/lurker_score.gd")
const BITES := ["res://assets/audio/sfx/lurker/bite_1.wav", "res://assets/audio/sfx/lurker/bite_2.wav"]
const SWING_TILE := true
func score(): return LURKER_SCORE
func kill_sound(seed_value: int) -> String: return BITES[seed_value % BITES.size()]
func approach(body: Node3D) -> Dictionary        # does not move her; {away, yaw, far, feet}: yaw from the hang to the victim on the level, feet = the victim's feet
func stage_extra(body: Node3D, placed: Dictionary) -> Dictionary   # 5.3
func choose_entry(body: Node3D, away: Vector3, rng: RandomNumberGenerator) -> Array
func creature_point(execution: Dictionary) -> Vector3   # eased from execution.point (where she was at the grab) to extra.hang over 0.25 s
func creature_forward(execution: Dictionary) -> Vector3 # -Basis(UP, yaw).z, as the Locust's
func victim_hold_point(execution: Dictionary) -> Vector3  # execution.from (the feet) + UP * lift(t) * extra.lift
func lens_point(execution: Dictionary) -> Vector3     # the hold point + UP * (0.9 crouched else 1.64)
func mask_from(execution: Dictionary) -> Vector3      # from the lens to her face: up and towards the hang
func drop_point(execution: Dictionary) -> Vector3     # execution.from
func staging(execution: Dictionary) -> Dictionary     # super() + {"look_up": true, "ceiling": extra.hang}
func tape_framing() -> Dictionary                     # 5.6
func tape_pose(execution: Dictionary, time: float, framed: Transform3D) -> Transform3D   # 5.6
func posable() -> bool                                # her visual exists
func pose(execution: Dictionary) -> void              # 5.5
func unpose() -> void
func mask_transform() -> Variant                      # her face as a frame: origin the face point, +Z to the lens, +Y the top of her head (world down while she hangs)
func blood_held(scene: Dictionary, time: float) -> Vector3   # 5.8
func blood_chest(scene: Dictionary, time: float) -> Vector3
func blood_face(scene: Dictionary, time: float) -> Vector3
func spill(scene: Dictionary, rng: RandomNumberGenerator, drops: Array, sparing: bool, blood) -> void
func blood_sounds(scene: Dictionary, rng: RandomNumberGenerator, sparing: bool, blood) -> Array
```

- `choose_entry()`: one `rng.randf()` (the side), always, as the Locust. `"above"` when she is in front of the victim's view within 70 degrees (her flattened direction from the victim's eyes) and the victim's camera pitch is under 30 degrees up (did not look up); `"back"` otherwise. Hidden victims never reach here (she never takes anybody out of a locker).
- Her capture lasts `CUT_TIME` and `executions.update_execution()` ends it at `capture_length() + 0.3` (5.7 s) as it does for the Locust.

### 5.5 Her body in the scene (`pose()`, the grips, the face upside down)

Every frame of the scene (`executions.update_execution()` calls `staged.pose(execution)`):

- `creature.global_transform = Transform3D(Basis(x, Vector3.DOWN, z), point)` with `point = creature_point(execution)` lowered by `0.25 * grab(t) * (1 - lift(t))` (she drops a little to take them, and goes back up with them), `z` = the victim's direction flattened (`creature_forward`), `x = Vector3.DOWN.cross(z)`. Clip: `"loom"` during the face, `"scare"` never, `"idle"` after the drop.
- `visual.look_point = lens_point(execution)`; `visual.limbs.upright = 0.0` while the scene lasts (`lurker_limbs.gd` gains `var upright := 1.0`, the share of `UPRIGHT` applied in `_look()`; 1.0 is today's): the face stays upside down.
- **Grips** (`lurker_limbs.gd`): `var grips := {}`, limb name -> `{"point": Vector3, "normal": Vector3}`; a limb in `grips` takes that point as its hold every frame (planted, not swinging, no probe), else as today. `pose()` sets `grips = {"a.L": shoulder left, "a.R": shoulder right}` from `avatar.bone_point(avatar.bones.la)` and `.ra` of the victim's body (the avatar's upper-arm joints, the keys `body_clip_probe` uses), normal from her to the shoulder, while `grab(t) > 0` and `t < DROP_TIME`; cleared after. `unpose()` clears grips and sets `upright = 1.0`.
- **The swinging tile** (`SWING_TILE`, `extra.tile` not empty): at `t >= 0.2`, once, a `MeshInstance3D` named `"SwingingTile"` (a 0.6 × 0.015 × 0.6 box in `level.hotel.materials.ceiling_service`, no collider) hinged on the edge of `extra.tile` farthest from the victim, at the ceiling; angle `0.2 + 0.45 * exp(-0.4 * s) * cos(2.2 * s)` rad with `s` its seconds; added to `executions.leavings` (it stays the stage) and `level.hotel.adopt()`ed. The batched tile above it stays: the angle never closes under 0.15 rad, and the gap reads as dark.
- The avatar of the victim: `place_victim()` passes `"hang": true` into `avatar.pose_capture(state)` when the style has `HANG := true` (constant on `lurker_capture.gd`). `avatar_visual.pose_capture()`: with `hang`, `over = Basis.IDENTITY` (not bent over an arm) and both upper arms raised 25 degrees about their side axis while `lift > 0` and `fall == 0`. Without the key: unchanged.

### 5.6 The tape (`death_tape.gd`)

- **Framing.** `facing()` reads `var framing: Dictionary = style.tape_framing() if style.has_method("tape_framing") else {}` and takes each distance with the file constant as default: `far` (`MASK_FAR`), `held`, `close`, `near`, `lunge` (`0.0` disables the lunge: `coming = 0`), `back_dip` (`BACK_DIP`, used in `turning()`). The Lurker's: `{"far": 0.6, "held": 0.34, "close": 0.3, "near": 0.24, "lunge": 0.0, "back_dip": -0.12}` (her face is 0.36 m tall in the game: at 0.34 m it fills about nine tenths of the picture; "a un palmo"). The up vector stays `Vector3.UP` (she hangs head down, so her face is upside down in the picture; the code's `absf(ahead.normalized().y) > 0.85` branch is untouched).
- **Rising.** After computing its transform `facing()` returns `style.tape_pose(execution, time, transform)` when the style has it. The Lurker's: with `k = score().lift(time)`, origin raised by `k * extra.lift * 0.9`, basis tilted up about its own x by `0.35 * k` rad: the picture rises into the dark of the ceiling.
- **The fall.** `plan()` copies `stage.get("look_up", false)` and `stage.get("ceiling", Vector3.INF)` into the scene for `camera_fall.solve()` (5.7). `fly_at()` = `face_end + SWIPE_REACH` = 2.4 from her score.
- `is_dark()` asks `level.hotel.lit()` (0e) for the room at `execution.from`.

### 5.7 The camera falls looking up (`camera_fall.gd`)

- `enum { VIEW, PARTIAL, DOWN, UP }`, `NAMES` gains `"mira arriba"`. Constants: `UP_PITCH := Vector2(55.0, 84.0)`, `UP_ROLL := 18.0`, `UP_REACH := 1.2`.
- `solve()`: with `scene.get("look_up", false)`, every candidate spot is framed by `frame_up()` instead of `frame()`, and the fallback is `face_up()` instead of `face_down()`. Without the key: unchanged (same rays, same draws).
- `frame_up(space, scene, spot, side, rng, exclude) -> Dictionary`: `eye = ground + Vector3.UP * 0.05`; aim at `scene.ceiling`; `pitch = clamp(atan2(dy, flat), UP_PITCH)`; `roll = side * rng.randf_range(4.0, UP_ROLL)` degrees; `rest = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0)) * Basis(Vector3.BACK, roll), eye + up * 0.06)`. Score: `+3` sees the ceiling point; `+2.5` the body's fall line (from `hold` to `body` at 0.3 m up) wholly outside `VIEW_HALF * 1.1` of the lens's forward, `-2` otherwise ("el golpe del cuerpo fuera de cuadro"); `+1.5` sees `hold + up * (1.2 + lift)` (the body held up, briefly, before the drop); `+2.4 * (1 - |flat reach - UP_REACH| / UP_REACH)`; the torch's beam towards the ceiling `+1.2`; `+ rng.randf() * 0.3`. Kind `VIEW` when it sees the ceiling and the held body, `PARTIAL` with the ceiling only.
- `face_up()`: at the owner's feet, lens up (`pitch` drawn in `UP_PITCH`), kind `UP`.
- `route()` and `pose()` are unchanged: the fall is the same physics to a different rest.

### 5.8 Blood (`blood.gd`)

- `snapshot()` adds `"style": staged`, `"feet": staged.drop_point(execution)`, `"extra": execution.get("extra", {})`.
- `held_at()`, `chest_at()`, `face_at()`: when `scene.style.has_method("blood_held")` (`"blood_chest"`, `"blood_face"`) return the style's; else today's formulas. `spill()` and `sounds()`: the style's `spill(scene, rng, drops, sparing, self)` / `blood_sounds(...)` when it has them (it calls back `blood.drop()` and `blood.scattered()`); `pool()` uses `scene.feet` (for the Locust `point + forward * HOLD_NEAR`, the same value).
- The Lurker's: no wound at the grab ("causa sí, impacto no"); at `KILL_TIME` a spray of 40 drops from the face held up (`blood_face`: the hold point + up * (1.58 + lift)), half upwards to the ceiling (speed 2 to 6 m/s) and half down to the floor round the feet; four pulses after the drop from the chest on the floor; sounds: the hotel's `SPRAY` at `KILL_TIME + 0.02` and `GUSHES` after the drop (no gush at the grab). With `sparing`, the spray only.

### 5.9 Who she catches, and the pairing

- Captures only come from the brain's cue (phase 2): `lurker.capture_log` gets `{cue_id, seat, cue_at, caught_at, window, forced}`; `forced` is true when `executions.forced` was not empty (tests and the clip probe), so the bots' watchdog and 9.2 do not count those.
- `begin_capture(data)`: brain `capture` state, her shell motion stops, visual crawling on (grips work). `end_capture()` (let go alive): brain `scared` with `how = &"light"`. Played to its end she goes by the nearest exit into the ducts (`roam`).

---

## 6. Step 3e: the observer and the data formats phase 4 inherits

### 6.1 Gizmos (`draw_gizmos(g)`, layer 7)

- `observer_gizmos.gd`: `COLOURS` gains `"shell": Color(0.75, 0.55, 1.0)`, `"duct": Color(0.5, 0.5, 0.55)`, `"duct_path": Color(1.0, 0.8, 0.3)`, `"exit": Color(0.6, 0.8, 1.0)`, `"closed": Color(1.0, 0.3, 0.3)`, `"cue": Color(1.0, 0.2, 0.15)`, `"drain": Color(1.0, 1.0, 0.6)`; `shown["ducts"] = true`; `_process()` calls `draw_ducts()` (`layer = &"ducts"; creature.draw_gizmos(self)`) when `shown.ducts`. `observer_view.gd`: the layer keys go to `KEY_7` with `"ducts"` seventh; the header comment lists `7 los ductos`.
- `lurker.draw_gizmos(g)`, only where `g.here()`:
  - `&"path"`: the outline of her current patch (`shell.outline(patch)`) in `shell`; a 0.5 m tick along her surface normal; her way ahead (`routes.path_points()`, or `ducts.path_points()` in a duct) in `path`; the director's lead ring (`lead`); in `cue`, a line from her face to the victim's head and a ring round the victim of radius `0.3 + 1.2 * left / window`; each drained room a ring at its centre of radius 0.5, alpha the amount, in `drain`.
  - `&"sight"`: her dark sight (20 m) as two cone edges from her eye, and a line to her quarry while she sees them.
  - `&"ducts"`: every duct edge on the viewed planta in `duct` (main and cross edges thicker: drawn twice 3 cm apart), every exit as a mark in `exit` (`closed` while the wing is closed), her duct path in `duct_path`, her duct position as a ring.
- `debug_lines()`: `["LURKER (ai)", "  acecha, gracia 0.0, 12, -40", "  ducto 213 a 0.40, sala 117", "  presa P2 a 7.1 m, aviso 0.6 de 1.5 s", "  bebe 117 (0.62), 118 (0.41)"]` (Spanish state words: `ronda, escucha, acecha, se asoma, quieta, se acerca, avisa, coge, se espanta, encima`). `debug_state()` adds `"estado"`, `"medio"`, `"presa"`, `"aviso"`.

### 6.2 `pack_state()` / `push_state()` (sent about 15 times a second, `match_net.gd:272`)

```text
[0 position: Vector3,
 1 orientation: Quaternion (global_basis),
 2 velocity: Vector3,
 3 state: int (index in STATES),
 4 grace: float,
 5 look: Vector3 (visual.look_point, INF for the camera),
 6 flags: int,
 7 duct: Vector2 (edge, along), Vector2(-1, 0) out of the ducts,
 8 quarry seat: int (-1 nobody)]
flags: 1 IN_DUCT, 2 HIDDEN (duct or plenum), 4 and 8 SURFACE (0 floor, 1 wall, 2 ceiling, 3 channel; << 2),
       16 DRAINING, 32 CUEING, 64 SCARED
```

`push_state(data)`: `if data.size() < 9: return`; stores the state, and in phase 3 snaps to it (transform, state, duct placement); phase 4 adds the smoothing. The Locust's 6-element array is unchanged; `match_net` only forwards arrays.

### 6.3 Reliable events (`match_net.gd`, the contract's `on_event()`)

```gdscript
## A moment of the creature every machine must hear of (docs/OFICINAS.md 11.6), told reliably by
## whoever drives it and applied by creature.on_event() on the others.
func creature_event(kind: String, data: Array) -> void:
	if in_match(): to_everyone(&"creature_event_rpc", [kind, data])

@rpc("any_peer", "call_remote", "reliable")
func creature_event_rpc(kind: String, data: Array) -> void   # the authority checks and relay of locust_call (lines 694 to 700); a puppet applies on_event(kind, data)
```

`creature.gd`: `func on_event(_kind: String, _data: Array) -> void: pass`. The kinds and their payloads (fixed now; phase 3 uses them offline, where the driving machine applies them itself and nothing is sent):

| Kind | Data | Applied |
|---|---|---|
| `"cue"` | `[cue_id: int, seat: int, window: float, face: Vector3]` | `voice.cue()` (3.7) |
| `"cue_end"` | `[cue_id: int, outcome: String]` (`"caught"`, `"scared"`, `"cancel"`) | the gizmo and the tally |
| `"scare"` | `[by_seat: int, how: String, at: Vector3]` | `voice.shriek()` |
| `"duct_in"`, `"duct_out"` | `[exit: int]` (index in `ducts.exits`) | `voice.tile_shift()` for ceiling exits and gaps |
| `"room_off"` | `[room_id: int, seconds: float]` | versus (phase 4): her drinking a room dark |

Phase 4 adds the guest's claim `creature_claim(kind: String, cue_id: int)` ("la estaba mirando"); its name is reserved here. **PROTOCOL**: a new RPC changes the method table: bump `net_session.PROTOCOL` to `"the-four-net-21"` unless 0c or 1e already bumped it in this unreleased stretch (never twice before a release). The four hotel net scenarios stay green.

### 6.4 Bot recordings

If 0a5 left `bot_recorder.gd` reading Locust members (lines 172 to 218), move them into the contract: `func record_fields() -> PackedStringArray` and `func record_row() -> Array` (Locust: exactly today's `CREATURE_FIELDS` and row; the recorder writes `creature.record_fields()` into the header). The Lurker's fields: `["x", "y", "z", "qx", "qy", "qz", "qw", "state", "quarry", "medium", "duct_edge", "duct_along", "drain", "cue_left"]`. `bot_replay` of a floor-2 recording places her by `x, y, z` and the quaternion; its full puppet is phase 4.

---

## 7. Step 3f: the bots and the balance batch

### 7.1 `tools/bots/bot_threat_lurker.gd`

Registered in `tools/bots/bot_threats.gd` (0a5's factory) under `&"lurker"`. It has every member `bot_brain.gd` reads of a threat (`threat.` uses: `active`, `novice`, `creature`, `position`, `mode`, `hostile`, `busy`, `lost_time`, `last_known`, `destination`, `landing`, `danger`, `room`, `refresh()`, `near_planta()`, `hunted()`, `torch_catches()`, `visible()`, `watched()`, `time_to_sight()`, `arrival()`, `audible()`, `deaf_to()`, `route_to()`, `searched_near()`, `room_cost()`, `lose_after()`), with her meaning, plus `mind()` and `wants_torch()`:

```gdscript
extends RefCounted
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const DARK_SIGHT := 20.0                  # she sees whoever is in the dark this far (OFICINAS 4)
const REACT := {"experto": 0.35, "novato": 0.9}   # seconds from the cue to the turn
const REACT_JITTER := 0.15
const TURN_CHANCE := {"experto": 1.0, "novato": 0.7}
const MATE_REACH := 8.0                   # a teammate this near, seeing her, turns its torch on her
const COVER_REACH := 15.0                 # a worker this near gets a guard
const COVER_BEHIND := 2.5                 # the guard stands this far behind the worker's back, facing the room
const COVER_MOST := 20.0                  # seconds a guard stays
const GLANCE_EVERY := Vector2(3.0, 7.0)   # the last of a moving team looks back this often
const GLANCE_FOR := 1.0
var level; var creature; var active := false; var novice := false
var position := Vector3.ZERO; var eye := Vector3.ZERO; var forward := Vector3.FORWARD
var mode := -1                            # never a Locust mode: the brain's Locust branches never match
var planta := -1; var room := -1
var hostile := false; var busy := false
var lost_time := 0.0; var last_known := Vector3.ZERO; var destination := Vector3.ZERO
var landing := Vector3.INF                # she never comes out of a lift
var danger := {}; var search_points: Array = []; var future: Array = []; var vantages: Array = []
var state := &""; var medium := &""; var quarry_seat := -1
var cue_seat := -1; var cue_left := 0.0; var face := Vector3.INF
var guards := {}                          # worker seat -> guard seat
func _init(owner_level) -> void
func refresh() -> void
func mind(brain, delta: float) -> Variant  # null: not its business this frame; bool: took the frame
func wants_torch(body) -> bool
```

- `refresh()` (a few times a second, as today): reads her through the contract and `lurker.brain` (state, quarry, cue seat and time left, face point, medium); `hostile` in stalk, approach, cue; `busy` in capture; `danger` adds `COST_PATH` (60) to the rooms of her way ahead and `INF` to hers; `future` from `routes.path_points()` at her speed (duct speed in ducts).
- `hunted(body)`: she is in stalk, approach or cue with that body as quarry. `torch_catches()`: false (her torch is what saves). `exposed()`/`visible()`/`watched()`: the body's room not lit (`hotel.lit()`), within `DARK_SIGHT` of her eye, nothing between (mask 1 | 8 | 64). `audible()`: `creature.hear_route(point, radius).audible` (masked by the fans). `route_to()`: her `travel_metres()` between the rooms. `deaf_to()`: `busy`. `searched_near()`: false. `lose_after()`: 5.0.
- `mind(brain, delta)`, in this order:
  1. **Cue on this bot**: on the first frame of a cue whose seat is this bot's, draw `delay = REACT[skill] + rng.randf_range(-REACT_JITTER, REACT_JITTER)` and whether it turns (`TURN_CHANCE`); after `delay`, `brain.halt()`, `brain.face(face)`, `body.torch_wanted = true`; hold it until the cue ends. True.
  2. **Cue on a teammate**: this bot within `MATE_REACH` of her with a clear line to her face turns and lights her after its own delay. True while it does.
  3. **Cover** (co-op): a teammate whose task kind is `"use"` (an office usable: typing, a tray, a lever, the console, the hatch) within `COVER_REACH`, with no guard yet: the nearest idle or walking bot becomes its guard: it goes to `worker stand - facing(worker yaw) * COVER_BEHIND` (the room side), faces away from the worker, torch on where not lit, until the worker's task ends or `COVER_MOST` s. True while guarding. The bot note `"cubre"` with both seats.
  4. **Looking back**: in a moving team of two or more on a planta, in a room not lit, the bot with the longest way to the team's goal looks back (`body.look_yaw += PI`) for `GLANCE_FOR` every `GLANCE_EVERY`; in the main duct it is the last crawler (the turn is slow there, `CRAWL_TURN_RATE`). Returns null (the walking goes on).
  5. Otherwise null: the brain's own flow (run from a hunt, go round where it is going).
- `wants_torch(body)`: false hidden; true where `hotel.lit()` is false at the body, while crawling, while the cue is on it, or (expert) when she is within 15 m.

### 7.2 `bot_brain.gd` hooks (no-ops with the Locust's threat, which has neither method)

- `mind_creature()` (line 702): right after the hidden branch, `if threat.has_method("mind"): var took = threat.mind(self, delta); if took != null: return bool(took)`.
- `wants_torch()` (line 1184): first, `if owner_match.threat != null and owner_match.threat.has_method("wants_torch"): return owner_match.threat.wants_torch(body)`. Its dark test reads `hotel.lit()` (0e).
- Lockers: unchanged (hiding is allowed; she waits on top).

### 7.3 Watchdog and tally

- `creature.gd`: `func tally() -> Dictionary: return {}`. The Lurker's: `{"cues", "saves" (cue_end scared), "captures" (from a cue), "forced", "scares", "scares_torch", "scares_turn", "scares_mate", "peeks", "duct_trips", "unpaired" (captures with no cue and not forced)}`, counted from her own signals.
- `bot_watchdog.gd`: for a creature with a `capture_log`, each new entry with `cue_id < 0` and not `forced` is a grave incident `"captura_sin_aviso"` with seat and place; a cue that has not ended within `window + 2 s` is a medium incident `"aviso_colgado"`.
- `bot_match.finish()`: `summary["creature"] = creature.tally()` and `summary["creature_kind"]`.
- `tools/bots.ps1`: `[ValidateSet(1,2)][int]$Floor = 1` passed as `--floor=$Floor` (`bot_run.gd` forwards it to `level.set_floor()` before `begin()`); rows gain `cues`, `saves`, `scares`, `unpaired`; the summary line for floor 2: `Aviso: {0:N1} avisos y {1:N1} espantos por piso; {2:P0} de los avisos acaban sin captura; capturas sin aviso: {3}`.

### 7.4 `bots_test --floor=2`: the Lurker part

After phase 1's `office_part()` (null creature, no threat), a `lurker_part()` on a floor built again with the Lurker (seed 81, two expert bots, desafiante, `knowledge "oracle"`), staged:

1. Bot A sent to type at the window (`mail.desk`, a `"use"` task); bot B idle 8 m away. Within 10 s B's task note is `"cubre"`, B stands within 1 m of the guard point and faces within 30 degrees of away from A.
2. The Lurker forced to `stalk` A (`force_state(&"stalk", A.seat)`) from the dark ceiling 6 m behind A, B parked out of reach: a cue starts on A within 30 s; A's camera faces her within `REACT.experto + 0.4 s` of the cue with its torch on; the cue ends `scared`; no capture.
3. A novice with its reaction forced to 3.0 s (beyond any window): the capture happens, and its log entry has `cue_id >= 0`; the watchdog reports no `captura_sin_aviso`.

### 7.5 The balance batch (OFICINAS 15: "un lote de equilibrio con bots")

Run after 3f, again after 3g, and compared batch to batch in `docs/DIFFICULTY.md` (a "Piso 2" table: one column per batch):

```
./tools/bots.ps1 -Floor 2 -Bots 3 -Seeds 81..100 -Difficulty <d> -Skill experto -Parallel 4 -Label f2_<d>_exp
./tools/bots.ps1 -Floor 2 -Bots 3 -Seeds 81..100 -Difficulty <d> -Skill novato  -Parallel 4 -Label f2_<d>_nov
./tools/bots.ps1 -Floor 2 -Bots 1 -Seeds 81..100 -Difficulty <d> -Skill experto -Parallel 4 -Label f2_<d>_solo
```

for each of the four difficulties (12 batches of 20 floors). Starting bands, to be replaced by the first batch's numbers; a band missed is a finding to discuss with the author, not a test failure, except the first row, which is a hard rule:

| Measure (per floor) | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| captures without a cue (`unpaired`) | 0 | 0 | 0 | 0 |
| expert team won | ≥ 85 % | ≥ 70 % | ≥ 50 % | ≥ 30 % |
| expert team deaths | ≤ 0.5 | ≤ 1.0 | ≤ 1.8 | ≤ 2.5 |
| expert saves / cues | ≥ 0.8 | ≥ 0.65 | ≥ 0.5 | ≥ 0.35 |
| novice saves / cues | ≥ 0.6 | ≥ 0.45 | ≥ 0.3 | ≥ 0.15 |
| cues per bot | 1 to 6 | 1.5 to 8 | 2 to 10 | 2 to 12 |
| scares per floor | ≥ 3 | ≥ 3 | ≥ 2 | ≥ 2 |

---

## 8. Step 3g: performance (OFICINAS 11.8 and 13)

### 8.1 Measure first

`tools/benchmarks/hotel_benchmark.gd --lurker`: in the lit corridor `tools/capture/lurker_capture.gd` `pick()` chooses on seed 81 (move `pick()` to a static `tools/capture/lurker_spot.gd` both use), four still views of `STILL_FRAMES` each per quality: `lurker_none` (the same camera, no Lurker) and `lurker_1.5`, `lurker_4`, `lurker_10` (an instance of `lurker.tscn` on the corridor floor at that distance in front of the camera, crawling, moving ±0.5 m along the corridor at 1 m/s so its hands step). The report adds, per view, the frame's GPU and CPU means and p95 and `lurker_limbs.cost_usec` per frame (`static var cost_usec := 0`, the time spent in `_process_modification_with_delta`, reset by the bench). Run it before any change (baseline into `docs/PERFORMANCE.md`), after 8.2 and after 8.3.

Targets at 1080p on the author's machine (Forward+), as deltas over `lurker_none`:

| Quality | 1.5 m | 4 m | 10 m | limbs < 8 m | limbs 8 to 18 m |
|---|---|---|---|---|---|
| Alto | ≤ 1.2 ms GPU | ≤ 0.6 ms | ≤ 0.3 ms | ≤ 0.15 ms CPU | ≤ 0.05 ms |
| Muy bajo | ≤ 0.8 ms | ≤ 0.4 ms | ≤ 0.2 ms | ≤ 0.1 ms | ≤ 0.05 ms |

Missed after 8.2 and 8.3: the fallbacks, in this order, are one step less per quality, no vapour from Medio down, and `rays = 1` under 8 m from Medio down. Also run it with `--rendering-method gl_compatibility` once.

### 8.2 The ink (`lurker_darkness.gdshader`, `bake_ink_noise.gd`)

- `tools/art/lurker/bake_ink_noise.gd` (`extends SceneTree`): a 64³ `Image.FORMAT_R8` stack: value noise on a lattice of period 16 (lattice values from the shader's old `hash()` at `i mod 16`, so it tiles), four texels per cell, smoothstep interpolated as the old `noise()`; saved with `ResourceSaver` as `ImageTexture3D` to `assets/enemies/lurker/ink_noise.res`. Deterministic; run once and commit.
- Shader: `uniform sampler3D ink_noise : filter_linear, repeat_enable;`, `uniform int steps = 10;`; `noise(x)` becomes `texture(ink_noise, x * (1.0 / 16.0)).r` (five reads a step instead of five value noises of eight hashes); `hash()` goes. The loop: `for (int i = 0; i < 10; i++) { if (i >= steps) break; ...; if (sum * density > 3.912) break; }` (alpha 0.98 is `1 - exp(-3.912)`).
- `lurker_visual.gd`:
  ```gdscript
  const PRESETS := preload("res://game/presentation/graphics_presets.gd")
  const INK_NOISE := preload("res://assets/enemies/lurker/ink_noise.res")
  const STEPS := {3: 10, 2: 8, 1: 6, 0: 5, 4: 4}    # ULTRA, HIGH, MEDIUM, LOW, VERY_LOW
  const NO_VAPOUR := [0, 4]                          # LOW, VERY_LOW
  const FAR := 15.0                                  # beyond: one layer, 4 steps
  const FAR_STEPS := 4
  const HANDS_NEAR := 8.0                            # full hands
  const HANDS_FAR := 18.0                            # beyond, or off screen: no rays
  var quality := 2
  var hidden_why := ""
  var on_screen: VisibleOnScreenNotifier3D           # aabb (-2.5, -1.5, -2.5) size (5, 4, 5), times size
  func set_quality(q: int) -> void
  func set_hidden(why: String) -> void               # "duct", "planta" or "": hides the model, the ink and the vapour; hands off
  func layer_meshes() -> Array                       # the model's MeshInstance3D (face, body, eyes, teeth surfaces), never the fog
  func lod(camera: Camera3D) -> void                 # every _process: steps, vapour, limbs.rays
  ```
  `fog()` sets `ink_noise` on both materials. `lod()`: distance `d` to the camera; `steps = FAR_STEPS if d > FAR else STEPS[quality]`; vapour visible only when `quality not in NO_VAPOUR and d <= FAR`; `limbs.rays = 0` off screen or `d > HANDS_FAR`, `1` for `d > HANDS_NEAR`, else `2`, and at most `1` on Bajo and Muy bajo.
- `lurker.gd`: `apply_quality()` (contract, 0a5) calls `visual.set_quality(level.settings.values.quality)`, also once in `_ready()`; every `_process`, `visual.set_hidden("duct" if shell.medium() == &"duct" else "planta" if FLOOR.planta_of(camera.y) != FLOOR.planta_of(global_position.y) else "")`.

### 8.3 The hands (`lurker_limbs.gd`)

- `var rays := 2`. In `_process_modification_with_delta()`: the round-robin probes per frame are `rays` (2, 1 or 0); an unplanted hand probes with rays only when `rays > 0`; with `rays == 0` it probes the analytic planes (`_probe_planes()`, below) and costs no ray. `_clear_elbow()`: every frame with `rays == 2`, every other frame with `rays == 1` (the other frame keeps `elbow_turn`), never with `rays == 0`.
- `var planes: Array = []` of `{"point": Vector3, "normal": Vector3}`, set by `lurker.gd` every 0.25 s from the shell (`shell.planes_near(global_position)`: the floor, the ceiling, the walls of her room and the walls of a channel; if the shell has no such function, from `FLOOR.room_at()`, `palette.height_of()`, `ROOM_LAYERS.rect_of()` less `WALL_HALF`, and the archive rows). `_probe_planes(limb, ...)`: the same eleven directions as `_probe()`, intersected with the planes instead of the world, the same scoring.
- `signal footfall(point: Vector3, strength: float, normal: Vector3)` with `limb.to_n`; `lurker_visual` passes the three on.
- `static var cost_usec := 0` (8.1).

### 8.4 Her face on Muy bajo

- `hotel_geometry.follow_bodies()` (0e uses `put_on_actor()` for actor meshes not on layer 1): `var meshes: Array = body.layer_meshes() if body.has_method("layer_meshes") else body.find_children("*", "GeometryInstance3D", true, false)`. `lurker.gd`: `func layer_meshes() -> Array: return visual.layer_meshes()`. Her model then carries the room's bit beside value 4, and on `static_light` the room's lamp lights her face, eyes and teeth; the ink (unshaded) keeps value 4 alone. `light_body()` likewise (4.5).
- Checked in 9.1 case M and in the capture `tools/capture/lurker_capture.gd --preset=4` (add the option: `level.settings.set_designed(int)` before the shots) beside the same shot on Alto: her face reads in both.

---

## 9. Tests

Every test: `extends SceneTree`, `check(title, passed)` as `hotel_test.gd`, evidence JSON in `res://evidence/<name>.json`, exit code 1 on any failure. Floor 2 tests build with `level.set_floor(2)` then `await level.start_floor(81, false, [1], "desafiante")` unless said, `level.ui.finish_intro()`, director freed (`level.director.queue_free()`) unless the case needs it. Rooms are found from the manifest by palette ids, the first by ascending id that qualifies, so every run picks the same ones. "Frozen" means `creature.set_physics_process(false)` and placed with `teleport()`/`force_state()`.

### 9.1 `tests/office/office_survival_test.gd`

| Case | Setup | Checks |
|---|---|---|
| A spawn | as built | `creature.kind_id() == &"lurker"`, its scene path `== office_floor.CREATURE`; `grace == tuning().grace`; `shell.medium() == &"duct"`; her room is not off-limits and is 3 hops or more from the freight lobby; `world_audio.profile` is `lurker.tres`; `world_audio` has the `Ducts` bus sending to `Creature`; `--null-creature` (second build) gives the null creature |
| B tuning | `set_difficulty` to each of the four | the brain's window, `lit_capture`, `duct_speed`, `stalk_distance`, `still_time`, `scare_calm`, `approach_scale`, `drain.reach`, `peek_rate` are 0.4's; the director's `encounter_every`, `cross_weight`, `raps_weight` are 0.4's; `director.raps(target)` returns false |
| C off-limits | her led towards the freight lobby (`lead_to(lobby centre, 4, 20, "merodea")`), physics on 20 s | `lead_to` returned false or `FLOOR.room_at(her)` is never an off-limits room (sampled every 0.25 s); never a duct node of an off-limits room |
| D drain | frozen 1.5 m under a troffer of the first lit wing-0 open office (type 1) | within 0.5 s `hotel.drain_of(room)` in [0.4, 0.7] and `hotel.lit(room)` false at ≥ 0.5; a lit room 6 m or more away has 0; moved 10 m away, back to 0 within 1.0 s and `lit()` true again; a hum player assigned to that room had `pitch_scale < 1.0` while drained |
| E herding | wing 1: a corridor cell of circuit 0, frozen on its ceiling, then physics on; `power.apply("lever", 0, 1, {}, false)` | within 4 s she is in a duct or in a room not lit; an event `"duct_in"` was applied; a tile shift was heard (`voice.last.path` contains `tile_creak_`) when the exit was a ceiling one |
| F fans | wing 2, in a duct of the planta; `air.fan_time = 5.0`, `air.apply("start", 0, 1, {}, false)` | after the spin-up `ducts.closed` is true for wing 2 and within 1.5 s she is out by the exit nearest by duct metres (± one exit); while closed she never re-enters; after the stop she is back in a duct within 10 s |
| G main duct | wing 2, the hatch opened (1g's case setup), the player crawling 2 m before the crossing, her stalking from the plant | she does not take the `cross` edge while the player is before the crossing; once the player is 2 m past it she may (allowed flag true) |
| H crawl window | the same, a cue forced on the crawler | the window equals `cue_window + CRAWL_CUE_EXTRA` (2.6 s at desafiante) |
| I plantas | the stage crossed to 2 by the real flow (`stages_test.cross_to_stage` pattern) | `in_transit()` true after the car leaves; while the player rides, at least two `outside_car` sounds (`voice.last` history); after the transit she is on wing 1, in a duct, 3 hops or more from the arrival lobby |
| J given back | a stage given back (`revival`) | she is at `den_point(stage)` ± 0.05, quarry null, every calm forgotten, grace ≥ the revival's rest |
| K locker | the player hidden in the first wing-0 locker, her forced to stalk the player | within 20 s `brain.state == &"above"` on that locker; `player.sanity` falls as in a wardrobe; after 30 s the locker was never opened by her; when she leaves, a knock is heard |
| L safe places | the player in the freight lobby (19), then in the car | 30 s of forced stalk each: no cue, no capture |
| M face on Muy bajo | quality 4 (`settings.set_designed(4)`), her frozen in a lit room | after 3 frames her model meshes have value 4 and the room's bit (`ROOM_LAYERS.ROOMS & layers != 0`); the ink and vapour have `layers == 4` exactly |
| N ink and hands | the camera 20 m away; then 5 m; then her in a duct; then the camera on another planta | far: vapour hidden, `steps == 4`, `limbs.rays == 0`; 5 m: `rays == 2` on Alto, 1 on Bajo; duct and other planta: `visual.visible == false` |
| O continue | her in a duct at edge e, along 0.4; `floor_save.take()`, a floor built again from the same seed (`continue_test` pattern), `give()` | medium duct, same edge, along ± 0.05; on a ceiling patch: same patch, (u, v) ± 0.05, same hang; a calm of 20 s owed to seat 1 kept ± 0.1; the power objective's zones (phase 1) kept with her |
| P director | the director on | `director.reach(a, b) == creature.travel_metres(a)[b]` for a pair joined by a `loose` duct link, and it is less than `director.walk(a, b)`; a `"cruce"` lead is accepted (`lead_to` true) in `roam` |

### 9.2 `tests/office/office_capture_test.gd`

| Case | Setup | Checks |
|---|---|---|
| 1 from a cue | the player in the first dark wing-0 room (not lit), torch off, back to her; her frozen on the dark ceiling 6 m behind, then `force_state(&"stalk", 1)` and physics on | a cue within 20 s; the capture starts `cue_window` (± 2 frames) after it; `execution.entry == "back"`; the last `capture_log` entry has `cue_id >= 0`, `forced` false, `caught_at - cue_at >= window` |
| 2 style | the same capture | `executions.style()` is `lurker_capture.gd`, `score()` is `lurker_score.gd`, `capture_length() == 5.4`, the execution ends at 5.7 ± 1 frame |
| 3 hang and lift | the same | `execution.extra.hang.y` within 0.1 of the room's ceiling; `extra.lift <= ceiling - floor - 1.85 - 0.12 + 0.01`; the victim's feet rise by `extra.lift` ± 0.05 at `LIFT_TO` and are on the floor ± 0.1 after `DROP_TIME + FALL_LENGTH` |
| 4 the face upside down | the same, sampled during [face_start + 0.1, face_end - 0.1] | `camera.global_basis.y.dot(mask.basis.y) < -0.5`; lens to face in [0.24, 0.6] m |
| 5 looking up | ten forced captures (`executions.forced = {entry: "back", seed: n}`, n = 1..10) in ten rooms (the first ten wing-0 non-corridor rooms) | `tape.take.rest` forward has `y > 0.5` in all; kind is not `DOWN`; the body's fall line outside `VIEW_HALF` in at least 8 of 10 |
| 6 the tile | case 1's capture | `executions.leavings` holds a `SwingingTile`; its rotation differs by more than 0.05 rad over 1 s; none in a room without a false ceiling (case 10's) |
| 7 the body stays | case 1, to its end | seat 1 is dead; the avatar is visible at the drop point, its hips under 0.5 m over the floor |
| 8 blood | gore on, then off (`settings.values.gore`) | on: one record, more than 10 stains, some on the floor within 1.5 m of the drop point, none within 0.3 m of her; off: no record |
| 9 sounds | case 1 with `world_audio.enabled` and events logged | a bite path (`lurker/bite_`) at `KILL_TIME` ± 0.05; a `BODY_FALL` at `DROP_TIME + 0.85 * FALL_LENGTH` ± 0.05 |
| 10 above | the first 4.4 m room or the boardroom (3.25); the player looking ahead (pitch 0); her on the ceiling 2 m in front | `choose_entry` gives `"above"`; `face_start("above") == 0.0`; the camera still falls looking up |
| 11 let go | `release_execution()` at 1.0 s | the victim alive, `player.held` false, her state `scared`, no blood record kept, grips cleared, `limbs.upright == 1.0` |
| 12 no capture | the player in the freight lobby; then in a lit room at Apacible after a forced stalk | 15 s each: no capture |
| 13 the hotel | floor 1, one forced capture | `style()` is `locust_capture.gd`, `score()` is `capture_score.gd`; the execution has no `"extra"`; `death_tape` used its own constants (`tape_framing` absent) |
| 14 payload | case 1's `data` (spy on `apply_execution`) | `execution.extra == data.extra` |

### 9.3 `tools/dev/body_clip_probe.gd --floor=2`

- `run()`: with `options.floor == "2"`, `level.set_floor(2)` before `start_floor`; the staging room is the largest wing-0 room with a false ceiling; her placed with `creature.teleport(creature_at, yaw, &"probe")` and `force_state(&"roam")` (`put()` asks the contract only on floor 2; floor 1 keeps its Locust lines); `executions.forced` as today.
- Stages: open, back to wall (0.4, 0.7, 1.2), it against wall, along each side wall, corner, for entries `"back"` and `"above"` (no `"side"`, no wardrobes); three doorways (`"back"`, under the 2.65 m lintel); new `"aisle"`: the first archive aisle's centre (wing 1), `"back"`.
- The `"top"` joint against the ceiling and the lintel is what this floor adds; `LIMIT 0.04` unchanged; `--strict` fails on any fault. The floor-1 run prints the same lines as before.

### 9.4 `tests/office/office_audio_test.gd` (real clock, batch 3)

Setup: floor 2, seed 81, settings `master 0.8`, `threat 0.85`, `effects 0.8`; her frozen. `R` = the first wing-0 open office with a `"ceiling"` exit `E`; she is placed on a duct edge of `E`'s cell node at `along 0.5`; the listener is the player's camera at `R`'s centre.

| Case | Checks |
|---|---|
| 1 bus | `Ducts` exists once, sends to `Creature`, has the EQ and the reverb |
| 2 out of the grille | `sound_route(listener)`: audible, `position` within 0.02 of `E.point`, `bus == &"Ducts"`; `world_audio.presence.bus == "Ducts"` after 0.5 s |
| 3 a room of its own | the listener moved to an adjacent room `Q` with its own exit, farther along the ducts | the position is `Q`'s exit |
| 4 out of reach | the listener in a room whose duct metres from her exceed 40 | not audible |
| 5 other planta | the listener on wing 1 | not audible |
| 6 never through a wall | 20 listener points (every room centre of wing 0 in id order, the first 20) | wherever audible, `world_audio.occluded(route.position, RID(), listener)` is false |
| 7 real audio | an `AudioEffectCapture` on `Ducts`; her duct knocks forced for 1 s (`voice.travel()` with a speed) | peak > 1e-5 with the listener in `R`; < 1e-6 on wing 1 |
| 8 surfaces | `voice.footfall(point, 0.8, normal)` with her medium set | ceiling of `R` → `tile_`; in a duct → `knock_`/`metal_`; a block wall (a corridor, `wall_material == "block"`) → `hard_`; a wing-2 type-16 wall (`veneer`) → `wood_`; that room's carpet floor → `hard_` with cutoff ≤ 1200 and gain 8 dB under the plain hard step |
| 9 cue | `force_state(&"cue", 1)` with her 2.5 m behind the player in `R` | `voice.last.path` contains `lurker/cue_`, its point within 0.1 of her face, its bus `Creature`; with subtitles on, `world_audio.caption_text == "[Una respiración en la nuca]"`; `world_audio.duck > 0` within 0.1 s |
| 10 aura | her in a duct 10 m from the listener | `aura.cue_point` within 0.05 of an exit point; `aura.route_distance` within 0.5 of the route's distance; the aura's breath player is not playing |
| 11 hum | her drained room has a hum | its `pitch_scale` < 1 |

### 9.5 `tests/hotel/sanity_test.gd --floor=2`

Without the argument the test is today's. With `--floor=2`, an `office_part()` instead (the creature frozen 80 m below as today, `lies.rng.seed = 81`):

| Case | Checks |
|---|---|
| 1 own lies | `sanity.creature_lies()` is `lurker_hallucinations.gd`; `lies_tell_own()` true |
| 2 cadence | sanity 30; 50 draws of `hallucinate()` with `hallucination_wait` forced to 0 each time: every new wait ≤ `lerpf(42, 13, gone) * 1.3 * 0.7` and ≥ `lerpf(42, 13, gone) * 0.7 * 0.7` |
| 3 kinds per planta | 200 `lies.lie(point, 0.8)` with the player on wing 0, then 1, then 2 (power and air states set for each condition) | every kind is in 4.3's table for that planta; `tubo` and `telefono` appear on wing 0, `palanca` and `tictac` on 1, `ventiladores` and `ducto` on 2 |
| 4 never | over those 600 lies (spies installed before) | `hotel.drain` never called; no path of `NEVER` played; no station lamp lit and no `tube_bell`; the power objective's state unchanged and no follow cue in `world_audio.long_cues`; `air.sound_mask()` 0 throughout; `world_audio.caption_text` never set |
| 5 one lamp | a `lampara` lie in a room with n ≥ 2 lamps | that room's light energy dips by at most `1/n` of it; every other lens material of the room unchanged |
| 6 conditions | the red lever running; the fans running | no `tictac`; no `ventiladores` and no `ducto` on wing 2 |
| 7 the face | `ensure_sight()` | the model has a `Skeleton3D` and the lurker visual; `poser.point("head")` is finite; with a dark door, a partition and a ceiling corner staged in view, `place()` returns true for each kind and `pose_peek` plays `"peek"` |
| 8 locker | hidden in a locker 2 s | sanity falls at the wardrobe's rate |
| 9 drained | a room drained at 0.6 | `lit_at()` false there |

### 9.6 `tests/hotel/creature_contract_test.gd` (a Lurker section) and `difficulty_test.gd`

- Every method of `creature.gd` is overridden or knowingly inherited by `lurker.gd` (a list in the test); `activity()`, `alarm_level()` and `hushed()` over the ten states are table 0.3; `can()` is true only for `&"ducts"`.
- `pack_state()` → `push_state()` on a second instance gives the same position, quaternion (± 1e-4), state, flags and duct; `save_state()` → `restore_state()` likewise (2.7).
- `lurker_score.gd` has every constant and static function `capture_score.gd` has (`get_script_constant_map()` keys and `get_script_method_list()` names), plus `GRAB` and `grab`.
- `lurker_hallucinations.gd` has `OWN_LIES`, `WAIT_SCALE`, `NEVER`, `lie`, `kinds_here`, `wait_scale` and the base API.
- `locust_capture.score()` is `capture_score.gd`; `FLOOR.den_rooms()` gives the Locust's `den_room()` of before on 10 seeds × 3 stages.
- `difficulty_test`: 0.4's keys and values; none of them in the Locust's profiles.

---

## 10. `tools/verify.ps1`

- `$tests` gains `'office/office_survival_test'`, `'office/office_capture_test'` (batch 1) and `'office/office_audio_test'` (batch 3: add it to the `$audio` names beside `hotel_audio_test` and `spatial_audio_test`).
- `office_test`, `office_stages_test`, `office_geometry_test` and phase 1's bots check with `--floor=2` get `'--null-creature'` in their user args.
- Two second runs of existing scripts, each with its own profile files (`--profile-tag`, already read by `hotel_main.gd:191`):
  - `Add-Check 'hotel/sanity_test' 'sanity_test_office' (Godot-Arguments 'res://tests/hotel/sanity_test.gd' $log $true @('--automation','--test-profile','--silent','--floor=2','--profile-tag=office')) 360`
  - `Add-Check 'dev/body_clip_probe' 'body_clip_probe_office' (Godot-Arguments 'res://tools/dev/body_clip_probe.gd' $log $true @('--test-profile','--strict','--automation','--silent','--floor=2','--profile-tag=office')) 480`
- The count of green lines grows by five.

---

## 11. Docs (Spanish; no «·» or «—» in anything the game shows)

- `docs/LURKER.md`: "Lo que falta" becomes what exists: how she sounds (by surface, in the ducts, the cue, the shriek), her capture, her lies, the lights she drinks, her cost and its levels; the commands of the bench with `--preset=4`.
- `docs/OFICINAS.md`: section 14 gets the decisions of 0.5; section 5 the corrected cadence; section 15 the verification of phase 3 as done, with the batch's numbers.
- `docs/DEVELOPMENT.md`: the score per capture style and its hooks (`stage_extra`, `tape_framing`, `tape_pose`, `blood_*`, `spill`, look-up rests), the `Ducts` bus, `creature_event` and its kinds, the pack format, `--null-creature`, the bots' threat for her.
- `docs/AUDIO.md`: her sounds and the duct bus; lies never captioned.
- `docs/DIFFICULTY.md`: the Lurker's table (0.4) and the batches.
- `docs/PERFORMANCE.md`: the Lurker's scenario, before and after.
- `docs/ASSETS.md`, `docs/asset_hashes.json`, `hotel_ui.gd CREDITS`: 3.1.
- `docs/PLAN.md` section 4: section 14's waiting list.
- `docs/textos_juego.txt`: the captions of 3.4 and the profile's.
- `docs/CHANGELOG.md`: nothing until the floor is released (phase 5).

---

## 12. Order of work

1. **Checks** (30 min, read only): every name of 0.1 and 0.2 exists under that name; note each difference at the top of the step's commit message and use the landed name.
2. **3a-0** (hotel identical): `turn_for_capture`, `on_event`, `tally` in the contract; `creature_scene_override` and `--null-creature`, with the phase-1 tests switched to it; `FLOOR.den_rooms()`; the director's `raps_weight`; `apply_rules` if needed. Whole `verify.ps1`.
3. **3g-0 baseline**: `hotel_benchmark --lurker` before any change to her drawing; numbers into `PERFORMANCE.md`.
4. **3a**: `office_floor.CREATURE`; her contract members (2.2, 2.3, 2.7); `lurker_drain.gd`, `lamp_points()`, `drain()`'s wobble, `drain_of()`, hysteresis, the hum's pitch; the systems (2.6); `office_survival_test` (cases needing sound or the capture come in their steps). `difficulty_test` keys.
5. **3b**: `prepare_lurker_sfx.py`, import, ASSETS; the profile and its aura fields; `ensure_duct_bus()` and routes with `bus`; `lurker_voice.gd`; `sound_route`/`presence_route`; `use_profile()`; the cue, shriek, `fright()`, the car; `office_audio_test`; cases E, I, K of 9.1.
6. **3d**: first the score refactor alone (5.1) with `capture_test`, the contract test and `body_clip_probe --strict` printing the same as before; then `lurker_score`, `lurker_capture`, grips and `upright`, the tape's hooks, `camera_fall` look-up, blood, the hanging pose; `office_capture_test`; `body_clip_probe --floor=2`.
7. **3c**: the office rows of 3.1 and CREDITS; `lurker_hallucinations.gd`, `lurker_poser.gd`, the sanity and phantom hooks, `flicker_one()`, `light_body()`; `sanity_test --floor=2`.
8. **3e**: gizmos and layer 7, debug lines; `pack_state`/`push_state`; `creature_event` and PROTOCOL; recordings; the contract test's Lurker section; the four hotel net scenarios green.
9. **3f**: `bot_threat_lurker.gd`, the brain hooks, cover and looking back, the watchdog and tally, `bot_match`, `bots.ps1 -Floor`; `bots_test`'s Lurker part; the first balance batch (7.5).
10. **3g**: the noise bake and shader, the visual's LOD and quality, the hands' rays and planes, `layer_meshes()` and `follow_bodies()`; the benchmark again; cases M and N; the capture tool at `--preset=4` and on Compatibility; the second batch.
11. **Docs** (section 11), whole `verify.ps1`, the hotel's bots check and net scenarios. A commit per step, as the loop does.

---

## 13. Risks and floor-1 guards

1. **Phase 2's names differ** (0.2). The behaviour asked here is the requirement; adapt the call, never fork a second shell or duct graph.
2. **Phase 1's tests expect the null creature** (`heard`, no hunting). Switching `CREATURE` breaks them unless they get `--null-creature` in the same commit as the switch.
3. **The score refactor moves the hotel**: one wrong `SCORE.` left or changed and a capture is a frame off. Do it alone, compare `capture_test`, the contract test and the clip probe's full output before and after; `avatar_visual` keeps `capture_score.gd`.
4. **Her orientation in a capture**: `executions.apply_execution()` turned the creature with `rotation.y`, which would undo her hanging basis; `turn_for_capture()` fixes it, and her puppet's `follow_state` (phase 4) must not pull her off the scene either.
5. **`lit()` flapping** under her drain flicker: the wobble never enters `drain_of()`, and the hysteresis (0.5 / 0.45) keeps rules (sanity, `lit_capture`, `regards()`) from chattering.
6. **Duct routes are costly** (Dijkstra per call): memoize as `walked_route()` does; measure `world_audio`'s frame time with her in a duct in the benchmark's CPU line.
7. **The grips**: two hands of 2 m arms on shoulders from above may put elbows through the victim's head; the clip probe only measures the victim. Look at it in `tools/capture/execution_capture.gd` on floor 2 (add `--floor=2`) and tune `HOLD_FAR`/the hang offset, not the IK.
8. **A camera lying on its back** is a choice of the author (OFICINAS 6); if it reads wrong in the capture, `frame_up()`'s pitch range is the knob, and `face_up()` keeps every capture resolvable.
9. **The swinging tile doubles the tile above it**: if it shows in the capture, set `SWING_TILE := false` and note it; nothing else depends on it.
10. **Lies and the interface**: a caption on a lie would make the interface lie. 9.5 case 4 catches it.
11. **Fairness in the duct**: without `CRAWL_CUE_EXTRA` a Pesadilla crawler cannot turn in time. It is an agents' decision (0.5.5) for the author.
12. **`default_bus_layout.tres`**: not edited (the bus is made at runtime); restore it after every Godot run, as the loop does.
13. **Pixabay mirrors at 24 kHz** sound dull next to 48 kHz BigSoundBank takes; they are the stand-ins until the author fetches the lossless originals (14). The `soft` and `tile` sets suffer most.
14. **CC BY**: the copier (CC BY 3.0) and the chair (CC BY 4.0) need their credits in the same commit; the chair's licence was uploaded on the author's behalf (registro note): confirm its page before the release, or drop the `silla` lie.
15. **Performance targets unmet**: the fallbacks of 8.1, in order; never a quality that hides her face or her ink completely (no advantage on any preset).
16. **GL Compatibility**: `sampler3D` and a loop with `break` are fine in GLES3, but test the shader there (`--rendering-method gl_compatibility` on the capture tool).
17. **Bot behaviour is a model**: the batch measures how the rules play for bots that turn at 0.35 or 0.9 s; the author's verdict comes from people (phase 5).
18. **Determinism**: lies use their own `rng` (the hotel's global `randf()` order untouched); her drain is per machine (presentation), the rules read the host's.

**Floor-1 guards** (each a no-op on the hotel): `creature_scene_override` empty; `turn_for_capture()` default; `on_event()`/`tally()` defaults; `raps_weight` 0.7 when the key is absent; `drain()`'s wobble 0 and `drain_of()` 0; the hum's pitch 1.0; `ensure_duct_bus()` never called; routes without `bus`; `use_profile(locust.tres)` = today's aura; `lies_tell_own()` false before any draw; `phantom_sight` without `sight_spots`; `score()` is `capture_score.gd`; no `extra`; no `tape_framing`/`tape_pose`; no `look_up`; blood without style hooks; `hang` absent; layer 7 draws nothing for the Locust; `pack_state` unchanged; a new RPC only; recordings' fields from the Locust as today; bots' hooks absent from `bot_threat.gd`. `manifest_golden_test`, `capture_test`, `body_clip_probe`, `hotel_audio_test`, `spatial_audio_test`, `sanity_test`, `bots_test` (floor 1), `stages_test`, `continue_test` and the four net scenarios stay green after every step.

---

## 14. Audio assets: what is used, and what waits for the author

**Used** (all `"status": "ok"` in their `registro.json`): 3.1's tables. From `audio_criatura`: `ceiling_claws_cardboard_scratch`, `tile_grid_metal_rattle`, `tile_styrofoam_grind`, `debris_sandfall`, `debris_gravel_dirt_small`, `metal_fingernail_elevator_ceiling`, `duct_impacts_metal_box`, `duct_heater_vent_hits`, `wall_claws_smooth_rock`, `plaster_tool_scrape`, `wood_claws_skittering_dog`, `wood_fingernail_scratch`, `breath_cow_bodot`, `breath_horse_bsb`, `bone_knuckles_crack`, `bone_celery_bsb`, `shriek_barn_owl_bsb`, `shriek_bat_screeches_oga`. Not used though ok: `ceiling_rat_gnawing_wood` (gnawing reads as a rodent; its noise floor needs work), kept as a layer to try in phase 5's mix. From `audio_oficina`: `telefono_antiguo` (`bsb_3532`), `fotocopiadora` (`soundbible_2169`, CC BY 3.0), `silla_oficina_ruedas` (`oga_nicolemariet`, CC BY 4.0). From `audio_edificio`: `fluorescent_starter_flicker` (`pixabay_61228`). Rejected entries (`metal_plate_contact_mic_scratch`, `shriek_fox_forest` and the others marked `rejected`) are never used.

**Waits for the author** (to `docs/PLAN.md` section 4, "Assets que faltan (tuyos)"):

- Missing, best as own foley: claws or nails on a real mineral-fibre ceiling tile (`claws_mineral_fibre_tile_direct`), a tile lifting in its T-bar grid (`tile_lifting_in_tbar_grid_direct`).
- Freesound, needs the author's login (CC0 unless said): noise in a ceiling (`fs_noise_in_ceiling`, low quality even so), nails tapping metal and fingernails on metal sheets (`fs_nails_tapping_metal`, `fs_fingernails_on_metal_sheets`), clawing at wood (`fs_clawing_at_wood`), fingernails on plaster and on a popcorn wall (`fs_fingernails_on_plaster_wall`, `fs_scratching_popcorn_wall`), crawling inside an air vent (`fs_crawling_inside_air_vent`, `fs_crawling_through_vent_foley`), particles falling (`fs_particulas_cayendo`), an office ceiling rattling and styrofoam creaking (`fs_ceiling_rattle_office`, `fs_styrofoam_creak`), heavy horse breathing (`fs_horses_heavy_breathing`), a fox screaming at night (`fs_fox_screaming_night`).
- The lossless originals of the Pixabay mirrors used above (Freesound login): the 24 kHz ones first (`ceiling_claws_cardboard_scratch` has no original left), then `breath_cow_bodot`, `bone_knuckles_crack`, `duct_impacts_metal_box`, `metal_fingernail_elevator_ceiling`, `tile_*`, `debris_sandfall`.
- BigSoundBank's 48 kHz WAV of `bone_celery_bsb`, `breath_horse_bsb` and `shriek_barn_owl_bsb` (its download button posts an anti-bot form; the 320 kbps MP3s are used meanwhile).
- `audio_oficina`: venetian blinds (`persianas_venecianas`, needs login: the `persiana` lie stays silent until then), metal doors with a push bar (`puerta_metalica_barra`), CC0 takes of the copier and the office chair (to drop two credits).
- Confirm on its own page the licence of the chair recording (uploaded on the author's behalf).
