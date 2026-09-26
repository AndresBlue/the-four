extends Node3D
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
var materials := {}
var batches := {}
var room_nodes: Array[Node3D] = []
## The planta each room and each door stands on (FLOOR.planta_of), in their
## build order: only the one being looked from is ever drawn.
var room_planta := PackedInt32Array()
var door_planta := PackedInt32Array()
var doors: Array = []
## The doors that lead from one wing to the next, one per stage.
var gates: Array = []
## The lift of each stage: the middle of the car standing in the lobby behind
## that refuge's door. Stepping into it is taking it -- to the next wing, or,
## for the last one, off the floor.
var lifts: Array = []
## And where each of those lifts puts people down: in front of the car in the
## cell the next wing is walked into from. Empty for the last one, which
## leaves the floor instead.
var arrivals: Array = []
## Every piece of furniture with drawers or shelves, as it is dressed:
## {room, position, yaw, kind, front, note}. Four of them hide the numbers of
## the code.
var containers: Array = []
## How far the solid piece being furnished reaches into the room, in its
## stretch's space (room_dressing.put): where a container's front is.
var piece_front := 0.0
## Where a note would sit on the piece being furnished, in its stretch's space
## (room_dressing.note_fold()): empty if it takes none.
var note_spot := {}
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
## The floor has lost its power (the blackout of the wing being played).
var dark := false
## Room ids whose lamps are out: the floor's `dark` rooms (map_generator.
## light_rooms()), read once in build().
var dark_ids := {}
## Set while a dark room's furniture is built: its lamps stay out.
var building_dark := false
## The module whose furniture is being built (prop_factory.gd), -1 otherwise.
var building_type := -1
## Glowing materials and their unlit copies (switch_off).
var unlit := {}
## What glows by itself when the floor has power -- the frosted domes, the
## lampshades, the battens, the beacon glass -- and how brightly, so a power
## cut can take it away and give it back. Filled the first time it is needed:
## these materials belong to this hotel (duplicated in _init), so nothing here
## reaches another floor. The wall lamps are meshes rather than materials of
## ours (their glow lives inside the model), so they are held apart.
var glows := {}
var lit_sconces: Array[MeshInstance3D] = []
## The exit signs, which are the one thing on the floor with a battery: they
## stay lit when the power goes, sign and green spill both, and are kept out of
## the lists the cut works through. A refuge one can still find in the dark.
var exit_panels: Array[ShaderMaterial] = []
var exit_lamps: Array[OmniLight3D] = []
## And how far one is seen from. Its own, not the furniture lamps' (which are
## off altogether on Low): an emergency light is not decoration.
const EXIT_REACH := 14.0
## The lamp in each lift car's ceiling. A car stands a hand from the wall it
## backs on to, and its lamp, without a shadow, lit the room on the other side
## of that wall: a pool on a dark room's ceiling, from nowhere.
var car_lamps: Array[OmniLight3D] = []
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
## And how many of them are lit at once. Wall lamps are the many: eight to a
## public room, fifty-odd within reach standing in the middle of a floor, and
## every one of them asks for a place in the shadow atlas along with the
## ceiling and furniture lamps. Over the atlas, Godot draws what does not fit
## **without a shadow** -- and an omni light with no shadow goes straight
## through the wall: the lit room next door appearing on your side of the
## partition, a frame at a time, as you walk and the lamps round you change.
## Measured (tools/dev/light_leak.gd, seed 81): with all of them the worst
## dark room read 0.030 where it should read 0; with the nearest twelve,
## 0.00013; with sixteen it was back to 0.029. The nearest few are all
## anybody sees, and they are the ones lit.
const SCONCES_LIT := 12
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

## The floor's share of vary(), from its seed.
static func looks_of(run_seed: int) -> float:
	return float(posmod(hash([run_seed, "looks"]), 100003)) * 0.0137

# Deterministic variation for what is only looked at (paintings, what stands
# along the walls, a flickering batten): from a position and the floor's seed
# (looks, set in build()), so every machine dresses a room the same and the
# same corner of two floors is not dressed alike. It never consumes the
# generator's randomness. Staged sets (intro, title) keep looks at 0.
var looks := 0.0
func vary(value: Vector3, salt := 0) -> float:
	return fposmod(sin(value.x * 12.9898 + value.z * 78.233 + value.y * 37.719 + salt * 11.31 + looks) * 43758.5453, 1.0)

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

## A room's solid boxes, every one a shape of one body the room has, by the
## room's instance id: a body for each box was a fifth of the nodes of a
## floor of three whole plantas.
var solids := {}

func box(parent: Node3D, pos: Vector3, size: Vector3, material: String, solid := false, form := "box", euler := Vector3.ZERO) -> void:
	# An empty material creates only the collider (detailed visuals stay separate).
	var target := batch_target(parent)
	if not material.is_empty():
		var key: int = target[0].get_instance_id()
		if not batches.has(key): batches[key] = {"parent": target[0], "groups": {}}
		var groups: Dictionary = batches[key].groups
		var group: String = material + SHAPES[form]
		if not groups.has(group): groups[group] = []
		groups[group].append(target[1] * Transform3D(Basis.from_euler(euler) * Basis.from_scale(size), pos))
	if solid:
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = size
		shape.shape = cube
		var room: Node3D = target[0]
		if batch_roots.has(room.get_instance_id()):
			var body: StaticBody3D = solids.get(room.get_instance_id())
			if body == null:
				body = StaticBody3D.new()
				body.name = "Solid"
				room.add_child(body)
				solids[room.get_instance_id()] = body
			shape.transform = target[1] * Transform3D(Basis.IDENTITY, pos)
			body.add_child(shape)
		else:
			# Outside a room (the staged sets): a body of its own, as ever.
			var single := StaticBody3D.new()
			single.position = pos
			shape.name = "CollisionShape3D"
			single.add_child(shape)
			parent.add_child(single)

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
	solids.clear()
	# What held walls, stretches and pieces of furniture only for their
	# transform while a room was built, and has nothing of its own left.
	for room in room_nodes: drop_empty(room)

