extends SceneTree
## Planta 2's new route in pictures (.claude/specs/cordura_y_edificio.md phase
## 6): the board with three sectors up and after a fourth trips them, the
## maneuver room's door without its sector's power and with it, its motor
## half way and done, the room inside with the lift's lever, and that lever
## pulled. As the game shows it (the tape and the torch on), no creature, at
## Alto. With a window:
##   godot --path . --script res://tools/capture/maneuver_capture.gd --log-file <log> -- --automation --test-profile --silent [--seed=7]
## Writes evidence/planta/fase6/<n>_<what>.png and sesion.txt.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OUT := "res://evidence/planta/fase6"
var level
var lines: Array = []

func _initialize() -> void: run.call_deferred()

## The player's eye at `from`, looking at `at`.
func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())

func shot(title: String, settle := 1.2) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	await level.bounce_ready()
	level.hotel.update_visibility(level.player.global_position, true)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(settle * 1000.0): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(OUT + "/" + title + ".png")
	lines.append(title)
	print("MANEUVER_SHOT " + title)

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 7
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(2)
	level.creature_scene = "none"
	await level.start_floor(seed_value, false, [1], "apacible", 2)
	level.apply_settings()
	await level.bounce_ready()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in 30: await process_frame
	level.player.set_physics_process(false)
	level.player.torch.visible = true
	var power = level.objective(&"power")
	var m: Dictionary = level.manifest
	level.hotel.start_bounce(1)
	# The board, from in front of it.
	var board: Dictionary = m.power.board
	var face := Basis(Vector3.UP, float(board.yaw)).z
	var board_at := Vector3(float(board.point[0]), float(board.point[1]), float(board.point[2]))
	for z in power.BACKUP: power.apply("lever", z, -1, {}, true)
	look(board_at + face * 2.4 + Vector3(0, 1.6, 0), board_at + Vector3(0, 1.4, 0))
	await shot("40_cuadro_tres_sectores")
	power.apply("lever", power.BACKUP, -1, {}, true)
	await shot("41_cuadro_cuarta_salta")
	lines.append("sectores arriba tras la cuarta: %d" % power.on_order.size())
	# The maneuver room's door, from the corridor.
	var door = power.motor_door
	var away: Vector3 = (power.usables[power.door_index()].stand - Vector3(door.doorway.x, power.usables[power.door_index()].stand.y, door.doorway.z)).normalized()
	# From across the corridor, a little to the side: the wall behind is 2.4 m off or more.
	var eye: Vector3 = door.doorway + away * 1.9 + door.along() * 0.7 + Vector3(0, 1.6, 0)
	look(eye, door.doorway + Vector3(0, 1.6, 0))
	await shot("42_puerta_sin_corriente")
	var told: Dictionary = power.apply("door", power.door_index(), -1, {}, true)
	lines.append("sin corriente, la puerta: %s, abierta %s" % [str(told), str(door.opened)])
	var zone: int = power.zone_of(power.maneuver_room)
	power.apply("lever", zone, -1, {}, true)
	look(eye, door.doorway + Vector3(0, 1.6, 0))
	await shot("43_puerta_con_corriente")
	told = power.apply("door", power.door_index(), -1, {}, true)
	lines.append("con corriente, la puerta: %s" % str(told))
	await shot("44_puerta_abriendose", 2.0)
	await shot("45_puerta_abierta", 3.5)
	lines.append("abierta: %s, con llave: %s" % [str(door.opened), str(door.locked)])
	# Inside: the lift's cabinet and its lever, from the door.
	var spot: Dictionary = m.power.maneuver.lever
	var lever_at := Vector3(float(spot.point[0]), float(spot.point[1]), float(spot.point[2]))
	var inward := Basis(Vector3.UP, float(spot.yaw)).z
	look(lever_at + inward * 2.2 + Vector3(0, 1.6, 0), lever_at + Vector3(0, 1.4, 0))
	await shot("46_sala_maniobra")
	var lamp: Light3D = level.hotel.lights[power.maneuver_room] if power.maneuver_room < level.hotel.lights.size() else null
	lines.append("sala de maniobra: con corriente %s, con luz %s, lámpara %s" % [str(power.powered(power.maneuver_room)), str(level.hotel.lit(power.maneuver_room)), "ninguna" if lamp == null else "visible %s, energía %.2f, apagada %s" % [str(lamp.visible), lamp.light_energy, str(lamp.has_meta("off"))]])
	power.apply("lift", power.lift_index(), -1, {}, true)
	await shot("47_palanca_bajada")
	lines.append("montacargas suelto: %s" % str(power.freed))
	var file := FileAccess.open(OUT + "/sesion.txt", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	quit(0)
