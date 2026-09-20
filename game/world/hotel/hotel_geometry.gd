extends Node3D
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
var materials := {}
var batches := {}
var room_nodes: Array[Node3D] = []
var doors: Array = []
## The doors that lead from one wing to the next, one per stage.
var gates: Array = []
## Wardrobes in build order: the same index names the same wardrobe on every
## machine in an online match (doors likewise).
var hides: Array = []
var lights: Array[OmniLight3D] = []
var manifest: Dictionary
var reduced := false
## The Locust's player is looking: it does not see light, so every lamp, the
## dust, the fog and the probes are hidden. The opaque pass still writes the
## depth its acoustic view reads, but pays for no shadow map and no light
## clustering, which is where that view's budget comes from.
var echo_view := false
## Walls drawn whole, both faces panelled: for modules seen alone from outside
## (the gallery). In a floor every wall has a room on each side.
var full_walls := false
var dust: CPUParticles3D
var curtain_material: ShaderMaterial
var fog_volumes: Array[FogVolume] = []
## Every lit room's reflection probe, made only while it is among the nearest
## (update_visibility): {room, parent, height, size, every_third, probe}.
var probe_slots: Array[Dictionary] = []
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
## reception, service rooms, halls or the refuge) whose lamps are all out.
## Darkness spreads: an eligible room beside a dark one goes dark as well with
## NEIGHBOUR_DARK, so dark rooms come in stretches where the torch is the only
## light, not as isolated black boxes.
const DARK_SHARE := 0.4
const NEIGHBOUR_DARK := 0.55
## Room ids whose lamps are out, decided once per floor in build().
var dark_ids := {}
## Set while a dark room's furniture is built: its lamps stay out.
var building_dark := false
## The module whose furniture is being built (prop_factory.gd), -1 otherwise.
var building_type := -1
## Glowing materials and their unlit copies (switch_off).
var unlit := {}
const MATERIALS := ["plaster", "plaster_decrepit", "wood", "panel", "door", "trim", "linen", "fabric", "bedspread", "leather", "metal", "black", "green", "screen", "leaf", "ceramic", "tile", "gold", "carpet", "ceiling", "ceiling_service", "light", "shade", "mirror", "painting", "curtain"]
## Service rooms (laundry, storeroom, maintenance, office) have a suspended
## ceiling of acoustic tiles; the empty lounge and the storeroom decrepit
## paper on the walls.
const SERVICE_CEILINGS := [7, 8, 9, 15]
const DECREPIT_WALLS := [8, 18]
## The walls' material of the room being built (build_room()).
var wall_material := "plaster"
# Batched primitive meshes. Unit size; transforms carry the dimensions.
const SHAPES := {"box": "", "cylinder": "@cyl", "cone": "@cone"}
## Modules with wall lamps: reception, lobby, corridor, gallery.
const SCONCE_ROOMS := [0, 10, 11, 12]
const WALL_LAMP := preload("res://assets/props/wall_lamp/wall_lamp.res")
## The supplied old wooden door, baked by tools/props/build_door.gd: the leaf
## (hinge at the origin, along +X) and the casing (centred on the doorway).
const DOOR_LEAF := preload("res://assets/props/door/door_leaf.res")
const DOOR_FRAME := preload("res://assets/props/door/door_frame.res")
## Where the leaf's faces are, for the room numbers screwed onto them.
const LEAF_FACE := 0.066
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const DRESSING := preload("res://game/world/hotel/room_dressing.gd")
## The graphics preset in force (graphics_presets.gd): how far rooms are drawn
## (room_reach; a hidden room casts no shadow), where the ceiling lamps fade
## (lamp_fade) and the furniture lamps go out, dust, haze and probes. Medium
## until apply_quality() says otherwise: the staged sets use it as built.
var preset: Dictionary = PRESETS.PRESETS[PRESETS.MEDIUM]
## Source sizes of the lamps (a small bulb for PCSS penumbrae), times the
## preset's penumbra (0: plain filtering).
const LAMP_SIZE := 0.12
const PRACTICAL_SIZE := 0.2
const SCONCE_SIZE := 0.05
## Colour and profiles of the lamps (docs/REALISM.md, phase 2).
const LIGHTING := preload("res://game/world/hotel/lighting.gd")
## Lit wall lamps (preset sconce_lights) and how far away they go out.
var sconce_lights: Array[OmniLight3D] = []
const SCONCE_REACH := 24.0
## Bounce light round each lit room (preset bounce): bounce_light.gd.
const BOUNCE := preload("res://game/world/hotel/bounce_light.gd")
var bounce := BOUNCE.new()
## Reflection probes made at once, the nearest (update_visibility), and how
## far down that order a made one is kept: never more than PROBES_KEPT, well
## under the 64 places of Godot's reflection atlas.
const PROBES_SHOWN := 24
const PROBES_KEPT := 32
## Door numbers are not drawn past this: about 5 px tall there, unreadable
## through the tape filter anyway.
const NUMBER_REACH := 20.0
## Casing and jamb stop of each door in doors, hidden with it.
var door_fixtures: Array = []
## Shared meshes: seal slabs by size, and the jamb stop.
var slabs := {}
var stop_mesh: ArrayMesh

func _init() -> void:
	for key in MATERIALS:
		materials[key] = load("res://game/presentation/materials/%s.tres" % key).duplicate()
		apply_scan(materials[key], small_maps)
	maps_small = small_maps
	curtain_material = materials.curtain
	# A dead ceiling dome: same glass, no glow.
	materials["light_off"] = materials.light.duplicate()
	materials.light_off.emission_enabled = false
	materials.light_off.albedo_color = materials.light.albedo_color.darkened(0.55)
	# A lampshade whose bulb is out does not glow either.
	materials["shade_off"] = materials.shade.duplicate()
	materials.shade_off.emission_enabled = false

## Scanned maps (docs/REALISM.md, phase 3): a material's set is its "scan"
## metadata, a folder of assets/textures/ made by tools/textures/ingest_pbr.py
## (albedo, normal, orm). Loaded once and shared by every builder; the preset
## chooses the 2048 px ones or the 1024 px ones (small_maps, set by
## hotel_main before a floor is built and by apply_quality()).
static var small_maps := false
static var scans := {}
## The size this builder's materials have.
var maps_small := false

static func apply_scan(material: Material, small: bool) -> void:
	if not material is ShaderMaterial or not material.has_meta("scan"): return
	var maps := scan_maps(material.get_meta("scan"), small)
	if maps.is_empty(): return
	material.set_shader_parameter("albedo_map", maps.albedo)
	material.set_shader_parameter("normal_map", maps.normal)
	material.set_shader_parameter("orm_map", maps.orm)
	material.set_shader_parameter("use_maps", true)

