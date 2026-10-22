extends RefCounted
## A room's dressing (docs/REALISM.md, phase 4): furniture along the free
## stretches of its walls, things on tops and shelves, clutter and decals as
## worn as the room is kept. How kept it is comes with the floor (`kept`);
## the rest from the builder's vary(), on positions and the floor's seed,
## never from the generator's random sequence, so every machine builds the
## same room.
##
## The corner sockets (prop_factory.gd) and the central cross stay as they
## were: a stretch runs along a wall between NEAR and FAR from its middle,
## and none is used within NEAR of a doorway in that wall (the leaf never
## swings beyond its hinge) or where a wardrobe stands. Big pieces get a box
## collider in the stretch's frame; nothing under about 30 cm collides.
## Models are baked by tools/props/build_catalogue.gd into assets/props/hotel/.
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
const ORNAMENTS := ["ceramic_vase_01", "brass_vase_02", "jug_01", "book_encyclopedia_set_01", "wall_clock_standing", "mantel_clock_01", "antique_ceramic_vase_01", "potted_plant_04"]
## What hangs on walls and from ceilings besides (October 2026): where a
## fire alarm's pull station is put, which rooms have a fuse box and which a
## ceiling fan, by module.
const ALARM_ROOMS := [0, 10, 11, 12]
const FUSE_ROOMS := [7, 8, 9, 15]
const FAN_ROOMS := [6, 13, 15]
## A long-case clock stands on a bare stretch of these, where no wall lamp
## hangs over it.
const CLOCK_ROOMS := [1, 2, 3, 5, 6, 13, 14]
const STORE_THINGS := ["cardboard_box_01", "plastic_crate_02", "bleach_bottle", "multi_cleaner_bottle", "wicker_basket_02", "cardboard_box_01"]
const BOTTLES := ["wine_bottles_01_bordeaux", "wine_bottles_01_alsace", "wine_bottles_01_burgundy", "wine_bottles_01_champagne"]
## Half a wardrobe's width, and a little (hiding_place.gd).
const WARDROBE_HALF := 0.75

static var meshes := {}
static var levels := {}
static var undersides := {}

static func mesh(name: String) -> Mesh:
	if not meshes.has(name): meshes[name] = MONSTERA if name == "monstera" else load(HOTEL % name)
	return meshes[name]

## How kept a room is: 0 kept, 1 neglected, 2 abandoned, as the floor says
## (map_generator.light_rooms(): with the room's order, give or take).
static func state(room: Dictionary) -> int:
	return int(room.get("kept", 0))

## The heights a model's things can stand on: its flat tops and shelves, the
## upward faces over the middle of its footprint, lowest first, each at the
## height the face really is (the mean of it, not a step of two centimetres).
static func shelves(name: String) -> Array:
	if not levels.has(name): levels[name] = flats(name, true)
	return levels[name]

## The undersides of those boards, the downward faces: what a thing stood on
## the shelf below has over it.
static func ceilings(name: String) -> Array:
	if not undersides.has(name): undersides[name] = flats(name, false)
	return undersides[name]

## How much room there is over a top of a model at `height`: up to the board
## over it, or to the top of the piece.
static func room_over(name: String, height: float) -> float:
	for under in ceilings(name):
		if under > height + 0.02: return under - height
	return maxf(0.0, mesh(name).get_aabb().end.y - height)

