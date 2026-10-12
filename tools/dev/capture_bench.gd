extends SceneTree
## The bench of the capture (docs/EXECUTION.md, phase 0): any way of being
## caught, in any light, as many times as it takes to look at it.
##
## Played (./tools/godot.ps1 bench, or "Banco de capturas.cmd"): you are the
## survivor in the biggest room of the floor and the creature is brought to
## you whenever you ask. How it catches you is up to you, as in the game:
## look at it, turn your back, crouch, have the sheet open. The keys are on
## the screen: the lunge that tears the picture or not (the comparison the
## author has to judge), the light, how it ends, and a way in forced whatever
## you do. A floor lost to it starts again by itself.
##
## With "-- --sheet=<name>" nobody plays: one capture is staged and its frames
## at fixed seconds are laid out on one picture, evidence/capture_<name>.png
## (the whole death in an image), and it quits. For a sheet:
##   --entry=front|back|side|above|busy|wardrobe   how (front)
##   --light=room|lamp|torch|dark                  what lights it (room)
##   --ending=leave|glance                         how it ends (leave)
##   --outside                                     seen by somebody standing by
##   --tear                                        the lunge tears the picture
##   --soft, --reduced                             soft startle, reduced effects
##   --character=0|1|2                             whose body (2, the Exploradora)
##   --seed=N, --times=a,b,c                       the floor, and other seconds
##   --full                                        every frame whole as well
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SCORE := preload("res://game/app/capture_score.gd")
const TIMES := [0.02, 0.05, 0.1, 0.3, 0.5, 0.62, 0.75, 0.9, 1.05, 1.5, 2.0, 2.5, 2.8, 3.1, 3.5, 4.1]
const THUMB := Vector2i(640, 360)
const COLUMNS := 4
var level
var options := {"entry": "front", "light": "room", "ending": "leave", "seed": 81}
var sheet := ""
var times: Array = TIMES
var board: Label
var tear := false
var light := 0
var forced_entry := 0
var forced_ending := 0
const LIGHTS := ["room", "torch", "dark"]
const ENTRIES := ["", "front", "back", "side", "above"]
const ENDINGS := ["", "leave", "glance"]

func _initialize() -> void: run.call_deferred()

func read_options() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sheet="): sheet = argument.trim_prefix("--sheet=")
		elif argument.begins_with("--times="):
			times = []
			for piece in argument.trim_prefix("--times=").split(","): times.append(float(piece))
		elif argument.begins_with("--") and argument.contains("="):
			var pair := argument.trim_prefix("--").split("=")
			options[pair[0]] = pair[1]
		elif argument.begins_with("--"): options[argument.trim_prefix("--")] = true

## The biggest room that is not the refuge: space enough to be caught in.
func staging_room() -> Dictionary:
	var best := {}
	var best_area := 0.0
	for room in level.manifest.rooms:
		# Of the first sector, and nowhere the creature may not take anybody.
		if int(room.get("wing", 0)) != 0 or FLOOR.is_void(room) or level.point_protected(FLOOR.position_of(room)): continue
		var span: Vector2 = FLOOR.size_of(room)
		if span.x * span.y > best_area:
			best_area = span.x * span.y
			best = room
	return best

func set_light(kind: String) -> void:
	var dark := kind in ["torch", "dark"]
	if is_instance_valid(level.hotel) and level.hotel.dark != dark: level.hotel.blackout(dark)
	level.player.torch.visible = kind == "torch"
	level.player.snap_torch()

## Everybody where a capture can start from: the survivor in the middle of the
## room, the creature `apart` metres from it on the side `where` says.
func stage(where: String, apart: float) -> void:
	var room := staging_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var span: Vector2 = FLOOR.size_of(room)
	var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var player = level.player
	if not level.execution.is_empty(): level.release_execution()
	player.reset_survival()
	player.global_position = centre
	player.velocity = Vector3.ZERO
	player.rotation.y = atan2(-along.x, -along.z)
	player.camera.rotation = Vector3.ZERO
	player.active = true
	player.held = false
	player.snap_torch()
	level.session.participants[player.slot] = level.session.Life.EXPLORING
	var creature = level.locust
	var side := along.cross(Vector3.UP)
	var offset := along * apart
	match where:
		"back": offset = -along * apart
		"side": offset = side * apart
	creature.global_position = centre + offset
	creature.rotation.y = atan2(offset.x, offset.z)
	creature.velocity = Vector3.ZERO
	creature.grace = 0.0
	creature.detection = 0.0
	creature.focus = null
	creature.set_mode(creature.Mode.PATROL)
	creature.destination = creature.global_position
	if is_instance_valid(level.director):
		level.director.queue_free()
		level.director = null
	level.clear_screen_cues()
	level.camera_cut()

