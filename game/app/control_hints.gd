extends RefCounted
## Control hints for the first games (the author, 16 November 2026): a key in
## its keycap and what it does, at the foot of the picture, the first time each
## thing comes up in a game (hotel_ui.show_controls). On for the first
## HINT_GAMES games of each floor reached and off by itself after them; the box
## under the sensitivity in Controles turns them on or off again (settings
## "control_hints", the games counted in "hint_games" for the floor in
## "hint_floor": reaching floor 2 turns them on for its own five).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HINT_GAMES := 5
## A dark room entered with the torch off says F, in this many rooms a game.
const DARK_ROOMS := 5
## Seconds into a game before Tab is shown, if nothing read showed it first.
const SHEET_AFTER := 30.0
## Seconds a card of hints stays up, and once one of its keys is pressed (the
## author, 16 November 2026).
const SHOWN_FOR := 5.0
const HEEDED := 0.3
## The keys that heed each card. The keypad's card goes when the keypad closes.
const HEEDS := {"door": ["interact"], "hide": ["interact"], "inside": ["forward", "interact"], "container": ["interact"], "tv": ["interact"], "read": ["interact"], "reading": ["interact"], "panel": ["interact"], "keypad": ["interact"], "lift": ["interact"], "usable": ["interact"], "torch": ["flashlight"], "sheet": ["sheet"], "hunter": ["interact", "sprint", "locust_trace", "flashlight"]}
## The kind of the card up.
var kind_up := ""
var level
## What was shown this game, by kind; the dark rooms it was shown in.
var shown := {}
var dark_rooms := {}
var last_room := -1
var clock := 0.0
## Cards waiting their turn, and how long the one up has left.
var queue: Array = []
var left := 0.0

func on() -> bool:
	return bool(level.settings.values.control_hints) and not level.observer and not level.bot_match

## A floor about to be played (populate_floor): it is one game more, and what
## was shown is forgotten.
func begin() -> void:
	shown.clear()
	dark_rooms.clear()
	queue.clear()
	last_room = -1
	clock = 0.0
	left = 0.0
	level.ui.show_controls([])
	if level.observer or level.bot_match: return
	# Written straight into the values and saved: set_value() applies every
	# setting again, the graphics too, as the floor starts.
	var values: Dictionary = level.settings.values
	var number: int = level.session.floor_number
	if number > int(values.hint_floor):
		values.hint_floor = number
		values.hint_games = 0
		values.control_hints = true
	if number != int(values.hint_floor): return
	values.hint_games = int(values.hint_games) + 1
	# Once, as the next game begins: turned back on by hand, they stay on.
	if int(values.hint_games) == HINT_GAMES + 1: values.control_hints = false
	level.settings.save_settings()

## Every frame of play (hotel_main, after drive_local).
func tick(delta: float) -> void:
	if left > HEEDED and heeded(): left = HEEDED
	if left > 0.0:
		left -= delta
		if left <= 0.0: next()
	if not on():
		if left > 0.0 or not queue.is_empty(): clear()
		return
	clock += delta
	if level.match_net.local_is_locust():
		if clock > 1.5: offer("hunter")
		return
	if not level.local_alive(): return
	if clock > SHEET_AFTER: offer("sheet")
	var room := FLOOR.room_at(level.manifest.rooms, level.player.global_position)
	var id := int(room.get("id", -1))
	if id == last_room: return
	last_room = id
	if id < 0 or level.hotel.lit(id) or level.player.torch.visible or dark_rooms.has(id) or dark_rooms.size() >= DARK_ROOMS: return
	dark_rooms[id] = true
	push(rows("torch"), "torch")

## What the player is on this frame (interaction.drive_local): the card for
## it, the first time in the game.
func aimed(kind: String, word := "", hold := false) -> void:
	if not on() or kind.is_empty(): return
	if kind == "usable":
		if shown.has("usable:" + word): return
		shown["usable:" + word] = true
		push([[["MANTÉN", key("interact")] if hold else [key("interact")], word.left(1).to_upper() + word.substr(1).to_lower()]], "usable")
		return
	offer(kind)

func offer(kind: String) -> void:
	if shown.has(kind): return
	shown[kind] = true
	push(rows(kind), kind)

func push(card: Array, kind: String) -> void:
	if card.is_empty(): return
	queue.append([kind, card])
	if left <= 0.0: next()

func next() -> void:
	if queue.is_empty():
		left = 0.0
		kind_up = ""
		level.ui.show_controls([])
		return
	left = SHOWN_FOR
	var item: Array = queue.pop_front()
	kind_up = item[0]
	level.ui.show_controls(item[1])

func clear() -> void:
	queue.clear()
	left = 0.0
	kind_up = ""
	level.ui.show_controls([])

## Whether the player just did what the card up says.
func heeded() -> bool:
	if kind_up == "typing": return not level.lock_open
	if kind_up == "hunter" and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)): return true
	for action in HEEDS.get(kind_up, []):
		if InputMap.has_action(action) and Input.is_action_just_pressed(action): return true
	return false

## An action's key, or its button on a pad.
func key(action: String) -> String:
	return level.settings.prompt_name(action).to_upper()

func on_pad() -> bool:
	return level.settings.using_pad and level.settings.pad_present()

## A card: rows of [keys, what they do]. "MANTÉN" before a key says to hold it.
func rows(kind: String) -> Array:
	var settings = level.settings
	var pad := on_pad()
	var e := key("interact")
	match kind:
		"sheet": return [[[key("sheet")], "Abrir la hoja"]]
		"torch": return [[[key("flashlight")], "Encender la linterna"]]
		"door": return [[[e], "Abrir o cerrar"], [["MANTÉN", e], "Despacio, sin ruido"]]
		"hide": return [[[e], "Esconderte"]]
		"inside": return [[["MANTÉN", "STICK IZQ. ↑" if pad else key("forward")], "Asomarte"], [[e], "Salir"], [["MANTÉN", e], "Salir sin ruido"]]
		"container": return [[["MANTÉN", e], "Registrar"]]
		"tv": return [[[e], "Encender la tele"]]
		"read": return [[[e], "Leer"]]
		"reading": return [[[e], "Dejar de leer"]]
		"panel": return [[[e], "Abrir el cuadro y dar la corriente"]]
		"keypad": return [[[e], "Usar el teclado"]]
		"typing": return [] if pad else [[["0 A 9"], "Teclear el código"], [["RETROCESO"], "Borrar"], [["ESC"], "Salir"]]
		"lift": return [[[e], "Pulsar el botón"]]
		"hunter":
			return [
				[[settings.trigger_name(true)] if pad else ["CLIC IZQ."], "Atacar"],
				[[settings.trigger_name(false)] if pad else ["CLIC DER."], "Chillar y escuchar"],
				[[key("sprint")], "Cazar a toda velocidad"],
				# On a pad the trace is the torch button (locust_player.gd).
				[[key("flashlight") if pad else key("locust_trace")], "Rastro hasta una tele encendida"],
				[[e], "Abrir puertas y armarios, pasar por una tele"],
			]
	return []