## The flat faces of a model over the middle of its footprint that look up
## (or down), as heights, lowest first; faces closer than 12 cm are one board,
## and the higher (the lower, looking down) is the one that counts. Godot
## winds a front face clockwise, so (b - a) x (c - a) points INTO the model:
## read the other way round, this used to take the underside of every board
## for its top, and whatever stood on a piece was sunk in it by the board's
## thickness.
static func flats(name: String, up: bool) -> Array:
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
			if cross.length() < 1e-9: continue
			var facing := -cross.normalized().y
			if (facing if up else -facing) < 0.97: continue
			var middle := (a + b + c) / 3.0
			if absf(middle.x - box.get_center().x) > box.size.x * 0.35 or absf(middle.z - box.get_center().z) > box.size.z * 0.35: continue
			var key := int(round(middle.y / 0.02))
			var area := cross.length() * 0.5
			var bin: Array = bins.get(key, [0.0, 0.0])
			bins[key] = [bin[0] + area, bin[1] + area * middle.y]
	var footprint := box.size.x * box.size.z
	var result := []
	var keys := bins.keys()
	keys.sort()
	if not up: keys.reverse()
	for key in keys:
		var height: float = bins[key][1] / bins[key][0]
		if bins[key][0] < footprint * 0.1 or height < 0.03: continue
		if not result.is_empty() and absf(height - result[-1]) < 0.12:
			result[-1] = height
			continue
		result.append(height)
	if not up: result.reverse()
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
	var ways := FLOOR.doorways(room)
	var half := (far - NEAR) * 0.5
	var result := []
	# Along a lobby's lift wall the pieces stand against it, in front of the
	# car (FLOOR.LIFT_DEPTH); its doorway is in the middle, inside NEAR.
	var lift := FLOOR.lift_wall(room)
	for wall in walls(span):
		if open.has(wall[0]) or float(wall[3]) < far * 2.0 + 1.0: continue
		var inward: Vector3 = wall[1]
		var along := Vector3.UP.cross(inward)
		var axis := axis_of(inward)
		for side in [-1, 1]:
			var middle: float = side * (NEAR + far) * 0.5
			# Where it is along the world's axis, as doorways are measured.
			var at: float = middle * along.dot(axis)
			var taken := false
			for way in ways:
				# Nearer a doorway in this wall than NEAR: in its way, or
				# where its leaf swings.
				if way.wall == wall[0] and absf(at - float(way.along)) - half < NEAR - 0.01: taken = true
			for spot: Vector3 in hides:
				# A wardrobe on this wall, where the stretch would be.
				if spot.normalized().dot(-inward) > 0.7 and absf(at - spot.dot(axis)) < half + WARDROBE_HALF: taken = true
			if taken: continue
			var inset: float = INSET + (FLOOR.LIFT_DEPTH - 0.09 if Vector3(lift.x, 0, lift.y) == -inward else 0.0)
			var origin: Vector3 = -inward * (wall[2] * 0.5 - inset) + along * middle
			result.append([Transform3D(Basis(along, Vector3.UP, inward), origin), far - NEAR])
	return result

## The world axis a wall runs along, by which way is into the room: z for the
## west and east walls, x for the north and south ones.
static func axis_of(inward: Vector3) -> Vector3:
	return Vector3(0, 0, 1) if absf(inward.x) > 0.5 else Vector3(1, 0, 0)

## Whether a mark `reach` either side of `at` (along the world axis of the
## wall `side`) keeps off every doorway in that wall.
static func off_doorways(ways: Array, side: String, at: float, reach: float) -> bool:
	for way in ways:
		if way.wall == side and absf(at - float(way.along)) < reach + FLOOR.PORTAL * 0.5: return false
	return true

## A room's four walls: [side, inward, distance across, length].
static func walls(span: Vector2) -> Array:
	return [["west", Vector3(1, 0, 0), span.x, span.y], ["east", Vector3(-1, 0, 0), span.x, span.y], ["north", Vector3(0, 0, 1), span.y, span.x], ["south", Vector3(0, 0, -1), span.y, span.x]]

## Dresses a room (called by hotel_geometry.build_room(), after its sockets).
## The pieces you can go through: drawers, shelves and cupboards, and a
## suitcase lying on the floor (which never holds a page: digit_placement).
const CONTAINERS := ["commode", "console", "drawers", "bookcase", "cabinet", "boxes", "luggage"]

