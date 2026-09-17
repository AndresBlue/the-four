extends StaticBody3D
signal noise(point: Vector3, radius: float)
signal sound_requested(opening: bool, slow: bool, point: Vector3, emitter: RID, forceful: bool)
## A swing started (towards `target` open or shut), and where it ended up:
## online, the host relays both so every machine shows the same door.
signal swung(target: bool, slow: bool, forceful: bool)
signal settled(opened: bool)
var opened := false
var moving := false
var closed_rotation := 0.0
var doorway := Vector3.ZERO
var motion: Tween

const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Only a body standing in the frame itself keeps the door from closing; the
## swinging leaf passes through anyone beside it (see _physics_process).
const THRESHOLD_DEPTH := 0.45

func occupied() -> bool:
	var frame := Basis(Vector3.UP, closed_rotation)
	for player in get_tree().get_nodes_in_group("hotel_players") + get_tree().get_nodes_in_group("hotel_actors"):
		var offset: Vector3 = player.global_position - doorway
		if absf(offset.dot(frame.z)) < THRESHOLD_DEPTH and absf(offset.dot(frame.x)) < FLOOR.PORTAL * 0.5 + 0.35:
			return true
	return false

## forceful: pushed while running; faster swing, a slam and a louder noise.
func toggle(slow := false, emit_noise := true, forceful := false) -> bool:
	if moving or (opened and occupied()): return false
	forceful = forceful and not slow
	if emit_noise: noise.emit(doorway, 3.0 if slow else 18.0 if forceful else 12.0)
	swing_to(not opened, slow, forceful)
	return true

## The swing itself, without the checks: also how a remote door follows the host.
func swing_to(target: bool, slow: bool, forceful: bool) -> void:
	if is_instance_valid(motion): motion.kill()
	moving = true
	# A swinging leaf must not sweep a CharacterBody into its door frame.
	# While swinging, ignore character contact but still occlude creature sight.
	collision_layer = 64
	swung.emit(target, slow, forceful)
	if target: sound_requested.emit(true, slow, doorway + Vector3.UP * 1.2, get_rid(), forceful)
	motion = create_tween()
	motion.tween_property(self, "rotation:y", closed_rotation + (1.48 if target else 0.0), 1.5 if slow else 0.32 if forceful else 0.55).set_trans(Tween.TRANS_QUAD if forceful else Tween.TRANS_SINE)
	motion.finished.connect(func():
		if not target and occupied():
			rotation.y = closed_rotation + 1.48
			opened = true
		else:
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
	collision_layer = 64

func _physics_process(_delta: float) -> void:
	if moving or collision_layer != 64: return
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null: return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = global_transform * shape.transform
	query.collision_mask = 4 | 32
	if get_world_3d().direct_space_state.intersect_shape(query).is_empty(): collision_layer = 8

func open_immediately() -> void:
	if is_instance_valid(motion): motion.kill()
	rotation.y = closed_rotation + 1.48
	opened = true
	moving = false
