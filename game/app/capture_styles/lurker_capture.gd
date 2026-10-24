extends "res://game/app/capture_styles/locust_capture.gd"
## How The Lurker plays a capture out (creature.capture_style();
## spec_f3_integration 5; OFICINAS 6): she never comes down. From the ceiling
## over the victim's shoulders (behind them, or in front of them from above in
## a high room or an archive aisle) two hands close on the shoulders, the body
## is turned round on them, her face hangs upside down in front of the lens
## until the camera is let go, and she pulls them up into the dark as far as
## the ceiling lets her; the bite is out of the picture, and the body is let
## fall where it stood. A ceiling tile swings where she came through.
## The Locust's way of laying the body down, and of the torch, is kept.
const LURKER_SCORE := preload("res://game/app/capture_styles/lurker_score.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const BITES := ["res://assets/audio/sfx/lurker/bite_1.wav", "res://assets/audio/sfx/lurker/bite_2.wav"]
## Her captures hang their victim (avatar_visual.pose_capture "hang") and a
## tile swings over them.
const SWING_TILE := true
const HANG := true
## A room this high is "techo alto": she may take somebody from above (0.5.5).
const HIGH_ROOM := 3.0
## How far behind (or in front of) the victim she hangs, and how far a ray
## looks up for the ceiling.
const HANG_BEHIND := 0.45
const CEILING_REACH := 2.6
## She comes down this much to take them, and goes back up with them.
const STOOP := 0.25
## The tile: when it is knocked loose, how far it hangs open and how it swings.
const TILE_FROM := 0.2
const TILE_OPEN := 0.2
const TILE_SWING := 0.45
var tile: MeshInstance3D = null
var tile_for := -1

func score(): return LURKER_SCORE

func kill_sound(seed_value: int) -> String: return BITES[seed_value % BITES.size()]

func kill_sound_at() -> float: return LURKER_SCORE.KILL_TIME

## The bite lands at her face.
func kill_point(execution: Dictionary) -> Vector3:
	var face = mask_transform()
	return (face as Transform3D).origin if face is Transform3D else hang_of(execution)

# --- What the host decides ---------------------------------------------------------

## She does not move: {away, yaw, far, feet}, from her to the victim on the
## level, the way she faces them, how far off they are (in her score's
## range), and their feet, where the body will be let go.
func approach(body: Node3D) -> Dictionary:
	var creature = level.creature
	var away: Vector3 = body.global_position - creature.global_position
	away.y = 0.0
	var distance := away.length()
	var yaw: float = creature.rotation.y if distance < 0.05 else atan2(-away.x, -away.z)
	return {"away": away, "yaw": yaw, "far": clampf(distance, LURKER_SCORE.HOLD_FAR.x, LURKER_SCORE.HOLD_FAR.y), "feet": body.global_position}

## [entry, side]: one draw of `rng`, always. From above when the room is high
## (or they stand in an archive aisle), she is ahead of their eyes within 70
## degrees and they have not looked up; from behind otherwise.
func choose_entry(body: Node3D, away: Vector3, rng: RandomNumberGenerator) -> Array:
	var chance := 1.0 if rng.randf() < 0.5 else -1.0
	var room := FLOOR.room_at(level.manifest.rooms, body.global_position)
	var high: bool = not room.is_empty() and (OFFICE.height_of(room) > HIGH_ROOM or in_aisle(body.global_position))
	var look := -Basis(Vector3.UP, body.rotation.y).z
	var towards := -away.normalized() if away.length() >= 0.05 else look
	var ahead: bool = rad_to_deg(look.angle_to(towards)) <= 70.0
	var pitch: float = rad_to_deg(body.camera.rotation.x) if body.get("camera") != null else 0.0
	return ["above" if high and ahead and pitch < 30.0 else "back", chance]

func in_aisle(point: Vector3) -> bool:
	for archive in level.manifest.get("archives", []):
		for r in archive.get("aisles", []):
			if point.x >= float(r[0]) and point.x <= float(r[2]) and point.z >= float(r[1]) and point.z <= float(r[3]): return true
	return false

## What only she needs sent with the capture (5.3): where she hangs, the
## ceiling there, how high she can lift them, and the tile over her.
func stage_extra(body: Node3D, _placed: Dictionary, data: Dictionary) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var creature = level.creature
	var exclude: Array = [body.get_rid(), creature.get_rid()]
	var head := body.global_position + Vector3.UP * 1.85
	var look := -Basis(Vector3.UP, body.rotation.y).z
	var behind: bool = String(data.get("entry", "back")) != "above"
	var under := head + (-look if behind else look) * HANG_BEHIND
	var ceiling := ceiling_over(space, under, exclude)
	var free := INF
	for offset in [Vector3.ZERO, Vector3(0.2, 0, 0), Vector3(-0.2, 0, 0), Vector3(0, 0, 0.2), Vector3(0, 0, -0.2)]:
		free = minf(free, ceiling_over(space, head + offset, exclude) - (head.y + offset.y))
	var room := FLOOR.room_at(level.manifest.rooms, under)
	var over: Array = []
	if not room.is_empty() and OFFICE.false_ceiling(room):
		var t := OFFICE.tile_of(under)
		over = [t.x, t.y]
	return {"hang": Vector3(under.x, ceiling - 0.05, under.z), "ceiling": ceiling, "lift": clampf(free - 0.12, 0.0, LURKER_SCORE.LIFT_HEIGHT), "tile": over}

## The ceiling's height over a point (a ray up, mask 1 | 8, CEILING_REACH);
## the point plus CEILING_REACH with nothing there.
func ceiling_over(space: PhysicsDirectSpaceState3D, point: Vector3, exclude: Array) -> float:
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.UP * CEILING_REACH, 1 | 8)
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	return (hit.position as Vector3).y if not hit.is_empty() else point.y + CEILING_REACH

