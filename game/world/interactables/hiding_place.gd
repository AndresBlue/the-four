extends Area3D
## Wardrobe hiding place. The occupant stands inside with both doors shut;
## holding forward eases the doors ajar. Each leaf opens on its own: looking to
## one side opens the opposite leaf, which then shields the head leaning out.
## Closed doors block sight like a wall; a door left ajar lets a creature see
## the occupant. The Area3D itself is only the interaction target.
const BODY := preload("res://assets/props/wardrobe/wardrobe_body.res")
const LEAVES := {"left": preload("res://assets/props/wardrobe/wardrobe_leaf_left.res"), "right": preload("res://assets/props/wardrobe/wardrobe_leaf_right.res")}
## Hinge of the right leaf in wardrobe space (the left one mirrors X).
const HINGE := Vector3(0.615, 0.0, 0.38)
const WIDTH := 1.25
const HEIGHT := 2.3
const DEPTH := 0.78
## Door angles (radians): fully open, and a leaf ajar at maximum peek.
const OPEN_ANGLE := 1.75
const PEEK_ANGLE := 1.05
## Doors wider than this stop blocking movement so they never shove anyone.
## They go on hiding what is behind them, like a door mid-swing: layer 64,
## which sight looks for and bodies do not. Turned off altogether, the wood
## still in front of somebody peeking stopped hiding them, and a creature saw
## straight through a leaf open 24 degrees.
const COLLISION_LIMIT := 0.3
const SOLID := 8
const SIGHT_ONLY := 64
signal peek_started(point: Vector3)
## The creature pulled the doors open (online, the host relays it).
signal forced
var occupant: CharacterBody3D
## Where the occupant steps out, and where they stand inside (local space).
var exit_offset := Vector3(0, 0.04, 1.15)
var inside_offset := Vector3(0, 0.04, -0.02)
## 0 closed .. 1 wide open (entering, leaving, forced); peek is separate.
var opening := 0.0
## Per leaf, 0..1, named in wardrobe space: "left" is the leaf at -X, which is
## on the right hand of someone standing inside.
var peek := {"left": 0.0, "right": 0.0}
## Leaves pulled wide open one by one (the creature searching it).
var wide := {"left": 0.0, "right": 0.0}
var leaf_motion := {}
## Only the first time the doors part during a stay makes a sound.
var peeked := false
var pivots := {}
var leaf_bodies := {}
var motion: Tween
var close_timer := 0.0

func _ready() -> void:
	add_to_group("hotel_hides")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Reaches just past the doors so the interaction ray meets it first.
	box.size = Vector3(WIDTH - 0.1, 1.9, DEPTH + 0.12)
	shape.shape = box
	shape.position = Vector3(0, 0.95, 0.06)
	add_child(shape)
	var body := MeshInstance3D.new()
	body.name = "WardrobeBody"
	body.mesh = BODY
	add_child(body)
	# Back, sides and top collide like furniture; the inside stays free.
	var frame := StaticBody3D.new()
	frame.name = "Frame"
	add_child(frame)
	for part in [[Vector3(0, HEIGHT * 0.5, -DEPTH * 0.5 + 0.02), Vector3(WIDTH, HEIGHT, 0.04)], [Vector3(-WIDTH * 0.5 + 0.02, HEIGHT * 0.5, 0), Vector3(0.04, HEIGHT, DEPTH)], [Vector3(WIDTH * 0.5 - 0.02, HEIGHT * 0.5, 0), Vector3(0.04, HEIGHT, DEPTH)], [Vector3(0, HEIGHT - 0.03, 0), Vector3(WIDTH, 0.06, DEPTH)]]:
		var collider := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = part[1]
		collider.shape = cube
		collider.position = part[0]
		frame.add_child(collider)
	for side in ["left", "right"]:
		var mirror := -1.0 if side == "left" else 1.0
		var pivot := Node3D.new()
		pivot.name = "Hinge_" + side
		pivot.position = Vector3(HINGE.x * mirror, 0, HINGE.z)
		add_child(pivot)
		var leaf := MeshInstance3D.new()
		leaf.mesh = LEAVES[side]
		pivot.add_child(leaf)
		# Leaves use the door layer: they block creature sight and movement.
		var door := StaticBody3D.new()
		door.collision_layer = 8
		door.collision_mask = 0
		var collider := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = Vector3(HINGE.x, HEIGHT - 0.35, 0.04)
		collider.shape = cube
		collider.position = Vector3(-mirror * HINGE.x * 0.5, 0.25 + (HEIGHT - 0.35) * 0.5, -0.02)
		door.add_child(collider)
		pivot.add_child(door)
		pivots[side] = pivot
		leaf_bodies[side] = door
	apply_angles()

