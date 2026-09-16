extends SceneTree

var level
var player
var checks: Array[Dictionary] = []
var failed := 0

func _initialize() -> void:
	run.call_deferred()

func check(label: String, passed: bool, detail := "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print("PASS " if passed else "FAIL ", label, " ", detail)
	if not passed: failed += 1

func frames(count: int) -> void:
	for i in count: await physics_frame

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func aim_at(item: Node3D, offset := Vector3(0, 0, 1.25)) -> void:
	player.position = item.global_position + offset
	player.position.y = 0.04
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.camera.look_at(item.global_position, Vector3.UP)
	await frames(3)

func tap() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)

func key(physical: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = true
	level._unhandled_input(event)

func fill_panel() -> bool:
	for item in level.gameplay.items:
		if item.kind == "fuse":
			await aim_at(item)
			if level.get_focused_item() != item: return false
			await tap()
	await aim_at(level.gameplay.panel, Vector3(1.05, 0, 0))
	for i in 3: await tap()
	return level.session.installed.size() == 3

func run() -> void:
	level = load("res://legacy/fuse_prototype/main.tscn").instantiate()
	root.add_child(level)
	player = level.player
	var session = level.session
	check("Menú inicial y cursor libre", session.state == session.State.MENU and paused and not player.active)
	level.ui.button_by_action["start"].pressed.emit()
	await frames(15)
	check("Botón iniciar habilita partida", session.state == session.State.PLAYING and not paused and player.active)
	check("Ascensor bloqueado sin fusibles", not session.install_fuse())
	session.advance_exit(4.0, true)
	check("Sin victoria prematura", session.state == session.State.PLAYING and is_zero_approx(session.exit_progress))
	var fuse: Node3D = level.gameplay.get_node("fuse_a")
	await aim_at(fuse, Vector3(0, 0, 3.2))
	await tap()
	check("No recoger fuera de alcance", session.carried.is_empty())
	await aim_at(fuse)
	check("Rayo enfoca fusible", level.get_focused_item() == fuse)
	# Occlude the actual interaction ray with a temporary physical wall.
	var blocker := StaticBody3D.new()
	blocker.position = (player.camera.global_position + fuse.global_position) * 0.5
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(1.0, 1.0, 0.1)
	blocker.add_child(shape)
	level.add_child(blocker)
	await frames(3)
	await tap()
	check("No recoger a través de pared", session.carried.is_empty())
	blocker.queue_free()
	await frames(3)
	await tap()
	check("Recogida E real", session.carried == ["fuse_a"] and not fuse.visible)
	for i in 5: await tap()
	check("No duplicar fusible por E repetido", session.carried.size() == 1 and not session.collect_fuse("fuse_a"))
	check("Rechazar objeto desconocido", not session.collect_fuse("fake_fuse"))
	key(KEY_ESCAPE)
	var frozen: Vector3 = player.position
	var elapsed: float = session.elapsed
	Input.action_press("forward")
	await wait_seconds(0.2)
	Input.action_release("forward")
	check("Pausa congela física y reloj", paused and player.position == frozen and is_equal_approx(session.elapsed, elapsed))
	check("Pausa impide modificar objetivos", not session.collect_fuse("fuse_b") and not session.capture("no"))
	level.ui.button_by_action["resume"].pressed.emit()
	await frames(3)
	check("Continuar restaura controles", not paused and player.active)
	level.begin_run()
	await frames(3)
	check("Reinicio restaura fusibles", session.carried.is_empty() and session.installed.is_empty() and fuse.visible)
	var door
	for item in level.gameplay.items:
		if item.kind == "door":
			door = item
			break
	await aim_at(door, Vector3(1.0, 0, 0))
	check("Rayo enfoca botonera", level.get_focused_item() == door)
	await tap()
	await wait_seconds(0.6)
	check("Puerta abre y libera paso", door.opened and door.door_shape.disabled and not door.moving, str([door.opened, door.moving, door.door_shape.disabled, door.door_leaf.position]))
	player.position = door.global_position + door.closed_position
	player.position.y = 0.04
	player.velocity = Vector3.ZERO
	await frames(4)
	check("Puerta no cierra sobre jugador", not door.toggle_door() and door.opened, str([door.opened, door.moving, door.doorway_occupied()]))
	await aim_at(door, Vector3(1.0, 0, 0))
	await tap()
	await wait_seconds(0.6)
	check("Puerta cierra con colisión", not door.opened and not door.door_shape.disabled, str([door.opened, door.moving, door.door_shape.disabled]))
	Input.action_press("interact")
	await wait_seconds(1.1)
	check("Mantener E inicia apertura lenta", door.moving)
	Input.action_release("interact")
	await wait_seconds(1.3)
	check("Soltar no invierte apertura lenta", door.opened and not door.moving, str([door.opened, door.moving, door.door_shape.disabled]))
	level.begin_run()
	await frames(3)
	check("Reinicio restaura puertas", not door.opened and not door.door_shape.disabled)
	check("Recoger e instalar tres objetos por rayos", await fill_panel())
	for i in 5: await tap()
	check("Panel sin duplicaciones", session.carried.is_empty() and session.installed.size() == 3)
	Input.action_press("interact")
	await wait_seconds(0.8)
	check("Salida requiere sostener 3 s", session.state == session.State.PLAYING and session.exit_progress > 0.5)
	Input.action_release("interact")
	await frames(3)
	check("Soltar cancela progreso", is_zero_approx(session.exit_progress))
	Input.action_press("interact")
	await wait_seconds(0.4)
	player.camera.rotation.y += PI
	await frames(3)
	check("Perder foco cancela salida", is_zero_approx(session.exit_progress))
	Input.action_release("interact")
	await aim_at(level.gameplay.panel, Vector3(1.05, 0, 0))
	check("Cabina exige cápsula completa", level.gameplay.contains_player(player.position) and not level.gameplay.contains_player(Vector3(0, 0, 9.9)))
	# Ten complete win/death/menu/retry cycles exercise real controls and timers.
	var cycles := 0 if OS.get_cmdline_user_args().has("--quick") else 10
	for cycle in cycles:
		level.begin_run()
		await frames(2)
		var collected: bool = await fill_panel()
		Input.action_press("interact")
		await wait_seconds(3.15)
		Input.action_release("interact")
		var locked: bool = session.state == session.State.EXITING and not session.capture("late")
		await wait_seconds(1.3)
		var won: bool = session.state == session.State.WON and paused and not player.active and level.ui.button_by_action.has("retry")
		if won: level.ui.button_by_action["retry"].pressed.emit()
		else: level.begin_run()
		await frames(2)
		key(KEY_F9)
		var single_death: bool = session.state == session.State.DYING and not session.capture("duplicate") and not session.collect_fuse("fuse_a")
		await wait_seconds(1.3)
		var dead: bool = session.state == session.State.DEAD and paused
		if dead: level.ui.button_by_action["menu"].pressed.emit()
		var menu: bool = session.state == session.State.MENU
		if menu: level.ui.button_by_action["start"].pressed.emit()
		await frames(2)
		var clean: bool = session.carried.is_empty() and session.installed.is_empty() and player.active and not paused and fuse.visible and not door.opened
		check("Ciclo completo %d/10" % (cycle + 1), collected and locked and won and single_death and dead and menu and clean, "objetivos→salida→victoria→reintento→derrota→menú→partida")
	var file := FileAccess.open("res://evidence/h1_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "passed": failed == 0, "total": checks.size(), "checks": checks}, "\t"))
	file.close()
	print("H1_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	paused = false
	quit(0 if failed == 0 else 1)
