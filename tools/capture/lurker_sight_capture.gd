extends SceneTree
## The Lurker's eyes in Versus (.claude/specs/lurker_versus.md 4 and 4.5): her
## view (game/enemies/lurker/lurker_view.gd) at Alto from her camera on each
## planta of floor 2, in --bots-hunt with the bots held still where the shot
## wants them: a dark corridor with nothing electric in it (the heat of the
## registers taken out for the shot), the corridor with a survivor without a
## torch (running) and one with, a torch behind a wall, a lit room, the
## planta's objectives, the flash half way (the camera saturated), the ducts'
## plan. One sheet per planta with matplotlib's plasma map at its foot (top
## its table, bottom the fit the view uses). Then the bench: GPU and frame
## time of her seat against a survivor's at the same corridor, Alto, banco.json.
##   godot --path . --script res://tools/capture/lurker_sight_capture.gd -- --bots-hunt --floor=2 --bots=3 --seed=81 --test-profile [--sight-out=f2b/antes] [--sight-quick]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const VIEW := preload("res://game/enemies/lurker/lurker_view.gd")
const SIZE := Vector2i(1280, 720)
const ALTO := 2
const BENCH_FRAMES := 240
## bot_body.gd Pace.STILL and Pace.RUN.
const STILL := 0
const RUN := 3
## matplotlib's plasma at 0, 1/4, 1/2, 3/4 and 1, from its table.
const PLASMA_TABLE := [Color("0d0887"), Color("7e03a8"), Color("cc4778"), Color("f89540"), Color("f0f921")]
var out := "res://evidence/versus/f2b/"
## --sight-quick: planta 1 only, no bench (to look while tuning).
var quick := false
## --sight-view=<res path>: another view script in hers (the before shots:
## phase 2's, with the tape's grain and vignette it had).
var swap := ""
var level
var lurker
var driver
var bots: Array = []
var lines: Array = []
var bench: Array = []
## bot -> [point, yaw, torch]: where each bot is held for the shot (whatever
## of the bot match is still about would walk it off and switch its torch).
var held := {}

func _initialize() -> void: run.call_deferred()

