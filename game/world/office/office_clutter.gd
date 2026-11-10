extends RefCounted
## What is left lying in the offices (spec_rediseno 5.2 and 7, area 4c, tramo
## B): the small things on the desks, tables, counters and filing cabinets,
## and «se fueron de golpe», half-abandonment and not ruin: chairs pushed
## back, turned aside or knocked over (chair_pose(), from office_props.chair())
## where what they sweep is free, a drawer left out, a cable over a desk or
## the floor, a phone off its hook, papers in heaps with a cause (by a fallen
## chair, out of a box knocked over) and at most one odd thing to a room (a
## chair facing away). Worse down the floor (planta 1 just left, planta 3 the
## worst) and with the room's neglect (room.kept). By vary(), with no
## collider (a chair keeps its upright one); nothing on a corridor's floor and
## no paper where the card goes (clear_of_route()): a dropped card is a paper
## on the floor too.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const MODELS := preload("res://game/world/office/office_models.gd")
const THINGS := preload("res://game/world/office/pieces/desk_things.gd")
const ROUTE_CLEAR := 2.0
## How far behind a chair it may end up, pushed back or fallen.
const SWEEP := 1.3
## Items whose chair stands among pieces of its own holder (office_suite's
## sideboard behind its exec chair): the sweep cannot see those, so it stays put.
const CROWDED := ["office_suite"]
## By how bad a room is (mess_of(), 0 to 4): how often a chair is knocked
## over, faces away (once to a room), is pushed aside; a filing cabinet has a
## drawer out; a desk has a cable; a phone is off its hook; a box is spilled.
const FALLEN := [0.0, 0.04, 0.1, 0.16, 0.24]
const ODD := [0.0, 0.04, 0.08, 0.12, 0.16]
const ASIDE := [0.15, 0.3, 0.45, 0.55, 0.65]
const OPEN_DRAWER := [0.05, 0.12, 0.2, 0.3, 0.4]
const CABLE := [0.1, 0.25, 0.4, 0.5, 0.6]
const OFF_HOOK := [0.0, 0.1, 0.2, 0.3, 0.4]
const SPILL := [0.0, 0.1, 0.2, 0.3, 0.4]
## A meeting table's top, from its board's middle (dress() shifts it to the
## board at table_z): two stacks of papers, the jug and the ashtray.
const MEETING_TOP := [["paper_stack", Vector3(-0.75, 0.75, -0.15), 0.0, 0.9], ["paper_stack", Vector3(-0.35, 0.75, 0.2), 0.4, 0.5], ["jug", Vector3(0.3, 0.75, -0.05), 0.0, 0.8], ["ashtray", Vector3(0.6, 0.75, 0.2), 0.0, 0.5]]
## What stands on each kind of furniture's top, in its holder's frame
## (office_props.build_item()): [thing (office_models.gd), where, yaw, how
## often]; clear of each other and of the lamps.
const TOPS := {
	"office_suite": [["phone", Vector3(0.55, 0.75, 0.05), PI, 0.9], ["tray", Vector3(0.15, 0.75, 0.3), PI, 0.7], ["folders", Vector3(-0.05, 0.75, -0.1), 0.2, 0.7], ["mug", Vector3(0.35, 0.75, -0.15), 0.0, 0.5], ["pen_cup", Vector3(0.7, 0.75, 0.35), 0.0, 0.6], ["paper_stack", Vector3(-0.25, 0.75, 0.3), 2.9, 0.5]],
	"exec_desk": [["phone", Vector3(0.7, 0.76, -0.05), PI, 0.9], ["tray", Vector3(0.35, 0.76, 0.22), PI, 0.7], ["pen_cup", Vector3(0.0, 0.76, 0.3), 0.0, 0.7], ["folders", Vector3(-0.2, 0.76, -0.12), 0.3, 0.6], ["ashtray", Vector3(0.65, 0.76, 0.3), 0.0, 0.5], ["paper_stack", Vector3(-0.4, 0.76, 0.25), 3.0, 0.5]],
	"secretary_desk": [["typewriter", Vector3(-0.1, 0.75, -0.75), 0.0, 0.9], ["phone", Vector3(0.6, 0.75, -0.1), 0.0, 0.9], ["tray", Vector3(0.35, 0.75, -0.9), 0.0, 0.7], ["folders", Vector3(0.6, 0.75, 0.25), 0.4, 0.6], ["mug", Vector3(-0.45, 0.75, -0.55), 0.0, 0.5]],
	"air_desk": [["paper_stack", Vector3(0.1, 0.75, -0.4), 0.2, 0.9], ["register", Vector3(-0.4, 0.75, -0.35), 0.1, 0.6]],
	"work_desk": [["phone", Vector3(0.45, 0.75, -0.4), 0.0, 0.9], ["register", Vector3(-0.05, 0.75, -0.35), 0.1, 0.8], ["mug", Vector3(0.6, 0.75, -0.08), 0.0, 0.5]],
	"reception_counter_l": [["phone", Vector3(-0.4, 0.74, 0.6), PI, 0.9], ["tray", Vector3(0.2, 0.74, 0.7), PI, 0.8], ["folders", Vector3(-0.8, 0.74, 0.6), 0.2, 0.6], ["plant_small", Vector3(-0.9, 1.1, 0.92), 0.0, 0.9]],
	"reader_table": [["paper_stack", Vector3(0.45, 0.74, -0.25), 0.3, 0.7]],
	"work_table": [["paper_stack", Vector3(-0.6, 0.74, 0.1), 0.2, 0.9], ["paper_stack", Vector3(0.1, 0.74, -0.2), 1.7, 0.7], ["tray_wire", Vector3(0.55, 0.74, 0.2), 0.0, 0.8], ["pen_cup", Vector3(-0.1, 0.74, 0.3), 0.0, 0.7], ["archive_box", Vector3(-0.5, 0.0, 0.0), 0.1, 0.8], ["archive_box", Vector3(0.4, 0.0, -0.1), -0.2, 0.6]],
	"dining_set": [["mug", Vector3(-0.25, 0.74, -0.15), 0.0, 0.7], ["mug", Vector3(0.3, 0.74, 0.2), 1.0, 0.5], ["ashtray", Vector3(0.0, 0.74, 0.0), 0.0, 0.6], ["paper_stack", Vector3(0.3, 0.74, -0.2), 0.4, 0.4]],
	"sideboard": [["books", Vector3(-0.5, 0.8, 0.0), 0.0, 0.8], ["plant_small", Vector3(0.6, 0.8, 0.0), 0.0, 0.6]],
	"sorting_table": [["box", Vector3(-0.5, 1.02, 0.05), 0.2, 0.8], ["paper_stack", Vector3(0.4, 1.02, 0.1), 0.5, 0.8]],
	"pigeon_counter": [["paper_stack", Vector3(-0.6, 1.1, 0.0), 0.0, 0.6], ["box", Vector3(0.5, 1.1, 0.0), 0.3, 0.6]],
	"filing": [["folders", Vector3(0.0, 1.32, 0.0), 0.2, 0.4]],
	"meeting_table_s": MEETING_TOP,
	"meeting_table_m": MEETING_TOP,
	"meeting_table_l": MEETING_TOP,
}
## The same on the corner pieces' tops (room.props), clear of where the
## papers go (document_placement: ±0.2 across, -0.2 to 0.1 deep, at 0.84).
const CORNER_TOPS := {
	"desk": [["phone", Vector3(0.55, 0.84, -0.45), 0.0, 0.7], ["tray", Vector3(-0.55, 0.84, -0.45), 0.0, 0.6], ["mug", Vector3(0.6, 0.84, 0.05), 0.0, 0.4]],
	"table": [["ashtray", Vector3(0.6, 0.84, -0.45), 0.0, 0.5], ["paper_stack", Vector3(-0.6, 0.84, -0.4), 0.3, 0.5]],
}
## On a desk of the lattice, from its middle, its sitter at +Z (turned for a
## desk facing -Z): [thing, where, how often]; the keyboard goes with the screen.
const DESK_THINGS := [["crt", Vector3(0.3, 0.76, -0.15), 0.6], ["keyboard", Vector3(0.3, 0.76, 0.2), 0.6], ["phone", Vector3(-0.42, 0.76, 0.12), 0.6], ["tray", Vector3(-0.62, 0.76, -0.18), 0.5], ["mug", Vector3(0.65, 0.76, 0.22), 0.4], ["folders", Vector3(-0.12, 0.76, 0.15), 0.5]]
## A filing cabinet (pieces/cabinets.gd filing_cabinet(), 0.47 × 1.32 × 0.62,
## four drawers): a drawer's pitch, and the drawer pulled out and where it stands.
const DRAWER_PITCH := 0.3125
const DRAWER_OUT := Vector3(0.42, 0.27, 0.36)
const DRAWER_Z := 0.4

