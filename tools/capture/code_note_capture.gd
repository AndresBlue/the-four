extends SceneTree
## The four pieces of furniture that hold a number of the code, and what says
## so: a slip of paper left showing. One shot from the doorway of the room
## (which is the distance that matters -- it has to be worth crossing for) and
## one from arm's length, plus the same piece with its number already taken.
##   godot --path . --script tools/capture/code_note_capture.gd
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String, frames := 45) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/code_note_%s.png" % filename)

func look_from(from: Vector3, at: Vector3, pitch := -0.1) -> void:
	level.player.position = from + Vector3(0, 0.04, 0)
	var d := at - from
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(pitch, 0, 0)
	level.player.snap_torch()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.settings.values.quality = 2
	for key in ["vhs", "grain", "chromatic", "scanlines"]: level.settings.values[key] = 0.0
	level.settings.values.reduced = true
	level.apply_settings()
	level.apply_lens(false, true)
	for key in ["vhs", "grain", "chromatic", "scanlines", "noise"]:
		if level.post_material.get_shader_parameter(key) != null: level.post_material.set_shader_parameter(key, 0.0)
	level.player.torch.visible = true
	var hidden: Array = level.containers.filter(func(piece): return piece.digit >= 0)
	print("CODE_NOTES ", hidden.size())
	for piece in hidden: print("  ", piece.kind)
	if hidden.is_empty():
		quit()
		return
	var piece = hidden[0]
	var at: Vector3 = piece.global_position + Vector3(0, 0.9, 0)
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, piece.global_position)
	# From the middle of the room, which is as close as anybody gets before
	# deciding whether that piece is worth a second of their time.
	look_from(FLOOR.position_of(room) + Vector3(0, 1.6, 0), at)
	await shot("room")
	var towards: Vector3 = (FLOOR.position_of(room) - piece.global_position).normalized()
	look_from(piece.global_position + towards * 1.6 + Vector3(0, 1.55, 0), at, -0.3)
	await shot("close")
	# Gone through: the paper leaves with whoever took it.
	level.apply_search(level.containers.find(piece), true)
	await shot("taken")
	# And the number stays written on the tape.
	print("CODE_NOTE_TAPE ", level.camcorder.code_note.text)
	quit()
