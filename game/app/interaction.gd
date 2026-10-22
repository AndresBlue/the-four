extends Node
## What the local player does with E and Tab, every frame they are playing
## (drive_local): what the camera is on and the word in the brackets for it
## (a door, a wardrobe, a set, a drawer, the keypad, a document, a teammate,
## the lift's button), the door pushed open or shut and the slow opening, the
## documents read and the sheet. Split out of hotel_main.gd, which owns it
## (`level.interaction`); the level keeps delegates of what the network, the
## bots and the tests reach through it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HIDE := preload("res://game/world/interactables/hiding_place.gd")
const DOCUMENT := preload("res://game/world/interactables/hotel_document.gd")
const TELEVISION := preload("res://game/world/interactables/hotel_television.gd")
const CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
const LOCK := preload("res://game/world/interactables/hotel_lock.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
const PLACEMENT := preload("res://game/world/generation/document_placement.gd")
const HINT_PAPER := preload("res://game/world/interactables/hotel_hint.gd")
const PANEL := preload("res://game/world/interactables/hotel_panel.gd")
var level

var pressed_door

var press_time := 0.0

var was_held := false

var slow_used := false

## The document being read, if any (or its entry, for one found in a
## suitcase, which has no paper left lying about); or the hint (its id), the
## way a document is: held up to the camera while the floor goes on.
var reading_document: Node3D
var reading_entry := ""
var reading_hint := -1

func reading() -> bool:
	return is_instance_valid(reading_document) or not reading_entry.is_empty() or reading_hint >= 0

## Seconds spent going through the piece of furniture in front.
var search_time := 0.0

## In a wardrobe: how long the key has been held, and whether it has been let
## go since getting in (the press that gets somebody in does not start to
## take them out). A touch leaves as always; held for HIDE.QUIET_EXIT seconds
## the doors are eased open and what is heard of it carries less far.
var hide_hold := 0.0
var hide_armed := false
## Held longer than this, it is not a touch.
const HIDE_TAP := 0.28

## Tab opens and closes the sheet. Dead players may look but not draw; The
## Locust never sees it.
func toggle_sheet() -> void:
	if level.ui.sheet.visible:
		level.ui.sheet.close()
		level.player.reading = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if level.match_net.local_is_locust() or reading(): return
	level.ui.sheet.seat = level.player.slot
	level.ui.sheet.map.marks = level.code.hint_marks()
	level.ui.sheet.open(level.local_alive(), level.settings.prompt_name("sheet"), level.notes_found(), level.code.own_hints(), level.code.hint_walls())
	level.player.reading = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if level.world_audio.enabled: level.paper_sound.play()

## The floor's documents: on their table, or shut in a suitcase
## (document_placement.gd), which shows its slip as a piece with a hint does.
## After the pieces of furniture (code_lock.place_containers()).
func place_documents() -> void:
	var pieces: Array = level.hotel.containers if level.containers.size() == level.hotel.containers.size() else []
	for spot in PLACEMENT.choose(level.manifest, "locust", pieces):
		if int(spot.get("container", -1)) >= 0:
			var piece = level.containers[int(spot.container)]
			piece.document = String(spot.entry)
			piece.plant_note()
			continue
		var document := DOCUMENT.new()
		document.name = "Document_" + spot.entry
		document.entry_id = spot.entry
		document.position = spot.position
		document.rotation.y = spot.yaw
		level.hotel.add_child(document)

func open_document(document: Node3D) -> void:
	read_document(document.entry_id)
	reading_document = document

## A document held up, heard, and kept in the archive: one lying about, or
## one just found in a suitcase.
func read_document(entry_id: String) -> void:
	if reading(): close_document()
	reading_entry = entry_id
	level.player.reading = true
	level.ui.show_document(CATALOG.entry(entry_id))
	if level.world_audio.enabled: level.paper_sound.play()
	level.discoveries.record(entry_id)

func close_document() -> void:
	reading_document = null
	reading_entry = ""
	reading_hint = -1
	level.player.reading = false
	level.ui.hide_document()

## A hint of the last planta held up (hint_view.gd), and kept: from now on it
## hangs on this player's sheet, and what it marks is on their plan. A blank
## "do not disturb" card (one on another door) is held up the same, with
## nothing on its back, and not kept.
func read_hint(id: int, blank := false) -> void:
	var hint: Dictionary = level.code.hint_of(id)
	if hint.is_empty(): return
	if is_instance_valid(reading_document) or not reading_entry.is_empty(): close_document()
	reading_hint = id
	level.player.reading = true
	if blank: hint = hint.merged({"hand": []}, true)
	else: level.code.note_read(id)
	level.ui.show_hint(hint, level.code.hint_walls())
	if level.world_audio.enabled: level.paper_sound.play()

## What an electrical panel offers: locked to whoever has no key; to whoever
## has it, opening it, and once open, the lights, while the blackout lasts.
func panel_word(panel) -> String:
	if not level.code.has_key(): return "CERRADO"
	if not panel.opened: return "ABRIR"
	return "DAR LA LUZ" if level.code.can_power() else ""

func focused_area():
	var from: Vector3 = level.player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - level.player.camera.global_basis.z * 2.0, 1 | 8 | 16)
	query.collide_with_areas = true
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() else null

