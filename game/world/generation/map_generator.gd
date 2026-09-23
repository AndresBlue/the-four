extends RefCounted
## A floor of The Locust: three plantas stacked, one per stage, joined by
## nothing but the lift, and each one a hotel of its own -- corridors laid out
## in a plan of their own and between 81 and 99 rooms (docs/DEVELOPMENT.md,
## "Generador de plantas").
##
## Each planta has its own grid: columns and rows of room modules, 12 to 16 m,
## with corridor lanes of 3 to 4 m in some of the gaps between them. What it
## makes of it is its own too: a shape cut out of it, which lanes are corridor
## (its plan: a spine, twin halls, a ring, a comb, blocks, arms, a warren, a
## rotten grid), how its rooms open on to the corridors and on to each other,
## and where its refuge is. The one thing a planta takes from the one above is
## where it is walked into: one of its columns and one of its rows are made the
## size of the lift lobby above and laid right under it, so the car goes
## straight down.
##
## Room ids run planta after planta: a planta's cells are its base plus row *
## columns + column (`cols` and `rows` in every room), so a cell's neighbours
## are one away along a row and `cols` away along a column. The cells a planta
## does not use are in the list too, as voids (FLOOR.VOID), so that a room's id
## is still its index.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")
## Plantas, one per stage (the name the rest of the game has always used).
const WINGS := FLOOR.PLANTAS
## Rooms with a television on the plantas of the second and third stages:
## their condition asks for as many sets as there are survivors, plus two.
const TV_ROOMS := 8
## Doors that carry no guest number: reception, circulation, service, the
## refuge and whatever is not there. In a hotel only the rooms let to
## somebody have a plaque.
const NO_NUMBER := [0, 7, 8, 9, 10, 11, 12, 15, 19, 20]
## What a room can be. Where the plan still reads like a hotel it is a guest
## room; where it has come apart it is whatever the place turned into.
const TIDY_ROOMS := [1, 1, 2, 2, 2, 3, 4, 16]
const UNRULY_ROOMS := [2, 3, 4, 5, 6, 13, 14, 16, 17, 18]
const SERVICE_ROOMS := [7, 8, 9, 15]
const HALL_ROOMS := [5, 6, 17, 18]
const RECEPTION := 0
const LANDING := 9
const LOBBY := 10
const CORRIDOR := 11
const GALLERY := 12
const TV_ROOM := 14
const REFUGE := 19
const VOID := FLOOR.VOID
## Rooms the three stages have to walk through at the very least: a floor that
## can be finished in fewer is drawn again.
const MIN_WALK := 30
## Rooms on a planta: more than 80 and fewer than 100. Each planta draws its
## own number in TARGET and is brought to it.
const ROOMS_LEAST := 81
const ROOMS_MOST := 99
const TARGET := Vector2i(84, 96)
## Module sizes (a room's side) and the width of a corridor lane, in metres.
const MODULE_SIZES := [12.0, 12.0, 13.0, 13.0, 14.0, 15.0, 16.0]
const LANE_WIDTHS := [3.0, 3.5, 3.5, 4.0]
## Longest a corridor or a salon runs straight and open. The creature sees
## seventy metres and runs faster than anybody: a long straight hall is a
## chase nobody wins. Longer, a fire door is put across it.
const OPEN_RUN := 45.0
## Tries at a floor, and at each planta within it, before the standby floor,
## which only promises it can be walked.
const ATTEMPTS := 8
const TRIES := 6
## Plans for a planta's corridors. Each floor deals one per planta, never the
## same twice; the first planta from the tidier plans, the last from the ones
## that have come apart.
const DECKS := [["spine", "twin", "ring", "comb", "arms"], ["spine", "twin", "blocks", "arms", "rot", "warren"], ["blocks", "warren", "rot", "comb", "ring"]]
## Share of a planta's rooms its corridors grow to serve, by plan: a warren is
## rooms giving on to rooms, blocks are a hotel with a corridor at most doors.
const SERVED := {"spine": 0.4, "twin": 0.45, "ring": 0.45, "comb": 0.55, "blocks": 0.6, "arms": 0.4, "warren": 0.0, "rot": 0.35}
## Plans too alike to share a floor: both are most of the lanes.
const APART := {"blocks": "rot", "rot": "blocks"}
## The most a planta's corridors may be like those of a planta above it (the
## share of corridor floor both have, as tools/dev/map_metrics.gd measures
## it); more, and it is drawn again. And the size of the square of cells that
## is measured on: a cell about as wide as a corridor.
const ALIKE := 0.3
const LIKENESS_CELLS := 48
## Shapes cut out of the grid, so a planta is not always a rectangle.
const SHAPES := ["rect", "notch", "ell", "you", "court", "aitch"]
## How much of a hotel each planta still is, before its own drift: it comes
## apart as one goes down, but never in the same direction twice.
const ORDER_BASE := [0.8, 0.6, 0.42]
## How far in the refuge is, as a share of the way to the farthest room of
## its planta, walking: never the deepest room, never near the door.
const DEPTH := Vector2(0.55, 0.9)
## The share of rooms farthest from the way in, in a straight line, that a
## refuge keeps out of where it can; and how much longer than a straight line
## the walk to it should be.
const FAR_SIDE := 0.3
const WINDING := 1.5
## Salons on a planta: two or three rooms thrown into one.
const HALLS := Vector2i(2, 6)
## Rings to walk round on a planta, at the least: a plan that is a tree has
## one way to everywhere, and the creature on it. It is asked for with room to
## spare before the refuge is placed, which takes a few away.
const CYCLES := 6
const LOOPS := CYCLES + 4
## How much more often rooms open on to each other, by plan: a warren is
## rooms giving on to rooms.
const ROOM_DOORS := {"warren": 1.8, "rot": 1.25}
const WAYS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Where a door can stand in the wall of a room, in metres from the middle of
## the wall, either way. A door off the middle leaves that wall its furniture
## on the far side only. Rooms with the domestic alcoves (2.8 m out from the
## middle: hotel_geometry.build_room()) keep it nearer, beside them.
const DOOR_PLACES := [0.0, 0.0, 1.5, -1.5, 2.0, -2.0]
const DOOR_PLACES_DOMESTIC := [0.0, 1.5, -1.5]
const DOMESTIC := [1, 2, 3, 4, 7, 15, 16]
## A fire door across a corridor hangs from the jamb next to one of its side
## walls, this far from it, so that open it lies flat against that wall: in
## the middle, its leaf stood across half the corridor with a pocket behind it.
const FIRE_JAMB := 0.2
## A wall shorter than this is the end of a corridor lane, not a room's side.
const LANE_WALL := 6.0
## Found open: a door between rooms, more often the less kept the rooms
## either side are (from the first to the second, by the tidier of the two);
## a fire door, mostly shut.
const OPEN_DOORS := Vector2(0.8, 0.5)
const FIRE_OPEN := 0.3
## Wardrobe spots along a wall, from its middle, and how far one keeps from
## the middle of a doorway in the same wall: the doorway, what the leaf sweeps
## and the wardrobe's own half width (hiding_place.gd).
const HIDE_SPOTS := [-1.8, 0.0, 1.8]
const HIDE_CLEAR := 1.75
## Two wardrobes on the same wall stand this far apart at the least, so both
## pairs of doors can open.
const HIDE_APART := 3.0
## The dark rooms. Each room that can be dark (FLOOR.may_be_dark()) is on its
## own with DARK_OWN, more the lower the planta; each one that is puts out the
## rooms it opens on to with DARK_SPREAD, so they come in stretches. A
## corridor is the last thing a hotel stops lighting and what makes a planta
## legible, so one goes dark rarely: on its own or beside a dark room.
const DARK_OWN := [0.23, 0.29, 0.36]
const DARK_SPREAD := 0.45
const DARK_CORRIDOR := Vector2(0.03, 0.05)
## How kept a room is (0 kept, 1 neglected, 2 abandoned) goes with its order,
## give or take WEAR: kept over the second number, abandoned under the first.
const WEAR := 0.25
const KEPT := Vector2(0.25, 0.55)
const EMPTY_SALON := 18

## Why tries came out empty, by reason, for the tools that measure the
## generator (tools/dev/map_metrics.gd).
var stats := {}

func generate(run_seed: int) -> Dictionary:
	for attempt in ATTEMPTS:
		var result := candidate(run_seed, attempt)
		if result.is_empty(): continue
		if int(result.walk) < MIN_WALK:
			fail("walk")
			continue
		var errors := VALIDATOR.new().validate(result)
		if errors.is_empty():
			result["fallback"] = false
			return result
		for error in errors: fail("invalid_" + String(error).rstrip("0123456789_"))
	var fallback := candidate(404, 0, true)
	fallback["requested_seed"] = run_seed
	fallback["fallback"] = true
	return fallback

func fail(reason: String) -> Dictionary:
	stats[reason] = int(stats.get(reason, 0)) + 1
	return {}

