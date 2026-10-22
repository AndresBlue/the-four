extends RefCounted
## How The Locust plays a capture out (creature.capture_style();
## docs/EXECUTION.md): on its victim at arm's length and turned to them, how
## they were caught, the room behind them for the body to go down in, and, at
## each second of the scene's clock, where everything of it is -- the body on
## its arm, the lens at their eyes, its mask over the lens, the floor the body
## is let fall on and where it comes to lie, the torch at rest -- and the pose
## its own body takes from those places (locust_visual.pose_capture).
##
## executions.gd keeps the capture itself (what the host decides and sends,
## the clock, the props, the death or letting go) and asks this for the
## places; death_tape.gd frames its picture in the mask given here, and
## blood.gd takes from it where the creature stands and faces. Moved here as
## it was in executions.gd: the same values, the same rays, the same draws in
## the same order (tests/hotel/creature_contract_test.gd holds it to the old
## computations). Made once by executions.gd, which sets `level`.
const SCORE := preload("res://game/app/capture_score.gd")
var level

# --- What the host decides ---------------------------------------------------------

## It is on them in the same instant it is in reach: the last of the way is
## its own, as far as the place lets its body go, and its victim is drawn in
## over what is left (executions.place_victim). Too near, it is the one that
## gives way: pushed back to arm's length, somebody against a wall went into
## it. Then it turns to them, wherever it was facing when it reached them.
## {away, yaw, far, feet}: from it to its victim on the level, the way it
## faces, how far from it they are held while the face lasts, and the floor
## the body will be let go on.
func approach(body: Node3D) -> Dictionary:
	var creature = level.creature
	var away: Vector3 = body.global_position - creature.global_position
	away.y = 0.0
	var distance := away.length()
	var wanted := clampf(distance, SCORE.HOLD_FAR.x, SCORE.HOLD_FAR.y)
	if distance >= 0.05 and absf(distance - wanted) > 0.02 and creature.control != "puppet" and not bool(body.hidden):
		creature.move_and_collide(away / distance * (distance - wanted))
		away = body.global_position - creature.global_position
		away.y = 0.0
		distance = away.length()
	var yaw: float = creature.rotation.y if distance < 0.05 else atan2(-away.x, -away.z)
	var feet: Vector3 = creature.global_position - Basis(Vector3.UP, yaw).z * SCORE.HOLD_NEAR
	return {"away": away, "yaw": yaw, "far": clampf(distance, SCORE.HOLD_FAR.x, SCORE.HOLD_FAR.y), "feet": feet}

## How somebody is caught, from where they and the creature are: [entry, side].
## In a wardrobe it is the wardrobe's (an ambush after the feint: pouncing);
## crouching, it comes from above; and on their feet it is where they were
## looking -- at it, away from it or neither. The side is the hand it is on
## (1 their right), or chance when it is ahead or behind: one draw of `rng`,
## always, whatever is chosen.
func choose_entry(body: Node3D, away: Vector3, rng: RandomNumberGenerator) -> Array:
	var creature = level.creature
	var chance := 1.0 if rng.randf() < 0.5 else -1.0
	if bool(body.hidden) and is_instance_valid(body.hiding_place): return ["ambush" if creature.get("pouncing") == true else "wardrobe", chance]
	if bool(body.crouched): return ["above", chance]
	if away.length() < 0.05: return ["front", chance]
	var look := -Basis(Vector3.UP, body.rotation.y).z
	var towards := -away.normalized()
	var angle := rad_to_deg(look.angle_to(towards))
	if angle <= 50.0: return ["front", chance]
	if angle >= 130.0: return ["back", chance]
	return ["side", 1.0 if towards.dot(Basis(Vector3.UP, body.rotation.y).x) > 0.0 else -1.0]

## How the body goes down when it is let go, from the room there is where it
## hangs: laid out back and to one side, to the other side if that one is
## taken, straight back if neither is free, and with no room to lie at all,
## folded up against whatever is behind it. [side, straight, slump, room]:
## the last is how far back it is clear, in metres. (Folded up it used to
## lean back a fixed half of the way down whatever was there: through the
## side of a wardrobe, or a wall.)
func fall_room(feet: Vector3, yaw: float, side: float, exclude: Array) -> Array:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for way in [side, -side]:
		if clear_along(space, feet, fall_way(yaw, float(way)), [0.35], exclude) >= SCORE.LIE_ROOM: return [float(way), false, false, SCORE.LIE_ROOM]
	var behind := clear_along(space, feet, fall_way(yaw, 0.0), [0.2, 0.6], exclude)
	if behind >= SCORE.LIE_ROOM: return [side, true, false, behind]
	return [side, false, true, behind]

