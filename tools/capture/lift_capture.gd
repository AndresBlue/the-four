extends SceneTree
## The lifts, which are how a floor is walked out of: the refuge's own door,
## the car waiting in the lobby behind it, the inside of the car, and the one
## it puts people down at in the next wing. Camera placement only.
##   godot --path . --script tools/capture/lift_capture.gd
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String, frames := 45) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/lift_%s.png" % filename)

func look_from(from: Vector3, at: Vector3, pitch := -0.04) -> void:
	level.player.position = from + Vector3(0, 0.04, 0)
	var d := at - from
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(pitch, 0, 0)
	level.player.snap_torch()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.settings.values.quality = 2
	# Without the tape filter and with the torch on: these shots are for
	# looking at the thing that was built, not at the presentation.
	for key in ["vhs", "grain", "chromatic", "scanlines"]: level.settings.values[key] = 0.0
	level.settings.values.reduced = true
	level.apply_settings()
	level.apply_lens(false, true)
	for key in ["vhs", "grain", "chromatic", "scanlines", "noise"]:
		if level.post_material.get_shader_parameter(key) != null: level.post_material.set_shader_parameter(key, 0.0)
	level.player.torch.visible = true
	# Every gate open, so the doors are not in the way of their own lobbies.
	for door in level.hotel.gates:
		door.locked = false
		door.set_state(true)
	# The floor is still coming up on the first frames: the shots would catch
	# the tape screen instead of the hotel.
	for i in 240: await process_frame
	for stage in level.manifest.gates.size():
		var gate: Dictionary = level.manifest.gates[stage]
		var refuge: Dictionary = level.manifest.rooms[int(gate.room)]
		var car: Vector3 = level.hotel.lifts[stage]
		# From the middle of the refuge, looking at the door its lift is behind.
		look_from(FLOOR.position_of(refuge), car)
		await shot("%d_refuge" % (stage + 1))
		# From the lobby, the car waiting across it, near and far.
		var into: Vector3 = (FLOOR.position_of(refuge) - car).normalized()
		look_from(car + into * 4.5, car + Vector3(0, 1.2, 0))
		await shot("%d_lobby" % (stage + 1))
		look_from(car + into * 2.2, car + Vector3(0, 1.2, 0))
		await shot("%d_car" % (stage + 1))
		var arrival: Vector3 = level.hotel.arrivals[stage]
		if arrival == Vector3.ZERO: continue
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, arrival)
		look_from(arrival + (FLOOR.position_of(room) - arrival).normalized() * 3.0, arrival)
		await shot("%d_arrival" % (stage + 1))
	print("LIFT_SHOTS ok")
	quit()
