extends SceneTree
## Furniture and props for the hotel (docs/REALISM.md, phase 4), step two:
## bakes each glTF in source_assets/props/<id>/ (outside git) into one mesh,
## assets/props/hotel/<id>.res: one surface per material (the materials that
## tools/props/ingest_models.py wrote beside it), at real size, floor at y = 0,
## centred on X and Z, front towards +Z, with automatic levels of detail (used
## in the shadows too).
##   python tools/props/ingest_models.py
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/props/build_catalogue.gd [-- --only=<id>]
const SOURCE := "res://source_assets/props/"
const TARGET := "res://assets/props/hotel/"
## Turns that bring a model's front to +Z, where the download faces elsewhere.
const YAW := {}
## Downloads not in metres.
const SCALE := {"steel_frame_shelves_01": 0.1}
## Downloads that hold several objects side by side: each is baked on its own,
## as <id>_<name>.res, from the glTF nodes whose name matches.
## Downloads the game does not use (tools/props/ingest_models.py SKIP).
const SKIP := ["Chandelier_01", "Ottoman_01", "hanging_picture_frame_02", "metal_office_desk", "modern_arm_chair_01", "round_wooden_table_01", "small_wooden_table_01", "television_02",
	"Chandelier_02", "hanging_picture_frame_01", "vintage_cabinet_01", "modular_airduct_rectangular_01", "korean_fire_extinguisher_01", "korean_public_payphone_01"]
const PARTS := {
	"metal_trash_can": {"clean": "^metal_trash_can(_handle_left|_handle_right|_lid)?$", "rust": "^metal_trash_can_rust"},
	"vintage_suitcase": {"a": "^vintage_suitcase_01", "b": "^vintage_suitcase_02"},
	"wine_bottles_01": {"bordeaux": "bordeaux$", "alsace": "alsace$", "burgundy": "burgundy$", "champagne": "champagne$"},
	"office_notepads": {"a4": "^office_notepads_a4", "pad": "^office_notepads_yellow"},
}
var failed := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
	var folder := ProjectSettings.globalize_path(SOURCE)
	for model in DirAccess.get_directories_at(folder):
		if (not only.is_empty() and model != only) or model in SKIP: continue
		if PARTS.has(model):
			for part in PARTS[model]: bake(model, folder + model, part, PARTS[model][part])
		else:
			bake(model, folder + model)
	quit(1 if failed else 0)

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
	var parts := []
	collect(scene, Transform3D.IDENTITY, parts, RegEx.create_from_string(pattern) if not pattern.is_empty() else null)
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
		var path: String = TARGET + model + "/" + key + ".tres"
		var material: Material = load(path) if ResourceLoader.exists(path) else null
		if material == null:
			print("CATALOGUE_WARNING ", model, " has no ", path)
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, material, key)
	importer.generate_lods(60.0, 25.0, [])
	var result := importer.get_mesh()
	result.resource_name = name
	ResourceSaver.save(result, TARGET + name + ".res")
	var size := result.get_aabb().size
	print("CATALOGUE %s size=(%.2f, %.2f, %.2f) triangles=%d surfaces=%d" % [name, size.x, size.y, size.z, triangles, result.get_surface_count()])
	scene.free()