## One try at a floor, or {} when it did not come out. `standby`: the floor of
## last resort, every wall that can be a doorway is one.
func candidate(run_seed: int, attempt: int, standby := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "floor", attempt])
	var f := {"rooms": [], "adjacency": [], "edges": [], "merged": {}, "plantas": [], "base": 0, "width": 0, "height": 0, "grid": {}, "lines": [], "edge_base": 0}
	var deck := deal(rng, standby)
	var gates: Array = []
	var refuges: Array = []
	var entries: Array = []
	var hits: Array = []
	var plans: Array = []
	var bearings: Array = []
	var anchor := {}
	var back := Vector2i.ZERO
	var walk := 0
	for planta in WINGS:
		var made := {}
		# A planta that does not come out is drawn again on its own, its grid
		# too: the ones above it stay as they are.
		for tried in TRIES:
			var planta_rng := RandomNumberGenerator.new()
			planta_rng.seed = hash([run_seed, "planta", planta, attempt, tried])
			open_planta(f, planta, lay_grid(planta_rng, standby, anchor))
			made = lay_planta(f, planta, int(f.grid.anchor), back, deck[planta], planta_rng, standby, bearings)
			if not made.is_empty(): break
			drop_planta(f, planta)
		if made.is_empty(): return fail("planta")
		var base: int = f.base
		refuges.append(base + int(made.refuge))
		entries.append(base + int(made.arrival))
		hits.append(int(made.hits))
		walk += int(made.walk)
		bearings.append(int(made.bearing))
		plans.append({"plan": deck[planta], "shape": made.shape, "rooms": int(made.count)})
		var out: Vector2i = made.out
		gates.append({"stage": planta + 1, "room": base + int(made.refuge), "beyond": base + int(made.landing), "out": [out.x, out.y], "arrive": -1})
		# The next planta is laid round the lobby under this one's lift.
		var lobby: Dictionary = at(f, int(made.landing))
		anchor = {"x": Vector2(float(lobby.px) - float(lobby.span_x) * 0.5, float(lobby.px) + float(lobby.span_x) * 0.5), "z": Vector2(float(lobby.pz) - float(lobby.span_z) * 0.5, float(lobby.pz) + float(lobby.span_z) * 0.5)}
		back = out
	for planta in range(WINGS - 1): gates[planta].arrive = entries[planta + 1]
	var start: int = entries[0]
	# The floor is centred on the reception: that is where the night comes in,
	# and where a body is put down when a floor starts.
	var origin := Vector2(float(f.rooms[start].px), float(f.rooms[start].pz))
	for room in f.rooms:
		room.px = float(room.px) - origin.x
		room.pz = float(room.pz) - origin.y
	var decoration := RandomNumberGenerator.new()
	decoration.seed = hash([run_seed, "rooms", attempt])
	finish(f, start, refuges, entries, decoration)
	# Its own draw, so a change in the numbering never moves the furniture.
	var plaques := RandomNumberGenerator.new()
	plaques.seed = hash([run_seed, "plaques", attempt])
	number_rooms(f, plaques)
	# Doors and wardrobes, then lamps and wear, each on a draw of its own.
	var fittings := RandomNumberGenerator.new()
	fittings.seed = hash([run_seed, "fittings", attempt])
	var doors := hang_doors(f, gates, fittings)
	place_hides(f, fittings)
	var wear := RandomNumberGenerator.new()
	wear.seed = hash([run_seed, "wear", attempt])
	light_rooms(f, wear)
	var merged: Array = f.merged.values()
	merged.sort_custom(func(a, b): return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var grids: Array = f.plantas.map(func(dims): return {"base": dims.base, "width": dims.width, "height": dims.height})
	return {"version": FLOOR.VERSION, "seed": run_seed, "walk": walk, "attempt": attempt, "plantas": grids, "start": start, "exit": refuges[0], "refuges": refuges, "gates": gates, "wings": WINGS, "rooms": f.rooms, "edges": f.edges, "adjacency": f.adjacency, "ambient_seed": run_seed + 4000037, "merged": merged, "doors": doors, "wall_hits": hits, "entries": entries, "plans": plans, "start_facing": facing(f, start)}

# --- The grid --------------------------------------------------------------------------

## A planta's grid: room modules in columns and rows, and corridor lanes in
## some of the gaps between them, in proportions of its own, from eight by
## thirteen to thirteen by eight. Under a lift (`anchor`: the lobby's span
## across and down) one column and one row are made that lobby's size and laid
## under it, and `anchor` in the grid is that cell.
func lay_grid(rng: RandomNumberGenerator, standby: bool, anchor: Dictionary) -> Dictionary:
	var columns := 10 if standby else rng.randi_range(8, 13)
	var rows := 10 if standby else clampi(ceili(rng.randf_range(100.0, 118.0) / float(columns)), 8, 13)
	while columns * rows < 100: rows += 1
	var lanes_across := 3 if standby else rng.randi_range(2, mini(4, columns / 3 + 1))
	var lanes_down := 3 if standby else rng.randi_range(2, mini(4, rows / 3 + 1))
	var across := axis(rng, columns, gaps(rng, columns, lanes_across, standby))
	var down := axis(rng, rows, gaps(rng, rows, lanes_down, standby))
	var grid := {"columns": across, "rows": down, "anchor": -1}
	if not anchor.is_empty(): grid.anchor = pin(rng, down, anchor.z) * across.size() + pin(rng, across, anchor.x)
	return grid

## One module of an axis made exactly the span given and the whole axis moved
## so that module stands on it. Which module of the axis that is, is drawn:
## the lobby can be anywhere on the planta. Returns its index on the axis.
func pin(rng: RandomNumberGenerator, line: Array, span: Vector2) -> int:
	var modules := module_indices(line)
	var chosen: int = modules[rng.randi_range(0, modules.size() - 1)]
	line[chosen].size = span.y - span.x
	var along := 0.0
	for entry in line:
		entry.centre = along + float(entry.size) * 0.5
		along += float(entry.size)
	var shift: float = (span.x + span.y) * 0.5 - float(line[chosen].centre)
	for entry in line: entry.centre = float(entry.centre) + shift
	return chosen

## Where the lanes go: gap i is the one before module i (0 the outside edge,
## `modules` the far one). Never side by side, so every block between them is
## at least two rooms deep -- rooms back to back, each with a corridor at its
## door -- and along an outside edge only now and then.
func gaps(rng: RandomNumberGenerator, modules: int, count: int, standby: bool) -> Array:
	var candidates: Array = []
	for gap in range(1, modules): candidates.append(gap)
	if standby: candidates = [3, 6, modules - 3, 1, modules - 1]
	else: shuffle(candidates, rng)
	var chosen: Array = []
	for gap in candidates:
		if chosen.size() >= count: break
		if chosen.any(func(other): return absi(int(other) - int(gap)) < 2): continue
		chosen.append(gap)
	if not standby and rng.randf() < 0.12:
		var edge := 0 if rng.randf() < 0.5 else modules
		if not chosen.any(func(other): return absi(int(other) - edge) < 2): chosen.append(edge)
	chosen.sort()
	return chosen

## One axis of a grid: its cells in order, {lane, size, centre}.
func axis(rng: RandomNumberGenerator, modules: int, lanes: Array) -> Array:
	var out: Array = []
	for index in modules + 1:
		if lanes.has(index): out.append({"lane": true, "size": LANE_WIDTHS[rng.randi_range(0, LANE_WIDTHS.size() - 1)]})
		if index < modules: out.append({"lane": false, "size": MODULE_SIZES[rng.randi_range(0, MODULE_SIZES.size() - 1)]})
	var along := 0.0
	for entry in out:
		entry["centre"] = along + float(entry.size) * 0.5
		along += float(entry.size)
	return out

## A cell of a planta, before the planta decides what it is.
func cell(grid: Dictionary, planta: int, base: int, local: int) -> Dictionary:
	var width: int = grid.columns.size()
	var column: Dictionary = grid.columns[local % width]
	var row: Dictionary = grid.rows[local / width]
	var kind := "cross" if column.lane and row.lane else "lane" if column.lane or row.lane else "module"
	return {"id": base + local, "x": local % width, "z": local / width, "cols": width, "rows": grid.rows.size(), "wing": planta, "kind": kind, "type": VOID, "sector": 0, "props": [], "px": column.centre, "py": FLOOR.planta_y(planta), "pz": row.centre, "span_x": column.size, "span_z": row.size, "hall": -1, "corridor": false, "service": false, "order": 0.5}

## A planta's cells, on its own grid, after the plantas above it; it is the
## planta laid from here on (use()).
func open_planta(f: Dictionary, planta: int, grid: Dictionary) -> void:
	var base: int = f.rooms.size()
	var width: int = grid.columns.size()
	var height: int = grid.rows.size()
	for local in width * height:
		f.rooms.append(cell(grid, planta, base, local))
		f.adjacency.append([])
	f.plantas.append({"base": base, "width": width, "height": height, "grid": grid, "lines": [], "edges": f.edges.size()})
	use(f, planta)
	f.plantas[planta].lines = lane_lines(f)
	f.lines = f.plantas[planta].lines

## A try at a planta undone: its cells, their doors and open walls go.
func drop_planta(f: Dictionary, planta: int) -> void:
	var base: int = f.plantas[planta].base
	f.rooms.resize(base)
	f.adjacency.resize(base)
	f.edges.resize(int(f.plantas[planta].edges))
	for pair in f.merged.keys():
		if int(f.merged[pair][0]) >= base: f.merged.erase(pair)
	f.plantas.resize(planta)

## The planta everything below works on: its base, grid and lanes.
func use(f: Dictionary, planta: int) -> void:
	var dims: Dictionary = f.plantas[planta]
	f.base = dims.base
	f.width = dims.width
	f.height = dims.height
	f.grid = dims.grid
	f.lines = dims.lines
	f.edge_base = dims.edges

## A cell of the planta in use, by its place on the grid.
func at(f: Dictionary, local: int) -> Dictionary:
	return f.rooms[int(f.base) + local]

## A plan for each planta, from its deck, never the same twice on one floor.
func deal(rng: RandomNumberGenerator, standby: bool) -> Array:
	if standby: return ["blocks", "blocks", "blocks"]
	var dealt: Array = []
	for planta in WINGS:
		var deck: Array = DECKS[planta].filter(func(plan): return not dealt.has(plan) and not dealt.has(APART.get(plan, "")))
		dealt.append(deck[rng.randi_range(0, deck.size() - 1)])
	return dealt

# --- One planta ------------------------------------------------------------------------

## One planta, on the grid in use. `arrival` is the cell it is walked into
## from (-1 on the first: it picks its reception), `back` the side of that
## cell the lift's car stands against, where no door may go. Cells are local
## indices (row * columns + column); returns {arrival, refuge, landing, out,
## hits, walk, shape, count, bearing}, or {} when this try could not make one.
func lay_planta(f: Dictionary, planta: int, arrival: int, back: Vector2i, plan: String, rng: RandomNumberGenerator, standby: bool, bearings: Array) -> Dictionary:
	var per: int = f.width * f.height
	var base: int = f.base
	var rooms: Array = f.rooms
	order_field(f, planta, rng)
	var target: int = TARGET.y if standby else rng.randi_range(TARGET.x, TARGET.y)
	var alive := {}
	for local in per:
		if at(f, local).kind == "module": alive[local] = true
	# The lift's lobby is not a room, and on the plantas below neither is the
	# lobby one arrives at.
	var reserved := 1 if planta == 0 else 2
	var shape := "rect"
	if not standby:
		var cut := pick_shape(f, rng, arrival, alive.size() - reserved - target)
		shape = cut.shape
		for local in cut.cells: alive.erase(local)
	var corridor := corridors(f, plan, rng, alive, arrival, standby)
	for local in corridor: alive[local] = true
	if arrival < 0: arrival = pick_start(f, alive, corridor, rng)
	if arrival < 0 or not alive.has(arrival): return fail("start")
	plant_service(f, planta, alive, arrival, rng, standby)
	open_doors(f, alive, corridor, arrival, back, rng, standby, ROOM_DOORS.get(plan, 1.0))
	join(f, alive, arrival, back, rng)
	if not standby: make_halls(f, alive, arrival, rng, count_rooms(f, planta, alive, arrival, -1) - 1 - target)
	trim(f, planta, alive, arrival, {}, target + 1, rng)
	loops(f, alive, arrival, back, rng)
	var refuge := place_refuge(f, alive, arrival, back, rng, standby, bearings)
	if refuge.is_empty(): return fail("refuge_%s" % plan)
	trim(f, planta, alive, arrival, refuge, target, rng)
	tidy(f, alive)
	var landing: int = refuge.landing
	var count := count_rooms(f, planta, alive, arrival, landing)
	if count < ROOMS_LEAST: return fail("few_%s" % plan)
	if count > ROOMS_MOST: return fail("many_%s" % plan)
	if cycles(f, alive) < CYCLES: return fail("cycles_%s" % plan)
	if not standby and alike(f, planta, alive) > ALIKE: return fail("alike_%s" % plan)
	var rooms_only := alive.duplicate()
	rooms_only.erase(landing)
	if not standby and not in_depth(f, rooms_only, arrival, int(refuge.room)): return fail("depth_%s" % plan)
	for local in per:
		var room: Dictionary = rooms[base + local]
		if alive.has(local):
			room.type = -1
			room.corridor = room.kind != "module"
			continue
		room.type = VOID
		room.corridor = false
		room.service = false
		room.hall = -1
	rooms[base + landing]["landing"] = true
	rooms[base + landing].service = false
	var hops := distances(f.adjacency, base + arrival)
	return {"arrival": arrival, "refuge": refuge.room, "landing": landing, "out": refuge.out, "hits": refuge.hits, "walk": maxi(0, hops[base + int(refuge.room)]), "shape": shape, "count": count, "bearing": refuge.bearing}

## How much of a hotel each cell still is: 1 is a plan somebody drew, 0 what
## the place turned into. A base per planta, falling as one goes down, a
## gradient across the planta in a direction of its own, and the drift of
## patches three or four rooms wide on top.
func order_field(f: Dictionary, planta: int, rng: RandomNumberGenerator) -> void:
	var per: int = f.width * f.height
	var angle := rng.randf() * TAU
	var slope := rng.randf_range(0.2, 0.6)
	var way := Vector2(cos(angle), sin(angle))
	var salt := rng.randi()
	for local in per:
		var room: Dictionary = at(f, local)
		var across := Vector2(float(room.x) / maxf(1.0, float(f.width - 1)), float(room.z) / maxf(1.0, float(f.height - 1))) - Vector2(0.5, 0.5)
		room.order = clampf(ORDER_BASE[planta] - slope * across.dot(way) + 0.3 * drift(float(room.x) / 4.0, float(room.z) / 4.0, salt), 0.0, 1.0)

## Value noise over a coarse grid: patches that drift the same way, with soft
## edges between them. Hand-rolled from `hash` on purpose -- every machine has
## to generate the same floor from the same seed, so it cannot lean on the
## engine's own noise.
static func drift(x: float, z: float, run_seed: int) -> float:
	var gx := floori(x)
	var gz := floori(z)
	var fx := smoothstep(0.0, 1.0, x - float(gx))
	var fz := smoothstep(0.0, 1.0, z - float(gz))
	var near := lerpf(patch(gx, gz, run_seed), patch(gx + 1, gz, run_seed), fx)
	var far := lerpf(patch(gx, gz + 1, run_seed), patch(gx + 1, gz + 1, run_seed), fx)
	return lerpf(near, far, fz)

static func patch(x: int, z: int, run_seed: int) -> float:
	return float(absi(hash([run_seed, "order", x, z])) % 1000) / 499.5 - 1.0

# --- The shape -------------------------------------------------------------------------

## A shape for the planta that leaves it about the rooms it wants. `spare` is
## how many rooms the whole rectangle has over its number: each shape is drawn
## a few times, in an order of its own, and the first cut that leaves between
## 2 and 16 to spare is taken (the salons and the trimming take the rest), or
## the nearest miss.
func pick_shape(f: Dictionary, rng: RandomNumberGenerator, keep: int, spare: int) -> Dictionary:
	var order := SHAPES.duplicate()
	shuffle(order, rng)
	var best := {"shape": "rect", "cells": []}
	var best_miss := INF
	for shape in order:
		for draw in (1 if shape == "rect" else 3):
			var cells := cut_shape(f, shape, rng, keep)
			var left: int = spare - cells.size()
			if left >= 2 and left <= 16: return {"shape": shape, "cells": cells}
			var miss := float(2 - left) * 3.0 if left < 2 else float(left - 16)
			if miss < best_miss:
				best_miss = miss
				best = {"shape": shape, "cells": cells}
	return best

## The modules a shape takes out of the grid: a corner, a quarter, a bite out
## of one side, a courtyard, two bites. Never the cell the planta is walked
## into from.
func cut_shape(f: Dictionary, shape: String, rng: RandomNumberGenerator, keep: int) -> Array:
	var columns: Array = module_indices(f.grid.columns)
	var rows: Array = module_indices(f.grid.rows)
	var mc := columns.size()
	var mr := rows.size()
	var blocks: Array = []
	match shape:
		"notch":
			blocks.append(corner_block(rng, mc, mr, rng.randi_range(2, 3), rng.randi_range(2, 3)))
			if rng.randf() < 0.4: blocks.append(corner_block(rng, mc, mr, rng.randi_range(1, 2), rng.randi_range(2, 3)))
		"ell":
			blocks.append(corner_block(rng, mc, mr, int(round(mc * rng.randf_range(0.3, 0.45))), int(round(mr * rng.randf_range(0.3, 0.45)))))
		"you":
			blocks.append(edge_block(rng, mc, mr, rng.randi_range(0, 3)))
		"court":
			var w := rng.randi_range(2, 3)
			var h := rng.randi_range(2, 3)
			blocks.append(Rect2i(rng.randi_range(2, maxi(2, mc - w - 2)), rng.randi_range(2, maxi(2, mr - h - 2)), w, h))
		"aitch":
			var side := rng.randi_range(0, 1)
			blocks.append(edge_block(rng, mc, mr, side))
			blocks.append(edge_block(rng, mc, mr, side + 2))
	var cut: Array = []
	for block: Rect2i in blocks:
		for mx in range(block.position.x, block.end.x):
			for mz in range(block.position.y, block.end.y):
				if mx < 0 or mz < 0 or mx >= mc or mz >= mr: continue
				var local: int = int(rows[mz]) * int(f.width) + int(columns[mx])
				if local != keep and not cut.has(local): cut.append(local)
	return cut

static func module_indices(line: Array) -> Array:
	var out: Array = []
	for index in line.size():
		if not line[index].lane: out.append(index)
	return out

static func corner_block(rng: RandomNumberGenerator, mc: int, mr: int, w: int, h: int) -> Rect2i:
	return Rect2i(0 if rng.randf() < 0.5 else mc - w, 0 if rng.randf() < 0.5 else mr - h, w, h)

## A bite out of the middle of one side: 0 north, 1 west, 2 south, 3 east.
static func edge_block(rng: RandomNumberGenerator, mc: int, mr: int, side: int) -> Rect2i:
	var along := mc if side % 2 == 0 else mr
	var span := maxi(2, int(round(along * rng.randf_range(0.25, 0.4))))
	var depth := rng.randi_range(2, 3)
	var from := clampi((along - span) / 2 + rng.randi_range(-1, 1), 1, maxi(1, along - span - 1))
	match side % 4:
		0: return Rect2i(from, 0, span, depth)
		1: return Rect2i(0, from, depth, span)
		2: return Rect2i(from, mr - depth, span, depth)
	return Rect2i(mc - depth, from, depth, span)

# --- Corridors -------------------------------------------------------------------------

## The lanes of the grid in use as lines: each lane column or row, and the
## stretches of it between two crossings. [{axis, index, cells, segments}].
func lane_lines(f: Dictionary) -> Array:
	var lines: Array = []
	for c in f.grid.columns.size():
		if not f.grid.columns[c].lane: continue
		var cells: Array = []
		for r in f.grid.rows.size(): cells.append(r * int(f.width) + c)
		lines.append({"axis": "v", "index": c, "cells": cells, "segments": segments(f, cells)})
	for r in f.grid.rows.size():
		if not f.grid.rows[r].lane: continue
		var cells: Array = []
		for c in f.grid.columns.size(): cells.append(r * int(f.width) + c)
		lines.append({"axis": "h", "index": r, "cells": cells, "segments": segments(f, cells)})
	return lines

## A line cut at its crossings: each stretch keeps the crossings at its ends.
func segments(f: Dictionary, cells: Array) -> Array:
	var out: Array = []
	var current: Array = []
	for local in cells:
		current.append(local)
		if at(f, local).kind == "cross" and current.size() > 1:
			out.append(current)
			current = [local]
	if current.size() > 1 or out.is_empty(): out.append(current)
	return out

## Which lane cells are corridor. The plan lays its skeleton; then the
## corridors grow, a stretch at a time and only out of corridor already laid,
## towards the rooms nobody serves, until the plan's share has one at its door;
## and whatever serves no room and carries on nowhere goes.
func corridors(f: Dictionary, plan: String, rng: RandomNumberGenerator, alive: Dictionary, arrival: int, standby: bool) -> Dictionary:
	var lines: Array = f.lines
	var on := {}
	if lines.is_empty(): return on
	var vertical: Array = lines.filter(func(line): return line.axis == "v")
	var horizontal: Array = lines.filter(func(line): return line.axis == "h")
	var blocked := {}
	match plan:
		"spine", "comb":
			var upright := horizontal.is_empty() or (not vertical.is_empty() and rng.randf() < 0.5)
			var mains: Array = vertical if upright else horizontal
			var crosses: Array = horizontal if upright else vertical
			var spine: Dictionary = mains[rng.randi_range(0, mains.size() - 1)]
			take(on, spine.cells)
			var along: int = spine.index
			var limit: int = (int(f.width) if upright else int(f.height)) - 1
			var teeth: Array = crosses.duplicate()
			shuffle(teeth, rng)
			if plan == "spine":
				for tooth in teeth.slice(0, rng.randi_range(1, 3)):
					var arm := rng.randi_range(3, 8)
					var both := rng.randf() < 0.6
					var forward := rng.randf() < 0.5
					take_between(f, on, tooth, along - arm if both or not forward else along, along + arm if both or forward else along)
			else:
				# The teeth all go one way, to the edge: towards the bigger half,
				# mostly.
				var side := 1 if along < limit / 2 else -1
				if rng.randf() < 0.2: side = -side
				for tooth in teeth: take_between(f, on, tooth, along if side > 0 else 0, limit if side > 0 else along)
				# Sometimes a back corridor joins their ends.
				var far: Array = mains.filter(func(line): return (int(line.index) - along) * side >= 4)
				if not far.is_empty() and rng.randf() < 0.5: take(on, far[far.size() - 1 if side > 0 else 0].cells)
		"arms":
			if vertical.is_empty() or horizontal.is_empty():
				for line in lines: take(on, line.cells)
			else:
				# A hub where two lanes cross, and an arm from it to the edge
				# in two, three or four of the four directions.
				var down: Dictionary = vertical[rng.randi_range(0, vertical.size() - 1)]
				var across: Dictionary = horizontal[rng.randi_range(0, horizontal.size() - 1)]
				var directions := [0, 1, 2, 3]
				shuffle(directions, rng)
				for direction in directions.slice(0, rng.randi_range(2, 4)):
					match direction:
						0: take_between(f, on, down, 0, int(across.index))
						1: take_between(f, on, down, int(across.index), int(f.height) - 1)
						2: take_between(f, on, across, 0, int(down.index))
						3: take_between(f, on, across, int(down.index), int(f.width) - 1)
		"twin":
			var upright := horizontal.size() < 2 or (vertical.size() >= 2 and rng.randf() < 0.5)
			var pair: Array = vertical if upright else horizontal
			var bridges: Array = (horizontal if upright else vertical).duplicate()
			if pair.size() < 2:
				for line in lines: take(on, line.cells)
			else:
				# Two parallel corridors, as far apart as the grid has them or
				# one block in, joined by one or two across.
				var first: int = 0 if pair.size() < 4 or rng.randf() < 0.6 else 1
				var last: int = pair.size() - 1 if pair.size() < 4 or rng.randf() < 0.6 else pair.size() - 2
				var one: Dictionary = pair[first]
				var two: Dictionary = pair[last]
				take(on, one.cells)
				take(on, two.cells)
				shuffle(bridges, rng)
				for bridge in bridges.slice(0, rng.randi_range(1, 2)): take_between(f, on, bridge, int(one.index), int(two.index))
		"ring":
			if vertical.size() < 2 or horizontal.size() < 2:
				for line in lines: take(on, line.cells)
			else:
				# A loop round the middle of the planta: the outermost lanes, or
				# one in where there are more.
				var inner := vertical.size() > 3 and horizontal.size() > 3 and rng.randf() < 0.35
				var left: Dictionary = vertical[1 if inner else 0]
				var right: Dictionary = vertical[vertical.size() - 1]
				var top: Dictionary = horizontal[1 if inner else 0]
				var bottom: Dictionary = horizontal[horizontal.size() - 1]
				take_between(f, on, left, int(top.index), int(bottom.index))
				take_between(f, on, right, int(top.index), int(bottom.index))
				take_between(f, on, top, int(left.index), int(right.index))
				take_between(f, on, bottom, int(left.index), int(right.index))
				var spokes: Array = vertical.filter(func(line): return int(line.index) > int(left.index) and int(line.index) < int(right.index))
				if not spokes.is_empty() and rng.randf() < 0.4: take_between(f, on, spokes[rng.randi_range(0, spokes.size() - 1)], int(top.index), int(bottom.index))
		"blocks", "rot":
			for line in lines: take(on, line.cells)
			if not standby:
				# Some stretches taken out, as long as the corridors stay one piece.
				var stretches := all_stretches(f)
				shuffle(stretches, rng)
				var drop := int(round(stretches.size() * rng.randf_range(0.3, 0.45)))
				for stretch in stretches:
					if drop <= 0: break
					var trial := on.duplicate()
					for local in stretch:
						if at(f, local).kind != "cross": trial.erase(local)
					if pieces(f, trial) == 1:
						on = trial
						drop -= 1
			if plan == "rot":
				# A patch where the corridors have given way to rooms and rubble.
				var middle := Vector2(float(f.grid.columns[rng.randi_range(0, f.grid.columns.size() - 1)].centre), float(f.grid.rows[rng.randi_range(0, f.grid.rows.size() - 1)].centre))
				var radius := rng.randf_range(25.0, 45.0)
				for local in on.keys():
					if Vector2(float(at(f, local).px), float(at(f, local).pz)).distance_to(middle) < radius:
						on.erase(local)
						blocked[local] = true
		"warren":
			# Hardly any corridor: a stretch or two by the way in, and rooms
			# giving on to rooms from there.
			var stretches := all_stretches(f)
			shuffle(stretches, rng)
			if arrival >= 0:
				var from := Vector2(float(at(f, arrival).px), float(at(f, arrival).pz))
				stretches.sort_custom(func(a, b): return middle_of(f, a).distance_to(from) < middle_of(f, b).distance_to(from))
			for stretch in stretches.slice(0, rng.randi_range(1, 2)): take(on, stretch)
	if not standby: grow(f, on, alive, SERVED.get(plan, 0.5), rng, blocked)
	prune(f, on, alive)
	return on

static func take(on: Dictionary, cells: Array) -> void:
	for local in cells: on[local] = true

## The part of a lane line between two positions along it (inclusive): rows
## for a line that runs down the grid, columns for one that runs across.
func take_between(f: Dictionary, on: Dictionary, line: Dictionary, low: int, high: int) -> void:
	for local in line.cells:
		var along: int = int(at(f, local).z) if line.axis == "v" else int(at(f, local).x)
		if along >= mini(low, high) and along <= maxi(low, high): on[local] = true

func all_stretches(f: Dictionary) -> Array:
	var out: Array = []
	for line in f.lines:
		for stretch in line.segments: out.append(stretch)
	return out

## The middle of a stretch, in plan.
func middle_of(f: Dictionary, stretch: Array) -> Vector2:
	var sum := Vector2.ZERO
	for local in stretch: sum += Vector2(float(at(f, local).px), float(at(f, local).pz))
	return sum / maxf(1.0, float(stretch.size()))

## Corridor reaching out to the rooms it does not serve yet, a stretch at a
## time, each one joined to what is laid, the tidier rooms counting for more;
## until `goal` of the rooms have one at their door. `blocked` cells never
## become corridor.
func grow(f: Dictionary, on: Dictionary, alive: Dictionary, goal: float, rng: RandomNumberGenerator, blocked: Dictionary) -> void:
	if goal <= 0.0 or on.is_empty(): return
	var stretches: Array = all_stretches(f).filter(func(stretch): return not stretch.any(func(local): return blocked.has(local)))
	for guard in 48:
		if served_share(f, on, alive) >= goal: return
		var best: Array = []
		var best_gain := 0.0
		for stretch in stretches:
			var joined := false
			var gain := 0.0
			for local in stretch:
				if on.has(local):
					joined = true
					continue
				for way in WAYS:
					var next := step(f, local, way)
					if next < 0: continue
					if on.has(next): joined = true
					elif alive.has(next) and not served(f, next, on): gain += 0.5 + float(at(f, next).order)
			if not joined or gain <= 0.0: continue
			gain += rng.randf() * 0.75
			if gain > best_gain:
				best_gain = gain
				best = stretch
		if best.is_empty(): return
		take(on, best)

func served(f: Dictionary, local: int, on: Dictionary) -> bool:
	for way in WAYS:
		var next := step(f, local, way)
		if next >= 0 and on.has(next): return true
	return false

func served_share(f: Dictionary, on: Dictionary, alive: Dictionary) -> float:
	var count := 0
	for local in alive:
		if served(f, local, on): count += 1
	return float(count) / maxf(1.0, float(alive.size()))

## A lane cell with no room beside it that does not carry on both ways goes,
## and so on until none is left: nothing leads nowhere.
func prune(f: Dictionary, on: Dictionary, alive: Dictionary) -> void:
	var changed := true
	while changed:
		changed = false
		for local in on.keys():
			var rooms_beside := 0
			var carries := 0
			for way in WAYS:
				var next := step(f, local, way)
				if next < 0: continue
				if on.has(next): carries += 1
				elif alive.has(next): rooms_beside += 1
			if rooms_beside == 0 and carries < 2:
				on.erase(local)
				changed = true

## How many separate pieces a set of lane cells is in.
func pieces(f: Dictionary, cells: Dictionary) -> int:
	var seen := {}
	var count := 0
	for from in cells:
		if seen.has(from): continue
		count += 1
		var queue: Array = [from]
		seen[from] = true
		while not queue.is_empty():
			var local: int = queue.pop_back()
			for way in WAYS:
				var next := step(f, local, way)
				if next >= 0 and cells.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
	return count

## The reception: any room on the first planta with a corridor at its door, or
## any room if the plan left it none.
func pick_start(f: Dictionary, alive: Dictionary, corridor: Dictionary, rng: RandomNumberGenerator) -> int:
	var pool: Array = []
	var any: Array = []
	for local in alive:
		if at(f, local).kind != "module": continue
		any.append(local)
		if served(f, local, corridor): pool.append(local)
	if pool.is_empty(): pool = any
	if pool.is_empty(): return -1
	pool.sort()
	return int(pool[rng.randi_range(0, pool.size() - 1)])

## The service department: on the first planta a block of four in its tidiest
## patch, with its tiles and its tubes; further down, loose pockets where the
## plan has come apart.
func plant_service(f: Dictionary, planta: int, alive: Dictionary, arrival: int, rng: RandomNumberGenerator, standby: bool) -> void:
	if standby: return
	var cells: Array = alive.keys()
	cells.sort()
	if planta == 0:
		var best: Array = []
		var best_order := -1.0
		for local in cells:
			var block: Array = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var next := offset(f, local, corner)
				if next < 0 or not alive.has(next) or at(f, next).kind != "module" or next == arrival: break
				block.append(next)
			if block.size() < 4: continue
			var tidiness := 0.0
			for member in block: tidiness += float(at(f, member).order)
			if tidiness > best_order:
				best_order = tidiness
				best = block
		for member in best: at(f, member).service = true
	for local in cells:
		if local == arrival or at(f, local).kind != "module": continue
		if rng.randf() < lerpf(0.0, 0.14, 1.0 - float(at(f, local).order)): at(f, local).service = true

# --- Doors -----------------------------------------------------------------------------

## The doors of a planta. Corridor meets corridor with no wall between them;
## rooms open on to the corridor as the plan is kept, and on to each other as
## it is not (`between` more often in a warren). The room one arrives in
## always has its door on to a corridor if there is one beside it, and never
## one on the side the lift stands against.
func open_doors(f: Dictionary, alive: Dictionary, corridor: Dictionary, arrival: int, back: Vector2i, rng: RandomNumberGenerator, standby: bool, between := 1.0) -> void:
	var base: int = f.base
	var cells: Array = alive.keys()
	cells.sort()
	for local in cells:
		if not corridor.has(local): continue
		for way: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var next := step(f, local, way)
			if next >= 0 and corridor.has(next): merge(f, base + local, base + next)
	fire_doors(f, corridor)
	for local in cells:
		if at(f, local).kind != "module": continue
		var order: float = at(f, local).order
		var doors: Array = []
		for way in WAYS:
			if local == arrival and way == back: continue
			var next := step(f, local, way)
			if next >= 0 and corridor.has(next): doors.append(next)
		if doors.is_empty(): continue
		shuffle(doors, rng)
		if standby or local == arrival or rng.randf() < 0.55 + 0.45 * order: link(f, base + local, base + int(doors[0]))
		for index in range(1, doors.size()):
			if standby or rng.randf() < lerpf(0.3, 0.03, order): link(f, base + local, base + int(doors[index]))
	for local in cells:
		if at(f, local).kind != "module": continue
		for way: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var next := step(f, local, way)
			if next < 0 or not alive.has(next) or at(f, next).kind != "module": continue
			if (local == arrival and way == back) or (next == arrival and -way == back): continue
			var shared := minf(float(at(f, local).order), float(at(f, next).order))
			# A department is one piece: its own back way through.
			var department: bool = at(f, local).service and at(f, next).service
			if standby or department or rng.randf() < lerpf(0.46, 0.05, shared) * between: link(f, base + local, base + next)

## A corridor that would run straight and open for longer than OPEN_RUN gets a
## fire door across it, where the run passes that length.
func fire_doors(f: Dictionary, corridor: Dictionary) -> void:
	var base: int = f.base
	for line in f.lines:
		var run := 0.0
		var previous := -1
		for local in line.cells:
			var size: float = float(at(f, local).span_z) if line.axis == "v" else float(at(f, local).span_x)
			if not corridor.has(local):
				run = 0.0
				previous = -1
				continue
			if previous >= 0 and f.merged.has(pair_key(base + previous, base + local)):
				run += size
				if run > OPEN_RUN:
					f.merged.erase(pair_key(base + previous, base + local))
					run = size
			else: run = size
			previous = local

## Every cell of the planta reachable from where it is walked into. What the
## draws left cut off is given a door on to the part already reached (a
## corridor if there is one beside it), or, across a lane no corridor uses, a
## passage: the stretch of lane between the two rooms, a door at each side.
## What still cannot be reached, walled in by the shape, goes. `avoid` cells
## are never given a door.
func join(f: Dictionary, alive: Dictionary, arrival: int, back: Vector2i, rng: RandomNumberGenerator, avoid: Array = []) -> void:
	var base: int = f.base
	var seen := reach(f, arrival, alive)
	while true:
		var missing: Array = []
		for local in alive:
			if not seen.has(local) and not avoid.has(local): missing.append(local)
		if missing.is_empty(): return
		missing.sort()
		shuffle(missing, rng)
		var joined := -1
		for local in missing:
			var best := -1
			for way in WAYS:
				var next := step(f, local, way)
				if next < 0 or not seen.has(next) or avoid.has(next): continue
				if (local == arrival and way == back) or (next == arrival and -way == back): continue
				if best < 0 or at(f, next).kind != "module": best = next
			if best < 0: continue
			if at(f, local).kind != "module" and at(f, best).kind != "module": merge(f, base + local, base + best)
			else: link(f, base + local, base + best)
			joined = local
			break
		if joined < 0:
			for local in missing:
				if at(f, local).kind != "module": continue
				for way in WAYS:
					var lane := step(f, local, way)
					if lane < 0 or alive.has(lane) or at(f, lane).kind != "lane": continue
					var other := step(f, lane, way)
					if other < 0 or not seen.has(other) or avoid.has(other) or at(f, other).kind != "module": continue
					if other == arrival and -way == back: continue
					alive[lane] = true
					link(f, base + local, base + lane)
					link(f, base + lane, base + other)
					seen[lane] = true
					joined = local
					break
				if joined >= 0: break
		if joined < 0:
			for local in missing: remove(f, alive, local)
			return
		# What that door brings in, and no more: the rest was reached already.
		seen[joined] = true
		var queue: Array = [joined]
		while not queue.is_empty():
			var here: int = queue.pop_back()
			for other in f.adjacency[base + here]:
				var next: int = int(other) - base
				if alive.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)

