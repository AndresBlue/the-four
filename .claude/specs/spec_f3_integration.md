# Phase 3: floor 2 played alone with The Lurker (and the data formats phase 4 inherits)

**Status:** draft, reviewed by two critics on 22 October 2026 and revised as a delta over phase 2. Not approved. Not to be split into units (`encargos`) until the director has reconciled phase 2 (Pending decisions, "For the director", 1) and the author has answered what blocks it.

Read first: `docs/OFICINAS.md` sections 1, 3 (each planta's own lies), 4, 5, 6, 7, 9, 11 (11.1 and 11.3 to 11.8), 13 and 15; `docs/LURKER.md`; `docs/EXECUTION.md` (the capture's rules: cause yes, impact no; half a second clean; never two alike). Companion specs:

- `spec_f1_generator.md`: manifest keys (`ducts`, `plenum`, `archives`, `power`, `air`, `tubes`, `mail`), palette questions and ids (`office_palette.gd`: `OPEN_OFFICE 1`, `CUBICLES 2`, `OFFICE 3`, `BOARDROOM 5`, `ARCHIVE 6`, `COPY_ROOM 7`, `MOBILE_ARCHIVE 13`, `EXEC_OFFICE 16`, `WINDOW 17`, `ELECTRICAL 18`, `REFUGE 19`, `SECURITY 21`, `AIR_ROOM 22`, `AIR_PLANT 23`, `SECRETARY 24`), `null_creature.gd`, `office_floor.gd`.
- `spec_f1_geometry.md`: render layers (8.1: the Lurker on value 4, plenum on value 8), power hooks (7.3), the hum (8.4: only lamps whose room `lit()` hum), lenses (`lens_of`, one `MultiMeshInstance3D` per room; `lens_off`; the failing troffer's own `troffer_fail_%d`, H5 `share`), `outside_holder()`/`add_outside()` (8.5), `crawl_space()` and `body_bit()` (H10).
- `spec_f1_systems.md`: `conduit_graph.gd` (1.5), `world_audio.play_moving()` and the sound mask (1.6), the objective base (1.1), noises and recordings (1.8), the crawl (4.4: `CRAWL_TURN_RATE 2.4`), `air.ducts_closed()`, the office RPCs (`office_state`, reliable, with catch-up).
- **`spec_f2_movement.md` (2a) and `spec_f2_mind.md` (2b) own The Lurker.** This spec is a delta over them: it never redefines what they define (her body, scene, shell, ducts, routes, motion, transit, den, drain, senses, brain and states, the warning and its ledger, the cue on the wire and in the ears, the cue and scare recordings, her difficulty keys, `hotel_main.creature_scene`). Section 0.2 lists what it uses. Where 2a and 2b disagree with each other, the director decides before this spec is split (Pending decisions).

Floor 1 stays identical through every step of this spec: every change to a shared file is a no-op for the hotel kind, and section 13 lists the guards. Line numbers are from the tree at `a854b6f` with step 0a5 half landed. Search by function name.

**Numbering.** Code counts plantas as `wing` 0, 1, 2 (Personal, Registro y Archivo, Dirección); prose says "planta 1 to 3" as OFICINAS does.

**Steps.** 3a the Lurker on the floor; 3b her sound; 3c her lies; 3d her capture; 3e the observer and the data formats; 3f the bots and the balance batch; 3g performance. Each is one commit, green on `tools/verify.ps1`.

---

## 0. What this spec assumes and what it decides

### 0.1 Phase 0 and phase 1 (as specified in `.claude/specs/fase0_pasos.md` and the phase 1 specs)

- `level.creature` (alias `level.locust`), the contract in `game/enemies/creature.gd`, `level.kind` (0c), `level.set_floor(n)` and `--floor=N`, `level.objective(id)` (0b's accessor), `level.tuning()` returning `DIFFICULTY.profile(id, kind.CREATURE_KEY)` merged (0f), `FLOOR.palette(manifest)` (0d), `level.point_protected(point)`.
- 0e: `hotel.lit(room_id)`, `hotel.set_room_power(room_id, on)`, `hotel.drain(room_id, amount)`, `ROOM_LAYERS.put_on_actor(mesh, bits)` used by `follow_bodies()` only for meshes with the meta `"follow_rooms"` (none on floor 1; the rest keep `put_on()`).
- 1a: `office_floor.gd` with `CREATURE := "res://game/enemies/null_creature.tscn"` and `CREATURE_KEY := &"lurker"`; `null_creature.gd` with `heard`.
- 1d: `office_geometry.gd` (troffers, `lens_of`, `battens_of`, per-room lens duplicates for drain, the failing-troffer flicker entry with `share`), `hum_path()`, `PLENUM_LAYER := 8`.
- 1e to 1g: `conduit_graph.gd`, `play_moving()`, `mask_db()`, `level.sound_mask(point)`, `level.crawling_at(point)`, `air.ducts_closed()`, the objectives `files`, `power`, `air` with `snapshot()/restore()`, `floor_save` writing `"objectives"`, the office RPCs (a circuit given travels there, reliably, with catch-up for late joiners).

None of 0b to 0f, phase 1 or phase 2 exists in the tree today. Section 12 says what has to land before any unit of this spec is cut.

### 0.2 Phase 2: what this spec calls (defined there, never here)

| Used here | Owner | What |
|---|---|---|
| `lurker.gd`, `lurker_creature.tscn` | 2a 8.1, 8.2 | `CharacterBody3D` root, `collision_layer = 32`, `collision_mask = 0`, `BodyShape` sphere, `Visual` = `lurker.tscn`; layer 0 and `Visual` hidden while `motion.hidden` |
| `lurker.shell`, `.ducts`, `.routes`, `.motion` | 2a 3 to 7 | `motion.hidden`, `motion.in_duct`, `motion.near_node`, `motion.duct_point`, `motion.transit`, `motion.jumps`, `jump_id`; `ducts.closed`, `ducts.exits`, `ducts.visible_kinds` (`main`, `cross`); `routes.travel_metres()` |
| `transit_phase()`, `in_transit()`, `hushed()`, `follow_to_planta()` | 2a 7.6, 8.2 | her way between plantas (`&"leaving"`, `&"drop"`, `&"arriving"`); `hushed()` true in the drop |
| `den_room(stage)`, `den_point(stage)`, `place_at(room)` | 2a 8.2 / 2b 8.5 | where she starts (the two specs differ: Pending, director 1) |
| `pack_state()`, `push_state()`, `follow_state()` | 2a 8.3 | `PACK_SIZE` 10: position, quaternion, velocity, word, flags (`IN_DUCT 1, HIDDEN 2, SURFACE 4, DRAINING 8, CUE 16`), grace, look, clip, near node, `jump_id` |
| `save_state()`, `restore_state()` | 2a 8.2 | `{"at", "heading"}`; restore cancels a transit |
| `sound_route()`, `presence_route()` | 2a 8.2 | out of the grilles in a hidden duct; `aura.route_to()` on a surface |
| `lurker.brain` | 2b 7 | `enum State {ROAM, LISTEN, STALK, PEEK, FREEZE, CREEP, CUE, TAKE, RECOIL, FLEE, TRANSIT, WAIT_ABOVE}`; `activity()`, `state_name()`, `prey_seat()`, `force(next, data)` (CUE and TAKE cannot be forced); signals `cue_started(entry)`, `cue_ended(entry)`, `scared(cause, seat)`, `took(seat)`, `alongside_car()`; `CHASE_EARSHOT`, `CUE_RANGE`, `spurned` |
| `lurker.brain.warning` | 2b 6 | `ledger` (`{id, seat, at, window, latency, due, point, outcome, end, by, reason, take_at, captured, heard_after}`), `active`, `TAKE_HOLD`, `TAKE_REACH`, `CUE_SOUNDS` (`cue_0..2`), `CUE_CAPTION`, `CUE_CAPTION_NEAR`, `static audit(log)` |
| `may_capture()`, `cue_of()`, `capture_log()`, `play_cue()`, `cue_over()` | 2b 2.1, 8.1 | the contract's capture gate and the cue; `capture_log()` is the ledger, one entry per cue |
| `lurker.senses` | 2b 5 | `drain_rooms()`, `DRAIN`, `DRAIN_WOBBLE`, `LIT_DRAIN 0.9`; `lurker.drained`, `update_drain()`; `hotel.drained(room)` |
| `lurker.thinking`, `lurker.place_on(point, surface, toward)` | 2b 8.1 | tests switch the mind off and place her |
| `world_audio.play_cue()`, `ears_hold`, `caption_lock`, `last_cue` | 2b 9.2 | the cue in the ears, never under `mask_db()` |
| `match_net.send_cue()`, `cue_behind`, `cue_reached`, `send_cue_over()`, `cue_closed`, `latency_of()` | 2b 9.1 | the cue on the wire, and the PROTOCOL bump |
| `tools/audio/prepare_lurker_sfx.py`, `cue_0..2.wav`, `scare_0.wav`, `scare_1.wav` | 2b 9.3 | the script and the cue and shriek recordings |
| world port `scream(point)` | 2b 8.4 | her shriek, played everywhere through `match_net.world_sound()` |
| `hotel_main.creature_scene`, `--creature=<key>` | 2b 8.6 | `"none"` is the null creature |
| `arm_creature()` guard | 2b 0.2 | `if "reach_scale" in creature:` around the two Locust lines |
| `CREATURE_PROFILES[&"lurker"]`, director overrides, traits | 2b 4.1 to 4.3 (step 0f) | `back_window`, `lit_takes`, `duct_speed`, `stalk_distance`, `freeze_time`, `scare_calm`, `creep_scale`, `drain_reach`, `peek_every`, `sated`, `forget`; `encounter_every`, `cross`, `lead_every`, `peak_max`, `peak_tense`, `rest_chase`, `ambush`, `double_back` |

Rule: if a name differs as landed, use the landed one and say so in the commit message. If something this spec needs is missing from phase 2 as landed, stop and report it; never add a second shell, duct graph, drain, cue path or state list.

### 0.2b Phase 2 as landed (24 October 2026, director; up to `ba62e00`)

Phases 0, 1 and 2 are in the tree. Where the table above differs from what landed, use what landed:

- **The warning** is `lurker.warning` (held by `lurker.gd`; the brain holds the same object). Its entries also carry `above`, `ran`, `forced`; reasons add `"corriendo"` (the author: leaving saves only running) and `"forzada"`. Captions: `CUE_CAPTION`, `CUE_CAPTION_NEAR`, `CUE_CAPTION_ABOVE` ("[Algo respira sobre ti]", a proposal).
- **Placing her:** `place_over(point, toward)` and `place_in_exit(exit)`, not `place_on()`. `teleport()`, `relocate()`, `restore_state()` as 2a 8.2b.
- **Her words:** `WORDS` ends with `&"stalk"` and `&"withdraw"`; STALK says `stalk` (the author: hostile, not hunting nor chasing), FLEE says `withdraw`. `creature.gd`'s `HOSTILE` has `stalk`.
- **Pack flags:** `IN_DUCT 1, HIDDEN 2, SURFACE 4, DRAINING 8, CUE 16, DROP 32, ARRIVING 64, TRAY 128, BAND 256`; `PACK_SIZE` 10 as written.
- **`save_state()`** is `{at, heading, hang, in_duct, near, wing_goal}`; restore puts her where a transit would have ended, in her duct at its node, or back at `at` with her hang.
- **The drain:** `lurker.drain_step(delta)` (targets, every machine), `_process()` (the applied drain and its tremble), `undrain()`; `SENSES.drain_rooms()`, `DRAIN`, `DRAIN_WOBBLE`; `LIT_DRAIN` is `hotel_geometry`'s (0.9), and the applied drain never goes over 0.89. From a duct over a room too; never an off-limits room. Emergency units are lamp points: `office_geometry.drain_emergency(room, amount)` is called when it exists (phase 3 adds it: the author's I9).
- **The net:** only `match_net.send_cue()` and `send_cue_over()`, on this machine. `cue_behind`, `cue_reached`, `cue_closed`, `latency_of()`, the reliable event and the `PROTOCOL` bump are phase 4's.
- **Not landed:** the brain's `alongside_car()` signal; ceiling crosses and doorframes as show spots (a show is a peek at a dark room's ceiling); spec_f2_mind 10.2 case 11 (turning on the pad, a measurement).
- **Spawning:** `hotel_main.creature_scene` / `--creature=lurker` (8.6) put her on a floor; `office_floor.CREATURE` is still the null creature: step 3a switches it. Her den on planta 3 is the air room. `arm_creature()` needs no guard (nothing of The Locust is read there any more).
- **Her elbows** keep clear of anything with a collider (`lurker_limbs.solid_mask`); the bench is `tools/workbenches/lurker_arena.tscn`.
- **The author's decisions** of 24 October (`.claude/specs/decisiones_fase2_3.md`, and the "Resolved by the author" note at the end of this spec) settle 0.5: a lie never captions, her real duct and tile sounds lose their captions too (I6); her presence loop only above a locker (I11); the main-duct rule holds in versus too (I10); "desde arriba" over 3.0 m (I11; the warning's own `over_of()` is geometric, step 3 checks the room's height where it starts the cue); the director's knocks stay (I2: `raps` 0.7).

### 0.3 Her states

Phase 2's (2b 7.1): the twelve `State` values, their `activity()` words and the base `alarm_level()` from those words; `hushed()` is 2a's (the drop). Phase 3 adds no table of its own. Where this spec names a state it uses 2b's enum (`STALK`, `CREEP`, `WAIT_ABOVE`...). On the wire the state travels as that enum's value (6.2).

### 0.4 Difficulty

Phase 2's tables (2b 4.1 and 4.2, written by 0f). Phase 3 adds one key to the director's overrides:

| Key | Apacible | Equilibrada | Desafiante | Pesadilla | Read by |
|---|---|---|---|---|---|
| `raps` | 0.7 | 0.7 | 0.7 | 0.7 | `pacing_director.tune()` (2.4) |

0.7 is the hotel's weight: "mismas reglas" until the author says otherwise (Pending, author 2). `difficulty_test` gains: every Lurker profile has `raps` (a float, `>= 0`); no Locust profile has it.

### 0.5 Decisions taken here (to `docs/OFICINAS.md` 14 as "decidido por los agentes, pendiente del autor")

1. **Lies never put a caption on screen** (the interface never lies, OFICINAS 5); the hotel's lies have none either. Her real sounds of 3.4 (`ducts`, `tile`) do (Pending, author 6).
2. **No breath and no jaw click in any lie, and none in the dread aura.** The cue is "an exhalation and two jaw clicks"; nothing else of the floor may sound like it.
3. **Her presence loop sounds only while she waits above a locker** (OFICINAS 4, states table: "Acercarse: solo las garras"; "Encima: respiración por las lamas"). In every other state she is heard by her claws, knocks and tiles (3.4), never by a breath.
4. **She enters the main duct only behind the last crawler**: through the crossing stub, only when every survivor in the duct is past the crossing towards the shaft ("por detrás puede venir ella").
5. **"Desde arriba" needs a high ceiling**: the `"above"` entry only where the room's height is over 3.0 m (the boardroom, the 4.4 m rooms) or in an archive aisle (OFICINAS 6: "en una sala de techo alto o en el archivo").
6. **Half a second clean before the take**: on the victim's machine none of her claws, knocks or tiles start in the last 0.5 s before `due` and until the cue ends (EXECUTION 3; OFICINAS 1 says the cue keeps it).
7. **Her shriek costs sanity**: `SANITY_SHRIEK := 6.0` to each survivor within 12 m with a clear line to her face, one per `SANITY_SIGHT_REST` like the sights.

Removed from this list after review: the lie cadence, the director's knuckles, a longer window for crawlers and whether her drain darkens a room are the author's (Pending); the camera falling face up and the swinging tile are OFICINAS 6 (approved), not decisions.

---

## 1. Files

### Create