func _physics_process(_delta: float) -> bool:
	for bot in held:
		var hold: Array = held[bot]
		if not is_instance_valid(bot): continue
		bot.torch_wanted = bool(hold[2])
		bot.torch.visible = bool(hold[2])
		if hold[0] == null: continue
		if (bot.global_position as Vector3).distance_to(hold[0]) > 0.05: bot.place(hold[0], float(hold[1]))
		bot.wish = Vector3.ZERO
		bot.pace = STILL
	return false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sight-out="): out = "res://evidence/versus/%s/" % arg.trim_prefix("--sight-out=")
		if arg == "--sight-quick": quick = true
		if arg.begins_with("--sight-view="): swap = arg.trim_prefix("--sight-view=")
	DisplayServer.window_set_size(SIZE)
	# The bench counts every frame, not the screen's.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 3600:
		await physics_frame
		lurker = level.get("creature")
		if is_instance_valid(lurker) and lurker.control == "player" and lurker.driver != null and level.session.state == level.session.State.PLAYING: break
	if not is_instance_valid(lurker) or lurker.control != "player":
		print("SIGHT no lurker to drive")
		quit(1)
		return
	driver = lurker.driver
	driver.scripted = true
	lurker.grace = 0.0
	# No torch of a bot standing in a shot scares her off (lurker.judge_light()):
	# the flash is the shot's own.
	lurker.fled_until = INF
	level.settings.set_designed(ALTO)
	level.apply_settings()
	if swap != "":
		var was = driver.view
		var cover: Node = was.plan.get_parent()
		for key in ["plan", "hud"]:
			if was.get(key) != null: was.get(key).queue_free()
		was.queue_free()
		driver.view = load(swap).new()
		driver.add_child(driver.view)
		driver.view.setup(driver, cover)
		old_tape()
	# The bots as props: their minds stopped (bot_watch runs them), their
	# bodies standing where each shot puts them.
	if is_instance_valid(level.get("bot_watch")):
		level.bot_watch.process_mode = Node.PROCESS_MODE_DISABLED
		# The match runs its brains whatever its parent does (PROCESS_MODE_ALWAYS).
		if is_instance_valid(level.bot_watch.get("current")): level.bot_watch.current.process_mode = Node.PROCESS_MODE_DISABLED
	for body in level.match_net.bodies.values():
		if is_instance_valid(body): bots.append(body)
	# This machine's own survivor, out of every shot.
	level.player.held = true
	level.player.global_position = Vector3(0, -60, 0)
	level.player.torch.visible = false
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	note("asiento de ella: %s, vista: %s, bots %d" % [str(level.rig.lurker_seat()), str(driver.view != null), bots.size()])
	# The match's opening words off the screen first.
	for i in 300: await process_frame
	# No calibration of her sensor holding a frame still in a shot, but the one
	# a flash brings (looked at in flash_shot()).
	if "nuc_clock" in driver.view: driver.view.nuc_clock = INF
	for planta in (1 if quick else 3):
		var tiles: Array = []
		tiles.append(await dark_shot(planta))
		tiles.append(await corridor_shot(planta))
		tiles.append(await wall_shot(planta))
		tiles.append(await lit_room_shot(planta))
		tiles.append(await objectives_shot(planta))
		tiles.append(await ducts_shot(planta))
		tiles.append(await flash_shot(planta))
		tiles.append(plasma_strip(Vector2i(SIZE.x / 2, SIZE.y / 2)))
		sheet(tiles, "hoja_p%d.png" % [planta + 1])
		if not quick: await bench_at(planta)
	var file := FileAccess.open(out + "banco.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(bench, "\t"))
	var text := FileAccess.open(out + "capturas.txt", FileAccess.WRITE)
	if text != null:
		for line in lines: text.store_line(line)
	print("SIGHT done")
	quit(0)

## The tape's share of phase 2's look over her seat.
func old_tape() -> void:
	if swap == "": return
	level.post_material.set_shader_parameter("grain", level.settings.values.grain / 3.0)
	level.post_material.set_shader_parameter("vignette", 0.3)

func note(words: String) -> void:
	lines.append(words)
	print("SIGHT ", words)

# --- Placing ---------------------------------------------------------------------------

func rooms_on(planta: int) -> Array:
	return level.manifest.rooms.filter(func(room: Dictionary) -> bool: return int(room.get("wing", -1)) == planta and lurker.shell.tray_of.has(int(room.id)))

## On her ceiling over a plan point, looking along `way` a little down.
func put_her(room: int, at: Vector2, way: Vector3, pitch := -0.25) -> void:
	lurker.motion.clear_legs()
	var r: Dictionary = level.manifest.rooms[room]
	lurker.teleport(Vector3(at.x, float(r.get("py", 0.0)) + 1.0, at.y), atan2(-way.x, -way.z), &"captura")
	driver.yaw = atan2(-way.x, -way.z)
	driver.pitch = pitch
	for i in 3: await physics_frame

## A bot stood at a plan point of a room, facing `way`, its torch as asked.
func put_bot(k: int, room: int, at: Vector2, way: Vector3, torch: bool) -> void:
	if k >= bots.size(): return
	var bot = bots[k]
	var r: Dictionary = level.manifest.rooms[room]
	bot.place(Vector3(at.x, float(r.get("py", 0.0)), at.y), atan2(-way.x, -way.z))
	held[bot] = [bot.global_position, bot.rotation.y, torch]
	bot.torch_wanted = torch
	bot.torch.visible = torch
	bot.wish = Vector3.ZERO
	bot.pace = STILL
	mind(bot, 100.0)
	# A torch the shot wants lit is not one she has drunk or put out.
	for key in ["drunk", "dead_torches"]:
		if key in lurker: lurker.get(key).erase(int(bot.slot))

## Every bot out of the way: in a room of another planta (under the floor
## a bot falls, and a fallen bot is put away).
func park_bots() -> void:
	var away: Array = rooms_on((FLOOR.planta_of(driver.camera.global_position.y) + 1) % 3)
	for k in bots.size():
		var bot = bots[k]
		var room: Dictionary = away[k % away.size()]
		bot.place(Vector3(float(room.px), float(room.get("py", 0.0)), float(room.pz)), 0.0)
		held[bot] = [bot.global_position, 0.0, false]
		bot.torch_wanted = false
		bot.torch.visible = false
		bot.wish = Vector3.ZERO
		bot.pace = STILL
		mind(bot, 100.0)

## A bot put somewhere is a survivor there for her a second or so later.
func bots_settle() -> void:
	for i in 90: await physics_frame

func centre(room: Dictionary) -> Vector2: return Vector2(float(room.px), float(room.pz))

## A survivor's mind (sanity.gd minds): at 0 it is gone (burnt).
func mind(bot, value: float) -> void:
	level.sanity.minds[int(bot.slot)] = {"sanity": value, "rest": 0.0, "paid": 0.0}
	bot.set_burnt(value <= 0.0)

## A room of the planta other than `room`, 6 to 14 m from the eye and ahead
## along `way`; -1 with none.
func beside_of(planta: int, room: int, eye: Vector3, way: Vector3) -> int:
	for other in rooms_on(planta):
		if int(other.id) == room: continue
		var c := centre(other)
		var to := Vector3(c.x - eye.x, 0, c.y - eye.z)
		if to.length() > 6.0 and to.length() < 14.0 and to.normalized().dot(way) > 0.6: return int(other.id)
	return -1

func shot(name: String, frames := 30) -> Image:
	level.hotel.update_visibility(driver.camera.global_position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out + name)
	var view = driver.view
	var told := "balizas %d, cuerpos %d, fríos %d, bebidas %s" % [view.beacons.size(), view.seen.size(), view.cold.size(), str(lurker.get("drunk"))]
	if "gain_high" in view: told += ", a la vista %s, ganancia %.2f" % [str(view.torch_view.values()), view.gain_high]
	for bot in bots: told += "; bot %d en %s luz %s activo %s" % [int(bot.slot), str((bot.global_position as Vector3).snapped(Vector3.ONE * 0.1)), str(bot.torch.visible), str(level.survivor_active(bot))]
	for seat_id in view.beacons:
		var one = view.beacons[seat_id]
		var query := PhysicsRayQueryParameters3D.create(driver.camera.global_position, one.torch.global_position, 1 | 8 | 64)
		query.exclude = [lurker.get_rid()]
		var hit: Dictionary = driver.camera.get_world_3d().direct_space_state.intersect_ray(query)
		told += "; linterna %d en %s, la tapa %s" % [seat_id, str((one.torch.global_position as Vector3).snapped(Vector3.ONE * 0.01)), str(hit.collider.get_path()) + " en " + str((hit.position as Vector3).snapped(Vector3.ONE * 0.01)) if not hit.is_empty() else "nada"]
	note("captura %s desde %s; %s" % [name, str(driver.camera.global_position.snapped(Vector3.ONE * 0.01)), told])
	return image

# --- The shots -------------------------------------------------------------------------

## The longest corridor of the planta and her place at one end of it, looking
## along it: [room, start, along, half length].
func corridor_of(planta: int) -> Array:
	var best: Dictionary = {}
	var longest := 0.0
	for room in rooms_on(planta):
		if int(room.type) != OFFICE.CORRIDOR: continue
		var size := FLOOR.size_of(room)
		if maxf(size.x, size.y) > longest:
			longest = maxf(size.x, size.y)
			best = room
	if best.is_empty(): best = rooms_on(planta)[0]
	var size := FLOOR.size_of(best)
	var along := Vector3(1, 0, 0) if size.x >= size.y else Vector3(0, 0, 1)
	var half := maxf(size.x, size.y) * 0.5
	return [int(best.id), centre(best) - Vector2(along.x, along.z) * (half - 1.0), along, half]

## The corridor with nobody in it and every heat of the registers taken out
## for the shot (the view gathers no more until it is over): the bare
## surfaces, what she has where nothing electric is in view.
func dark_shot(planta: int) -> Image:
	park_bots()
	var c := corridor_of(planta)
	await put_her(int(c[0]), c[1], c[2], -0.2)
	for i in 10: await physics_frame
	var view = driver.view
	view.gather_clock = 1.0e9
	view.lamps = []
	for key in ["wires", "beacons", "seen", "marks"]:
		if key in view: view.get(key).clear()
	view.rings.clear()
	# And her room's light, which would wash it out past a few metres.
	view.dazzled = false
	view.dazzle = 0.0
	note("P%d pasillo oscuro: sala %d, sin calor de los registros" % [planta + 1, int(c[0])])
	var image := await shot("p%d_oscuro.png" % [planta + 1], 40)
	view.gather_clock = 0.0
	return image

## From one end of the corridor: a survivor without a torch running away
## from 2.5 m, one with a torch further on facing her, a door slammed behind
## her.
func corridor_shot(planta: int) -> Image:
	park_bots()
	var c := corridor_of(planta)
	var start: Vector2 = c[1]
	var along: Vector3 = c[2]
	var half: float = c[3]
	await put_her(int(c[0]), start, along, -0.2)
	var flat := Vector2(along.x, along.z)
	put_bot(0, int(c[0]), start + flat * minf(2.5, half), along, false)
	put_bot(1, int(c[0]), start + flat * maxf(2.0, half * 2.0 - 2.5), -along, true)
	await bots_settle()
	# Let go: it runs.
	held[bots[0]][0] = null
	bots[0].wish = along
	bots[0].pace = RUN
	for i in 10: await physics_frame
	var eye: Vector3 = driver.camera.global_position
	for door in level.hotel.doors:
		# One behind her: a door ahead would shut the bots away.
		if (door.doorway as Vector3).distance_to(eye) < 12.0 and FLOOR.planta_of(door.doorway.y) == planta and ((door.doorway as Vector3) - eye).dot(along) < 0.0:
			door.toggle(false, true, true)
			break
	for i in 12: await process_frame
	note("P%d pasillo: sala %d (%.1f m), luz %s" % [planta + 1, int(c[0]), half * 2.0, str(level.hotel.lit(int(c[0])))])
	return await shot("p%d_pasillo.png" % [planta + 1])

## The torch of a survivor in a room beside the corridor, behind its wall.
func wall_shot(planta: int) -> Image:
	park_bots()
	var c := corridor_of(planta)
	await put_her(int(c[0]), c[1], c[2], -0.2)
	var eye: Vector3 = driver.camera.global_position
	var beside := beside_of(planta, int(c[0]), eye, c[2])
	if beside < 0:
		note("P%d tras el muro: ninguna sala delante" % [planta + 1])
		return Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var room: Dictionary = level.manifest.rooms[beside]
	put_bot(2, beside, centre(room), eye - FLOOR.position_of(room), true)
	# Looking at it: whatever stands between is the wall.
	var to: Vector3 = bots[2].global_position - eye
	driver.yaw = atan2(-to.x, -to.z)
	await bots_settle()
	note("P%d tras el muro: linterna en la sala %d, a %.1f m" % [planta + 1, beside, to.length()])
	return await shot("p%d_tras_muro.png" % [planta + 1])

## The biggest lit room of the planta, from a corner: a survivor without a
## torch past the 4 m it dazzles her to.
func lit_room_shot(planta: int) -> Image:
	park_bots()
	var best: Dictionary = {}
	var widest := 0.0
	for room in rooms_on(planta):
		if not level.hotel.lit(int(room.id)): continue
		var rect: Rect2 = lurker.shell.patches[int(lurker.shell.tray_of[int(room.id)])].rect
		if rect.get_area() > widest:
			widest = rect.get_area()
			best = room
	if best.is_empty():
		# None lit here (Desafiante's dark plantas): the biggest office is
		# given its light, as the board's zones give it.
		for room in rooms_on(planta):
			if int(room.type) in [OFFICE.OPEN_OFFICE, OFFICE.OFFICE, OFFICE.CUBICLES] and lurker.shell.patches[int(lurker.shell.tray_of[int(room.id)])].rect.get_area() > widest:
				widest = lurker.shell.patches[int(lurker.shell.tray_of[int(room.id)])].rect.get_area()
				best = room
		if best.is_empty():
			note("P%d sala encendida: ninguna" % [planta + 1])
			return Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		level.hotel.dark_ids.erase(int(best.id))
		level.hotel.set_room_power(int(best.id), true)
		level.hotel.lights[int(best.id)].remove_meta("off")
		note("P%d sala encendida: ninguna con luz; se enciende la %d para la captura (%s)" % [planta + 1, int(best.id), str(level.hotel.lit(int(best.id)))])
	var rect: Rect2 = lurker.shell.patches[int(lurker.shell.tray_of[int(best.id)])].rect
	var from := rect.position + Vector2(0.8, 0.8)
	var way := Vector3(rect.size.x, 0, rect.size.y).normalized()
	await put_her(int(best.id), from, way, -0.3)
	put_bot(0, int(best.id), from + Vector2(way.x, way.z) * minf(6.0, rect.size.length() * 0.6), -way, false)
	put_bot(1, int(best.id), from + Vector2(way.x, way.z) * 2.5, -way, false)
	# One whose mind has gone, in a room beside: a cold outline through the wall.
	var beside := beside_of(planta, int(best.id), driver.camera.global_position, way)
	if beside >= 0:
		put_bot(2, beside, centre(level.manifest.rooms[beside]), way, false)
		mind(bots[2], 0.0)
	await bots_settle()
	note("P%d sala encendida %d (tipo %d), %.0f m2; sin cordura en la sala %d" % [planta + 1, int(best.id), int(best.type), widest, beside])
	return await shot("p%d_sala_encendida.png" % [planta + 1])

## The planta's objective (the window and the stations, the board, the air
## plant): from 3 m off its first electric usable, a station's lamp waiting.
func objectives_shot(planta: int) -> Image:
	park_bots()
	var target = null
	var lit_lamp := false
	for objective in level.objectives.values():
		if not "usables" in objective: continue
		for usable in objective.usables:
			if is_instance_valid(usable) and String(usable.action) in VIEW.ELECTRIC and FLOOR.planta_of(usable.global_position.y) == planta:
				target = usable
				break
		if target != null:
			if "lamps" in objective and not objective.lamps.is_empty():
				objective.lamps[0].visible = true
				lit_lamp = true
			break
	if target == null:
		note("P%d objetivos: ninguno" % [planta + 1])
		return Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var at: Vector3 = target.global_position
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, at)
	var rect: Rect2 = lurker.shell.patches[int(lurker.shell.tray_of[int(room.id)])].rect
	var c := rect.get_center()
	var away := Vector2(c.x - at.x, c.y - at.z)
	var from := Vector2(at.x, at.z) + (away.normalized() * minf(3.5, away.length() + 1.5) if away.length() > 0.1 else Vector2(1, 0))
	from = Vector2(clampf(from.x, rect.position.x + 0.3, rect.end.x - 0.3), clampf(from.y, rect.position.y + 0.3, rect.end.y - 0.3))
	await put_her(int(room.id), from, Vector3(at.x - from.x, 0, at.z - from.y), -0.45)
	for i in 20: await physics_frame
	note("P%d objetivos: %s en la sala %d%s" % [planta + 1, String(target.action), int(room.id), ", lámpara de estación encendida" if lit_lamp else ""])
	return await shot("p%d_objetivos.png" % [planta + 1])

