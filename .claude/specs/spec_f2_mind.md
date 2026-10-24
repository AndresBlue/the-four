# Phase 2, step 2b: The Lurker's senses and mind, and the fairness guarantee

**Status:** draft, reviewed by two critics on 22 October 2026 and corrected against the code and `docs/OFICINAS.md`. **Not approved.** What is still open is in the last section, "Pending decisions".

Read first: `docs/OFICINAS.md` sections 1 (the contract with the player), 4 (how she behaves, the difficulty table), 5 (what hallucinations never fake), 6 (the capture), 7 (versus), 11.1, 11.5, 11.6 and 15 (phase 2). Then `game/enemies/creature.gd` as it stands, `docs/LURKER.md`, `game/enemies/lurker/lurker_visual.gd` and `tools/workbenches/lurker_test.gd`.

This spec covers step **2b**: `game/enemies/creature_sight.gd`, `game/enemies/lurker/lurker_senses.gd`, `game/enemies/lurker/lurker_warning.gd`, `game/enemies/lurker/lurker_brain.gd`, the parts of `game/enemies/lurker/lurker.gd` that tie them to the body 2a builds, the cue in the ears (on this machine; the wire is phase 4's, 9.1), the cue and scare recordings, and two tests: `tests/office/lurker_fairness_test.gd` and `tests/office/lurker_senses_test.gd`. Section 4 is **the only table** of the Lurker's difficulty keys, the director's overrides and her four lines of traits: step 0f writes it into `difficulty.gd`, 2a's section 10 and 0f's note in `fase0_pasos.md` refer to it, 2b reads it.

**Two parts** (section 11). **2b-1** needs nothing that is not in the tree today: `creature_sight.gd` and its two delegations, the contract and the capture gate, `lurker_warning.gd`, the brain's warning states and Part B of the fairness test. **2b-2** comes after phase 0 (0b to 0f), phase 1 and 2a: the senses, the rest of the brain, 2b's part of `lurker.gd`, the cue in the ears, Part A and `lurker_senses_test`. The flow `encargos` can cut 2b-1 into closed units now; 2b-2's fact sheets can only be raised from the code once its prerequisites exist.

**Floor 1 stays byte-identical.** Every change to a shared file is a no-op for the hotel. `manifest_golden_test`, `creature_contract_test`, `capture_test`, `stages_test`, `sanity_test`, the net tests and the whole `tools/verify.ps1` stay green after every commit.

**Numbering.** Prose follows OFICINAS: plantas 1 to 3. Code counts `wing` from 0.

---

## 0. What 2b assumes, and what it decides

### 0.1 Done before 2b

**For 2b-1** only what is committed today: the contract of `creature.gd` as 0a1 to 0a5 left it (0a5 is `d32f23a`): `quarry()`, `saw_enter(hide, sure)`, `CHASING`/`is_chasing()`, `resume_state()`, `validate_strike(origin, facing, body) -> float`, `sense_scale()`, `hunter_*()`, `apply_quality()`, `wardrobe_steps()`, `capture_style()`, `begin_capture()`, and `debug_lines()`/`debug_state()`/`draw_gizmos(g)`; `executions.gd` with `forced`, `capture_survivor()`, `stage_capture()`, `apply_execution()`.

**For 2b-2**, in addition:

- **Phase 0** as in `.claude/specs/fase0_pasos.md` (0b to 0f). Step 0e gives `hotel.lit(room_id)`, `hotel.set_room_power(room_id, on)`, `hotel.drain(room_id, amount)`. Step 0f gives `DIFFICULTY.profile(id, creature_key)` merging `CREATURE_PROFILES[creature_key][id]` over `PROFILES[id]`, and `level.tuning()` returning the merged profile.
- **Phase 1**: the office floor builds (`level.set_floor(2)`, `--floor=2`). The manifest keys used here are the generator's (`spec_f1_generator.md` 2.5 and 2.8): `ducts {nodes, edges, exits}`, `plenum`, `archives[].aisles`, `gates`, `refuges`, room `hides` (lockers), `room.furniture` (`partition` items). The palette (`office_palette.gd`): `OFF_LIMITS := [9, 10, 19]`, `off_limits_rooms(manifest)`, `troffers(room)`, `lamp_of(room)`. Systems (`spec_f1_systems.md` 1.1, 1.5): `level.sound_mask(point)`, `level.crawling_at(point)`, `conduit_graph.gd` with `from_manifest()`, `distances_from(node)`, `nearest_node(point)`, `mouths_in_room(room)`, `exits` (`{node, room, kind, number, position, normal}`), `closed`. Geometry (`spec_f1_geometry.md`): one `OmniLight3D` per room in `hotel.lights[id]`, `hotel.crawl_space(point)`, `PLENUM_LAYER`.
- **Step 2a** (`spec_f2_movement.md`, an unreviewed draft written in parallel with this one): `lurker.gd` (the playing body, `extends "res://game/enemies/creature.gd"`, holding `lurker.tscn` as its visual), `lurker_shell.gd` (ceilings, door-head and wall bands, archive channels: **no floor and no free walls**, "She is never on the floor in a room", 2a 8.2), `lurker_routes.gd` (A* over rooms, open doors and duct exits; `travel_metres()`, `nearest_exit()`, `flee_exit()`, `arrival_exit()`), `lurker_motion.gd` (the orders of 2a 7.2, the planta transit of 2a 7.6), `duct_graph.gd` (`extends conduit_graph.gd`, with `inbound()`). **2a owns the movement.** 2b never calls it directly except in one function, `lurker.gd.apply_intent()` (8.3), and the getters of 8.3: the brain says what it wants as an *intent*, and that function turns it into 2a's orders. If 2a's names change when it is reviewed, that function is the only place that changes; the meanings below hold.

What exists today under `game/enemies/lurker/` is only the visual (`lurker.tscn`, `lurker_visual.gd`, `lurker_limbs.gd`); `tests/office/` does not exist yet (2b-1 creates it).

### 0.2 Check before starting 2b-2 (`git grep`, 15 minutes)

Places that still read The Locust and would crash or misbehave with any other creature on the floor. **Redo this table with a grep for `locust\.` in `game/app/hotel_main.gd` and `creature.<Locust-only member>` in `game/` when 2b-2 starts** (phase 0 may have moved more), and fix what remains as pure refactors (floor 1 identical, proven by the tests named). As of `d32f23a`:

| Where (function) | What | Fix |
|---|---|---|
| `hotel_main.populate_floor()` | `world_audio.set_creature(null if observer else locust.sound_profile)` | `locust.sound_profile if "sound_profile" in locust else null` (phase 3 gives her an aura profile). Proof: `sanity_test`, `stages_test`. |
| `hotel_main` blackout (the function with `mark_blackout`) | `locust.driver` | `"driver" in locust and is_instance_valid(locust.driver) and ...` before the call. Proof: `stages_test`. |
| `hotel_main.arm_creature()` | `locust.reach_scale`, `ONSLAUGHT_REACH`, `relentless` | Only for a creature that has them: `if "reach_scale" in locust:` around the two lines (0f may already have moved onslaught behind the rule's creature). Proof: `rules_test`. |
| `hotel_main.spawn_creature()` | `locust.den_room(1)`, `FLOOR.position_of(...)`, `locust.patrol_room` | Those three lines only `if "patrol_room" in locust`; any other creature places itself (2a's `arrive()` puts her at `den_point(1)`, a ceiling anchor). No `place_at()` exists or is needed. Proof: `stages_test`, `loop_test`. |
| `hotel_main.hand_creature_to_player()`, and the two other `locust.camera.current = true` (solo preview, the hunter's rejoin) | `locust.camera` | Not reached with the Lurker before phase 4 (a human hunter). Leave; note it in `docs/DEVELOPMENT.md` as phase 4's. |

Already through the contract (0a5): `run_ledger.gd`, `interaction.gd` (`creature.saw_enter()`), `presentation_rig.gd` (`creature.apply_quality()`).

### 0.3 Decisions proposed here (record them in `docs/OFICINAS.md` 14 under **"Abierto"**, labelled "propuesto por los agentes, pendiente del autor": never in the table "Decidido")

1. **A teammate who looks at her in the light also saves.** OFICINAS 11.5 names the victim's look in the light and anybody's torch. The code saves on *anybody's* look in the light too: a strict superset (it only ever adds protection), and it is what "dos que se cubren la espalda son casi intocables" means.
2. **The torch's aim is the view.** The local player's torch follows the camera with a lag (`hotel_player.torch_follow`, line 116 and 620 to 627). For every rule here, a torch "covers" her face when it is on and the *camera* points at her face within `TORCH_FACE_ANGLE`: the beam's lag is presentation and never costs a save.
3. **Latency** for a seat (phase 4 measures it, 6.3) is the round trip to its machine plus the 0.1 s a puppet's view runs late (`remote_player.DELAY`) plus a guest's send period (`1 / match_net.SEND_RATE`), capped at 0.5 s; 0 for the host's own survivor, offline, and for bodies with no machine of their own (bots). In 2b only the tests set it (`warning.latency_for`). Only the victim's latency counts (OFICINAS 1, "la latencia de quien la sufre"). The cap and whose latency are the author's (Pending decisions).
4. **The take may still happen up to `TAKE_HOLD` (0.6 s) after the window**, if the victim is in reach and nothing saved them; after that the cue expires and nobody is taken.
5. **She does not open lockers.** Someone hidden during the window ends the cue (aborted, no take); she waits on top of the locker ("Encima") only if she saw them get in (`saw_hides`); otherwise she goes back to stalking from their last point.
6. **A passive drain never darkens a room for the rules.** `hotel.lit()` turns false only past `LIT_DRAIN` (0.9) of drain, which only versus' "beber la luz" reaches (phase 4). Her passive drain is 0.4 to 0.7.

---

## 1. Files

| Action | Path | Section |
|---|---|---|
| create | `game/enemies/creature_sight.gd` | 3 |
| create | `game/enemies/lurker/lurker_senses.gd` | 5 |
| create | `game/enemies/lurker/lurker_warning.gd` | 6 |
| create | `game/enemies/lurker/lurker_brain.gd` | 7 |
| change | `game/enemies/lurker/lurker.gd` (2a's) | 8 |
| change | `game/enemies/creature.gd` | 2 |
| change | `game/enemies/locust/hotel_locust.gd` (`watched()` delegates) | 3.3 |
| change | `game/app/phantom_sight.gd` (`beside_view()` delegates) | 3.3 |
| change | `game/app/executions.gd` (the gate, the cue id in the data) | 2.2 |
| change | `game/net/match_net.gd` (`send_cue()`, `send_cue_over()`: this machine only; no RPC, no `PROTOCOL`) | 9.1 |
| change | `game/audio/world_audio.gd` (`play_cue()`, held ears, held caption) | 9.2 |
| change | `game/app/hotel_main.gd` (the guards of 0.2, `creature_scene`, `--creature=`) | 0.2, 8.6 |
| change | `game/world/hotel/hotel_geometry.gd` (only if 0e lacks them: `drained()`, the `LIT_DRAIN` threshold in `lit()`) | 5.6 |
| change | `game/floors/difficulty.gd` (only the values of section 4, if 0f has not written them) | 4 |
| create | `tools/audio/prepare_lurker_sfx.py` | 9.3 |
| create | `assets/audio/sfx/lurker/cue_0.wav`, `cue_1.wav`, `cue_2.wav`, `scare_0.wav`, `scare_1.wav` | 9.3 |
| create | `tests/office/lurker_senses_test.gd`, `tests/office/lurker_fairness_test.gd` | 10 |
| change | `tests/hotel/creature_contract_test.gd` (`RPCS` untouched: 2b adds no RPC), `tests/hotel/difficulty_test.gd` | 10.3, 4.4 |
| change | `tools/verify.ps1` (`$tests` += `'office/lurker_senses_test'`, `'office/lurker_fairness_test'`) | 10 |
| change | `docs/LURKER.md`, `docs/OFICINAS.md` (14), `docs/DEVELOPMENT.md`, `docs/ASSETS.md`, `docs/asset_hashes.json` (Spanish prose) | 12 |

---

## 2. Contract additions and the capture gate

### 2.1 `game/enemies/creature.gd`

Add, with these comments (English, the file's voice):

```gdscript
## Whether it may take this survivor now, asked by executions.capture_survivor()
## at the last moment, on the machine that decides. The Lurker only at the end
## of her warning behind them (docs/OFICINAS.md 11.5, lurker_warning.gd);
## every other creature: yes.
func may_capture(_body: Node3D) -> bool: return true

## The warning a capture of this survivor answers (its id in capture_log()),
## -1 for none: executions.stage_capture() keeps it with the capture.
func cue_of(_body: Node3D) -> int: return -1

## Every warning it has given this floor, and what came of each
## (lurker_warning.gd ledger): what the tests and the bots' watcher check.
func capture_log() -> Array: return []

## Its warning behind `seat`, decided on the machine in charge, played here
## from `point`, where it really is (match_net.send_cue).
func play_cue(_seat: int, _cue_id: int, _point: Vector3, _hold: float) -> void: pass

## That warning is over (taken, saved, given up): whatever of it is still
## held on this machine lets go.
func cue_over(_cue_id: int, _outcome: String) -> void: pass
```

In the comment list of `activity()`, add one word (1a adds `idle`):

```
##   withdraw     drawing off after a fright, nobody in mind, not to be led
##                (the Lurker's flight to a duct)
```

`withdraw` is in none of the lists, so every predicate is false for it and `alarm_level()` is 0. (If the author chooses a word of her own for stalking, `stalk`, it is added here the same way and to HOSTILE only: Pending decisions.) The Locust overrides none of the five functions: the hotel is unchanged.

### 2.2 `game/app/executions.gd`

1. **The gate.** In `capture_survivor(body)`, after the spare check (`if level.spare.is_valid() and bool(level.spare.call(body)): return`) and before `var data := stage_capture(body)`:

   ```gdscript
   	# The Lurker takes nobody she has not warned, and only once the warning
   	# has run out (lurker_warning.gd): asked here, last, whoever asked.
   	if not level.creature.may_capture(body): return
   ```

2. **The cue id in the data.** `stage_capture(body)` builds its return literal into `var staged := {...}`, then `var cue: int = creature.cue_of(body)`, `if cue >= 0: staged["cue"] = cue`, then `return staged`. The hotel never has a cue, so the dictionary, its key order and the `execute_start` payload are unchanged.
3. **Kept in the execution.** In `apply_execution()`, after the `execution = {...}` literal: `if data.has("cue"): execution["cue"] = int(data.cue)`. `begin_capture(execution)` (called further down in the same function) then carries it to the creature.

**Forced captures.** The tools that stage a capture on purpose (`tools/dev/body_clip_probe.gd`, `tools/dev/blood_look.gd`; phase 3's `body_clip_probe --floor=2`) set `level.executions.forced` and call `capture_survivor()` directly. The Lurker's `may_capture()` lets them through while `forced` is not empty and logs it as an entry with `forced: true` (6.2), which `audit()` and the bots' watcher skip. Nothing in play sets `forced`.

`capture_survivor()` returns early when `capture_style()` is null (its first line), before the gate. Until phase 3 gives the Lurker `capture_styles/lurker_capture.gd`, her take reaches the gate only in the tests' direct calls (10.2); the ledger records the decision either way (6.4).

---

## 3. `game/enemies/creature_sight.gd` (shared)

`extends RefCounted`, everything `static`. Taken out of The Locust and `phantom_sight.gd` (OFICINAS 11.5): `watched()`, `torch_covers()` (without the 5 m minimum of `hotel_locust.lit_by_torch()`, and aimed at the face), `regards()`, `beside_view()`. No state, no preload of anything but `floor_definition.gd` (The Locust will preload this file for its delegation: it must not drag `remote_player.gd` and the avatar's scene with it).

### 3.1 Constants

```gdscript
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## What blocks a look: the world, the doors, the hiding places (the rays of
## hotel_locust.clear_sight and sanity.sight_of_creature). Bodies (layer 4)
## never do.
const MASK := 1 | 8 | 64
## Degrees between where a survivor looks and her face for them to be looking
## at her: their own view, and a guest's puppet, whose view arrives late
## (remote_player.DELAY and the net) and is given the benefit of the doubt.
const REGARD_LOCAL := 30.0
const REGARD_REMOTE := 45.0
## Metres a look carries (sanity sees the creature to 28).
const REGARD_REACH := 30.0
## The torch on her face: on, the view pointed within this of the face, this
## near (the beam, spot_range 24, is still strong there), nothing between.
## The aim is the camera's, not the lamp's lagging node (0.3, decision 2).
const TORCH_FACE_ANGLE := 20.0
const TORCH_REACH := 20.0
## watched(): The Locust's SIGHT_RANGE and its cone.
const WATCH_REACH := 70.0
const WATCH_DOT := 0.35
## beside_view(): phantom_sight.PLACE_OFF, the band at the edge of a view.
const BESIDE := Vector2(0.45, 0.85)
## Behind somebody: horizontally more than ~105 degrees from where they look,
## or above them (50 degrees up or more) while they do not look up at her.
const REAR_DOT := -0.26
const OVER_SIN := 0.77
const OVER_LOOK := 0.5
```

### 3.2 Functions

```gdscript
## Alive (not DEAD in the session), with a camera: a body whose look counts.
## Protected rooms and cars included: a torch from the freight lobby still saves.
static func alive(level, body) -> bool
## Any survivor but this machine's own player: its view reaches here late.
## Bots (bot_body.gd extends remote_player.gd) get the same margin: on the
## side of more saves (Pending decisions, director).
static func is_remote(level, body) -> bool              # body != level.player
## Her face or anything is lit where it is: the room's lamps on (hotel.lit()),
## never inside a crawl space (level.crawling_at(), absent on the hotel: false).
static func lit_point(level, point: Vector3) -> bool
## Nothing of MASK between two points (exclude: RIDs).
static func clear(level, from: Vector3, to: Vector3, exclude: Array) -> bool
## Whether any active survivor (level.survivor_active) has `target` in view:
## within WATCH_REACH, the camera's forward dotted with the way to it at least
## `dot`, a clear ray from the camera. The Locust's watched(), point for point.
static func watched(level, target: Vector3, exclude: Array, reach := WATCH_REACH, dot := WATCH_DOT) -> bool
## Their torch is on, they are not hidden, and their view points at `face`
## within TORCH_FACE_ANGLE, within TORCH_REACH, through nothing.
static func torch_covers(level, body, face: Vector3, exclude: Array) -> bool
## They are looking at her: their view within REGARD_LOCAL (REGARD_REMOTE for
## a puppet) of `face`, within REGARD_REACH, a clear ray, and she can be made
## out: `lit_face` (lit_point(face), computed once by the caller) or their
## torch covers her face. Hidden bodies regard nothing.
static func regards(level, body, face: Vector3, exclude: Array, lit_face: bool) -> bool
## Who regards her now and whose torch is on her face: {"regarded_by": [seat...],
## "torch_by": [seat...]} over every alive, unhidden survivor (level.survivors()),
## ascending seats. One ray per body serves both.
static func regarders(level, face: Vector3, exclude: Array) -> Dictionary
## Whether anybody would see her along these points of her way: the first,
## the middle (index size / 2) and the last, each with its own lit_point().
static func stretch_exposed(level, points: PackedVector3Array, exclude: Array) -> bool
## Just off to the side of a view, where a turn of the head finds it.
static func beside(eye: Vector3, forward: Vector3, point: Vector3, band := BESIDE) -> bool
static func beside_view(camera: Camera3D, point: Vector3, band := BESIDE) -> bool  # beside(camera eye, -basis.z, ...)
## She is behind them (REAR_DOT) or above them out of their look (OVER_*).
static func behind_of(eye: Vector3, view: Vector3, face: Vector3) -> bool
```

Exact rules:

- `torch_covers`: `alive(level, body)`, `not body.hidden`, `body.torch.visible`; `eye := body.camera.global_position`, `to := face - eye`, `d := to.length()`; false if `d > TORCH_REACH` or `d < 0.05`; false if `rad_to_deg((-body.camera.global_basis.z).angle_to(to)) > TORCH_FACE_ANGLE`; then `clear(level, eye, face, exclude + [body.get_rid()])`. **No minimum distance**: at a metre the torch on her face is exactly when it must count.
- `regards`: `alive`, `not body.hidden`; `eye`, `to`, `d` as above; false if `d > REGARD_REACH or d < 0.05`; `cone := REGARD_REMOTE if is_remote(level, body) else REGARD_LOCAL`; false if the angle between `-camera.global_basis.z` and `to` is over `cone`; false if not `clear(...)`; then `lit_face or torch_covers(...)` (the cone test of `torch_covers` is the narrower one; reuse the ray already cast).
- `behind_of`: `to := face - eye`; false if `to.length() < 0.01`; `flat := Vector3(to.x, 0, to.z)`, `ahead := Vector3(view.x, 0, view.z)`; rear when `flat.length() > 0.2 and ahead.length() > 0.01 and ahead.normalized().dot(flat.normalized()) <= REAR_DOT`; over when `to.normalized().y >= OVER_SIN and view.normalized().dot(to.normalized()) < OVER_LOOK`. Behind if either. Behind always means "not within 30 degrees of the view", so it never contradicts `regards()`.
- `lit_point`: `if level.has_method("crawling_at") and level.crawling_at(point): return false`; `room := FLOOR.room_at(level.manifest.rooms, point)`; false if empty; `return level.hotel.lit(int(room.id))`.

### 3.3 Two delegations, proven identical

- `hotel_locust.watched(point)` becomes `return SIGHT.watched(level, point + Vector3(0, 1.2, 0), [get_rid()])`. The loop, the reach, the 0.35 cone, the ray (exclude the body and itself) and the active-survivor filter are the same; `creature_contract_test` compares the old body (kept as a function inside the test) with the new on 100 seeded points of a hotel floor.
- `phantom_sight.beside_view(point, camera)` becomes `return SIGHT.beside_view(camera, point, PLACE_OFF)`. Same comparison on 100 seeded directions.

Nothing else of the hotel calls `creature_sight.gd`.

---

## 4. For step 0f: the Lurker's difficulty keys, the director's overrides, her traits

### 4.1 `CREATURE_PROFILES[&"lurker"][id]`: her own keys

OFICINAS 4's table, plus the few keys her mind needs. **This is the only table of these keys.** 2a's section 10 (`lit_grab`, `stare_time`, `approach_scale`, `peek_rate`) and 0f's "values from the OFICINAS table" both give way to it: same names, same values, the director fixes those two texts. 0f writes them; 2b reads them in `lurker.tune()` (8.1); 2a reads `duct_speed`. Defaults in code are Desafiante's (the reference). Until 0f exists (2b-1), Part B reads a local copy of this table (`const LURKER_PROFILES` in the test) and, once 0f lands, checks that the copy equals `DIFFICULTY.profile(id, &"lurker")` for these keys.

The rows `sated` and `forget` are not in OFICINAS, and the base `creep_scale` multiplies (1.0 m/s here, 1.35 in 2a's draft) is not settled: both are in Pending decisions; the values below are the draft's.

| Key | Apacible | Equilibrada | Desafiante | Pesadilla | Read by | Meaning |
|---|---|---|---|---|---|---|
| `back_window` | 2.2 | 1.8 | 1.5 | 1.2 | warning | s from the cue to the take (OFICINAS 1) |
| `lit_takes` | false | true | true | true | brain, warning | takes from behind, after the cue, in a lit room |
| `duct_speed` | 1.2 | 1.6 | 2.0 | 2.4 | 2a's motion and routes, the planta transit (2a 7.6) | m/s inside the ducts |
| `stalk_distance` | 12.0 | 10.0 | 8.0 | 6.0 | brain | m she keeps from her prey while stalking |
| `freeze_time` | 2.0 | 3.0 | 4.0 | 6.0 | brain | s still in the light before she backs away |
| `scare_calm` | 60.0 | 45.0 | 35.0 | 25.0 | brain | s before she goes for the same prey after a fright |
| `creep_scale` | 0.8 | 0.9 | 1.0 | 1.15 | brain | × `CREEP_SPEED` (1.0 m/s) when closing in |
| `drain_reach` | 3.0 | 3.0 | 3.5 | 4.0 | drain (5.6) | m from a lamp at which she drinks it |
| `peek_every` | [20.0, 35.0] | [25.0, 40.0] | [40.0, 65.0] | [70.0, 110.0] | brain | s between her own peeks while stalking ("Asomos": muchos, muchos, normales, pocos) |
| `sated` | 50.0 | 45.0 | 40.0 | 30.0 | brain | s after a take before she chooses prey again |
| `forget` | 8.0 | 10.0 | 12.0 | 15.0 | senses | s a survivor out of her senses is still remembered |

The six system keys of `spec_f1_systems.md` 1.8 (`typing_time`, `board_budget`, `lift_timer`, `timer_switch`, `fan_charges`, `fan_time`) live in the same dictionaries.

### 4.2 The director's overrides (same dictionaries, over the Locust's values)

The director stays as it is (section 7.8): zones, never positions. These keys only retune it for a slow creature whose encounters are scares. **None of these values is in OFICINAS**; they are tuning, listed for the author in Pending decisions (notably `encounter_every` on Desafiante, where the hotel has 0.0, and `ambush` 0.5 on Apacible, where the hotel has 0.0, against "En Apacible, más asomos y menos capturas").

| Key | Apacible | Equilibrada | Desafiante | Pesadilla | Why |
|---|---|---|---|---|---|
| `encounter_every` | 100.0 | 120.0 | 160.0 | 220.0 | the guaranteed encounter, now a peek or a ceiling cross (OFICINAS 4); on every difficulty, more often on the easy ones |
| `cross` | 2.0 | 1.6 | 1.0 | 0.4 | weight of "cruce" among the BUILD moves (same reason) |
| `lead_every` | [35.0, 50.0] | [32.0, 48.0] | [30.0, 45.0] | [22.0, 35.0] | she is slower than The Locust: leads further apart |
| `peak_max` | 40.0 | 45.0 | 50.0 | 60.0 | stalking is slow: the hands-off phase lasts longer |
| `peak_tense` | 25.0 | 30.0 | 35.0 | 40.0 | same |
| `rest_chase` | 40.0 | 35.0 | 30.0 | 25.0 | the rest after a stalk or a fright (she is hostile while stalking) |
| `ambush` | 0.5 | 1.2 | 2.0 | 2.5 | the things that turn your back (the typewriter, a station, the board) are her ground |
| `double_back` | 0.0 | 0.2 | 0.4 | 0.6 | as the Locust's, one step milder on Pesadilla |

Every other key (`grace`, `hearing`, `prowl_min`, `rest_death`, `death_ease`, `distract_rest`, `burnt_every`, `calm`, `solo_ease`, `restarts`, `solo_restarts`, ...) is inherited from `PROFILES[id]`. Her hearing multiplier is the shared `hearing` (0.7, 0.75, 1.0, 1.2). The Locust-only keys she inherits (`sight_range`, `chase_*`...) are read by nobody on floor 2.

### 4.3 Her traits (Spanish, four short lines, no «·» or «—»)

In the place 0f made for traits per creature (`TRAITS` by creature key). Only what the numbers above do; the restarts line matches `restarts`/`solo_restarts`.

```gdscript
&"lurker": {
	"apacible": ["Avisa con tiempo para darte la vuelta", "Con luz no te coge", "Se asoma mucho y acecha de lejos", "Reintentos de etapa sin límite"],
	"equilibrada": ["Avisa a tu espalda: date la vuelta", "De espaldas te coge también con luz", "Se asoma a menudo", "Reintentos de etapa: 1 a solas, 2 en equipo"],
	"desafiante": ["Avisa con poco margen", "Acecha más cerca y vuelve antes", "Bebe la luz desde más lejos", "Reintentos de etapa: 0 a solas, 1 en equipo"],
	"pesadilla": ["Un aviso y apenas tiempo", "Se acerca más deprisa y apenas se asoma", "Espantada, vuelve enseguida", "Sin reintentos de etapa"],
},
```

### 4.4 `tests/hotel/difficulty_test.gd` (0f adds; 2b re-runs)

- Every `DIFFICULTY.profile(id, &"lurker")` has every key of 4.1 (and the six system keys), with these types: `lit_takes` bool, `peek_every` an Array of two floats with `[0] < [1]`, the rest floats.
- Ordered by `ORDER`: `back_window`, `stalk_distance`, `scare_calm`, `sated` strictly decrease; `duct_speed`, `creep_scale`, `freeze_time` strictly increase; `drain_reach` never decreases; `peek_every` means strictly increase; `lit_takes` is false only on Apacible; `encounter_every > 0` on all four (only if the author keeps 4.2's values: Pending decisions).
- `back_window` equals OFICINAS' 2.2, 1.8, 1.5, 1.2 exactly.
- No `PROFILES[id]` (the Locust's) has any key of 4.1; `DIFFICULTY.profile(id, &"locust")` equals `PROFILES[id]` (deep compare).
- The Lurker's traits: four lines each, no `·` (U+00B7) or `—` (U+2014), each under 48 characters.

---

## 5. `game/enemies/lurker/lurker_senses.gd`

`extends RefCounted`. Her senses, computed on the machine that drives her (`control == "ai"`), plus the light drain, computed on every machine. "Los suyos": the director never tells her where anybody is. What she perceives feeds the brain; what she must *not* do (the warning) is decided on the truth (6.2), which only ever holds her back.

### 5.1 Data handed to the brain

```gdscript
## One survivor as she has them this tick. `seen` and the perceived fields come
## from her senses; for her prey's seat the senses also fill the truth
## (Percept.victim), which only the warning's restraints and cue_ready() read.
class Seen:
	var seat := -1
	var body: Node3D = null        # null in a harness
	var point := Vector3.ZERO      # feet
	var eye := Vector3.ZERO        # camera
	var view := Vector3.FORWARD    # camera forward, normalised
	var seen := false              # sees() this tick
	var seen_at := -INF            # brain clock of the last sight
	var heard_at := -INF           # last noise she took for theirs (within CHASE_EARSHOT of their last point)
	var lit := false               # SIGHT.lit_point(eye)
	var torch := false
	var hidden := false
	var hide_known := false        # hidden in a locker she saw them get into (saw_hides)
	var hide: Node3D = null        # that locker, when hide_known
	var fair := false              # level.survivor_active(body) and participants[seat] == EXPLORING
	var protected := false         # level.point_protected(point) or lifts.riding.has(seat) or untouchable.has(seat)
	var remote := false            # SIGHT.is_remote(level, body)
	var latency := 0.0             # warning.latency_for[seat] (tests), else 0 until phase 4 (6.3)
	var distance := INF            # her face to their eye
	var behind := false            # SIGHT.behind_of(eye, view, her face)
	var regards := false           # Percept.regarded_by.has(seat): no ray of its own
	var alone := INF               # metres to the nearest other survivor she perceives or remembers

class Percept:
	var grace := false
	var face := Vector3.ZERO
	var room := -1                 # room of her face; -1 inside a network duct
	var in_duct := false           # inside the network ducts (not the crawlable main duct)
	var exit_here := -1            # duct exit index she is at, else -1
	var off_limits := false        # her face is in an off-limits room (never, by her routes; checked)
	var regarded_by: Array[int] = []
	var torch_by: Array[int] = []
	var stretch_exposed := false   # SIGHT.stretch_exposed() of the motion's next stretch
	var moving := false            # motion.route_state() == &"moving"
	var arrived := false           # motion.at_goal() this tick, for the goal last given
	var failed := false            # motion.route_state() == &"blocked"
	var transit: StringName = &""  # body.transit_phase() (2a 7.6): &"" when not between plantas
	var on_channel := false        # held up between the shelves (the loom clip)
	var bodies := {}               # seat -> Seen: seen now, or remembered within `forget`
	var victim: Seen = null        # the truth about brain.prey_seat() (perceived or not); null when none or the seat has no body
	var mask := 0.0                # level.sound_mask(face): the fans (planta 3)
```

### 5.2 Constants

```gdscript
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
## She sees whoever is in the dark to here, without needing a torch
## (OFICINAS 4: ~20 m); into a lit place only this far: the light blinds her.
const SIGHT_DARK := 20.0
const SIGHT_LIT := 4.0
## A lit torch in the dark gives its holder away from this far (the beam).
const BEAM_SEEN := 35.0
## Degrees to either side of where her head looks: all round but straight behind.
const SIGHT_HALF := 110.0
## How often she looks (rays); the restraints are checked every tick.
const SENSE_EVERY := 0.1
## At a grille, listening, she hears this much further.
const LISTEN_EAR := 1.4
## How much of her hearing the fans take at full cover (planta 3; OFICINAS 11.7).
const FAN_DEAF := 0.7
## A torch switched on or off: heard metres before `hearing` (OFICINAS 4: she hears the click).
const TORCH_CLICK := 8.0
## As The Locust's hear_route() and hear() (hotel_locust.gd).
const APPARENT_NEAREST := 3.5
const CHASE_EARSHOT := 9.0
```

### 5.3 API

```gdscript
var level
var body                 # lurker.gd
var graph                # duct_graph (2a), or null
var hearing := 1.0       # profile.hearing
var forget := 12.0       # profile.forget
var listening := false   # set by the brain in LISTEN
var saw_hides := {}      # hide node -> true: lockers she saw somebody get into (who: hide.occupant, read when asked)
var memory := {}         # seat -> Seen (last perceived)
var torch_was := {}      # seat -> bool, for the clicks; a seat not in it yet makes no click
func setup(owner_level, owner_body, duct_graph) -> void
func tune(profile: Dictionary) -> void
## Once per physics tick on the driving machine. `prey_seat`: the brain's.
func perceive(delta: float, clock: float, prey_seat: int) -> Percept
func sees(player: Node3D, ignore_concealment := false) -> bool
## How a noise reaches her: {audible, apparent, distance, muffle, via: "room"|"duct"}.
func hear_route(point: Vector3, radius: float) -> Dictionary
## Called before the survivor is inside (interaction, match_net and bot_body
## call saw_enter() before use_hide()): only the locker is kept.
func saw_enter(hide: Node3D) -> void
## The light she drinks (5.6). Static: every machine calls it with her position.
static func drain_rooms(level, point: Vector3, reach: float, cache: Dictionary) -> Dictionary
```

### 5.4 Sight: `sees(player, ignore_concealment)`

In order:

1. False unless `SIGHT.alive(level, player)` and `level.survivor_active(player)` (no one in a protected room, a car, untouchable or dead is ever seen). False during `body.grace > 0`.
2. Hidden: `return ignore_concealment and saw_hides.has(player.hiding_place)` (she knows which locker she saw them get into, as The Locust's `observed_hide`).
3. Her eye: inside a network duct she sees only from an exit she is at (`body.at_exit() >= 0`; from `exit.position - exit.normal * 0.05`; nothing between exits). Outside, `body.face_point()`.
4. Blinded: `SIGHT.torch_covers(level, player, her face, [body.get_rid()])` → false ("ni a quien la alumbra").
5. Range: `SIGHT_LIT` if `SIGHT.lit_point(level, player.camera.global_position)`, else `BEAM_SEEN` if `player.torch.visible`, else `SIGHT_DARK`. Distance from her eye to their camera over it → false.
6. Angle: the angle between `body.gaze()` and the way to them over `SIGHT_HALF` → false (unless closer than 1.5 m).
7. A clear ray (`SIGHT.clear`, exclude her and them) from her eye to their camera, or to their chest (`camera - (0, 0.6, 0)`).

`perceive()` runs `sees()` for every survivor every `SENSE_EVERY` (staggered: one survivor per tick when there are more than 4); the result stays until the next look. A seen survivor's `Seen` goes into `memory[seat]` with `seen_at = clock`; memory older than `forget` is dropped. `alone` is the straight distance from their point to the nearest other entry of `memory` (INF when none): only who she perceives counts.

### 5.5 Hearing

`body.hear(point, radius)` (the contract, through `hotel_main.locust_hear` and `match_net.noise` as for The Locust) calls `hear_route()`; an audible route goes to `brain.on_heard(route, point)`. Nothing is heard during grace or while `control != "ai"`.

`hear_route(point, radius)`:

- **Missed**: `level.point_protected(point)` (the lobbies and the car: "allí no se oye nada"), another planta (`FLOOR.planta_of(point.y) != FLOOR.planta_of(her face.y)`), or her in transit (`body.in_transit()`, 2a).
- `reach := radius * NOISE.HEARING_SCALE * hearing * body.dull * (LISTEN_EAR if listening else 1.0) * (1.0 - FAN_DEAF * level.sound_mask(face))` (use 0 for the mask when `level` has no `sound_mask`).
- **By the rooms** (not while inside a network duct): the algorithm of `hotel_locust.hear_route()` step for step, with her ear (`face_point()`) for the straight check and `FLOOR.floor_point(face)` as the start of `FLOOR.navigation_path()`. It is copied, not shared, so The Locust's stays byte-identical; merging both into one helper is a later cleanup (note it in `docs/PLAN.md`). `via = "room"`.
- **By the ducts** (none if `graph == null or graph.closed`): 2a's `graph.inbound(point, reach, to_node, room_of)` (2a 5.1, written for this: how the sound goes in by the mouths of the point's room and along the conduit). No second implementation and no constants of its own here.
  - Inside a network duct: `to_node = body.duct_node()` (2a's `motion.near_node`); `apparent = face`; `distance = route.metres`.
  - In a room: for each exit `e` of `graph.exits_of_room(her room)` with a clear ray from her face to `e.position`, `route = inbound(point, reach - face.distance_to(e.position), e.node, room_of)`; `distance = route.metres + face.distance_to(e.position)`, `apparent = e.position`; the smallest wins.
  - Audible when `inbound` says so and `distance <= reach`. `muffle = 0.5 + 0.5 * clampf(distance / 40.0, 0, 1)`, `via = "duct"`.
- The smaller `distance` of the two wins.

**Torch clicks.** Each `perceive()` compares every alive survivor's `torch.visible` with `torch_was[seat]` (a seat not yet in `torch_was` is only recorded: no click on the first look); a change is a noise at `camera.global_position` with `radius = TORCH_CLICK / NOISE.HEARING_SCALE`, through `hear_route()` like any other. The player emits nothing new and nothing goes on the wire (remote torches already arrive in `pack_local()`'s flags): floor 1 is untouched.

### 5.6 The light drain (the tell, OFICINAS 4)

`lurker.gd` calls this every `DRAIN_EVERY` on **every machine** (the host's body and the puppets alike), from her own position, so everybody sees the same lamps without a word on the wire:

```gdscript
## Share of a lamp's light she drinks, from the edge of her reach to right
## under it (the lamp keeps 30 to 60 % of itself).
const DRAIN := Vector2(0.4, 0.7)
const DRAIN_EVERY := 0.1
## Share per second the light comes back after her (and goes when she comes).
const DRAIN_EASE := 1.5
## The tubes flicker while she drinks: so much either way, 7 to 11 times a second.
const DRAIN_WOBBLE := 0.08
## hotel.lit(): drunk past this, a room is dark for the rules (only versus'
## "beber la luz" goes that far; decision 6).
const LIT_DRAIN := 0.9
```

- `drain_rooms(level, point, reach, cache) -> {room_id: amount}`. Lamp points per room, cached in `cache` by manifest identity: for `lamp_of(room) == "troffer"` each `palette.troffers(room)` centre at `y = py + height`; for an archive room, the centre of each `archives[].aisles` rect over it at its ceiling (the battens hang over the aisles, geometry 9.4); for every other lit kind, `hotel.lights[id].global_position`; `"emergency"` rooms have none. For each room on her planta with a lamp point within `reach` (3D, from `point`), `amount = lerpf(DRAIN.y, DRAIN.x, nearest / reach)`. Rooms whose lamps are out (`not hotel.lit(id)` before her drain) are skipped.
- In `lurker.gd`: the **targets** are worked out every `DRAIN_EVERY` (`drain_rooms()` while she is out of the network ducts, not in transit and past her grace; otherwise none). The **applied** amounts move every frame (`_process(delta)`, not the 0.1 s step: at 10 Hz a 7 to 11 Hz tremble would alias into a slow beat): each room's amount moves toward its target at `DRAIN_EASE` per second, and while the target is above 0 the amount sent is that plus `DRAIN_WOBBLE * sin(TAU * f * t + id)` with `f` from `hash(id) % 5 + 7` Hz. `hotel.drain(id, amount)` is called only when it changed by more than 0.01, and once more with 0 when it reaches 0. All the lamps of a room share its one drain, so they dip **together** (the difference from a tube failing on its own, which the hallucinations keep to one lamp).
- **Reduced effects** (`level.hotel.reduced`, as the hotel's flickers): no wobble, only the smooth dip, all together. The tell is a rule and survives the setting; the tremble is presentation.
- `relocate()`, `restore_state()` and `brain.forget_all()` set every target and applied amount to 0 at once (`hotel.drain(id, 0.0)` for each): a stage given back or a checkpoint never keeps a room drained. Nothing of the drain is saved.
- Whether she drains from inside a duct over a room, and whether the freight lobbies (19) are drained at all, are the author's (Pending decisions); as written, no drain from a network duct, and lobbies are drained like any lit room in reach.
- **0e's `lit()`**: if 0e made any drain unlit the room, change `lit()` to `powered and not dark and drained(id) < LIT_DRAIN`. Add `func drained(room_id: int) -> float` if 0e did not. Nothing drains on floor 1, so the hotel is unchanged.
- The hum's pitch falling with the drain is world audio's, phase 3 (it reads `hotel.drained()`).

### 5.7 The percept, every tick

`perceive(delta, clock, prey_seat)` fills, in this order: `grace`; `face`, `room`, `in_duct`, `exit_here`, `off_limits` (from the body and `level.off_limits_rooms()`); `mask`; the motion's `moving`, `arrived`, `failed`, `transit`, `on_channel` (the getters of 8.3); the torch clicks (5.5); `regarded_by`/`torch_by` from `SIGHT.regarders(level, face, [body.get_rid()])` with `lit_face = SIGHT.lit_point(level, face)`, both empty inside a network duct ("por los ductos se la oye y no se la ve"; in the crawlable main duct she is in a real, dark space and the rays work); `stretch_exposed` from `SIGHT.stretch_exposed(level, body.ahead(3.0), ...)` (false in a duct); `bodies` (5.4, with `regards = regarded_by.has(seat)`, `behind`, `distance` filled for every entry: no ray of their own); `victim` = the truth for `prey_seat` (a fresh `Seen` from the body whether perceived or not, `seen` copied from the look, `hide_known = saw_hides.has(body.hiding_place)`, `latency` from `body.warning.latency_for` when it has the seat, else 0 until phase 4), null when `prey_seat < 0` or the seat has no body (a guest who left).

Cost: about 4 rays for `regarders`, up to 12 for the stretch, and up to 8 per `SENSE_EVERY` for sight: under 1500 rays a second with four survivors. Measured on 2c's bench (host, four survivors, her hands' own rays): it must not take the frame rate on High below 60.

---

## 6. `game/enemies/lurker/lurker_warning.gd`: the guarantee, in code

`extends RefCounted`. One object per Lurker, **held by `lurker.gd`** (`var warning`), on the machine in charge (`level.match_net.in_charge()`), whoever drives her: the brain with `control == "ai"`, and phase 4's take request of a human hunter ("Coger: solo desde detrás de alguien. Lanza el aviso de la espalda y la presa tiene su ventana, la misma que con la IA", OFICINAS 7; "coger (siempre con su ventana)", 11.6). Both go through `start()` and `check()`; phase 4 keeps that seam and does not redesign it. The brain gets the object in `setup()`; the harness of 10.2 gives it one of its own. The only way to a take. Its rules are OFICINAS 1 ("antes de cogerte, siempre se oye detrás de ti") and 11.5, and they outrank everything else the brain does.

### 6.1 Data

```gdscript
const TAKE_HOLD := 0.6       # s after the due time the take may still happen (decision 4)
const TAKE_REACH := 3.4      # m from her face to the victim's eye: no take from farther
const LATENCY_CAP := 0.5     # s (decision 3)
const REMOTE_VIEW := 0.1     # remote_player.DELAY: a puppet's view is this late
const EPS := 0.000001
const CUE_SOUNDS := ["res://assets/audio/sfx/lurker/cue_0.wav", "res://assets/audio/sfx/lurker/cue_1.wav", "res://assets/audio/sfx/lurker/cue_2.wav"]
const CUE_CAPTION := "[Algo respira a tu espalda]"
const CUE_CAPTION_NEAR := "[Algo respira cerca]"
## Every warning of the floor: {id, seat, at, window, latency, due, point: [x, y, z],
## outcome: "active"|"taken"|"saved"|"aborted"|"expired", end, by (saver seat, -1),
## reason, take_at (-1), captured (bool), forced (bool: a tool's capture, no
## warning, skipped by audit()), heard_after (-1; phase 4: the victim's machine
## said it played it this many s after `at`)}
var ledger: Array = []
var active := {}              # the ledger entry in hand, or {}
var next_id := 1
var latency_for := {}         # seat -> s, set by tests only; wins over the net
```

`reason` values: `"mirada"` (looked at in the light), `"linterna"` (a torch on her face), `"protegida"` (protected room, car, untouchable), `"escondida"`, `"fuera"` (dead, not exploring, or no body any more: a guest who left), `"con luz"` (a lit room on a difficulty without `lit_takes`), `"lejos"` (not in reach by the end of the hold), `"movida"` (a teleport, a relocation, a stage change, a rejoin), `"forzada"` (a tool's capture, `forced`).

### 6.2 Rules

```gdscript
func can_start(clock: float) -> bool        # active.is_empty()
## Begins a warning behind `seat` now. Returns the entry (also in `active`).
func start(seat: int, clock: float, window: float, latency: float, point: Vector3) -> Dictionary
## Every tick while a warning is active, before anything else the brain does,
## with that tick's truth. Returns &"" (go on), &"saved", &"aborted", &"due"
## (take now) or &"expired". Ends the entry for every verdict but &"" and &"due".
func check(clock: float, v, p, lit_takes: bool) -> StringName
## The take, on the tick check() said &"due": marks the entry "taken" with take_at.
func take(clock: float) -> bool
## The gate (creature.may_capture): true only for the seat of the entry taken on this very tick.
func may_capture(seat: int, clock: float) -> bool
## A tool's capture (executions.forced not empty): logged, never a warning.
func forced_take(seat: int, clock: float) -> void
func captured(cue_id: int) -> void          # begin_capture with execution.cue
func heard(cue_id: int, after: float) -> void
func cancel(clock: float, reason: String) -> void   # active -> "aborted"
## Everything wrong with a ledger ([] when fair). Static: the bots' watcher and the tests call it.
static func audit(log: Array) -> Array[String]
```

- `start`: `due = clock + window + clampf(latency, 0, LATENCY_CAP)`; `outcome = "active"`; appended to `ledger` and kept in `active`.
- `check(clock, v, p, lit_takes)`, in this order, so a save on the last tick wins over the take:
  0. **Abort** `"fuera"` if `v == null` (the seat has no body: a guest who left during the window).
  1. **Abort** if the victim is no longer fair game: `not v.fair` (`"protegida"` when `v.protected`, `"fuera"` otherwise), `v.hidden` (`"escondida"`), `v.lit and not lit_takes` (`"con luz"`), or `p.off_limits` (`"protegida"`).
  2. **Save** if `v.regards` (the victim looks at her in the light or with the torch on her face: `by = v.seat`, `"linterna"` when `p.torch_by.has(v.seat)` else `"mirada"`), else if `p.torch_by` is not empty (`by = torch_by[0]`, `"linterna"`), else if `p.regarded_by` is not empty (`by = regarded_by[0]`, `"mirada"`; decision 1).
  3. **Due** if `clock >= due - EPS` and `v.distance <= TAKE_REACH` (`const TAKE_REACH := 3.4` in this file; the brain reads `WARNING.TAKE_REACH`).
  4. **Expired** if `clock > due + TAKE_HOLD + EPS` (`"lejos"`).
- `take(clock)`: true only if `active` is not empty and `due - EPS <= clock <= due + TAKE_HOLD + EPS`; sets `outcome = "taken"`, `take_at = clock`, `end = clock`, clears `active`.
- `may_capture(seat, clock)`: the last ledger entry with that seat has `outcome == "taken"` and `absf(take_at - clock) <= EPS`. Anything else, any other seat, any other moment: false. A capture can only be the one taken on this tick.
- `forced_take(seat, clock)`: cancels an active entry (`"movida"`) and appends `{id, seat, at: clock, window: 0, latency: 0, due: clock, outcome: "taken", take_at: clock, end: clock, reason: "forzada", forced: true}`.
- `audit(log)` skips entries with `forced`, and flags: an entry `"taken"` with `take_at < due - EPS` or `take_at > due + TAKE_HOLD + EPS`; `due != at + window + latency` (within EPS); `latency` outside `[0, LATENCY_CAP]`; `captured` without `"taken"`; two entries with overlapping `[at, end]`; an entry still `"active"` that is not the last; ids not strictly increasing.

### 6.3 Latency: phase 4's, recorded here

2b has no network (9.1): every latency is 0 except what the tests put in `warning.latency_for`. The latency is frozen into the entry when the warning starts, so the log says exactly what each victim was given.

What phase 4 must build, so that it is not rediscovered then:

- **Measured by the game, the same for both transports.** The host of a Steam match is a `SteamMultiplayerPeer` (`steam_link.gd`, `net_session.gd`), not ENet: reading `ENetPacketPeer.PEER_ROUND_TRIP_TIME` would give 0 there. A ping of the game's own (a time stamp echoed by RPC, a moving average per seat) serves ENet and Steam alike.
- **The sum**: `rtt + remote_player.DELAY + 1 / match_net.SEND_RATE + 1 / 60` (the puppet's lateness, a guest's send period up to 0.05 s, one physics tick), capped at `LATENCY_CAP`. Jitter and a lost reliable packet are what the cap and the claim below are for.
- **A guest's torch**: `TORCH_FACE_ANGLE` stays 20 degrees for everybody in 2b; whether a puppet's torch gets a wider cone (about 30) is phase 4's, with its scenario.
- **The claim** "la estaba mirando" (11.6) arrives as a guest RPC and is folded into `check()` as one more save source, never as a way to skip the window.
- **Acceptance** in `office_late`: `heard_after <= latency`, and the guest's turn reaching the host as a save within `latency`, in 95 % of cues.
- **Rejoin**: `resume_state()`/`push_state()` carry no active warning; a rejoin cancels it with `"movida"`, logged.

The cap itself (0.5 s, decision 3) and whose latency counts are the author's (Pending decisions).

### 6.4 What is logged, and when

- The cue begins: entry appended (`start`). The brain emits `cue_started(entry)`; `lurker.gd` calls `match_net.send_cue()` (9.1: this machine only in 2b).
- Saved, aborted, expired: `end`, `by`, `reason`; `cue_ended(entry)`; `match_net.send_cue_over(id, outcome)`.
- Taken: `take_at`; `took(seat)`; the body calls `level.capture_survivor(victim)` the same tick (8.3), which asks `may_capture()` (true) and, once a capture style exists (phase 3), stages the capture with `data.cue = id`; `begin_capture(execution)` then calls `captured(execution.cue)`. In phase 2 the style is null, so `captured` stays false; the decision is still logged.
- `capture_log()` returns `ledger.duplicate(true)`.

---

## 7. `game/enemies/lurker/lurker_brain.gd`

`extends RefCounted`. Her mind: OFICINAS 4's states, on the machine that drives her. It never touches the scene: it reads a `Percept` (5.1), asks a *world port* (7.9, implemented by `lurker.gd`, faked by the harness of 10.2) for map knowledge, and returns an *intent* (7.10). It draws only from the `rng` it is given (the creature's `rng`, seeded with the floor), in a fixed order.

### 7.1 States and the shared words

| State | `state_name()` | `activity()` | What she does | Clip (forced) |
|---|---|---|---|---|
| `ROAM` | RONDAR | `roam` | By ducts and ceilings, room to room: the director's zone, a noise, or her own round | by motion |
| `LISTEN` | ESCUCHAR | `search` | Still at a grille, inside the duct | `idle` |
| `STALK` | ACECHAR | `chase` (Pending decisions: or a word of her own, `stalk`) | Follows her prey at `stalk_distance`, out of their view | by motion |
| `PEEK` | ASOMARSE | `investigate` | A show at the edge of a view: a peek, or a ceiling cross | `peek` at the spot; by motion on a cross |
| `FREEZE` | QUIETA | `alert` | Seen in the light: still, staring; then backs off slowly | `idle`, then `retreat` |
| `CREEP` | ACERCARSE | `chase` | Prey in the dark (or lit, with `lit_takes`) and back turned: closes in from behind or above | by motion |
| `CUE` | AVISO | `strike` | Behind them at 2 to 3 m: the warning runs | `loom` in a channel, else `idle` |
| `TAKE` | COGER | `capture` | The capture | (the capture style's) |
| `RECOIL` | ESPANTARSE | `recover` | The torch on her face, or a save: `scare`, the shriek | `scare` |
| `FLEE` | HUIR | `withdraw` | Into the nearest duct (2a's `flee_exit()`) | `crawl_fast` |
| `TRANSIT` | TRÁNSITO | `roam` (2a's `in_transit()` true from the drop) | Between plantas through the ducts, unseen: **2a moves her** (2a 7.6); the brain only waits | none (hidden) |
| `WAIT_ABOVE` | ENCIMA | `wait` | On top of a locker somebody is hiding in | `idle` |

Why these words (creature.gd's lists): stalking and closing in are hostile and hunting (the director's PEAK, the dread's worst, no phantom of her meanwhile, run_ledger's chase); a peek and listening are wary and not hostile; the cue and the recoil are engaged; waiting above a locker is The Locust's `wait`; her flight is `withdraw`, in no list; in transit `in_transit()` silences the director.

### 7.2 Constants

**Her paces, one table.** The brain passes the pace with every order (2a's `go_to(point, pace)`, `go_to_exit(exit, pace)`); 2a's own constants are only its defaults. The director makes 2a 7.1 and 9 agree with this table.

| Pace | m/s | Where it comes from | Used by |
|---|---|---|---|
| `CRAWL_SPEED` | 1.35 | OFICINAS 1 "repta a ~1,35"; 2a routes' timing | ROAM, LISTEN travel, STALK, travel to a show |
| `CREEP_SPEED` | 1.0 × `creep_scale` | OFICINAS 4 "a paso lento", "Velocidad al acercarse ×0,8 ... ×1,15": the base is open (Pending decisions) | CREEP, CUE following |
| `SCURRY_SPEED` | 3.5 | OFICINAS 1 "se escabulle a ~3,5"; 2a 7.1 | a ceiling cross |
| `FLEE_SPEED` | 2.0 | OFICINAS 1 "huye a ~2" (2a's `flee()` order runs at 3.5: the brain does not use it, it calls `go_to_exit(routes.flee_exit(...), FLEE_SPEED)`) | FLEE |
| `RETREAT_SPEED` | 0.8 | OFICINAS 4 "retrocede despacio" (2a 7.1 has 2.0, the `retreat` clip's own pace: Pending decisions) | FREEZE's retreat |
| `duct_speed` | 1.2 to 2.4 | the profile (section 4); 2a's motion and routes | inside the ducts, the planta transit |

```gdscript
## m/s. Survivors walk at 3.8 (OFICINAS 1): she is slower than any of them.
const CRAWL_SPEED := 1.35
const CREEP_SPEED := 1.0         # × creep_scale
const SCURRY_SPEED := 3.5
const FLEE_SPEED := 2.0
const RETREAT_SPEED := 0.8
## The warning: from this near to this far behind them (OFICINAS 4: 2 to 3 m),
## and the spot she creeps to. How far she can still take from
## while they drift is WARNING.TAKE_REACH (3.4).
const CUE_RANGE := Vector2(2.0, 3.0)
const CUE_DIST := 2.4
## s of a torch on her face before she recoils (outside a warning: there, one tick).
const TORCH_SCARE := 0.2
## s looked at in the light before she freezes; s unlooked-at before she goes on.
const FREEZE_AFTER := 0.3
const UNFREEZE := 1.0
## s looked at before a peek is over ("se va si se la mira más de un instante").
const PEEK_SEEN := 0.35
const RECOIL_HOLD := 0.5
## Flight: how far (walking metres) an exit may be; how long she stays inside after.
const FLEE_FAR := 40.0
const FLEE_HIDE := 6.0
const STALK_SLACK := 2.0
const STALK_REPATH := 0.5
const CREEP_LOSE := 2.0          # s she cannot get behind them before she drops back to stalking
const LISTEN_TIME := Vector2(4.0, 8.0)
const LISTEN_P := 0.5
const SHOW_FIND := 30.0          # m: whom she looks for at the end of a "cruce" lead
const SHOW_WAIT := 10.0
const SHOW_PEEK_P := 0.6         # a peek rather than a ceiling cross
const PEEK_RANGE := Vector2(5.0, 16.0)
const CROSS_LENGTH := Vector2(4.0, 9.0)
const WAIT_ABOVE := Vector2(20.0, 40.0)
const SEARCHED_FOR := 60.0
const SWITCH_MARGIN := 0.3
const CHASE_EARSHOT := 9.0
const CLUE_FOR := 20.0           # s a noise stays worth going to
const SCARE_SOUNDS := ["res://assets/audio/sfx/lurker/scare_0.wav", "res://assets/audio/sfx/lurker/scare_1.wav"]
const SCARE_GAIN := -2.0
```

### 7.3 Members and API

```gdscript
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
enum State { ROAM, LISTEN, STALK, PEEK, FREEZE, CREEP, CUE, TAKE, RECOIL, FLEE, TRANSIT, WAIT_ABOVE }
signal cue_started(entry: Dictionary)
signal cue_ended(entry: Dictionary)
signal scared(cause: String, seat: int)      # sanity's hit for whoever saw it is phase 3's
signal took(seat: int)
var world                                    # 7.9
var rng: RandomNumberGenerator
var warning                                  # lurker.gd's (6), or the harness's
var clock := 0.0
var state := State.ROAM
var state_time := 0.0
var prey := -1                               # seat
var lead := {}                               # {point, radius, until, kind, rooms, once, sniff}
var clue := {}                               # {point, at}
var spurned := {}                            # seat -> clock until which she leaves them be
var sated_until := -INF
var searched := {}                           # room -> clock
var visited := {}                            # room -> clock (staleness of her round)
var show := {}                               # PEEK: {kind: "peek"|"cross", point, path, seat}
var locker: Node3D = null                    # WAIT_ABOVE
var torch_time := 0.0
var regard_time := 0.0
var unregard_time := 0.0
var peek_clock := 0.0
var resume := State.ROAM                     # the state TRANSIT goes back to
## Her numbers (tune(); defaults are Desafiante's):
var window := 1.5
var lit_takes := true
var stalk_distance := 8.0
var freeze_time := 4.0
var scare_calm := 35.0
var creep_scale := 1.0
var peek_every := Vector2(40.0, 65.0)
var sated := 40.0

func setup(port, draws: RandomNumberGenerator, held_warning) -> void
func tune(profile: Dictionary) -> void       # the keys of 4.1
func tick(delta: float, p) -> Dictionary     # the intent (7.10)
func activity() -> StringName
func state_name() -> String
func prey_seat() -> int                      # prey, or the CUE/TAKE victim
func noticing() -> bool                      # prey >= 0 and state in [STALK, CREEP, CUE, PEEK, FREEZE, WAIT_ABOVE, TAKE]
func searched_lately(room: int) -> bool      # searched.get(room, -INF) > clock
func lead_to(point, radius, seconds, kind, once, avoid, sniff) -> bool
## She has reached the zone of her lead (ROAM calls it on arrival; tests call it):
## a "cruce" lead turns into a show (PEEK) for the first fair seat she perceives.
func on_lead_reached() -> void
## A noise she heard: always kept as `clue = {point, at: clock}` (and the prey's
## heard_at refreshed within CHASE_EARSHOT); it moves her only in ROAM and LISTEN.
func on_heard(route: Dictionary, point: Vector3) -> void
func on_saw_enter(hide: Node3D, sure: bool) -> void   # kept; who is inside is read later (Seen.hide)
func on_captured(execution: Dictionary) -> void   # warning.captured(execution.cue)
func on_released() -> void                        # TAKE -> FLEE
func forget_all(rest: float) -> void              # warning.cancel("movida"); prey -1; lead, clue, show, locker cleared; ROAM
## The workbench's keys (2c) and the tests: into a state with what it needs
## ({"seat": n} for STALK/CREEP/WAIT_ABOVE, {"hide": node} for WAIT_ABOVE,
## {"kind": "peek"|"cross"} for PEEK). CUE and TAKE cannot be forced: they
## only come from CREEP and the warning.
func force(next: StringName, data := {}) -> void
```

### 7.4 One tick, in order

`tick(delta, p)`: `clock += delta`; `state_time += delta`.

1. **Grace.** `p.grace`: intent hold, nothing else (no senses, no cue).
2. **Transit.** `p.transit != &""` (2a moves her between plantas, 7.6): state `TRANSIT` (`resume` = `ROAM`), intent `{"do": &"keep"}` (no order: 2a's legs run), nothing else. When `p.transit` is `&""` again: `ROAM`. 2a defers the transit while she is engaged (`strike`, `capture`: CUE, TAKE), so a warning is never cut by it.
3. **The warning.** In `CUE`: `verdict := warning.check(clock, p.victim, p, lit_takes)`:
   - `&"saved"` → `recoil(entry.by, entry.reason)`; `&"aborted"` → `STALK`, except reason `"escondida"` with `p.victim.hide_known` → `WAIT_ABOVE` on that locker (she saw them get in; otherwise she has only their last point: `clue`, `STALK`'s rules); `&"expired"` → `STALK`;
   - `&"due"` → `warning.take(clock)` → `TAKE`, `took.emit(victim)`, intent `{"do": &"take", "seat": victim}` (the body asks for the capture on this same tick, while `may_capture()` holds);
   - `&""` → hold; if the victim has stepped beyond `CUE_RANGE.y`, intent go to `world.behind_point(victim, CUE_DIST)` at creep speed (never faster). Return.
   - What walking away during the window means (as written: the cue can expire `"lejos"` and she goes back to STALK with no calm, so it can start again) is the author's (Pending decisions).
4. **The torch on her face.** Unless in `TAKE`, `RECOIL`, `FLEE`, `TRANSIT`: `torch_time` grows while `p.torch_by` is not empty, else 0; at `TORCH_SCARE` → `recoil(p.torch_by[0], "linterna")`.
5. **Exposure.** `regard_time` grows while `p.regarded_by` is not empty, else 0; `unregard_time` the reverse. In the moving states (`ROAM`, `LISTEN` travel, `STALK`, `PEEK` travel and cross, `CREEP`, `WAIT_ABOVE` travel): if `not p.regarded_by.is_empty() or p.stretch_exposed`, the intent is **hold**: *she only moves along a stretch when nobody has it exposed*; in the dark without a torch nobody does, even looking straight at her. Exceptions: `FREEZE`'s retreat, `FLEE`, `RECOIL`, `TAKE`. Then:
   - `regard_time >= FREEZE_AFTER` in `ROAM`, `LISTEN`, `STALK`, `CREEP`, `WAIT_ABOVE` → `FREEZE` (looked at in the light: "lo que miras no avanza");
   - `regard_time >= PEEK_SEEN` in `PEEK` → `FLEE` (a short one, no spurn: the peek is over).
6. **The state's own behaviour** (7.5).

`recoil(by, cause)`: `RECOIL`; `spurned[prey_or_victim] = clock + scare_calm`; `scared.emit(cause, by)`; `world.scream(p.face)` once (a world sound, 9.2); `warning` already closed by `check()` when it came from a save.

### 7.5 States

**ROAM.** Goal, first that applies: an active `lead` (`clock < lead.until`): the stalest of `lead.rooms` not visited in the last 60 s, nearest by `world.travel_metres()`; for a `"cruce"` lead, see PEEK; for a `sniff` lead (a burnt-out mind), `WAIT_ABOVE` on a locker of the lead's rooms drawn with `rng`; else a fresh `clue` (`clock - clue.at < CLUE_FOR`): `world.clue_point(clue.point)`; else `world.patrol_room()`. Intent go there at `CRAWL_SPEED` (2a's routes choose ducts or ceilings by cost). On `p.arrived`: `visited[room] = clock`; with `LISTEN_P` and an exit in the room → `LISTEN`; a `once` lead ends. On `p.failed`: drop that goal and pick again next tick. A perceived fair seat (7.7) → prey → `STALK`.

**LISTEN.** Intent `{"do": &"listen", "exit": world.exit_of_room(room)}`; `senses.listening = true` while here; hold for `rng.randf_range(LISTEN_TIME)`. A noise → `clue` → `ROAM`; a seen fair seat → `STALK`; timeout → `searched[room] = clock + SEARCHED_FOR`, `ROAM`.

**STALK.** Prey memory from `p.bodies[prey]` (perceived or remembered). Every `STALK_REPATH`: intent go to `world.behind_point(seen, stalk_distance)` at `CRAWL_SPEED` (2a's routes keep her out of lit rooms where they can, and in ducts when the way is lit). Keep within `stalk_distance ± STALK_SLACK`; hold when inside it. `look` = their eye. Then:
- prey gone from memory (older than `forget`) → `clue = {point: last point}`, `ROAM`;
- the prey hidden in a locker she saw them get into (`v.hide_known`) → `WAIT_ABOVE` on `v.hide`;
- `creep_ready(v)`: `v.seen`, `v.fair`, not `v.hidden`, `v.behind`, `v.distance <= stalk_distance + 1`, `v.lit == false or lit_takes`, `p.regarded_by` and `p.torch_by` empty, `clock >= sated_until`, `spurned.get(prey, -INF) <= clock` → `CREEP`;
- `peek_clock` (set to `rng.randf_range(peek_every)` on entering STALK) counts down while `v.seen`; at 0 → `start_show(prey, kind)` with kind `"peek"` at `SHOW_PEEK_P`, else `"cross"`; if `world.show_spot()` finds nothing, `peek_clock = 5.0`.
- prey choice may switch (7.7) while in STALK.

**PEEK** (a show). `show = world.show_spot(seen, kind)`: `{kind, point}` for a peek (a dark doorframe next to their room, on its door-head band; a ceiling corner of a dark room in view; **not** over a partition: OFICINAS 4 names "sobre una mampara", but 2a's shell has no partition tops (Pending decisions, director); 5 to 16 m from their eye, `SIGHT.beside()` of their view, a clear line to it) or `{kind: "cross", path: [a, b]}` (a straight ceiling run of 4 to 9 m in a room they can see, its middle beside their view, at least 6 m from them). Travel there at `CRAWL_SPEED` (exposure rule), then: a peek holds the `peek` clip (4 s, "mira, y desaparece de golpe") looking at them, and ends in `FLEE` (short: out of sight, then `STALK` or `ROAM`) when the clip ends or after `PEEK_SEEN` of being looked at; a cross goes from `a` to `b` at `SCURRY_SPEED` on the ceiling (the exposure rule still holds: nobody looking up, nobody stops her) and on into the dark or a duct. Then `STALK` if she still has prey, else `ROAM`. A show at the end of a director's `"cruce"` lead: on arrival in the lead's zone she looks for the first fair seat within `SHOW_FIND` (dark sight or a torch); none after `SHOW_WAIT` (listening at a grille) → the lead is done, `ROAM`.

**FREEZE.** Intent hold, `look` = the eye of `p.regarded_by[0]`, clip `idle`. Torch → recoil (7.4.4). `unregard_time >= UNFREEZE` → back to the state she froze in (`STALK`/`CREEP`; `ROAM` otherwise): when they look away she comes on. After `freeze_time` of looks: retreat to `world.dark_retreat(regarders' eyes)` at `RETREAT_SPEED` with the `retreat` clip, looking at them, **ignoring exposure**; there, `STALK` (or `ROAM` without prey).

**CREEP.** Target `world.behind_point(v, CUE_DIST)` (on the ceiling over that point: her only surface in a room), repathed every 0.25 s; speed `CREEP_SPEED * creep_scale`; `look` = their eye; exposure rule. Each tick, `cue_ready(p)`:

```
state in [CREEP, WAIT_ABOVE] and v = p.victim and v.seat == prey
and v.seen and v.fair and not v.hidden
and not p.in_duct and not p.off_limits
and CUE_RANGE.x <= v.distance <= CUE_RANGE.y
and v.behind
and p.regarded_by.is_empty() and p.torch_by.is_empty()
and (lit_takes or not v.lit)
and warning.can_start(clock)
and clock >= sated_until and spurned.get(prey, -INF) <= clock
```

→ `entry = warning.start(prey, clock, window, v.latency, p.face)`, `cue_started.emit(entry)`, state `CUE`. Otherwise: not behind for `CREEP_LOSE` → `STALK`; prey not fair or hidden → `STALK` (or `WAIT_ABOVE`); lost → `STALK`'s rules.

**CUE.** Only 7.4.3. Clip `loom` when `p.on_channel`, else `idle`.

**TAKE.** The take intent once (7.10); then hold. `on_captured(execution)` marks the ledger; the capture plays out (phase 3's style). `on_released()` or `capture_length()` elapsed (or no capture started within 0.2 s: nothing to play in phase 2) → `sated_until = clock + sated`, prey -1, `FLEE`.

**RECOIL.** Hold `RECOIL_HOLD` with the `scare` clip (her jump into the pose of the image), looking at whoever scared her; then `FLEE`.

**FLEE.** `exit = world.flee_exit(away_from)` (the scarer's eye, or the regarders', or her prey's; 2a's `routes.flee_exit()`), if within `FLEE_FAR` walking metres; intent `{"do": &"duct", "exit": exit, "speed": FLEE_SPEED}` (2a's `go_to_exit()`: it ends inside the duct at the exit's node, hidden), clip `crawl_fast`, ignoring exposure; inside, hold `FLEE_HIDE`; then `ROAM` (her next goal is planned from the duct). No exit within reach: `world.dark_retreat(away_from)` at `FLEE_SPEED`, then `ROAM`.

**TRANSIT.** Only 7.4.2: 2a's `follow_to_planta()` starts it, 2a's motion carries it (leaving, drop, arriving), and the brain waits with `{"do": &"keep"}` until `p.transit` is `&""`, then `ROAM`. No senses, no cue, no lead meanwhile (`in_transit()` silences the director).

**WAIT_ABOVE.** `locker` = the prey's `v.hide` (set only when `v.hide_known`): from `STALK`, or from a cue aborted `"escondida"`; or a locker of a `sniff` lead's rooms (ROAM), where she waits on a guess. Intent go to `world.above_locker(locker)` (the ceiling over the locker, 2a's tray), then hold, `look` = the locker, for `rng.randf_range(WAIT_ABOVE)`. The occupant leaving (`not v.hidden`) → `CREEP` (she is right above them: often `cue_ready` at once). Timeout or nobody inside (`locker.occupant` empty and not her prey's) → `searched[room]`, `ROAM`. She never opens it (`can(&"wardrobes")` is false).

### 7.6 Transit between plantas (OFICINAS 4, Ductos)

**2a's** (2a 7.6): she never uses the freight lift (`can(&"lifts")` is false, so `lifts.creature_car()` is -1 and `creature_crossing()` skips her); `lifts.follow_players(stage)` calls `follow_to_planta(stage, true)`; 2a times the drop by `duct_speed`, brings her out at `routes.arrival_exit()` (far from the lobby), and its `transit_phase() == &"drop"` is phase 3's hook for the claws outside the cage ("solo sonido; nunca entra en la cabina"). The brain adds nothing but the wait of 7.4.2.

### 7.7 Prey: her own choice, from her own senses

- **Candidates**: `p.bodies` entries with `seen` this look, `fair`, not `hidden`, not spurned; none while `clock < sated_until`.
- **No prey**: the first candidate she perceives (lowest seat when several appear on the same look) unless several, then the best `score`.
- **Score**: `0.6 * clampf(alone / 15.0, 0, 1) + 0.4 * (0.0 if lit else 1.0)`: "la más sola y a oscuras"; the straggler is the one farthest from the others she perceives ("va a por el que se queda atrás").
- **Switch** in `STALK` only (never in `CREEP`, `CUE`, `TAKE`, `WAIT_ABOVE`): to a candidate whose score beats the prey's by `SWITCH_MARGIN`.
- **Noises** never choose prey: they make clues; a noise within `CHASE_EARSHOT` of the prey's last point refreshes `heard_at` (The Locust's rule, in `hotel_locust.hear()`).

### 7.8 The director, adapted (no change to `pacing_director.gd`)

- **Zones only.** `lead_to(point, radius, seconds, kind, once, avoid, sniff)` is accepted only in `ROAM` and `LISTEN` (the `LEADABLE` words) and where `control == "ai"`. Its rooms are `world.lead_rooms(point, radius, avoid)`: the filter of `hotel_locust.lead_to()`: same wing, not void, not off-limits, not in `avoid`, centre within the radius. Then `lead = {...}` and her round goes there; whom she finds is down to her senses. `investigate(point)` (the director's distraction) is a `clue`.
- **Reach with ducts.** `travel_metres(room)` is 2a's routes (doors and ducts), so `reach()`, `menace`, `nearest_walk()`, `pick_target()` and `pressed_in_hiding()` already measure her real way (0a2 split `walk()` and `reach()`).
- **The guaranteed encounter.** `encounter_due()` and the `"cruce"` move call `cross(target)`, which leads her (`kind == "cruce"`, `once`) to a room the target can see 15 to 32 m away. She turns that lead into a show (PEEK): a peek or a ceiling cross at the edge of whoever she finds there. The frequency is the profile's `encounter_every` and `cross` (4.2).
- **Rests.** After a fright she withdraws (not hostile), so the director's `breathe(rest_chase)` follows the end of her hostility as it does for a chase; after a death, `rest_death`. Her own `scare_calm` and `sated` keep her off the same person meanwhile. `dull` (the director's `REST_HEARING` on a rest that was earned) scales her hearing (5.5).
- **Silent** while `in_transit()`.
- `burnt_lead()` needs `activity() == &"roam"`: ROAM qualifies; its sniff becomes a wait on a locker.
- `searched_lately(room)` keeps the director's leads off rooms she has just listened at.

### 7.9 The world port (what the brain asks; `lurker.gd` answers, 8.4)

```gdscript
func behind_point(seen, metres: float) -> Vector3
func flee_exit(away_from: Vector3) -> int
func dark_retreat(away_from: Vector3) -> Vector3
func patrol_room() -> int
func travel_metres(room: int) -> Dictionary
func exit_of_room(room: int) -> int
func room_point(room: int) -> Vector3
func lead_rooms(point: Vector3, radius: float, avoid: Array) -> Array
func clue_point(point: Vector3) -> Vector3
func show_spot(seen, kind: String) -> Dictionary
func above_locker(hide: Node3D) -> Vector3
func scream(point: Vector3) -> void
```

### 7.10 Intents (what the brain returns)

A Dictionary with `"do"` and, always, `"clip"` (`""`: the body chooses by motion) and `"look"` (`Vector3.INF`: the camera that draws her, `lurker_visual.look_point`'s default):

| `do` | Fields | Meaning |
|---|---|---|
| `&"hold"` | | stay where she is, hands planted |
| `&"keep"` | | no order: 2a's motion carries on (the planta transit) |
| `&"go"` | `to: Vector3`, `speed: float`, `exposed_ok: bool` | to her surfaces over `to` (2a resolves the room and the tray point), by her routes (rooms, open doors, ducts) |
| `&"duct"` | `exit: int`, `speed: float` | into the network by that exit, and stay just inside, hidden |
| `&"listen"` | `exit: int` | the same at `CRAWL_SPEED`, and wait there ("quieta en una rejilla") |
| `&"take"` | `seat: int` | the capture (8.3) |

---

## 8. `game/enemies/lurker/lurker.gd`: 2b's part

2a creates the file (the body, its shell, routes, motion, duct graph and visual: `shell`, `routes`, `motion`, `ducts`, `visual`, 2a 8.2). 2b adds the following. Every call into 2a's movement is in `apply_intent()` or in the getters at the end of 8.3; if 2a's names change when it is reviewed, only those change.

### 8.1 Members and the contract

```gdscript
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
var senses
var brain
var warning := WARNING.new()  # 6: held here, on the machine in charge, whoever drives her
var thinking := true          # tests and probes switch the mind off (the senses still answer)
var drained := {}             # room -> applied drain (5.6)
var drain_targets := {}       # room -> target, every DRAIN_EVERY
var drain_clock := 0.0
var drain_reach := 3.5
var drain_cache := {}
var intent := {}

func tune(profile: Dictionary) -> void      # super() (2a: tuning, duct_speed); brain.tune, senses.tune, drain_reach
func activity() -> StringName: return word  # 2a's member: set from the brain where she is driven (8.2), unpacked on a puppet
func mode_name() -> String                  # brain.state_name() where the brain runs; on a puppet, from `word`
func sees(player, ignore := false) -> bool: return senses.sees(player, ignore)
func hear(point: Vector3, radius: float) -> void      # control "ai", grace <= 0: route = senses.hear_route(); audible: brain.on_heard()
func hear_route(point: Vector3, radius: float) -> Dictionary: return senses.hear_route(point, radius)
func watched(point: Vector3) -> bool: return SIGHT.watched(level, point, [get_rid()])
func quarry() -> Node3D                      # the body of brain.prey_seat() when brain.noticing(), else null
func saw_enter(hide: Node3D, sure := true) -> void   # senses.saw_enter(hide); brain.on_saw_enter(hide, sure): called before the survivor is inside
func lead_to(point, radius, seconds, kind, once := false, avoid := [], sniff := false) -> bool: return control == "ai" and brain.lead_to(...)
func investigate(point: Vector3) -> void     # brain.clue
func searched_lately(room_id: int) -> bool: return brain.searched_lately(room_id)
func noticing() -> bool: return brain.noticing()
func relocate(point: Vector3, rest: float) -> void   # super() (2a); brain.forget_all(rest); the drain to 0 (5.6)
func forget_journey(point: Vector3, reason: StringName) -> void   # super() (2a); warning.cancel(brain.clock, "movida") if active
## The gate: the machine in charge only (not `control`: versus' hunter takes
## through the same warning, phase 4); a tool's forced capture is let through
## and logged (2.2).
func may_capture(body: Node3D) -> bool:
	if not level.match_net.in_charge(): return false
	if not level.executions.forced.is_empty():
		warning.forced_take(int(body.slot), brain.clock)
		return true
	return warning.may_capture(int(body.slot), brain.clock)
func cue_of(body: Node3D) -> int             # id of the ledger entry "taken" for that seat this tick, else -1
func capture_log() -> Array: return warning.ledger.duplicate(true)
func begin_capture(data: Dictionary) -> void # brain.on_captured(data) where the brain runs
func end_capture() -> void                   # brain.on_released()
func play_cue(seat, cue_id, point, hold) -> void      # 9.2
func cue_over(cue_id, outcome) -> void       # 9.2
## Tests and the workbench: on the ceiling of the room of `point`, over the
## point's x, z (2a's tray: `shell.state_at()`), facing `toward` (INF: as she
## was), held there. teleport() plus a hold.
func place_over(point: Vector3, toward := Vector3.INF) -> void
## Tests: inside the duct at that exit's node, hidden (2a's go_to_exit() made instant).
func place_in_exit(exit: int) -> void
func debug_lines() -> Array[String]          # 8.7
func debug_state() -> Dictionary             # 8.7
```

`kind_id()`, `can()`, `in_transit()`, `transit_phase()`, `follow_to_planta()`, `den_point()`, `teleport()` and the network state are 2a's and stay as 2a writes them. `tune()` keeps the profile; `hotel_main.arm_creature()` calls it with `level.tuning()` (the merged Lurker profile, 0f).

### 8.2 The physics tick (added to 2a's `_physics_process`)

```
if control == "ai" and thinking:
	var p = senses.perceive(delta, brain.clock, brain.prey_seat())
	intent = brain.tick(delta, p)
	apply_intent(intent)
	word = brain.activity()
	cue = brain.state == BRAIN.State.CUE
draining = not drained.is_empty()
# 2a's motion step for this frame runs after, on what apply_intent() set
drain_clock -= delta
if drain_clock <= 0.0: drain_clock = SENSES.DRAIN_EVERY; drain_targets = (5.6)
```

and in `_process(delta)`, on every machine: the applied drain (5.6).

- `word`, `cue` and `draining` are 2a's packed state (2a 8.3: `word` as an index in `WORDS`, the flags `CUE` and `DRAINING`), so on a puppet `activity()`, `is_hostile()` and the rest answer from what arrives: the dread's aura, `phantom_sight` and `world_audio`'s presence run on every machine. **2a's `WORDS` gets `&"withdraw"` appended at the end** (indices kept). `in_transit()` on a puppet: 2a's packed flags (2a adds a `TRANSIT` bit if `HIDDEN` alone does not tell the drop; the director decides with 2a's review). `mode_name()` on a puppet: the Spanish name of the state that gives `word`.

The brain's signals are connected in `_ready()`: `cue_started` → `level.match_net.send_cue(entry.seat, entry.id, v3(entry.point), entry.due - entry.at)`; `cue_ended` → `level.match_net.send_cue_over(entry.id, entry.outcome)`; `took`, `scared` → nothing yet (phase 3).

### 8.3 `apply_intent(intent)`: the one adaptation point to 2a

Against 2a's orders (2a 7.2). An order is given only when the intent changed (another `do`, or `to` moved more than 0.3 m, or another exit); `go_to*` returning false sets `route_failed` for the percept.

| Intent | 2a's call |
|---|---|
| hold | `motion.hold()` |
| keep | nothing |
| go | `motion.go_to(to, speed)`: 2a resolves `room_at(to)` and the tray point over it; `exposed_ok` is informative (the brain already held when it had to) |
| duct | `motion.go_to_exit(exit, speed)` (ends inside at the exit's node, hidden) |
| listen | `motion.go_to_exit(exit, BRAIN.CRAWL_SPEED)`, then nothing: she stays at the node, at the mouth |
| take | `level.capture_survivor(body_of(seat))` (`level.survivors()` by slot), then `motion.hold()` |
| clip | `clip = CLIPS.find(clip)` (2a's member) when it is not `""`; `""` leaves 2a's motion clips |
| look | `visual.look_point = look` |

**Getters the percept reads** (in `lurker.gd`, over 2a's members; 2a is asked for none of them):

| Getter | Over 2a |
|---|---|
| `face_point()`, `gaze()` | 2a 8.2's (2b may refine the face from the head bone, as `lurker_visual._process()` computes `head`) |
| `in_network_duct() -> bool` | `motion.in_duct and motion.hidden` (the crawlable main duct is not hidden) |
| `duct_node() -> int` | `motion.near_node` |
| `at_exit() -> int` | the exit whose node is `motion.near_node` when `in_network_duct()` and `motion.legs` is empty, else -1 |
| `ahead(metres) -> PackedVector3Array` | the points of `motion.legs` (tray `to` at her face height, band and duct points) over the next `metres`, starting at her face; empty when holding |
| `moving()`, `arrived()`, `route_failed()` | `motion.route_state() == &"moving"`; `motion.at_goal()`; `motion.route_state() == &"blocked"` or the last `go_to*` false |
| `on_channel()` | `motion.state != null and motion.state.patch` is a channel |

### 8.4 The world port (lurker.gd implements 7.9)

Every point it returns is on her surfaces: a ceiling (2a's tray), a band, a channel, or a duct exit. Never the floor.

- `behind_point(seen, metres)`: `flat := seen.eye - flat(seen.view) * metres`, clamped into the room of `seen.point` (`FLOOR.room_at`, its rect less 0.3), at that room's tray height (`shell.state_at()`); if that room is off-limits, the nearest point outside it on the way. With a 2.95 m false ceiling, `metres` 2.4 behind gives her face about 2.2 m up against an eye at 1.64: about 2.5 m in 3D, inside `CUE_RANGE`.
- `flee_exit(away_from)`: 2a's `routes.flee_exit(start, away_from, her point)`; -1 if its walking metres (`travel_metres`) are over `FLEE_FAR`.
- `dark_retreat(away_from)`: the nearest point (her routes) at least 4 m from `away_from` in a room where `not SIGHT.lit_point()`, on its ceiling, else the position of 2a's `routes.nearest_exit(start)`.
- `patrol_room()`: rooms of her planta, not void, not off-limits, not `searched_lately`, farther than 6 m; weight `(1 + minf(clock - visited.get(room, -300), 300) / 60) / (1 + metres / 40)` with `metres = travel_metres(her room)[room]`; drawn with `rng`.
- `lead_rooms()`: the Locust's filter (7.8).
- `clue_point(point)`: the exit of `room_at(point)` nearest the point, else the point (on its ceiling).
- `show_spot(seen, kind)`: the candidates of 7.5 PEEK, filtered by `SIGHT.beside(seen.eye, seen.view, spot)`, a clear line from their eye, `PEEK_RANGE`, a dark room (`not lit_point`) for the spot itself, reachable by her routes; drawn with `rng`. Doorframes: the door-head bands of `FLOOR.doorways()` (2a's shell); corners from the room's tray rect at its height; cross paths along the longer axis of a room's tray rect. No partitions (7.5).
- `above_locker(hide)`: the tray point over `hide.global_position` in its room (the ceiling over the locker; OFICINAS 4 "Encima: sobre la taquilla", "respiración por las lamas" is phase 3's sound).
- `scream(point)`: `level.world_audio.play_at(path, point, SCARE_GAIN)` and `level.match_net.world_sound(path, point, SCARE_GAIN, 0.0)` (the director's pattern, `pacing_director.distraction()`), path drawn with `rng` from `SCARE_SOUNDS`.

### 8.5 Where she starts

2a's `den_point(stage)` (2a 8.2: a ceiling anchor at a share of the planta's walk in `[0.5, 0.8]`); 2a's `arrive()` places her there. 2b adds nothing; `spawn_creature()` only stops calling the Locust's members for her (0.2).

### 8.6 Spawning her before phase 3: `hotel_main.creature_scene`

`office_floor.CREATURE` stays the null creature until phase 3. For the tests and the workbench, `hotel_main` gets:

```gdscript
## The creature to put on the floor instead of the kind's (tests, probes,
## the workbenches): a key of CREATURE_SCENES, or "" for the kind's own.
## --creature=<key> on the command line sets it.
const CREATURE_SCENES := {"locust": "res://game/enemies/locust/locust.tscn", "lurker": "<2a's playing scene>", "none": "res://game/enemies/null_creature.tscn"}
var creature_scene := ""
```

`spawn_creature()` instantiates `load(CREATURE_SCENES[creature_scene])` when it is set, else `kind.CREATURE` as now. Read the argument where the other user arguments are read (`_enter_tree`). Floor 1 with no argument is unchanged.

### 8.7 The observer's lines

`debug_lines()`: `["LURKER (%s)" % control, "  %s, presa %s, gracia %0.1f" % [state, prey or "-", grace], "  %s" % ("en ducto, nodo %d" or "sala %d"), "  aviso: %s" % ("%0.1f de %0.1f s" or "-"), "  avisos %d: %d cogidas, %d salvadas, %d dejadas" % counts]`. `debug_state()`: `{"modo", "mando", "donde", "presa", "aviso": active entry or {}, "avisos": ledger size}`. The gizmos (ducts, shell, the cue ring) are phase 3's.

---

## 9. The cue in the ears (and, in phase 4, on the wire)

### 9.1 `game/net/match_net.gd`: this machine only

OFICINAS 15 leaves the network to phase 4 ("Estado y eventos, latencia, reincorporación y protocolo"), nothing in 2b would exercise an RPC, `creature_contract_test` holds `RPCS` to the hotel's table, and `spec_f3_integration.md` reserves a single `creature_event` and one `PROTOCOL` bump ("never twice before a release"). So 2b adds **no RPC and no `PROTOCOL` change**, only the two calls the body uses, with the seam ready:

```gdscript
## Her warning behind somebody (docs/OFICINAS.md 1), decided on the machine in
## charge: played here from where she really is. Phase 4 also sends it, reliable,
## to every machine (the victim's in its own ears), as one creature_event.
func send_cue(seat: int, cue_id: int, point: Vector3, hold: float) -> void:
	if is_instance_valid(level.creature): level.creature.play_cue(seat, cue_id, point, hold)

## That warning is over here (phase 4: and on every machine).
func send_cue_over(cue_id: int, outcome: String) -> void:
	if is_instance_valid(level.creature): level.creature.cue_over(cue_id, outcome)
```

For phase 4 (recorded so it is not rediscovered): the cue and its end ride the one `creature_event` of `spec_f3_integration.md`; the victim's machine answers that it played it (`heard(cue_id, after)`), and the host accepts that answer only from the victim's own peer (`net.seat_of_peer(multiplayer.get_remote_sender_id()) == entry.seat`); `RPCS` in `creature_contract_test` is updated in the same commit; latency as 6.3.

### 9.2 `game/audio/world_audio.gd` and the body's `play_cue()`

```gdscript
## The ears held on a point for a while (her warning): update_ears() aims there
## instead of at her presence or a phantom of it.
var ears_hold := {}                 # {"point": Vector3, "left": float}: counted down every physics tick, sound on or off
## A caption held for a while: no other caption replaces it meanwhile.
var caption_lock := 0.0
## The last warning played here, for the tests (set even when the sound is off).
var last_cue := {}
## Her warning, from where she is: in the victim's own ears on the creature
## buses (binaural: the Ears delay, world_audio.update_ears), heard through the
## floor's routes by anybody else. Never under the fans' mask
## (spec_f1_systems 1.6): the warning always reaches.
func play_cue(path: String, point: Vector3, mine: bool, gain := 0.0) -> AudioStreamPlayer3D
```

- `play_cue`: first, whatever the sound setting, `last_cue = {path, point, mine, time: clock}` and, when `mine`, `ears_hold = {"point": point, "left": stream length}` (the length read from the loaded stream). Then returns null if `not enabled or hush`. Makes an `AudioStreamPlayer3D` at `point` like `play_at()` (unit 6, max distance 40, `area_mask = ACOUSTIC_MASK`, pitch exactly 1.0: the warning is always the same sound).
  - `mine`: `apply_route(voice, {"audible": true, "position": point, "gain": 0.0, "cutoff": 20000.0, "echo": false, "distance": 0.0}, gain, "Threat", true)` (the creature bus, panning 0), **then** `voice.volume_db = gain` and `voice.attenuation_filter_cutoff_hz = 20000.0`: `apply_route()` always takes `REAR_GAIN` (-4 dB) and the `REAR_CUTOFF` low-pass (3200 Hz) off a sound straight behind, and the warning is always straight behind; it would be the one sound dulled most, and its clicks (high-passed at 2 kHz, 9.3) cut. The victim's warning skips head shadow and air.
  - Not mine: `route_source(point)`, inaudible → free it; else `apply_route(..., gain - 6.0, "Threat", true)` (head shadow and air as any sound).
  - No `mask_db()`.
- `_physics_process`: **before** `if not enabled: return` (where `caption_time` is counted down), `ears_hold.left -= delta` and clear it at 0; after it, before `update_ears(target, delta)`, `if not ears_hold.is_empty(): target = ears_hold.point`. Physics time, not the wall clock: deterministic under `--fixed-fps`.
- **Front and back.** `update_ears()` turns `side = sin(atan2(x, -z))`, which is 0 both straight ahead and straight behind: the binaural delay says left or right, never behind. With head shadow skipped for the victim, nothing in the sound itself tells behind from ahead; the rule ("siempre se oye detrás de ti") and the caption do. Say so in LURKER.md (12).
- `show_caption(words, is_presence, hold := 0.0)`: returns early if `caption_lock > 0.0` and `hold <= 0.0`; with `hold > 0`, `caption_lock = hold` and `caption_time = maxf(2.5, hold)`. `caption_lock` counts down with `caption_time`; `reset()` clears both. The hotel never passes `hold`: unchanged.
- `lurker.play_cue(seat, cue_id, point, hold)`: `mine := seat == level.player.slot and level.local_alive() and not level.match_net.local_is_locust()`; `level.world_audio.play_cue(WARNING.CUE_SOUNDS[cue_id % 3], point, mine)`; the caption, shown only when subtitles are on (`hotel_main` already shows `caption_text` only then): mine → `show_caption(WARNING.CUE_CAPTION, false, hold)`; not mine and the route audible within 10 m → `show_caption(WARNING.CUE_CAPTION_NEAR, false)`. Bots on the host: `took`/`cue_started` signals are their hook (phase 3's `bot_threat_lurker`).
- `lurker.cue_over(cue_id, outcome)`: `caption_lock = 0` on this machine if the held caption is the cue's.
- **Hallucinations never fake it** (OFICINAS 5): nothing but `lurker.gd` and `lurker_warning.gd` may name a `lurker/cue_` path, `CUE_SOUNDS` or `CUE_CAPTION`, and nothing but `lurker.gd` may call a room's `.drain(` ("las luces de una sala temblando juntas"). The fairness test scans for all three (10.2). Phase 3: her aura profile uses no breaths (the aura has a breath at its cue point in `dread_aura.gd`, which would sound like the warning's exhalation).

### 9.3 The recordings: `tools/audio/prepare_lurker_sfx.py`

Modelled on `tools/audio/prepare_lift_sfx.py` (its `load`, `trim`, `fade`, `write`; ffmpeg from `tools/trailer3d/audio/dsp.py`; mono, 44.1 kHz, deterministic). Sources in `source_assets/oficinas/audio_criatura/` (outside git), all `status: ok` in its `registro.json`. Only animal recordings, cut and laid side by side: nothing synthesised.

| Copy | Built from | Licence |
|---|---|---|
| `cue_0..2.wav`: one wet exhalation, then two jaw clicks | breath: `breath_horse_bsb/bsb_0285_breath_of_a_horse_1.mp3` and `bsb_1543_breath_horse_4.mp3` (BigSoundBank, CC0); clicks: `bone_celery_bsb/bsb_0596_bones_cracking_1.mp3` (CC0), `bone_knuckles_crack/freesound_community-knuckles-cracking-98331.mp3` (Pixabay) | CC0, Pixabay |
| `scare_0.wav`, `scare_1.wav`: her shriek (not human) | `shriek_barn_owl_bsb/bsb_1400_barn_owl_1.mp3`, `bsb_1403_barn_owl_2.mp3` (CC0) | CC0 |

- **Breath**: the three non-overlapping 0.7 s windows of highest RMS across the two breath files (skip each file's first 0.1 s), in descending RMS; variant `v` takes window `v`; fade in 0.01 s, out 0.12 s.
- **Clicks**: high-pass the click sources at 2 kHz, envelope with a 2 ms window; the strongest peaks at least 0.15 s apart; each click cut from 10 ms before to 70 ms after its peak; variant `v` uses clicks `2v` and `2v + 1`.
- **Layout**: breath at 0; first click at 0.72 s; second at `0.72 + [0.18, 0.22, 0.26][v]`. Total about 1.1 s, under the shortest window (1.2 s): the warning has finished before any take can come. Peak 0.9.
- **Onset**: the script measures each copy's onset (first sample above -30 dBFS) and fails unless it is at most 20 ms: the window counts from `at`, when the sound starts, so the breath must start with it. It prints, and `docs/ASSETS.md` records, the time from onset to the first click of each copy (about 0.72 s: on Pesadilla that leaves about 0.48 s after the first click).
- **Scare**: the loudest 1.4 s of each owl file, fade in 0.005 s, out 0.3 s, peak 0.9.
- Register the five copies in `docs/ASSETS.md` and `docs/asset_hashes.json` like the other `prepare_*` outputs; the BigSoundBank MP3s are to be replaced by their WAVs (RESUMEN item 2), noted in `docs/PLAN.md` section 4.

---

## 10. Tests

Both are `extends SceneTree` with the `check()`/evidence/`quit()` pattern of `tests/hotel/creature_test.gd`; check titles in Spanish; evidence `res://evidence/<name>.json`; they print `PASS`/`FAIL` lines. Both run with `--automation --test-profile --silent` under `--fixed-fps 60` (verify's batch 1). Add `'office/lurker_senses_test'` and `'office/lurker_fairness_test'` to `$tests` in `tools/verify.ps1`. Under `--automation`/`--silent`, `hotel_main` sets `world_audio.enabled = false`: the tests read `last_cue` and `ears_hold`, which 9.2 sets before that check.

**The common floor** (2b-2). `const SEEDS := [2026, 7, 11, 23]`. `level = load("res://game/app/hotel.tscn").instantiate()`, `root.add_child(level)`, `level.drawn_for = 2`, `level.creature_scene = "lurker"`, `level.set_floor(2)`, `await level.start_floor(seed)` with the first seed of `SEEDS` whose planta 0 has what the test needs (each helper says what; the seed used goes into the evidence). Then: `lurker = level.creature`, `lurker.grace = 0.0`, `lurker.thinking = false` unless a case drives the brain, `level.director.process_mode = Node.PROCESS_MODE_DISABLED`, `level.player.set_physics_process(false)` (the test places and turns it), `level.settings.values.subtitles = true`. Placement helpers:

- `place_player(point, yaw, pitch := 0.0)`: `global_position`, `rotation.y = yaw`, `camera.rotation.x = pitch`, `velocity = 0`, three physics frames.
- `aim_at(body, point)`: the yaw and pitch that put `body.camera`'s forward on `point` (local player: body yaw plus camera pitch; a remote body: `camera.look_at(point)`).
- `mate(seat, point, yaw)`: `REMOTE.new()`, `setup(level, seat, "Prueba", 0)`, add as child of `level`, `set_physics_process(false)`, `place(point, yaw)`, `level.match_net.bodies[seat] = mate`, `level.session.participants[seat] = EXPLORING` (as `tests/net/echo_test.gd` does for its mates); removed at the end of the case.
- `lurker.place_over(point, toward)` (8.1): always with `toward` = the victim's camera, so her head (and her sight, 110 degrees each way) faces them. She is always on a ceiling, a band or in a duct, never on the floor (2a). `lurker.place_in_exit(exit)` for a duct.
- `dark(room)` / `light(room)`: `level.hotel.set_room_power(room, false / true)`.

### 10.1 `tests/office/lurker_senses_test.gd` (2b-2)

**Setup helpers.** `line(min_metres)`: on planta 0, the two corridor cells farthest apart on one straight row or column with every cell between them a corridor (step the grid); seeds are tried until it is at least 24 m. `rooms_by_ducts()`: a pair of planta-0 rooms A, B with a `ceiling` exit each, walking metres A to B at least 40, B holding a floor point at least 6 m (in plan) from its exit and 0.5 m from its walls, with the smallest duct-over-walk ratio among such pairs. `lobby()`: planta 0's freight lobby (palette `REFUGE`, 19) and a room across one of its doorways.

Distances below are from her eye to their camera (3D); she hangs from the ceiling, so in plan they are a little shorter.

Sections and checks:

1. **Ver en la oscuridad.** The line dark. Her over one end facing along it; the player at 15 m facing away, torch off: `sees` true. At 22 m: false. Torch on at 22 m (beam toward the far end): true. The line lit: at 6 m false, at 3 m true.
2. **La linterna la ciega.** Line dark. Player at 10 m, `aim_at` her face, torch on: `sees(player)` false. A mate (seat 2) at 12 m in the dark, torch off, looking away: `sees(mate)` true.
3. **Las paredes tapan.** The player in a room next to her cell across a wall with no door (`FLOOR.beside()` with no door edge), 5 m apart, dark: false.
4. **Escondidos y protegidos.** `lurker.saw_enter(hide, true)` with the first locker of planta 0 still empty (as `interaction.gd` calls it), then the player put in it (`hidden = true`, `hiding_place = hide`): `sees(player)` false, `sees(player, true)` true, and the percept's victim (prey = the player) has `hide_known` and `hide == hide`. A second locker never seen: `sees(player, true)` false, `hide_known` false. The player in the freight lobby 3 m from her (she over the room across the doorway), dark: false; `hear_route(player point, NOISE.radius("run"))` not audible.
5. **Oír por las salas.** Line dark, her over one end. A `walk` noise at 7 m: audible, `via == "room"`, muffle 0. A `slam` 60 m away: not audible. A noise in a room off the line reached through a doorway: audible, `apparent` within 1 m of that doorway's portal or an earlier corner, `muffle > 0`.
6. **Oír por los ductos.** A, B from `rooms_by_ducts()`. Her over A's ceiling 1 m from A's exit (`place_over`). A noise 1.5 m under B's grille with `radius` set so the reach is the route plus 2 m (computed in the test from `ducts.inbound()` to A's exit node plus her distance to A's exit, the profile's `hearing`, `HEARING_SCALE`): audible, `via == "duct"`, `apparent` within 0.05 m of A's exit position. The same noise 6 m from B's grille inside B: not audible. Back under the grille, `graph.closed = true`: not audible. The same x, z one planta down: not audible. Her inside A's exit (`place_in_exit`): the first noise audible, `apparent` her face.
7. **El clic de la linterna.** The player dark at 5 m: one `perceive()` with the torch off (records it, no click), then the torch on and one `perceive()`: the brain got a clue within 0.5 m of the player's camera (`brain.clue.point`). At 12 m on Desafiante (8 m reach): nothing.
8. **Las reglas de la mirada** (`creature_sight.gd`), her face as the target, a lit room: the player 6 m away with the view 25 degrees off her face: `regards` true; 35 degrees: false. A mate at 40 degrees: true (remote cone); at 50: false. The room dark, torch off, looking straight at her: false. Torch on, straight: true. Torch on at 1.5 m: `torch_covers` true (no minimum). At 21 m: false. 25 degrees off: false. A wall between: false. `behind_of`: view away from her: true; view 90 degrees off: false; her straight above (60 degrees up) and the view level: true; looking up at her: false.
9. **Lo que se ve de su camino.** `stretch_exposed` over three points ahead of her: a lit room, the player looking at the middle point: true; dark, torch off: false; dark, torch on aimed at it: true; the player looking 60 degrees away: false.
10. **Bebe la luz.** A troffer room R of planta 0, lit: her over a troffer centre (`place_over`). With `level.hotel.reduced = true`: sampled every frame for 0.6 s, `hotel.drained(R)` never decreases, and at 0.6 s it is in `[DRAIN.x - 0.01, DRAIN.y + 0.01]`; `hotel.lit(R)` true. With `reduced = false` and 0.6 s more: in `[DRAIN.x - DRAIN_WOBBLE - 0.01, DRAIN.y + DRAIN_WOBBLE + 0.01]`. A second room of the same circuit not in reach: `drained == 0`. Her moved 8 m into another room: `drained(R) <= 0.01` within 1.0 s. Her inside R's exit (`place_in_exit`): no room drained. `lurker.relocate()` while a room is drained: every room at 0 the same frame.
11. **Elige presa ella.** On a bare brain (`BRAIN.new()` with the fake world of 10.2): one percept with seat 1 seen (lit, `alone` 2 m) → prey 1 (the first perceived). Next look also seat 2 (dark, `alone` 18 m), brain in STALK → prey 2. Brain in CREEP → stays on 1. With seat 2 spurned → stays on 1.
12. **El director solo da zonas.** Brain in ROAM: `lurker.lead_to(point, 12, 30, "merodea", false, [room of the player])` true, and `brain.lead.rooms` holds no off-limits room and not the player's. Forced STALK: `lead_to` false. A `"cruce"` lead and `brain.on_lead_reached()` with seat 1 perceived: state PEEK within one tick, `show.seat == 1`.
13. **Lo que ven los demás.** With `thinking = true` and her forced into STALK: `lurker.word == &"chase"` (or the author's word) and `lurker.cue` false; forced FLEE: `word == &"withdraw"`, and `WORDS.find(&"withdraw")` is the last index.

### 10.2 `tests/office/lurker_fairness_test.gd`

**Part A: in the world** (2b-2; the common floor; `lurker.thinking = true`; latency 0 for the local player). Helper `corridor()`: the lowest-id planta-0 corridor cell whose longer side is at least 8 m, not next to an off-limits room. Per case: `C` = that cell, `along` = unit along its longer side; the player at `C + along * 1.5` facing `+along`; her `place_over(C - along * 0.9, player camera)` (2.4 m behind in plan, her face about 2.2 m up against the eye at 1.64: about 2.5 m, inside `CUE_RANGE`); `brain.force(&"creep", {"seat": player.slot})`; frames are counted; times are `brain.clock` and the ledger's.

1. **De espaldas a oscuras** (C dark, torch off), for each of the four difficulties (`level.set_difficulty(id)`, then `level.arm_creature()`): a cue starts within 0.5 s; `world_audio.last_cue.mine == true`, `last_cue.point` within 0.05 m of `p.face` at the cue, `world_audio.ears_hold.point` the same, `level.ui.subtitle.text == "[Algo respira a tu espalda]"` the next frame; the entry's `window` equals the profile's `back_window`; a take follows with `take_at - at` in `[W, W + 1/60 + 1e-6]`; `outcome == "taken"`; `lurker.may_capture(player)` was true on that tick (record it in a lambda on `took`) and is false on the next. Between cases: `level.release_execution()` if an execution started, `brain.forget_all(0.0)`, the player and her placed again.
   - **The sound itself**, once: `world_audio.enabled = true` for one direct call `world_audio.play_cue(WARNING.CUE_SOUNDS[0], point straight behind the player's camera at 2.4 m, true)`: the player it returns is on the creature bus (`CREATURE_BUS[false]`), `attenuation_filter_cutoff_hz == 20000.0`, `volume_db == 0.0` (no head shadow, no air); freed at once, `enabled` restored.
2. **Darse la vuelta con la linterna a falta de 0,3 s** (C dark, torch on from the start, pointing away), each difficulty: on the first tick where `brain.clock >= due - 0.3`, `aim_at(player, her face)`. Expect `outcome == "saved"`, `by == player.slot`, `reason == "linterna"`, `end < due`, no take, state RECOIL within one tick and FLEE after `RECOIL_HOLD`, `brain.spurned[player.slot] >= end + scare_calm - 0.01`, and `lurker.may_capture(player)` false throughout.
3. **A oscuras, sin linterna, la vuelta no basta** (Equilibrada): the same turn with the torch off: `"taken"` at the due tick.
4. **Con luz** (C lit). Equilibrada: a cue, the same turn without a torch: `"saved"`, `reason == "mirada"`. Apacible: no cue in 3 s (`capture_log()` empty), she holds in CREEP.
5. **La linterna de un compañero** (C dark, the player's torch off), Equilibrada: a mate (seat 2) at `C + along * 4.0 + side * 0.8`, torch on, looking down the corridor away from her; at `due - 0.5`, `aim_at(mate, her face)`: `"saved"`, `by == 2`. A mate looking at her in the dark with the torch off: no save, `"taken"`.
6. **La latencia del que la sufre**: the victim is the mate (seat 2, standing where the player stood, the player parked 30 m away): `lurker.warning.latency_for[2] = 0.25`: `due - at == W + 0.25` within 1e-6; `take_at - at` in `[W + 0.25, W + 0.25 + 1/60]`. `latency_for[2] = 0.9`: `latency == 0.5` (the cap). The mate removed (`bodies.erase(2)`, freed) during the window: `"aborted"`, `"fuera"`, no error.
7. **Nunca en el vestíbulo del montacargas ni en el coche.** The player 1.0 m inside the planta-0 freight lobby from its doorway, back to it; her placed over the room across the doorway, 2.4 m behind; forced CREEP; 4 s: no ledger entry, state never CUE. The player inside the car of gate 0 (`hotel.lifts[0]`, `level.lifts.riding[player.slot] = true`) and her placed 2.4 m behind (placement ignores her routes on purpose): 4 s, no entry. The same in the arrival lobby (10) of planta 1.
8. **Una captura sin aviso no existe**: at ten ticks of cases 1 to 7 drawn with a `RandomNumberGenerator` seeded 9000 (outside a take tick), `lurker.may_capture(player)` false; `WARNING.audit(capture_log())` empty after every case.
9. **Las alucinaciones no la imitan**: every `.gd` under `res://game` (DirAccess, recursive): none but `game/enemies/lurker/lurker.gd` and `lurker_warning.gd` contains `"lurker/cue_"`, `CUE_SOUNDS` or `CUE_CAPTION`; none but `lurker.gd` contains `.drain(` (the definition in `hotel_geometry.gd` is `func drain(`, not a call).
10. **Una herramienta que fuerza la captura**: `level.executions.forced = {"glance": false}`, `lurker.may_capture(player)` true, the last ledger entry has `forced == true` and `reason == "forzada"`, `WARNING.audit(capture_log())` empty; `forced = {}` after.
11. **Darse la vuelta con el mando** (a measurement, recorded, not asserted until the author decides: Pending decisions): with `pad_feel` at the default settings (`pad_look` 2.6) and its minimum (0.6), the stick held at the rim from `at + 0.25` (a reaction), the player's look turned frame by frame from facing away until the camera is within `TORCH_FACE_ANGLE` of her face at a real cue position: the seconds it takes, per difficulty, against `W`, into the evidence. Also with `player.reading = true` at the cue: the time until a look can move at all (it cannot while reading).

**Part B: 200 seeded approaches** (2b-1; no scene, about a second of CPU). A `FakeWorld` inner class answers the port (7.9) with a 1D corridor: `behind_point()` returns `x_victim - metres` on the line, `flee_exit()` 0, `dark_retreat()` 20 m away, everything else trivial; `scream()` counts. The brain is `BRAIN.new()`, `setup(world, rng, WARNING.new())`, `tune(<the profile of id>)` (`LURKER_PROFILES[id]` in 2b-1, 4.1; `DIFFICULTY.profile(id, &"lurker")` once 0f exists), `force(&"creep", {"seat": 1})`. In 2b-1 the brain needs only CREEP, CUE, TAKE, RECOIL and FLEE; the rest can be stubs that hold.

For approach `i` in `0..199`: `id = DIFFICULTY.ORDER[i % 4]`, `W` its `back_window`, `r = RandomNumberGenerator` seeded `7000 + i`, `dt = 1 / 60`. Draws, in this order: start gap `r.randf_range(4.0, 9.0)`; `lit = r.randf() < 0.3`; `torch = r.randf() < 0.4`; `remote = r.randf() < 0.5`, `latency = r.randf_range(0.0, 0.6) if remote else 0.0` (above the cap on purpose); `facing_her = r.randf() < 0.08` (faces her from the start and never turns away); `turn_at = r.randf_range(0.0, W + latency + 0.8) if r.randf() < 0.45 else INF`; `mate_at = r.randf_range(0.0, W + latency + 0.3) if r.randf() < 0.15 else INF`; `walk_at = r.randf_range(0.0, W) if r.randf() < 0.2 else INF`; `protect_at = r.randf_range(0.0, W) if r.randf() < 0.08 else INF`; `hide_at = r.randf_range(0.0, W) if r.randf() < 0.04 else INF`; `protected_from_start = r.randf() < 0.04`; `gone_at = r.randf_range(0.0, W) if r.randf() < 0.03 else INF` (last, so the earlier draws are unchanged).

**Time.** Each tick the harness first sets `t = brain.clock + dt` (the clock `tick()` is about to reach), computes its truth at `t`, builds the percept, then calls `tick(dt, p)`. `at` is the `entry.at` of the cue (the `t` of the tick it started on). An event `x_at` holds on every tick with `t >= at + x_at`; before a cue nothing happens. The oracle uses the same `t` for the same tick.

The harness is her senses: each tick it builds the `Percept` and the victim's `Seen` (seat 1) from its own truth: the victim at `x_v = 0` (moving away at 3.8 m/s from `walk_at`), facing `+x` and turning toward her at 600 degrees a second from `turn_at`; her at `x_l = -gap`, moving toward the intent's `to.x` at the intent's `speed` (hold: still); `distance = sqrt((x_v - x_l)^2 + 1.0)`; `angle` between the victim's facing and the way to her; `behind = angle >= 105`; `regards = angle <= (45 if remote else 30) and (lit or (torch and angle <= 20))`; `torch_by = [1] if torch and angle <= 20 else []`, plus `2` from `mate_at` on; `regarded_by = [1] if regards else []`; `protected` from `protect_at` on (or from the start); `fair = not protected`; `hidden` from `hide_at` on (`hide_known` false); `p.victim = null` from `gone_at` on; `lit`; `remote`; `latency` (in `warning.latency_for[1]`); `seen = true`; `p.off_limits = false`. It runs until 12 s, or until the brain has left CUE and TAKE after a cue.

**The oracle**, independent of the brain: from the cue's tick on, scan the harness's own truth tick by tick at the same `t`; at each tick test, in this order, abort (victim gone, not fair, hidden, `lit and not lit_takes`), save (`regards`, or `torch_by` or `regarded_by` non-empty), take (`t >= due - EPS` and `distance <= TAKE_REACH`), expiry (`t > due + TAKE_HOLD + EPS`), with `due = at + W + min(latency, 0.5)`; the first tick where one holds gives the outcome and its tick. No cue at all is expected when `facing_her` (she is never behind), `protected_from_start`, or Apacible with `lit`.

Checks:

- For all 200, the brain's ledger outcome **and** its `end`/`take_at` tick equal the oracle's exactly.
- Every take the fake world recorded has exactly one ledger entry `"taken"` for seat 1 at the same clock (**every capture paired with its cue**), and no take exists without one; `take_at - at >= window + min(latency, 0.5) - EPS` for every take; no cue started on a tick where the victim was not fair or was regarded; `WARNING.audit(ledger)` empty.
- **Properties that do not copy the order of `check()`:** (a) for every take, no tick in `[at, take_at]` of the harness's truth has a save condition (regards, a torch on her, a regarder); (b) every approach whose truth has a save condition on some tick at or before `due` (and no abort before it) ends `"saved"`, and at least 10 of those have their first save condition in the last 0.1 s before `due`.
- **Coverage**: the counts of taken, saved, aborted, expired and no-cue go into the evidence. Before 2b-1 is handed out, the director runs Part B once against the reference warning and writes the minimum counts here (the draft's guess: 20, 20, 5, 3, 8; property (b) at least 10). A unit that misses them reports it and does not change the draws.
- Evidence: per approach `{i, id, draws, oracle, outcome, at, due, take_at}` and the counts per difficulty.

### 10.3 `tests/hotel/creature_contract_test.gd` (additions, 2b-1)

- "La mirada compartida": `SIGHT.watched()` equals the old `hotel_locust.watched()` body (copied into the test) on 100 seeded points of seed 81's floor; `SIGHT.beside_view()` equals the old `phantom_sight.beside_view()` on 100 seeded directions.
- The Locust: `may_capture(player)` true, `cue_of(player) == -1`, `capture_log().is_empty()`; the null creature the same (if 1a has made it by then).
- `executions.stage_capture()` on the hotel has no `"cue"` key (the payload is unchanged).
- `RPCS` is not touched: 2b adds no RPC (9.1).

`capture_test`, `stages_test`, `sanity_test`, `bots_test`, the net tests and `manifest_golden_test` must stay green: they prove the hotel did not move.

---

## 11. Order of work

### 2b-1 (now: nothing of phase 0 to 2a needed)

1. **Contract and gate** (2.1, 2.2, the forced path). `capture_test`, `creature_contract_test`.
2. **`creature_sight.gd`** and the two delegations (3.3) with their equivalence checks (10.3). `lit_point()` is written against 0e's `hotel.lit()` and is not called on the hotel.
3. **`lurker_warning.gd`** (6).
4. **The brain's warning states** (CREEP, CUE, TAKE, RECOIL, FLEE of 7; the others hold) and **Part B** of the fairness test (`tests/office/lurker_fairness_test.gd` created with Part B only, and added to `verify.ps1`), with the local `LURKER_PROFILES` (4.1): the guarantee is proven before anything else of her mind exists. Acceptance: Part B green with the coverage the director fixed (10.2), its evidence file written.
5. **The recordings**: `prepare_lurker_sfx.py` and its five files (9.3), with the onset check; `docs/ASSETS.md`, `docs/asset_hashes.json`.

**2b-1 as built (24 October 2026, director, with the author's decisions):**

- **Contract and gate** as 2.1 and 2.2. `creature.gd`'s word list gains `stalk` (C8: in `HOSTILE` only, not hunting nor chasing) and `withdraw`; `lurker.gd`'s `WORDS` ends with them. `creature_contract_test` 180/180, with 10.3's three checks (`watched()` and `beside_view()` equal to their old bodies on 100 seeded cases, The Locust and the null creature take with no warning and log nothing; the staged payload is already compared field by field by that test).
- **`creature_sight.gd`** as 3, plus `DARK_FACE` 1.2 m (C7: her face is made out in the dark only this near), `look_of()` (one ray for a regard and a torch), and `rear_of()`/`over_of()` behind `behind_of()` (C5: the cue from above). The delegations name it `SHARED_SIGHT` (The Locust already has `SIGHT_RANGE`; `phantom_sight` and `sanity` use `SIGHT` for other scripts).
- **`lurker_warning.gd`** as 6, and **C3** (leaving during the window saves only running): the entry keeps `ran` (the victim faster than `RUNNING` 5.0 m/s on any tick of the window; `survivor_gait` walks at 3.8, runs at 6.0); at the due time the take holds within `TAKE_REACH`, or within `TAKE_REACH_WALKED` (`TAKE_REACH` plus the long leap's 4.0 m) when they only walked; out of reach after running it is `saved`, reason `"corriendo"`, by the victim. `start()` takes `above` (C5) for the caption `CUE_CAPTION_ABOVE` "[Algo respira sobre ti]" (a proposal: the texts are the author's). `Seen` gains `above` and `speed`.
- **`lurker_brain.gd`**: 2b-1's states (CREEP, CUE, TAKE, RECOIL, FLEE, and FREEZE from a look); the others hold until 2b-2. In CUE, a victim beyond `CUE_RANGE.y` is followed at `CUE_FOLLOW` 3.8 m/s (a walker's pace, C3), and the take intent says `leap` when they are beyond `TAKE_REACH`. `lurker_senses.gd` has only the data classes (5.1) for now.
- **Part B** (`tests/office/lurker_fairness_test.gd`, in `verify`, 9 checks): as 10.2, with two draws added last (so the spec's draws are unchanged): `run_at` (12 %, the victim runs at 6.0 m/s) and a late turn (30 %: `turn_at` set so the first save lands in the last 0.1 s before `due`). The oracle adds C3 (ran, then out of reach at the due time: saved). The first run gave taken 85, saved 53, aborted 25, expired 0, no cue 37, 11 last-moment saves; the minimums are 40, 25, 10, 0, 15 and 10. None expires on a straight corridor (she keeps up with a walker), so the warning's own `"lejos"`, `"corriendo"` and the walked take are checked directly (`rules()`).
- **The recordings** (9.3): the two horse breaths last about 0.7 s each, so each is taken whole from 2 ms before its first sound (copies 0 and 2 share the first, with other clicks and gaps), not three windows of the louder parts. Onsets 15.6 to 16.3 ms, first click 0.704 s after; deterministic. `docs/ASSETS.md` and `docs/asset_hashes.json` register them.

### 2b-2 (after 0b to 0f, phase 1 and 2a, and after 2a's review has fixed its names)

1. **0.2's table redone with a grep**, and its guards, each a pure refactor; `stages_test`, `loop_test`, `rules_test`, `sanity_test`.
2. **Section 4 values** in `difficulty.gd` if 0f left any out; `difficulty_test`; Part B switches to `DIFFICULTY.profile()`.
3. **`lurker_senses.gd`** (sight, hearing through 2a's `inbound()`, drain; `drained()`/`LIT_DRAIN` in 0e's code if needed).
4. **`lurker_brain.gd`**: the rest of the states, prey, leads, the transit wait, wait above.
5. **`lurker.gd`**: contract methods, the warning, `apply_intent()` and the getters (8.3), the world port, the drain, the packed `word`/`cue`/`draining`; `hotel_main.creature_scene`.
6. **The cue in the ears**: `world_audio.play_cue()` and the held ears and caption; `match_net.send_cue()`/`send_cue_over()` (local).
7. **Tests**: `lurker_senses_test`, Part A of `lurker_fairness_test`; `verify.ps1`. Acceptance: both green on the four seeds, case A1's take at `W` on all four difficulties, case A11's figures in the evidence.
8. **Docs** (12).

---

## 12. Docs (Spanish, `docs/` voice; no «·» or «—» in game text)

- `docs/LURKER.md`: a section "Cómo percibe y decide" (sus sentidos, sus estados, la garantía del aviso y su registro, la luz que bebe), and "Lo que falta" updated (2b hecho: sentidos, cerebro, aviso; falta: captura, sonidos de ductos y garras, red, versus). It says honestly that the warning tells left from right but not front from back by sound: the rule and the subtitle say "detrás".
- `docs/OFICINAS.md` 14: under **"Abierto"**, with the label "propuesto por los agentes, pendiente del autor", the decisions of 0.3 and every "For the author" line of the last section. Never in the table "Decidido".
- `docs/DEVELOPMENT.md`: the files of section 1 and how the brain, the senses, the warning and the body talk (percept, intent, world port), the one adaptation point, and the `locust.camera` lines left for phase 4 (0.2).
- `docs/ASSETS.md`, `docs/asset_hashes.json`: 9.3, with each copy's onset and the time to its first click. `docs/PLAN.md` section 4: the WAVs of BigSoundBank still to replace the MP3s; merging the two copies of `hear_route()` into one helper.

---

## 13. Risks

- **2a's names.** 2a is an unreviewed draft. Every call into the movement goes through `apply_intent()` and the getters of 8.3, all in `lurker.gd`, never in the brain; when 2a's review changes a name, only those change.
- **The torch's lag** (decision 2). Using the lamp node's basis would make "turning 0.3 s before the end" fail by a few frames on a quick turn; the camera's aim is the rule, and Part A case 2 holds it to it.
- **The 30-degree border.** Camera sway and the hand's tremor move the view by a few degrees. Tests aim exactly or 5 degrees or more off a border, never on it.
- **`lit()` semantics.** 0e's note in `fase0_pasos.md` says `lit()` is "power and not dark and not drained": with that, her passive drain would make every room she passes "dark" for the rules (looks in the light would stop freezing her and Apacible would refuse cues near lamps). 5.6 fixes the threshold (`LIT_DRAIN`); `lurker_senses_test` 10 checks `lit()` stays true while drained. The director corrects 0e's note before 0e is handed out.
- **Glass.** If 1d gives the glass partitions a collider on layer 1, looks, torches and her sight stop at the glass. That is the conservative side for fairness (she cannot see through, and a torch through glass does not save); if it reads wrong in play, a dedicated layer for glass excluded from `MASK` is the fix.
- **No capture style in phase 2.** `capture_survivor()` returns before the gate while `capture_style()` is null. The ledger records takes regardless, and Part A checks `may_capture()` directly; phase 3's `office_capture_test` must add "every capture's `execution.cue` is a `taken` entry of `capture_log()`".
- **Ray budget.** Exposure is checked every tick for her face and her next stretch. With four survivors that is about 16 rays a tick plus her hands'; measure on 2c's bench (60 FPS on High, host, four survivors) and drop the stretch check to every second tick only if the bench says so, never the cue's checks.
- **Turning round in time** (A11). On the pad at the default sensitivity a half turn takes about 0.85 s (2.6 rad/s, the rim boost after 0.15 + 0.45 s); with a reaction of 0.25 s that is about 1.1 s against Pesadilla's 1.2 s, and at the minimum sensitivity more than any window. Reading a paper blocks the look entirely. The figures go to the author (Pending decisions).
- **Bots turn faster than people.** `bot_body.TURN_RATE` 7 rad/s turns them round in about 0.45 s, and they get the remote cone (3.1). Phase 3's `bot_threat_lurker` must take its turn rate and reaction from a person's figures (A11), or the balance batch shows too many saves.
- **The cue under other sounds.** The fans' mask must not touch it (9.2); the duck (`duck_db()`) applies to the music only. Check in phase 3's `office_audio_test`.
- **The director's PEAK.** Stalking counts as hostile (`chase`), so long stalks run into `peak_max` and a rest, the dread's aura reads 2 the whole stalk, and `lifts.creature_busy()` counts it; whether stalking gets a word of its own is the author's (Pending decisions).
- **Leftover Locust reads** (0.2) crash the moment the Lurker is on a floor; the senses test is the first to put her on one and fails loudly if one is missed.

---

## 14. Pending decisions

### For the author (game, lore, feel)

1. **The six of 0.3**: a teammate's look in the light also saves; the torch counts by the camera's aim; the latency added and its 0.5 s cap; the take up to 0.6 s after the window; no lockers opened, hiding ends the cue; her passive drain never makes a room dark.
2. **Whose latency** (0.3, 3): only the victim's (as OFICINAS 1 says), so a guest covering the host's back must light her about a round trip earlier on their screen; or the largest latency of the survivors with a line to her face; or leave it to phase 4's "la estaba mirando" claim. And whether the 0.5 s cap stays (OFICINAS 1 puts none).
3. **Walking away during the window** (7.4.3): as written the cue expires (`"lejos"`) and can start again at once, so walking on beats it and the cue can repeat over one person. Options: it saves but with a calm before the next cue for that seat; she keeps up with the victim during the window; it counts as expired with a calm per seat. In every case, a minimum gap between two cues for the same seat (and a Part B property for it).
4. **Turning round on the pad** (A11, 13): whether Pesadilla must be beatable on the pad at the default sensitivity; whether the cue closes the paper being read (or frees the look) and whether typing at the counter is the same.
5. **A cue from above** (3.1 `behind_of`): in rooms over 3.3 m she can be "behind" by being above. Does a cue from above exist (its own caption, "encima", and a test), or only from behind horizontally (OFICINAS 1: "siempre se oye detrás de ti")?
6. **Whose room is lit** for "o la sala tiene luz" (OFICINAS 1): as written, the light at her face; a victim in a lit room warned from a dark corridor behind turns, sees her in the dark and is taken. Or the victim's room.
7. **Peeks in the dark** (7.5 PEEK): without a torch nobody makes out her face in a dark spot, so a guaranteed encounter can go unseen and "se va si se la mira" never fires. Is her pale face seen in the dark at a peek's distance (a look of cone and clear ray, no light needed), or does the peek's spot sit at the edge of a lit area?
8. **Stalking's word** (7.1): `chase` (the dread's aura at its worst the whole stalk, the lifts and the director count it as a chase), or a word of her own, `stalk`, hostile but not hunting nor chasing (OFICINAS 4: stalking shows by the claws and the lights, not by dread).
9. **Drain from a duct and the lobbies** (5.6): does she drink the lamps of a room from a duct over it ("luces que tiemblan a su paso"; "siempre hay algo encima")? Are the freight lobbies (19) ever drained (it can read as "she is inside" in the one safe room)?
10. **Her paces** (7.2): what `creep_scale` multiplies (1.0 m/s here, 1.35, her crawl, in 2a's draft: on Desafiante 1.0 against 1.35 m/s); the retreat's pace ("retrocede despacio": 0.8 here, 2.0 in 2a, the clip's own); OFICINAS 1's "en ducto va a ~0,75" against section 4's 1.2 to 2.4 m/s (2a reads 0.75 as the clip's pace seen in the main duct): correct the text of section 1.
11. **New tuning not in OFICINAS** (4.1, 4.2): the keys `sated` and `forget`; `encounter_every` on all four (the hotel has 0 on Desafiante); `cross`, `lead_every`, `peak_*`, `rest_chase`, `ambush` (0.5 on Apacible, where the hotel has 0, against "en Apacible, menos capturas"), `double_back`.

### For the director (contracts, architecture)

1. **2a and 2b agree before either is handed out**: 2a's section 10 and 0f's note use section 4's key names and values (`lit_takes`, `freeze_time`, `creep_scale`, `peek_every`); 2a's 7.1 and 9 take the paces of 7.2; 2a's `WORDS` gets `&"withdraw"` (and `&"stalk"` if the author chooses it); a `TRANSIT` flag in 2a's pack if `HIDDEN` does not tell the drop; 2a's `flee()` order runs at `FLEE_SPEED` or 2b keeps calling `go_to_exit()` itself.
2. **Partition tops**: OFICINAS 4 names "sobre una mampara" for a peek, and 2a's shell has no partition patch. Either 2a adds one (and `show_spot()` its candidates) or the peek on a partition waits; 2b leaves it out meanwhile.
3. **`spec_f3_integration.md` follows 2b**: `brain.state` is an enum (not a StringName), `cue_started(entry)`/`cue_ended(entry)` with the ledger's outcomes (`taken`, `saved`, `aborted`, `expired`), `capture_log()` is the ledger of warnings with `forced` per entry (not one entry per capture), `force()` not `force_state()`, `WAIT_ABOVE`, no `lead_encounter` (a `"cruce"` lead), no `creature_scene_override` (`creature_scene`). Correct f3 before its encargos.
4. **0e's note** in `fase0_pasos.md`: `lit()` with the `LIT_DRAIN` threshold, not "not drained" (13).
5. **The network is phase 4's** (9.1, 6.3): one `creature_event` for the cue and its end, the sender checked against the victim's seat, `RPCS` updated with it, a ping of the game's own for ENet and Steam, the latency sum of 6.3, a wider torch cone for a puppet or not, an active warning cancelled on a rejoin.
6. **Bots and the remote cone** (3.1): `is_remote()` is `body != level.player`, so bots on the host get the 45-degree cone; whether to tell bots apart (a marker on `bot_body.gd`) is the director's.
7. **Part B's coverage minimums** (10.2): run it once against the reference warning and fix them before 2b-1 is handed out.
8. **Phase 3 notes**: her aura profile without breaths (9.2); `bot_threat_lurker` with a person's turn rate and reaction (13); `tools/capture/execution_capture.gd` calls `capture_survivor()` without `forced` and reads `level.locust`: on floor 2 it must set `forced`.

### Notes from step 0f (22 October 2026)

- `game/floors/difficulty.gd` has `CREATURE_PROFILES[&"lurker"]` with the eight keys of OFICINAS 4 that have values, named as 4.1. Out until the author gives numbers: the peeks, `sated`, `forget`, spec_f1_systems 1.8's six system keys and every director adjustment (4.2 is a draft).
- `DIFFICULTY.value(id, key)` still knows no creature: with one of her keys it fails (it always evaluates `PROFILES[REFERENCE][key]`). Phase 2 reads `level.tuning()`, or extends `value()` first.
- `TRAITS` stays indexed by difficulty; her four lines are the author's to write, and the difficulty screen's fixed subtitle (hotel_ui.gd, «LA BESTIA QUE TE ESPERA EN EL HOTEL») will need the floor's creature then.

### Resolved by the author (24 October 2026; .claude/specs/decisiones_fase2_3.md)

- **1, 2, 4, 6, 8, 9, 10, 11:** as recommended: the six rules of 0.3; only the victim's latency, capped at 0.5 s; Pesadilla beatable on the pad at the default sensitivity, and the cue closes the paper being read and stops the typing; "o la sala tiene luz" is the victim's room; stalking has its own word, `stalk`; she drinks lamps from a duct over the room but never in the freight lobbies; `creep_scale` over 1.0 m/s and a 0.8 m/s retreat; the draft's new keys approved, `ambush` 0 on Apacible.
- **3:** leaving during the window **saves only running, not walking**.
- **5:** **a cue from above exists** in rooms over 3.3 m (its own caption and test).
- **7:** her pale face is seen in the dark **only very close**; at middle and long range it is not.
