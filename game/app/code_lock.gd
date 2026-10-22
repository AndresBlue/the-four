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
const PANEL := preload("res://game/world/interactables/hotel_panel.gd")
const DRESSING := preload("res://game/world/hotel/room_dressing.gd")
## The marks the hints put on the plan: the carbon copy's circle, the
## evacuation plan's in its red, and the other sheet's four in its own pencil
## (the sixth of the sheet's inks).
const CARBON_MARK := Color(0.2, 0.22, 0.42)
const PLAN_MARK := Color(0.55, 0.12, 0.09)
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

## The electrical panels of the floor (hotel_panel.gd), in build order, and
## the one key that opens them (the author's word, 22 October 2026): the piece
## of furniture it is shut in (an index into `containers`, -1 when there is
## none) and the seat that took it (-1 while nobody has). Only whoever has it
## opens a panel, and from an open panel gives a wing in the blackout its
## lights back (the stage's goal, `restored`). Nothing of this is needed.
var panels: Array = []
var key_in := -1
var key_holder := -1

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
	panels.clear()
	key_in = -1
	key_holder = -1
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
	place_panels()
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
## sight lie on their table; the card hangs on its door, among blank ones on
## other doors; and the work order's wet floor sign is put out where it says.
## The floor's electrical panels, where the dressing hung them.
func place_panels() -> void:
	panels.clear()
	for spot in level.hotel.panels:
		var panel := PANEL.new()
		panel.name = "Panel_%d" % panels.size()
		panel.main = spot.get("main", {})
		var room_node = level.hotel.room_nodes[int(spot.room)] if int(spot.room) < level.hotel.room_nodes.size() else level.hotel
		panel.position = (spot.position as Vector3) - room_node.position
		panel.rotation.y = float(spot.yaw)
		room_node.add_child(panel)
		panels.append(panel)

## The key: in a drawer of a piece of the first two plantas (a commode, the
## office's drawers or the painted cabinet; never one with a page, a hint or a
## document in it, nor in a refuge or a lift lobby), the same one on every
## machine. Its ring hangs out of the drawer it is shut in, as a note would.
const KEY_IN := ["GothicCommode_01", "drawer_cabinet", "painted_wooden_cabinet"]
func place_key() -> void:
	key_in = -1
	key_holder = -1
	if containers.is_empty(): return
	var refuges: Array = level.manifest.get("refuges", [])
	var spots: Array = []
	for index in containers.size():
		var piece = containers[index]
		if not KEY_IN.has(String(piece.note_spot.get("model", ""))) or piece.digit >= 0 or piece.hint >= 0 or not piece.document.is_empty(): continue
		var room: Dictionary = level.manifest.rooms[int(level.hotel.containers[index].room)]
		if int(room.get("wing", 0)) > 1 or refuges.has(int(room.id)) or bool(room.get("landing", false)): continue
		spots.append(index)
	if spots.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(level.manifest.seed), "key"])
	key_in = int(spots[rng.randi_range(0, spots.size() - 1)])
	containers[key_in].key = true
	containers[key_in].plant_key()

## Whether this machine's player has the key.
func has_key() -> bool:
	return key_holder >= 0 and key_holder == level.player.slot

## A panel opened, or its switches thrown: the host decides, as with
## everything else (match_net.use_panel), and here it is done on every
## machine. Quiet: caught up on coming back, not happening now.
func apply_panel(index: int, action: String, quiet := false) -> void:
	if index < 0 or index >= panels.size() or not is_instance_valid(panels[index]): return
	var panel = panels[index]
	match action:
		"open":
			if panel.opened: return
			panel.open(0.0 if quiet else panel.SWING)
			if level.world_audio.enabled and not quiet: level.world_audio.play_at(PANEL_SOUND, panel.global_position, PANEL_DB)
		"power":
			if not panel.opened: panel.open(0.0)
			if not level.net.is_client() and bool(level.session.goal.get("blackout", false)):
				level.session.goal["blackout"] = false
				level.session.goal["restored"] = true
				level.session.changed.emit()
			if level.world_audio.enabled and not quiet: level.world_audio.play_long(level.BLACKOUT_SOUND, panel.global_position, -6.0, RID(), false, level.POWER_BACK)

