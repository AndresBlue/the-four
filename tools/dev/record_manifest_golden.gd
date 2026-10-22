extends SceneTree
## The hotel's floors as the generator draws them today, recorded so that
## nothing that is not meant to change them does (docs/OFICINAS.md, 15, Fase
## 0): tests/hotel/manifest_golden_test.gd draws them again and compares. Each
## case is a seed and the survivors it is drawn for, one to five: three plays
## the floor of two (the palette's AREA) but not its sets, as TV_PLACEMENT seeds its
## choice with the survivors and asks for one more. Plus, for each number, the
## standby floor forced as hotel_main.build_floor() forces it. Each is drawn as
## build_floor() comes by it before building anything: the manifest, and the
## sets TV_PLACEMENT.settle() picks on it, both kept as the SHA-256 of their
## JSON, keys sorted and floats at full precision.
##
##   godot --headless --script tools/dev/record_manifest_golden.gd -- --test-profile
## Writes tests/hotel/manifest_golden.json. Only when a change to the floors
## is intended: recorded over a mistake, the test holds the mistake.
const GENERATOR := preload("res://game/world/generation/map_generator.gd")
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GOLDEN := "res://tests/hotel/manifest_golden.json"
## Fifty seeds, all fixed: the ones the tests and the tools already walk (81,
## 202, 213, 777, 4242, 9001) first. Two hundred and fifty floors and the
## standby take about forty seconds.
const SEEDS := [81, 202, 213, 777, 4242, 9001, 1, 3, 7, 11, 17, 23, 31, 42, 64, 77, 99, 123, 128, 256, 314, 404, 500, 555, 666, 808, 999, 1000, 1111, 1234, 1337, 1500, 2024, 2048, 2500, 2718, 3000, 3141, 4096, 4444, 5000, 6000, 6502, 7777, 8080, 8192, 9999, 10000, 12345, 31337]
const SURVIVORS := [1, 2, 3, 4, 5]
## The seed a forced standby floor was asked for (it only goes in the
## manifest as `requested_seed`).
const STANDBY_ASKED := 81

## Every case recorded: [{seed, survivors, fallback}].
static func cases() -> Array:
	var result: Array = []
	for survivors in SURVIVORS:
		for seed_value in SEEDS: result.append({"seed": seed_value, "survivors": survivors, "fallback": false})
		result.append({"seed": STANDBY_ASKED, "survivors": survivors, "fallback": true})
	return result

static func key_of(entry: Dictionary) -> String:
	return "%s%d/%d" % ["standby " if bool(entry.fallback) else "", int(entry.seed), int(entry.survivors)]

## The manifest of a case and the sets of its stages, exactly as
## hotel_main.build_floor() comes by them before it builds anything.
static func draw(entry: Dictionary) -> Dictionary:
	var seed_value := int(entry.seed)
	var survivors := int(entry.survivors)
	var manifest: Dictionary
	# Forced, build_floor() draws the floor asked for first and throws it away,
	# a generator of its own each: skipping that changes nothing.
	if bool(entry.fallback):
		manifest = GENERATOR.new().candidate(404, 0, true)
		manifest["fallback"] = true
		manifest["requested_seed"] = seed_value
	else: manifest = GENERATOR.new().generate(seed_value, survivors)
	var drawn := String(JSON.stringify(manifest, "", true, true))
	var sets: Dictionary = TV_PLACEMENT.settle(manifest, survivors)
	return {"manifest": drawn.sha256_text(), "televisions": String(JSON.stringify(sets, "", true, true)).sha256_text(), "fell_back": bool(manifest.get("fallback", false))}

func _initialize() -> void:
	var began := Time.get_ticks_msec()
	var recorded: Array = []
	var steady := true
	for entry in cases():
		var digest := draw(entry)
		# The same case drawn twice in one run comes out the same, or there is
		# nothing to record: once for each size and the standby floor.
		if (int(entry.seed) == int(SEEDS[0]) or bool(entry.fallback)) and draw(entry) != digest:
			steady = false
			push_error("Manifest of %s is not the same twice" % key_of(entry))
		recorded.append({"key": key_of(entry), "seed": int(entry.seed), "survivors": int(entry.survivors), "fallback": bool(entry.fallback), "fell_back": digest.fell_back, "manifest": digest.manifest, "televisions": digest.televisions})
	var seconds := float(Time.get_ticks_msec() - began) / 1000.0
	if not steady:
		quit(1)
		return
	var file := FileAccess.open(GOLDEN, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % GOLDEN)
		quit(1)
		return
	file.store_string(JSON.stringify({"version": FLOOR.VERSION, "cases": recorded}, "\t", false))
	file.close()
	print("MANIFEST_GOLDEN_RECORDED %d cases in %.1f s" % [recorded.size(), seconds])
	quit(0)