## How far it is clear from a spot on the floor in a direction, at the
## nearest of some heights, up to the length of a body.
static func clear_along(space: PhysicsDirectSpaceState3D, feet: Vector3, along: Vector3, heights: Array, exclude: Array) -> float:
	var least: float = SCORE.LIE_ROOM
	for height in heights:
		var from: Vector3 = feet + Vector3.UP * float(height)
		var query := PhysicsRayQueryParameters3D.create(from, from + along * SCORE.LIE_ROOM, 1 | 8)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if not hit.is_empty(): least = minf(least, from.distance_to(hit.position))
	return least

## The way a body falls, in the world: back from the creature and to a side
## (the avatar's own, avatar_visual.pose_capture); straight back with no side.
static func fall_way(yaw: float, side: float) -> Vector3:
	return (Basis(Vector3.UP, yaw + PI) * Vector3(side * 0.62, 0.0, 0.78)).normalized()

# --- Where everything is, at a second of the scene (`execution`) ---------------------

## Where it stands: the creature, or where the host said it was if it has gone.
func creature_point(execution: Dictionary) -> Vector3:
	return level.creature.global_position if is_instance_valid(level.creature) else execution.point

## The way it faces: its victim, always.
func creature_forward(execution: Dictionary) -> Vector3:
	return -Basis(Vector3.UP, float(execution.yaw)).z

## Where the victim of the execution in hand is: on the arm in front of the
## creature, at arm's length while the face lasts, then lifted and drawn in
## as it straightens, and on the floor once it lets go.
func victim_hold_point(execution: Dictionary) -> Vector3:
	var time := float(execution.time)
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	var reach := lerpf(far, SCORE.HOLD_NEAR, SCORE.closing(time))
	return creature_point(execution) + creature_forward(execution) * reach + Vector3(0, SCORE.HOLD_STAND * (1.0 - SCORE.fall(time)) + SCORE.lift(time) * SCORE.LIFT_HEIGHT, 0)

## Where the victim's camera is while the face lasts: at its own eyes, where
## it was pulled to.
func lens_point(execution: Dictionary) -> Vector3:
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	var eyes := 0.9 if bool(execution.get("crouched", false)) else 1.64
	return creature_point(execution) + creature_forward(execution) * far + Vector3(0, SCORE.HOLD_STAND + eyes, 0)

## From the lens, which way the mask is: ahead and a little over it; and
## straight above somebody caught crouching.
func mask_from(execution: Dictionary) -> Vector3:
	if bool(execution.get("crouched", false)): return (Vector3.UP * 0.9 - creature_forward(execution) * 0.35).normalized()
	return (-creature_forward(execution) + Vector3.UP * 0.2).normalized()

## The floor where the body is let go, and where it lies: along the way it
## falls, or in a heap where it dropped.
func drop_point(execution: Dictionary) -> Vector3:
	return creature_point(execution) + creature_forward(execution) * SCORE.HOLD_NEAR

## The way the body goes down: back and to its side, or straight back when
## that is all the room there is (laid out so, or folded up).
func fall_dir(execution: Dictionary) -> Vector3:
	var straight: bool = bool(execution.get("straight", false)) or bool(execution.get("slump", false))
	return fall_way(float(execution.yaw), 0.0 if straight else float(execution.get("side", 1.0)))

func body_rest(execution: Dictionary) -> Vector3:
	var room := float(execution.get("room", 0.0))
	return drop_point(execution) + fall_dir(execution) * (SCORE.seat_back(room) + 0.3 * sin(SCORE.seat_lean(room)))

## Where its head comes to lie (or to hang, sitting).
func head_rest(execution: Dictionary) -> Vector3:
	var room := float(execution.get("room", 0.0))
	return drop_point(execution) + fall_dir(execution) * (SCORE.seat_back(room) + 0.1 + 0.7 * sin(SCORE.seat_lean(room)))

