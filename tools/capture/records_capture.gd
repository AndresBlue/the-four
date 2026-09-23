extends SceneTree
## The two screens a floor ends on: the report of the tape that just got out,
## and the board of the ones before it. Made up lines, so the pictures always
## show a full board.
##
##   godot --path . --script tools/capture/records_capture.gd
## Writes evidence/records_report.png and evidence/records_board.png.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	var records = level.records
	records.save_path = "user://capture_records.json"
	records.runs = []
	for line in [
		{"floor": 1, "company": records.SOLO, "players": 1, "time": 1284.0, "deaths": 0, "hides": 2, "escaped": 1, "seed": 4417},
		{"floor": 1, "company": records.SOLO, "players": 1, "time": 1502.0, "deaths": 1, "hides": 0, "escaped": 1, "seed": 81},
		{"floor": 1, "company": records.COOP, "players": 3, "time": 1105.0, "deaths": 1, "hides": 4, "escaped": 2, "seed": 9071},
		{"floor": 1, "company": records.COOP, "players": 4, "time": 1390.0, "deaths": 0, "hides": 0, "escaped": 4, "seed": 22118},
	]: records.record(line)
	var run := {
		"floor": 1, "company": records.COOP, "players": 3, "time": 1042.0,
		"sectors": [318.0, 701.0, 1042.0], "deaths": 0, "hides": 0, "escaped": 3, "seed": 81,
		"team": [
			{"seat": 1, "name": "Andrés", "escaped": true, "digits": 2},
			{"seat": 2, "name": "Camila", "escaped": true, "digits": 1},
			{"seat": 3, "name": "Rodrigo", "escaped": true, "digits": 1},
		],
	}
	level.ui.elapsed = float(run.time)
	level.ui.places = records.record(run)
	level.ui.summary = run
	level.ui.menu("won")
	for i in 150: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/records_report.png")
	level.ui.menu("records")
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/records_board.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_records.json"))
	print("RECORDS listo")
	level.queue_free()
	await process_frame
	quit()
