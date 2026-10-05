extends SceneTree
## Continuar, photographed: a floor played alone is left in its second sector
## in front of a set it has lit, from the pause, and gone on with from the
## menu. Before leaving it (continue_antes.png), the pause, the menu, the card
## it comes back under and the floor given back (continue_despues.png): the
## same place, the same set, the tape's clock where it was.
## Needs a window (it reads the rendered image), never --headless.
##
##   godot --path . --script tools/capture/continue_capture.gd -- --test-profile
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
func _initialize() -> void: run.call_deferred()
func shot(name: String, frames := 60) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/continue_%s.png" % name)
	print("SHOT ", name)
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	level.settings.values.first_game_done = true
	await level.start_floor(81, false, [1], "equilibrada")
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.session.stage = 2
	level.last_stage = 2
	level.session.changed.emit()
	var lit := int(level.stage_televisions(2)[0])
	level.apply_television(lit, true)
	var set: Node3D = level.televisions[lit]
	level.player.global_position = FLOOR.closest(level.player.get_world_3d().navigation_map, set.global_position + set.global_basis.z.normalized() * 2.6) + Vector3(0, 0.04, 0)
	var look: Vector3 = set.screen_point() - (level.player.global_position + Vector3(0, 1.64, 0))
	level.player.rotation.y = atan2(-look.x, -look.z)
	level.player.torch.visible = true
	level.session.elapsed = 754.0
	await shot("antes", 420)
	level.on_action("pause")
	await process_frame
	await shot("pausa", 20)
	level.on_action("main")
	await process_frame
	await shot("menu", 30)
	level.on_action("continue")
	for i in 4: await process_frame
	while level.session.state == level.session.State.LOADING: await process_frame
	await shot("tarjeta", 40)
	await shot("despues", 420)
	print("CONTINUE listo")
	level.queue_free()
	await process_frame
	quit()
