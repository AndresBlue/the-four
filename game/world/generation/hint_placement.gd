extends RefCounted
## The hints of the stage that asks for the code (the last, in the hotel):
## eight papers on its planta that say, each its own way, where the pages of
## the code are (the author, 20 October 2026, reworked on the 22nd after
## playing it). Four lie in sight on tables and desks, well short of the far
## end, one for each page: a maid's sheet and a work order that name the
## page's room, directions written down from the lift and torn before the
## end, and a Polaroid of the piece of furniture the page is in, taken in its
## room. Three more are for three of the pages: a carbon copy and a corner of
## an evacuation plan, in drawers further in, which put the page on the plan,
## and a "do not disturb" card hung on the door of the page's room, among a
## few others left blank on other doors. And one, in the most out-of-the-way
## room of the planta, is the sheet of somebody who was here before, with
## the four marked.
##
## None lies in the zone of its own page, nor in a room with a page. Worked
## out from the seed, the planta and the furniture, the same on every machine:
## nothing about them travels but who took the ones in drawers.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const DOCUMENTS := preload("res://game/world/generation/document_placement.gd")
const ZONE_KINDS := ["limpieza", "orden", "indicaciones", "polaroid"]
const POINT_KINDS := ["calco", "plano", "nomolestar"]
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
## The "do not disturb" cards left blank on other doors of the planta, so
## that a card on a door is not by itself the answer.
const BLANK_CARDS := 3
## How a maid ticks a room off.
const STATES := ["HECHA", "HECHA", "HECHA", "HECHA", "NO MOLESTAR", "SIN TOALLAS", "CAMA SIN HACER", "NO ABRE"]
## Where in a piece of furniture a paper is, said as a maid would say it.
const IN_PIECE := {"commode": "en un cajón", "console": "en una consola", "drawers": "en un cajón", "bookcase": "en una estantería", "cabinet": "en un mueble", "boxes": "en unas cajas", "luggage": "en una maleta"}
const ORDINALS := ["primer", "segundo", "tercer", "cuarto", "quinto", "sexto", "séptimo", "octavo"]

## Returns [{id, kind, slot (the page it is about, 0 for all four), place
## ("surface", "container", or "door" for the card), container (or -1),
## room, position, yaw, and what it shows: printed (lines), hand (lines),
## rows, and plan data}].
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
	var wider: Array = []
	for page in pages:
		var made := {}
		for attempt in kinds.size():
			var kind: String = kinds[(hints.size() + attempt) % kinds.size()]
			made = zone_hint(manifest, kind, page, entry, rng)
			if not made.is_empty(): break
		if made.is_empty(): made = zone_hint(manifest, "limpieza", page, entry, rng)
		var spot := pick_spot(surfaces, page, hints, rooms, rng)
		# Too few tables between the near and the far end: anywhere on the
		# planta a table is, but its zone.
		if spot.is_empty():
			if wider.is_empty(): wider = surface_spots(manifest, wing, metres, deepest, refuge, blocked, rng, Vector2(0.0, 1.01))
			spot = pick_spot(wider, page, hints, rooms, rng)
		if spot.is_empty(): continue
		blocked[int(spot.room)] = true
		made.merge({"id": hints.size(), "slot": int(page.slot), "place": "surface", "container": -1, "room": int(spot.room), "position": spot.position, "yaw": float(spot.yaw)}, true)
		hints.append(made)
	# Three on the plan, for three of the pages.
	var marked := pages.duplicate()
	shuffle(marked, rng)
	var ways := POINT_KINDS.duplicate()
	shuffle(ways, rng)
	# The card goes to a page whose room has a door to hang it on, if any has.
	var card_at := ways.find("nomolestar")
	if card_at < marked.size() and card(manifest, marked[card_at]).is_empty():
		for other in marked.size():
			if other == card_at or card(manifest, marked[other]).is_empty(): continue
			var swap: Dictionary = marked[other]
			marked[other] = marked[card_at]
			marked[card_at] = swap
			break
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
		# No door of its own to hang a card on: the plan's corner, or the
		# carbon copy, whichever is not there yet.
		if made.is_empty():
			var spare: Array = ["plano", "calco"].filter(func(kind): return not used.has(kind) and not ways.slice(index + 1, POINTS).has(kind))
			made = point_hint(manifest, String(spare[0]) if not spare.is_empty() else "calco", page, rng)
		used[String(made.kind)] = true
		# The card hangs on the page's own door, outside: not in a drawer.
		if String(made.kind) == "nomolestar":
			made.merge({"id": hints.size(), "slot": int(page.slot), "place": "door", "container": -1, "room": int(made.door[1]), "position": FLOOR.portal_between(rooms[int(made.door[0])], rooms[int(made.door[1])]), "yaw": 0.0}, true)
			made["blank"] = blank_cards(manifest, page_rooms, int(made.door[0]), wing, rng)
			hints.append(made)
			continue
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
		"polaroid": return {"kind": "polaroid", "printed": [], "rows": [], "hand": [], "shot": int(page.container)}
	return {}