## How bad a room is, 0 to 4: its planta and its neglect.
static func mess_of(room: Dictionary) -> int:
	return clampi(int(room.get("wing", 0)) + int(room.get("kept", 0)), 0, 4)

## The room's leavings (office_geometry.extras(), after its furniture).
static func dress(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var t := int(room.type)
	if t == OFFICE.CORRIDOR or t == OFFICE.GALLERY or t == OFFICE.WINDOW or t == OFFICE.SECURITY: return
	var mess := mess_of(room)
	var items: Array = room.get("furniture", [])
	for k in items.size():
		var item: Dictionary = items[k]
		var holder := node.get_node_or_null("Furniture_%d" % k) as Node3D
		if holder == null: continue
		var kind := String(item.kind)
		var seed_pos: Vector3 = node.position + holder.position
		if kind == "desk":
			desk_things(builder, node, holder, room, Vector3(0, 0, -float(item.size[1]) * 0.5 + 0.375), 1.0, seed_pos, mess)
		elif kind == "desk_pair":
			desk_things(builder, node, holder, room, Vector3(0, 0, -0.375), -1.0, seed_pos, mess)
			desk_things(builder, node, holder, room, Vector3(0, 0, 0.375), 1.0, seed_pos + Vector3(0.5, 0, 0), mess)
		# A meeting table's tops sit on its board (table_z, office_props.build_item()).
		var shift: Vector3 = Vector3(0, 0, -float(item.size[1]) * 0.5 + 0.6) if kind.begins_with("meeting_table") else Vector3.ZERO
		for thing: Array in TOPS.get(kind, []):
			var at: Vector3 = (thing[1] as Vector3) + shift
			var yaw: float = float(thing[2]) + (builder.vary(seed_pos + at, 410) - 0.5) * 0.3
			lay(builder, node, holder, room, String(thing[0]), Transform3D(Basis(Vector3.UP, yaw), at), float(thing[3]), seed_pos + at)
		if kind == "filing": drawer(builder, node, holder, room, mess, seed_pos)
		if kind in ["office_suite", "exec_desk", "secretary_desk", "work_desk"] and builder.vary(seed_pos, 420) < float(CABLE[mess]):
			lay(builder, node, holder, room, "cable", Transform3D(Basis(Vector3.UP, builder.vary(seed_pos, 421) * TAU), Vector3(0.1, 0, 0)), 1.0, seed_pos + Vector3(0, 1, 0))
	if room.has("sockets"):
		for prop in room.get("props", []):
			var spots: Array = CORNER_TOPS.get(String(prop.kind), [])
			if spots.is_empty(): continue
			var socket: Transform3D = builder.prop_transform(room, prop, builder.palette)
			for thing: Array in spots:
				var at: Vector3 = thing[1]
				lay(builder, node, node, room, String(thing[0]), socket * Transform3D(Basis(Vector3.UP, float(thing[2])), at), float(thing[3]), node.position + socket * at)
	if mess >= 2 and builder.vary(node.position, 430) < float(SPILL[mess]): spill(builder, node, room)

## One thing at `xform` in `holder`, `often` of the time by vary(); noted (in
## the world, `node` its room's node).
static func lay(builder: Node3D, node: Node3D, holder: Node3D, room: Dictionary, kind: String, xform: Transform3D, often: float, seed_pos: Vector3) -> void:
	if builder.vary(seed_pos, 440) >= often: return
	MODELS.put(builder, holder, kind, xform)
	var local: Vector3 = xform.origin if holder == node else holder.transform * xform.origin
	note(builder, room, kind, node.position + local, xform.origin.y < 0.05, false)

## A desk of the lattice: its screen and keyboard (or neither), phone, tray,
## mug and folders, and now and then a cable across it.
static func desk_things(builder: Node3D, node: Node3D, holder: Node3D, room: Dictionary, centre: Vector3, face: float, seed_pos: Vector3, mess: int) -> void:
	var turn := Basis(Vector3.UP, 0.0 if face > 0.0 else PI)
	var screen: bool = builder.vary(seed_pos, 450) < 0.6
	for thing: Array in DESK_THINGS:
		var kind := String(thing[0])
		if (kind == "crt" or kind == "keyboard") and not screen: continue
		if kind == "phone" and builder.vary(seed_pos, 451) < float(OFF_HOOK[mess]): kind = "phone_off"
		var spot: Vector3 = thing[1]
		var often: float = 1.0 if kind == "crt" or kind == "keyboard" else float(thing[2])
		lay(builder, node, holder, room, kind, Transform3D(turn, centre + turn * spot), often, seed_pos + spot)
	if builder.vary(seed_pos, 452) < float(CABLE[mess]):
		lay(builder, node, holder, room, "cable", Transform3D(turn * Basis(Vector3.UP, builder.vary(seed_pos, 453) * 0.6 - 0.3), centre + turn * Vector3(0, 0.76, -0.1)), 1.0, seed_pos + Vector3(0, 2, 0))

## A filing cabinet with one of its two middle drawers pulled out, now and
## then; noted either way (the test weighs drawers out against cabinets).
static func drawer(builder: Node3D, node: Node3D, holder: Node3D, room: Dictionary, mess: int, seed_pos: Vector3) -> void:
	if builder.vary(seed_pos, 460) >= float(OPEN_DRAWER[mess]):
		note(builder, room, "filing_shut", node.position + holder.position, false, false)
		return
	var row := 1 + int(builder.vary(seed_pos, 461) * 2.0)
	var t := int(room.type)
	var key: String = OFFICE.FILING_FINISH.get(t, "steel_olive")
	var at := Vector3(0, 0.04 + DRAWER_PITCH * row + 0.02, DRAWER_Z)
	builder.place(holder, THINGS.drawer_out(builder, DRAWER_OUT, key), Transform3D(Basis.IDENTITY, at))
	note(builder, room, "drawer", node.position + holder.transform * at, false, false)

## A box knocked over with its papers out of it (spec_rediseno 7), at the
## first of the room's quarter points that nothing takes and whose papers
## the route leaves alone.
static func spill(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var zones: Array = zones_of(builder, room).duplicate()
	for item in room.get("furniture", []): zones.append({"rect": LAYOUT.footprint(item).grow(0.3)})
	var span := FLOOR.size_of(room)
	var lift: float = MODELS.size_of(builder, "box").z * 0.5
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]:
		var p := corner * (span * 0.5 - Vector2(1.6, 1.6))
		if LAYOUT.blocked(Rect2(p - Vector2(0.7, 0.7), Vector2(1.4, 1.4)), zones): continue
		var world := node.position + Vector3(p.x, 0, p.y)
		var turn := Basis(Vector3.UP, builder.vary(world, 480) * TAU)
		var papers := world + turn * Vector3(0, 0, 0.6)
		if not clear_of_route(builder, room, papers): continue
		MODELS.put(builder, node, "box", Transform3D(turn * Basis(Vector3.RIGHT, PI / 2), Vector3(p.x, lift, p.y)))
		builder.place(node, MODELS.mesh_of(builder, "paper_scatter"), Transform3D(turn, Vector3(p.x, 0, p.y) + turn * Vector3(0, 0, 0.6)))
		note(builder, room, "spill", papers, true, true)
		return

## How a chair is left (office_props.chair(), its face and yaw): as put, pushed back and turned
## aside, knocked over on its back with papers by it where they may lie, or,
## once in a room, turned to face away; by vary() of where it stands. Pushed
## back, fallen or turned only where what it sweeps is free (swept_clear()). Noted
## each one (chair_upright, chair_aside, chair_fallen, chair_odd).
static func chair_pose(builder: Node3D, holder: Node3D, at: Vector3, face: float, kind: String, yaw := 0.0) -> Transform3D:
	var turn := Basis(Vector3.UP, (0.0 if face > 0.0 else PI) + yaw)
	var upright := Transform3D(turn, at)
	var room: Dictionary = builder.building_room
	var parent := holder.get_parent() as Node3D
	if room.is_empty() or parent == null: return upright
	var t := int(room.type)
	if t == OFFICE.WINDOW or t == OFFICE.SECURITY: return upright
	var spot: Vector3 = parent.position + holder.transform * at
	var mess := mess_of(room)
	var roll: float = builder.vary(spot, 470)
	var fallen := float(FALLEN[mess])
	var odd := fallen + float(ODD[mess])
	var aside := odd + float(ASIDE[mess])
	var pose := "upright"
	if roll < fallen: pose = "fallen"
	elif roll < odd and not odd_in(builder, room): pose = "odd"
	elif roll < aside: pose = "aside"
	if pose != "upright" and not swept_clear(builder, room, holder, at, turn): pose = "upright"
	match pose:
		"fallen":
			var size := MODELS.size_of(builder, kind)
			note(builder, room, "chair_fallen", spot, true, false)
			var papers := at + turn * Vector3(0.45, 0, -0.55)
			var world: Vector3 = parent.position + holder.transform * papers
			var local := in_room(holder, room, papers)
			if clear_of_route(builder, room, world) and LAYOUT.inner(room).has_point(Vector2(local.x, local.z)):
				builder.place(holder, MODELS.mesh_of(builder, "paper_scatter"), Transform3D(Basis(Vector3.UP, builder.vary(spot, 472) * TAU), papers))
				note(builder, room, "paper_scatter", world, true, true)
			return Transform3D(turn * Basis(Vector3.UP, (builder.vary(spot, 471) - 0.5) * 0.8) * Basis(Vector3.RIGHT, -PI / 2), at + turn * Vector3(0, size.z * 0.5, -0.35))
		"odd":
			note(builder, room, "chair_odd", spot, false, false, true)
			# Backed off the desk as it turns, so its back stays clear of it.
			return Transform3D(turn * Basis(Vector3.UP, PI), at + turn * Vector3(0, 0, -0.35))
		"aside":
			note(builder, room, "chair_aside", spot, false, false)
			return Transform3D(turn * Basis(Vector3.UP, (builder.vary(spot, 473) - 0.5) * 1.2), at + turn * Vector3((builder.vary(spot, 474) - 0.5) * 0.3, 0, -0.25))
	note(builder, room, "chair_upright", spot, false, false)
	return upright

## Whether a chair may be pushed back, knocked over or turned: the plan it
## sweeps, from where it stands to SWEEP behind it, stays on the room's inner
## floor and touches no other furniture, the room's rect zones (doors, lockers,
## corner pieces, systems, the lift), nor the pieces of a CROWDED item.
## The walking lanes may be crossed: its collider stays where it stood.
static func swept_clear(builder: Node3D, room: Dictionary, holder: Node3D, at: Vector3, turn: Basis) -> bool:
	var p: Vector3 = in_room(holder, room, at)
	var q: Vector3 = in_room(holder, room, at + turn * Vector3(0, 0, -SWEEP))
	var rect := Rect2(Vector2(p.x, p.z), Vector2.ZERO).expand(Vector2(q.x, q.z)).grow(0.3)
	if not LAYOUT.inner(room).encloses(rect): return false
	var zones: Array = zones_of(builder, room).filter(func(z: Dictionary) -> bool: return z.has("rect"))
	var items: Array = room.get("furniture", [])
	for k in items.size():
		var item: Dictionary = items[k]
		if String(holder.name) == "Furniture_%d" % k:
			if String(item.kind) in CROWDED: return false
			continue
		zones.append({"rect": LAYOUT.footprint(item)})
	return not LAYOUT.blocked(rect, zones)

## A point of a chair's holder frame in its room's own frame (the one the
## furniture and LAYOUT.inner() use): the world point clear_of_route() reads,
## less the room's centre. A holder is a child of the room node (a furniture
## item or a corner prop) or the room node itself.
static func in_room(holder: Node3D, room: Dictionary, at: Vector3) -> Vector3:
	var parent := holder.get_parent() as Node3D
	return parent.position + holder.transform * at - FLOOR.position_of(room)

## The room's clear zones (LAYOUT.clear_zones()), worked out once per room and
## manifest.
static func zones_of(builder: Node3D, room: Dictionary) -> Array:
	var manifest: Dictionary = builder.manifest
	var held: Dictionary = builder.get_meta("clutter_zones", {})
	if held.is_empty() or not is_same(held.manifest, manifest):
		held = {"manifest": manifest, "rooms": {}}
		builder.set_meta("clutter_zones", held)
	var cache: Dictionary = held.rooms
	if not cache.has(int(room.id)): cache[int(room.id)] = LAYOUT.clear_zones(manifest, room, false)
	return cache[int(room.id)]

## Notes a leaving for the dressing test (builder.dressing_log.clutter).
static func note(builder: Node3D, room: Dictionary, kind: String, world: Vector3, on_floor: bool, paper: bool, odd := false) -> void:
	builder.dressing_log.clutter.append({"room": int(room.id), "kind": kind, "at": world, "floor": on_floor, "paper": paper, "odd": odd})

## Whether the room has had its odd thing already.
static func odd_in(builder: Node3D, room: Dictionary) -> bool:
	return builder.dressing_log.clutter.any(func(e: Dictionary) -> bool: return int(e.room) == int(room.id) and bool(e.odd))

## Whether a paper may lie at a world point of a room: never in the rooms the
## card goes through for certain (circulation, corridors, the refuge, the
## window and route_rooms()), nor within ROUTE_CLEAR of a doorway, of an open
## side (all its length) or of the straight way between two of them.
static func clear_of_route(builder: Node3D, room: Dictionary, world: Vector3) -> bool:
	var t := int(room.type)
	if t in OFFICE.CIRCULATION or t == OFFICE.CORRIDOR or t == OFFICE.REFUGE or t == OFFICE.WINDOW: return false
	if route_rooms(builder).has(int(room.id)): return false
	var centre := FLOOR.position_of(room)
	var local := Vector2(world.x - centre.x, world.z - centre.z)
	var span := FLOOR.size_of(room)
	var ways: Array = []
	for way in FLOOR.doorways(room):
		var wall := String(way.wall)
		ways.append(Vector2(LAYOUT.face(room, wall), float(way.along)) if wall == "west" or wall == "east" else Vector2(float(way.along), LAYOUT.face(room, wall)))
	for side in room.get("open_sides", []):
		var wall := String(side)
		var across := wall == "west" or wall == "east"
		var a: Vector2 = Vector2(LAYOUT.face(room, wall), -span.y * 0.5) if across else Vector2(-span.x * 0.5, LAYOUT.face(room, wall))
		var b: Vector2 = Vector2(LAYOUT.face(room, wall), span.y * 0.5) if across else Vector2(span.x * 0.5, LAYOUT.face(room, wall))
		if Geometry2D.get_closest_point_to_segment(local, a, b).distance_to(local) < ROUTE_CLEAR: return false
		ways.append((a + b) * 0.5)
	for i in ways.size():
		var a: Vector2 = ways[i]
		if local.distance_to(a) < ROUTE_CLEAR: return false
		for j in range(i + 1, ways.size()):
			var b: Vector2 = ways[j]
			if Geometry2D.get_closest_point_to_segment(local, a, b).distance_to(local) < ROUTE_CLEAR: return false
	return true

## The rooms the card is in for certain: the window's, every station's and
## the reader's (the mail's and the tubes' spots) and every cell of the same
## nave as one of them (room.hall), cached per manifest.
static func route_rooms(builder: Node3D) -> Dictionary:
	var manifest: Dictionary = builder.manifest
	if builder.has_meta("clutter_route"):
		var cached: Dictionary = builder.get_meta("clutter_route")
		if is_same(cached.manifest, manifest): return cached.rooms
	var out := {}
	var mail: Dictionary = manifest.get("mail", {})
	if mail.has("window"): out[int(mail.window)] = true
	var spots: Array = []
	LAYOUT.gather(mail, spots)
	for exit in manifest.get("tubes", {}).get("exits", []):
		if exit is Dictionary and exit.has("point"): spots.append(exit)
	var rooms: Array = manifest.get("rooms", [])
	for spot: Dictionary in spots:
		var point: Array = spot.point
		var here := FLOOR.room_at(rooms, Vector3(float(point[0]), float(point[1]), float(point[2])))
		if not here.is_empty(): out[int(here.id)] = true
	var halls := {}
	for room in rooms:
		if out.has(int(room.id)) and int(room.get("hall", -1)) >= 0: halls[int(room.hall)] = true
	for room in rooms:
		if halls.has(int(room.get("hall", -1))): out[int(room.id)] = true
	builder.set_meta("clutter_route", {"manifest": manifest, "rooms": out})
	return out
