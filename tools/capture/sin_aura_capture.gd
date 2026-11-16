extends SceneTree
## The Lurker's new lies to a mind nearly gone (lurker_hallucinations, the
## author's 16 November 2026: no aura), from the player's camera at Alto: fresh
## ink on the ceiling, a tile lifted over the listener with its dust, a shadow
## across the torch's beam, and her hanging over the lintel of the door just
## come through. She is far off; nothing here is her. With a window:
##   godot --path . --script res://tools/capture/sin_aura_capture.gd -- --automation --test-profile --silent
## Shots in evidence/sin_aura/*.png.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const OUT := "res://evidence/sin_aura/"
var level
var lies

func _initialize() -> void: run.call_deferred()

func shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + filename + ".png")
	print("CAPTURE evidence/sin_aura/%s.png" % filename)

func seconds(time: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(time * 1000.0):
		level.sanity.hallucination_wait = 999.0
		await process_frame

## Looks at a point from where the player stands.
func face(point: Vector3) -> void:
	var camera: Camera3D = level.player.camera
	var towards := point - camera.global_position
	level.player.rotation.y = atan2(-towards.x, -towards.z)
	camera.rotation.x = clampf(atan2(towards.y, Vector2(towards.x, towards.z).length()), -1.3, 1.3)

func stand(point: Vector3) -> void:
	level.player.global_position = point
	level.hotel.update_visibility(level.player.position, true)
	await seconds(0.3)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.ui.finish_intro()
	level.creature_scene = "lurker"
	level.set_floor(2)
	await level.start_floor(81, false, [1], "equilibrada")
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	var lurker = level.creature
	lurker.thinking = false
	lurker.set_physics_process(false)
	lurker.global_position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	level.player.set_process_input(false)
	level.player.set_process_unhandled_input(false)
	level.settings.values.quality = 2
	level.apply_settings()
	level.world_audio.enabled = true
	level.player.sanity = 15.0
	level.sanity.hallucination_wait = 999.0
	lies = level.sanity.creature_lies()
	var sight = level.sanity.ensure_sight()
	sight.set_physics_process(false)
	sight.ensure_model()
	var room := {}
	for r in level.manifest.rooms:
		if FLOOR.is_void(r) or int(r.get("wing", -1)) != 0 or level.point_protected(FLOOR.position_of(r)): continue
		if OFFICE.false_ceiling(r) and level.hotel.lit(int(r.id)) and float(r.span_x) >= 5.0 and float(r.span_z) >= 5.0:
			room = r
			break
	if room.is_empty():
		print("SIN_AURA no room")
		quit(1)
		return
	var at := FLOOR.closest(level.get_world_3d().navigation_map, FLOOR.position_of(room)) + Vector3(0, 0.04, 0)
	await stand(at)
	# Fresh ink on the ceiling a few metres off.
	var ink: Vector3 = lies.ink(at, 0.75)
	face(ink)
	await seconds(2.5)
	await shot("tinta")
	for job in lies.jobs.duplicate(): if lies.step(job, 100.0): lies.jobs.erase(job)
	# A tile over them lifted, with the dust it lets down.
	var tile: Vector3 = lies.lift_tile(at, 0.9)
	lies.dust_over(at)
	face(tile)
	await seconds(0.55)
	await shot("placa")
	await seconds(1.5)
	# A shadow across the torch's beam on a wall ahead.
	level.player.torch.visible = true
	var beam := {}
	for turn in 12:
		level.player.rotation.y = TAU * turn / 12.0
		level.player.camera.rotation.x = 0.0
		await process_frame
		beam = lies.beam_spot(level.player.camera)
		if not beam.is_empty() and (beam.point as Vector3).distance_to(level.player.camera.global_position) <= 7.0: break
	if not beam.is_empty():
		lies.beam_shadow(beam)
		await seconds(0.22)
		await shot("haz")
	# Through a door, and half turned back: her over its lintel.
	var found := false
	for door in level.hotel.doors:
		if found: break
		if not is_instance_valid(door) or door.locked or FLOOR.planta_of(door.doorway.y) != 0: continue
		var across: Vector3 = door.across()
		var base := FLOOR.planta_y(0) + 0.04
		var steps := [door.doorway - across * 1.5, door.doorway - across * 0.4, door.doorway + across * 4.5]
		var ok := true
		for p in steps:
			p.y = base
			if FLOOR.room_at(level.manifest.rooms, p).is_empty() or level.point_protected(p): ok = false
		if not ok: continue
		if not door.opened: door.open_immediately()
		lies.passed = {}
		for p in steps:
			p.y = base
			await stand(p)
			lies.track_door()
		if lies.passed.is_empty(): continue
		for turn in [deg_to_rad(35.0), deg_to_rad(-35.0)]:
			var to: Vector3 = door.doorway - level.player.global_position
			level.player.rotation.y = atan2(-to.x, -to.z) + turn
			level.player.camera.rotation.x = 0.1
			await process_frame
			for spot in lies.sight_spots(sight, level.player.camera):
				if String(spot.kind) != "lintel" or not sight.place_spot(spot, level.player.camera): continue
				print("SIN_AURA puerta %s a lo ancho %s, ella %s cabeza %s, ojo %s, lado de ella %.2f, del ojo %.2f" % [str(door.doorway), str(across), str(spot.point), str(sight.face_point), str(level.player.camera.global_position), across.dot((spot.point as Vector3) - door.doorway), across.dot(level.player.camera.global_position - door.doorway)])
				sight.model.visible = true
				sight.seen_for = 1.0
				level.hotel.light_body(sight.model)
				sight.pose(1.0)
				# Where the game would show her first, and then looked at.
				await seconds(0.3)
				await shot("dintel_al_borde")
				face(sight.face_point)
				sight.pose(1.0)
				await seconds(0.3)
				await shot("dintel")
				found = true
				break
			if found: break
	print("SIN_AURA dintel %s" % str(found))
	level.queue_free()
	await process_frame
	quit()
