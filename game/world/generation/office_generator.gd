extends "res://game/world/generation/map_generator.gd"
## The offices' generator (docs/OFICINAS.md 11.3): the hotel's grid and
## refuges, drawn with the office palette, with each planta's own pieces laid
## as it is drawn (place_specials()), the rooms typed once every planta is
## there (finish()) and the systems written into the manifest (furnish()). It
## never preloads office_floor.gd, which preloads it.
const OFFICE_PALETTE := preload("res://game/floors/palettes/office_palette.gd")
const OFFICE_VALIDATOR := preload("res://game/world/generation/office_validator.gd")
const METRES := preload("res://game/world/generation/conduit_metres.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
## Generator-only tuning (not read by anything else).
const LOOSE_P := 0.3          # loose duct links between rooms (OFICINAS 11.3)
const CORRIDOR_EXIT_P := 0.5  # grilles on corridor cells
const WALL_EXIT_P := 0.15     # low wall grilles instead of ceiling ones
const TIMER_P := 0.65
const MAIN_TRIES := 64        # candidate paths ranked for the main duct
const GLAZED_P := 0.55        # each eligible wall of a despacho, exec office or secretaría
const READER_ALONG := 1.1     # a reader, from its door's centre along the wall (code_lock.gd:120's keypad)
const READER_Y := 1.2
const STOP_Y := 1.3
const CAMERA_DROP := 0.15     # the ceiling camera under the ceiling
const STAND_OUT := 0.6        # the typist's feet, out from the desk's point
const TABLE_OFFSET := 2.2     # the meeting table's centre from the boardroom's centre
const DESKS_MOST := 8         # free-standing items per cell
## The band a duct shortcut keeps against the walk (1c's validator has its own).
const SHORTCUT_MIN := 0.55
const EXPRESS_PER := 30       # straight trunks over the rooms, per planta
const EXPRESS_CELLS := Vector2i(2, 12) # how many cells one spans
const EXPRESS_MOST := 0.9     # a straight trunk cuts the walk to this or less
const EXPRESS_STARTS := 80    # cells tried as a trunk's start, per planta

func _init() -> void: palette = OFFICE_PALETTE

func validator() -> RefCounted: return OFFICE_VALIDATOR.new()

## The hotel's try, said to be floor 2's: FLOOR.palette() and every reader in
## play pick the office palette by "floor", and a checkpoint or a match
## compares "version" with office_floor.GENERATOR_VERSION.
func candidate(run_seed: int, attempt: int, standby := false) -> Dictionary:
	var result := super.candidate(run_seed, attempt, standby)
	if not result.is_empty():
		result["floor"] = 2
		result["version"] = OFFICE_PALETTE.VERSION
	return result

## Each planta's own band for its refuge (the climb, the power room's lift, the air plant).
func depth_wanted() -> Vector2: return palette.DEPTHS[laying]

## The least walk to the refuge, grown with the floor as the hotel's is.
func least_walk() -> float: return float(palette.LEAST_WALKS[laying]) * sqrt(drawing)

## The planta's own piece, laid once its refuge is there: the post's window on
## the first, the electrical room on the second, the security post and the
## main duct's way on the third. False draws the planta again.
func place_specials(f: Dictionary, planta: int, alive: Dictionary, arrival: int, back: Vector2i, refuge: Dictionary, rng: RandomNumberGenerator, standby: bool) -> bool:
	if not f.has("specials"): f["specials"] = [{}, {}, {}]
	f.specials[planta] = {}
	var base: int = f.base
	var shares := depth_shares(f, alive, arrival)
	if planta == 0:
		var band: Vector2 = palette.WINDOW_DEPTH
		var window := pick_special(f, candidates(f, alive, arrival, refuge, shares, band, standby, true, []), band, standby, rng, "window")
		if window < 0:
			fail("window")
			return false
		f.specials[0] = {"window": base + window}
		return true
	if planta == 1:
		var band: Vector2 = palette.ELECTRICAL_DEPTH
		var electrical := pick_special(f, candidates(f, alive, arrival, refuge, shares, band, standby, false, [], true), band, standby, rng, "electrical")
		if electrical < 0:
			fail("electrical")
			return false
		f.specials[1] = {"electrical": base + electrical}
		return true
	return place_air(f, alive, arrival, back, refuge, rng, standby)

## {local: metres / deepest} from where the planta is walked into: the share
## in_depth() judges the refuge by.
func depth_shares(f: Dictionary, alive: Dictionary, arrival: int) -> Dictionary:
	var metres := route_metres(f, alive, arrival)
	var deepest := 0.0
	for local in metres: deepest = maxf(deepest, float(metres[local]))
	if deepest <= 0.0: return {}
	var shares := {}
	for local in metres: shares[local] = float(metres[local]) / deepest
	return shares

## The cells a special room may take: whole modules of no salon, not the way
## in nor the refuge, inside the band (in standby the band only ranks).
func candidates(f: Dictionary, alive: Dictionary, arrival: int, refuge: Dictionary, shares: Dictionary, band: Vector2, standby: bool, corridor_door: bool, apart: Array, allow_service := false) -> Array:
	var base: int = f.base
	var out: Array = []
	var keys: Array = alive.keys()
	keys.sort()
	for key in keys:
		var local := int(key)
		var room := at(f, local)
		if room.kind != "module" or int(room.hall) >= 0: continue
		var service := bool(room.service)
		if service and not allow_service: continue
		if local == arrival or local == int(refuge.room) or local == int(refuge.landing): continue
		if not shares.has(local): continue
		if corridor_door:
			var on_corridor := false
			for g in f.adjacency[base + local]:
				# room.corridor is not written yet: a corridor is a live cell that is no module.
				if alive.has(int(g) - base) and f.rooms[int(g)].kind != "module": on_corridor = true
			if not on_corridor: continue
		var beside := false
		for way in WAYS:
			if apart.has(step(f, local, way)): beside = true
		if beside: continue
		var share := float(shares[local])
		if not standby and (share < band.x or share > band.y): continue
		out.append({"room": local, "share": share, "doors": f.adjacency[base + local].size(), "service": service, "weight": 1.0})
	return out

## One of the candidates, weighted by rule ("window": one or two doors;
## "electrical": one door, then service cells); in standby the one nearest the
## band's middle. -1 with none.
func pick_special(_f: Dictionary, pool: Array, band: Vector2, standby: bool, rng: RandomNumberGenerator, rule: String) -> int:
	if pool.is_empty(): return -1
	for entry in pool:
		var doors := int(entry.doors)
		if rule == "window": entry.weight = 2.0 if doors == 1 or doors == 2 else 1.0
		elif rule == "electrical":
			var weight := 1.0
			if doors == 1: weight *= 3.0
			if bool(entry.service): weight *= 1.5
			entry.weight = weight
	if standby:
		var middle := (band.x + band.y) / 2
		var ranked := pool.duplicate()
		ranked.sort_custom(func(a, b): return absf(float(a.share) - middle) < absf(float(b.share) - middle) or (absf(float(a.share) - middle) == absf(float(b.share) - middle) and int(a.room) < int(b.room)))
		return int(ranked[0].room)
	return int(weighted(pool, rng).room)

## The third planta: the air room and its plant are the refuge and its lobby,
## open to each other; a security post with one door, and the main duct's way.
func place_air(f: Dictionary, alive: Dictionary, arrival: int, back: Vector2i, refuge: Dictionary, rng: RandomNumberGenerator, standby: bool) -> bool:
	var base: int = f.base
	var air_room := int(refuge.room)
	var air_plant := int(refuge.landing)
	merge(f, base + air_room, base + air_plant)
	var shares := depth_shares(f, alive, arrival)
	var band: Vector2 = palette.SECURITY_DEPTH
	var pool := candidates(f, alive, arrival, refuge, shares, band, standby, false, [air_room, air_plant])
	for entry in pool: entry.weight = 4.0 if int(entry.doors) == 1 else 1.0
	var order: Array = []
	if standby:
		var middle := (band.x + band.y) / 2
		order = pool.duplicate()
		order.sort_custom(func(a, b): return absf(float(a.share) - middle) < absf(float(b.share) - middle) or (absf(float(a.share) - middle) == absf(float(b.share) - middle) and int(a.room) < int(b.room)))
	else:
		var left := pool.duplicate()
		while order.size() < 8 and not left.is_empty():
			var pick := weighted(left, rng)
			left.erase(pick)
			order.append(pick)
	var security := -1
	for entry in order.slice(0, 8):
		var local := int(entry.room)
		var saved := save(f)
		var trial := alive.duplicate()
		var cell := base + local
		var doors: Array = f.adjacency[cell].duplicate()
		doors.sort()
		var keep := int(doors[0]) if not doors.is_empty() else -1
		for d in doors:
			if f.rooms[int(d)].kind != "module":
				keep = int(d)
				break
		for d in doors:
			if int(d) != keep: unlink(f, cell, int(d))
		# Not past the air rooms either, as try_refuge() keeps them: a door join()
		# opened on to them would break the refuge's and the lobby's checks.
		join(f, trial, arrival, back, rng, [local, air_room, air_plant])
		if accepts_security(f, alive, trial, arrival, refuge, local, standby):
			alive.clear()
			alive.merge(trial)
			security = local
			break
		restore(f, saved)
	if security < 0:
		fail("security")
		return false
	var path := main_path(f, alive, arrival, refuge, rng, standby)
	if path.is_empty():
		fail("main_duct")
		return false
	f.specials[2] = {"air_room": base + air_room, "air_plant": base + air_plant, "security": base + security, "main_cells": path.cells, "main_exit": path.exit, "main_length": path.length, "main_bends": path.bends}
	return true

## Whether the planta still holds with the security post sealed to one door.
func accepts_security(f: Dictionary, alive: Dictionary, trial: Dictionary, arrival: int, refuge: Dictionary, local: int, standby: bool) -> bool:
	for key in alive:
		if not trial.has(key): return false
	if reach(f, arrival, trial).size() != trial.size(): return false
	if cycles(f, trial) < int(palette.rings(drawing)): return false
	if standby: return true
	var rooms_only := trial.duplicate()
	rooms_only.erase(int(refuge.landing))
	if not in_depth(f, rooms_only, arrival, int(refuge.room)): return false
	var population := 0
	for key in trial:
		if at(f, int(key)).kind == "module": population += 1
	var base: int = f.base
	if int(WALKER.score(f.rooms, f.adjacency, base + arrival, base + int(refuge.room), population).hits) != 0: return false
	var shares := depth_shares(f, trial, arrival)
	var band: Vector2 = palette.SECURITY_DEPTH
	if not shares.has(local): return false
	var share := float(shares[local])
	return share >= band.x and share <= band.y

## The main duct's way from the air plant out through a wall of the planta:
## the best of up to MAIN_TRIES paths, by how near its length is to the ideal.
func main_path(f: Dictionary, alive: Dictionary, arrival: int, refuge: Dictionary, rng: RandomNumberGenerator, standby: bool) -> Dictionary:
	var kept: Array = []
	walk_main(f, [int(refuge.landing)], alive, arrival, kept, rng, standby)
	if kept.is_empty(): return {}
	var best: Dictionary = kept[0]
	for entry in kept:
		if float(entry.score) > float(best.score): best = entry
	return {"cells": best.cells, "exit": best.exit, "length": best.length, "bends": best.bends}

## Depth first from the plant: every path of two cells or more is tried for a
## way out, then grown to six steps.
func walk_main(f: Dictionary, path: Array, alive: Dictionary, arrival: int, kept: Array, rng: RandomNumberGenerator, standby: bool) -> void:
	if kept.size() >= MAIN_TRIES: return
	var last := int(path[path.size() - 1])
	if path.size() >= 2:
		var s := way_between(f, int(path[path.size() - 2]), last)
		for e in WAYS:
			if e == -s: continue
			try_main_exit(f, path, alive, e, kept, rng, standby)
			if kept.size() >= MAIN_TRIES: return
	if path.size() - 1 < 6:
		for w in WAYS:
			var n := step(f, last, w)
			if n < 0 or not alive.has(n) or n == arrival or path.has(n): continue
			path.append(n)
			walk_main(f, path, alive, arrival, kept, rng, standby)
			path.pop_back()
			if kept.size() >= MAIN_TRIES: return

## Keeps the path if it can leave its last cell through e, within the lengths
## and bends the palette asks.
func try_main_exit(f: Dictionary, path: Array, alive: Dictionary, e: Vector2i, kept: Array, rng: RandomNumberGenerator, standby: bool) -> void:
	var half_wall: float = palette.WALL_HALF
	var shaft: Vector2 = palette.SHAFT
	var last := int(path[path.size() - 1])
	var last_room := at(f, last)
	var beyond := step(f, last, e)
	if beyond >= 0:
		if alive.has(beyond): return
		if along_span(at(f, beyond), e) < shaft.y + 2 * half_wall + 0.05: return
	if across_span(last_room, e) < shaft.x + 2 * half_wall + 0.05: return
	var d1 := way_between(f, int(path[0]), int(path[1]))
	var plant := at(f, int(path[0]))
	var hatch_in := float(palette.HATCH["in"])
	var hatch := centre_of(plant) + Vector2(d1) * (along_span(plant, d1) / 2 - hatch_in)
	var mouth := centre_of(last_room) + Vector2(e) * (along_span(last_room, e) / 2 + half_wall)
	var length := hatch.distance_to(centre_of(at(f, int(path[1]))))
	for i in range(1, path.size() - 1): length += centre_of(at(f, int(path[i]))).distance_to(centre_of(at(f, int(path[i + 1]))))
	length += centre_of(last_room).distance_to(mouth)
	var steps: Array = []
	for i in range(path.size() - 1): steps.append(way_between(f, int(path[i]), int(path[i + 1])))
	steps.append(e)
	var bends := 0
	for i in range(1, steps.size()):
		if steps[i] != steps[i - 1]: bends += 1
	if standby:
		if length < 15.0 or length > 70.0 or bends < 1: return
	else:
		var span: Vector2 = palette.MAIN_LENGTH
		if length < span.x or length > span.y or bends < int(palette.MAIN_BENDS): return
	var base: int = f.base
	var cells: Array = path.map(func(local): return base + int(local))
	kept.append({"cells": cells, "exit": [e.x, e.y], "length": length, "bends": bends, "score": -absf(length - float(palette.MAIN_IDEAL)) + rng.randf() * 4.0})

## The grid step from one cell to the next.
func way_between(f: Dictionary, a: int, b: int) -> Vector2i:
	var width: int = f.width
	return Vector2i(b % width - a % width, b / width - a / width)

## A cell's centre in plan.
func centre_of(room: Dictionary) -> Vector2:
	return Vector2(float(room.px), float(room.pz))

## A cell's size along a grid step.
func along_span(room: Dictionary, way: Vector2i) -> float:
	return float(room.span_x) if way.x != 0 else float(room.span_z)

## A cell's size across a grid step.
func across_span(room: Dictionary, way: Vector2i) -> float:
	return float(room.span_z) if way.x != 0 else float(room.span_x)

## The rooms made offices: corridors and galleries, the departments of each
## planta, the structure and the special pieces, the salons and the modules by
## their department's focus, what each planta must have, and the corners.
func finish(f: Dictionary, start: int, refuges: Array, entries: Array, decoration: RandomNumberGenerator) -> void:
	# Sectors first: the departments, and with them what each room becomes, hang on them.
	zones(f, entries)
	var typed := {}
	var locked := {}
	var galleries := {}
	for planta in WINGS:
		for line in f.plantas[planta].lines:
			if decoration.randf() < float(palette.GALLERY_SHARE): galleries["%d%s%d" % [planta, line.axis, line.index]] = true
	for room in f.rooms:
		if int(room.type) == palette.VOID or not room.corridor: continue
		var gallery: bool = galleries.has("%dv%d" % [int(room.wing), int(room.x)]) or galleries.has("%dh%d" % [int(room.wing), int(room.z)])
		room.type = palette.GALLERY if gallery else palette.CORRIDOR
		typed[int(room.id)] = true
	name_departments(f, decoration)
	var structure := {}
	structure[start] = palette.RECEPTION
	for planta in range(1, WINGS): structure[int(entries[planta])] = palette.LOBBY
	for room in f.rooms:
		if bool(room.get("landing", false)): structure[int(room.id)] = palette.AIR_PLANT if int(room.wing) == 2 else palette.LANDING
	structure[int(refuges[0])] = palette.REFUGE
	structure[int(refuges[1])] = palette.REFUGE
	structure[int(refuges[2])] = palette.AIR_ROOM
	structure[int(f.specials[0].window)] = palette.WINDOW
	structure[int(f.specials[1].electrical)] = palette.ELECTRICAL
	structure[int(f.specials[2].security)] = palette.SECURITY
	for id in structure:
		var room: Dictionary = f.rooms[int(id)]
		room.type = structure[id]
		typed[int(id)] = true
		locked[int(id)] = true
	for id in [int(refuges[0]), int(refuges[1]), int(refuges[2])]:
		f.rooms[id].hall = -1
		f.rooms[id].service = false
	for id in [int(f.specials[0].window), int(f.specials[1].electrical), int(f.specials[2].security)]: f.rooms[id].service = false
	# Salons, by their lowest id: one type for the whole of each.
	var halls := {}
	for room in f.rooms:
		if int(room.type) == palette.VOID or room.corridor or typed.has(int(room.id)) or int(room.hall) < 0: continue
		if not halls.has(int(room.hall)): halls[int(room.hall)] = []
		halls[int(room.hall)].append(int(room.id))
	var anchors: Array = halls.keys()
	anchors.sort_custom(func(a, b): return int(halls[a].min()) < int(halls[b].min()))
	for hall in anchors:
		var members: Array = halls[hall]
		var anchor: Dictionary = f.rooms[int(hall)]
		var weights: Dictionary = palette.HALL_MIX[int(anchor.wing)].duplicate()
		focus_weights(weights, focus_of(f, anchor))
		if not straight(f, members): weights.erase(palette.ARCHIVE)
		var pick := int(weighted(weight_list(weights), decoration).type)
		for id in members:
			f.rooms[int(id)].type = pick
			typed[int(id)] = true
	for room in f.rooms:
		if int(room.type) == palette.VOID or room.corridor or typed.has(int(room.id)): continue
		var wing := int(room.wing)
		if room.service:
			var service: Array = palette.SERVICE_BY_PLANTA[wing]
			room.type = int(service[decoration.randi_range(0, service.size() - 1)])
		else:
			var weights: Dictionary = palette.PLANTA_MIX[wing].duplicate()
			focus_weights(weights, focus_of(f, room))
			var pick := int(weighted(weight_list(weights), decoration).type)
			if pick == palette.BOARDROOM and not boardroom_fits(f, room): pick = palette.OFFICE
			room.type = pick
		typed[int(room.id)] = true
	for planta in WINGS: place_musts(f, planta, locked)
	cap_numbers(f, locked)
	for room in f.rooms:
		room.props = []
		room.cover_slots = 0
		room.variant = 0
		room.layout = 0
		room.height = palette.height_of(room)
		if int(room.type) == palette.VOID: continue
		room.variant = decoration.randi_range(0, 3)
		if room.corridor: continue
		room.cover_slots = 4
		var kinds: Array = palette.RECIPES[int(room.type)].duplicate()
		shuffle(kinds, decoration)
		for slot in 4:
			var kind: String = kinds[slot]
			if kind == "": continue
			var rotation := 0
			if kind in palette.WALL_KINDS: rotation = 0 if slot < 2 else 2
			else: rotation = decoration.randi_range(0, 3)
			room.props.append({"kind": kind, "slot": slot, "rotation": rotation})
	# Open sides: where a salon or a corridor carries on with no wall.
	for room in f.rooms: room["open_sides"] = []
	for pair in f.merged.values():
		var a: Dictionary = f.rooms[int(pair[0])]
		var b: Dictionary = f.rooms[int(pair[1])]
		var direction := "east" if int(b.x) > int(a.x) else "south"
		a.open_sides.append(direction)
		b.open_sides.append("west" if direction == "east" else "north")

## Each planta's departments, one per sector: the entrance's sector gets the
## first, the rest are drawn; on the third, the security post's sector is
## SEGURIDAD and the air room's MANTENIMIENTO.
func name_departments(f: Dictionary, decoration: RandomNumberGenerator) -> void:
	f["departments"] = [[], [], []]
	for planta in WINGS:
		var found := {}
		for room in f.rooms:
			if int(room.wing) == planta and int(room.type) != palette.VOID: found[int(room.sector)] = true
		var sectors: Array = found.keys()
		sectors.sort()
		var table: Array = palette.DEPARTMENTS[planta]
		var rest: Array = range(1, table.size())
		shuffle(rest, decoration)
		var colours: Array = range(palette.STRIPES.size())
		shuffle(colours, decoration)
		for i in sectors.size():
			var dep: Array = table[0] if i == 0 else table[int(rest[i - 1])]
			f.departments[planta].append({"sector": int(sectors[i]), "name": String(dep[0]), "colour": int(colours[i]), "focus": dep[1]})
	var third: Array = f.departments[2]
	var security_sector := int(f.rooms[int(f.specials[2].security)].sector)
	rename_sector(third, security_sector, "SEGURIDAD")
	var air_sector := int(f.rooms[int(f.specials[2].air_room)].sector)
	if air_sector != security_sector: rename_sector(third, air_sector, "MANTENIMIENTO")

## Gives a sector a department's name: swapped with the one that has it, or
## taken from the palette's table if none does.
func rename_sector(entries: Array, sector: int, title: String) -> void:
	var own: Dictionary = {}
	var holder: Dictionary = {}
	for entry in entries:
		if int(entry.sector) == sector: own = entry
		if String(entry.name) == title: holder = entry
	if own.is_empty() or String(own.name) == title: return
	if not holder.is_empty():
		var name_was: String = own.name
		var focus_was: Array = own.focus
		own.name = holder.name
		own.focus = holder.focus
		holder.name = name_was
		holder.focus = focus_was
		return
	for dep in palette.DEPARTMENTS[2]:
		if String(dep[0]) == title:
			own.name = title
			own.focus = dep[1]

## The focus types of the department a room's sector is.
func focus_of(f: Dictionary, room: Dictionary) -> Array:
	for entry in f.departments[int(room.wing)]:
		if int(entry.sector) == int(room.sector): return entry.focus
	return []

## A department's focus types weigh FOCUS times more.
func focus_weights(weights: Dictionary, focus: Array) -> void:
	for t in focus:
		if weights.has(t): weights[t] = float(weights[t]) * float(palette.FOCUS)

## [{type, weight}] by type, for weighted().
func weight_list(weights: Dictionary) -> Array:
	var keys: Array = weights.keys()
	keys.sort()
	return keys.map(func(t): return {"type": int(t), "weight": float(weights[t])})

## Whether a salon runs in one line (all one x or all one z).
func straight(f: Dictionary, members: Array) -> bool:
	var xs := {}
	var zs := {}
	for id in members:
		xs[int(f.rooms[int(id)].x)] = true
		zs[int(f.rooms[int(id)].z)] = true
	return xs.size() == 1 or zs.size() == 1

## A boardroom wants a large module, and none on the main duct's way.
func boardroom_fits(f: Dictionary, room: Dictionary) -> bool:
	if minf(float(room.span_x), float(room.span_z)) < float(palette.BOARDROOM_SIDE): return false
	return not (int(room.wing) == 2 and f.specials[2].main_cells.has(int(room.id)))

## A plain cell a must may take: a whole module, no corridor, no salon, no
## service, not settled yet.
func flat_cell(room: Dictionary, locked: Dictionary) -> bool:
	return room.kind == "module" and not room.corridor and int(room.hall) < 0 and not room.service and not locked.has(int(room.id))

## What each planta must have (MUSTS), an archive salon on the second, toilets
## in every big sector, and mobile archives only where their aisles run.
func place_musts(f: Dictionary, planta: int, locked: Dictionary) -> void:
	var rooms: Array = f.rooms.filter(func(r): return int(r.wing) == planta and int(r.type) != palette.VOID)
	var musts: Dictionary = palette.MUSTS[planta]
	var types: Array = musts.keys()
	types.sort()
	for t in types:
		var have := 0
		var seen_halls := {}
		for room in rooms:
			if int(room.type) != int(t): continue
			if int(room.hall) >= 0:
				if not seen_halls.has(int(room.hall)):
					seen_halls[int(room.hall)] = true
					have += 1
			else: have += 1
		var need := int(musts[t]) - have
		if need <= 0: continue
		var units: Array = []
		for room in rooms:
			if not flat_cell(room, locked): continue
			if int(t) == palette.BOARDROOM and not boardroom_fits(f, room): continue
			units.append({"order": float(room.order), "id": int(room.id), "members": [int(room.id)]})
		if int(t) == palette.ARCHIVE:
			for hall in salons(rooms, locked):
				if straight(f, hall.members): units.append({"order": float(f.rooms[int(hall.anchor)].order), "id": int(hall.anchor), "members": hall.members})
		units.sort_custom(func(a, b): return float(a.order) < float(b.order) or (float(a.order) == float(b.order) and int(a.id) < int(b.id)))
		for unit in units.slice(0, need):
			for id in unit.members:
				f.rooms[int(id)].type = int(t)
				locked[int(id)] = true
	# What the musts count on stays, lowest id first and a salon as one:
	# toilets and cap_numbers() take only unlocked rooms, and one drawn by the
	# mix can be the planta's only one.
	for t in types:
		var units := {}
		for room in rooms:
			if int(room.type) != int(t): continue
			var key := int(room.hall) if int(room.hall) >= 0 else -1 - int(room.id)
			if not units.has(key): units[key] = []
			units[key].append(int(room.id))
		var kept: Array = units.values()
		kept.sort_custom(func(x, y): return int(x.min()) < int(y.min()))
		for members in kept.slice(0, int(musts[t])):
			for id in members: locked[int(id)] = true
	if planta == 1:
		var has_archive := false
		for hall in salons(rooms, {}):
			if int(f.rooms[int(hall.members[0])].type) == palette.ARCHIVE: has_archive = true
		if not has_archive:
			var straights: Array = salons(rooms, locked).filter(func(hall): return straight(f, hall.members))
			straights.sort_custom(func(a, b): return float(f.rooms[int(a.anchor)].order) < float(f.rooms[int(b.anchor)].order) or (float(f.rooms[int(a.anchor)].order) == float(f.rooms[int(b.anchor)].order) and int(a.anchor) < int(b.anchor)))
			if not straights.is_empty():
				for id in straights[0].members:
					f.rooms[int(id)].type = palette.ARCHIVE
					locked[int(id)] = true
	var by_sector := {}
	for room in rooms:
		if room.corridor: continue
		if not by_sector.has(int(room.sector)): by_sector[int(room.sector)] = []
		by_sector[int(room.sector)].append(room)
	var sectors: Array = by_sector.keys()
	sectors.sort()
	for sector in sectors:
		var members: Array = by_sector[sector]
		if members.size() < 5: continue
		var toilets: Array = members.filter(func(r): return int(r.type) == palette.TOILETS)
		for r in toilets: locked[int(r.id)] = true
		if not toilets.is_empty(): continue
		var pool: Array = members.filter(func(r): return flat_cell(r, locked) and f.adjacency[int(r.id)].any(func(g): return bool(f.rooms[int(g)].corridor)))
		if pool.is_empty(): continue
		pool.sort_custom(func(a, b): return float(a.order) < float(b.order) or (float(a.order) == float(b.order) and int(a.id) < int(b.id)))
		pool[0].type = palette.TOILETS
		locked[int(pool[0].id)] = true
	for room in rooms:
		if int(room.type) != palette.MOBILE_ARCHIVE: continue
		var across := false
		var along := false
		for g in f.adjacency[int(room.id)]:
			if int(f.rooms[int(g)].x) != int(room.x): across = true
			else: along = true
		if across and along: room.type = palette.ARCHIVE

## The planta's salons with no member settled, each {anchor, members}, by anchor.
func salons(rooms: Array, locked: Dictionary) -> Array:
	var groups := {}
	for room in rooms:
		if int(room.hall) < 0 or room.corridor: continue
		if not groups.has(int(room.hall)): groups[int(room.hall)] = []
		groups[int(room.hall)].append(int(room.id))
	var anchors: Array = groups.keys()
	anchors.sort()
	var out: Array = []
	for anchor in anchors:
		var members: Array = groups[anchor]
		if members.any(func(id): return locked.has(int(id))): continue
		out.append({"anchor": int(anchor), "members": members})
	return out

## keep_to_hundred() for offices: what is over NUMBERED_MOST becomes a depot,
## never a salon nor a room already settled, and nothing is drawn.
func cap_numbers(f: Dictionary, locked: Dictionary) -> void:
	var was := {"base": f.base, "width": f.width, "height": f.height, "grid": f.grid, "lines": f.lines, "edge_base": f.edge_base}
	for planta in WINGS:
		var dims: Dictionary = f.plantas[planta]
		var let: Array = []
		var count := 0
		for local in int(dims.width) * int(dims.height):
			var room: Dictionary = f.rooms[int(dims.base) + local]
			if int(room.type) != palette.VOID and int(room.type) != palette.LANDING and numbers(room):
				count += 1
				if int(room.hall) < 0 and not locked.has(int(room.id)): let.append(room)
		var over: int = count - int(palette.NUMBERED_MOST)
		if over <= 0: continue
		use(f, planta)
		var rank := func(room: Dictionary) -> float:
			var near_service := false
			for way in WAYS:
				var next := step(f, int(room.id) - int(dims.base), way)
				if next >= 0 and bool(at(f, next).service): near_service = true
			return float(room.order) - (0.3 if near_service else 0.0)
		let.sort_custom(func(a, b): return rank.call(a) < rank.call(b) or (is_equal_approx(rank.call(a), rank.call(b)) and int(a.id) < int(b.id)))
		for room in let.slice(0, over):
			room.service = true
			room.type = palette.DEPOT
	f.merge(was, true)

# --- Systems (furnish) -------------------------------------------------------------------

## A random stream of its own for each system, so one system's draws never
## move another's.
func stream(run_seed: int, attempt: int, name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "office", name, attempt])
	return rng