## Frees the plain holders under `node` that are left with nothing in them
## (batch_target() walked through them while the room was built), from the
## deepest up.
func drop_empty(node: Node) -> void:
	for child in node.get_children():
		drop_empty(child)
		if child.get_child_count() == 0 and child.get_class() == "Node3D" and child.get_script() == null:
			node.remove_child(child)
			child.free()

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
	projector.visible = decal_shown(projector)
	parent.add_child(projector)
	decals.append(projector)

var decals: Array[Decal] = []

## Whether a decal is drawn: its share of the preset, and never while the
## floor is drawn for the creature's ears (echo_view). Forward+ stamps a
## decal on every fragment inside its box, unshaded and transparent ones
## too, and the echo field is a quad sitting on the camera that echo_field
## stretches over the whole frame: with the camera pressed against a damp
## wall (the spring arm leaves it 0.2-0.3 m off, a wall decal reaches 0.32
## m out), the stain was spread across the hunter's screen in olive streaks.
## The grains and its own body standing in a box took the stain as well.
func decal_shown(projector: Decal) -> bool:
	return projector.get_meta("rank") < float(preset.decals) and not echo_view

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
	var stop := door_stop()
	stop.name = "JambSeal"
	stop.position = center
	stop.rotation.y = yaw
	return stop

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

## The power goes. Every light in the hotel dies at once: the ceilings, the
## lamps inside the furniture, the wall sconces, the service battens and the
## red lamp of the reception. The televisions are not touched (they have their
## own set) and neither is anybody's torch.
##
## It comes back the same way. The power belongs to the wing that lost it, so
## the next one is found lit: `blackout(false)` hands the ceilings back to the
## room culling (which only shows a lamp that is not marked out), and the
## battens and the beacon, that nothing else looks after, are lit here.
func blackout(on: bool) -> void:
	if dark == on: return
	dark = on
	for light in lights:
		# The lamp of a cell with nothing in it is out for good.
		if light.has_meta("void"): continue
		if on: light.set_meta("off", true)
		elif not dark_ids.has(int(light.get_meta("room", -1))): light.remove_meta("off")
		light.visible = light.visible and not on
	for lamp in practicals: lamp.visible = lamp.visible and not on
	for lamp in sconce_lights: lamp.visible = lamp.visible and not on
	for entry in tubes: entry.light.visible = entry.light.visible and not on
	for entry in beacons:
		# A beacon hangs off its room and nobody shows it again frame by frame.
		entry.light.visible = not on
	# Lamps stop glowing as well as stop lighting. A dome, a shade, a batten or
	# a wall lamp is a lit surface in its own right, and one left glowing over
	# a room that nothing else lights is the only thing still visible in it:
	# the power cut ignored by the lamps it was supposed to put out.
	for material in held_glows():
		material.emission_energy_multiplier = 0.0 if on else glows[material]
	for sconce in lit_sconces:
		if on: switch_off(sconce)
		else: switch_on(sconce)
	# The bounce baked for the lit rooms would keep lighting them.
	if on and is_instance_valid(bounce): bounce.show_near(Vector3(0, -9000, 0), false)

## Every glow this floor owns, with the strength it was built at. The ones that
## are animated (the battens' flicker, the beacon's blink) are written again
## from scratch every frame once the power is back, so what is kept for them is
## only a starting point.
func held_glows() -> Array:
	if glows.is_empty():
		for key in materials:
			var surface := materials[key] as BaseMaterial3D
			if surface != null and surface.emission_enabled: glows[surface] = surface.emission_energy_multiplier
		for entry in beacons:
			if entry.has("material"): glows[entry.material] = entry.material.emission_energy_multiplier
	return glows.keys()

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

## The other way round: the mesh glows with its own materials again.
func switch_on(instance: MeshInstance3D) -> void:
	for surface in instance.mesh.get_surface_count(): instance.set_surface_override_material(surface, null)

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

## The pairs of cells with no wall between them (corridor running on, or a
## salon), by pair: looked up for every wall and every door.
var open_pairs := {}
## While a floor is put up. build() hands a frame back between plantas and
## before the navigation: a window that answers nothing for five seconds is
## "not responding" to Windows, and all in one go a floor of three whole
## plantas held it three seconds on this PC, more on a slower one. The three
## navigation bakes go together (two seconds): with a frame between them, the
## navigation took in each planta on its own and the floor was ready two
## seconds later. Meanwhile nothing of the floor is drawn: it is hidden, and
## update_visibility() leaves it be (the frames in between drew every room
## built so far, lamps and all).
var building := false