func run() -> void:
	read_options()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(int(options.seed))
	if options.has("reduced"): level.settings.values.reduced = true
	if options.has("soft"): level.settings.values["startle"] = false
	# A sheet is of the body the scene is built on, whoever played last.
	if not sheet.is_empty() or options.has("character"): level.settings.values.character = int(options.get("character", 2))
	level.apply_settings()
	if sheet.is_empty(): await play()
	else: await take_sheet()
	level.queue_free()
	await process_frame
	quit()

# --- A sheet ------------------------------------------------------------------------

func take_sheet() -> void:
	var entry := String(options.entry)
	level.windup_tear = options.has("tear")
	level.locust.set_physics_process(false)
	stage("back" if entry == "back" else "side" if entry == "side" else "front", 1.5)
	set_light(String(options.light))
	if String(options.light) == "lamp":
		var lamp := OmniLight3D.new()
		lamp.light_energy = 2.5
		lamp.omni_range = 10.0
		lamp.position = level.player.global_position + Vector3(1.5, 2.5, 1.0)
		level.add_child(lamp)
	var player = level.player
	if entry == "busy": level.toggle_sheet()
	for i in 40: await process_frame
	# Crouched, and left so: nobody is at the keys of a sheet to hold it.
	if entry == "above":
		player.MOVEMENT.set_crouch(player, true)
		player.set_physics_process(false)
		player.eye_height = 0.9
		player.camera.position.y = 0.9
		for i in 4: await process_frame
	var view: Camera3D = null
	if options.has("outside"):
		view = Camera3D.new()
		view.fov = 58.0
		level.add_child(view)
		var middle: Vector3 = (player.global_position + level.locust.global_position) * 0.5
		var across: Vector3 = (level.locust.global_position - player.global_position).cross(Vector3.UP).normalized()
		view.global_position = middle + across * 3.6 + Vector3.UP * 1.7
		view.look_at(middle + Vector3.UP * 1.3)
	level.executions.forced = {"glance": String(options.ending) == "glance"}
	if entry in ["front", "back", "side", "above"]: level.executions.forced["entry"] = entry
	level.capture_survivor(player)
	player.set_physics_process(true)
	print("CAPTURE_AS ", level.execution.get("entry", "?"), " crouched=", level.execution.get("crouched", false), " busy=", level.tape.busy, " dark=", level.tape.dark, " torch=", level.execution.get("torch", false))
	if level.execution.is_empty(): print("CAPTURE_REFUSED life=", level.session.participants.get(player.slot), " state=", level.session.state, " protected=", level.point_protected(player.global_position), " riding=", level.lifts.riding, " spare=", level.spare.is_valid(), " client=", level.net.is_client(), " locust=", is_instance_valid(level.locust), " at=", player.global_position)
	if view != null: view.current = true
	var columns := COLUMNS
	var rows := int(ceil(float(times.size()) / float(columns)))
	var page := Image.create(THUMB.x * columns, THUMB.y * rows, false, Image.FORMAT_RGB8)
	var next := 0
	var taken: Array = []
	while next < times.size():
		await process_frame
		if level.execution.is_empty() and level.lost_signal <= 0.0: break
		var now: float = float(level.execution.time) if not level.execution.is_empty() else SCORE.END_TIME + 0.1
		if now < float(times[next]): continue
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		# "--full": each frame kept whole as well, beside the sheet.
		if options.has("full"): frame.save_png("res://evidence/capture_%s_%03d.png" % [sheet, int(round(float(times[next]) * 100.0))])
		frame.convert(Image.FORMAT_RGB8)
		frame.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
		page.blit_rect(frame, Rect2i(Vector2i.ZERO, THUMB), Vector2i((next % columns) * THUMB.x, (next / columns) * THUMB.y))
		taken.append(snappedf(now, 0.01))
		next += 1
	page.save_png("res://evidence/capture_%s.png" % sheet)
	var tape = level.tape
	print("CAPTURE_SHEET ", sheet, " entry=", entry, " light=", options.light, " frames=", taken, " take=", tape.take.get("kind", -1), " tried=", tape.take.get("tried", 0), " valid=", tape.take.get("valid", 0), " covered=", tape.take.get("covered", 0.0), " rest=", (tape.take.get("rest", Transform3D.IDENTITY) as Transform3D).origin)

# --- Played -------------------------------------------------------------------------

