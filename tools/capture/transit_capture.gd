extends SceneTree
## What a floor says of its sectors, as it is played: the card it opens on,
## the picture found when the card is cut, the notice of what the sector wants
## (the first anybody gets, with its warning in red; and the offices', which
## are the longest); then the cut between one wing and the next, with its card
## on the black, and the notice on arriving. At the author's own wear of the
## tape (35 %), which is where they have to be read. Frames by the clock of
## the ride itself. Without --automation: with it a floor has no card.
##   godot --path . --script tools/capture/transit_capture.gd -- --test-profile --silent
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/office_floor.gd")
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
	# --large: a screen bigger than the layout, where what is drawn small and
	# stretched shows.
	DisplayServer.window_set_size(Vector2i(1920, 1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	level.settings.values.vhs = 0.35
	level.settings.values.first_game_done = false
	await level.start_floor(81)
	level.rig.apply_settings()
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	await seconds(1.0)
	await shot("opening")
	while is_instance_valid(level.ui.transit): await process_frame
	for step in ["a", "b", "c", "d"]:
		await frames(4)
		await shot("found_" + step)
	await seconds(1.6)
	await shot("notice_warning")
	await seconds(2.6)
	await shot("notice_first")
	level.ui.show_brief(OFFICE.title_of(2), String(OFFICE.STAGES[1].brief))
	await seconds(0.15)
	await shot("notice_coming")
	await seconds(1.0)
	await shot("notice_office")
	level.ui.show_brief(OFFICE.title_of(1), level.lifts.FIRST_BRIEF, OFFICE.FIRST_LEAD, level.lifts.FIRST_HOLD)
	await seconds(3.2)
	await shot("notice_office_first")
	level.ui.hide_brief()
	# All that the foot of the picture can have at once, each on its own line
	# (the level's own loop stopped, which would take them away again), and
	# the word under the brackets.
	level.set_process(false)
	level.set_physics_process(false)
	level.ui.subtitle.visible = true
	level.ui.show_controls([[["W"], "Asomarte", []], [["E"], "Salir", []], [["MANTÉN", "E"], "Salir sin ruido", []], [["F"], "Linterna", []]])
	level.camcorder.notice.text = "LA CAZA EMPIEZA EN 12"
	level.camcorder.notice.visible = true
	level.camcorder.focus_label.text = "CERRAR"
	level.camcorder.focus_label.modulate.a = 1.0
	level.ui.subtitle.text = "[Pasos en el pasillo, cada vez más cerca de la puerta]"
	level.ui.hint.text = "OBSERVANDO A CAMILA, E PARA CAMBIAR"
	await seconds(0.8)
	await shot("foot")
	level.ui.hint.text = ""
	level.ui.subtitle.text = ""
	level.camcorder.notice.text = ""
	level.hints.notice(level.coffee.FELT, level.coffee.FELT_FOR)
	await seconds(0.8)
	await shot("foot_coffee")
	level.hints.clear()
	level.set_process(true)
	level.set_physics_process(true)
	await frames(30)
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
	# Out of the car, with the notice of the sector, and where what it asks
	# for is kept: the pause.
	await seconds(1.0)
	await shot("arrived")
	await seconds(1.2)
	await shot("notice")
	level.session.pause()
	await frames(20)
	await shot("pause")
	print("TRANSIT listo")
	quit()