static func dress(builder, node: Node3D, room: Dictionary) -> void:
	# Neither the refuge nor the lift lobby is furnished: one is bare by
	# design and the other has nothing in it but the car.
	if int(room.type) == 19 or bool(room.get("landing", false)): return
	var kept := state(room)
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
		builder.note_spot = {}
		builder.piece_main = {}
		builder.piece_things = []
		furnish(builder, holder, pick, stretch[1], seed_pos, kept, room)
		# Anything with drawers or shelves is somewhere a number could be
		# hidden: the builder keeps the list so a floor can put four in them.
		# With how far its front reaches: the note shows out of it and the
		# hand finds it there, whatever the piece's depth.
		# And where a note of the code would be left in it (note_fold()).
		if pick in CONTAINERS: builder.containers.append({"room": int(room.id), "position": node.position + frame.origin, "yaw": frame.basis.get_euler().y, "kind": pick, "front": builder.piece_front, "note": builder.note_spot, "main": builder.piece_main, "things": builder.piece_things})
		builder.piece_things = null
		# A fire alarm's pull station on the first stretch of a corridor, a
		# lobby or the reception, at the end of it nearer the middle of the
		# wall: a painting and its lamps hang past the other end.
		if k == 0 and int(room.type) in ALARM_ROOMS and builder.vary(seed_pos, 130) < 0.6:
			var end: float = -0.72 * signf(frame.basis.x.dot(frame.origin))
			place(builder, holder, "fire_alarm", Transform3D(Basis.IDENTITY, Vector3(end, 1.22, WALL_FACE + 0.018)), false)
		k += 1
	# Ceiling fans, still: one either side of the lamp along the room.
	if int(room.type) in FAN_ROOMS:
		var span := FLOOR.size_of(room)
		var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
		var drop: float = mesh("ceiling_fan").get_aabb().size.y
		for side in [-1, 1]:
			var at: Vector3 = along * side * maxf(span.x, span.y) * 0.25
			place(builder, node, "ceiling_fan", Transform3D(Basis(Vector3.UP, builder.vary(node.position + at, 132) * TAU), at + Vector3(0, float(room.height) - drop - 0.004, 0)), false)
	decals(builder, node, room, kept)