## The cells reached from `from` through the doors of the planta in use,
## leaving out `without`.
func reach(f: Dictionary, from: int, alive: Dictionary, without := -1) -> Dictionary:
	var base: int = f.base
	var seen := {from: true}
	var queue: Array = [from]
	while not queue.is_empty():
		var local: int = queue.pop_back()
		for other in f.adjacency[base + local]:
			var next: int = int(other) - base
			if next != without and alive.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

## Rings to walk round: a planta with fewer than LOOPS is given doors between
## cells side by side that the plan left far apart -- a door that closes a
## long way round, not a square of four rooms -- until it has them. A long
## ring is a way to lose the creature, and what it goes round is out of reach
## of a hand on the wall.
func loops(f: Dictionary, alive: Dictionary, arrival: int, back: Vector2i, rng: RandomNumberGenerator) -> void:
	var base: int = f.base
	var have := cycles(f, alive)
	if have >= LOOPS: return
	var depth := distances(f.adjacency, base + arrival)
	var pairs: Array = []
	var cells: Array = alive.keys()
	cells.sort()
	for local in cells:
		for way: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var next := step(f, local, way)
			if next < 0 or not alive.has(next) or f.adjacency[base + local].has(base + next): continue
			if at(f, local).kind != "module" and at(f, next).kind != "module": continue
			if (local == arrival and way == back) or (next == arrival and -way == back): continue
			var apart := absi(depth[base + local] - depth[base + next])
			pairs.append({"a": local, "b": next, "rank": float(apart) + rng.randf() * 3.0})
	pairs.sort_custom(func(one, two): return float(one.rank) > float(two.rank))
	for pair in pairs:
		if have >= LOOPS: return
		link(f, base + int(pair.a), base + int(pair.b))
		have += 1

