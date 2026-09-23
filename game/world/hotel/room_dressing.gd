extends RefCounted
## A room's dressing (docs/REALISM.md, phase 4): furniture along the free
## stretches of its walls, things on tops and shelves, clutter and decals as
## worn as the room is kept. Everything comes from vary() on positions, never
## from the generator's random sequence, so every machine builds the same room.
##
## The corner sockets (prop_factory.gd) and the central cross stay as they
## were: a stretch runs along a wall from past the doorway (the leaf never
## swings beyond its hinge) to before the corner socket, and none is used
## where a wardrobe stands. Big pieces get a box collider in the stretch's
## frame; nothing under about 30 cm collides. Models are baked by
## tools/props/build_catalogue.gd into assets/props/hotel/.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HOTEL := "res://assets/props/hotel/%s.res"
const MONSTERA := preload("res://assets/props/monstera/monstera.res")
## Modules with the domestic alcoves (hotel_geometry.build_room()).
const DOMESTIC := [1, 2, 3, 4, 7, 15, 16]
## From the wall's centre line to the back of a piece (half core, panels and
## rails).
const INSET := 0.2
## Where the plaster is in a stretch's frame, above the chair rail: for what
## hangs on the wall.
const WALL_FACE := -0.11
## Along a wall, from its middle: past the doorway, before the corner socket
## (or an alcove's partition).
const NEAR := 1.35
const FAR := 3.05
const FAR_DOMESTIC := 2.6
## What each module puts along its walls; one entry per stretch, picked by
## position. "" leaves a stretch bare.
const SETS := {
	"bedroom": ["commode", "armchair", "chair", "luggage", "", "commode"],
	"lounge": ["console", "armchair", "commode", "plant", "bookcase", "armchair", ""],
	"reading": ["bookcase", "bookcase", "armchair", "console", ""],
	"dining": ["console", "chairs", "cabinet", "chairs", ""],
	"service": ["steel", "rack", "boxes", "bins", "steel", ""],
	"laundry": ["rack", "baskets", "boxes", "bins", ""],
	"office": ["drawers", "steel", "chairs", "boxes", ""],
	"bath": ["bins", "", "chairs"],
	"corridor": ["console", "chairs", "bins", "plant", "armchair", ""],
	"passage": ["console", "bins", "plant", "", ""],
	"garden": ["plant", "plant", "armchair", ""],
	"empty": ["boxes", "chairs", "cabinet", "", ""],
	"wardrobe": ["luggage", "rack", "luggage", ""],
}
const MODULE_SET := {0: "lounge", 1: "bedroom", 2: "bedroom", 3: "bedroom", 4: "bath", 5: "lounge", 6: "dining", 7: "laundry", 8: "service", 9: "service", 10: "lounge", 11: "corridor", 12: "corridor", 13: "reading", 14: "lounge", 15: "office", 16: "wardrobe", 17: "garden", 18: "empty"}
## Small things by what a top or shelf holds.
const ORNAMENTS := ["ceramic_vase_01", "brass_vase_02", "jug_01", "book_encyclopedia_set_01", "wall_clock_standing"]
const DESK_THINGS := ["office_notepads_pad", "stationery_supplies", "clipboard", "cigarette_pack", "alarm_clock_01"]
const STORE_THINGS := ["cardboard_box_01", "plastic_crate_02", "bleach_bottle", "multi_cleaner_bottle", "wicker_basket_02", "cardboard_box_01"]
const BOTTLES := ["wine_bottles_01_bordeaux", "wine_bottles_01_alsace", "wine_bottles_01_burgundy", "wine_bottles_01_champagne"]
## Kept (0), neglected (1) or abandoned (2), by share of rooms.
const STATE_SHARES := [0.5, 0.85]

static var meshes := {}
static var levels := {}

static func mesh(name: String) -> Mesh:
	if not meshes.has(name): meshes[name] = MONSTERA if name == "monstera" else load(HOTEL % name)
	return meshes[name]

## How kept a room is: 0 kept, 1 neglected, 2 abandoned. The empty lounge is
## never better than neglected.
static func state(builder, room: Dictionary) -> int:
	var v: float = builder.vary(FLOOR.position_of(room), 21)
	var result := 0 if v < STATE_SHARES[0] else 1 if v < STATE_SHARES[1] else 2
	return maxi(result, 1) if int(room.type) == 18 else result

