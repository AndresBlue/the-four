extends SceneTree
## The floor's key and an electrical panel (code_lock.place_key(),
## hotel_panel.gd), photographed: the key's ring out of its drawer, from arm's
## length and from the room; a panel shut, and open with the key. With a
## window:
##   godot --path . --script res://tools/capture/key_capture.gd -- --test-profile --automation --silent [--seed=81]
## Shots in evidence/key_*.png.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String, frames := 40) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/key_%s.png" % name)
	print("CAPTURE evidence/key_%s.png" % name)

func look(eye: Vector3, at: Vector3) -> void:
	level.player.set_physics_process(false)
	level.player.velocity = Vector3.ZERO
	level.player.position = eye - Vector3(0, level.player.eye_height, 0)
	var d := at - eye
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	level.player.snap_torch()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.settings.values.quality = 2
	for key in ["vhs", "grain", "chromatic", "scanlines"]: level.settings.values[key] = 0.0
	level.settings.values.reduced = true
	level.apply_settings()
	level.apply_lens(false, true)
	level.player.torch.visible = true
	for i in 120: await process_frame
	var piece = level.containers[level.code.key_in]
	var at: Vector3 = piece.key_shown.global_position
	var out: Vector3 = piece.global_basis.z.normalized()
	var side: Vector3 = piece.global_basis.x.normalized()
	var floor_y: float = piece.global_position.y
	# The torch sits low and to the right of where the eye looks: aimed a
	# little above and to the left of the key, it lands on it.
	var eye: Vector3 = at + out * 0.6 + side * 0.1 + Vector3(0, 0.12, 0)
	look(eye, at)
	await process_frame
	var camera: Basis = level.player.camera.global_basis
	look(eye, at - camera.x * 0.1 + camera.y * 0.09)
	await shot("drawer_close")
	look(Vector3(at.x, floor_y + 1.64, at.z) + out * 1.6 + side * 0.4, at)
	await shot("drawer_room")
	level.apply_search(level.code.key_in, true, false, level.player.slot)
	for i in 30: await process_frame
	await shot("taken")
	var panel = level.code.panels[0]
	var front: Vector3 = panel.global_basis.z.normalized()
	look(panel.global_position + front * 1.3 + Vector3(0.25, 0.1, 0), panel.global_position)
	await shot("panel_shut")
	level.match_net.use_panel(0, "open")
	await shot("panel_open", 80)
	quit()