## How alike the planta being laid is to the most alike of the ones above
## it: their corridors drawn on one square of LIKENESS_CELLS a side over both
## plans, at the best of the eight turns and mirrors.
func alike(f: Dictionary, planta: int, alive: Dictionary) -> float:
	var here: Array = []
	for local in alive:
		if at(f, local).kind != "module": here.append(at(f, local))
	var most := 0.0
	for above in planta:
		var dims: Dictionary = f.plantas[above]
		var there: Array = []
		var cells: Array = []
		for local in int(dims.width) * int(dims.height):
			var room: Dictionary = f.rooms[int(dims.base) + local]
			cells.append(room)
			if room.corridor: there.append(room)
		for local in int(f.width) * int(f.height): cells.append(at(f, local))
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for room in cells:
			low = Vector2(minf(low.x, float(room.px) - float(room.span_x) * 0.5), minf(low.y, float(room.pz) - float(room.span_z) * 0.5))
			high = Vector2(maxf(high.x, float(room.px) + float(room.span_x) * 0.5), maxf(high.y, float(room.pz) + float(room.span_z) * 0.5))
		var box := Rect2(low, high - low)
		most = maxf(most, overlap(raster(here, box), raster(there, box)))
	return most

## Rooms drawn on a LIKENESS_CELLS square laid over a box of the plan.
static func raster(rooms: Array, box: Rect2) -> PackedByteArray:
	var side := LIKENESS_CELLS
	var cells := PackedByteArray()
	cells.resize(side * side)
	for room in rooms:
		var x0 := clampi(int((float(room.px) - float(room.span_x) * 0.5 - box.position.x) / box.size.x * side), 0, side - 1)
		var x1 := clampi(int((float(room.px) + float(room.span_x) * 0.5 - box.position.x) / box.size.x * side), 0, side - 1)
		var z0 := clampi(int((float(room.pz) - float(room.span_z) * 0.5 - box.position.y) / box.size.y * side), 0, side - 1)
		var z1 := clampi(int((float(room.pz) + float(room.span_z) * 0.5 - box.position.y) / box.size.y * side), 0, side - 1)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1): cells[z * side + x] = 1
	return cells

