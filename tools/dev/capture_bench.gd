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
##   --entry=front|back|side|above|busy|wardrobe|ambush   how (front); in a
##                                                 wardrobe, times under 0 are
##                                                 of what leads to it
##   --light=room|lamp|torch|dark                  what lights it (room)
##   --ending=leave|glance                         how it ends (leave)
##   --outside                                     seen by somebody standing by
##   --tear                                        the lunge tears the picture
##   --soft, --reduced                             soft startle, reduced effects
##   --brief                                       the short version (seen before)
##   --difficulty=apacible                         the floor's (the settings')
##   --character=0|1|2                             whose body (2, the Exploradora)
##   --seed=N, --times=a,b,c                       the floor, and other seconds
##   --wall=0.4 [--corner]                         their back to a wall, that far
##   --full                                        every frame whole as well
##   --large                                       big frames, two to a row
##   --act=peek|leave|quiet|wait, --ideal, --big   in a wardrobe (see below)
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SCORE := preload("res://game/app/capture_score.gd")
const TIMES := [0.02, 0.05, 0.1, 0.3, 0.5, 0.62, 0.75, 0.9, 1.05, 1.5, 2.0, 2.5, 2.8, 3.1, 3.5, 4.1]
## Each frame's size on the sheet and how many go in a row ("--large": twice
## the size, two to a row, for looking closely at a few).
var THUMB := Vector2i(640, 360)
var COLUMNS := 4
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
	if options.has("large"):
		THUMB = Vector2i(1280, 720)
		COLUMNS = 2

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
	# "--wall=0.4": their back that far from the wall of the room behind them
	# (and "--corner": in the corner of it), where a body has no room to lie.
	if options.has("wall"):
		centre -= along * (maxf(span.x, span.y) * 0.5 - float(options.wall) - 0.3)
		if options.has("corner"): centre += along.cross(Vector3.UP) * (minf(span.x, span.y) * 0.5 - float(options.wall) - 0.3)
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
	# A sheet is of one difficulty whatever the last one left in its profile
	# (in Desafiante the first capture is the end of the floor).
	await level.start_floor(int(options.seed), false, [1], String(options.get("difficulty", "equilibrada" if not sheet.is_empty() else "")))
	if options.has("reduced"): level.settings.values.reduced = true
	if options.has("soft"): level.settings.values["startle_soft"] = true
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
	if entry in ["wardrobe", "ambush"]:
		await take_wardrobe_sheet(entry)
		return
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
		var middle: Vector3 = (player.global_position + level.locust.global_position) * 0.5 + Vector3.UP * 1.3
		var along: Vector3 = (level.locust.global_position - player.global_position).normalized()
		view.global_position = stand_beside(middle, along, [player.get_rid(), level.locust.get_rid()])
		view.look_at(middle)
	level.executions.forced = {"glance": String(options.ending) == "glance"}
	# "--brief": as if this way in had been seen on this floor already.
	if options.has("brief"): level.tape.seen[entry if entry != "busy" else "front"] = true
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
	var after := 0.0
	while next < times.size():
		await process_frame
		# Past the end of the scene the seconds go on counting (what follows
		# it: the lost signal, the stage given back, the tape rewinding).
		if level.execution.is_empty(): after += 1.0 / 60.0
		if after > 12.0: break
		var now: float = float(level.execution.time) if not level.execution.is_empty() else SCORE.END_TIME + after
		if now < float(times[next]): continue
		await RenderingServer.frame_post_draw
		if options.has("ui"): print("UI_AT ", snappedf(now, 0.01), " flash='", level.ui.flash_label.text, "' shown=", level.ui.flash_label.is_visible_in_tree(), " alpha=", level.ui.flash_label.modulate.a, " time=", level.ui.flash_time, " hud=", level.ui.get_node("HUD").visible, " layer=", level.ui.layer, " rewind=", level.ui.rewind_mark.is_visible_in_tree(), " analog=", level.get_node("Presentation/Analog").layer, " lost=", level.lost_signal)
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