## The maid's sheet: the block of rooms she had, the page's among them, each
## with how she left it, and under them, typed like the rest (the author's
## word, 22 October 2026), the room a paper with a number turned up in, and
## where in it. On the hotel's form (hotel_form.gd), like the work order: its
## number from the floor's seed, never from where the page is.
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
	form["lines"] = ["", "En %s encontré un papel con un número %s. No lo toqué." % [place_said(manifest, page), String(IN_PIECE.get(String(page.kind), "en un mueble"))]]
	return {"kind": "limpieza", "form": form, "printed": [], "rows": [], "hand": []}

## A work order about the page's own room, by its number (the author's word,
## 22 October 2026: the room it names is the one with the number): no light
## in it, or, when it is lit, a leak in the corridor in front of it with the
## wet floor sign put out there (`sign`, built with the hints); and, typed
## under it, that a paper with a number is in there.
static func work_order(manifest: Dictionary, page: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Array = manifest.rooms
	var target: Dictionary = rooms[int(page.room)]
	var number := rng.randi_range(210, 980)
	var form := {"number": "%04d" % number, "post": "MANTENIMIENTO", "place": "PLANTA %d" % (int(target.wing) + 1), "subject": "ORDEN DE TRABAJO", "type": "tarea", "priority": "media", "state": "pendiente", "seed": number}
	var said := place_said(manifest, page)
	var inside := "En %s hay un papel con un número %s. No es cosa mía." % [said, String(IN_PIECE.get(String(page.kind), "en un mueble"))]
	if bool(target.get("dark", false)):
		form["lines"] = ["Sin luz en %s." % said, "Revisar el diferencial.", "", inside]
		return {"kind": "orden", "form": form, "printed": [], "rows": [], "hand": []}
	# Lit: a leak in the corridor in front of it.
	var sign := leak_spot(manifest, page)
	if sign.is_empty(): return {}
	var leak := "Fuga de agua en %s." % said if bool(target.get("corridor", false)) else "Fuga de agua en el pasillo, frente %s." % to_said(said)
	form["lines"] = [leak, "Puesto el cartel de suelo mojado.", "", inside]
	form["priority"] = "alta"
	return {"kind": "orden", "form": form, "printed": [], "rows": [], "hand": [], "sign": sign}

## Where the leak is: the corridor cell nearest the page's room, which is the
## room the order says it is in front of.
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
	var at := FLOOR.position_of(rooms[best])
	return {"room": best, "position": at + Vector3(0.6, 0.0, 0.4), "yaw": 0.4, "said": room_said(rooms[from])}

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
			var window := Rect2(at - CORNER * 0.5 + shift, CORNER)
			# As a plan on a wall has them: the numbers of the rooms and the
			# names of the rest (the author's word, 22 October 2026), so the
			# corner is found by the plaques on the doors; and reading it puts
			# a circle round the page on the plan, as the carbon copy does.
			var labels: Array = []
			for room in manifest.rooms:
				if int(room.get("wing", -1)) != int(manifest.rooms[int(page.room)].wing) or bool(room.get("corridor", false)) or FLOOR.is_void(room): continue
				var middle := FLOOR.position_of(room)
				if not window.has_point(Vector2(middle.x, middle.z)): continue
				labels.append([Vector2(middle.x, middle.z), str(int(room.number)) if int(room.get("number", 0)) > 0 else String(FLOOR.NAMES[int(room.type)]).to_upper()])
			var angle := rng.randf() * TAU
			var off := Vector2(cos(angle), sin(angle)) * CIRCLE * rng.randf_range(0.25, 0.55)
			return {"kind": "plano", "printed": ["PLANO DE EVACUACIÓN", "USTED ESTÁ AQ"], "rows": [], "hand": [], "window": window, "cross": at, "labels": labels, "centre": at + off, "radius": CIRCLE}
		"nomolestar": return card(manifest, page)
	return {}

## The card on the page's own door: the door to a corridor (or, with none,
## any of its doors), hung outside on the knob; "no molestar" printed on it,
## and on its back, in pencil, that it is in there.
static func card(manifest: Dictionary, page: Dictionary) -> Dictionary:
	var room := int(page.room)
	var outside := -1
	for other in manifest.adjacency[room]:
		if bool(manifest.rooms[int(other)].get("corridor", false)) and has_leaf(manifest, room, int(other)) and (outside < 0 or int(other) < outside): outside = int(other)
	if outside < 0:
		for other in manifest.adjacency[room]:
			if has_leaf(manifest, room, int(other)) and (outside < 0 or int(other) < outside): outside = int(other)
	if outside < 0: return {}
	return {"kind": "nomolestar", "printed": ["NO MOLESTAR"], "rows": [], "hand": ["Está aquí dentro, %s." % String(IN_PIECE.get(String(page.kind), "en un mueble"))], "door": [room, outside]}

## The blank ones: on the corridor doors of other numbered rooms of the
## planta, none with a page, as guests leave them: [[room, corridor], ...].
static func blank_cards(manifest: Dictionary, page_rooms: Dictionary, own: int, wing: int, rng: RandomNumberGenerator) -> Array:
	var doors: Array = []
	for room in manifest.rooms:
		if int(room.get("wing", -1)) != wing or int(room.get("number", 0)) <= 0 or page_rooms.has(int(room.id)) or int(room.id) == own: continue
		for other in manifest.adjacency[int(room.id)]:
			if bool(manifest.rooms[int(other)].get("corridor", false)) and has_leaf(manifest, int(room.id), int(other)):
				doors.append([int(room.id), int(other)])
				break
	shuffle(doors, rng)
	return doors.slice(0, BLANK_CARDS)

## Whether a door with a leaf (hotel_geometry, Door_a_b) hangs between two
## rooms: not where two rooms were made one, nor a door of a stage.
static func has_leaf(manifest: Dictionary, a: int, b: int) -> bool:
	for pair in manifest.get("merged", []):
		if (int(pair[0]) == a and int(pair[1]) == b) or (int(pair[0]) == b and int(pair[1]) == a): return false
	for gate in manifest.get("gates", []):
		var beyond := int(gate.get("beyond", -1))
		if (int(gate.room) == a and beyond == b) or (int(gate.room) == b and beyond == a): return false
	return true

# --- Where they lie -------------------------------------------------------------------

## The tops of the planta a paper can lie on, within ZONE_SPAN of the way.
static func surface_spots(manifest: Dictionary, wing: int, metres: Dictionary, deepest: float, refuge: int, blocked: Dictionary, rng: RandomNumberGenerator, span := ZONE_SPAN) -> Array:
	var spots: Array = []
	for room in manifest.rooms:
		if int(room.get("wing", -1)) != wing or int(room.id) == refuge or bool(room.get("landing", false)) or blocked.has(int(room.id)): continue
		var walked := float(metres.get(int(room.id), -1.0))
		if walked < maxf(ZONE_LEAST, deepest * span.x) or walked > deepest * span.y: continue
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
## Where a page is, as a paper would say it: its room's number; a corridor by
## the numbered door nearest the page («el pasillo frente a la 312»); or what
## the room is («el almacén»).
static func place_said(manifest: Dictionary, page: Dictionary) -> String:
	var room: Dictionary = manifest.rooms[int(page.room)]
	if int(room.get("number", 0)) > 0 or not bool(room.get("corridor", false)): return room_said(room)
	var nearest := {}
	var gap := INF
	for other in manifest.rooms:
		if int(other.get("number", 0)) <= 0 or int(other.wing) != int(room.wing): continue
		var away := FLOOR.position_of(other).distance_to(page.position)
		if away < gap:
			gap = away
			nearest = other
	return "el pasillo" if nearest.is_empty() else "el pasillo frente a la %d" % int(nearest.number)

## «a» before what a place is called: «a la 308», «al almacén».
static func to_said(said: String) -> String:
	return "al " + said.trim_prefix("el ") if said.begins_with("el ") else "a " + said

static func room_said(room: Dictionary) -> String:
	if int(room.get("number", 0)) > 0: return "la %d" % int(room.number)
	var type := int(room.type)
	return "%s %s" % [THE[type], String(FLOOR.NAMES[type]).to_lower()]

static func shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap
