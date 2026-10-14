extends Area3D
## Wardrobe hiding place. Whoever is inside stands behind both doors shut,
## an eye to the crack between them (`slit`); holding forward eases the doors
## ajar. Each leaf opens on its own: looking to one side opens the opposite
## leaf and shuts the near one, and the head, which stays inside, moves over
## to look out between them. Closed doors block sight like a wall (the crack
## is in what is drawn, not in what blocks: nothing sees in through it); a
## door left ajar lets a creature see who is inside. The Area3D itself is
## only the interaction target.
##
## There are two. The small one (a model: wardrobe_body and its leaves) takes
## one person. The big one (`big`: the double wardrobe prop_factory builds out
## of boards, 2.2 m wide, its carcass still its own) takes two, side by side,
## each behind a leaf. Everything below is the same for both, by `capacity`.
const BODY := preload("res://assets/props/wardrobe/wardrobe_body.res")
const LEAVES := {"left": preload("res://assets/props/wardrobe/wardrobe_leaf_left.res"), "right": preload("res://assets/props/wardrobe/wardrobe_leaf_right.res")}
## The small wardrobe: hinge of the right leaf in wardrobe space (the left one
## mirrors X), and its size.
const HINGE := Vector3(0.615, 0.0, 0.38)
const WIDTH := 1.25
const HEIGHT := 2.3
const DEPTH := 0.78
## The big one, as prop_factory builds it (before `scale_by`): its doors hang
## from the inside of its side boards and stand BIG_FRONT out from its middle.
const BIG_SIZE := Vector3(2.2, 2.45, 0.9)
const BIG_HINGE := Vector3(0.99, 0.0, 0.46)
const BIG_LEAF_THICK := 0.09
## Its bottom board's top, which is what whoever is inside stands on.
const BIG_FLOOR := 0.15
## How far either side of the middle its two places are.
const BIG_PLACE := 0.45
## Door angles (radians): fully open, a leaf ajar at maximum peek, and both
## leaves as far as they are eased open by somebody leaving quietly.
## PEEK_ANGLE was 1.05, sixty degrees, and the head leant out past the doors:
## looking aside from a wardrobe showed the whole room, as from a doorway.
## Now it is a gap to look through, with wood on both sides of it.
const OPEN_ANGLE := 1.75
const PEEK_ANGLE := 0.75
const EASE_ANGLE := 1.3
## How far each leaf opens of that, looking straight ahead.
const PEEK_AHEAD := 0.8
## The crack between the big wardrobe's two boards (the small one's is cut
## into its model: tools/props/build_wardrobe.gd, SLIT).
const BIG_SLIT := 0.015
## Getting in and out is a movement (hotel_player.transit): how long the body
## takes to step in and to step out, and how long the key is held to leave
## without the bang of the doors (heard NOISE.QUIET of the way).
const ENTER_TIME := 0.5
const LEAVE_TIME := 0.34
const QUIET_EXIT := 3.0
const QUIET_LEAVE_TIME := 0.6
## Doors wider than this stop blocking movement so they never shove anyone.
## They go on hiding what is behind them, like a door mid-swing: layer 64,
## which sight looks for and bodies do not. Turned off altogether, the wood
## still in front of somebody peeking stopped hiding them, and a creature saw
## straight through a leaf open 24 degrees. (0.3 while a leaf opened to
## 1.05: brought down with PEEK_ANGLE, so that the doors give somebody away
## from about as far through the peek as they did -- ajar().)
const COLLISION_LIMIT := 0.25
const SOLID := 8
const SIGHT_ONLY := 64
## What keeps anybody from walking in (`plug`): solid for survivors only, like
## an open door's leaf (hotel_door.gd OPEN_SOLID). Sight does not look for it.
const SURVIVORS_ONLY := 128
signal peek_started(point: Vector3)
## The creature pulled the doors open (online, the host relays it).
signal forced
## Set before it enters the tree: the big wardrobe, how much smaller than
## built it stands (0.85 in the rooms with alcoves) and the hotel's materials
## for its leaves (hotel_geometry.materials).
var big := false
var scale_by := 1.0
var materials := {}
## This wardrobe's own size and right hinge, and how many it takes.
var width := WIDTH
var height := HEIGHT
var depth := DEPTH
var hinge := HINGE
var capacity := 1
## The crack between the shut leaves, in wardrobe space: where its middle is
## across (x) and how far out its inner mouth (z). Whoever is inside rests an
## eye behind it (hotel_player.gd, CRACK_BACK).
var slit := Vector3.ZERO
## Who is inside, in the order they got in, and which place each has.
var occupants: Array = []
var places := {}
## The first of them: for whoever only asks whether somebody is in there.
var occupant: CharacterBody3D:
	get:
		for body in occupants:
			if is_instance_valid(body): return body
		return null
