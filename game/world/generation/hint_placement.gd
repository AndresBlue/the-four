extends RefCounted
## The hints of the stage that asks for the code (the last, in the hotel):
## eight papers on its planta that say, each its own way, where the pages of
## the code are (the author, 20 October 2026). Four lie in sight on tables and
## desks, well short of the far end, one for each page, and say where to look
## without saying where it is: the block of rooms on a maid's sheet, a work
## order of the maintenance, directions written down from the lift and torn
## before the end, a sign taken off the door of a room the page is in or
## beside. Three are in drawers further in and put a page on the plan: a
## carbon copy that leaves a circle on the sheet, a corner of an evacuation
## plan with a cross on it, and a trail of chalk on the walls. And one, in the
## most out-of-the-way room of the planta, is the sheet of somebody who was
## here before, with the four marked.
##
## None lies in the zone of its own page, nor in a room with a page. Worked
## out from the seed, the planta and the furniture, the same on every machine:
## nothing about them travels but who took the ones in drawers.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const DOCUMENTS := preload("res://game/world/generation/document_placement.gd")
const ZONE_KINDS := ["limpieza", "orden", "indicaciones", "cartel"]
const POINT_KINDS := ["calco", "plano", "tiza"]
const POINTS := 3
## Where the papers in sight lie, as shares of the walk to the farthest room
## from the lobby (and never nearer than ZONE_LEAST metres); and the drawers
## the three of the plan are in.
const ZONE_SPAN := Vector2(0.1, 0.6)
const ZONE_LEAST := 12.0
const POINT_SPAN := Vector2(0.25, 0.85)
## The tops papers are put on (document_placement.SURFACES).
const SURFACES := DOCUMENTS.SURFACES
## The circle of the carbon copy, round the page but not on it, in metres; the
## part of the plan the evacuation plan's corner shows; the circles on the
## other sheet.
const CIRCLE := 10.0
const CORNER := Vector2(44.0, 32.0)
const MARKED := 4.0
## The chalk: from where to where it may run, in metres walked, and one arrow
## every this many on a straight.
const CHALK := Vector2(12.0, 70.0)
const CHALK_EVERY := 9.0
## How a maid ticks a room off.
const STATES := ["HECHA", "HECHA", "HECHA", "HECHA", "NO MOLESTAR", "SIN TOALLAS", "CAMA SIN HACER", "NO ABRE"]
## The rooms whose door a sign can come off, and what it said.
const SIGNS := {7: "SOLO PERSONAL", 6: "CERRADO", 5: "SE RUEGA SILENCIO", 17: "NO PISAR LAS PLANTAS", 18: "EN OBRAS", 13: "SILENCIO", 14: "APAGUE AL SALIR", 4: "FUERA DE SERVICIO", 16: "SOLO PERSONAL", 8: "PRIVADO", 9: "PELIGRO", 15: "PRIVADO"}
## Where in a piece of furniture a paper is, said as a maid would say it.
const IN_PIECE := {"commode": "en un cajón", "console": "en un cajón", "drawers": "en un cajón", "bookcase": "en una estantería", "cabinet": "en un mueble", "boxes": "en unas cajas", "luggage": "en una maleta"}
const ORDINALS := ["primer", "segundo", "tercer", "cuarto", "quinto", "sexto", "séptimo", "octavo"]

