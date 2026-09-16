extends Node3D
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
var materials := {}
var batches := {}
var room_nodes: Array[Node3D] = []
var doors: Array = []
var lights: Array[OmniLight3D] = []
var manifest: Dictionary
var quality := 1
var reduced := false
var dust: CPUParticles3D
var curtain_material: ShaderMaterial
var fog_volumes: Array[FogVolume] = []
var reflection_probes: Array[ReflectionProbe] = []

func _init() -> void:
	materials = {
		"plaster": preload("res://game/presentation/materials/plaster.tres").duplicate(),
		"wood": preload("res://game/presentation/materials/wood.tres").duplicate(),
		"trim": preload("res://game/presentation/materials/trim.tres").duplicate(),
		"linen": preload("res://game/presentation/materials/linen.tres").duplicate(),
		"fabric": preload("res://game/presentation/materials/fabric.tres").duplicate(),
		"metal": preload("res://game/presentation/materials/metal.tres").duplicate(),
		"black": preload("res://game/presentation/materials/black.tres").duplicate(),
		"green": preload("res://game/presentation/materials/green.tres").duplicate(),
		"ceramic": preload("res://game/presentation/materials/ceramic.tres").duplicate(),
		"gold": preload("res://game/presentation/materials/gold.tres").duplicate(),
		"carpet": preload("res://game/presentation/materials/carpet.tres").duplicate(),
		"ceiling": preload("res://game/presentation/materials/ceiling.tres").duplicate(),
		"light": preload("res://game/presentation/materials/light.tres").duplicate(),
		"curtain": preload("res://game/presentation/materials/curtain.tres").duplicate(),
	}
	curtain_material = materials.curtain

func box(parent: Node3D, pos: Vector3, size: Vector3, material: String, solid := false) -> void:
	var key := parent.get_instance_id()
	if not batches.has(key): batches[key] = {"parent": parent, "groups": {}}
	var groups: Dictionary = batches[key].groups
	if not groups.has(material): groups[material] = []
	groups[material].append(Transform3D(Basis.from_scale(size), pos))
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

func flush() -> void:
	for batch in batches.values():
		for material in batch.groups:
			var transforms: Array = batch.groups[material]
			var mesh := BoxMesh.new()
			mesh.size = Vector3.ONE
			mesh.material = materials[material]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = transforms.size()
			for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = "Mesh_" + material
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
		door.position = center + Basis(Vector3.UP, yaw) * Vector3(-1.12, 0, 0)
		door.rotation.y = yaw
		door.closed_rotation = yaw
		door.doorway = center
		add_child(door)
		var leaf := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.24, 2.58, 0.11)
		mesh.material = materials.wood
		leaf.mesh = mesh
		leaf.position = Vector3(1.12, 1.29, 0)
		door.add_child(leaf)
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cube := BoxShape3D.new()
		cube.size = mesh.size
		shape.shape = cube
		shape.position = leaf.position
		door.add_child(shape)
		box(door, Vector3(1.96, 1.08, 0.09), Vector3(0.28, 0.06, 0.07), "gold")
		box(door, Vector3(1.96, 1.08, -0.09), Vector3(0.28, 0.06, 0.07), "gold")
		text(door, str(100 + int(b.id)), Vector3(1.12, 1.94, 0.065), 0, 28)
		text(door, str(100 + int(a.id)), Vector3(1.12, 1.94, -0.065), PI, 28)
		if int(a.id + b.id) % 3 != 0: door.open_immediately()
		doors.append(door)
	flush()
	build_navigation()
	build_dust()

