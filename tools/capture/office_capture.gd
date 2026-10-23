extends SceneTree
## Views of floor 2 (spec_f1_systems 6.5), with a window: the receipt, the
## card with its photo, the tubes, the window's desk, the tube map, the board's
## memo, a glazed office, a ceiling gap, the plant ladder and hatch, inside the
## main duct, the shaft, a planta-2 room without power and with it, and a
## corridor under its emergency units. PNGs in evidence/office_capture_*.png.
##
##   godot --path . --script res://tools/capture/office_capture.gd -- --test-profile [--seed=7]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
var level

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
	root.get_texture().get_image().save_png("res://evidence/office_capture_%s.png" % name)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 7
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	await level.start_floor(seed_value, false, [1], "", 2)
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
	level.player.torch.visible = false
	files.requests[level.player.slot].state = files.Card.IN_TRAY
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
	# A glazed office seen from its corridor.
	for room in m.rooms:
		if int(room.wing) != 0 or room.get("glazed", []).is_empty() or level.hotel.dark_ids.has(int(room.id)): continue
		var side: String = room.glazed[0]
		var way: Vector3 = {"west": Vector3(-1, 0, 0), "east": Vector3(1, 0, 0), "north": Vector3(0, 0, -1), "south": Vector3(0, 0, 1)}[side]
		var c := FLOOR.position_of(room)
		var half: float = (float(room.span_x) if absf(way.x) > 0.5 else float(room.span_z)) * 0.5
		var pane := c + way * half
		look(pane + way * 1.0 + Vector3(way.z, 0, -way.x) * 0.8 + Vector3(0, 1.6, 0), pane + Vector3(0, 1.6, 0))
		await shot("cristal_armado")
		break
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
	level.objective(&"air").hatch_open = true
	level.objective(&"air").show_hatch(false)
	await shot("compuerta_abierta")
	var mouth: Transform3D = MD.mouth(m)
	var into: Vector3 = -out
	look(mouth.origin + Vector3(0, 0.62, 0), mouth.origin + into * 6.0 + Vector3(0, 0.55, 0))
	await shot("ducto_dentro")
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
	quit()
