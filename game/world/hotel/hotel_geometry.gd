extends Node3D
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
var materials := {}
var batches := {}
var room_nodes: Array[Node3D] = []
var doors: Array = []
## Wardrobes in build order: the same index names the same wardrobe on every
## machine in an online match (doors likewise).
var hides: Array = []
var lights: Array[OmniLight3D] = []
var manifest: Dictionary
var quality := 1
var reduced := false
var dust: CPUParticles3D
var curtain_material: ShaderMaterial
var fog_volumes: Array[FogVolume] = []
var reflection_probes: Array[ReflectionProbe] = []
# Lamp lights inside furniture; visibility is managed with the rooms.
var practicals: Array[OmniLight3D] = []
# Fluorescent fixtures that flicker (never while effects are reduced).
var flickers: Array = []
## Every fluorescent batten (service rooms), steady or failing: they hum.
var tubes: Array = []
var flicker_clock := 0.0
## Red start lamps in the reception: {light, material, energy}.
var beacons: Array = []
## Share of eligible rooms (private rooms, lounges, corridors; never the
## reception, service rooms, halls or the refuge) whose ceiling lamp is out.
const DARK_SHARE := 0.2
const MATERIALS := ["plaster", "wood", "panel", "door", "trim", "linen", "fabric", "leather", "metal", "black", "green", "screen", "leaf", "ceramic", "tile", "gold", "carpet", "ceiling", "light", "shade", "mirror", "painting", "curtain"]
# Batched primitive meshes. Unit size; transforms carry the dimensions.
const SHAPES := {"box": "", "cylinder": "@cyl", "cone": "@cone"}
## Modules with wall lamps: reception, lobby, corridor, gallery.
const SCONCE_ROOMS := [0, 10, 11, 12]
const WALL_LAMP := preload("res://assets/props/wall_lamp/wall_lamp.res")
const FADE_BEGIN := 40.0
const FADE_LENGTH := 16.0
const SHADOW_FADE := 26.0

func _init() -> void:
	for key in MATERIALS:
		materials[key] = load("res://game/presentation/materials/%s.tres" % key).duplicate()
		apply_image_maps(materials[key], key)
	curtain_material = materials.curtain
	# A dead ceiling dome: same glass, no glow.
	materials["light_off"] = materials.light.duplicate()
	materials.light_off.emission_enabled = false
	materials.light_off.albedo_color = materials.light.albedo_color.darkened(0.55)

# Photographic maps dropped in assets/textures/<material>/ replace the
# procedural base automatically: albedo, normal (OpenGL) and roughness.
static func apply_image_maps(material: Material, key: String) -> void:
	if not material is ShaderMaterial: return
	for slot in [["albedo", "albedo_map", "use_albedo_map"], ["normal", "normal_map", "use_normal_map"], ["roughness", "roughness_map", "use_roughness_map"]]:
		for extension in ["png", "jpg", "jpeg", "webp"]:
			var path := "res://assets/textures/%s/%s.%s" % [key, slot[0], extension]
			if ResourceLoader.exists(path):
				material.set_shader_parameter(slot[1], load(path))
				material.set_shader_parameter(slot[2], true)
				break

# Deterministic per-position variation; never consumes generator randomness.
static func vary(value: Vector3, salt := 0) -> float:
	return fposmod(sin(value.x * 12.9898 + value.z * 78.233 + value.y * 37.719 + salt * 11.31) * 43758.5453, 1.0)

func box(parent: Node3D, pos: Vector3, size: Vector3, material: String, solid := false, form := "box", euler := Vector3.ZERO) -> void:
	# An empty material creates only the collider (detailed visuals stay separate).
	if not material.is_empty():
		var key := parent.get_instance_id()
		if not batches.has(key): batches[key] = {"parent": parent, "groups": {}}
		var groups: Dictionary = batches[key].groups
		var group: String = material + SHAPES[form]
		if not groups.has(group): groups[group] = []
		groups[group].append(Transform3D(Basis.from_euler(euler) * Basis.from_scale(size), pos))
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cube := BoxShape3D.new()
		cube.size = size
		shape.shape = cube
		body.add_child(shape)
		parent.add_child(body)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: String, euler := Vector3.ZERO) -> void:
	box(parent, pos, Vector3(radius * 2, height, radius * 2), material, false, "cylinder", euler)

