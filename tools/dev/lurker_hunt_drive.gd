extends SceneTree
## A session of --bots-hunt on floor 2 (godot.ps1 lurker-hunt) played through
## the real devices' path, for her presentation (.claude/specs/lurker_versus.md
## 13.9): key, button and mouse events put into Input as a person's would
## arrive, read by lurker_player.gd through the InputMap. The bots' minds are
## stopped and their bodies placed by the script for the moments that need
## them. Her view at Alto, in order: as the floor is up and 3 s later (she must
## not have moved); crawling the plenum over survivors; over a lit room; over
## an objective in use; by a way into the ducts; in their network, picking a
## far way out, on the way and arriving; down by a tile; a prey white, red for
## a look on where she would drop, red for a torch on it; the attack, its
## warning and the take; a torch turned on her in her warning, the flash and
## her flight. Then the polish (lurker_versus.md 11, «Estado del pulido»): a
## door slammed near her (its wave), a service gallery with no false ceiling,
## planta 3 in the dark, her keys and moves on a pad's events, and the flash
## with reduced effects. Her screen of fase 3 (cordura_y_edificio.md): the
## minds' colours, her disc waiting on a prey she struck twice, a torch far
## off and a beam, the warm steps of a walker, a coffee machine, her doubles
## from afar and what her drink would reach. Four shots of the view before
## fase 3 lead the sheet.
## evidence/versus/interfaz/*.png, sesion.txt and hoja.png.
##   godot --path . --script res://tools/dev/lurker_hunt_drive.gd -- --bots-hunt --floor=2 --bots=3 --seed=81 --test-profile
const OUT := "res://evidence/versus/interfaz/"
const BEFORE := "res://evidence/versus/doble/"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIZE := Vector2i(1280, 720)
const ALTO := 2
## bot_body.gd Pace.STILL.
const STILL := 0
var level
var lurker
var driver
var bots: Array = []
var log_lines: Array = []
var shots: Array = []
var clock := 0.0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 3600:
		await physics_frame
		lurker = level.get("creature")
		if is_instance_valid(lurker) and lurker.control == "player" and lurker.driver != null and level.session.state == level.session.State.PLAYING: break
	if not is_instance_valid(lurker) or lurker.control != "player":
		print("SESSION no lurker to drive")
		quit(1)
		return
	driver = lurker.driver
	# A click elsewhere on the desk must not pause it (hotel_main, focus out).
	level.automation = true
	level.settings.set_designed(ALTO)
	level.apply_settings()
	for title in ["02_plenum_supervivientes", "04_sala_encendida", "14_presa_blanca", "16_presa_roja_linterna"]:
		var old := Image.load_from_file(ProjectSettings.globalize_path(BEFORE + title + ".png"))
		if old != null and not old.is_empty(): shots.append(["antes_%s.png" % title, old])
	# As it loads: nothing touched, her and her camera where they were 3 s later.
	await shot("00_carga")
	var at_load: Vector3 = at()
	var camera_load: Vector3 = driver.camera.global_position
	await wait(3.0)
	note("3 s después de cargar, sin tocar nada: se movió %.3f m (%s a %s), la cámara %.3f m" % [at().distance_to(at_load), str(at_load), str(at()), driver.camera.global_position.distance_to(camera_load)])
	await shot("01_quieta_3s")
	var watch = level.get("bot_watch")
	if is_instance_valid(watch):
		watch.process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(watch.get("current")): watch.current.process_mode = Node.PROCESS_MODE_DISABLED
	for body in level.match_net.bodies.values():
		if is_instance_valid(body): bots.append(body)
	for bot in bots: park(bot)
	level.player.held = true
	level.player.global_position = Vector3(0, -60, 0)
	level.player.torch.visible = false
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	# A stage given back would put her elsewhere with a new grace: not in this drive.
	if level.session.revived.is_connected(level.on_revived): level.session.revived.disconnect(level.on_revived)
	lurker.grace = 0.0
	level.camcorder.announce("")
	note("en sus manos; %d bots quietos" % bots.size())
	await crawl_part()
	await screen_part()
	await lit_part()
	await busy_part()
	await double_part()
	await down_part()
	await noise_part()
	await prey_part()
	await gallery_part()
	await top_part()
	await pad_part()
	await reduced_part()
	var file := FileAccess.open(OUT + "sesion.txt", FileAccess.WRITE)
	if file != null:
		for line in log_lines: file.store_line(line)
	sheet()
	print("SESSION done, %d lines" % log_lines.size())
	quit(0)

