extends Node
## Bots playing one floor after another, watched live in the observer:
##   ./tools/godot.ps1 bots [-Bots 3] [-Seed 81] [-Mercy]
## A floor won, lost or out of time, and the next one starts with the next
## seed, for as long as the window is open. Each is recorded like a floor of
## ./tools/bots.ps1 (evidence/bots/vivo-<hora>/), so whatever is seen go by
## can be watched again with ./tools/godot.ps1 bots-replay; resumen.txt keeps
## one line per floor and one per incident, with the command that opens it.
## R in the observer ends the floor on screen and goes on to the next.
const MATCH := preload("res://tools/bots/bot_match.gd")
## Real seconds between one floor and the next, to read how it went.
const BETWEEN := 4.0
var level
var options := {}
var folder := ""
var current
var played := 0
var won := 0
var seed_value := 81

func setup(owner_level, given: Dictionary) -> void:
	level = owner_level
	options = given
	name = "BotWatch"
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed_value = int(options.get("seed", 81))
	folder = ProjectSettings.globalize_path("res://evidence/bots/vivo-%s" % Time.get_datetime_string_from_system().replace(":", "").replace("T", "-"))
	DirAccess.make_dir_recursive_absolute(folder)

func run() -> void:
	while is_inside_tree():
		played += 1
		var run_options := options.duplicate()
		run_options["seed"] = seed_value
		run_options["out"] = folder.path_join("%02d-s%d-b%d" % [played, seed_value, int(options.get("bots", 3))])
		run_options["verbose"] = false
		current = MATCH.new()
		current.setup(level, run_options)
		add_child(current)
		var began: bool = await current.begin()
		if began:
			# Every floor put up gives the player's camera back: the observer's again.
			level.enter_observer_mode()
			say("PISO %d · semilla %d · %d bots%s" % [played, seed_value, current.bodies.size(), " · clemencia" if bool(options.get("mercy", false)) else ""])
			current.report_to = self
			while current.outcome.is_empty(): await get_tree().physics_frame
		var summary: Dictionary = current.finish()
		write(summary, String(run_options.out))
		current.teardown()
		current.queue_free()
		current = null
		seed_value += 1
		# A moment to read it, whatever the time scale the observer set.
		var left := BETWEEN
		while left > 0.0:
			await get_tree().process_frame
			left -= get_process_delta_time() / maxf(Engine.time_scale, 0.01)

## The floor on screen ends here (R in the observer): on to the next.
func skip() -> void:
	if current != null and current.outcome.is_empty():
		say("R: al siguiente piso")
		current.outcome = "saltada"

## An incident of the floor being played, as it happens.
func incident(entry: Dictionary) -> void:
	if String(entry.severity) == "leve": return
	say("%s %s · %s%s" % [String(entry.severity).to_upper(), entry.kind, (String(entry.bot) + " · ") if not String(entry.bot).is_empty() else "", entry.words])

func say(words: String) -> void:
	print("BOTS ", words)
	if level.observer_view != null: level.observer_view.note(words)

func write(summary: Dictionary, out: String) -> void:
	if String(summary.result) == "ganada": won += 1
	var file := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	var line := "PISO %d · semilla %d · %s · %s de juego · %d muertes · %d incidencias graves · van %d ganados de %d" % [played, int(summary.seed), summary.result, MATCH.clock_text(float(summary.sim_seconds)), int(summary.deaths), summary.incidents.filter(func(entry): return entry.severity == "grave").size(), won, played]
	say(line)
	var lines: Array = [line]
	for entry in summary.incidents:
		if String(entry.severity) == "leve": continue
		lines.append("  %s %s · %s · %s%s · %s" % [MATCH.clock_text(float(entry.t)), String(entry.severity).to_upper(), entry.kind, (String(entry.bot) + " · ") if not String(entry.bot).is_empty() else "", entry.room_name, entry.words])
		lines.append("    → ./tools/godot.ps1 bots-replay -Run \"%s\" -At %d" % [out, int(entry.get("replay_at", 0.0))])
	var path := folder.path_join("resumen.txt")
	var log_file := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if log_file == null: return
	log_file.seek_end()
	for text in lines: log_file.store_line(text)
	log_file.close()
