extends SceneTree
## Phase 3 of The Lurker in Versus (.claude/specs/lurker_versus.md 6 and 4.3):
## her eyes at Alto, in --bots-hunt on floor 2. Settled over a lintel of
## planta 1 (lurker_stalk) with the places to lie in wait near her marked;
## a bot ahead with its torch on, its back to her. Then the bot turns to her
## and its torch blinds her, judged as the host judges it: the flash as it is
## born, from the torch's side (she looks a little away from it), and fading
## over the ducts' plan she bolted into. evidence/versus/f3/, capturas.txt.
##   godot --path . --script res://tools/capture/lurker_stalk_capture.gd -- --bots-hunt --floor=2 --bots=3 --seed=81 --test-profile
const OUT := "res://evidence/versus/f3/"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const SIZE := Vector2i(1280, 720)
const ALTO := 2
## bot_body.gd Pace.STILL.
const STILL := 0
## The bot this far along from her lintel; she looks this much off it.
const AHEAD := 5.5
const LOOK_OFF := 0.6
var level
var lurker
var driver
var bots: Array = []
var lines: Array = []

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
		print("STALK no lurker to drive")
		quit(1)
		return
	driver = lurker.driver
	driver.scripted = true
	lurker.grace = 0.0
	level.settings.set_designed(ALTO)
	level.apply_settings()
	# The bots' minds stopped: their bodies stand and look where they are put.
	var watch = level.get("bot_watch")
	if is_instance_valid(watch):
		watch.process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(watch.get("current")): watch.current.process_mode = Node.PROCESS_MODE_DISABLED
	for body in level.match_net.bodies.values():
		if is_instance_valid(body): bots.append(body)
	for bot in bots:
		bot.place(Vector3(0, -60, 0), 0.0)
		bot.torch_wanted = false
		bot.wish = Vector3.ZERO
		bot.pace = STILL
	level.player.held = true
	level.player.global_position = Vector3(0, -60, 0)
	level.player.torch.visible = false
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	var spot := find_spot()
	if spot.is_empty() or bots.is_empty():
		note("sin dintel (%s) o sin bots (%d)" % [str(spot), bots.size()])
		quit(1)
		return
	var site: Dictionary = lurker.stalk_sites[int(spot.site)]
	var way: Vector3 = spot.way
	note("dintel: sala %d, %s, ventana %.1f s" % [int(spot.room), str((site.point as Vector3).snapped(Vector3.ONE * 0.01)), float(level.tuning().back_window)])
	level.hotel.set_room_power(int(spot.room), false)
	# To the lintel from a metre off it, and settled.
	lurker.teleport(Vector3((site.point as Vector3).x, float(spot.py) + 1.0, (site.point as Vector3).z) + way * 0.8, NAN, &"captura")
	look(way.rotated(Vector3.UP, LOOK_OFF), -0.2)
	for i in 3: await physics_frame
	driver.asked[&"lurker_stalk"] = true
	for i in 480:
		await physics_frame
		if driver.settled(): break
	note("asentada: %s, sobre %s, sitios marcados %d, oscura %s, asiento %s, cámara %s" % [str(driver.settled()), "una banda" if driver.on_band() else "otra cosa", driver.view.marks.size(), str(driver.dark), str(driver.view.seat()), str(driver.camera.current)])
	var bot = bots[0]
	var stand: Vector3 = Vector3(lurker.face_point().x, float(spot.py), lurker.face_point().z) + way * AHEAD
	bot.place(stand, atan2(-way.x, -way.z))
	bot.torch_wanted = true
	bot.torch.visible = true
	bot.look_pitch = 0.0
	for i in 60:
		await physics_frame
		if lurker.fled_until > -1e9 or lurker.motion.in_duct:
			note("se fue antes de tiempo: %s, bot en %s mirando %s; %s" % [str(SIGHT.regarders(level, lurker.face_point(), [lurker.get_rid()])), str(bot.global_position.snapped(Vector3.ONE * 0.01)), str((-bot.camera.global_basis.z).snapped(Vector3.ONE * 0.01)), str(lurker.fled_until)])
			break
	await shot("f3_dintel_acecho.png")
	# The bot turns to her: its torch on her face blinds her (lurker.judge_light()).
	var was: float = driver.view.flash_clock
	var to: Vector3 = lurker.face_point() - bot.camera.global_position
	bot.look_yaw = atan2(-to.x, -to.z)
	bot.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	for i in 240:
		await process_frame
		if driver.view.flash_clock != was: break
	if driver.view.flash_clock == was:
		note("no hubo fogonazo: %s, gracia %.1f, oscura %s, asiento %s; %s" % [str(SIGHT.regarders(level, lurker.face_point(), [lurker.get_rid()])), lurker.grace, str(driver.dark), str(driver.view.seat()), " / ".join(lurker.debug_lines())])
		quit(1)
		return
	while driver.view.clock - driver.view.flash_clock < 0.05: await process_frame
	note("fogonazo naciendo, blanco %.2f, desde %s en su pantalla" % [driver.view.flash_now(), str(driver.view.flash_from)])
	await shot("f3_fogonazo_nace.png", 0)
	while driver.view.clock - driver.view.flash_clock < 0.6: await process_frame
	note("fogonazo sobre el plano, blanco %.2f, en ducto %s, en espera %s" % [driver.view.flash_now(), str(lurker.motion.in_duct), str(lurker.stunned())])
	await shot("f3_fogonazo_plano.png", 0)
	var text := FileAccess.open(OUT + "capturas.txt", FileAccess.WRITE)
	if text != null:
		for line in lines: text.store_line(line)
	print("STALK done")
	quit(0)

func note(words: String) -> void:
	lines.append(words)
	print("STALK ", words)

func look(way: Vector3, pitch: float) -> void:
	driver.yaw = atan2(-way.x, -way.z)
	driver.pitch = pitch

func shot(name: String, frames := 30) -> Image:
	level.hotel.update_visibility(driver.camera.global_position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(OUT + name)
	note("captura %s desde %s" % [name, str(driver.camera.global_position.snapped(Vector3.ONE * 0.01))])
	return image

## A lintel of planta 1 over a room that may be dark, no other site within
## 2 m, with a clear line AHEAD m along a way into its room:
## {site, room, way, py} (tests/office/lurker_stalk_test.gd's, shorter).
func find_spot() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	for i in lurker.stalk_sites.size():
		var site: Dictionary = lurker.stalk_sites[i]
		var room := int(site.room)
		if String(site.kind) != "door" or int(site.wing) != 0 or off.has(room) or not OFFICE.may_be_dark(level.manifest.rooms[room]): continue
		if lurker.stalk_sites.any(func(o): return o != site and int(o.wing) == 0 and Vector2((o.point as Vector3).x - (site.point as Vector3).x, (o.point as Vector3).z - (site.point as Vector3).z).length() < 2.0): continue
		var py := float(level.manifest.rooms[room].get("py", 0.0))
		var at: Vector3 = site.point
		for k in 16:
			var way := Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0))
			var good := true
			var metres := 1.0
			while metres <= AHEAD and good:
				var found := FLOOR.room_at(level.manifest.rooms, Vector3(at.x, py + 1.0, at.z) + way * metres)
				good = not found.is_empty() and int(found.id) == room
				metres += 0.5
			if good and SIGHT.clear(level, at, Vector3(at.x, py + 1.6, at.z) + way * AHEAD, [lurker.get_rid()]):
				return {"site": i, "room": room, "way": way, "py": py}
	return {}
