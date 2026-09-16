extends Camera3D
## F6 gallery camera only. Never attached to the game player.
@export_range(1.0, 60.0) var speed := 12.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.003
		rotation.x = clampf(rotation.x - event.relative.y * 0.003, -1.55, 1.55)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	var axis := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	position += basis * axis.normalized() * speed * delta * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)

func _exit_tree() -> void: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