## Where somebody steps out, and where they stand inside (local space): the
## first place's. exit_of() and inside_of() say each occupant's own.
var exit_offset := Vector3(0, 0.04, 1.15)
var inside_offset := Vector3(0, 0.04, -0.02)
## 0 closed .. 1 wide open (entering, leaving, forced); peek is separate.
var opening := 0.0
## Per leaf, 0..1, named in wardrobe space: "left" is the leaf at -X, which is
## on the right hand of someone standing inside. The most anybody inside asks
## of each (`peeks`: by occupant).
var peek := {"left": 0.0, "right": 0.0}
var peeks := {}
## How far somebody inside has eased both leaves open on their way out, 0 to
## 1: by occupant, and the most of them.
var eases := {}
var ease := 0.0
## Only the first time the doors part during a stay makes a sound.
var peeked := false
var pivots := {}
var leaf_bodies := {}
var motion: Tween
## The doors were pulled open on somebody: they stay open while they are in.
var pulled := false
## Somebody was taken out of it and let fall in its mouth (executions.gd):
## the doors stay open on the body, and nobody gets in over it.
var held_open := false
## Fills the inside for anybody on foot. Nobody walks into a wardrobe: one
## gets in by asking, and is put inside. Without it, a leaf ajar -- which
## stops being solid so as not to shove anyone -- left the way in open, and
## while somebody inside leaned out to look, another walked in beside them,
## past how many it takes and behind doors the creature cannot see through
## (the old bug of the peeking doors). Off only while a body this machine
## moves is inside: it would be pushed out of its own hiding place.
var plug: CollisionShape3D
## Seconds until the doors swing shut by themselves. Setting it wakes the
## wardrobe up to count them (_physics_process).
var close_timer := 0.0:
	set(value):
		close_timer = value
		if value > 0.0: set_physics_process(true)

## How far the model stands off the floor (metres).
const STAND := 0.004

static var big_leaves := {}

