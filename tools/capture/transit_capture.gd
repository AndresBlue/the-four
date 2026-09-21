extends SceneTree
## The cut between one wing and the next, as it is played: the survivor steps
## into the car, the picture goes, the card says which wing this is and what
## the stage asks for, and the picture comes back somewhere else. Frames by the
## clock of the ride itself.
##   godot --path . --script tools/capture/transit_capture.gd -- --silent
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/transit_%s.png" % name)
	print("SHOT %s · %.2f s de viaje" % [name, float(level.boarding.get("time", -1.0))])

func frames(count: int) -> void:
	for i in count: await process_frame

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	await frames(120)
	# The stage is closed the way a team closes it, and the survivor steps into
	# the car that is waiting behind the door.
	level.session.goal["ready"] = true
	level.session.changed.emit()
	await frames(6)
	level.player.global_position = level.hotel.lifts[0] + Vector3(0, 0.04, 0)
	# The ride is 3.2 s: the picture goes over the first third of a second, the
	# card is up for most of the middle, and it clears at the end.
	var beats := {"board": 6, "dark": 24, "card": 60, "hold": 60, "clearing": 36, "out": 24}
	for beat in beats:
		await frames(int(beats[beat]))
		await shot(beat)
	print("TRANSIT listo")
	quit()
