extends SceneTree
## Her drink of a room with the bots (lurker_versus.md 10; phase 4): floor 2
## played by oracle bots against her in a difficulty, a few seeds, and what
## her drinks came to -- how many, the warnings begun in their dark and how
## many of those ended in a capture. Writes evidence/versus/f4/medida.json.
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev/lurker_drink_measure.gd -- \
##     --test-profile --automation --silent [--difficulties=equilibrada,desafiante] [--seeds=81,7] [--bots=3] [--run-cap=900]
const MATCH := preload("res://tools/bots/bot_match.gd")

func _initialize() -> void: run.call_deferred()

func arg(name_value: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name_value): return argument.trim_prefix("--%s=" % name_value)
	return fallback

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test-profile"):
		printerr("lurker_drink_measure: sin --test-profile no se juega.")
		quit(2)
		return
	var out := {}
	for id in arg("difficulties", "equilibrada,desafiante").split(","):
		var rows: Array = []
		for seed_text in arg("seeds", "81,7").split(","): rows.append(await play(id, int(seed_text)))
		var sum := {"drinks": 0, "cues": 0, "taken": 0, "saved": 0}
		for row in rows:
			for key in sum: sum[key] += int(row[key])
		sum["rate"] = snappedf(float(sum.taken) / float(sum.drinks), 0.01) if int(sum.drinks) > 0 else 0.0
		out[id] = {"total": sum, "runs": rows}
		print("MEDIDA %s: %d bebidas, %d avisos en su apagón, %d capturas (%.2f por apagón), %d salvados" % [id, sum.drinks, sum.cues, sum.taken, sum.rate, sum.saved])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/versus/f4"))
	var file := FileAccess.open("res://evidence/versus/f4/medida.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	quit(0)

func play(id: String, seed_value: int) -> Dictionary:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	Engine.max_fps = 0
	level.set_floor(2)
	level.creature_scene = "lurker"
	var bots = MATCH.new()
	bots.setup(level, {"bots": int(arg("bots", "3")), "seed": seed_value, "knowledge": "oracle", "difficulty": id, "stage_cap": 600.0, "run_cap": float(arg("run-cap", "900")), "verbose": false, "out": ""})
	root.add_child(bots)
	var summary: Dictionary = await bots.play()
	var lurker = level.creature
	var row := {"seed": seed_value, "result": String(summary.get("result", "")), "sim": snappedf(float(summary.get("sim_seconds", 0.0)), 1.0), "drinks": 0, "cues": 0, "taken": 0, "saved": 0, "each": []}
	if is_instance_valid(lurker) and "drinks" in lurker:
		var ledger: Array = lurker.capture_log()
		for drink in lurker.drinks:
			var mine: Array = ledger.filter(func(e): return not bool(e.forced) and float(e.at) >= float(drink.at) and float(e.at) < float(drink.at) + float(drink.dark))
			row.drinks += 1
			row.cues += mine.size()
			row.taken += mine.filter(func(e): return String(e.outcome) == "taken").size()
			row.saved += mine.filter(func(e): return String(e.outcome) == "saved").size()
			row.each.append({"at": snappedf(float(drink.at), 0.1), "room": int(drink.room), "seats": drink.seats, "warnings": mine.map(func(e): return [String(e.outcome), String(e.reason)])})
	print("MEDIDA %s semilla %d: %s en %d s, %d bebidas, %d avisos, %d capturas" % [id, seed_value, row.result, int(row.sim), row.drinks, row.cues, row.taken])
	bots.teardown()
	paused = false
	level.queue_free()
	await process_frame
	await process_frame
	return row
