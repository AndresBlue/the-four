extends StaticBody3D
const NOISE := preload("res://game/audio/noise_kinds.gd")
signal noise(point: Vector3, radius: float, kind: int)
signal sound_requested(opening: bool, slow: bool, point: Vector3, emitter: RID, forceful: bool)
## A swing started (towards `target` open or shut), and where it ended up:
## online, the host relays both so every machine shows the same door.
signal swung(target: bool, slow: bool, forceful: bool)
signal settled(opened: bool)
var opened := false
var moving := false
## The door that leads on to the next wing stays shut until its stage is
## closed. Nothing opens it in the meantime: not the players, not the creature,
## not a slam.
var locked := false
var gate_stage := 0
var closed_rotation := 0.0
var doorway := Vector3.ZERO
var motion: Tween

## The leaf is solid only at rest and with nobody inside it. While it swings
## it is a ghost to bodies -- it still hides what is behind it from sight and
## from the creature's hearing, which look for layer 64 -- and when it stops
## it stays one until whoever it stopped on has stepped out of it (see
## _physics_process). So a door is never refused because somebody stands in
## the frame, it never shoves anybody, and nobody is ever shut inside it.
const GHOST := 64
const SOLID := 8
## Bodies a solid leaf would trap: survivors, local or remote. The creature
## does not collide with doors at all, so it never holds one open.
const TRAPPED := 4

## forceful: pushed while running; faster swing, a slam and a louder noise.
func toggle(slow := false, emit_noise := true, forceful := false) -> bool:
	if locked or moving: return false
	forceful = forceful and not slow
	if emit_noise: noise.emit(doorway, NOISE.radius("door_slow" if slow else "slam" if forceful else "door"), NOISE.Kind.SLAM if forceful else NOISE.Kind.DOOR)
	swing_to(not opened, slow, forceful)
	return true

## The swing itself, without the checks: also how a remote door follows the host.
func swing_to(target: bool, slow: bool, forceful: bool) -> void:
	if is_instance_valid(motion): motion.kill()
	moving = true
	collision_layer = GHOST
	swung.emit(target, slow, forceful)
	if target: sound_requested.emit(true, slow, doorway + Vector3.UP * 1.2, get_rid(), forceful)
	motion = create_tween()
	motion.tween_property(self, "rotation:y", closed_rotation + (1.48 if target else 0.0), 1.5 if slow else 0.32 if forceful else 0.55).set_trans(Tween.TRANS_QUAD if forceful else Tween.TRANS_SINE)
	# It always ends where it was sent: whoever stands in it is let out by
	# _physics_process, never by sending the door back. (A door that bounced
	# open again also bounced differently on each machine, since each one
	# judged who was in the frame by its own copy of the bodies.)
	motion.finished.connect(func():
		opened = target
		if not target: sound_requested.emit(false, slow, doorway + Vector3.UP * 1.2, get_rid(), forceful)
		moving = false
		settled.emit(opened)
	)

## Snaps to a state decided elsewhere (the host's door after its swing).
func set_state(open: bool) -> void:
	if is_instance_valid(motion): motion.kill()
	rotation.y = closed_rotation + (1.48 if open else 0.0)
	opened = open
	moving = false
	# Solid again once nobody stands in the leaf (see _physics_process).
	collision_layer = GHOST

## Whether a body stands where the leaf is now: a solid leaf there would
## have it inside and the physics would throw it out sideways, or keep it.
func holds_somebody() -> bool:
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null or not is_inside_tree(): return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = global_transform * shape.transform
	query.collision_mask = TRAPPED
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _physics_process(_delta: float) -> void:
	if moving or collision_layer != GHOST: return
	if not holds_somebody(): collision_layer = SOLID

func open_immediately() -> void:
	if is_instance_valid(motion): motion.kill()
	rotation.y = closed_rotation + 1.48
	opened = true
	moving = false
	# Wherever it was left, it turns solid only once it holds nobody.
	collision_layer = GHOST
