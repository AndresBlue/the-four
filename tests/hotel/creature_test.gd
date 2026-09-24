extends SceneTree
## The creature's own rounds and searches, on a real floor with nobody about:
## that its patrol walks the wing instead of pacing between two rooms, that a
## search it gets nothing from is given up in seconds and left behind, that a
## place it has given its time to stops holding it, and that the director's
## lead is followed. What it finds in a wardrobe, and when, is survival_test's.
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

## Nobody for it to see or hear: the player stood far under the floor, where
## the stuck probe keeps it too.
func park_player() -> void:
	level.player.set_physics_process(false)
	level.player.global_position = Vector3(0, -200, 0)
	level.player.velocity = Vector3.ZERO

## Its rounds for `seconds`: the rooms it stood in, and each leg it chose
## (metres of walking from where it chose it).
func patrol_for(seconds: float) -> Dictionary:
	var creature = level.locust
	var rooms := {}
	var legs: Array = []
	var last_goal := Vector3.INF
	var steps := int(seconds * 60.0)
	for i in steps:
		await physics_frame
		if i % 30 == 0:
			var here := FLOOR.room_at(level.manifest.rooms, creature.global_position)
			if not here.is_empty(): rooms[int(here.id)] = true
		if creature.mode == creature.Mode.PATROL and creature.destination != last_goal:
			last_goal = creature.destination
			var from := FLOOR.room_at(level.manifest.rooms, creature.global_position)
			var to := FLOOR.room_at(level.manifest.rooms, creature.destination)
			if not from.is_empty() and not to.is_empty():
				legs.append(float(creature.walk_from(int(from.id)).get(int(to.id), 0.0)))
	return {"rooms": rooms.size(), "legs": legs}

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for seed_value in [81, 213]:
		await level.start_floor(seed_value)
		park_player()
		var creature = level.locust
		creature.grace = 0.0
		var walked: Dictionary = await patrol_for(180.0)
		var long_legs: int = walked.legs.filter(func(metres): return metres >= creature.PATROL_NEAR).size()
		check("Semilla %d: en tres minutos de ronda recorre al menos doce salas (%d)" % [seed_value, walked.rooms], walked.rooms >= 12)
		check("Semilla %d: sus tramos van lejos, no a la sala de al lado (%d de %d)" % [seed_value, long_legs, walked.legs.size()], walked.legs.size() >= 3 and long_legs >= int(ceil(walked.legs.size() * 0.8)))
	await searching()
	await leading()
	await after_a_kill()
	var file := FileAccess.open("res://evidence/creature_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	quit(0 if failed == 0 else 1)

## Lost somebody where nobody is: a look round, then it gives the place up and
## goes somewhere else, and does not come back to it for a while.
func searching() -> void:
	var creature = level.locust
	var map: RID = level.get_world_3d().navigation_map
	var spot := FLOOR.closest(map, creature.global_position + Vector3(4, 0, 0))
	creature.last_known = spot
	creature.last_heading = Vector3(1, 0, 0)
	creature.set_mode(creature.Mode.SEARCH)
	check("Una búsqueda es un plan corto, no un anillo", creature.search_plan.size() >= 1 and creature.search_plan.size() <= 4)
	var began := 0.0
	while creature.mode == creature.Mode.SEARCH and began < 30.0:
		await physics_frame
		began += 1.0 / 60.0
	check("Sin pistas se rinde en diez segundos (%.1f s)" % began, creature.mode == creature.Mode.PATROL and began <= creature.GIVE_UP_HARD + 0.5)
	check("Y se va lejos de allí", creature.leaving and creature.destination.distance_to(spot) >= creature.LEAVE_MIN - 1.0)
	var near_rooms: Array = creature.searched_until.keys()
	check("Las salas de alrededor quedan registradas", not near_rooms.is_empty() and near_rooms.all(func(id): return FLOOR.position_of(level.manifest.rooms[id]).distance_to(spot) <= creature.SEARCHED_RADIUS + 0.1))
	# For the next minute and more its rounds keep away from there.
	var came_back := false
	var last_goal := Vector3.INF
	for i in int(creature.SEARCHED_FOR * 0.9 * 60.0):
		await physics_frame
		if creature.mode == creature.Mode.PATROL and creature.destination != last_goal:
			last_goal = creature.destination
			if creature.destination.distance_to(spot) < creature.SEARCHED_RADIUS * 0.5: came_back = true
	check("No vuelve a rondar lo que ya registró", not came_back)
	# A place it has had enough of: a quiet noise there no longer holds it,
	# a loud one still does.
	creature.set_mode(creature.Mode.PATROL)
	creature.search_origin = creature.global_position
	creature.area_spent = creature.AREA_CAP + 1.0
	creature.hear(creature.global_position + Vector3(1.0, 0.5, 0), 3.0)
	check("Tras cuarenta segundos en un sitio, un ruido flojo ya no la retiene", creature.mode == creature.Mode.PATROL)
	creature.hear(creature.global_position + Vector3(1.0, 0.5, 0), 20.0)
	check("Pero uno fuerte sí", creature.mode == creature.Mode.INVESTIGATE)
	creature.search_origin = Vector3.INF
	creature.area_spent = 0.0
	creature.set_mode(creature.Mode.PATROL)

## The director's lead: its rounds keep to the rooms it was sent to.
func leading() -> void:
	var creature = level.locust
	var here := FLOOR.room_at(level.manifest.rooms, creature.global_position)
	var target := {}
	var metres: Dictionary = creature.walk_from(int(here.id))
	for key in metres:
		var room: Dictionary = level.manifest.rooms[int(key)]
		if float(metres[key]) > 30.0 and float(metres[key]) < 60.0 and int(room.get("wing", -1)) == int(here.get("wing", -2)) and not level.off_limits_rooms().has(int(key)) and not FLOOR.is_void(room):
			target = room
			break
	var point := FLOOR.position_of(target)
	check("Acepta una pista del director", not target.is_empty() and creature.lead_to(point, 12.0, 60.0, "prueba"))
	var outside := 0
	var goals := 0
	var last_goal := Vector3.INF
	for i in 45 * 60:
		await physics_frame
		if creature.mode == creature.Mode.PATROL and creature.destination != last_goal:
			last_goal = creature.destination
			goals += 1
			if creature.destination.distance_to(point) > 12.5: outside += 1
	var arrived: bool = creature.global_position.distance_to(point) < 16.0
	check("Y ronda por esa zona, sin salir de ella (%d destinos)" % goals, goals >= 1 and outside == 0 and arrived)
	creature.set_mode(creature.Mode.INVESTIGATE)
	check("Distraída por otra cosa, la pista se olvida", not creature.lead_active())
	creature.set_mode(creature.Mode.PATROL)

## Once it has killed, what it half noticed of anybody else goes with it.
func after_a_kill() -> void:
	var creature = level.locust
	creature.set_mode(creature.Mode.EXECUTE)
	creature.detection = 0.9
	creature.focus = level.player
	creature.state_time = creature.EXECUTION_TIME + 1.0
	creature.update_execution(1.0 / 60.0)
	check("Tras una ejecución empieza de cero", creature.mode == creature.Mode.SEARCH and creature.detection == 0.0 and creature.focus == null)
