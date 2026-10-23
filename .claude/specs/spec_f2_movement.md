# Phase 2, step 2a: how The Lurker moves

**Status:** draft reviewed by two critics on 22 October 2026 and corrected; **not approved**. What the critics raised that is a game decision or a contract between areas is in section 15, "Pending decisions".

Read first: `docs/OFICINAS.md` sections 1, 4, 6, 7, 11.4, 11.6 and 15 (fase 2); `docs/LURKER.md` (the visual, how it is driven); `game/enemies/creature.gd` (the contract); `tools/workbenches/lurker_test.gd` (`outline()`, `place()`, `BEND`, `SUSPEND`: the seed of the channel primitive). Manifest keys come from `spec_f1_generator.md` §2.5 and §2.8; `conduit_graph.gd` from `spec_f1_systems.md` §1.5.

**What 2a delivers.** The Lurker as a body that can be told where to go and gets there the way the design says: across ceilings, down and up the band over a door head, held between the shelves of an archive aisle, through her ducts (hidden, heard through the grilles), never through a shut door, never into an off-limits room, between plantas through the ducts. Plus everything of the creature contract that is about where she is: transform, network state, save, teleport, den, travel metres for the director, sound routes.

**Not in 2a.** Senses, states, the back cue, exposure, scare, peeks, light drinking (2b: `lurker_senses.gd`, `lurker_brain.gd`, `creature_sight.gd`); the arena bench (2c); putting her on floor 2 for real, audio, capture, layers on Muy bajo (phase 3); versus driving (phase 4). 2a leaves explicit hooks for all of them (section 8.6).