func build(data: Dictionary) -> void:
	building = true
	visible = false
	manifest = data
	looks = looks_of(int(data.get("seed", 0)))
	open_pairs.clear()
	for pair in data.get("merged", []): open_pairs[Vector2i(int(pair[0]), int(pair[1]))] = true
	decide_dark(data)
	var planta := int(data.rooms[0].get("wing", 0)) if not data.rooms.is_empty() else 0
	for room in data.rooms:
		# One planta at a time, with a frame between them.
		if int(room.get("wing", 0)) != planta:
			planta = int(room.get("wing", 0))
			await get_tree().process_frame
		var node := Node3D.new()
		node.name = "Room_%d_%s" % [room.id, FLOOR.TYPES[room.type]]
		node.position = FLOOR.position_of(room)
		add_child(node)
		room_nodes.append(node)
		room_planta.append(FLOOR.planta_of(node.position.y))
		# A cell its planta does not use: nothing is built there. Its lamp
		# stands in the list, off, so a room's lamp is still lights[id].
		if FLOOR.is_void(room):
			var lamp := OmniLight3D.new()
			lamp.visible = false
			lamp.light_energy = 0.0
			lamp.set_meta("off", true)
			lamp.set_meta("void", true)
			lamp.set_meta("room", int(room.id))
			node.add_child(lamp)
			lights.append(lamp)
			continue
		build_room(node, room)
	route_signs.clear()
	for sign in ROUTE_SIGN.place(data): route_sign(sign)
	for edge in data.edges:
		var a: Dictionary = data.rooms[edge[0]]
		var b: Dictionary = data.rooms[edge[1]]
		# One door per connection, with a physical leaf and a stable identifier.
		if open_pairs.has(Vector2i(int(edge[0]), int(edge[1]))): continue
		# The last door of the floor, the one with the lock, is built at the
		# end so the gates keep the order of their stages.
		if gate_stage(data, int(a.id), int(b.id)) == int(data.get("wings", 3)): continue
		var spec: Dictionary = data.get("doors", {}).get("%d:%d" % [int(a.id), int(b.id)], {})
		var center := FLOOR.portal_between(a, b)
		var yaw := FLOOR.leaf_yaw(a, b, spec)
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
		door.open_turn = DOOR.OPEN_TURN * FLOOR.leaf_turn(a, b, spec, center, yaw)
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
		# the room that face looks into, on a brass plaque screwed to the leaf.
		# A door into service or common space has no plaque at all.
		var b_side := signf((FLOOR.position_of(b) - center).dot(Basis(Vector3.UP, yaw).z))
		for which in 2:
			var behind: Dictionary = a if which == 0 else b
			var number := int(behind.get("number", 0))
			if number <= 0: continue
			var side := b_side if which == 0 else -b_side
			box(door, Vector3(half, 1.94, side * (LEAF_FACE + 0.002)), Vector3(0.34, 0.19, 0.004), "gold")
			text(door, str(number), Vector3(half, 1.94, side * (LEAF_FACE + 0.005)), 0.0 if side > 0 else PI, 20, NUMBER_REACH, PLAQUE_INK)
		# The door on to the next wing is the gate of its stage: shut, locked,
		# and never open at the start.
		var stage := gate_stage(data, int(a.id), int(b.id))
		if stage > 0:
			door.gate_stage = stage
			door.locked = true
			gates.append(door)
		elif bool(spec.get("open", false)): door.open_immediately()
		doors.append(door)
	# Last, so the gates stay in the order of their stages and the doors keep
	# the indices the network knows them by.
	build_exit_door(data)
	for door in doors: door_planta.append(FLOOR.planta_of(door.doorway.y))
	build_lifts(data)
	flush()
	await get_tree().process_frame
	build_navigation()
	build_dust()
	building = false
	visible = true

## How far from a doorway's middle the middle of a painting keeps: its lamps
## (0.98 m either side) would be on the casing.
const PAINTING_CLEAR := 2.2

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
		# The cell beside it on its planta's grid (none past the edge).
		var neighbor: int = FLOOR.beside(room, direction)
		var connected: bool = neighbor >= 0 and manifest.adjacency[room.id].has(neighbor)
		if connected and open_pairs.has(Vector2i(mini(room.id, neighbor), maxi(room.id, neighbor))):
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
		# Where the doorway is along the wall, in the wall's own x: on a wall
		# between cells side by side in x (turned a quarter) that runs the
		# other way to the world's z (FLOOR.door_offset()).
		var door_at := 0.0
		if connected:
			door_at = FLOOR.door_offset(room, neighbor) * (-1.0 if direction.x != 0 else 1.0)
			for side in [-1, 1]:
				# From the jamb on that side to the end of the wall.
				var run: float = length * 0.5 - side * door_at - FLOOR.PORTAL * 0.5
				if run > 0.01: wall_run(boundary, door_at + side * (FLOOR.PORTAL * 0.5 + run * 0.5), run, height, inner)
			# Jambs, head and casing come with the door (DOOR_FRAME, in build()).
			wall_core(boundary, Vector3(door_at, (height + 2.65) / 2, 0), Vector3(FLOOR.PORTAL, height - 2.65, 0.18), inner)
			box(boundary, Vector3(door_at, height - 0.05, inner * 0.12), Vector3(FLOOR.PORTAL, 0.1, 0.06), "trim")
		else:
			wall_run(boundary, 0.0, length, height, inner)
		# The end of a corridor, three or four metres across, has no room for
		# a painting either side of its middle, nor for the lamps beside one.
		if length < 9.0: continue
		for side in [-1, 1]:
			# Nor on the side a doorway was moved to.
			if connected and absf(side * 3.5 - door_at) < PAINTING_CLEAR: continue
			# Framed hotel art on this room's face of the wall (inner); vary()
			# picks each canvas, by its position and the floor. It used to hang
			# on local -Z, which on west and north walls is the next room's
			# face, on top of that room's own prints (two frames z-fighting,
			# this room's wall bare).
			hang_painting(boundary, Vector3(side * 3.5, 2.02, 0), inner, int(room.variant) % 2 == 0)
			# Public spaces: a pair of cloth-shaded wall lamps beside each print.
			if room.type in SCONCE_ROOMS and length > 9.0:
				for flank in [-1, 1]:
					var sconce := MeshInstance3D.new()
					sconce.mesh = WALL_LAMP
					# In a dark room its shade and bulb are out: an emissive
					# shade lit the walls round it by bounce light.
					if dark_room(room): switch_off(sconce)
					else: lit_sconces.append(sconce)
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
	light.set_meta("room", int(room.id))
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