| File | Step | What |
|---|---|---|
| `game/enemies/lurker/lurker_voice.gd` | 3b | what she sounds like besides the cue and the shriek: footfalls by surface, duct travel, tile and dust, the car |
| `game/audio/profiles/lurker.tres` | 3b | her `CreatureAudioProfile` |
| `assets/audio/sfx/lurker/*.wav` (+ `.import`), the rows of 3.1 | 3b | output of the extended script |
| `game/app/hallucinations/lurker_hallucinations.gd` | 3c | her lies |
| `game/app/hallucinations/lurker_poser.gd` | 3c | poses her phantom (peek, stare) |
| `game/app/capture_styles/lurker_score.gd` | 3d | her capture, beat by beat (standalone: a script cannot override a parent's constants) |
| `game/app/capture_styles/lurker_capture.gd` | 3d | `extends "res://game/app/capture_styles/locust_capture.gd"`: lift and drop |
| `tools/bots/bot_threat_lurker.gd` | 3f | the bots' model of her |
| `tools/art/lurker/bake_ink_noise.gd` | 3g | bakes the 64³ ink noise |
| `assets/enemies/lurker/ink_noise.res` | 3g | its output (8.2) |
| `tests/office/office_survival_test.gd` | 3a | section 9.1 |
| `tests/office/office_audio_test.gd` | 3b | section 9.4 |
| `tests/office/office_capture_test.gd` | 3d | section 9.2 |

### Change

| File | Step | Change (each a no-op for floor 1) |
|---|---|---|
| `game/floors/office_floor.gd` | 3a | `CREATURE := "res://game/enemies/lurker/lurker_creature.tscn"` |
| `game/enemies/creature.gd` | 3a, 3b, 3d, 3e | `turn_for_capture()`, `on_event()`, `tally()`, `voice_point()`, `presence_on()` |
| `game/enemies/lurker/lurker.gd`, `lurker_brain.gd` | all | the members of sections 2 to 8 (on top of phase 2) |
| `game/enemies/lurker/lurker_visual.gd`, `lurker_limbs.gd`, `lurker_darkness.gdshader` | 3d, 3g | grips, `upright`, footfall normal, LOD, quality, `set_hidden()`, `layer_meshes()` |
| `game/director/pacing_director.gd` | 3a | `raps_weight` |
| `game/world/hotel/hotel_geometry.gd` | 3g, 3c | `follow_bodies()`/`light_body()` use `layer_meshes()` |
| `game/world/office/office_geometry.gd` | 3c | `flicker_one()` |
| `game/audio/world_audio.gd` | 3b | `ensure_duct_bus()`, routes may carry `bus`, `voice_point()` and `presence_on()` read, hum pitch under drain |
| `game/audio/creature_audio_profile.gd` | 3b | aura fields |
| `game/audio/dread_aura.gd` | 3b | `use_profile()`, `aura_rise` |
| `game/app/sanity.gd` | 3b, 3c | own lies, `fright()` |
| `game/app/phantom_sight.gd` | 3c | `sight_spots()`, `place_spot()`, `sight_rest()` |
| `game/app/executions.gd`, `death_tape.gd`, `blood.gd`, `camera_fall.gd`, `capture_styles/locust_capture.gd`, `game/player/avatars/avatar_visual.gd` | 3d | the score per style, `kill_sound_at()`/`kill_point()`, `stage_extra()`, framing hooks, look-up rests, blood hooks, the hanging pose |
| `game/app/observer_gizmos.gd`, `observer_view.gd` | 3e | layer 7 `ducts`, colours |
| `game/net/match_net.gd`, `game/net/net_session.gd` | 3e | `creature_event`, PROTOCOL (once, 6.3) |
| `tools/bots/bot_threats.gd`, `bot_brain.gd`, `bot_watchdog.gd`, `bot_match.gd`, `tools/bots.ps1`, `tests/hotel/bots_test.gd` | 3f | section 7 (the recorder unchanged: 6.4) |
| `tools/audio/prepare_lurker_sfx.py` (2b's) | 3b | the rows of 3.1 |
| `tools/audio/prepare_office_sfx.py` | 3c | four rows (3.1) |
| `tools/dev/body_clip_probe.gd` | 3d | `--floor=2` (9.3) |
| `tools/capture/execution_capture.gd` | 3d | `--floor=2` (9.2 case 15) |
| `tests/hotel/sanity_test.gd` | 3c | `--floor=2` part |
| `tests/hotel/creature_contract_test.gd`, `difficulty_test.gd` | 3a to 3e | sections 9.6 and 0.4 |
| `tools/benchmarks/hotel_benchmark.gd` | 3g | `--lurker` |
| `tools/verify.ps1` | each | section 10 |
| `game/ui/hotel_ui.gd` (`CREDITS`), `docs/*` | 3b, 3c, end | section 11 |

`hotel_main.gd` is not changed here: 2b's `creature_scene` and `arm_creature()` guard serve.

---

## 2. Step 3a: the Lurker on the floor

### 2.1 Spawning by `kind.CREATURE`

- `office_floor.CREATURE` becomes 2a's playing scene. `hotel_main.spawn_creature()` (0c) instantiates `load(kind.CREATURE)`, sets `creature.level = self` before `add_child` (as for the Locust today, `hotel_main.gd:1393`) and calls `place_at(room)`.
- **The null creature stays for the phase 1 tests** through 2b's `creature_scene`: `office_test`, `office_stages_test`, `office_geometry_test` and the phase-1 part of `bots_test --floor=2` get `--creature=none` (in `verify.ps1`) or set `level.creature_scene = "none"` before `start_floor`; the net scenario `office_coop` sets it on every role. In the same commit as the switch of `CREATURE`. On floor 1 `creature_scene` is empty: unchanged.
- `arm_creature()`: 2b's guard; nothing more here.
- `world_audio.set_creature(creature.sound_profile)`: `lurker.gd` has `@export var sound_profile: Resource = preload("res://game/audio/profiles/lurker.tres")`.
- **Where she starts**: phase 2's den (2a 8.2 or 2b 8.5, whichever the director keeps). No change to The Locust's `den_room()` and no shared `den_rooms()`: the hotel's draws stay where they are.

### 2.2 What phase 3 adds to the contract and to `lurker.gd`

```gdscript
## creature.gd (defaults keep the hotel identical)
func turn_for_capture(yaw: float) -> void: rotation.y = yaw   # executions.apply_execution() calls it (executions.gd:267)
func on_event(_kind: String, _data: Array) -> void: pass      # 6.3
func tally() -> Dictionary: return {}                          # 7.3
## Where its presence and its voice sound from (world_audio): today's point.
func voice_point() -> Vector3: return global_position + Vector3.UP * 1.4   # world_audio.PRESENCE_RISE; read the constant, do not copy it
## Whether its presence loop may play now (world_audio): always, but the Lurker's (0.5.3).
func presence_on() -> bool: return true
```

`lurker.gd` overrides: `turn_for_capture(_yaw): pass` (her orientation is the capture style's, 5.4); `on_event()` (6.3); `tally()` (7.3); `voice_point()`: in a hidden duct or the plenum the position of `sound_route()` toward the listener, else `face_point()`; `presence_on()`: `brain.state == BRAIN.State.WAIT_ABOVE`; `layer_meshes()` (8.4, not in the contract: callers use `has_method`). These five contract additions are the director's to approve (Pending, director 4).

### 2.3 Between plantas (OFICINAS 4, Ductos)

Phase 2's transit (2a 7.6, 2b 7.5 TRANSIT). Phase 3 adds only the sound outside the car: while `transit_phase() == &"drop"` (or after `alongside_car`, whichever phase 2 keeps) and this machine's player rides a car (`level.lifts.boarding.get("car", -1) >= 0`), `voice.outside_car()` every `CAR_SCRATCH := Vector2(0.6, 1.3)` s for the whole ride ("se la oye arañar por fuera del coche durante el viaje"). Nothing of her is ever placed in the car.

### 2.4 The director with her keys

- `pacing_director.tune(profile)`: `raps_weight = float(profile.get("raps", 0.7))`. In `build()` the moving list uses `["golpes", raps_weight]` instead of the literal `0.7` (the filter of weight 0 that follows, line 542, already drops it).
- The stalled branch (lines 533 to 541): `calm <= 0.0` keeps `[["quieto", 3.0]]`; `calm > 0.0` keeps `[["golpes", 1.0]]` when `raps_weight > 0.0`, and with `raps_weight == 0.0` plays nothing: `next_lead = clock + rng.randf_range(lead_every.x, lead_every.y) * spacing()` and return, as the strained branch above it does (the code gives a frightened, stalled team the knuckles "and nothing else"; without knuckles, nothing).
- `raps(target)` returns false at once when `raps_weight <= 0.0`.
- Hotel profiles have no `raps` key: 0.7 and the same draws, identical.
- `encounter_every`, `cross` and the other overrides come from 2b 4.2 through the merged profile. `reach()` already asks `creature.travel_metres()` (0a2): her metres include the ducts.

### 2.5 The lights she drinks

Phase 2 does it (2b 5.6): `senses.drain_rooms()`, `lurker.update_drain()` every 0.1 s on every machine, the lamps of a room down together, `hotel.drained(room)`, `lit()` false only past `LIT_DRAIN` 0.9 (a passive drain never darkens a room for the rules), nothing drained from a network duct, rooms already out skipped, emergency rooms not drained. Phase 3 adds only the hum:

- `world_audio.update_hum_levels()` (line 701): `hum.pitch_scale = 1.0 - HUM_DRAIN_PITCH * level.hotel.drained(int(entry.light.get_meta("room", -1)))`, `HUM_DRAIN_PITCH := 0.08`. Hotel: `drained()` is 0, pitch 1.0 as now (the hum players' pitch is set nowhere else).
- 1d's hum filter keeps humming every lamp whose room is `lit()`: with 2b's threshold a drained room still hums, lower.

Three questions stay with the author (Pending, author 1, 8, 9): whether her passive drain makes a room "dark" for the rules (OFICINAS 11.3 says "no la está bebiendo"; 2b's decision 6 says no), whether she drinks from inside a duct, and whether the emergency lamps tremble. This spec follows phase 2 until then.

### 2.6 The floor's systems and her (OFICINAS 3)

- **Light herds her (planta 2).** Phase 2's routes make lit rooms dear and powered zones dearer (`herds()`). Phase 3 adds the move when the light comes on where she is: every 0.25 s, on the driving machine, if the room she is in (or over, in the plenum) became `lit()` while she is in `ROAM`, `STALK` or `CREEP`, `brain.on_room_lit(room)`: she leaves by `world.nearest_exit()` into the ducts as in `FLEE` but with no spurn and no shriek, and the move is heard: `voice.tile_shift(exit point)` for a ceiling exit or a gap, and the knocks of 3.4 (OFICINAS 3: "se va por los ductos a la oscuridad, y se oye adónde"). The director checks that this fits 2b's brain (Pending, director 5).
- **Fans close the ducts (planta 3).** Phase 2 does the closing and the way out (2a 7.6: `ducts.closed`, `motion.eject()`; routes skip closed duct edges). Phase 3 adds: the way out is heard (tile shift and knocks, as above); and when the fans stop she goes back in (OFICINAS 3: "es una carrera por entrar antes"): `brain.on_ducts_open()` sets her goal to the first exit within `stalk_distance` of her, or the nearest. Her hearing under the fans is 2b's (5.2, the mask).
- **The main duct** (decision 0.5.4): duct edges of kind `main` and `cross` are hers, but she takes the `cross` edge into the main only when no survivor crawling in the main (`level.crawling_at(body)`) is between the hatch and the crossing node along `air.main.nodes`. In `lurker_routes` (2a) as an edge filter, so the same rule holds for whoever drives her.
- **The crawler's window.** Unchanged: the window is `back_window`. Whether a crawler gets more, or nothing (OFICINAS 3: "quien va el último puede ir mirando hacia atrás"), is the author's (Pending, author 4). If the author wants more, it is added where the deadline is computed (`lurker_warning.start()`) and in the oracle of 2b's fairness test, never in the brain.
- **Lockers (Encima).** Phase 2's `WAIT_ABOVE`. 9.1 case K checks it on the floor.

### 2.7 What is kept with a floor (`save_state()`, `restore_state()`)

2a's format, plus what a continue needs from phase 3:

```text
{"at": Vector3, "heading": Vector3,                 # 2a's
 "duct_node": int,                                  # motion.near_node when in a duct, else absent
 "calm": {seat (int): seconds left (float)},        # brain.spurned minus brain.clock, where positive
 "transit_wing": int}                               # the wing she was going to, absent when not in transit
```

`restore_state(state, rest)`: 2a's (relocate, heading, a transit cancelled); then with `duct_node`, `motion.place_in_duct(duct_node)` (2a/2b's name); `brain.spurned[seat] = brain.clock + left` for each `calm`; with `transit_wing`, `follow_to_planta(transit_wing + 1)` again. Her prey, a cue and a peek are never kept: `relocate()` cancels the cue (`"movida"`, 2b), nothing is owed (floor_save GRACE 8 s still applies). `floor_save.gd` is unchanged.

---

### 2.8 Step 3a as landed (24 October 2026, director)

- **Spawning** (088a9c4): `office_floor.CREATURE` is `lurker_creature.tscn`; `office_test`, `office_walk_test`, `office_bots_test`, `office_capture`, `lurker_route_probe` and the net scenarios `office_host` / `office_guest` set `creature_scene = "none"`. `bot_threats.MODELS[&"lurker"]` is the null threat until 3f's `bot_threat_lurker`.
- **The contract:** `turn_for_capture()`, `on_event()`, `tally()`, `voice_point()` (reads `WORLD_AUDIO.PRESENCE_RISE`), `presence_on()` in `creature.gd`, approved. `lurker.gd` overrides `turn_for_capture` (pass), `voice_point()` (hidden in a duct: where her last `sound_route()` came out, `heard_at`, else the duct point; out of one, `face_point()`) and `presence_on()` (`activity() == &"wait"`, so it reads the same on every machine). `on_event()` and `tally()` keep the defaults until 6.3 and 7.3. `world_audio` reads `voice_point()` and mutes the presence when `not presence_on()` (not for a phantom).
- **Light (2.6):** `lurker.watch_systems()` every `SYSTEMS_EVERY` 0.25 s in `think()`; the room is `motion.room()` (none in a duct). `brain.on_room_lit(face)` enters FLEE from ROAM, STALK or CREEP with `away_from = face`, no spurn and no shriek; FLEE's own `flee_exit(away_from)` picks the exit. The tile shift and knocks are 3b's.
- **Fans (2.6):** on wing 2's ducts going from shut to open, `brain.on_ducts_open(point)` (ROAM or LISTEN) sets her clue to the exit `routes.nearest_exit()` gives, not "the first within stalk_distance".
- **The main duct (2.6, I10):** `lurker_routes.cross_shut`, read every `tick()`: a survivor `crawling_at()` with `along_main()` under the crossing's plus `CROSS_CLEAR` (1.0 m) bars the cross edge into the main (`cross_barred()`, in `edge_cost()` and `edge_metres()`, and in the `travel_metres()` cache key). Out of the main through it is always open; the hatch exit stays usable while the hatch is open.
- **Kept (2.7):** `save_state()` keys stay 2a's (`near`, `wing_goal`, not `duct_node` / `transit_wing`) plus `calm`; `restore_state()` sets `brain.spurned` from it after `forget_all()`.
- **The director (2.4):** no `raps` knob: the author keeps the knocks at 0.7 (I2), so the literal stays.
- **The hum (2.5):** `HUM_DRAIN_PITCH` 0.08 in `world_audio.update_hum_levels()`.
- **The car (2.3):** moved to 3b with her voice (`voice.outside_car()`).
- Tested in `lurker_senses_test` (`systems()`, `main_duct()`): 29 checks.

## 3. Step 3b: her sound

### 3.1 The recordings (rows added to 2b's `tools/audio/prepare_lurker_sfx.py`)

The script, its helpers and the cue and shriek copies (`cue_0..2`, `scare_0..1`) are 2b's (9.3). Phase 3 adds rows, with these helpers if 2b's script lacks them: `pitch(x, ratio)` (ffmpeg `asetrate` + `aresample`), `lowpass(x, hz)`, `onsets(x, count, gap, pre, post)` (envelope over 5 ms, peaks above -24 dB of the maximum and at least `gap` apart, the `count` loudest, returned in time order, each cut `pre` before to `post` after), `mix(a, b, at, gain_db)`. Sources under `source_assets/oficinas/audio_criatura/<slug>/`, only entries with `"status": "ok"` in its `registro.json`. Every output gets a 4 ms fade in, 30 ms fade out, peak 0.7 unless said.

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
| `presence.wav` | `breath_cow_bodot`: `freesound_community-breath-of-cow-78843.mp3` | Pixabay | 20 s from 10 s, pitch 0.85, lowpass 3.5 kHz, 0.5 s crossfaded loop, peak 0.6 | her presence loop: only while she waits above a locker (0.5.3) |
| `bite_1.wav`, `bite_2.wav` | `bone_celery_bsb`: `bsb_1408_bones_cracking_2.mp3`, `bsb_1409_bones_cracking_3.mp3` + `bone_knuckles_crack`: knuckles onset 5 | CC0 + Pixabay | whole, pitch 0.8, the click at +0.05 s, -6 dB | the kill beat of her capture |

No cue and no shriek rows here: 2b's `cue_0..2` and `scare_0..1` are the only ones.

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
@export var aura_rise := 1.5            # dread_aura: the ear this far over its cue point (today's 1.5)
```

`lurker.tres`: `presence = sfx/lurker/presence.wav`, `volume_db = -14.0`, `audible_distance = 14.0`, `caption` = the author's text for her breath through the locker's slats (Pending, author 7; it must not be 2b's `"[Algo respira cerca]"`, which is the cue heard by others), `aura_start = 22.0`, `aura_full = 3.0`, `aura_breath = false` (0.5.2), `aura_clicks = [hard_2, tile_3, metal_2, wood_5]`, `aura_rise = 0.0` (her `presence_route()` already gives the point she sounds from: 3.5). `locust.tres` is not touched.

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
- **Where the presence sounds from** (`_process`, lines 586 to 595): `var voice_point: Vector3 = creature.voice_point()` instead of `creature.global_position + PRESENCE_RISE`, and `audible` also needs `creature.presence_on()`. The Locust's defaults give today's point and today's flag. For her, hanging from a ceiling, `global_position + 1.4` would be over the ceiling and inside a duct it would be the duct, not the grille.

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
const CAR_DB := -8.0
const CLEAN := 0.5                   # s before a cue's due time from which nothing of hers starts on the victim's machine (0.5.6)
const CAPTIONS := {"scare": "[Un chillido]", "ducts": "[Algo se arrastra por los conductos]", "tile": "[Cruje el falso techo]"}
const CAPTION_NEAR := {"scare": 16.0, "ducts": 10.0, "tile": 8.0}
var creature
var level
var quiet_until := -INF              # this machine's clock: set by lurker.play_cue() on the victim's machine (0.5.6)
func setup(owner) -> void
func material_at(point: Vector3, normal: Vector3, medium: StringName) -> StringName
func footfall(point: Vector3, strength: float, normal: Vector3) -> void
func travel(delta: float) -> void
func tile_shift(point: Vector3, dust := true) -> void
func shriek_heard(point: Vector3) -> void   # the caption only: the sound is 2b's scream()
func outside_car() -> void
func play_routed(path: String, point: Vector3, gain: float, cutoff := 20000.0) -> void
func play_direct(path: String, point: Vector3, gain: float, bus := &"Creature") -> void
var last := {}                       # {"path", "point", "bus", "material"} of the last sound, for tests (world_audio.enabled false included)
var history: Array = []              # the last 32 of `last` with their time, for tests
```

`medium` is derived from 2a: `&"duct"` while `motion.in_duct`, `&"plenum"` on a plenum patch (the shell's), else `&"room"`.

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

**`footfall(point, strength, normal)`**: connected to `visual.footfall` (3g adds the `normal` argument to `lurker_limbs.footfall` and `lurker_visual.footfall`; nothing else connects to them). Skips: within `STEP_GAP` of the last; `level.session.state != PLAYING`; the listener in an off-limits room (`level.point_protected(listener_position())`, OFICINAS 4: "Allí no se oye nada"); this machine's clock past `quiet_until - CLEAN` while a cue on this machine's player is open (0.5.6). Picks the set by `material_at()`, never the same file twice running, gain `STEP_DB[material] + lerpf(-6.0, 0.0, strength) + world_audio.duck_db()`, `soft` also `cutoff = SOFT_CUTOFF` and the `hard` set; `play_routed()`. Pitch `randf_range(0.9, 1.08)`.

**`travel(delta)`** (from `lurker._physics_process` while `medium != &"room"` and she is hidden, when no hand lands): in a duct, a knock every `maxf(0.18, 0.5 / speed)` s (speed: her duct speed now), `knock_1..8` round-robin without repeats, gain `KNOCK_DB`, and `scrape_1` every `SCRAPE_EVERY` s; in the plenum, a `tile_N` every `0.6 / maxf(speed, 0.5)` s at `CREAK_DB` and, crossing a gap tile (`ducts.exits` of kind `"gap"` within 0.6 m), `tile_shift(gap point)`. Caption `"ducts"` within its distance, with world_audio's caption cooldown. The same `quiet_until` rule as footfalls. Nothing while `hushed()` (the drop).

**`play_routed(path, point, gain, cutoff)`**: the route is `creature.sound_route_from(point, listener)` (3.5): in a duct through the exits (`bus = &"Ducts"`), in the plenum through the tile under her, in a room `world_audio.route_source(point, creature.get_rid())`. Not audible: nothing. Then `world_audio.apply_route(player, route, gain, "Threat", true)` (binaural; the route's `bus` wins), `attenuation_filter_cutoff_hz = minf(it, cutoff)`. `world_audio.last_event` is written as `play_at()` does, so tests see it.

**`tile_shift(point, dust)`**: `tile_creak_N` at `CREAK_DB` and, with `dust`, `dust_N` at `DUST_DB` 0.15 s later, and a dust puff: a `CPUParticles3D` (one shot, 40 particles, 1.6 s, grey, emitting from a 0.5 m square under the tile, gravity -1.5, not on any room layer of its own: `level.hotel.adopt()` it) freed after 3 s. Called by the `duct_in`/`duct_out` events with an exit of kind `ceiling` or `gap`, and by `travel()` over gaps. Caption `"tile"` within its distance.

**`shriek_heard(point)`**: 2b's world port `scream()` already plays `scare_N` everywhere (`world_audio.play_at` and `match_net.world_sound`). This only shows the caption `"scare"` within its distance (subtitles setting) on each machine, from the `"scare"` event (6.3).

**`outside_car()`** (3.8).

### 3.5 Where she is heard from (on top of 2a's `sound_route`, `presence_route`)

2a already routes a hidden duct out of the grilles (`ducts.sound_route`) and a surface through `world_audio.route_source()` / `aura.route_to()`. Phase 3 adds:

```gdscript
const PLENUM_LOSS := -6.0
const PLENUM_CUTOFF := 1800.0
func sound_route_from(point: Vector3, listener: Vector3) -> Dictionary   # 2a's sound_route(listener) becomes sound_route_from(face_point(), listener)
```

- `{"audible": false}` when the listener is protected (`level.point_protected(listener)`) or on another planta.
- In a duct: 2a's route with `bus = &"Ducts"` added; its `distance` is metres inside plus the mouth's route to the listener (asserted in 9.4).
- In the plenum over room R: a point `p` under her at R's ceiling minus 0.05; listener in R: `{audible, position: p, gain: PLENUM_LOSS, cutoff: PLENUM_CUTOFF, echo: false, distance}`; elsewhere `world_audio.route_source(p, RID(), listener)` with `PLENUM_LOSS` added and the cutoff capped.
- `presence_route(listener)`: `[INF, Vector3.INF]` with the listener protected; otherwise 2a's, with the duct and plenum cases above, and on a surface the opening point raised to her face's height (the aura's `aura_rise` is 0 for her, 3.2).
- **Never through a wall** (OFICINAS 9, AUDIO.md): every route ends at a point the listener can see (the mouth in their room, or the opening `route_source` finds). 9.4 case 6 holds it, on the real player's position (the `presence` player's `global_position`), not only on the route.
- Cost: `sound_route` is asked four times a second by `world_audio` and by each footfall; memoize the duct part per `(node, listener cell)` for 0.25 s like `world_audio.walked_route()` does (`ROUTE_MEMO`).

### 3.6 The dread aura (`dread_aura.gd`)

- `world_audio.set_creature(profile)` calls `aura.use_profile(profile)` (null: the defaults): `start_distance = profile.aura_start`, `full_distance = profile.aura_full`, `breath_enabled = profile.aura_breath`, `chitter_streams` = loaded `profile.aura_clicks` or `CHITTERS`, `rise = profile.aura_rise`.
- `apply_levels()`: the breath player plays only with `breath_enabled` (stopped otherwise); the ear (line 172) is `cue_point + Vector3.UP * rise` (1.5 today). Nothing else changes: `alarm_level()` from 2b's words, `hushed()` (×`HUSHED`, 2a's drop), the phantom point (her lies never set `world_audio.phantom_point`, 0.5.2).
- Hotel: `locust.tres` has the defaults: identical (`hotel_audio_test`, `spatial_audio_test` green).

### 3.7 The cue and the shriek

- **The cue is phase 2's** (2b 9): `brain.cue_started` → `match_net.send_cue()` → `lurker.play_cue()` → `world_audio.play_cue()` with the ears and the caption held, never under the fans' mask. Phase 3 adds no sound, no caption and no event for it. It adds two things inside `lurker.play_cue()`: on the victim's machine, `voice.quiet_until = now + hold` (0.5.6; cleared by `cue_over()`); and the signal `cue_played(seat, cue_id, point)` the bots react to (7.1).
- **The shriek is phase 2's sound** (2b 8.4 `scream()`). Phase 3 connects `brain.scared(cause, seat)` on the driving machine to `on_event("scare", [seat, cause, face_point()])` and `match_net.creature_event()` (6.3). On every machine `on_event("scare")`: `voice.shriek_heard(at)`; and `sanity.fright(level.player, SANITY_SHRIEK)` for the local player when alive, on her planta, within 12 m of `at` and with a clear line to it. Sanity is local on each machine (OFICINAS 5), so the event carries no target. New in `sanity.gd`:
  ```gdscript
  const SANITY_SHRIEK := 6.0
  ## A fright that is not a sight of it (her shriek): one per SANITY_SIGHT_REST, like the sights.
  func fright(body: Node3D, cost: float) -> void
  ```
  using the same rest and paid bookkeeping as `wear()` (lines 100 to 123). Never called on floor 1.

### 3.8 The car

`voice.outside_car()`: `metal_N` or `scrape_1` at `level.lifts.boarding.point + side * 1.3 + Vector3.UP * randf_range(1.0, 2.4)`, `side` the horizontal perpendicular of the riding camera's forward, alternating sides; `play_direct()` on `Creature` at `CAR_DB`: it is through the car's sheet on purpose, the one sound of hers not routed. (`boarding.car` indexes `arrival_cars`, and `level.hotel.lifts[car]` can be the lobby left behind, `lifts.gd:415-423`: never use it.)

---

### 3.9 Step 3b as landed (24 October 2026, director)

- **Recordings (3.1):** her rows as the table, in `prepare_lurker_sfx.py` (`sounds()`, run after the cues; the cues and shrieks come out byte-identical). The bite's knuckle is the fifth of `click_cuts()` on the knuckles (the warning's high-passed clicks): `onsets()` found only two peaks over -24 dB there. `presence.wav`: 20.5 s from 10 s, pitch 0.85, lowpass 3.5 kHz, cut to 20.5 s and its last 0.5 s crossfaded into its start: a 20.0 s loop. Picked by the script, unheard. The office rows for 3c's lies are not made yet. Registered in `docs/ASSETS.md` and `docs/asset_hashes.json`.
- **Profile and aura (3.2, 3.6):** as written; `caption` is the author's I7 proposal, "[Algo respira encima]". `dread_aura.use_profile()` from `world_audio.set_creature()`; the breath player stops while `breath_enabled` is false.
- **Duct bus and routes (3.3, 3.5):** as written. A grille's duct node is the grille itself (0.0 m on seed 81), so a duct route that ends in the listener's room already ends at the grille. `presence_route()`: nothing to a protected listener; on a surface the aura's point is raised to her face's height. The duct part is kept `ROUTE_MEMO` 0.25 s per node and listener's 2 m cell (`route_memo`). There is no plenum patch in the shell (M7's layer is the duct graph's gap and drop edges): her medium is `&"plenum"` while her nearest duct node is a `gap` node.
- **The voice (3.4):** `lurker_voice.gd` as written, but: no captions for her claws, knocks or tiles (the author's I6); only the shriek's (`SHRIEK_CAPTION` "[Un chillido]", 16 m). `quiet_until` is INF with no warning open. Every routed sound of hers takes its own player, at most `STEP_VOICES` at once. `travel(delta, speed)` makes nothing while she holds still (speed under 0.05). `history` notes every sound attempted, heard or not. `footfall` gets the hand's normal (`lurker_limbs.footfall` and `lurker_visual.footfall` carry it). There is no `duct_in`/`duct_out` event yet: `lurker.sound_step()` calls `tile_shift()` when `view().in_duct` changes within 1.5 m of a `ceiling` or `gap` exit, on every machine.
- **The shriek (3.7):** `brain.scared` calls `on_event("scare", [seat, cause, face])` on the driving machine only (the reliable event is phase 4's). Its fright is applied on the authority to every survivor on her planta within `SHRIEK_FRIGHT` 12 m with a clear line, not by each machine to its own player: `sanity.gd` keeps every mind on the authority (`wear()`, `minds`). `sanity.fright(body, cost)` uses `wear()`'s rest and paid bookkeeping; `SANITY_SHRIEK` 6.0.
- **The cue (3.7):** `play_cue()` sets `voice.quiet_until` on the victim's machine and emits `cue_played(seat, cue_id, point)`; `cue_over()` clears it.
- **The car (2.3, 3.8):** `lurker.sound_step()`: while `lifts.boarding.car >= 0` and her `view().drop`, `voice.outside_car()` every `CAR_SCRATCH` (drawn from the voice's rng, not hers).
- **Tests:** `tests/office/office_audio_test.gd` in verify's audio batch (seed 81). Not built of 9.4: case 4 (out of the ducts' reach: the fallback through the air can still be heard, so the check needs a room picked for it), case 9 on three wings with the mask compared in dB (one wing, the clean half second and the ears only), and the aura's ear position.

## 4. Step 3c: her lies

### 4.1 `lurker_hallucinations.gd`

Keeps the base API sanity and phantom_sight already call (`setup`, `false_call`, `quiet`, `walk_past`, `walk_start`, `sight_model`, `sight_poser`, `HEAD`, `BODY_BONES`) and adds what lets the creature choose its own lies:

```gdscript
extends Node
const OWN_LIES := true
## The cadence (Pending, author 3): placeholders that keep the hotel's until the author chooses.
const WAIT_SCALE := 1.0                      # × sanity's HALLUCINATION_WAIT draw, for her sound lies
const SIGHT_REST := Vector2(90.0, 180.0)     # her faces' rest; phantom_sight.REST today
const HEAD := "head"
const BODY_BONES := ["body", "abdomen", "upperarm_a.L", "upperarm_a.R", "forearm_a.L", "forearm_a.R"]
const VISUAL := preload("res://game/enemies/lurker/lurker.tscn")
const POSER := preload("res://game/app/hallucinations/lurker_poser.gd")
## Her own sounds no lie may play (decision 0.5.2): the cue, the shriek, the presence, the bite, and the station's bell.
const NEVER := ["res://assets/audio/sfx/lurker/cue_0.wav", "res://assets/audio/sfx/lurker/cue_1.wav", "res://assets/audio/sfx/lurker/cue_2.wav", "res://assets/audio/sfx/lurker/scare_0.wav", "res://assets/audio/sfx/lurker/scare_1.wav", "res://assets/audio/sfx/lurker/presence.wav", "res://assets/audio/sfx/lurker/bite_1.wav", "res://assets/audio/sfx/lurker/bite_2.wav", "res://assets/audio/sfx/office/tube_bell.wav"]
var level
var rng := RandomNumberGenerator.new()      # randomized in setup(); tests seed it
var told: Array = []                        # the last 32: {kind, point, time}
func setup(owner_level) -> void
func wait_scale() -> float: return WAIT_SCALE
func sight_rest() -> Vector2: return SIGHT_REST
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

`lie()` always records `told` (tests run silent), and plays only with `level.world_audio.enabled`. It never calls `world_audio.show_caption()`, `world_audio.play_cue()`, `hotel.drain()`, `hotel.set_room_power()`, an objective's `apply()`, `play_long(..., follow = true)` or anything that sends on the net. 2b's scan (no `"lurker/cue_"` outside `lurker_warning.gd`) covers this file: `NEVER` must name the cue clips by a path built so the scan does not match it (`BASE + "cue_%d.wav"`), or 2b's scan excludes this file by name; the director picks one (Pending, director 7).

### 4.2 `sanity.gd` and `phantom_sight.gd` hooks (the hotel's order of random draws unchanged)

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
- `phantom_sight.gd`: where `rest` is drawn (lines 81 and 162), `var span: Vector2 = lies.sight_rest() if lies.has_method("sight_rest") else REST` and the same one `rng.randf_range(span.x, span.y)` (line 81 keeps its `* 0.5`): one draw either way, the hotel's values unchanged.
- `lit_at()` asks `level.hotel.lit()` (0e does it; 3c checks it).
- `fright()` of 3.7.

### 4.3 The lies she tells (OFICINAS 5 and each planta's of section 3)

`kinds_here(gone)` keeps a kind only where its condition holds; `lie()` draws one by weight with `rng`. "Near" is walking metres (`world_audio.walked_route` length) unless said. **With the player in a protected room** (`level.point_protected()`: the freight lobby, the car), `garras` and `ducto` are never kept (OFICINAS 4: "Allí no se oye nada"; what is learnt keeps serving, OFICINAS 5).

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

The cue (its clips are in `NEVER`, and `play_cue()` is never called); the lights of a room trembling together (`lie()` never calls `drain()`; the `lampara` lie is one lamp); the interface, the sheet and the map (no captions, no UI); a station's bell with its lamp (`tube_bell.wav` in `NEVER`, no station lamp touched); the freight lift's tick (no follow cue, no tick while the red runs); the real fans (no `sound_mask`).

### 4.5 Her face where she is not (`phantom_sight.gd`, `lurker_poser.gd`)

- `phantom_sight.place(camera)`: `if lies.has_method("sight_spots"):` try `place_spot(spot, camera)` for each spot of `lies.sight_spots(self, camera)` in their order and return the first true (false if none); else the hotel's doors and corridor ends, unchanged.
- `sight_spots()` returns up to six spots, shuffled with `rng`, of three kinds (OFICINAS 5), each `{kind, point, yaw, up, side}`:
  - `"peek"`: the jamb of an open door 10 to 35 m off whose far room is not lit: on the far room's wall beside the jamb, 1.9 to 2.3 m up, facing the camera; `side` the lean towards the gap (as `place_peek()` computes `lean_side`).
  - `"partition"`: a cubicle `partition` (`room.furniture`, kind `"partition"`) 10 to 25 m off: over its top, head 0.25 m above it, body behind it.
  - `"corner"`: a ceiling corner of a room 8 to 20 m off in view: hanging upside down (`up = Vector3.DOWN`), face 0.35 m under the ceiling.
- `place_spot(spot, camera) -> bool` (new in `phantom_sight.gd`, used only through `sight_spots`):
  1. `kind` (phantom_sight's member, which `pose()` and `vanish()` already read) from the class: `"peek"` → `"peek"`; `"partition"` and `"corner"` → `"stand"`. So `pose()` gives `pose_peek()` to the first and `pose_stare()` to the other two, with no change to `pose()`.
  2. `model.global_transform = Transform3D(Basis.looking_at(-flat_to_camera, spot.up), spot.point)` (the model's +Z to the camera, its up `spot.up`); `lean_side = spot.side` for a peek.
  3. `pose(1.0)`, `face_point = poser.point(lies.HEAD)`.
  4. Accepted when `clear(eye, face_point)`, `lit(face_point, camera)` (the room it hangs in lit, or the torch on it) and, for `"peek"` and `"partition"`, `hidden_body(eye)`; else `kind = ""` and false.
  `haunt()` and `vanish()` are unchanged (they read `kind`, `face_point` and `lean_side` only through `pose()`).
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
## only, as a failing troffer does: the room's light dips by that lamp's share at most, the other
## lenses do not change. False when the room has fewer than two lamps.
func flicker_one(room_id: int, seconds: float, seed_value: int) -> bool
```

The lenses of a room are one `MultiMeshInstance3D` (`lens_of`), so one troffer's lens cannot be changed on its own. Instead: a quad of the troffer's lens size in the existing `lens_off` material, 2 mm under that troffer's lens (no collider, on the room's layers like the lens), shown and hidden by the same flicker pattern for `seconds`, and the room's light moved by `share = 1 / lamps` with a temporary entry in `flickers` (H5). Then the quad is freed and the entry removed. No new material (OFICINAS 11.8). It never calls `drain()`. For battens (`battens_of`) the same with a quad over the batten's tube.

---

### 4.7 Step 3c as landed, the sound lies (24 October 2026, director)

- **`lurker_hallucinations.gd`** in `game/app/hallucinations/` (beside The Locust's), as 4.1 without the faces yet: `sight_model`, `sight_poser` and `sight_spots` are the next unit, and until then `sanity.ensure_sight()` makes no sight for lies without `sight_model()`. `SIGHT_REST` is the author's I3, 40 to 90 s; `WAIT_SCALE` 1.0. `NEVER` is built from `BASE` (the director's 7: the fairness test's scan stays strict). What a lie leaves going is a `jobs` entry moved by `quiet()` (the phone until the listener is within 4 m or 8 s, the duct knocks, the tube's hiss, the fans' shape, the shadow). Walked candidates (`room_near()`, `desk_near()`) are kept `FOUND_KEEP` 2 s per listener's metre cell.
- **Kinds (4.3):** as the table. Rooms by the palette: `OFFICE.has_phone()` (3, 16, 24), `has_typewriter()` (3, 16, 17, 24), `has_copier()` (7). `ducto` is a random walk of 3 to 6 edges on the listener's planta from a node within 12 m, refused within 3 m of her real duct point; its knocks go out by `ducts.sound_route()` on the duct bus, as hers. `tubo` moves a looped `tube_hiss` long cue along `files.tube_path()` at the capsule's speed and stops it at 60 to 80 % (no bell, no station lamp). `persiana` uses `office_geometry.panes` (every blind's sheet), the room 0.6 m behind the pane on the far side not lit; the shadow is an unshaded quad with a square alpha gradient (its own material: it is not a light). `tictac` ticks from a planta 2 corridor cell centre, 6 to 20 m off and 6 m from every timer button. `garras` and `ducto` never with the listener protected.
- **`flicker_one()` (4.6)** on troffers only: a batten room returns false. The temporary `flickers` entry has no material and a `quad` (the dark lens, `lens_off`); `hotel_geometry`'s flicker loop skips a null material, shows the quad while the level is under 0.6, and makes such an entry chatter the whole time. The hotel's entries are unchanged.
- **Tests (9.5):** `tests/office/office_lies_test.gd` (its own script, not `sanity_test --floor=2`, so the hotel's test stays as it was), cases 1 to 6b, 8 and 9 (14 checks); the faces (case 7) come with the faces.

## 5. Step 3d: her capture (`lurker_capture.gd`)

### 5.1 The score belongs to the style (pure refactor first, the hotel byte-identical)

- `locust_capture.gd` gains `func score(): return SCORE` (capture_score.gd), `func kill_sound(_seed: int) -> String: return KILL_BLOW`'s path, `func kill_sound_at() -> float: return score().ARM_TIME` and `func kill_point(execution: Dictionary) -> Vector3: return creature_point(execution) + Vector3(0, 1.7, 0)` (today's, `executions.gd:334-335`).
- `executions.gd`: `func score(): return style().score()`; every `SCORE.` inside a function becomes `score().` (or a local `var beat = score()`): `stage_capture`, `apply_execution` (`HOLD_FAR`, `LIE_ROOM`), `scream`, `update_execution` (`ARM_TIME`, `KILL_TIME`, `DROP_TIME`, `FALL_LENGTH`, `END_TIME`), `place_victim` (`lift`, `limp`, `fall`, `turned`, `LIE_ROOM`), `move_camcorder`, `move_torch`. The kill sound in `update_execution()`: `time >= staged.kill_sound_at()`, `staged.kill_sound(seed)`, at `staged.kill_point(execution)`. The file constants `ARM_TIME`, `KILL_TIME`, `SIGNAL_TIME`, `DROP_TIME` and `ARM_SWING` stay (the Locust's) but no function reads them.
- `death_tape.gd` and `blood.gd`: the same, through `level.executions.score()`.
- `avatar_visual.gd` reads `SCORE.KILL_TIME` in `bleed()` (line 421) and in `pose_capture()` (674), and `LIFT_FROM`, `LIFT_TO`, `KILL_TIME` in `pose_capture()` (740 to 751). Her score has other times (`KILL_TIME` 3.15 against 3.3; `LIFT_TO` 2.6 against 2.7): `place_victim()` adds `"score": score()` to the state, `pose_capture()` reads `var beat = state.get("score", SCORE)`, and `bleed(since)` gains `kill_time := SCORE.KILL_TIME` that its caller passes from `score()`. The hotel passes its own score: the same numbers.
- `body_clip_probe.gd`: its `until` from `level.executions.score()`.
- Proof: `capture_test`, `creature_contract_test` and `body_clip_probe --strict` print the same lines before and after (keep both logs in the commit message's verification). This refactor needs Godot before and after, in series: one unit alone, never beside others.

### 5.2 `lurker_score.gd`

Standalone (a script cannot override a parent's constants): every constant and static function of `capture_score.gd`, same names, so a parity check (9.6) can compare the two maps. Values (seconds from the grab):

| Name | Value | Meaning here |
|---|---|---|
| `ENTRIES` | `["back", "above"]` | from behind (the main one); from above in a high room or an archive aisle (0.5.5) |
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

Functions as `capture_score.gd`'s, except `closing(time) -> 0.0` (never drawn in), `thrust(time)` = `ramp(time, ARM_TIME, KILL_TIME)`, `swipe(entry, time)` = `ramp(time, face_end(entry), face_end(entry) + SWIPE_LENGTH)` (the release), `face_start("above") = 0.0`, and the new `static func grab(time: float) -> float: return smooth(ramp(time, 0.0, GRAB))`. `lurker.capture_length()` returns `CUT_TIME` (5.4); 2b's `TAKE` reads it.

### 5.3 What the host decides (`stage_extra`, the payload)

- `executions.stage_capture()`: after building `data` (2b already adds `"cue"`), `var extra: Dictionary = style().stage_extra(body, placed)`; `if not extra.is_empty(): data["extra"] = extra`. `apply_execution()`: `if data.has("extra"): execution["extra"] = data.extra`. The Locust's `stage_extra()` returns `{}`: its payload and its `execution` are unchanged.
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
const HANG := true
const HIGH_ROOM := 3.0                           # m: "techo alto" for the entry from above (0.5.5)
func score(): return LURKER_SCORE
func kill_sound(seed_value: int) -> String: return BITES[seed_value % BITES.size()]
func kill_sound_at() -> float: return LURKER_SCORE.KILL_TIME     # the bite lands
func kill_point(execution: Dictionary) -> Vector3                # her face: the mask transform's origin at that moment
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

- `choose_entry()`: one `rng.randf()` (the side), always, as the Locust. `"above"` when all hold: the victim's room is higher than `HIGH_ROOM` (`palette.height_of(room)`) or the victim stands in an archive aisle; she is in front of the victim's view within 70 degrees (her flattened direction from the victim's eyes); the victim's camera pitch is under 30 degrees up (did not look up). `"back"` otherwise. Hidden victims never reach here (she never takes anybody out of a locker).
- Her capture lasts `CUT_TIME` and `executions.update_execution()` ends it at `capture_length() + 0.3` (5.7 s) as it does for the Locust.

### 5.5 Her body in the scene (`pose()`, the grips, the face upside down)

Every frame of the scene (`executions.update_execution()` calls `staged.pose(execution)`):

- `creature.global_transform = Transform3D(Basis(x, Vector3.DOWN, z), point)` with `point = creature_point(execution)` lowered by `0.25 * grab(t) * (1 - lift(t))` (she drops a little to take them, and goes back up with them), `z` = the victim's direction flattened (`creature_forward`), `x = Vector3.DOWN.cross(z)`. Her motion (2a) is held (`motion.hold()`) and does not write her transform while the scene lasts. Clip: `"loom"` during the face, `"scare"` never, `"idle"` after the drop.
- `visual.look_point = lens_point(execution)`; `visual.limbs.upright = 0.0` while the scene lasts (`lurker_limbs.gd` gains `var upright := 1.0`, the share of `UPRIGHT` applied in `_look()`; 1.0 is today's): the face stays upside down.
- **Grips** (`lurker_limbs.gd`): `var grips := {}`, limb name -> `{"point": Vector3, "normal": Vector3}`; a limb in `grips` takes that point as its hold every frame (planted, not swinging, no probe), else as today. `pose()` sets `grips = {"a.L": shoulder left, "a.R": shoulder right}` from `avatar.bone_point(avatar.bones.la)` and `.ra` of the victim's body (the avatar's upper-arm joints, the keys `body_clip_probe` uses), normal from her to the shoulder, while `grab(t) > 0` and `t < DROP_TIME`; cleared after. `unpose()` clears grips and sets `upright = 1.0`.
- **The swinging tile** (`SWING_TILE`, `extra.tile` not empty; OFICINAS 6: "una placa que se balancea"): at `t >= 0.2`, once, a `MeshInstance3D` named `"SwingingTile"` (a 0.6 × 0.015 × 0.6 box in `level.hotel.materials.ceiling_service`, the office's tile material too, `spec_f1_geometry.md` 5.2; no collider) hinged on the edge of `extra.tile` farthest from the victim, at the ceiling; angle `0.2 + 0.45 * exp(-0.4 * s) * cos(2.2 * s)` rad with `s` its seconds; added to `executions.leavings` (it stays the stage) and `level.hotel.adopt()`ed. The batched tile above it stays: the angle never closes under 0.15 rad, and the gap reads as dark.
- The avatar of the victim: `place_victim()` passes `"hang": true` into `avatar.pose_capture(state)` when the style has `HANG := true`. `avatar_visual.pose_capture()`: with `hang`, `over = Basis.IDENTITY` (not bent over an arm) and both upper arms raised 25 degrees about their side axis while `lift > 0` and `fall == 0`. Without the key: unchanged.

### 5.6 The tape (`death_tape.gd`)

- **Framing.** `facing()` reads `var framing: Dictionary = style.tape_framing() if style.has_method("tape_framing") else {}` and takes each value with the file constant as default. The keys and their constants:

  | Key | Unit | File constant (default) | Meaning |
  |---|---|---|---|
  | `far` | m | `MASK_FAR` | |
  | `held` | m | the held distance constant | |
  | `close` | m | the close distance constant | |
  | `near` | m | the near distance constant | |
  | `lunge_to` | m | `MASK_LUNGE` (0.082) | how far the mask comes at the lens |
  | `lunge_time` | s | `LUNGE` (0.07) | how long it takes; `0.0` disables the lunge (`coming = 0`) |
  | `back_dip` | m | `BACK_DIP` | used in `turning()` |

  The Lurker's: `{"far": 0.6, "held": 0.34, "close": 0.3, "near": 0.24, "lunge_time": 0.0, "back_dip": -0.12}` (her face is 0.36 m tall in the game: at 0.34 m it fills about nine tenths of the picture; "a un palmo"). `lunge_to` is not read when `lunge_time` is 0. The up vector stays `Vector3.UP` (she hangs head down, so her face is upside down in the picture; the code's `absf(ahead.normalized().y) > 0.85` branch is untouched). The implementer writes the constant's real name in each row before coding (lines 37 to 38 and 312 to 314 are `MASK_LUNGE` and `LUNGE`).
- **Rising.** After computing its transform `facing()` returns `style.tape_pose(execution, time, transform)` when the style has it. The Lurker's: with `k = score().lift(time)`, origin raised by `k * extra.lift * 0.9`, basis tilted up about its own x by `0.35 * k` rad: the picture rises into the dark of the ceiling.
- **The fall.** `plan()` copies `stage.get("look_up", false)` and `stage.get("ceiling", Vector3.INF)` into the scene for `camera_fall.solve()` (5.7). `fly_at()` = `face_end + SWIPE_REACH` = 2.4 from her score.
- `is_dark()` will ask `not level.hotel.lit(...)` for the room at `execution.from`. Phase 1 makes that change, not 0e (see the notes from step 0e in `spec_f1_systems.md`): `game/app/death_tape.gd` still reads `dark_ids`. 3c checks it.

### 5.7 The camera falls looking up (`camera_fall.gd`; OFICINAS 6)

- `enum { VIEW, PARTIAL, DOWN, UP }`, `NAMES` gains `"mira arriba"`. Constants: `UP_PITCH := Vector2(55.0, 84.0)`, `UP_ROLL := 18.0`, `UP_REACH := 1.2`.
- `solve()`: with `scene.get("look_up", false)`, every candidate spot is framed by `frame_up()` instead of `frame()`, and the fallback is `face_up()` instead of `face_down()`. Without the key: unchanged (same rays, same draws).
- `frame_up(space, scene, spot, side, rng, exclude) -> Dictionary`: `eye = ground + Vector3.UP * 0.05`; aim at `scene.ceiling`; `pitch = clamp(atan2(dy, flat), UP_PITCH)`; `roll = side * rng.randf_range(4.0, UP_ROLL)` degrees; `rest = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0)) * Basis(Vector3.BACK, roll), eye + up * 0.06)`. **The impact is never in the picture** (OFICINAS 6 and EXECUTION 5: the body falling may be seen, the blow may not): a spot whose view (`VIEW_HALF * 1.1` of the lens's forward) contains the landing point (`body` at 0.3 m up) or the last 0.5 m of the fall line above it is rejected, not scored. Score of the others: `+3` sees the ceiling point; `+1.5` sees `hold + up * (1.2 + lift)` (the body held up: the cause, "los pies que dejan el suelo"); `+2.4 * (1 - |flat reach - UP_REACH| / UP_REACH)`; the torch's beam towards the ceiling `+1.2`; `+ rng.randf() * 0.3`. Kind `VIEW` when it sees the ceiling and the held body, `PARTIAL` with the ceiling only.
- `face_up()`: at the owner's feet, lens up (`pitch` drawn in `UP_PITCH`), yaw turned away from the landing point (the landing point at least `VIEW_HALF * 1.1` off its forward), kind `UP`.
- `route()` and `pose()` are unchanged: the fall is the same physics to a different rest.

### 5.8 Blood (`blood.gd`)

- `snapshot()` adds `"style": staged`, `"feet": staged.drop_point(execution)`, `"extra": execution.get("extra", {})`.
- `held_at()`, `chest_at()`, `face_at()`: when `scene.style.has_method("blood_held")` (`"blood_chest"`, `"blood_face"`) return the style's; else today's formulas. `spill()` and `sounds()`: the style's `spill(scene, rng, drops, sparing, self)` / `blood_sounds(...)` when it has them (it calls back `blood.drop()` and `blood.scattered()`); `pool()` uses `scene.feet` (for the Locust `point + forward * HOLD_NEAR`, the same value).
- The Lurker's: no wound at the grab ("causa sí, impacto no"); at `KILL_TIME` a spray of 40 drops from the face held up (`blood_face`: the hold point + up * (1.58 + lift)), half upwards to the ceiling (speed 2 to 6 m/s) and half down to the floor round the feet; four pulses after the drop from the chest on the floor; sounds: the hotel's `SPRAY` at `KILL_TIME + 0.02` and `GUSHES` after the drop (no gush at the grab). With `sparing`, the spray only.

### 5.9 Who she catches, and the pairing

- Captures only come through 2b's gate (`may_capture()`: the ledger entry taken on this tick) and carry `execution.cue` (2b 2.2). `begin_capture(data)` is 2b's (`brain.on_captured`, `warning.captured(cue)`); phase 3 adds to it: her motion held, `visual.crawling` on (grips work), and one record in `lurker.takes` (an Array, not in the contract): `{seat, cue: int(data.get("cue", -1)), at: brain.clock, forced: not level.executions.forced.is_empty()}` (`forced`: tests and the clip probe, which the watchdog and 9.2 do not count).
- `end_capture()` (let go alive) is 2b's (`on_released`: `TAKE` → `FLEE`). Played to its end she flees by the nearest exit (2b's `TAKE`).
- The pairing every check uses (9.2 case 1, the watchdog 7.3, the batch 7.5), for each record of `takes` not forced: `cue >= 0`; the ledger entry with that id has `outcome == "taken"`, `seat == record.seat`, `captured == true`, `take_at` in `[due - EPS, due + TAKE_HOLD + EPS]`; and `WARNING.audit(capture_log())` is empty. A capture with no such entry is "unpaired".

---

## 6. Step 3e: the observer and the data formats phase 4 inherits

### 6.1 Gizmos (`draw_gizmos(g)`, layer 7)

- `observer_gizmos.gd`: `COLOURS` gains `"shell": Color(0.75, 0.55, 1.0)`, `"duct": Color(0.5, 0.5, 0.55)`, `"duct_path": Color(1.0, 0.8, 0.3)`, `"exit": Color(0.6, 0.8, 1.0)`, `"closed": Color(1.0, 0.3, 0.3)`, `"cue": Color(1.0, 0.2, 0.15)`, `"drain": Color(1.0, 1.0, 0.6)`; `shown["ducts"] = true`; `_process()` calls `draw_ducts()` (`layer = &"ducts"; creature.draw_gizmos(self)`) when `shown.ducts`. `observer_view.gd`: the layer keys go to `KEY_7` with `"ducts"` seventh; the header comment lists `7 los ductos`.
- `lurker.draw_gizmos(g)` (on top of 2a's legs and band profile), only where `g.here()`:
  - `&"path"`: the outline of her current patch in `shell`; a 0.5 m tick along her surface normal; the director's lead ring (`lead`); with `warning.active`, a line from her face to the victim's head and a ring round the victim of radius `0.3 + 1.2 * left / window`; each drained room a ring at its centre of radius 0.5, alpha the amount, in `drain`.
  - `&"sight"`: her dark sight (2b's range) as two cone edges from her eye, and a line to her prey while she sees them.
  - `&"ducts"`: every duct edge on the viewed planta in `duct` (main and cross edges thicker: drawn twice 3 cm apart), every exit as a mark in `exit` (`closed` while `ducts.closed`), her duct path in `duct_path`, her duct position as a ring.
- `debug_lines()`: 2b's (8.7) plus one line of what she drinks: `"  bebe 117 (0.62), 118 (0.41)"`. `debug_state()`: 2b's plus `"bebe"`.

### 6.2 `pack_state()` / `push_state()`

2a's format (8.3: `PACK_SIZE`, interpolation, `jump_id`, flags), with only what phase 3 and phase 4 need beyond it:

```text
[0 to 9: 2a's,
 10 state: int (lurker_brain.State value; -1 where there is no brain, as for a puppet before the first pack),
 11 prey seat: int (-1 nobody)]
flags: 2a's IN_DUCT 1, HIDDEN 2, SURFACE 4, DRAINING 8, CUE 16, plus SCARED 32 (RECOIL or FLEE)
```

`PACK_SIZE` becomes 12; `push_state()` ignores any other size (2a's rule). The Locust's 6-element array is unchanged; `match_net` only forwards arrays. Whether these two fields go in now or wait for phase 4 is the director's (Pending, director 6).

### 6.3 Reliable events (`match_net.gd`, the contract's `on_event()`)

```gdscript
## A moment of the creature every machine must hear of (docs/OFICINAS.md 11.6), told reliably by
## whoever drives it and applied by creature.on_event() on the others.
func creature_event(kind: String, data: Array) -> void:
	if in_match(): to_everyone(&"creature_event_rpc", [kind, data])

@rpc("any_peer", "call_remote", "reliable")
func creature_event_rpc(kind: String, data: Array) -> void   # the authority checks and relay of locust_call (lines 694 to 700); a puppet applies on_event(kind, data)
```

The kinds and their payloads (fixed now; phase 3 uses them offline, where the driving machine applies them itself and nothing is sent):

| Kind | Data | Applied |
|---|---|---|
| `"scare"` | `[by_seat: int, cause: String, at: Vector3]` | `voice.shriek_heard()`, the local `sanity.fright()` (3.7) |
| `"duct_in"`, `"duct_out"` | `[exit: int]` (index in `ducts.exits`) | `voice.tile_shift()` for ceiling exits and gaps |
| `"room_off"` | `[room_id: int, seconds: float]` | versus (phase 4): her drinking a room dark |

Not here, because they already have their reliable way: the cue and its end (2b's `cue_behind`, `cue_closed`), a circuit given (phase 1's `office_state`, with catch-up). Phase 4 adds the guest's claim `creature_claim(kind: String, cue_id: int)` ("la estaba mirando"); its name is reserved here.

**A late joiner** (`match_net.restore()`, phase 4's `office_late`): the catch-up for the creature is reserved as `save_state()` (2.7) plus the active ledger entry (`warning.active`, or `{}`), applied with `restore_state()`; a cue in hand is never replayed to the joiner, and phase 4's scenario checks that one joining during a cue never gets half a cue for its seat.

**PROTOCOL**: a new RPC changes the method table. Phase 1 (`office_*`), 2b (the cue RPCs) and this step all add methods before the floor-2 release: one bump in that stretch, not three (Pending, director 3). The four hotel net scenarios stay green.

### 6.4 Bot recordings

0a5 put the recording in the threat model (`bot_recorder.gd:172-212` calls `threat.recorded_row()`, `recorded_route()`, `recorded_watch()`, `recorded_mode_change()`, `on_gave_up()`; `bot_watchdog.gd:63` calls `threat.on_stuck()`; `CREATURE_FIELDS := 12`). `bot_threat_lurker.gd` implements those, with a 12-field row: `x, y, z, qx, qy, qz, qw, state (brain.State), prey, in_duct (0/1), near_node, cue_left`. No change to the contract or the recorder. `bot_replay` of a floor-2 recording places her by `x, y, z` and the quaternion (`replay_pose()`); its full puppet is phase 4.

---

## 7. Step 3f: the bots and the balance batch

### 7.1 `tools/bots/bot_threat_lurker.gd`

Registered in `tools/bots/bot_threats.gd` (0a5's factory) under `&"lurker"`. It has **every public member of `tools/bots/bot_threat.gd`** (the step starts with `git grep -n "^var \|^func " tools/bots/bot_threat.gd` and lists each one in the file's header with its meaning for her), so no caller fails at run time. The callers today: `bot_brain` (`activity`, `arrival()`, `audible()`, `busy`, `chase_earshot()`, `deaf_to()`, `destination`, `hostile`, `hunted()`, `landing`, `last_known`, `leaving()`, `lose_after()`, `lost_time`, `mode`, `near_planta()`, `novice`, `position`, `room`, `route_to()`, `searched_near()`, `time_to_sight()`, `torch_catches()`, `visible()`, `watched()`); `bot_nav` (`danger`, `near_planta()`, `position`, `room_cost()`, `watched()`); `bot_match` (`arrival()`, `audible()`, `deaf_to()`, `destination`, `near_planta()`, `novice`, `position`, `refresh()`, `time_to_sight()`); the recorder and the watchdog (6.4); `bot_replay` (`replay_pose()`, `replay_mode()`). Plus `mind()` and `wants_torch()`:

```gdscript
extends RefCounted
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const REACT := {"experto": 0.35, "novato": 0.9}   # seconds from the cue being played to the turn
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
var activity: StringName = &""            # creature.activity()
var planta := -1; var room := -1
var hostile := false; var busy := false
var lost_time := 0.0; var last_known := Vector3.ZERO; var destination := Vector3.ZERO
var landing := Vector3.INF                # she never comes out of a lift
var danger := {}; var search_points: Array = []; var future: Array = []; var vantages: Array = []
var state := -1; var prey := -1
var cues := {}                            # seat -> {cue_id, point, played_at}: from lurker.cue_played (3.7)
var guards := {}                          # worker seat -> guard seat
var cue_records: Array = []               # 7.5: one per cue played
func _init(owner_level) -> void
func refresh() -> void
func mind(brain, delta: float) -> Variant  # null: not its business this frame; bool: took the frame
func wants_torch(body) -> bool
```

- `refresh()` (a few times a second, as today): reads her through the contract and `lurker.brain` (state, prey, face point, in duct); `activity = creature.activity()`; `hostile` in `STALK`, `CREEP`, `CUE`; `busy` in `TAKE`; `danger` adds `COST_PATH` (60) to the rooms of her way ahead and `INF` to hers; `future` from her route ahead at her speed (duct speed in ducts).
- Her meaning for the members the callers read (the rest as the header list says): `hunted(body)`: she is in `STALK`, `CREEP` or `CUE` with that body as prey. `torch_catches()`: false (her torch is what saves). `exposed()`/`visible()`/`watched()`: the body's room not lit (`hotel.lit()`), within her dark sight of her eye, nothing between (mask 1 | 8 | 64). `audible()`: `creature.hear_route(point, radius).audible` (masked by the fans). `route_to()`/`arrival()`: her `travel_metres()` between the rooms, in metres and in seconds at her pace. `time_to_sight(point)`: the seconds for her to reach a spot within her dark sight of the point. `deaf_to()`: `busy` or the fans' mask over her. `searched_near()`: `creature.searched_lately(room of point)`. `lose_after()`: 2b's `forget`. `chase_earshot()`: `BRAIN.CHASE_EARSHOT`. `leaving()`: `FLEE` or `TRANSIT`. `room_cost(room)`: the Locust's formula over her `danger`. `on_gave_up()`/`on_stuck()`: never fire (she never gives up a chase the Locust's way; the watchdog's stuck test does not apply to a body that is hidden in a duct). `replay_pose()`/`replay_mode()`: 6.4.
- The bots react to **the cue played for their seat**, not to the brain's state: `lurker.cue_played(seat, cue_id, point)` (3.7) fills `cues[seat]`.
- `mind(brain, delta)`, in this order:
  1. **Cue on this bot**: on the first frame after `cues[this seat]` appears, draw `delay = REACT[skill] + rng.randf_range(-REACT_JITTER, REACT_JITTER)` and whether it turns (`TURN_CHANCE`); after `delay`, `brain.halt()`, `brain.face(point)`, `body.torch_wanted = true`; hold it until the cue is over (`cue_over`). True.
  2. **Cue on a teammate**: this bot within `MATE_REACH` of her with a clear line to her face turns and lights her after its own delay. True while it does.
  3. **Cover** (co-op): a teammate whose task kind is `"use"` (an office usable: typing, a tray, a lever, the console, the hatch) within `COVER_REACH`, with no guard yet: the nearest idle or walking bot becomes its guard: it goes to `worker stand - facing(worker yaw) * COVER_BEHIND` (the room side), faces away from the worker, torch on where not lit, until the worker's task ends or `COVER_MOST` s. True while guarding. The bot note `"cubre"` with both seats.
  4. **Looking back**: in a moving team of two or more on a planta, in a room not lit, the bot with the longest way to the team's goal looks back (`body.look_yaw += PI`) for `GLANCE_FOR` every `GLANCE_EVERY`; in the main duct it is the last crawler (the turn is slow there, `CRAWL_TURN_RATE`). Returns null (the walking goes on).
  5. Otherwise null: the brain's own flow (run from a hunt, go round where it is going).
- `wants_torch(body)`: false hidden; true where `hotel.lit()` is false at the body, while crawling, while a cue is on it, or (expert) when she is within 15 m.
- **What is recorded of each cue** (`cue_records`, for 7.5): at `played_at`, from the victim's body: the angle between its view and her face, and whether she is above (50 degrees up or more); the distance from its eye to her face; whether `world_audio.route_source(point, RID(), eye)` was audible from the victim (a route, not the direct fallback); `played_at - entry.at` (the delay to playing); the ledger's outcome and `take_at - played_at`.

### 7.2 `bot_brain.gd` hooks (no-ops with the Locust's threat, which has neither method)

- `mind_creature()` (line 702): right after the hidden branch, `if threat.has_method("mind"): var took = threat.mind(self, delta); if took != null: return bool(took)`.
- `wants_torch()` (line 1184): first, `if owner_match.threat != null and owner_match.threat.has_method("wants_torch"): return owner_match.threat.wants_torch(body)`. Its dark test reads `hotel.lit()` (0e).
- Lockers: unchanged (hiding is allowed; she waits on top).

### 7.3 Watchdog and tally

- `lurker.tally()`: `{"cues", "saves" (ledger "saved"), "captures" (takes not forced), "forced", "scares", "scares_torch", "scares_turn", "scares_mate", "peeks", "duct_trips", "unpaired" (5.9)}`, counted from the ledger, `takes` and her signals.
- `bot_watchdog.gd`: for a creature with `takes` (`"takes" in creature`), each new record not forced that fails the pairing of 5.9 is a grave incident `"captura_sin_aviso"` with seat and place; a non-empty `WARNING.audit(capture_log())` is a grave incident `"registro_injusto"`; a ledger entry still `"active"` past `due + TAKE_HOLD + 2 s` is a medium incident `"aviso_colgado"`.
- `bot_match.finish()`: `summary["creature"] = creature.tally()`, `summary["creature_kind"]` and the threat's `cue_records`.
- `tools/bots.ps1`: first check whether 0c already passes the floor (`--floor` in `bot_run.gd` and a parameter in `bots.ps1`); if not, `[ValidateSet(1,2)][int]$Floor = 1` passed as `--floor=$Floor` (`bot_run.gd` forwards it to `level.set_floor()` before `begin()`). Rows gain `cues`, `saves`, `scares`, `unpaired`; the summary line for floor 2: `Aviso: {0:N1} avisos y {1:N1} espantos por piso; {2:P0} de los avisos acaban sin captura; capturas sin aviso: {3}`.

### 7.4 `bots_test --floor=2`: the Lurker part

After phase 1's `office_part()` (null creature, no threat), a `lurker_part()` on a floor built again with the Lurker (seed 81, two expert bots, desafiante, `knowledge "oracle"`), staged:

1. Bot A sent to type at the window (`mail.desk`, a `"use"` task); bot B idle 8 m away. Within 10 s B's task note is `"cubre"`, B stands within 1 m of the guard point and faces within 30 degrees of away from A.
2. The Lurker forced to stalk A (`brain.force(&"stalk", {"seat": A.seat})`) from the dark ceiling 6 m behind A, B parked out of reach: a cue starts on A within 30 s; A's camera faces her within `REACT.experto + 0.4 s` of the cue being played, with its torch on; the cue ends `"saved"`; no capture.
3. A novice with its reaction forced to 3.0 s (beyond any window): the capture happens and passes the pairing of 5.9; the watchdog reports no `captura_sin_aviso` and no `registro_injusto`.

### 7.5 The balance batch (OFICINAS 15: "un lote de equilibrio con bots")

**Cost first.** The machine is the scarce thing (CLAUDE.md): the batch never runs beside `verify.ps1` or the net scenarios, and the director checks it fits the usage window before launching it.

1. Time one floor-2 run of three expert bots (`-Seeds 81 -Parallel 1`) and one floor-1 run for comparison; write both in `docs/DIFFICULTY.md`.
2. The first batch is short: 5 seeds (81..85) for each of the 12 combinations below, `-Parallel 4`. Its time, from step 1, goes in the request to the director.
3. The full batch (20 seeds, 81..100) only if the short one shows nothing to fix first and it fits the window.

```
./tools/bots.ps1 -Floor 2 -Bots 3 -Seeds <seeds> -Difficulty <d> -Skill experto -Parallel 4 -Label f2_<d>_exp
./tools/bots.ps1 -Floor 2 -Bots 3 -Seeds <seeds> -Difficulty <d> -Skill novato  -Parallel 4 -Label f2_<d>_nov
./tools/bots.ps1 -Floor 2 -Bots 1 -Seeds <seeds> -Difficulty <d> -Skill experto -Parallel 4 -Label f2_<d>_solo
```

for each of the four difficulties, after 3f and again after 3g, compared batch to batch in `docs/DIFFICULTY.md` (a "Piso 2" table: one column per batch). Starting bands, to be replaced by the first batch's numbers; a band missed is a finding to discuss with the author, not a test failure, except the hard rules (the first four rows):

| Measure | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| captures without a paired cue (5.9) and audits not empty | 0 | 0 | 0 | 0 |
| cues played from behind (angle ≥ 105°) or above, out of all | 100 % | 100 % | 100 % | 100 % |
| cues whose route to the victim was audible (not the direct fallback) | 100 % | 100 % | 100 % | 100 % |
| takes with `take_at - played_at >= window` | 100 % | 100 % | 100 % | 100 % |
| cue distance (her face to the victim's eye) | in 2b's `CUE_RANGE` | same | same | same |
| expert team won | ≥ 85 % | ≥ 70 % | ≥ 50 % | ≥ 30 % |
| expert team deaths per floor | ≤ 0.5 | ≤ 1.0 | ≤ 1.8 | ≤ 2.5 |
| expert saves / cues | ≥ 0.8 | ≥ 0.65 | ≥ 0.5 | ≥ 0.35 |
| novice saves / cues | ≥ 0.6 | ≥ 0.45 | ≥ 0.3 | ≥ 0.15 |
| cues per bot | 1 to 6 | 1.5 to 8 | 2 to 10 | 2 to 12 |
| scares per floor | ≥ 3 | ≥ 3 | ≥ 2 | ≥ 2 |
| cues on the bot farthest from the rest of its team ("va a por el que se queda atrás") | ≥ 60 % | ≥ 60 % | ≥ 60 % | ≥ 60 % |
| cues per minute on a guarded worker, over an unguarded one ("dos que se cubren...") | < 1/3 | < 1/3 | < 1/3 | < 1/3 |
| real peeks per bot and floor ("más asomos" in Apacible) | ≥ Equilibrada's | > Desafiante's | > Pesadilla's | |

The cue distance band is 2b's `CUE_RANGE` (1.6 to 3.2 m) while OFICINAS 4 says "a 2–3 m" (Pending, director 8).

---

## 8. Step 3g: performance (OFICINAS 11.8 and 13)

### 8.1 Measure first

`tools/benchmarks/hotel_benchmark.gd --lurker`: in the lit corridor `tools/capture/lurker_capture.gd` `pick()` chooses on seed 81 (move `pick()` to a static `tools/capture/lurker_spot.gd` both use), four still views of `STILL_FRAMES` each per quality: `lurker_none` (the same camera, no Lurker) and `lurker_1.5`, `lurker_4`, `lurker_10` (an instance of `lurker.tscn` on the corridor floor at that distance in front of the camera, crawling, moving ±0.5 m along the corridor at 1 m/s so its hands step). The report adds, per view, the frame's GPU and CPU means and p95 and `lurker_limbs.cost_usec` per frame (`static var cost_usec := 0`, the time spent in `_process_modification_with_delta`, reset by the bench). Run it before any change (baseline into `docs/PERFORMANCE.md`), after 8.2 and after 8.3. The bench runs alone (a window capture: the director or one agent at a time).

Targets at 1080p on the author's machine (Forward+), as deltas over `lurker_none`:

| Quality | 1.5 m | 4 m | 10 m | limbs < 8 m | limbs 8 to 18 m |
|---|---|---|---|---|---|
| Alto | ≤ 1.2 ms GPU | ≤ 0.6 ms | ≤ 0.3 ms | ≤ 0.15 ms CPU | ≤ 0.05 ms |
| Muy bajo | ≤ 0.8 ms | ≤ 0.4 ms | ≤ 0.2 ms | ≤ 0.1 ms | ≤ 0.05 ms |

Missed after 8.2 and 8.3: the fallbacks, in this order, are one step less per quality, no vapour from Medio down, and `rays = 1` under 8 m from Medio down. Also run it with `--rendering-method gl_compatibility` once.

### 8.2 The ink (`lurker_darkness.gdshader`, `bake_ink_noise.gd`)

- `tools/art/lurker/bake_ink_noise.gd` (`extends SceneTree`): a 64³ `Image.FORMAT_R8` stack: value noise on a lattice of period 16 (lattice values from the shader's old `hash()` at `i mod 16`, so it tiles), four texels per cell, smoothstep interpolated as the old `noise()`; saved with `ResourceSaver` as `ImageTexture3D` to `assets/enemies/lurker/ink_noise.res`. Deterministic; run once and commit. **First check** that an `ImageTexture3D` saved this way in Godot 4.7 loads back with its 64 images (`get_depth()`, one texel compared); if not, plan B: the 64 slices side by side in one PNG imported as `Texture3D` (`slices/horizontal = 64`).
- Shader: `uniform sampler3D ink_noise : filter_linear, repeat_enable;`, `uniform int steps = 10;`; `noise(x)` becomes `texture(ink_noise, x * (1.0 / 16.0)).r` (five reads a step instead of five value noises of eight hashes); `hash()` goes. The loop (line 100 today: `float dt = (t1 - t0) / float(STEPS);`): **`float dt = (t1 - t0) / float(steps);`**, then `for (int i = 0; i < 10; i++) { if (i >= steps) break; ...; if (sum * density > 3.912) break; }` (alpha 0.98 is `1 - exp(-3.912)`). With `dt` from `steps`, every quality integrates the whole ray: fewer steps are coarser, never thinner ink (OFICINAS 13: no quality gives an advantage).
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
- `lurker.gd`: `apply_quality()` (contract, 0a5) calls `visual.set_quality(level.settings.values.quality)`, also once in `_ready()`. Every `_process`, with `camera = get_viewport().get_camera_3d()` (whichever camera draws: the player's, a teammate's that a dead player watches, the observer's): `visual.set_hidden("duct" if motion.hidden else "planta" if FLOOR.planta_of(camera.global_position.y) != FLOOR.planta_of(global_position.y) else "")`. `motion.hidden` is 2a's (hidden duct segments and the drop; she is seen on `main` and `cross` segments, OFICINAS 4: "por él viene detrás de quien huye"). `set_hidden()` replaces 2a's direct writes to `Visual.visible` and `Visual.process_mode`, with the same effect.

### 8.3 The hands (`lurker_limbs.gd`)

- `var rays := 2`. In `_process_modification_with_delta()`: the round-robin probes per frame are `rays` (2, 1 or 0); an unplanted hand probes with rays only when `rays > 0`; with `rays == 0` it probes the analytic planes (`_probe_planes()`, below) and costs no ray. `_clear_elbow()`: every frame with `rays == 2`, every other frame with `rays == 1` (the other frame keeps `elbow_turn`), never with `rays == 0`.
- `var planes: Array = []` of `{"point": Vector3, "normal": Vector3}`, set by `lurker.gd` every 0.25 s from the shell (`shell.planes_near(global_position)`: the floor, the ceiling, the walls of her room and the walls of a channel; if the shell has no such function, from `FLOOR.room_at()`, `palette.height_of()`, `ROOM_LAYERS.rect_of()` less `WALL_HALF`, and the archive rows). `_probe_planes(limb, ...)`: the same eleven directions as `_probe()`, intersected with the planes instead of the world, the same scoring.
- `signal footfall(point: Vector3, strength: float, normal: Vector3)` with `limb.to_n`; `lurker_visual` passes the three on.
- `static var cost_usec := 0` (8.1). 2a's `replant()` is kept.

### 8.4 Her face on Muy bajo

- `hotel_geometry.follow_bodies()` (0e uses `put_on_actor()` only for meshes with the meta `"follow_rooms"`; 3g must set that meta on her face, eyes and teeth (not on the ink) and put her body in the group `hotel_actors`, which `follow_bodies()` walks; nothing does either yet, see `spec_f2_movement.md`, from step 0e): `var meshes: Array = body.layer_meshes() if body.has_method("layer_meshes") else body.find_children("*", "GeometryInstance3D", true, false)`. `lurker.gd`: `func layer_meshes() -> Array: return visual.layer_meshes()`. Her model then carries the room's bit beside value 4, and on `static_light` the room's lamp lights her face, eyes and teeth; the ink (unshaded) keeps value 4 alone. `light_body()` likewise (4.5).
- Checked in 9.1 case M and in the capture `tools/capture/lurker_capture.gd --preset=4` (add the option: `level.settings.set_designed(int)` before the shots) beside the same shot on Alto: her face reads in both.

---

## 9. Tests

Every test: `extends SceneTree`, `check(title, passed)` as `hotel_test.gd`, evidence JSON in `res://evidence/<name>.json`, exit code 1 on any failure. Floor 2 tests build with `level.set_floor(2)` then `await level.start_floor(81, false, [1], "desafiante")` unless said, `level.ui.finish_intro()`, director freed (`level.director.queue_free()`) unless the case needs it. Rooms are found from the manifest by palette ids, the first by ascending id that qualifies, so every run picks the same ones. "Frozen" means `lurker.thinking = false`, `creature.set_physics_process(false)` where her motion must not run, and placed with 2b's `place_on()` or `teleport()`; states are forced with 2b's `brain.force()` (CUE and TAKE cannot be forced: a cue is obtained by forcing `CREEP` with her placed 2.4 m behind the victim, as 2b's fairness test does). Only the Godot runs a unit's brief names, headless, short; the units that run in parallel do not run Godot: their reviewer does, in series.

### 9.1 `tests/office/office_survival_test.gd`

| Case | Setup | Checks |
|---|---|---|
| A spawn | as built | `creature.kind_id() == &"lurker"`, its scene path `== office_floor.CREATURE`; `grace == tuning().grace`; she starts where phase 2's den rule says (the rule the director kept), not in an off-limits room; `world_audio.profile` is `lurker.tres`; `world_audio` has the `Ducts` bus sending to `Creature`; `--creature=none` (second build) gives the null creature |
| B tuning | `set_difficulty` to each of the four | `brain.window`, `lit_takes`, `duct_speed`, `stalk_distance`, `freeze_time`, `scare_calm`, `creep_scale`, `drain_reach`, `peek_every` equal 2b 4.1's; the director's `encounter_every`, `cross_weight`, `raps_weight` equal the profile's (2b 4.2 and 0.4) |
| C off-limits | her led towards the freight lobby (`lead_to(lobby centre, 4, 20, "merodea")`), physics on 20 s | `lead_to` returned false or `FLOOR.room_at(her)` is never an off-limits room (sampled every 0.25 s); never a duct node of an off-limits room |
| D drain | frozen 1.5 m under a troffer of the first lit wing-0 open office (type 1) | within 0.5 s `hotel.drained(room)` in `[DRAIN.x - 0.01, DRAIN.y + DRAIN_WOBBLE + 0.01]` and `hotel.lit(room)` still true; a lit room 6 m or more away has 0; moved 10 m away, back to 0 within 1.0 s; a hum player assigned to that room had `pitch_scale < 1.0` while drained and was still playing |
| D2 the light still counts | the same room lit, her hanging 1 m from a troffer centre (drained ≥ 0.6); the player 6 m away looking at her face, torch off; `brain.force(&"stalk", {"seat": 1})`, mind on | within 0.5 s `brain.state == FREEZE`; no ledger entry in 5 s |
| E herding | wing 1: a corridor cell of circuit 0, frozen on its ceiling, then mind on; `power.apply("lever", 0, 1, {}, false)` | within 4 s she is in a duct or in a room not lit; an event `"duct_in"` was applied; a tile shift was heard (`voice.history` has a path with `tile_creak_`) when the exit was a ceiling one |
| F fans | wing 2, in a duct of the planta at a known duct distance `m` from the nearest exit; `air.fan_time = 5.0`, `air.apply("start", 0, 1, {}, false)` | after the spin-up `ducts.closed` is true; she starts leaving within 1 s and is out by `m / duct_speed + 1 s`, by the exit nearest by duct metres (± one exit); while closed she never re-enters; after the stop she is back in a duct within 10 s |
| G main duct | wing 2, the hatch opened (1g's case setup), the player crawling 2 m before the crossing, her stalking from the plant | she does not take the `cross` edge while the player is before the crossing; once the player is 2 m past it she may (the route filter allows it) |
| H crawl window | the same, a cue on the crawler | the entry's `window` equals `back_window` (or `back_window` plus the extra, if the author adopts one: Pending, author 4) |
| I plantas | the stage crossed to 2 by the real flow (`stages_test.cross_to_stage` pattern) | `in_transit()` true after the car leaves; while the player rides and `transit_phase() == &"drop"`, an `outside_car` sound at least every 1.3 s (`voice.history`), the first within 1.3 s of the drop; after the transit she is on wing 1, where phase 2's arrival rule puts her |
| J given back | a stage given back (`revival`) | she is at `den_point(stage)` ± 0.05, no prey, every `spurned` cleared, grace ≥ the revival's rest, no active ledger entry |
| K locker | the player hidden in the first wing-0 locker, `brain.force(&"wait_above", {"seat": 1, "hide": locker})` | `brain.state == WAIT_ABOVE` within 20 s on that locker; `world_audio.presence` playing (0.5.3); `player.sanity` falls as in a wardrobe; after 30 s the locker was never opened by her; when she leaves, a knock is heard |
| K2 no breath elsewhere | her forced to `STALK` and then `CREEP` (2b) 4 m behind the player, dark | `world_audio.presence` not playing in either |
| L safe places | the player in the freight lobby (19), then in the car | 30 s of forced stalk each: no ledger entry, no capture |
| M face on Muy bajo | quality 4 (`settings.set_designed(4)`), her frozen in a lit room | after 3 frames her model meshes have value 4 and the room's bit (`ROOM_LAYERS.ROOMS & layers != 0`); the ink and vapour have `layers == 4` exactly |
| N ink and hands | the camera 20 m away; then 5 m; then her in a hidden duct; then on a `main` duct segment; then the camera on another planta; then a second camera (a teammate's, made current) on her planta | far: vapour hidden, `steps == 4`, `limbs.rays == 0`; 5 m: `rays == 2` on Alto, 1 on Bajo; hidden duct and other planta: `visual.visible == false`; main segment and the teammate's camera: visible |
| O continue | her in a duct at node k; a 20 s spurn on seat 1; `floor_save.take()`, a floor built again from the same seed (`continue_test` pattern), `give()` | in a duct at node k; on a ceiling patch: same patch, (u, v) ± 0.05, same hang; the spurn kept ± 0.1; saved in transit: the transit restarted to the same wing; the power objective's zones (phase 1) kept with her |
| P director | the director on | `director.reach(a, b) == creature.travel_metres(a)[b]` for a pair joined by a `loose` duct link, and it is less than `director.walk(a, b)`; a `"cruce"` lead is accepted (`lead_to` true) in `ROAM` |

### 9.2 `tests/office/office_capture_test.gd`

| Case | Setup | Checks |
|---|---|---|
| 1 from a cue | the player in the first dark wing-0 room (not lit), torch off, back to her; her frozen on the dark ceiling 6 m behind, then `brain.force(&"stalk", {"seat": 1})` and mind on | a cue within 20 s; the capture starts on the tick the entry is taken; the pairing of 5.9 holds (`entry.seat == 1`, `take_at` in `[due, due + TAKE_HOLD]`, `execution.cue` is that `"taken"` entry, `captured`, `audit()` empty); `execution.entry == "back"` |
| 2 style | the same capture | `executions.style()` is `lurker_capture.gd`, `score()` is `lurker_score.gd`, `capture_length() == 5.4`, the execution ends at 5.7 ± 1 frame |
| 3 hang and lift | the same | `execution.extra.hang.y` within 0.1 of the room's ceiling; `extra.lift <= ceiling - floor - 1.85 - 0.12 + 0.01`; the victim's feet rise by `extra.lift` ± 0.05 at `LIFT_TO` and are on the floor ± 0.1 after `DROP_TIME + FALL_LENGTH` |
| 4 the face upside down | the same, sampled during [face_start + 0.1, face_end - 0.1] | `camera.global_basis.y.dot(mask.basis.y) < -0.5`; lens to face in [0.24, 0.6] m |
| 5 looking up | ten forced captures (`executions.forced = {entry: "back", seed: n}`, n = 1..10) in ten rooms (the first ten wing-0 non-corridor rooms) | `tape.take.rest` forward has `y > 0.5` in all; kind is not `DOWN`; the landing point and the last 0.5 m of the fall line are outside `VIEW_HALF` in **all ten** |
| 6 the tile | case 1's capture | `executions.leavings` holds a `SwingingTile`; its rotation differs by more than 0.05 rad over 1 s; none in a room without a false ceiling |
| 7 the body stays | case 1, to its end | seat 1 is dead; the avatar is visible at the drop point, its hips under 0.5 m over the floor |
| 8 blood | gore on, then off (`settings.values.gore`) | on: one record, more than 10 stains, some on the floor within 1.5 m of the drop point, none within 0.3 m of her; off: no record |
| 9 sounds | case 1 with `world_audio.enabled` and events logged | a bite path (`lurker/bite_`) at `kill_sound_at()` (her `KILL_TIME`) ± 0.05, its position within 0.3 m of her face (`kill_point()`), not over the ceiling; a `BODY_FALL` at `DROP_TIME + 0.85 * FALL_LENGTH` ± 0.05 |
| 10 above | the boardroom (type 5) or the first room higher than 3.0 m; the player looking ahead (pitch 0); her on the ceiling 2 m in front | `choose_entry` gives `"above"`; `face_start("above") == 0.0`; the camera still falls looking up |
| 10b not above | a 2.95 m open office, the same staging | `choose_entry` gives `"back"` |
| 11 let go | `release_execution()` at 1.0 s | the victim alive, `player.held` false, her state `RECOIL` or `FLEE` (2b's `on_released`), no blood record kept, grips cleared, `limbs.upright == 1.0` |
| 12 no capture | the player in the freight lobby; then in a lit room at Apacible after a forced stalk | 15 s each: no capture, no ledger entry |
| 13 the hotel | floor 1, one forced capture | `style()` is `locust_capture.gd`, `score()` is `capture_score.gd`; `kill_sound_at() == ARM_TIME`; the execution has no `"extra"` and no `"cue"`; `death_tape` used its own constants (`tape_framing` absent) |
| 14 payload | case 1's `data` (spy on `apply_execution`) | `execution.extra == data.extra`; `execution.cue == data.cue` |
| 15 hands in the picture | case 1, the tape's camera projected | both grip points (`grips["a.L"]`, `grips["a.R"]`) enter the tape's frame through its left and right thirds before `face_start`; the frames of the tape at 0.2, 0.6, 1.2, 2.0, 2.8 and 4.5 s saved for the author by `tools/capture/execution_capture.gd --floor=2` (entries `back` and `above`, three rooms) |

### 9.3 `tools/dev/body_clip_probe.gd --floor=2`

- `run()`: with `options.floor == "2"`, `level.set_floor(2)` before `start_floor`; the staging room is the largest wing-0 room with a false ceiling; her placed with `creature.place_on(creature_at, &"ceiling", victim)` and `lurker.thinking = false` (`put()` asks the contract only on floor 2; floor 1 keeps its Locust lines, including `Mode.PATROL`, line 73); `executions.forced` as today.
- The probe assumes a creature standing on the floor: its ray origin is `level.locust.global_position + UP * 1.1` (line 96) and its floor is `level.locust.global_position.y - 0.04` (line 122). On floor 2: the origin is the victim's hips (`avatar.bone_point(avatar.bones.hips)`) and the floor is `execution.from.y - 0.04`. Floor 1 keeps both lines.
- Stages: open, back to wall (0.4, 0.7, 1.2), it against wall, along each side wall, corner, for entries `"back"` and `"above"` (no `"side"`, no wardrobes; `"above"` in the boardroom); three doorways (`"back"`, under the 2.65 m lintel); new `"aisle"`: the first archive aisle's centre (wing 1), `"back"` and `"above"`.
- The `"top"` joint against the ceiling and the lintel is what this floor adds; `LIMIT 0.04` unchanged; `--strict` fails on any fault. The floor-1 run prints the same lines as before.

### 9.4 `tests/office/office_audio_test.gd` (real clock, batch 3)

Setup: floor 2, seed 81, settings `master 0.8`, `threat 0.85`, `effects 0.8`; her frozen. `R` = the first wing-0 open office with a `"ceiling"` exit `E`; she is placed in the duct at `E`'s node (2a's `place_in_duct`); the listener is the player's camera at `R`'s centre.

| Case | Checks |
|---|---|
| 1 bus | `Ducts` exists once, sends to `Creature`, has the EQ and the reverb |
| 2 out of the grille | `sound_route(listener)`: audible, `position` within 0.02 of `E.point`, `bus == &"Ducts"`; after 0.5 s `world_audio.presence.bus == "Ducts"` is not required (the presence is off outside `WAIT_ABOVE`), but a knock played by `voice.travel()` has its player at `E.point` ± 0.02 on bus `Ducts` |
| 3 a room of its own | the listener moved to an adjacent room `Q` with its own exit, farther along the ducts: the position is `Q`'s exit |
| 4 out of reach | the listener in a room whose duct metres from her exceed 40: not audible |
| 5 other planta | the listener on wing 1: not audible |
| 6 never through a wall | 20 listener points (every room centre of wing 0 in id order, the first 20): wherever audible, the knock player's real `global_position` is not occluded from the listener (`world_audio.occluded(player position, RID(), listener)` false) |
| 6b protected | the listener in the freight lobby: `sound_route` and `presence_route` not audible; 30 s of her duct travel and two `garras` lies forced: no player of hers started |
| 7 real audio | an `AudioEffectCapture` on `Ducts`; her duct knocks forced for 1 s (`voice.travel()` with a speed): peak > 1e-5 with the listener in `R`; < 1e-6 on wing 1 |
| 8 surfaces | `voice.footfall(point, 0.8, normal)` with her medium set: ceiling of `R` → `tile_`; in a duct → `knock_`/`metal_`; a block wall (a corridor, `wall_material == "block"`) → `hard_`; a wing-2 type-16 wall (`veneer`) → `wood_`; that room's carpet floor → `hard_` with cutoff ≤ 1200 and gain 8 dB under the plain hard step |
| 9 the cue, unmasked | on wing 0, 1 and 2: her placed 2.5 m behind the player in a dark room, `brain.force(&"creep", {"seat": 1})`; an `AudioEffectCapture` on the bus the cue plays on; once with the fans stopped and once with `air.spin == 1` (wing 2; on wings 0 and 1 a forced `sound_mask` of 1.0 at the player) | `world_audio.last_cue.path` contains `lurker/cue_`, `mine`, its point within 0.1 of her face; with subtitles on, the caption is 2b's `CUE_CAPTION`; the cue's peak with the mask and without it within 1 dB; `world_audio.ears_hold.point` within 0.1 of her face for the clip's length; no footfall, knock or tile of hers started in `[due - 0.5, end of the cue]` (`voice.history`) |
| 10 aura | her in a duct 10 m from the listener: `aura.cue_point` within 0.05 of an exit point; `aura.route_distance` within 0.5 of the route's distance; the aura's breath player is not playing; the aura's ear within 0.05 of the exit point (`aura_rise` 0) |
| 11 hum | her drained room has a hum: its `pitch_scale` < 1 and it plays |
| 12 the presence | her placed on a ceiling 3 m from the listener, `STALK`: `presence` not playing; forced `WAIT_ABOVE` on a locker 3 m away: playing, its `global_position` within 0.3 of the locker's top (not over the ceiling) |

### 9.5 `tests/hotel/sanity_test.gd --floor=2`

Without the argument the test is today's. With `--floor=2`, an `office_part()` instead (the creature frozen 80 m below as today, `lies.rng.seed = 81`):

| Case | Checks |
|---|---|
| 1 own lies | `sanity.creature_lies()` is `lurker_hallucinations.gd`; `lies_tell_own()` true |
| 2 cadence | sanity 30; 50 draws of `hallucinate()` with `hallucination_wait` forced to 0 each time: every new wait in `[lerpf(42, 13, gone) * 0.7, lerpf(42, 13, gone) * 1.3] * WAIT_SCALE`; the faces' rest drawn in `sight_rest()` |
| 3 kinds per planta | 200 `lies.lie(point, 0.8)` with the player on wing 0, then 1, then 2 (power and air states set for each condition): every kind is in 4.3's table for that planta; `tubo` and `telefono` appear on wing 0, `palanca` and `tictac` on 1, `ventiladores` and `ducto` on 2 |
| 4 never | over those 600 lies (spies installed before): `hotel.drain` never called; `world_audio.play_cue` never called; no path of `NEVER` played; no station lamp lit and no `tube_bell`; the power objective's state unchanged and no follow cue in `world_audio.long_cues`; `air.sound_mask()` 0 throughout; `world_audio.caption_text` never set |
| 5 one lamp | a `lampara` lie in a room with n ≥ 2 lamps: that room's light energy dips by at most `1/n` of it; the room's lens `MultiMeshInstance3D` material unchanged; the quad is gone after 1.2 s |
| 6 conditions | the red lever running; the fans running: no `tictac`; no `ventiladores` and no `ducto` on wing 2 |
| 6b protected | the player in the freight lobby: no `garras` and no `ducto` in 200 lies |
| 7 the face | `ensure_sight()`: the model has a `Skeleton3D` and the lurker visual; `poser.point("head")` is finite; with a dark door, a partition and a ceiling corner staged in view, `place()` returns true for each kind; `pose()` played `"peek"` for the door and `"idle"` (stare) for the partition and the corner |
| 8 locker | hidden in a locker 2 s: sanity falls at the wardrobe's rate |
| 9 drained | a room drained at 0.6 by her: `lit_at()` still true there (2b's threshold) |

### 9.6 `tests/hotel/creature_contract_test.gd` (a Lurker section) and `difficulty_test.gd`

- Every method of `creature.gd` is overridden or knowingly inherited by `lurker.gd` (a list in the test); `can()` is true only for `&"ducts"`; the Locust's `voice_point()` equals `global_position + PRESENCE_RISE` and `presence_on()` is true.
- `pack_state()` → `push_state()` on a second instance gives the same position, quaternion (± 1e-4), state, flags and near node; `save_state()` → `restore_state()` likewise (2.7).
- `lurker_score.gd` has every constant and static function `capture_score.gd` has (`get_script_constant_map()` keys and `get_script_method_list()` names), plus `GRAB` and `grab`.
- `lurker_hallucinations.gd` has `OWN_LIES`, `WAIT_SCALE`, `SIGHT_REST`, `NEVER`, `lie`, `kinds_here`, `wait_scale`, `sight_rest` and the base API.
- `locust_capture.score()` is `capture_score.gd`; `kill_sound_at() == executions.ARM_TIME`.
- `bot_threat_lurker.gd` has every public member of `bot_threat.gd` (names from `get_script_method_list()` and `get_script_property_list()`).
- `difficulty_test`: 0.4's key; none of it in the Locust's profiles.

---

## 10. `tools/verify.ps1`

- `$tests` gains `'office/office_survival_test'`, `'office/office_capture_test'` (batch 1) and `'office/office_audio_test'` (batch 3: add it to the `$audio` names beside `hotel_audio_test` and `spatial_audio_test`).
- `office_test`, `office_stages_test`, `office_geometry_test` and phase 1's bots check with `--floor=2` get `'--creature=none'` in their user args.
- Two second runs of existing scripts, each with its own profile files (`--profile-tag`, already read by `hotel_main.gd:191`), each after setting `$log` as the neighbouring lines do, with the rule, batch and log `Add-Check` takes (`verify.ps1:31`):
  - `Add-Check 'hotel/sanity_test' 'sanity_test_office' (Godot-Arguments 'res://tests/hotel/sanity_test.gd' $log $true @('--automation','--test-profile','--silent','--floor=2','--profile-tag=office')) 360 'plain' 1 $log`
  - `Add-Check 'dev/body_clip_probe' 'body_clip_probe_office' (Godot-Arguments 'res://tools/dev/body_clip_probe.gd' $log $true @('--test-profile','--strict','--automation','--silent','--floor=2','--profile-tag=office')) 480 'plain' 1 $log`
- The count of green lines grows by five.
- **Time.** `verify.ps1` takes 5 to 8 minutes today. Before adding these, the director measures each new check alone (phase 2 adds `lurker_shell_test`, the route probe, `lurker_senses_test` and `lurker_fairness_test`; phase 3 these five) and writes the total added to `verify` in the step's commit; if phases 2 and 3 together add more than 3 minutes, the slowest checks go to a second list run at phase close.

---

## 11. Docs (Spanish; no «·» or «—» in anything the game shows)

- `docs/LURKER.md`: "Lo que falta" becomes what exists: how she sounds (by surface, in the ducts, the cue and the shriek of phase 2), her capture, her lies, her cost and its levels; the commands of the bench with `--preset=4`.
- `docs/OFICINAS.md`: section 14 gets the decisions of 0.5 as "decidido por los agentes, pendiente del autor"; section 15 the verification of phase 3 as done, with the batch's numbers. Sections 1, 3, 4, 5, 6 and 11.3 are not edited here: what this review found in them goes to the author (Pending).
- `docs/DEVELOPMENT.md`: the score per capture style and its hooks (`kill_sound_at`, `kill_point`, `stage_extra`, `tape_framing`, `tape_pose`, `blood_*`, `spill`, look-up rests), `voice_point()` and `presence_on()`, the `Ducts` bus, `creature_event` and its kinds, the pack fields added, the bots' threat for her.
- `docs/AUDIO.md`: her sounds and the duct bus; lies never captioned; the clean half second.
- `docs/DIFFICULTY.md`: the key `raps`, the batches and their times.
- `docs/PERFORMANCE.md`: the Lurker's scenario, before and after.
- `docs/ASSETS.md`, `docs/asset_hashes.json`, `hotel_ui.gd CREDITS`: 3.1.
- `docs/PLAN.md` section 4: section 14's waiting list.
- `docs/textos_juego.txt`: the captions of 3.4 and the profile's (once the author gives it).
- `docs/CHANGELOG.md`: nothing until the floor is released (phase 5).

---

## 12. Order of work

**Before any unit is cut** (the director): 0b to 0f, phase 1 and phase 2 landed and green; phase 2's two specs reconciled (Pending, director 1); the author's answers to the questions that change code here (Pending, author 1 to 4). Then a map from file to unit, with one acceptance test per area, written from the code as it then is (`encargos`). Several steps touch the same files and go in series, never in parallel: `lurker.gd` (every step), `world_audio.gd` (3a's hum and 3b), `hotel_geometry.gd` (3c and 3g), `executions.gd`/`death_tape.gd`/`blood.gd`/`avatar_visual.gd` (3d).

1. **Checks** (read only): every name of 0.1 and 0.2 exists under that name; note each difference at the top of the step's commit message and use the landed name.
2. **3a-0** (hotel identical): `turn_for_capture`, `on_event`, `tally`, `voice_point`, `presence_on` in the contract; the director's `raps_weight`. Whole `verify.ps1`.
3. **3g-0 baseline**: `hotel_benchmark --lurker` before any change to her drawing; numbers into `PERFORMANCE.md`.
4. **3a**: `office_floor.CREATURE` and `--creature=none` for the phase-1 tests, in the same commit; `save_state` additions; the hum's pitch; herding and the fans' sounds and return (2.6); the main duct filter; `office_survival_test` (cases needing sound or the capture come in their steps). `difficulty_test` key.
5. **3b**: the rows of `prepare_lurker_sfx.py`, import, ASSETS; the profile and its aura fields; `ensure_duct_bus()`, routes with `bus`, `voice_point()`/`presence_on()` in `world_audio`; `lurker_voice.gd`; the route additions; `use_profile()`; `play_cue()`'s two additions, the shriek's caption and `fright()`, the car; `office_audio_test`; cases E, I, K, K2 of 9.1.
6. **3d**: first the score refactor alone (5.1), with Godot before and after in series: `capture_test`, the contract test and `body_clip_probe --strict` printing the same as before; then `lurker_score`, `lurker_capture`, grips and `upright`, the tape's hooks, `camera_fall` look-up, blood, the hanging pose; `office_capture_test`; `body_clip_probe --floor=2`; the frames for the author.
7. **3c**: the office rows of 3.1 and CREDITS; `lurker_hallucinations.gd`, `lurker_poser.gd`, the sanity and phantom hooks, `place_spot()`, `flicker_one()`, `light_body()`; `sanity_test --floor=2`.
8. **3e**: gizmos and layer 7, debug lines; the pack fields; `creature_event` and PROTOCOL; the late joiner's reserve; the recordings through the threat; the contract test's Lurker section; the four hotel net scenarios green.
9. **3f**: `bot_threat_lurker.gd`, the brain hooks, cover and looking back, the watchdog and tally, `bot_match`, `bots.ps1 -Floor` (if 0c did not); `bots_test`'s Lurker part; the timing and the short batch (7.5).
10. **3g**: the noise bake (with its check) and shader, the visual's LOD and quality, `set_hidden()`, the hands' rays and planes, `layer_meshes()` and `follow_bodies()`; the benchmark again; cases M and N; the capture tool at `--preset=4` and on Compatibility; the second batch.
11. **Docs** (section 11), whole `verify.ps1`, the hotel's bots check and net scenarios. A commit per step.

---

## 13. Risks and floor-1 guards

1. **Phase 2 lands differently from its specs**, or its two specs are reconciled another way. This spec is a delta: adapt the call, never fork a second shell, duct graph, drain, state list or cue path; anything missing from phase 2 is reported, not built here.
2. **Phase 1's tests expect the null creature** (`heard`, no hunting). Switching `CREATURE` breaks them unless they get `--creature=none` in the same commit as the switch.
3. **The score refactor moves the hotel**: one wrong `SCORE.` left or changed and a capture is a frame off. Do it alone, compare `capture_test`, the contract test and the clip probe's full output before and after; `avatar_visual` takes the score from the state with the hotel's as default.
4. **Her orientation in a capture**: `executions.apply_execution()` turned the creature with `rotation.y`, which would undo her hanging basis; `turn_for_capture()` fixes it, her motion is held during the scene, and her puppet's `follow_state` (phase 4) must not pull her off the scene either.
5. **`lit()` and her drain**: with 2b's `LIT_DRAIN` 0.9 her passive drain never darkens a room for the rules, and 9.1 D2 holds that looking at her in the light still freezes her. If the author decides her drain darkens (Pending, author 1), sections 2.5, 9.1 D and D2, 9.5 case 9, Apacible's `lit_takes`, the hum filter (1d 8.4) and 2b's fairness and senses tests all change together, and in a match each machine computes `lit()` from its own copy of her: the rules must then read the host's.
6. **Duct routes are costly** (Dijkstra per call): memoize as `walked_route()` does; measure `world_audio`'s frame time with her in a duct in the benchmark's CPU line.
7. **The grips**: two hands of 2 m arms on shoulders from above may put elbows through the victim's head; the clip probe only measures the victim. Look at it in `tools/capture/execution_capture.gd --floor=2` and tune `HOLD_FAR`/the hang offset, not the IK.
8. **A camera lying on its back** (OFICINAS 6): if it reads wrong in the capture, `frame_up()`'s pitch range is the knob, and `face_up()` keeps every capture resolvable with the impact out of the picture.
9. **The swinging tile doubles the tile above it**: if it shows in the capture, set `SWING_TILE := false` and tell the author (OFICINAS 6 asks for it).
10. **Lies and the interface**: a caption on a lie would make the interface lie. 9.5 case 4 catches it. Captions on her real sounds tell a subtitled player what is real (Pending, author 6).
11. **The crawler in the main duct**: at Pesadilla a half turn on all fours (`CRAWL_TURN_RATE` 2.4, about 1.3 s) is longer than the 1.2 s window. The batch's crawler saves will show it; the answer is the author's (Pending, author 4).
12. **`default_bus_layout.tres`**: not edited (the bus is made at runtime); restore it after every Godot run.
13. **Pixabay mirrors at 24 kHz** sound dull next to 48 kHz BigSoundBank takes; they are the stand-ins until the author fetches the lossless originals (14). The `soft` and `tile` sets suffer most.
14. **CC BY**: the copier (CC BY 3.0) and the chair (CC BY 4.0) need their credits in the same commit; the chair's licence was uploaded on the author's behalf (registro note): confirm its page before the release, or drop the `silla` lie.
15. **Performance targets unmet**: the fallbacks of 8.1, in order; never a quality that hides her face or her ink completely, and never a thinner ink (8.2's `dt`).
16. **GL Compatibility**: `sampler3D` and a loop with `break` are fine in GLES3, but test the shader there (`--rendering-method gl_compatibility` on the capture tool).
17. **Bot behaviour is a model**: the batch measures how the rules play for bots that turn at 0.35 or 0.9 s after the cue is played; the author's verdict comes from people (phase 5).
18. **Determinism**: lies use their own `rng` (the hotel's global `randf()` order untouched); her drain is per machine (presentation), the rules read the host's.
19. **The batch's cost**: 480 floors at full size; measured first and run short first (7.5), never beside `verify.ps1` or the net scenarios.

**Floor-1 guards** (each a no-op on the hotel): `creature_scene` empty; `turn_for_capture()`, `on_event()`, `tally()`, `voice_point()`, `presence_on()` defaults; `raps_weight` 0.7 when the key is absent, the stalled branch unchanged at 0.7; `drained()` 0 and the hum's pitch 1.0; `ensure_duct_bus()` never called; routes without `bus`; `use_profile(locust.tres)` = today's aura (`aura_rise` 1.5); `lies_tell_own()` false before any draw; `phantom_sight` without `sight_spots`/`sight_rest`, one `rest` draw as today; `score()` is `capture_score.gd`, `kill_sound_at()` `ARM_TIME`, `kill_point()` today's; no `extra`; no `tape_framing`/`tape_pose`; no `look_up`; blood without style hooks; `hang` and `score` absent from the avatar's state or equal to today's; layer 7 draws nothing for the Locust; `pack_state` unchanged; a new RPC only; recordings through `bot_threat.gd` as today; bots' hooks absent from `bot_threat.gd`. `manifest_golden_test`, `capture_test`, `body_clip_probe`, `hotel_audio_test`, `spatial_audio_test`, `sanity_test`, `bots_test` (floor 1), `stages_test`, `continue_test` and the four net scenarios stay green after every step.

---

## 14. Audio assets: what is used, and what waits for the author

**Used** (all `"status": "ok"` in their `registro.json`): 3.1's tables. From `audio_criatura`: `ceiling_claws_cardboard_scratch`, `tile_grid_metal_rattle`, `tile_styrofoam_grind`, `debris_sandfall`, `debris_gravel_dirt_small`, `metal_fingernail_elevator_ceiling`, `duct_impacts_metal_box`, `duct_heater_vent_hits`, `wall_claws_smooth_rock`, `plaster_tool_scrape`, `wood_claws_skittering_dog`, `wood_fingernail_scratch`, `breath_cow_bodot`, `bone_knuckles_crack`, `bone_celery_bsb`. The cue's and the shriek's sources (`breath_horse_bsb`, `bone_celery_bsb` `bsb_0596`, `bone_knuckles_crack`, `shriek_barn_owl_bsb`) are chosen once, in 2b 9.3; `shriek_bat_screeches_oga` is not used. Not used though ok: `ceiling_rat_gnawing_wood` (gnawing reads as a rodent; its noise floor needs work), kept as a layer to try in phase 5's mix. From `audio_oficina`: `telefono_antiguo` (`bsb_3532`), `fotocopiadora` (`soundbible_2169`, CC BY 3.0), `silla_oficina_ruedas` (`oga_nicolemariet`, CC BY 4.0). From `audio_edificio`: `fluorescent_starter_flicker` (`pixabay_61228`). Rejected entries (`metal_plate_contact_mic_scratch`, `shriek_fox_forest` and the others marked `rejected`) are never used.

**Waits for the author** (to `docs/PLAN.md` section 4, "Assets que faltan (tuyos)"):

- Missing, best as own foley: claws or nails on a real mineral-fibre ceiling tile (`claws_mineral_fibre_tile_direct`), a tile lifting in its T-bar grid (`tile_lifting_in_tbar_grid_direct`).
- Freesound, needs the author's login (CC0 unless said): noise in a ceiling (`fs_noise_in_ceiling`, low quality even so), nails tapping metal and fingernails on metal sheets (`fs_nails_tapping_metal`, `fs_fingernails_on_metal_sheets`), clawing at wood (`fs_clawing_at_wood`), fingernails on plaster and on a popcorn wall (`fs_fingernails_on_plaster_wall`, `fs_scratching_popcorn_wall`), crawling inside an air vent (`fs_crawling_inside_air_vent`, `fs_crawling_through_vent_foley`), particles falling (`fs_particulas_cayendo`), an office ceiling rattling and styrofoam creaking (`fs_ceiling_rattle_office`, `fs_styrofoam_creak`), heavy horse breathing (`fs_horses_heavy_breathing`), a fox screaming at night (`fs_fox_screaming_night`).
- The lossless originals of the Pixabay mirrors used above (Freesound login): the 24 kHz ones first (`ceiling_claws_cardboard_scratch` has no original left), then `breath_cow_bodot`, `bone_knuckles_crack`, `duct_impacts_metal_box`, `metal_fingernail_elevator_ceiling`, `tile_*`, `debris_sandfall`.
- BigSoundBank's 48 kHz WAV of `bone_celery_bsb` (its download button posts an anti-bot form; the 320 kbps MP3s are used meanwhile; 2b lists the cue's and the shriek's).
- `audio_oficina`: venetian blinds (`persianas_venecianas`, needs login: the `persiana` lie stays silent until then), metal doors with a push bar (`puerta_metalica_barra`), CC0 takes of the copier and the office chair (to drop two credits).
- Confirm on its own page the licence of the chair recording (uploaded on the author's behalf).

---

## 15. Pending decisions

### For the author (game, lore, feel)

1. **Does her passive drain make a room "dark" for the rules?** OFICINAS 11.3 says `lit()` is false while she drinks it; 2b's decision 6 says only versus' "beber la luz" (past 0.9) does. If it does (the first draft's 0.5 threshold), she darkens any room as she nears a lamp: looking at her in the light no longer freezes her, Apacible's "no coge con luz" stops protecting under the lamps, the light no longer herds her out, and the hum stops instead of dropping in pitch. This spec follows 2b; OFICINAS 11.3 needs the author's wording either way.
2. **The director's knuckles on a door (`raps`) on floor 2.** Off (a knock could be taken for her tell) or "mismas reglas" (0.7, as now in this spec). Off also means a stalled, frightened team gets no move at all.
3. **How often she lies.** OFICINAS 5 says "cada 40–90 s frente a 1,5–3 min en el hotel"; the hotel's 1.5–3 min is the faces' rest (`phantom_sight.REST` 90–180 s), while its sound lies come every 13–42 s (`sanity.gd:54`). Options: faces every 40–90 s and sound lies at the hotel's pace; both at 40–90 s (fewer sound lies than the hotel); sound lies ×0.7 (about 9–38 s, which may bury her real claws under false ones); another figure. Placeholders keep the hotel's until then.
4. **The crawler at the back of the main duct.** A longer window while crawling (and how much); free looking back while crawling (the camera turns faster than `CRAWL_TURN_RATE`, the body does not); or nothing ("quien va el último puede ir mirando hacia atrás").
5. **The cue under the fans.** OFICINAS 3 says that with the fans running "nadie la oye ni a ella"; OFICINAS 1 says the cue always sounds. 2b and this spec keep the cue out of the fans' mask: confirm.
6. **Captions as a lie detector.** Lies never carry a caption; her real `ducts` and `tile` sounds do, so a subtitled player knows which claws are real. Accept that and say so in OFICINAS 5, or take the captions off those two real sounds (the cue and the shriek keep theirs: they are rules).
7. **The caption of her breath above a locker** (the presence loop, only in Encima): its text. It must differ from the cue's "[Algo respira a tu espalda]" and from "[Algo respira cerca]" (the cue heard by others).
8. **Does she drink the light from inside a duct?** 2b: no (OFICINAS 4: "por los ductos se la oye y no se la ve"); the first draft: yes, the lamps trembling under her as she passes overhead.
9. **The emergency lamps of planta 2** (amber, on battery): do they tremble with her? Today none is drained, so on that planta her clearest sign disappears.
10. **In versus**, does "she enters the main duct only behind the last crawler" (0.5.4) hold for a person driving her too?
11. **The decisions of 0.5** (lies uncaptioned, no breath or click outside the cue, the presence only above a locker, "techo alto" over 3.0 m, the clean half second, `SANITY_SHRIEK` 6) and **the director's numbers of 2b 4.2** (`encounter_every`, `cross`, `lead_every` and the rest, which OFICINAS does not give): to OFICINAS 14 as "decidido por los agentes, pendiente del autor".

### For the director (contracts, architecture)

1. **Reconcile phase 2's two specs before phase 3 is cut.** They differ on: the difficulty key names (2a 10: `lit_grab`, `stare_time`, `approach_scale`, `peek_rate`; 2b 4.1: `lit_takes`, `freeze_time`, `creep_scale`, `peek_every`, plus `sated`, `forget`); the den (2a: a tray room, `"lurker_den"`, on the ceiling; 2b: a room with a duct exit, inside the duct, more than 3 hops from the entry); the transit (2a: `PITCH * wings / duct_speed`, arrival in `ARRIVE_BAND`; 2b: `(PITCH + TRANSIT_DUCT) / duct_speed`, `transit_exit()` at `TRANSIT_AWAY`); the words (2a's `WORDS` and `word` against 2b's `activity()`); who sets `ducts.closed` (2a's motion; 2b's brain). This spec names neither side where they differ.
2. **This spec is not ready for `encargos`**: after 1, a file to unit map from the code as it then is, with an acceptance test per area (section 12).
3. **PROTOCOL**: phase 1, 2b and 3e each add RPCs before the floor-2 release: one bump in that stretch, and which step makes it.
4. **Five contract additions** (2.2): `turn_for_capture()`, `on_event()`, `tally()`, `voice_point()`, `presence_on()`; and the capture style's `kill_sound_at()`/`kill_point()` (5.1).
5. **Two brain hooks phase 2 does not have**: `on_room_lit(room)` (the light herds her, 2.6) and `on_ducts_open()` (back into the ducts when the fans stop); and, for versus, `ducts.closed` computed on every machine from `air.ducts_closed()` rather than in the AI's motion.
6. **The pack**: 2a's ten fields plus `state` and `prey` and the flag `SCARED` now (phase 3), or all of it left to phase 4.
7. **2b's scan for `"lurker/cue_"`** would match the `NEVER` list of the lies: build those paths without the literal, or exclude `lurker_hallucinations.gd` by name in 2b's test.
8. **The cue's distance**: 2b's `CUE_RANGE` 1.6–3.2 m against OFICINAS 4's "a 2–3 m": which the batch holds her to.
9. **`verify.ps1`'s length**: the minutes phases 2 and 3 add together (section 10), and whether some checks move to the phase-close list.
10. **The balance batch**: the timing of one floor first and the short batch (7.5), launched only by the director, alone, within the usage window.

### From step 1a (22 October 2026): the planta's card

- OFICINAS 3 (line 176) sets the card of each planta in three parts: «NIVEL 1» / «PERSONAL» / «PIDE TU FICHA». 1a gives `kind.title_of(stage)` («NIVEL %d») to every live card (hotel_main `show_transit`/`show_brief`, lifts), but nothing shows the department. This phase does it: `show_transit` and `show_brief` gain the department line when the kind has one (the hotel has none, so its cards do not change).
- Source of truth: `title_of()` for the level and `office_palette.PLANTA_NAMES` for the department. `office_floor.STAGES[n].level` and `.department` repeat them; this phase reads the two sources and removes the copies (or derives them), so the data is written once.

### Resolved by the author (24 October 2026; .claude/specs/decisiones_fase2_3.md)

- **1, 3 to 11:** as recommended: her passive drain does not make a room dark for the rules; faces every 40 to 90 s and sound lies at the hotel's pace; the last crawler may look back freely with the camera (the body still turns slowly), no longer window; the cue stays out of the fans' mask; her real duct and tile sounds lose their captions (the cue and the shriek keep theirs); the breath above a locker reads «[Algo respira encima]» (the author may change the text); she drinks light from inside a duct; planta 2's emergency lamps tremble with her; in versus a person driving her also enters the main duct only behind the last crawler; 0.5's decisions and 2b 4.2's numbers approved, to be tuned with the balance batch.
- **2:** **the director's knuckles on doors stay on floor 2** ("mismas reglas"): they frighten when there is no danger.
