extends SceneTree
## A floor is three chained stages, not one errand: closing one carries into
## the next and only the last one ends the floor. This drives a real floor from
## the refuge, the way a player does, and checks what the session does with it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

func frames(count: int) -> void:
	for i in count: await physics_frame

## Stands in the refuge and holds the interaction, as a player would.
func hold_until_stage(stage: int, seconds := 10.0) -> bool:
	var session = level.session
	var refuge: Vector3 = FLOOR.position_of(level.manifest.rooms[level.manifest.exit])
	var left := seconds
	Input.action_press("interact")
	while left > 0.0:
		level.player.global_position = refuge + Vector3(0, 0.04, 0)
		level.player.velocity = Vector3.ZERO
		await physics_frame
		left -= 1.0 / 60.0
		if session.stage >= stage and session.state == session.State.PLAYING:
			Input.action_release("interact")
			return true
	Input.action_release("interact")
	return false

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	var session = level.session
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	check("Un piso empieza en la etapa 1", session.stage == 1 and session.STAGES == 3)
	check("Y su condición es la del refugio", session.goal.kind == "refuge")
	# Outside the refuge the hold counts for nothing.
	level.player.global_position = Vector3(0, 0.04, 0)
	Input.action_press("interact")
	for i in 240: await physics_frame
	Input.action_release("interact")
	check("Fuera del refugio no avanza ninguna etapa", session.stage == 1 and session.exit_progress == 0.0)
	check("Cerrar la etapa 1 no termina el piso", await hold_until_stage(2))
	check("Sigue jugándose, en la etapa 2", session.state == session.State.PLAYING and session.stage == 2)
	check("Sin pantalla de fin de piso por el medio", level.ui.screen != "transition" and level.ui.screen != "won")
	check("El progreso de salida se reinicia en cada etapa", session.exit_progress < 3.0)
	check("Cerrar la etapa 2 lleva a la 3", await hold_until_stage(3))
	# The last one is the only one that ends the floor.
	var refuge: Vector3 = FLOOR.position_of(level.manifest.rooms[level.manifest.exit])
	var won := false
	Input.action_press("interact")
	for i in 900:
		level.player.global_position = refuge + Vector3(0, 0.04, 0)
		await physics_frame
		if session.state == session.State.WON:
			won = true
			break
	Input.action_release("interact")
	check("La última etapa sí termina el piso", won and session.stage == 3)
	check("Y entonces sale la pantalla de fin", level.ui.screen == "won")
	# A floor started again begins at the first stage.
	await level.start_floor(81)
	check("Un piso nuevo vuelve a la etapa 1", level.session.stage == 1 and level.session.state == level.session.State.PLAYING)
	var file := FileAccess.open("res://evidence/stages_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("STAGES_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