## The door of the last stage: in the wall the last refuge shares with the
## landing, shut and locked until its code is read in. Behind it are the back
## stairs -- a room of the floor that nothing else opens on to -- and stepping
## into them is leaving the floor. It is built after every other door so the
## gates stay in the order of their stages.
func build_exit_door(data: Dictionary) -> void:
	var gates_list: Array = data.get("gates", [])
	if gates_list.is_empty(): return
	var last: Dictionary = gates_list[gates_list.size() - 1]
	var room: Dictionary = data.rooms[int(last.room)]
	var out: Array = last.get("out", [1, 0])
	var direction := Vector2i(int(out[0]), int(out[1]))
	var span := FLOOR.size_of(room)
	var away := Vector3(direction.x, 0, direction.y)
	var centre: Vector3 = FLOOR.position_of(room) + away * (Vector2(span.x, span.y).dot(Vector2(absf(away.x), absf(away.z))) * 0.5)
	# The cell behind that door is the lift lobby, and its doorway is the wall
	# the two of them share.
	var beyond := int(last.get("beyond", -1))
	var yaw := PI / 2 if direction.x != 0 else 0.0
	var turn: float = DOOR.OPEN_TURN
	if beyond >= 0:
		centre = FLOOR.portal_between(room, data.rooms[beyond])
		# Hung like any other door (build()): it swings into the lobby.
		var a: Dictionary = data.rooms[mini(int(room.id), beyond)]
		var b: Dictionary = data.rooms[maxi(int(room.id), beyond)]
		var spec: Dictionary = data.get("doors", {}).get("%d:%d" % [int(a.id), int(b.id)], {})
		yaw = FLOOR.leaf_yaw(a, b, spec)
		turn = DOOR.OPEN_TURN * FLOOR.leaf_turn(a, b, spec, centre, yaw)
	var door = DOOR.new()
	door.name = "ExitDoor"
	door.collision_layer = 8
	door.collision_mask = 4
	var half := FLOOR.LEAF_WIDTH * 0.5
	door.position = centre + Basis(Vector3.UP, yaw) * Vector3(-half, 0, 0)
	door.rotation.y = yaw
	door.closed_rotation = yaw
	door.open_turn = turn
	door.doorway = centre
	door.locked = true
	door.gate_stage = int(last.stage)
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	leaf.mesh = DOOR_LEAF
	door.add_child(leaf)
	door.add_child(light_seal())
	var shape := CollisionShape3D.new()
	# By this name the door finds it to tell whether somebody stands in the
	# leaf (hotel_door.holds_somebody); unnamed, it never found it and went
	# solid on top of whoever crowded the last door.
	shape.name = "CollisionShape3D"
	var body := BoxShape3D.new()
	body.size = Vector3(FLOOR.LEAF_WIDTH, OPENING_HIGH, 0.12)
	shape.shape = body
	shape.position = Vector3(half, OPENING_HIGH * 0.5, 0)
	door.add_child(shape)
	add_child(door)
	var casing := MeshInstance3D.new()
	casing.name = "ExitCasing"
	casing.mesh = DOOR_FRAME
	casing.position = centre
	casing.rotation.y = yaw
	add_child(casing)
	var stop := jamb_seal(centre, yaw)
	add_child(stop)
	# Same as every other door: its casing and stop are shown with it.
	door_fixtures.append([casing, stop])
	doors.append(door)
	gates.append(door)

## The cars themselves: one waiting in the lobby behind each refuge's door,
## and one in the cell its lift arrives at. Brushed metal, a light of its own
## and its doors stood open, because it is waiting for whoever closed the
## stage. Stepping into one is taking it.
const CAR := Vector3(2.6, 2.45, 2.3)
func build_lifts(data: Dictionary) -> void:
	for gate in data.get("gates", []):
		var out: Array = gate.get("out", [1, 0])
		var lobby := int(gate.get("beyond", -1))
		# In the lobby the car stands against the far wall, facing the door
		# the refuge is behind.
		lifts.append(build_car(data.rooms[lobby], Vector2i(-int(out[0]), -int(out[1]))) if lobby >= 0 else Vector3.ZERO)
		var arrive := int(gate.get("arrive", -1))
		if arrive < 0:
			arrivals.append(Vector3.ZERO)
			continue
		# The lobby it arrives at is the one straight under this one, and the
		# car stands against the same wall: it goes down, it does not move
		# across. That wall has no door (map_generator.gd).
		var facing := Vector2i(-int(out[0]), -int(out[1]))
		var car := build_car(data.rooms[arrive], facing)
		# People are put down in front of it, not inside it.
		arrivals.append(car + Vector3(facing.x, 0, facing.y) * 1.8)