## The panel's door: a wardrobe's latch and hinge, the nearest recording
## there is of a small metal door (docs/PLAN.md, apartado 4).
const PANEL_SOUND := "res://assets/audio/sfx/wardrobe/opening1.ogg"
const PANEL_DB := -10.0

## Whether a panel can give the lights back now: in a blackout of this wing
## (one given back does not come again: the goal's `restored`).
func can_power() -> bool:
	return bool(level.session.goal.get("blackout", false))

## The panels standing open, by their place in the floor's list.
func opened_panels() -> Array:
	var out: Array = []
	for index in panels.size():
		if is_instance_valid(panels[index]) and panels[index].opened: out.append(index)
	return out

func place_hints(hiding: Array, stage: int) -> void:
	hints = HINTS.choose(level.manifest, level.hotel.containers, hiding, stage) if stage > 0 else []
	for hint in hints:
		if String(hint.place) == "container":
			var index := int(hint.container)
			if index < 0 or index >= containers.size(): continue
			containers[index].hint = int(hint.id)
			containers[index].plant_note()
		elif String(hint.place) == "door":
			hang_card(hint.door, int(hint.id), false)
			for blank in hint.get("blank", []): hang_card(blank, int(hint.id), true)
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

## A "do not disturb" card on the door between `pair` [room, outside], hung
## on the knob on the outside's face (hotel_door.gd's leaf runs along +X from
## its hinge; the knob is at KNOB), and swinging with the leaf. `blank`: one of
## those on other doors, with nothing on its back.
const KNOB := Vector3(1.16, 1.25, 0.078)
func hang_card(pair: Array, id: int, blank: bool) -> void:
	var room: Dictionary = level.manifest.rooms[int(pair[0])]
	var outside: Dictionary = level.manifest.rooms[int(pair[1])]
	var door: Node3D = null
	for candidate in level.hotel.doors:
		if String(candidate.name) in ["Door_%d_%d" % [int(pair[0]), int(pair[1])], "Door_%d_%d" % [int(pair[1]), int(pair[0])]]: door = candidate
	if door == null: return
	var side := signf((FLOOR.position_of(outside) - (door.doorway as Vector3)).dot(Basis(Vector3.UP, door.closed_rotation).z))
	var hanger := HINT_PAPER.new()
	hanger.name = "Card_%d_%d" % [int(room.id), int(outside.id)]
	hanger.hint_id = id
	hanger.kind = "nomolestar"
	hanger.blank = blank
	door.add_child(hanger)
	# Its hole round the knob's neck (2.3 cm under the card's top), flat on
	# the leaf below it.
	hanger.transform = Transform3D(Basis(Vector3.UP, 0.0 if side >= 0.0 else PI), Vector3(KNOB.x, KNOB.y - 0.09, side * KNOB.z))

## Under its room's node, so its lamps light it and it goes with the room;
## where the hint said, in the world.
func put_in_room(node: Node3D, room: int, where: Transform3D) -> void:
	var parent: Node3D = level.hotel.room_nodes[room] if room >= 0 and room < level.hotel.room_nodes.size() and is_instance_valid(level.hotel.room_nodes[room]) else level.hotel
	parent.add_child(node)
	node.global_transform = where

func hint_of(id: int) -> Dictionary:
	return hints[id] if id >= 0 and id < hints.size() else {}

## A hint comes to this player: taken from a drawer, or read where it lies.
func own_hint(id: int) -> void:
	if not hints_mine.has(id): hints_mine.append(id)
	if String(hint_of(id).get("kind", "")) == "polaroid": develop_photo(hint_of(id))