func leaf_angle(side: String) -> float:
	return maxf(maxf(opening, wide[side]) * OPEN_ANGLE, peek[side] * PEEK_ANGLE)

## The creature pulls one leaf open; the other stays as it is.
func open_leaf(side: String, seconds := 0.35) -> void:
	if leaf_motion.has(side) and is_instance_valid(leaf_motion[side]): leaf_motion[side].kill()
	var tween := create_tween()
	tween.tween_method(func(value): wide[side] = value; apply_angles(), wide[side], 1.0, seconds).set_trans(Tween.TRANS_SINE)
	leaf_motion[side] = tween
	close_timer = 6.0

func close_leaves(seconds := 0.7) -> void:
	for side in wide:
		if leaf_motion.has(side) and is_instance_valid(leaf_motion[side]): leaf_motion[side].kill()
		var tween := create_tween()
		var which: String = side
		tween.tween_method(func(value): wide[which] = value; apply_angles(), wide[which], 0.0, seconds).set_trans(Tween.TRANS_SINE)
		leaf_motion[which] = tween

func apply_angles() -> void:
	# Left leaf swings out with a negative turn, the right one with a positive turn.
	pivots.left.rotation.y = -leaf_angle("left")
	pivots.right.rotation.y = leaf_angle("right")
	for side in leaf_bodies: leaf_bodies[side].collision_layer = SOLID if leaf_angle(side) < COLLISION_LIMIT else SIGHT_ONLY

func swing(to: float, seconds: float) -> void:
	if is_instance_valid(motion): motion.kill()
	motion = create_tween()
	motion.tween_method(func(value): opening = value; apply_angles(), opening, to, seconds).set_trans(Tween.TRANS_SINE)

func enter(player: CharacterBody3D) -> void:
	occupant = player
	peek = {"left": 0.0, "right": 0.0}
	wide = {"left": 0.0, "right": 0.0}
	peeked = false
	opening = 0.85
	apply_angles()
	swing(0.0, 0.55)

func leave() -> void:
	occupant = null
	peek = {"left": 0.0, "right": 0.0}
	swing(1.0, 0.3)
	close_timer = 1.1

## A creature that knows someone is inside pulls the doors open.
func force_open() -> void:
	if opening < 0.9:
		swing(1.0, 0.25)
		forced.emit()
	close_timer = 2.5

func set_peek(left: float, right: float) -> void:
	peek.left = clampf(left, 0.0, 1.0)
	peek.right = clampf(right, 0.0, 1.0)
	if not peeked and maxf(peek.left, peek.right) > 0.02:
		peeked = true
		peek_started.emit(to_global(Vector3(0, 1.2, HINGE.z)))
	apply_angles()

## True when a leaf is open enough for a line of sight to the occupant.
func ajar() -> bool:
	return maxf(leaf_angle("left"), leaf_angle("right")) >= COLLISION_LIMIT

func _physics_process(delta: float) -> void:
	if close_timer <= 0.0: return
	close_timer -= delta
	if close_timer <= 0.0 and not is_instance_valid(occupant):
		swing(0.0, 0.8)
		close_leaves(0.8)

func available_exit(player: CharacterBody3D) -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.05
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 8 | 4 | 32
	query.exclude = [player.get_rid()]
	var destination := to_global(exit_offset)
	query.transform = Transform3D(Basis.IDENTITY, destination + Vector3(0, 0.54, 0))
	if get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return destination
	return Vector3.INF
