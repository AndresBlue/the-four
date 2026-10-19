extends SceneTree
## The screens the marks are read on, photographed with made up lines so the
## pictures always show something: the report of a tape that has just got out,
## tab by tab, the report of one that did not (and its team), the main menu,
## the marks with their boards, the career and the cards side by side, the
## achievements, the archive with a file open, and the loading screen's
## controls.
##
##   godot --path . --script tools/capture/records_capture.gd -- --test-profile
## Writes evidence/records_<screen>.png.
const SCORE := preload("res://game/services/run_score.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String, frames := 40) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/records_%s.png" % name)

func member(seat: int, name: String, out: bool, more: Dictionary) -> Dictionary:
	var base := {"seat": seat, "name": name, "escaped": out, "digits": 0, "tvs": 0, "code": 0, "searched": 4, "rooms": 30, "escapes": 0, "chases": 1, "chased": 12, "sectors": 3, "deaths": 0, "hides": 0, "hidden": 0, "metres": 700, "run": 150, "closest": 6.5, "low": 55, "burnt": 0, "lifts": 0}
	base.merge(more, true)
	return base

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	var records = level.records
	records.save_path = "user://capture_records.json"
	records.runs = []
	records.career = {}
	records.milestones = {}
	records.rivals = {}
	level.settings.values.player_name = "Andrés"
	# Boards with something on them.
	for sample in [
		[records.SOLO, 1, 1284.0, 0, 2, 4417, ["Andrés"]],
		[records.SOLO, 1, 1502.0, 0, 0, 81, ["Andrés"]],
		[records.SOLO, 1, 1731.0, 0, 5, 30662, ["Andrés"]],
		[records.COOP, 3, 1105.0, 1, 4, 9071, ["Andrés", "Camila", "Rodrigo"]],
		[records.COOP, 4, 1390.0, 0, 0, 22118, ["Andrés", "Camila", "Rodrigo", "Valentina"]],
		[records.COOP, 2, 1650.0, 2, 1, 5120, ["Andrés", "Camila"]],
	]:
		var team: Array = []
		var names: Array = sample[6]
		for index in names.size():
			team.append(member(index + 1, names[index], index < int(sample[1]) - int(sample[3]) or int(sample[3]) == 0, {"tvs": 2 - index % 2, "digits": 1 if index < 4 else 0, "code": 1 if index == 0 else 0, "deaths": 1 if index == names.size() - 1 and int(sample[3]) > 0 else 0, "hides": int(sample[4]) if index == 0 else 0, "escapes": index % 3}))
		var third: float = float(sample[2]) / 3.0
		records.file(SCORE.settle({"floor": 1, "company": sample[0], "mode": "coop", "players": int(sample[1]), "time": sample[2], "par": 2400.0, "stage": 3, "sectors": [third * 0.8, third * 1.9, sample[2]], "deaths": sample[3], "hides": sample[4], "escaped": int(sample[1]) - (1 if int(sample[3]) > 0 else 0), "seed": sample[5], "team": team}), 1)
	# People played with.
	records.keep_card({"id": "aaaa0001", "name": "Camila", "part": "SABUESO", "floors": 9, "lost": 4, "solo_time": 1190, "coop_time": 1105, "best_score": 9120, "best_grade": "S", "mvps": 3, "tvs": 31, "digits": 22, "escapes": 14, "deaths": 6, "time": 21400, "milestones": 11})
	records.keep_card({"id": "aaaa0002", "name": "Rodrigo", "part": "CEBO", "floors": 4, "lost": 7, "solo_time": -1, "coop_time": 1105, "best_score": 8340, "best_grade": "A", "mvps": 1, "tvs": 12, "digits": 5, "escapes": 23, "deaths": 15, "time": 16800, "milestones": 6})
	records.played_with("aaaa0001")
	records.played_with("aaaa0001")
	records.played_with("aaaa0002")
	# The floor that has just ended: three out of three, a fast one.
	var tape := {
		"floor": 1, "company": records.COOP, "mode": "coop", "players": 3, "time": 1042.0, "par": 2400.0, "stage": 3,
		"sectors": [318.0, 701.0, 1042.0], "deaths": 1, "hides": 2, "restarts": 0, "escaped": 3, "seed": 81,
		"team": [
			member(1, "Andrés", true, {"tvs": 3, "digits": 1, "code": 1, "escapes": 1, "metres": 912, "run": 240, "rooms": 41, "searched": 9, "closest": 3.2, "low": 38}),
			member(2, "Camila", true, {"tvs": 2, "digits": 3, "metres": 1104, "run": 120, "rooms": 52, "searched": 14, "chases": 0, "chased": 0, "closest": 9.1, "low": 61, "hides": 2, "hidden": 74}),
			member(3, "Rodrigo", true, {"tvs": 1, "escapes": 3, "chases": 4, "chased": 96, "deaths": 1, "sectors": 3, "metres": 1380, "run": 610, "rooms": 37, "closest": 0.9, "low": 4, "burnt": 1}),
		],
		"events": [
			{"t": 62.0, "k": "lift", "s": 2, "st": 1}, {"t": 318.0, "k": "sector", "s": 0, "st": 1, "n": 1},
			{"t": 371.5, "k": "tv", "s": 1, "st": 2, "n": 1, "of": 3}, {"t": 402.0, "k": "escape", "s": 3, "st": 2, "n": 22},
			{"t": 455.0, "k": "tv", "s": 2, "st": 2, "n": 2, "of": 3}, {"t": 455.2, "k": "dark", "s": 0, "st": 2},
			{"t": 531.0, "k": "death", "s": 3, "st": 2}, {"t": 588.0, "k": "tv", "s": 1, "st": 2, "n": 3, "of": 3},
			{"t": 690.0, "k": "lift", "s": 1, "st": 2}, {"t": 701.0, "k": "sector", "s": 0, "st": 2, "n": 2},
			{"t": 742.0, "k": "digit", "s": 2, "st": 3, "n": 1, "w": "HABITACIÓN 214"}, {"t": 790.0, "k": "tv", "s": 2, "st": 3, "n": 1, "of": 3},
			{"t": 803.0, "k": "burnt", "s": 3, "st": 3}, {"t": 836.0, "k": "digit", "s": 2, "st": 3, "n": 2, "w": "LAVANDERÍA"},
			{"t": 861.0, "k": "tv", "s": 1, "st": 3, "n": 2, "of": 3}, {"t": 861.3, "k": "dark", "s": 0, "st": 3},
			{"t": 899.0, "k": "escape", "s": 3, "st": 3, "n": 41}, {"t": 925.0, "k": "digit", "s": 1, "st": 3, "n": 3, "w": "HABITACIÓN 231"},
			{"t": 951.0, "k": "tv", "s": 3, "st": 3, "n": 3, "of": 3}, {"t": 977.0, "k": "digit", "s": 2, "st": 3, "n": 4, "w": "HABITACIÓN 207"},
			{"t": 1009.0, "k": "code", "s": 1, "st": 3}, {"t": 1030.0, "k": "lift", "s": 3, "st": 3}, {"t": 1042.0, "k": "out", "s": 0, "st": 3},
		],
	}
	SCORE.settle(tape)
	# A few of its milestones are new, so the pictures show them being stamped.
	for key in ["1:quick", "1:three", "1:mvp", "1:first"]: records.milestones.erase(key)
	level.ui.elapsed = float(tape.time)
	level.ui.outcome = records.file(tape, 1)
	level.ui.places = level.ui.outcome.places
	# As the board keeps it, with its date: the board picks it out by that.
	tape = records.runs[records.runs.size() - 1]
	level.ui.summary = tape
	level.ui.menu("won")
	await shot("report_resumen", 150)
	for page in ["equipo", "sectores", "cronologia", "hitos"]:
		level.ui.turn_tab(1)
		await shot("report_" + page, 110 if page == "hitos" else 20)
	# One that never got out.
	var lost: Dictionary = tape.duplicate(true)
	lost.merge({"result": "lost", "time": 655.0, "stage": 2, "sectors": [318.0], "deaths": 3, "escaped": 0, "restarts": 1}, true)
	lost.events = (lost.events as Array).slice(0, 7) + [{"t": 560.0, "k": "collapse", "s": 0, "st": 2}, {"t": 602.0, "k": "death", "s": 1, "st": 2}, {"t": 655.0, "k": "death", "s": 2, "st": 2}]
	for entry in lost.team: entry.merge({"escaped": false, "sectors": 1, "deaths": 1, "digits": 0, "code": 0}, true)
	SCORE.settle(lost)
	level.ui.summary = lost
	level.ui.outcome = {"places": {}, "milestones": [], "previous": {}}
	level.ui.menu("failed")
	await shot("report_perdida", 150)
	# Its team, with the cursor on the second entry of the row: against its
	# own word, not the one before.
	level.ui.turn_tab(1)
	level.ui.buttons["records"].grab_focus()
	await shot("report_perdida_equipo", 20)
	level.ui.turn_tab(1)
	await shot("report_perdida_sectores", 20)
	# The marks.
	level.ui.summary = tape
	level.ui.noise_floor = 0.0
	level.ui.records_view = {}
	level.ui.menu("records")
	await shot("tablones")
	for page in ["ficha", "comparar"]:
		level.ui.turn_tab(1)
		await shot(page, 20)
	level.ui.show_tape(records.table_of("time", 1, records.SOLO)[0])
	await shot("cinta_guardada", 150)
	level.ui.turn_tab(1)
	await shot("cinta_guardada_equipo", 20)
	level.ui.menu("main", true)
	await shot("menu_principal")
	level.ui.menu("achievements")
	await shot("logros")
	# The archive, all sixteen, and one of them open as its file.
	if not level.discoveries.has("locust_reception"): level.discoveries.record("locust_reception")
	level.ui.menu("archive")
	await shot("archivo")
	level.ui.show_dossier(1, load("res://game/discovery/discovery_catalog.gd").entry("locust_reception"))
	await shot("archivo_ficha")
	level.ui.close_dossier()
	# The controls beside the loading screen.
	level.ui.menu("loading")
	await shot("carga")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_records.json"))
	print("RECORDS listo")
	level.queue_free()
	await process_frame
	quit()