## A car standing against the wall its opening turns away from, in the cell
## given, and the middle of it in world space.
func build_car(room: Dictionary, facing: Vector2i) -> Vector3:
	var node: Node3D = room_nodes[int(room.id)]
	var span := FLOOR.size_of(room)
	var back := Vector3(-facing.x, 0, -facing.y)
	var depth: float = span.y if absf(back.z) > 0.5 else span.x
	var centre := back * (depth * 0.5 - CAR.z * 0.5 - 0.1)
	# The mirror wall is the car's -Z and has to face the wall it backs on to.
	# The old two-way choice was right for -Z and -X only: a car backing on to
	# +Z or +X was built the other way round, a shut box with its mirror to the
	# room -- the "block, no lift" at the end of some floors.
	var yaw := atan2(-back.x, -back.z)
	var car := Node3D.new()
	car.name = "Lift"
	car.position = centre
	car.rotation.y = yaw
	node.add_child(car)
	# Floor, ceiling, the wall it backs on to and its two sides. The front is
	# the opening, so nothing is built there.
	var deep: float = CAR.z
	box(car, Vector3(0, -0.15, 0), Vector3(CAR.x, 0.3, deep), "metal", true)
	box(car, Vector3(0, CAR.y, 0), Vector3(CAR.x, 0.12, deep), "metal", true)
	box(car, Vector3(0, CAR.y * 0.5, -deep * 0.5), Vector3(CAR.x, CAR.y, 0.12), "mirror", true)
	for side in [-1.0, 1.0]:
		box(car, Vector3(side * CAR.x * 0.5, CAR.y * 0.5, 0), Vector3(0.12, CAR.y, deep), "metal", true)
		# The handrail down each side, and the panelling under it.
		box(car, Vector3(side * (CAR.x * 0.5 - 0.1), 0.92, 0), Vector3(0.05, 0.05, deep - 0.2), "gold", false, "cylinder", Vector3(PI / 2, 0, 0))
		box(car, Vector3(side * (CAR.x * 0.5 - 0.07), 0.45, 0), Vector3(0.03, 0.9, deep - 0.3), "panel")
	box(car, Vector3(0, 0.45, -deep * 0.5 + 0.07), Vector3(CAR.x - 0.3, 0.9, 0.03), "panel")
	# The leaves, slid back into the jambs, and the brass sill between them.
	for side in [-1.0, 1.0]:
		box(car, Vector3(side * (CAR.x * 0.5 - 0.16), CAR.y * 0.5, deep * 0.5), Vector3(0.28, CAR.y - 0.1, 0.1), "metal")
	box(car, Vector3(0, 0.05, deep * 0.5), Vector3(CAR.x, 0.06, 0.16), "gold")
	# Its light, which is the only one it has and never goes out with the rest.
	var panel := box_light(car, Vector3(0, CAR.y - 0.1, 0))
	car.add_child(panel)
	return node.position + centre

## The flat light in a car's ceiling: a small lamp and the panel it comes out
## of, which stays on whatever the floor is doing.
func box_light(car: Node3D, at: Vector3) -> OmniLight3D:
	box(car, at + Vector3(0, 0.03, 0), Vector3(1.0, 0.04, 0.7), "light")
	var lamp := OmniLight3D.new()
	lamp.name = "CarLight"
	lamp.position = at - Vector3(0, 0.1, 0)
	lamp.light_color = Color(0.96, 0.94, 0.86)
	lamp.light_energy = 2.4
	lamp.omni_range = 5.5
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.light_volumetric_fog_energy = 0.0
	car_lamps.append(lamp)
	return lamp

## The refuge's sign: a sheet of clear acrylic lit from the diodes buried in
## its top edge, engraved SALIDA with an arrow pointing down at the room the
## floor is left from, in an aluminium channel hung from the ceiling on a
## stem. The lettering is drawn by the light the sheet guides
## (shaders/exit_panel.gdshader); the sign also throws its own green light,
## with a shadow, like every other visible lamp in the hotel.
const EXIT_PANEL := preload("res://game/presentation/shaders/exit_panel.gdshader")
const EXIT_ENGRAVING := preload("res://assets/props/exit_sign/engraving.png")
const PANEL_SIZE := Vector2(0.62, 0.31)

## `front` is what the sheet is engraved with, read from the side it faces;
## `back`, when given, what its other face says (read from there).
func exit_sign(node: Node3D, pos: Vector3, yaw: float, ceiling: float, front: Texture2D = EXIT_ENGRAVING, back: Texture2D = null, size := PANEL_SIZE) -> void:
	var board := Node3D.new()
	board.name = "ExitSign"
	board.position = pos
	board.rotation.y = yaw
	node.add_child(board)
	var top := size.y * 0.5
	# The channel the diodes sit in, its end clamps, and the stem and canopy
	# that hang the whole thing from the ceiling.
	box(board, Vector3(0, top + 0.03, 0), Vector3(size.x + 0.06, 0.055, 0.07), "metal")
	box(board, Vector3(0, top + 0.058, 0), Vector3(size.x + 0.062, 0.006, 0.072), "black")
	for side in [-1.0, 1.0]:
		box(board, Vector3(side * (size.x * 0.5 - 0.012), top - 0.022, 0), Vector3(0.05, 0.06, 0.034), "black")
	var drop := ceiling - pos.y - top - 0.06
	box(board, Vector3(0, top + 0.06 + drop * 0.5, 0), Vector3(0.016, drop, 0.016), "metal", false, "cylinder")
	box(board, Vector3(0, ceiling - 0.01, 0), Vector3(0.1, 0.02, 0.1), "metal")
	var glass := ShaderMaterial.new()
	glass.shader = EXIT_PANEL
	glass.set_shader_parameter("engraving", front)
	if back != null:
		glass.set_shader_parameter("two_faced", true)
		glass.set_shader_parameter("engraving_back", back)
	var sheet := MeshInstance3D.new()
	sheet.name = "Panel"
	var quad := QuadMesh.new()
	quad.size = size
	sheet.mesh = quad
	sheet.material_override = glass
	exit_panels.append(glass)
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
	set_fade(lamp, EXIT_REACH - 4.0, 3.0)
	board.add_child(lamp)
	exit_lamps.append(lamp)

## The corridors' way-out signs (exit_route_signs.gd): the same lit acrylic
## as the refuge's, hung across the way most people come by, a figure running
## out of a door and an arrow on each face -- ahead, left, right or back, for
## whoever reads that face. A metre off the middle of the cell along the way
## it faces, clear of the ceiling lamp, and well over everybody's head:
## at 2.4 m, like the refuge's, it hung at the height of the players' eyes.
const ROUTE_SIGN := preload("res://game/world/generation/exit_route_signs.gd")
const WAY_ENGRAVINGS := [
	preload("res://assets/props/exit_sign/way_ahead.png"),
	preload("res://assets/props/exit_sign/way_left.png"),
	preload("res://assets/props/exit_sign/way_right.png"),
	preload("res://assets/props/exit_sign/way_back.png"),
]
const ROUTE_SIGN_OFFSET := 1.0
## A third bigger than the refuge's: it is read from down the corridor.
const ROUTE_PANEL := PANEL_SIZE * 1.35
const ROUTE_SIGN_HEIGHT := 2.65
## Where each way-out sign hangs: {room, position (world), normal, front, back}.
var route_signs: Array = []

func route_sign(sign: Dictionary) -> void:
	var room: Dictionary = manifest.rooms[int(sign.room)]
	var node: Node3D = room_nodes[int(sign.room)]
	var normal := Vector3(float(sign.normal.x), 0.0, float(sign.normal.y))
	var span := FLOOR.size_of(room)
	var reach: float = (span.x if sign.normal.x != 0 else span.y) * 0.5 - 0.45
	var height: float = float(room.height)
	var pos := normal * clampf(ROUTE_SIGN_OFFSET, 0.0, maxf(reach, 0.0)) + Vector3(0, minf(ROUTE_SIGN_HEIGHT, height - 0.45), 0)
	# The sheet's front faces +Z of its own: turned to face along the normal.
	exit_sign(node, pos, atan2(normal.x, normal.z), height, WAY_ENGRAVINGS[int(sign.front)], WAY_ENGRAVINGS[int(sign.back)], ROUTE_PANEL)
	var placed := sign.duplicate()
	placed["position"] = node.position + pos
	route_signs.append(placed)

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

## A stage given back whole after a collapse: its door shut and locked again,
## until its condition is met again. Only a restart does this.
func relock_gate(stage: int) -> void:
	for door in gates:
		if not is_instance_valid(door) or door.gate_stage != stage or door.locked: continue
		if door.opened or door.moving: door.set_state(false)
		door.locked = true

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
	lamp.shadow_bias = 0.02
	lamp.shadow_normal_bias = 0.05
	lamp.light_volumetric_fog_energy = 0.0
	lamp.light_projector = LIGHTING.profile("sconce")
	# Out of the bounce light: a wall lamp sits 25 cm from the wall, and the
	# next room's volume (bounce_light.gd) took its light in through a half
	# wall thinner than one of its voxels, lighting the far face yellow. And
	# only the nearest twelve are lit: in the bounce, one going out took its
	# glow from its own volume alone, and the corridor came out lighter on
	# one side of a cell's edge than on the other. BAKE_DYNAMIC (Godot's
	# default) is what puts a light *in* a VoxelGI; disabled keeps it out.
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
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
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
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

## The planta whose bounce light is baked (or baking), -1 for none. Only one
## at a time: a planta is some 140 lit rooms and 55 ms each on one core, the
## three of them held up the start of a floor by four seconds and their
## volumes' data never went, and the others are under a slab anyway.
var bounce_planta := -1
## The planta the last look was from (update_visibility()).
var eye_planta := 0

