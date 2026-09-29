extends SceneTree
## Every kind of place a note of the code can be left, photographed: one piece
## of each (the commode, the painted cabinet, the console, the drawers, the
## bookcase on each of its three shelves, the cardboard box and the crate),
## with a note planted on it whether it hides a number or not, from arm's
## length (evidence/note_<kind>_close.png) and from across the room
## (evidence/note_<kind>_room.png), up to it (note_<kind>_detail.png) and from the side, level with
## it (note_<kind>_side.png). The notes are looked for over several
## floors until every kind has turned up.
##   godot --path . --script tools/capture/note_survey_capture.gd [-- --seeds=81,777,202]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var seen := {}

func _initialize() -> void: run.call_deferred()

func shot(filename: String, frames := 40) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/note_%s.png" % filename)

## The camera's eye at `eye`, looking at `at`.
func look(eye: Vector3, at: Vector3) -> void:
	# Held where it is put: left to its physics, a body put at a drawer's
	# height fell to the floor before the shot and the camera with it.
	level.player.set_physics_process(false)
	level.player.velocity = Vector3.ZERO
	level.player.position = eye - Vector3(0, level.player.eye_height, 0)
	var d := at - eye
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	level.player.snap_torch()

## Which variant of note this piece has.
func variant(piece) -> String:
	var spot: Dictionary = piece.note_spot
	if spot.is_empty(): return piece.kind + "_none"
	var model := String(spot.get("model", ""))
	match model:
		"wooden_bookshelf_worn":
			var y: float = ((spot.piece as Transform3D).affine_inverse() * (spot.at as Vector3)).y
			return "bookcase_%s" % ("low" if y < 0.8 else "middle" if y < 1.1 else "high")
		"GothicCommode_01": return piece.kind + "_commode"
		"painted_wooden_cabinet": return "cabinet_painted"
		"ClassicConsole_01": return "console"
		"drawer_cabinet": return "drawers"
		"cardboard_box_01": return "boxes_cardboard"
		"plastic_crate_02": return "boxes_crate"
	return piece.kind + "_" + model

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var seeds := [81, 777, 202, 4242]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	for seed_value in seeds:
		await level.start_floor(seed_value)
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
		for i in 120: await process_frame
		for piece in level.containers:
			var name := variant(piece)
			if seen.has(name): continue
			seen[name] = true
			piece.plant_note()
			var note: Node3D = piece.note
			var at: Vector3 = note.global_position if is_instance_valid(note) else piece.global_position + Vector3(0, 0.9, 0)
			var out: Vector3 = piece.global_basis.z.normalized()
			var side: Vector3 = piece.global_basis.x.normalized()
			var floor_y: float = piece.global_position.y
			# Arm's length, a little to one side, from a standing eye.
			look(Vector3(at.x, floor_y + 1.64, at.z) + out * 1.0 + side * 0.35, at)
			await shot(name + "_close")
			# Up to it, as a hand would be: where the paper meets the wood.
			# A note near the floor (on a crate) is looked down at, as it would be.
			var above: float = 0.22 if at.y - floor_y > 0.5 else 0.6
			look(at + out * 0.5 + side * 0.18 + Vector3(0, above, 0), at)
			await shot(name + "_detail")
			# From the side, level with it: whether the paper lies on the wood
			# or goes into it.
			look(at + side * 0.45 + out * 0.3 + Vector3(0, 0.04, 0), at)
			await shot(name + "_side")
			# From across the room, as it is first seen.
			var room: Dictionary = FLOOR.room_at(level.manifest.rooms, piece.global_position)
			var middle := FLOOR.position_of(room)
			var from: Vector3 = at + (Vector3(middle.x, at.y, middle.z) - at).normalized() * 4.0
			look(Vector3(from.x, floor_y + 1.64, from.z), at)
			await shot(name + "_room")
			print("NOTE ", name, " seed ", seed_value, " room ", int(room.get("id", -1)), " digit ", piece.digit)
	print("NOTE_KINDS ", seen.keys())
	quit()
