extends SceneTree
## Her drink of a room from a survivor's eyes (.claude/specs/lurker_versus.md
## 8; phase 4), in Alto at 1280x720, floor 2, seed 81, Equilibrada: a lit
## corridor with the torch on (antes); drunk dark, the torch out (bebida);
## the torch lit again at its third press (reencendida). Her mind is off and
## she is out of the way. Writes evidence/versus/f4/<name>.png.
##   godot --path . --rendering-method forward_plus --script res://tools/capture/lurker_drink_capture.gd -- --automation --test-profile --silent
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const OUT := "res://evidence/versus/f4"
var level
var lurker

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())
	level.player.snap_torch()

func shot(name: String) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("SHOT ", name, " lit=", level.hotel.lit(int(corridor.room)), " torch=", level.player.torch.visible, " dim=", level.player.torch_dim)

var corridor := {}

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
	corridor = find_corridor()
	if corridor.is_empty():
		print("NO corridor")
		quit(1)
		return
	var room := int(corridor.room)
	var centre: Vector3 = corridor.centre
	var along: Vector3 = corridor.along
	level.hotel.set_room_power(room, true)
	look(centre - along * 2.5 + Vector3(0, 1.6, 0), centre + along * 4.0 + Vector3(0, 1.1, 0))
	level.player.torch.visible = true
	await shot("antes")
	lurker.drink(room, 600.0, 1.5)
	await shot("bebida")
	# Her clock past RELIGHT_AFTER (her mind is off), then the three presses.
	lurker.brain.clock += 1.2
	for i in 3:
		level.player.torch.visible = not level.player.torch.visible
		for k in 9: await process_frame
	await shot("reencendida")
	lurker.snuff(-1)
	level.queue_free()
	await process_frame
	quit(0)

## The capture's corridor (lurker_drink_test.gd's): planta 1, long, hers to
## hold on to and to drink, not one of the floor's dark rooms.
func find_corridor() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or int(room.type) != OFFICE.CORRIDOR or level.hotel.dark_ids.has(id): continue
		var span := FLOOR.size_of(room)
		if maxf(span.x, span.y) < 7.0 or not lurker.shell.tray_of.has(id): continue
		if level.manifest.adjacency[id].any(func(other): return off.has(int(other))): continue
		var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
		return {"room": id, "centre": FLOOR.position_of(room), "along": along}
	return {}
