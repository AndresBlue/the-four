extends SceneTree
## The creature of the second floor (assets/enemies/lurker/lurker.glb) set
## inside the hotel only to be looked at: in a lit corridor, its back to a
## wall, holding the pose of the author's reference picture (the loom clip),
## filmed from low down the way that picture was. Nothing of the game drives
## it; it is there to compare with the picture (docs/LURKER.md).
##   godot --path . --rendering-method forward_plus --script res://tools/capture/lurker_capture.gd -- --automation --test-profile --no-enemy --silent [--label=name] [--clip=loom] [--at=0.0]
## Writes evidence/lurker/<label>_<shot>_raw.png and _vhs.png: one with the
## corridor's own light, one with the torch on.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const SIZE := Vector2i(1920, 1080)
const CORRIDOR := 11
var level
var out_dir := "res://evidence/lurker"
var label := "current"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var clip := "loom"
	var at := 0.0
	var distance := 1.55
	var eye := 0.95
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--clip="): clip = argument.trim_prefix("--clip=")
		if argument.begins_with("--at="): at = float(argument.trim_prefix("--at="))
		if argument.begins_with("--distance="): distance = float(argument.trim_prefix("--distance="))
		if argument.begins_with("--eye="): eye = float(argument.trim_prefix("--eye="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.settings.set_designed(PRESETS.HIGH)
	await level.bounce_ready()
	DisplayServer.window_set_size(SIZE)
	level.player.set_physics_process(false)
	# The player would put its eye back at standing height every frame.
	level.player.set_process(false)
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	var room := pick()
	if room.is_empty():
		print("LURKER no lit corridor")
		quit(1)
		return
	var centre := FLOOR.position_of(room)
	var span: Vector2 = FLOOR.size_of(room)
	# Its back to the long wall of the corridor, facing across it.
	var along_x := span.x >= span.y
	var back := Vector3(0, 0, -1) if along_x else Vector3(-1, 0, 0)
	var half := (span.y if along_x else span.x) * 0.5
	var spot := centre + back * (half - 0.62)
	spot.y = 0.0
	var beast: Node3D = load("res://assets/enemies/lurker/lurker.glb").instantiate()
	level.add_child(beast)
	beast.global_position = spot
	beast.rotation.y = 0.0 if along_x else PI * 0.5
	report(beast)
	var player: AnimationPlayer = beast.find_child("AnimationPlayer", true, false)
	print("LURKER clips ", player.get_animation_list())
	player.play(clip)
	player.seek(at, true)
	player.speed_scale = 0.0
	# The camera low and close, a little to one side, looking up at the face.
	var from := spot - back * distance + (Vector3(0.03, 0, 0) if along_x else Vector3(0, 0, 0.03))
	level.player.global_position = Vector3(from.x, 0.04, from.z)
	level.player.eye_height = eye
	level.player.camera.position = Vector3(0, eye, 0)
	level.player.rotation.y = 0.0 if along_x else PI * 0.5
	level.player.camera.rotation.x = 0.16
	level.player.snap_torch()
	level.player.torch.visible = false
	await capture("lit")
	level.player.torch.visible = true
	level.player.snap_torch()
	await capture("torch")
	level.queue_free()
	await process_frame
	quit()

func lit(room: Dictionary) -> bool:
	return not level.hotel.lights[int(room.id)].has_meta("off")

func pick() -> Dictionary:
	for room in level.manifest.rooms:
		if int(room.get("hall", -1)) >= 0 and int(room.hall) != int(room.id): continue
		if int(room.type) == CORRIDOR and lit(room): return room
	return {}

func report(beast: Node3D) -> void:
	for mesh_instance in beast.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var material = mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				print("LURKER %s/%d %s vertex_color=%s specular=%.2f rough=%.2f cull=%d" % [mesh_instance.name, surface, material.resource_name,
					material.vertex_color_use_as_albedo, material.metallic_specular, material.roughness, material.cull_mode])

func capture(shot: String) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	level.hotel.flicker_clock = 0.4
	level.hotel._process(0.0)
	level.hotel.set_process(false)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1500: await process_frame
	# The objective's lines belong to playing, not to this picture.
	level.ui.visible = false
	var screen: CanvasItem = level.get_node("Presentation/Analog/Screen")
	var lens: CanvasLayer = level.get_node("Presentation/Lens")
	var camcorder: CanvasLayer = level.get_node("Presentation/Camcorder")
	level.set_process(false)
	screen.visible = false
	lens.visible = false
	camcorder.visible = false
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_%s_raw.png" % [label, shot])
	screen.visible = true
	lens.visible = true
	camcorder.visible = true
	level.set_process(true)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_%s_vhs.png" % [label, shot])
	level.hotel.set_process(true)
	print("LURKER ", shot)
