extends SceneTree
## The reception two cells long (the author, 17 November 2026): on the first
## planta its bay's cell and its cross's stub toward the end, one room of 9 m or
## more along, its counter in the first and its wait down the annex; and no
## other planta's room in its column grows past the structure's bay (the
## freight lift B and its lobby back to 7.2), seeds 7 and 33 among them.
const GEN := preload("res://game/world/generation/office_generator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const RUNS := [[7, 2], [33, 2], [21, 2], [1, 2], [2, 3], [5, 1], [12, 1], [44, 4]]

var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var short: Array = []
	var grown: Array = []
	var pieces: Array = []
	var invalid: Array = []
	for each in RUNS:
		var tag := "%d/%d" % [int(each[0]), int(each[1])]
		var generator = GEN.new()
		var m: Dictionary = generator.generate(int(each[0]), int(each[1]))
		if m.is_empty() or bool(m.get("fallback", false)):
			invalid.append(tag + " sin piso")
			continue
		var errors: Array = generator.validator().validate(m)
		if not errors.is_empty(): invalid.append("%s %s" % [tag, str(errors.slice(0, 3))])
		var start: Dictionary = m.rooms[int(m.start)]
		var hall: Array = m.rooms.filter(func(r): return int(r.wing) == 0 and int(start.hall) >= 0 and int(r.hall) == int(start.hall))
		var along := 0.0
		for r in hall: along += float(r.span_x) if int(r.z) == int(start.z) else float(r.span_z)
		var long_side: float = maxf(along, maxf(float(start.span_x), float(start.span_z)))
		print("RECEPCION %s celdas=%d largo=%.1f ancho=%.1f" % [tag, hall.size(), long_side, minf(float(start.span_x), float(start.span_z))])
		if long_side < 9.0 - 0.001: short.append("%s %.1f" % [tag, long_side])
		# The counter in the reception's own cell, the wait in its annex.
		var kinds := func(r: Dictionary) -> Array: return r.get("furniture", []).map(func(it): return String(it.kind))
		var annex: Array = hall.filter(func(r): return int(r.id) != int(start.id))
		var all: Array = []
		for r in hall: all.append_array(kinds.call(r))
		if not kinds.call(start).has("reception_counter_l") or annex.is_empty() or not kinds.call(annex[0]).has("waiting_row_4") or all.count("reception_counter_l") != 1 or all.count("waiting_row_4") != 1: pieces.append("%s %s / %s" % [tag, str(kinds.call(start)), str(annex.map(func(r): return kinds.call(r)))])
		# The other plantas' rooms in the reception's column and its stub's: none over the bay.
		for r in m.rooms:
			if int(r.wing) == 0 or int(r.type) == OFFICE.VOID or absi(int(r.x) - int(start.x)) > 1: continue
			if maxf(float(r.span_x), float(r.span_z)) > OFFICE.BAY + 0.001: grown.append("%s sala %d %.1f" % [tag, int(r.id), maxf(float(r.span_x), float(r.span_z))])
	check("Cada piso sale válido", invalid.is_empty(), str(invalid))
	check("La recepción mide 9 m o más en su lado largo", short.is_empty(), str(short))
	check("Un mostrador, en la celda de la recepción, y una espera, en su anexo", pieces.is_empty(), str(pieces))
	check("Ninguna sala de otra planta en la columna de la recepción pasa del vano de 7,2", grown.is_empty(), str(grown.slice(0, 8)))
	quit(1 if failed > 0 else 0)