func park(bot) -> void:
	bot.place(Vector3(0, -60, 0), 0.0)
	bot.torch_wanted = false
	bot.torch.visible = false
	bot.wish = Vector3.ZERO
	bot.pace = STILL

# --- Devices --------------------------------------------------------------------------

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	note("tecla %s %s" % [OS.get_keycode_string(code), "abajo" if down else "arriba"])

func tap(code: Key) -> void:
	key(code, true)
	await tick()
	await tick()
	key(code, false)

func click(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await tick()
	await tick()
	var up: InputEventMouseButton = event.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	note("clic %s" % ("izquierdo" if button == MOUSE_BUTTON_LEFT else "derecho"))

## The mouse moved so her camera turns toward a flat way, a share of what is left each tick.
func steer(way: Vector3, share := 0.25) -> void:
	if Vector2(way.x, way.z).length() < 1e-3: return
	var wanted := atan2(-way.x, -way.z)
	var left := wrapf(wanted - float(driver.yaw), -PI, PI)
	var sensitivity: float = level.settings.values.sensitivity
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-left * share / sensitivity, 0.0)
	Input.parse_input_event(event)

## Turned all the way, over a quarter second.
func turn_to(way: Vector3) -> void:
	for i in 15:
		steer(way, 0.3)
		await tick()

## The mouse up or down until her camera's tilt (over the ceiling) or pitch (down) is `wanted`.
func tilt_to(wanted: float) -> void:
	var sensitivity: float = level.settings.values.sensitivity
	for i in 15:
		var now: float = driver.pitch if driver.mode == "down" else driver.tilt
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(0.0, -(wanted - now) * 0.3 / sensitivity)
		Input.parse_input_event(event)
		await tick()

## Her camera tilted so `point` sits at `share` of the picture's height from
## the top: over her body, which hides the middle and below.
func frame(point: Vector3, share := 0.3) -> void:
	var best := -0.85
	var best_gap := INF
	for k in 10:
		var tilt := lerpf(-0.35, -1.35, k / 9.0)
		await tilt_to(tilt)
		if driver.camera.is_position_behind(point): continue
		var gap := absf(driver.camera.unproject_position(point).y / driver.camera.get_viewport().get_visible_rect().size.y - share)
		if gap < best_gap:
			best_gap = gap
			best = tilt
	await tilt_to(best)

func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await tick()
		left -= 1.0 / 60.0

func tick() -> void:
	await physics_frame
	clock += 1.0 / 60.0

func note(words: String) -> void:
	var line := "%6.2f %s" % [clock, words]
	log_lines.append(line)
	print("SESSION ", line)

func shot(title: String) -> void:
	level.hotel.update_visibility(lurker.motion.anchor(), true)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUT + "%s.png" % title)
	shots.append(["%s.png" % title, image])
	var info: Dictionary = driver.prey_info
	note("captura %s.png (cámara %s, presa %d %s)" % [title, String(driver.mode), int(driver.prey), "lista" if bool(info.get("ok", false)) else String(info.get("why", ""))])

