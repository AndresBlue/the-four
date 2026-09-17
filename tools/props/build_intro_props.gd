extends SceneTree
## Bakes the supplied CRT television and bed into meshes for the opening scene.
## Output space: floor at y = 0, centred on X/Z, front facing +Z, real size.
##   godot --headless --path . --script res://tools/props/build_intro_props.gd
const OUT := "res://assets/props/"
## Model, parts to keep, yaw applied first, target size along "axis" (x, z or the
## longest horizontal side) and material per part (none keeps the slot empty for
## a runtime material, as the TV screen needs).
## The bedroom set is a bed (head at -Z) with a desk and chair on its +X side.
const JOBS := [
	{"source": "res://assets/props/tv/old_tv.fbx", "parts": {"TV_body_low": "tv/tv_body.res", "TV_screen_low": "tv/tv_screen.res"}, "yaw": 0.0, "axis": "long", "size": 0.62, "materials": {"TV_body_low": "res://game/presentation/materials/tv_body.tres"}},
	{"source": "res://assets/props/bedroom/bedroom_set.fbx", "parts": {"SM_Bed_01": "bedroom/bed.res"}, "yaw": 0.0, "axis": "z", "size": 2.1, "materials": {"SM_Bed_01": "res://game/presentation/materials/bed.tres"}},
]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for job in JOBS:
		var scene: Node3D = load(job.source).instantiate()
		root.add_child(scene)
		var turn := Basis(Vector3.UP, job.yaw)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false).filter(func(m): return job.parts.has(String(m.name)))
		var bounds := AABB()
		var first := true
		for mesh in meshes:
			for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = turn * (mesh.global_transform * vertex)
				bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
				first = false
		var along: float = bounds.size.z if job.axis == "z" else bounds.size.x if job.axis == "x" else maxf(bounds.size.x, bounds.size.z)
		var factor: float = job.size / along
		var offset := -Vector3(bounds.position.x + bounds.size.x * 0.5, bounds.position.y, bounds.position.z + bounds.size.z * 0.5)
		var fit := Transform3D(Basis.from_scale(Vector3.ONE * factor), Vector3.ZERO) * Transform3D(Basis.IDENTITY, offset) * Transform3D(turn, Vector3.ZERO)
		for mesh in meshes:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.append_from(mesh.mesh, 0, fit * mesh.global_transform)
			tool.generate_tangents()
			var baked := tool.commit()
			var material_path: String = job.materials.get(String(mesh.name), "")
			if not material_path.is_empty(): baked.surface_set_material(0, load(material_path))
			ResourceSaver.save(baked, OUT + job.parts[String(mesh.name)])
			var uvs: PackedVector2Array = baked.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			var uv_bounds := Rect2(uvs[0], Vector2.ZERO)
			for uv in uvs: uv_bounds = uv_bounds.expand(uv)
			print("BAKED ", job.parts[String(mesh.name)], " aabb=", baked.get_aabb(), " uv=", uv_bounds)
			# Mattress top: the highest vertices in the middle of the length, per X band.
			if job.axis == "z":
				var bands := {}
				for vertex in baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					if absf(vertex.z) < 0.3:
						var key := snappedf(vertex.x, 0.2)
						bands[key] = maxf(bands.get(key, 0.0), vertex.y)
				var keys := bands.keys()
				keys.sort()
				print("PROFILE ", keys.map(func(k): return "%.1f:%.2f" % [k, bands[k]]))
		scene.queue_free()
	quit()
