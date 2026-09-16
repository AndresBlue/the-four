extends SceneTree

var failures: Array[String] = []
var checks: Array[Dictionary] = []

func check(label: String, success: bool, detail: String) -> void:
	checks.append({"check": label, "passed": success, "detail": detail})
	print("PASS " if success else "FAIL ", label, " ", detail)
	if not success:
		failures.append(label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var level: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	var player = level.get_node("Player")
	await frames(30)
	check("Suelo y gravedad", player.is_on_floor() and absf(player.position.y) < 0.1, str(player.position))
	player.active = true
	var start: Vector3 = player.position
	Input.action_press("forward")
	await frames(60)
	Input.action_release("forward")
	var walked: float = start.z - player.position.z
	check("W avanza", walked > 3.2 and walked < 4.2, "metros=%.2f" % walked)
	player.reset_position()
	Input.action_press("forward")
	Input.action_press("sprint")
	await frames(60)
	Input.action_release("forward")
	Input.action_release("sprint")
	check("Shift corre", start.z - player.position.z > walked + 1.5, "metros=%.2f" % (start.z - player.position.z))
	player.position = Vector3(2, 0.02, 1)
	player.velocity = Vector3.ZERO
	Input.action_press("right")
	await frames(80)
	Input.action_release("right")
	check("Pared detiene al jugador", player.position.x < 3.15 and player.position.x > 2.9, str(player.position))
	player.position = Vector3(2, 0.02, 6.5)
	player.velocity = Vector3.ZERO
	Input.action_press("right")
	await frames(60)
	Input.action_release("right")
	check("Puerta permite entrar a sala", player.position.x > 5.2, str(player.position))
	await frames(20)
	Input.action_press("jump")
	await frames(10)
	Input.action_release("jump")
	check("Salto", player.position.y > 0.4, str(player.position))
	await frames(60)
	check("Aterrizaje", player.is_on_floor(), str(player.position))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 10000)
	player._unhandled_input(motion)
	check("Ratón y límite de cámara", player.rotation.y < -0.1 and is_equal_approx(player.camera.rotation.x, -1.4), str(player.rotation))
	player.reset_position()
	player.active = false
	await frames(10)
	start = player.position
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	check("Ratón libre bloquea movimiento", player.position.distance_to(start) < 0.05, str(player.position))
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1, -9), Vector3(0, 1, -14))
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	check("Colisión del enemigo", not hit.is_empty() and hit.collider.name == "StaticCollision", str(hit.get("position", "sin impacto")))
	check("Enemigo estático", level.get_node("Enemy").position == Vector3(0, 0, -12), str(level.get_node("Enemy").position))
	check("Modelo GLB importado", level.has_node("Enemy/ImportedLocust"), "Locust de Doumty")
	var imported: Node3D = level.get_node("Enemy/ImportedLocust")
	check("Mallas del personaje", imported.find_children("*", "MeshInstance3D", true, false).size() >= 2, str(imported.find_children("*", "MeshInstance3D", true, false).size()))
	var music = level.get_node("Music")
	check("MP3 y bucle", music.stream is AudioStreamMP3 and music.stream.loop and music.stream.get_length() > 30, "duración=%.2fs" % music.stream.get_length())
	var mute_key := InputEventKey.new()
	mute_key.physical_keycode = KEY_M
	mute_key.pressed = true
	level._unhandled_input(mute_key)
	check("M silencia la música", music.muted and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), level.music_label.text)
	level._unhandled_input(mute_key)
	check("M restaura la música", not music.muted and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), level.music_label.text)
	music.adjust_volume(999)
	check("Límite superior de volumen", is_equal_approx(music.volume_db, -6.0), str(music.volume_db))
	music.adjust_volume(-999)
	check("Límite inferior de volumen", is_equal_approx(music.volume_db, -40.0), str(music.volume_db))
	music.adjust_volume(18)
	var file := FileAccess.open("res://evidence/tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "passed": failures.is_empty(), "checks": checks}, "\t"))
	file.close()
	quit(0 if failures.is_empty() else 1)
