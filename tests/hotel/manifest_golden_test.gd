extends SceneTree
## The hotel's floors come out of the generator as they were recorded
## (tests/hotel/manifest_golden.json, tools/dev/record_manifest_golden.gd):
## fifty seeds for each number of survivors, one to five, and the forced
## standby floor, each manifest and the sets settled on it, byte for byte. A
## refactor that moves anything of the floors fails here; one that is meant to
## is recorded again.
const RECORD := preload("res://tools/dev/record_manifest_golden.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

func run() -> void:
	var began := Time.get_ticks_msec()
	var golden: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORD.GOLDEN))
	var recorded: Array = golden.get("cases", []) if golden is Dictionary else []
	check("Hay manifiestos grabados (%d)" % recorded.size(), not recorded.is_empty())
	check("Grabados con la versión de planos de ahora (%d)" % FLOOR.VERSION, golden is Dictionary and int(golden.get("version", -1)) == FLOOR.VERSION)
	var keys: Array = recorded.map(func(entry): return String(entry.get("key", "")) if entry is Dictionary else "")
	var listed: Array = RECORD.cases().map(func(entry): return RECORD.key_of(entry))
	check("Los casos grabados son los de la herramienta", keys == listed)
	for entry in recorded:
		if not entry is Dictionary: continue
		var digest: Dictionary = RECORD.draw(entry)
		var key := String(entry.get("key", ""))
		check("%s: el manifiesto es el grabado" % key, digest.manifest == String(entry.get("manifest", "")) and digest.fell_back == bool(entry.get("fell_back", false)))
		check("%s: las teles de cada etapa son las grabadas" % key, digest.televisions == String(entry.get("televisions", "")))
	var seconds := float(Time.get_ticks_msec() - began) / 1000.0
	var file := FileAccess.open("res://evidence/manifest_golden_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"passed": failed == 0, "seconds": seconds, "checks": checks}, "\t"))
	print("MANIFEST_GOLDEN_RESULT ", checks.size() - failed, "/", checks.size(), " in %.1f s" % seconds)
	quit(1 if failed > 0 else 0)