# --- Where everything is, at a second of the scene ---------------------------------

func extra_of(execution: Dictionary) -> Dictionary: return execution.get("extra", {})

## Where she hangs: the host's point, or over the victim's feet with none.
func hang_of(execution: Dictionary) -> Vector3:
	var extra := extra_of(execution)
	if extra.has("hang"): return extra.hang
	return (execution.get("from", execution.point) as Vector3) + Vector3.UP * CEILING_REACH

## Her anchor: from where she was at the grab to where she hangs, over her
## score's ARRIVE.
func creature_point(execution: Dictionary) -> Vector3:
	var time := float(execution.get("time", 0.0))
	return (execution.point as Vector3).lerp(hang_of(execution), LURKER_SCORE.smooth(time / LURKER_SCORE.ARRIVE))

## The victim's feet lifted as far as the ceiling lets her.
func victim_hold_point(execution: Dictionary) -> Vector3:
	var lift := float(extra_of(execution).get("lift", LURKER_SCORE.LIFT_HEIGHT))
	return (execution.from as Vector3) + Vector3.UP * LURKER_SCORE.lift(float(execution.time)) * lift

func lens_point(execution: Dictionary) -> Vector3:
	var eyes := 0.9 if bool(execution.get("crouched", false)) else 1.64
	return victim_hold_point(execution) + Vector3.UP * eyes

## From the lens to her face: up and towards where she hangs.
func mask_from(execution: Dictionary) -> Vector3:
	var to := hang_of(execution) - lens_point(execution)
	return to.normalized() if to.length() > 0.01 else Vector3.UP

## The body is let go where it stood.
func drop_point(execution: Dictionary) -> Vector3:
	return execution.from

## The tape is told to look up as the camera falls, at where she hangs.
func staging(execution: Dictionary) -> Dictionary:
	var out := super(execution)
	out["look_up"] = true
	out["ceiling"] = hang_of(execution)
	return out

# --- Her body ------------------------------------------------------------------------

func posable() -> bool:
	var creature = level.creature
	return is_instance_valid(creature) and is_instance_valid(creature.visual) and creature.visual.get("limbs") != null