func focused_hide():
	var area = focused_area()
	return area if area is HIDE else null

func focused_document():
	var area = focused_area()
	return area if area is DOCUMENT else null

func focused_hint():
	var area = focused_area()
	return area if area is HINT_PAPER else null

## Online: the name of the teammate straight ahead, within a few metres.
func focused_teammate() -> String:
	if level.match_net.bodies.is_empty(): return ""
	var from: Vector3 = level.player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - level.player.camera.global_basis.z * 8.0, 1 | 4 | 8)
	query.exclude = [level.player.get_rid()]
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not "player_name" in hit.collider: return ""
	return hit.collider.player_name.to_upper()

## Doors are reached from a little further away than wardrobes. It was 3.2 m,
## and a door was opened or shut from across a room (playtest, October 2026).
const DOOR_REACH := 2.4

## An open door this close can be shut without looking at it, so it can be
## pulled closed behind you while running away. It was 3 m.
const DOOR_BEHIND_REACH := 2.0

## Held this long on a door, it is eased open (or shut) slowly.
const SLOW_HOLD := 1.0

func focused_door():
	var from: Vector3 = level.player.camera.global_position
	# 64 too: a leaf somebody is standing in is not solid yet, and it must
	# still be there to be used -- to open again the door just shut on you.
	var query := PhysicsRayQueryParameters3D.create(from, from - level.player.camera.global_basis.z * DOOR_REACH, 1 | 8 | 64)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is DOOR: return hit.collider
	# And from inside it, doors only: the head can be in the leaf of a door
	# shut on it, and a ray starting inside a shape does not see that shape.
	query.collision_mask = 8 | 64
	query.hit_from_inside = true
	hit = level.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is DOOR and hit.position.distance_to(from) < 0.01 else null

## Nearest open door within reach, for closing it without looking at it.
## Asked every tick somebody walks looking at nothing: only the doors round
## the player are gone through (hotel_geometry.doors_near()), not the floor's
## several hundred.
func door_behind():
	var best = null
	var best_distance := DOOR_BEHIND_REACH
	var here: Vector3 = level.player.global_position
	for door in level.hotel.doors_near(here, DOOR_BEHIND_REACH):
		if not door.opened or door.moving: continue
		var distance := Vector2(door.doorway.x - here.x, door.doorway.z - here.z).length()
		# Not the one on the planta above or below, straight overhead.
		if absf(door.doorway.y - here.y) > 2.0: continue
		if distance < best_distance:
			best = door
			best_distance = distance
	return best