static func scan_maps(set_name: String, small: bool) -> Dictionary:
	var key := set_name + ("_1k" if small else "")
	if not scans.has(key):
		var folder := "res://assets/textures/%s/" % set_name
		if not ResourceLoader.exists(folder + "albedo.jpg"): return {}
		# The other size goes: never both in video memory.
		scans.erase(set_name + ("" if small else "_1k"))
		var suffix := "_1k" if small else ""
		scans[key] = {}
		for kind in ["albedo", "normal", "orm"]: scans[key][kind] = load(folder + kind + suffix + ".jpg")
	return scans[key]

# Deterministic per-position variation; never consumes generator randomness.
static func vary(value: Vector3, salt := 0) -> float:
	return fposmod(sin(value.x * 12.9898 + value.z * 78.233 + value.y * 37.719 + salt * 11.31) * 43758.5453, 1.0)

## Nodes whose whole subtree is batched together (a room: its walls and its
## furniture). One MultiMesh per material for the room instead of one per
## wall and per piece of furniture: a fraction of the draw calls, in the
## camera pass and in every face of every shadow round it.
var batch_roots := {}

## Where a box under `parent` is batched, and its parent's transform in that
## node's space. The nodes are not in the tree yet, so the chain is walked by
## hand. Anything outside a registered room (opening scene, title set) keeps
## one batch per parent as before.
func batch_target(parent: Node3D) -> Array:
	var node: Node = parent
	var chain := Transform3D.IDENTITY
	while node != null and node != self:
		if batch_roots.has(node.get_instance_id()): return [node, chain]
		chain = (node as Node3D).transform * chain
		node = node.get_parent()
	return [parent, Transform3D.IDENTITY]

func box(parent: Node3D, pos: Vector3, size: Vector3, material: String, solid := false, form := "box", euler := Vector3.ZERO) -> void:
	# An empty material creates only the collider (detailed visuals stay separate).
	if not material.is_empty():
		var target := batch_target(parent)
		var key: int = target[0].get_instance_id()
		if not batches.has(key): batches[key] = {"parent": target[0], "groups": {}}
		var groups: Dictionary = batches[key].groups
		var group: String = material + SHAPES[form]
		if not groups.has(group): groups[group] = []
		groups[group].append(target[1] * Transform3D(Basis.from_euler(euler) * Basis.from_scale(size), pos))
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

## Materials whose vertices move with TIME (the curtain sway). Godot redraws
## every shadow that such a caster falls in on every frame, so they cast
## through a still copy instead (a 3.5 cm sway never shows in a shadow).
const SWAYING := ["curtain"]

func flush() -> void:
	for batch in batches.values():
		for group in batch.groups:
			var transforms: Array = batch.groups[group]
			var mesh := unit_mesh(group)
			mesh.material = materials[material_of(group)]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			var room: Variant = batch_roots.get(batch.parent.get_instance_id())
			# A room's boxes carry the room (surface.gdshaderinc room_data), for
			# the grime where its surfaces meet.
			multi.use_custom_data = room != null
			multi.mesh = mesh
			multi.instance_count = transforms.size()
			for i in transforms.size():
				multi.set_instance_transform(i, transforms[i])
				if room != null: multi.set_instance_custom_data(i, room)
			var instance := MultiMeshInstance3D.new()
			instance.name = "Mesh_" + group.replace("@", "-")
			instance.multimesh = multi
			# Outside a room (door plaques, staged sets): no bounce light,
			# like the doors themselves.
			if room == null: instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			batch.parent.add_child(instance)
			if room != null: bounce.add(batch.parent.get_instance_id(), group, transforms)
			if material_of(group) in SWAYING:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var still := MultiMeshInstance3D.new()
				still.name = instance.name + "_Shadow"
				still.multimesh = multi
				still.material_override = materials.black
				still.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				batch.parent.add_child(still)
	batches.clear()
	for batch in model_batches.values():
		for entry in batch.meshes.values():
			var mesh: Mesh = entry.mesh
			var transforms: Array = entry.transforms
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = transforms.size()
			for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = "Model_" + mesh.resource_name
			instance.multimesh = multi
			var size := mesh.get_aabb().size
			# Lamps redraw their shadows whenever anything moves near them:
			# only pieces of furniture cast, never what stands on them.
			if not entry.casts or size.y < SHADOW_MODEL:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if size.y < SMALL_MODEL and maxf(size.x, size.z) < 0.8:
				# Small things are not drawn from afar.
				instance.visibility_range_end = SMALL_REACH
				instance.visibility_range_end_margin = 2.0
			batch.parent.add_child(instance)
	model_batches.clear()

## Baked models (assets/props/hotel, room_dressing.gd), batched per room and
## per mesh like the boxes: one MultiMesh each. Nothing under SHADOW_MODEL
## tall casts a shadow, nor anything placed with casts off (what stands on a
## top or a shelf); things under SMALL_MODEL are not drawn past SMALL_REACH.
var model_batches := {}
const SHADOW_MODEL := 0.6
const SMALL_MODEL := 0.3
const SMALL_REACH := 16.0

func place(parent: Node3D, mesh: Mesh, xform: Transform3D, casts := true) -> void:
	var target := batch_target(parent)
	var key: int = target[0].get_instance_id()
	if not model_batches.has(key): model_batches[key] = {"parent": target[0], "meshes": {}}
	var meshes: Dictionary = model_batches[key].meshes
	var slot := "%d:%s" % [mesh.get_instance_id(), casts]
	if not meshes.has(slot): meshes[slot] = {"mesh": mesh, "casts": casts, "transforms": []}
	meshes[slot].transforms.append(target[1] * xform)

## A decal from assets/decals/ (tools/textures/ingest_dressing.py) under
## parent: projected along the transform's -Y over size, as strong as
## strength. Only on surfaces facing it, and faded out from afar. rank (0-1)
## orders a room's decals: the preset shows those under its share (decals).
func decal(parent: Node3D, name: String, xform: Transform3D, size: Vector3, strength: float, rank: float) -> void:
	var tint: Color = DECAL_TINT.get(name, Color.WHITE)
	var projector := Decal.new()
	projector.transform = xform
	projector.size = size
	projector.texture_albedo = load("res://assets/decals/%s.png" % name)
	var normal := "res://assets/decals/%s_normal.png" % name
	if ResourceLoader.exists(normal): projector.texture_normal = load(normal)
	projector.modulate = Color(tint.r, tint.g, tint.b, clampf(strength * tint.a, 0.0, 1.0))
	projector.normal_fade = 0.4
	projector.upper_fade = 0.2
	projector.lower_fade = 0.2
	projector.distance_fade_enabled = true
	projector.distance_fade_begin = DECAL_REACH
	projector.distance_fade_length = 4.0
	projector.set_meta("rank", rank)
	projector.visible = rank < float(preset.decals)
	parent.add_child(projector)
	decals.append(projector)