## Every frame of the scene: hanging head down over them, facing them, a little
## lower to take them and back up with them; her face upside down at the
## lens, her front hands on their shoulders until she lets go; and the tile.
func pose(execution: Dictionary) -> void:
	if not posable(): return
	var creature = level.creature
	var visual = creature.visual
	var time := float(execution.time)
	var beat = LURKER_SCORE
	var z := creature_forward(execution)
	var x := Vector3.DOWN.cross(z).normalized()
	var at := creature_point(execution) + Vector3.DOWN * STOOP * float(beat.grab(time)) * (1.0 - float(beat.lift(time)))
	creature.global_transform = Transform3D(Basis(x, Vector3.DOWN, z), at)
	creature.scene_held = true
	visual.crawling = true
	visual.look_point = lens_point(execution)
	visual.limbs.upright_share = 0.0
	var clip := "loom" if time < beat.face_end(String(execution.get("entry", "back"))) else "idle"
	if visual.get("animator") != null and visual.animator.current_animation != clip: visual.play(clip)
	var grips := {}
	var body = level.executions.victim_body()
	if body != null and "avatar" in body and body.avatar != null and float(beat.grab(time)) > 0.0 and time < float(beat.DROP_TIME):
		for side in [["a.L", "la"], ["a.R", "ra"]]:
			var bone = body.avatar.bones.get(side[1], -1)
			if int(bone) < 0: continue
			var point: Vector3 = body.avatar.bone_point(int(bone))
			grips[side[0]] = {"point": point, "normal": (at - point).normalized()}
	visual.limbs.grips = grips
	swing_tile(execution, time)

## A ceiling tile knocked loose where she came through, swinging on its edge
## farthest from the victim, left there after (executions.leavings).
func swing_tile(execution: Dictionary, time: float) -> void:
	var extra := extra_of(execution)
	var over: Array = extra.get("tile", [])
	if not SWING_TILE or over.is_empty() or time < TILE_FROM: return
	if tile_for != int(execution.get("id", 0)) or not is_instance_valid(tile):
		tile_for = int(execution.get("id", 0))
		tile = MeshInstance3D.new()
		tile.name = "SwingingTile"
		var box := BoxMesh.new()
		box.size = Vector3(OFFICE.TILE, 0.015, OFFICE.TILE)
		tile.mesh = box
		tile.material_override = level.hotel.materials.get("ceiling_service")
		level.hotel.add_child(tile)
		var leavings = level.executions.get("leavings")
		if leavings is Array: leavings.append(tile)
	var centre := OFFICE.tile_centre(Vector2i(int(over[0]), int(over[1])), float(extra.get("ceiling", 0.0)))
	var away: Vector3 = centre - (execution.from as Vector3)
	away.y = 0.0
	var out := away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var hinge := centre + out * OFFICE.TILE * 0.5
	var s := time - TILE_FROM
	var angle := TILE_OPEN + TILE_SWING * exp(-0.4 * s) * cos(2.2 * s)
	var axis := Vector3.UP.cross(out).normalized()
	var basis := Basis(axis, -angle)
	tile.global_transform = Transform3D(basis, hinge + basis * (-out * OFFICE.TILE * 0.5))
	level.hotel.adopt(tile)

func unpose() -> void:
	if not posable(): return
	var creature = level.creature
	creature.scene_held = false
	creature.visual.limbs.grips = {}
	creature.visual.limbs.upright_share = 1.0

# --- The tape and the blood ----------------------------------------------------------

## Her face fills the picture, a span away, and does not come at the lens
## (death_tape.facing()).
func tape_framing() -> Dictionary:
	return {"far": 0.6, "held": 0.34, "close": 0.3, "near": 0.24, "lunge_time": 0.0, "back_dip": -0.12}

