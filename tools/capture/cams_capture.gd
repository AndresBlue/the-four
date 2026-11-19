extends SceneTree
## The security post's console in pictures (.claude/specs/cordura_y_edificio.md
## phase 7): the post and its monitors, the cameras' screen on the air room's
## camera in the dark and on another, two rooms lit from it, a lock opened,
## the air room lit (the air handler on its camera) and its lock opened.
## No creature, at Alto. With a window:
##   godot --path . --script res://tools/capture/cams_capture.gd --log-file <log> -- --automation --test-profile --silent [--seed=7]
## Writes evidence/planta/fase7/<n>_<what>.png and sesion.txt.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OUT := "res://evidence/planta/fase7"
var level
var lines: Array = []

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())

## The console's pointer put on one of its buttons, by its id.
func point_at(id: String) -> void:
	for zone in level.objective(&"air").console.zones:
		if String(zone.id) == id: level.objective(&"air").console.pointer = (zone.rect as Rect2).get_center()

func shot(title: String, settle := 1.5) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(settle * 1000.0): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(OUT + "/" + title + ".png")
	lines.append(title)
	print("CAMS_SHOT " + title)

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
	var air = level.objective(&"air")
	var m: Dictionary = level.manifest
	level.player.torch.visible = true
	# The post, open, from its door: the console and its monitors.
	air.post_open = true
	air.show_post()
	var desk: Dictionary = m.air.security.desk
	var face := Basis(Vector3.UP, float(desk.yaw)).z
	var desk_at := Vector3(float(desk.point[0]), float(desk.point[1]), float(desk.point[2]))
	level.hotel.start_bounce(2)
	look(desk_at + face * 2.3 + Vector3(0, 1.6, 0), desk_at + face * 0.2 + Vector3(0, 1.0, 0))
	level.hotel.update_visibility(level.player.global_position, true)
	await shot("50_puesto_consola", 2.5)
	# Sat: the cameras.
	level.player.global_position = air.usables[4].stand + Vector3(0, 0.04, 0)
	await process_frame
	level.match_net.use_office(&"air", "sit", 4)
	await process_frame
	var vent: int = air.vent_cam()
	lines.append("sentado: %s, ventilación en CAM %d" % [str(air.console != null), vent + 1])
	air.console.show_cam(vent)
	await shot("51_camaras_ventilacion", 2.5)
	var other := (vent + 1) % 8
	air.console.show_cam(other)
	await shot("52_camaras_otra_sala", 2.5)
	# The static between two cameras, held still.
	air.console.set_process(false)
	air.console.screen.set_shader_parameter("burst", 0.55)
	await shot("52b_estatica", 0.3)
	air.console.set_process(true)
	# Two rooms lit from the console: the other camera's and a corridor's.
	level.match_net.use_office(&"air", "light", int(m.air.cams[other].room))
	for room in m.rooms:
		if bool(room.get("corridor", false)) and air.lightable(int(room.id)):
			level.match_net.use_office(&"air", "light", int(room.id))
			break
	point_at("light")
	await shot("53_camaras_luz", 2.5)
	air.console.pointer = Vector2.INF
	# The same room from the player's own camera at the security camera's place.
	var cam_other: Dictionary = m.air.cams[other]
	air.console.visible = false
	level.player.reading = false
	look(Vector3(float(cam_other.point[0]), float(cam_other.point[1]), float(cam_other.point[2])), Vector3(float(cam_other.look[0]), float(cam_other.look[1]), float(cam_other.look[2])))
	level.player.set_physics_process(false)
	await shot("53b_ojo_del_jugador_alli", 2.0)
	var lamp: Light3D = level.hotel.lights[int(cam_other.room)]
	lines.append("sala de CAM %d: con luz %s, lámpara visible %s, energía %.2f, apagada %s, oscura %s" % [other + 1, str(level.hotel.lit(int(cam_other.room))), str(lamp.visible), lamp.light_energy, str(lamp.has_meta("off")), str(level.hotel.dark_ids.has(int(cam_other.room)))])
	air.console.visible = true
	level.player.set_physics_process(true)
	level.player.global_position = air.usables[4].stand + Vector3(0, 0.04, 0)
	level.match_net.use_office(&"air", "lock", other)
	await shot("54_camaras_cierre_abierto", 1.5)
	# The air room, lit: its camera on the air handler, then its lock opened.
	air.console.show_cam(vent)
	level.match_net.use_office(&"air", "light", int(m.air.room))
	await shot("55_camaras_ventilacion_con_luz", 2.5)
	level.match_net.use_office(&"air", "lock", vent)
	await shot("56_camaras_ventilacion_abierta", 2.0)
	lines.append("luces %d, abiertas %s" % [air.lights.size(), str(air.unlocked)])
	# The plan, coming up and up, the pointer on a lit corridor.
	air.console.act("plan")
	await shot("57_plano_subiendo", 0.1)
	await shot("58_plano", 1.5)
	for room_id in air.lights: point_at("room:%d" % int(room_id))
	await shot("59_plano_sobre_una_sala", 1.0)
	point_at("cam:%d" % other)
	await shot("60_plano_sobre_una_camara", 1.0)
	var file := FileAccess.open(OUT + "/sesion.txt", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	quit(0)