var decals: Array[Decal] = []

## Decals scanned from something else: footprints in sand made mud, a white
## handprint made grime, the smear softened.
const DECAL_TINT := {"Footsteps003": Color(0.2, 0.16, 0.11, 1.0), "Fingerprints004": Color(0.4, 0.36, 0.3, 1.0), "Smear003": Color(1, 1, 1, 0.45)}
## Decals are not drawn past this: some 20 in view at most.
const DECAL_REACH := 14.0

## Compatibility draws no decals: none are made.
func decals_drawn() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

## reach: past it the label is not drawn at all (0 keeps it at any distance).
## Engraved figures on the door plaques.
const PLAQUE_INK := Color(0.07, 0.05, 0.03)

func text(parent: Node3D, words: String, pos: Vector3, yaw := 0.0, size := 38, reach := 0.0, ink := Color("d3bd8e")) -> void:
	var label := Label3D.new()
	label.text = words
	label.position = pos
	label.rotation.y = yaw
	label.font_size = size
	label.pixel_size = 0.007
	label.modulate = ink
	label.outline_size = 0
	# Lit like everything else: an unshaded label glowed in a black room.
	label.shaded = true
	# Blended text never reaches a shadow map; saying so keeps it out of them.
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if reach > 0.0:
		label.visibility_range_end = reach
		label.visibility_range_end_margin = 1.0
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
	leaf.mesh = DOOR_LEAF
	holder.add_child(leaf)
	if not number.is_empty():
		text(holder, number, Vector3(width * 0.5, 1.94, LEAF_FACE), 0, 24)
		text(holder, number, Vector3(width * 0.5, 1.94, -LEAF_FACE), PI, 24)
	return hinge

## A shut door has to stop light, and a shadow map sees through a crack or
## a thin leaf. Two shadow-only pieces, never drawn and without collision:
##  - light_seal(): a slab inside the leaf that swings with it. SEAL_DEPTH is
##    under the leaf's thinnest part (its sunken panels, 3.5 cm either side of
##    the middle), or it would shade the leaf's own panels (they came out
##    blotchy while the door was shut).
##  - jamb_seal(): strips fixed in the doorway, SEAL_LIP into the opening
##    behind the edges of the leaf and SEAL_OVERLAP into the wall and header,
##    so no crack round a shut leaf lets the next room's light through. These
##    are drawn too, as the frame's door stop, so no crack can be seen through.
## Both are always there: one that appeared only once the door had finished
## closing made the room go dark all at once.
const SEAL_DEPTH := 0.04
const SEAL_OVERLAP := 0.12
const SEAL_LIP := 0.04
const OPENING_HIGH := 2.65
func light_seal() -> MeshInstance3D:
	var bounds := DOOR_LEAF.get_aabb()
	return shadow_block("LightSeal", Vector3(bounds.size.x - 0.02, bounds.size.y - 0.02, SEAL_DEPTH), bounds.get_center() * Vector3(1, 1, 0))

func jamb_seal(center: Vector3, yaw: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "JambSeal"
	holder.position = center
	holder.rotation.y = yaw
	holder.add_child(door_stop())
	return holder

## The jamb strips are drawn, like the stop of a real door frame: through the
## crack beside a shut leaf you saw straight into the lit room next door.
## The two sides and the head are one mesh, the same for every doorway.
func door_stop() -> MeshInstance3D:
	if stop_mesh == null:
		var edge := FLOOR.PORTAL * 0.5
		var side_width := SEAL_LIP + SEAL_OVERLAP
		var strips := []
		for side in [-1.0, 1.0]:
			strips.append([Vector3(side_width, OPENING_HIGH + SEAL_OVERLAP, SEAL_DEPTH), Vector3(side * (edge - SEAL_LIP + side_width * 0.5), (OPENING_HIGH + SEAL_OVERLAP) * 0.5, 0)])
		strips.append([Vector3(FLOOR.PORTAL + SEAL_OVERLAP * 2.0, SEAL_LIP + SEAL_OVERLAP, SEAL_DEPTH), Vector3(0, OPENING_HIGH - SEAL_LIP + (SEAL_LIP + SEAL_OVERLAP) * 0.5, 0)])
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for strip in strips:
			var box := BoxMesh.new()
			box.size = strip[0]
			tool.append_from(box, 0, Transform3D(Basis.IDENTITY, strip[1]))
		stop_mesh = tool.commit()
	var block := MeshInstance3D.new()
	block.name = "Stop"
	block.mesh = stop_mesh
	block.material_override = DOOR_FRAME.surface_get_material(0)
	return block

## Puts out whatever glows on a mesh (lamp shades, bulbs): same surfaces,
## emission off.
func switch_off(instance: MeshInstance3D) -> void:
	for surface in instance.mesh.get_surface_count():
		var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
		if material == null or not material.emission_enabled: continue
		if not unlit.has(material):
			var dark := material.duplicate() as BaseMaterial3D
			dark.emission_enabled = false
			dark.albedo_color = dark.albedo_color.darkened(0.3)
			unlit[material] = dark
		instance.set_surface_override_material(surface, unlit[material])

func shadow_block(title: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	var block := MeshInstance3D.new()
	block.name = title
	# Every door's seal is the same slab: one mesh for all of them.
	if not slabs.has(size):
		var slab := BoxMesh.new()
		slab.size = size
		slabs[size] = slab
	block.mesh = slabs[size]
	block.position = at
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return block

func build(data: Dictionary) -> void:
	manifest = data
	decide_dark(data)
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
		# In each room's bounce stand-in the doorway is shut (bounce_light.gd):
		# through a hole in it the voxels there took the next room's lamps
		# and lit the leaf's face on this side, door closed.
		for room in [a, b]:
			var slab := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(FLOOR.PORTAL, 2.65, 0.12)), center - FLOOR.position_of(room) + Vector3(0, 1.325, 0))
			bounce.add(room_nodes[int(room.id)].get_instance_id(), "door", [slab])
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
		leaf.name = "Leaf"
		leaf.mesh = DOOR_LEAF
		# A leaf and its casing stand in both rooms' bounce volumes: Godot
		# lit each face with both, and a shut door's far face glowed with the
		# lamps of the room behind it. Doors take no bounce light.
		leaf.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		door.add_child(leaf)
		door.add_child(light_seal())
		# The body keeps the leaf's original box: walking, the creature's reach
		# and the physical checks were all tuned against it.
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cube := BoxShape3D.new()
		cube.size = Vector3(FLOOR.LEAF_WIDTH, 2.58, 0.07)
		shape.shape = cube
		shape.position = Vector3(half, 1.29, 0)
		door.add_child(shape)
		# The casing belongs to the wall, not the leaf: it stays when it swings.
		var casing := MeshInstance3D.new()
		casing.name = "Casing_%d_%d" % [a.id, b.id]
		casing.mesh = DOOR_FRAME
		casing.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		casing.position = center
		casing.rotation.y = yaw
		add_child(casing)
		var stop := jamb_seal(center, yaw)
		add_child(stop)
		# They belong to the wall, but are shown only as far as the door is.
		door_fixtures.append([casing, stop])
		# Each face shows the number of the room behind the door, as seen from
		# the room that face looks into.
		var b_side := signf((FLOOR.position_of(b) - center).dot(Basis(Vector3.UP, yaw).z))
		# On a brass plaque screwed to the leaf, in dark letters.
		for face in [1, -1]:
			box(door, Vector3(half, 1.94, face * (LEAF_FACE + 0.002)), Vector3(0.34, 0.19, 0.004), "gold")
		text(door, str(100 + int(a.id)), Vector3(half, 1.94, (LEAF_FACE + 0.005) * b_side), 0.0 if b_side > 0 else PI, 20, NUMBER_REACH, PLAQUE_INK)
		text(door, str(100 + int(b.id)), Vector3(half, 1.94, -(LEAF_FACE + 0.005) * b_side), PI if b_side > 0 else 0.0, 20, NUMBER_REACH, PLAQUE_INK)
		# The door on to the next wing is the gate of its stage: shut, locked,
		# and never open at the start.
		var stage := gate_stage(data, int(a.id), int(b.id))
		if stage > 0:
			door.gate_stage = stage
			door.locked = true
			gates.append(door)
		elif int(a.id + b.id) % 3 != 0: door.open_immediately()
		doors.append(door)
	flush()
	build_navigation()
	build_dust()

