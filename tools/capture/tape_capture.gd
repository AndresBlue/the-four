extends SceneTree
## The tape's look over the game itself, to set beside the author's references
## (evidence/referencias/vhs): the picture held, with its edges, its bottom
## strip and the camcorder's lettering; a field whose colour came off wrong;
## the snow of a lost signal; and the picture found as a tape starts. Into
## evidence/vhs/<prefix>_*.png. With a window.
##   godot --path . --script tools/capture/tape_capture.gd -- --automation --test-profile --silent [--prefix=game] [--seed=81]
var level
var prefix := "game"
var floor_seed := 81
var lit_room := 2
const FLOOR := preload("res://game/world/generation/floor_definition.gd")

func _initialize() -> void: run.call_deferred()

func shot(name: String, frames := 2) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/vhs/%s_%s.png" % [prefix, name])
	print("SHOT ", name)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
		if argument.begins_with("--seed="): floor_seed = int(argument.trim_prefix("--seed="))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/vhs"))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await level.start_floor(floor_seed)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -50, 0)
	# The floor's first view, and the benchmark's lit room (hotel_benchmark.gd).
	await shot("llegada", 60)
	var room: Dictionary = level.manifest.rooms[lit_room]
	level.player.position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	level.player.rotation.y = 0.65
	level.player.camera.rotation.x = -0.1
	level.hotel.update_visibility(level.player.position, true)
	await shot("still", 60)
	await shot("still_b", 7)
	# The picture as it is found, eight moments of it.
	for step in [0.96, 0.82, 0.68, 0.54, 0.4, 0.3, 0.16, 0.05]:
		level.rig.entry = step
		await shot("entry_%02d" % int(step * 100.0))
	level.rig.entry = 0.0
	# The tracking band is somewhere else every few seconds.
	for i in 3: await shot("band_%d" % i, 200)
	# One field of colour gone wrong, three times over: each is different.
	level.post_material.set_shader_parameter("chroma_slip", 1.0)
	for i in 3: await shot("slip_%d" % i, 3)
	level.post_material.set_shader_parameter("chroma_slip", 0.0)
	# The signal lost.
	level.rig.lost_signal = 2.0
	await shot("snow", 30)
	await shot("snow_b", 1)
	level.rig.lost_signal = 0.0
	# The lowest preset's three reads a pixel, and then reduced effects: the
	# first keeps the tape's frame, the second has none of it.
	level.post_material.set_shader_parameter("lite", true)
	await shot("lite", 90)
	level.post_material.set_shader_parameter("lite", false)
	level.settings.values.reduced = true
	level.rig.apply_settings()
	await shot("reduced", 30)
	paused = false
	level.queue_free()
	await process_frame
	print("TAPE listo")
	quit()
