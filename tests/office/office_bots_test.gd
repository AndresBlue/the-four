extends SceneTree
## The test bots on floor 2 (spec_f1_systems 6.4): two oracle bots play the
## offices from the window to the shaft's ladder on their own, through every
## handler's errands (the card, the board, the post, the fans, the hatch and
## the crawl), and win, with no grave incident and every level closed in
## time. The null creature leaves them nothing to mind.
const MATCH := preload("res://tools/bots/bot_match.gd")
## Simulated seconds a level may take, at most.
const STAGE_MOST := 240.0
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, "" if passed or detail.is_empty() else "  (" + detail + ")")

func run() -> void:
	for seed_value in [7, 33]: await play(int(seed_value))
	print("OFFICE_BOTS_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

func play(seed_value: int) -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	Engine.max_fps = 0
	level.set_floor(2)
	var bot_match = MATCH.new()
	bot_match.setup(level, {"bots": 2, "seed": seed_value, "knowledge": "oracle", "stage_cap": 600.0, "run_cap": 1500.0, "verbose": false, "out": ""})
	root.add_child(bot_match)
	var summary: Dictionary = await bot_match.play()
	var tag := "semilla %d" % seed_value
	check("%s: los bots ganan el piso 2" % tag, String(summary.result) == "ganada" and not bool(summary.fallback), "%s, nivel %d" % [String(summary.result), int(summary.stage)])
	var graves: Array = summary.incidents.filter(func(entry): return entry.severity == "grave")
	check("%s: sin incidencias graves" % tag, graves.is_empty(), str(graves.map(func(entry): return String(entry.get("kind", ""))).slice(0, 4)))
	var marks: Array = summary.sectors
	var slowest := 0.0
	for i in marks.size(): slowest = maxf(slowest, float(marks[i]) - (float(marks[i - 1]) if i > 0 else 0.0))
	check("%s: cada nivel en menos de %d s simulados" % [tag, int(STAGE_MOST)], marks.size() == 3 and slowest <= STAGE_MOST, "%s" % str(marks))
	bot_match.teardown()
	paused = false
	level.queue_free()
	await process_frame
	await process_frame