## What two drawings have in common over what either has, at the best of the
## eight ways of turning and mirroring the second.
static func overlap(one: PackedByteArray, two: PackedByteArray) -> float:
	var side := LIKENESS_CELLS
	var count_one := 0
	for value in one: count_one += value
	var marks := PackedInt32Array()
	for index in two.size():
		if two[index]: marks.append(index)
	if count_one + marks.size() == 0: return 0.0
	var best := 0.0
	for turn in 8:
		# Each cell of the second, turned back to where it lands on the first.
		var both := 0
		for index in marks:
			var u := index % side
			var v := index / side
			if turn & 4:
				var swap := u
				u = v
				v = swap
			if turn & 1: u = side - 1 - u
			if turn & 2: v = side - 1 - v
			both += one[v * side + u]
		best = maxf(best, float(both) / float(count_one + marks.size() - both))
	return best

## Independent rings in a planta's doors: doors, less cells, plus one.
func cycles(f: Dictionary, alive: Dictionary) -> int:
	var base: int = f.base
	var doors := 0
	for local in alive: doors += f.adjacency[base + local].size()
	return doors / 2 - alive.size() + 1

## Salons: two or three rooms side by side thrown into one, the walls between
## them gone -- in a line (never longer than a straight open run may be) or in
## an L. Never the way in, never service, and no more of them than the rooms
## the planta has to spare (`budget`: a salon of three is two rooms fewer).
func make_halls(f: Dictionary, alive: Dictionary, arrival: int, rng: RandomNumberGenerator, budget: int) -> void:
	var base: int = f.base
	var wanted := rng.randi_range(HALLS.x, HALLS.y)
	var cells: Array = alive.keys()
	cells.sort()
	shuffle(cells, rng)
	for local in cells:
		if wanted <= 0 or budget <= 0: return
		if not free_for_hall(f, alive, local, arrival): continue
		var members: Array = [local]
		var ways: Array = WAYS.duplicate()
		shuffle(ways, rng)
		for way: Vector2i in ways:
			if members.size() >= mini(3, budget + 1): break
			var next := step(f, local, way)
			if not free_for_hall(f, alive, next, arrival): continue
			if members.size() == 2:
				# The third in a line with the other two only if the three are
				# not too long to see down.
				var first: int = members[1]
				var line := step(f, local, -way) == first
				var length: float = at(f, local).span_x + at(f, first).span_x + at(f, next).span_x if way.y == 0 else at(f, local).span_z + at(f, first).span_z + at(f, next).span_z
				if line and length > OPEN_RUN: continue
			members.append(next)
		if members.size() < 2: continue
		for member in members: at(f, member).hall = base + local
		for member in members.slice(1): merge(f, base + local, base + int(member))
		budget -= members.size() - 1
		wanted -= 1

func free_for_hall(f: Dictionary, alive: Dictionary, local: int, arrival: int) -> bool:
	if local < 0 or local == arrival or not alive.has(local): return false
	var room: Dictionary = at(f, local)
	return room.kind == "module" and room.hall < 0 and not room.service

# --- Trimming --------------------------------------------------------------------------

## Down to `target` rooms. First rooms that lead nowhere else; before the
## refuge is placed, also rooms on the edge of the planta whose going leaves
## the rest walkable, which is what frays the outline. Once the refuge is
## there only rooms that lead nowhere else go, and never on the way to it:
## walling one of those up leaves every walk as it was, the one with a hand on
## the wall too.
func trim(f: Dictionary, planta: int, alive: Dictionary, arrival: int, refuge: Dictionary, target: int, rng: RandomNumberGenerator) -> void:
	var base: int = f.base
	var landing := int(refuge.get("landing", -1))
	var keep := {arrival: true}
	if not refuge.is_empty():
		keep[int(refuge.room)] = true
		keep[landing] = true
		for local in way_to(f, alive, arrival, int(refuge.room)): keep[local] = true
	var count := count_rooms(f, planta, alive, arrival, landing)
	while count > target:
		var cells: Array = alive.keys()
		cells.sort()
		shuffle(cells, rng)
		var pick := -1
		for local in cells:
			var room: Dictionary = at(f, local)
			if keep.has(local) or room.kind != "module" or room.hall >= 0: continue
			if f.adjacency[base + local].size() <= 1:
				pick = local
				break
		if pick < 0 and refuge.is_empty():
			for local in cells:
				var room: Dictionary = at(f, local)
				if keep.has(local) or room.kind != "module" or room.hall >= 0 or not on_edge(f, local, alive): continue
				if reach(f, arrival, alive, local).size() == alive.size() - 1:
					pick = local
					break
		if pick < 0: return
		remove(f, alive, pick)
		count -= 1

## Corridor stubs no room opens on to go: a corridor leads somewhere.
func tidy(f: Dictionary, alive: Dictionary) -> void:
	var base: int = f.base
	var changed := true
	while changed:
		changed = false
		for local in alive.keys():
			if at(f, local).kind == "module": continue
			var links: Array = f.adjacency[base + local]
			if links.size() > 1 or (links.size() == 1 and f.rooms[int(links[0])].kind == "module"): continue
			remove(f, alive, local)
			changed = true

func remove(f: Dictionary, alive: Dictionary, local: int) -> void:
	var base: int = f.base
	alive.erase(local)
	for other in f.adjacency[base + local].duplicate(): unlink(f, base + local, int(other))

