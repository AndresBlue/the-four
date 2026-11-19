extends SceneTree
## The tape in motion, filmed by the engine's movie writer: what a still cannot
## show (how the edges creep, how the snow moves, how the picture settles as it
## is found). Two films, into evidence/vhs/: the boot from its notice to the
## menu, and a floor's picture found, held, lost to snow and found again.
##   godot --path . --rendering-method forward_plus --write-movie evidence/vhs/arranque.avi --fixed-fps 60 --script res://tools/capture/tape_movie.gd -- --test-profile --silent --part=boot
##   godot --path . --rendering-method forward_plus --write-movie evidence/vhs/entrada.avi --fixed-fps 60 --script res://tools/capture/tape_movie.gd -- --automation --test-profile --silent --part=entry
## At 60 frames a second, which is what tools/capture/film_check.py counts
## flashes by. tools/capture/film_strip.py lays their frames out on a sheet and
## makes a GIF.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await process_frame

func seconds(length: float) -> void:
	await frames(int(round(length * 60.0)))

func run() -> void:
	var part := "boot"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--part="): part = argument.trim_prefix("--part=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	if part == "boot":
		# Without --automation the game plays its boot by itself.
		await frames(5)
		while is_instance_valid(level.ui.intro): await process_frame
		await seconds(1.5)
	else:
		await process_frame
		await level.start_floor(81)
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -50, 0)
		# The benchmark's lit room (hotel_benchmark.gd).
		var room: Dictionary = level.manifest.rooms[2]
		level.player.position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
		level.player.rotation.y = 0.65
		level.player.camera.rotation.x = -0.1
		level.hotel.update_visibility(level.player.position, true)
		await seconds(2.5)
		# The picture found, as the rig plays it when a floor starts.
		level.rig.entry = 1.0
		await seconds(3.0)
		# Lost to snow, and back.
		level.rig.lost_signal = 1.0
		await seconds(3.5)
	print("MOVIE listo")
	quit()
