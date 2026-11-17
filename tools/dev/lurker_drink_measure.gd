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
		var sum := {"drinks": 0, "dark_drinks": 0, "cues": 0, "taken": 0, "saved": 0, "sim": 0}
		for row in rows:
			for key in sum: sum[key] += int(row[key])
		sum["rate"] = snappedf(float(sum.taken) / float(sum.drinks), 0.01) if int(sum.drinks) > 0 else 0.0
		sum["per_game"] = snappedf(float(sum.drinks) / float(rows.size()), 0.01)
		sum["cues_per_drink"] = snappedf(float(sum.cues) / float(sum.drinks), 0.01) if int(sum.drinks) > 0 else 0.0
		sum["per_10_min"] = snappedf(float(sum.drinks) * 600.0 / float(sum.sim), 0.01) if int(sum.sim) > 0 else 0.0
		out[id] = {"total": sum, "runs": rows}
		print("MEDIDA %s: %d partidas, %d bebidas (%.2f por partida, %.2f cada 10 min; %d a oscuras), %d avisos en su apagón (%.2f por apagón), %d capturas (%.2f por apagón), %d salvados" % [id, rows.size(), sum.drinks, sum.per_game, sum.per_10_min, sum.dark_drinks, sum.cues, sum.cues_per_drink, sum.taken, sum.rate, sum.saved])
	var folder := arg("out", "evidence/versus/f4")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + folder))
	var file := FileAccess.open("res://%s/%s.json" % [folder, arg("name", "medida")], FileAccess.WRITE)
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
	# Once a second of her clock: her state, and with her count for the drink
	# run out, what held it back (lurker.drink_fair()).
	var why := {}
	var ticks := [0]
	var sample := func() -> void:
		ticks[0] += 1
		var it = level.creature
		if ticks[0] % 60 != 0 or not is_instance_valid(it) or it.get("brain") == null or it.control != "ai": return
		var key: String = "estado " + it.brain.state_name()
		why[key] = int(why.get(key, 0)) + 1
		if it.snuff_time > 0.0 and it.snuff_clock >= it.snuff_time and it.warn_room < 0:
			var reason := held(level, it)
			why["retenida " + reason] = int(why.get("retenida " + reason, 0)) + 1
	physics_frame.connect(sample)
	var summary: Dictionary = await bots.play()
	physics_frame.disconnect(sample)
	var lurker = level.creature
	var row := {"seed": seed_value, "result": String(summary.get("result", "")), "sim": snappedf(float(summary.get("sim_seconds", 0.0)), 1.0), "drinks": 0, "dark_drinks": 0, "cues": 0, "taken": 0, "saved": 0, "each": [], "why": why}
	if is_instance_valid(lurker) and "drinks" in lurker:
		var ledger: Array = lurker.capture_log()
		for drink in lurker.drinks:
			var mine: Array = ledger.filter(func(e): return not bool(e.forced) and float(e.at) >= float(drink.at) and float(e.at) < float(drink.at) + float(drink.dark))
			row.drinks += 1
			if not bool(drink.get("lit", true)): row.dark_drinks += 1
			row.cues += mine.size()
			row.taken += mine.filter(func(e): return String(e.outcome) == "taken").size()
			row.saved += mine.filter(func(e): return String(e.outcome) == "saved").size()
			row.each.append({"at": snappedf(float(drink.at), 0.1), "room": int(drink.room), "lit": bool(drink.get("lit", true)), "seats": drink.seats, "warnings": mine.map(func(e): return [String(e.outcome), String(e.reason)])})
	print("MEDIDA %s semilla %d: %s en %d s, %d bebidas, %d avisos, %d capturas" % [id, seed_value, row.result, int(row.sim), row.drinks, row.cues, row.taken])
	bots.teardown()
	paused = false
	level.queue_free()
	await process_frame
	await process_frame
	return row

## What holds her drink back now, in drink_fair()'s order.
func held(level, it) -> String:
	var seat := int(it.brain.prey)
	var body = it.senses.body_of(seat)
	if body == null: return "sin presa"
	var room: int = it.room_of_point(body.global_position)
	var clock: float = it.brain.clock
	if room < 0: return "sin sala"
	if it.deep_room >= 0: return "otra sala a oscuras"
	if not it.warning.active.is_empty(): return "aviso en marcha"
	if it.drunk.has(seat) or it.dead_torches.has(seat): return "linterna bebida"
	if clock - it.last_drink < float(it.tuning.get("drink_every", 60.0)): return "espera entre bebidas"
	if clock - it.brain.scared_at < it.BRAIN.SCARE_CALM: return "tras un susto"
	var torch: bool = is_instance_valid(body.get("torch")) and body.torch.visible
	if not level.hotel.lit(room) and not torch: return "a oscuras sin linterna"
	if not it.may_snuff(room, clock): return "sala que no puede"
	return "otra"
