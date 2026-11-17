extends SceneTree
## The cut between one wing and the next, as it is played: the survivor steps
## into the car, the picture goes to black, and it comes back somewhere else.
## Nothing is written on the black or after it (the author, 16 November 2026).
## Frames by the clock of the ride itself.
##   godot --path . --script tools/capture/transit_capture.gd -- --silent
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/transit_%s.png" % name)
	print("SHOT %s · %.2f s de viaje" % [name, float(level.lifts.boarding.get("time", -1.0))])

func frames(count: int) -> void:
	for i in count: await process_frame

func seconds(span: float) -> void:
	var until := Time.get_ticks_msec() + int(span * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

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
	await frames(2)
	level.match_net.call_lift(0)
	# The ride (lifts.RIDE_TIME): the doors shut, the picture goes, the black
	# holds through the middle, and it clears as the doors open down there.
	var beats := {"board": 1.0, "dark": 1.2, "card": 2.0, "hold": 2.0, "clearing": 1.6, "out": 1.0}
	for beat in beats:
		await seconds(float(beats[beat]))
		await shot(beat)
	# Out of the car, and where what the sector asks for is kept: the pause.
	await seconds(1.0)
	await shot("arrived")
	level.session.pause()
	await frames(20)
	await shot("pause")
	print("TRANSIT listo")
	quit()
