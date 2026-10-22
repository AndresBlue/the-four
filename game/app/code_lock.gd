extends Node
## The code of the last door: the drawers, shelves and cupboards of the floor
## and the four numbers hidden in four of them, going through them, what each
## player has written down, and the keypad beside the last door. Split out of
## hotel_main.gd, which owns it (`level.code`); the level keeps delegates of
## what the network, the bots and the tests reach through it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
const LOCK := preload("res://game/world/interactables/hotel_lock.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const HINTS := preload("res://game/world/generation/hint_placement.gd")
const HINT_PAPER := preload("res://game/world/interactables/hotel_hint.gd")
const DRESSING := preload("res://game/world/hotel/room_dressing.gd")
const CHALK := preload("res://game/presentation/shaders/chalk.gdshader")
## The marks the hints put on the plan: the carbon copy's circle, and the
## other sheet's four in its own pencil (the sixth of the sheet's inks).
const CARBON_MARK := Color(0.2, 0.22, 0.42)
const OTHER_MARK := Color(0.29, 0.1, 0.33)
const NOISE := preload("res://game/audio/noise_kinds.gd")
const SEARCH_TIMING := preload("res://game/audio/search_timing.gd")
var level

## Everything with drawers or shelves, in build order, and the numbers found
## in them so far, by place in the code.
var containers: Array = []

var found_digits := {}

## Code place -> seat of whoever found it. The goal counts every number the team
## has; what is written down for a player -- the sheet, the keypad's notes, the
## tape -- is only what that player found. The rest they have to be told.
var found_by := {}

## And where each one was found, as it would be said out loud: the number on
## that door, or what the room is when it has no plaque (service rooms, halls
## and corridors carry none). A number without a place is a number nobody can
## check, and checking is what the others are for.
var found_where := {}

## Whether the code has been read into the lock: from then on the last door
## opens and the floor is left by stepping through it.
var code_entered := false

## The hints of the stage (hint_placement.gd), by id; who took each one that
## was in a drawer (the seat, as the pages: it leaves with them); the ones
## lying in sight this player has read; and this player's, in the order they
## came to it, which is how they hang on the sheet.
var hints: Array = []
var hints_taken := {}
var hints_read := {}
var hints_mine: Array = []

## The keypad of the last door, and what is being typed into it.
var lock: Node3D

var lock_open := false

var typed := ""

## The drawers, shelves and cupboards of the floor, and the four numbers hidden
## in four of them, in the wing of the last stage. Everyone works out the same
## hiding places from the seed; only what has been gone through travels.
func place_containers() -> void:
	containers.clear()
	found_digits.clear()
	found_by.clear()
	found_where.clear()
	hints.clear()
	hints_taken.clear()
	hints_read.clear()
	hints_mine.clear()
	code_entered = false
	typed = ""
	lock = null
	close_lock()
	if level.manifest.get("gates", []).is_empty(): return
	for spot in level.hotel.containers:
		var piece := CONTAINER.new()
		piece.name = "Container_%d" % containers.size()
		piece.kind = str(spot.kind)
		piece.front = float(spot.get("front", 0.5))
		piece.note_spot = spot.get("note", {})
		piece.main = spot.get("main", {})
		piece.things = spot.get("things", []) if spot.get("things") != null else []
		piece.position = spot.position
		piece.rotation.y = spot.yaw
		# Parented to its room, so it is culled with it, but placed by the
		# world point the dressing worked out.
		var room_node = level.hotel.room_nodes[int(spot.room)] if int(spot.room) < level.hotel.room_nodes.size() else level.hotel
		piece.position = spot.position - room_node.position
		room_node.add_child(piece)
		containers.append(piece)
	# The keypad, beside the last door, on the refuge's side of it.
	if not level.hotel.lifts.is_empty() and not level.manifest.gates.is_empty():
		var last: Dictionary = level.manifest.gates[level.manifest.gates.size() - 1]
		var out: Array = last.get("out", [1, 0])
		var away := Vector3(int(out[0]), 0, int(out[1]))
		# On the wall the door is in, which is the one the refuge shares with
		# the landing behind it.
		var door_point: Vector3 = FLOOR.portal_between(level.manifest.rooms[int(last.room)], level.manifest.rooms[int(last.beyond)])
		lock = LOCK.new()
		lock.name = "CodeLock"
		# Its back on the plaster (0.09 from the wall's centre line; the panel
		# sits 0.05 in front of the node): at 0.35 it hung in the air.
		lock.position = door_point - away * 0.07 + Vector3(away.z, 0, -away.x) * 1.1
		lock.rotation.y = atan2(-away.x, -away.z)
		level.hotel.add_child(lock)
	# In the wing of the stage that asks for the code (the last, in the hotel).
	var asking: Array = level.kind.stages_asking("code")
	var hiding: Array = DIGITS.choose(level.manifest, level.hotel.containers, int(asking[0])) if not asking.is_empty() else []
	for hidden in hiding:
		var index := int(hidden.container)
		if index < 0 or index >= containers.size(): continue
		containers[index].digit = int(hidden.digit)
		containers[index].slot = int(hidden.slot)
		# The four that hold something say so: a slip of paper left showing.
		containers[index].plant_note()
	place_hints(hiding, int(asking[0]) if not asking.is_empty() else 0)
	level.camcorder.write_code("")
	# The parts of the pieces that open, loaded now and kept while the floor
	# lasts: not read off the disk on the first search.
	opening_meshes.clear()
	for piece in containers:
		if piece.main.is_empty(): continue
		var base := String((piece.main.entry.mesh as Mesh).resource_path).get_basename()
		if opening_meshes.has(base): continue
		var body: Mesh = load(base + "_body.res")
		var parts := [body]
		for part_name in body.get_meta("parts"): parts.append(load("%s_%s.res" % [base, part_name]))
		opening_meshes[base] = parts

## The pieces that open on this floor: model -> its body and parts.
var opening_meshes := {}

## The hints of the stage that asks for the code: those in drawers show a slip
## as the pages do (nobody can tell which is which before looking); those in
## sight lie on their table; and what two of them speak of is put in the
## world -- the work order's wet floor sign, the chalk on the walls.
func place_hints(hiding: Array, stage: int) -> void:
	hints = HINTS.choose(level.manifest, level.hotel.containers, hiding, stage) if stage > 0 else []
	for hint in hints:
		if String(hint.place) == "container":
			var index := int(hint.container)
			if index < 0 or index >= containers.size(): continue
			containers[index].hint = int(hint.id)
			containers[index].plant_note()
		else:
			var paper := HINT_PAPER.new()
			paper.name = "Hint_%d" % int(hint.id)
			paper.hint_id = int(hint.id)
			paper.kind = String(hint.kind)
			put_in_room(paper, int(hint.room), Transform3D(Basis(Vector3.UP, float(hint.yaw)), hint.position))
		if hint.has("sign"):
			var sign := MeshInstance3D.new()
			sign.name = "WetFloorSign"
			sign.mesh = DRESSING.mesh("WetFloorSign_01")
			put_in_room(sign, int(hint.sign.room), Transform3D(Basis(Vector3.UP, float(hint.sign.yaw)), hint.sign.position))
		for mark in hint.get("marks", []):
			var chalk := chalk_mark(mark)
			put_in_room(chalk, int(mark.room), chalk.get_meta("where"))

## Under its room's node, so its lamps light it and it goes with the room;
## where the hint said, in the world.
func put_in_room(node: Node3D, room: int, where: Transform3D) -> void:
	var parent: Node3D = level.hotel.room_nodes[room] if room >= 0 and room < level.hotel.room_nodes.size() and is_instance_valid(level.hotel.room_nodes[room]) else level.hotel
	parent.add_child(node)
	node.global_transform = where

## A mark of the chalk on a wall: an arrow along the trail, or the cross by
## the door, a hair off the plaster.
func chalk_mark(mark: Dictionary) -> MeshInstance3D:
	var cross := String(mark.mark) == "cross"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.34) if cross else Vector2(0.56, 0.24)
	var material := ShaderMaterial.new()
	material.shader = CHALK
	var normal: Vector3 = (mark.normal as Vector3).normalized()
	var across := Vector3.UP.cross(normal).normalized()
	material.set_shader_parameter("cross_mark", cross)
	material.set_shader_parameter("flip", across.dot(mark.along) < 0.0)
	material.set_shader_parameter("seed", float(int(mark.room) % 97))
	var node := MeshInstance3D.new()
	node.name = "Chalk"
	node.mesh = quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("where", Transform3D(Basis(across, Vector3.UP, normal), (mark.position as Vector3) + normal * 0.012))
	return node

