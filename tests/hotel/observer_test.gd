extends SceneTree
## The observer with nobody hosting, looking at floors of its own
## (game/app/observer_view.gd): R puts up another one with the view as it was,
## Shift+R goes back to the one before, a knock nobody answers leaves the
## floor alone, the planta is the one chosen however high it flies, and
## none of its floors is anybody's game.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const VIEW := preload("res://game/app/observer_view.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
const FIRST := 4242
var level
var view
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, "" if passed or detail.is_empty() else " · " + detail)

func wait_for(condition: Callable, limit: int) -> bool:
	for frame in limit:
		if condition.call(): return true
		await process_frame
	return condition.call()

## A key as the observer gets it.
func press(code: Key, shift := false) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.shift_pressed = shift
	key.pressed = true
	view._unhandled_input(key)

## The floor with this seed is up, played, and taken in by the observer.
func settled(seed_value: int) -> bool:
	return int(level.session.run_seed) == seed_value and level.session.state == level.session.State.PLAYING and is_same(view.floor_seen, level.manifest)

## The plan straight over the middle of the planta's cells, as it frames it.
func framed(planta: int) -> bool:
	var middle := Vector3.ZERO
	var count := 0
	for room in level.manifest.rooms:
		if FLOOR.planta_of(FLOOR.position_of(room).y) != planta: continue
		middle += FLOOR.position_of(room)
		count += 1
	middle /= float(maxi(count, 1))
	var at: Vector3 = view.global_position
	return view.map_view and view.planta == planta and Vector2(at.x, at.z).distance_to(Vector2(middle.x, middle.z + 0.01)) < 0.05 and absf(at.y - middle.y - VIEW.MAP_HEIGHT) < 0.05

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var saved: String = level.session.checkpoint_path
	for path in [saved, saved + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	# Nobody is hosting: it knocks, nobody answers, and it builds its own.
	await level.begin_observing(FIRST)
	view = level.observer_view
	check("Sin nadie en la sala, mira un piso suyo", view != null and await wait_for(func(): return settled(FIRST), 3000))
	var entry: Vector3 = FLOOR.position_of(level.manifest.rooms[int(level.manifest.entries[0])])
	check("La cámara empieza en la llegada, a la altura de los ojos", view.global_position.distance_to(entry + Vector3(0, 1.7, 0)) < 0.05, str(view.global_position))
	press(KEY_M)
	press(KEY_PAGEDOWN)
	check("M y AvPág: el plano de la planta 2", framed(1))
	var plans: Array = level.manifest.plans
	check("El panel dice qué es esa planta", view.report().contains("Planta 2 de 3, %s, %s, %d habitaciones" % [VIEW.PLAN_NAMES[plans[1].plan], VIEW.SHAPE_NAMES[plans[1].shape], int(plans[1].rooms)]))
	press(KEY_R)
	var building: bool = level.session.state == level.session.State.LOADING
	press(KEY_R)
	check("R pone otro piso, y otra R mientras se construye no pide otro", building and view.events.filter(func(line: String): return line.contains("construyendo el piso")).size() == 1)
	var second := -1
	if await wait_for(func(): return int(level.session.run_seed) != FIRST and settled(int(level.session.run_seed)), 5000): second = int(level.session.run_seed)
	check("Llega el piso nuevo, con otra semilla", second >= 0)
	check("Y la vista sigue como estaba: el plano de la planta 2, encuadrado en el piso nuevo", framed(1))
	check("Mayús+R sabe a cuál volver", view.seed_before == FIRST and view.report().contains("Mayús+R vuelve al %d" % FIRST))
	check("Su criatura está en el piso, y nada del de antes se dibuja", view.live_locust() != null and view.gizmos.trails.keys().all(func(key): return is_instance_valid(instance_from_id(key))))
	press(KEY_R, true)
	check("Mayús+R vuelve al piso de antes", await wait_for(func(): return settled(FIRST), 5000) and view.seed_before == second and framed(1))
	check("Ninguno de sus pisos toca el punto de control de Continuar", not FileAccess.file_exists(saved))
	# A knock nobody answers ends like this, some thirty seconds after it
	# was made (net_session: connection_failed).
	if not level.net.active(): level.net.join_observer("127.0.0.1", level.observer_port)
	level.net.shutdown("No se pudo conectar con esa dirección.")
	await wait_for(func(): return false, 30)
	check("Una llamada sin respuesta deja su piso en paz", settled(FIRST) and view.live_locust() != null and not paused and view.map_view)
	# Off the plan and flying up to look at the planta from above: it stays
	# the one RePág/AvPág chose, not the one the height is on.
	press(KEY_M)
	view.global_position.y += 40.0
	await wait_for(func(): return false, 10)
	check("Sin el plano y subiendo, sigue en la planta elegida", not view.map_view and view.planta == 1 and level.hotel.eye_planta == 1)
	check("Y se mira sin la lente de la cámara", not level.lens_layer.visible)
	var named: Array = [LOCUST.Mode.PATROL, LOCUST.Mode.CHASE, LOCUST.Mode.SEARCH, LOCUST.Mode.ALERT, LOCUST.Mode.WARDROBE, LOCUST.Mode.EXECUTE].map(func(mode: int): return view.modo(mode))
	check("El panel nombra cada modo de la criatura por el suyo", named == ["patrulla", "persigue", "busca", "alerta", "armario", "ejecuta"], str(named))
	var file := FileAccess.open("res://evidence/observer_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("OBSERVER_RESULT ", checks.size() - failed, "/", checks.size())
	level.net.shutdown("")
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