static func unit_mesh(group: String) -> Mesh:
	if group.ends_with("@cyl") or group.ends_with("@cone"):
		var rounded := CylinderMesh.new()
		rounded.height = 1.0
		rounded.bottom_radius = 0.5
		rounded.top_radius = 0.28 if group.ends_with("@cone") else 0.5
		rounded.radial_segments = 20
		rounded.rings = 1
		return rounded
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	return cube

static func material_of(group: String) -> String:
	return group.get_slice("@", 0)

func flush() -> void:
	for batch in batches.values():
		for group in batch.groups:
			var transforms: Array = batch.groups[group]
			var mesh := unit_mesh(group)
			mesh.material = materials[material_of(group)]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = transforms.size()
			for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = "Mesh_" + group.replace("@", "-")
			instance.multimesh = multi
			batch.parent.add_child(instance)
	batches.clear()

func text(parent: Node3D, words: String, pos: Vector3, yaw := 0.0, size := 38) -> void:
	var label := Label3D.new()
	label.text = words
	label.position = pos
	label.rotation.y = yaw
	label.font_size = size
	label.pixel_size = 0.007
	label.modulate = Color("d3bd8e")
	label.outline_size = 0
	parent.add_child(label)

## Staged sets (opening scene, title screen), built outside the floor plan.
## A papered wall between two floor points, with doorway gaps centred at the
## given distances from its start.
func set_wall(from: Vector2, to: Vector2, gaps: Array, height := 2.9) -> void:
	var direction := to - from
	var length := direction.length()
	var boundary := Node3D.new()
	var middle := (from + to) * 0.5
	boundary.position = Vector3(middle.x, 0, middle.y)
	boundary.rotation.y = atan2(-direction.y, direction.x)
	add_child(boundary)
	var cuts: Array = gaps.duplicate()
	cuts.sort()
	var start := 0.0
	var portal: float = FLOOR.PORTAL
	for centre in cuts + [length + portal * 0.5]:
		var stop: float = minf(centre - portal * 0.5, length)
		if stop - start > 0.01:
			var x := (start + stop) * 0.5 - length * 0.5
			box(boundary, Vector3(x, height / 2, 0), Vector3(stop - start, height, 0.18), "plaster", true)
			for face in [-1, 1]:
				box(boundary, Vector3(x, 0.48, face * 0.11), Vector3(stop - start, 0.96, 0.07), "panel")
				box(boundary, Vector3(x, 0.98, face * 0.15), Vector3(stop - start, 0.05, 0.035), "trim")
				box(boundary, Vector3(x, 0.07, face * 0.155), Vector3(stop - start, 0.14, 0.03), "trim")
				box(boundary, Vector3(x, height - 0.05, face * 0.12), Vector3(stop - start, 0.1, 0.06), "trim")
		if centre < length:
			var x: float = centre - length * 0.5
			box(boundary, Vector3(x, (height + 2.65) / 2, 0), Vector3(portal, height - 2.65, 0.18), "plaster", true)
			for face in [-1, 1]:
				box(boundary, Vector3(x, 2.74, face * 0.165), Vector3(portal + 0.26, 0.14, 0.035), "trim")
				for side in [-1, 1]: box(boundary, Vector3(x + side * (portal * 0.5 + 0.06), 1.36, face * 0.165), Vector3(0.14, 2.72, 0.035), "trim")
		start = centre + portal * 0.5

