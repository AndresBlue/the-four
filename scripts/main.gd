extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hint: Label = $HUD/Hint
@onready var status: Label = $HUD/Status
var capture_path := ""
var frame_count := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		if arg == "--closeup":
			player.position = Vector3(0, 0.05, -7.8)
			player.camera.rotation.x = 0.035
		if arg == "--overview":
			player.position = Vector3(10.8, 0.05, 3.8)
			player.rotation.y = 1.0
	_update_hint()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		player.set_active(true)
		_update_hint()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				player.set_active(not player.active)
				_update_hint()
			KEY_R:
				player.reset_position()
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(player):
		player.set_active(false)
		_update_hint()

func _update_hint() -> void:
	hint.text = "W A S D   MOVERSE     /     RATÓN   MIRAR     /     SHIFT   CORRER     /     ESPACIO   SALTAR     /     ESC   LIBERAR RATÓN" if player.active else "HAZ CLIC PARA EXPLORAR     /     R   VOLVER AL INICIO     /     F11   PANTALLA COMPLETA"

func _process(_delta: float) -> void:
	frame_count += 1
	status.text = "PISO 01   /   %s" % ("OBSERVACIÓN" if player.position.z < -5 else "ACCESO" if absf(player.position.x) < 3.5 else "SALAS LATERALES")
	if capture_path != "" and frame_count == 30:
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(capture_path)
		print("CAPTURE_RESULT=", error, " PATH=", capture_path)
		get_tree().quit(error)