## Bakes a planta's lit rooms' bounce light on worker threads
## (bounce_light.gd), letting the other plantas' volumes go. A room alone, or
## a hall's cells together (one volume over the hall, if it is a rectangle; an
## L-shaped hall has none: see bounce_light.gd), or a straight stretch of
## corridor (corridor_runs()). update_visibility() asks for the planta the eye
## goes to.
func start_bounce(planta: int) -> void:
	if planta == bounce_planta or bounce.baking(): return
	bounce_planta = planta
	bounce.release(planta)
	var halls := {}
	var wanted := []
	var runs := corridor_runs(planta)
	for i in room_nodes.size():
		var room: Dictionary = manifest.rooms[i]
		if dark_room(room) or FLOOR.is_void(room) or room_planta[i] != planta: continue
		var hall := int(room.get("hall", -1))
		# Keyed by its first cell's index, which no hall uses (a hall is
		# keyed by one of its own cells, and a corridor is never in one).
		if hall < 0: hall = int(runs.get(i, -1))
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

## The planta's straight stretches of lit corridor, each baked as one volume
## like a hall: room index -> the index of its stretch's first cell. With a
## volume per cell, each was baked alone and lit by the lamps round it, and
## Godot does not blend one volume into the next (a surface takes the ones it
## lies in, normalised): walls, ceiling and floor were cut straight at every
## cell's edge, one side up to four times brighter (seed 81, rooms 18 and 19).
## A cell where two stretches cross goes to the longer; a stretch of one cell
## keeps its own volume. Where two stretches meet the cut remains, at a turn.
func corridor_runs(planta: int) -> Dictionary:
	var lit := {}
	for i in room_nodes.size():
		var room: Dictionary = manifest.rooms[i]
		if room_planta[i] == planta and bool(room.get("corridor", false)) and int(room.get("hall", -1)) < 0 and not dark_room(room) and not FLOOR.is_void(room): lit[i] = true
	var runs := []
	for way in [Vector2i(1, 0), Vector2i(0, 1)]:
		for i in lit:
			if open_between(i, FLOOR.beside(manifest.rooms[i], -way), lit): continue
			var run := [i]
			while open_between(run[-1], FLOOR.beside(manifest.rooms[run[-1]], way), lit): run.append(FLOOR.beside(manifest.rooms[run[-1]], way))
			if run.size() > 1: runs.append(run)
	runs.sort_custom(func(a: Array, b: Array) -> bool: return run_length(a) > run_length(b))
	var first := {}
	for run in runs:
		var piece := []
		for i in run + [-1]:
			if i >= 0 and not first.has(i):
				piece.append(i)
				continue
			if piece.size() > 1:
				for cell in piece: first[cell] = piece[0]
			piece = []
	return first

## Two cells of corridor open on to each other, both lit.
func open_between(a: int, b: int, lit: Dictionary) -> bool:
	return b >= 0 and lit.has(b) and open_pairs.has(Vector2i(mini(a, b), maxi(a, b)))

func run_length(run: Array) -> float:
	var metres := 0.0
	for i in run:
		var span := FLOOR.size_of(manifest.rooms[i])
		metres += maxf(span.x, span.y)
	return metres

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
		var shown: bool = decal_shown(projector)
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
	for lamp in exit_lamps:
		var size: float = PRACTICAL_SIZE * preset.penumbra
		if lamp.light_size != size: lamp.light_size = size
	# Baked the first time a preset asks for it, for the planta looked from
	# (only where a GPU can draw it: not headless, not Compatibility).
	if preset.bounce and RenderingServer.get_rendering_device() != null: start_bounce(maxi(eye_planta, 0))
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
	# With the power gone nothing blinks and nothing hums: the lamps are not
	# failing, they are dead.
	if dark: return
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
	# Four voxels to the agent's radius. At 0.2 the rasterised bake lost width
	# inside a furnished room and left the mesh cut in two, with a refuge
	# nobody could walk to (one floor in a thousand: seed 213). Finer costs
	# about half a second of the second and a half a floor takes to put up,
	# and the radius comes out exact instead of being ceiled to voxels.
	nav.cell_size = 0.1
	nav.cell_height = 0.1
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, self)
	# One region per planta, each baked from the floor it stands on. Nothing
	# joins them but the lift, so nothing a route could follow does either:
	# they are PITCH apart, far past where two regions' edges would meet.
	var plantas := {}
	for index in room_planta: plantas[index] = true
	# The whole plan, wherever the reception put the origin.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for room in manifest.rooms:
		var at := FLOOR.position_of(room)
		var half := FLOOR.size_of(room) * 0.5
		low = Vector2(minf(low.x, at.x - half.x), minf(low.y, at.z - half.y))
		high = Vector2(maxf(high.x, at.x + half.x), maxf(high.y, at.z + half.y))
	for planta in plantas:
		var mesh: NavigationMesh = nav.duplicate()
		mesh.filter_baking_aabb = AABB(Vector3(low.x - 2.0, FLOOR.planta_y(planta) - 0.5, low.y - 2.0), Vector3(high.x - low.x + 4.0, 3, high.y - low.y + 4.0))
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)
		var region := NavigationRegion3D.new()
		region.name = "Navigation_%d" % planta
		region.navigation_mesh = mesh
		add_child(region)

## Whether this room's ceiling lamp is out (deterministic per position).
func dark_room(room: Dictionary) -> bool:
	return dark_ids.has(int(room.id))

## Which rooms are dark: the ones the floor says (it draws them by seed, so
## every machine has the same).
func decide_dark(data: Dictionary) -> void:
	dark_ids.clear()
	for room in data.rooms:
		if bool(room.get("dark", false)): dark_ids[int(room.id)] = true