## The shots in one sheet, three across, each with its name under it.
func sheet() -> void:
	if shots.is_empty(): return
	var cell := Vector2i(SIZE.x / 3, SIZE.y / 3)
	var rows := int(ceil(shots.size() / 3.0))
	var out := Image.create(cell.x * 3, cell.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var small: Image = (shots[i][1] as Image).duplicate()
		small.convert(Image.FORMAT_RGB8)
		small.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(small, Rect2i(Vector2i.ZERO, cell), Vector2i(cell.x * (i % 3), cell.y * (i / 3)))
	out.save_png(OUT + "hoja.png")

# --- The parts ------------------------------------------------------------------------

func at() -> Vector3: return lurker.motion.anchor()

func middle(room: int) -> Vector2:
	return Vector2(float(level.manifest.rooms[room].px), float(level.manifest.rooms[room].pz))

func centre(room: int) -> Vector3: return FLOOR.position_of(level.manifest.rooms[room])

func place_bot(bot, point: Vector3, look: Vector3, torch: bool) -> void:
	bot.place(point, atan2(-look.x, -look.z))
	bot.look_yaw = atan2(-look.x, -look.z)
	bot.look_pitch = atan2(look.y, Vector2(look.x, look.z).length())
	bot.torch_wanted = torch
	bot.torch.visible = torch

## Rooms of planta 1 under her ceilings, [id, area, lit], biggest first.
func her_rooms() -> Array:
	var out: Array = []
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or not lurker.shell.tray_of.has(id) or not OFFICE.false_ceiling(room): continue
		out.append([id, FLOOR.size_of(room).x * FLOOR.size_of(room).y, level.hotel.lit(id)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	return out

## W held toward a point until she is within `near` of it or the time is up.
func crawl_to(goal: Vector3, seconds: float, near := 0.8, half_shot := "") -> void:
	key(KEY_W, true)
	var left := seconds
	var start := Vector2(at().x, at().z).distance_to(Vector2(goal.x, goal.z))
	var shot_half := false
	while left > 0.0:
		var to := goal - at()
		var gone := Vector2(to.x, to.z).length()
		if gone < near: break
		if not shot_half and not half_shot.is_empty() and gone < start * 0.5:
			shot_half = true
			await shot(half_shot)
		steer(to)
		await tick()
		left -= 1.0 / 60.0
	key(KEY_W, false)

## Over two survivors on planta 1, one with its torch, crawling to them.
func crawl_part() -> void:
	var rooms := her_rooms()
	var dark: Array = rooms.filter(func(r: Array) -> bool: return not bool(r[2]))
	var pool: Array = dark if dark.size() >= 2 else rooms
	var a := int(pool[0][0])
	var b := int(pool[1][0]) if pool.size() > 1 else a
	place_bot(bots[0], centre(a) + Vector3(0.6, 0, 0), Vector3(1, 0, 0.3), true)
	place_bot(bots[1], centre(b), Vector3(0, 0, 1), false)
	var start := centre(a) + Vector3(-8.0, 1.0, -3.0)
	driver.to_plenum(start, a)
	await wait(0.3)
	await turn_to(centre(a) - at())
	await tilt_to(-0.85)
	await wait(0.4)
	note("en el plénum, dos supervivientes debajo (salas %d y %d), uno con linterna" % [a, b])
	key(KEY_W, true)
	await wait(0.4)
	await shot("02_plenum_supervivientes")
	key(KEY_W, false)
	await crawl_to(centre(a), 6.0, 5.0)
	await shot("03_plenum_encima")

## Over a lit room of hers, its fittings burning.
func lit_part() -> void:
	for bot in bots: park(bot)
	var lit: Array = her_rooms().filter(func(r: Array) -> bool: return bool(r[2]))
	if lit.is_empty():
		note("sin sala encendida en la planta 1")
		return
	var room := int(lit[0][0])
	driver.to_plenum(centre(room) + Vector3(-4.0, 1.0, 0.0), room)
	await wait(0.3)
	await turn_to(centre(room) - at())
	await wait(0.5)
	note("sobre la sala encendida %d" % room)
	await shot("04_sala_encendida")

## An objective's machine with somebody at it, seen from over the ceiling.
func busy_part() -> void:
	var files = level.objectives.get("files")
	if files == null or files.usables.is_empty():
		note("sin máquina de escribir")
		return
	var usable = files.usables[0]
	var point: Vector3 = usable.global_transform * Vector3(0, 0, usable.box.z * 0.5)
	var front: Vector3 = usable.global_basis.z
	place_bot(bots[0], point + Vector3(front.x, 0, front.z).normalized() * 0.9 + Vector3(0, -point.y + FLOOR.planta_y(FLOOR.planta_of(point.y)), 0), -front, false)
	var room := int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1))
	driver.to_plenum(point + Vector3(front.x, 0, front.z).normalized() * 3.5 + Vector3(0, 1, 0), room)
	await wait(0.3)
	await turn_to(point - at())
	await wait(0.8)
	note("un superviviente en la máquina de escribir: en uso %s" % str(driver.view.busy(point)))
	await shot("05_objetivo_en_uso")
	park(bots[0])

## Her screen of fase 3, over a dark room of planta 1.
func screen_part() -> void:
	var dark: Array = her_rooms().filter(func(r: Array) -> bool: return not bool(r[2]) and not level.point_protected(centre(int(r[0])) + Vector3(0, 1, 0)))
	if dark.size() < 2 or bots.size() < 3:
		note("sin salas oscuras o bots para la interfaz")
		return
	for bot in bots: park(bot)
	var room := int(dark[0][0])
	var c := centre(room)
	# Three minds, whole, half and nearly gone.
	var minds := [100.0, 50.0, 8.0]
	for i in 3:
		place_bot(bots[i], c + Vector3(-1.6 + 1.6 * i, 0, 0), Vector3(0, 0, 1), false)
		level.sanity.minds[int(bots[i].slot)] = {"sanity": minds[i], "rest": 0.0, "paid": 0.0}
	driver.view.drank_at = -INF
	driver.to_plenum(c + Vector3(0, 1, -5.5), room)
	await wait(0.3)
	await turn_to(c - at())
	await tilt_to(-0.85)
	await wait(0.6)
	note("tres mentes: %s, colores %s" % [str(bots.slice(0, 3).map(func(b) -> float: return snappedf(level.sanity.sanity_of(b), 0.1))), str(bots.slice(0, 3).map(func(b) -> String: return driver.view.mind_colour(level.sanity.sanity_of(b)).to_html(false)))])
	note("huella de beber: salas %s; [sala, con luz para ella, encendida, mermada, en sus salas con luz]: %s" % [str(driver.view.footprint), str(driver.view.footprint.map(func(id: int) -> Array: return [id, driver.view.glowing(id), level.hotel.lit(id), snappedf(float(level.hotel.drained(id)), 0.01), driver.view.lit_rooms.any(func(e: Array) -> bool: return int(e[1]) == id)]))])
	await shot("30_cordura_colores")
	# Her disc: waiting after an attack, on a prey struck twice already.
	driver.last_attack = driver.clock - 1.5
	var seat := int(bots[2].slot)
	driver.strikes[seat] = [2.0, driver.clock]
	await turn_to(bots[2].global_position - at())
	await wait(0.2)
	note("disco: presa %d, espera %.2f, le costaría %.2f de uno nuevo" % [driver.prey, float(driver.prey_info.get("wait", 0.0)), driver.strike_share(seat)])
	await shot("31_disco_espera_repetida")
	driver.strikes.clear()
	# A walker down a corridor (the room's long way when there is none 8 m
	# long), seen along it from over its end: from a side its walls hide its
	# floor, and across a room the desks do. Its warm steps.
	for bot in bots: park(bot)
	var hall := -1
	for r in her_rooms():
		var data: Dictionary = level.manifest.rooms[int(r[0])]
		if bool(data.get("corridor", false)) and maxf(FLOOR.size_of(data).x, FLOOR.size_of(data).y) >= 8.0 and not level.point_protected(centre(int(r[0])) + Vector3(0, 1, 0)):
			hall = int(r[0])
			break
	var walk_at := centre(hall if hall >= 0 else room)
	var size := FLOOR.size_of(level.manifest.rooms[hall if hall >= 0 else room])
	var along := Vector3(1, 0, 0) if size.x >= size.y else Vector3(0, 0, 1)
	var span := minf(maxf(size.x, size.y) * 0.4, 5.0)
	driver.to_plenum(walk_at - along * (span + 2.5) + Vector3(0, 1, 0), hall if hall >= 0 else room)
	await wait(0.3)
	await turn_to(along)
	await frame(walk_at, 0.3)
	for i in 150:
		bots[0].place(walk_at + along * lerpf(-span, span, i / 149.0), atan2(-along.x, -along.z))
		await tick()
	await wait(0.3)
	var first: Vector3 = driver.view.prints[0][0] if not driver.view.prints.is_empty() else Vector3.INF
	note("pasos por el pasillo %d: %d huellas, la primera en %s, el que anda en %s" % [hall, driver.view.prints.size(), str(first), str(bots[0].global_position)])
	await shot("32_pasos")
	# A torch on a wall near her: its beam.
	park(bots[0])
	driver.to_plenum(c + Vector3(0, 1, -5.5), room)
	await wait(0.3)
	await turn_to(c - at())
	var beam_way := Vector3(1, 0, 0)
	place_bot(bots[1], c - beam_way * 1.5, beam_way + Vector3(0, -0.6, 0), true)
	await wait(0.5)
	await frame(c + beam_way * 1.0, 0.35)
	note("haz: alcance %s" % str(driver.view.beam_reach))
	await shot("33_haz")
	park(bots[1])
	# A torch far off, through the walls.
	var far := -1
	var far_metres := 0.0
	for r in her_rooms():
		var metres := Vector2(centre(int(r[0])).x - c.x, centre(int(r[0])).z - c.z).length()
		if metres >= 45.0 and metres <= 75.0 and (far < 0 or absf(metres - 60.0) < absf(far_metres - 60.0)):
			far = int(r[0])
			far_metres = metres
	if far >= 0:
		place_bot(bots[1], centre(far), c - centre(far), true)
		await turn_to(centre(far) - at())
		await tilt_to(-0.3)
		await wait(0.9)
		note("linterna lejos: sala %d a %.0f m, baliza %s" % [far, far_metres, str(driver.view.beacons.keys())])
		await shot("34_linterna_lejos")
		park(bots[1])
	else: note("sin sala a 45 a 75 m")
	# A coffee machine of planta 1, somebody at it.
	var machine = null
	for one in level.coffee.machines:
		if is_instance_valid(one) and FLOOR.planta_of(one.global_position.y + 1.0) == 0: machine = one
	if machine != null:
		var front: Vector3 = machine.global_basis.z
		var aside: Vector3 = machine.global_basis.x
		place_bot(bots[0], machine.global_position + front * 0.5 + aside * 1.0, -front, false)
		var cup := int(FLOOR.room_at(level.manifest.rooms, machine.global_position + Vector3(0, 1, 0)).get("id", room))
		# From its side and further off, so neither the drinker nor her body hides it.
		driver.to_plenum(machine.global_position + front * 5.0 - aside * 5.0 + Vector3(0, 1, 0), cup)
		await wait(0.3)
		await turn_to(machine.global_position - at())
		await frame(machine.global_position + Vector3(0, 1.0, 0), 0.3)
		await wait(0.6)
		note("café en %s" % str(machine.global_position))
		await shot("35_cafe")
		park(bots[0])
	# Two doubles left, seen from afar.
	var other := int(dark[1][0])
	for r in [room, other]:
		driver.to_plenum(centre(r) + Vector3(0, 1, 0), r)
		await wait(0.3)
		lurker.double_at = -INF
		driver.doubled_at = -INF
		await tap(KEY_E)
		await wait(0.4)
	driver.to_plenum(c + Vector3(-12, 1, -8), room)
	await wait(0.3)
	await turn_to(c - at())
	await tilt_to(-0.5)
	await wait(0.5)
	note("dobles: %d" % lurker.doubles.doubles.size())
	await shot("36_dobles_lejos")
	for id in lurker.doubles.doubles.keys(): lurker.doubles.on_event([int(id), "gone"])

## Her double (the Doppelganger that took the place of her ducts): E over a
## room leaves it in the corner nearest her.
func double_part() -> void:
	var rooms: Array = her_rooms()
	if rooms.is_empty(): return
	var room := int(rooms[0][0])
	driver.to_plenum(FLOOR.position_of(level.manifest.rooms[room]) + Vector3(0, 1.0, 0), room)
	await wait(0.4)
	lurker.double_at = -INF
	driver.doubled_at = -INF
	await tap(KEY_E)
	await wait(0.5)
	note("E sobre la sala %d: dobles %d, rechazados %d" % [room, lurker.doubles.doubles.size(), lurker.doubles_refused])
	await tilt_to(-0.55)
	await shot("06_doble")
	await wait(0.4)
	await shot("07_doble_tecla")

func down_part() -> void:
	var dark: Array = her_rooms().filter(func(r: Array) -> bool: return lurker.ducts.room_tiles.has(int(r[0])))
	if dark.is_empty(): return
	var room := int(dark[0][0])
	driver.to_plenum(centre(room) + Vector3(0, 1, 0), room)
	await wait(0.4)
	await tilt_to(-1.2)
	await wait(0.2)
	await shot("11_placa_para_bajar")
	await tap(KEY_SPACE)
	await wait(0.25)
	await shot("12_bajando")
	await wait(1.0)
	note("abajo: en un techo %s, cámara %s, a %.2f m de su cara, lado %d" % [str(lurker.motion.surface()), String(driver.mode), driver.camera.global_position.distance_to(lurker.face_point()), int(driver.side)])
	await shot("13_abajo")
	# Looking round the room with the mouse.
	await turn_to(driver.forward().rotated(Vector3.UP, 0.6))
	await tilt_to(-0.7)
	await wait(0.2)
	await shot("13b_abajo_mira")
	await tap(KEY_SPACE)
	await wait(1.0)
	note("arriba otra vez: plénum %s" % str(lurker.motion.plenum))

## A dark room of planta 1 with tiles, 7 m at least, for the prey.
func prey_room() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	var best := {}
	var longest := 7.0
	for id in lurker.ducts.room_tiles:
		var room: Dictionary = level.manifest.rooms[int(id)]
		if int(room.wing) != 0 or off.has(int(id)) or not lurker.shell.tray_of.has(int(id)) or not OFFICE.false_ceiling(room) or not OFFICE.may_be_dark(room): continue
		var size := FLOOR.size_of(room)
		if level.point_protected(FLOOR.position_of(room) + Vector3(0, 1, 0)) or maxf(size.x, size.y) < longest: continue
		longest = maxf(size.x, size.y)
		best = {"room": int(id), "centre": FLOOR.position_of(room), "way": Vector3(1, 0, 0) if size.x >= size.y else Vector3(0, 0, 1)}
	return best

func prey_part() -> void:
	var spot := prey_room()
	if spot.is_empty() or bots.size() < 2:
		note("sin sala para la presa o sin bots")
		return
	for bot in bots: park(bot)
	var way: Vector3 = spot.way
	var middle_at: Vector3 = spot.centre
	level.hotel.set_room_power(int(spot.room), false)
	var prey = bots[0]
	var witness = bots[1]
	var stand := middle_at + way * 1.0
	place_bot(prey, stand, way, false)
	driver.to_plenum(stand - way * 5.0 + Vector3(0, 1, 0), int(spot.room))
	await wait(0.3)
	await turn_to(stand - at())
	await tilt_to(-0.9)
	for i in 60:
		if bool(driver.prey_info.get("ok", false)): break
		await tick()
	note("presa: %s" % str(driver.prey_info))
	await shot("14_presa_blanca")
	# A run's noise where it stands, as her view gets one (lurker_view.listen()).
	driver.view.ripple(prey.global_position + Vector3(0, 0.05, 0), driver.view.NOISE.radius("run"), 2.0)
	await wait(0.15)
	note("la oye correr: %d ondas" % driver.view.ripples.size())
	await shot("14b_onda_carrera")
	# A witness beside the prey looking past it at where her face would be.
	var drop: Dictionary = driver.prey_info.get("drop", {})
	var face: Vector3 = drop.get("face", stand - way * 1.8 + Vector3(0, 2.4, 0))
	var witness_at := stand - way * 3.0 + Vector3(way.z, 0, way.x) * 1.5
	place_bot(witness, witness_at, face - (witness_at + Vector3(0, 1.6, 0)), false)
	await wait(0.4)
	note("con un testigo que mira: %s" % str(driver.prey_info))
	await shot("15_presa_roja_mirada")
	witness.torch_wanted = true
	witness.torch.visible = true
	# A torch just on is cold half a second (lurker_versus.md 4.2).
	await wait(0.8)
	note("con su linterna: %s; marcas %d vértices, a través %d" % [str(driver.prey_info), driver.view.marks.mesh.get_faces().size(), driver.view.marks_through.mesh.get_faces().size()])
	await shot("16_presa_roja_linterna")
	park(witness)
	await wait(2.4)
	note("sin testigo, vigilada: %s, carga %.2f" % [str(driver.prey_info), float(driver.charge)])
	await click(MOUSE_BUTTON_LEFT)
	for i in 60:
		await tick()
		if String(driver.attack.get("phase", "")) == "drop": break
	await shot("17_ataque_cae")
	for i in 60:
		await tick()
		if driver.strike > 0.99: break
	note("encuadre de la presa: %.2f, cámara a %.2f m de su pecho" % [float(driver.strike), driver.camera.global_position.distance_to(prey.global_position + Vector3(0, 1.1, 0))])
	await shot("17b_ataque_encuadre")
	for i in 120:
		await tick()
		if lurker.cue: break
	note("aviso: %s" % str(lurker.warning.ledger.back() if not lurker.warning.ledger.is_empty() else {}))
	await shot("18_aviso")
	for i in 240:
		await tick()
		if not level.execution.is_empty(): break
	await wait(0.4)
	note("captura: %s" % str(level.execution))
	await shot("19_captura")
	# The flash: another bot, its torch on, back to her; it turns in her warning.
	# After a take she is quiet near it a while (lurker_brain.sated): out of it first.
	await wait(float(lurker.brain.sated) + 0.5)
	var lit_one = bots[2] if bots.size() > 2 else witness
	var other := middle_at - way * 1.0
	place_bot(lit_one, other, -way, true)
	await wait(0.8)
	driver.to_plenum(other + way * 4.5 + Vector3(0, 1, 0), int(spot.room))
	await wait(0.3)
	await turn_to(other - at())
	await wait(0.6)
	note("segunda presa: %s" % str(driver.prey_info))
	await click(MOUSE_BUTTON_LEFT)
	for i in 180:
		await tick()
		if lurker.cue: break
	var flash_was: float = driver.view.flash_clock
	if lurker.cue:
		await wait(0.2)
		var to: Vector3 = lurker.face_point() - lit_one.camera.global_position
		lit_one.look_yaw = atan2(-to.x, -to.z)
		lit_one.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
		for i in 10:
			await tick()
			if driver.view.flash_clock != flash_was: break
		# The bot's turn did not blind her (its torch follows its own look):
		# the judge's own way off, as when it does (lurker.scare_off()).
		if driver.view.flash_clock == flash_was:
			note("el giro del bot no la ciega; la ciega el juez a mano (lurker.scare_off)")
			lurker.scare_off(true, int(lit_one.slot), lurker.face_point())
		await tick()
		await shot("20_fogonazo")
		await wait(0.35)
		await shot("21_huye")
		await wait(1.5)
		note("tras el fogonazo: %s, cámara %s" % ["arriba" if driver.up() else "abajo", String(driver.mode)])
		await shot("22_huida_arriba")
		# Sent off, that warning is called off (lurker.scare_off()): no take.
		for i in 600:
			if level.execution.is_empty() and not lurker.scene_held and lurker.warning.active.is_empty(): break
			await tick()
		note("aquel aviso acabó: %s %s" % [String(lurker.warning.ledger.back().get("outcome", "")), String(lurker.warning.ledger.back().get("reason", ""))])
	else: note("la segunda presa no empezó aviso: %s" % str(driver.prey_info))

## A door of the room under her slammed: the wave of what she hears.
func noise_part() -> void:
	var spot := prey_room()
	if spot.is_empty(): return
	var room := int(spot.room)
	var door = null
	for one in level.hotel.doors:
		var at: Vector3 = one.doorway
		if absf(at.y - float(level.manifest.rooms[room].py)) < 2.0 and Vector2(at.x - centre(room).x, at.z - centre(room).z).length() < 12.0 and (door == null or Vector2(at.x - centre(room).x, at.z - centre(room).z).length() < Vector2(door.doorway.x - centre(room).x, door.doorway.z - centre(room).z).length()): door = one
	if door == null:
		note("sin puerta cerca para el ruido")
		return
	var doorway: Vector3 = door.doorway
	driver.to_plenum(doorway + (centre(room) - doorway).normalized() * 5.0 + Vector3(0, 2.0, 0), room)
	await wait(0.3)
	await turn_to(doorway - at())
	await tilt_to(-1.0)
	await wait(0.3)
	door.toggle(false, true, true)
	await wait(0.05)
	note("portazo en %s: %d ondas" % [str(doorway), driver.view.ripples.size()])
	await shot("13c_ruido_portazo")

## A service gallery (no false ceiling): on its slab, in sight, and crawling it.
func gallery_part() -> void:
	var best := -1
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or not lurker.shell.tray_of.has(id) or OFFICE.false_ceiling(room) or FLOOR.is_void(room): continue
		# The longest of planta 1.
		var size := FLOOR.size_of(room)
		if best < 0 or maxf(size.x, size.y) > maxf(FLOOR.size_of(level.manifest.rooms[best]).x, FLOOR.size_of(level.manifest.rooms[best]).y): best = id
	if best < 0:
		note("sin galería de servicio")
		return
	for bot in bots: park(bot)
	driver.to_plenum(centre(best) + Vector3(0, 1, 0), best)
	await wait(0.3)
	# Along its long way.
	var size := FLOOR.size_of(level.manifest.rooms[best])
	await turn_to(Vector3(1, 0, 0) if size.x >= size.y else Vector3(0, 0, 1))
	await wait(0.3)
	note("galería %d (planta %d): galería %s, arriba %s, cámara %s" % [best, int(level.manifest.rooms[best].get("wing", -1)) + 1, str(driver.gallery()), str(driver.up()), String(driver.mode)])
	await shot("23_galeria")
	var from: Vector3 = at()
	key(KEY_W, true)
	var m = lurker.motion
	for i in 4:
		await wait(0.25)
		note("  W: %.2f m/s (ritmo %.2f), empuje %s, tramos %d, ráfagas %s, aviso %s, huida %s, ataque %s, cruce %s" % [m.speed, m.pace, str(m.free_way), m.legs.size(), str(m.in_bursts()), str(lurker.cue), str(m.bolting), str(driver.attack), str(lurker.motion.transit.get("phase", ""))])
	key(KEY_W, false)
	await wait(0.3)
	note("por la galería: %.2f m en 1 s, galería %s" % [Vector2(at().x - from.x, at().z - from.z).length(), str(driver.gallery())])
	await shot("24_galeria_avanza")

## Planta 3 in the dark, from over its ceiling.
func top_part() -> void:
	var best := -1
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 2 or not lurker.shell.tray_of.has(id) or not OFFICE.false_ceiling(room): continue
		if best < 0 or FLOOR.size_of(room).x * FLOOR.size_of(room).y > FLOOR.size_of(level.manifest.rooms[best]).x * FLOOR.size_of(level.manifest.rooms[best]).y: best = id
	if best < 0:
		note("sin sala en la planta 3")
		return
	driver.to_plenum(centre(best) + Vector3(0, 1, 0), best)
	await wait(1.0)
	note("planta 3, sala %d: plénum %s, planta %d, encendida %s; su cuerpo visible %s a %.2f m de su punto; cámara a %.2f m sobre el suelo" % [best, str(lurker.motion.plenum), driver.planta() + 1, str(level.hotel.lit(best)), str(lurker.visual.is_visible_in_tree()), lurker.visual.global_position.distance_to(at()), driver.camera.global_position.y - FLOOR.planta_y(2)])
	await shot("25_planta3")

func pad_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func pad_button(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)

func pad_tap(button: JoyButton) -> void:
	pad_button(button, true)
	await tick()
	await tick()
	pad_button(button, false)

## On a pad's events (no pad can be plugged in from a script: the hints are
## told one is): the stick moves her, the other turns her camera, each button
## does its action, and her keys along the foot name the pad's.
func pad_part() -> void:
	var spot := prey_room()
	if spot.is_empty(): return
	for bot in bots: park(bot)
	level.hints.pad_said = true
	driver.to_plenum((spot.centre as Vector3) + Vector3(-3, 1, 0), int(spot.room))
	await wait(0.3)
	var from: Vector3 = at()
	pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	await wait(0.8)
	pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await wait(0.3)
	note("mando, stick izquierdo 0,8 s: %.2f m (usa mando %s)" % [Vector2(at().x - from.x, at().z - from.z).length(), str(level.settings.using_pad)])
	var yaw_was: float = driver.yaw
	pad_axis(JOY_AXIS_RIGHT_X, 1.0)
	await wait(0.5)
	pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	await wait(0.3)
	note("stick derecho 0,5 s: la cámara gira %.2f rad" % absf(wrapf(driver.yaw - yaw_was, -PI, PI)))
	pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	pad_axis(JOY_AXIS_LEFT_X, 1.0)
	await wait(0.4)
	note("LB mantenido: sigilo %s a %.2f m/s" % [str(driver.sneaking), lurker.motion.speed])
	pad_axis(JOY_AXIS_LEFT_X, 0.0)
	pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	var distance_was: float = driver.distance
	await pad_tap(JOY_BUTTON_RIGHT_SHOULDER)
	await wait(0.1)
	note("RB: la cámara de %.1f a %.1f m" % [distance_was, driver.distance])
	await wait(0.3)
	await shot("26_mando_plenum")
	await pad_tap(JOY_BUTTON_A)
	await wait(1.2)
	note("A: abajo %s, cámara %s" % [str(not driver.up()), String(driver.mode)])
	var clip_was: String = lurker.intent_clip
	await pad_tap(JOY_BUTTON_Y)
	await wait(0.1)
	note("Y: asomarse, pose %s (antes %s)" % [lurker.intent_clip, clip_was])
	await wait(1.3)
	pad_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await wait(0.1)
	pad_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	note("LT: beber pedido; sala bebida %s" % str(lurker.get("deep_room")))
	await shot("27_mando_abajo")
	pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait(0.1)
	pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	note("RT: atacar sin presa, nada: ataque %s" % str(driver.attack))
	await pad_tap(JOY_BUTTON_A)
	await wait(1.2)
	note("A otra vez: arriba %s" % str(driver.up()))
	lurker.double_at = -INF
	driver.doubled_at = -INF
	var made: int = lurker.doubles.doubles.size()
	await pad_tap(JOY_BUTTON_X)
	await wait(0.4)
	note("X: doble %s" % str(lurker.doubles.doubles.size() > made))
	await shot("28_mando_doble")
	note("teclas con mando: %s" % str(driver.view.rows().map(func(row: Array) -> Array: return row[0])))
	level.hints.pad_said = false

## Reduced effects: the flash half as far and steady.
func reduced_part() -> void:
	var spot := prey_room()
	if spot.is_empty(): return
	level.settings.values.reduced = true
	level.apply_settings()
	driver.to_plenum((spot.centre as Vector3) + Vector3(0, 1, 0), int(spot.room))
	await wait(0.3)
	driver.go_down()
	await wait(1.2)
	driver.view.immune_until = -1.0
	driver.view.flash(-driver.camera.global_basis.z)
	var values: Array = []
	for i in 30:
		await tick()
		values.append(snappedf(driver.view.flash_now(), 0.01))
		if i == 9: await shot("29_reducidos_fogonazo")
	note("fogonazo con efectos reducidos, %s (tope %.2f)" % [str(values), driver.view.REDUCED_PEAK])
	level.settings.values.reduced = false
	level.apply_settings()