func build_room(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	# Half the floor round the room's origin, the height, and the open sides
	# of a hall (no wall, the next cell goes on): no grime gathers there.
	batch_roots[node.get_instance_id()] = Color(span.x * 0.5, span.y * 0.5, height, 0.0)
	wall_material = "plaster_decrepit" if room.type in DECREPIT_WALLS else "plaster"
	box(node, Vector3(0, -0.15, 0), Vector3(span.x, 0.3, span.y), "tile" if room.type in FLOOR.HARD_FLOORS else "carpet", true)
	box(node, Vector3(0, height + 0.1, 0), Vector3(span.x, 0.2, span.y), "ceiling_service" if room.type in SERVICE_CEILINGS else "ceiling", true)
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: int = room.id + direction.x + direction.y * int(manifest.width)
		var connected: bool = manifest.adjacency[room.id].has(neighbor) and (direction.y != 0 or abs(int(room.x) - neighbor % int(manifest.width)) == 1)
		var edge := [mini(room.id, neighbor), maxi(room.id, neighbor)]
		if connected and manifest.get("merged", []).has(edge):
			# 1 -x, 2 +x, 4 -z, 8 +z (surface.gdshaderinc room_edge()).
			var bit: int = {Vector2i(-1, 0): 1, Vector2i(1, 0): 2, Vector2i(0, -1): 4, Vector2i(0, 1): 8}[direction]
			batch_roots[node.get_instance_id()].a += bit
			continue
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
			# Jambs, head and casing come with the door (DOOR_FRAME, in build()).
			wall_core(boundary, Vector3(0, (height + 2.65) / 2, 0), Vector3(FLOOR.PORTAL, height - 2.65, 0.18), inner)
			box(boundary, Vector3(0, height - 0.05, inner * 0.12), Vector3(FLOOR.PORTAL, 0.1, 0.06), "trim")
		else:
			wall_run(boundary, 0.0, length, height, inner)
		for side in [-1, 1]:
			# Framed hotel art on this room's face of the wall (inner); each canvas
			# composition varies with its position. It used to hang on local -Z,
			# which on west and north walls is the next room's face, on top of that
			# room's own prints (two frames z-fighting, this room's wall bare).
			hang_painting(boundary, Vector3(side * 3.5, 2.02, 0), inner, int(room.variant) % 2 == 0)
			# Public spaces: a pair of cloth-shaded wall lamps beside each print.
			if room.type in SCONCE_ROOMS and length > 9.0:
				for flank in [-1, 1]:
					var sconce := MeshInstance3D.new()
					sconce.mesh = WALL_LAMP
					# In a dark room its shade and bulb are out: an emissive
					# shade lit the walls round it by bounce light.
					if dark_room(room): switch_off(sconce)
					sconce.position = Vector3(side * 3.5 + flank * 0.98, 1.6, inner * 0.09)
					# The model faces +Z: turned to face into this room.
					sconce.rotation.y = PI if inner < 0 else 0.0
					boundary.add_child(sconce)
					if not dark_room(room): sconce_light(boundary, sconce)
	for prop in room.props:
		var furniture := Node3D.new()
		furniture.name = "Prop_%d_%s" % [prop.slot, prop.kind]
		furniture.transform = prop_transform(room, prop)
		node.add_child(furniture)
		building_dark = dark_room(room)
		building_type = int(room.type)
		build_prop(furniture, prop.kind)
		building_dark = false
		building_type = -1
	if room.type in [1, 2, 3, 4, 7, 15, 16]:
		# Domestic alcoves interrupt the square footprint while preserving portals.
		for side in [-1, 1]:
			for end in [-1, 1]:
				if room.get("layout", 0) == 1 and side > 0: continue
				if room.get("layout", 0) == 2 and end > 0: continue
				if room.get("layout", 0) == 3 and side != end: continue
				box(node, Vector3(side * 4.4, height / 2, end * 2.8), Vector3(3.2, height, 0.12), wall_material, true)
				blocker(Transform3D.IDENTITY, Vector3(side * 4.4, height / 2, end * 2.8), Vector2(3.2, height))
				for z in [3.2, 5.6]:
					box(node, Vector3(side * 2.8, height / 2, end * z), Vector3(0.12, height, 0.8), wall_material, true)
				box(node, Vector3(side * 2.8, (height + 2.55) / 2, end * 4.4), Vector3(0.12, height - 2.55, 1.6), wall_material, true)
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
	# Furniture along the free walls, things, clutter and decals (phase 4).
	DRESSING.dress(self, node, room)
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
		light.light_color = LIGHTING.light_color(LIGHTING.FLUORESCENT, LIGHTING.TUBE_TINT)
		light.light_energy = 3.4 * LIGHTING.PROFILE_GAIN
		light.set_meta("profile", LIGHTING.profile("tube"))
		light.position = Vector3(0, height - 0.35, 0)
	else:
		# Frosted dome in a brass ring: warm pool with darker corners.
		cylinder(node, Vector3(0, height - 0.03, 0), 0.26, 0.06, "gold")
		box(node, Vector3(0, height - 0.13, 0), Vector3(0.46, 0.16, 0.46), "light_off" if dark_room(room) else "light", false, "cone", Vector3(PI, 0, 0))
		light.light_color = LIGHTING.light_color(LIGHTING.INCANDESCENT)
		light.light_energy = 3.6 * LIGHTING.PROFILE_GAIN
		light.set_meta("profile", LIGHTING.profile("dome"))
		light.position = Vector3(0, height - 0.45, 0)
	light.omni_range = maxf(10.0, maxf(span.x, span.y) * 0.85)
	light.omni_attenuation = 1.25
	light.light_size = LAMP_SIZE * preset.penumbra
	light.light_specular = 0.45 if service else 0.6
	light.shadow_enabled = true
	# Small biases so thin shelves and trays still block light and glints.
	# Lower ones (0.01 and 0.25 were tried) cover walls and ceilings in
	# shadow acne, rippling bands: doors are sealed with geometry instead
	# (light_seal, jamb_seal).
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 0.6
	# The shape of its light: a photometric profile as a projector
	# (lighting.gd), which only works while the light casts shadows.
	light.light_projector = light.get_meta("profile")
	# Lamps light the volumetric fog only on presets with lamp_fog, where the
	# fog is short enough (14 m) for its cells not to straddle walls: at 48 m a
	# lit room's haze glowed in the dark room next door (apply_quality).
	light.light_volumetric_fog_energy = 0.0
	# Lights and shadows fade with distance instead of switching on abruptly
	# (lamp_fade, per preset). A light keeps its shadow until the light itself
	# is gone: a shadow that faded earlier left lamps shining through walls and
	# closed doors between that distance and the light's own fade.
	light.distance_fade_enabled = true
	set_fade(light, preset.lamp_fade[0], preset.lamp_fade[1])
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
	# Every lit room can have a reflection probe the size of the room; the
	# preset decides which are in use (probes: every third hall, or every lit
	# room), and only the nearest exist (update_visibility). A dark room has
	# none and stays black.
	if not dark_room(room):
		probe_slots.append({"room": int(room.id), "parent": node, "height": height, "size": Vector3(span.x - 0.2, height - 0.05, span.y - 0.2), "every_third": room.hall == room.id and room.hall >= 0 and int(room.id) % 3 == 0, "probe": null})
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
		beacon.light_volumetric_fog_energy = 0.0
		node.add_child(beacon)
		beacons.append({"light": beacon, "material": beacon_glass, "energy": beacon.light_energy})
	if room.type == 19:
		exit_sign(node, Vector3(0, 2.25, -2.5), 0.0, height)
		exit_sign(node, Vector3(0, 2.45, 4.8), PI, height)
		light.light_color = Color("b8d4b6")
	build_occluder(node)

## The refuge's sign: a sheet of clear acrylic lit from the diodes buried in
## its top edge, engraved SALIDA with an arrow pointing down at the room the
## floor is left from, in an aluminium channel hung from the ceiling on a
## stem. The lettering is drawn by the light the sheet guides
## (shaders/exit_panel.gdshader); the sign also throws its own green light,
## with a shadow, like every other visible lamp in the hotel.
const EXIT_PANEL := preload("res://game/presentation/shaders/exit_panel.gdshader")
const EXIT_ENGRAVING := preload("res://assets/props/exit_sign/engraving.png")
const PANEL_SIZE := Vector2(0.62, 0.31)

func exit_sign(node: Node3D, pos: Vector3, yaw: float, ceiling: float) -> void:
	var board := Node3D.new()
	board.name = "ExitSign"
	board.position = pos
	board.rotation.y = yaw
	node.add_child(board)
	var top := PANEL_SIZE.y * 0.5
	# The channel the diodes sit in, its end clamps, and the stem and canopy
	# that hang the whole thing from the ceiling.
	box(board, Vector3(0, top + 0.03, 0), Vector3(PANEL_SIZE.x + 0.06, 0.055, 0.07), "metal")
	box(board, Vector3(0, top + 0.058, 0), Vector3(PANEL_SIZE.x + 0.062, 0.006, 0.072), "black")
	for side in [-1.0, 1.0]:
		box(board, Vector3(side * (PANEL_SIZE.x * 0.5 - 0.012), top - 0.022, 0), Vector3(0.05, 0.06, 0.034), "black")
	var drop := ceiling - pos.y - top - 0.06
	box(board, Vector3(0, top + 0.06 + drop * 0.5, 0), Vector3(0.016, drop, 0.016), "metal", false, "cylinder")
	box(board, Vector3(0, ceiling - 0.01, 0), Vector3(0.1, 0.02, 0.1), "metal")
	var glass := ShaderMaterial.new()
	glass.shader = EXIT_PANEL
	glass.set_shader_parameter("engraving", EXIT_ENGRAVING)
	var sheet := MeshInstance3D.new()
	sheet.name = "Panel"
	var quad := QuadMesh.new()
	quad.size = PANEL_SIZE
	sheet.mesh = quad
	sheet.material_override = glass
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	board.add_child(sheet)
	# The light it spills: green, close, and with a shadow, so it stays in
	# this room like every other lamp (docs/REALISM.md, the bounce leak).
	var lamp := OmniLight3D.new()
	lamp.name = "ExitGlow"
	lamp.position = Vector3(0, 0.02, 0)
	lamp.light_color = Color(0.25, 1.0, 0.45)
	lamp.light_energy = 0.55
	lamp.omni_range = 2.8
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.light_size = PRACTICAL_SIZE
	lamp.light_specular = 0.3
	# No bounce: a sign hangs in the doorway's own volume as well, and the
	# rebuilt bounce would carry its green into the room next door.
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
	lamp.light_volumetric_fog_energy = 0.12
	lamp.distance_fade_enabled = true
	practical_fade(lamp)
	board.add_child(lamp)
	practicals.append(lamp)

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
	wall_core(boundary, Vector3(x, height / 2, 0), Vector3(length, height, 0.18), inner)
	for face in ([-1, 1] if full_walls else [inner]):
		box(boundary, Vector3(x, 0.48, face * 0.11), Vector3(length, 0.96, 0.07), "panel")
		box(boundary, Vector3(x, 0.98, face * 0.15), Vector3(length, 0.05, 0.035), "trim")
		box(boundary, Vector3(x, 0.07, face * 0.155), Vector3(length, 0.14, 0.03), "trim")
	box(boundary, Vector3(x, height - 0.05, inner * 0.12), Vector3(length, 0.1, 0.06), "trim")
	box(boundary, Vector3(x, height - 0.13, inner * 0.1), Vector3(length, 0.06, 0.03), "trim")

## Occlusion culling: every wall of a room is also a quad of an occluder, so
## rooms and furniture hidden behind walls are not drawn by the camera. It
## never touches shadows (Godot does not occlusion-cull shadow passes), so
## light stays sealed exactly as before. Doors are left out: they move, and an
## open door must show the room behind it. Quads sit inside the wall's own
## drawn half and are 3 cm short of every edge, so nothing visible is ever
## behind them. lockers collects them while a room is built.
const BLOCKER_INSET := 0.03
var blockers: Array = []

## A vertical quad of size (width along local X, height along Y) centred at
## pos in the frame rame (a wall boundary, or the room itself).
func blocker(frame: Transform3D, pos: Vector3, size: Vector2) -> void:
	var half := Vector2(size.x * 0.5 - BLOCKER_INSET, size.y * 0.5 - BLOCKER_INSET)
	if half.x <= 0.0 or half.y <= 0.0: return
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		blockers.append(frame * (pos + Vector3(corner.x * half.x, corner.y * half.y, 0)))

## The room's occluder, from the quads its walls left in lockers.
## The stage whose gate this pair of rooms holds, or 0 for a normal door.
static func gate_stage(data: Dictionary, a: int, b: int) -> int:
	for gate in data.get("gates", []):
		var beyond := int(gate.get("beyond", -1))
		if beyond < 0: continue
		if (int(gate.room) == a and beyond == b) or (int(gate.room) == b and beyond == a): return int(gate.stage)
	return 0

## Closing a stage opens its gate for good; every machine works it out from the
## stage itself, which is already replicated, so no door message is needed.
func open_gates(stage: int, ready: bool) -> void:
	for door in gates:
		if not is_instance_valid(door) or not door.locked: continue
		# A gate only ever opens: past stages are already through, and the one
		# in hand gives way as soon as its condition is met. Once open it stays
		# open, even if somebody steps out of the refuge again.
		if door.gate_stage > stage or (door.gate_stage == stage and not ready): continue
		door.locked = false
		if not door.opened and not door.moving: door.set_state(true)

func build_occluder(node: Node3D) -> void:
	if full_walls or blockers.is_empty(): return
	var indices := PackedInt32Array()
	for quad in blockers.size() / 4:
		var first := quad * 4
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var shape := ArrayOccluder3D.new()
	shape.set_arrays(PackedVector3Array(blockers), indices)
	var occluder := OccluderInstance3D.new()
	occluder.name = "Occluder"
	occluder.occluder = shape
	node.add_child(occluder)
	blockers.clear()

## Plaster core of a wall along its boundary. The collider is the whole 18 cm,
## as always (walking, navigation, hearing and the creature's sight are tuned
## to it). What is drawn is only this room's half, and wall_run() panels only
## this room's face: the room on the other side draws its own, so a shared
## wall is no longer drawn twice. Together the two halves are the old wall,
## in the camera and in every shadow.
func wall_core(boundary: Node3D, pos: Vector3, size: Vector3, inner: int) -> void:
	box(boundary, pos, size, "", true)
	blocker(boundary.transform, pos + Vector3(0, 0, inner * size.z * 0.25), Vector2(size.x, size.y))
	if full_walls: box(boundary, pos, size, wall_material)
	else: box(boundary, pos + Vector3(0, 0, inner * size.z * 0.25), Vector3(size.x, size.y, size.z * 0.5), wall_material)

## A wall lamp that really lights its wall (preset sconce_lights): a cone up
## and one down out of the shade, nothing behind it (lighting.gd "sconce").
## Like every lamp it casts shadows, which the profile needs anyway; without
## shadows (the Sombras switch) it stays off rather than shine through the
## wall.
func sconce_light(boundary: Node3D, sconce: MeshInstance3D) -> void:
	var lamp := OmniLight3D.new()
	var facing := Basis(Vector3.UP, sconce.rotation.y)
	lamp.transform = Transform3D(facing, sconce.position + facing.z * 0.16 + Vector3(0, 0.22, 0))
	lamp.light_color = LIGHTING.light_color(2600.0)
	lamp.light_energy = 1.6
	lamp.omni_range = 3.4
	lamp.omni_attenuation = 1.6
	lamp.light_size = SCONCE_SIZE * preset.penumbra
	lamp.light_specular = 0.3
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.light_volumetric_fog_energy = 0.0
	lamp.light_projector = LIGHTING.profile("sconce")
	# Out of the bounce light: a wall lamp sits 25 cm from the wall, and the
	# next room's volume (bounce_light.gd) took its light in through a half
	# wall thinner than one of its voxels, lighting the far face yellow.
	lamp.light_bake_mode = Light3D.BAKE_DYNAMIC
	lamp.distance_fade_enabled = true
	set_fade(lamp, SCONCE_REACH - 8.0, 6.0)
	lamp.visible = false
	boundary.add_child(lamp)
	sconce_lights.append(lamp)

# A lamp that really lights its surroundings (no shadows, culled by distance).
func practical(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> void:
	# In a dark room the table and floor lamps are out too: it is dark.
	if building_dark: return
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 2.2
	lamp.light_size = PRACTICAL_SIZE * preset.penumbra
	# Floor and desk lamps stand near walls: out of the bounce light, like the
	# wall lamps (sconce_light()).
	lamp.light_bake_mode = Light3D.BAKE_DYNAMIC
	lamp.light_specular = 0.25
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.light_volumetric_fog_energy = 0.0
	lamp.distance_fade_enabled = true
	# Shadows last as long as the light does (set_fade): a lamp still shining
	# without its shadow shines through walls and closed doors.
	practical_fade(lamp)
	parent.add_child(lamp)
	practicals.append(lamp)

## A furniture lamp fades over its last 10 m before furniture_lamps (it is
## hidden there), 8 m of fade and 2 m to spare.
func practical_fade(lamp: OmniLight3D) -> void:
	var out: float = preset.furniture_lamps
	if out > 0.0: set_fade(lamp, out - 10.0, 8.0)

## Bakes the lit rooms' bounce light on worker threads (bounce_light.gd), once.
## A room alone, or a hall's cells together (one volume over the hall, if it
## is a rectangle; an L-shaped hall has none: see bounce_light.gd).
func start_bounce() -> void:
	var halls := {}
	var wanted := []
	for i in room_nodes.size():
		var room: Dictionary = manifest.rooms[i]
		if dark_room(room): continue
		var hall := int(room.get("hall", -1))
		if hall >= 0:
			if not halls.has(hall): halls[hall] = []
			halls[hall].append(i)
		else:
			wanted.append({"room": i, "node": room_nodes[i], "centre": Vector3.ZERO, "size": FLOOR.size_of(room), "height": float(room.height), "parts": [[room_nodes[i], Vector3.ZERO]]})
	for hall in halls:
		var cells: Array = halls[hall]
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var area := 0.0
		var height := 0.0
		for i in cells:
			var span := FLOOR.size_of(manifest.rooms[i])
			var at := room_nodes[i].position
			low = Vector2(minf(low.x, at.x - span.x * 0.5), minf(low.y, at.z - span.y * 0.5))
			high = Vector2(maxf(high.x, at.x + span.x * 0.5), maxf(high.y, at.z + span.y * 0.5))
			area += span.x * span.y
			height = maxf(height, float(manifest.rooms[i].height))
		var size := high - low
		if absf(size.x * size.y - area) > 0.5: continue
		var middle := Vector3((low.x + high.x) * 0.5, 0.0, (low.y + high.y) * 0.5)
		var root: Node3D = room_nodes[cells[0]]
		wanted.append({"room": cells[0], "node": root, "centre": middle - root.position, "size": size, "height": height, "parts": cells.map(func(i): return [room_nodes[i], room_nodes[i].position - middle])})
	bounce.start(wanted, unit_mesh)

## The floor goes mid-bake: the bake is waited for, which is safe (its workers
## never wait for the main thread), and error printing comes back on.
func _exit_tree() -> void:
	bounce.finish()

func make_probe(slot: Dictionary) -> void:
	var probe := ReflectionProbe.new()
	probe.position.y = slot.height * 0.5
	probe.size = slot.size
	probe.interior = true
	probe.box_projection = true
	probe.blend_distance = 0.1
	probe.intensity = 0.6
	probe.max_distance = 30
	probe_settings(probe)
	slot.parent.add_child(probe)
	slot.probe = probe

## Freeing it is what gives its place in the atlas back.
func drop_probe(slot: Dictionary) -> void:
	slot.probe.queue_free()
	slot.probe = null

## Rendered with shadows at probes 2, and there, without bounce light, its
## capture is also its room's ambient light (the bounce volumes would be
## replaced by it otherwise).
func probe_settings(probe: ReflectionProbe) -> void:
	var shadowed: bool = preset.probes >= 2
	if probe.enable_shadows != shadowed: probe.enable_shadows = shadowed
	var mode := ReflectionProbe.AMBIENT_ENVIRONMENT if shadowed and not preset.bounce else ReflectionProbe.AMBIENT_DISABLED
	if probe.ambient_mode != mode: probe.ambient_mode = mode

## Distance fade of a lamp; its shadow ends exactly where its light does.
static func set_fade(lamp: Light3D, begin: float, length: float) -> void:
	if lamp.distance_fade_begin != begin: lamp.distance_fade_begin = begin
	if lamp.distance_fade_length != length: lamp.distance_fade_length = length
	if lamp.distance_fade_shadow != begin + length: lamp.distance_fade_shadow = begin + length

## A new graphics preset (graphics_presets.gd), from hotel_main. Visibility
## follows on the next update_visibility().
func apply_quality(new_preset: Dictionary) -> void:
	preset = new_preset
	for projector in decals:
		var shown: bool = projector.get_meta("rank") < float(preset.decals)
		if projector.visible != shown: projector.visible = shown
	small_maps = preset.small_maps
	if maps_small != small_maps:
		maps_small = small_maps
		for key in materials: apply_scan(materials[key], small_maps)
	for light in lights:
		set_fade(light, preset.lamp_fade[0], preset.lamp_fade[1])
		var size: float = LAMP_SIZE * preset.penumbra
		if light.light_size != size: light.light_size = size
	for lamp in practicals:
		practical_fade(lamp)
		var size: float = PRACTICAL_SIZE * preset.penumbra
		if lamp.light_size != size: lamp.light_size = size
	# Baked once, the first time a preset asks for it (only where a GPU can
	# draw it: not headless, not Compatibility).
	if preset.bounce and RenderingServer.get_rendering_device() != null: start_bounce()
	# Every lit room's probe, rendered with shadows, also lights its room
	# (probes 2); otherwise only reflections. The bounce volumes take over
	# from it (a probe's ambient light would replace theirs).
	for slot in probe_slots:
		if slot.probe != null: probe_settings(slot.probe)
	var fog_energy := 1.0 if preset.lamp_fog else 0.0
	for light in lights:
		if light.light_volumetric_fog_energy != fog_energy: light.light_volumetric_fog_energy = fog_energy
	for lamp in sconce_lights:
		var size: float = SCONCE_SIZE * preset.penumbra
		if lamp.light_size != size: lamp.light_size = size
	if is_instance_valid(dust) and preset.dust > 0 and dust.amount != preset.dust: dust.amount = preset.dust

func _process(delta: float) -> void:
	bounce.poll()
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

## Public-domain paintings (assets/paintings, tools/textures/ingest_dressing.py)
## in their frames: a gold, carved frame (Poly Haven's, its own canvas taken
## out) or a plain wooden one. Portraits hang upright. Which painting hangs
## where comes from the position, like everything else.
const PAINTINGS := "res://assets/paintings/"
const CANVAS := Vector2(1.14, 0.78)
static var art: Array = []
static var carved_frame: Mesh
## Where the carved frame's opening is, in its own space: centre and size.
static var carved_opening := AABB()

static func paintings() -> Array:
	if not art.is_empty(): return art
	var entries = JSON.parse_string(FileAccess.get_file_as_string(PAINTINGS + "paintings.json"))
	for entry in entries:
		var portrait: bool = entry.aspect < 0.95
		var canvas := Vector2(CANVAS.y, CANVAS.x) if portrait else CANVAS
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(PAINTINGS + "%d.jpg" % int(entry.id))
		material.roughness = 0.62
		# Cropped to the canvas, centred; a portrait keeps its upper part.
		var ratio: float = (canvas.x / canvas.y) / float(entry.aspect)
		if ratio < 1.0:
			material.uv1_scale = Vector3(ratio, 1, 1)
			material.uv1_offset = Vector3((1.0 - ratio) * 0.5, 0, 0)
		else:
			material.uv1_scale = Vector3(1, 1.0 / ratio, 1)
			material.uv1_offset = Vector3(0, (1.0 - 1.0 / ratio) * (0.25 if portrait else 0.5), 0)
		var quad := QuadMesh.new()
		quad.size = canvas
		quad.material = material
		quad.resource_name = "painting_%d" % int(entry.id)
		art.append({"mesh": quad, "portrait": portrait})
	# The carved frame without the canvas it came with.
	var source: Mesh = load("res://assets/props/hotel/fancy_picture_frame_01.res")
	carved_frame = ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var box := AABB()
		var first := true
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			box = AABB(vertex, Vector3.ZERO) if first else box.expand(vertex)
			first = false
		if source.surface_get_name(surface).ends_with("canvas"):
			carved_opening = box
			continue
		(carved_frame as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		carved_frame.surface_set_material(carved_frame.get_surface_count() - 1, source.surface_get_material(surface))
	carved_frame.resource_name = "carved_frame"
	return art

## A painting on a wall's inner face (inner: which side of the boundary),
## centred at pos; carved gold frame or a wooden one.
func hang_painting(boundary: Node3D, pos: Vector3, inner: int, carved: bool) -> void:
	var list := paintings()
	var pick: Dictionary = list[int(vary(boundary.position + boundary.basis * pos, 13) * list.size())]
	var canvas := Vector2(CANVAS.y, CANVAS.x) if pick.portrait else CANVAS
	var facing := Basis(Vector3.UP, PI if inner < 0 else 0.0)
	# The plaster face above the chair rail is 9 cm from the wall's centre.
	var face := 0.09
	pos += Vector3(0, 0, inner * face)
	if carved:
		# The frame is carved landscape: a portrait turns it on its side
		# rather than stretching the carving.
		var turn := Basis(Vector3.BACK, PI / 2) if pick.portrait else Basis.IDENTITY
		var scale := Vector3(CANVAS.x / carved_opening.size.x, CANVAS.y / carved_opening.size.y, 1.6)
		var local := Basis.from_scale(scale)
		var centre := turn * (local * carved_opening.get_center())
		var depth := 0.016 + 1.6 * (carved_frame.get_aabb().size.z * 0.5)
		place(boundary, carved_frame, Transform3D(facing * turn * local, pos + facing * Vector3(-centre.x, -centre.y, depth - 0.016)))
		place(boundary, pick.mesh, Transform3D(facing, pos + facing * Vector3(0, 0, depth - 0.016 + centre.z + 0.002)))
	else:
		var border := 0.07
		box(boundary, pos + Vector3(0, 0, inner * 0.02), Vector3(canvas.x + border * 2, canvas.y + border * 2, 0.04), "trim")
		place(boundary, pick.mesh, Transform3D(facing, pos + Vector3(0, 0, inner * 0.041)))

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
func dark_room(room: Dictionary) -> bool:
	return dark_ids.has(int(room.id))

static func may_be_dark(room: Dictionary) -> bool:
	return not (int(room.type) in [0, 4, 7, 8, 9, 19] or int(room.get("hall", -1)) >= 0)

## Which rooms are dark: a share of the eligible ones, then their eligible
## neighbours with NEIGHBOUR_DARK. Deterministic from positions, like the
## rest of the floor, so every machine agrees.
func decide_dark(data: Dictionary) -> void:
	dark_ids.clear()
	for room in data.rooms:
		if may_be_dark(room) and vary(FLOOR.position_of(room), 7) < DARK_SHARE: dark_ids[int(room.id)] = true
	var seeds: Array = dark_ids.keys()
	for id in seeds:
		for neighbour in data.adjacency[id]:
			var other: Dictionary = data.rooms[int(neighbour)]
			if may_be_dark(other) and vary(FLOOR.position_of(other), 13) < NEIGHBOUR_DARK: dark_ids[int(neighbour)] = true

func add_nav_quad(vertices: PackedVector3Array, polygons: Array[PackedInt32Array], center: Vector3, low: Vector2, high: Vector2) -> void:
	var first := vertices.size()
	vertices.append_array(PackedVector3Array([center + Vector3(low.x, 0.04, low.y), center + Vector3(low.x, 0.04, high.y), center + Vector3(high.x, 0.04, high.y), center + Vector3(high.x, 0.04, low.y)]))
	polygons.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))

func update_visibility(player_position: Vector3, shadows: bool) -> void:
	curtain_material.set_shader_parameter("motion", 0.0 if reduced else 1.0)
	if is_instance_valid(dust):
		dust.position = player_position + Vector3(0, 1.2, 0)
		dust.emitting = preset.dust > 0 and not reduced and not echo_view
		dust.visible = dust.emitting
	# Hall haze only exists in Forward+ (the preset has it off elsewhere).
	for fog in fog_volumes: fog.visible = preset.floor_haze and not reduced and not echo_view
	var reach: float = preset.room_reach
	var fade_end: float = preset.lamp_fade[0] + preset.lamp_fade[1]
	for i in room_nodes.size():
		var distance := room_nodes[i].position.distance_to(player_position)
		room_nodes[i].visible = distance < reach
		# A lamp only shines while every wall round it is still drawn: a hidden
		# room casts no shadow, and a lamp left on among hidden walls poured its
		# light into the dark rooms beside it (far walls of a shut dark room lit).
		var light_reach := minf(fade_end + 2.0, reach - lights[i].omni_range - 2.0)
		lights[i].visible = distance < light_reach and not lights[i].has_meta("off") and not echo_view
		# Only when it changes: every write makes Godot redraw that shadow. A
		# profile only works on a shadowed light: without shadows it goes, or
		# the lamp would give no light at all.
		if lights[i].shadow_enabled != shadows:
			lights[i].shadow_enabled = shadows
			lights[i].light_projector = lights[i].get_meta("profile") if shadows else null
	# A probe captures its room once, when it is made: only while the room's
	# lamp is on, or it would keep a dark capture. Only the nearest exist.
	# Godot's reflection atlas has 64 places and a probe keeps its place until
	# it is freed, even hidden: with a probe in every lit room, exploring a big
	# floor filled the atlas, probes then showed other rooms' captures (a red
	# square on a ceiling, warm light in a tiled bathroom) and the game
	# crashed. So the nearest PROBES_SHOWN are made, one already made is kept
	# while among the nearest PROBES_KEPT (no remaking at the edge), and the
	# rest are freed.
	var wanted: Array[Dictionary] = []
	for slot in probe_slots:
		var used: bool = preset.probes >= 2 or (preset.probes == 1 and slot.every_third)
		if used and not echo_view and lights[slot.room].visible: wanted.append(slot)
		elif slot.probe != null: drop_probe(slot)
	wanted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.parent.global_position.distance_squared_to(player_position) < b.parent.global_position.distance_squared_to(player_position))
	for k in wanted.size():
		if wanted[k].probe == null and k < PROBES_SHOWN: make_probe(wanted[k])
		elif wanted[k].probe != null and k >= PROBES_KEPT: drop_probe(wanted[k])
	for lamp in sconce_lights:
		lamp.visible = preset.sconce_lights and shadows and not echo_view and lamp.global_position.distance_to(player_position) < SCONCE_REACH
	bounce.show_near(player_position, preset.bounce and not echo_view)
	for lamp in practicals:
		lamp.visible = not echo_view and lamp.global_position.distance_to(player_position) < preset.furniture_lamps
		if lamp.shadow_enabled != shadows: lamp.shadow_enabled = shadows
	# Doors carry their light seals, casings and stops: shown as far as the
	# rooms are. No lit lamp reaches past that (its range ends inside it).
	for i in doors.size():
		var shown: bool = doors[i].doorway.distance_to(player_position) < reach
		doors[i].visible = shown
		for fixture in door_fixtures[i]: fixture.visible = shown

func build_dust() -> void:
	dust = CPUParticles3D.new()
	# Its specks would never show in a shadow, and as a caster its every-frame
	# update made Godot redraw the shadow of every lamp round the player.
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.amount = maxi(1, preset.dust)
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