## The heights a model's things can stand on: its flat tops and shelves, the
## upward faces over the middle of its footprint, lowest first.
static func shelves(name: String) -> Array:
	if levels.has(name): return levels[name]
	var model := mesh(name)
	var box := model.get_aabb()
	var bins := {}
	for surface in model.get_surface_count():
		var arrays := model.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var a := vertices[indices[t]]
			var b := vertices[indices[t + 1]]
			var c := vertices[indices[t + 2]]
			var cross := (b - a).cross(c - a)
			if cross.length() < 1e-9 or cross.normalized().y < 0.97: continue
			var middle := (a + b + c) / 3.0
			if absf(middle.x - box.get_center().x) > box.size.x * 0.35 or absf(middle.z - box.get_center().z) > box.size.z * 0.35: continue
			var key := int(round(middle.y / 0.02))
			bins[key] = bins.get(key, 0.0) + cross.length() * 0.5
	var footprint := box.size.x * box.size.z
	var result := []
	var keys := bins.keys()
	keys.sort()
	for key in keys:
		if bins[key] < footprint * 0.1 or key * 0.02 < 0.03: continue
		if not result.is_empty() and key * 0.02 - result[-1] < 0.12:
			result[-1] = key * 0.02
			continue
		result.append(key * 0.02)
	levels[name] = result
	return result

## The free stretches of a room's walls: [frame (room space; origin on the
## floor against the wall, +Z into the room, +X along it), width]. Each wall
## is [side, inward, how far it is across the room, how long it is]; a wall
## too short for a stretch either side of its doorway -- the end of a
## corridor -- has none.
static func stretches(room: Dictionary) -> Array:
	var span := FLOOR.size_of(room)
	var far := FAR_DOMESTIC if int(room.type) in DOMESTIC else FAR
	var open: Array = room.get("open_sides", [])
	var hides: Array = [] if int(room.type) == 19 else FLOOR.hiding_positions(room)
	var result := []
	for wall in walls(span):
		if open.has(wall[0]) or float(wall[3]) < far * 2.0 + 1.0: continue
		var inward: Vector3 = wall[1]
		var along := Vector3.UP.cross(inward)
		for side in [-1, 1]:
			var middle: float = side * (NEAR + far) * 0.5
			var taken := false
			for spot: Vector3 in hides:
				# A wardrobe on this wall, on this side of its doorway.
				if spot.normalized().dot(-inward) > 0.7 and signf(spot.dot(along)) == signf(middle): taken = true
			if taken: continue
			var origin: Vector3 = -inward * (wall[2] * 0.5 - INSET) + along * middle
			result.append([Transform3D(Basis(along, Vector3.UP, inward), origin), far - NEAR])
	return result

## A room's four walls: [side, inward, distance across, length].
static func walls(span: Vector2) -> Array:
	return [["west", Vector3(1, 0, 0), span.x, span.y], ["east", Vector3(-1, 0, 0), span.x, span.y], ["north", Vector3(0, 0, 1), span.y, span.x], ["south", Vector3(0, 0, -1), span.y, span.x]]

## Dresses a room (called by hotel_geometry.build_room(), after its sockets).
## The pieces you can go through: drawers, shelves and cupboards.
const CONTAINERS := ["commode", "console", "drawers", "bookcase", "cabinet", "boxes"]

