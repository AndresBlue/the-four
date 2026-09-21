extends SceneTree
## The camcorder at a frame time no machine should ever see. A real floor is
## started and the look is flicked from side to side every frame while the game
## runs at whatever --fixed-fps says; what is reported is whether the picture
## is still a number, and how far the hand-held spring threw it.
##
## Below about 8 FPS the explicit integration this was written for diverged:
## the spring gained energy every frame until the rotation left the range of a
## float, and a camera whose rotation is NaN draws nothing -- through the menu
## and into the next match, because the body is the same node.
##
##   godot --headless --path . --fixed-fps 5 --script tools/dev/low_fps_camera.gd \
##       -- --automation --handheld --silent
const FRAMES := 600

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	var player = level.player
	player.handheld_enabled = true
	level.settings.set_value("reduced", false)
	player.active = true
	var began: float = player.hand_clock
	var worst_sway := 0.0
	var worst_pitch := 0.0
	var broke := -1
	for i in FRAMES:
		# A hand that will not keep still: a flick one way, then the other.
		player.turn_delta += Vector2(0.6 if i % 2 == 0 else -0.6, 0.35 if i % 3 == 0 else -0.35)
		await process_frame
		worst_sway = maxf(worst_sway, player.sway.length()) if player.sway.is_finite() else INF
		worst_pitch = maxf(worst_pitch, absf(player.camera.rotation.x)) if player.camera.rotation.is_finite() else INF
		if broke < 0 and not player.camera.rotation.is_finite(): broke = i
	# The frame time the game actually saw, out of the hand's own clock.
	var step: float = (player.hand_clock - began) / float(FRAMES)
	print("LOW_FPS_CAMERA %.1f FPS · %d cuadros · roto: %s · muelle máx %.4f · cabeceo máx %.4f rad · mirada %s" % [
		1.0 / maxf(step, 0.0001), FRAMES,
		("cuadro %d" % broke) if broke >= 0 else "no",
		worst_sway, worst_pitch,
		"número" if is_finite(player.look_pitch()) else "NaN"])
	quit(0 if broke < 0 else 1)