func add_nav_quad(vertices: PackedVector3Array, polygons: Array[PackedInt32Array], center: Vector3, low: Vector2, high: Vector2) -> void:
	var first := vertices.size()
	vertices.append_array(PackedVector3Array([center + Vector3(low.x, 0.04, low.y), center + Vector3(low.x, 0.04, high.y), center + Vector3(high.x, 0.04, high.y), center + Vector3(high.x, 0.04, low.y)]))
	polygons.append(PackedInt32Array([first, first + 1, first + 2, first + 3]))

## reach_over: the observer looking at the whole floor from above asks for
## everything to be drawn, whatever the preset would hide (0: the preset's).
## show_all: nothing is hidden at all -- every room, every door with its
## fixtures, every lamp that is not switched off, wherever they are. It is for
## looking at a floor (--observer), never for playing one: what it costs is
## exactly what the distances above exist to avoid.
## planta: the one drawn; by default the one the eye is on. Only one ever is:
## the others are under a slab, and their lamps would light through it.
func update_visibility(player_position: Vector3, shadows: bool, reach_over := 0.0, show_all := false, planta := -1) -> void:
	if building: return
	var here: int = planta if planta >= 0 else FLOOR.planta_of(player_position.y)
	eye_planta = here
	# The eye has gone down a planta (or the observer to another): its bounce.
	if preset.bounce and here != bounce_planta and RenderingServer.get_rendering_device() != null: start_bounce(here)
	curtain_material.set_shader_parameter("motion", 0.0 if reduced else 1.0)
	if is_instance_valid(dust):
		dust.position = player_position + Vector3(0, 1.2, 0)
		dust.emitting = preset.dust > 0 and not reduced and not echo_view
		dust.visible = dust.emitting
	# Hall haze only exists in Forward+ (the preset has it off elsewhere).
	for fog in fog_volumes: fog.visible = preset.floor_haze and not reduced and not echo_view
	var reach: float = maxf(preset.room_reach, reach_over)
	if show_all: reach = 100000.0
	var fade_end: float = preset.lamp_fade[0] + preset.lamp_fade[1]
	for i in room_nodes.size():
		var distance := room_nodes[i].position.distance_to(player_position)
		var on_planta: bool = i >= room_planta.size() or room_planta[i] == here
		room_nodes[i].visible = on_planta and distance < reach
		if lights[i].has_meta("void"): continue
		if not on_planta:
			lights[i].visible = false
			continue
		if show_all:
			# Every lamp of the floor at once, and none of them with a shadow:
			# a hundred shadowed lamps do not fit in the atlas, and what falls
			# out of it shines through the walls.
			lights[i].visible = not lights[i].has_meta("off") and not echo_view
			if lights[i].shadow_enabled: lights[i].shadow_enabled = false
			continue
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
	# The nearest SCONCES_LIT wall lamps and no more: over the atlas they lose
	# their shadows and light the room on the other side of the wall.
	var near_sconces := sconce_lights.filter(func(lamp: OmniLight3D) -> bool: return FLOOR.planta_of(lamp.global_position.y) == here)
	for lamp in sconce_lights:
		if FLOOR.planta_of(lamp.global_position.y) != here: lamp.visible = false
	near_sconces.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool: return sconce_order(a, player_position) < sconce_order(b, player_position))
	for k in near_sconces.size():
		near_sconces[k].visible = not dark and preset.sconce_lights and shadows and not echo_view and k < SCONCES_LIT and near_sconces[k].global_position.distance_to(player_position) < SCONCE_REACH
	# Not with the power cut (blackout() hides them; this used to bring them
	# back a quarter of a second later, lit by nothing but the torch).
	bounce.show_near(player_position, preset.bounce and not echo_view and not dark, here)
	for lamp in practicals:
		lamp.visible = not dark and not echo_view and (show_all or lamp.global_position.distance_to(player_position) < preset.furniture_lamps)
		if lamp.shadow_enabled != shadows: lamp.shadow_enabled = shadows
	# The exit signs keep theirs through a power cut: they are the one thing
	# here that would have a battery, and the refuge stays findable.
	for lamp in exit_lamps:
		lamp.visible = not echo_view and (show_all or lamp.global_position.distance_to(player_position) < EXIT_REACH)
		if lamp.shadow_enabled != shadows: lamp.shadow_enabled = shadows
	# The cars' lamps keep theirs looking at the whole floor as well: there are
	# a handful, and they fit in the atlas where a hundred room lamps do not.
	for lamp in car_lamps:
		if lamp.shadow_enabled != (shadows or show_all): lamp.shadow_enabled = shadows or show_all
	# Doors carry their light seals, casings and stops: shown as far as the
	# rooms are. No lit lamp reaches past that (its range ends inside it).
	for i in doors.size():
		var on_planta: bool = i >= door_planta.size() or door_planta[i] == here
		var shown: bool = on_planta and (show_all or doors[i].doorway.distance_to(player_position) < reach)
		doors[i].visible = shown
		for fixture in door_fixtures[i]: fixture.visible = shown

## Where a wall lamp stands in the queue for the twelve. One already lit counts
## as a metre and a half nearer, so the ones round a room do not swap places
## every time the player takes a step: a lamp going on and off as you shift
## your weight would be worse than one lamp fewer.
func sconce_order(lamp: OmniLight3D, from: Vector3) -> float:
	return lamp.global_position.distance_to(from) - (1.5 if lamp.visible else 0.0)

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