## Rooms on the planta, as they are counted: every room, salon, service room
## and refuge, a salon once however many modules it takes; not the corridors,
## and not the lobbies of the lifts.
func count_rooms(f: Dictionary, planta: int, alive: Dictionary, arrival: int, landing: int) -> int:
	var count := 0
	var halls := {}
	for local in alive:
		var room: Dictionary = at(f, local)
		if room.kind != "module" or local == landing or (planta > 0 and local == arrival): continue
		if room.hall >= 0:
			if halls.has(room.hall): continue
			halls[room.hall] = true
		count += 1
	return count

## The cells on the shortest way (in doors) between two cells of the planta.
func way_to(f: Dictionary, alive: Dictionary, from: int, to: int) -> Array:
	var base: int = f.base
	var parents := {from: -1}
	var queue: Array = [from]
	var cursor := 0
	while cursor < queue.size():
		var local: int = queue[cursor]
		cursor += 1
		if local == to: break
		for other in f.adjacency[base + local]:
			var next: int = int(other) - base
			if alive.has(next) and not parents.has(next):
				parents[next] = local
				queue.append(next)
	var path: Array = []
	var here := to
	while parents.has(here) and here >= 0:
		path.append(here)
		here = int(parents[here])
	return path

func on_edge(f: Dictionary, local: int, alive: Dictionary) -> bool:
	for way in WAYS:
		var next := step(f, local, way)
		if next < 0 or not alive.has(next): return true
	return false

# --- The refuge ------------------------------------------------------------------------

## The refuge and the lift lobby behind it. Not the room farthest in, which is
## what made every floor solve alike ("the back, the corner"): any ordinary
## room between 55 and 90 % of the way in, as the route goes, rather one that
## no corridor passes and not on the outside edge; never the way another
## planta's was, nor among the rooms farthest in a straight line, nor where
## the walk is hardly longer than the line, while there is anything else. Its
## lobby is the room beside it on the side it is drawn, sealed but for the
## refuge's locked door; the refuge keeps one door of its own, drawn too. And
## none of it is found by walking with a hand on the wall, the walk that solves
## most mazes (wall_walker.gd): the rooms that walk looks into from the way in
## are measured first, and a refuge whose one door can be off all of them is
## the one wanted.
func place_refuge(f: Dictionary, alive: Dictionary, arrival: int, back: Vector2i, rng: RandomNumberGenerator, standby: bool, bearings: Array) -> Dictionary:
	var base: int = f.base
	var metres := route_metres(f, alive, arrival)
	var walked := WALKER.covered(f.rooms, f.adjacency, base + arrival)
	var deepest := 0.0
	for local in metres: deepest = maxf(deepest, float(metres[local]))
	if deepest <= 0.0: return {}
	var from := Vector2(float(at(f, arrival).px), float(at(f, arrival).pz))
	# Going to the far side first is how a hotel is searched: the rooms
	# farthest in a straight line, the third of them that would be tried
	# first, are left alone where anything else will do.
	var across: Array = []
	for local in alive:
		if at(f, local).kind == "module": across.append(Vector2(float(at(f, local).px), float(at(f, local).pz)).distance_to(from))
	across.sort()
	var far_side: float = across[int(across.size() * (1.0 - FAR_SIDE))] if not across.is_empty() else INF
	var candidates: Array = []
	var cells: Array = alive.keys()
	cells.sort()
	for local in cells:
		var room: Dictionary = at(f, local)
		if room.kind != "module" or local == arrival or room.hall >= 0 or room.service or not metres.has(local): continue
		var share: float = float(metres[local]) / deepest
		if share < DEPTH.x or share > DEPTH.y: continue
		var spot := Vector2(float(room.px), float(room.pz))
		var bearing := int(floor(fposmod((spot - from).angle() + PI / 8.0, TAU) / (PI / 4.0))) % 8
		for way in WAYS:
			var landing := step(f, local, way)
			if landing < 0 or landing == arrival or not alive.has(landing): continue
			var other: Dictionary = at(f, landing)
			if other.kind != "module" or other.hall >= 0: continue
			var weight := 1.0
			if not beside_corridor(f, local, alive): weight *= 2.0
			if not on_edge(f, local, alive): weight *= 1.5
			if walked.has(base + local): weight *= 0.3
			if hidden_doors(f, local, landing, alive, walked) > 0: weight *= 6.0
			var plain: bool = spot.distance_to(from) >= far_side or float(metres[local]) < WINDING * spot.distance_to(from)
			candidates.append({"room": local, "landing": landing, "out": way, "weight": weight, "bearing": bearing, "share": share, "walked": walked, "plain": plain})
	# Never the way another planta's refuge was, nor among the rooms farthest
	# in a straight line, nor where the walk there is hardly longer than the
	# line, while there is anything else.
	# The way the others were is a rule: with no other way, the planta is
	# drawn again.
	var elsewhere: Array = candidates.filter(func(entry): return not bearings.has(int(entry.bearing)))
	if elsewhere.is_empty() and not standby: return {}
	if not elsewhere.is_empty(): candidates = elsewhere
	var hidden: Array = candidates.filter(func(entry): return not entry.plain)
	if not hidden.is_empty(): candidates = hidden
	if candidates.is_empty(): return {}
	if standby: candidates.sort_custom(func(a, b): return float(a.share) > float(b.share))
	var pool := candidates.duplicate()
	var population := 0
	for local in alive:
		if at(f, local).kind == "module": population += 1
	var best := {}
	var best_state := {}
	for attempt in 8:
		if candidates.is_empty(): break
		var pick: Dictionary = candidates[0] if standby else weighted(candidates, rng)
		candidates.erase(pick)
		var saved := save(f)
		var tried := alive.duplicate()
		var trial := try_refuge(f, tried, arrival, back, pick, rng, population)
		if trial.is_empty():
			restore(f, saved)
			continue
		if int(trial.hits) == 0 and trial.fits:
			alive.clear()
			alive.merge(tried)
			return trial
		if best.is_empty() or int(trial.cost) > int(best.cost):
			best = trial
			best_state = save(f)
			best_state["alive"] = tried
		restore(f, saved)
	# Nothing the walk misses as the planta is: the refuge is made an island.
	pool.sort_custom(func(a, b): return float(a.weight) > float(b.weight))
	for pick in pool.slice(0, 16):
		var saved := save(f)
		var tried := alive.duplicate()
		var trial := island(f, tried, arrival, back, pick, rng, population)
		if not trial.is_empty() and int(trial.hits) == 0 and trial.fits:
			alive.clear()
			alive.merge(tried)
			fail("island")
			return trial
		restore(f, saved)
	# Not even that: the planta is drawn again. Only the standby floor takes
	# what it gets.
	if best.is_empty() or not standby: return {}
	restore(f, best_state)
	alive.clear()
	alive.merge(best_state.alive)
	return best

## One refuge tried: its lobby sealed, and of its own doors the one that hides
## it best kept. Returns {room, landing, out, hits, cost, fits, bearing} or {}.
func try_refuge(f: Dictionary, alive: Dictionary, arrival: int, back: Vector2i, pick: Dictionary, rng: RandomNumberGenerator, population: int) -> Dictionary:
	var base: int = f.base
	var room: int = pick.room
	var landing: int = pick.landing
	for other in f.adjacency[base + landing].duplicate(): unlink(f, base + landing, int(other))
	var ways: Array = []
	for way in WAYS:
		var next := step(f, room, way)
		if next >= 0 and next != landing and alive.has(next): ways.append(next)
	if ways.is_empty(): return {}
	shuffle(ways, rng)
	# Doors on to rooms the walk from the way in never looks into first.
	var walked: Dictionary = pick.walked
	ways.sort_custom(func(one, two): return not walked.has(base + int(one)) and walked.has(base + int(two)))
	var start_state := save(f)
	var best := {}
	for keep in ways:
		restore(f, start_state)
		for other in f.adjacency[base + room].duplicate(): unlink(f, base + room, int(other))
		link(f, base + room, base + int(keep))
		var trial_alive := alive.duplicate()
		trial_alive.erase(landing)
		join(f, trial_alive, arrival, back, rng, [room, landing])
		if not reach(f, arrival, trial_alive).has(room): continue
		var found := WALKER.score(f.rooms, f.adjacency, base + arrival, base + room, population)
		var hits: int = found.hits
		var cost: int = found.cost
		# How far in it now is only matters once nothing finds it.
		var fits := hits == 0 and in_depth(f, trial_alive, arrival, room)
		if best.is_empty() or hits < int(best.hits) or (hits == int(best.hits) and fits and not best.fits) or (hits == int(best.hits) and fits == best.fits and cost > int(best.cost)):
			best = {"hits": hits, "cost": cost, "fits": fits, "state": save(f), "alive": trial_alive}
		if hits == 0 and fits: break
	if best.is_empty(): return {}
	restore(f, best.state)
	# What the joining walled off is gone, and a passage it opened is there.
	alive.clear()
	alive.merge(best.alive)
	alive[landing] = true
	# The lock's door: nothing else opens on to the lobby.
	link(f, base + room, base + landing)
	return {"room": room, "landing": landing, "out": pick.out, "hits": best.hits, "cost": best.cost, "fits": best.fits, "bearing": pick.bearing}

## The refuge as an island: the ten cells round it and its lobby doored into a
## closed ring, and its one door on to the ring's inside. A hand on the wall
## goes round the outside of the ring and never turns in -- and it is a plan a
## hotel has: the core with the lift in it, and the rooms and the corridor
## round it. A lane in the ring becomes a passage; a room the shape took out
## or the way in cannot be part of it.
func island(f: Dictionary, alive: Dictionary, arrival: int, back: Vector2i, pick: Dictionary, rng: RandomNumberGenerator, population: int) -> Dictionary:
	var base: int = f.base
	var room: int = pick.room
	var landing: int = pick.landing
	var ring := ring_round(f, room, landing)
	if ring.is_empty() or ring.has(arrival): return {}
	for local in ring:
		if not alive.has(local) and at(f, local).kind == "module": return {}
	for local in ring: alive[local] = true
	for other in f.adjacency[base + landing].duplicate(): unlink(f, base + landing, int(other))
	for other in f.adjacency[base + room].duplicate(): unlink(f, base + room, int(other))
	for index in ring.size(): link(f, base + int(ring[index]), base + int(ring[(index + 1) % ring.size()]))
	var doors: Array = ring.filter(func(local): return absi(int(local) % int(f.width) - room % int(f.width)) + absi(int(local) / int(f.width) - room / int(f.width)) == 1)
	if doors.is_empty(): return {}
	link(f, base + room, base + int(doors[rng.randi_range(0, doors.size() - 1)]))
	alive.erase(landing)
	join(f, alive, arrival, back, rng, [room, landing])
	if not reach(f, arrival, alive).has(room):
		alive[landing] = true
		return {}
	var found := WALKER.score(f.rooms, f.adjacency, base + arrival, base + room, population)
	var fits := int(found.hits) == 0 and in_depth(f, alive, arrival, room)
	alive[landing] = true
	link(f, base + room, base + landing)
	return {"room": room, "landing": landing, "out": pick.out, "hits": found.hits, "cost": found.cost, "fits": fits, "bearing": pick.bearing}