## A door leaf hinged at the south edge of a doorway in a wall running along Z;
## returns its hinge. A negative turn swings it towards +X. With `yaw` the
## whole door turns for walls along other directions (PI / 2: a wall along X,
## hinged at its east edge).
func set_door(centre: Vector3, number: String, yaw := 0.0) -> Node3D:
	var width: float = FLOOR.LEAF_WIDTH
	var hinge := Node3D.new()
	hinge.position = centre + Basis(Vector3.UP, yaw) * Vector3(0, 0, width * 0.5)
	hinge.rotation.y = yaw
	add_child(hinge)
	var holder := Node3D.new()
	holder.rotation.y = PI / 2
	hinge.add_child(holder)
	var leaf := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 2.58, 0.07)
	mesh.material = materials.door
	leaf.mesh = mesh
	leaf.position = Vector3(width * 0.5, 1.29, 0)
	holder.add_child(leaf)
	for face in [-1, 1]: box(holder, Vector3(width - 0.14, 1.08, face * 0.07), Vector3(0.14, 0.04, 0.05), "gold")
	if not number.is_empty():
		text(holder, number, Vector3(width * 0.5, 1.94, 0.045), 0, 24)
		text(holder, number, Vector3(width * 0.5, 1.94, -0.045), PI, 24)
	return hinge

func build(data: Dictionary) -> void:
	manifest = data
	for room in data.rooms:
		var node := Node3D.new()
		node.name = "Room_%d_%s" % [room.id, FLOOR.TYPES[room.type]]
		node.position = FLOOR.position_of(room)
		add_child(node)
		room_nodes.append(node)
		build_room(node, room)
	for edge in data.edges:
		var a: Dictionary = data.rooms[edge[0]]
		var b: Dictionary = data.rooms[edge[1]]
		# One door per connection, with a physical leaf and a stable identifier.
		if data.get("merged", []).has(edge): continue
		var center := FLOOR.portal_between(a, b)
		var yaw := PI / 2 if a.x != b.x else 0.0
		var door = DOOR.new()
		door.name = "Door_%d_%d" % [a.id, b.id]
		door.collision_layer = 8
		door.collision_mask = 4
		var half := FLOOR.LEAF_WIDTH * 0.5
		door.position = center + Basis(Vector3.UP, yaw) * Vector3(-half, 0, 0)
		door.rotation.y = yaw
		door.closed_rotation = yaw
		door.doorway = center
		add_child(door)
		var leaf := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(FLOOR.LEAF_WIDTH, 2.58, 0.07)
		mesh.material = materials.door
		leaf.mesh = mesh
		leaf.position = Vector3(half, 1.29, 0)
		door.add_child(leaf)
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cube := BoxShape3D.new()
		cube.size = mesh.size
		shape.shape = cube
		shape.position = leaf.position
		door.add_child(shape)
		for face in [-1, 1]: box(door, Vector3(FLOOR.LEAF_WIDTH - 0.14, 1.08, face * 0.07), Vector3(0.14, 0.04, 0.05), "gold")
		# Each face shows the number of the room behind the door, as seen from
		# the room that face looks into.
		var b_side := signf((FLOOR.position_of(b) - center).dot(Basis(Vector3.UP, yaw).z))
		text(door, str(100 + int(a.id)), Vector3(half, 1.94, 0.045 * b_side), 0.0 if b_side > 0 else PI, 24)
		text(door, str(100 + int(b.id)), Vector3(half, 1.94, -0.045 * b_side), PI if b_side > 0 else 0.0, 24)
		if int(a.id + b.id) % 3 != 0: door.open_immediately()
		doors.append(door)
	flush()
	build_navigation()
	build_dust()