func hint_of(id: int) -> Dictionary:
	return hints[id] if id >= 0 and id < hints.size() else {}

## A hint comes to this player: taken from a drawer, or read where it lies.
func own_hint(id: int) -> void:
	if not hints_mine.has(id): hints_mine.append(id)

func note_read(id: int) -> void:
	if String(hint_of(id).get("place", "")) == "surface": hints_read[id] = true
	own_hint(id)

## This player's hints, as they hang on the sheet.
func own_hints() -> Array:
	return hints_mine.map(func(id): return hint_of(int(id))).filter(func(hint): return not hint.is_empty())

## The planta the hints are about, and its walls as the plans draw them.
func hint_walls() -> Array:
	if hints.is_empty(): return []
	var planta := int(level.manifest.rooms[int(hints[0].room)].wing)
	var out: Array = []
	for wall in level.hotel.plan_walls:
		if int(wall[2]) == planta: out.append([wall[0], wall[1]])
	return out

## What this player's hints have put on the plan.
func hint_marks() -> Array:
	var marks: Array = []
	for hint in own_hints():
		var planta := int(level.manifest.rooms[int(hint.room)].wing)
		match String(hint.kind):
			"calco": marks.append({"planta": planta, "centre": hint.centre, "radius": float(hint.radius), "ink": CARBON_MARK})
			"hoja":
				for point in hint.points: marks.append({"planta": planta, "centre": point, "radius": float(hint.radius), "ink": OTHER_MARK})
	return marks