## Caught in a wardrobe: the nearest one to the staging room, its occupant
## already inside, the creature in front of it and sure of who is in there.
## "wardrobe" is the search, leaf by leaf. "ambush" is the feint as it is
## played: it looks, steps aside and waits, and then whoever is inside does
## what "--act=" says -- peek (a leaf held ajar, the default), leave, quiet
## (the key held, to leave quietly) or wait (nothing: it tires and goes);
## with "--ideal" it is at the doors already, about to throw them open. The
## times are counted from the capture, and those under zero are of what led
## to it (two and a half seconds of it are kept).
const REEL := 150
func take_wardrobe_sheet(entry: String) -> void:
	var player = level.player
	var hide: Node3D = null
	for other in level.hotel.hides:
		if level.point_protected(other.global_position): continue
		if options.has("big") != bool(other.big): continue
		if hide == null or other.global_position.distance_to(player.global_position) < hide.global_position.distance_to(player.global_position): hide = other
	player.global_position = hide.to_global(hide.exit_offset)
	player.rotation.y = hide.global_rotation.y
	await physics_frame
	player.enter_hide(hide)
	for i in 80: await process_frame
	var creature = level.locust
	# "--aside=0.8": that far to one side of the spot in front of the doors,
	# as it is when it reaches a wardrobe along the wall.
	creature.global_position = hide.to_global(hide.exit_offset + Vector3(float(options.get("aside", 0.0)), 0, 0))
	creature.rotation.y = hide.global_rotation.y
	creature.set_physics_process(true)
	creature.saw_enter(hide)
	creature.focus = player
	if String(options.light) == "lamp":
		var lamp := OmniLight3D.new()
		lamp.light_energy = 2.5
		lamp.omni_range = 10.0
		level.add_child(lamp)
		lamp.global_position = hide.to_global(Vector3(1.2, 2.5, 2.2))
	if options.has("outside"):
		var view := Camera3D.new()
		view.fov = 58.0
		level.add_child(view)
		var aim: Vector3 = hide.to_global(Vector3(0, 1.3, 0.9))
		view.global_position = stand_to_watch(aim, hide, [player.get_rid(), creature.get_rid()])
		view.look_at(aim)
		view.current = true
	var played: bool = entry == "ambush" and not options.has("ideal")
	var act := String(options.get("act", "peek"))
	if played: creature.begin_lurk(hide, player)
	elif entry == "ambush":
		creature.set_mode(creature.Mode.LURK)
		creature.lurk = {"hide": hide, "who": player, "phase": "pounce", "until": -1.0, "spot": creature.global_position, "ajar": 1.0, "since": creature.clock}
		creature.pouncing = true
	else: creature.begin_wardrobe(hide)
	var columns := COLUMNS
	var rows := int(ceil(float(times.size()) / float(columns)))
	var page := Image.create(THUMB.x * columns, THUMB.y * rows, false, Image.FORMAT_RGB8)
	var next := 0
	var taken: Array = []
	var reel: Array = []
	var clock := 0.0
	var caught := -1.0
	var acting := -1.0
	var gone := -1.0
	var said := ""
	while next < times.size() and clock < 45.0:
		await process_frame
		clock += 1.0 / 60.0
		# What it is at, said once each.
		var state := "%s/%s" % [creature.Mode.keys()[creature.mode], String(creature.lurk.get("phase", "-"))]
		if state != said:
			said = state
			print("WARDROBE_STATE ", snappedf(clock, 0.01), " ", state, " hushed=", creature.hushed(), " at=", (hide.to_local(creature.global_position) as Vector3).snapped(Vector3.ONE * 0.01))
		# Once it is waiting and nothing tells of it, whoever is inside does
		# their part.
		if played and acting < 0.0 and creature.hushed() and String(creature.lurk.get("phase", "")) == "wait":
			acting = clock
			print("WARDROBE_ACT ", act, " at=", snappedf(clock, 0.01))
			match act:
				"peek": Input.action_press("forward")
				"leave": level.match_net.use_hide(hide, false)
				"quiet": Input.action_press("interact")
		if acting >= 0.0 and caught < 0.0 and int(round((clock - acting) * 60.0)) % 15 == 0 and clock - acting < 3.0:
			print("WARDROBE_LEAF ", snappedf(clock - acting, 0.01), " left=", snappedf(hide.leaf_angle("left"), 0.01), " right=", snappedf(hide.leaf_angle("right"), 0.01), " ajar=", hide.ajar(), " seen=", creature.doors_seen_from(hide, creature.global_position), " held=", snappedf(float(creature.lurk.get("ajar", -1.0)), 0.01))
		# It tired of waiting and went: that is all there is to see of it.
		if played and act == "wait" and acting >= 0.0 and caught < 0.0 and creature.mode != creature.Mode.LURK:
			if gone < 0.0:
				gone = clock
				print("WARDROBE_LEFT after=", snappedf(clock - acting, 0.01), " mode=", creature.Mode.keys()[creature.mode])
			if clock - gone > 1.0: break
		if caught < 0.0 and not level.execution.is_empty():
			caught = clock
			Input.action_release("forward")
			Input.action_release("interact")
			print("CAPTURE_AS ", level.execution.get("entry", "?"), " after=", snappedf(clock, 0.01), " since_act=", snappedf(clock - acting, 0.01) if acting >= 0.0 else -1.0, " busy=", level.tape.busy, " dark=", level.tape.dark, " creature=", (hide.to_local(creature.global_position) as Vector3).snapped(Vector3.ONE * 0.01), " victim=", (hide.to_local(player.global_position) as Vector3).snapped(Vector3.ONE * 0.01))
		if caught >= 0.0 and level.execution.is_empty() and level.lost_signal <= 0.0: break
		if caught < 0.0:
			# Kept in case it is asked for: what led to the capture.
			if float(times[0]) < 0.0:
				await RenderingServer.frame_post_draw
				reel.append([clock, thumb()])
				if reel.size() > REEL: reel.pop_front()
			continue
		# The frames from before the capture, out of what was kept.
		while next < times.size() and float(times[next]) < 0.0:
			var chosen = null
			for kept in reel:
				if float(kept[0]) >= caught + float(times[next]) - 0.0001:
					chosen = kept
					break
			if chosen != null:
				page.blit_rect(chosen[1], Rect2i(Vector2i.ZERO, THUMB), Vector2i((next % columns) * THUMB.x, (next / columns) * THUMB.y))
				taken.append(snappedf(float(chosen[0]) - caught, 0.01))
			next += 1
		reel.clear()
		var now: float = float(level.execution.time) if not level.execution.is_empty() else clock - caught
		if next >= times.size() or now < float(times[next]): continue
		await RenderingServer.frame_post_draw
		if options.has("full"): root.get_texture().get_image().save_png("res://evidence/capture_%s_%02d.png" % [sheet, next])
		page.blit_rect(thumb(), Rect2i(Vector2i.ZERO, THUMB), Vector2i((next % columns) * THUMB.x, (next / columns) * THUMB.y))
		taken.append(snappedf(now, 0.01))
		next += 1
	Input.action_release("forward")
	Input.action_release("interact")
	page.save_png("res://evidence/capture_%s.png" % sheet)
	print("CAPTURE_SHEET ", sheet, " entry=", entry, " frames=", taken, " take=", level.tape.take.get("kind", -1), " valid=", level.tape.take.get("valid", 0))