static func dress(builder, node: Node3D, room: Dictionary) -> void:
	# Neither the refuge nor the lift lobby is furnished: one is bare by
	# design and the other has nothing in it but the car.
	if int(room.type) == 19 or bool(room.get("landing", false)): return
	var kept := state(builder, room)
	var set_name: String = MODULE_SET.get(int(room.type), "")
	# A corridor of three or four metres keeps to what stands flat against a
	# wall: an armchair and its table would half close it.
	if set_name == "corridor" and minf(FLOOR.size_of(room).x, FLOOR.size_of(room).y) < 5.0: set_name = "passage"
	var sets: Array = SETS.get(set_name, [])
	var k := 0
	for stretch in stretches(room):
		var frame: Transform3D = stretch[0]
		var holder := Node3D.new()
		holder.name = "Stretch_%d" % k
		holder.transform = frame
		node.add_child(holder)
		var seed_pos: Vector3 = node.position + frame.origin
		var pick: String = sets[int(builder.vary(seed_pos, 31) * sets.size())] if not sets.is_empty() else ""
		builder.piece_front = 0.0
		furnish(builder, holder, pick, stretch[1], seed_pos, kept, room)
		# Anything with drawers or shelves is somewhere a number could be
		# hidden: the builder keeps the list so a floor can put four in them.
		# With how far its front reaches: the note shows out of it and the
		# hand finds it there, whatever the piece's depth.
		if pick in CONTAINERS: builder.containers.append({"room": int(room.id), "position": node.position + frame.origin, "yaw": frame.basis.get_euler().y, "kind": pick, "front": builder.piece_front})
		k += 1
	decals(builder, node, room, kept)

## One stretch: a piece (or a group) of the set, its things, and on a bare
## stretch the clutter a neglected room leaves.
static func furnish(builder, holder: Node3D, pick: String, width: float, seed_pos: Vector3, kept: int, room: Dictionary) -> void:
	var v := func(salt: int) -> float: return builder.vary(seed_pos, salt)
	match pick:
		"commode":
			var s := minf(1.0, width / 1.25)
			put(builder, holder, "GothicCommode_01", Vector3(0, 0, 0.3 * s), 0.0, s, true)
			dress_top(builder, holder, "GothicCommode_01", Vector3(0, 0, 0.3 * s), s, ORNAMENTS, seed_pos, 2)
			hang_mirror(builder, holder, room, 1.62, seed_pos)
		"console":
			var s := minf(0.85, width / 1.6)
			put(builder, holder, "ClassicConsole_01", Vector3(0, 0, 0.3 * s), 0.0, s, true)
			dress_top(builder, holder, "ClassicConsole_01", Vector3(0, 0, 0.3 * s), s, ORNAMENTS, seed_pos, 2)
			hang_mirror(builder, holder, room, 1.45, seed_pos)
		"armchair":
			var chair: String = "ArmChair_01" if v.call(32) < 0.5 else "GreenChair_01"
			put(builder, holder, chair, Vector3(-0.22, 0, 0.45), v.call(33) * 0.4 - 0.2, 1.0, true)
			put(builder, holder, "side_table_tall_01", Vector3(0.45, 0, 0.25), 0.0, 1.0, true)
			dress_top(builder, holder, "side_table_tall_01", Vector3(0.45, 0, 0.25), 1.0, ["ceramic_vase_01", "brass_vase_02", "cigarette_pack", "alarm_clock_01"], seed_pos, 1)
		"chair":
			put(builder, holder, "dining_chair_02", Vector3(-0.2, 0, 0.35), v.call(34) * 0.5 - 0.25, 1.0, true)
			if v.call(35) < 0.5: put(builder, holder, "side_table_tall_01", Vector3(0.35, 0, 0.22), 0.0, 1.0, true)
		"chairs":
			for x in [-0.28, 0.28]: put(builder, holder, "dining_chair_02", Vector3(x, 0, 0.32), v.call(36 + int(x * 10)) * 0.2 - 0.1, 1.0, true)
		"luggage":
			put(builder, holder, "vintage_suitcase_a", Vector3(-0.15, 0, 0.14), 0.05, 1.0, true)
			# The other lies flat beside it (on its back: it reaches into the room).
			place(builder, holder, "vintage_suitcase_b", Transform3D(Basis(Vector3.UP, v.call(37) * 0.6 - 0.3) * Basis(Vector3.RIGHT, PI / 2), Vector3(0.4, 0.12, 0.1)))
		"plant":
			put(builder, holder, "monstera", Vector3(0, 0, 0.35), v.call(38) * TAU, 1.0, false)
			builder.box(holder, Vector3(0, 0.27, 0.35), Vector3(0.5, 0.54, 0.5), "", true)
		"bookcase":
			var s := minf(0.9, width / 1.4)
			put(builder, holder, "wooden_bookshelf_worn", Vector3(0, 0, 0.3 * s), 0.0, s, true)
			fill_shelves(builder, holder, "wooden_bookshelf_worn", Vector3(0, 0, 0.3 * s), s, ["book_encyclopedia_set_01", "book_encyclopedia_set_01", "ceramic_vase_01", "cardboard_box_01"], seed_pos)
		"cabinet":
			put(builder, holder, "painted_wooden_cabinet" if kept >= 1 else "GothicCommode_01", Vector3(0, 0, 0.32), 0.0, minf(1.0, width / 1.25), true)
		"drawers":
			put(builder, holder, "drawer_cabinet", Vector3(0, 0, 0.26), 0.0, minf(1.0, width / 1.2), true)
		"steel", "rack":
			var name := "steel_frame_shelves_01" if pick == "steel" else "worn_metal_rack"
			put(builder, holder, name, Vector3(0, 0, 0.3), 0.0, 1.0, true)
			fill_shelves(builder, holder, name, Vector3(0, 0, 0.3), 1.0, STORE_THINGS, seed_pos)
		"boxes":
			stack(builder, holder, seed_pos, 3 + kept)
		"baskets":
			for x in [-0.3, 0.2]: put(builder, holder, "wicker_basket_02", Vector3(x, 0, 0.2), v.call(40 + int(x * 10)) * TAU, 1.3, false)
			put(builder, holder, "bleach_bottle", Vector3(0.5, 0, 0.1), v.call(42) * TAU, 1.0, false)
		"bins":
			put(builder, holder, "metal_trash_can_rust" if kept >= 1 else "metal_trash_can_clean", Vector3(-0.2, 0, 0.3), v.call(43) * TAU, 0.6, true)
			if v.call(44) < 0.5: put(builder, holder, "WetFloorSign_01", Vector3(0.4, 0, 0.35), v.call(45) * 0.8 - 0.4, 1.0, false)
		_:
			# A bare stretch: what a neglected room leaves lying about.
			if kept >= 1: litter(builder, holder, seed_pos, kept)
	# A clock on one wall in some rooms.
	if pick in ["", "chairs", "armchair", "chair"] and v.call(46) < 0.3:
		place(builder, holder, "wall_clock", Transform3D(Basis.IDENTITY, Vector3(0.2, 2.05, WALL_FACE + 0.025)))