func build_room(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	box(node, Vector3(0, -0.15, 0), Vector3(span.x, 0.3, span.y), "ceramic" if room.type in [4, 7, 9] else "carpet", true)
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
		if connected:
			for side in [-1, 1]:
				box(boundary, Vector3(side * (length + 2.4) * 0.25, height / 2, 0), Vector3((length - 2.4) * 0.5, height, 0.18), "plaster", true)
				box(boundary, Vector3(side * (length + 2.4) * 0.25, 0.48, -0.11), Vector3((length - 2.4) * 0.5, 0.96, 0.07), "wood")
				box(boundary, Vector3(side * (length + 2.4) * 0.25, 0.48, 0.11), Vector3((length - 2.4) * 0.5, 0.96, 0.07), "wood")
				box(boundary, Vector3(side * 1.23, 1.35, 0), Vector3(0.12, 2.7, 0.3), "trim")
			box(boundary, Vector3(0, (height + 2.65) / 2, 0), Vector3(2.4, height - 2.65, 0.18), "plaster", true)
			box(boundary, Vector3(0, 2.65, 0), Vector3(2.6, 0.12, 0.3), "trim")
		else:
			box(boundary, Vector3(0, height / 2, 0), Vector3(length, height, 0.18), "plaster", true)
			box(boundary, Vector3(0, 0.48, -0.11), Vector3(length, 0.96, 0.07), "wood")
			box(boundary, Vector3(0, 0.48, 0.11), Vector3(length, 0.96, 0.07), "wood")
		for side in [-1, 1]:
			box(boundary, Vector3(side * 3.5, 2.02, -0.16), Vector3(1.28, 0.92, 0.08), "gold")
			box(boundary, Vector3(side * 3.5, 2.02, -0.21), Vector3(1.14, 0.78, 0.035), "fabric" if int(room.variant) % 2 == 0 else "green")
	for prop in room.props:
		var furniture := Node3D.new()
		furniture.name = "Prop_%d_%s" % [prop.slot, prop.kind]
		furniture.position = Vector3(-3.95 if prop.slot % 2 == 0 else 3.95, 0, -3.95 if prop.slot < 2 else 3.95)
		if room.type in [1, 2, 3, 4, 7, 15, 16]:
			furniture.position = Vector3(-4.35 if prop.slot % 2 == 0 else 4.35, 0, -4.35 if prop.slot < 2 else 4.35)
			furniture.scale = Vector3.ONE * 0.85
		furniture.rotation.y = prop.rotation * PI / 2
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
	# Four curtained hiding booths with open approaches and collision-free exits.
	if room.type != 19:
		for corner in FLOOR.hiding_positions(room):
			var hide := preload("res://game/world/interactables/hiding_place.gd").new()
			hide.name = "HidingBooth_%d" % node.get_child_count()
			hide.position = corner
			hide.rotation.y = FLOOR.hiding_yaw(corner)
			node.add_child(hide)
			box(hide, Vector3(0, 1.05, -0.58), Vector3(1.25, 2.1, 0.1), "wood", true)
			for side in [-1, 1]: box(hide, Vector3(side * 0.62, 1.05, 0), Vector3(0.1, 2.1, 1.2), "wood", true)
			box(hide, Vector3(0, 2.12, 0), Vector3(1.3, 0.12, 1.25), "wood")
			for side in [-1, 1]: box(hide, Vector3(side * 0.42, 1.05, 0.6), Vector3(0.35, 2.0, 0.04), "curtain")
	# Central sightlines remain open; booths sit against the perimeter.
	box(node, Vector3(0, height - 0.13, 0), Vector3(1.3, 0.12, 0.55), "gold")
	box(node, Vector3(0, height - 0.21, 0), Vector3(1.15, 0.05, 0.4), "light")
	var light := OmniLight3D.new()
	light.position = Vector3(0, height - 0.5, 0)
	light.light_color = Color("ffdba7") if room.type not in [4, 7, 9] else Color("c5d9cb")
	light.light_energy = 1.5
	light.omni_range = maxf(9.0, maxf(span.x, span.y) * 0.7)
	light.omni_attenuation = 0.75
	light.shadow_enabled = true
	node.add_child(light)
	lights.append(light)
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
	if room.type in [0, 19]:
		text(node, "THE FOUR\nHOTEL · RECEPCIÓN" if room.type == 0 else "SALIDA\nREFUGIO", Vector3(0, 2.25, -2.5), 0, 40)
		if room.type == 19:
			text(node, "SALIDA / REFUGIO", Vector3(0, 2.65, 4.8), PI, 35)
			light.light_color = Color("b8d4b6")

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
		lights[i].visible = distance < 26.0
		lights[i].shadow_enabled = shadows and distance < 16.0
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
