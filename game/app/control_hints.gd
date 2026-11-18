extends RefCounted
## Control hints for the first games (the author, 16 November 2026): a key in
## its keycap and what it does, at the foot of the picture, the first time each
## thing comes up in a game (hotel_ui.show_controls). On for the first
## HINT_GAMES games of each floor reached and off by itself after them; the box
## under the sensitivity in Controles turns them on or off again (settings
## "control_hints", the games counted in "hint_games" for the floor in
## "hint_floor": reaching floor 2 turns them on for its own five).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SETTINGS := preload("res://game/services/settings_service.gd")
const HINT_GAMES := 5
## A dark room entered with the torch off says F, in this many rooms a game.
const DARK_ROOMS := 5
## Seconds into a game before Tab is shown, if nothing read showed it first.
const SHEET_AFTER := 30.0
## Seconds a card stays up. Each of its hints goes HEEDED seconds after it is
## done, alone (the others stay, at least REST_AFTER more, to be tried too).
const SHOWN_FOR := 5.0
const HEEDED := 0.3
const REST_AFTER := 3.0
## Held this long, a key is held ("MANTÉN"); let go sooner, it was a touch.
const HOLD := 0.4
## The keys whose touches and holds are told apart.
const TRACKED := ["interact", "forward"]
var level
## What was shown this game, by kind; the dark rooms it was shown in.
var shown := {}
var dark_rooms := {}
var last_room := -1
var clock := 0.0
## Cards waiting their turn, and how long the one up has left.
var queue: Array = []
var left := 0.0
## The hints of the card up: what does each one ({heeds}), and the seconds
## until a done one goes ("wait", -1 not done) and whether it has ("gone").
var up: Array = []
## A line of words alone (notice()) is up: it stays with the hints off.
var notice_up := false
## Seconds each tracked key has been held, and the ones let go this frame
## after a touch.
var held := {}
var tapped := {}

func on() -> bool:
	return bool(level.settings.values.control_hints) and not level.observer and not level.bot_match

## A floor about to be played (populate_floor): it is one game more, and what
## was shown is forgotten.
func begin() -> void:
	shown.clear()
	dark_rooms.clear()
	last_room = -1
	clock = 0.0
	clear()
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
	track(delta)
	heed(delta)
	if left > 0.0:
		left -= delta
		if left <= 0.0: next()
	if not on():
		if (left > 0.0 and not notice_up) or not queue.is_empty(): clear()
		return
	clock += delta
	if level.match_net.local_is_locust():
		# Her keys are always along the foot (lurker_view.rows()): no card for them.
		if clock > 1.5 and level.kind.CREATURE_KEY == &"locust": offer("hunter")
		return
	if not level.local_alive(): return
	if clock > SHEET_AFTER: offer("sheet")
	var room := FLOOR.room_at(level.manifest.rooms, level.player.global_position)
	var id := int(room.get("id", -1))
	if id == last_room: return
	last_room = id
	if id < 0 or level.hotel.lit(id) or level.player.torch.visible or dark_rooms.has(id) or dark_rooms.size() >= DARK_ROOMS: return
	dark_rooms[id] = true
	push(rows("torch"))

## Touches and holds of the tracked keys.
func track(delta: float) -> void:
	tapped.clear()
	for action: String in TRACKED:
		if not InputMap.has_action(action): continue
		var was := float(held.get(action, 0.0))
		if Input.is_action_pressed(action): held[action] = was + delta
		else:
			if was > 0.0 and was < HOLD: tapped[action] = true
			held[action] = 0.0

## Each hint done goes HEEDED seconds later, alone; the last takes the card.
func heed(delta: float) -> void:
	if up.is_empty(): return
	var going := false
	for index in up.size():
		var hint: Dictionary = up[index]
		if hint.gone: continue
		if float(hint.wait) < 0.0 and done(hint.heeds):
			hint.wait = HEEDED
			left = maxf(left, REST_AFTER)
		if float(hint.wait) < 0.0: continue
		hint.wait = float(hint.wait) - delta
		if float(hint.wait) > 0.0: continue
		hint.gone = true
		going = true
		if up.any(func(other): return not other.gone): level.ui.fade_control(index)
	if going and up.all(func(other): return other.gone): next()

## Whether the player just did one of these: an action pressed, "tap:" or
## "hold:" one of TRACKED, "mouse_left" / "mouse_right", "digit" and
## "backspace" (the keypad's keys), "lock" (the keypad closed) and "out" (out
## of the wardrobe).
func done(heeds: Array) -> bool:
	for heed_id: String in heeds:
		if heed_id.begins_with("tap:"):
			if tapped.has(heed_id.trim_prefix("tap:")): return true
		elif heed_id.begins_with("hold:"):
			if float(held.get(heed_id.trim_prefix("hold:"), 0.0)) >= HOLD: return true
		else:
			match heed_id:
				"mouse_left": if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return true
				"mouse_right": if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): return true
				"backspace": if Input.is_physical_key_pressed(KEY_BACKSPACE): return true
				"lock": if not level.lock_open: return true
				"out": if not level.player.hidden: return true
				"digit":
					for code in range(KEY_0, KEY_9 + 1):
						if Input.is_physical_key_pressed(code): return true
				_: if InputMap.has_action(heed_id) and Input.is_action_just_pressed(heed_id): return true
	return false