## The ten cells round a two-cell core, in the order they ring it, or none if
## the block does not fit on the grid.
func ring_round(f: Dictionary, one: int, two: int) -> Array:
	var width: int = f.width
	var low := Vector2i(mini(one % width, two % width) - 1, mini(one / width, two / width) - 1)
	var high := Vector2i(maxi(one % width, two % width) + 1, maxi(one / width, two / width) + 1)
	if low.x < 0 or low.y < 0 or high.x >= width or high.y >= int(f.height): return []
	var ring: Array = []
	for x in range(low.x, high.x + 1): ring.append(low.y * width + x)
	for z in range(low.y + 1, high.y + 1): ring.append(z * width + high.x)
	for x in range(high.x - 1, low.x - 1, -1): ring.append(high.y * width + x)
	for z in range(high.y - 1, low.y, -1): ring.append(z * width + low.x)
	return ring

## Whether the refuge is as far in as it has to be, as the planta now stands:
## between DEPTH of the way to its farthest room, measured walking. (Sealing
## its lobby and leaving it one door changes the routes it was chosen by.)
func in_depth(f: Dictionary, alive: Dictionary, arrival: int, room: int) -> bool:
	var metres := route_metres(f, alive, arrival)
	var deepest := 0.0
	for local in metres: deepest = maxf(deepest, float(metres[local]))
	if not metres.has(room) or deepest <= 0.0: return false
	var share: float = float(metres[room]) / deepest
	return share >= DEPTH.x and share <= DEPTH.y

## Metres from where the planta is walked into to every cell, along its doors.
func route_metres(f: Dictionary, alive: Dictionary, from: int) -> Dictionary:
	var base: int = f.base
	var metres := {from: 0.0}
	var open: Array = [from]
	while not open.is_empty():
		var best_index := 0
		for index in open.size():
			if float(metres[open[index]]) < float(metres[open[best_index]]): best_index = index
		var local: int = open[best_index]
		open.remove_at(best_index)
		var here: Dictionary = at(f, local)
		for other in f.adjacency[base + local]:
			var next: int = int(other) - base
			if not alive.has(next): continue
			var there: Dictionary = at(f, next)
			var length: float = float(metres[local]) + Vector2(float(here.px), float(here.pz)).distance_to(Vector2(float(there.px), float(there.pz)))
			if not metres.has(next):
				open.append(next)
				metres[next] = length
			elif length < float(metres[next]) - 0.001: metres[next] = length
	return metres

## How many of a room's possible doors (not its lobby's) open on to rooms the
## walk from the way in never looks into.
func hidden_doors(f: Dictionary, local: int, landing: int, alive: Dictionary, walked: Dictionary) -> int:
	var count := 0
	for way in WAYS:
		var next := step(f, local, way)
		if next >= 0 and next != landing and alive.has(next) and not walked.has(int(f.base) + next): count += 1
	return count

func beside_corridor(f: Dictionary, local: int, alive: Dictionary) -> bool:
	for way in WAYS:
		var next := step(f, local, way)
		if next >= 0 and alive.has(next) and at(f, next).kind != "module": return true
	return false