## The Polaroid's picture (hint_view.gd): the piece of furniture its page is
## in, from a step or two back in its room, with the flash, as whoever was
## here before took it. Taken on this machine the first time the hint is had
## (read, or given back with a kept floor): a camera of its own on the same
## world, with the room shown for the frames it takes, whatever the round of
## the rooms says (hotel_geometry.update_visibility(), which puts it back on
## its next round). Without a screen nothing is drawn, and it has none.
const PHOTO_SIZE := 512
const PHOTO_BACK := 2.2
const PHOTO_EYE := 1.45
func develop_photo(hint: Dictionary) -> void:
	if hint.has("photo") or hint.has("developing") or DisplayServer.get_name() == "headless": return
	var index := int(hint.get("shot", -1))
	if index < 0 or index >= containers.size() or not is_instance_valid(containers[index]): return
	hint["developing"] = true
	var piece: Node3D = containers[index]
	var out := Vector3(piece.global_basis.z.x, 0.0, piece.global_basis.z.z).normalized()
	var target := piece.global_position + out * float(piece.front) + Vector3.UP * 0.55
	var wanted := target + out * PHOTO_BACK + out.cross(Vector3.UP) * 0.3 + Vector3.UP * (PHOTO_EYE - 0.55)
	# Not through a wall or a wardrobe: as far back as the room lets it.
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target, wanted, 1 | 8))
	var eye := wanted if hit.is_empty() else (hit.position as Vector3) - (wanted - target).normalized() * 0.2
	var view := SubViewport.new()
	view.name = "Polaroid"
	view.size = Vector2i(PHOTO_SIZE, PHOTO_SIZE)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.current = true
	view.add_child(camera)
	var flash := OmniLight3D.new()
	flash.omni_range = 7.0
	flash.light_energy = 2.4
	flash.light_color = Color(1.0, 0.97, 0.92)
	flash.shadow_enabled = true
	view.add_child(flash)
	level.add_child(view)
	camera.look_at_from_position(eye, target, Vector3.UP)
	flash.global_position = eye + Vector3.UP * 0.06
	var room_node: Node3D = piece.get_parent() as Node3D
	# Two frames drawn, the room shown just before each: what the round
	# hides in between is shown again for the draw.
	for frame in 2:
		await RenderingServer.frame_pre_draw
		if not is_instance_valid(view): return
		if is_instance_valid(room_node): room_node.visible = true
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(view): return
	hint["photo"] = ImageTexture.create_from_image(view.get_texture().get_image())
	hint.erase("developing")
	view.queue_free()
	for lying in level.hotel.find_children("Hint_%d" % int(hint.id), "Area3D", true, false): lying.show_photo(hint.photo)

func note_read(id: int) -> void:
	if String(hint_of(id).get("place", "")) in ["surface", "door"]: hints_read[id] = true
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
			"plano": marks.append({"planta": planta, "centre": hint.centre, "radius": float(hint.radius), "ink": PLAN_MARK})
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
	# piece left open with it, the drawer reaching its stop on the knock. Of a
	# console, a bookcase, crates or a suitcase only the paper is heard, close
	# by: the creature does not hear it.
	var sounds: Array = piece.search_sounds()
	var path: String = sounds[randi() % sounds.size()]
	piece.show_searched(0.0 if quiet else SEARCH_TIMING.stop(path, piece.UNTIMED_OPEN if piece.hushed() else piece.DOOR_SWING))
	if level.world_audio.enabled and not quiet:
		level.world_audio.play_at(path, piece.global_position + Vector3(0, 0.8, 0), piece.search_db(path))
	if not level.net.is_client() and not quiet and not piece.hushed(): level.on_noise(piece.global_position + Vector3(0, 0.8, 0), piece.noise_radius(), NOISE.Kind.DOOR)
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
	# The key goes to whoever finds it, and it is theirs alone.
	if piece.key:
		key_holder = seat
		piece.take_key()
		if seat == level.player.slot and not quiet and not level.bot_match: level.ui.flash("LLAVE DEL CUADRO ELÉCTRICO", 3.0)
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
