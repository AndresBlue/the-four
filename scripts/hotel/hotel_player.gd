extends CharacterBody3D
var camera: Camera3D
var torch: SpotLight3D
var active := false
var settings
var spawn := Vector3.ZERO
var bob_time := 0.0

func _ready() -> void:
	add_to_group("hotel_players")
	collision_layer = 4
	collision_mask = 1 | 8
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.91
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.64
	camera.fov = 78
	camera.far = 95
	add_child(camera)
	torch = SpotLight3D.new()
	torch.spot_range = 20
	torch.spot_angle = 34
	torch.light_energy = 2.0
	torch.light_color = Color("fff3dc")
	torch.shadow_enabled = true
	torch.visible = false
	camera.add_child(torch)

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * settings.values.sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * settings.values.sensitivity * (-1 if settings.values.invert else 1), -1.45, 1.45)
	if event.is_action_pressed("flashlight"): torch.visible = not torch.visible

func _physics_process(delta: float) -> void:
	var axis := Input.get_vector("left", "right", "forward", "backward") if active else Vector2.ZERO
	var direction := (basis * Vector3(axis.x, 0, axis.y)).normalized()
	var speed := 6.0 if active and Input.is_action_pressed("sprint") else 3.8
	velocity.x = move_toward(velocity.x, direction.x * speed, 22 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22 * delta)
	if not is_on_floor(): velocity.y -= 20 * delta
	if active and is_on_floor() and Input.is_action_just_pressed("jump"): velocity.y = 5.4
	move_and_slide()
	if position.y < -5:
		position = spawn
		velocity = Vector3.ZERO
	if axis.length() > 0.1 and is_on_floor(): bob_time += delta * speed * 1.8
	var amplitude: float = 0.0 if settings.values.reduced else settings.values.bob * 0.08
	camera.position.y = 1.64 + sin(bob_time) * amplitude * axis.length()