## One stretch: a piece (or a group) of the set, its things, and on a bare
## stretch the clutter a neglected room leaves.
static func furnish(builder, holder: Node3D, pick: String, width: float, seed_pos: Vector3, kept: int, room: Dictionary) -> void:
	var v := func(salt: int) -> float: return builder.vary(seed_pos, salt)
	match pick:
		"commode":
			var s := minf(1.0, width / 1.25)
			put(builder, holder, "GothicCommode_01", Vector3(0, 0, 0.3 * s), 0.0, s, true)
			commode_note(builder, Vector3(0, 0, 0.3 * s), s, seed_pos)
			dress_top(builder, holder, "GothicCommode_01", Vector3(0, 0, 0.3 * s), s, ORNAMENTS, seed_pos, 2)
			hang_mirror(builder, holder, room, 1.62, seed_pos)
		"console":
			var s := minf(0.85, width / 1.6)
			put(builder, holder, "ClassicConsole_01", Vector3(0, 0, 0.3 * s), 0.0, s, true)
			dress_top(builder, holder, "ClassicConsole_01", Vector3(0, 0, 0.3 * s), s, ORNAMENTS, seed_pos, 2)
			# No drawer: on the top (0.949), between its two ornaments, and from
			# the top's edge (0.236) out over the moulded lip in front of it,
			# 2 cm lower (0.93 at 0.29), past the slab's front (0.295).
			note_fold(builder, "ClassicConsole_01", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(0, 0, 0.3 * s)), Vector3(v.call(120) * 0.16 - 0.08, 0.951, 0.236), v.call(121) * 0.3 - 0.15, 0.12, 0.09, 0.0, 1.2)
			hang_mirror(builder, holder, room, 1.45, seed_pos)
		"armchair":
			var chair: String = "ArmChair_01" if v.call(32) < 0.5 else "GreenChair_01"
			put(builder, holder, chair, Vector3(-0.22, 0, 0.45), v.call(33) * 0.4 - 0.2, 1.0, true)
			put(builder, holder, "side_table_tall_01", Vector3(0.45, 0, 0.25), 0.0, 1.0, true)
			dress_top(builder, holder, "side_table_tall_01", Vector3(0.45, 0, 0.25), 1.0, ["ceramic_vase_01", "brass_vase_02", "cigarette_pack", "alarm_clock_01", "potted_plant_04"], seed_pos, 1)
		"chair":
			put(builder, holder, "dining_chair_02", Vector3(-0.2, 0, 0.35), v.call(34) * 0.5 - 0.25, 1.0, true)
			if v.call(35) < 0.5: put(builder, holder, "side_table_tall_01", Vector3(0.35, 0, 0.22), 0.0, 1.0, true)
		"chairs":
			for x in [-0.28, 0.28]: put(builder, holder, "dining_chair_02", Vector3(x, 0, 0.32), v.call(36 + int(x * 10)) * 0.2 - 0.1, 1.0, true)
		"luggage":
			put(builder, holder, "vintage_suitcase_a", Vector3(-0.15, 0, 0.14), 0.05, 1.0, true)
			# The other lies flat beside it, on its back, its lid up and its
			# handle towards the room: the one that is gone through (the
			# author's word, 21 October 2026), its lid lifting on the hinge
			# along the edge by the wall.
			var turn: float = v.call(37) * 0.6 - 0.3
			var lying := Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI / 2), Vector3(0.4, 0.12, 0.1))
			builder.piece_main = place(builder, holder, "vintage_suitcase_b", lying)
			builder.piece_front = maxf(builder.piece_front, 0.1 + mesh("vintage_suitcase_b").get_aabb().size.y)
			# What is shut in it shows between the two halves, at the seam of
			# the edge with the handle (0.545 up the case, the seam at 0.0145),
			# clear of the handle and the latches: back inside, and down the
			# front of the lower half.
			var side: float = 1.0 if v.call(127) < 0.5 else -1.0
			var fold := Vector3(side * (0.26 + v.call(128) * 0.04), 0.545, 0.0145)
			builder.note_spot = {"at": lying * fold, "yaw": turn, "skew": v.call(129) * 0.2 - 0.1, "lie": 0.1, "hang": 0.09, "lie_tilt": 0.0, "hang_tilt": 0.12, "model": "vintage_suitcase_b", "piece": lying}
		"plant":
			put(builder, holder, "potted_plant_02" if v.call(39) < 0.3 else "monstera", Vector3(0, 0, 0.35), v.call(38) * TAU, 1.0, false)
			builder.box(holder, Vector3(0, 0.27, 0.35), Vector3(0.5, 0.54, 0.5), "", true)
		"bookcase":
			var s := minf(0.9, width / 1.4)
			put(builder, holder, "wooden_bookshelf_worn", Vector3(0, 0, 0.3 * s), 0.0, s, true)
			fill_shelves(builder, holder, "wooden_bookshelf_worn", Vector3(0, 0, 0.3 * s), s, ["book_encyclopedia_set_01", "book_encyclopedia_set_01", "ceramic_vase_01", "cardboard_box_01"], seed_pos)
			# Laid on one of the three middle shelves (their boards' tops, and
			# the lip in front at 0.272), pushed under what stands on it, the
			# end come down over the edge.
			var shelf: float = [0.671, 0.961, 1.276][int(v.call(122) * 3.0)]
			note_fold(builder, "wooden_bookshelf_worn", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(0, 0, 0.3 * s)), Vector3(v.call(123) * 0.6 - 0.3, shelf + 0.002, 0.274), v.call(124) * 0.3 - 0.15, 0.11, 0.1)
		"cabinet":
			var s := minf(1.0, width / 1.25)
			if kept == 0:
				# A glazed cabinet where the room is kept: a cupboard below, a
				# counter, and a dresser of three glass doors set back on it.
				# A note of the code is left on the counter (0.912, its edge at
				# 0.291), the end come down over the lip in front of it.
				var c := minf(0.82, width / 2.1)
				var stood := Vector3(0, 0, 0.335 * c + 0.02)
				put(builder, holder, "vintage_cabinet_01", stood, 0.0, c, true)
				note_fold(builder, "vintage_cabinet_01", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * c), stood), Vector3(v.call(120) * 0.8 - 0.4, 0.914, 0.289), v.call(121) * 0.3 - 0.15, 0.12, 0.07, 0.0, 0.5)
				return
			put(builder, holder, "painted_wooden_cabinet" if kept >= 1 else "GothicCommode_01", Vector3(0, 0, 0.32), 0.0, s, true)
			if kept >= 1:
				# Left on its top, which is dark wood (1.182, the edge at 0.237),
				# the end come down over the edge: on the painted front, as pale
				# as the paper, it was not seen. On the side of the shut drawer
				# (the left one stands out of the carcass, 0.277), clear of that
				# drawer's handle at a quarter of the width.
				note_fold(builder, "painted_wooden_cabinet", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(0, 0, 0.32)), Vector3(0.1 + v.call(120) * 0.06, 1.184, 0.239), v.call(121) * 0.24 - 0.12, 0.13, 0.08, 0.0, 0.05)
			else: commode_note(builder, Vector3(0, 0, 0.32), s, seed_pos)
		"drawers":
			var s := minf(1.0, width / 1.2)
			put(builder, holder, "drawer_cabinet", Vector3(0, 0, 0.26), 0.0, s, true)
			# Shut in the third drawer: out of the slit above it (0.928 to
			# 0.953), hanging down its front (0.244). The drawers are flush,
			# with no handles.
			note_fold(builder, "drawer_cabinet", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(0, 0, 0.26)), Vector3(v.call(120) * 0.5 - 0.25, 0.94, 0.246), v.call(121) * 0.16 - 0.08, 0.07, 0.14, 0.0, DRAWER_TILT)
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
			# Where nobody empties them any more, a full bag left beside it.
			elif kept >= 1: put(builder, holder, "trashbag", Vector3(0.42, 0, 0.3), v.call(45) * TAU, 1.0, true)
		_:
			# A long-case clock on a bare stretch of a room, a lounge or a
			# dining room that is still kept (and has no wall clock here).
			if kept == 0 and int(room.type) in CLOCK_ROOMS and v.call(46) >= 0.3 and v.call(133) < 0.45: put(builder, holder, "vintage_grandfather_clock_01", Vector3(0, 0, 0.25), 0.0, 1.0, true)
			# A bare stretch: what a neglected room leaves lying about.
			if kept >= 1: litter(builder, holder, seed_pos, kept)
	# A clock on one wall in some rooms.
	if pick in ["", "chairs", "armchair", "chair"] and v.call(46) < 0.3:
		place(builder, holder, "wall_clock", Transform3D(Basis.IDENTITY, Vector3(0.2, 2.05, WALL_FACE + 0.027)))
	# A fuse box on the wall of some service rooms, over nothing taller than a
	# stack of boxes. Every planta has one at least (fuse_boxes_left()): the
	# stretches it could hang on are kept for that.
	if pick in ["", "boxes", "bins", "baskets"]:
		if int(room.type) in FUSE_ROOMS and v.call(134) < 0.4: fuse_box(builder, holder, room)
		elif int(room.type) != 19 and not bool(room.get("landing", false)): builder.panel_spares.append({"wing": int(room.get("wing", 0)), "holder": holder, "room": room})