func build_room(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	box(node, Vector3(0, -0.15, 0), Vector3(span.x, 0.3, span.y), "tile" if room.type in FLOOR.HARD_FLOORS else "carpet", true)
	box(node, Vector3(0, height + 0.1, 0), Vector3(span.x, 0.2, span.y), "ceiling", true)
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: int = room.id + direction.x + direction.y * int(manifest.width)
		var connected: bool = manifest.adjacency[room.id].has(neighbor) and (direction.y != 0 or abs(int(room.x) - neighbor % int(manifest.width)) == 1)
		var edge := [mini(room.id, neighbor), maxi(room.id, neighbor)]
		if connected and manifest.get("merged", []).has(edge): continue
		var length: float = span.y if direction.x != 0 else span.x
		var boundary := Node3D.new()
		boundary.name = "Wall_%s_%s" % [direction.x, direction.y]
		boundary.position = Vector3(direction.x * span.x * 0.5, 0, direction.y * span.y * 0.5)
		boundary.rotation.y = PI / 2 if direction.x != 0 else 0.0
		node.add_child(boundary)
		# Local face pointing into this room; a neighbour may have another height.
		var inner: int = -(direction.x + direction.y)
		if connected:
			for side in [-1, 1]:
				wall_run(boundary, side * (length + FLOOR.PORTAL) * 0.25, (length - FLOOR.PORTAL) * 0.5, height, inner)
				box(boundary, Vector3(side * (FLOOR.PORTAL * 0.5 + 0.03), 1.35, 0), Vector3(0.06, 2.7, 0.3), "trim")
				# Door casing proud of both wall faces.
				for face in [-1, 1]: box(boundary, Vector3(side * (FLOOR.PORTAL * 0.5 + 0.06), 1.36, face * 0.165), Vector3(0.14, 2.72, 0.035), "trim")
			box(boundary, Vector3(0, (height + 2.65) / 2, 0), Vector3(FLOOR.PORTAL, height - 2.65, 0.18), "plaster", true)
			box(boundary, Vector3(0, 2.65, 0), Vector3(FLOOR.PORTAL + 0.2, 0.12, 0.3), "trim")
			for face in [-1, 1]:
				box(boundary, Vector3(0, 2.74, face * 0.165), Vector3(FLOOR.PORTAL + 0.26, 0.14, 0.035), "trim")
			box(boundary, Vector3(0, height - 0.05, inner * 0.12), Vector3(FLOOR.PORTAL, 0.1, 0.06), "trim")
		else:
			wall_run(boundary, 0.0, length, height, inner)
		for side in [-1, 1]:
			# Framed hotel art; each canvas composition varies with its position.
			box(boundary, Vector3(side * 3.5, 2.02, -0.16), Vector3(1.28, 0.92, 0.08), "gold" if int(room.variant) % 2 == 0 else "trim")
			box(boundary, Vector3(side * 3.5, 2.02, -0.205), Vector3(1.14, 0.78, 0.02), "painting")
			# Public spaces: a pair of cloth-shaded wall lamps beside each print.
			if room.type in SCONCE_ROOMS and length > 9.0:
				for flank in [-1, 1]:
					var sconce := MeshInstance3D.new()
					sconce.mesh = WALL_LAMP
					sconce.position = Vector3(side * 3.5 + flank * 0.98, 1.6, -0.09)
					sconce.rotation.y = PI
					boundary.add_child(sconce)
	for prop in room.props:
		var furniture := Node3D.new()
		furniture.name = "Prop_%d_%s" % [prop.slot, prop.kind]
		furniture.transform = prop_transform(room, prop)
		node.add_child(furniture)
		build_prop(furniture, prop.kind)
	if room.type in [1, 2, 3, 4, 7, 15, 16]:
		# Domestic alcoves interrupt the square footprint while preserving portals.
		for side in [-1, 1]:
			for end in [-1, 1]:
				if room.get("layout", 0) == 1 and side > 0: continue
				if room.get("layout", 0) == 2 and end > 0: continue
				if room.get("layout", 0) == 3 and side != end: continue
				box(node, Vector3(side * 4.4, height / 2, end * 2.8), Vector3(3.2, height, 0.12), "plaster", true)
				for z in [3.2, 5.6]:
					box(node, Vector3(side * 2.8, height / 2, end * z), Vector3(0.12, height, 0.8), "plaster", true)
				box(node, Vector3(side * 2.8, (height + 2.55) / 2, end * 4.4), Vector3(0.12, height - 2.55, 1.6), "plaster", true)
	# Wardrobes only in room-like modules (see FLOOR.WARDROBES), against the walls.
	if room.type != 19:
		for corner in FLOOR.hiding_positions(room):
			var hide := preload("res://game/world/interactables/hiding_place.gd").new()
			hide.name = "Wardrobe_%d" % node.get_child_count()
			hide.position = corner
			hide.rotation.y = FLOOR.hiding_yaw(corner)
			hides.append(hide)
			# The wardrobe builds its own model, frame colliders and door leaves.
			node.add_child(hide)
	# Central sightlines remain open; booths sit against the perimeter.
	var service: bool = room.type in [4, 7, 8, 9]
	var light := OmniLight3D.new()
	var failing := service and vary(node.position, 3) < 0.35
	if service:
		# Fluorescent batten: cold, even, occasionally failing.
		var tube := "light"
		if failing:
			tube = "tube_%d" % flickers.size()
			materials[tube] = materials.light.duplicate()
			materials[tube].emission = Color("d8f0dc")
		box(node, Vector3(0, height - 0.04, 0), Vector3(1.5, 0.08, 0.32), "metal")
		for z in [-0.08, 0.08]: box(node, Vector3(0, height - 0.11, z), Vector3(0.05, 1.38, 0.05), tube, false, "cylinder", Vector3(0, 0, PI / 2))
		light.light_color = Color("d4e3d2")
		light.light_energy = 3.4
		light.position = Vector3(0, height - 0.35, 0)
	else:
		# Frosted dome in a brass ring: warm pool with darker corners.
		cylinder(node, Vector3(0, height - 0.03, 0), 0.26, 0.06, "gold")
		box(node, Vector3(0, height - 0.13, 0), Vector3(0.46, 0.16, 0.46), "light_off" if dark_room(room) else "light", false, "cone", Vector3(PI, 0, 0))
		light.light_color = Color("ffcf94")
		light.light_energy = 3.6
		light.position = Vector3(0, height - 0.45, 0)
	light.omni_range = maxf(10.0, maxf(span.x, span.y) * 0.85)
	light.omni_attenuation = 1.25
	light.light_size = 0.12
	light.light_specular = 0.45 if service else 0.6
	light.shadow_enabled = true
	# Small biases so thin shelves and trays still block light and glints.
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 0.6
	# Lights and shadows fade with distance instead of switching on abruptly.
	# Shadows stay on wherever a light can reach visible rooms, so light never
	# passes through walls.
	light.distance_fade_enabled = true
	light.distance_fade_begin = FADE_BEGIN
	light.distance_fade_length = FADE_LENGTH
	light.distance_fade_shadow = SHADOW_FADE
	node.add_child(light)
	lights.append(light)
	# Some rooms have their lamp out: only torches and the doorways light them.
	if dark_room(room):
		light.set_meta("off", true)
		light.visible = false
	if service: tubes.append({"light": light, "energy": light.light_energy})
	if failing:
		flickers.append({"light": light, "energy": light.light_energy, "phase": vary(node.position, 9) * 50.0, "material": materials["tube_%d" % flickers.size()], "glow": materials.light.emission_energy_multiplier})
	if room.hall == room.id and room.hall >= 0:
		if RenderingServer.get_current_rendering_method() == "forward_plus":
			var fog := FogVolume.new()
			fog.size = Vector3(span.x * 0.65, 0.7, span.y * 0.65)
			fog.position.y = 0.45
			var fog_mat := FogMaterial.new()
			fog_mat.density = 0.025
			fog_mat.albedo = Color("81775f")
			fog.material = fog_mat
			node.add_child(fog)
			fog_volumes.append(fog)
		if int(room.id) % 3 == 0:
			var probe := ReflectionProbe.new()
			probe.position.y = 1.8
			probe.size = Vector3(span.x, height, span.y)
			probe.interior = true
			probe.intensity = 0.35
			probe.max_distance = 25
			node.add_child(probe)
			reflection_probes.append(probe)
	if room.type == 0:
		# Where the night started: a red emergency lamp blinking over the
		# reception, the one landmark to find the way back by.
		box(node, Vector3(0, height - 0.12, 0), Vector3(0.36, 0.12, 0.2), "metal")
		var beacon_glass := StandardMaterial3D.new()
		beacon_glass.albedo_color = Color(0.5, 0.02, 0.02)
		beacon_glass.emission_enabled = true
		beacon_glass.emission = Color(1.0, 0.08, 0.04)
		beacon_glass.emission_energy_multiplier = 4.0
		var lens := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = 0.11
		dome.height = 0.14
		dome.material = beacon_glass
		lens.mesh = dome
		lens.position = Vector3(0, height - 0.22, 0)
		node.add_child(lens)
		var beacon := OmniLight3D.new()
		beacon.name = "StartBeacon"
		beacon.position = Vector3(0, height - 0.45, 0)
		beacon.light_color = Color(1.0, 0.1, 0.06)
		beacon.light_energy = 3.2
		beacon.omni_range = 10.0
		# The usual warm ceiling light is kept low so the red reads from afar.
		light.light_energy *= 0.3
		beacon.shadow_enabled = true
		node.add_child(beacon)
		beacons.append({"light": beacon, "material": beacon_glass, "energy": beacon.light_energy})
	if room.type == 19:
		text(node, "SALIDA\nREFUGIO", Vector3(0, 2.25, -2.5), 0, 40)
		text(node, "SALIDA / REFUGIO", Vector3(0, 2.65, 4.8), PI, 35)
		light.light_color = Color("b8d4b6")

# One straight wall segment centred at x along the boundary: plaster core,
# panelled wainscot, chair rail and skirting on both faces; cornice inside only.
## Furniture socket in room space: corners, set further in and smaller in
## domestic rooms, turned by the recipe.
static func prop_transform(room: Dictionary, prop: Dictionary) -> Transform3D:
	var domestic: bool = room.type in [1, 2, 3, 4, 7, 15, 16]
	var corner := 4.35 if domestic else 3.95
	var basis := Basis(Vector3.UP, prop.rotation * PI / 2).scaled(Vector3.ONE * (0.85 if domestic else 1.0))
	return Transform3D(basis, Vector3(-corner if prop.slot % 2 == 0 else corner, 0, -corner if prop.slot < 2 else corner))

func wall_run(boundary: Node3D, x: float, length: float, height: float, inner: int) -> void:
	box(boundary, Vector3(x, height / 2, 0), Vector3(length, height, 0.18), "plaster", true)
	for face in [-1, 1]:
		box(boundary, Vector3(x, 0.48, face * 0.11), Vector3(length, 0.96, 0.07), "panel")
		box(boundary, Vector3(x, 0.98, face * 0.15), Vector3(length, 0.05, 0.035), "trim")
		box(boundary, Vector3(x, 0.07, face * 0.155), Vector3(length, 0.14, 0.03), "trim")
	box(boundary, Vector3(x, height - 0.05, inner * 0.12), Vector3(length, 0.1, 0.06), "trim")
	box(boundary, Vector3(x, height - 0.13, inner * 0.1), Vector3(length, 0.06, 0.03), "trim")

# A lamp that really lights its surroundings (no shadows, culled by distance).
func practical(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 2.2
	lamp.light_size = 0.2
	lamp.light_specular = 0.25
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 18.0
	lamp.distance_fade_length = 8.0
	lamp.distance_fade_shadow = 14.0
	parent.add_child(lamp)
	practicals.append(lamp)

func _process(delta: float) -> void:
	flicker_clock += delta
	for beacon in beacons:
		# A slow emergency blink with a nervous stutter in each lit phase.
		var t: float = fposmod(flicker_clock, 1.6)
		var on := 1.0 if t < 0.8 else 0.0
		if on > 0.0 and not reduced: on *= 0.75 + 0.25 * sign(sin(flicker_clock * 37.0))
		beacon.light.light_energy = beacon.energy * (0.08 + 0.92 * on)
		beacon.material.emission_energy_multiplier = 0.4 + 3.6 * on
	if flickers.is_empty(): return
	for entry in flickers:
		var lamp: OmniLight3D = entry.light
		if not lamp.visible: continue
		var level := 1.0
		if not reduced:
			# Mostly steady, with short irregular dropouts and a faint hum.
			var t: float = flicker_clock + entry.phase
			var burst := fposmod(t, 7.3) < 0.45
			var chatter := sin(t * 71.0) * sin(t * 23.0)
			level = 0.95 + sin(t * 314.0) * 0.02
			if burst: level = 0.25 if chatter > 0.1 else 1.0
		lamp.light_energy = entry.energy * level
		entry.material.emission_energy_multiplier = entry.glow * level

func build_prop(node: Node3D, kind: String) -> void:
	preload("res://game/world/hotel/prop_factory.gd").build(self, node, kind)

func build_navigation() -> void:
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.agent_radius = 0.4
	nav.agent_height = 1.8
	nav.agent_max_climb = 0.1
	nav.cell_size = 0.2
	nav.cell_height = 0.1
	nav.filter_baking_aabb = AABB(Vector3(-12, -0.5, -12), Vector3(300, 3, 300))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, self)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nav
	add_child(region)

## Whether this room's ceiling lamp is out (deterministic per position).
static func dark_room(room: Dictionary) -> bool:
	if int(room.type) in [0, 4, 7, 8, 9, 19] or int(room.get("hall", -1)) >= 0: return false
	return vary(FLOOR.position_of(room), 7) < DARK_SHARE

func add_nav_quad(vertices: PackedVector3Array, polygons: Array[PackedInt32Array], center: Vector3, low: Vector2, high: Vector2) -> void:
	var first := vertices.size()
	vertices.append_array(PackedVector3Array([center + Vector3(low.x, 0.04, low.y), center + Vector3(low.x, 0.04, high.y), center + Vector3(high.x, 0.04, high.y), center + Vector3(high.x, 0.04, low.y)]))
	polygons.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))

func update_visibility(player_position: Vector3, shadows: bool) -> void:
	curtain_material.set_shader_parameter("motion", 0.0 if reduced else 1.0)
	if is_instance_valid(dust):
		dust.position = player_position + Vector3(0, 1.2, 0)
		dust.emitting = quality > 0 and not reduced
		dust.visible = quality > 0 and not reduced
	for fog in fog_volumes: fog.visible = quality == 2 and not reduced and RenderingServer.get_current_rendering_method() == "forward_plus"
	for probe in reflection_probes: probe.visible = quality > 0
	for i in room_nodes.size():
		var distance := room_nodes[i].position.distance_to(player_position)
		room_nodes[i].visible = distance < (42.0 if quality == 0 else 66.0)
		lights[i].visible = distance < FADE_BEGIN + FADE_LENGTH + 4.0 and not lights[i].has_meta("off")
		lights[i].shadow_enabled = shadows
	for lamp in practicals:
		lamp.visible = quality > 0 and lamp.global_position.distance_to(player_position) < 28.0
		lamp.shadow_enabled = shadows
	for door in doors: door.visible = door.doorway.distance_to(player_position) < 66.0

func build_dust() -> void:
	dust = CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 10
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(6, 1.2, 6)
	dust.direction = Vector3(1, 0.15, 0.3)
	dust.spread = 30
	dust.initial_velocity_min = 0.03
	dust.initial_velocity_max = 0.09
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.006
	dust.scale_amount_max = 0.017
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.73, 0.55, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = false
	mesh.material = mat
	dust.mesh = mesh
	add_child(dust)