## A model on the stretch's floor, turned by yaw and scaled by s; with a box
## collider round it when solid (turned only a little, so its box stays).
static func put(builder, holder: Node3D, name: String, pos: Vector3, yaw: float, s: float, solid: bool) -> void:
	place(builder, holder, name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos))
	if solid:
		var size := mesh(name).get_aabb().size * s
		builder.box(holder, pos + Vector3(0, size.y * 0.5, 0), size, "", true)
		builder.piece_front = maxf(builder.piece_front, pos.z + size.z * 0.5)

static func place(builder, holder: Node3D, name: String, xform: Transform3D, casts := true) -> void:
	builder.place(holder, mesh(name), xform, casts)

## Things on a piece's top: count of them, from choices, spaced along it.
static func dress_top(builder, holder: Node3D, base: String, at: Vector3, s: float, choices: Array, seed_pos: Vector3, count: int) -> void:
	var tops := shelves(base)
	if tops.is_empty(): return
	var box := mesh(base).get_aabb()
	var top: float = tops[-1] * s
	var usable := box.size.x * s * 0.8
	for i in count:
		var slot := (i + 0.5) / count - 0.5
		var name: String = choices[int(builder.vary(seed_pos, 50 + i) * choices.size())]
		var yaw: float = builder.vary(seed_pos, 55 + i) * 0.8 - 0.4
		if name == "wall_clock_standing": name = "alarm_clock_01"
		place(builder, holder, name, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(slot * usable, top, box.get_center().z * s - 0.02)), false)