## Returns [{id, kind, slot (the page it is about, 0 for all four), place
## ("surface" or "container"), container (or -1), room, position, yaw, and
## what it shows: printed (lines), hand (lines), rows, and plan data}].
## `containers` are the hotel's furniture spots (hotel_geometry.containers),
## `hiding` what digit_placement.choose() put in them.
static func choose(manifest: Dictionary, containers: Array, hiding: Array, stage := 3) -> Array:
	var wing := stage - 1
	if hiding.is_empty() or wing < 0 or wing >= manifest.get("plantas", []).size(): return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "hints", stage])
	var rooms: Array = manifest.rooms
	var entry := FLOOR.entry_of(manifest, wing)
	var metres := FLOOR.route_metres(manifest, entry)
	var deepest := 0.0
	for id in metres: deepest = maxf(deepest, float(metres[id]))
	var refuge := int(manifest.refuges[wing]) if wing < manifest.get("refuges", []).size() else -1
	var pages: Array = []
	var page_rooms := {}
	for hidden in hiding:
		var spot: Dictionary = containers[int(hidden.container)]
		var room: Dictionary = rooms[int(spot.room)]
		pages.append({"slot": int(hidden.slot), "container": int(hidden.container), "room": int(spot.room), "sector": int(room.sector), "position": spot.position, "kind": String(spot.kind)})
		page_rooms[int(spot.room)] = true
	pages.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
	var blocked := page_rooms.duplicate()
	# Nor where a document is, nor in the suitcase one is shut in.
	var held := {}
	for document in DOCUMENTS.choose(manifest, "locust", containers):
		blocked[int(document.room)] = true
		held[int(document.container)] = true
	var hints: Array = []
	# One paper in sight for each page.
	var kinds := ZONE_KINDS.duplicate()
	shuffle(kinds, rng)
	var surfaces := surface_spots(manifest, wing, metres, deepest, refuge, blocked, rng)
	for page in pages:
		var made := {}
		for attempt in kinds.size():
			var kind: String = kinds[(hints.size() + attempt) % kinds.size()]
			made = zone_hint(manifest, kind, page, entry, rng)
			if not made.is_empty(): break
		if made.is_empty(): made = zone_hint(manifest, "limpieza", page, entry, rng)
		var spot := pick_spot(surfaces, page, hints, rooms, rng)
		if spot.is_empty(): continue
		blocked[int(spot.room)] = true
		made.merge({"id": hints.size(), "slot": int(page.slot), "place": "surface", "container": -1, "room": int(spot.room), "position": spot.position, "yaw": float(spot.yaw)}, true)
		hints.append(made)
	# Three on the plan, for three of the pages.
	var marked := pages.duplicate()
	shuffle(marked, rng)
	var ways := POINT_KINDS.duplicate()
	shuffle(ways, rng)
	# Of the papers that help (the hints and the documents), one at most is
	# shut in a suitcase on a floor: the rest are seen at a glance (the
	# author's word, 21 October 2026).
	var suitcases := {}
	for index in containers.size():
		if DOCUMENTS.HOLDERS.has(String(containers[index].get("kind", ""))): suitcases[index] = true
	var shut_one := held.keys().any(func(index): return int(index) >= 0)
	var drawers := drawer_spots(manifest, containers, hiding, wing, metres, deepest, refuge, POINT_SPAN).filter(func(spot): return not held.has(int(spot.container)) and not (shut_one and suitcases.has(int(spot.container))))
	var used := {}
	for index in mini(POINTS, marked.size()):
		var page: Dictionary = marked[index]
		var made := point_hint(manifest, String(ways[index]), page, rng)
		# No chalk to be had (no corridor to the door): the plan's corner, or
		# the carbon copy, whichever is not there yet.
		if made.is_empty():
			var spare: Array = ["plano", "calco"].filter(func(kind): return not used.has(kind) and not ways.slice(index + 1, POINTS).has(kind))
			made = point_hint(manifest, String(spare[0]) if not spare.is_empty() else "calco", page, rng)
		used[String(made.kind)] = true
		var spot := pick_spot(drawers, page, hints, rooms, rng)
		if spot.is_empty(): continue
		blocked[int(spot.room)] = true
		drawers = drawers.filter(func(other): return int(other.room) != int(spot.room))
		if suitcases.has(int(spot.container)):
			shut_one = true
			drawers = drawers.filter(func(other): return not suitcases.has(int(other.container)))
		made.merge({"id": hints.size(), "slot": int(page.slot), "place": "container", "container": int(spot.container), "room": int(spot.room), "position": spot.position, "yaw": float(spot.yaw)}, true)
		hints.append(made)
	# And the other sheet, in the room nobody would go to.
	var far := remotest(manifest, containers, hiding, wing, metres, deepest, refuge, blocked, suitcases if shut_one else {})
	if not far.is_empty():
		var points: Array = []
		for page in pages: points.append(Vector2(float(page.position.x), float(page.position.z)))
		hints.append({"id": hints.size(), "kind": "hoja", "slot": 0, "place": "container", "container": int(far.container), "room": int(far.room), "position": far.position, "yaw": float(far.yaw), "printed": [], "hand": [], "rows": [], "points": points, "radius": MARKED})
	return hints