## Going through one: the host decides, as with everything else.
func search_container(piece: Node3D) -> void:
	if not is_instance_valid(piece) or piece.searched: return
	level.match_net.use_container(piece)

## Applied everywhere, whoever decided it. Quiet: caught up on coming back,
## not happening now.
func apply_search(index: int, value: bool, quiet := false, seat := -1) -> void:
	if seat < 0: seat = level.player.slot
	if index < 0 or index >= containers.size(): return
	var piece = containers[index]
	if not is_instance_valid(piece) or not piece.set_searched(value): return
	if not value: return
	# Its own drawer, box or door (hotel_container.search_sounds()), and the
	# piece left open with it, the drawer reaching its stop on the knock. One
	# that makes no sound (a console, a bookcase, crates, a suitcase) is not
	# heard by anybody, the creature either.
	var sounds: Array = piece.search_sounds()
	var path: String = sounds[randi() % sounds.size()] if not sounds.is_empty() else ""
	piece.show_searched(0.0 if quiet else piece.SILENT_OPEN if path.is_empty() else SEARCH_TIMING.stop(path, piece.DOOR_SWING))
	if level.world_audio.enabled and not quiet and not path.is_empty():
		level.world_audio.play_at(path, piece.global_position + Vector3(0, 0.8, 0), piece.SEARCH_CREAK_DB if path == piece.SEARCH_SOUND else piece.SEARCH_DB)
	if not level.net.is_client() and not quiet and not path.is_empty(): level.on_noise(piece.global_position + Vector3(0, 0.8, 0), piece.noise_radius(), NOISE.Kind.DOOR)
	# A document of the archive in a suitcase is read by whoever finds it, at
	# once, and goes into their archive; the paper leaves with them.
	if not piece.document.is_empty():
		piece.take_note()
		if seat == level.player.slot and not level.match_net.local_is_locust() and not quiet and not level.bot_match: level.interaction.read_document(piece.document)
	# A hint leaves with whoever took it, as a page does; for this player, it
	# is held up to the camera the moment it is found.
	if piece.hint >= 0:
		hints_taken[piece.hint] = seat
		piece.take_note()
		if seat == level.player.slot and not level.match_net.local_is_locust():
			own_hint(piece.hint)
			if not quiet and not level.bot_match: level.interaction.read_hint(piece.hint)
	if piece.digit >= 0:
		found_digits[piece.slot] = piece.digit
		found_by[piece.slot] = seat
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, piece.global_position)
		var number := int(room.get("number", 0))
		found_where[piece.slot] = ("HABITACIÓN %d" % number) if number > 0 else String(FLOOR.NAMES[int(room.get("type", 0))]).to_upper()
		if not level.net.is_client() and not quiet: level.ledger.note_search(seat, int(piece.slot), String(found_where[piece.slot]))
		# The paper leaves with whoever took it, and what it said stays written
		# on the tape until the floor is over.
		piece.take_note()
		if not level.match_net.local_is_locust() and seat == level.player.slot:
			level.camcorder.write_code(noted_code())
	elif not level.net.is_client() and not quiet: level.ledger.note_search(seat, 0, "")