## As she pulls them up the picture rises into the dark of the ceiling.
func tape_pose(execution: Dictionary, time: float, framed: Transform3D) -> Transform3D:
	var k: float = LURKER_SCORE.lift(time)
	var lift := float(extra_of(execution).get("lift", LURKER_SCORE.LIFT_HEIGHT))
	return Transform3D(framed.basis * Basis(Vector3.RIGHT, 0.35 * k), framed.origin + Vector3.UP * k * lift * 0.9)

## Where the body is held, its chest and its face, from what blood.gd kept of
## the scene: over their feet, lifted as she lifts them.
func blood_held(scene: Dictionary, time: float) -> Vector3:
	var lift := float((scene.get("extra", {}) as Dictionary).get("lift", LURKER_SCORE.LIFT_HEIGHT))
	return (scene.feet as Vector3) + Vector3.UP * LURKER_SCORE.lift(time) * lift

func blood_chest(scene: Dictionary, time: float) -> Vector3:
	var falling: float = LURKER_SCORE.fall(time)
	var sunk: float = LURKER_SCORE.sunk(falling)
	return blood_held(scene, time) + Vector3.UP * lerpf(1.2, 0.3, sunk) + (scene.fall as Vector3) * LURKER_SCORE.seat_back(float(scene.room)) * sunk

func blood_face(scene: Dictionary, time: float) -> Vector3:
	return blood_held(scene, time) + Vector3.UP * 1.58

## No wound at the grab (the cause is seen, not the blow); at the bite a spray
## from the face held up, half of it up to the ceiling and half down round
## the feet; let go, the chest on the floor wells four times. Sparing, the
## spray only.
func spill(scene: Dictionary, rng: RandomNumberGenerator, drops: Array, sparing: bool, blood) -> void:
	var face := blood_face(scene, LURKER_SCORE.KILL_TIME)
	for index in 40:
		var towards := Vector3.UP if index % 2 == 0 else Vector3.DOWN
		var from := face + Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
		blood.drop(drops, LURKER_SCORE.KILL_TIME + rng.randf() * 0.1, from, blood.scattered(rng, towards, 0.55 if index % 2 == 0 else 0.9) * rng.randf_range(2.0, 6.0), rng.randf_range(0.07, 0.2))
	if sparing: return
	for pulse in 4:
		var at: float = LURKER_SCORE.DROP_TIME + 0.04 + 0.21 * float(pulse)
		var strength := 1.0 - 0.24 * float(pulse)
		for index in 7 - pulse:
			blood.drop(drops, at + rng.randf() * 0.07, blood_chest(scene, at), blood.scattered(rng, Vector3.UP, 0.75) * rng.randf_range(0.8, 2.3) * strength, rng.randf_range(0.09, 0.18))

## What is heard of it: the spray at the bite, and the chest welling after the
## drop (nothing at the grab).
func blood_sounds(scene: Dictionary, rng: RandomNumberGenerator, sparing: bool, blood) -> Array:
	var said: Array = [{"time": LURKER_SCORE.KILL_TIME + 0.02, "path": blood.SPRAY, "at": blood_face(scene, LURKER_SCORE.KILL_TIME), "db": blood.SPRAY_DB}]
	if sparing: return said
	var gushes: Array = blood.GUSHES
	var first := rng.randi_range(0, gushes.size() - 1)
	for pulse in 4:
		var at: float = LURKER_SCORE.DROP_TIME + 0.04 + 0.21 * float(pulse)
		said.append({"time": at, "path": gushes[(first + pulse) % gushes.size()], "at": blood_chest(scene, at), "db": blood.WELL_DB - blood.WELL_FADE * float(pulse)})
	return said

## Her face as a frame: at her face, +Z to the lens, +Y the top of her head
## (down, while she hangs).
func mask_transform() -> Variant:
	if not posable(): return null
	var creature = level.creature
	var face: Vector3 = creature.face_point()
	var lens: Dictionary = level.executions.execution
	var to: Vector3 = lens_point(lens) - face if not lens.is_empty() else -creature.global_basis.y
	if to.length() < 0.01: return null
	return Transform3D(Basis.looking_at(-to, Vector3.DOWN), face)
