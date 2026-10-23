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
		if members.any(func(r): return int(r.type) == palette.TOILETS): continue
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

## Spec 2.5c, the post and its tubes: written by step 1b's U7.
func furnish_mail(_job: Dictionary) -> String: return ""

## Spec 2.5d, the board, the zones and their timers: written by U8.
func furnish_power(_job: Dictionary) -> String: return ""

## Spec 2.5e, the air plant and its hatch: written by U8.
func furnish_air(_job: Dictionary) -> String: return ""

## Spec 2.5f, the corner sockets: written by U9.
func furnish_sockets(_job: Dictionary) -> String: return ""

## Spec 2.5g, the glazed walls: written by U9.
func furnish_glass(_job: Dictionary) -> String: return ""

## Spec 2.5h, the free-standing furniture: written by U9.
func furnish_furniture(_job: Dictionary) -> String: return ""

## Spec 2.5i, the duct network and its exits: written by U10.
func furnish_ducts(_job: Dictionary) -> String: return ""

## Spec 2.5j, the crawlable main duct: written by U10.
func furnish_main(_job: Dictionary) -> String: return ""

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

## The closed walls with no doorway, the farthest from a doorway first.
func far_walls(room: Dictionary) -> Array:
	var rooms: Array = job_rooms
	var doors := doorway_walls(room)
	var walls: Array = []
	for wall in ["west", "east", "north", "south"]:
		if not room.get("open_sides", []).has(wall) and not doors.has(wall): walls.append(wall)
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

## The rooms of the floor being furnished (set by furnish()), for helpers
## that only get a room.
var job_rooms: Array = []

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
