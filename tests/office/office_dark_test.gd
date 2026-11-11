extends SceneTree
## Floor 2's first stage dark by difficulty (the author, 24 October 2026;
## .claude/specs/spec_f3_aggression.md): the same seed built in the four, its
## planta 1 all lit in Apacible, the manifest's in Equilibrada, all but about
## a tenth (office_geometry.LIT_LEFT) in Desafiante, every room that may be dark
## in Pesadilla (the author, 11 November 2026); the rooms that may never be dark
## lit in all of them; plantas 2 and 3 the same in all four.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const ORDER := ["apacible", "equilibrada", "desafiante", "pesadilla"]
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	level.set_floor(2)
	var dark := {}
	var upper := {}
	var never_dark_lit := true
	var manifest_dark := []
	for id in ORDER:
		await level.start_floor(7, false, [1], id)
		var mine: Array = []
		var above: Array = []
		for room in level.manifest.rooms:
			if FLOOR.is_void(room): continue
			var rid := int(room.id)
			var out: bool = level.hotel.dark_ids.has(rid)
			if int(room.get("wing", -1)) == 0:
				if out: mine.append(rid)
				if out and (not OFFICE.may_be_dark(room) or OFFICE.off_limits(room)) and id != "equilibrada": never_dark_lit = false
				if id == "equilibrada" and bool(room.get("dark", false)): manifest_dark.append(rid)
			elif out: above.append(rid)
		dark[id] = mine
		upper[id] = above
	var may := 0
	var may_dark := 0
	for room in level.manifest.rooms:
		if not FLOOR.is_void(room) and int(room.get("wing", -1)) == 0 and OFFICE.may_be_dark(room) and not OFFICE.off_limits(room):
			may += 1
			if (dark.pesadilla as Array).has(int(room.id)): may_dark += 1
	var sizes: Array = ORDER.map(func(id): return (dark[id] as Array).size())
	check("Apacible: la primera etapa con todas las luces", (dark.apacible as Array).is_empty(), str(sizes))
	check("Equilibrada: las salas a oscuras del manifiesto", dark.equilibrada == manifest_dark, "%s %s" % [str(dark.equilibrada), str(manifest_dark)])
	check("Desafiante: todo a oscuras menos más o menos un décimo", float((dark.desafiante as Array).size()) >= float(may) * 0.75 and (dark.desafiante as Array).size() <= (dark.pesadilla as Array).size(), "%s de %d" % [str(sizes), may])
	check("Pesadilla: todo lo que puede estar a oscuras", may_dark == may, "%d de %d" % [may_dark, may])
	check("Las salas que nunca se apagan siguen con luz", never_dark_lit)
	check("Las plantas 2 y 3, iguales en las cuatro", upper.apacible == upper.equilibrada and upper.equilibrada == upper.desafiante and upper.desafiante == upper.pesadilla)
	var file := FileAccess.open("res://evidence/office_dark_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "sizes": sizes}, "\t"))
	print("OFFICE_DARK_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