## A fuse box on a stretch's wall: solid, at the height of a head, shut and
## locked. It is an electrical panel, which the floor's key opens
## (hotel_panel.gd), and the builder keeps where it is and where it is drawn.
static func fuse_box(builder, holder: Node3D, room: Dictionary) -> void:
	var size := mesh("power_box_01").get_aabb().size
	var at := Vector3(-0.45, 1.25, WALL_FACE + size.z * 0.5 + 0.004)
	var handle := place(builder, holder, "power_box_01", Transform3D(Basis.IDENTITY, at), false)
	builder.box(holder, at + Vector3(0, size.y * 0.5, 0), size, "", true)
	builder.panels.append({"room": int(room.id), "wing": int(room.get("wing", 0)), "position": holder.get_parent().position + holder.transform * (at + Vector3(0, size.y * 0.5, size.z * 0.5)), "yaw": holder.transform.basis.get_euler().y, "main": handle})

## Once every room is dressed: a planta left with no panel (a half-sized one
## was found with none, and its blackout with nowhere to be undone from) has
## one on the first stretch it could hang on, a service room's before any
## other's.
static func fuse_boxes_left(builder) -> void:
	var wings := {}
	for spare in builder.panel_spares: wings[int(spare.wing)] = true
	for wing in wings:
		if builder.panels.any(func(panel): return int(panel.wing) == wing): continue
		var spares: Array = builder.panel_spares.filter(func(spare): return int(spare.wing) == wing)
		var served: Array = spares.filter(func(spare): return int(spare.room.type) in FUSE_ROOMS)
		var spare: Dictionary = served[0] if not served.is_empty() else spares[0]
		fuse_box(builder, spare.holder, spare.room)
	builder.panel_spares.clear()

