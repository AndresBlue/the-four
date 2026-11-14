extends RefCounted
## Keep scripted rendering away from the active desktop window.

static func configure() -> void:
	if not OS.get_cmdline_user_args().has("--background"): return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var primary := DisplayServer.screen_get_position(DisplayServer.SCREEN_PRIMARY)
	for screen in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_position(screen) == primary: continue
		var desktop := DisplayServer.screen_get_usable_rect(screen)
		DisplayServer.window_set_position(desktop.position + Vector2i(36, 54))
		return

static func release_input(level: Node) -> void:
	level.player.set_process_unhandled_input(false)
	level.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