**Floor 1 is untouched.** Nothing here runs unless an office manifest (`floor == 2`) is built and a Lurker body is instantiated. The only shared files touched are `conduit_graph.gd`, `conduit_metres.gd` (pure refactors, tubes unchanged), `creature.gd` (one default method), `lurker_limbs.gd` (one method), `power_objective.gd` (one query) and `difficulty.gd` (the Lurker's keys, if 0f left any out). `air_objective.gd` is only read (`hatch_open`, `ducts_closed()`).

**Numbering.** Code counts plantas from 0 (`wing`): 0 Personal, 1 Registro, 2 Dirección. Stages are 1-based (`stage - 1 == wing`).

---

## 0. Dependencies and the checks before the `encargos` flow

**Today (22 October 2026) only step 0a is done** (`.claude/relevo.md`): 0b to 0f and phases 1 to 5 are pending. None of `conduit_graph.gd`, `conduit_metres.gd`, `office_palette.gd`, `objective()`, `set_floor()`, `lit()`, `CREATURE_PROFILES`, `power_objective.gd` or `air_objective.gd` exists yet. So 2a is two areas (section 12), each started only when its dependencies are in the tree:

- **2a-I, pure** (shell, duct graph, routes on a stub level, the shell test A to P, the `BODY_DEPTH` measurement): needs 1a, 1b, 1c and the `conduit_graph.gd` of 1e.
- **2a-II, body and probe** (`lurker_motion.gd` with physics, `lurker.gd`, `lurker_creature.tscn`, the small changes of 8.5, the probe): needs 0b, 0c, 0e, 0f and 1d to 1g, and 2a-I approved.

**Who checks.** When each dependency lands, the director (or a reviewer) checks the names below against the code and **corrects this spec** before its area goes through the `encargos` flow. A unit never renames or reinterprets on its own: if a name or a meaning in its encargo does not match the code, it reports it and stops (CLAUDE.md, "Encargos").

The names to confirm:

1. `game/world/generation/conduit_graph.gd` exists with `from_manifest(data, radiate)`, `nodes`, `node_rooms`, `edges`, `adjacency`, `exits` (`{node, room, kind, number, position, normal}`), `closed`, `distances_from()`, `shortest()`, `points_of()`, `point_along()`, `nearest_node()`, `mouths_in_room()`, `sound_route(source, near_node, listener, room_of, world_audio)` (systems §1.5). `conduit_metres.gd` exists with `adjacency()`, `metres()`, `pieces()`, `walk_within()` (generator §2.6).
2. `office_palette.gd`: `WALL_HALF`, `PLENUM`, `TILE`, `false_ceiling(room)`, `ceiling_rect(room) -> Rect2`, `off_limits(room)`, `off_limits_rooms(manifest)`, `height_of(room)`, `ARCHIVE`, `WALL_GRILLE_Y`.
3. Manifest (floor 2): `rooms[i]` with `id, x, z, cols, rows, px, py, pz, span_x, span_z, wing, type, height, open_sides` (`"east"|"west"|"north"|"south"`), `doors: [[other, along]]`; `edges`, `merged`, `adjacency`, `entries`, `seed`; `plenum`; `archives[i].{rooms, axis, spine, aisles}` (rects `[x0, z0, x1, z1]`, world, min-max); `ducts.{nodes: [[x, y, z, room, kind]], edges: [[a, b, metres, kind]], exits: [{node, room, kind, point, yaw}]}` with exit kinds `ceiling|wall|duct|hatch|gap`; `air.hatch.node`, `air.main`.
   - **Gap exits.** Read how 1b stored a gap's `node`. If it is `-1`, or a node with no edge, `duct_graph.gd` attaches it (section 5.2). If it is a real exit node with a drop edge, use it as is.
4. `hotel_main`: `set_floor(n)` (0c), `start_floor(seed, force_fallback, slots, difficulty_id)` (line 627 today), `objective(id: StringName)` (0b's accessor; may return null), `tuning()` (0f, merged with `CREATURE_PROFILES[&"lurker"]`), `off_limits_rooms()` (palette-routed, 1a).
5. `level.hotel.lit(room_id) -> bool` (0e). Door nodes are children of the geometry root named `"Door_%d_%d" % [edge[0], edge[1]]` (`hotel_geometry.gd:1072`; looked up the same way in `code_lock.gd:265` and `tools/capture/preset_tour.gd:88`), with `opened`, `moving`, `locked`, signals `swung(target, slow, forceful)` and `settled(opened)` (`hotel_door.gd`).
6. `DIFFICULTY.profile(id, creature_key)` (0f) and whether 0f already wrote the Lurker keys of section 10. If it did under other names, use 0f's and fix the table in `docs/DEVELOPMENT.md`.
7. `power_objective.gd` (1f): `applied`, `lit_always`. `air_objective.gd` (1g): `hatch_open`, `ducts_closed()`.
8. 0a5's observer gizmo API (`draw_gizmos(g)`: what `g` offers). `resume_state(data)` is already in the contract (`creature.gd:236`, called by `match_net.gd:1102` only when the local player is the hunter): 2a keeps the base no-op (section 8.2).
9. Lamp positions as pure data (for section 3.7): whether 1d's palette exposes `OFFICE.troffers(room)` and the positions of battens and pendants per room from the manifest. If not, section 15 (director) decides where they come from.

---

## 1. Files

| Action | Path | What |
|---|---|---|
| create | `game/enemies/lurker/lurker_shell.gd` | Pure maths: profiles, patches, state, transform, seams. No scene access. |
| create | `game/enemies/lurker/duct_graph.gd` | `extends conduit_graph.gd`: her duct network (wings, gap exits, visible edges, closure). |
| create | `game/enemies/lurker/lurker_routes.gd` | The macro graph (rooms, open sides, doors, exits, ducts), costs, A*, legs, door watching, `travel_metres`, exit choices. |
| create | `game/enemies/lurker/lurker_motion.gd` | Executes legs: speeds, hang and its ray, heading, squeezes, duct travel, planta transit, the jump log. |
| create | `game/enemies/lurker/lurker.gd` | `extends "res://game/enemies/creature.gd"`: the body and the contract. |
| create | `game/enemies/lurker/lurker_creature.tscn` | `CharacterBody3D` root with `lurker.gd`, `BodyShape`, `Visual` (instance of `lurker.tscn`). |
| create | `tests/office/lurker_shell_test.gd` | Pure maths and pure routing (no physics, no floor built). |
| create | `tools/dev/lurker_route_probe.gd` | On a built floor 2: trips, jumps, off-limits, doors shutting, duct speeds, planta transit, net round trip. |
| change | `game/world/generation/conduit_graph.gd` | `fill()` instance method; `nearest_exits()`, `exits_of_room()`, `inbound()` (section 5.1). Tubes unchanged. |
| change | `game/world/generation/conduit_metres.gd` | Public heap helpers if not already (section 5.1). |
| change | `game/enemies/creature.gd` | Default `transit_phase() -> StringName: return &""`. |
| change | `game/enemies/lurker/lurker_limbs.gd` | `func replant() -> void`. |
| change | `game/floors/objectives/power_objective.gd` | `func herds(room: int) -> bool`. |
| change | `game/floors/difficulty.gd` | Lurker keys of section 10, only those 0f did not write. |
| change | `tools/verify.ps1` | `'office/lurker_shell_test'` in `$tests`; an `Add-Check` for the probe. |
| change | `docs/LURKER.md`, `docs/DEVELOPMENT.md`, `docs/OFICINAS.md` (11.4: `duct_graph.gd` extends `conduit_graph.gd`), `docs/PLAN.md` (phase 4 notes) | Spanish, section 14. |
| create | `tools/dev/lurker_depth_probe.gd` | Section 12 step 1: measures `BODY_DEPTH`. Not in `verify.ps1`. |

`lurker.tscn`, `lurker_visual.gd`, `lurker_darkness.gdshader` and `tools/workbenches/lurker_test.gd` are not changed. Commit the `.uid` files Godot writes for every new script.

---

## 2. Frames and conventions

- **The visual's frame** (`lurker_visual.gd`, LURKER.md "En Godot"): its +Y is the surface it clings to, pointing away from that surface; its +Z the way it goes. The bench builds it as `Basis(y.cross(forward), y, forward)` (`lurker_test.gd`, `place()`). The shell returns exactly that: `X = Y.cross(Z)`, `Y = N`, `Z = H`, orthonormal, determinant +1.
- **The body root.** `lurker.gd` is the `CharacterBody3D` root, and its `global_transform` **is** the shell's transform: `global_position` is the anchor, the `Visual` child sits at identity. So `FLOOR.room_at(rooms, global_position)` and `FLOOR.planta_of(global_position.y)` work for her as for anybody: an anchor on a 2.95 m ceiling at `py + 2.6` is on its planta (`planta_of`, floor_definition.gd:103), and so is a duct point at `py + 3.7`.
- **The anchor** is where the visual's origin goes. `hang` is how far the anchor is from the surface along its normal (trays), or radially in from the outline (channels). Her body and head hang about `BODY_DEPTH` further along +Y.
- **World yaw to heading** (for `teleport(point, yaw)`): the forward of a body turned by `yaw` is `Vector3(-sin(yaw), 0, -cos(yaw))` (the Locust's -Z convention, `creature.gd` `gaze()`); it is projected on her tangent plane.
- **No trig in anything sent or saved** is not needed here: her state is host-only and puppets interpolate what they receive. The shell is built from the manifest the same way on every machine anyway.

---

## 3. `lurker_shell.gd`

```gdscript
extends RefCounted
## Where The Lurker can be on a floor of the offices, as surfaces worked out from
## the manifest (docs/OFICINAS.md 11.4): the ceiling of each room (a tray), the
## band over each door head and down a wall to a grille (bands), and the aisles
## of the archives, where she goes held up between the shelves (channels). A
## place on them is a State (patch, u, v, heading, hang), and the transform of a
## State is the one lurker_visual.gd wants: +Y the surface's normal, +Z the way
## she goes. Pure maths: nothing of the scene is read.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
```

### 3.1 Constants (starting values)

```gdscript
enum Kind { TRAY, BAND, CHANNEL }
const BEND := 0.45            ## the round of every seam (lurker_test.gd BEND)
const R_MIN := 0.05           ## no fillet may come out tighter (build fails loudly)
const BAND_CLEAR := 0.35      ## the anchor's distance from ceiling, header and soffit on a band
const DEFAULT_HANG := 0.35    ## = BAND_CLEAR, so tray <-> band seams need no easing
const HANG_MIN := 0.05
const HANG_MAX := 0.9         ## on a tray
const CH_HANG := 0.25         ## in a channel, default (the bench's SUSPEND 0.5 on a 1 m aisle's wall)
const CH_HANG_SHARE := 0.6    ## channel hang <= this x min(width, height) / 2 (no fold)
const OPEN := 2.65            ## door head over the floor (= hotel_geometry.OPENING_HIGH)
const EXPOSED_CEILING := 3.05 ## her ceiling in rooms without a false ceiling: over the door heads, under the main duct's floor (3.1)
const TRAY_INSET := 0.25      ## the anchor keeps this far in from ceiling_rect() on walled sides
const PORTAL_REACH := 1.4     ## a door band reaches this far into each room from the wall's centre line
const WALL_REACH := 1.4       ## a wall band starts this far out from the wall's face
const DIP_RUN := 0.6          ## see 3.4: s = clamp(DIP_RUN - header, 0, DIP_RUN)
const PORTAL_WIDTH := 1.3     ## a door band's v range is +-PORTAL_WIDTH / 2 (= FLOOR.PORTAL)
const WALL_BAND_WIDTH := 1.2
const GRILLE_ABOVE := 0.55    ## a wall band ends this far above its grille's centre
const CHANNEL_MAX := 1.6      ## only aisles narrower than this are channels
const SEAM_TOL := 0.02
```

A test asserts `OPEN == load("res://game/world/hotel/hotel_geometry.gd").get_script_constant_map().OPENING_HIGH` and `PORTAL_WIDTH == FLOOR.PORTAL`, so they cannot drift.

### 3.2 `class Profile` (2D curves, arc-length parameter)

```gdscript
class Profile extends RefCounted:
	var closed := false
	var side := 1.0               ## normal = side * Vector2(-t.y, t.x)
	var pieces: Array = []        ## line: [0, length, start: Vector2, dir: Vector2]; arc: [1, length, centre: Vector2, radius, start_angle, sweep]
	var starts := PackedFloat64Array()   ## cumulative u at each piece's start
	var length := 0.0
	var min_radius := INF
	func at(u: float) -> Array          ## [point: Vector2, tangent: Vector2 (unit)]; closed: u wraps (fposmod); open: clamped to [0, length]
	func normal_at(u: float) -> Vector2 ## side * (-t.y, t.x)
	func sample(step: float) -> PackedVector2Array   ## gizmos and tests
	static func rounded(points: PackedVector2Array, radius: float, side: float) -> Profile
	static func section(width: float, height: float, bend: float) -> Profile
```

- **`rounded()`** fillets an open polyline. For each inner vertex `i`: `d0`, `d1` the unit directions in and out, `theta = d0.angle_to(d1)` (signed; skip below 1e-6). Tangent length allowed: `tau_max = minf(len_prev if i == 1 else len_prev / 2, len_next if i == n - 2 else len_next / 2)` (a segment that starts or ends at an endpoint can give all of itself). `r = minf(radius, tau_max / tan(|theta| / 2))`, `tau = r * tan(|theta| / 2)`. Tangent points `T_in = P[i] - d0 * tau`, `T_out = P[i] + d1 * tau`; centre `T_in + Vector2(-d0.y, d0.x) * r * signf(theta)`; arc from the angle of `T_in - centre`, sweep `theta`. Lines join the tangent points. Track `min_radius`; `build()` pushes an error and the shell test fails if any profile has `min_radius < R_MIN`.
- **`section(w, h, bend)`** is the bench's outline exactly: `r = minf(bend, minf(w, h) / 2 - 0.02)`, closed, counter-clockwise in (across, up) with `x` in `[-w/2, w/2]`, `y` in `[0, h]`, **u = 0 at the middle of the floor**, then the floor towards +x, the right wall up, the ceiling towards -x, the left wall down; `side = 1` (normals inward: the floor's is +y). The test compares it with `lurker_test.gd`'s `outline()` point and normal for the bench's own numbers (11.1 B).
- `at()` on an arc: `angle = start + sweep * s / len`; point `centre + r * (cos, sin)(angle)`; tangent `signf(sweep) * (-sin, cos)(angle)`. Find the piece by binary search on `starts`.

### 3.3 Patches

`var patches: Array[Dictionary]`, indexed; plus lookups `tray_of: Dictionary` (room -> patch), `bands_of` (room -> Array of patch), `band_of_pair` (`Vector2i(min, max)` -> patch), `wall_band_of_exit` (exit index -> patch), `channels_of` (room -> Array of patch). Every record has `kind`, `wing`.

**TRAY** (one per usable room: not void, not in `OFFICE.off_limits_rooms(manifest)`):

```text
{kind: TRAY, room, wing, y: float (world height of her surface),
 rect: Rect2 (x, z: the clamp rect), cell: Rect2 (x, z: the full cell),
 open: {"east": room, ...} (neighbours across open sides that have a tray at the same y)}
```

- `y = py + room.height` if `OFFICE.false_ceiling(room)`, else `py + EXPOSED_CEILING` (service corridors 12, air room 22, plant 23: their slab is at 4.4, the network ducts hang under it with no collider, the main duct's floor is at 3.1; at 3.05 she rides above the door heads and under all of it).
- **Open (section 15, author):** in those three types nothing is at 3.05. The network ducts, the cable tray and its rods have no collider (`spec_f1_geometry` 5.3), the slab is at 4.4, and her hands only ray layer 1 (`lurker_limbs.gd` `world_mask`) within about `ARM_SPAN` 0.88 x 1.35: she would float with nothing to hold. The battens hang at `minf(height - 0.6, 2.9) = 2.9` along the long axis (`spec_f1_geometry` 7.1), in her lane and inside her body. Until the author picks how she goes along a service corridor, these trays are built as written and the probe records, per trip, the metres she spends on them.
- `rect` = `OFFICE.ceiling_rect(room)` (the cell less `WALL_HALF` on walled sides) shrunk by `TRAY_INSET` on every side that is **not** in `open_sides`. Across an open side the rect runs to the cell edge.
- An open side whose neighbour's tray `y` differs by more than 0.001 is treated as walled (none expected: halls share a type; the merged air room and plant share 3.05).
- `u, v` on a tray are world `x, z`. Frame: `Tu = +X`, `Tv = +Z`, `N = (0, -1, 0)`. Anchor `(u, y - hang, v)`.

**BAND** (door band: one per entry of `edges` that is not in `merged` and whose two rooms both have trays; wall band: one per `"wall"` exit, and more on demand):

```text
{kind: BAND, wing, rooms: [a, b] (b = -1 for a wall band), pair: Vector2i or (-1, -1), exit: int or -1,
 origin: Vector3 (on the floor, py), across: Vector3 (unit, horizontal), axis: Vector3 (unit, along the wall),
 width: float, profile: Profile, ends: [tray a, tray b or -1]}
```

- Point `S(u, v) = origin + axis * v + across * p.x + UP * p.y` with `[p, t] = profile.at(u)`; `Tu = across * t.x + UP * t.y`; `Tv = axis`; `N = across * n.x + UP * n.y` with `n = profile.normal_at(u)` (`side = -1`, so `n = (t.y, -t.x)`: down on a ceiling stretch travelled towards +n, back into the room on a wall stretch travelled downwards). **The anchor is the profile point itself**: the profile is already the anchor curve at `BAND_CLEAR`; a State on a band keeps `hang == BAND_CLEAR`.
- `axis = Vector3(-across.z, 0, across.x)`. `v` in `[-width / 2, width / 2]`.

**CHANNEL** (one per rect of `archives[i].aisles` whose short side is under `CHANNEL_MAX`, in units with `mobile == false`; a mobile archive's aisle is where the crank leaves it, OFICINAS 2 "Un pasillo que se abre y se cierra", so it gets no channel until that is decided, section 15):

```text
{kind: CHANNEL, room, wing, origin: Vector3 (floor level, on the aisle's centre line at its mouth),
 axis: Vector3 (along the aisle, mouth -> far end), across: Vector3 (UP.cross(axis)), length: float,
 width: float, height: float (= tray y - py), profile: Profile (section(width, height, BEND)), tray: int}
```

- `room` = `FLOOR.room_at(rooms, rect centre at py + 1).get("id", -1)` (`room_at` returns the room's Dictionary, `{}` outside). `archives[i].rooms` may hold several merged cells and an aisle may cross from one to the next: the channel accepts as its tray, at each point, the tray of `room_at(anchor)` when that tray's `y` equals `tray`'s within 0.001 (`switch_to()` looks it up there, not in `tray` alone). The long side is the axis; the **mouth** is the short side nearer the unit's `spine` rect (compare the distance of each short side's middle to the spine rect's centre line).
- Outline point `o = origin + axis * v + across * p.x + UP * p.y`; section centre `c = origin + axis * v + UP * height / 2`. **Anchor (radial inset, never folds):** `c + (o - c) * maxf(0.0, 1.0 - hang / (o - c).length())`. At the middle of the ceiling stretch this is exactly `hang` under the ceiling, the same point a tray gives (the seam). `N` = the outline's normal at `u` (as the bench: `Y` is the outline's normal, not the inset direction). `Tu = across * t.x + UP * t.y`, `Tv = axis`.
- `hang` in a channel is clamped to `CH_HANG_SHARE * minf(width, height) / 2` (0.30 for a 1.0 m aisle). `u` wraps (closed); `v` in `[0, length]`.
- The walls of the section go up to the room's ceiling although the shelves stop at 2.1 m: above them the hands find the shelf tops and the ceiling by their own rays. Accepted, as in the bench.

### 3.4 Band profiles (numbers for a 2.95 m room)

Let `t = 2 * OFFICE.WALL_HALF` (0.18), `c = BAND_CLEAR`, `hA`, `hB` the two trays' `y - py`, `H = h - OPEN` the header, `s = clampf(DIP_RUN - H, 0, DIP_RUN)`. `n` is measured from the wall's centre line, negative in room `a`.

**Door band**, points then `Profile.rounded(points, BEND, -1)`:

```text
K0 = (-(t/2 + PORTAL_REACH), hA - c)    on a's ceiling
K1 = (-(t/2 + c + sA),       hA - c)    where she starts down
K2 = (-(t/2 + c),            OPEN - c)  under the head, a's side
K3 = ( (t/2 + c),            OPEN - c)  under the head, b's side
K4 = ( (t/2 + c + sB),       hB - c)
K5 = ( (t/2 + PORTAL_REACH), hB - c)    on b's ceiling
```

- 2.95 both sides: `K0 (-1.49, 2.60)`, `K1 (-0.74, 2.60)`, `K2 (-0.44, 2.30)`, `K3 (0.44, 2.30)`, `K4 (0.74, 2.60)`, `K5 (1.49, 2.60)`; every fillet keeps `r = 0.45`; she dips 0.30 m under the head and stays upside down (the header is only 0.30 m).
- The boardroom (3.25, header 0.60, `s = 0`) goes straight down 0.6 m, fillets 0.30. Exposed rooms (3.05, header 0.40, `s = 0.2`) fillet about 0.36.
- `origin = FLOOR.portal_between(a, b)` (on the floor, `py` of `a`); `across` = the unit grid step from `a` to `b` (`(signf(b.x - a.x), 0, 0)` or `(0, 0, signf(b.z - a.z))`); `width = PORTAL_WIDTH`.
- Clearance (tested): the anchor curve stays at least `0.8 * c` from the head's two edges `(+-t/2, OPEN)`, never above `h - c + 1e-4`, never below `OPEN - c - 1e-4`. With 2.95 rooms the nearest approach is about 0.46 m.
- **Open (section 15, author):** under the head the anchor is at 2.30, so with `BODY_DEPTH` 0.7 her body, and the 0.3 m sphere on layer 32, reach down to about 1.58 to 1.60 m, under the top of a survivor's capsule (1.81 m, `player.tscn`): she blocks the doorway at head height (mask 169 includes 32), and, moved by transform, pushes whoever is there. Whether she may is the author's call; the probe measures it (11.2).

**Wall band** (to a grille low on a wall; `n` measured from the wall's inner face, negative in the room):

```text
K0 = (-WALL_REACH, h - c)
K1 = (-c,          h - c)
K2 = (-c,          bottom)     bottom = point[1] - py + GRILLE_ABOVE (0.90 for WALL_GRILLE_Y 0.35)
```

- The shell reads the manifest's raw exits (`manifest.ducts.exits[i]`: `{node, room, kind, point: [x, y, z], yaw}`), not `conduit_graph.exits`, and preloads nothing of the objectives (it stays pure): `across = -(Basis(Vector3.UP, yaw) * Vector3.BACK)` written inline (towards the wall; `Basis(UP, yaw).z` points into the room, the same as `facing(yaw)` of systems §0.2), `origin = Vector3(point[0], py, point[2])`, `width = WALL_BAND_WIDTH`. One 90 degree fillet of 0.45. At `K2` the frame is: `Tu = -UP` (head down), `N = -across` (into the room).
- `func wall_band(room: int, side: String, along: float, bottom: float) -> int` makes one on demand for 2b (stalking down a wall, "sobre una mampara"), cached by `"%d:%s:%0.2f:%0.2f"`. `along` is as `FLOOR.doorways()` gives it. Same profile with `bottom` given.

### 3.5 State and its transform

```gdscript
class State extends RefCounted:
	var patch := -1
	var u := 0.0
	var v := 0.0
	var heading := 0.0     ## radians in the patch's (Tu, Tv) plane: H = Tu * cos(heading) + Tv * sin(heading)
	var hang := DEFAULT_HANG
	func copy() -> State
```

```gdscript
static func build(manifest: Dictionary) -> RefCounted    ## null unless manifest.floor == 2; reads lamp points as 3.7 says
func clear_point(room: int, x: float, z: float) -> Vector2 ## the nearest point of the room's tray rect at least LAMP_CLEAR in plan from every lamp (3.7)
func cue_pose(eye: Vector3, view: Vector3, distance: float) -> State   ## 3.8; null if none
func frame_of(s: State) -> Array                          ## [N, Tu, Tv], unit
func anchor_of(s: State) -> Vector3
func heading_vector(s: State) -> Vector3
func transform_of(s: State) -> Transform3D                ## Basis(Y.cross(Z), Y = N, Z = H), origin = anchor
func set_heading(s: State, world: Vector3) -> void        ## projects on (Tu, Tv); keeps the old heading if the projection is under 1e-4
func advance(s: State, metres: float) -> float            ## moves along the heading; returns the metres actually moved
func clamp_state(s: State) -> void
func max_hang(s: State) -> float                          ## HANG_MAX on a tray; CH_HANG_SHARE * min(w, h) / 2 in a channel; BAND_CLEAR on a band
func tray_state(room: int, x: float, z: float, hang := DEFAULT_HANG) -> State   ## clamped into rect; null without a tray
func state_at(point: Vector3, hang := DEFAULT_HANG) -> State   ## the tray of room_at(point); outside any tray, the nearest tray rect point of that planta (plan distance, ties lower room id)
func band_start(band: int, from_room: int, v := 0.0) -> State  ## u = 0 (from rooms[0]) or length (from rooms[1]), heading into the band (0 or PI)
func band_end_state(band: int, to_room: int) -> State     ## the tray State at the far end, heading kept
func channel_mouth(channel: int) -> State                 ## u at the middle of the ceiling stretch, v = 0, heading PI / 2 (into the aisle), hang = channel entry hang
func channel_u_on_wall(channel: int, side: float, height: float) -> float  ## lurker_test.on_wall() on this section: side -1 left, 1 right, height clamped to [BEND, h - BEND]
func switch_to(s: State, patch: int) -> State             ## the same transform on another patch; null if s is not on a seam to it
func room_of(s: State) -> int
func dump() -> Array                                      ## deterministic plain description (tests)
```

- `transform_of()` must give an orthonormal basis for every valid State: on every patch `Tu`, `Tv` are orthonormal and both are perpendicular to `N` by construction, so `H` is unit and perpendicular to `N`.
- **`advance()`**:
  - TRAY: `(x, z) += (cos, sin)(heading) * m`. Leaving `rect` across an edge that is open (`open[side]`) moves the State to the neighbour's tray at the same world point (identity seam) and continues there with the rest of the metres; any other edge clamps, and the return value is less than `m`.
  - BAND: `u += cos(heading) * m`, `v += sin(heading) * m`, clamped to `[0, length]`, `[-width/2, width/2]`. The parameter is arc length of the anchor curve, so the anchor moves exactly `m`.
  - CHANNEL: `u += cos(heading) * m` (wraps), `v += sin(heading) * m` clamped. The inset anchor moves at most `m`.
- **Seams** (`switch_to()`), all at points where both patches have the same anchor, the same normal and the same tangent plane, so the heading is carried as a world vector and recomputed (`set_heading`):
  - TRAY <-> door BAND: the tray anchor within `SEAM_TOL` of the band's `S(0, v)` (room `a`) or `S(length, v)` (room `b`) for some `v` in range, and `|hang - BAND_CLEAR| < SEAM_TOL`.
  - TRAY <-> wall BAND: the same at `S(0, v)`.
  - TRAY <-> CHANNEL: the tray anchor's lateral offset `d = (anchor - origin).dot(across)` within the flat ceiling stretch (`|d| <= (width - 2 r) / 2`) **and** within `|d| <= SEAM_TOL * (height / 2) / hang` (the radial inset moves a point `d` off the centre line sideways by `d * hang / |o - c|`, with `|o - c| >= height / 2`: about 7 cm at the edge of a 1.6 m aisle's flat stretch, more than `SEAM_TOL`), `v` in `[0, length]`, `hang <= max hang of the channel`; channel `u = u_ceiling_mid - d` (the ceiling is travelled towards -x). The tray's room may be any cell of the unit (3.3).
  - TRAY <-> TRAY across an open side: inside `advance()` (identity).
  - Every other pair: null.
- `channel_mouth()` hang: `minf(BAND_CLEAR, max_hang)` (0.30 in a 1.0 m aisle). The motion eases the tray hang to it before switching.

### 3.6 What the shell does not cover

Floors and plain walls in general (versus, phase 4, will add a WALL patch kind on the same sweep machinery), the plenum over the false ceiling, the crawl spaces and the shaft (ducts are not surfaces: section 7.5). Rooms on another floor kind: `build()` returns null.

**Open (section 15):** OFICINAS asks for her in the plenum in three places (4 "Rondar: Por ductos y plénum"; 2 "Una placa que se mueve, cruje en la perfilería [...] es ella arriba"; the open office "se la oye correr por encima"), the "Encima" posture over a locker (OFICINAS 2 and 4) is out of reach of any tray (a locker keeps the wardrobe's 2.3 m height, `hiding_place.gd:24`, leaving 0.65 m under a 2.95 ceiling, less than `BODY_DEPTH`), and 2b expects floor and wall patches (`spec_f2_mind` 0.1 and 8.3). 2a does not add any of these until they are decided.

### 3.7 Lamps in her way

Troffer omnis sit at `height - LAMP_DROP` (0.35) at the middle of a room (`spec_f1_geometry` 7.1), exactly where a default anchor hangs (hang 0.35) at the room's centre; battens hang at `minf(height - 0.6, 2.9)` over every narrow archive aisle's centre line, where `channel_mouth()` would put her; pendants hang in the boardroom. A body parked in a lamp is inside its light and its shadow.

- `build()` gathers, per room, the lamp points in plan (troffer omnis, battens, pendants) from the palette's pure functions (section 0, check 9), the same on every machine.
- `const LAMP_CLEAR := 1.0`. `clear_point(room, x, z)`: the point of the room's tray `rect` nearest `(x, z)` at least `LAMP_CLEAR` in plan from every lamp of that room; if none exists, the rect point farthest from its nearest lamp (ties: lower x, then lower z).
- **Every default stop goes through it:** the goal point when `go_to_room()` has no point (the room's centre), `den_point()`, the room-centre leg after a planta arrival (7.6), and the tray point of a ceiling, gap or duct exit's `OUT` leg when the next leg ends there. Explicit points (`go_to(point)`, 2b's) are not moved.
- `channel_mouth()` takes the ceiling `u` when the aisle has no batten within `LAMP_CLEAR` of its mouth; otherwise `u = channel_u_on_wall(c, side, 1.8)` on the side farther from the batten (the bench's wall stance).
- Passing under a lamp while moving is accepted (OFICINAS 1: she may cross a lit room by the ceiling); the battens and pendants as obstacles are in section 15 with the service corridors.

### 3.8 The back cue's posture (`cue_pose`)

2b needs the torch to find her face (`TORCH_FACE_ANGLE` 20 degrees, `CUE_RANGE` 1.6 to 3.2 m, `spec_f2_mind.md`), and the face hangs above the victim's eye: on a 2.95 m ceiling at hang 0.35 the face (anchor + 0.45 along +Y) is at 2.15 m, 0.51 m over a standing eye (camera at 1.64), 17.7 degrees at 1.6 m; in the boardroom (3.25) 26.8 degrees at 1.6 m. `cue_pose(eye, view, distance)`: of the tray States in `eye`'s room `distance` behind `eye` (`eye - flat(view) * distance`, clamped into the rect), the one with the smallest hang that keeps the face at most `CUE_ANGLE` (15 degrees) above the horizontal of `eye`, within `max_hang()` and with the measured body clearance (7.1) over the floor of that point; null when none. The face offset is `FACE_OFFSET := Vector3(0, 0.45, 0.3)` in her frame, the same `face_point()` uses (8.2); who defines the face for good, 2a's offset or 2b's head bone, is in section 15. A crouched victim (camera near 0.9 m) has no such pose from any ceiling: section 15 (author).

---

## 4. Seams and speeds in one table

| From | To | Where | Condition |
|---|---|---|---|
| tray | door band | `K0` (a) or `K5` (b), any `v` in the door's width (the router uses `v = 0`) | door open; hang = 0.35; heading within 0.05 rad of into-the-band |
| tray | wall band | `K0`, `v = 0` | hang = 0.35 |
| tray | channel | over the aisle's centre line, any `v` | hang <= the channel's entry hang |
| tray | tray | an open side | identity |
| tray / wall band end | duct | squeeze (7.3) | the exit usable |
| duct | duct | along conduit edges | not `edge_closed` (per wing, 5.2) |

---

## 5. Ducts: `conduit_graph.gd` additions and `duct_graph.gd`

### 5.1 `game/world/generation/conduit_graph.gd` (shared with the tubes)

Pure additions and one refactor. `office_test`, `office_stages_test` and the tube tests stay green.

```gdscript
## The body of from_manifest(), as an instance method, so a script that extends
## this one gets an instance of itself (a static new() would make the base).
func fill(data: Dictionary, radiate: bool) -> void
static func from_manifest(data: Dictionary, radiate: bool) -> RefCounted   ## var g := new(); g.fill(data, radiate); return g
## Exit indices of a room.
func exits_of_room(room: int) -> PackedInt32Array
## The `count` exits nearest `from` along the conduit, {exit, metres} ascending
## (ties: lower exit index). allow(exit_index) -> bool filters; ignore_closed:
## measured even through closed edges (edge_closed(); her way out when the fans start).
func nearest_exits(from: int, count: int, allow := Callable(), ignore_closed := false) -> Array
## A sound made at `point` (heard `radius` out) and somebody inside at node
## `to_node`: it goes in by the mouths of the point's room that are within
## `radius` of it and along the conduit. {audible, metres (in the air plus
## inside), mouth (exit index), apparent (the mouth's position)}. Inaudible
## past REACH inside, from another planta, or with no mouth in reach. For 2b's
## hearing through the ducts ("lo que pasa junto a una rejilla le llega desde el otro extremo").
func inbound(point: Vector3, radius: float, to_node: int, room_of: Callable) -> Dictionary
```

- `nearest_exits` runs `distances_from(from)` once (it is `METRES.metres()`, a binary-heap Dijkstra).
- **What the searches read.** `METRES.metres(conduit, from, ...)` builds its own adjacency from a conduit Dictionary's `edges` (generator §2.6). So `distances_from()`, `shortest()` and `nearest_exits()` must pass the instance's current `nodes` and `edges` (`{"nodes": ..., "edges": edges}`), never the manifest Dictionary kept from `fill()`; otherwise the edges `duct_graph.finish()` adds are not seen. If 1e wrote them otherwise, this is a change to 1e for the director (section 15).
- **Closure per planta.** `func edge_closed(edge: int) -> bool: return closed` in the base (tubes: unchanged, `closed` stays false); every search here skips an edge for which it is true unless `ignore_closed`. `duct_graph` overrides it (5.2).
- **Heap.** If `conduit_metres.gd` keeps its heap private, expose `static func heap_push(heap: Array, item: Array) -> void` and `static func heap_pop(heap: Array) -> Array` (items `[priority, tie, node]`, smallest first, ties by `tie` then `node`) and make its own Dijkstra use them (no behaviour change). `lurker_routes.gd` uses the same two.

### 5.2 `game/enemies/lurker/duct_graph.gd`

```gdscript
extends "res://game/world/generation/conduit_graph.gd"
## Her ducts (docs/OFICINAS.md 4, Ductos): the manifest's network, the same on
## every machine, with what only she needs: the planta of every node, the kind
## of every edge she may be seen in, and the missing tiles as ways in.
var node_wings := PackedInt32Array()      ## FLOOR.planta_of(y) of each node
var node_kinds := PackedStringArray()     ## manifest kind; "gap" for the virtual nodes below
var cell_node := {}                       ## room -> its trunk or branch node
var visible_kinds := ["main", "cross"]    ## inside the crawlable main duct she can be seen (1g builds it)
static func of(manifest: Dictionary) -> RefCounted   ## new(); fill(manifest.ducts, false); finish(manifest)
func finish(manifest: Dictionary) -> void
func edge_between(a: int, b: int) -> int  ## index into edges, -1 if none
func edge_kind(a: int, b: int) -> String
func trunk_nearest(point: Vector3, wing: int) -> int   ## trunk node of that wing nearest in plan (ties lower index)
```

- **`finish()`**: fills `node_wings`, `node_kinds`, `cell_node` (node whose kind is `trunk` or `branch` per room). Then for every exit of kind `"gap"` whose `node` is `< 0` or has no edge, in exit order (deterministic):
  - append the node to **every** per-node array: `nodes` (`PackedVector3Array`, its `point`), `node_rooms` (its room), `node_wings` (its wing), `node_kinds` (`"gap"`), and an empty entry to `adjacency`;
  - append the edge `[new, cell_node[room], distance, "drop"]` to `edges` (index `e`), and to `adjacency` in the base's format in both directions: `adjacency[new].append([cell, distance, e])`, `adjacency[cell].append([new, distance, e])`;
  - set the exit's `node` (and its `position` stays the gap's point).
  Gaps then are ways in and out like grilles (OFICINAS 2: "entra y sale por rejillas y placas que faltan").
- **Closure per planta.** `var closed_wings := PackedByteArray([0, 0, 0])`; `edge_closed(edge)` returns `closed_wings[node_wings[edge's first node]] != 0`. The base's single `closed` stays false for her. While a wing is closed, routes use no duct edge of that wing except to get out (7.6); the other wings are untouched.

---

## 6. `lurker_routes.gd`

```gdscript
extends RefCounted
## How she gets from where she is to where she is going on her planta
## (docs/OFICINAS.md 11.4): rooms, the open sides of halls, the doors that are
## open now, her duct exits and the ducts, searched with A* on what it costs
## her (dark rooms cheap, lit ones dear, the zones the team powered dearer
## still, off-limits rooms not there at all), and laid out as legs she can
## follow: up the band at a door, across a ceiling, down to the next door or
## into a grille. She never opens a door: one that shuts on her route sends her
## another way.
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const METRES := preload("res://game/world/generation/conduit_metres.gd")
```

### 6.1 Constants

```gdscript
const CRAWL_SPEED := 1.35     ## what plans are timed at on surfaces (the clip's 1.0 m/s x 1.35)
const LIT_FACTOR := 6.0       ## a lit room's metres cost this many times a dark one's
const POWER_FACTOR := 25.0    ## a room the team powered on the board or a minutero (wing 1)
const PORTAL_COST := 0.5      ## seconds added for going through a doorway
const ENTER_COST := 1.5       ## seconds to squeeze into a grille (on top of its metres)
const LEAVE_COST := 1.5
const REPLAN_EVERY := 2.0     ## seconds between re-costings while on surfaces (lights change)
const BAN_TIME := 10.0        ## a door she gave up waiting at is left out this long
const ARRIVE_BAND := Vector2(0.5, 0.9)   ## share of the walk from the planta's entry where she comes out after a planta transit
const FLEE_TOWARD := 8.0      ## seconds added to an exit straight towards a threat (flee_exit)
```

### 6.2 The graph

Macro node ids: room `r` is `r` (the global room id, `0..R-1`, `R = manifest.rooms.size()`); duct node `k` is `R + k`. Only rooms with a tray get edges. Built once in `setup()`, from the manifest and the shell; usability and costs are evaluated during the search.

Edge record (Array, for speed): `[to, kind, metres_a, metres_b, room_a, room_b, key]` with

| kind | between | metres_a / metres_b | usable when | cost (seconds) |
|---|---|---|---|---|
| `OPEN` | room, room (merged) | centre of `a` to the shared edge's middle / from there to `b`'s centre | always | `(ma * f(a) + mb * f(b)) / CRAWL_SPEED` |
| `DOOR` | room, room (door band) | `a`'s centre to `K0` + half the band / half the band + `K5` to `b`'s centre | `door_open(key)` and the pair not banned | same, plus `PORTAL_COST` |
| `IN` | room -> exit node | centre to the point under the exit (or the wall band's `K0`) + the wall band's length + the squeeze / 0 | the exit usable (6.3), its drop edge not `edge_closed` | `ma * f(room) / CRAWL_SPEED + ENTER_COST` |
| `OUT` | exit node -> room | 0 / the same metres back | the exit usable | `LEAVE_COST + mb * f(room) / CRAWL_SPEED` |
| `DUCT` | duct node, duct node | conduit metres / 0 | not `ducts.edge_closed(edge)` | `ma / duct_speed` |

`f(room)`: `POWER_FACTOR` if `herds(room)`, else `LIT_FACTOR` if `level.hotel.lit(room)`, else 1.0, worked out **once per `plan()`** for the rooms of the planta (an Array by room id) before the search, never per expansion. `herds(room)`: `level.objective(&"power")` exists, has `herds`, and returns true. Rooms off limits have no node, so no edge reaches them; exits are never in them (validator group 11) and duct edges never cross them (they join grid-adjacent allowed cells).

Room node position (heuristic): the tray anchor at the room's centre (clamped into `rect`), hang 0.35. Duct node position: its conduit node. Heuristic `h(n) = distance(pos(n), pos(goal)) / maxf(CRAWL_SPEED, duct_speed)`: admissible, since every cost is at least metres over the fastest speed.

**A\***: binary heap of `[f, g_tie, node]`, ties by lower node id, closed set; nodes of other wings are never pushed. Deterministic.

### 6.3 API

```gdscript
var level            ## hotel_main, or a stub with: manifest, hotel (lit(), get_node_or_null()), objective(), tuning()
var shell            ## lurker_shell
var ducts            ## duct_graph
var duct_speed := 1.6
var door_epoch := 0  ## bumped by every door signal and whenever door_signature() changes
var last_shut := Vector2i(-1, -1)   ## the last pair a door signal shut (motion reads it, 7.3)
var shut_frame := -1                ## physics frame of that signal
func setup(level, shell, ducts, watch_doors: bool) -> void   ## watch_doors: only for control "ai"
func door_signature(wing: int) -> int   ## hash of (opened, moving, locked) of the wing's doors, at most once per physics frame
func door_open(pair: Vector2i) -> bool
func room_factor(room: int) -> float
func exit_usable(exit: int) -> bool
## start: {"room": r} on a surface, or {"duct": [a, b], "metres": [ma, mb], "point": p} in a duct
## (a, b the two ends of the segment she is on, ma, mb the conduit metres from p to each: she may turn round).
## goal: {"room": r, "point": p (optional)} or {"exit": e, "mouth": bool (optional)} (into that exit and on to its node, or stop at the mouth).
## {ok, cost, nodes: PackedInt32Array, legs: Array, pairs: Array[Vector2i] (doors used), why: String}
func plan(start: Dictionary, goal: Dictionary, from_state: State, from_point: Vector3) -> Dictionary
func travel_metres(room: int) -> Dictionary                 ## {room: metres}, same planta
func nearest_exit(start: Dictionary) -> int                 ## by cost
func flee_exit(start: Dictionary, threat: Vector3, from_point: Vector3) -> int
func arrival_exit(wing: int, rng: RandomNumberGenerator) -> int
func ban(pair: Vector2i, seconds: float) -> void
func tick(delta: float) -> void                             ## ages bans
```

- **`door_open(pair)`**: open sides come **only** from `manifest.merged` (a merged pair -> true, no node looked up). An edge that is not merged: its `Door_a_b` node with `door.opened and not door.moving and not door.locked`; no such node (the stage's last door is built as `ExitDoor` and skipped by name, `hotel_geometry.gd:1059` and `:1502`; the offices' stage 2 has none, `spec_f1_geometry` §12 test 12; or a misspelt name) -> **shut**, with one `push_error` per pair for the session. A door swinging either way is shut for her. So a failed lookup never lets her through a shut door.
- **Door watching.** `setup()` builds `door_nodes: {Vector2i(min, max): node}` from `manifest.edges` (not merged) with `level.hotel.get_node_or_null("Door_%d_%d" % [e0, e1])`. With `watch_doors` it connects `swung` and `settled` of each to `_on_door(pair, target)`: `door_epoch += 1`; if `not target`: `last_shut = pair`, `shut_frame = Engine.get_physics_frames()`. Routes knows nothing of the motion's legs: the motion compares `last_shut` with its `remaining_pairs()` (7.3 step 1). Disconnect all in `teardown()` (called by `lurker.gd` on `_exit_tree` and before a rebuild). Puppets (`control != "ai"`) call `setup(..., false)`: they connect nothing.
- **Doors that change without a signal.** `hotel_door.set_state()` (`hotel_door.gd:92`) emits neither `swung` nor `settled`, and `locked` changes emit nothing. It is called on continuing a floor (`floor_save.gd:88`), by the stage gates (`hotel_geometry.gd:1944`, `:1951`, which also set `locked`), by the net (`match_net.gd:404`, `:1083`) and by the probe. So the signals are only the immediate warning: `door_signature(wing)` hashes `(opened, moving, locked)` of that wing's door nodes in index order, cached per physics frame (`Engine.get_physics_frames()`), and `door_epoch` is bumped whenever it differs from the last one seen. The motion calls it every `REPLAN_EVERY` (7.3 step 1) and `travel_metres()` calls it before reading its cache.
- **`exit_usable(e)`**: kind `"hatch"` needs `level.objective(&"air")` absent or its `hatch_open` true (she never opens the hatch, it is a door); every other kind is always usable. Never an exit of another wing.
- **`travel_metres(room)`**: Dijkstra over the same graph with plain metres (`ma + mb`, conduit metres, no factors, no fixed costs), honouring doors and `edge_closed`. Returns room nodes only. Cached in `{room: [door_signature(wing), closed_wings, result]}`, the key compared on every call; the director calls it every tick (`pacing_director.gd:350`).
- **`arrival_exit(wing, rng)`**: `entry = FLOOR.entry_of(manifest, wing)`; `walk = FLOOR.route_metres(manifest, entry)` (cached per wing); `top` = the largest walk among the wing's rooms with trays. Candidates: exits of the wing of kind `ceiling`, `wall`, `duct` or `gap` whose room's share `walk / top` is in `ARRIVE_BAND`; weight = the share; `rng` draws (cumulative weights, one `randf()`). None in the band: the exit of the farthest room (ties lower exit index). Far from the lift lobby, as OFICINAS 4 asks.
- **`flee_exit()`**: Dijkstra from `start` by cost; each exit node's cost gets `FLEE_TOWARD * maxf(0, cos(angle between exit - from_point and threat - from_point))`; the cheapest wins (ties lower exit index). For 2b's flight to the nearest duct after a scare.

### 6.4 From nodes to legs

`plan()` turns the node path into legs, using her real position for the first leg and the shell for every point.

Leg shapes (Dictionaries):

```text
{"kind": "tray", "to": Vector2 (x, z), "room": r, "hang": float or NAN (keep)}   straight on the ceiling; advance() crosses open sides
{"kind": "band", "patch": b, "dir": 1 | -1, "v": 0.0}                             the whole band, u 0 -> length or back
{"kind": "squeeze", "from": Vector3, "to": Vector3, "into": bool, "exit": e, "basis": Basis}
{"kind": "duct", "nodes": PackedInt32Array, "points": PackedVector3Array, "kinds": PackedStringArray (per segment), "length": float}
{"kind": "turn", "basis": Basis}                                                   inserted by the motion only
{"kind": "drop", "seconds": float, "to_node": int, "wing": int}                    planta transit only
{"kind": "channel", "patch": c, "v_to": float, "u_goal": float}                    2b and the probe only; never planned
```

Rules:

1. **Fixed waypoints** first: a door band's `K0` or `K5` at `v = v_door` (the end on the side she comes from; `v_door` = 0.25 m towards the side away from the hinge, `door.leaf_line()[0]`, so her hands do not go through the open leaf standing beside the frame; 0 with no door node), the tray point under a ceiling, gap, duct or hatch exit (its `x, z`), a wall band's `K0`, the goal (`goal.point` clamped into its room's tray, else `shell.clear_point()` of the room's centre, 3.7).
2. **Open sides** between two fixed waypoints: each crossing point is where the straight line between those two waypoints meets the shared edge, clamped to the edge's span less `TRAY_INSET`. One tray leg per crossing (`to` = crossing point), then one to the next fixed waypoint.
3. `DOOR` edge: tray leg to the band's start (`hang` = 0.35), band leg (`dir` = +1 from `rooms[0]`, -1 from `rooms[1]`).
4. `IN` edge: tray leg to the point under the exit (or, for a wall exit, to the wall band's `K0` with hang 0.35, then a band leg down); a squeeze leg from that anchor to the exit's `point` (`into = true`, `basis` = the transform's basis there); then the duct leg.
5. Consecutive `DUCT` edges merge into one duct leg. Points: `ducts.points_of(nodes)`, with every point of a `main` or `cross` segment lowered by `plenum.main / 2 - 0.02` (on the duct's floor, where the visual can lie). A node shared by a lowered segment and one that is not (the `stub` node `s`, where the network meets the `cross`, generator §2.8 i.6; the main's ends) appears twice: at its conduit height for the network side and lowered for the `cross` side, so the leg has an explicit vertical segment there and never a jump. The first point is her current point when she starts inside a duct. The leg's `kinds` holds a kind per segment (the vertical one takes the lowered side's kind).
6. `OUT` edge: squeeze from the exit's `point` to the tray anchor under it at hang 0.35 (or to the wall band's `K2` anchor, then a band leg up, `dir = -1`), `into = false`, `basis` = the destination's basis.
7. Goal `{"exit": e}`: the legs end with the squeeze into it and the duct leg to its node; goal `{"exit": e, "mouth": true}` (2b's "Escuchar: quieta en una rejilla") ends with the squeeze in and stops there, inside, at the exit's `point`, hidden.

Every waypoint lies inside a tray's `rect` or on a band or exit by construction (the shell test checks band ends and exit points against `rect`).

---

## 7. `lurker_motion.gd`

```gdscript
extends RefCounted
## Her legs followed, one physics frame at a time (lurker.gd calls tick()): the
## pace eased, the heading eased, how low she hangs eased and kept clear of
## what is under her (a ray down every 0.25 s), the squeeze through a grille,
## the ducts at her difficulty's speed, the way down to another planta, and a
## log of every move that is a jump on purpose (the route probe holds her to it).
```

### 7.1 Constants and state

```gdscript
const SCURRY_SPEED := 3.5        ## crawl_fast 2.6 x 1.35
const RETREAT_SPEED := 2.0       ## retreat 1.5 x 1.35
const VENT_CLIP_SPEED := 0.74    ## vent_crawl 0.55 x 1.35: the clip's own pace, scaled to duct_speed when seen
const SQUEEZE_SPEED := 0.6
const ACCEL := 5.0               ## m/s2 (lurker_test.gd): her hands could not keep up otherwise
const HEADING_RATE := 3.0        ## rad/s while moving on a surface
const TURN_RATE := 4.0           ## rad/s for a "turn" leg (slerp)
const HANG_RATE := 0.5           ## m/s
const BODY_DEPTH := 0.7          ## anchor to her lowest point along +Y; a guess until the first unit of 2a-I measures it (risk 6)
const HEAD_CLEAR := 0.25         ## kept between her lowest point and whatever is under her
const RAY_EVERY := 0.25
const RAY_MASK := 1 | 4          ## the world and the survivors (player.tscn layer 4)
const BAND_WAIT := 4.0           ## longest she waits at a band's start for room under it, then bans the door
const ARRIVE := 0.01             ## metres: a waypoint reached
const LOOKAHEAD := 0.8           ## metres before a band start the heading turns to the band's
const DUCT_GAP := 1.5            ## in a visible duct segment, the least distance kept behind the first body ahead on the line (starting value)

var shell; var routes; var ducts
var state: State                 ## on a surface; null while squeezing or in a duct
var legs: Array = []
var goal := {}                   ## what plan() was last asked
var speed := 0.0                 ## current m/s along the way
var pace := 1.35                 ## wanted m/s on surfaces (the brain or the order sets it)
var hang_goal := 0.35
var hang_limit := 0.9            ## from the ray
var clearance_short := 0.0       ## metres the lane under her lacked at the last ray (0: enough)
var cue := false                 ## lurker.cue, copied every frame (7.3 step 0)
var in_duct := false
var hidden := false
var duct_point := Vector3.ZERO
var duct_dir := Vector3.FORWARD
var near_node := -1
var squeeze_t := 0.0
var basis := Basis()             ## the transform's basis while not on a surface
var transit := {}                ## {phase: &"leaving"|&"drop"|&"arriving", wing, left, exit}
var pending_wing := -1           ## follow_to_planta while busy
var busy := Callable()           ## () -> bool: lurker.gd gives is_engaged() or is_hunting() or cue (7.3 step 2); tests a stub
var bodies_ahead := Callable()   ## (from: Vector3, dir: Vector3, reach: float) -> float metres to the first survivor body on the duct line, INF none; lurker.gd gives the physics one
var jumps: Array = []            ## {frame, reason: StringName, from: Vector3, to: Vector3}
var jump_id := 0
var clearance := Callable()      ## (anchor: Vector3, s: State) -> float max hang; lurker.gd gives the physics one, tests a stub
var wait_clock := 0.0
var replan_clock := 0.0
var ray_clock := 0.0
signal arrived
signal blocked(why: String)
```

### 7.2 Orders (what 2b, the arena and the probe call)

```gdscript
func go_to(point: Vector3, pace_: float) -> bool        ## goal {"room": room_at(point), "point": point}; false if no plan
func go_to_room(room: int, pace_: float) -> bool
func go_to_exit(exit: int, pace_: float, mouth := false) -> bool   ## ends inside the duct at its node, hidden; mouth: stops just inside the grille (6.4 rule 7)
func hold() -> void                                      ## stop where she is (a band, a channel, a duct: anywhere)
func place_in_duct(node: int) -> void                    ## inside at that node, hidden, no legs; a logged jump &"place"
## Queries 2b's percept reads (spec_f2_mind 8.3), under 2a's names:
func in_network_duct() -> bool                           ## in_duct and the current segment is not main/cross
func duct_node() -> int                                  ## near_node, -1 on a surface
func at_exit() -> int                                    ## the exit whose mouth she holds at (goal mouth reached), else -1
func on_channel() -> bool
func ahead(metres: float) -> PackedVector3Array          ## her route's next `metres`, sampled every 0.25 m from where she is (anchor points)
func into_channel(channel: int, v_to: float, u_goal: float, pace_: float) -> bool  ## tray to the mouth, then the channel leg
func flee(threat: Vector3) -> bool                       ## go_to_exit(routes.flee_exit(...), SCURRY_SPEED)
func eject() -> void                                     ## out by the nearest exit along the ducts, even closed
func at_goal() -> bool
func route_state() -> StringName                         ## &"idle", &"moving", &"waiting", &"blocked", &"transit"
func remaining_pairs() -> Array                          ## doors the legs still use (routes' door watching)
```

- A new order while on a band, in a squeeze or in a drop **keeps the current leg** and plans from where it ends. In a duct leg it plans from the duct (start `{"duct": [a, b], "metres": [ma, mb], "point": duct_point}`, the two ends of her segment, so she can turn round).
- `plan()` failing: `route_state() == &"blocked"`, `blocked` emitted, she holds.
- **While `cue` is set** (2b: the back cue is running) nothing of 2a moves her on its own: no replanning, no door bans, no `eject()`, no planta transit; each is deferred until `cue` clears. Only an order from 2b moves her.

### 7.3 `tick(delta)`

In order, every physics frame (host or offline, `control == "ai"`):

0. `cue` (a member, copied from `lurker.cue` by `lurker.gd` before each tick): steps 1 and 2 and the fans' `eject()` (7.6) are skipped while it is true (7.2).
1. `routes.tick(delta)`. **A door shut on her route:** if `routes.shut_frame` is newer than the last one this motion handled and `routes.last_shut` is in `remaining_pairs()`, replan to `goal` now (rule above) and emit `blocked` only if that fails. Else on a surface with legs, every `REPLAN_EVERY`: call `routes.door_signature(wing)` (a door changed by `set_state()` bumps `door_epoch`: replan as for a shut door if a remaining pair is no longer `door_open`); then replan, **recompute the cost of the remaining legs of the old plan with the current factors** (lights and power now, the same formula of 6.2), and keep the new legs only if their cost is lower than that by 5 % or more (no dithering).
2. `pending_wing >= 0` and `busy.call()` false (`lurker.gd`: `is_engaged() or is_hunting() or cue`, as `lifts.creature_busy()` keeps The Locust from riding mid-hunt, `lifts.gd:200`): start the transit (7.6).
3. Ray (`RAY_EVERY`, on trays only): `hang_limit = clearance.call(anchor, state)`. Physics version (`lurker.gd`): a ray from the anchor straight down to `py - 0.2`, mask `RAY_MASK`, excluding her RID; `hit_y` = the hit or `py`; `hang_limit = clampf(tray.y - hit_y - BODY_DEPTH - HEAD_CLEAR, HANG_MIN, HANG_MAX)`. When the unclamped value is under `HANG_MIN` (furniture of 2.2 m leaves a 0.75 m lane, OFICINAS 2, less than `BODY_DEPTH + HEAD_CLEAR + HANG_MIN` = 1.0 m), `clearance_short` is set to the shortfall; the probe fails on it (11.2 check 7).
4. The current leg:
   - **tray**: target `to`; `want = pace`, but no more than `sqrt(2 * ACCEL * left)` if this is the last leg, or if the next leg is a band and her heading is more than 0.05 rad off the band's (she must stop to turn there: never from full pace to 0 in one frame); `speed = move_toward(speed, want, ACCEL * delta)`. Heading eases at `HEADING_RATE` towards the direction to `to` (within `LOOKAHEAD` of a band start, towards the band's entry heading). `shell.advance(state, minf(speed * delta, left))`. Hang eases at `HANG_RATE` towards `min(leg.hang if set else hang_goal, hang_limit)`. Reached: next leg.
   - **band start** (the tray leg before a band is done): the switch needs the heading within 0.05 rad of the band's (turn in place at `HEADING_RATE`, speed 0), `|hang - 0.35| < SEAM_TOL` and `hang_limit >= BAND_CLEAR`. Waiting longer than `BAND_WAIT`: `routes.ban(pair, BAN_TIME)` and replan. Then `state = shell.switch_to(state, band)`.
   - **band**: `advance(state, speed * delta)` with heading 0 or PI. The door of a door band shutting while she is on it: she carries on only if `u` is past half the band in her direction **and** her body is outside the leaf's swept arc (the arc of `door.leaf_line()` from shut to open, in plan, against her anchor's plan point widened by the sphere's 0.3 m); otherwise she turns round (heading += PI over `TURN_RATE`) and goes back. Either way she ends on a tray and replans. (A shut leaf does not go solid on layer 32, `hotel_door.TRAPPED`, so nothing else stops it crossing her; whether the leaf should bounce off her is in section 15.) At the end: `switch_to()` the end tray.
   - **squeeze**: position lerps `from -> to` at `SQUEEZE_SPEED`, basis constant (`leg.basis`). `into`: at the end `in_duct = true`, `hidden = true` (unless the next duct segment is `main` or `cross`, then `hidden = false`), `state = null`. Out: `in_duct = false` and `hidden = false` at the start; at the end `state` = the destination State.
   - **duct**: `duct_point = ducts.point_along(points, travelled)` at `segment_speed(kind)` (no easing inside). `segment_speed()` returns `duct_speed` for every kind in 2a; whether the visible `main` and `cross` segments go at the `vent_crawl` pace instead is the author's (section 10, section 15). In a visible segment she never passes a body: each frame `bodies_ahead.call(duct_point, duct_dir, DUCT_GAP + 1.0)`; closer than `DUCT_GAP`, she stops (speed 0) until it is farther; `duct_dir` = the horizontal direction of the current segment (kept when vertical); `near_node` = the next node; `hidden` = segment kind not in `visible_kinds`. Basis `Basis(UP.cross(Z), UP, Z)` with `Z = duct_dir` eased at `TURN_RATE` (only seen in the main duct).
   - **turn**: slerp the basis to `leg.basis` at `TURN_RATE`.
   - **drop**: 7.6.
   - **channel**: `v` towards `v_to` at `speed`, `u` towards `u_goal` the short way at 0.7 m/s (the bench's `ROUND`), hang towards `CH_HANG`. Heading `PI / 2` or `-PI / 2` (along `Tv`), as the bench faces down the corridor while it moves round.
5. **Turn legs**: before starting any leg whose first basis differs from the current one by more than 0.05 rad and the body is not hidden (the hatch: from upside down on the plant's ceiling to lying in the main duct), insert a turn leg. So the visible orientation never jumps.
6. `velocity = (anchor - previous anchor) / delta`.

`at_goal()`: no legs left and the last leg reached.

### 7.4 What the transform is

`lurker.gd` asks `motion.transform()`: on a surface `shell.transform_of(state)`; squeezing or in a duct `Transform3D(basis, point)`. `motion.surface()`: true on a surface (hands on: `visual.crawling`).

### 7.5 Ducts are not surfaces

In a duct her anchor is on the conduit's centre line (the duct floor in the main duct), with no collision (`lurker.gd` puts `collision_layer = 0` while `in_duct`), and her room is `FLOOR.room_at()` of that point: the room under the duct, as for a crawling survivor (generator risk "A body inside the duct is in the room under it").

**One rule for what is seen:** the `Visual` follows `hidden`, never `in_duct`, on every machine. In the network (hidden) nothing draws her; in the `main` and `cross` segments (`hidden == false`) the `Visual` is shown lying in the duct, playing `vent_crawl` with `animator.speed_scale = segment_speed(kind) / VENT_CLIP_SPEED`. The puppet applies the `HIDDEN` flag the same way (8.3). Phase 3 refines the look, not the rule.

### 7.6 Between plantas (`follow_to_planta`) and the fans

OFICINAS 4: "Entre plantas no usa el ascensor: baja por los ductos, sin que nadie la vea. Llega a la planta nueva tras el tiempo que tardaría y aparece lejos del vestíbulo."

`func start_transit(wing: int) -> void` (her wing below `wing`; else nothing):

1. **Leaving**: on a surface, `go_to_exit(routes.nearest_exit(start), pace)`; `transit.phase = &"leaving"`. Already in a duct: straight to the drop, from where she is.
2. **Drop**, once inside (at the exit's node, or her duct point): `to_node = ducts.trunk_nearest(that point, wing)`; `seconds = FLOOR.PITCH * (wing - her wing) / duct_speed`. Logged jump `&"planta"` (from her point to `to_node`'s point), `jump_id += 1`; she waits there `seconds`, hidden, `transit.phase = &"drop"`.
3. **Arriving**: `exit = routes.arrival_exit(wing, rng)`; legs: duct from `to_node` to the exit's node, squeeze out, tray to `shell.clear_point()` of the room's centre (3.7). `transit.phase = &"arriving"` until the squeeze out starts; then `transit = {}`.

- `in_transit()` is true from the drop to the squeeze out. `hushed()` is true during the drop. `transit_phase()` returns the phase: phase 3's lifts play her claws outside the cage while it is `&"drop"` and a car rides ("se la oye arañar por fuera del coche").
- **Open (section 15, author):** the drop lasts `PITCH / duct_speed`, 2.5 to 5 s, while a car rides `RIDE_TIME` 8.5 s (`lifts.gd:442`), so the claws would stop halfway and she would arrive before them; and `follow_players()` calls her with the first stage closed (`lifts.gd:61`), so she leaves even if someone is still on her planta (OFICINAS 4: "Va a por el que se queda atrás"). 2a keeps the drop as written and the probe measures how much the drop overlaps a ride.
- `follow_to_planta(stage, fresh)` (`lurker.gd`): `wing = stage - 1`; if `busy.call()` sets `pending_wing`, else starts now. `lifts.follow_players()` calls it once per closed stage; `creature_crossing()` never does for her (`can(&"lifts")` is false, `lifts.gd:181`). Since nobody calls it again, the wing she is heading for is part of what is saved (8.2 `save_state`).
- `teleport()` and `relocate()` cancel a transit. `restore_state()` does not lose it: it places her as 8.2 says.
- **Fans** (wing 2, phase 3 adds the sound): every `RAY_EVERY`, **whatever wing she is on**, for each wing `w`: `ducts.closed_wings[w] = 1` if `w == 2` and `level.objective(&"air")` has `ducts_closed()` and it returns true, else 0. If her own wing is closed and she is in a duct: `eject()` (deferred while `cue`).

### 7.7 The jump log

Every move that is not continuous on purpose appends `{frame: Engine.get_physics_frames(), reason, from, to}` and bumps `jump_id`: `&"teleport"` (and the teleport's own reason), `&"relocate"`, `&"restore"`, `&"planta"`, `&"place"` (`place_in_duct`). Nothing else may move her more than speed times delta. The probe holds her to it.

---

## 8. `lurker.gd` and `lurker_creature.tscn`

### 8.1 The scene

```text
[node name="Lurker" type="CharacterBody3D"]   script = lurker.gd, collision_layer = 32, collision_mask = 0
  [node name="BodyShape" type="CollisionShape3D"]   SphereShape3D radius 0.3, position (0, 0.42, 0.1)
  [node name="Visual" instance of res://game/enemies/lurker/lurker.tscn]   identity
```

- **Layer 32** like The Locust (`locust.tscn:9`): sight rays (masks 1 | 8) pass her, survivors (mask 169 includes 32) cannot walk through her in an aisle, and a shut leaf does not go solid on her in a doorway (`hotel_door.TRAPPED` includes 32). Mask 0: she is kinematic and collides with nothing; nothing moves her but her motion.
- No gravity, no `move_and_slide()`: `global_transform` is set from the motion every physics frame. `velocity` is written for whoever reads it.
- While `in_duct` or in a drop: `collision_layer = 0`. While `hidden` (and always in a drop): `Visual.visible = false`, `Visual.process_mode = PROCESS_MODE_DISABLED` (OFICINAS 11.8: nothing of the ink in a hidden duct). The `Visual` follows `hidden`, not `in_duct` (7.5), on host and puppet alike. On coming out: back, and `visual.limbs.replant()` so no hand stays planted where she went in.
- **Open (section 15, author):** on a tray the sphere's bottom is under a survivor's capsule top (1.81 m) as soon as the hang passes about 0.42, and in a door band (anchor 2.30) at 1.58 m; the ray every 0.25 s with `HANG_RATE` 0.5 m/s cannot rise in time for a survivor at 3.8 or 6 m/s. Whether survivors collide with her when she hangs at head height is the author's; the probe measures it (11.2).

### 8.2 Members and contract

```gdscript
extends "res://game/enemies/creature.gd"
## The Lurker, the creature of the offices (docs/OFICINAS.md 4 and 11.4; the
## body that is seen is lurker.tscn, docs/LURKER.md). In this step she is never
## on the floor of a room: she goes over the ceilings, down the band over a door head,
## held up between the shelves of an archive, and through her ducts, where she
## is heard and not seen. She never opens a door. What she wants is the brain's
## (lurker_brain.gd); how she gets there is here.
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const DUCTS := preload("res://game/enemies/lurker/duct_graph.gd")
const ROUTES := preload("res://game/enemies/lurker/lurker_routes.gd")
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const WORDS: Array[StringName] = [&"roam", &"investigate", &"search", &"alert", &"chase", &"strike", &"recover", &"capture", &"open", &"wait", &"idle"]
const CLIPS := ["idle", "crawl", "crawl_fast", "vent_crawl", "retreat", "loom", "scare", "peek"]
const PACK_SIZE := 10
enum Flag { IN_DUCT = 1, HIDDEN = 2, SURFACE = 4, DRAINING = 8, CUE = 16, DROP = 32, ARRIVING = 64, TRAY = 128, BAND = 256 }   ## TRAY/BAND: the patch kind (neither: a channel) for visual.cling
const FACE_OFFSET := Vector3(0, 0.45, 0.3)
var level
var shell; var ducts; var routes; var motion
var visual: Node3D
var word: StringName = &"roam"   ## what she is doing (2b sets it)
var clip := 0
var draining := false            ## 2b / phase 3
var cue := false                 ## 2b: the back cue is running
var tuning := {}                 ## the merged profile (tune())
var duct_speed := 1.6
var net_states: Array = []; var net_clock := 0.0; var net_jump := -1; var net_flags := 0; var net_look := Vector3.INF; var net_near := -1   ## net_jump -1: the first packet always snaps
```

| Contract | The Lurker in 2a |
|---|---|
| `kind_id()` | `&"lurker"` |
| `can(a)` | true only for `&"ducts"`. No lifts, no sets, no shriek (phase 3 decides her cry). No wardrobes is **provisional**: it follows OFICINAS 2 "no abre taquillas", but how hiding meets her is decision 5 of `spec_f2_mind.md`, still the author's (section 15); one line to change. |
| `tune(profile)` | `tuning = profile`; `duct_speed = float(profile.get("duct_speed", 1.6))`; `routes.duct_speed = duct_speed` if `routes` exists (`arrive()` applies it otherwise). The rest is read by 2b from `tuning`. |
| `activity()` | `word` (2a leaves it `&"roam"`). `mode_name()`: `"ronda"` until 2b. |
| `eye_point()`, `face_point()` | `global_transform * FACE_OFFSET` (her face in her frame), the offset `shell.cue_pose()` uses (3.8). Whether 2b replaces it with the head bone is in section 15 (director): both must use the same one. |
| `gaze()` | `visual.look_point - eye_point()` when set, else `heading` (`global_basis.z`; her forward is +Z, not -Z). |
| `travel_metres(room)` | `routes.travel_metres(room)`. |
| `in_transit()` | View (below): `drop or arriving`. |
| `transit_phase()` | View: `&"drop"`, `&"arriving"`, `&"leaving"` (host only; a puppet reports `&""` for it) or `&""`. New default in `creature.gd` returning `&""`. |
| `teleport(point, yaw, reason)` | Overridden: `state = shell.state_at(point)`, heading from `yaw` (section 2) unless NAN; out of any duct; `velocity = 0`; `forget_journey(point, reason)`; jump logged with `reason`. |
| `forget_journey()` | Clears legs, goal, transit, pending wing, squeeze; `net_states.clear()`. |
| `relocate(point, rest)` | Same placement, hold, `grace = maxf(grace, rest)`, jump `&"relocate"`. |
| `search_from()` | No-op (2b). |
| `follow_to_planta(stage, fresh)` | 7.6. |
| `den_point(stage)` | `den_room(stage)`: the wing's rooms with trays at a share of `route_metres(entry)` in `[0.5, 0.8]`, not off-limits; drawn with `hash([manifest.seed, "lurker_den", stage])`; -1 if none. Returns `shell.anchor_of(shell.tray_state(room, p.x, p.y, 0.35))` with `p = shell.clear_point(room, centre)` (3.7), `Vector3.INF` for -1. Whether her den on wing 2 is the air room ("Su nido", OFICINAS 2; "En su casa", OFICINAS 1) is in section 15 (author). |
| `save_state()` | `{"at": global_position, "heading": global_basis.z, "in_duct": motion.in_duct, "near": motion.near_node, "wing_goal": transit.wing if a transit runs, else pending_wing, else -1}` (Vector3s and ints; The Locust keeps `{at, yaw}`, `hotel_locust.gd:2475`, so this is her own shape). The floor is kept every `KEEP_EVERY` 30 s and on closing (`hotel_main.gd:1555`), so it can be mid-transit. |
| `restore_state(state, rest)` | Jump `&"restore"`, `grace = maxf(grace, rest)`, then: **`wing_goal >= 0`** and not `busy`: she is put where the transit would have ended, as if done: `routes.arrival_exit(wing_goal, rng)`, on the tray State of `clear_point()` of that exit's room (3.7); while busy, `pending_wing = wing_goal`. **In a duct** (`in_duct` and `near >= 0`): `place_in_duct(near)`, hidden (never pulled out to the tray below). **Else** `relocate(state.at, rest)`, heading from `state.heading`. (`floor_save.gd:126` calls it once on continuing; nobody calls `follow_to_planta()` again.) |
| `pack_state()` | 8.3. |
| `push_state(data)` | 8.3. |
| `hushed()` | View: `drop`. |
| `sound_route(listener)` | View: `drop`: `{"audible": false, "distance": INF}`. `hidden_duct`: `ducts.sound_route(duct_point, near, listener, room_of, level.world_audio)` (out of the grilles, never through walls). Else `level.world_audio.route_source(global_position, get_rid(), listener)`. |
| `presence_route(listener)` | View: `hidden_duct`: the same duct route as `[route.distance, route.position]` (`[INF, Vector3.INF]` if inaudible). On a surface: `level.world_audio.aura.route_to(listener, FLOOR.floor_point(global_position))`, as The Locust (`hotel_locust.gd:2206`). |
| `resume_state(data)` | The base no-op (`creature.gd:236`): only `match_net.restore()` calls it, for a hunter coming back into versus (`match_net.gd:1102`), phase 4. Phase 4 implements it (position, quaternion to `state_at` plus heading, grace from the pack), with `play_call` and `validate_strike`; noted in `docs/PLAN.md` (section 14). |

**The view.** `world_audio.gd:594` and `:602`, `dread_aura.gd:122` and `:166` and `televisions.gd:190` call `sound_route`, `presence_route`, `hushed` and `in_transit` on **every** machine, and a puppet's `motion` never runs. So every contract method above that says "View" reads one function, `view() -> Dictionary`, never `motion` directly:

- `control == "ai"`: `{drop: transit.phase == &"drop", arriving: transit.phase == &"arriving", leaving: transit.phase == &"leaving", in_duct: motion.in_duct, hidden: motion.hidden, duct_point: motion.duct_point, near: motion.near_node}`;
- a puppet: the same keys from `net_flags` (`DROP`, `ARRIVING`, `IN_DUCT`, `HIDDEN`; `leaving` false), `near: net_near`, `duct_point: global_position` (the interpolated one).
- `hidden_duct = in_duct and hidden`.
| `debug_lines()` | `"lurker, <word>, <patch kind> <room>, u %.1f v %.1f, cuelga %.2f, <leg kind>, ducto si/no, viaje <phase>"`, commas only. |
| `debug_state()` | Base plus `patch, kind, room, u, v, hang, in_duct, hidden, legs, transit, jump_id`. |
| `draw_gizmos(g)` | With 0a5's API: the remaining legs as a polyline (tray and band points sampled every 0.1 m, duct points), the current band's or channel's profile at her `v`. |

`hear()`, `hear_route()`, `sees()`, `watched()`, `lead_to()`, `investigate()`, `noticing()`, `searched_lately()`, `capture_style()` and the capture calls keep the base defaults in 2a; 2b and phase 3 fill them.

**`_ready()`**: `visual = $Visual`; `rng.seed = hash([int(level.manifest.seed), "lurker"])` when `level` is set; `arrive()`.

**`arrive()`**: `shell = SHELL.build(level.manifest)` (null: push an error and disable processing); `ducts = DUCTS.of(level.manifest)`; `routes.setup(level, shell, ducts, control == "ai")` (only the machine that moves her watches doors; a later `set_control("ai")` calls `arrive()` again); `motion` with `clearance`, `busy` and `bodies_ahead` (7.1, 7.3); if she has no place (`motion.state == null and not motion.in_duct`), `teleport(den_point(level.session.stage), 0.0, &"den")`. `_exit_tree()`: `routes.teardown()`. `hotel_main.spawn_creature()` (`hotel_main.gd:1391`) is The Locust's (floor position, `den_room`, `patrol_room`): phase 3 puts her on the floor by its own path, not that one.

**Hallucinations (OFICINAS 5).** `SHELL.build()` and `DUCTS.of()` work without a body and without any `rng` (pure, from the manifest), so phase 3's phantoms (the face "en el marco de una puerta a oscuras, sobre una mampara o en una esquina del techo", knocks travelling along an empty duct) can take postures and duct paths on each machine with no real Lurker. Nothing a phantom uses may read `transit_phase()`, `cue` or the drain (OFICINAS 1: they never imitate the back cue or the lights trembling together).

**`_physics_process(delta)`**: `grace = maxf(0, grace - delta)`. `"ai"`: `motion.tick(delta)` (moving even in grace is the brain's call; 2a moves when told). `"puppet"`: `follow_state(delta)`. `"player"`: nothing (phase 4). Then `global_transform = motion.transform()` (puppet: the interpolated one), `velocity`, `collision_layer`, `visual.velocity = velocity`, `visual.crawling = surface`, `visual.cling` (tray 0.3, band 0.5, channel 0.6, the bench's 0.6 held up; a puppet takes the patch kind from the `TRAY` and `BAND` flags, so both machines agree), and the clip: `idle` at speed under 0.05, `crawl` up to 1.6 m/s (`animator.speed_scale = speed / 1.35`), `crawl_fast` above (`speed / 3.5`); 2b overrides by setting `clip`.

### 8.3 Network state

```text
pack_state(): [
 0 position: Vector3        (the anchor)
 1 orientation: Quaternion  (global_basis.get_rotation_quaternion())
 2 velocity: Vector3
 3 word: int                (index in WORDS)
 4 flags: int               (Flag bits: in_duct, hidden, surface, draining, cue, drop, arriving, tray, band)
 5 grace: float
 6 look_point: Vector3      (visual.look_point; INF none)
 7 clip: int                (index in CLIPS)
 8 near_node: int           (duct node she heads to, -1 on a surface)
 9 jump_id: int ]
```

- `push_state(data)`: ignore unless `data.size() == PACK_SIZE`. A `jump_id` different from the last received (`net_jump` starts at -1, so the first packet a late joiner gets always snaps and never lerps from where `arrive()` put her) clears `net_states` and snaps. Else append `{time: net_clock, position, rotation, velocity}` (keep 10), apply word, flags, grace, look, clip and near node at once.
- `follow_state(delta)`: as The Locust's (`hotel_locust.gd`, `follow_state`): render at `net_clock - 0.1`, `lerp` positions and `slerp` quaternions between the two states around it. Hidden flag: visual hidden, layer 0.
- Same RPC (`match_net.locust_state`), same send rate. The payload is a plain Array of Variants. Only floor-2 matches send this shape, and 0c put the floor in the match config, so no `PROTOCOL` change in 2a. `restore()` passes it to `push_state()` (guest) unchanged.
- **Deviation from OFICINAS 11.6, for phase 4.** 11.6 asks for reliable events on entering and leaving a duct. 2a sends them only as flags in the unreliable state (a lost packet is corrected by the next, 1/15 s later). A new RPC would break `creature_contract_test`'s wire check (`rpcs.size() == RPCS.size()`, `creature_contract_test.gd:1530`), so the reliable events come with phase 4's net work; noted in `docs/PLAN.md` (section 14).

### 8.4 Who calls what in 2a

Nobody in the game: `office_floor.CREATURE` stays `null_creature.tscn` until phase 3. The shell test, the route probe and (2c) the arena instantiate `lurker_creature.tscn` themselves, set `level`, add it as a child of the level and call orders on `motion`.

### 8.5 Small changes elsewhere

- `creature.gd`: `## Where it is on its way to another planta without the lifts (the Lurker's ducts): &"" when not.` `func transit_phase() -> StringName: return &""`.
- `lurker_limbs.gd`: `## Every hand lets go and looks for a new hold (after the body has been somewhere else).` `func replant() -> void: for limb in limbs: limb.planted = false; limb.swing = false; limb.t = 1.0`. (Today a hand re-probes only past 2.5 reaches from its shoulder, `_process_modification_with_delta`.)
- `power_objective.gd`: `## Whether the team gave this room its light (a zone up or a minutero running): she keeps away from those most.` `func herds(room: int) -> bool: return bool(applied.get(room, false)) and not lit_always.has(room)`.
- `difficulty.gd`: the keys of section 10 not yet written by 0f, under `CREATURE_PROFILES[&"lurker"]`, and `difficulty_test`: every Lurker profile has them; no Locust profile does.

### 8.6 Hooks left for 2b and later

`motion.pace`, `motion.hang_goal`, `motion.go_to*()` (with `go_to_exit(..., mouth)`), `into_channel()`, `flee()`, `hold()`, `place_in_duct()`, the queries `in_network_duct()`, `duct_node()`, `at_exit()`, `on_channel()`, `ahead()`, `shell.wall_band()`, `shell.cue_pose()`, `shell.clear_point()`, `routes.flee_exit()`, `ducts.inbound()`, `word`, `clip`, `draining`, `cue`, `transit_phase()`, `motion.jumps`.

- **2b's names.** `spec_f2_mind.md` 8.3 keeps its own names in one adapter, `apply_intent()`: `halt` is `hold()`, `go` is `go_to()`, `enter_duct(exit)` is `go_to_exit(exit, pace)`, `to_exit(exit, true)` is `go_to_exit(exit, pace, true)`, `place_in_duct` is `place_in_duct`. What 2a does not give (floor and wall patches, `behind_point(..., &"any")`, "Desde arriba: baja del techo delante", walls for "Acechar") is in section 15 (director).
- **Channels are never planned.** `plan()` never routes along an archive aisle; only `into_channel()` goes into one. So wing 1's way of moving between the two shelves (OFICINAS 2) happens only when 2b asks for it. Whether channels get a cost in the route graph is in section 15 (director).

---

## 9. Constants at a glance

| Where | Name | Value | Why |
|---|---|---|---|
| shell | `BEND` | 0.45 | the bench's |
| shell | `BAND_CLEAR`, `DEFAULT_HANG` | 0.35 | header 0.30 m: she stays upside down through a door |
| shell | `EXPOSED_CEILING` | 3.05 | over the 2.65 heads, under the main duct's 3.1 floor |
| shell | `PORTAL_REACH`, `WALL_REACH` | 1.4 | room for 0.45 fillets on both sides |
| shell | `TRAY_INSET` | 0.25 | |
| shell | `CH_HANG`, `CH_HANG_SHARE` | 0.25, 0.6 | the bench's look on a 1 m aisle; no fold |
| routes | `CRAWL_SPEED` | 1.35 | OFICINAS 1 "repta a ~1,35" |
| routes | `LIT_FACTOR`, `POWER_FACTOR` | 6, 25 | lit rooms dear, powered zones dearer (herding, OFICINAS 3) |
| routes | `ENTER_COST`, `LEAVE_COST`, `PORTAL_COST` | 1.5, 1.5, 0.5 s | |
| motion | `SCURRY_SPEED`, `RETREAT_SPEED` | 3.5, 2.0 | OFICINAS 1 |
| motion | `ACCEL`, `HEADING_RATE`, `TURN_RATE`, `HANG_RATE` | 5, 3, 4, 0.5 | |
| motion | `BODY_DEPTH`, `HEAD_CLEAR`, `RAY_EVERY` | 0.7, 0.25, 0.25 | OFICINAS 11.4 "un rayo hacia abajo cada 0,25 s" |
| motion | `SQUEEZE_SPEED`, `BAND_WAIT` | 0.6, 4 s | |
| motion | `DUCT_GAP` | 1.5 | never passes a body in the visible duct (7.3) |
| shell | `LAMP_CLEAR`, `CUE_ANGLE` | 1.0 m, 15 degrees | 3.7, 3.8 |

---

## 10. Difficulty (OFICINAS 4, "Dificultad"), `CREATURE_PROFILES[&"lurker"][id]`

| Key | apacible | equilibrada | desafiante | pesadilla | Read by |
|---|---|---|---|---|---|
| `duct_speed` (m/s) | 1.2 | 1.6 | 2.0 | 2.4 | 2a: motion, routes, planta transit |
| `back_window` (s) | 2.2 | 1.8 | 1.5 | 1.2 | 2b (plus the victim's latency online) |
| `lit_grab` | false | true | true | true | 2b |
| `stalk_distance` (m) | 12 | 10 | 8 | 6 | 2b |
| `stare_time` (s) | 2 | 3 | 4 | 6 | 2b |
| `scare_calm` (s) | 60 | 45 | 35 | 25 | 2b |
| `approach_scale` | 0.8 | 0.9 | 1.0 | 1.15 | 2b (multiplies `CRAWL_SPEED` for `motion.pace`) |
| `drain_reach` (m) | 3.0 | 3.0 | 3.5 | 4.0 | 2b / phase 3 |
| `peek_rate` | 1.5 | 1.5 | 1.0 | 0.5 | 2b ("Muchos, Muchos, Normales, Pocos" as a multiplier) |

**Decided (section 15 item 5, author, 23 October: 1 m/s on `main` and `cross`): her speed in the visible main duct.** OFICINAS 1 says "en ducto va a ~0,75" and "Huir de ella siempre es posible si sabes dónde está"; OFICINAS 4 "Ductos" says "más deprisa que reptando: de 1,2 a 2,4 m/s" and that on wing 2 the main duct "es suyo también: por él viene detrás de quien huye". A survivor crawls at 1.2 m/s and 0.6 looking back (`spec_f1_systems` gait), so at `duct_speed` she catches whoever flees along the main duct at every difficulty. 2a does not settle it: `segment_speed(kind)` (7.3) returns `duct_speed` for every kind, and the answer changes that one function (for example `VENT_CLIP_SPEED * approach_scale` on `main` and `cross`).

**Starting values.** Every number of this table, and `LIT_FACTOR`, `POWER_FACTOR`, `ARRIVE_BAND` and the den band of 8.2, is a starting value; `docs/DEVELOPMENT.md` lists them as such (section 14), with what would set each (the probe's figures, playtests). `peek_rate` turns OFICINAS's "Muchos, Muchos, Normales, Pocos" into a multiplier: that reading is in section 15 (author, minor).

---

## 11. Tests

### 11.1 `tests/office/lurker_shell_test.gd`

`extends SceneTree`, the `check(title, passed)` / evidence / `quit()` pattern of `manifest_golden_test.gd`, titles in Spanish without "·" or "—", `evidence/lurker_shell_test.json`, last line `LURKER_SHELL_TEST_RESULT passed/total`. No floor is built; no physics. Inputs: the fixture below and office manifests from `office_generator.new().generate(seed)` for seeds 1 to 10 at 2 survivors (as `office_test` calls it).

**Fixture** (planta 0, `floor: 2`, `plenum: OFFICE.PLENUM.duplicate(true)`, one row of four cells). Every room carries what `room_at()`'s index (`floor_definition.gd:164`) and `portal_between()` (`:307`) read: `id`, `x = id`, `z = 0`, `cols 4`, `rows 1`, `wing 0`, `py 0`, `pz 0`, `span_z 8`, `height 2.95`, `open_sides []`, plus the table's:

| id | type | px | span_x | doors |
|---|---|---|---|---|
| 0 | 3 (despacho) | 0.0 | 8.0 | `[[1, 0.0]]` |
| 1 | 11 (pasillo) | 5.2 | 2.4 | `[[0, 0.0], [2, 1.0]]` |
| 2 | 6 (archivo) | 11.4 | 10.0 | `[[1, 1.0], [3, 0.0]]` |
| 3 | 19 (off-limits) | 20.4 | 8.0 | `[[2, 0.0]]` |

`edges [[0, 1], [1, 2], [2, 3]]`, `adjacency [[1], [0, 2], [1, 3], [2]]`, `merged []`, `entries [0]`, `seed 1`. Ducts: nodes `n0 (0, 3.7, 0, 0, "branch")`, `n1 (5.2, 3.7, 0, 1, "trunk")`, `n2 (11.4, 3.7, 0, 2, "branch")`, `n3 (-1.5, 2.95, 1.5, 0, "exit")`, `n4 (11.4, 0.35, 3.91, 2, "exit")`; edges `[n0, n1, 5.2, "branch"]`, `[n1, n2, 6.2, "branch"]`, `[n3, n0, d, "drop"]`, `[n4, n2, d, "drop"]` (`d` the 3D distance); exits `{node 3, room 0, kind "ceiling", point [-1.5, 2.95, 1.5], yaw 0.0}`, `{node 4, room 2, kind "wall", point [11.4, 0.35, 3.91], yaw PI}`. Archives: `[{rooms [2], axis "x", spine [6.75, -0.8, 16.05, 0.8], aisles [[8.0, 0.8, 9.0, 3.85]], ...}]`. A second fixture copy merges rooms 0 and 1 (`merged [[0, 1]]`, `open_sides` east/west, no door) for the open-side cases.

Sections and cases:

A. **Perfiles.**
   - `Profile.rounded([(0,0), (2,0), (2,-2)], 0.45, -1)`: `length == 3.1 + 0.45 * PI / 2` (1e-6); `at()` at 1 mm steps: point steps at most `du * 1.0001`, unit tangents, tangent turn per step at most `du / 0.45 + 1e-6`.
   - A polyline with a 0.3 m middle segment between two right angles: radii clamped to 0.15, `min_radius == 0.15`, still C1.
   - `section(1.0, 2.95, 0.45).length == 2 * 0.1 + 2 * 2.05 + TAU * 0.45`; closed: `at(length + 0.3) == at(0.3)`.
B. **El banco.** Load `res://tools/workbenches/lurker_test.gd`, `new()` (not added to the tree, so `_ready` does not run), and for 200 `u` over its `perimeter()`: `section(WIDTH, HEIGHT, BEND).at(u)` point equals `outline(u)[0]` and `normal_at(u)` equals `outline(u)[1]` within 1e-5. Free it.
C. **Constantes.** `OPEN` equals `hotel_geometry.gd`'s `OPENING_HIGH`; `PORTAL_WIDTH == FLOOR.PORTAL`; `BEND == lurker_test.gd BEND`.
D. **Transformación.** 500 random States (rng seed 5) on random patches of seeds 1 to 5: basis orthonormal (1e-5), `determinant()` within 1e-5 of 1, `Y == frame_of(s)[0]`, `Z == heading_vector(s)`, `Y.dot(Z)` under 1e-6. Tray: `Y == (0, -1, 0)`, heading `PI / 2` gives `Z == (0, 0, 1)`.
E. **Costuras.** For every door band of seeds 1 to 10 and `v` in `{-0.6, 0, 0.6}`: the tray State of `rooms[0]` at the band's `S(0, v)` with hang 0.35 and the band State `(0, v)` have the same transform (position 1e-4, basis angle 1e-4); likewise at `length` with `rooms[1]`. Every wall band at `u = 0`. Every channel: tray over the centre line at `v` in `{0, length / 2, length}` and hang in `{0.1, 0.25}` against the channel at the matching `u`, and the same at the largest offset `d` that `switch_to()` accepts (3.5) on both sides; one step past it, `switch_to()` returns null.
F. **Ida y vuelta.** `switch_to()` tray -> band -> tray at the same end gives back `x, z`, hang and world heading (1e-6); tray -> channel -> tray the same; `switch_to()` away from a seam returns null.
G. **Continuidad.** Every band of seeds 1 to 10, `u` from 0 to `length` in 5 mm steps at `v` in `{-0.5, 0, 0.5}`: anchor steps at most `du * 1.001`, basis angle per step at most `du / R_MIN + 1e-4`, `min_radius >= R_MIN`. Every channel, `u` over its whole outline at hang `{0, CH_HANG, max}`: steps at most `du * 1.001`, anchor inside the section (at least 0.05 from walls, floor and ceiling when hang > 0), inside the aisle's rect in plan.
H. **Holguras.** Door bands: distance from the anchor curve (sampled 5 mm) to both head edges at least `0.8 * BAND_CLEAR`; `y <= h - c + 1e-4` everywhere; lowest `y >= OPEN - c - 1e-4`; over `|n| <= t / 2` the anchor is under `OPEN - c + 1e-4`. Wall bands end between 0.45 and 0.65 m above their grille.
I. **Cobertura.** Every room with a tray is non-void and not off-limits, and every such room has one; every door edge between two of them (not merged) has exactly one band; no band touches room 3 of the fixture or any off-limits room of the seeds; every wall exit has a wall band; every aisle narrower than 1.6 of a unit that is not mobile has a channel with `width` its short side and `length` its long side, and mobile units have none; band ends `K0`, `K5` and every exit's tray point lie inside their trays' `rect`, and every channel's `v` range inside the union of the `rect`s of its unit's trays at the same `y` (in plan).
I2. **Lámparas y postura.** Seeds 1 to 10: `clear_point()` of every room's centre is at least `LAMP_CLEAR` from every lamp of the room, or, where none is, it is the farthest; `den_point(1..3)` the same. `cue_pose()`: for every room with a tray, eye at 1.64 m at 20 points (rng seed 11) and `d` in `{1.6, 2.4, 3.2}`, the share of cases with a pose is written to the evidence, and every pose returned has its face at most `CUE_ANGLE` above the eye, hang within `max_hang()`; rooms where the share is under 100 % are listed (they are the figure section 15 needs).
J. **Alturas.** Tray `y - py`: 2.95 for type 3, 3.25 for type 5, 3.05 for types 12, 22 and 23.
K. **Avanzar.** On a tray, `advance(s, 1.0)` moves the anchor 1.0 (1e-6); into a walled edge it returns less than asked and the anchor stays in `rect`; in the merged fixture copy, crossing the open side lands on room 1's tray at the same world anchor. On a band, `advance` 1 m moves the anchor 1 m along the curve (sum of 1 mm sub-steps within 1e-3).
L. **Estado en un punto.** 200 random points inside trays: `state_at(p)` is on `room_at(p)`'s tray with the anchor's `x, z` equal to `p`'s clamped into `rect` (1e-6), hang 0.35. A point in room 3 of the fixture lands on room 2's tray.
M. **Determinismo.** Two builds of seed 7: `JSON.stringify(dump())` equal. A hotel manifest (`map_generator.new().generate(7)`): `build()` is null.
N. **Grafo de ductos.** `duct_graph.of(seed 7)`: `node_wings` as `planta_of`; `nodes`, `node_rooms`, `node_wings`, `node_kinds` and `adjacency` all have the same size; every gap exit has a node with an edge, listed in `adjacency` both ways as `[other, length, edge]`, and `distances_from()` of the gap node reaches its cell node (so the searches see the added edges); with `closed_wings[2] = 1`, `nearest_exits()` from a wing-0 node is unchanged and from a wing-2 node is empty unless `ignore_closed`; `nearest_exits(node, 3)` ascending; `inbound()` from a point 1 m under a grille reaches a node two edges away with `apparent` at that grille; from another planta, inaudible. `conduit_graph.from_manifest(seed 7's tubes, true)` still has `nodes.size() == tubes.nodes.size()`, the manifest's edges in order and one exit per tube exit (the refactor to `fill()` changed nothing), and `connected()`.
O. **Rutas** (stub level: `manifest`, `hotel` with `lit(room)` from a set, `doors` (the stub doors in index order) and `get_node_or_null(name)` returning stub doors `{opened, moving, locked}` with the two signals and `leaf_line()`, `objective()` null; `lurker_routes` must use duck typing for these; `setup(..., true)`):
   - All doors open, all dark: `plan({"room": 0}, {"room": 2})` goes 0 -> 1 -> 2 by bands, each band leg at `v` 0.25 m from the middle on the side away from its door's hinge; leg kinds `tray, band, tray, band, tray`; `pairs == [(0,1), (1,2)]`; cost equals the formula of 6.2 recomputed from the shell's lengths (1e-4).
   - Door 1-2 shut (`opened = false`): the plan goes into exit 0 (room 0's ceiling grille), along the ducts and out of exit 1 (room 2's wall grille, wall band up): kinds include `squeeze`, `duct`, `squeeze`, `band`; no pair (1, 2). Its duct leg time at `duct_speed` 1.2, 1.6, 2.0, 2.4 equals `metres / speed` (1e-6).
   - Room 1 lit: the cost of the door route rises by `(LIT_FACTOR - 1) * metres in room 1 / CRAWL_SPEED`; the planner picks whichever of the two routes is cheaper by the formula (both computed in the test).
   - No plan ever contains room 3; `plan(..., {"room": 3})` is not ok; `travel_metres(0)` has no key 3.
   - `travel_metres(0)` with everything open equals the hand-computed metres for rooms 1 and 2 (1e-4); after shutting door 0-1 (stub `swung.emit(false, ...)` then `opened = false`) the metres come by the ducts. Then, with **no signal**, the stub door's `opened = true` (as `set_state()` does) and the frame counter advanced: `door_signature(0)` differs, `door_epoch` was bumped, and `travel_metres(0)` is the door route again.
   - Door watching: the stub door emits `swung(false, false, false)`: `routes.last_shut == Vector2i(0, 1)` and `shut_frame` is set; routes holds no reference to any motion. (The motion's side, replanning when `last_shut` is in `remaining_pairs()`, is checked by the probe, 11.2.)
   - `door_open()`: a merged pair is open with no node; an unmerged edge whose node is missing (rename the stub's node) is shut and pushes one error.
   - Duct start: `plan({"duct": [n0, n1], "metres": [1.0, 4.2], "point": p}, {"room": 0})` may go back through `n0` (the cheaper way) and its first duct point is `p`. A duct leg through a `stub` node of seed 7 (wing 2) has no step between consecutive points longer than its own segment, and has the vertical piece of 6.4 rule 5.
   - Replanning: the cost of an old plan recomputed after lighting a room on it is higher by the formula of 6.2 (1e-4).
   - Seeds 1 to 5, every planta, 20 random pairs of rooms with trays (rng seed 99): with every door open the plan is ok; with every door of the planta shut the plan is ok and has no band (validator: every room is reached by the ducts alone) for rooms that have an exit; no plan contains an off-limits room.
   - `arrival_exit(wing, rng)` 50 draws (seed 3) on seed 7: every share inside `ARRIVE_BAND`; the same seed gives the same sequence.
P. **Texto.** No U+00B7 or U+2014 in the six new scripts (read with `FileAccess`).

Add `'office/lurker_shell_test'` to `$tests` in `tools/verify.ps1`.

### 11.2 `tools/dev/lurker_route_probe.gd`

`extends SceneTree`, modelled on `tools/dev/creature_stuck_probe.gd`:

```text
godot --headless --path . --rendering-method forward_plus --fixed-fps 60 \
    --script tools/dev/lurker_route_probe.gd -- --test-profile --seeds=7,81,404 --trips=10 [--short] [--strict] [--trace]
```

**Setup per seed:** `level = load("res://game/app/hotel.tscn").instantiate()`, `root.add_child(level)`, `level.set_floor(2)`, `await level.start_floor(seed, false, [1], "equilibrada")`. The player out of the way as the stuck probe does (`set_physics_process(false)`, `global_position = Vector3(0, -200, 0)`). `lurker = load("res://game/enemies/lurker/lurker_creature.tscn").instantiate()`, `lurker.level = level`, `level.add_child(lurker)`, `lurker.grace = 0.0`, `lurker.tune(DIFFICULTY.profile("equilibrada", &"lurker"))`. `level.creature` stays the null creature, so nothing else reacts to her. With the player out of the way, check 7 never sees a survivor: the survivors' side is measured by the test body of "A body under her", not by check 7.

**Trips:** per planta, `--trips` journeys between two rooms with trays on that planta, centres at least 10 m apart (rng `seed * 7919 + 13`). Each: `lurker.teleport(centre of a, 0.0, &"probe")`, `motion.go_to_room(b, 1.35)`, then `await physics_frame` until `motion.at_goal()` or the budget `3 * plan.cost + 10` seconds.

**Checks every frame** (a failure records `{seed, trip, frame, reason, position}`):

1. **Jumps.** `|anchor - previous| <= maxf(SCURRY_SPEED, duct_speed) * delta * 1.25 + 0.01` unless `motion.jumps` got an entry this frame.
2. **Turns.** Basis angle change `<= 6.0 * delta + step / r_floor + 0.01` (`step` the anchor's move this frame, `r_floor` the smallest `min_radius` of the shell's profiles: going round a fillet turns her at `speed / r`), unless hidden this or the last frame, or a jump was logged.
3. **Basis.** Orthonormal, determinant 1 (1e-3).
4. **Off-limits.** `FLOOR.room_at(rooms, anchor)` is never in `level.off_limits_rooms()`. (In the shaft `{}` is allowed.)
5. **Doors.** On the frame she switches onto a door band, its door is open (`routes.door_open(pair)`); no plan's `pairs` holds a locked door.
6. **Hidden only inside.** `hidden` only while `in_duct` or in a drop; visible in a duct only on `main` or `cross` segments.
7. **Hang and real clearance.** On trays, every `RAY_EVERY`: `hang <= hang_limit + HANG_RATE * RAY_EVERY + 1e-3`, and `motion.clearance_short == 0`. Besides, the real clearance: the ray's hit against her lowest bone (`get_bone_global_pose` over the skeleton's bones, plus 0.05 for the skin) must not be negative; a value under 0 is a failure whatever `hang_limit` says (the clamped limit cannot show it).
8. **Lamps.** Wherever she stops at a default point (a goal reached with no point given, the den, a planta arrival), her anchor is at least `LAMP_CLEAR` in plan from every lamp of the room, or at the farthest point (3.7).
9. **Recorded, not judged** (figures for section 15): metres on trays of types 12, 22 and 23; the lowest point of her body under a door head.

**Special trips** (seed 7 only):

- **A door shuts on her.** Every third trip, when the remaining legs hold a door band at least two legs ahead, the probe `toggle()`s that door shut. Within one physics frame `motion.remaining_pairs()` no longer has it; the trip finishes, or, if `routes.plan()` from her place finds nothing with that door shut, `route_state() == &"blocked"` within 2 s (counted as a pass and noted).
- **Ducts only.** On wing 1 every non-gate door `set_state(false)` (no signal: the motion must find it through `door_signature()`, 7.3 step 1); a trip between the two rooms farthest apart that have exits: it finishes, it has duct legs, and the seconds spent in duct legs equal their metres over `segment_speed()` within 10 % plus 0.5 s. Repeated at all four difficulties (`lurker.tune(DIFFICULTY.profile(id, &"lurker"))`), giving 1.2, 1.6, 2.0, 2.4 m/s.
- **The cue holds her.** With `lurker.cue = true` and `motion.hold()`, for 3 s: a door of her route shut, `closed_wings` of her wing set, `follow_to_planta()` called: her anchor moves no more than 1e-3. Cleared, the deferred transit starts.
- **A leaf shutting over her.** With her under a door head, the probe `toggle()`s that door: from 0.3 s after the toggle on, no frame where her sphere cuts the shut leaf's volume (`hotel_door` collision shape at its shut transform).
- **A body under her.** A test `CharacterBody3D` with the player's capsule (radius 0.3, height 1.8, layer 4, mask 169) walked by velocity under her on a tray and through the doorway she holds, at 3.8 and 6 m/s: the least distance between her lowest bone and the capsule's top, and whether it was stopped, are recorded (the figure for section 15).
- **Nobody passed in the main duct** (wing 2). A test body moved along the main duct's line at 1.2 m/s ahead of her as she goes the same way: the distance never drops under `DUCT_GAP - 0.05`; her speed on `main` segments equals `segment_speed(&"main")` within 5 % while the way is clear.
- **An archive aisle.** The first channel of wing 1: `motion.into_channel(c, length - 0.5, shell.channel_u_on_wall(c, -1.0, 1.8), 1.35)`, then `go_to_room(its room)`: checks 1 to 4 hold through the mouth seam, along the aisle and back.
- **Planta transit.** Doors restored. From a room on wing 0: `lurker.follow_to_planta(2, true)`. She enters a grille, exactly one jump `&"planta"` is logged, `in_transit()` is true from then until she comes out, `hushed()` during the drop, she is never visible between going in and coming out, she comes out on wing 1 in a room whose share of `route_metres(entry_of(manifest, 1))` is in `ARRIVE_BAND`, and the time from the jump to the squeeze out is the drop's seconds plus the arrival duct metres over `duct_speed` (within 0.5 s). Recorded: how many seconds of the drop overlap a car's `RIDE_TIME` started at the same moment (section 15).
- **Saved mid-transit.** The transit again, three times: `save_state()` in `&"leaving"`, in `&"drop"` and in `&"arriving"`; each time a fresh body takes `restore_state(saved, 0.0)`: she ends on wing 1, out of any duct, in a room whose share is in `ARRIVE_BAND`, with no transit and no pending wing left. Saved in a hidden duct and restored: `in_duct` and hidden, at the saved node.
- **Net round trip.** A second instance with `set_control("puppet")` fed `pack_state()` of the first every 4 frames (15 Hz) through a whole trip and the planta transit. The probe keeps the host's transform for every physics frame with its `net_clock` time; each puppet frame is compared with the host's transform **at the time the puppet renders** (`net_clock - 0.1`, interpolated between the two kept frames around it), not with the host's current one (at 3.5 m/s the render delay alone is 0.35 to 0.58 m): within 0.1 m and 0.1 rad (the chord of a 1/15 s sample on a fillet), except on the frame of a snap. The planta transit's `jump_id` makes it snap (no frame lerps across plantas); a puppet created after the host's first packets snaps on its first one (`net_jump` -1). On every frame `hushed()`, `in_transit()` and `sound_route(listener).audible` agree between host and puppet (listener: a point in the room under her duct and one in the next room), and in a hidden duct the puppet's `sound_route` has the host's `position` within 0.5 m; `pack_state().size() == PACK_SIZE`.
- **Contract.** `kind_id() == &"lurker"`; `can(&"ducts")` and nothing else of the five; `travel_metres(room)` of her room has the rooms of her planta with trays and no off-limits key; `den_point(1..3)` on its planta, in a room with a tray; `save_state()` then `restore_state()` puts her on the same tray within 1e-3; `teleport()` logs a jump; a puppet connects no door signal.

**Output:** a line per seed (trips, finished, failures, time in ducts, transits) and a total `LURKER_ROUTE_PROBE PASS|FAIL passed/total`; `evidence/lurker_route_probe.json` with every failure; `--trace` prints every trip; `--strict` exits 1 on any failure.

**`tools/verify.ps1`**, next to the stuck probe:

`verify.ps1` already takes 5 to 8 minutes with 8 jobs, so its version is short: `--seeds=7 --trips=2 --short`, where `--short` runs the special trips once, the ducts-only one at `equilibrada` only. The full version (three seeds, ten trips, the four difficulties) is run by the area's reviewer, never by verify.

```powershell
# The Lurker on her surfaces and in her ducts: trips on floor 2, no jump she did
# not declare, never in an off-limits room, never through a shut door
# (tools/dev/lurker_route_probe.gd).
$log = Join-Path $evidence 'verify_lurker_route_probe.log'
Add-Check 'dev/lurker_route_probe' 'lurker_route_probe' (Godot-Arguments 'res://tools/dev/lurker_route_probe.gd' $log $true @('--test-profile','--seeds=7','--trips=2','--short','--strict','--automation','--silent')) <limit> 'plain' 1 $log
```

`<limit>`: the reviewer runs the short version once, alone, and writes here and in `verify.ps1` twice the wall time it measured (rounded up to 30 s); not 480 by default.

### 11.3 Regression

`tools/verify.ps1` whole (floor 1 identical: `manifest_golden_test`, `creature_contract_test`, `stages_test`, `hotel_test`, net tests), `office_test`, `office_stages_test`, `difficulty_test` (the new keys), and `bots_test --floor=2` (the null creature is still the floor's).

---

## 12. Order of work

Two areas (section 0). Units that share a file or need Godot go in series; the shell test is run by the area's reviewer, not by units working in parallel.

**2a-I, pure** (after 1a, 1b, 1c and 1e's `conduit_graph.gd`; the director has corrected this spec against them):

1. **`BODY_DEPTH`, measured** (its own unit; needs only `lurker.tscn`, which exists): a small headless script under `tools/dev/` puts `lurker.tscn` on a ceiling (Y down) playing `crawl`, `crawl_fast`, `idle` and `peek`, and records over 5 s each the lowest point of the skeleton along +Y (`get_bone_global_pose` over all bones, plus 0.05 for the skin). **Acceptance:** one number, the maximum, written into 7.1 and 9 of this spec by the director, with the clip that gave it. If it is over 0.70, the director reopens the lane question of section 15 before step 7.
2. `conduit_metres` heap helpers and `conduit_graph.fill()` refactor; add `exits_of_room`, `nearest_exits`, `inbound`, `edge_closed`. Run `office_test`, `office_stages_test`.
3. `lurker_shell.gd`: `Profile` (and test sections A to C at once), then trays, door bands, wall bands, channels, `State`, `transform_of`, `advance`, `switch_to`, `state_at`, `clear_point`, `cue_pose`, `dump`. Test sections D to M and I2.
4. `duct_graph.gd` (section N).
5. `lurker_routes.gd`: graph, `door_open`, `door_signature`, costs, A*, legs, door watching, `travel_metres`, exit choices. Test section O with the stub level. Section P.
6. **Acceptance of 2a-I:** `lurker_shell_test` green on seeds 1 to 10, with I2's figures in its evidence; `office_test`, `office_stages_test` and the tube tests unchanged.

**2a-II, body and probe** (after 0b, 0c, 0e, 0f, 1d to 1g, and 2a-I approved):

7. `lurker_motion.gd` with stub `clearance`, `busy` and `bodies_ahead` (unit-testable without physics), then `lurker.gd`, `lurker_creature.tscn`, the small changes of 8.5, the difficulty keys.
8. `lurker_route_probe.gd`; the reviewer runs it with `--trace` on the three seeds; fix; then the short version in `verify.ps1` with its measured limit (11.2).
9. Whole `verify.ps1` (by the director or one agent, never two at once); docs (section 14).
10. **Acceptance of 2a-II:** the full probe `PASS` on seeds 7, 81 and 404 with its recorded figures (section 15) in `evidence/lurker_route_probe.json`, and `verify.ps1` green.

---

## 13. Risks

1. **A static `new()` in a base script builds the base.** `duct_graph.of()` must call its own `new()` and the base's instance `fill()`; never the base's `from_manifest()` (it would return a `conduit_graph`, without `node_wings`).
2. **Folds and tight turns.** A channel hang past `CH_HANG_SHARE` or a band fillet under `R_MIN` gives a visible snap. Both are clamped at build time and tested (A, G). If a generated door sits so that `K0` falls outside a narrow room's `rect`, the shell test (I) fails: shrink `PORTAL_REACH` per band to what fits (minimum `t/2 + c + s + 0.2`) rather than moving the tray inset.
3. **Door state names.** `opened` flips at the end of a swing (`hotel_door.swing_to()`); `moving` covers the swing. Reading only `opened` would let her start into a door that is being shut. Use the three fields as 6.3 says.
4. **Signal lifetime.** Doors are rebuilt with every floor; connect in `setup()`, disconnect in `teardown()`, and rebuild `routes` in `arrive()`; never keep a node from a previous floor.
5. **Duck-typed level.** `lurker_routes` and `lurker_motion` must not type `level`, `hotel` or doors, or the stubs of 11.1 O will not fit. `hotel.get_node_or_null()` takes a NodePath on the real hotel and a String on the stub: pass a String.
6. **`BODY_DEPTH` is a guess** until step 1 of section 12 measures it. Too small and she clips heads and shelf tops; too large and she presses on the ceiling. Over 2.2 m furniture the lane is 0.75 m (OFICINAS 2), less than `BODY_DEPTH + HEAD_CLEAR + HANG_MIN`: the probe fails on a negative real clearance (11.2 check 7), and the lane is in section 15.
7. **Survivors and her shape.** In a 1 m aisle her 0.3 m sphere blocks a survivor (mask 169 has 32). That is wanted (she is in the way), but a dead-end aisle with her at its mouth is a trap; 2b's rule "nunca coge a quien la está mirando en la luz" and her stare time decide it. If playtests show stuck survivors, take 32 off while she is in a channel and a survivor is within 1.2 m. `bots_test --floor=2` uses the null creature, so it never measures this; the probe's test body does (11.2), and the head-height question is in section 15.
8. **Lamps and duct visuals.** Default stops keep `LAMP_CLEAR` from lamps (3.7). Passing under battens and pendants, and over network duct meshes in exposed rooms (no colliders), is still possible while moving; it goes with the service-corridor question of section 15.
9. **Versus restore.** Settled: `resume_state()` is in the contract (`creature.gd:236`) and `match_net.restore()` calls it for a returning hunter (`match_net.gd:1102`). She keeps the base no-op until phase 4 (8.2), noted in `docs/PLAN.md`.
10. **Observer.** `observer_view.gd:474` copies `creature.rotation.y`; with her upside-down basis it is a meaningless angle (no crash). Phase 3 changes the observer to `global_basis.z` for her if it matters.
11. **Room of a duct point.** `room_at()` of a duct point is the room below it. The director's `reach()` and `wing_of()` are right with that; nothing in 2a treats it as "she is in that room's light". 2b's senses must ask `motion.in_duct` first.
12. **Phase-1 manifest gaps.** If 1b gives gaps no node and 1c's validator rejects a gap exit with a node, `duct_graph.finish()` is the only place that attaches them; do not write nodes into the manifest (it is hashed on every machine).

---

## 14. Docs (Spanish, no "·" or "—")

- **`docs/LURKER.md`**: under "En Godot", a paragraph "Cómo se mueve" (cáscara: techos, franjas de dintel, bajadas a una rejilla, pasillos de archivo; ductos ocultos; nunca abre puertas; entre plantas por los ductos) pointing at `lurker_shell.gd`, `lurker_routes.gd`, `lurker_motion.gd`, `duct_graph.gd`, `lurker_creature.tscn`; "Lo que falta" loses "quien la mueva" and keeps the brain, the back cue, sounds and the floor.
- **`docs/DEVELOPMENT.md`**: the shell (patches, State, the frame, seams), the macro graph and its costs, the difficulty keys, how to run the probe and the shell test.
- **`docs/OFICINAS.md` 11.4**: "Grafo de ductos (`duct_graph.gd`, sobre `conduit_graph.gd`, el mismo que los tubos)".
- **`docs/DEVELOPMENT.md`**, also: the numbers of section 10 and `LIT_FACTOR`, `POWER_FACTOR`, `ARRIVE_BAND`, the den band, `DUCT_GAP`, `LAMP_CLEAR` and `CUE_ANGLE` as starting values, each with what would set it (a probe figure or playtests).
- **`docs/PLAN.md`** (phase 4): her `resume_state()`, `play_call()` and `validate_strike()`; the reliable events on entering and leaving a duct (OFICINAS 11.6), sent today only as flags (8.3).

---

## 15. Pending decisions

Raised by the critics on 22 October 2026. Until each is answered, 2a builds what the sections above say and the tests record the figures named.

### For the author (game, lore, how it feels)

1. **Service corridors, air room and plant (types 12, 22, 23):** with nothing to hold at 3.05 m and battens at 2.9 in her lane, how she goes along them: colliders on the network ducts on a layer only her hands see, with her tray under them; along the walls (bringing the WALL patch forward); or the battens moved off the centre line (3.3).
2. **The lane under 2.2 m furniture is 0.75 m** (OFICINAS 2) and her body needs about 1.0 m with the clearances: what gives (her hang, the furniture's height, or she does not pass over the tallest pieces), once `BODY_DEPTH` is measured (section 12 step 1).
3. **Under a door head** her body comes down to about 1.6 m: whether she may block a doorway at head height (3.4).
4. **Survivors against her** when she hangs at head height on a tray or in a doorway: whether they collide (are stopped, pushed) or pass (8.1); the probe records the figure.
5. **Her speed in the visible main duct:** decided by the author (23 October): **1 m/s on `main` and `cross` at every difficulty** (`MAIN_DUCT_SPEED := 1.0`), under the survivors' 1.2 crawl; `duct_speed` (1.2 to 2.4) for every other kind. `segment_speed(kind)` returns it by kind. OFICINAS 1 and 4 say so.
6. **A leaf shutting on her** under a door head: should the door bounce off her as off a body (7.3 band)?
7. **The plenum:** does "plénum" (OFICINAS 4 "Rondar", OFICINAS 2 "es ella arriba", the open office "correr por encima") mean only the ducts, or a hidden layer over the tiles with her sound coming out of the tile under her (3.6)?
8. **"Encima" of a locker:** a locker is 2.3 m tall under a 2.95 ceiling, 0.65 m between, and "la cara invertida a un palmo" of the slot is out of reach of any ceiling: what the posture is (for example, down the locker's front to the slot) (3.6).
9. **Wing 2's den** is the air room ("Su nido", "En su casa"): does she start each stage of wing 2 there, where the survivors end (8.2 `den_point`)?
10. **Between plantas:** what "el tiempo que tardaría" is (the drop of 2.5 to 5 s against a ride of 8.5 s, so the claws outside the car stop halfway), and whether she stays while someone is still on her planta ("Va a por el que se queda atrás") (7.6).
11. **A crouched victim** (camera near 0.9 m) cannot have her face within 20 degrees from any ceiling: must the victim look up, or does she come down for the cue (3.8)?
12. **No wardrobes** (`can(&"wardrobes")` false) follows OFICINAS 2 "no abre taquillas" and stays provisional with decision 5 of `spec_f2_mind.md` (8.2).
13. **Minor:** `peek_rate` as a multiplier for "Muchos, Muchos, Normales, Pocos"; whether a minutero's light herds her like the board's zones (`herds` and `lit()` are nearly the same rooms on wing 1, so `POWER_FACTOR` and `LIT_FACTOR` barely differ there) (section 10, 6.2).

### For the director (contracts, architecture)

1. **Split 2a** into 2a-I (pure) and 2a-II (body and probe) with the dependencies of section 0, and do the section 0 checks, correcting this spec, as each dependency lands.
2. **Lamp points as pure data:** whether 1d's palette exposes troffers, battens and pendants per room from the manifest (3.7); if not, which step adds it.
3. **`conduit_graph` searches** must read the instance's `edges` (5.1), and the base gains `edge_closed()`: a requirement on 1e's spec.
4. **The face:** 2a's `FACE_OFFSET` or 2b's head bone for `face_point()`; `cue_pose()` and 2b's torch test must use the same (3.8, 8.2).
5. **2b's interface:** floor and wall patches, `behind_point(..., &"any")`, "baja del techo delante" (OFICINAS 6), walls for "Acechar": whether 2a, 2b or phase 4's WALL patch provides them (8.6).
6. **Archive aisles:** channels in mobile archives once the crank exists (rebuilt when it moves), and whether channels get a cost in `plan()` so wing 1's way between the shelves does not depend only on 2b (3.3, 8.6).
7. **Reliable duct events** (OFICINAS 11.6) deferred to phase 4 because a new RPC breaks the wire check (8.3): confirm.
8. **`resume_state()`, `play_call()`, `validate_strike()`** for her deferred to phase 4 (8.2): confirm.
9. **`DUCT_GAP`** keeps her from passing a body in the visible duct (7.3): how close she may come there is 2b's capture rule; confirm 2a's guard stays under it.

### Resolved by the director (22 October 2026, step 0f)

- Difficulty key names are spec_f2_mind.md 4.1's (`lit_takes`, `freeze_time`, `creep_scale`, `peek_every` if the author gives the peeks numbers), not this draft's `lit_grab`, `stare_time`, `approach_scale` and `peek_rate`. Rename them here before `encargos`.
- Still open for phase 2: this draft's default `duct_speed` in code (1.6, Equilibrada) against MIND's rule that code defaults are Desafiante's (2.0); and the base of `creep_scale` (MIND's CREEP_SPEED 1.0 or this draft's CRAWL_SPEED 1.35).
- Line 19 is out of date: `set_floor()` exists since 0c (9f759db).

### From step 0e (22 October 2026)

- `ROOM_LAYERS.put_on_actor(mesh, bits)` exists, but `follow_bodies()` uses it only for meshes with the meta `"follow_rooms"` (none on floor 1; the first-person body is on layer 2 and must not move). Her face (lurker_visual.gd, LAYER 4) needs that meta and her body in the group follow_bodies walks (or `body_bit`, spec_f1_geometry H10).
