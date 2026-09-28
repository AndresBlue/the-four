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
const NOISE := preload("res://game/audio/noise_kinds.gd")
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

## The keypad of the last door, and what is being typed into it.
var lock: Node3D

var lock_open := false

var typed := ""

## Going through a drawer: the slow creak of a door, which is what it is.
const SEARCH_SOUND := "res://assets/audio/sfx/door/opening/creaky-wooden-door-slow-opening.mp3"

## The drawers, shelves and cupboards of the floor, and the four numbers hidden
## in four of them, in the wing of the last stage. Everyone works out the same
## hiding places from the seed; only what has been gone through travels.
func place_containers() -> void:
	containers.clear()
	found_digits.clear()
	found_by.clear()
	found_where.clear()
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
	for hidden in DIGITS.choose(level.manifest, level.hotel.containers):
		var index := int(hidden.container)
		if index < 0 or index >= containers.size(): continue
		containers[index].digit = int(hidden.digit)
		containers[index].slot = int(hidden.slot)
		# The four that hold something say so: a slip of paper left showing.
		containers[index].plant_note()
	level.camcorder.write_code("")

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
	if level.world_audio.enabled and not quiet: level.world_audio.play_at(SEARCH_SOUND, piece.global_position + Vector3(0, 0.8, 0), -10.0)
	if not level.net.is_client() and not quiet: level.on_noise(piece.global_position + Vector3(0, 0.8, 0), piece.noise_radius(), NOISE.Kind.DOOR)
	if piece.digit >= 0:
		found_digits[piece.slot] = piece.digit
		found_by[piece.slot] = seat
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, piece.global_position)
		var number := int(room.get("number", 0))
		found_where[piece.slot] = ("HABITACIÓN %d" % number) if number > 0 else String(FLOOR.NAMES[int(room.get("type", 0))]).to_upper()
		# The paper leaves with whoever took it, and what it said stays written
		# on the tape until the floor is over.
		piece.take_note()
		if not level.match_net.local_is_locust() and seat == level.player.slot:
			level.camcorder.write_code(noted_code())

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
	if verdict == "sets":
		typed = ""
		level.ui.keypad("wrong")
		level.ui.show_lock("", DIGITS.COUNT, "FALTAN TELEVISORES", noted_code(), lock_digit)
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
## sets are still dark, so the door would not move) or "wrong". The keypad on
## screen asks here, and so do the test bots, which have no screen.
func code_verdict(text: String) -> String:
	var right: String = "".join(DIGITS.code(level.manifest).map(func(digit): return str(digit)))
	if text != right: return "wrong"
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