## One of the candidates, drawn by their weights.
static func weighted(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for entry in candidates: total += float(entry.weight)
	var draw := rng.randf() * total
	for entry in candidates:
		draw -= float(entry.weight)
		if draw <= 0.0: return entry
	return candidates[candidates.size() - 1]

# --- What each room is -----------------------------------------------------------------

## Types, televisions, heights, furniture and zones, once every planta is laid.
func finish(f: Dictionary, start: int, refuges: Array, entries: Array, decoration: RandomNumberGenerator) -> void:
	# A corridor line is corridor or gallery the whole way along.
	var galleries := {}
	for planta in WINGS:
		for line in f.plantas[planta].lines:
			if decoration.randf() < 0.22: galleries["%d%s%d" % [planta, line.axis, line.index]] = true
	for room in f.rooms:
		if int(room.type) == VOID: continue
		if room.corridor:
			var gallery: bool = galleries.has("%dv%d" % [int(room.wing), int(room.x)]) or galleries.has("%dh%d" % [int(room.wing), int(room.z)])
			room.type = GALLERY if gallery else CORRIDOR
		elif room.service: room.type = SERVICE_ROOMS[decoration.randi_range(0, SERVICE_ROOMS.size() - 1)]
		elif decoration.randf() < float(room.order): room.type = TIDY_ROOMS[decoration.randi_range(0, TIDY_ROOMS.size() - 1)]
		else: room.type = UNRULY_ROOMS[decoration.randi_range(0, UNRULY_ROOMS.size() - 1)]
		if room.hall >= 0: room.type = HALL_ROOMS[int(room.hall) % HALL_ROOMS.size()]
		# Behind the door of a refuge: the lift lobby. Tiled, lit, and nothing
		# in it but the car.
		if bool(room.get("landing", false)): room.type = LANDING
	f.rooms[start].type = RECEPTION
	# One comes out of the lift into the planta's own lobby: a landmark to
	# come back to, and the only one there is.
	for planta in range(1, WINGS): f.rooms[int(entries[planta])].type = LOBBY
	for id in refuges:
		f.rooms[int(id)].type = REFUGE
		f.rooms[int(id)].hall = -1
		f.rooms[int(id)].service = false
	# The second and third stages are played on the sets of their own planta:
	# each has to hold enough of them, whatever the types rolled.
	for planta in [1, 2]:
		var dims: Dictionary = f.plantas[planta]
		var with_tv: Array = []
		var plain: Array = []
		for local in int(dims.width) * int(dims.height):
			var room: Dictionary = f.rooms[int(dims.base) + local]
			if int(room.type) in [VOID, RECEPTION, LOBBY, REFUGE, LANDING] or room.corridor or room.service or room.hall >= 0: continue
			if FLOOR.RECIPES[int(room.type)].has("tv"): with_tv.append(int(room.id))
			else: plain.append(int(room.id))
		while with_tv.size() < TV_ROOMS and not plain.is_empty():
			var pick: int = plain[decoration.randi_range(0, plain.size() - 1)]
			plain.erase(pick)
			f.rooms[pick].type = TV_ROOM
			with_tv.append(pick)
	for room in f.rooms:
		room.props = []
		room.cover_slots = 0
		room.variant = 0
		room.layout = 0
		room.height = 3.15
		if int(room.type) == VOID: continue
		room.variant = decoration.randi_range(0, 3)
		room.layout = decoration.randi_range(0, 3)
		room.height = 4.8 if room.hall >= 0 else 4.2 if int(room.type) in [0, 5, 6, 17, 18] else 3.15
		# A corridor is a lane of three or four metres: nothing in its corners.
		if room.corridor: continue
		room.cover_slots = 4
		# The recipe's four pieces go to the four corners in an order of the
		# room's own: the bed is not always in the same corner of a bedroom.
		var kinds: Array = FLOOR.RECIPES[int(room.type)].duplicate()
		shuffle(kinds, decoration)
		for slot in 4:
			var kind: String = kinds[slot]
			var rotation := decoration.randi_range(0, 3)
			if kind in ["bed", "sofa", "desk", "tv", "reception", "washer", "basin", "shelf"]: rotation = 0 if slot < 2 else 2
			if kind in ["wardrobe", "curtain"]: rotation = 1 if slot % 2 == 0 else 3
			room.props.append({"kind": kind, "slot": slot, "rotation": rotation})
	# Open sides: where a salon or a corridor carries on with no wall.
	for room in f.rooms: room["open_sides"] = []
	for pair in f.merged.values():
		var a: Dictionary = f.rooms[int(pair[0])]
		var b: Dictionary = f.rooms[int(pair[1])]
		var direction := "east" if int(b.x) > int(a.x) else "south"
		a.open_sides.append(direction)
		b.open_sides.append("west" if direction == "east" else "north")
	zones(f, entries)

## Zones: five to seven parts of each planta, the room farthest from the others
## seeding each, so what a stage asks for is spread over it instead of piled in
## a corner. (They are what `sector` has always meant to the placements.)
func zones(f: Dictionary, entries: Array) -> void:
	for planta in WINGS:
		var dims: Dictionary = f.plantas[planta]
		var members: Array = []
		for local in int(dims.width) * int(dims.height):
			if int(f.rooms[int(dims.base) + local].type) != VOID: members.append(int(dims.base) + local)
		var count := clampi(int(round(float(members.size()) / 20.0)), 5, 7)
		var seeds: Array = [int(entries[planta])]
		var nearest: Array[int] = distances(f.adjacency, int(entries[planta]))
		while seeds.size() < count:
			var far := -1
			for id in members:
				if nearest[id] >= 0 and (far < 0 or nearest[id] > nearest[far]): far = id
			if far < 0 or nearest[far] <= 1: break
			seeds.append(far)
			var from_seed := distances(f.adjacency, far)
			for id in members:
				if from_seed[id] >= 0 and (nearest[id] < 0 or from_seed[id] < nearest[id]): nearest[id] = from_seed[id]
		var tables: Array = []
		for seed_id in seeds: tables.append(distances(f.adjacency, seed_id))
		for id in members:
			var best := 0
			for index in tables.size():
				var here: int = tables[index][id]
				if here >= 0 and (tables[best][id] < 0 or here < tables[best][id]): best = index
			f.rooms[id].sector = best

## Which way the reception's door is, as a yaw: a floor starts looking at it,
## the door on to a corridor if it has one.
func facing(f: Dictionary, start: int) -> float:
	var room: Dictionary = f.rooms[start]
	var doors: Array = f.adjacency[start].duplicate()
	doors.sort()
	if doors.is_empty(): return PI
	var pick: int = doors[0]
	for other in doors:
		if f.rooms[int(other)].corridor:
			pick = int(other)
			break
	var door := FLOOR.portal_between(room, f.rooms[pick]) - FLOOR.position_of(room)
	return atan2(-door.x, -door.z)

# --- Doors, wardrobes, lamps and wear --------------------------------------------

## Every door of the floor: where it stands in its wall, the jamb it hangs
## from, which way it swings and whether it is found open, by "a:b" (the
## pair's ids, lower first) for the manifest's `doors`, so every machine hangs
## them alike; and each room's `doors` ([neighbour, offset]) for FLOOR.
## portal_between() and whatever looks for a doorway.
##  - offset: metres from the middle of the wall, along +z for a wall between
##    cells side by side in x and along +x for one between cells one behind
##    the other. A fire door, across a corridor, stands by a side wall.
##  - hinge: the jamb it hangs from, +1 the one that way along the wall.
##  - swing: +1 it opens into the second room of the pair, -1 into the first.
##    Into the room from a corridor, never across the corridor; into the lift
##    lobby from a refuge; between two rooms, either way.
func hang_doors(f: Dictionary, gates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var doors := {}
	for room in f.rooms: room["doors"] = []
	var lobbies := {}
	for gate in gates: lobbies[pair_key(int(gate.room), int(gate.beyond))] = int(gate.beyond)
	for edge in f.edges:
		var a: Dictionary = f.rooms[int(edge[0])]
		var b: Dictionary = f.rooms[int(edge[1])]
		var key := pair_key(int(a.id), int(b.id))
		if f.merged.has(key): continue
		var wall: float = float(a.span_z) if int(a.x) != int(b.x) else float(a.span_x)
		var room_most := wall * 0.5 - FLOOR.PORTAL * 0.5 - FIRE_JAMB
		var spec := {"offset": 0.0, "hinge": 1 if rng.randf() < 0.5 else -1, "swing": 1, "open": false}
		if lobbies.has(key):
			# A refuge's door: in the middle, beside its keypad, shut, and
			# opening into the lobby, away from whoever waits in the refuge.
			spec.swing = 1 if int(lobbies[key]) == int(b.id) else -1
		elif bool(a.corridor) and bool(b.corridor) and wall < LANE_WALL:
			var side := 1 if rng.randf() < 0.5 else -1
			spec.offset = side * room_most
			spec.hinge = side
			# Into the lane, whose sides are walls: a crossing's sides are
			# the other corridor going on, and a leaf open there stood in it.
			spec.swing = 1 if rng.randf() < 0.5 else -1
			if a.kind == "cross": spec.swing = 1
			elif b.kind == "cross": spec.swing = -1
			spec.open = rng.randf() < FIRE_OPEN
		else:
			var places: Array = DOOR_PLACES_DOMESTIC if int(a.type) in DOMESTIC or int(b.type) in DOMESTIC else DOOR_PLACES
			spec.offset = clampf(float(places[rng.randi_range(0, places.size() - 1)]), -room_most, room_most)
			if bool(a.corridor) != bool(b.corridor): spec.swing = -1 if bool(b.corridor) else 1
			else: spec.swing = 1 if rng.randf() < 0.5 else -1
			spec.open = rng.randf() < lerpf(OPEN_DOORS.x, OPEN_DOORS.y, minf(float(a.order), float(b.order)))
		doors["%d:%d" % [int(a.id), int(b.id)]] = spec
		a.doors.append([int(b.id), spec.offset])
		b.doors.append([int(a.id), spec.offset])
	return doors

## Where each room's wardrobes stand (`hides`, room space), as many as its
## type has (FLOOR.WARDROBES): on closed walls, at the middle or 1.8 m either
## side of it, clear of that wall's doorway and of what its leaf sweeps; with
## two, on opposite walls where there can be, or else well apart.
func place_hides(f: Dictionary, rng: RandomNumberGenerator) -> void:
	var opposite := {"west": "east", "east": "west", "north": "south", "south": "north"}
	for room in f.rooms:
		room["hides"] = []
		if int(room.type) in [VOID, REFUGE] or int(room.hall) >= 0: continue
		var wanted: int = FLOOR.WARDROBES.get(int(room.type), 0)
		if wanted == 0: continue
		var ways := FLOOR.doorways(room)
		var free := {}
		for wall in ["west", "east", "north", "south"]:
			if room.open_sides.has(wall): continue
			var spots: Array = []
			for along in HIDE_SPOTS:
				if not ways.any(func(way): return way.wall == wall and absf(float(way.along) - float(along)) < HIDE_CLEAR): spots.append(along)
			if not spots.is_empty(): free[wall] = spots
		var span := FLOOR.size_of(room) * 0.5 - Vector2.ONE * 0.8
		var taken: Array = []
		while taken.size() < wanted and not free.is_empty():
			var walls: Array = free.keys()
			if not taken.is_empty() and free.has(opposite[taken[0][0]]): walls = [opposite[taken[0][0]]]
			var wall: String = walls[rng.randi_range(0, walls.size() - 1)]
			var along: float = free[wall][rng.randi_range(0, free[wall].size() - 1)]
			taken.append([wall, along])
			free[wall] = free[wall].filter(func(other): return absf(float(other) - along) >= HIDE_APART)
			if free[wall].is_empty(): free.erase(wall)
		for spot in taken:
			match spot[0]:
				"west": room.hides.append([-span.x, spot[1]])
				"east": room.hides.append([span.x, spot[1]])
				"north": room.hides.append([spot[1], -span.y])
				"south": room.hides.append([spot[1], span.y])

## Which rooms have their lamps out (`dark`) and how kept each one is
## (`kept`), by seed: the same corner of two floors has nothing to do with
## each other. See DARK_OWN and WEAR.
func light_rooms(f: Dictionary, rng: RandomNumberGenerator) -> void:
	var seeds: Array = []
	for room in f.rooms:
		room["dark"] = false
		room["kept"] = 0
		if int(room.type) == VOID: continue
		var kept := float(room.order) + rng.randf_range(-WEAR, WEAR)
		room.kept = 0 if kept > KEPT.y else 1 if kept > KEPT.x else 2
		if int(room.type) == EMPTY_SALON: room.kept = maxi(int(room.kept), 1)
		if not FLOOR.may_be_dark(room): continue
		if rng.randf() < (DARK_CORRIDOR.x if bool(room.corridor) else float(DARK_OWN[int(room.wing)])):
			room.dark = true
			seeds.append(int(room.id))
	for id in seeds:
		for other in f.adjacency[id]:
			var next: Dictionary = f.rooms[int(other)]
			if bool(next.dark) or not FLOOR.may_be_dark(next): continue
			if rng.randf() < (DARK_CORRIDOR.y if bool(next.corridor) else DARK_SPREAD): next.dark = true

## The numbers on the doors. Each planta has its own hundred and the numbers
## run across it in rows, odd on one side of a corridor and even on the other,
## as they do in a hotel; which way the rows run is drawn per planta, so going
## up in number leads nowhere in particular. A room no corridor reaches takes
## its number in the same run, as the far half of a suite would.
func number_rooms(f: Dictionary, rng: RandomNumberGenerator) -> void:
	for room in f.rooms: room["number"] = 0
	for planta in WINGS:
		var dims: Dictionary = f.plantas[planta]
		var hundred := (planta + 1) * 100
		var down := rng.randf() < 0.5
		var backwards := rng.randf() < 0.5
		var odd_first := rng.randf() < 0.5
		var let: Array = []
		for local in int(dims.width) * int(dims.height):
			if numbered(f.rooms[int(dims.base) + local]): let.append(int(dims.base) + local)
		var sweep := func(one: int, two: int) -> bool:
			var first := Vector2i(int(f.rooms[one].x), int(f.rooms[one].z))
			var second := Vector2i(int(f.rooms[two].x), int(f.rooms[two].z))
			if down:
				first = Vector2i(first.y, first.x)
				second = Vector2i(second.y, second.x)
			if first.x != second.x: return first.x < second.x
			return first.y < second.y
		let.sort_custom(sweep)
		if backwards: let.reverse()
		var next := [1, 2]
		for id in let:
			var room: Dictionary = f.rooms[id]
			# Odd down one side of the corridor and even down the other.
			var side := (int(room.x) + int(room.z)) % 2
			for other in f.adjacency[id]:
				var hall: Dictionary = f.rooms[int(other)]
				if not hall.corridor: continue
				side = 0 if int(room.x) + int(room.z) < int(hall.x) + int(hall.z) else 1
				if not odd_first: side = 1 - side
				break
			room.number = hundred + take_number(next, side)

## The next number of that side's series (odd or even), or of the other one
## when it has run out: a hundred has room for 99.
static func take_number(next: Array, side: int) -> int:
	if int(next[side]) > 99: side = 1 - side
	var number: int = next[side]
	next[side] = number + 2
	return number

## Whether this room is let to somebody, and so has a number on its door.
static func numbered(room: Dictionary) -> bool:
	return int(room.hall) < 0 and not bool(room.get("corridor", false)) and not bool(room.get("service", false)) and not int(room.type) in NO_NUMBER

# --- Grid and graph helpers ------------------------------------------------------------

## The cell one step from this one on the grid in use (local indices), or -1
## off it.
func step(f: Dictionary, local: int, way: Vector2i) -> int:
	return offset(f, local, way)

func offset(f: Dictionary, local: int, by: Vector2i) -> int:
	var width: int = f.width
	var x := local % width + by.x
	var z := local / width + by.y
	if x < 0 or z < 0 or x >= width or z >= int(f.height): return -1
	return z * width + x

static func pair_key(a: int, b: int) -> int:
	return mini(a, b) * 65536 + maxi(a, b)

## A door between two cells (global ids), once.
func link(f: Dictionary, a: int, b: int) -> void:
	if f.adjacency[a].has(b): return
	connect_rooms(a, b, f.edges, f.adjacency)

## No wall at all between two cells: corridor to corridor, or a salon.
func merge(f: Dictionary, a: int, b: int) -> void:
	link(f, a, b)
	f.merged[pair_key(a, b)] = [mini(a, b), maxi(a, b)]

func unlink(f: Dictionary, a: int, b: int) -> void:
	disconnect_rooms(a, b, f.edges, f.adjacency)
	f.merged.erase(pair_key(a, b))

## The doors of the planta in use, to go back to after a try. Only its own:
## the plantas above are not touched while it is laid and the ones below are
## not laid yet, so its edges go back at the end of the list, where they were.
func save(f: Dictionary) -> Dictionary:
	var base: int = f.base
	var per: int = f.width * f.height
	var adjacency: Array = []
	for local in per: adjacency.append(f.adjacency[base + local].duplicate())
	var merged := {}
	for pair in f.merged:
		if int(f.merged[pair][0]) >= base: merged[pair] = f.merged[pair]
	# Its edges are the last in the list: the ones before are the plantas'
	# above, which nothing here touches. Pairs are never changed, only added
	# or taken out, so the list of them is enough.
	return {"adjacency": adjacency, "edges": f.edges.slice(int(f.edge_base)), "merged": merged}

func restore(f: Dictionary, saved: Dictionary) -> void:
	var base: int = f.base
	var per: int = f.width * f.height
	for local in per:
		f.adjacency[base + local].clear()
		f.adjacency[base + local].append_array(saved.adjacency[local])
	f.edges.resize(int(f.edge_base))
	f.edges.append_array(saved.edges)
	for pair in f.merged.keys():
		if int(f.merged[pair][0]) >= base: f.merged.erase(pair)
	for pair in saved.merged: f.merged[pair] = saved.merged[pair]

static func shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap

static func disconnect_rooms(a: int, b: int, edges: Array, adjacency: Array) -> void:
	adjacency[a].erase(b)
	adjacency[b].erase(a)
	# A pair is in the list once, and the newest are at the end.
	for index in range(edges.size() - 1, -1, -1):
		if int(edges[index][0]) == mini(a, b) and int(edges[index][1]) == maxi(a, b):
			edges.remove_at(index)
			return

static func connect_rooms(a: int, b: int, edges: Array, adjacency: Array) -> void:
	edges.append([mini(a, b), maxi(a, b)])
	adjacency[a].append(b)
	adjacency[b].append(a)

static func distance_map(adjacency: Array, start: int) -> Array[int]:
	return distances(adjacency, start)

static func distances(adjacency: Array, start: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(adjacency.size())
	result.fill(-1)
	result[start] = 0
	var queue: Array[int] = [start]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for next in adjacency[current]:
			if result[next] == -1:
				result[next] = result[current] + 1
				queue.append(next)
	return result
