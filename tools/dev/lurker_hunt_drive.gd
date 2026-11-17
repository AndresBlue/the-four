extends SceneTree
## A session of --bots-hunt on floor 2 (godot.ps1 lurker-hunt) played through
## the real devices' path, after the rehecho (.claude/specs/lurker_versus.md 13):
## key, button and mouse events put into Input as a person's would arrive,
## read by lurker_player.gd through the InputMap. The bots' minds are stopped
## and their bodies placed by the script for the moments that need them. In
## the plenum of planta 1 she crawls her department end to end, then slowly;
## into the ducts by a grille, a far way out picked by turning to it, the trip
## and out; down by a tile and up; a bot marked as her prey, red while
## another looks at where she would drop, red with a torch there, red far
## off, then green with her charge full; the attack, the warning and the take;
## another bot turns its torch on her in her warning: the flash and her flight
## up. What she did, with times, and her view at Alto in
## evidence/versus/rehecho/sesion*.png, sesion.txt and hoja.png.
##   godot --path . --script res://tools/dev/lurker_hunt_drive.gd -- --bots-hunt --floor=2 --bots=3 --seed=81 --test-profile
const OUT := "res://evidence/versus/rehecho/"
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
var stuck := 0.0
var worst_stuck := 0.0

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
	level.settings.set_designed(ALTO)
	level.apply_settings()
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
	note("en sus manos; gracia %.1f s; %d bots quietos" % [float(lurker.grace), bots.size()])
	await shot("00_gracia")
	while lurker.grace > 0.0: await tick()
	await crawl_part()
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

func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await tick()
		left -= 1.0 / 60.0

func tick() -> void:
	await physics_frame
	clock += 1.0 / 60.0
	if int(round(clock * 60.0)) % 30 == 0:
		var m = lurker.motion
		var where := "plénum" if m.plenum else ("techo %d" % m.room() if m.surface() else ("ducto" if m.in_duct else "paso"))
		note("%s, %.2f m/s, cámara %s, presa %d %s, sigilo %s, tramos %s, colgada %s, en el suelo %s" % [where, float(m.speed) if not m.plenum else driver.velocity.length(), String(driver.mode), int(driver.prey), str(driver.prey_info.get("why", "")) if not bool(driver.prey_info.get("ok", false)) else "lista", str(driver.sneaking), str(m.legs.map(func(l): return String(l.kind))), str(m.state.lowered) if m.surface() else "-", str(m.on_floor)])

func note(words: String) -> void:
	var line := "%6.2f %s" % [clock, words]
	log_lines.append(line)
	print("SESSION ", line)

func shot(title: String) -> void:
	level.hotel.update_visibility(driver.camera.global_position, true)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUT + "sesion_%s.png" % title)
	shots.append(["sesion_%s.png" % title, image])
	note("captura sesion_%s.png (cámara %s)" % [title, String(driver.mode)])

## The shots in one sheet, three across.
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

## Her department's longest way of rooms on planta 1 (as lurker_player_test).
func longest_way() -> Array:
	var graph := {}
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or not lurker.shell.tray_of.has(id) or not OFFICE.false_ceiling(room): continue
		var half := FLOOR.size_of(room) * 0.5
		var near: Array = []
		for side in [Vector2(-half.x - 0.2, 0), Vector2(half.x + 0.2, 0), Vector2(0, -half.y - 0.2), Vector2(0, half.y + 0.2)]:
			var other := FLOOR.room_at(level.manifest.rooms, Vector3(float(room.px) + side.x, float(room.py) + 1.0, float(room.pz) + side.y))
			if not other.is_empty() and lurker.shell.tray_of.has(int(other.id)) and OFFICE.false_ceiling(other) and int(other.sector) == int(room.sector): near.append(int(other.id))
		graph[id] = near
	var best: Array = []
	for start in graph:
		var way: Array = farthest(graph, int(farthest(graph, int(start)).back()))
		if way.size() > best.size(): best = way
	return best

func farthest(graph: Dictionary, start: int) -> Array:
	var parent := {start: -1}
	var queue := [start]
	var last := start
	while not queue.is_empty():
		var r: int = queue.pop_front()
		last = r
		for n in graph[r]:
			if parent.has(n): continue
			parent[n] = r
			queue.append(n)
	var way: Array = []
	var r := last
	while r >= 0:
		way.push_front(r)
		r = int(parent[r])
	return way

func middle(room: int) -> Vector2:
	return Vector2(float(level.manifest.rooms[room].px), float(level.manifest.rooms[room].pz))

