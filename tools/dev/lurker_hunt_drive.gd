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
## her flight. evidence/versus/presentacion/*.png, sesion.txt and hoja.png.
##   godot --path . --script res://tools/dev/lurker_hunt_drive.gd -- --bots-hunt --floor=2 --bots=3 --seed=81 --test-profile
const OUT := "res://evidence/versus/presentacion/"
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
	lurker.grace = 0.0
	level.camcorder.announce("")
	note("en sus manos; %d bots quietos" % bots.size())
	await crawl_part()
	await lit_part()
	await busy_part()
	await duct_part()
	await down_part()
	await prey_part()
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

func duct_part() -> void:
	var ducts = lurker.ducts
	var best := -1
	var nearest := INF
	for e in ducts.exits.size():
		if not driver.travel_exit(e) or int(ducts.node_wings[int(ducts.exits[e].node)]) != 0: continue
		var d := Vector2((ducts.exits[e].position as Vector3).x - at().x, (ducts.exits[e].position as Vector3).z - at().z).length()
		if d < nearest:
			nearest = d
			best = e
	if best < 0: return
	var exit: Dictionary = ducts.exits[best]
	driver.to_plenum((exit.position as Vector3) + Vector3(2.5, 0, 0), int(exit.room))
	await wait(0.3)
	await turn_to((exit.position as Vector3) - at())
	await crawl_to(exit.position, 4.0, 1.2)
	await wait(0.4)
	note("junto a la rejilla %d: la toma %s" % [best, str(driver.entrance() == best)])
	await shot("06_entrada_ducto")
	await tap(KEY_E)
	await wait(0.5)
	await tilt_to(-0.55)
	await shot("07_red_ductos")
	var far := -1
	for entry in driver.trip.get("targets", []):
		if float(entry[1]) > 15.0 and float(entry[1]) < 45.0: far = int(entry[0])
	if far >= 0: await turn_to((ducts.exits[far].position as Vector3) - (exit.position as Vector3))
	await wait(0.3)
	note("elegida la salida %d (%s)" % [int(driver.trip.get("pick", -1)), "la lejana" if int(driver.trip.get("pick", -1)) == far else "otra"])
	await shot("08_salida_elegida")
	var started := clock
	await click(MOUSE_BUTTON_LEFT)
	for i in 600:
		await tick()
		if driver.trip_done() >= 0.45: break
	var metres := float(driver.trip.get("length", 0.0))
	await shot("09_viaje")
	for i in 900:
		if driver.trip.is_empty(): break
		await tick()
	note("viaje de %.1f m en %.1f s; sale %s" % [metres, clock - started, "al plénum" if lurker.motion.plenum else "a su galería"])
	await wait(0.4)
	await shot("10_llegada")

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
	note("abajo: en un techo %s, cámara %s" % [str(lurker.motion.surface()), String(driver.mode)])
	await shot("13_abajo")
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
		for i in 60:
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
	else: note("la segunda presa no empezó aviso: %s" % str(driver.prey_info))
