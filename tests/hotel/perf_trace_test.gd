extends SceneTree
## The performance trace's own times (game/app/session_perf.gd): work timed
## inside other work is taken out of it, so the rows of a frame add up to the
## time the named work took, once; and where --perf-log= writes.
const PERF := preload("res://game/app/session_perf.gd")
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var trace := PERF.new()
	trace.phase = PERF.Phase.PHYSICS
	# outer [0, 100] holds one [10, 30] and two [40, 60], which holds three
	# [45, 50]; after it, four [110, 120]. Each closes after what it holds.
	trace.count(&"one", 10, 30)
	trace.count(&"three", 45, 50)
	trace.count(&"two", 40, 60)
	trace.count(&"outer", 0, 100)
	trace.count(&"four", 110, 120)
	trace.count(&"one", 125, 130)
	var own := {}
	for name in trace.timings: own[name] = trace.timings[name][3]
	check("Lo de dentro sale del tiempo propio", own == {&"one": 25, &"two": 15, &"three": 5, &"outer": 60, &"four": 10}, str(own))
	check("Llamadas, total y mayor", trace.timings[&"one"].slice(0, 3) == [2, 25, 20], str(trace.timings[&"one"]))
	check("La fase en que corrió", trace.timings[&"outer"][4] == PERF.Phase.PHYSICS)
	check("Lo propio de la fase suma el trabajo con nombre una vez", trace.named_us[PERF.Phase.PHYSICS] == 100 + 10 + 5, str(trace.named_us))
	var folder := ProjectSettings.globalize_path("res://evidence/perf/perf_trace_test")
	var made := PERF.path_for(folder.replace("/", "\\"))
	check("Una carpeta da un archivo con la hora dentro", made.begins_with(folder + "/") and made.ends_with(".jsonl") and DirAccess.dir_exists_absolute(folder), made)
	check("Un archivo se queda como está", PERF.path_for("C:\\a\\b.jsonl") == "C:/a/b.jsonl")
	print("PERF_TRACE_TEST ", "ok" if failed == 0 else "%d fallos" % failed)
	quit(1 if failed > 0 else 0)
