extends SceneTree

var level
var player
var failures: Array[String] = []
var visited: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/h1_" + label + ".png")

func walk(target: Vector3) -> void:
	player.camera.rotation = Vector3.ZERO
	var ticks := 0
	while Vector2(player.position.x - target.x, player.position.z - target.z).length() > 0.18 and ticks < 700:
		var direction: Vector3 = target - player.position
		player.rotation.y = atan2(-direction.x, -direction.z)
		Input.action_press("forward")
		ticks += 1
		await physics_frame
	Input.action_release("forward")
	await frames(9)
	if ticks >= 700:
		failures.append("Ruta bloqueada hacia " + str(target) + " desde " + str(player.position))
		print("FAIL ", failures.back())
	else:
		print("WALK ", player.position)

func interact(item: Node3D) -> void:
	player.camera.look_at(item.global_position, Vector3.UP)
	await frames(3)
	if level.get_focused_item() != item:
		failures.append("Objeto fuera de alcance: " + item.name)
		print("FAIL ", failures.back())
		return
	Input.action_press("interact")
	await frames(3)
	Input.action_release("interact")
	await frames(35)
	visited.append(item.name)

func open_room(side: int, z: float) -> void:
	await walk(Vector3(0, 0, z + 1.65))
	await walk(Vector3(side * 2.0, 0, z + 1.65))
	for item in level.gameplay.items:
		if item.kind == "door" and signf(item.position.x) == side and is_equal_approx(item.position.z, z + 1.65):
			await interact(item)
	await walk(Vector3(0, 0, z))
	await walk(Vector3(side * 6.5, 0, z))

func run() -> void:
	level = load("res://legacy/fuse_prototype/main.tscn").instantiate()
	root.add_child(level)
	level.automation = true
	player = level.player
	await snapshot("menu")
	level.ui.button_by_action["start"].pressed.emit()
	await frames(15)
	await open_room(-1, 6.5)
	await walk(Vector3(-8, 0, 6.5))
	player.camera.look_at(level.gameplay.get_node("fuse_a").global_position)
	await snapshot("fuse")
	await interact(level.gameplay.get_node("fuse_a"))
	await walk(Vector3(-6.5, 0, 6.5))
	await walk(Vector3(0, 0, 6.5))
	await open_room(1, 6.5)
	await walk(Vector3(8, 0, 6.5))
	await interact(level.gameplay.get_node("fuse_b"))
	await walk(Vector3(6.5, 0, 6.5))
	await walk(Vector3(0, 0, 6.5))
	await open_room(1, -4.5)
	await walk(Vector3(6.5, 0, -6.5))
	await walk(Vector3(8, 0, -6.5))
	await interact(level.gameplay.get_node("fuse_c"))
	await walk(Vector3(6.5, 0, -6.5))
	await walk(Vector3(6.5, 0, -4.5))
	await walk(Vector3(0, 0, -4.5))
	await walk(Vector3(0, 0, 11.3))
	for i in 3: await interact(level.gameplay.panel)
	await snapshot("panel")
	Input.action_press("interact")
	await create_timer(3.15).timeout
	Input.action_release("interact")
	await create_timer(1.3).timeout
	await snapshot("victory")
	var won: bool = level.session.state == level.session.State.WON
	if not won: failures.append("No llegó a victoria con ruta física")
	level.begin_run()
	await frames(2)
	level.session.capture("Derrota de prueba. La IA de The Locust todavía no está activa.")
	await create_timer(1.3).timeout
	await snapshot("defeat")
	var file := FileAccess.open("res://evidence/h1_walkthrough.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "visited": visited, "position_teleports": 0, "won": won}, "\t"))
	file.close()
	print("WALKTHROUGH_RESULT=", failures.is_empty(), " failures=", failures)
	paused = false
	quit(0 if failures.is_empty() else 1)