## In the ducts of the planta, at a trunk node near its middle: the plan.
func ducts_shot(planta: int) -> Image:
	park_bots()
	var ducts = lurker.ducts
	var middle := Vector3.ZERO
	var count := 0
	for room in rooms_on(planta):
		middle += FLOOR.position_of(room)
		count += 1
	middle /= maxf(1.0, count)
	var node: int = ducts.trunk_nearest(middle, planta)
	lurker.motion.place_in_duct(node)
	lurker.apply_motion()
	driver.pitch = 0.0
	for i in 40: await physics_frame
	note("P%d ductos: nodo %d, salida marcada %d, a oscuras %s" % [planta + 1, node, int(driver.view.plan.pick), str(driver.dark)])
	return await shot("p%d_ductos.png" % [planta + 1])

## Back in the corridor, a torch flashes her: as it comes, and half way back.
func flash_shot(planta: int) -> Image:
	await corridor_shot(planta)
	var way: Vector3 = (bots[1].camera.global_position - driver.camera.global_position).normalized()
	driver.view.immune_until = -1.0
	driver.view.flash(way)
	await settle(0.07)
	note("P%d fogonazo naciendo, blanco %.2f" % [planta + 1, driver.view.flash_now()])
	await shot("p%d_fogonazo_nace.png" % [planta + 1], 0)
	await settle(0.75)
	note("P%d fogonazo a mitad, blanco %.2f" % [planta + 1, driver.view.flash_now()])
	var image := await shot("p%d_fogonazo.png" % [planta + 1], 0)
	# Let it pass before anything else is shot: the sensor calibrates after it.
	driver.view.flash_clock = -1.0
	if "frozen_until" in driver.view:
		var from: float = driver.view.clock
		while driver.view.clock - from < 0.45: await process_frame
		note("P%d tras el fogonazo, calibración: imagen quieta %s, clic %s" % [planta + 1, str(driver.view.frozen_until > driver.view.clock), str(driver.view.click.playing)])
		driver.view.nuc_clock = INF
	return image

