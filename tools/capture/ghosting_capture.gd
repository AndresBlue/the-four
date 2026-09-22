extends SceneTree
## What a reconstruction does with something moving: whether it smears it, and
## whether it leaves a trail behind it. The creature is walked across the view
## at a fixed speed, the same walk in every mode (fixed frames, fixed steps),
## and the picture is taken with it still moving. Every mode is then compared
## with the same frame drawn whole, at full resolution: that is the truth this
## measures against, over the frame and over the strip the creature has just
## walked out of, which is where a trail hangs. The floor under the readings is
## printed too -- the same picture one frame later, which is never identical.
##
## Measured on seed 81 at 0.6 (levels of 0..255, lower is closer to the truth):
## the floor is 0.45; TAA at full resolution 6.66; the plain stretch 6.20;
## FSR 1.0 5.66; FSR 2.2 1.86. Nothing here says a trail: the temporal one is
## the closest to the truth of the lot, with a third of the pixels drawn.
##
##   godot --path . --rendering-method forward_plus --fixed-fps 60 \
##     --script tools/capture/ghosting_capture.gd -- [--seed=81] [--scale=0.6]
## Writes evidence/ghost_<mode>.png and prints GHOST lines with the readings.
## Forward+ only: Compatibility has no FSR.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Metres the creature covers per frame, and how many frames it walks before
## the picture is taken: a second of walking at about 3 m/s.
const STEP := 0.05
const FRAMES := 60
var level

func _initialize() -> void: run.call_deferred()

## The creature walks from left to right in front of the camera, and the frame
## is taken with it still moving.
func walk(name: String, mode: int, scale: float) -> void:
	root.scaling_3d_mode = mode
	root.scaling_3d_scale = scale
	var start: Vector3 = level.player.global_position - level.player.global_basis.z * 4.5 + level.player.global_basis.x * 1.5
	var across: Vector3 = -level.player.global_basis.x
	level.locust.global_position = start
	level.locust.rotation.y = level.player.rotation.y + PI * 0.5
	# Its own history gone, and the camcorder's iris settled on this picture:
	# it meters the whole frame, and a change of mode moves it enough to swamp
	# the reading.
	for i in 150:
		level.locust.velocity = Vector3.ZERO
		await process_frame
	for i in FRAMES:
		level.locust.global_position = start + across * (STEP * (i + 1))
		level.locust.velocity = across * (STEP * 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/ghost_%s.png" % name)
	# And the very next frame, with everything carrying on as it was: two
	# pictures of the same walk, one frame apart, which is the floor under
	# every reading (the picture is never identical to itself).
	level.locust.global_position = start + across * (STEP * (FRAMES + 1))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/ghost_%s_next.png" % name)

## How far a moving picture is from the truth: the same frame of the same walk
## drawn at full resolution, which every mode is compared with. The walk is the
## same in every mode (fixed frames, fixed steps), so the creature is in the
## same place with the same legs; what differs is what the mode did with it.
func compare(name: String) -> void:
	var native := Image.load_from_file("res://evidence/ghost_native.png")
	var shot := Image.load_from_file("res://evidence/ghost_%s.png" % name)
	var next := Image.load_from_file("res://evidence/ghost_%s_next.png" % name)
	if native == null or shot == null or next == null or native.get_size() != shot.get_size(): return
	print("GHOST %s %s" % [name, reading(native, shot)])
	if name == "native": print("GHOST %s (fondo, un fotograma después) %s" % [name, reading(native, next)])

## The difference between two pictures, whole and over the strip the creature
## walked out of. Levels of 0..255, averaged per pixel, and the worst pixel.
func reading(native: Image, shot: Image) -> String:
	var size := native.get_size()
	var whole := 0.0
	var trail := 0.0
	var worst := 0.0
	var trail_pixels := 0
	for y in range(0, size.y, 2):
		for x in range(0, size.x, 2):
			var difference: float = absf(native.get_pixel(x, y).get_luminance() - shot.get_pixel(x, y).get_luminance()) * 255.0
			whole += difference
			# Behind it: the side it came from.
			if x > size.x * 0.45 and x < size.x * 0.75 and y > size.y * 0.3 and y < size.y * 0.85:
				trail += difference
				worst = maxf(worst, difference)
				trail_pixels += 1
	var samples: float = float(size.x * size.y) / 4.0
	return "whole=%.2f trail=%.2f worst=%.0f" % [whole / samples, trail / maxf(float(trail_pixels), 1.0), worst]

func run() -> void:
	var seed_value := 81
	var scale := 0.6
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--scale="): scale = float(argument.trim_prefix("--scale="))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(seed_value)
	level.settings.values.quality = 2
	level.apply_settings()
	level.player.torch.visible = true
	# The tape's own grain and wobble change every frame and would drown the
	# reading; this is about what the reconstruction leaves, not the tape.
	for key in ["vhs", "scanlines", "grain", "chromatic"]: level.settings.values[key] = 0.0
	level.settings.values.reduced = true
	level.apply_settings()
	# Nothing of its own: it stands where it is put, frame by frame.
	level.locust.set_physics_process(false)
	level.locust.grace = 999.0
	for i in 60: await process_frame
	for pair in [["native", Viewport.SCALING_3D_MODE_BILINEAR], ["taa", Viewport.SCALING_3D_MODE_BILINEAR], ["bilinear", Viewport.SCALING_3D_MODE_BILINEAR], ["fsr1", Viewport.SCALING_3D_MODE_FSR], ["fsr2", Viewport.SCALING_3D_MODE_FSR2]]:
		# Native and the plain stretch are the two without reconstruction;
		# "taa" is native with the engine's own temporal smoothing, which is
		# what a trail is usually blamed on.
		root.use_taa = pair[0] == "taa" or pair[0] == "native"
		await walk(pair[0], pair[1], 1.0 if pair[0] in ["native", "taa"] else scale)
		compare(pair[0])
	print("GHOSTING listo")
	quit()