## This machine's own player: looking, opening, reading, hiding, or watching a
## teammate once it is dead.
func drive_local(delta: float) -> void:
	level.track_refuges()
	# The bots drive their own bodies; this machine's player is parked, and
	# everything below is for a player who is playing. Run, it put the parked
	# body back in sight and in reach every frame (stop_watching).
	if level.bot_match: return
	if not level.execution.is_empty() and int(level.execution.seat) == level.player.slot:
		level.hold_victim(delta)
		return
	# Not over the keypad: closing the sheet let the body walk off with the
	# keypad still on screen taking digits.
	if Input.is_action_just_pressed("sheet") and not level.online_menu and not level.lock_open: toggle_sheet()
	if level.ui.sheet.visible:
		# Looking at the sheet: the character stands still, the world goes on.
		level.camcorder.focus("")
		if not level.local_alive(): level.watch_teammates()
		return
	if not level.local_alive():
		# Its own picture went with it: the lost signal holds a moment before
		# the view ends up over a teammate's shoulder.
		if level.lost_signal > 0.0:
			level.camcorder.focus("")
			level.ui.hint.text = ""
			return
		level.watch_teammates()
		return
	if level.online_menu or level.match_net.local_is_locust(): return
	# On its feet and still put away: whatever watching a teammate did to the
	# body is undone now. The word that it is up and the replicated session
	# that says so do not always arrive in that order, and a body left hidden
	# is a body whose own torch only the others can see.
	if is_instance_valid(level.watch_rig) or not level.player.visible: level.stop_watching()
	# And on its feet. Only the revival stood it up (restore_local_player):
	# back among the living any other way -- a floor started anew after it
	# died, the session saying so before the revival did -- it was left lying
	# as the creature dropped it, under its own camera and drawn for it, and
	# nothing moves a body that has fallen: it stayed there for the rest of
	# the game. Its own capture never gets this far (hold_victim, above).
	if level.player.avatar != null and level.player.avatar.fallen: level.player.avatar.end_capture()
	level.camcorder.set_stamina(level.player.stamina / 100.0, level.player.exhausted)
	var floor_room := FLOOR.room_at(level.manifest.rooms, level.player.global_position)
	level.player.hard_floor = not floor_room.is_empty() and int(floor_room.type) in FLOOR.HARD_FLOORS
	if reading():
		level.camcorder.focus("")
		if Input.is_action_just_pressed("interact"): close_document()
		was_held = true
		return
	if level.lock_open:
		level.camcorder.focus("")
		level.ui.hint.text = ""
		return
	# What the hand is on, looked for once: a lock, a drawer, a set, a paper
	# and a wardrobe are all found by the same ray.
	var aimed = focused_area()
	var lock_target = aimed if aimed is LOCK else null
	if Input.is_action_just_pressed("interact") and is_instance_valid(lock_target) and not level.code_entered:
		level.open_lock()
		was_held = true
		return
	var container_target = aimed if aimed is CONTAINER else null
	if is_instance_valid(container_target) and not container_target.searched:
		if Input.is_action_pressed("interact"):
			search_time += delta
			level.ui.hold(search_time / CONTAINER.SEARCH_TIME)
			if search_time >= CONTAINER.SEARCH_TIME:
				level.search_container(container_target)
				search_time = 0.0
			level.camcorder.focus("REGISTRAR")
			level.ui.hint.text = ""
			was_held = true
			return
		search_time = 0.0
	else: search_time = 0.0
	# Standing in a car that can go: the button. It leaves with everybody who
	# is in it (lifts.gd), so a team waits for each other before pressing.
	var car: int = level.lifts.car_at(level.player.global_position) if not level.player.hidden else -1
	if car >= 0:
		level.camcorder.focus("PULSAR")
		if Input.is_action_just_pressed("interact"): level.match_net.call_lift(car)
		was_held = Input.is_action_pressed("interact")
		return
	var television_target = aimed if aimed is TELEVISION else null
	if Input.is_action_just_pressed("interact") and not level.player.hidden and is_instance_valid(television_target) and not television_target.on:
		level.switch_television(television_target)
		was_held = true
		return
	var document_target = aimed if aimed is DOCUMENT else null
	if Input.is_action_just_pressed("interact") and not level.player.hidden and is_instance_valid(document_target):
		open_document(document_target)
		was_held = true
		return
	var hint_target = aimed if aimed is HINT_PAPER else null
	if Input.is_action_just_pressed("interact") and not level.player.hidden and is_instance_valid(hint_target):
		read_hint(hint_target.hint_id, hint_target.blank)
		was_held = true
		return
	# An electrical panel: only whoever has the key opens it, and from it gives
	# a wing in the blackout its lights back.
	var panel_target = aimed if aimed is PANEL else null
	if Input.is_action_just_pressed("interact") and not level.player.hidden and is_instance_valid(panel_target) and level.code.has_key():
		var index: int = level.code.panels.find(panel_target)
		if not panel_target.opened: level.match_net.use_panel(index, "open")
		elif level.code.can_power(): level.match_net.use_panel(index, "power")
		was_held = true
		return
	var hiding_target = aimed if aimed is HIDE else null
	if Input.is_action_just_pressed("interact") and not level.player.hidden and is_instance_valid(hiding_target):
		var creature = level.creature
		if is_instance_valid(creature) and creature.control == "ai" and creature.sees(level.player, true): creature.saw_enter(hiding_target)
		level.match_net.use_hide(hiding_target, true)
		hide_hold = 0.0
		hide_armed = false
		pressed_door = null
		was_held = true
	var key: String = level.settings.prompt_name("interact")
	if level.player.hidden:
		leave_wardrobe(delta)
		level.camcorder.focus("SALIR")
		level.ui.hint.text = ""
		level.ui.subtitle.text = ""
		level.ui.progress.visible = false
		return
	var target = focused_door()
	if not is_instance_valid(target) and not is_instance_valid(hiding_target): target = door_behind()
	var held := Input.is_action_pressed("interact")
	# Camcorder-style focus brackets replace the old control prompts.
	level.camcorder.focus("TECLADO" if is_instance_valid(lock_target) and not level.code_entered else "ENCENDER" if is_instance_valid(television_target) and not television_target.on else "LEER" if is_instance_valid(document_target) or is_instance_valid(hint_target) else panel_word(panel_target) if is_instance_valid(panel_target) else ("ESCONDERSE" if hiding_target.has_room() else "OCUPADO") if is_instance_valid(hiding_target) else ("CERRAR" if target.opened else "ABRIR") if is_instance_valid(target) else focused_teammate())
	if held and not was_held:
		pressed_door = target
		press_time = 0
		slow_used = false
	if held and is_instance_valid(pressed_door) and target == pressed_door:
		press_time += delta
		# The ring round the dot: how long is left before it goes slowly.
		level.ui.hold(1.0 if slow_used else press_time / SLOW_HOLD)
		if press_time >= SLOW_HOLD and not slow_used:
			level.match_net.use_door(pressed_door, true, false)
			slow_used = true
	elif held:
		pressed_door = null
		press_time = 0
	if was_held and not held:
		if is_instance_valid(pressed_door) and target == pressed_door and not slow_used:
			# Running into a door pushes it open (or shut) with a slam.
			var running := Vector2(level.player.velocity.x, level.player.velocity.z).length() > 4.6
			level.match_net.use_door(pressed_door, false, running)
		pressed_door = null
	was_held = held
	# Nothing is written about where the survivor stands: not the refuge and
	# what it still waits for, not the open door, not the car on its way back.
	# The door that opens and the lift that is not there say it themselves.
	level.ui.hint.text = ""
	level.ui.subtitle.text = ""
	if level.settings.values.subtitles and level.session.elapsed > 5 and level.session.elapsed < 10:
		level.ui.subtitle.text = "[Ventilación constante]"
	if not level.save_error.is_empty(): level.ui.subtitle.text = level.save_error

## The key in a wardrobe: touched, out as always; held, the doors are eased
## open for as long as it is and at the end of HIDE.QUIET_EXIT seconds the
## survivor steps out with far less to be heard (NOISE.QUIET of the way); let
## go before that, they fall shut and nothing has happened.
func leave_wardrobe(delta: float) -> void:
	var held := Input.is_action_pressed("interact")
	if not hide_armed:
		# Still the press that got them in.
		if not held: hide_armed = true
		was_held = held
		return
	if held:
		hide_hold += delta
		if hide_hold > HIDE_TAP:
			var share := clampf((hide_hold - HIDE_TAP) / (HIDE.QUIET_EXIT - HIDE_TAP), 0.0, 1.0)
			level.player.ease_out(share)
			level.ui.hold(share)
		if hide_hold >= HIDE.QUIET_EXIT:
			hide_hold = 0.0
			hide_armed = false
			level.match_net.use_hide(level.player.hiding_place, false, true)
	else:
		if hide_hold > 0.0 and hide_hold <= HIDE_TAP: level.match_net.use_hide(level.player.hiding_place, false)
		elif hide_hold > HIDE_TAP: level.player.ease_out(0.0)
		hide_hold = 0.0
	was_held = held