# --- In sight: where to look ---------------------------------------------------------

## A paper about where `page` is, of `kind`, or {} when that kind has nothing
## true to say about it.
static func zone_hint(manifest: Dictionary, kind: String, page: Dictionary, entry: int, rng: RandomNumberGenerator) -> Dictionary:
	match kind:
		"limpieza": return cleaning(manifest, page, rng)
		"orden": return work_order(manifest, page, rng)
		"indicaciones": return directions(manifest, page, entry, rng)
		"cartel": return door_sign(manifest, page)
	return {}

## The maid's sheet: the block of rooms she had, the page's among them, each
## with how she left it, and under them in pencil that a paper turned up in one.
## Typed on the hotel's form (hotel_form.gd), like the work order: its number
## from the floor's seed, never from where the page is.
static func cleaning(manifest: Dictionary, page: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Array = manifest.rooms
	var target: Dictionary = rooms[int(page.room)]
	var near := FLOOR.route_metres(manifest, int(page.room))
	var numbered: Array = []
	for id in near:
		var room: Dictionary = rooms[int(id)]
		if int(room.wing) == int(target.wing) and int(room.get("number", 0)) > 0: numbered.append(int(id))
	numbered.sort_custom(func(a, b): return float(near[a]) < float(near[b]) or (is_equal_approx(float(near[a]), float(near[b])) and a < b))
	var count := rng.randi_range(6, 8)
	var block: Array = numbered.slice(0, count)
	if int(target.get("number", 0)) <= 0: block = numbered.slice(0, count - 1)
	block.sort_custom(func(a, b): return int(rooms[a].number) < int(rooms[b].number))
	var rows: Array = []
	for id in block: rows.append([str(int(rooms[id].number)), String(STATES[rng.randi_range(0, STATES.size() - 1)])])
	if int(target.get("number", 0)) <= 0: rows.append([String(FLOOR.NAMES[int(target.type)]).to_upper(), String(STATES[rng.randi_range(0, 3)])])
	var number := 1000 + absi(hash([manifest.seed, "limpieza"])) % 9000
	var form := {"number": "%04d" % number, "post": "LIMPIEZA, TURNO DE NOCHE", "place": "PLANTA %d" % (int(target.wing) + 1), "subject": "PARTE DE LIMPIEZA", "type": "tarea", "rows": rows, "state": "en_curso", "signed": true, "seed": number}
	return {"kind": "limpieza", "form": form, "printed": [], "rows": [], "hand": ["En una de estas, un papel con", "un número %s. No lo toqué." % String(IN_PIECE.get(String(page.kind), "en un mueble"))]}

## A work order: the dark stretch the page's room is in, by its numbers, or,
## when it is lit, a leak in the corridor near it with the wet floor sign put
## out there (`sign`, built with the hints).
static func work_order(manifest: Dictionary, page: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Array = manifest.rooms
	var target: Dictionary = rooms[int(page.room)]
	var number := rng.randi_range(210, 980)
	var form := {"number": "%04d" % number, "post": "MANTENIMIENTO", "place": "PLANTA %d" % (int(target.wing) + 1), "subject": "ORDEN DE TRABAJO", "type": "tarea", "priority": "media", "state": "pendiente", "seed": number}
	if bool(target.get("dark", false)):
		var stretch: Array = [int(page.room)]
		var queue: Array = [int(page.room)]
		while not queue.is_empty() and stretch.size() < 6:
			var here: int = queue.pop_front()
			for other in manifest.adjacency[here]:
				var next: Dictionary = rooms[int(other)]
				if stretch.has(int(other)) or not bool(next.get("dark", false)) or bool(next.get("corridor", false)): continue
				stretch.append(int(other))
				queue.append(int(other))
		var named: Array = []
		for id in stretch: named.append(room_said(rooms[id]))
		if named.size() >= 2:
			named.sort()
			form["lines"] = ["Sin luz en %s." % listed(named), "Revisar el diferencial."]
			return {"kind": "orden", "form": form, "printed": [], "rows": [], "hand": ["Dentro hay papeles con números.", "No es cosa mía."]}
	# Lit: a leak a door or two along the corridor, said by a room that is not
	# the page's.
	var sign := leak_spot(manifest, page)
	if sign.is_empty(): return {}
	form["lines"] = ["Fuga de agua en el pasillo, frente a %s." % String(sign.said), "Puesto el cartel de suelo mojado."]
	form["priority"] = "alta"
	return {"kind": "orden", "form": form, "printed": [], "rows": [], "hand": ["Por ahí cerca había un papel", "con un número."], "sign": sign}

## Where the leak is: a corridor cell beside the page's room or one along from
## it, and the room it is said to be in front of (never the page's own).
static func leak_spot(manifest: Dictionary, page: Dictionary) -> Dictionary:
	var rooms: Array = manifest.rooms
	var from := int(page.room)
	var near := FLOOR.route_metres(manifest, from)
	var best := -1
	for id in near:
		var room: Dictionary = rooms[int(id)]
		if int(room.wing) != int(rooms[from].wing) or not bool(room.get("corridor", false)): continue
		if best < 0 or float(near[id]) < float(near[best]): best = int(id)
	if best < 0: return {}
	var front := -1
	var front_metres := INF
	var at := FLOOR.position_of(rooms[best])
	for room in rooms:
		if int(room.id) == from or int(room.wing) != int(rooms[from].wing) or int(room.get("number", 0)) <= 0: continue
		var gap := FLOOR.position_of(room).distance_to(at)
		if gap < front_metres:
			front = int(room.id)
			front_metres = gap
	if front < 0: return {}
	return {"room": best, "position": at + Vector3(0.6, 0.0, 0.4), "yaw": 0.4, "said": "la %d" % int(rooms[front].number)}

## Written down by somebody from the lift, turn by turn, and torn off before
## the end: it leaves you in the stretch the page is in, not at its door.
static func directions(manifest: Dictionary, page: Dictionary, entry: int, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Array = manifest.rooms
	var path := way_between(manifest, entry, int(page.room))
	if path.size() < 4: return {}
	var merged := {}
	for pair in manifest.get("merged", []): merged["%d:%d" % [int(pair[0]), int(pair[1])]] = true
	# Legs: runs of the same heading, from cell centre to cell centre.
	var legs: Array = []
	for index in range(1, path.size()):
		var heading := heading_of(rooms[path[index - 1]], rooms[path[index]])
		if legs.is_empty() or legs[legs.size() - 1].heading != heading: legs.append({"heading": heading, "cells": [path[index - 1]]})
		legs[legs.size() - 1].cells.append(path[index])
	var lines: Array = []
	# Out of the lift's lobby: the turn straight away, or on first.
	if legs[0].cells.size() == 2: lines.append("Al salir del ascensor, %s." % turn_said(legs[0].heading, legs[1].heading))
	else: lines.append("Al salir del ascensor, recto.")
	for k in range(0 if legs[0].cells.size() > 2 else 1, legs.size() - 1):
		var leg: Dictionary = legs[k]
		var cells: Array = leg.cells
		var crossings := 0
		var fire := false
		for c in range(1, cells.size() - 1):
			if junction(manifest, int(cells[c])): crossings += 1
		for c in range(1, cells.size()):
			var a := mini(int(cells[c - 1]), int(cells[c]))
			var b := maxi(int(cells[c - 1]), int(cells[c]))
			if bool(rooms[a].get("corridor", false)) and bool(rooms[b].get("corridor", false)) and not merged.has("%d:%d" % [a, b]): fire = true
		var corner := int(cells[cells.size() - 1])
		var turn := turn_said(leg.heading, legs[k + 1].heading)
		var line := "%s, %s." % [("en el %s cruce" % ORDINALS[mini(crossings, ORDINALS.size() - 1)]) if junction(manifest, corner) else "donde el pasillo dobla", turn]
		# Through a room on the way: in by one door and out by another.
		if not bool(rooms[corner].get("corridor", false)): line = "cruza %s y sal %s." % [room_said(rooms[corner]), "de frente" if turn == "recto" else turn]
		if fire: line = "pasa la puerta de incendios y, %s" % line
		lines.append(line.substr(0, 1).to_upper() + line.substr(1))
	# Three turns at the least: fewer, torn, say nothing.
	if lines.size() < 3: return {}
	# Torn: the last of it gone, the one before it most of the way through.
	var keep := clampi(lines.size() - rng.randi_range(1, 2), 2, lines.size() - 1)
	var torn: String = lines[keep]
	var cut := clampi(int(torn.length() * rng.randf_range(0.55, 0.85)), 8, torn.length() - 3)
	var hand: Array = lines.slice(0, keep)
	hand.append(torn.substr(0, cut).strip_edges())
	return {"kind": "indicaciones", "printed": [], "rows": [], "hand": hand}

## A sign off a door: the room the page is in, if it is one a sign hangs on,
## or the one beside it through a door.
static func door_sign(manifest: Dictionary, page: Dictionary) -> Dictionary:
	var rooms: Array = manifest.rooms
	var target: Dictionary = rooms[int(page.room)]
	if SIGNS.has(int(target.type)):
		return {"kind": "cartel", "printed": [String(FLOOR.NAMES[int(target.type)]).to_upper(), String(SIGNS[int(target.type)])], "rows": [], "hand": ["La del número, aquí dentro."]}
	for other in manifest.adjacency[int(page.room)]:
		var next: Dictionary = rooms[int(other)]
		if bool(next.get("corridor", false)) or not SIGNS.has(int(next.type)): continue
		return {"kind": "cartel", "printed": [String(FLOOR.NAMES[int(next.type)]).to_upper(), String(SIGNS[int(next.type)])], "rows": [], "hand": ["La del número, en el cuarto", "de al lado."]}
	return {}

# --- In drawers: on the plan ---------------------------------------------------------

static func point_hint(manifest: Dictionary, kind: String, page: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var at := Vector2(float(page.position.x), float(page.position.z))
	match kind:
		"calco":
			var angle := rng.randf() * TAU
			var off := Vector2(cos(angle), sin(angle)) * CIRCLE * rng.randf_range(0.25, 0.55)
			return {"kind": "calco", "printed": [], "rows": [], "hand": [], "centre": at + off, "radius": CIRCLE}
		"plano":
			var shift := Vector2(rng.randf_range(-0.3, 0.3) * CORNER.x, rng.randf_range(-0.3, 0.3) * CORNER.y)
			return {"kind": "plano", "printed": ["PLANO DE EVACUACIÓN", "USTED ESTÁ AQ"], "rows": [], "hand": [], "window": Rect2(at - CORNER * 0.5 + shift, CORNER), "cross": at}
		"tiza": return chalk(manifest, page, rng)
	return {}

## The chalk: from a fire door (or, with none near, a salon's door, or the
## lift) along the corridors to the page's door, an arrow on a wall at every
## turn and every CHALK_EVERY metres, and a cross beside the door.
static func chalk(manifest: Dictionary, page: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Array = manifest.rooms
	var target := int(page.room)
	var wing := int(rooms[target].wing)
	var merged := {}
	for pair in manifest.get("merged", []): merged["%d:%d" % [int(pair[0]), int(pair[1])]] = true
	# Corridor cells at the page's door.
	var doors: Array = []
	for other in manifest.adjacency[target]:
		if bool(rooms[int(other)].get("corridor", false)): doors.append(int(other))
	if doors.is_empty(): return {}
	# Walking the corridors only, back from the door.
	var back := corridor_walk(manifest, doors)
	var starts: Array = []
	for room in rooms:
		if int(room.wing) != wing or not bool(room.get("corridor", false)) or not back.metres.has(int(room.id)): continue
		for other in manifest.adjacency[int(room.id)]:
			var next := int(other)
			if not bool(rooms[next].get("corridor", false)) or next < int(room.id): continue
			if merged.has("%d:%d" % [int(room.id), next]): continue
			var walked := float(back.metres[int(room.id)])
			if walked >= CHALK.x and walked <= CHALK.y: starts.append({"cell": int(room.id), "metres": walked, "from": "desde la puerta de incendios"})
	if starts.is_empty():
		for room in rooms:
			if int(room.wing) != wing or not bool(room.get("corridor", false)) or not back.metres.has(int(room.id)): continue
			var walked := float(back.metres[int(room.id)])
			if walked < CHALK.x or walked > CHALK.y: continue
			for other in manifest.adjacency[int(room.id)]:
				var next: Dictionary = rooms[int(other)]
				if int(next.type) == 10: starts.append({"cell": int(room.id), "metres": walked, "from": "desde el ascensor"})
				elif int(next.hall) >= 0 and SIGNS.has(int(next.type)): starts.append({"cell": int(room.id), "metres": walked, "from": "desde %s" % room_said(next).to_lower()})
	if starts.is_empty(): return {}
	starts.sort_custom(func(a, b): return absf(float(a.metres) - 35.0) < absf(float(b.metres) - 35.0) or (is_equal_approx(absf(float(a.metres) - 35.0), absf(float(b.metres) - 35.0)) and int(a.cell) < int(b.cell)))
	var start: Dictionary = starts[0]
	var cells: Array = [int(start.cell)]
	while back.parent.has(cells[cells.size() - 1]): cells.append(int(back.parent[cells[cells.size() - 1]]))
	cells.append(target)
	# An arrow on the right-hand wall of a stretch, near where it is walked
	# into, at the first stretch after every turn and every CHALK_EVERY metres
	# on a straight; a crossing has no walls to write on.
	var marks: Array = []
	var since := CHALK_EVERY
	var last := Vector2i.ZERO
	for index in range(0, cells.size() - 1):
		var here: Dictionary = rooms[int(cells[index])]
		var next: Dictionary = rooms[int(cells[index + 1])]
		var heading := heading_of(here, next)
		var way := Vector3(heading.x, 0, heading.y)
		var right := Vector3(-way.z, 0, way.x)
		var span := FLOOR.size_of(here)
		var length: float = span.x if heading.x != 0 else span.y
		var side: float = span.y * 0.5 if heading.x != 0 else span.x * 0.5
		if int(cells[index + 1]) == target:
			# Beside the page's door, on the corridor's side of its wall.
			var door := FLOOR.portal_between(next, here)
			marks.append({"room": int(here.id), "position": door - way * 0.08 + right * 0.95 + Vector3.UP * 1.45, "normal": -way, "along": right, "mark": "cross"})
			break
		var turned := heading != last
		last = heading
		if String(here.get("kind", "lane")) == "lane" and (turned or since >= CHALK_EVERY):
			marks.append({"room": int(here.id), "position": FLOOR.position_of(here) + right * (side - 0.03) - way * (length * 0.5 - 1.6) + Vector3.UP * 1.35, "normal": -right, "along": way, "mark": "arrow"})
			since = 0.0
		since += length
	if marks.size() < 2: return {}
	return {"kind": "tiza", "printed": [], "rows": [], "hand": ["Marqué el camino con tiza", "%s." % String(start.from)], "marks": marks}

## Metres walked along the corridors to the nearest of `doors`, and the next
## cell on the way there from each.
static func corridor_walk(manifest: Dictionary, doors: Array) -> Dictionary:
	var rooms: Array = manifest.rooms
	var metres := {}
	var parent := {}
	var open: Array = []
	for door in doors:
		metres[int(door)] = 0.0
		open.append(int(door))
	while not open.is_empty():
		var best := 0
		for index in open.size():
			if float(metres[open[index]]) < float(metres[open[best]]): best = index
		var at: int = open[best]
		open.remove_at(best)
		var here := FLOOR.position_of(rooms[at])
		for other in manifest.adjacency[at]:
			var next := int(other)
			if not bool(rooms[next].get("corridor", false)): continue
			var length: float = float(metres[at]) + here.distance_to(FLOOR.position_of(rooms[next]))
			if not metres.has(next) or length < float(metres[next]) - 0.001:
				if not metres.has(next): open.append(next)
				metres[next] = length
				parent[next] = at
	return {"metres": metres, "parent": parent}

# --- Where they lie -------------------------------------------------------------------

## The tops of the planta a paper can lie on, within ZONE_SPAN of the way.
static func surface_spots(manifest: Dictionary, wing: int, metres: Dictionary, deepest: float, refuge: int, blocked: Dictionary, rng: RandomNumberGenerator) -> Array:
	var spots: Array = []
	for room in manifest.rooms:
		if int(room.get("wing", -1)) != wing or int(room.id) == refuge or bool(room.get("landing", false)) or blocked.has(int(room.id)): continue
		var walked := float(metres.get(int(room.id), -1.0))
		if walked < maxf(ZONE_LEAST, deepest * ZONE_SPAN.x) or walked > deepest * ZONE_SPAN.y: continue
		for prop in room.props:
			if not SURFACES.has(prop.kind): continue
			var socket := GEOMETRY.prop_transform(room, prop)
			var local := Vector3(rng.randf_range(-0.18, 0.18), SURFACES[prop.kind] + 0.004, rng.randf_range(-0.15, 0.1))
			spots.append({"room": int(room.id), "sector": int(room.sector), "position": FLOOR.position_of(room) + socket * local, "yaw": socket.basis.get_euler().y + rng.randf_range(-0.6, 0.6)})
	return spots

## The pieces of furniture of the planta within `span` of the way, with no page
## in them.
static func drawer_spots(manifest: Dictionary, containers: Array, hiding: Array, wing: int, metres: Dictionary, deepest: float, refuge: int, span: Vector2) -> Array:
	var used := {}
	for hidden in hiding: used[int(hidden.container)] = true
	var spots: Array = []
	for index in containers.size():
		if used.has(index): continue
		var spot: Dictionary = containers[index]
		var room: Dictionary = manifest.rooms[int(spot.room)]
		if int(room.get("wing", -1)) != wing or int(room.id) == refuge or bool(room.get("landing", false)): continue
		var walked := float(metres.get(int(room.id), -1.0))
		if walked < deepest * span.x or walked > deepest * span.y: continue
		spots.append({"container": index, "room": int(room.id), "sector": int(room.sector), "position": spot.position, "yaw": float(spot.yaw)})
	return spots

## A place for a paper about `page`: never in its zone nor in a room already
## holding something, and as far from the other papers as the planta allows.
static func pick_spot(spots: Array, page: Dictionary, hints: Array, _rooms: Array, rng: RandomNumberGenerator) -> Dictionary:
	var best := {}
	var best_score := -INF
	var taken := {}
	for hint in hints: taken[int(hint.room)] = true
	for spot in spots:
		if int(spot.sector) == int(page.sector) or taken.has(int(spot.room)): continue
		var apart := 60.0
		for hint in hints: apart = minf(apart, (spot.position as Vector3).distance_to(hint.position))
		var score := apart + rng.randf() * 12.0
		if score > best_score:
			best_score = score
			best = spot
	return best

## The most out-of-the-way piece of furniture of the planta: the deepest walk
## from the lobby, more in a room with one door, more in the dark, never with
## a page in it, nor in a room already holding a paper, nor one of `skip`.
static func remotest(manifest: Dictionary, containers: Array, hiding: Array, wing: int, metres: Dictionary, deepest: float, refuge: int, blocked: Dictionary, skip: Dictionary = {}) -> Dictionary:
	var best := {}
	var best_score := -INF
	for spot in drawer_spots(manifest, containers, hiding, wing, metres, deepest, refuge, Vector2(0.0, 1.01)):
		if skip.has(int(spot.container)): continue
		if blocked.has(int(spot.room)): continue
		var room: Dictionary = manifest.rooms[int(spot.room)]
		var score := float(metres.get(int(spot.room), 0.0))
		if manifest.adjacency[int(spot.room)].size() == 1: score += 25.0
		if bool(room.get("dark", false)): score += 15.0
		score += float(int(spot.container) % 7) * 0.01
		if score > best_score:
			best_score = score
			best = spot
	return best

# --- Small helpers ----------------------------------------------------------------------

## The shortest walk from one room to another (by metres from centre to
## centre), as the rooms passed: [from, ..., to], or [] when there is none.
static func way_between(manifest: Dictionary, from: int, to: int) -> Array:
	var rooms: Array = manifest.rooms
	var metres := {from: 0.0}
	var parent := {}
	var open: Array = [from]
	while not open.is_empty():
		var best := 0
		for index in open.size():
			if float(metres[open[index]]) < float(metres[open[best]]): best = index
		var at: int = open[best]
		open.remove_at(best)
		if at == to: break
		var here := FLOOR.position_of(rooms[at])
		for other in manifest.adjacency[at]:
			var next := int(other)
			var length: float = float(metres[at]) + here.distance_to(FLOOR.position_of(rooms[next]))
			if not metres.has(next) or length < float(metres[next]) - 0.001:
				if not metres.has(next): open.append(next)
				metres[next] = length
				parent[next] = at
	if not metres.has(to): return []
	var path: Array = [to]
	while path[0] != from: path.push_front(int(parent[path[0]]))
	return path

## Which way one cell lies from the one before it, on the grid.
static func heading_of(a: Dictionary, b: Dictionary) -> Vector2i:
	var gap := FLOOR.position_of(b) - FLOOR.position_of(a)
	if absf(gap.x) >= absf(gap.z): return Vector2i(signi(int(roundf(gap.x))), 0)
	return Vector2i(0, signi(int(roundf(gap.z))))

## The turn from one heading to the next, said: right, left, or on.
static func turn_said(before: Vector2i, after: Vector2i) -> String:
	if after == before: return "recto"
	var right := Vector2i(-before.y, before.x)
	return "a la derecha" if after == right else "a la izquierda" if after == -right else "vuelve atrás"

## A corridor cell where corridors meet: three or more ways on.
static func junction(manifest: Dictionary, id: int) -> bool:
	var rooms: Array = manifest.rooms
	if not bool(rooms[id].get("corridor", false)): return false
	var ways := 0
	for other in manifest.adjacency[id]:
		if bool(rooms[int(other)].get("corridor", false)): ways += 1
	return ways >= 3

## A room as it would be named on a paper: «la 344», or «el almacén».
const THE := ["la", "la", "la", "la", "los", "el", "el", "la", "el", "el", "el", "el", "la", "la", "la", "la", "el", "el", "el", "el", "el"]
static func room_said(room: Dictionary) -> String:
	if int(room.get("number", 0)) > 0: return "la %d" % int(room.number)
	var type := int(room.type)
	return "%s %s" % [THE[type], String(FLOOR.NAMES[type]).to_lower()]

## «la 344, la 346 y la 348».
static func listed(names: Array) -> String:
	if names.size() == 1: return String(names[0])
	return ", ".join(names.slice(0, names.size() - 1)) + " y " + String(names[names.size() - 1])

static func shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap
