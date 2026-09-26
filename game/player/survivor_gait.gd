extends RefCounted
## How a survivor's body moves, whoever moves it: the local player from the
## keys, a test bot from what it decided (tools/bots). One set of numbers, so a
## bot that gets through a doorway is a player that gets through it, and one
## that tires or is heard does so at the same stride and the same distance.
##
## Everything works on the body's own fields, which keep the names the rest of
## the game and the tests read: stamina, recovery_delay, exhausted, crouched,
## body_shape (its capsule), velocity and step_phase.
const NOISE := preload("res://game/audio/noise_kinds.gd")
const SPEED_CROUCH := 2.0
const SPEED_WALK := 3.8
const SPEED_RUN := 6.0
## Metres per second gained or lost per second: quick to start and to stop.
const ACCELERATION := 22.0
const GRAVITY := 20.0
# Stamina: long sprints, slow and delayed recovery.
const STAMINA_DRAIN := 8.0
const STAMINA_RECOVERY := 6.0
const RECOVERY_DELAY := 3.0
const EXHAUSTED_UNTIL := 30.0
# Adult cadence at each gait's speed (steps per second). Footfalls still come
# from distance covered, so the stride is speed / cadence: long strides
# walking, longer and slightly quicker ones running.
const CADENCE_WALK := 2.0
const CADENCE_RUN := 2.5
const CADENCE_CROUCH := 1.5
const STRIDE_WALK := SPEED_WALK / CADENCE_WALK
const STRIDE_RUN := SPEED_RUN / CADENCE_RUN
const STRIDE_CROUCH := SPEED_CROUCH / CADENCE_CROUCH
## The capsule standing and crouched: its height, and where its middle sits.
const HEIGHT_STANDING := 1.8
const HEIGHT_CROUCHED := 1.05
const MIDDLE_STANDING := 0.91
const MIDDLE_CROUCHED := 0.54

## Crouched if it wants to be, standing only where there is room above. The
## capsule follows, and only on a change: every write rebuilds the shape.
static func set_crouch(body, wants: bool) -> void:
	if wants or can_stand(body): body.crouched = wants
	var height := HEIGHT_CROUCHED if body.crouched else HEIGHT_STANDING
	if not is_equal_approx(body.body_shape.shape.height, height):
		body.body_shape.shape.height = height
		body.body_shape.position.y = MIDDLE_CROUCHED if body.crouched else MIDDLE_STANDING

static func can_stand(body) -> bool:
	if not body.crouched: return true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = HEIGHT_STANDING
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	# Query above the contact margin: touching the floor must not forbid standing.
	query.transform = Transform3D(Basis.IDENTITY, body.global_position + Vector3(0, 0.95, 0))
	query.collision_mask = 1 | 8 | 128
	return body.get_world_3d().direct_space_state.intersect_shape(query).is_empty()

## One frame of breath: whether the body runs, given that it wants to and is
## moving at all. Running spends stamina; anything else gets it back after a
## delay, and an empty body walks until it is back to EXHAUSTED_UNTIL.
static func tire(body, wants_run: bool, delta: float) -> bool:
	var running: bool = wants_run and not body.crouched and body.stamina > 0 and not body.exhausted
	if running:
		body.stamina = maxf(0, body.stamina - STAMINA_DRAIN * delta)
		body.recovery_delay = RECOVERY_DELAY
		if body.stamina <= 0: body.exhausted = true
	else:
		body.recovery_delay = maxf(0, body.recovery_delay - delta)
		if body.recovery_delay <= 0: body.stamina = minf(100, body.stamina + STAMINA_RECOVERY * delta)
		if body.stamina >= EXHAUSTED_UNTIL: body.exhausted = false
	return running

static func speed(crouched: bool, running: bool) -> float:
	return SPEED_CROUCH if crouched else SPEED_RUN if running else SPEED_WALK

## Towards `direction` (flat, at most unit long: a pad pushed half way is half
## the gait's speed) at the gait's speed, and down while off the floor. The
## caller moves the body.
static func accelerate(body, direction: Vector3, running: bool, delta: float) -> void:
	var top := speed(body.crouched, running)
	body.velocity.x = move_toward(body.velocity.x, direction.x * top, ACCELERATION * delta)
	body.velocity.z = move_toward(body.velocity.z, direction.z * top, ACCELERATION * delta)
	if not body.is_on_floor(): body.velocity.y -= GRAVITY * delta

static func stride(crouched: bool, running: bool) -> float:
	return STRIDE_CROUCH if crouched else STRIDE_RUN if running else STRIDE_WALK

## What one footfall sounds like to the creature: how far it carries and what
## made it. Tiles carry a step further than carpet.
static func footfall(crouched: bool, running: bool, hard: bool) -> Dictionary:
	var gait := "crouch" if crouched else "run" if running else "walk"
	return {"radius": NOISE.radius(gait + ("_hard" if hard else "")), "kind": NOISE.Kind.RUN if running and not crouched else NOISE.Kind.FOOTSTEP}