## Every shelf of a piece, a few things each, some gaps.
static func fill_shelves(builder, holder: Node3D, base: String, at: Vector3, s: float, choices: Array, seed_pos: Vector3) -> void:
	var box := mesh(base).get_aabb()
	var tops := shelves(base)
	for level in tops.size():
		var y: float = tops[level] * s
		var room_above: float = ((tops[level + 1] if level + 1 < tops.size() else box.size.y) - tops[level]) * s
		var x := -box.size.x * s * 0.42
		var i := 0
		while x < box.size.x * s * 0.4 and i < 5:
			var name: String = choices[int(builder.vary(seed_pos + Vector3(level, 0, i), 60) * choices.size())]
			var size := mesh(name).get_aabb().size
			var fit := minf(1.0, (room_above - 0.03) / maxf(size.y, 0.01))
			if builder.vary(seed_pos + Vector3(level, 0, i), 61) < 0.2 or fit < 0.45:
				x += 0.2
			else:
				place(builder, holder, name, Transform3D(Basis(Vector3.UP, builder.vary(seed_pos + Vector3(level, 0, i), 62) * 0.3 - 0.15).scaled(Vector3.ONE * fit), at + Vector3(x + size.x * fit * 0.5, y, box.get_center().z * s)), false)
				x += size.x * fit + 0.04
			i += 1

## A mirror above a piece, where no wall lamp hangs.
static func hang_mirror(builder, holder: Node3D, room: Dictionary, bottom: float, seed_pos: Vector3) -> void:
	if int(room.type) in [0, 10, 11, 12] or builder.vary(seed_pos, 47) < 0.4: return
	place(builder, holder, "ornate_mirror_01", Transform3D(Basis.IDENTITY, Vector3(0, bottom, WALL_FACE + 0.015)))

## Boxes and crates stacked against the wall.
static func stack(builder, holder: Node3D, seed_pos: Vector3, count: int) -> void:
	var x := -0.55
	var y := 0.0
	for i in count:
		var name: String = ["cardboard_box_01", "plastic_crate_02", "cardboard_box_01"][int(builder.vary(seed_pos, 70 + i) * 3)]
		var size := mesh(name).get_aabb().size
		var yaw: float = builder.vary(seed_pos, 75 + i) * 0.5 - 0.25
		place(builder, holder, name, Transform3D(Basis(Vector3.UP, yaw), Vector3(x + size.x * 0.5, y, size.z * 0.5 + 0.02)))
		if y == 0.0 and builder.vary(seed_pos, 80 + i) < 0.5:
			y = size.y
		else:
			x += size.x + 0.05
			y = 0.0
		if x > 0.5: break
	builder.box(holder, Vector3(0, 0.25, 0.28), Vector3(1.1, 0.5, 0.5), "", true)
	builder.piece_front = maxf(builder.piece_front, 0.53)

## What lies about in a neglected (1) or abandoned (2) room: a tipped chair,
## bottles, a suitcase, papers, boxes.
static func litter(builder, holder: Node3D, seed_pos: Vector3, kept: int) -> void:
	var things := 1 + kept * 2
	for i in things:
		var roll: float = builder.vary(seed_pos, 90 + i)
		var x: float = builder.vary(seed_pos, 95 + i) * 1.1 - 0.55
		var z: float = 0.15 + builder.vary(seed_pos, 100 + i) * 0.5
		var yaw: float = builder.vary(seed_pos, 105 + i) * TAU
		if roll < 0.2 and kept == 2:
			# A chair knocked over, on its back, reaching into the room.
			place(builder, holder, "dining_chair_02", Transform3D(Basis(Vector3.UP, yaw * 0.15 - 0.5) * Basis(Vector3.RIGHT, PI / 2), Vector3(x, 0.29, 0.1)))
		elif roll < 0.5:
			var bottle: String = BOTTLES[int(builder.vary(seed_pos, 110 + i) * BOTTLES.size())]
			# Most lie on their side.
			var lying: Basis = Basis(Vector3.FORWARD, PI / 2) if builder.vary(seed_pos, 115 + i) < 0.7 else Basis.IDENTITY
			place(builder, holder, bottle, Transform3D(Basis(Vector3.UP, yaw) * lying, Vector3(x, 0.04 if lying != Basis.IDENTITY else 0.0, z)))
		elif roll < 0.7:
			place(builder, holder, "office_notepads_a4", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.6), Vector3(x, 0.002, z)))
		elif roll < 0.85:
			place(builder, holder, "cardboard_box_01", Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0, z + 0.1)))
		else:
			place(builder, holder, "cigarette_pack", Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2), Vector3(x, 0.015, z)))