## A model on the stretch's floor, turned by yaw and scaled by s; with a box
## collider round it when solid (turned only a little, so its box stays).
## A piece that opens (its drawers and doors baked apart as well: tools/props/
## build_catalogue.gd, MOVING) is kept as the piece being furnished.
static func put(builder, holder: Node3D, name: String, pos: Vector3, yaw: float, s: float, solid: bool) -> void:
	var handle := place(builder, holder, name, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos))
	if opens(name): builder.piece_main = handle
	if solid:
		var size := mesh(name).get_aabb().size * s
		builder.box(holder, pos + Vector3(0, size.y * 0.5, 0), size, "", true)
		builder.piece_front = maxf(builder.piece_front, pos.z + size.z * 0.5)

## A thing put on or in the piece being furnished, kept with it (when it is
## one: hotel_geometry.piece_things).
static func keep(builder, handle: Dictionary) -> void:
	if builder.piece_things != null: builder.piece_things.append(handle)

## Whether a model has its drawers and doors baked apart, asked once each.
static var opening := {}
static func opens(name: String) -> bool:
	if not opening.has(name): opening[name] = ResourceLoader.exists(HOTEL % (name + "_body"))
	return opening[name]

static func place(builder, holder: Node3D, name: String, xform: Transform3D, casts := true) -> Dictionary:
	return builder.place(holder, mesh(name), xform, casts)

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
		keep(builder, place(builder, holder, name, Transform3D(Basis(Vector3.UP, yaw), at + Vector3(slot * usable, top + ON_TOP, box.get_center().z * s - 0.02)), false))

## How far a thing put on a piece stands off its top or its shelf (metres):
## a crate's or a jug's underside, drawn from both sides, lay in the plane of
## the board under it and flickered into it.
const ON_TOP := 0.002

## Every shelf of a piece, a few things each, some gaps.
static func fill_shelves(builder, holder: Node3D, base: String, at: Vector3, s: float, choices: Array, seed_pos: Vector3) -> void:
	var box := mesh(base).get_aabb()
	var tops := shelves(base)
	for level in tops.size():
		var y: float = tops[level] * s
		var room_above: float = room_over(base, tops[level]) * s
		var x := -box.size.x * s * 0.42
		var i := 0
		while x < box.size.x * s * 0.4 and i < 5:
			var name: String = choices[int(builder.vary(seed_pos + Vector3(level, 0, i), 60) * choices.size())]
			var size := mesh(name).get_aabb().size
			var fit := minf(1.0, (room_above - 0.03) / maxf(size.y, 0.01))
			var turn: float = builder.vary(seed_pos + Vector3(level, 0, i), 62) * 0.3 - 0.15
			# As wide as it stands turned: a thing that would reach past the
			# side of the piece is not put there. A set of books used to be
			# put down wherever its left end was still on the shelf, and hung
			# in the air beside the bookcase.
			var wide: float = (size.x * cos(turn) + size.z * absf(sin(turn))) * fit
			if builder.vary(seed_pos + Vector3(level, 0, i), 61) < 0.2 or fit < 0.45:
				x += 0.2
			elif x + wide > box.size.x * s * 0.42:
				break
			else:
				keep(builder, place(builder, holder, name, Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * fit), at + Vector3(x + wide * 0.5, y + ON_TOP, box.get_center().z * s)), false))
				x += wide + 0.04
			i += 1