## To which side the head of whoever dies turns once it is dead (1 its left,
## -1 its right): away from where its camcorder lies, as it will be lying
## when it has fallen -- on its back, its head along the way it went over --,
## so that the last of the tape is not its face looking into the lens. With
## no word yet of where the camera is, the side it falls to.
func head_away(execution: Dictionary) -> float:
	var lens = execution.get("lens")
	var side := float(execution.get("side", 1.0))
	if not (lens is Transform3D): return side
	var level_way := Vector3(0.0 if bool(execution.get("straight", false)) or bool(execution.get("slump", false)) else side * 0.62, 0.0, 0.78).normalized()
	var its_right := Basis(Vector3.UP, float(execution.yaw) + PI + atan2(level_way.x, level_way.z)) * Vector3.RIGHT
	var beside := ((lens as Transform3D).origin - head_rest(execution)).dot(its_right)
	if absf(beside) < 0.05: return side
	return 1.0 if beside > 0.0 else -1.0

## What the tape of whoever dies needs to know of the place (death_tape.plan).
func staging(execution: Dictionary) -> Dictionary:
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	return {
		"lens": lens_point(execution), "middle": creature_point(execution) + creature_forward(execution) * far * 0.5, "hold": drop_point(execution), "body": body_rest(execution),
		"head": head_rest(execution), "creature": creature_point(execution),
	}

## Where the victim's torch ends up, and pointing where: to the side the swipe
## sends things, a step or two from where the body hangs, lying on the floor
## and turned back towards the creature -- so that its beam runs along the
## carpet, up the creature and on to the wall behind it. Drawn from the
## capture's seed and stopped by the walls, which are the same on every
## machine: everybody sees it come to rest in the same place.
func torch_rest(execution: Dictionary) -> Transform3D:
	var draw := RandomNumberGenerator.new()
	draw.seed = int(execution.get("seed", 0)) ^ 0x51ed
	var forward := creature_forward(execution)
	var right := forward.cross(Vector3.UP)
	var side := float(execution.get("side", 1.0))
	var out := (forward * draw.randf_range(0.5, 0.9) - right * side * draw.randf_range(0.6, 1.0)).normalized()
	var from := lens_point(execution) - Vector3.UP * 0.3
	# Far enough for its beam, level with the floor, to have opened up to the
	# height of legs by the time it reaches them.
	var spot := drop_point(execution) + out * draw.randf_range(2.1, 2.9)
	var query := PhysicsRayQueryParameters3D.create(from, spot + Vector3.UP * 0.2, 1)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var back := from - (hit.position as Vector3)
		back.y = 0.0
		spot = (hit.position as Vector3) + back.normalized() * 0.25
	spot.y = creature_point(execution).y + 0.035
	var aim := drop_point(execution).lerp(creature_point(execution), 0.5) + Vector3.UP * 0.9 - spot
	return Transform3D(Basis(Vector3.UP, atan2(-aim.x, -aim.z) + draw.randf_range(-0.22, 0.22)) * Basis(Vector3.RIGHT, deg_to_rad(4.0)), spot)

# --- Its own body ------------------------------------------------------------------

## What the creature needs to pose itself (locust_visual.pose_capture):
## places in the world, at this second.
func scene_for(execution: Dictionary) -> Dictionary:
	var time := float(execution.time)
	var hold := victim_hold_point(execution)
	# Somebody caught crouching is on their feet by the time they are lifted.
	var low := (1.0 - SCORE.lift(time)) if bool(execution.get("crouched", false)) else 0.0
	var lens = execution.get("lens")
	return {
		"time": time, "entry": String(execution.get("entry", "front")), "side": float(execution.get("side", 1.0)),
		"ending": String(execution.get("ending", "leave")), "lens": lens_point(execution), "mask_from": mask_from(execution),
		"chest": hold + Vector3.UP * lerpf(1.2, 0.68, low), "face": hold + Vector3.UP * lerpf(1.58, 0.88, low),
		"body": body_rest(execution) + Vector3.UP * 0.12, "glance": (lens as Transform3D).origin if lens is Transform3D else Vector3.INF,
	}

## Whether there is a body of it the scene can pose: its visual, with a
## scene to be written.
func posable() -> bool:
	var creature = level.creature
	return is_instance_valid(creature) and is_instance_valid(creature.visual) and "scene" in creature.visual

## Its body posed by the scene at this second, every frame of it.
func pose(execution: Dictionary) -> void:
	if posable(): level.creature.visual.scene = scene_for(execution)

## The scene lets go of its body: its own animation again.
func unpose() -> void:
	if posable(): level.creature.visual.scene = {}

## Where the mask is in the world as posed, as a frame (+Z out of the face, +Y
## up it: locust_visual.mask_transform): the tape of whoever is caught frames
## its picture in it while the face lasts (death_tape.facing). Null with no
## body of it to frame.
func mask_transform() -> Variant:
	if not posable(): return null
	return level.creature.visual.mask_transform()
