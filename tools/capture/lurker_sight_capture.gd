extends SceneTree
## Phase 2 of The Lurker in Versus (.claude/specs/lurker_versus.md 4 and 11):
## her eyes (game/enemies/lurker/lurker_view.gd) at Alto from her camera on
## each planta of floor 2, in --bots-hunt with the bots held still where the
## shot wants them: a corridor with a survivor with a torch, one without (and
## running), and one with a torch behind a wall; a lit room; the planta's
## objectives; the ducts' plan; the flash half way. One sheet per planta with
## matplotlib's plasma map under it (top its table, bottom the shader's fit),
## evidence/versus/f2/. Then the bench: GPU and frame time of her seat against
## a survivor's at the same corridor, Alto, evidence/versus/f2/banco.json.
##   godot --path . --script res://tools/capture/lurker_sight_capture.gd -- --bots-hunt --floor=2 --bots=3 --seed=81 --test-profile
const OUT := "res://evidence/versus/f2/"
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
var level
var lurker
var driver
var bots: Array = []
var lines: Array = []
var bench: Array = []

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(SIZE)
	# The bench counts every frame, not the screen's.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
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
	level.settings.set_designed(ALTO)
	level.apply_settings()
	# The bots as props: their minds stopped (bot_watch runs them), their
	# bodies standing where each shot puts them.
	if is_instance_valid(level.get("bot_watch")): level.bot_watch.process_mode = Node.PROCESS_MODE_DISABLED
	for body in level.match_net.bodies.values():
		if is_instance_valid(body): bots.append(body)
	# This machine's own survivor, out of every shot.
	level.player.held = true
	level.player.global_position = Vector3(0, -60, 0)
	level.player.torch.visible = false
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	note("asiento de ella: %s, vista: %s, bots %d" % [str(level.rig.lurker_seat()), str(driver.view != null), bots.size()])
	await handling()
	for planta in 3:
		var tiles: Array = []
		var corridor := await corridor_shot(planta)
		tiles.append(corridor)
		tiles.append(await lit_room_shot(planta))
		tiles.append(await objectives_shot(planta))
		tiles.append(await ducts_shot(planta))
		tiles.append(await flash_shot(planta))
		tiles.append(plasma_strip(Vector2i(SIZE.x / 2, SIZE.y / 2)))
		sheet(tiles, "hoja_p%d.png" % [planta + 1])
		await bench_at(planta)
	var file := FileAccess.open(OUT + "banco.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(bench, "\t"))
	var text := FileAccess.open(OUT + "capturas.txt", FileAccess.WRITE)
	if text != null:
		for line in lines: text.store_line(line)
	print("SIGHT done")
	quit(0)

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
	bot.torch_wanted = torch
	bot.torch.visible = torch
	bot.wish = Vector3.ZERO
	bot.pace = STILL
	mind(bot, 100.0)

## Every bot out of the way, under the floor.
func park_bots() -> void:
	for bot in bots:
		bot.place(Vector3(0, -60, 0), 0.0)
		bot.torch_wanted = false
		bot.torch.visible = false
		bot.wish = Vector3.ZERO
		bot.pace = STILL
		mind(bot, 100.0)

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
	image.save_png(OUT + name)
	note("captura %s desde %s" % [name, str(driver.camera.global_position.snapped(Vector3.ONE * 0.01))])
	return image

# --- The shots -------------------------------------------------------------------------

## The longest corridor of the planta: from one end, a survivor without a
## torch running at 4 m, one with a torch at 8 m facing her, one with a
## torch in a room beside it (a beacon through the wall), a door slammed.
func corridor_shot(planta: int) -> Image:
	park_bots()
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
	var start := centre(best) - Vector2(along.x, along.z) * (half - 1.0)
	await put_her(int(best.id), start, along, -0.2)
	var flat := Vector2(along.x, along.z)
	put_bot(0, int(best.id), start + flat * minf(4.0, half), along, false)
	# Running away from her down the corridor.
	bots[0].wish = along
	bots[0].pace = RUN
	put_bot(1, int(best.id), start + flat * minf(8.0, half * 1.8), -along, true)
	var eye: Vector3 = driver.camera.global_position
	var beside := beside_of(planta, int(best.id), eye, along)
	if beside >= 0:
		put_bot(2, beside, centre(level.manifest.rooms[beside]), eye - FLOOR.position_of(level.manifest.rooms[beside]), true)
		note("P%d pasillo: baliza tras la pared en la sala %d" % [planta + 1, beside])
	for i in 10: await physics_frame
	# A door near her on the planta, shut hard: a ring where she hears it.
	for door in level.hotel.doors:
		if (door.doorway as Vector3).distance_to(eye) < 12.0 and FLOOR.planta_of(door.doorway.y) == planta:
			door.toggle(false, true, true)
			break
	for i in 12: await process_frame
	note("P%d pasillo: sala %d (%.1f m), luz %s" % [planta + 1, int(best.id), longest, str(level.hotel.lit(int(best.id)))])
	return await shot("p%d_pasillo.png" % [planta + 1])

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
	for i in 30: await physics_frame
	note("P%d sala encendida: sin cordura en la sala %d, %s" % [planta + 1, beside, str(level.sanity.burnt_survivors().size())])
	note("P%d sala encendida %d (%s), %.0f m2" % [planta + 1, int(best.id), "tipo %d" % int(best.type), widest])
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

## Back in the corridor, a torch flashes her: the picture half way through.
func flash_shot(planta: int) -> Image:
	await corridor_shot(planta)
	var way: Vector3 = (bots[1].camera.global_position - driver.camera.global_position).normalized()
	# As it comes, from the torch's side; then half way back.
	driver.view.immune_until = -1.0
	driver.view.flash(way)
	await settle(0.07)
	note("P%d fogonazo naciendo, blanco %.2f" % [planta + 1, driver.view.flash_now()])
	await shot("p%d_fogonazo_nace.png" % [planta + 1], 0)
	await settle(0.75)
	note("P%d fogonazo a mitad, blanco %.2f" % [planta + 1, driver.view.flash_now()])
	var image := await shot("p%d_fogonazo.png" % [planta + 1], 0)
	# Let it pass before anything else is shot.
	driver.view.flash_clock = -1.0
	return image

## Frames until `seconds` have gone since the flash.
func settle(seconds: float) -> void:
	while driver.view.clock - driver.view.flash_clock < seconds: await process_frame

# --- Her handling (phase 0's leftovers) -------------------------------------------------

## From rest, the stick full forward: her pace every tenth of a second. Then
## through a door of planta 1 looking at it: the least pace on the way over.
func handling() -> void:
	park_bots()
	var shell = lurker.shell
	var best: Dictionary = {}
	var area := 0.0
	for room in rooms_on(0):
		var rect: Rect2 = shell.patches[int(shell.tray_of[int(room.id)])].rect
		if rect.get_area() > area and not shell.columns_of.has(int(room.id)):
			area = rect.get_area()
			best = room
	var rect: Rect2 = shell.patches[int(shell.tray_of[int(best.id)])].rect
	var way := Vector3(rect.size.x, 0, rect.size.y).normalized()
	await put_her(int(best.id), rect.position + Vector2(0.5, 0.5), way)
	driver.axis = Vector2(0, -1)
	var paces: Array = []
	for i in 42:
		await physics_frame
		if i % 6 == 5: paces.append(snappedf(lurker.motion.speed, 0.01))
	driver.axis = Vector2.ZERO
	note("manejo: desde parada, empujando, ritmo cada 0,1 s: %s" % str(paces))
	for pair in shell.band_of_pair:
		var record: Dictionary = shell.patches[int(shell.band_of_pair[pair])]
		var a := int(record.rooms[0])
		if wing_of(a) != 0 or lurker.routes.door_nodes.get(pair) == null: continue
		var door = lurker.routes.door_nodes[pair]
		if not lurker.routes.door_open(pair): door.set_state(true)
		var origin: Vector3 = record.origin
		var across: Vector3 = record.across
		var r: Rect2 = shell.patches[int(shell.tray_of[a])].rect.grow(-0.1)
		var from := Vector2(clampf(origin.x - across.x * 3.0, r.position.x, r.end.x), clampf(origin.z - across.z * 3.0, r.position.y, r.end.y))
		await put_her(a, from, across, -0.2)
		driver.axis = Vector2(0, -1)
		var least := INF
		var crossed := false
		var kinds := {}
		for i in 240:
			await physics_frame
			var m = lurker.motion
			if not m.legs.is_empty():
				kinds[String(m.legs[0].kind)] = true
				least = minf(least, m.speed)
			if m.legs.is_empty() and m.surface() and m.room() == int(record.rooms[1]):
				crossed = true
				break
		driver.axis = Vector2.ZERO
		note("manejo: puerta %s mirándola y empujando: cruza %s, tramos %s, ritmo mínimo en la orden %.2f m/s" % [str(pair), str(crossed), str(kinds.keys()), least])
		# Pushed along the wall past it, looking along the wall: it stays.
		var side := Vector3(-across.z, 0, across.x)
		var by := Vector2(origin.x - across.x * 0.8 - side.x * 1.5, origin.z - across.z * 0.8 - side.z * 1.5)
		await put_her(a, Vector2(clampf(by.x, r.position.x, r.end.x), clampf(by.y, r.position.y, r.end.y)), side, -0.2)
		driver.axis = Vector2(0, -1)
		var went := false
		for i in 90:
			await physics_frame
			if not lurker.motion.legs.is_empty(): went = true
		driver.axis = Vector2.ZERO
		note("manejo: puerta %s rozada a lo largo de la pared: la cruza %s" % [str(pair), str(went)])
		break

func wing_of(room: int) -> int: return int(level.manifest.rooms[room].get("wing", -1))

# --- Sheets ----------------------------------------------------------------------------

## matplotlib's plasma: the top half from its table (between five of its
## points), the bottom half the shader's fit (lurker_view.plasma()).
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

func sheet(tiles: Array, name: String) -> void:
	var cell := Vector2i(SIZE.x / 2, SIZE.y / 2)
	var out := Image.create(cell.x * 2, cell.y * 3, false, Image.FORMAT_RGBA8)
	for k in tiles.size():
		var tile: Image = tiles[k]
		tile.convert(Image.FORMAT_RGBA8)
		if tile.get_size() != cell: tile.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(tile, Rect2i(Vector2i.ZERO, cell), Vector2i(k % 2 * cell.x, k / 2 * cell.y))
	out.save_png(OUT + name)
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
	root.get_texture().get_image().save_png(OUT + "p%d_banco_superviviente.png" % [planta + 1])
	level.player.torch.visible = false
	level.player.global_position = Vector3(0, -60, 0)
	level.solo_locust = true
	driver.camera.current = true
	level.apply_settings()
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