## A mirror above a piece, where no wall lamp hangs.
static func hang_mirror(builder, holder: Node3D, room: Dictionary, bottom: float, seed_pos: Vector3) -> void:
	if int(room.type) in [0, 10, 11, 12] or builder.vary(seed_pos, 47) < 0.4: return
	place(builder, holder, "ornate_mirror_01", Transform3D(Basis.IDENTITY, Vector3(0, bottom, WALL_FACE + 0.015)))

## Boxes and crates stacked against the wall.
static func stack(builder, holder: Node3D, seed_pos: Vector3, count: int) -> void:
	var x := -0.55
	var y := 0.0
	# The one a note would be left on: a cardboard box before any crate (a
	# crate is open, and lower than the note is long), the highest of them.
	var top := {}
	for i in count:
		var name: String = ["cardboard_box_01", "plastic_crate_02", "cardboard_box_01"][int(builder.vary(seed_pos, 70 + i) * 3)]
		var size := mesh(name).get_aabb().size
		var yaw: float = builder.vary(seed_pos, 75 + i) * 0.5 - 0.25
		var xform := Transform3D(Basis(Vector3.UP, yaw), Vector3(x + size.x * 0.5, y, size.z * 0.5 + 0.02))
		keep(builder, place(builder, holder, name, xform))
		var rank: float = y + size.y + (10.0 if name == "cardboard_box_01" else 0.0)
		if top.is_empty() or rank > float(top.rank): top = {"name": name, "xform": xform, "rank": rank}
		if y == 0.0 and builder.vary(seed_pos, 80 + i) < 0.5:
			y = size.y + ON_TOP
		else:
			x += size.x + 0.05
			y = 0.0
		if x > 0.5: break
	builder.box(holder, Vector3(0, 0.25, 0.28), Vector3(1.1, 0.5, 0.5), "", true)
	builder.piece_front = maxf(builder.piece_front, 0.53)
	if top.is_empty(): return
	var across: float = builder.vary(seed_pos, 125) * 0.12 - 0.06
	if top.name == "cardboard_box_01":
		# On the lid, whose flaps dip from the front edge (0.324) to the
		# middle (0.29), and over that edge down the front (0.245).
		note_fold(builder, top.name, top.xform, Vector3(across, 0.326, 0.254), builder.vary(seed_pos, 126) * 0.3 - 0.15, 0.13, 0.08, 0.27)
	else:
		# Only crates: across the open top from the front rim (0.221, its
		# ribs out to 0.203), and down the front.
		note_fold(builder, top.name, top.xform, Vector3(across, 0.224, 0.205), builder.vary(seed_pos, 126) * 0.2 - 0.1, 0.13, 0.08)

## How far the part of a note hanging out of a shut drawer stands off its
## face at the foot (radians): enough for a gap and a shadow under it.
const DRAWER_TILT := 0.2

## A commode's note: shut in its middle drawer, out of the slit under the
## moulding above it and down the drawer's front, clear of the knobs (at a
## quarter of the width either side). `at` and `s` place the piece.
static func commode_note(builder, at: Vector3, s: float, seed_pos: Vector3) -> void:
	# The slit is at 0.781, under the moulding (0.25 out); the drawer's face
	# is at 0.216, its top edge rounding out to 0.227.
	# Most of the sheet out (0.14 of 0.21) and standing off the face: 9 cm
	# pressed flat on the drawer read as a label stuck to it, not a paper
	# somebody shut in, and was walked past (September 2026). The drawer runs
	# down to 0.557, the knobs are well clear at a quarter of the width.
	note_fold(builder, "GothicCommode_01", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), at), Vector3(builder.vary(seed_pos, 120) * 0.16 - 0.08, 0.781, 0.229), builder.vary(seed_pos, 121) * 0.16 - 0.08, 0.07, 0.14, 0.0, DRAWER_TILT)