## W held, the mouse turning her to each next room's middle.
func crawl_through(way: Array, seconds: float, half_shot := "") -> bool:
	var k := 0
	key(KEY_W, true)
	var left := seconds
	var shot_half := false
	while left > 0.0:
		var goal := middle(int(way[k]))
		if Vector2(at().x, at().z).distance_to(goal) < 0.7:
			k += 1
			if k >= way.size(): break
			if not shot_half and not half_shot.is_empty() and k >= way.size() / 2:
				shot_half = true
				await shot(half_shot)
			goal = middle(int(way[k]))
		steer(Vector3(goal.x - at().x, 0, goal.y - at().z))
		var before := at()
		await tick()
		left -= 1.0 / 60.0
		stuck = stuck + 1.0 / 60.0 if before.distance_to(at()) < 0.005 else 0.0
		worst_stuck = maxf(worst_stuck, stuck)
	key(KEY_W, false)
	return k >= way.size()

func crawl_part() -> void:
	var way := longest_way()
	note("recorrido del plénum, planta 1: %d salas %s" % [way.size(), str(way)])
	driver.to_plenum(Vector3(middle(int(way[0])).x, FLOOR.planta_y(0) + 1.0, middle(int(way[0])).y), int(way[0]))
	await wait(0.3)
	await turn_to(Vector3(middle(int(way[1])).x - at().x, 0, middle(int(way[1])).y - at().z))
	await shot("01_plenum_inicio")
	var started := clock
	var done := await crawl_through(way, 90.0, "02_plenum_mitad")
	note("de punta a punta: %s en %.1f s, quieta como mucho %.2f s" % [str(done), clock - started, worst_stuck])
	await shot("03_plenum_fin")
	# Slowly back three rooms, Shift held.
	key(KEY_SHIFT, true)
	var back := way.slice(maxi(0, way.size() - 4))
	back.reverse()
	worst_stuck = 0.0
	started = clock
	var slow := await crawl_through(back, 40.0)
	key(KEY_SHIFT, false)
	note("en sigilo: %s en %.1f s, quieta como mucho %.2f s" % [str(slow), clock - started, worst_stuck])
	key(KEY_SHIFT, true)
	key(KEY_W, true)
	await wait(0.6)
	await shot("04_sigilo")
	key(KEY_W, false)
	key(KEY_SHIFT, false)

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
	if nearest > 6.0:
		note("la rejilla más cercana a %.1f m: allí directamente" % nearest)
		driver.to_plenum((exit.position as Vector3) + Vector3(2.0, 0, 0), int(exit.room))
	await wait(0.3)
	# Up to it.
	key(KEY_W, true)
	for i in 240:
		var to: Vector3 = (exit.position as Vector3) - at()
		if Vector2(to.x, to.z).length() < 1.0: break
		steer(to)
		await tick()
	key(KEY_W, false)
	await wait(0.4)
	note("junto a la rejilla %d: la toma %s" % [best, str(driver.entrance() == best)])
	await shot("05_rejilla")
	await tap(KEY_E)
	await wait(0.3)
	await shot("06_ductos_elegir")
	var far := -1
	for entry in driver.trip.get("targets", []):
		if float(entry[1]) > 20.0 and float(entry[1]) < 45.0: far = int(entry[0])
	if far >= 0: await turn_to((ducts.exits[far].position as Vector3) - (exit.position as Vector3))
	await wait(0.2)
	note("elegida la salida %d (%s)" % [int(driver.trip.get("pick", -1)), "la lejana" if int(driver.trip.get("pick", -1)) == far else "otra"])
	await shot("07_ductos_elegida")
	var started := clock
	await tap(KEY_E)
	for i in 600:
		await tick()
		if driver.trip_done() >= 0.45: break
	var metres := float(driver.trip.get("length", 0.0))
	await shot("08_ductos_viaje")
	for i in 900:
		if driver.trip.is_empty(): break
		await tick()
	note("viaje de %.1f m en %.1f s; sale %s" % [metres, clock - started, "al plénum" if lurker.motion.plenum else "a su galería"])
	await wait(0.4)
	await shot("09_ductos_salida")

