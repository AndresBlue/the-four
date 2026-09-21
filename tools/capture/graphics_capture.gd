extends SceneTree
## Fixed-view visual comparison. Usage after "--": --prefix=name [--quality=2]
## Places the camera for inspection only; it is not a walkthrough.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var prefix := "graphics"

func _initialize() -> void: run.call_deferred()

func shot(filename: String, torch := false, dark_room := -1) -> void:
	level.hotel.update_visibility(level.player.position, true)
	level.player.torch.visible = torch
	var energies := {}
	if dark_room >= 0:
		# Blackout for flashlight inspection; restored after the capture.
		for lamp in level.hotel.lights + level.hotel.practicals:
			energies[lamp] = lamp.light_energy
			lamp.light_energy = 0.0
	for i in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s_%s.png" % [prefix, filename])
	for lamp in energies: lamp.light_energy = energies[lamp]

func look(from: Vector3, target: Vector3, pitch := -0.05) -> void:
	level.player.position = from + Vector3(0, 0.04, 0)
	var d := target - from
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(pitch, 0, 0)

func first_room(test: Callable) -> Dictionary:
	for room in level.manifest.rooms:
		if test.call(room): return room
	return {}

func run() -> void:
	var quality := 2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The tape screen plays over everything for its first seconds and these
	# shots are about what is behind it.
	level.ui.finish_intro()
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -50, 0)
	level.settings.values.quality = quality
	level.apply_settings()
	# Reception, looking across the lobby.
	look(Vector3(0, 0, 4.5), Vector3(0, 0, -5))
	await shot("reception")
	var bedroom := first_room(func(r): return r.type == 1 and r.hall == -1)
	var c := FLOOR.position_of(bedroom)
	look(c + Vector3(1.2, 0, 1.2), c + Vector3(-4.5, 0, -4.5), -0.18)
	await shot("bedroom")
	var bath := first_room(func(r): return r.type in [4, 7] and r.hall == -1)
	c = FLOOR.position_of(bath)
	look(c + Vector3(1.0, 0, 1.0), c + Vector3(-4.5, 0, -4.5), -0.15)
	await shot("service")
	for edge in level.manifest.merged:
		var a := FLOOR.position_of(level.manifest.rooms[edge[0]])
		var b := FLOOR.position_of(level.manifest.rooms[edge[1]])
		look(a - (b - a).normalized() * 3.0, b)
		await shot("salon")
		break
	var corridor := first_room(func(r): return r.type in [11, 12] and r.hall == -1)
	c = FLOOR.position_of(corridor)
	look(c + Vector3(2.5, 0, 2.5), c + Vector3(-5, 0, -3), -0.1)
	await shot("torch", true, int(corridor.id))
	look(Vector3(0, 0, 3.0), Vector3(0, 0, -3))
	level.locust.position = Vector3(0, 0.04, -2.2)
	level.locust.rotation.y = 0
	await shot("locust")
	paused = false
	level.queue_free()
	await process_frame
	quit()
