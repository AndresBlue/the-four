extends CharacterBody3D

@export var walk_speed := 3.8
@export var sprint_speed := 6.0
@export var mouse_sensitivity := 0.0022
@export var jump_speed := 5.4
@onready var camera: Camera3D = $Camera3D
var active := false
var spawn_position := Vector3(0, 0.05, 9)

func _ready() -> void:
	for action in ["forward", "backward", "left", "right", "sprint", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var keys := {"forward": KEY_W, "backward": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE}
	for action in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	spawn_position = position

func set_active(value: bool) -> void:
	active = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE

func reset_position() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and active:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.4, 1.4)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	var axis := Input.get_vector("left", "right", "forward", "backward") if active else Vector2.ZERO
	var direction := (basis * Vector3(axis.x, 0, axis.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
	if active and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
	move_and_slide()
	if position.y < -10:
		reset_position()