## Frames until `seconds` have gone since the flash.
func settle(seconds: float) -> void:
	while driver.view.clock - driver.view.flash_clock < seconds: await process_frame

# --- Sheets ----------------------------------------------------------------------------

## matplotlib's plasma: the top half from its table (between five of its
## points), the bottom half the fit the view uses (lurker_view.plasma()).
func plasma_strip(size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for x in size.x:
		var t := float(x) / float(size.x - 1)
		var k := mini(int(t * 4.0), 3)
		var table: Color = PLASMA_TABLE[k].lerp(PLASMA_TABLE[k + 1], t * 4.0 - float(k))
		var fit: Color = VIEW.plasma(t)
		for y in size.y:
			image.set_pixel(x, y, table if y < size.y / 2 - 2 else (Color.BLACK if y < size.y / 2 + 2 else fit))
	return image

## Two tiles a row, at half size.
func sheet(tiles: Array, name: String) -> void:
	var cell := Vector2i(SIZE.x / 2, SIZE.y / 2)
	var rows := (tiles.size() + 1) / 2
	var sheet_image := Image.create(cell.x * 2, cell.y * rows, false, Image.FORMAT_RGBA8)
	for k in tiles.size():
		var tile: Image = tiles[k]
		tile.convert(Image.FORMAT_RGBA8)
		if tile.get_size() != cell: tile.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet_image.blit_rect(tile, Rect2i(Vector2i.ZERO, cell), Vector2i(k % 2 * cell.x, k / 2 * cell.y))
	sheet_image.save_png(out + name)
	note("hoja %s" % name)

# --- The bench -------------------------------------------------------------------------

## Her seat and a survivor's at the corridor's spot, Alto: GPU and frame time.
func bench_at(planta: int) -> void:
	await corridor_shot(planta)
	var eye: Vector3 = driver.camera.global_position
	var hers := await sample()
	# The survivor's: this machine's player there, at a survivor's eye height,
	# looking the same way, torch on, through the camcorder (the seat back).
	level.solo_locust = false
	level.player.global_position = Vector3(eye.x, FLOOR.planta_y(planta), eye.z)
	level.player.held = true
	level.player.camera.current = true
	level.player.global_rotation.y = driver.yaw
	level.player.camera.rotation.x = driver.pitch
	level.player.torch.visible = true
	level.apply_settings()
	var theirs := await sample()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "p%d_banco_superviviente.png" % [planta + 1])
	level.player.torch.visible = false
	level.player.global_position = Vector3(0, -60, 0)
	level.solo_locust = true
	driver.camera.current = true
	level.apply_settings()
	old_tape()
	bench.append({"planta": planta + 1, "quality": "Alto", "size": str(root.size), "hers": hers, "survivor": theirs})
	note("P%d banco Alto: ella GPU %.2f ms (p95 %.2f), cuadro %.2f ms; superviviente GPU %.2f ms (p95 %.2f), cuadro %.2f ms" % [planta + 1, hers.gpu_mean, hers.gpu_p95, hers.frame_mean, theirs.gpu_mean, theirs.gpu_p95, theirs.frame_mean])

func sample() -> Dictionary:
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for i in 30: await process_frame
	var gpu: Array = []
	var frames: Array = []
	var last := Time.get_ticks_usec()
	for i in BENCH_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	gpu.sort()
	frames.sort()
	return {"gpu_mean": mean(gpu), "gpu_p95": gpu[int(gpu.size() * 0.95)], "frame_mean": mean(frames), "frame_p95": frames[int(frames.size() * 0.95)]}

func mean(values: Array) -> float:
	var total := 0.0
	for v in values: total += float(v)
	return total / maxf(1.0, values.size())