func build_board() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	level.add_child(layer)
	board = Label.new()
	board.position = Vector2(24, 24)
	board.add_theme_font_size_override("font_size", 15)
	board.add_theme_color_override("font_color", Color(0.85, 0.87, 0.8))
	board.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	board.add_theme_constant_override("shadow_offset_x", 1)
	board.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(board)

func write_board() -> void:
	var lines := [
		"BANCO DE CAPTURAS",
		"G    que venga a por ti (desde 9 m)        H    captura inmediata",
		"T    desgarro de la embestida: %s" % ("SÍ (como era)" if tear else "NO (medio segundo limpio)"),
		"L    luz: %s" % {"room": "la sala", "torch": "a oscuras, con linterna", "dark": "a oscuras, sin nada"}[LIGHTS[light]],
		"1    entrada: %s" % ("la que toque" if forced_entry == 0 else {"front": "de frente", "back": "por la espalda", "side": "de lado", "above": "desde arriba"}[ENTRIES[forced_entry]]),
		"2    final: %s" % ("el que toque" if forced_ending == 0 else {"leave": "se va", "glance": "mira la lente"}[ENDINGS[forced_ending]]),
		"R    volver a empezar",
		"",
		"Cómo te coge depende de ti: mírala, dale la espalda, agáchate, abre la hoja.",
	]
	if not level.execution.is_empty(): lines.append("\n%.2f s · %s · cámara: %s" % [float(level.execution.time), String(level.execution.entry), ["ve", "ve a medias", "boca abajo"][int(level.tape.take.get("kind", 0))] if not level.tape.take.is_empty() else "—"])
	board.text = "\n".join(lines)

func apply_forced() -> void:
	var forced := {}
	if forced_entry > 0: forced["entry"] = ENTRIES[forced_entry]
	if forced_ending > 0: forced["glance"] = ENDINGS[forced_ending] == "glance"
	level.executions.forced = forced
	level.windup_tear = tear

## The creature put beside the survivor where the way in asked for needs it:
## ahead of where they look, behind them or at their side.
func bring_close() -> void:
	var player = level.player
	var ahead := -Basis(Vector3.UP, player.rotation.y).z
	var way := ahead
	match ENTRIES[forced_entry]:
		"back": way = -ahead
		"side": way = ahead.cross(Vector3.UP)
	var creature = level.locust
	creature.global_position = player.global_position + way * 1.5
	creature.rotation.y = atan2(way.x, way.z)
	creature.velocity = Vector3.ZERO

func restage() -> void:
	if level.session.state != level.session.State.PLAYING: await level.start_floor(level.session.run_seed)
	stage("front", 9.0)
	set_light(LIGHTS[light])
	level.locust.set_physics_process(false)

func play() -> void:
	build_board()
	await restage()
	var was := {}
	var over := 0.0
	var last := Time.get_ticks_msec()
	while true:
		await process_frame
		if not is_instance_valid(level) or level.session.state == level.session.State.MENU: break
		var now := Time.get_ticks_msec()
		var delta := float(now - last) / 1000.0
		last = now
		var pressed := {}
		for key in [KEY_G, KEY_H, KEY_T, KEY_L, KEY_1, KEY_2, KEY_R]:
			var down := Input.is_physical_key_pressed(key)
			pressed[key] = down and not bool(was.get(key, false))
			was[key] = down
		if pressed[KEY_T]: tear = not tear
		if pressed[KEY_L]:
			light = (light + 1) % LIGHTS.size()
			set_light(LIGHTS[light])
		if pressed[KEY_1]: forced_entry = (forced_entry + 1) % ENTRIES.size()
		if pressed[KEY_2]: forced_ending = (forced_ending + 1) % ENDINGS.size()
		apply_forced()
		# A floor that ended with that death: its end is left on screen a
		# moment, and then it is staged again.
		over = over + delta if level.session.state != level.session.State.PLAYING else 0.0
		if pressed[KEY_R] or over > 4.0:
			over = 0.0
			await restage()
		if level.session.state != level.session.State.PLAYING: continue
		if pressed[KEY_G] and level.execution.is_empty():
			# It has seen you: it shrieks, runs and lunges, as in a floor.
			var creature = level.locust
			creature.set_physics_process(true)
			creature.focus = level.player
			creature.last_known = level.player.global_position
			creature.detection = 1.2
			creature.set_mode(creature.Mode.ALERT)
		if pressed[KEY_H] and level.execution.is_empty():
			bring_close()
			level.locust.set_physics_process(true)
			level.capture_survivor(level.player)
		write_board()