## What the offices add to the manifest once doors, lockers and lamps are
## there: each system in the order of spec 2.5l, every wall spot registered so
## none lands on another, or {"fail": reason}.
func furnish(f: Dictionary, gates: Array, doors: Dictionary, run_seed: int, attempt: int, standby: bool) -> Dictionary:
	job_rooms = f.rooms
	job_standby = standby
	var job := {"f": f, "gates": gates, "doors": doors, "seed": run_seed, "attempt": attempt, "standby": standby, "out": {}, "taken": {}}
	for room in f.rooms:
		for h in room.get("hides", []):
			var hw := LAYOUT.hide_wall(h)
			register(job, int(room.id), String(hw.wall), float(hw.along), 0.65)
	for step_call in [furnish_lobby, furnish_archives, furnish_mail, furnish_power, furnish_air, furnish_sockets, furnish_glass, furnish_furniture, furnish_ducts, furnish_main]:
		var reason: String = step_call.call(job)
		if not reason.is_empty(): return {"fail": reason}
	var out: Dictionary = job.out
	out["floor"] = 2
	out["version"] = palette.VERSION
	var departments: Array = []
	for planta in f.departments:
		departments.append(planta.map(func(entry): return {"sector": int(entry.sector), "name": String(entry.name), "colour": int(entry.colour)}))
	out["departments"] = departments
	out["plenum"] = palette.PLENUM.duplicate(true)
	return out

