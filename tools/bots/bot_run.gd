extends SceneTree
## One floor played by bots, headless, and its summary written down.
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/bots/bot_run.gd -- \
##     --test-profile --automation --silent --bots=3 --seed=81 [--knowledge=oracle] \
##     [--mercy] [--no-enemy] [--out=<folder>] [--profile-tag=w1]
##
## It will not start without --test-profile: a run without it once overwrote
## a player's own checkpoint. ./tools/bots.ps1 runs many of these in a row.
const MATCH := preload("res://tools/bots/bot_match.gd")
var level
var bot_match

func _initialize() -> void: run.call_deferred()

func arg(name_value: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name_value): return argument.trim_prefix("--%s=" % name_value)
	return fallback

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--test-profile"):
		printerr("bot_run: sin --test-profile no se juega (protege el punto de control de Continuar).")
		quit(2)
		return
	var options := {
		"bots": clampi(int(arg("bots", "3")), 1, 5),
		"seed": int(arg("seed", "81")),
		"knowledge": arg("knowledge", "discover"),
		"mercy": args.has("--mercy"),
		"stage_cap": float(arg("stage-cap", "1800")),
		"run_cap": float(arg("run-cap", "5400")),
		"verbose": not args.has("--quiet"),
		"out": arg("out", ""),
		"faults": arg("fault", ""),
		"commit": arg("commit", ""),
	}
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	Engine.max_fps = 0
	bot_match = MATCH.new()
	bot_match.setup(level, options)
	root.add_child(bot_match)
	var summary: Dictionary = await bot_match.play()
	var out: String = options.out if not String(options.out).is_empty() else ProjectSettings.globalize_path("res://evidence/bots/last")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	var graves: int = summary.incidents.filter(func(entry): return entry.severity == "grave").size()
	print("BOTS_RESULT %s · semilla %d · %d bots · %s simulados en %s (x%.1f) · %d incidencias, %d graves" % [summary.result, summary.seed, summary.bots, MATCH.clock_text(summary.sim_seconds), MATCH.clock_text(summary.wall_seconds), summary.realtime_factor, summary.incidents.size(), graves])
	bot_match.teardown()
	paused = false
	level.queue_free()
	await process_frame
	quit(0)