func down_part() -> void:
	# Over the biggest room of hers with tiles near her.
	var room := -1
	var area := 0.0
	for id in lurker.ducts.room_tiles:
		var r: Dictionary = level.manifest.rooms[int(id)]
		if int(r.wing) != 0 or not OFFICE.false_ceiling(r) or not lurker.shell.tray_of.has(int(id)): continue
		var a := FLOOR.size_of(r).x * FLOOR.size_of(r).y
		if a > area and level.hotel.lit(int(id)):
			area = a
			room = int(id)
	if room < 0: return
	driver.to_plenum(Vector3(middle(room).x, FLOOR.planta_y(0) + 1.0, middle(room).y), room)
	await wait(0.4)
	await tap(KEY_SPACE)
	await wait(1.0)
	note("abajo: en un techo %s, cámara %s, sala encendida %s" % [str(lurker.motion.surface()), String(driver.mode), str(level.hotel.lit(room))])
	await shot("10_abajo_sala_encendida")
	await tap(KEY_SPACE)
	await wait(1.0)
	note("arriba otra vez: plénum %s" % str(lurker.motion.plenum))
	await shot("11_arriba")

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

func place_bot(bot, point: Vector3, look: Vector3, torch: bool) -> void:
	bot.place(point, atan2(-look.x, -look.z))
	bot.look_yaw = atan2(-look.x, -look.z)
	bot.look_pitch = atan2(look.y, Vector2(look.x, look.z).length())
	bot.torch_wanted = torch
	bot.torch.visible = torch

func prey_part() -> void:
	var spot := prey_room()
	if spot.is_empty() or bots.size() < 2:
		note("sin sala para la presa o sin bots")
		return
	var way: Vector3 = spot.way
	var centre: Vector3 = spot.centre
	level.hotel.set_room_power(int(spot.room), false)
	var prey = bots[0]
	var witness = bots[1]
	var stand := centre + way * 1.0
	place_bot(prey, stand, way, false)
	# Her over the tile behind it, far first.
	driver.to_plenum(stand - way * 9.0 + Vector3(0, 1, 0), int(spot.room))
	await wait(0.3)
	await turn_to(stand - at())
	await wait(0.4)
	note("presa lejos: %s" % str(driver.prey_info))
	await shot("12_presa_lejos")
	driver.to_plenum(stand - way * 1.5 + Vector3(0, 1, 0), int(spot.room))
	await wait(0.3)
	await turn_to(stand - at())
	await wait(0.3)
	for i in 60:
		if bool(driver.prey_info.get("ok", false)): break
		await tick()
	note("presa cerca: %s" % str(driver.prey_info))
	# A witness beside the prey looking past it at where her face would be.
	var drop: Dictionary = driver.prey_info.get("drop", {})
	var face: Vector3 = drop.get("face", stand - way * 1.8 + Vector3(0, 2.4, 0))
	var witness_at := stand + way * 2.5 + Vector3(way.z, 0, way.x) * 1.5
	place_bot(witness, witness_at, face - (witness_at + Vector3(0, 1.6, 0)), false)
	await wait(0.4)
	note("con un testigo que mira: %s" % str(driver.prey_info))
	await shot("13_presa_te_mira")
	witness.torch_wanted = true
	witness.torch.visible = true
	# A torch just on is cold half a second (lurker_versus.md 4.2).
	await wait(0.8)
	note("con su linterna: %s" % str(driver.prey_info))
	await shot("14_presa_luz")
	park(witness)
	await wait(2.4)
	note("sin testigo, vigilada: %s, carga %.2f" % [str(driver.prey_info), float(driver.charge)])
	await shot("15_presa_lista_carga")
	await click(MOUSE_BUTTON_LEFT)
	for i in 60:
		await tick()
		if String(driver.attack.get("phase", "")) == "drop": break
	await shot("16_ataque_cae")
	for i in 120:
		await tick()
		if lurker.cue: break
	note("aviso: %s" % str(lurker.warning.ledger.back() if not lurker.warning.ledger.is_empty() else {}))
	await shot("17_aviso")
	for i in 240:
		await tick()
		if not level.execution.is_empty(): break
	await wait(0.4)
	note("captura: %s" % str(level.execution))
	await shot("18_captura")
	# The flash: another bot, its torch on, back to her; it turns in her warning.
	# After a take she is quiet near it a while (lurker_brain.sated): out of it first.
	await wait(float(lurker.brain.sated) + 0.5)
	var lit_one = bots[2] if bots.size() > 2 else witness
	var other := centre - way * 1.0
	place_bot(lit_one, other, -way, true)
	await wait(0.8)
	driver.to_plenum(other + way * 1.5 + Vector3(0, 1, 0), int(spot.room))
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
		await shot("19_fogonazo")
		await wait(0.25)
		await shot("20_huye")
		await wait(1.5)
		note("tras el fogonazo: %s, cámara %s" % ["arriba" if driver.up() else "abajo", String(driver.mode)])
		await shot("21_huida_arriba")
	else: note("la segunda presa no empezó aviso: %s" % str(driver.prey_info))
