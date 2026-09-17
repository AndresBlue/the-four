extends SceneTree
## The Locust's acoustic view (echo_view.gd), everything that can be checked
## without a GPU: the click cadence, the ray budget, the ring buffers, what a
## body is and is not allowed to reveal, the sound contacts, the shriek, the
## landmarks, reduced effects and leaving the hunter's seat behind cleanly.
## The picture itself is checked by eye with tools/capture/echo_capture.gd, and
## the shaders by tools/dev/check_shaders.gd, which needs a window.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GENERATOR := preload("res://game/world/generation/map_generator.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
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

## Which room of the floor is farthest from this one along the map.
func far_room(from: int) -> Dictionary:
	var spans: Array = GENERATOR.distance_map(level.manifest.adjacency, from)
	var best := from
	for room in level.manifest.rooms:
		if spans[int(room.id)] > spans[best]: best = int(room.id)
	return level.manifest.rooms[best]

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	Engine.max_fps = 0
	await level.take_locust(81)
	var creature = level.locust
	var echo = creature.driver.echo
	check("El asiento del cazador crea la vista acústica", echo != null and echo.enabled)
	check("La vista trae su propio azar y no el del mapa", echo.rng != null and echo.rng.seed != 0)
	# The order the five readings stack in. The hotel's own transparents (the
	# monstera leaves, the dust) all sit at 0, so the whole echo draws above
	# them; within the echo, the field goes first and its own body last.
	var order := [echo.field_material.render_priority, echo.mark_material.render_priority, echo.wall_material.render_priority, echo.body_material.render_priority, echo.self_material.render_priority]
	var rising := true
	for i in range(1, order.size()):
		if order[i] <= order[i - 1]: rising = false
	check("Las cinco lecturas se dibujan en orden y sobre el hotel", rising and order[0] > 0)

	# --- Cadence ------------------------------------------------------------------
	var intervals: Array = []
	var seen: int = echo.clicks
	var ticks := 0
	while intervals.size() < 40 and ticks < 600:
		await physics_frame
		ticks += 1
		if echo.clicks != seen:
			seen = echo.clicks
			intervals.append(echo.last_interval)
	var nominal: float = 1.0 / float(echo.CLICK_RATE)
	var widest: float = nominal * (1.0 + echo.CLICK_JITTER) * (1.0 + echo.BREATH_DEPTH)
	var tightest: float = nominal * (1.0 - echo.CLICK_JITTER) * (1.0 - echo.BREATH_DEPTH)
	var inside := intervals.all(func(value: float): return value >= tightest - 0.001 and value <= widest + 0.001)
	check("La cadencia de pulsos se mantiene en su margen", intervals.size() >= 30 and inside)
	var distinct := {}
	for value in intervals: distinct[snappedf(value, 0.0001)] = true
	check("El pulso no es un metrónomo", distinct.size() > intervals.size() / 2)

	# --- Rays and the ring buffer -------------------------------------------------
	var budget: int = echo.RAY_BUDGET[echo.quality]
	var most := 0
	var before: int = echo.rays_cast
	for i in 120:
		await physics_frame
		most = maxi(most, echo.rays_cast - before)
		before = echo.rays_cast
	check("El presupuesto de rayos se reparte entre fotogramas", most <= echo.per_tick and echo.per_tick < budget)
	check("Se lanzan rayos en cada pulso", echo.rays_cast > budget)
	var cloud: MultiMesh = echo.walls.multimesh
	check("El anillo de puntos nunca pasa del presupuesto", cloud.instance_count == echo.POINT_BUDGET[echo.quality] and echo.wall_at < cloud.instance_count and echo.wall_shown <= cloud.instance_count)
	var span: float = echo.wall_material.get_shader_parameter("age_limit")
	check("Los puntos se apagan antes de ser sobrescritos", span <= float(maxi(echo.wall_shown, 1)) / maxf(echo.write_rate, 1.0) + 0.001 and span <= echo.MEMORY)

	# --- Bodies -------------------------------------------------------------------
	var corridor: Dictionary = level.manifest.rooms[0]
	for room in level.manifest.rooms:
		if int(room.type) in [11, 12] and int(room.get("hall", -1)) == -1:
			corridor = room
			break
	var centre: Vector3 = FLOOR.position_of(corridor)
	creature.global_position = centre + Vector3(0, 0.04, 4.0)
	# Looking back down the corridor at the survivor (forward is -Z).
	creature.rotation.y = 0.0
	level.player.global_position = centre + Vector3(0, 0.06, 0.0)
	await frames(30)
	check("La criatura ve al superviviente a la vista", creature.sees(level.player))
	var grown: int = echo.body_shown
	await frames(30)
	check("Un cuerpo a la vista deja puntos", echo.body_shown > grown or echo.body_shown == echo.bodies.multimesh.instance_count)
	# The same survivor, rooms away: no silhouette at all.
	var away := far_room(int(corridor.id))
	level.player.global_position = FLOOR.position_of(away) + Vector3(0, 0.06, 0)
	await frames(20)
	echo.body_shown = 0
	var quiet: int = echo.body_shown
	await frames(40)
	check("Un cuerpo tras las paredes no deja ninguno", not creature.sees(level.player) and echo.body_shown == quiet)

	# --- Sound contacts -----------------------------------------------------------
	creature.driver.heard.clear()
	var near_point: Vector3 = creature.global_position + Vector3(1.6, 0.2, 0.0)
	level.on_noise(near_point, 12.0, NOISE.Kind.SLAM)
	await frames(4)
	var close: Dictionary = creature.driver.heard[0] if not creature.driver.heard.is_empty() else {}
	check("El contacto llega con su clase", close.get("kind", -1) == NOISE.Kind.SLAM)
	check("Cerca se pinta donde ocurrió", not close.is_empty() and close.at.distance_to(near_point) < 0.01 and close.blur == 0.0)
	# Something heard from rooms away arrives through an opening instead.
	creature.driver.heard.clear()
	var route_point: Vector3 = FLOOR.position_of(away) + Vector3(0, 0.2, 0)
	var route: Dictionary = creature.hear_route(route_point, 400.0)
	check("El oído mide la ruta y la abertura por la que entra", route.audible and route.distance >= creature.global_position.distance_to(route_point) - 0.01 and route.apparent.distance_to(route_point) > 1.0)
	level.on_noise(route_point, 400.0, NOISE.Kind.DOOR)
	await frames(4)
	var far_mark: Dictionary = creature.driver.heard[0] if not creature.driver.heard.is_empty() else {}
	check("Lejos se pinta por dónde llega, no dónde está", not far_mark.is_empty() and far_mark.blur == 1.0 and far_mark.at.distance_to(far_mark.apparent) < 0.01)
	await frames(int(echo.CONTACT_LIFE * 60) + 20)
	var stale: bool = creature.driver.heard.any(func(mark): return Time.get_ticks_msec() / 1000.0 - mark.time > echo.CONTACT_LIFE + 0.1)
	check("Los contactos caducan", not stale)

	# --- The shriek ---------------------------------------------------------------
	echo.flash_shriek()
	await frames(30)
	check("El chillido enrojece la lectura", echo.shriek > 0.9)
	echo.shriek_hold = 0.0
	await frames(240)
	check("Y se apaga después", echo.shriek < 0.05)

	# --- Landmarks ----------------------------------------------------------------
	var wanted: int = level.hotel.doors.size() * 4 + level.hotel.hides.size() * 6
	var marks: int = echo.marks.multimesh.instance_count
	await frames(60)
	check("Conoce sus puertas y armarios", marks == wanted and marks > 0)
	check("Y esos hitos no cambian", echo.marks.multimesh.instance_count == marks)

	# --- Settings -----------------------------------------------------------------
	level.settings.set_value("reduced", true)
	level.apply_settings()
	await frames(10)
	var quiet_base: float = echo.field_material.get_shader_parameter("base_level")
	check("Efectos reducidos quitan temblor y grano", echo.field_material.get_shader_parameter("jitter_amount") == 0.0 and echo.field_material.get_shader_parameter("grain_amount") == 0.0)
	check("Pero no apagan la imagen", quiet_base >= echo.BASE_LEVEL and echo.walls.multimesh.instance_count > 0)
	level.settings.set_value("reduced", false)
	level.settings.set_value("quality", 0)
	level.apply_settings()
	await frames(20)
	check("Calidad 0 apaga la nube y deja el campo", echo.walls.multimesh.instance_count == 0 and echo.RAY_BUDGET[echo.quality] == 0 and is_instance_valid(echo.field))
	level.settings.set_value("quality", 1)
	level.apply_settings()
	await frames(10)

	# --- It never touches the map's randomness ------------------------------------
	var generator = GENERATOR.new()
	var again: Dictionary = generator.generate(81)
	check("El eco no consume el azar del mapa", JSON.stringify(again.rooms) == JSON.stringify(level.manifest.rooms))

	# --- Leaving the seat ---------------------------------------------------------
	var meshes: Array = creature.visual.find_children("*", "MeshInstance3D", true, false)
	var swapped := meshes.any(func(mesh): return mesh.material_override != null)
	creature.set_control("ai")
	await frames(4)
	check("Mientras conduce, su cuerpo lleva el material del eco", swapped)
	check("Al salir del asiento no queda rastro", not echo.enabled and meshes.all(func(mesh): return mesh.material_override == null and not mesh.has_meta("echo_kept")))

	var file := FileAccess.open("res://evidence/echo_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("ECHO_RESULT ", checks.size() - failed, "/", checks.size())
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