## The slips this player took, in the order the code reads: which place, the
## number on it, and the room it came out of. Only its own -- what the others
## found is theirs to say out loud, which is half of playing together.
func notes_found() -> Array:
	var slips: Array = []
	for slot in range(1, DIGITS.COUNT + 1):
		if not found_digits.has(slot) or int(found_by.get(slot, level.player.slot)) != level.player.slot: continue
		slips.append({"slot": slot, "digit": int(found_digits[slot]), "where": String(found_where.get(slot, ""))})
	return slips

## What is written down: nothing until the first number turns up, and from
## then on the code with a dash in the places still missing.
func noted_code() -> String: return "" if notes_found().is_empty() else code_so_far(true)

## The code as it is known so far, with a dash where a number is missing: the
## team's, or with `own` only what this player found.
func code_so_far(own := false) -> String:
	var text := ""
	for slot in range(1, DIGITS.COUNT + 1):
		var known: bool = found_digits.has(slot) and (not own or int(found_by.get(slot, level.player.slot)) == level.player.slot)
		text += str(found_digits[slot]) if known else "–"
	return text

## The number the cross is resting on while the keypad is up (a pad has no
## number keys, so it is dialled).
var lock_digit := 0

## The keypad: numbers go in, a wrong code clears itself, the right one opens
## the door for everybody.
func type_code(character: String) -> void:
	if character == "borrar": typed = typed.substr(0, maxi(0, typed.length() - 1))
	elif typed.length() < DIGITS.COUNT: typed += character
	if typed.length() < DIGITS.COUNT:
		level.ui.keypad("key")
		level.ui.show_lock(typed, DIGITS.COUNT, "", noted_code(), lock_digit)
		return
	var verdict := code_verdict(typed)
	# The right code on a wing whose sets are still dark: the door is not
	# going to move, and it is better said here than guessed at the door.
	if verdict in ["sets", "notes"]:
		typed = ""
		level.ui.keypad("wrong")
		level.ui.show_lock("", DIGITS.COUNT, "FALTAN TELEVISORES" if verdict == "sets" else "FALTAN NOTAS", noted_code(), lock_digit)
		return
	# Only the keypad is heard: a try is not a door. It used to creak like one
	# on every wrong code, and latch on the right one, with nothing moving.
	if verdict == "right":
		level.ui.keypad("right")
		level.match_net.use_code()
		level.ui.show_lock(typed, DIGITS.COUNT, "ABIERTA", noted_code(), lock_digit)
		close_lock()
	else:
		typed = ""
		level.ui.keypad("wrong")
		level.ui.show_lock("", DIGITS.COUNT, "NO ES", noted_code(), lock_digit)

## What the keypad makes of a code: "right", "sets" (right, but the stage's
## sets are still dark, so the door would not move), "notes" (right, but the
## room asks for the four notes and the team has not found them) or "wrong". The keypad on
## screen asks here, and so do the test bots, which have no screen.
func code_verdict(text: String) -> String:
	var right: String = "".join(DIGITS.code(level.manifest).map(func(digit): return str(digit)))
	if text != right: return "wrong"
	# The room wants the four notes found: a code guessed, or told by somebody
	# who played this tape before, opens nothing until the team has them.
	if level.rule("code") == 1 and found_digits.size() < DIGITS.COUNT: return "notes"
	return "right" if level.sets_lit() else "sets"

func open_lock() -> void:
	lock_open = true
	typed = ""
	lock_digit = 0
	level.player.reading = true
	level.ui.show_lock("", DIGITS.COUNT, "", noted_code(), lock_digit)

func close_lock() -> void:
	lock_open = false
	level.player.reading = false
	level.ui.hide_lock()

## The code is in: the last door gives way, on every machine.
func apply_code() -> void:
	if code_entered: return
	code_entered = true
	if is_instance_valid(lock): lock.set_open(true)