## The picture of this frame, at the size it has on a sheet.
func thumb() -> Image:
	var frame := root.get_texture().get_image()
	frame.convert(Image.FORMAT_RGB8)
	frame.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
	return frame

## Somewhere to watch two that face each other along `along` from: to one
## side of them, a few metres off, with nothing in between.
func stand_beside(aim: Vector3, along: Vector3, exclude: Array) -> Vector3:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for far in [3.6, 3.0, 2.4, 1.9, 1.5]:
		for angle in [90.0, -90.0, 65.0, -65.0, 115.0, -115.0, 40.0, -40.0, 140.0, -140.0]:
			var point: Vector3 = aim + Basis(Vector3.UP, deg_to_rad(float(angle))) * along * float(far) + Vector3.UP * 0.4
			var query := PhysicsRayQueryParameters3D.create(aim, point)
			query.exclude = exclude
			if space.intersect_ray(query).is_empty(): return point
	return aim + along.cross(Vector3.UP) * 1.5 + Vector3.UP * 0.4

## Somewhere to watch the front of a wardrobe from: to one side of it, a few
## metres off, with nothing between it and what is looked at.
func stand_to_watch(aim: Vector3, hide: Node3D, exclude: Array) -> Vector3:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for far in [4.2, 3.4, 2.7, 2.1]:
		for angle in [38.0, -38.0, 58.0, -58.0, 20.0, -20.0, 0.0]:
			var turned := Basis(Vector3.UP, deg_to_rad(float(angle))) * Vector3(0, 0, float(far))
			var point: Vector3 = hide.to_global(Vector3(turned.x, 1.65, turned.z + 0.9))
			var query := PhysicsRayQueryParameters3D.create(aim, point)
			query.exclude = exclude
			if space.intersect_ray(query).is_empty(): return point
	return hide.to_global(Vector3(1.6, 1.65, 2.6))

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
