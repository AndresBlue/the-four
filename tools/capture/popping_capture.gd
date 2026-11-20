extends SceneTree
## Pictures of what popped: for chosen records of tools/dev/popping_probe.gd,
## the view from a step before and from where it popped, the same look, after
## the floor's rounds have caught up with each place. Run on the code before
## and after a fix, the four pictures of a record show the pop and its end.
##
##   godot --path . --script res://tools/capture/popping_capture.gd -- --test-profile --automation --silent --no-enemy --floor=2 --seed=81 --quality=3 --pops=res://evidence/popping/base_q3.json --picks=3,17 --prefix=antes [--size=1920x1080] [--back=0.8]
##
## Writes evidence/popping/shots/<prefix>_<pick>_a.png (the step before) and
## _b.png (where it popped). Needs a window.
const BACKGROUND := preload("res://tools/capture/background_window.gd")
var level


func _initialize() -> void: run.call_deferred()


func run() -> void:
	BACKGROUND.configure()
	var seed_value := 81
	var quality := 3
	var source := ""
	var picks: Array = []
	var prefix := "shot"
	var size := Vector2i(1920, 1080)
	var back := 0.8
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--pops="): source = argument.trim_prefix("--pops=")
		if argument.begins_with("--picks="): picks = Array(argument.trim_prefix("--picks=").split(",")).map(func(p): return int(p))
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
		if argument.begins_with("--back="): back = float(argument.trim_prefix("--back="))
		if argument.begins_with("--size="): size = Vector2i(int(argument.trim_prefix("--size=").get_slice("x", 0)), int(argument.trim_prefix("--size=").get_slice("x", 1)))
	var pops: Array = JSON.parse_string(FileAccess.get_file_as_string(source)).pops
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(quality)
	await level.start_floor(seed_value)
	await level.bounce_ready()
	if OS.get_cmdline_user_args().has("--background"): BACKGROUND.release_input(level)
	DisplayServer.window_set_size(size)
	level.player.set_physics_process(false)
	var out := "res://evidence/popping/shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for pick in picks:
		var pop: Dictionary = pops[pick]
		var eye := Vector3(pop.eye[0], pop.eye[1], pop.eye[2])
		var look := Vector3(pop.look[0], 0.0, pop.look[2]).normalized()
		for shot in [["a", eye - look * back], ["b", eye]]:
			await stand(shot[1], look, eye.y)
			root.get_texture().get_image().save_png("%s/%s_%d_%s.png" % [out, prefix, pick, shot[0]])
		print("POPPING_SHOT %d %s %s at %.1f m" % [pick, pop.how, pop.what, pop.distance])
	quit(0)


## Puts the eye at `at` looking along `look`, and lets a second of the floor's
## rounds (four a second) and drawing go by.
func stand(at: Vector3, look: Vector3, _eye_y: float) -> void:
	level.player.rotation.y = atan2(-look.x, -look.z)
	await process_frame
	var offset: Vector3 = level.player.camera.global_position - level.player.global_position
	level.player.global_position = at - offset
	for frame in 70: await process_frame
	await RenderingServer.frame_post_draw
