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
	var brief = level.ui.brief
	print("SHOT %s · %.2f s de viaje · aviso %s" % [name, float(level.boarding.get("time", -1.0)),
		("%d escala %s" % [brief.get_instance_id(), str(brief.get_child(0).scale)]) if is_instance_valid(brief) else "no"])

func frames(count: int) -> void:
	for i in count: await process_frame

## By the clock, not by frames: the notice's own tween runs on seconds, and a
## capture draws as many frames a second as the machine gives it.
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
	# The ride is 3.2 s: the picture goes over the first third of a second, the
	# card is up for most of the middle, and it clears at the end.
	var beats := {"board": 6, "dark": 24, "card": 60, "hold": 60, "clearing": 36, "out": 24}
	for beat in beats:
		await frames(int(beats[beat]))
		await shot(beat)
	# Out of the car: the notice of the sector, and the set going off at the
	# end of it.
	await seconds(1.0)
	await shot("brief")
	# The set going off: a quarter of a second of fade in, the hold, and then
	# the picture falls to a line (0.22 s) and the line closes (0.16 s).
	var off_at: float = 0.25 + level.ui.BRIEF_HOLD - 0.65
	await seconds(off_at + 0.12 - 1.0)
	await shot("brief_off")
	await seconds(0.17)
	await shot("brief_line")
	# And where it is kept afterwards: the pause screen.
	level.session.pause()
	await frames(20)
	await shot("pause")
	print("TRANSIT listo")
	quit()