func _ready() -> void:
	add_to_group("hotel_hides")
	collision_layer = 16
	collision_mask = 0
	if big:
		width = BIG_SIZE.x * scale_by
		height = BIG_SIZE.y * scale_by
		depth = BIG_SIZE.z * scale_by
		hinge = BIG_HINGE * scale_by
		capacity = 2
		inside_offset = Vector3(-BIG_PLACE * scale_by, BIG_FLOOR * scale_by + 0.04, -0.02)
		exit_offset = Vector3(-BIG_PLACE * scale_by, 0.04, hinge.z + 0.78)
		slit = Vector3(0.0, 0.0, hinge.z - BIG_LEAF_THICK * scale_by * 0.5)
	else:
		var cut: Vector3 = LEAVES.left.get_meta("slit", Vector3(0.0, 0.0, hinge.z - 0.04))
		slit = Vector3(cut.x, 0.0, cut.z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Reaches just past the doors so the interaction ray meets it first.
	box.size = Vector3(width - 0.1, 1.9, depth + 0.12)
	shape.shape = box
	shape.position = Vector3(0, 0.95, 0.06)
	add_child(shape)
	if not big:
		var body := MeshInstance3D.new()
		body.name = "WardrobeBody"
		body.mesh = BODY
		# Off the floor by a hair: the wardrobe is drawn from both sides (so the
		# inside of its doors shows), and its underside, in the plane of the
		# carpet, flickered into it wherever one looked in at its floor.
		body.position.y = STAND
		add_child(body)
		# Back, sides and top collide like furniture; the inside stays free.
		# (The big one's carcass is prop_factory's, boards and colliders.)
		var frame := StaticBody3D.new()
		frame.name = "Frame"
		add_child(frame)
		for part in [[Vector3(0, HEIGHT * 0.5, -DEPTH * 0.5 + 0.02), Vector3(WIDTH, HEIGHT, 0.04)], [Vector3(-WIDTH * 0.5 + 0.02, HEIGHT * 0.5, 0), Vector3(0.04, HEIGHT, DEPTH)], [Vector3(WIDTH * 0.5 - 0.02, HEIGHT * 0.5, 0), Vector3(0.04, HEIGHT, DEPTH)], [Vector3(0, HEIGHT - 0.02, 0), Vector3(WIDTH, 0.04, DEPTH)]]:
			var collider := CollisionShape3D.new()
			var cube := BoxShape3D.new()
			cube.size = part[1]
			collider.shape = cube
			collider.position = part[0]
			frame.add_child(collider)
	var stopper := StaticBody3D.new()
	stopper.name = "Plug"
	stopper.collision_layer = SURVIVORS_ONLY
	stopper.collision_mask = 0
	plug = CollisionShape3D.new()
	var filling := BoxShape3D.new()
	# From the back to just behind the shut doors, short of the sides.
	filling.size = Vector3(width - 0.2, height - 0.3, hinge.z + depth * 0.5 - 0.12)
	plug.shape = filling
	plug.position = Vector3(0, height * 0.5, (hinge.z - depth * 0.5) * 0.5 - 0.02)
	stopper.add_child(plug)
	add_child(stopper)
	for side in ["left", "right"]:
		var mirror := -1.0 if side == "left" else 1.0
		var pivot := Node3D.new()
		pivot.name = "Hinge_" + side
		pivot.position = Vector3(hinge.x * mirror, STAND, hinge.z)
		add_child(pivot)
		var leaf := MeshInstance3D.new()
		leaf.mesh = big_leaf(side, scale_by) if big else LEAVES[side]
		if big:
			for surface in BIG_LEAF_MATERIALS.size():
				if materials.has(BIG_LEAF_MATERIALS[surface]): leaf.set_surface_override_material(surface, materials[BIG_LEAF_MATERIALS[surface]])
		pivot.add_child(leaf)
		# Leaves use the door layer: they block creature sight and movement.
		var door := StaticBody3D.new()
		door.collision_layer = 8
		door.collision_mask = 0
		var collider := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = Vector3(hinge.x, height - 0.35, 0.04)
		collider.shape = cube
		collider.position = Vector3(-mirror * hinge.x * 0.5, 0.25 + (height - 0.35) * 0.5, -0.02)
		door.add_child(collider)
		pivot.add_child(door)
		pivots[side] = pivot
		leaf_bodies[side] = door
	apply_angles()

## The big wardrobe's leaves: a board, two panels on it and a brass pull, as
## prop_factory drew its doors when they did not open -- one mesh a side and
## a size, hung from its hinge (the right one runs towards -X from it).
const BIG_LEAF_MATERIALS := ["wood_leaf", "panel_leaf", "gold"]
static func big_leaf(side: String, s: float) -> ArrayMesh:
	var key := "%s:%.3f" % [side, s]
	if big_leaves.has(key): return big_leaves[key]
	var mirror := -1.0 if side == "left" else 1.0
	var tall: float = BIG_SIZE.y * s
	var mesh := ArrayMesh.new()
	# Short of the middle by half the crack (BIG_SLIT).
	var wide: float = BIG_HINGE.x * s - BIG_SLIT * 0.5
	var board := BoxMesh.new()
	board.size = Vector3(wide, (BIG_SIZE.y - 0.12) * s, BIG_LEAF_THICK * s)
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.append_from(board, 0, Transform3D(Basis.IDENTITY, Vector3(-mirror * wide * 0.5, tall * 0.5, 0)))
	wood.commit(mesh)
	var panels := SurfaceTool.new()
	panels.begin(Mesh.PRIMITIVE_TRIANGLES)
	for at in [[0.65, 0.9], [1.75, 0.8]]:
		var panel := BoxMesh.new()
		panel.size = Vector3(0.7, at[1], 0.015) * s
		panels.append_from(panel, 0, Transform3D(Basis.IDENTITY, Vector3(-mirror * 0.485, at[0], 0.05) * s))
	panels.commit(mesh)
	var pull := CylinderMesh.new()
	pull.top_radius = 0.018 * s
	pull.bottom_radius = 0.018 * s
	pull.height = 0.22 * s
	pull.radial_segments = 12
	pull.rings = 1
	var brass := SurfaceTool.new()
	brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	brass.append_from(pull, 0, Transform3D(Basis.IDENTITY, Vector3(-mirror * 0.91, 1.2, 0.07) * s))
	brass.commit(mesh)
	big_leaves[key] = mesh
	return mesh

func has_room() -> bool:
	tidy()
	return occupants.size() < capacity and not held_open

func holds(body: Node) -> bool:
	return body != null and occupants.has(body)

## Whoever has gone without leaving (freed with the floor) is not inside.
func tidy() -> void:
	for body in occupants.duplicate():
		if not is_instance_valid(body): forget(body)

func forget(body: Variant) -> void:
	occupants.erase(body)
	places.erase(body)
	peeks.erase(body)
	eases.erase(body)
	sum_eases()

## Which place somebody has, or would be given: the first one free.
func place_of(body: Node) -> int:
	if places.has(body): return places[body]
	for place in capacity:
		if not place in places.values(): return place
	return 0

## Where somebody stands inside and where they step out, in wardrobe space:
## side by side in the big one, each before their own leaf.
func inside_of(body: Node) -> Vector3:
	return Vector3(-inside_offset.x if place_of(body) == 1 else inside_offset.x, inside_offset.y, inside_offset.z)

func exit_of(body: Node) -> Vector3:
	return Vector3(-exit_offset.x if place_of(body) == 1 else exit_offset.x, exit_offset.y, exit_offset.z)

## Off while a body this machine moves is inside (plug).
func set_plug() -> void:
	var moved_here := false
	for body in occupants:
		if is_instance_valid(body) and body is CollisionObject3D and (body as CollisionObject3D).collision_mask & SURVIVORS_ONLY != 0: moved_here = true
	plug.set_deferred("disabled", moved_here)
	# At once as well when it goes off: whoever comes in is put inside this
	# same frame, and must not be met by it.
	if moved_here: plug.disabled = true

func leaf_angle(side: String) -> float:
	return maxf(maxf(opening * OPEN_ANGLE, peek[side] * PEEK_ANGLE), ease * EASE_ANGLE)

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
	tidy()
	if not occupants.has(player):
		places[player] = place_of(player)
		occupants.append(player)
	peeks.erase(player)
	sum_peeks()
	peeked = false
	pulled = false
	set_plug()
	# The doors are pulled open, stay open while the body steps in, and shut
	# behind it.
	if is_instance_valid(motion): motion.kill()
	motion = create_tween()
	motion.tween_method(func(value): opening = value; apply_angles(), opening, 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	motion.tween_interval(maxf(0.0, ENTER_TIME - 0.2))
	motion.tween_method(func(value): opening = value; apply_angles(), 1.0, 0.0, 0.45).set_trans(Tween.TRANS_SINE)

## One of them leaves (nobody named: everybody, as when a floor is reset).
func leave(player: Node = null) -> void:
	if player == null:
		for body in occupants.duplicate(): forget(body)
	else: forget(player)
	tidy()
	sum_peeks()
	# Pulled open on two, and one dragged out: they stay open on the other.
	pulled = pulled and not occupants.is_empty()
	set_plug()
	swing(1.0, 0.16)
	close_timer = 1.1

## A creature that knows someone is inside pulls the doors open (or, done
## waiting for them, throws them open: `seconds`).
func force_open(seconds := 0.25) -> void:
	if opening < 0.9:
		swing(1.0, seconds)
		forced.emit()
	pulled = true
	close_timer = 2.5

## Wide open and left so, until release_open().
func hold_open() -> void:
	held_open = true
	if opening < 0.99: swing(1.0, 0.2)

func release_open() -> void:
	if not held_open: return
	held_open = false
	pulled = pulled and is_instance_valid(occupant)
	close_timer = 0.6

## What one of those inside asks of each leaf; a leaf opens as far as whoever
## asks most of it.
func set_peek(left: float, right: float, who: Node = null) -> void:
	peeks[who] = [clampf(left, 0.0, 1.0), clampf(right, 0.0, 1.0)]
	sum_peeks()
	if not peeked and maxf(peek.left, peek.right) > 0.02:
		peeked = true
		peek_started.emit(to_global(Vector3(0, 1.2, hinge.z)))
	apply_angles()

func sum_peeks() -> void:
	peek = {"left": 0.0, "right": 0.0}
	for who in peeks:
		peek.left = maxf(peek.left, peeks[who][0])
		peek.right = maxf(peek.right, peeks[who][1])

## Somebody inside easing both doors open to leave without a sound, this far
## (0 lets them fall shut again). No creak is counted for it, as there is for
## a peek: what it costs is heard once, when they are out.
func set_ease(amount: float, who: Node = null) -> void:
	if amount <= 0.0: eases.erase(who)
	else: eases[who] = clampf(amount, 0.0, 1.0)
	sum_eases()
	apply_angles()

func sum_eases() -> void:
	ease = 0.0
	for who in eases: ease = maxf(ease, float(eases[who]))

## What one of those inside asks of the leaves, itself: [left, right].
func peek_of(who: Node) -> Array:
	return peeks.get(who, [0.0, 0.0])

## True when a leaf is open enough for a line of sight to whoever is inside.
func ajar() -> bool:
	return maxf(leaf_angle("left"), leaf_angle("right")) >= COLLISION_LIMIT

## Asleep with nothing to count down, like the doors (hotel_door.gd): there
## are three hundred wardrobes on a floor.
func _physics_process(delta: float) -> void:
	if close_timer <= 0.0:
		set_physics_process(false)
		return
	close_timer -= delta
	# Shut again once the time is up, unless they were pulled open on
	# somebody who is still in there: one of two leaving shuts them on the
	# other.
	if close_timer <= 0.0 and not held_open and not (pulled and is_instance_valid(occupant)):
		swing(0.0, 0.8)

func available_exit(player: CharacterBody3D) -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.05
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 8 | 4 | 32
	query.exclude = [player.get_rid()]
	var destination := to_global(exit_of(player))
	query.transform = Transform3D(Basis.IDENTITY, destination + Vector3(0, 0.54, 0))
	if get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return destination
	return Vector3.INF
