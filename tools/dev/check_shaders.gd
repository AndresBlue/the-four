extends SceneTree
## Loads every shader under game/ and actually draws it, so compile errors
## surface. Must run WITH a window: under --headless the dummy rasterizer makes
## shader_set_code a no-op, so a broken shader loads without one complaint.
## A shader is only compiled once something using it is rendered, hence the
## throwaway mesh and the two frames.
##
##   godot --path . --script res://tools/dev/check_shaders.gd
##
## Godot reports compile failures through the log, not through the API, so
## verify.ps1 also greps the run's log for SHADER ERROR.
var failed := 0
var checked := 0

func _initialize() -> void: run.call_deferred()

func collect(path: String, out: Array) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	for name in directory.get_directories(): collect(path + "/" + name, out)
	for name in directory.get_files():
		if name.ends_with(".gdshader"): out.append(path + "/" + name)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SHADERS_SKIPPED headless")
		quit(0)
		return
	var paths: Array = []
	collect("res://game", paths)
	paths.sort()
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3)
	holder.add_child(camera)
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	holder.add_child(mesh)
	for path in paths:
		# Fog shaders exist only where there is volumetric fog: the OpenGL
		# renderer refuses the type, and nothing loads them there.
		if RenderingServer.get_current_rendering_method() == "gl_compatibility" and FileAccess.get_file_as_string(path).contains("shader_type fog"): continue
		var shader: Shader = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if shader == null:
			print("BROKEN ", path)
			failed += 1
			continue
		var material := ShaderMaterial.new()
		material.shader = shader
		mesh.material_override = material
		await process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		checked += 1
		# An empty uniform list on a shader that declares uniforms is a
		# reliable sign the code did not compile on this device.
		var declared := shader.code.contains("uniform ")
		if declared and shader.get_shader_uniform_list().is_empty():
			print("NO_UNIFORMS ", path)
			failed += 1
	mesh.material_override = null
	print("SHADERS_CHECKED ", checked, " SHADERS_BROKEN ", failed)
	holder.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