## Decals: damp under the ceiling and rising from the floor, fingerprints
## beside the doorways, stains, gum and footprints; more the worse a room is
## kept. All are made; the preset shows a share of them (hotel_geometry
## decal()). None in Compatibility.
static func decals(builder, node: Node3D, room: Dictionary, kept: int) -> void:
	if not builder.decals_drawn(): return
	var span := FLOOR.size_of(room)
	var height: float = room.height
	var open: Array = room.get("open_sides", [])
	var count: int = [4, 9, 16][kept]
	var base := node.position
	for i in count:
		var roll: float = builder.vary(base, 200 + i)
		var along: float = builder.vary(base, 220 + i) * 2.0 - 1.0
		var sides := []
		for wall in walls(span):
			if not open.has(wall[0]): sides.append(wall)
		if sides.is_empty() or roll < 0.3:
			# On the floor: stains, gum in public rooms, footprints where it is abandoned.
			var pick: String = ["SurfaceImperfections001", "SurfaceImperfections013", "SurfaceImperfections017"][int(builder.vary(base, 240 + i) * 3)]
			if kept == 2 and builder.vary(base, 245 + i) < 0.4: pick = "Footsteps003"
			elif int(room.type) in [0, 10, 11, 12] and builder.vary(base, 246 + i) < 0.3: pick = "ChewingGum001"
			var at: Vector3 = Vector3((builder.vary(base, 250 + i) - 0.5) * span.x * 0.8, 0.0, (builder.vary(base, 255 + i) - 0.5) * span.y * 0.8)
			var size: float = 1.6 if pick == "Footsteps003" else 1.2 + builder.vary(base, 260 + i) * 1.4
			builder.decal(node, pick, Transform3D(Basis(Vector3.UP, builder.vary(base, 265 + i) * TAU), at), Vector3(size, 0.3, size), 0.55 + kept * 0.15, float(i) / count)
			continue
		var wall: Array = sides[int(builder.vary(base, 270 + i) * sides.size())]
		var inward: Vector3 = wall[1]
		var along_axis := Vector3.UP.cross(inward)
		var surface: Vector3 = -inward * (float(wall[2]) * 0.5 - 0.16)
		# A decal projects along its -Y, into the wall; its image's top (-Z) up.
		var facing := Basis(along_axis, inward, along_axis.cross(inward))
		if roll < 0.55:
			var pick: String = ["Leaking001", "Leaking003", "Leaking005"][int(builder.vary(base, 280 + i) * 3)]
			var size: float = 1.4 + builder.vary(base, 285 + i) * 1.2
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * along * (float(wall[3]) * 0.42) + Vector3(0, height - size * 0.5, 0)), Vector3(size, 0.5, size), 0.5 + kept * 0.2, float(i) / count)
		elif roll < 0.7:
			var pick: String = ["Leaking008", "Leaking009"][int(builder.vary(base, 290 + i) * 2)]
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * along * (float(wall[3]) * 0.42) + Vector3(0, 0.55, 0)), Vector3(1.6, 0.5, 1.1), 0.45 + kept * 0.2, float(i) / count)
		elif roll < 0.85:
			# Beside a doorway, where hands push.
			var pick: String = "Fingerprints004" if kept == 2 and builder.vary(base, 295 + i) < 0.5 else "Fingerprints002"
			var side := 1.0 if along > 0.0 else -1.0
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * side * 1.0 + Vector3(0, 1.15, 0)), Vector3(0.5, 0.4, 0.5), 0.5 + kept * 0.15, float(i) / count)
		else:
			# Smears where there is tile or metal to smear.
			var stains := ["SurfaceImperfections001", "SurfaceImperfections013", "Smear003"] if int(room.type) in [4, 7, 8, 9] else ["SurfaceImperfections001", "SurfaceImperfections013"]
			var pick: String = stains[int(builder.vary(base, 300 + i) * stains.size())]
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * along * (float(wall[3]) * 0.42) + Vector3(0, 0.6 + builder.vary(base, 305 + i) * 1.4, 0)), Vector3(1.0, 0.4, 1.0), 0.3 + kept * 0.15, float(i) / count)
