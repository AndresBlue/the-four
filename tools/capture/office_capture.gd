extends SceneTree
## Views of floor 2 (spec_f1_systems 6.5), with a window: the receipt, the
## card with its photo, the tubes, the window's desk, the tube map, the board's
## memo, a glazed office, a ceiling gap, the plant ladder and hatch, inside the
## main duct, the shaft, a planta-2 room without power and with it, and a
## corridor under its emergency units; and the equipment (spec_rediseno 12,
## area 5): the tube central, the window from its corridor, a station with a
## card waiting, the freight lift's reader and car, the security post's
## console and glass (seed 29 glazes it), the main duct's sign, the board and
## a minutero. PNGs in evidence/office_capture_*.png.
##
##   godot --path . --script res://tools/capture/office_capture.gd -- --test-profile [--seed=7]
##     [--quality=4] [--prefix=muybajo]   (4 is Muy bajo: graphics_presets.NAMES)
##   and with --rendering-method gl_compatibility for Compatibility.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
var level
## Before each picture's name, for a run at another quality or renderer.
var prefix := ""

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())

func shot(name: String) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/office_capture_%s%s.png" % [prefix, name])

## What stands in a room with no light to show it whole: a lamp at the eye,
## for this picture only, and no torch.
func lit_shot(title: String) -> void:
	var torch_on: bool = level.player.torch.visible
	level.player.torch.visible = false
	var lamp := OmniLight3D.new()
	lamp.omni_range = 14.0
	lamp.light_energy = 1.2
	lamp.omni_attenuation = 0.6
	level.hotel.add_child(lamp)
	lamp.global_position = level.player.camera.global_position + Vector3(0, 0.4, 0)
	await shot(title)
	lamp.free()
	level.player.torch.visible = torch_on

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 7
	var quality := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=") + "_"
	# The rooms as they are, without her drinking their light.
	level.creature_scene = "none"
	await level.start_floor(seed_value, false, [1], "", 2)
	if quality >= 0:
		level.settings.values.quality = quality
		level.apply_settings()
	level.player.set_physics_process(false)
	# Planta 1's papers: the receipt, then the card.
	var m: Dictionary = level.manifest
	var files = level.objective(&"files")
	level.player.global_position = files.usables[0].stand
	level.player.rotation.y = files.usables[0].face_yaw
	level.hotel.update_visibility(level.player.global_position, true)
	for i in 20: await process_frame
	files.snap(level.player.slot)
	for i in 10: await process_frame
	files.apply("type", 0, level.player.slot, {}, false)
	await shot("resguardo")
	level.interaction.close_document()
	# The capsule some way along its tube, seen from under it.
	level.session.elapsed = float(files.requests[level.player.slot].sent) + 0.15
	files.show_capsules()
	var hub: Dictionary = m.tubes.exits[0]
	var hub_at := Vector3(float(hub.point[0]), float(hub.point[1]), float(hub.point[2]))
	var hub_out: Vector3 = Basis(Vector3.UP, float(hub.yaw)).z
	look(hub_at + hub_out * 3.0 + Vector3(0, 0.4, 0) + Vector3(hub_out.z, 0, -hub_out.x) * 1.0, hub_at + Vector3(0, 1.0, 0))
	level.player.torch.visible = true
	await shot("capsula")
	var stand: Dictionary = m.mail.stand
	var desk_spot: Dictionary = m.mail.desk
	var wall_at := Vector3(float(desk_spot.point[0]), 0, float(desk_spot.point[2]))
	var desk_in: Vector3 = Basis(Vector3.UP, float(desk_spot.yaw)).z
	look(wall_at + desk_in * 2.6 + Vector3(desk_in.z, 0, -desk_in.x) * 1.2 + Vector3(0, 1.7, 0), wall_at + Vector3(0, 0.8, 0))
	await shot("ventanilla")
	# The tube central at the hub, its lamps and its tubes (spec_rediseno 6.3).
	look(hub_at + hub_out * 1.7 + Vector3(hub_out.z, 0, -hub_out.x) * 0.5 + Vector3(0, 0.3, 0), hub_at + Vector3(0, 0.1, 0))
	await shot("central")
	# The window counter from its corridor: its ledge and its sign (6.2).
	var win_room: Dictionary = m.rooms[int(m.mail.window)]
	# From the corridor, framed on its sign so the door's leaf is not in the way.
	for plate_node in level.hotel.find_children("*", "Label3D", true, false):
		if String(plate_node.text) != "PERSONAL": continue
		var sign_at: Vector3 = plate_node.global_position
		var sign_out: Vector3 = (plate_node.global_basis.z as Vector3).normalized()
		look(Vector3(sign_at.x, float(win_room.py) + 1.6, sign_at.z) + sign_out * 3.0 + Vector3(sign_out.z, 0, -sign_out.x), sign_at - Vector3(0, 1.0, 0))
		await shot("ventanilla_pasillo")
		break
	level.player.torch.visible = false
	files.requests[level.player.slot].state = files.Card.IN_TRAY
	# Its station with the card waiting: the receiver, its number, its lamp lit (6.3).
	files.show_state()
	files.show_capsules()
	var waiting: Dictionary = files.station_exits[int(files.requests[level.player.slot].station)]
	var st_at := Vector3(float(waiting.point[0]), float(waiting.point[1]), float(waiting.point[2]))
	var st_out: Vector3 = Basis(Vector3.UP, float(waiting.yaw)).z
	look(st_at + st_out * 1.4 + Vector3(st_out.z, 0, -st_out.x) * 0.5 + Vector3(0, 0.3, 0), st_at)
	await shot("estacion")
	files.apply("take", int(files.requests[level.player.slot].station) + 1, level.player.slot, {}, false)
	await shot("ficha")
	level.interaction.close_document()
	files.requests.clear()
	level.interaction.read_paper(files.paper_of(0))
	await shot("mapa_tubos")
	level.interaction.close_document()
	level.interaction.read_paper(level.objective(&"power").paper_of(0))
	await shot("memo_cuadro")
	level.interaction.close_document()
	# The card reader by the freight lift's door and what it says, then the
	# car from its lobby (6.15).
	var rd: Dictionary = m.mail.reader
	var rd_at := Vector3(float(rd.point[0]), float(rd.point[1]), float(rd.point[2]))
	var rd_out: Vector3 = Basis(Vector3.UP, float(rd.yaw)).z
	look(rd_at + rd_out * 1.4 + Vector3(rd_out.z, 0, -rd_out.x) * 0.3 + Vector3(0, 0.35, 0), rd_at + Vector3(0, 0.25, 0))
	await shot("lector")
	var car_frame: Transform3D = level.hotel.car_frames[0]
	look(car_frame * Vector3(0.0, 1.6, 2.6), car_frame * Vector3(-0.5, 1.1, -1.2))
	await shot("montacargas")
	# An open office's desks.
	for room in m.rooms:
		if int(room.wing) != 0 or int(room.type) != OFFICE.OPEN_OFFICE or level.hotel.dark_ids.has(int(room.id)) or room.get("furniture", []).is_empty(): continue
		var oc := FLOOR.position_of(room)
		var it: Dictionary = room.furniture[0]
		var desk_at := oc + Vector3(float(it.at[0]), 0, float(it.at[1]))
		look(desk_at + Vector3(1.8, 1.6, 1.8), desk_at + Vector3(0, 0.6, 0))
		await shot("mesas")
		look(desk_at + Vector3(0.9, 1.2, 1.4), desk_at + Vector3(0, 0.5, 0))
		level.player.torch.visible = true
		await shot("mesa_cerca")
		level.player.torch.visible = false
		break
	# An archive aisle under its batten.
	for unit in m.get("archives", []):
		var a: Array = unit.aisles[0]
		var mid := Vector3((float(a[0]) + float(a[2])) / 2, float(m.rooms[int(unit.rooms[0])].py), (float(a[1]) + float(a[3])) / 2)
		if int(m.rooms[int(unit.rooms[0])].wing) != 1: continue
		var long_x: bool = absf(float(a[2]) - float(a[0])) > absf(float(a[3]) - float(a[1]))
		# Planta 2 starts with no power: the board's zone over this archive on.
		var board = level.objective(&"power")
		for z in board.zones.size():
			if board.zones[z].rooms.has(int(unit.rooms[0])): board.apply("lever", z, 1, {}, true)
		look(mid + (Vector3(2.0, 1.6, 0) if long_x else Vector3(0, 1.6, 2.0)), mid + Vector3(0, 2.4, 0))
		await shot("archivo_regleta")
		break
	# The security post's wired glass seen from its corridor (6.12), when the
	# floor glazes it (seed 29 does).
	var glass_shot := false
	for room in m.rooms:
		if int(room.type) != OFFICE.SECURITY or room.get("glazed", []).is_empty(): continue
		var side: String = room.glazed[0]
		var way: Vector3 = {"west": Vector3(-1, 0, 0), "east": Vector3(1, 0, 0), "north": Vector3(0, 0, -1), "south": Vector3(0, 0, 1)}[side]
		var c := FLOOR.position_of(room)
		var half: float = (float(room.span_x) if absf(way.x) > 0.5 else float(room.span_z)) * 0.5
		var pane := c + way * half
		look(pane + way * 1.0 + Vector3(way.z, 0, -way.x) * 0.8 + Vector3(0, 1.6, 0), pane + Vector3(0, 1.6, 0))
		level.player.torch.visible = true
		await shot("cristal_armado")
		level.player.torch.visible = false
		glass_shot = true
		break
	if not glass_shot: print("LOOK cristal_armado none")
	# A ceiling gap with its tile hanging.
	for e in m.ducts.exits:
		if String(e.kind) != "gap" or int(m.rooms[int(e.room)].wing) != 0: continue
		var gap_at := Vector3(float(e.point[0]), 0, float(e.point[2]))
		if level.hotel.vary(level.hotel.room_nodes[int(e.room)].position + (gap_at - level.hotel.room_nodes[int(e.room)].position), 161) >= 0.4: continue
		look(gap_at + Vector3(1.8, 1.6, 1.8), gap_at + Vector3(0, 2.6, 0))
		level.player.torch.visible = true
		await shot("hueco_placa")
		level.player.torch.visible = false
		break
	var MD = load("res://game/world/office/main_duct_geometry.gd")
	level.player.torch.visible = true
	var foot: Transform3D = MD.foot(m)
	var hatch: Vector3 = MD.hatch_floor(m)
	var out: Vector3 = MD.facing(float(m.air.hatch.yaw))
	look(foot.origin + out * 2.5 + Vector3(0, 1.6, 0), hatch + Vector3(0, 0.3, 0))
	await shot("planta_escalerilla")
	var unit: Dictionary = m.air.unit
	var unit_at := Vector3(float(unit.point[0]), float(unit.point[1]), float(unit.point[2]))
	var unit_out: Vector3 = Basis(Vector3.UP, float(unit.yaw)).z
	var unit_side: Vector3 = Basis(Vector3.UP, float(unit.yaw)).x
	# Three quarters from the side of its pipes: its doors and plate show too.
	look(unit_at + unit_out * 3.0 + unit_side * 2.2 + Vector3(0, 1.6, 0), unit_at + unit_out * 1.0 + unit_side * 1.0 + Vector3(0, 1.1, 0))
	await lit_shot("climatizadora")
	look(hatch + out * 2.2 + Vector3(out.z, 0, -out.x) * 0.5 + Vector3(0, 0.3, 0), hatch + Vector3(0, 0.3, 0))
	await lit_shot("compuerta")
	level.objective(&"air").hatch_open = true
	level.objective(&"air").show_hatch(false)
	await lit_shot("compuerta_abierta")
	# The security post's console on its desk (6.12).
	var post: Dictionary = m.air.security.desk
	var post_at := Vector3(float(post.point[0]), float(post.point[1]), float(post.point[2]))
	var post_in: Vector3 = Basis(Vector3.UP, float(post.yaw)).z
	look(post_at + post_in * 1.8 + Vector3(post_in.z, 0, -post_in.x) * 0.7 + Vector3(0, 1.55, 0), post_at + post_in * 0.2 + Vector3(0, 1.0, 0))
	await shot("seguridad_consola")
	# The main duct's sign (6.14), seen from the side of the plant's middle.
	var plant_room: Dictionary = m.rooms[int(m.air.plant)]
	var duct_side := Vector3(out.z, 0, -out.x)
	if (FLOOR.position_of(plant_room) - hatch).dot(duct_side) < 0.0: duct_side = -duct_side
	var duct_sign_at := hatch - out * 0.75 + duct_side * 0.6 + Vector3(0, 0.74, 0)
	look(duct_sign_at + duct_side * 1.8 + out * 0.5, duct_sign_at)
	await lit_shot("ducto_rotulo")
	var mouth: Transform3D = MD.mouth(m)
	var into: Vector3 = -out
	look(mouth.origin + Vector3(0, 0.62, 0), mouth.origin + into * 6.0 + Vector3(0, 0.55, 0))
	await shot("ducto_dentro")
	var rp: Array = m.air.remains.point
	var remains := Vector3(float(rp[0]), MD.floor_y(m), float(rp[2]))
	var along := Vector3(1, 0, 0)
	for box in MD.boxes(m):
		if (box as AABB).grow(0.05).has_point(remains + Vector3(0, 0.1, 0)):
			along = Vector3(1, 0, 0) if box.size.x >= box.size.z else Vector3(0, 0, 1)
			break
	look(remains + along * 1.1 + Vector3(0, 0.6, 0), remains + Vector3(0, 0.1, 0))
	await shot("restos")
	var r: Array = m.air.shaft.rect
	var sp: Array = m.air.shaft.point
	var landing := Vector3(float(r[0]), MD.floor_y(m), float(r[1]))
	var mouth_at := Vector3(float(sp[0]), MD.floor_y(m), float(sp[2]))
	look(mouth_at + (mouth_at - landing).normalized() * 1.0 + Vector3(0, 0.62, 0), landing + Vector3(0, 0.2, 0))
	await shot("pozo")
	# Planta 2: a zone's room without power, then with it.
	var power = level.objective(&"power")
	level.player.torch.visible = false
	var target := -1
	for id in power.zones[0].rooms:
		var room: Dictionary = m.rooms[int(id)]
		if not bool(room.get("corridor", false)) and not level.hotel.dark_ids.has(int(id)) and String(OFFICE.lamp_of(room)) == "troffer":
			target = int(id)
			break
	if target < 0: target = int(power.zones[0].rooms[0])
	var room2: Dictionary = m.rooms[target]
	var centre := FLOOR.position_of(room2)
	look(centre + Vector3(float(room2.span_x) * 0.35, 1.6, float(room2.span_z) * 0.35), centre + Vector3(-1.0, 2.6, -1.0))
	await shot("planta2_sin_corriente")
	power.apply("lever", 0, 1, {}, true)
	await shot("planta2_con_corriente")
	# A corridor of planta 2 with no power: the battery units.
	var units: Array = level.hotel.emergency.filter(func(e): return int(e.planta) == 1 and int(m.rooms[int(e.room)].type) == OFFICE.CORRIDOR and not level.hotel.lit(int(e.room)))
	print("LOOK emergency units %d, on planta 2 unlit corridors %d" % [level.hotel.emergency.size(), units.size()])
	if not units.is_empty():
		var e: Dictionary = units[units.size() / 2]
		var room3: Dictionary = m.rooms[int(e.room)]
		var c := FLOOR.position_of(room3)
		var spot: Vector3 = e.spot
		var away := Vector3(c.x - spot.x, 0, c.z - spot.z).normalized()
		look(c + away * 0.6 + Vector3(0, 1.6, 0) + Vector3(away.z, 0, -away.x) * 3.0, spot)
		await shot("emergencia_pasillo")
	# The board in the electrical room (6.13), powered and lit for the picture; the torch stays on for the minutero.
	var board_spot: Dictionary = m.power.board
	var b_at := Vector3(float(board_spot.point[0]), float(board_spot.point[1]), float(board_spot.point[2]))
	var b_out: Vector3 = Basis(Vector3.UP, float(board_spot.yaw)).z
	level.hotel.set_room_power(int(m.power.room), true)
	level.player.torch.visible = true
	look(b_at + b_out * 3.0 + Vector3(b_out.z, 0, -b_out.x) * 0.6 + Vector3(0, 1.6, 0), b_at + Vector3(0, 1.4, 0))
	await lit_shot("cuadro")
	# A minutero running: its pilot lit.
	var timers: Array = m.power.timers
	if not timers.is_empty():
		var timer_spot: Dictionary = timers[0]
		var t_at := Vector3(float(timer_spot.point[0]), float(timer_spot.point[1]), float(timer_spot.point[2]))
		var t_out: Vector3 = Basis(Vector3.UP, float(timer_spot.yaw)).z
		power.apply("switch", power.red_index() + 1, 1, {}, true)
		power.tick(0.0)
		look(t_at + t_out * 1.1 + Vector3(t_out.z, 0, -t_out.x) * 0.4 + Vector3(0, 0.4, 0), t_at)
		await shot("minutero")
	level.player.torch.visible = false
	quit()
