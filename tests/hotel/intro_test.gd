extends SceneTree
## Opening scene of a new game: plays through into the floor, can be skipped,
## and hands the view back to the player.
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

func wait_for(condition: Callable, limit: int) -> bool:
	for frame in limit:
		if condition.call(): return true
		await process_frame
	return condition.call()

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var ambient: float = level.environment.ambient_light_energy
	level.on_action("new")
	var intro = level.intro
	check("Nueva partida abre la escena de entrada", is_instance_valid(intro) and level.session.state == level.session.State.CUTSCENE)
	check("La escena usa su propia cámara y oscurece el ambiente", intro.camera.current and level.environment.ambient_light_energy < ambient)
	check("Durante la escena no hay menú ni pausa del árbol", not level.ui.overlay.visible and not paused)
	intro.speed = 12.0
	var outcome := {"fired": false}
	intro.finished.connect(func(): outcome.fired = intro.fired.all(func(f): return f))
	var screen: ShaderMaterial = intro.screen
	check("La tele se agrieta con los golpes", await wait_for(func(): return intro.time > 30.2, 600) and float(screen.get_shader_parameter("crack_level")) > 0.9)
	check("La puerta del dormitorio se cierra de golpe al salir", await wait_for(func(): return intro.time > 35.0, 600) and absf(intro.bedroom_leaf.rotation.y) < 0.05)
	check("Todos los eventos se disparan", await wait_for(func(): return outcome.fired, 600))
	check("Al terminar empieza la partida", await wait_for(func(): return level.session.state == level.session.State.PLAYING, 900))
	check("La escena se libera y vuelve la cámara del jugador", not is_instance_valid(level.intro) and level.player.camera.current and level.player.visible)
	check("Se restaura la luz ambiente", is_equal_approx(level.environment.ambient_light_energy, ambient))
	# Skipping: holding interact ends the scene early.
	level.session.set_state(level.session.State.MENU)
	await process_frame
	level.on_action("new")
	check("Se puede volver a abrir desde el menú", is_instance_valid(level.intro))
	Input.action_press("interact")
	var skipped: bool = await wait_for(func(): return not is_instance_valid(level.intro), 120)
	Input.action_release("interact")
	check("Mantener interactuar la salta", skipped)
	check("Tras saltarla empieza la partida", await wait_for(func(): return level.session.state == level.session.State.PLAYING, 900))
	var file := FileAccess.open("res://evidence/intro_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("INTRO_RESULT ", checks.size() - failed, "/", checks.size())
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
