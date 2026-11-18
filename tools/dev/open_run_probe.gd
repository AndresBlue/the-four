extends SceneTree
## Which rooms a floor's open runs go through (map_validator.open_runs()), for
## the seeds given: their type, their salon and their row's role.
##   godot --headless --script tools/dev/open_run_probe.gd -- 5 12 [--survivors=1]
const GEN := preload("res://game/world/generation/office_generator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const VALIDATOR := preload("res://game/world/generation/office_validator.gd")

func _initialize() -> void:
	var survivors := 2
	var seeds: Array = []
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): seeds.append(int(argument))
		elif argument.begins_with("--survivors="): survivors = int(argument.get_slice("=", 1))
	for run_seed in seeds:
		var generator = GEN.new()
		generator.areas = OFFICE.areas_for(survivors)
		var data := {}
		var valid := -1
		var codes := {}
		for attempt in generator.attempts():
			var trial: Dictionary = generator.candidate(run_seed, attempt)
			if trial.is_empty(): continue
			if data.is_empty(): data = trial
			var found: Array = VALIDATOR.new().validate(trial)
			for e in found: codes[String(e).rstrip("0123456789").rstrip("_")] = true
			if found.is_empty():
				valid = attempt
				break
		print("PROBE_GAME %d: %s" % [run_seed, ("válido al intento %d" % valid) if valid >= 0 else "RESERVA, motivos %s, validador %s" % [str(generator.stats), str(codes.keys())]])
		if data.is_empty():
			print("PROBE %d: sin piso, motivos %s" % [run_seed, str(generator.stats)])
			continue
		var errors: Array = VALIDATOR.new().validate(data)
		var runs: Array = errors.filter(func(e): return String(e).begins_with("open_run"))
		var typology := String(generator.building.get("typology", ""))
		print("PROBE %d (%s): %d errores, %s" % [run_seed, typology, errors.size(), str(errors.filter(func(e): return not String(e).begins_with("open_run")).slice(0, 6))])
		for e in runs.slice(0, 6):
			var room: Dictionary = data.rooms[int(String(e).get_slice("_", 2))]
			print("  %s: tipo %s, salón %d, pasillo %s, fila %d, columna %d, %.1f x %.1f" % [e, OFFICE.label(room), int(room.get("hall", -1)), str(room.get("corridor", false)), int(room.z), int(room.x), float(room.span_x), float(room.span_z)])
	quit(0)
