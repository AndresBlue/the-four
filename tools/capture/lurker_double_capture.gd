extends SceneTree
## Her double from a survivor's eyes (.claude/specs/cordura_y_edificio.md 3.5),
## in Alto at 1280x720, floor 2, seed 81, Equilibrada: an office of planta 1,
## lit, its double upside down in the corner (sala_luz) and the same with the
## room dark and the torch on it (sala_linterna); then its leap at the eyes
## half way (salto). Her mind is off and she is out of the way.
## Writes evidence/versus/doble/survivor_<name>.png.
##   godot --path . --rendering-method forward_plus --script res://tools/capture/lurker_double_capture.gd -- --automation --test-profile --silent
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const OUT := "res://evidence/versus/doble"
var level
var lurker

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())
	level.player.snap_torch()

func shot(name: String, frames := 40) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/survivor_%s.png" % [OUT, name])
	print("SHOT ", name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	level.ui.finish_intro()
	await level.start_floor(81, false, [1], "equilibrada")
	level.settings.set_designed(PRESETS.HIGH)
	await level.bounce_ready()
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	level.player.set_process_input(false)
	level.player.set_process_unhandled_input(false)
	lurker = level.creature
	lurker.thinking = false
	lurker.set_physics_process(false)
	lurker.global_position = Vector3(0, -80, 0)
	var room := office()
	if room.is_empty():
		print("NO office")
		quit(1)
		return
	var id := int(room.id)
	var centre := FLOOR.position_of(room)
	var corner: Dictionary = lurker.doubles.corner_of(id, centre + Vector3(10, 0, 10))
	lurker.doubles.put(1, id, corner.point, float(corner.yaw))
	var head: Vector3 = lurker.doubles.head_of(1)
	# From the far corner of the room, at eye height, looking at it.
	var eye := Vector3(centre.x - (head.x - centre.x) * 0.8, centre.y + 1.6, centre.z - (head.z - centre.z) * 0.8)
	level.hotel.set_room_power(id, true)
	look(eye, head)
	level.player.torch.visible = false
	await shot("sala_luz")
	level.hotel.set_room_power(id, false)
	level.player.torch.visible = true
	await shot("sala_linterna")
	lurker.doubles.pounce(1, int(level.player.slot))
	lurker.doubles.doubles[1].from = (lurker.doubles.doubles[1].node as Node3D).global_position
	await shot("salto", 18)
	level.queue_free()
	await process_frame
	quit(0)

## An office of planta 1 with a false ceiling, mid-sized, not protected.
func office() -> Dictionary:
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 0 or int(room.type) != OFFICE.OFFICE or not OFFICE.false_ceiling(room): continue
		var size := FLOOR.size_of(room)
		if size.x < 3.4 or size.y < 3.4 or level.point_protected(FLOOR.position_of(room)): continue
		return room
	return {}