## What the player is on this frame (interaction.drive_local): the card for
## it, the first time in the game.
func aimed(kind: String, word := "", hold := false) -> void:
	if not on() or kind.is_empty(): return
	if kind == "usable":
		if shown.has("usable:" + word): return
		shown["usable:" + word] = true
		push([[["MANTÉN", key("interact")] if hold else [key("interact")], word.left(1).to_upper() + word.substr(1).to_lower(), ["hold:interact" if hold else "interact"]]])
		return
	offer(kind)

func offer(kind: String) -> void:
	if shown.has(kind): return
	shown[kind] = true
	push(rows(kind))

func push(card: Array) -> void:
	if card.is_empty(): return
	queue.append(card)
	if up.is_empty(): next()

func next() -> void:
	up.clear()
	notice_up = false
	if queue.is_empty():
		left = 0.0
		level.ui.show_controls([])
		return
	left = SHOWN_FOR
	var card: Array = queue.pop_front()
	for row in card: up.append({"heeds": row[2], "wait": -1.0, "gone": false})
	level.ui.show_controls(card)

func clear() -> void:
	queue.clear()
	up.clear()
	notice_up = false
	left = 0.0
	level.ui.show_controls([])

## Words at the foot of the picture, where the hints go, for `seconds`, hints
## on or off ("Te sientes mejor...", coffee.gd): over whatever card was up.
func notice(words: String, seconds: float) -> void:
	queue.clear()
	up.clear()
	left = seconds
	notice_up = true
	level.ui.show_controls([[[], words, []]])

## An action's key, or its button on a pad.
func key(action: String) -> String:
	return level.settings.prompt_name(action).to_upper()

## Her keys are fixed, not bound (settings_service.LURKER_ACTIONS): named from
## there, a mouse button or a trigger as the hunter's card names them.
func lurker_keys(action: String) -> Array:
	var pair: Array = SETTINGS.LURKER_ACTIONS[action]
	if pair[1] is Array:
		var right := int(pair[1][0]) == JOY_AXIS_TRIGGER_RIGHT
		return [level.settings.trigger_name(right) if on_pad() else ("CLIC IZQ." if right else "CLIC DER.")]
	return [(level.settings.button_name(int(pair[1])) if on_pad() else OS.get_keycode_string(int(pair[0]))).to_upper()]

## A script cannot plug a pad in: the drive with a pad's events
## (tools/dev/lurker_hunt_drive.gd) says one is there.
var pad_said := false

func on_pad() -> bool:
	return level.settings.using_pad and (pad_said or level.settings.pad_present())

## A card: rows of [keys, what they do, what does it (done())]. "MANTÉN"
## before a key says to hold it.
func rows(kind: String) -> Array:
	var settings = level.settings
	var pad := on_pad()
	var e := key("interact")
	match kind:
		"sheet": return [[[key("sheet")], "Abrir la hoja", ["sheet"]]]
		"torch": return [[[key("flashlight")], "Encender la linterna", ["flashlight"]]]
		"door": return [[[e], "Abrir o cerrar", ["tap:interact"]], [["MANTÉN", e], "Despacio, sin ruido", ["hold:interact"]]]
		"hide": return [[[e], "Esconderte", ["interact"]]]
		"inside": return [[["MANTÉN", "STICK IZQ. ↑" if pad else key("forward")], "Asomarte", ["hold:forward", "out"]], [[e], "Salir", ["tap:interact", "out"]], [["MANTÉN", e], "Salir sin ruido", ["hold:interact", "out"]]]
		"container": return [[["MANTÉN", e], "Registrar", ["hold:interact"]]]
		"tv": return [[[e], "Encender la tele", ["interact"]]]
		"read": return [[[e], "Leer", ["interact"]]]
		"reading": return [[[e], "Dejar de leer", ["interact"]]]
		"panel": return [[[e], "Abrir el cuadro y dar la corriente", ["interact"]]]
		"keypad": return [[[e], "Usar el teclado", ["interact"]]]
		"typing": return [] if pad else [[["0 A 9"], "Teclear el código", ["digit", "lock"]], [["RETROCESO"], "Borrar", ["backspace", "lock"]], [["ESC"], "Salir", ["lock"]]]
		"lift": return [[[e], "Pulsar el botón", ["interact"]]]
		"coffee": return [[[e], "Tomar un café", ["interact"]]]
		"hunter":
			return [
				[[settings.trigger_name(true)] if pad else ["CLIC IZQ."], "Atacar", ["mouse_left", "locust_strike"]],
				[[settings.trigger_name(false)] if pad else ["CLIC DER."], "Chillar y escuchar", ["mouse_right", "locust_shriek"]],
				[[key("sprint")], "Cazar a toda velocidad", ["sprint"]],
				# On a pad the trace is the torch button (locust_player.gd).
				[[key("flashlight") if pad else key("locust_trace")], "Rastro hasta una tele encendida", ["flashlight" if pad else "locust_trace"]],
				[[e], "Abrir puertas y armarios, pasar por una tele", ["interact"]],
			]
		# Her keys (settings_service.LURKER_ACTIONS) and what each is called, as
		# her view writes them along the foot (lurker_view.rows(), 13.9).
		"lurker":
			return [
				[lurker_keys("lurker_release"), "Atacar", ["mouse_left", "lurker_release"]],
				[lurker_keys("lurker_drop"), "Bajar", ["lurker_drop"]],
				[["MANTÉN"] + lurker_keys("lurker_sneak"), "Sigilo", ["lurker_sneak"]],
				[lurker_keys("lurker_double"), "Doppelgänger", ["lurker_double"]],
				[lurker_keys("lurker_drink"), "Beber la luz", ["mouse_right", "lurker_drink"]],
				[lurker_keys("lurker_peek"), "Asomarse", ["lurker_peek"]],
			]
	return []