## Where a note of the code sits on the piece just placed, for the container
## (hotel_container.plant_note()). A slip folded once over an edge that runs
## across the piece: `lie` metres of it back from the fold, down by `lie_tilt`
## (into a drawer, under the books), and `hang` metres down in front of it, its
## foot out by `hang_tilt`; `skew` turns the slip in its own plane, so it lies
## askew and still flat on both faces. `fold` is in the model's own space,
## measured on its mesh;
## `piece` is how that model stands on the stretch, kept with the spot so the
## fold can be checked against the mesh (tests/hotel/stages_test.gd).
## Whatever scale the piece has, the paper keeps its size.
static func note_fold(builder, model: String, piece: Transform3D, fold: Vector3, skew: float, lie: float, hang: float, lie_tilt := 0.0, hang_tilt := 0.1) -> void:
	builder.note_spot = {"at": piece * fold, "yaw": piece.basis.orthonormalized().get_euler().y, "skew": skew, "lie": lie, "hang": hang, "lie_tilt": lie_tilt, "hang_tilt": hang_tilt, "model": model, "piece": piece}

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
	var ways := FLOOR.doorways(room)
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
		if roll >= 0.7 and roll < 0.85 and not ways.is_empty():
			# Fingerprints go on a wall with a doorway in it.
			var way: Dictionary = ways[int(builder.vary(base, 310 + i) * ways.size())]
			for each in sides:
				if each[0] == way.wall: wall = each
		var inward: Vector3 = wall[1]
		var along_axis := Vector3.UP.cross(inward)
		var sense: float = along_axis.dot(axis_of(inward))
		var surface: Vector3 = -inward * (float(wall[2]) * 0.5 - 0.16)
		# A decal projects along its -Y, into the wall; its image's top (-Z) up.
		var facing := Basis(along_axis, inward, along_axis.cross(inward))
		# Where along the wall (from its middle) a mark that is not about a
		# doorway goes; none is put over one, where it would be drawn on the
		# leaf.
		var spread: float = along * (float(wall[3]) * 0.42)
		if roll < 0.55:
			var pick: String = ["Leaking001", "Leaking003", "Leaking005"][int(builder.vary(base, 280 + i) * 3)]
			var size: float = 1.4 + builder.vary(base, 285 + i) * 1.2
			if not off_doorways(ways, wall[0], spread * sense, size * 0.5): continue
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * spread + Vector3(0, height - size * 0.5, 0)), Vector3(size, 0.5, size), 0.5 + kept * 0.2, float(i) / count)
		elif roll < 0.7:
			var pick: String = ["Leaking008", "Leaking009"][int(builder.vary(base, 290 + i) * 2)]
			if not off_doorways(ways, wall[0], spread * sense, 0.8): continue
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * spread + Vector3(0, 0.55, 0)), Vector3(1.6, 0.5, 1.1), 0.45 + kept * 0.2, float(i) / count)
		elif roll < 0.85:
			# Beside a doorway, where hands push: a metre from its middle, on
			# whichever side there is wall for them.
			var pick: String = "Fingerprints004" if kept == 2 and builder.vary(base, 295 + i) < 0.5 else "Fingerprints002"
			var side := 1.0 if along > 0.0 else -1.0
			var door_at := 0.0
			for way in ways:
				if way.wall == wall[0]: door_at = float(way.along) * sense
			if absf(door_at + side) > float(wall[3]) * 0.5 - 0.3: side = -side
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * (door_at + side * 1.0) + Vector3(0, 1.15, 0)), Vector3(0.5, 0.4, 0.5), 0.5 + kept * 0.15, float(i) / count)
		else:
			# Smears where there is tile or metal to smear.
			var stains := ["SurfaceImperfections001", "SurfaceImperfections013", "Smear003"] if int(room.type) in [4, 7, 8, 9] else ["SurfaceImperfections001", "SurfaceImperfections013"]
			var pick: String = stains[int(builder.vary(base, 300 + i) * stains.size())]
			if not off_doorways(ways, wall[0], spread * sense, 0.5): continue
			builder.decal(node, pick, Transform3D(facing, surface + along_axis * spread + Vector3(0, 0.6 + builder.vary(base, 305 + i) * 1.4, 0)), Vector3(1.0, 0.4, 1.0), 0.3 + kept * 0.15, float(i) / count)
