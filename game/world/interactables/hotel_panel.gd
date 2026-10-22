extends Area3D
## An electrical panel on the wall of a service room: the fuse box
## (power_box_01), shut and locked (the author's word, 22 October 2026). The
## one key of the floor opens any of them, and only whoever has it can: its
## door swings out on its hinge, and the switches inside give a wing in the
## blackout its lights back. Nothing of it is needed; it is there for
## whoever finds the key. Like the pieces gone through, it is drawn by its
## room's batch while it is shut and in its parts (tools/props/
## build_catalogue.gd, MOVING) once it is open. The Area3D is only what the
## focus ray finds (layer 16).
const ROOM_LAYERS := preload("res://game/world/hotel/room_layers.gd")
## How far its door swings (radians), how long it takes, and how far in front
## of the wall the focus finds it.
const OPEN := 1.75
const SWING := 0.7
const REACH := 0.35
## Where it is drawn (hotel_geometry.place): {entry, index, parent}.
var main := {}
var opened := false
## What it is drawn with once open.
var shown: Array = []

func _ready() -> void:
	add_to_group("hotel_panels")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.6, REACH)
	shape.shape = box
	shape.position = Vector3(0, 0, REACH * 0.5)
	add_child(shape)

## Opened: its door swung out over `seconds` (none: at once, as for somebody
## coming back into a floor where it was already open).
func open(seconds: float) -> void:
	if opened: return
	opened = true
	if main.is_empty() or main.entry.get("multi") == null: return
	var entry: Dictionary = main.entry
	var base := String((entry.mesh as Mesh).resource_path).get_basename()
	var body: Mesh = load(base + "_body.res")
	var stood: Transform3D = entry.transforms[int(main.index)]
	var source: GeometryInstance3D = entry.instance
	var room: Node3D = main.parent
	(entry.multi as MultiMesh).set_instance_transform(int(main.index), Transform3D(Basis.from_scale(Vector3.ZERO), stood.origin))
	drawn(room, source, body, stood)
	for part_name in body.get_meta("parts"):
		var part: Mesh = load("%s_%s.res" % [base, part_name])
		var at := stood * Transform3D(Basis.IDENTITY, part.get_meta("pivot"))
		var node := drawn(room, source, part, at)
		# Its free edge out into the room, about the hinge.
		var box: AABB = part.get_meta("box")
		var hinge: Vector3 = part.get_meta("pivot")
		var swung := at * Transform3D(Basis(Vector3.UP, -OPEN if box.get_center().x > hinge.x else OPEN), Vector3.ZERO)
		if seconds <= 0.0:
			node.transform = swung
			continue
		create_tween().tween_property(node, "transform", swung, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## A mesh drawn on its own where the batch drew it, lit as the batch is.
func drawn(room: Node3D, source: GeometryInstance3D, mesh: Mesh, at: Transform3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Panel_" + mesh.resource_name
	node.mesh = mesh
	node.cast_shadow = source.cast_shadow
	node.gi_mode = source.gi_mode
	room.add_child(node)
	node.transform = at
	ROOM_LAYERS.put_on(node, source.layers & ROOM_LAYERS.ROOMS)
	shown.append(node)
	return node
