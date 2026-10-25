extends SceneTree
## Furniture and props for the hotel (docs/REALISM.md, phase 4), step two:
## bakes each glTF in source_assets/props/<id>/ (outside git) into one mesh,
## assets/props/hotel/<id>.res: one surface per material (the materials that
## tools/props/ingest_models.py wrote beside it), at real size, floor at y = 0,
## centred on X and Z, front towards +Z, with automatic levels of detail (used
## in the shadows too).
##   python tools/props/ingest_models.py
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/props/build_catalogue.gd [-- --only=<id>] [--moving]
##   godot --headless --path . --script res://tools/props/build_catalogue.gd -- --target=res://assets/props/office/ --sources=res://assets/props/office/sources.json [--only=<slug>]
## (the offices: ingest_models.py --set=office writes sources.json, each
## model's glTF folder by its slug; --source=<res folder> takes the models from
## another folder of model folders, as SOURCE is.) YAW, SCALE, PARTS and the
## rest are looked up by that key: a hotel download's id, an office model's
## slug. The offices' Poly Haven kits the hotel bakes are left out of
## --set=office (OFFICE_HOTEL_KITS there), so no office kit needs PARTS.
## (--moving bakes only the parts of MOVING, leaving every <id>.res as it is.)
const SOURCE := "res://source_assets/props/"
const TARGET := "res://assets/props/hotel/"
## Turns that bring a model's front to +Z, where the download faces elsewhere.
const YAW := {}
## Downloads not in metres.
const SCALE := {"steel_frame_shelves_01": 0.1}
## Downloads that hold several objects side by side: each is baked on its own,
## as <id>_<name>.res, from the glTF nodes whose name matches.
## Downloads the game does not use (tools/props/ingest_models.py SKIP). The
## seven at the end are the offices' downloads (source_assets/props/ holds them
## too): left out of the hotel's bake, baked from a --sources list.
const SKIP := ["Chandelier_01", "Ottoman_01", "hanging_picture_frame_02", "modern_arm_chair_01", "round_wooden_table_01", "small_wooden_table_01", "television_02",
	"hanging_picture_frame_01", "modular_airduct_rectangular_01", "korean_fire_extinguisher_01", "korean_public_payphone_01",
	"sofa_02", "potted_plant_01", "pachira_aquatica_01", "calathea_orbifolia_01", "anthurium_botany_01", "plastic_bottle_gallon", "mid_century_lounge_chair"]
const PARTS := {
	"metal_trash_can": {"clean": "^metal_trash_can(_handle_left|_handle_right|_lid)?$", "rust": "^metal_trash_can_rust"},
	"vintage_suitcase": {"a": "^vintage_suitcase_01", "b": "^vintage_suitcase_02"},
	"wine_bottles_01": {"bordeaux": "bordeaux$", "alsace": "alsace$", "burgundy": "burgundy$", "champagne": "champagne$"},
	"office_notepads": {"a4": "^office_notepads_a4", "pad": "^office_notepads_yellow"},
	# The offices' air handler (its in-line fan and a round duct) and the
	# shaft's ladder down into the pit.
	"modular_airduct_circular_01": {"fan": "^modular_airduct_circular_fan$", "duct": "^modular_airduct_circular_single$"},
	"modular_fire_escape": {"ladder": "^modular_fire_escape_ladder_bottom$"},
	# The archives' battens over their aisles.
	"mounted_fluorescent_lights": {"batten": "^mounted_fluorescent_lights_a$"},
	# The pneumatic tubes: a straight metre of steel pipe, stretched along
	# each run of the tube tree.
	"modular_pipes": {"straight": "^pipe_100cm_metal$"},
}
## Clocks, whose hands turn in the game (hotel_geometry.gd, tell_time): each
## hand is baked apart, as <id>_<hand>.res -- pointing at twelve, turning
## about +Z at its own origin, with where that origin is in the body's mesh
## kept in its "pivot" -- and the body without them, with their names in its
## "hands". A hand is a glTF node (a pattern for its name: its origin is the
## axis) or, where the model has its hands in the body's own mesh, the loose
## pieces of that mesh inside a box (in the model's own space, grown 2 mm),
## with the dial's centre said.
const CLOCKS := {
	"wall_clock": {"hour": "hours_hand$", "minute": "minute_hand$", "second": "second_hand$"},
	"alarm_clock_01": {"hour": "^houd_hand$", "minute": "^minute_hand$", "second": "^second_hand$"},
	"vintage_grandfather_clock_01": {"hour": "houd_hand$", "minute": "minute_hand$"},
	"mantel_clock_01": {"centre": Vector3(0, 0.0915, 0.048), "hour": AABB(Vector3(-0.004, 0.087, 0.047), Vector3(0.039, 0.009, 0.001)), "minute": AABB(Vector3(-0.004, 0.087, 0.048), Vector3(0.008, 0.051, 0.0005))},
}
## Furniture that is gone through (hotel_container.gd), whose drawers and
## doors come as nodes of their own: baked apart as well, for the piece that
## has been searched, which is drawn in parts with one of them left open (the
## merged <id>.res is baked as ever, for every other). <id>_body.res is the
## piece without them; each part is <id>_<kind>_<n>.res, n the number its
## node ends in (the capture), about its node's origin -- the hinge, for a
## door -- with where that is in the body's mesh kept in its "pivot" and its
## extent there in its "box". The body lists them in its "parts". The commode
## calls its three drawers doors; the glazed cabinet's three upper doors are
## glass, its four lower ones wood. A pattern with no number in it is part 0.
## A download of several (PARTS) is baked so each of its own: the suitcases
## each with their lid, whose node's origin is the hinge, along the bottom edge
## at the seam (the author's word, 21 October 2026: a suitcase opens).
const MOVING := {
	"GothicCommode_01": {"drawer": "_door0(\\d)$"},
	"painted_wooden_cabinet": {"drawer": "_drawer_0(\\d)$", "door": "_door_0(\\d)$"},
	"drawer_cabinet": {"drawer": "_drawer_0(\\d)$"},
	"vintage_cabinet_01": {"door": "_door_0([2567])$", "glass": "_door_0([134])$"},
	"vintage_suitcase": {"lid": "_top$"},
	"power_box_01": {"door": "_door$"},
}
## Downloads that come with something open which the game shows shut: the
## nodes whose name matches are baked with their own turn taken out, as they
## were modelled, in the merged piece and in its parts. The fuse box came with
## its door swung wide; shut, it is the electrical panel that only the key
## opens (game/world/interactables/hotel_panel.gd).
const SHUT := {"power_box_01": "_door$"}
## Downloads that come as a rack: things hung one above another, to be seen
## from the front. The nodes whose name matches are put where they would be
## with the rack laid flat on its back (what was up is towards the front),
## each on whichever of its sides is the lower and a little askew, and every
## node is set down on the floor by itself. The stationery is a cup with its
## pencils and pens in a column beside it and its eraser over it: on a desk
## they floated there.
const LAID := {"stationery_supplies": "_(pen|pencil)_|_eraser$"}
## How far askew, at most (radians either way).
const ASKEW := 0.06
var failed := false
## Where the meshes go (--target=): the hotel's unless told.
var target := TARGET

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var only := ""
	var folder := ProjectSettings.globalize_path(SOURCE)
	var sources: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		if argument.begins_with("--source="): folder = ProjectSettings.globalize_path(argument.trim_prefix("--source=").trim_suffix("/") + "/")
		if argument.begins_with("--target="): target = argument.trim_prefix("--target=").trim_suffix("/") + "/"
		if argument.begins_with("--sources="):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--sources=")))
			if not parsed is Dictionary:
				print("CATALOGUE_FAILED sources ", argument)
				quit(1)
				return
			sources = parsed
	var moving_only := OS.get_cmdline_user_args().has("--moving")
	var models: Array = Array(DirAccess.get_directories_at(folder))
	if not sources.is_empty():
		models = sources.keys()
		models.sort()
	for model in models:
		# The hotel's SKIP is about source_assets/props/: a list of sources says itself what to bake.
		if (not only.is_empty() and model != only) or (sources.is_empty() and model in SKIP): continue
		var place: String = ProjectSettings.globalize_path(String(sources[model])) if not sources.is_empty() else folder + model
		if MOVING.has(model):
			if PARTS.has(model):
				for part in PARTS[model]: bake_moving(model, place, part, PARTS[model][part])
			else: bake_moving(model, place)
		if moving_only: continue
		if CLOCKS.has(model):
			bake_clock(model, place)
		elif PARTS.has(model):
			for part in PARTS[model]: bake(model, place, part, PARTS[model][part])
		else:
			bake(model, place)
	quit(1 if failed else 0)

## Every mesh under node with its transform from the scene's root and the
## name of its node.
func collect_named(node: Node, xform: Transform3D, out: Array) -> void:
	var here := xform
	if node is Node3D: here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null: out.append([node.mesh, here, String(node.name)])
	for child in node.get_children(): collect_named(child, here, out)

## The lowest and the highest a mesh reaches, stood as `xform` has it.
func heights(mesh: Mesh, xform: Transform3D) -> Vector2:
	var reach := Vector2(INF, -INF)
	for surface in mesh.get_surface_count():
		for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var y: float = (xform * vertex).y
			reach = Vector2(minf(reach.x, y), maxf(reach.y, y))
	return reach

## Which loose piece of a surface each of its vertices is in: vertices at
## the same place are one, and so is whatever a triangle joins.
static func pieces_of(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	var place := {}
	var welded := PackedInt32Array()
	welded.resize(vertices.size())
	for i in vertices.size():
		var key := Vector3i((vertices[i] * 100000.0).round())
		if not place.has(key): place[key] = place.size()
		welded[i] = place[key]
	var parent: Array = range(place.size())
	for t in range(0, indices.size(), 3):
		var a := root_of(parent, welded[indices[t]])
		parent[root_of(parent, welded[indices[t + 1]])] = a
		parent[root_of(parent, welded[indices[t + 2]])] = a
	var result := PackedInt32Array()
	result.resize(vertices.size())
	for i in vertices.size(): result[i] = root_of(parent, welded[i])
	return result

static func root_of(parent: Array, start: int) -> int:
	var root := start
	while parent[root] != root: root = parent[root]
	while parent[start] != root:
		var next: int = parent[start]
		parent[start] = root
		start = next
	return root

## A clock: its body and each of its hands (CLOCKS).
func bake_clock(model: String, folder: String) -> void:
	var file := ""
	for entry in DirAccess.get_files_at(folder):
		if entry.ends_with(".gltf") or entry.ends_with(".glb"): file = entry
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(folder + "/" + file, state) != OK:
		print("CATALOGUE_FAILED ", model, " (glTF)")
		failed = true
		return
	var scene := document.generate_scene(state)
	var parts := []
	collect_named(scene, Transform3D.IDENTITY, parts)
	var spec: Dictionary = CLOCKS[model]
	var turn := Transform3D(Basis(Vector3.UP, YAW.get(model, 0.0)).scaled(Vector3.ONE * SCALE.get(model, 1.0)), Vector3.ZERO)
	# The same fit as any model's, from the whole of it: the body stays
	# where it was with its hands in it.
	var bounds := AABB()
	var first := true
	for piece in parts:
		var mesh: Mesh = piece[0]
		for surface in mesh.get_surface_count():
			for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = turn * (piece[1] * vertex)
				bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
				first = false
	var fit := Transform3D(Basis.IDENTITY, -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)) * turn
	var hand_names: Array = spec.keys().filter(func(key): return key != "centre")
	# What goes where: "" is the body. Each: material -> a SurfaceTool.
	var tools := {"": {}}
	var pivots := {}
	var points := {}
	for hand in hand_names:
		tools[hand] = {}
		points[hand] = PackedVector3Array()
	for piece in parts:
		var mesh: Mesh = piece[0]
		var whole: Transform3D = fit * piece[1]
		var node_hand := ""
		for hand in hand_names:
			if spec[hand] is String and RegEx.create_from_string(spec[hand]).search(String(piece[2])) != null: node_hand = hand
		if node_hand != "": pivots[node_hand] = whole.origin
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vertices.size()))
			var normals = arrays[Mesh.ARRAY_NORMAL]
			var uvs = arrays[Mesh.ARRAY_TEX_UV]
			var tangents = arrays[Mesh.ARRAY_TANGENT]
			var material := mesh.surface_get_material(surface)
			var key := safe(material.resource_name) if material != null else "material"
			# The loose pieces of this surface that are a hand's (a model with
			# its hands in its body): those wholly inside the hand's box.
			var vertex_hand := PackedStringArray()
			vertex_hand.resize(vertices.size())
			if node_hand == "" and hand_names.any(func(hand): return spec[hand] is AABB):
				var piece_of := pieces_of(vertices, indices)
				var boxes := {}
				for i in vertices.size():
					var id := piece_of[i]
					boxes[id] = AABB(vertices[i], Vector3.ZERO) if not boxes.has(id) else (boxes[id] as AABB).expand(vertices[i])
				var owner := {}
				for id in boxes:
					for hand in hand_names:
						if spec[hand] is AABB and (spec[hand] as AABB).grow(0.002).encloses(boxes[id]): owner[id] = hand
				for i in vertices.size(): vertex_hand[i] = owner.get(piece_of[i], "")
			for t in range(0, indices.size(), 3):
				var where: String = node_hand if node_hand != "" else vertex_hand[indices[t]]
				if not tools[where].has(key):
					tools[where][key] = SurfaceTool.new()
					tools[where][key].begin(Mesh.PRIMITIVE_TRIANGLES)
				var tool: SurfaceTool = tools[where][key]
				for corner in 3:
					var i := indices[t + corner]
					if normals != null: tool.set_normal((whole.basis * normals[i]).normalized())
					if uvs != null: tool.set_uv(uvs[i])
					if tangents != null:
						var along := (whole.basis * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])).normalized()
						tool.set_tangent(Plane(along, tangents[i * 4 + 3]))
					tool.add_vertex(whole * vertices[i])
					if where != "": points[where].append(whole * vertices[i])
	if spec.has("centre"):
		for hand in hand_names:
			if not pivots.has(hand): pivots[hand] = fit * (spec.centre as Vector3)
	for where in tools:
		if tools[where].is_empty() or (where != "" and not pivots.has(where)):
			print("CATALOGUE_FAILED ", model, " (no ", where if where != "" else "body", ")")
			failed = true
			scene.free()
			return
	for where in tools:
		# A hand: about its axis, and stood up to point at twelve, whatever
		# hour its model was left at.
		var stand := Transform3D.IDENTITY
		if where != "":
			var pivot: Vector3 = pivots[where]
			var tip := pivot
			for p in points[where]:
				if Vector2(p.x - pivot.x, p.y - pivot.y).length() > Vector2(tip.x - pivot.x, tip.y - pivot.y).length(): tip = p
			stand = Transform3D(Basis(Vector3(0, 0, 1), atan2(tip.x - pivot.x, tip.y - pivot.y)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
		var importer := ImporterMesh.new()
		var triangles := 0
		for key in tools[where]:
			var tool: SurfaceTool = tools[where][key]
			tool.index()
			var arrays := tool.commit_to_arrays()
			if where != "":
				var moved := SurfaceTool.new()
				moved.begin(Mesh.PRIMITIVE_TRIANGLES)
				var holder := ArrayMesh.new()
				holder.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				moved.append_from(holder, 0, stand)
				moved.index()
				arrays = moved.commit_to_arrays()
			if arrays[Mesh.ARRAY_TANGENT] == null and arrays[Mesh.ARRAY_TEX_UV] != null:
				tool = SurfaceTool.new()
				tool.create_from_arrays(arrays)
				tool.generate_tangents()
				arrays = tool.commit_to_arrays()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var path: String = target + model + "/" + key + ".tres"
			var material: Material = load(path) if ResourceLoader.exists(path) else null
			if material == null: print("CATALOGUE_WARNING ", model, " has no ", path)
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, material, key)
		if where == "": importer.generate_lods(60.0, 25.0, [])
		var result := importer.get_mesh()
		var name: String = model + (("_" + String(where)) if where != "" else "")
		result.resource_name = name
		if where == "": result.set_meta("hands", PackedStringArray(hand_names))
		else: result.set_meta("pivot", pivots[where])
		ResourceSaver.save(result, target + name + ".res")
		var size := result.get_aabb().size
		print("CATALOGUE %s size=(%.3f, %.3f, %.3f) triangles=%d surfaces=%d%s" % [name, size.x, size.y, size.z, triangles, result.get_surface_count(), "" if where == "" else " pivot=%s" % pivots[where]])
	scene.free()

## A piece that is gone through, in parts (MOVING); one of several in its
## download (PARTS), from the nodes whose name matches `pattern`.
func bake_moving(model: String, folder: String, part := "", pattern := "") -> void:
	var file := ""
	for entry in DirAccess.get_files_at(folder):
		if entry.ends_with(".gltf") or entry.ends_with(".glb"): file = entry
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(folder + "/" + file, state) != OK:
		print("CATALOGUE_FAILED ", model, " (glTF)")
		failed = true
		return
	var scene := document.generate_scene(state)
	shut(scene, model)
	var pieces := []
	collect_named(scene, Transform3D.IDENTITY, pieces)
	if not pattern.is_empty():
		var own := RegEx.create_from_string(pattern)
		pieces = pieces.filter(func(piece): return own.search(String(piece[2])) != null)
	var baked := model + ("_" + part if not part.is_empty() else "")
	var turn := Transform3D(Basis(Vector3.UP, YAW.get(model, 0.0)).scaled(Vector3.ONE * SCALE.get(model, 1.0)), Vector3.ZERO)
	# The same fit as the merged piece's, from the whole of it: the body and
	# its parts stay where they are in it.
	var bounds := AABB()
	var first := true
	for piece in pieces:
		var mesh: Mesh = piece[0]
		for surface in mesh.get_surface_count():
			for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = turn * (piece[1] * vertex)
				bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
				first = false
	var fit := Transform3D(Basis.IDENTITY, -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)) * turn
	var spec: Dictionary = MOVING[model]
	# What goes where: "" is the body. Each: material -> a SurfaceTool.
	var tools := {"": {}}
	var pivots := {}
	var boxes := {}
	for piece in pieces:
		var mesh: Mesh = piece[0]
		var whole: Transform3D = fit * piece[1]
		var where := ""
		for kind in spec:
			var found := RegEx.create_from_string(spec[kind]).search(String(piece[2]))
			if found != null: where = "%s_%s" % [kind, found.get_string(1) if found.get_group_count() >= 1 else "0"]
		var shift := Transform3D.IDENTITY
		if where != "":
			if pivots.has(where):
				print("CATALOGUE_FAILED ", model, " (two nodes for ", where, ")")
				failed = true
			pivots[where] = whole.origin
			shift = Transform3D(Basis.IDENTITY, -whole.origin)
			tools[where] = {}
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			var key := safe(material.resource_name) if material != null else "material"
			if not tools[where].has(key):
				tools[where][key] = SurfaceTool.new()
				tools[where][key].begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[where][key].append_from(mesh, surface, shift * whole)
			if where != "":
				for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = whole * vertex
					boxes[where] = AABB(p, Vector3.ZERO) if not boxes.has(where) else (boxes[where] as AABB).expand(p)
	var names := tools.keys().filter(func(where): return where != "")
	names.sort()
	if names.is_empty() or tools[""].is_empty():
		print("CATALOGUE_FAILED ", model, " (no parts)")
		failed = true
		scene.free()
		return
	for where in tools:
		var importer := ImporterMesh.new()
		var triangles := 0
		for key in tools[where]:
			var tool: SurfaceTool = tools[where][key]
			tool.index()
			var arrays := tool.commit_to_arrays()
			if arrays[Mesh.ARRAY_TANGENT] == null and arrays[Mesh.ARRAY_TEX_UV] != null:
				tool = SurfaceTool.new()
				tool.create_from_arrays(arrays)
				tool.generate_tangents()
				arrays = tool.commit_to_arrays()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var path: String = target + model + "/" + key + ".tres"
			var material: Material = load(path) if ResourceLoader.exists(path) else null
			if material == null: print("CATALOGUE_WARNING ", model, " has no ", path)
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, material, key)
		importer.generate_lods(60.0, 25.0, [])
		var result := importer.get_mesh()
		var name: String = baked + "_" + (String(where) if where != "" else "body")
		result.resource_name = name
		if where == "": result.set_meta("parts", PackedStringArray(names))
		else:
			result.set_meta("pivot", pivots[where])
			result.set_meta("box", boxes[where])
		ResourceSaver.save(result, target + name + ".res")
		var size := result.get_aabb().size
		print("CATALOGUE %s size=(%.3f, %.3f, %.3f) triangles=%d surfaces=%d%s" % [name, size.x, size.y, size.z, triangles, result.get_surface_count(), "" if where == "" else " pivot=%s box=%s" % [pivots[where], boxes[where]]])
	scene.free()

## What SHUT says to show shut: those nodes with their turn taken out.
func shut(node: Node, model: String) -> void:
	if not SHUT.has(model): return
	var pattern := RegEx.create_from_string(SHUT[model])
	for child in node.find_children("*", "Node3D", true, false):
		if pattern.search(String(child.name)) != null: (child as Node3D).basis = Basis.from_scale((child as Node3D).basis.get_scale())

static func safe(name: String) -> String:
	var regex := RegEx.create_from_string("[^A-Za-z0-9_]+")
	var result := regex.sub(name, "_", true).strip_edges()
	while result.begins_with("_"): result = result.substr(1)
	while result.ends_with("_"): result = result.left(-1)
	return result if not result.is_empty() else "material"

## Every mesh under node (whose name matches, if a pattern is given), with
## its transform from the scene's root.
func collect(node: Node, xform: Transform3D, out: Array, pattern: RegEx) -> void:
	var here := xform
	if node is Node3D: here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		if pattern == null or pattern.search(String(node.name)) != null: out.append([node.mesh, here])
	for child in node.get_children(): collect(child, here, out, pattern)

func bake(model: String, folder: String, part := "", pattern := "") -> void:
	var file := ""
	for entry in DirAccess.get_files_at(folder):
		if entry.ends_with(".gltf") or entry.ends_with(".glb"): file = entry
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(folder + "/" + file, state) != OK:
		print("CATALOGUE_FAILED ", model, " (glTF)")
		failed = true
		return
	var scene := document.generate_scene(state)
	shut(scene, model)
	var parts := []
	collect(scene, Transform3D.IDENTITY, parts, RegEx.create_from_string(pattern) if not pattern.is_empty() else null)
	if LAID.has(model):
		var named := []
		collect_named(scene, Transform3D.IDENTITY, named)
		var flat := RegEx.create_from_string(LAID[model])
		var over := Basis(Vector3.RIGHT, PI / 2.0)
		parts = []
		for piece in named:
			var stood: Transform3D = piece[1]
			if flat.search(String(piece[2])) != null:
				var turned := Transform3D(over * stood.basis, over * stood.origin)
				var moved := Transform3D(stood.basis, over * stood.origin)
				stood = turned if heights(piece[0], turned).y - heights(piece[0], turned).x < heights(piece[0], moved).y - heights(piece[0], moved).x else moved
				stood.basis = Basis(Vector3.UP, (float(String(piece[2]).hash() % 1000) / 500.0 - 1.0) * ASKEW) * stood.basis
			parts.append([piece[0], Transform3D(Basis.IDENTITY, Vector3(0, -heights(piece[0], stood).x, 0)) * stood])
	var name := model + ("_" + part if not part.is_empty() else "")
	if parts.is_empty():
		print("CATALOGUE_FAILED ", name, " (no mesh)")
		failed = true
		return
	var turn := Transform3D(Basis(Vector3.UP, YAW.get(model, 0.0)).scaled(Vector3.ONE * SCALE.get(model, 1.0)), Vector3.ZERO)
	var bounds := AABB()
	var first := true
	for piece in parts:
		var mesh: Mesh = piece[0]
		for surface in mesh.get_surface_count():
			for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = turn * (piece[1] * vertex)
				bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
				first = false
	var fit := Transform3D(Basis.IDENTITY, -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)) * turn
	# One surface per material.
	var groups := {}
	for piece in parts:
		var mesh: Mesh = piece[0]
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			var key := safe(material.resource_name) if material != null else "material"
			if not groups.has(key):
				groups[key] = SurfaceTool.new()
				groups[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key].append_from(mesh, surface, fit * piece[1])
	var importer := ImporterMesh.new()
	var triangles := 0
	for key in groups:
		var tool: SurfaceTool = groups[key]
		tool.index()
		var arrays := tool.commit_to_arrays()
		if arrays[Mesh.ARRAY_TANGENT] == null and arrays[Mesh.ARRAY_TEX_UV] != null:
			tool = SurfaceTool.new()
			tool.create_from_arrays(arrays)
			tool.generate_tangents()
			arrays = tool.commit_to_arrays()
		triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
		var path: String = target + model + "/" + key + ".tres"
		var material: Material = load(path) if ResourceLoader.exists(path) else null
		if material == null:
			print("CATALOGUE_WARNING ", model, " has no ", path)
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, material, key)
	importer.generate_lods(60.0, 25.0, [])
	var result := importer.get_mesh()
	result.resource_name = name
	ResourceSaver.save(result, target + name + ".res")
	var size := result.get_aabb().size
	print("CATALOGUE %s size=(%.2f, %.2f, %.2f) triangles=%d surfaces=%d" % [name, size.x, size.y, size.z, triangles, result.get_surface_count()])
	scene.free()