## Spec 2.5c, the post: the window's desk, camera and map, the reader by the
## stage gate, the stations and the tube tree from the hub to every one.
func furnish_mail(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var rng := stream(int(job.seed), int(job.attempt), "tubes")
	var win := int(f.specials[0].window)
	var win_room: Dictionary = rooms[win]
	var py := float(win_room.py)
	var wall := ""
	for w in far_walls(win_room):
		if spot_free(job, win_room, String(w), 0.0, 0.9):
			wall = String(w)
			break
	if wall == "": return "window_desk"
	var desk := wall_spot(win_room, wall, 0.0, py, 0.55)
	register(job, win, wall, 0.0, 0.9)
	var n := LAYOUT.inward(wall)
	var p: Array = desk.point
	var stand := {"point": rounded(Vector3(float(p[0]) + n.x * STAND_OUT, py, float(p[2]) + n.y * STAND_OUT)), "yaw": LAYOUT.wall_yaw(wall)}
	# The camera: the opposite wall's ceiling corner farther from the main door.
	var opp := LAYOUT.wall_of(-LAYOUT.way_of(wall))
	var reach := LAYOUT.wall_length(win_room, opp) / 2 - float(palette.WALL_HALF) - 0.3
	var cam_y := py + float(palette.height_of(win_room)) - CAMERA_DROP
	var door := FLOOR.portal_between(win_room, rooms[main_door(f, win)])
	var plus := wall_point(win_room, opp, reach, cam_y, 0.3)
	var minus := wall_point(win_room, opp, -reach, cam_y, 0.3)
	var camera := plus
	if Vector2(minus.x, minus.z).distance_to(Vector2(door.x, door.z)) > Vector2(plus.x, plus.z).distance_to(Vector2(door.x, door.z)): camera = minus
	var sp: Array = stand.point
	var camera_target := rounded(Vector3(float(sp[0]), float(sp[1]) + 1.3, float(sp[2])))
	var side := 1.0 if absf(1.2) <= LAYOUT.wall_length(win_room, wall) / 2 - 0.4 - 0.3 else -1.0
	var map := wall_spot(win_room, wall, 1.2 * side, py + 1.5)
	register(job, win, wall, 1.2 * side, 0.3)
	var hub := wall_spot(win_room, wall, -0.9 * side, py + float(palette.STATION_Y))
	register(job, win, wall, -0.9 * side, 0.3)
	var reader := mail_reader(job)
	if reader.is_empty(): return "mail_reader"
	# The stations: eligible rooms, each with its spot and its tube fixed once.
	var area := float(f.areas[0])
	var count := clampi(roundi(11.0 * sqrt(area)) + rng.randi_range(-1, 1), int(palette.STATIONS.x), int(palette.STATIONS.y))
	var parent := door_tree(f, win, 0)
	var eligible := {}
	for room in rooms:
		var id := int(room.id)
		var t := int(room.type)
		if int(room.wing) != 0 or t == palette.VOID or bool(room.corridor) or palette.off_limits(room): continue
		if id == win or t == palette.RECEPTION or t == palette.ARCHIVE or t == palette.MOBILE_ARCHIVE or not parent.has(id): continue
		var spot := station_spot(job, room)
		if spot.is_empty(): continue
		var chain: Array = [id]
		while int(chain[0]) != win: chain.push_front(int(parent[int(chain[0])]))
		var owners: Array = []
		var points := tube_points(f, chain, hub, spot, owners)
		var length := 0.0
		for i in range(1, points.size()): length += (points[i] as Vector3).distance_to(points[i - 1])
		if length < float(palette.STATION_TUBE_MIN): continue
		eligible[id] = {"spot": spot, "points": points, "owners": owners}
	var hub_walk := METRES.walk_within(rooms, f.adjacency, win, INF)
	var sectors: Array = []
	for id in eligible:
		if not sectors.has(int(rooms[int(id)].sector)): sectors.append(int(rooms[int(id)].sector))
	sectors.sort()
	shuffle(sectors, rng)
	var ids: Array = eligible.keys()
	ids.sort()
	var placed: Array = []
	var walks: Array = []
	var relax := 1.0
	var dry := 0
	while placed.size() < count:
		var any := false
		for sector in sectors:
			if placed.size() >= count: break
			var best := -1
			var best_score := -INF
			for id in ids:
				if int(rooms[int(id)].sector) != int(sector) or placed.has(int(id)): continue
				var close := false
				for w in walks:
					if float(w.get(int(id), INF)) < float(palette.STATION_APART) * sqrt(area) * relax: close = true
				if close: continue
				var least := float(hub_walk.get(int(id), INF))
				for w in walks: least = minf(least, float(w.get(int(id), INF)))
				var score := least + rng.randf() * 4.0
				if score > best_score:
					best_score = score
					best = int(id)
			if best < 0: continue
			placed.append(best)
			walks.append(METRES.walk_within(rooms, f.adjacency, best, INF))
			var spot: Dictionary = eligible[best].spot
			register(job, best, String(spot.wall), float(spot.along), 0.3)
			any = true
		if placed.size() >= count: break
		if not any:
			dry += 1
			if dry >= 2: break
			relax = 0.8
	if placed.size() < int(palette.STATIONS.x): return "stations"
	var nums: Array = range(1, placed.size() + 1)
	shuffle(nums, rng)
	# The tube tree: every station's polyline, its points made nodes once.
	var tubes := {"nodes": [], "rooms": [], "edges": [], "exits": [], "hub": 0}
	var index := {}
	var pairs := {}
	var mouths: Array = []
	var hub_node := -1
	for id in placed:
		var points: Array = eligible[id].points
		var owners: Array = eligible[id].owners
		var last := -1
		for i in points.size():
			var at: Vector3 = points[i]
			var key := Vector3i(roundi(at.x * 1000), roundi(at.y * 1000), roundi(at.z * 1000))
			if not index.has(key):
				index[key] = tubes.nodes.size()
				tubes.nodes.append(rounded(at))
				tubes.rooms.append(int(owners[i]))
			var node: int = index[key]
			if i == 0: hub_node = node
			if last >= 0 and last != node:
				var pair := "%d:%d" % [mini(last, node), maxi(last, node)]
				if not pairs.has(pair):
					pairs[pair] = true
					tubes.edges.append([last, node, snappedf(at.distance_to(points[i - 1]), 0.001), "tube"])
			last = node
		mouths.append(last)
	var along_tube := METRES.metres(tubes, hub_node)
	tubes.exits.append({"node": hub_node, "room": win, "kind": "hub", "point": hub.point, "yaw": hub.yaw})
	for k in placed.size():
		var spot: Dictionary = eligible[placed[k]].spot
		tubes.exits.append({"node": mouths[k], "room": placed[k], "kind": "station", "point": spot.point, "yaw": spot.yaw, "number": int(nums[k]), "tube": snappedf(float(along_tube.get(mouths[k], INF)), 0.001)})
	job.out["tubes"] = tubes
	job.out["mail"] = {"window": win, "desk": desk, "stand": stand, "camera": rounded(camera), "camera_target": camera_target, "map": map, "reader": reader, "stations": placed.size()}
	return ""

## The swipe reader on the freight lobby's wall with the landing, beside the
## stage gate (code_lock.gd's keypad); {} when neither side has room.
func mail_reader(job: Dictionary) -> Dictionary:
	var f: Dictionary = job.f
	var gate: Dictionary = job.gates[0]
	var lobby := int(gate.room)
	var lobby_room: Dictionary = f.rooms[lobby]
	var away := Vector2i(int(gate.out[0]), int(gate.out[1]))
	var wall := LAYOUT.wall_of(away)
	var da := FLOOR.door_offset(lobby_room, int(gate.beyond))
	var s := float(-away.x) if away.x != 0 else float(away.y)
	for along in [da + s * READER_ALONG, da - s * READER_ALONG]:
		if absf(along) > LAYOUT.wall_length(lobby_room, wall) / 2 - 0.4: continue
		var near := false
		for h in lobby_room.get("hides", []):
			var hw := LAYOUT.hide_wall(h)
			if String(hw.wall) == wall and absf(float(hw.along) - along) < 1.05: near = true
		if near: continue
		var reader := wall_spot(lobby_room, wall, along, float(lobby_room.py) + READER_Y)
		reader["room"] = lobby
		register(job, lobby, wall, along, 0.15)
		return reader
	return {}

## {room: parent} of planta `wing`'s door graph from `from` (-1 for it), the
## shortest centre-to-centre metres, ties to the lower id; an off-limits room
## is reached but leads nowhere.
func door_tree(f: Dictionary, from: int, wing: int) -> Dictionary:
	var rooms: Array = f.rooms
	var dist := {from: 0.0}
	var parent := {from: -1}
	var done := {}
	while true:
		var at := -1
		for id in dist:
			if done.has(id): continue
			if at < 0 or float(dist[id]) < float(dist[at]) - 0.0001 or (absf(float(dist[id]) - float(dist[at])) <= 0.0001 and int(id) < at): at = int(id)
		if at < 0: break
		done[at] = true
		if at != from and palette.off_limits(rooms[at]): continue
		var here := FLOOR.position_of(rooms[at])
		for other in f.adjacency[at]:
			var next := int(other)
			var room: Dictionary = rooms[next]
			if int(room.wing) != wing or int(room.type) == palette.VOID or done.has(next): continue
			var d: float = float(dist[at]) + here.distance_to(FLOOR.position_of(room))
			if not dist.has(next) or d < float(dist[next]) - 0.0001 or (absf(d - float(dist[next])) <= 0.0001 and at < int(parent[next])):
				dist[next] = minf(d, float(dist.get(next, INF)))
				parent[next] = at
	return parent

## A station's wall spot: the wall opposite the room's first doorway first,
## then the other closed walls; {} with no free spot.
func station_spot(job: Dictionary, room: Dictionary) -> Dictionary:
	var walls: Array = []
	var ways := FLOOR.doorways(room)
	ways.sort_custom(func(a, b): return int(a.other) < int(b.other))
	if not ways.is_empty(): walls.append(LAYOUT.wall_of(-LAYOUT.way_of(String(ways[0].wall))))
	for w in ["west", "east", "north", "south"]:
		if not walls.has(w) and not room.get("open_sides", []).has(w): walls.append(w)
	for w in walls:
		for along in HIDE_SPOTS:
			if spot_free(job, room, String(w), float(along), 0.3):
				return wall_spot(room, String(w), float(along), float(room.py) + float(palette.STATION_Y))
	return {}

## A point 0.3 m in from a wall's inner face, square to it from `at` (a
## doorway's middle is on the cell edge, a mouth on the face: both runs line up).
func off_wall(room: Dictionary, wall: String, at: Vector3, y: float) -> Vector3:
	var n := LAYOUT.inward(wall)
	if wall == "west" or wall == "east": return Vector3(float(room.px) + LAYOUT.face(room, wall) + n.x * 0.3, y, at.z)
	return Vector3(at.x, y, float(room.pz) + LAYOUT.face(room, wall) + n.y * 0.3)

## A tube from the hub to a station along the room chain: up from the hub's
## mouth, in each room a run leaving each wall square 0.3 m in, over every
## door, and down into the station's mouth. `owners` gets each point's room.
func tube_points(f: Dictionary, chain: Array, hub_spot: Dictionary, station_spot_at: Dictionary, owners: Array = []) -> Array:
	var rooms: Array = f.rooms
	var ty := float(rooms[int(chain[0])].py) + float(palette.TUBE_Y)
	var points: Array = []
	var hp: Array = hub_spot.point
	var sp: Array = station_spot_at.point
	var add := func(at: Vector3, owner: int) -> void:
		points.append(at)
		owners.append(owner)
	add.call(Vector3(float(hp[0]), float(hp[1]), float(hp[2])), int(chain[0]))
	add.call(Vector3(float(hp[0]), ty, float(hp[2])), int(chain[0]))
	for i in chain.size():
		var id := int(chain[i])
		var room: Dictionary = rooms[id]
		var entry: Vector3
		var entry_wall: String
		if i == 0:
			entry = Vector3(float(hp[0]), ty, float(hp[2]))
			entry_wall = String(hub_spot.wall)
		else:
			var prev: Dictionary = rooms[int(chain[i - 1])]
			entry = FLOOR.portal_between(prev, room)
			entry_wall = LAYOUT.wall_of(Vector2i(int(prev.x) - int(room.x), int(prev.z) - int(room.z)))
		var exit: Vector3
		var exit_wall: String
		if i < chain.size() - 1:
			var next: Dictionary = rooms[int(chain[i + 1])]
			exit = FLOOR.portal_between(room, next)
			exit_wall = LAYOUT.wall_of(Vector2i(int(next.x) - int(room.x), int(next.z) - int(room.z)))
		else:
			exit = Vector3(float(sp[0]), ty, float(sp[2]))
			exit_wall = String(station_spot_at.wall)
		var p1 := off_wall(room, entry_wall, entry, ty)
		var p2 := off_wall(room, exit_wall, exit, ty)
		var across := entry_wall == "west" or entry_wall == "east"
		add.call(p1, id)
		if entry_wall == exit_wall:
			pass
		elif LAYOUT.way_of(entry_wall) == -LAYOUT.way_of(exit_wall):
			if across:
				add.call(Vector3(float(room.px), ty, p1.z), id)
				add.call(Vector3(float(room.px), ty, p2.z), id)
			else:
				add.call(Vector3(p1.x, ty, float(room.pz)), id)
				add.call(Vector3(p2.x, ty, float(room.pz)), id)
		elif across:
			add.call(Vector3(p2.x, ty, p1.z), id)
		else:
			add.call(Vector3(p1.x, ty, p2.z), id)
		add.call(p2, id)
		if i < chain.size() - 1: add.call(Vector3(exit.x, ty, exit.z), id)
	add.call(Vector3(float(sp[0]), ty, float(sp[2])), int(chain[-1]))
	add.call(Vector3(float(sp[0]), float(sp[1]), float(sp[2])), int(chain[-1]))
	return points

## Spec 2.5d, planta 1's power: the board, one circuit a sector with its
## lever, and the corridor timers.
func furnish_power(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var rng := stream(int(job.seed), int(job.attempt), "power")
	var el := int(f.specials[1].electrical)
	var el_room: Dictionary = rooms[el]
	var py := float(el_room.py)
	var board := {}
	for wall in far_walls(el_room):
		for along in [0.0, -1.8, 1.8]:
			if spot_free(job, el_room, String(wall), along, 0.9):
				board = wall_spot(el_room, String(wall), along, py)
				register(job, el, String(wall), along, 0.9)
				break
		if not board.is_empty(): break
	if board.is_empty(): return "board"
	# One circuit a sector, the levers in a drawn order.
	var entries: Array = f.departments[1].duplicate()
	entries.sort_custom(func(a, b): return int(a.sector) < int(b.sector))
	var order: Array = entries.duplicate()
	shuffle(order, rng)
	var circuits: Array = []
	for lever in order.size():
		var entry: Dictionary = order[lever]
		var members: Array = []
		for room in rooms:
			if int(room.wing) != 1 or int(room.type) == palette.VOID or int(room.sector) != int(entry.sector): continue
			if palette.off_limits(room) or int(room.id) == el: continue
			members.append(int(room.id))
		members.sort()
		circuits.append({"code": "R-%d" % (lever + 1), "name": String(entry.name), "sector": int(entry.sector), "colour": int(entry.colour), "lever": lever, "rooms": members})
	# The timers: one a corridor stretch drawn, then the longest until enough
	# of the corridor is covered.
	var b := int(f.plantas[1].base)
	var stretches: Array = []
	for line in f.plantas[1].lines:
		var cells: Array = line.cells
		var i := 0
		while i < cells.size():
			if not timed_lane(rooms[b + int(cells[i])]):
				i += 1
				continue
			var lanes: Array = []
			var j := i
			while j < cells.size() and timed_lane(rooms[b + int(cells[j])]):
				lanes.append(b + int(cells[j]))
				j += 1
			var all: Array = lanes.duplicate()
			if i > 0 and timed_cross(rooms[b + int(cells[i - 1])]): all.push_front(b + int(cells[i - 1]))
			if j < cells.size() and timed_cross(rooms[b + int(cells[j])]): all.append(b + int(cells[j]))
			stretches.append({"lanes": lanes, "rooms": all, "axis": String(line.axis)})
			i = j
	var corridor := 0
	for room in rooms:
		if int(room.wing) == 1 and int(room.type) != palette.VOID and bool(room.corridor): corridor += 1
	var timers: Array = []
	var covered := {}
	var used := {}
	for k in stretches.size():
		if rng.randf() >= TIMER_P: continue
		used[k] = true
		var timer := timer_button(job, stretches[k], py)
		if timer.is_empty(): continue
		timers.append(timer)
		for id in stretches[k].rooms: covered[int(id)] = true
	while corridor > 0 and float(covered.size()) / float(corridor) < float(palette.TIMER_COVER):
		var best := -1
		for k in stretches.size():
			if used.has(k): continue
			if best < 0 or stretches[k].rooms.size() > stretches[best].rooms.size() or (stretches[k].rooms.size() == stretches[best].rooms.size() and int(stretches[k].rooms[0]) < int(stretches[best].rooms[0])): best = k
		if best < 0: break
		used[best] = true
		var timer := timer_button(job, stretches[best], py)
		if timer.is_empty(): continue
		timers.append(timer)
		for id in stretches[best].rooms: covered[int(id)] = true
	if corridor > 0 and float(covered.size()) / float(corridor) < float(palette.TIMER_COVER): return "timers"
	job.out["power"] = {"room": el, "board": board, "circuits": circuits, "lift_lever": circuits.size(), "timers": timers}
	return ""

## A corridor lane cell, where a timed stretch runs.
func timed_lane(room: Dictionary) -> bool:
	return String(room.kind) == "lane" and int(room.type) != palette.VOID and bool(room.corridor)

## A crossing a timed stretch opens onto.
func timed_cross(room: Dictionary) -> bool:
	return String(room.kind) == "cross" and int(room.type) != palette.VOID

## A stretch's timer, its button on a side wall of an end lane cell well clear
## of the doorways; {} with no room for one.
func timer_button(job: Dictionary, stretch: Dictionary, py: float) -> Dictionary:
	var rooms: Array = job.f.rooms
	var ends: Array = [stretch.lanes[0]]
	if int(stretch.lanes[-1]) != int(stretch.lanes[0]): ends.append(stretch.lanes[-1])
	var walls: Array = ["west", "east"] if stretch.axis == "v" else ["north", "south"]
	for id in ends:
		var room: Dictionary = rooms[int(id)]
		for wall in walls:
			for along in HIDE_SPOTS:
				if not spot_free(job, room, String(wall), float(along), 0.3): continue
				var near := false
				for way in FLOOR.doorways(room):
					if String(way.wall) == wall and absf(float(along) - float(way.along)) < FLOOR.PORTAL / 2 + 1.0: near = true
				if near: continue
				var spot := wall_spot(room, String(wall), float(along), py + 1.2)
				register(job, int(id), String(wall), float(along), 0.3)
				var members: Array = stretch.rooms.duplicate()
				members.sort()
				return {"rooms": members, "sector": int(room.sector), "room": int(id), "wall": spot.wall, "along": spot.along, "point": spot.point, "yaw": spot.yaw}
	return {}

## Spec 2.5e, planta 2's air: the security post and its card door, the plant's
## hatch, handler and stop, and the shaft at the main duct's far end.
func furnish_air(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var sp: Dictionary = f.specials[2]
	var sec := int(sp.security)
	var sec_room: Dictionary = rooms[sec]
	var py := float(sec_room.py)
	var outside := int(f.adjacency[sec][0])
	var key := "%d:%d" % [mini(sec, outside), maxi(sec, outside)]
	job.doors[key].open = false
	job.doors[key]["lock"] = "card"
	# The post's console: a closed wall with no doorway, its middle when no
	# locker is near it.
	var desk := {}
	var doors := doorway_walls(sec_room)
	for wall in ["west", "east", "north", "south"]:
		if sec_room.get("open_sides", []).has(wall) or (doors.has(wall) and not bool(job.standby)): continue
		var clear := true
		for h in sec_room.get("hides", []):
			var hw := LAYOUT.hide_wall(h)
			if String(hw.wall) == wall and absf(float(hw.along)) <= 1.5: clear = false
		var at := INF
		if clear and spot_free(job, sec_room, wall, 0.0, 0.9):
			at = 0.0
		else:
			for along in HIDE_SPOTS:
				if spot_free(job, sec_room, wall, float(along), 0.9):
					at = float(along)
					break
		if at == INF: continue
		desk = wall_spot(sec_room, wall, at, py)
		register(job, sec, wall, at, 0.9)
		break
	if desk.is_empty(): return "security_desk"
	# Its reader, outside, on the side the door does not swing to.
	var out_room: Dictionary = rooms[outside]
	var rwall := LAYOUT.wall_of(Vector2i(int(sec_room.x) - int(out_room.x), int(sec_room.z) - int(out_room.z)))
	var da := FLOOR.door_offset(out_room, sec)
	var hinge := float(int(job.doors[key].hinge))
	var reader := {}
	for along in [da - hinge * READER_ALONG, da + hinge * READER_ALONG]:
		if absf(along) > LAYOUT.wall_length(out_room, rwall) / 2 - 0.4: continue
		var near := false
		for h in out_room.get("hides", []):
			var hw := LAYOUT.hide_wall(h)
			if String(hw.wall) == rwall and absf(float(hw.along) - along) < 1.05: near = true
		if near: continue
		reader = wall_spot(out_room, rwall, along, py + READER_Y)
		register(job, outside, rwall, along, 0.15)
		break
	if reader.is_empty(): return "security_reader"
	# The hatch over the plant, toward the main duct's first cell.
	var room := int(sp.air_room)
	var plant := int(sp.air_plant)
	var p_room: Dictionary = rooms[plant]
	var hatch_d: Dictionary = palette.HATCH
	var plenum: Dictionary = palette.PLENUM
	var c1: Dictionary = rooms[int(sp.main_cells[1])]
	var d1 := Vector2i(int(c1.x) - int(p_room.x), int(c1.z) - int(p_room.z))
	var hatch := Vector3(float(p_room.px) + d1.x * (float(p_room.span_x) / 2 - float(hatch_d["in"])), py + float(plenum.duct_y), float(p_room.pz) + d1.y * (float(p_room.span_z) / 2 - float(hatch_d["in"])))
	var foot := Vector3(hatch.x, py, hatch.z) + Vector3(-d1.x, 0, -d1.y) * float(hatch_d.stand)
	var hatch_local := Vector2(hatch.x - float(p_room.px), hatch.z - float(p_room.pz))
	var hatch_square := Rect2(hatch_local - Vector2(0.75, 0.75), Vector2(1.5, 1.5))
	var foot_local := Vector2(foot.x - float(p_room.px), foot.z - float(p_room.pz))
	# The duct's band from the hatch to the plant's wall.
	var band_half := float(plenum.main) / 2 + 0.3
	var edge := Vector2(d1.x * float(p_room.span_x) / 2, d1.y * float(p_room.span_z) / 2)
	var duct_band: Rect2
	if d1.x != 0: duct_band = Rect2(minf(hatch_local.x, edge.x), hatch_local.y - band_half, absf(edge.x - hatch_local.x), band_half * 2)
	else: duct_band = Rect2(hatch_local.x - band_half, minf(hatch_local.y, edge.y), band_half * 2, absf(edge.y - hatch_local.y))
	# The handler against a wall clear of the hatch, the duct and the ladder's foot.
	var unit_d: Vector3 = palette.AIR_UNIT
	var walls: Array = [LAYOUT.wall_of(-d1)]
	walls.append_array(["west", "east"] if d1.x == 0 else ["north", "south"])
	var unit := {}
	var unit_box := Rect2()
	var room_inner := LAYOUT.inner(p_room).grow(LAYOUT.INNER_PAD)
	for wall in walls:
		if p_room.get("open_sides", []).has(wall): continue
		for along in [0.0, -1.5, 1.5]:
			var box := LAYOUT.wall_rect(p_room, String(wall), along, unit_d.x / 2, unit_d.z)
			if not LAYOUT.fits_in(room_inner, box) or box.intersects(hatch_square) or box.intersects(duct_band): continue
			if LAYOUT.point_rect_distance(foot_local, box) < 1.0: continue
			unit = wall_spot(p_room, String(wall), along, py)
			unit_box = box
			register(job, plant, String(wall), along, unit_d.x / 2)
			break
		if not unit.is_empty(): break
	if unit.is_empty(): return "unit"
	var stop := {}
	for along in [float(unit.along) + (unit_d.x / 2 + 0.5), float(unit.along) - (unit_d.x / 2 + 0.5)]:
		if spot_free(job, p_room, String(unit.wall), along, 0.3):
			stop = wall_spot(p_room, String(unit.wall), along, py + STOP_Y)
			register(job, plant, String(unit.wall), along, 0.3)
			break
	if stop.is_empty(): return "stop"
	# The shaft past the main duct's last cell.
	var last: Dictionary = rooms[int(sp.main_cells[-1])]
	var e := Vector2i(int(sp.main_exit[0]), int(sp.main_exit[1]))
	var shaft_d: Vector2 = palette.SHAFT
	var reach := along_span(last, e) / 2 + float(palette.WALL_HALF)
	var mouth := Vector3(float(last.px) + e.x * reach, py + float(plenum.duct_y), float(last.pz) + e.y * reach)
	var cc := Vector2(mouth.x + e.x * shaft_d.y / 2, mouth.z + e.y * shaft_d.y / 2)
	var sx := shaft_d.y if e.x != 0 else shaft_d.x
	var sz := shaft_d.x if e.x != 0 else shaft_d.y
	var floor_y := py + float(plenum.duct_y) - float(plenum.main) / 2
	var ladder := {"point": rounded(Vector3(cc.x + e.x * (shaft_d.y / 2 - 0.45), floor_y, cc.y + e.y * (shaft_d.y / 2 - 0.45))), "yaw": LAYOUT.yaw_of(-e)}
	var shaft := {"point": rounded(mouth), "side": [e.x, e.y], "rect": [snappedf(cc.x, 0.001), snappedf(cc.y, 0.001), snappedf(sx, 0.001), snappedf(sz, 0.001)], "floor_y": snappedf(floor_y, 0.001), "ladder": ladder}
	job.gates[2]["kind"] = "shaft"
	rooms[int(job.gates[2].beyond)].erase("lift")
	job.out["air"] = {"security": {"room": sec, "door": key, "outside": outside, "desk": desk, "reader": reader}, "room": room, "plant": plant, "hatch": {"point": rounded(hatch), "yaw": LAYOUT.yaw_of(-d1)}, "unit": unit, "stop": stop, "shaft": shaft}
	job["foot"] = foot
	job["hatch_square"] = hatch_square
	job["unit_box"] = unit_box
	return ""

## Spec 2.5f, the corner sockets; then the corner props that would stand on a
## locker, a wall fixture's clear rect, the hatch or the handler give way.
func furnish_sockets(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var view := working(job)
	var plant := int(f.specials[2].air_plant)
	for room in f.rooms:
		if int(room.type) == palette.VOID or bool(room.corridor): continue
		var sx := float(room.span_x) / 2 - float(palette.SOCKET_INSET)
		var sz := float(room.span_z) / 2 - float(palette.SOCKET_INSET)
		var lift := FLOOR.lift_wall(room)
		var most := (float(room.span_x) * absi(lift.x) + float(room.span_z) * absi(lift.y)) / 2 - FLOOR.LIFT_DEPTH - 0.9
		var sockets: Array = []
		for s in [Vector2(-sx, -sz), Vector2(sx, -sz), Vector2(-sx, sz), Vector2(sx, sz)]:
			var at: Vector2 = s
			if lift != Vector2i.ZERO:
				var along := at.x * lift.x + at.y * lift.y
				if along > most: at -= Vector2(lift) * (along - most)
			sockets.append([snappedf(at.x, 0.001), snappedf(at.y, 0.001)])
		room["sockets"] = sockets
		var keep_clear: Array = []
		for h in room.get("hides", []):
			var hw := LAYOUT.hide_wall(h)
			keep_clear.append(LAYOUT.wall_rect(room, String(hw.wall), float(hw.along), LAYOUT.LOCKER.x / 2, LAYOUT.LOCKER.y))
		for fx in LAYOUT.fixtures(view, int(room.id)):
			keep_clear.append(LAYOUT.wall_rect(room, String(fx.wall), float(fx.along), LAYOUT.FIXTURE_CLEAR.x / 2, LAYOUT.FIXTURE_CLEAR.y))
		# Where a door's leaf swings: a corner piece there stops it.
		for way in FLOOR.doorways(room):
			keep_clear.append(LAYOUT.wall_rect(room, String(way.wall), float(way.along), FLOOR.PORTAL / 2 + LAYOUT.DOOR_SIDE, LAYOUT.DOOR_BAND))
		if int(room.id) == plant:
			keep_clear.append(job.hatch_square)
			keep_clear.append(job.unit_box)
		var props: Array = []
		for prop in room.props:
			var s: Array = sockets[int(prop.slot)]
			var size := Vector2(2.3, 1.4) if int(prop.rotation) % 2 == 0 else Vector2(1.4, 2.3)
			var corner := Rect2(Vector2(float(s[0]), float(s[1])) - size / 2, size)
			if not keep_clear.any(func(r): return corner.intersects(r)): props.append(prop)
		room.props = props
	return ""

## Spec 2.5g, the glass partitions on the corridor side: the window always,
## the other glazed types by draw, written on both sides of the wall.
func furnish_glass(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var rng := stream(int(job.seed), int(job.attempt), "glazed")
	for room in rooms: room["glazed"] = []
	var win := int(f.specials[0].window)
	var near: Array = []
	for n in f.adjacency[win]:
		if bool(rooms[int(n)].corridor): near.append(int(n))
	near.sort()
	var done := false
	for n in near:
		var wall := LAYOUT.wall_of(Vector2i(int(rooms[n].x) - int(rooms[win].x), int(rooms[n].z) - int(rooms[win].z)))
		if wall != "" and glazable(job, rooms[win], wall):
			glaze(job, rooms[win], wall)
			done = true
			break
	if not done: return "window_glass"
	for room in rooms:
		if int(room.id) == win or not palette.GLAZED_TYPES.has(int(room.type)): continue
		for wall in ["west", "east", "north", "south"]:
			if glazable(job, room, wall) and rng.randf() < GLAZED_P: glaze(job, room, wall)
	return ""

## Whether a wall can be glass: a glazed type's closed side onto a corridor or
## gallery not merged with it, no lift wall or gate, nothing on either face.
func glazable(job: Dictionary, room: Dictionary, wall: String) -> bool:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	if not palette.GLAZED_TYPES.has(int(room.type)) or room.get("open_sides", []).has(wall): return false
	var way := LAYOUT.way_of(wall)
	var n := FLOOR.beside(room, way)
	if n < 0: return false
	var other: Dictionary = rooms[n]
	var t := int(other.type)
	if t == palette.VOID or (t != palette.CORRIDOR and t != palette.GALLERY) or f.merged.has(pair_key(int(room.id), n)): return false
	if FLOOR.lift_wall(room) == way or FLOOR.lift_wall(other) == -way: return false
	for gate in job.gates:
		var pair := [int(gate.room), int(gate.beyond)]
		if pair.has(int(room.id)) and pair.has(n): return false
	var opposite := LAYOUT.wall_of(-way)
	for h in room.get("hides", []):
		if String(LAYOUT.hide_wall(h).wall) == wall: return false
	for h in other.get("hides", []):
		if String(LAYOUT.hide_wall(h).wall) == opposite: return false
	for entry in job.taken.get(int(room.id), []):
		if String(entry.wall) == wall: return false
	for entry in job.taken.get(n, []):
		if String(entry.wall) == opposite: return false
	return true

## Glass on a wall, seen from both rooms.
func glaze(job: Dictionary, room: Dictionary, wall: String) -> void:
	var way := LAYOUT.way_of(wall)
	room.glazed.append(wall)
	job.f.rooms[FLOOR.beside(room, way)].glazed.append(LAYOUT.wall_of(-way))

## Spec 2.5h, the free-standing furniture: desks on a lattice, cubicle pods
## kept whole, the boardroom's table, and the pieces that stand on a wall.
func furnish_furniture(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var view := working(job)
	job["wall_items"] = {}
	for room in rooms: room["furniture"] = []
	for room in rooms:
		var t := int(room.type)
		if t != palette.OPEN_OFFICE and t != palette.CUBICLES and t != palette.BOARDROOM and t != palette.COPY_ROOM and t != palette.MAIL and t != palette.SECRETARY: continue
		var zones := LAYOUT.clear_zones(view, room, t == palette.BOARDROOM)
		if t == palette.OPEN_OFFICE or t == palette.CUBICLES: lay_lattice(f, room, zones)
		elif t == palette.BOARDROOM: lay_table(room, zones)
		else:
			var kind: String = "copier" if t == palette.COPY_ROOM else "pigeonholes" if t == palette.MAIL else "card_index"
			lay_on_wall(job, room, zones, kind, 2 if t == palette.MAIL else 1)
	return ""

## A furniture item as the manifest keeps it.
func item(kind: String, at: Vector2, turn: int, group: int, length := 0.0) -> Dictionary:
	var spec: Dictionary = palette.FURNITURE[kind]
	var size: Vector2 = spec.size
	if kind == "partition": size.x = length
	return {"kind": kind, "at": [snappedf(at.x, 0.001), snappedf(at.y, 0.001)], "turn": turn, "size": [snappedf(size.x, 0.001), snappedf(size.y, 0.001)], "extra": {"height": float(spec.height), "group": group}}

## Whether an item fits: inside the walls, clear of every zone, ITEM_GAP from
## the pieces of other groups.
func item_fits(room: Dictionary, zones: Array, piece: Dictionary) -> bool:
	var r := LAYOUT.footprint(piece)
	if not LAYOUT.fits_in(LAYOUT.inner(room), r) or LAYOUT.blocked(r, zones): return false
	for other in room.furniture:
		if int(other.extra.group) == int(piece.extra.group): continue
		if not LAYOUT.apart(r, LAYOUT.footprint(other), LAYOUT.ITEM_GAP): return false
	return true

## Open offices and cubicles: a lattice from the inner corner, desks turned
## along the hall; a cubicle pod is kept whole or not at all.
func lay_lattice(f: Dictionary, room: Dictionary, zones: Array) -> void:
	var along_x := float(room.span_x) >= float(room.span_z)
	if int(room.hall) >= 0:
		along_x = true
		for other in f.rooms:
			if int(other.hall) == int(room.hall) and int(other.z) != int(room.z): along_x = false
	var turn := 0 if along_x else 1
	var pods: bool = int(room.type) == palette.CUBICLES
	var size: Vector2 = Vector2(1.92, 1.49) if pods else palette.FURNITURE.desk_pair.size
	if turn % 2 == 1: size = Vector2(size.y, size.x)
	var space := LAYOUT.inner(room)
	var z := space.position.y + size.y / 2
	while LAYOUT.fits_in(space, Rect2(Vector2(space.position.x, z - size.y / 2), size)):
		var x := space.position.x + size.x / 2
		var column := 0
		while LAYOUT.fits_in(space, Rect2(Vector2(x - size.x / 2, z - size.y / 2), size)):
			var at := Vector2(x, z)
			var group: int = room.furniture.size()
			if not pods:
				var piece := item("desk_pair", at, turn, group)
				if room.furniture.size() < DESKS_MOST and item_fits(room, zones, piece): room.furniture.append(piece)
			else:
				var side := 1.0 if column % 2 == 0 else -1.0
				var spin := Basis(Vector3.UP, turn * PI / 2)
				var back := spin * Vector3(0, 0, -0.73)
				var beside := spin * Vector3(side * 0.93, 0, 0)
				var pod := [item("desk", at, turn, group), item("partition", at + Vector2(back.x, back.z), turn, group, 1.8), item("partition", at + Vector2(beside.x, beside.z), (turn + 1) % 4, group, 1.46)]
				if room.furniture.size() + 3 <= DESKS_MOST and pod.all(func(piece): return item_fits(room, zones, piece)): room.furniture.append_array(pod)
			x += size.x + LAYOUT.ITEM_GAP
			column += 1
		z += size.y + LAYOUT.ITEM_GAP

## The boardroom's table off the middle, with room to walk round it.
func lay_table(room: Dictionary, zones: Array) -> void:
	var spots: Array = [[Vector2(0, TABLE_OFFSET), 0], [Vector2(0, -TABLE_OFFSET), 0], [Vector2(TABLE_OFFSET, 0), 1], [Vector2(-TABLE_OFFSET, 0), 1]]
	if float(room.span_z) < float(room.span_x): spots = [spots[2], spots[3], spots[0], spots[1]]
	for spot in spots:
		var piece := item("meeting_table", spot[0], int(spot[1]), 0)
		if not item_fits(room, zones, piece): continue
		var r := LAYOUT.footprint(piece)
		var clear := r.grow_individual(0.6, 1.55, 0.6, 1.55) if int(spot[1]) % 2 == 0 else r.grow_individual(1.55, 0.6, 1.55, 0.6)
		if not LAYOUT.fits_in(LAYOUT.inner(room), clear): continue
		room.furniture.append(piece)
		return

## Up to `most` pieces of a kind with their backs to a closed wall.
func lay_on_wall(job: Dictionary, room: Dictionary, zones: Array, kind: String, most: int) -> void:
	var spec: Dictionary = palette.FURNITURE[kind]
	var size: Vector2 = spec.size
	var turns := {"north": 0, "west": 1, "south": 2, "east": 3}
	for wall in ["west", "east", "north", "south"]:
		if room.get("open_sides", []).has(wall): continue
		var n := LAYOUT.inward(wall)
		var off := LAYOUT.face(room, wall) + (n.x + n.y) * (0.05 + size.y / 2)
		for along in [0.0, -2.0, 2.0]:
			var at := Vector2(off, along) if wall == "west" or wall == "east" else Vector2(along, off)
			var piece := item(kind, at, int(turns[wall]), room.furniture.size())
			if not item_fits(room, zones, piece): continue
			room.furniture.append(piece)
			if not job.wall_items.has(int(room.id)): job.wall_items[int(room.id)] = []
			job.wall_items[int(room.id)].append({"wall": wall, "along": along, "half": size.x / 2})
			if room.furniture.size() >= most: return

## Spec 2.5i, the ducts: one graph over the three plantas, trunks along the
## corridors and a branch to every room, bridges and loose links that keep
## every shortcut within SHORTCUT_MIN of walking, the crossing's side duct, the
## exits and the gaps.
func furnish_ducts(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var rng := stream(int(job.seed), int(job.attempt), "ducts")
	var plenum: Dictionary = palette.PLENUM
	var ducts := {"nodes": [], "edges": [], "exits": []}
	job["ducts"] = ducts
	job["node_of"] = {}
	job["duct_pairs"] = {}
	var cells: Array = [[], [], []]
	for planta in 3:
		for room in rooms:
			if int(room.wing) == planta and int(room.type) != palette.VOID and not palette.off_limits(room): cells[planta].append(int(room.id))
		cells[planta].sort()
		var in_c := {}
		for id in cells[planta]:
			in_c[id] = true
			var room: Dictionary = rooms[id]
			job.node_of[id] = duct_node(job, Vector3(float(room.px), float(room.py) + float(plenum.duct_y), float(room.pz)), id, "trunk" if bool(room.corridor) else "branch")
		# Trunks along the corridors.
		for pair in f.edges:
			var a := int(pair[0])
			var b := int(pair[1])
			if in_c.has(a) and in_c.has(b) and bool(rooms[a].corridor) and bool(rooms[b].corridor): duct_edge(job, a, b, "trunk")
		# A branch to every room, by hops from the corridors.
		var level := {}
		var current: Array = []
		for id in cells[planta]:
			if bool(rooms[id].corridor):
				level[id] = 0
				current.append(id)
		var hops := 0
		while not current.is_empty():
			var next: Array = []
			for id in current:
				for n in f.adjacency[id]:
					if in_c.has(int(n)) and not level.has(int(n)) and not next.has(int(n)): next.append(int(n))
			next.sort()
			for id in next: level[id] = hops + 1
			for id in next:
				var parent := -1
				for n in f.adjacency[id]:
					if int(level.get(int(n), -1)) != hops: continue
					var better: bool = parent < 0 or (bool(rooms[int(n)].corridor) and not bool(rooms[parent].corridor)) or (bool(rooms[int(n)].corridor) == bool(rooms[parent].corridor) and int(n) < parent)
					if better: parent = int(n)
				duct_edge(job, parent, id, "branch")
			current = next
			hops += 1
		# Bridges until the planta is one piece: first the doors the branch tree
		# left between two pieces (two rooms each hung from its own corridor),
		# as good as walking, lowest pair first; then grid neighbours with no
		# door, the best L / walk first, none under SHORTCUT_MIN.
		var label := duct_pieces(job, cells[planta])
		for pair in grid_pairs(f, cells[planta], in_c, true):
			var a := int(pair[0])
			var b := int(pair[1])
			if not f.adjacency[a].has(b) or int(label[a]) == int(label[b]): continue
			duct_edge(job, a, b, "bridge")
			label = duct_pieces(job, cells[planta])
		var nodes: Array = cells[planta].map(func(id): return int(job.node_of[id]))
		var ratios := {}
		while METRES.pieces(ducts, nodes) > 1:
			label = duct_pieces(job, cells[planta])
			var best: Array = []
			var best_ratio := -1.0
			for pair in grid_pairs(f, cells[planta], in_c):
				var a := int(pair[0])
				var b := int(pair[1])
				if int(label[a]) == int(label[b]): continue
				var key := pair_key(a, b)
				if not ratios.has(key): ratios[key] = shortcut(f, a, b)
				if float(ratios[key]) > best_ratio:
					best_ratio = float(ratios[key])
					best = [a, b]
			if best.is_empty() or best_ratio < SHORTCUT_MIN: return "duct_bridge"
			duct_edge(job, int(best[0]), int(best[1]), "bridge")
		# Loose links, the shortcuts.
		var loose: Array = []
		for pair in grid_pairs(f, cells[planta], in_c):
			if not job.duct_pairs.has(pair_key(int(pair[0]), int(pair[1]))): loose.append(pair)
		loose.sort_custom(func(x, y): return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
		shuffle(loose, rng)
		var drawn := 0
		for pair in loose:
			if rng.randf() >= LOOSE_P: continue
			if shortcut(f, int(pair[0]), int(pair[1])) >= SHORTCUT_MIN:
				duct_edge(job, int(pair[0]), int(pair[1]), "loose")
				drawn += 1
		# A planta the draw left without one gets the best shortcut there is,
		# lowest pair on a tie; some have none in reach (one in five or so),
		# and drawing those again cost too many floors.
		if drawn == 0:
			var best: Array = []
			var best_ratio := SHORTCUT_MIN
			loose.sort_custom(func(x, y): return int(x[0]) < int(y[0]) or (int(x[0]) == int(y[0]) and int(x[1]) < int(y[1])))
			for pair in loose:
				var ratio := shortcut(f, int(pair[0]), int(pair[1]))
				if ratio > best_ratio or (best.is_empty() and ratio >= SHORTCUT_MIN):
					best_ratio = ratio
					best = pair
			if not best.is_empty(): duct_edge(job, int(best[0]), int(best[1]), "loose")
		# Straight trunks over the rooms, the doors left aside: the duct is her
		# shortcut (OFICINAS 11.3), between SHORTCUT_MIN and EXPRESS_MOST of
		# the walk from door to door, over cells all hers to cross.
		# Each start keeps its longest trunk that cuts the walk enough.
		var starts: Array = cells[planta].duplicate()
		shuffle(starts, rng)
		if not job.has("door_graph"): job["door_graph"] = METRES.door_graph(rooms, f.adjacency)
		var laid := 0
		for a in starts.slice(0, EXPRESS_STARTS):
			if laid >= EXPRESS_PER: break
			var from: Dictionary = rooms[int(a)]
			var walks := METRES.door_metres_all(rooms, job.door_graph, int(a), 12.0 * EXPRESS_CELLS.y / SHORTCUT_MIN)
			var best := -1
			var best_length := 0.0
			for way in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var b := int(a)
				for k in EXPRESS_CELLS.y:
					b = FLOOR.beside(rooms[b], way)
					if b < 0 or not in_c.has(b): break
					if k + 1 < EXPRESS_CELLS.x or job.duct_pairs.has(pair_key(int(a), b)) or not walks.has(b): continue
					var length := FLOOR.position_of(from).distance_to(FLOOR.position_of(rooms[b]))
					var ratio := length / float(walks[b])
					if ratio >= SHORTCUT_MIN and ratio <= EXPRESS_MOST and length > best_length:
						best = b
						best_length = length
			if best < 0: continue
			duct_edge(job, int(a), best, "express")
			laid += 1
	var crossed := duct_cross(job, rng)
	if not crossed.is_empty(): return crossed
	for planta in 3:
		var reason := duct_exits(job, planta, cells[planta], rng)
		if not reason.is_empty(): return reason
	for planta in 3:
		var reason := duct_gaps(job, planta, cells[planta], rng)
		if not reason.is_empty(): return reason
	job.out["ducts"] = ducts
	return ""

## A duct node [x, y, z, room, kind]; its index.
func duct_node(job: Dictionary, at: Vector3, room: int, kind: String) -> int:
	var p := rounded(at)
	job.ducts.nodes.append([p[0], p[1], p[2], room, kind])
	return job.ducts.nodes.size() - 1

## A node's point.
func node_point(job: Dictionary, node: int) -> Vector3:
	var n: Array = job.ducts.nodes[node]
	return Vector3(float(n[0]), float(n[1]), float(n[2]))

## A duct edge between two nodes, its metres the 3D distance.
func node_edge(job: Dictionary, a: int, b: int, kind: String) -> void:
	job.ducts.edges.append([a, b, snappedf(node_point(job, a).distance_to(node_point(job, b)), 0.001), kind])

## A duct edge between two cells' nodes, noted by the pair of cells.
func duct_edge(job: Dictionary, a: int, b: int, kind: String) -> void:
	job.duct_pairs[pair_key(a, b)] = job.ducts.edges.size()
	node_edge(job, int(job.node_of[a]), int(job.node_of[b]), kind)

## The grid neighbours east and south of each cell, both in C and with no door
## between them, as [a, b].
func grid_pairs(f: Dictionary, cells: Array, in_c: Dictionary, doors := false) -> Array:
	var pairs: Array = []
	for a in cells:
		for way in [Vector2i(1, 0), Vector2i(0, 1)]:
			var b := FLOOR.beside(f.rooms[int(a)], way)
			if b >= 0 and in_c.has(b) and (doors or not f.adjacency[int(a)].has(b)): pairs.append([int(a), b])
	return pairs

## A link's length over the walk it saves, walked from door to door; 0 when
## the walk is too long.
func shortcut(f: Dictionary, a: int, b: int) -> float:
	var length := FLOOR.position_of(f.rooms[a]).distance_to(FLOOR.position_of(f.rooms[b]))
	var walk := METRES.door_metres(f.rooms, f.adjacency, a, b, length / SHORTCUT_MIN)
	return length / walk if walk > 0.0 else 0.0

## {cell: piece} of a planta's cells over the duct edges so far, by union and find.
func duct_pieces(job: Dictionary, cells: Array) -> Dictionary:
	var up := {}
	var cell_of := {}
	for id in cells:
		up[int(job.node_of[id])] = int(job.node_of[id])
		cell_of[int(job.node_of[id])] = int(id)
	var find := func(node: int) -> int:
		var at := node
		while int(up[at]) != at: at = int(up[at])
		return at
	for edge in job.ducts.edges:
		var a := int(edge[0])
		var b := int(edge[1])
		if not up.has(a) or not up.has(b): continue
		var ra: int = find.call(a)
		var rb: int = find.call(b)
		if ra != rb: up[maxi(ra, rb)] = mini(ra, rb)
	var label := {}
	for node in up: label[cell_of[node]] = find.call(node)
	return label

## The main duct's floor line in plan: the hatch, the main cells' centres
## after the plant, the shaft's mouth.
func main_line(job: Dictionary) -> Array:
	if job.has("main_line"): return job.main_line
	var f: Dictionary = job.f
	var sp: Dictionary = f.specials[2]
	var air: Dictionary = job.out.air
	var hp: Array = air.hatch.point
	var line: Array = [Vector2(float(hp[0]), float(hp[2]))]
	for i in range(1, sp.main_cells.size()): line.append(centre_of(f.rooms[int(sp.main_cells[i])]))
	var mp: Array = air.shaft.point
	line.append(Vector2(float(mp[0]), float(mp[2])))
	job["main_line"] = line
	return line

## Spec 2.5i step 6: where the main duct meets her network, a side duct out of
## a main cell split at STUB past the main's wall.
func duct_cross(job: Dictionary, rng: RandomNumberGenerator) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var sp: Dictionary = f.specials[2]
	var plenum: Dictionary = palette.PLENUM
	var main: Array = sp.main_cells
	var line := main_line(job)
	var candidates: Array = []
	var walked: float = (line[0] as Vector2).distance_to(line[1])
	for i in range(1, main.size()):
		var c := int(main[i])
		if i > 1: walked += centre_of(rooms[int(main[i - 1])]).distance_to(centre_of(rooms[c]))
		if not job.node_of.has(c): continue
		var into := way_between(f, int(main[i - 1]), c)
		var out: Vector2i = way_between(f, c, int(main[i + 1])) if i < main.size() - 1 else Vector2i(int(sp.main_exit[0]), int(sp.main_exit[1]))
		var ns: Array = []
		for way in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if way == -into or way == out: continue
			var n := FLOOR.beside(rooms[c], way)
			if n < 0 or not job.node_of.has(n) or main.has(n) or int(rooms[n].wing) != 2: continue
			if not job.duct_pairs.has(pair_key(c, n)): continue
			ns.append(n)
		if not ns.is_empty(): candidates.append({"cell": c, "share": walked / float(sp.main_length), "ns": ns})
	var target := 0.5 + rng.randf_range(-0.2, 0.2)
	if candidates.is_empty(): return "main_cross"
	var pick: Dictionary = candidates[0]
	for entry in candidates:
		var gap := absf(float(entry.share) - target)
		var best_gap := absf(float(pick.share) - target)
		if gap < best_gap or (gap == best_gap and int(entry.cell) < int(pick.cell)): pick = entry
	var c := int(pick.cell)
	var ns: Array = pick.ns
	ns.sort()
	var n := int(ns[0])
	for other in ns:
		if String(job.ducts.edges[int(job.duct_pairs[pair_key(c, int(other))])][3]) == "trunk":
			n = int(other)
			break
	var stub := Vector2i(int(rooms[n].x) - int(rooms[c].x), int(rooms[n].z) - int(rooms[c].z))
	var reach := float(plenum.main) / 2 + float(palette.STUB)
	var centre := centre_of(rooms[c]) + Vector2(stub) * reach
	var owner := c if reach <= along_span(rooms[c], stub) / 2 else n
	var s := duct_node(job, Vector3(centre.x, float(rooms[c].py) + float(plenum.duct_y), centre.y), owner, "stub")
	var index := int(job.duct_pairs[pair_key(c, n)])
	var kind := String(job.ducts.edges[index][3])
	var cn := int(job.node_of[c])
	job.ducts.edges[index] = [cn, s, snappedf(node_point(job, cn).distance_to(node_point(job, s)), 0.001), kind]
	node_edge(job, s, int(job.node_of[n]), kind)
	job["cross"] = {"cell": c, "stub": [stub.x, stub.y], "s_node": s}
	return ""

## Whether a point in plan keeps clear of the main duct and its stub.
func main_clear(job: Dictionary, at: Vector2) -> bool:
	var reach := float(palette.PLENUM.main) / 2 + float(palette.MAIN_CLEAR)
	var line := main_line(job)
	for i in range(1, line.size()):
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, line[i - 1], line[i])) < reach: return false
	var c := int(job.cross.cell)
	var s := node_point(job, int(job.cross.s_node))
	if at.distance_to(Geometry2D.get_closest_point_to_segment(at, centre_of(job.f.rooms[c]), Vector2(s.x, s.z))) < reach: return false
	return true

## The tiles a ceiling exit or a gap may take in a room, in free_tiles' order.
func exit_tiles(job: Dictionary, room: Dictionary) -> Array:
	if not job.has("tiles"): job["tiles"] = {}
	if job.tiles.has(int(room.id)): return job.tiles[int(room.id)]
	var out: Array = []
	var shelves: bool = int(room.type) == palette.ARCHIVE or int(room.type) == palette.MOBILE_ARCHIVE
	for tile in palette.free_tiles(room):
		var c: Vector3 = palette.tile_centre(tile, 0.0)
		if int(room.wing) == 2 and not main_clear(job, Vector2(c.x, c.z)): continue
		if shelves:
			var under := false
			for unit in job.out.archives:
				for row in unit.rows:
					if c.x >= float(row[0]) and c.x <= float(row[2]) and c.z >= float(row[1]) and c.z <= float(row[3]): under = true
			if under: continue
		out.append(tile)
	job.tiles[int(room.id)] = out
	return out

## An exit: its own node, dropped from its cell's node.
func add_exit(job: Dictionary, room: Dictionary, kind: String, at: Vector3, yaw: float) -> void:
	var id := int(room.id)
	var node := duct_node(job, at, id, "exit")
	node_edge(job, int(job.node_of[id]), node, "drop")
	job.ducts.exits.append({"node": node, "room": id, "kind": kind, "point": rounded(at), "yaw": yaw})

## A low wall grille, the first free place on the given walls; false with none.
func wall_exit(job: Dictionary, room: Dictionary, walls: Array) -> bool:
	var id := int(room.id)
	var items: Array = job.wall_items.get(id, [])
	for wall in walls:
		if room.get("open_sides", []).has(wall) or room.get("glazed", []).has(wall): continue
		for along in HIDE_SPOTS:
			if not spot_free(job, room, String(wall), float(along), 0.3): continue
			if items.any(func(it): return String(it.wall) == wall and absf(float(it.along) - float(along)) < 1.0): continue
			var zone := LAYOUT.wall_rect(room, String(wall), float(along), LAYOUT.FIXTURE_CLEAR.x / 2, LAYOUT.FIXTURE_CLEAR.y)
			if room.get("furniture", []).any(func(it): return zone.intersects(LAYOUT.footprint(it))): continue
			var hit := false
			for prop in room.get("props", []):
				var s: Array = room.sockets[int(prop.slot)]
				var size := Vector2(2.3, 1.4) if int(prop.rotation) % 2 == 0 else Vector2(1.4, 2.3)
				if zone.intersects(Rect2(Vector2(float(s[0]), float(s[1])) - size / 2, size)): hit = true
			if hit: continue
			var spot := wall_spot(room, String(wall), float(along), float(room.py) + float(palette.WALL_GRILLE_Y))
			register(job, id, String(wall), float(along), 0.3)
			var p: Array = spot.point
			add_exit(job, room, "wall", Vector3(float(p[0]), float(p[1]), float(p[2])), float(spot.yaw))
			return true
	return false

## A ceiling grille on one of the given tiles, drawn.
func ceiling_exit(job: Dictionary, room: Dictionary, tiles: Array, rng: RandomNumberGenerator) -> void:
	var tile: Vector2i = tiles[rng.randi_range(0, tiles.size() - 1)]
	job.grille[int(room.id)] = tile
	add_exit(job, room, "ceiling", palette.tile_centre(tile, float(room.py) + float(palette.height_of(room))), 0.0)

## An exit under the cell's own duct where there is no false ceiling, moved
## off the main when it crosses the cell; false when none fits.
func open_exit(job: Dictionary, room: Dictionary) -> bool:
	var f: Dictionary = job.f
	var plenum: Dictionary = palette.PLENUM
	var id := int(room.id)
	var node := node_point(job, int(job.node_of[id]))
	var section: Array = plenum.duct if String(job.ducts.nodes[int(job.node_of[id])][4]) == "trunk" else plenum.branch
	var y := float(room.py) + float(plenum.duct_y) - float(section[1]) / 2
	var tries: Array = [Vector2(node.x, node.z)]
	var main: Array = f.specials[2].main_cells
	var i := main.find(id)
	if i >= 1:
		var into := way_between(f, int(main[i - 1]), id)
		var across := Vector2(0, 2.0) if into.x != 0 else Vector2(2.0, 0)
		tries = []
		for at in [Vector2(node.x, node.z) + across, Vector2(node.x, node.z) - across]:
			var local: Vector2 = at - centre_of(room)
			if absf(local.x) <= float(room.span_x) / 2 - 0.3 and absf(local.y) <= float(room.span_z) / 2 - 0.3: tries.append(at)
	for at in tries:
		if int(room.wing) == 2 and not main_clear(job, at): continue
		add_exit(job, room, "duct", Vector3(at.x, y, at.y), 0.0)
		return true
	return false

## Spec 2.5i step 7 for a planta: one exit a room, corridor grilles by draw,
## and one in every lane run that has none.
func duct_exits(job: Dictionary, planta: int, cells: Array, rng: RandomNumberGenerator) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	if not job.has("grille"): job["grille"] = {}
	var main: Array = f.specials[2].main_cells
	var has_exit := {}
	for id in cells:
		var room: Dictionary = rooms[id]
		if bool(room.corridor): continue
		has_exit[id] = true
		if not palette.false_ceiling(room):
			if not open_exit(job, room) and not main.has(id): return "duct_exit"
			continue
		var shelves: bool = int(room.type) == palette.ARCHIVE or int(room.type) == palette.MOBILE_ARCHIVE
		if not shelves and rng.randf() < WALL_EXIT_P and wall_exit(job, room, ["west", "east", "north", "south"]): continue
		var tiles := exit_tiles(job, room)
		if not tiles.is_empty():
			ceiling_exit(job, room, tiles, rng)
			continue
		if not wall_exit(job, room, ["west", "east", "north", "south"]): return "duct_exit"
	for id in cells:
		var room: Dictionary = rooms[id]
		if not bool(room.corridor): continue
		if rng.randf() >= CORRIDOR_EXIT_P: continue
		if not palette.false_ceiling(room):
			if open_exit(job, room): has_exit[id] = true
			continue
		var tiles := exit_tiles(job, room)
		if tiles.is_empty(): continue
		ceiling_exit(job, room, tiles, rng)
		has_exit[id] = true
	var b := int(f.plantas[planta].base)
	var in_c := {}
	for id in cells: in_c[id] = true
	for line in f.plantas[planta].lines:
		for segment in line.segments:
			var runs: Array = []
			var run: Array = []
			for local in segment:
				var id := b + int(local)
				if String(rooms[id].kind) == "lane" and in_c.has(id): run.append(id)
				else:
					if not run.is_empty(): runs.append(run)
					run = []
			if not run.is_empty(): runs.append(run)
			for r in runs:
				if r.any(func(id): return has_exit.has(int(id))): continue
				var mid: int = r.size() / 2
				var order: Array = range(r.size())
				order.sort_custom(func(x, y): return absi(x - mid) < absi(y - mid) or (absi(x - mid) == absi(y - mid) and x < y))
				var done := false
				for k in order:
					var room: Dictionary = rooms[int(r[k])]
					if not palette.false_ceiling(room):
						if open_exit(job, room): done = true
					else:
						var tiles := exit_tiles(job, room)
						if not tiles.is_empty():
							ceiling_exit(job, room, tiles, rng)
							done = true
					if done:
						for id in r: has_exit[int(id)] = true
						break
				if done: continue
				var walls: Array = ["west", "east"] if line.axis == "v" else ["north", "south"]
				if not wall_exit(job, rooms[int(r[mid])], walls): return "duct_exit"
				for id in r: has_exit[int(id)] = true
	return ""

## Spec 2.5i step 8 for a planta: missing tiles, the kept rooms shedding more.
func duct_gaps(job: Dictionary, planta: int, cells: Array, rng: RandomNumberGenerator) -> String:
	var rooms: Array = job.f.rooms
	var pool: Array = []
	for id in cells:
		if palette.false_ceiling(rooms[id]): pool.append({"id": id, "weight": 1.0 + float(rooms[id].kept)})
	var count := roundi(float(palette.GAP_SHARE[planta]) * float(pool.size()))
	var made := 0
	while made < count:
		if pool.is_empty(): return "gaps"
		var pick := weighted(pool, rng)
		pool.erase(pick)
		var room: Dictionary = rooms[int(pick.id)]
		var height := float(room.py) + float(palette.height_of(room))
		var grille: Variant = job.grille.get(int(room.id))
		for tile in exit_tiles(job, room):
			if grille != null:
				if tile == grille: continue
				if palette.tile_centre(tile, 0.0).distance_to(palette.tile_centre(grille, 0.0)) < 1.2: continue
			job.ducts.exits.append({"node": -1, "room": int(room.id), "kind": "gap", "point": rounded(palette.tile_centre(tile, height)), "yaw": 0.0})
			made += 1
			break
	return ""

## Spec 2.5j, the crawlable main duct: the hatch, a node a main cell, the
## shaft, the crossing's edge, and where the remains lie.
func furnish_main(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var sp: Dictionary = f.specials[2]
	var rng := stream(int(job.seed), int(job.attempt), "air")
	var plenum: Dictionary = palette.PLENUM
	var air: Dictionary = job.out.air
	var main: Array = sp.main_cells
	var plant := int(main[0])
	var hp: Array = air.hatch.point
	var hatch := duct_node(job, Vector3(float(hp[0]), float(hp[1]), float(hp[2])), plant, "hatch")
	var nodes: Array = [hatch]
	var cross_node := -1
	for i in range(1, main.size()):
		var room: Dictionary = rooms[int(main[i])]
		var node := duct_node(job, Vector3(float(room.px), float(room.py) + float(plenum.duct_y), float(room.pz)), int(main[i]), "main")
		nodes.append(node)
		if int(main[i]) == int(job.cross.cell): cross_node = node
	var mp: Array = air.shaft.point
	var shaft := duct_node(job, Vector3(float(mp[0]), float(mp[1]), float(mp[2])), int(main[-1]), "shaft")
	nodes.append(shaft)
	var length := 0.0
	for i in range(1, nodes.size()):
		node_edge(job, int(nodes[i - 1]), int(nodes[i]), "main")
		length += float(job.ducts.edges[-1][2])
	job.ducts.edges.append([cross_node, int(job.cross.s_node), snappedf(float(plenum.main) / 2 + float(palette.STUB), 0.001), "cross"])
	job.ducts.exits.append({"node": hatch, "room": plant, "kind": "hatch", "point": air.hatch.point, "yaw": air.hatch.yaw})
	air.hatch["node"] = hatch
	air.shaft["node"] = shaft
	# The remains, along the duct's floor line.
	var share := rng.randf_range(float(palette.REMAINS.x), float(palette.REMAINS.y))
	var line: Array = nodes.map(func(node): return node_point(job, int(node)))
	var total := 0.0
	for i in range(1, line.size()): total += Vector2(line[i].x, line[i].z).distance_to(Vector2(line[i - 1].x, line[i - 1].z))
	var left := share * total
	var at := Vector2(line[-1].x, line[-1].z)
	for i in range(1, line.size()):
		var a := Vector2(line[i - 1].x, line[i - 1].z)
		var b := Vector2(line[i].x, line[i].z)
		var piece := a.distance_to(b)
		if left <= piece:
			at = a.lerp(b, left / piece) if piece > 0.0 else a
			break
		left -= piece
	air["remains"] = {"point": rounded(Vector3(at.x, float(air.shaft.floor_y), at.y)), "along": snappedf(share, 0.001)}
	air["main"] = {"nodes": nodes, "cells": main.duplicate(), "length": snappedf(length, 0.001), "bends": int(sp.main_bends), "cross": cross_node, "stub": job.cross.stub}
	return ""

## A point on a wall's inner face, world, at height y, inset into the room.
func wall_point(room: Dictionary, wall: String, along: float, y: float, inset := 0.0) -> Vector3:
	var n := LAYOUT.inward(wall)
	var point := Vector3(float(room.px), y, float(room.pz))
	if wall == "west" or wall == "east":
		point.x += LAYOUT.face(room, wall)
		point.z += along
	else:
		point.z += LAYOUT.face(room, wall)
		point.x += along
	point.x += n.x * inset
	point.z += n.y * inset
	return point

## A wall spot as the manifest keeps it: {wall, along, point, yaw}.
func wall_spot(room: Dictionary, wall: String, along: float, y: float, inset := 0.0) -> Dictionary:
	return {"wall": wall, "along": snappedf(along, 0.001), "point": rounded(wall_point(room, wall, along, y, inset)), "yaw": LAYOUT.wall_yaw(wall)}

## A point stored to the millimetre.
static func rounded(p: Vector3) -> Array:
	return [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]

## Whether a wall spot is free: on a closed wall, clear of its doorways as a
## locker is, inside the wall, and WALL_APART from every spot already there.
func spot_free(job: Dictionary, room: Dictionary, wall: String, along: float, half: float) -> bool:
	if room.get("open_sides", []).has(wall): return false
	for way in FLOOR.doorways(room):
		if String(way.wall) == wall and absf(along - float(way.along)) < HIDE_CLEAR: return false
	if absf(along) > LAYOUT.wall_length(room, wall) / 2 - 0.4 - half: return false
	for entry in job.taken.get(int(room.id), []):
		if String(entry.wall) == wall and absf(along - float(entry.along)) < float(palette.WALL_APART): return false
	return true

## Marks a stretch of wall as taken.
func register(job: Dictionary, room_id: int, wall: String, along: float, half: float) -> void:
	if not job.taken.has(room_id): job.taken[room_id] = []
	job.taken[room_id].append({"wall": wall, "along": along, "half": half})

## The walls with a doorway in them.
func doorway_walls(room: Dictionary) -> Array:
	var walls: Array = []
	for way in FLOOR.doorways(room):
		if not walls.has(String(way.wall)): walls.append(String(way.wall))
	return walls

## The closed walls with no doorway, the farthest from a doorway first; on
## the floor of last resort, where every wall can be a doorway, any closed one.
func far_walls(room: Dictionary) -> Array:
	var rooms: Array = job_rooms
	var doors := doorway_walls(room)
	var walls: Array = []
	for wall in ["west", "east", "north", "south"]:
		if not room.get("open_sides", []).has(wall) and not doors.has(wall): walls.append(wall)
	if walls.is_empty() and job_standby:
		for wall in ["west", "east", "north", "south"]:
			if not room.get("open_sides", []).has(wall): walls.append(wall)
	var points: Array = []
	for way in FLOOR.doorways(room):
		var p := FLOOR.portal_between(room, rooms[int(way.other)])
		points.append(Vector2(p.x, p.z))
	var far := func(wall: String) -> float:
		var mid := wall_point(room, wall, 0.0, 0.0)
		var least := INF
		for p in points: least = minf(least, Vector2(mid.x, mid.z).distance_to(p))
		return least
	var ranked: Array = []
	for i in walls.size(): ranked.append({"wall": walls[i], "far": float(far.call(walls[i])), "i": i})
	ranked.sort_custom(func(a, b): return float(a.far) > float(b.far) or (float(a.far) == float(b.far) and int(a.i) < int(b.i)))
	return ranked.map(func(entry): return String(entry.wall))

## The rooms of the floor being furnished and whether it is the floor of last
## resort (set by furnish()), for helpers that only get a room.
var job_rooms: Array = []
var job_standby := false

## A room's main door: the first neighbour that is a corridor, else the first
## (facing()'s choice); -1 with none.
func main_door(f: Dictionary, id: int) -> int:
	var doors: Array = f.adjacency[id].duplicate()
	doors.sort()
	if doors.is_empty(): return -1
	for d in doors:
		if bool(f.rooms[int(d)].corridor): return int(d)
	return int(doors[0])

## The manifest as it stands while furnishing, as LAYOUT reads one.
func working(job: Dictionary) -> Dictionary:
	var f: Dictionary = job.f
	var view := {"rooms": f.rooms, "adjacency": f.adjacency}
	for key in ["mail", "power", "air", "tubes", "ducts"]:
		if job.out.has(key): view[key] = job.out[key]
	return view

## Where the lift the floor is come down by stands in the reception: a closed
## wall with no doorway, the one opposite its main door first.
func furnish_lobby(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var start := -1
	for room in rooms:
		if int(room.type) == palette.RECEPTION: start = int(room.id)
	if start < 0: return ""
	var reception: Dictionary = rooms[start]
	var walls: Array = []
	var d := main_door(f, start)
	if d >= 0:
		var dw := LAYOUT.wall_of(Vector2i(int(rooms[d].x) - int(reception.x), int(rooms[d].z) - int(reception.z)))
		var opposite := LAYOUT.wall_of(-LAYOUT.way_of(dw))
		if opposite != "": walls.append(opposite)
	for wall in ["west", "east", "north", "south"]:
		if not walls.has(wall): walls.append(wall)
	var doors := doorway_walls(reception)
	for wall in walls:
		if reception.get("open_sides", []).has(wall) or doors.has(wall): continue
		var way := LAYOUT.way_of(wall)
		job.out["arrival_lift"] = [way.x, way.y]
		register(job, start, wall, 0.0, 1.5)
		break
	return ""

## The archives' shelving: rows across a spine through each unit, cross aisles
## to its doors, and in the mobile ones the rows packed with one gap a side.
func furnish_archives(job: Dictionary) -> String:
	var f: Dictionary = job.f
	var rooms: Array = f.rooms
	var rng := stream(int(job.seed), int(job.attempt), "archives")
	var a: Dictionary = palette.ARCHIVE_LAYOUT
	var units: Array = []
	var halls := {}
	for room in rooms:
		var t := int(room.type)
		if int(room.hall) >= 0:
			if t != palette.ARCHIVE: continue
			if not halls.has(int(room.hall)): halls[int(room.hall)] = []
			halls[int(room.hall)].append(int(room.id))
		elif t == palette.ARCHIVE or t == palette.MOBILE_ARCHIVE:
			units.append([int(room.id)])
	for hall in halls: units.append(halls[hall])
	units.sort_custom(func(x, y): return int(x.min()) < int(y.min()))
	var archives: Array = []
	for members in units:
		archives.append(lay_archive(f, members, a, rng))
	job.out["archives"] = archives
	return ""

## One archive unit's spine, rows and aisles (spec 2.5b).
func lay_archive(f: Dictionary, members: Array, a: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rooms: Array = f.rooms
	var first: Dictionary = rooms[int(members[0])]
	var mobile: bool = members.size() == 1 and int(first.type) == palette.MOBILE_ARCHIVE
	var axis := "x"
	if members.size() > 1:
		var zs := {}
		for id in members: zs[int(rooms[int(id)].z)] = true
		axis = "x" if zs.size() == 1 else "z"
	elif mobile:
		var walls := doorway_walls(first)
		axis = "z" if not walls.is_empty() and walls.all(func(w): return w == "north" or w == "south") else "x"
	else:
		axis = "x" if float(first.span_x) >= float(first.span_z) else "z"
	var inset := float(a.inset)
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	var centre := 0.0
	for id in members:
		var r: Dictionary = rooms[int(id)]
		x0 = minf(x0, float(r.px) - float(r.span_x) / 2)
		x1 = maxf(x1, float(r.px) + float(r.span_x) / 2)
		z0 = minf(z0, float(r.pz) - float(r.span_z) / 2)
		z1 = maxf(z1, float(r.pz) + float(r.span_z) / 2)
		centre += float(r.pz) if axis == "x" else float(r.px)
	centre /= float(members.size())
	x0 += inset
	x1 -= inset
	z0 += inset
	z1 -= inset
	var a0 := x0 if axis == "x" else z0
	var a1 := x1 if axis == "x" else z1
	var b0 := z0 if axis == "x" else x0
	var b1 := z1 if axis == "x" else x1
	var length := a1 - a0
	var gaps: Array = a.wall_gap
	var wall_gap := float(gaps[rng.randi_range(0, 1)])
	var row := float(a.row)
	var aisle := float(a.aisle)
	var spine := float(a.spine)
	var e0 := float(a.end_min)
	var e1 := float(a.end_min)
	# The short walls: west and east of the ends along x, north and south along z.
	var low_wall := "west" if axis == "x" else "north"
	var high_wall := "east" if axis == "x" else "south"
	var low_id := int(members[0])
	var high_id := int(members[0])
	for id in members:
		var key: float = float(rooms[int(id)].px) if axis == "x" else float(rooms[int(id)].pz)
		if key < (float(rooms[low_id].px) if axis == "x" else float(rooms[low_id].pz)): low_id = int(id)
		if key > (float(rooms[high_id].px) if axis == "x" else float(rooms[high_id].pz)): high_id = int(id)
	if doorway_walls(rooms[low_id]).has(low_wall): e0 = maxf(e0, float(a.door_depth))
	if doorway_walls(rooms[high_id]).has(high_wall): e1 = maxf(e1, float(a.door_depth))
	# The long walls' doorways, by side: north or west is the side of less.
	var minus_wall := "north" if axis == "x" else "west"
	var plus_wall := "south" if axis == "x" else "east"
	var minus_doors: Array = []
	var plus_doors: Array = []
	for id in members:
		var r: Dictionary = rooms[int(id)]
		for way in FLOOR.doorways(r):
			var at: float = (float(r.px) if axis == "x" else float(r.pz)) + float(way.along)
			if String(way.wall) == minus_wall: minus_doors.append(at)
			elif String(way.wall) == plus_wall: plus_doors.append(at)
	var sides := [[b0 + wall_gap, centre - spine / 2], [centre + spine / 2, b1 - wall_gap]]
	var rows: Array = []
	var aisles: Array = []
	var opened: Array = []
	if mobile:
		var nm := floori((length - e0 - e1 - aisle) / row)
		var rem := length - e0 - e1 - aisle - float(nm) * row
		var kl := rng.randi_range(0, nm)
		var kr := rng.randi_range(0, nm)
		opened = [kl, kr]
		for side in 2:
			var k: int = opened[side]
			var starts: Array = []
			for i in nm: starts.append(a0 + e0 + rem / 2 + float(i) * row + (aisle if i >= k else 0.0))
			for s in starts: rows.append(rect_of(axis, s, s + row, float(sides[side][0]), float(sides[side][1])))
			if k > 0 and k < nm:
				var gap_start: float = float(starts[k - 1]) + row
				aisles.append(rect_of(axis, gap_start, gap_start + aisle, float(sides[side][0]), float(sides[side][1])))
	else:
		var pitch := row + aisle
		var n := floori((length - e0 - e1 + aisle) / pitch)
		var rem := length - (float(n) * row + float(n - 1) * aisle) - e0 - e1
		for side in 2:
			var doors: Array = minus_doors if side == 0 else plus_doors
			var kept: Array = []
			for i in n:
				var s := a0 + e0 + rem / 2 + float(i) * pitch
				var cut := false
				for door in doors:
					if s < float(door) + float(a.door_band) and s + row > float(door) - float(a.door_band): cut = true
				if not cut: kept.append(s)
			for s in kept: rows.append(rect_of(axis, s, s + row, float(sides[side][0]), float(sides[side][1])))
			for i in range(1, kept.size()):
				var gap_start: float = float(kept[i - 1]) + row
				if absf(float(kept[i]) - gap_start - aisle) <= 0.001: aisles.append(rect_of(axis, gap_start, float(kept[i]), float(sides[side][0]), float(sides[side][1])))
	return {"rooms": members.duplicate(), "axis": axis, "mobile": mobile, "open": opened, "height": float(a.shelf), "wall_gap": wall_gap, "spine": rect_of(axis, a0, a1, centre - spine / 2, centre + spine / 2), "rows": rows, "aisles": aisles}

## [x0, z0, x1, z1] of a span along the axis and one across it, to the millimetre.
func rect_of(axis: String, along0: float, along1: float, across0: float, across1: float) -> Array:
	if axis == "x": return [snappedf(along0, 0.001), snappedf(across0, 0.001), snappedf(along1, 0.001), snappedf(across1, 0.001)]
	return [snappedf(across0, 0.001), snappedf(along0, 0.001), snappedf(across1, 0.001), snappedf(along1, 0.001)]
