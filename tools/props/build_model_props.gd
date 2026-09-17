extends SceneTree
## Bakes supplied furniture models into single meshes (one surface per
## material) in prop space: floor at y = 0, centred on X/Z, front facing +Z,
## at real size. Wall pieces keep their back at z = 0 instead of centring.
##   godot --headless --path . --script res://tools/props/build_model_props.gd
const MATERIALS := "res://game/presentation/materials/"
## source, output, parts (mesh name: material, "" keeps the slot for a runtime
## material), yaw applied first, axis the size refers to (x, y, z or long) and
## anchor ("centre" or "wall").
## The bedroom set is a bed (head at -Z) with a desk and chair on its +X side.
const JOBS := [
	{"source": "res://assets/props/tv/old_tv.fbx", "output": "", "split": {"TV_body_low": "res://assets/props/tv/tv_body.res", "TV_screen_low": "res://assets/props/tv/tv_screen.res"}, "parts": {"TV_body_low": "tv_body.tres", "TV_screen_low": ""}, "yaw": 0.0, "axis": "long", "size": 0.62, "anchor": "centre"},
	{"source": "res://assets/props/bedroom/bedroom_set.fbx", "output": "res://assets/props/bedroom/bed.res", "parts": {"SM_Bed_01": "bed.tres"}, "yaw": 0.0, "axis": "z", "size": 2.1, "anchor": "centre"},
	{"source": "res://assets/props/sofa/sofa.fbx", "output": "res://assets/props/sofa/sofa.res", "parts": {"Sofa": "sofa.tres"}, "yaw": 0.0, "axis": "x", "size": 2.15, "anchor": "centre"},
	{"source": "res://assets/props/wall_lamp/wall_lamp.fbx", "output": "res://assets/props/wall_lamp/wall_lamp.res", "parts": {"Wall Lamp": ["wall_lamp_metal.tres", "wall_lamp_cloth.tres"], "Wall Lamp - Light Bulb": "wall_lamp_bulb.tres"}, "yaw": 0.0, "axis": "y", "size": 0.42, "anchor": "wall"},
	{"source": "res://assets/props/monstera/monstera.fbx", "output": "res://assets/props/monstera/monstera.res", "parts": {"Leaves": "monstera_leaf.tres", "root_HP_1": "monstera_leaf.tres", "Stand": "monstera_pot.tres", "Pot_LP": "monstera_pot.tres"}, "yaw": 0.0, "axis": "y", "size": 1.35, "anchor": "centre"},
]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
	for job in JOBS:
		if not only.is_empty() and not job.source.contains(only): continue
		bake(job)
	quit()

func bake(job: Dictionary) -> void:
	var scene: Node3D = load(job.source).instantiate()
	root.add_child(scene)
	var turn := Basis(Vector3.UP, job.yaw)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false).filter(func(m): return job.parts.has(String(m.name)))
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = turn * (mesh.global_transform * vertex)
				bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
				first = false
	var along: float = {"x": bounds.size.x, "y": bounds.size.y, "z": bounds.size.z}.get(job.axis, maxf(bounds.size.x, bounds.size.z))
	var factor: float = job.size / along
	var offset := -Vector3(bounds.position.x + bounds.size.x * 0.5, bounds.position.y, bounds.position.z if job.anchor == "wall" else bounds.position.z + bounds.size.z * 0.5)
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * factor), Vector3.ZERO) * Transform3D(Basis.IDENTITY, offset) * Transform3D(turn, Vector3.ZERO)
	# Surfaces grouped by material so each material is one surface of the result.
	var groups := {}
	var split: Dictionary = job.get("split", {})
	for mesh in meshes:
		var assigned = job.parts[String(mesh.name)]
		for surface in mesh.mesh.get_surface_count():
			var material: String = assigned[surface] if assigned is Array else assigned
			var key: String = (String(mesh.name) + ":" if split.has(String(mesh.name)) else "") + material
			if not groups.has(key):
				groups[key] = SurfaceTool.new()
				groups[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key].append_from(mesh.mesh, surface, fit * mesh.global_transform)
	var combined := ArrayMesh.new()
	for key in groups:
		var tool: SurfaceTool = groups[key]
		tool.generate_tangents()
		var material: String = key.get_slice(":", 1) if key.contains(":") else key
		if split.is_empty():
			tool.commit(combined)
			if not material.is_empty(): combined.surface_set_material(combined.get_surface_count() - 1, load(MATERIALS + material))
		else:
			var alone := tool.commit()
			if not material.is_empty(): alone.surface_set_material(0, load(MATERIALS + material))
			ResourceSaver.save(alone, split[key.get_slice(":", 0)])
			print("BAKED ", split[key.get_slice(":", 0)], " aabb=", alone.get_aabb())
	if split.is_empty():
		ResourceSaver.save(combined, job.output)
		print("BAKED ", job.output, " surfaces=", combined.get_surface_count(), " aabb=", combined.get_aabb())
	scene.queue_free()
