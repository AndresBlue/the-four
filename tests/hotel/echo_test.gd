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
const REMOTE := preload("res://game/net/remote_player.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
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

## Waits for the next click. At two a second with its jitter and its breathing,
## an interval can run past three quarters of a second, so counting frames is
## how a test becomes flaky.
func click_passes(echo) -> void:
	var seen: int = echo.clicks
	var ticks := 0
	while echo.clicks == seen and ticks < 180:
		ticks += 1
		await physics_frame

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
	# The motes of a burnt-out mind belong to the reading: a cloud of its own,
	# red, that goes through walls and is not gated on sight or distance.
	check("La lectura tiene una nube propia para las motas, roja y a través de todo", echo.motes != null and echo.motes.multimesh.instance_count > 0 and echo.mote_material.get_shader_parameter("tone_cold").r > 1.0 and is_equal_approx(echo.mote_material.get_shader_parameter("through"), 1.0))
	check("La vista trae su propio azar y no el del mapa", echo.rng != null and echo.rng.seed != 0)
	# Forward+ stamps a decal on the echo field itself (a quad on the camera):
	# pressed against a damp wall, the stain covered the hunter's screen.
	check("Para el cazador no se dibuja ninguna mancha de las paredes", level.hotel.echo_view and level.hotel.decals.all(func(decal): return not decal.visible))
	# The order the five readings stack in. The hotel's own transparents (the
	# monstera leaves, the dust) all sit at 0, so the whole echo draws above
	# them; within the echo, the field goes first and its own body last.
	var order := [echo.field_material.render_priority, echo.mark_material.render_priority, echo.wall_material.render_priority, echo.frame_material.render_priority, echo.puff_material.render_priority, echo.find_material.render_priority, echo.body_material.render_priority, echo.self_material.render_priority]
	var rising := true
	for i in range(1, order.size()):
		if order[i] <= order[i - 1]: rising = false
	check("Las lecturas se dibujan en orden y sobre el hotel", rising and order[0] > 0)

	# --- Cadence ------------------------------------------------------------------
	var intervals: Array = []
	var seen: int = echo.clicks
	var ticks := 0
	# Enough wall clock for a slow click rate: sixteen intervals at two per
	# second is eight seconds, so give it fifteen.
	while intervals.size() < 16 and ticks < 900:
		await physics_frame
		ticks += 1
		if echo.clicks != seen:
			seen = echo.clicks
			intervals.append(echo.last_interval)
	var nominal: float = 1.0 / float(echo.CLICK_RATE)
	var widest: float = nominal * (1.0 + echo.CLICK_JITTER) * (1.0 + echo.BREATH_DEPTH)
	var tightest: float = nominal * (1.0 - echo.CLICK_JITTER) * (1.0 - echo.BREATH_DEPTH)
	var inside := intervals.all(func(value: float): return value >= tightest - 0.001 and value <= widest + 0.001)
	check("La cadencia de pulsos se mantiene en su margen", intervals.size() >= 12 and inside)
	var distinct := {}
	for value in intervals: distinct[snappedf(value, 0.0001)] = true
	check("El pulso no es un metrónomo", distinct.size() > intervals.size() / 2)

	# --- Rays and the ring buffer -------------------------------------------------
	var budget: int = echo.budget.rays
	var most := 0
	var before: int = echo.rays_cast
	for i in 120:
		await physics_frame
		most = maxi(most, echo.rays_cast - before)
		before = echo.rays_cast
	check("El presupuesto de rayos se reparte entre fotogramas", most <= echo.per_tick and echo.per_tick < budget)
	check("Se lanzan rayos en cada pulso", echo.rays_cast > budget)
	var cloud: MultiMesh = echo.walls.multimesh
	check("El anillo de puntos nunca pasa del presupuesto", cloud.instance_count == echo.budget.points and echo.wall_at < cloud.instance_count and echo.wall_shown <= cloud.instance_count)
	var span: float = echo.wall_material.get_shader_parameter("age_limit")
	check("Los puntos se apagan antes de ser sobrescritos", span <= float(maxi(echo.wall_shown, 1)) / maxf(echo.write_rate, 1.0) + 0.001 and span <= echo.MEMORY)

	# --- Bodies -------------------------------------------------------------------
	# A stretch of corridor on the first planta that runs north to south,
	# long enough to stand four metres apart in.
	var corridor: Dictionary = level.manifest.rooms[int(level.manifest.start)]
	for room in level.manifest.rooms:
		if int(room.type) in [11, 12] and int(room.get("hall", -1)) == -1 and int(room.wing) == 0 and float(room.span_z) >= 10.0:
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
	await click_passes(echo)
	await click_passes(echo)
	check("Un cuerpo a la vista deja puntos", echo.body_shown > grown or echo.body_shown == echo.bodies.multimesh.instance_count)
	# The same survivor, rooms away: no silhouette at all.
	var away := far_room(int(corridor.id))
	level.player.global_position = FLOOR.position_of(away) + Vector3(0, 0.06, 0)
	await frames(20)
	echo.body_shown = 0
	var quiet: int = echo.body_shown
	await click_passes(echo)
	await click_passes(echo)
	check("Un cuerpo tras las paredes no deja ninguno", not creature.sees(level.player) and echo.body_shown == quiet)

	# --- Sound contacts -----------------------------------------------------------
	creature.driver.heard.clear()
	# Along the corridor: across it, a metre and a half is the wall.
	var near_point: Vector3 = creature.global_position + Vector3(0.0, 0.2, -1.6)
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
	var hugging := false
	for door in level.hotel.doors:
		var heard_route: Dictionary = creature.hear_route(door.doorway, 30.0)
		# Heard in plain sight it is placed where it is, however close; only a
		# noise round a corner is placed by the way it arrives.
		if heard_route.audible and heard_route.apparent.distance_to(door.doorway) > 0.01 and heard_route.apparent.distance_to(creature.global_position + Vector3.UP * 1.5) < creature.APPARENT_NEAREST - 0.05: hugging = true
	check("Un ruido tras una esquina nunca se pinta encima de la criatura", not hugging)
	check("Lejos se pinta por dónde llega, no dónde está", not far_mark.is_empty() and far_mark.blur == 1.0 and far_mark.at.distance_to(far_mark.apparent) < 0.01)
	# A heard noise leaves a puff of grains hanging where it was heard, and a
	# noise made close by brings the shape of whoever made it with it. Puffs
	# bloom on a click, so wait for one instead of counting frames.
	creature.driver.heard.clear()
	level.player.global_position = near_point
	await frames(4)
	var before_puff: int = echo.puff_at
	level.on_noise(near_point, 12.0, NOISE.Kind.SLAM)
	await click_passes(echo)
	var grains: int = echo.puff_at - before_puff
	check("El ruido se materializa como una nube de puntos", echo.puffs.multimesh.instance_count > 0 and grains > 0)
	check("Y un ruido cercano trae la forma de quien lo hizo", grains > echo.budget.puff_points * 2)
	await frames(int(echo.CONTACT_LIFE * 60) + 20)
	var stale: bool = creature.driver.heard.any(func(mark): return Time.get_ticks_msec() / 1000.0 - mark.time > echo.CONTACT_LIFE + 0.1)
	check("Los contactos caducan", not stale)
	# Each kind shows as much as it should: at the same loudness a run leaves
	# far more than a step, and a door more than either. Nobody near, so no
	# body shape is added to the count.
	level.player.global_position = Vector3(0, -80, 0)
	var puffed := {}
	for kind in [NOISE.Kind.FOOTSTEP, NOISE.Kind.RUN, NOISE.Kind.DOOR]:
		creature.driver.heard.clear()
		var start: int = echo.puff_at
		level.on_noise(near_point, 12.0, kind)
		await click_passes(echo)
		puffed[kind] = posmod(echo.puff_at - start, echo.puffs.multimesh.instance_count)
	check("Correr deja más rastro que caminar, y una puerta más aún", puffed[NOISE.Kind.RUN] > puffed[NOISE.Kind.FOOTSTEP] * 2 and puffed[NOISE.Kind.DOOR] > puffed[NOISE.Kind.FOOTSTEP] * 2)
	# A wardrobe is heard from the next rooms, as far as a door, and its cloud
	# hangs in front of its doors instead of inside it.
	# That a wardrobe carries into the next room is the property being checked,
	# so the hunter is stood in a room next door to one instead of being left
	# wherever its patrol had taken it. A wardrobe stands against its room's
	# wall, so the middle of the room next door can be as close as seven
	# metres: the pair is only taken if it is more than eight, which is a
	# room away and not arm's reach.
	var far_hide = null
	var far_gap := 0.0
	for hide in level.hotel.hides:
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, hide.global_position)
		if room.is_empty() or int(room.type) == 19: continue
		for neighbour in level.manifest.adjacency[int(room.id)]:
			var next_room: Dictionary = level.manifest.rooms[int(neighbour)]
			if int(next_room.type) == 19: continue
			creature.global_position = FLOOR.position_of(next_room) + Vector3(0, 0.1, 0)
			await frames(2)
			if not creature.hear_route(hide.global_position, level.HUNTER_WARDROBE_RADIUS).audible: continue
			if hide.global_position.distance_to(creature.global_position) <= 8.0: continue
			far_hide = hide
			far_gap = hide.global_position.distance_to(creature.global_position)
			break
		if far_hide != null: break
	creature.driver.heard.clear()
	if far_hide != null: level.on_hide_changed(true, far_hide.global_position)
	await frames(3)
	# Asked straight away: a contact lives CONTACT_LIFE seconds, and waiting
	# for a couple of clicks first is long enough to lose it.
	check("Un armario se oye desde otra habitación", far_hide != null and far_gap > 8.0 and creature.driver.heard.any(func(mark): return int(mark.kind) == NOISE.Kind.WARDROBE))
	# The way on has moved: while the survivors have gone on and it has not, the
	# way to its car is laid out in blue in its reading, worked out here from
	# where it stands on every click. Nothing is sent for it.
	var stage_before: int = level.session.stage
	var creature_before: Vector3 = creature.global_position
	creature.global_position = Vector3(0, 0.04, 0)
	level.session.stage = 2
	var car_index: int = level.lifts.creature_car(2)
	await click_passes(echo)
	await click_passes(echo)
	check("Con la etapa cerrada y ella atrás, ve en azul el camino al coche", car_index == 0 and echo.guide_routes.lift > 1 and echo.guide_count > echo.guide_routes.lift and echo.guide_material.get_shader_parameter("tone_cold").b > 1.0 and is_equal_approx(echo.guide_material.get_shader_parameter("through"), 1.0))
	check("Y el chillido no lo tiñe de rojo", echo.guide_material.get_shader_parameter("shriek_cold") == echo.guide_material.get_shader_parameter("tone_cold"))
	level.lifts.apply_locust_ride(level.hotel.arrivals[car_index] + Vector3(0, 0.04, 0))
	await click_passes(echo)
	check("En cuanto toma el coche el camino desaparece", echo.guide_routes.lift == 0)
	level.lifts.lift_away.clear()
	# Now in the wing of the second stage: its lit sets burn yellow from anywhere
	# on the floor, and Q lays the way to the nearest it can walk to, for
	# fifteen seconds, once every twenty from when it is asked for.
	var stage_sets: Array = level.stage_televisions(2)
	creature.grace = 0.0
	creature.driver.trace_cooldown = 0.0
	creature.driver.trace()
	check("Sin teles encendidas, Q no gasta nada", creature.driver.trace_cooldown == 0.0 and creature.driver.trace_left == 0.0)
	for index in stage_sets.slice(0, 2): level.apply_television(int(index), true)
	await click_passes(echo)
	check("Las teles encendidas brillan en amarillo en su lectura", echo.guide_routes.screens == 2 and echo.guide_material.get_shader_parameter("tone_hot").r > 1.0)
	creature.driver.trace()
	var asked: int = creature.driver.trace_target
	var nav_map: RID = level.get_world_3d().navigation_map
	var nearest := -1
	var shortest := INF
	for index in stage_sets.slice(0, 2):
		var way := FLOOR.navigation_path(nav_map, creature.global_position, creature.driver.set_front(int(index)))
		var length := 0.0
		for i in range(1, way.size()): length += way[i].distance_to(way[i - 1])
		if way.size() >= 2 and length < shortest:
			shortest = length
			nearest = int(index)
	await click_passes(echo)
	check("Q traza en amarillo el camino a la tele encendida más cercana", asked >= 0 and asked == nearest and echo.guide_routes.trace > 1 and creature.driver.trace_left > 13.0)
	var waited: float = creature.driver.trace_cooldown
	creature.driver.trace()
	check("Y no se puede volver a pedir hasta veinte segundos después de pedirlo", is_equal_approx(creature.driver.TRACE_COOLDOWN, 20.0) and waited > 18.0 and creature.driver.trace_cooldown <= waited)
	creature.driver.trace_left = 0.01
	await click_passes(echo)
	check("A los quince segundos el rastro se va", echo.guide_routes.trace == 0)
	for index in stage_sets.slice(0, 2): level.apply_television(int(index), false)
	await click_passes(echo)
	check("Y una tele apagada deja de brillar", echo.guide_routes.screens == 0)
	level.session.stage = stage_before
	creature.global_position = creature_before
	var before_dark: int = echo.find_at
	creature.driver.mark_blackout()
	await click_passes(echo)
	check("Y el apagón le llega como una sacudida alrededor", echo.find_at != before_dark)
	if level.hotel.hides.size() > 0:
		var cabinet = level.hotel.hides[0]
		var hung: Vector3 = echo.before_wardrobe(cabinet.global_position)
		check("La nube de un armario cuelga delante de sus puertas", hung.y - cabinet.global_position.y > 0.8 and (cabinet.global_basis.inverse() * (hung - cabinet.global_position)).z > 0.5)
	# A door's cloud is a bell round its source, not an even ball: many more
	# grains in its core than an even ball would put there (under 3%; this one over 30%).
	var core := 0
	for i in 400:
		if echo.bell_offset(1.0).length() < 0.3: core += 1
	check("La nube de una puerta se concentra en su origen", core > 120 and NOISE.Kind.DOOR in echo.PUFF_BELLS and NOISE.Kind.WARDROBE in echo.PUFF_BELLS)
	# However loud and however far, a sound stays a place: a far run once hung
	# a ball twelve metres across round the creature with nobody in it.
	var loudest: float = echo.puff_radius(1.0, NOISE.Kind.RUN, 1.0)
	check("Una nube de sonido nunca es más grande que un sitio", loudest <= echo.PUFF_MAX_RADIUS and echo.PUFF_MAX_RADIUS <= 2.0 and echo.puff_radius(0.25, NOISE.Kind.FOOTSTEP, 0.0) < loudest)
	check("Una carrera oída solo por dónde llega es algo por ahí, no un objeto", echo.puff_radius(1.0, NOISE.Kind.RUN, 1.0) < echo.puff_radius(1.0, NOISE.Kind.RUN, 0.0) and echo.puff_radius(1.0, NOISE.Kind.DOOR, 1.0) >= echo.puff_radius(1.0, NOISE.Kind.DOOR, 0.0))
	check("Un armario se apaga antes que una puerta", echo.PUFF_LIVES[NOISE.Kind.WARDROBE] < echo.PUFF_LIVES[NOISE.Kind.DOOR] and echo.PUFF_LIVES[NOISE.Kind.DOOR] > echo.PUFF_LIFE and echo.PUFF_DENSITY[NOISE.Kind.WARDROBE] == echo.PUFF_DENSITY[NOISE.Kind.DOOR])

	# --- The shriek ---------------------------------------------------------------
	# It only finds what is moving and out in the open. Checked on a real
	# remote body, which is what an online match actually hunts, and whose
	# velocity comes from the states its owner pushes.
	var mate = REMOTE.new()
	mate.setup(level, 2, "Prueba", 0)
	level.add_child(mate)
	var spot: Vector3 = creature.global_position + Vector3(2.5, 0.0, 0.0)
	mate.place(spot, 0.0)
	level.match_net.bodies[2] = mate
	level.session.participants[2] = level.session.Life.EXPLORING
	for i in 8:
		mate.push_state([spot, 0.0, 0.0, Vector3.ZERO, 0, -1, 0.0, 0.0])
		await physics_frame
	level.match_net.shriek_left = level.match_net.SHRIEK_TIME
	level.match_net.shriek_clock = 0.0
	creature.driver.revealed.clear()
	for i in 20:
		mate.push_state([spot, 0.0, 0.0, Vector3.ZERO, 0, -1, 0.0, 0.0])
		await physics_frame
	check("Quieto, el chillido no lo encuentra", creature.driver.revealed.is_empty())
	level.match_net.shriek_clock = 0.0
	for i in 20:
		spot += Vector3(0.05, 0.0, 0.0)
		mate.push_state([spot, 0.0, 0.0, Vector3(3.0, 0.0, 0.0), 0, -1, 0.0, 0.0])
		await physics_frame
	var found: bool = not creature.driver.revealed.is_empty()
	check("Moviéndose, el chillido lo marca", found)
	check("Y la marca es una nube que dura", found and echo.finds.multimesh.instance_count > 0 and echo.finds_written > 0 and echo.FIND_LIFE >= 3.0)
	level.match_net.shriek_left = 0.0
	level.match_net.bodies.erase(2)
	level.session.participants.erase(2)
	mate.queue_free()
	await physics_frame
	echo.flash_shriek()
	await frames(30)
	check("El chillido enrojece la lectura", echo.shriek > 0.9)
	echo.shriek_hold = 0.0
	await frames(240)
	check("Y se apaga después", echo.shriek < 0.05)
	# The cry sounds exactly as long as the red, fading with it, and a second
	# shriek while it lasts stretches it instead of cutting it short.
	var cry: float = echo.SHRIEK_HOLD + 1.0 / echo.SHRIEK_FALL
	creature.howl(echo.SHRIEK_HOLD, 1.0 / echo.SHRIEK_FALL, false)
	check("El chillido suena lo que dura el rojo", absf(creature.howl_left - cry) < 0.05)
	await frames(180)
	creature.howl(echo.SHRIEK_HOLD, 1.0 / echo.SHRIEK_FALL, false)
	check("Chillar otra vez lo alarga", absf(creature.howl_left - cry) < 0.05 and creature.grunt_left > 0.0)
	await frames(int(cry * 60.0) + 20)
	check("Y termina callado", creature.howl_left == 0.0 and creature.grunt_left == 0.0)
	# From the hunter's own button, once every ten seconds counted from when it
	# starts: longer than the cry, so it can no longer be chained. At three it
	# could, and a hunter holding the button never stopped crying.
	creature.grace = 0.0
	creature.driver.shriek_cooldown = 0.0
	creature.driver.shriek()
	var first_cry: float = creature.howl_left
	await frames(120)
	creature.driver.shriek()
	check("El chillido tiene diez segundos de enfriamiento desde que se usa", is_equal_approx(creature.driver.SHRIEK_COOLDOWN, 10.0) and creature.driver.shriek_cooldown > 7.0 and creature.driver.shriek_cooldown < 8.5 and creature.howl_left < first_cry - 1.5)
	creature.howl_left = 0.0
	creature.grunt_left = 0.0
	creature.voice.stop()
	echo.shriek_hold = 0.0
	level.match_net.shriek_left = 0.0

	# --- The motes ----------------------------------------------------------------
	# Red over a burnt-out mind only while it is out: killed, what it left must
	# not hang there for the rest of the match. The motes' material never ages
	# a grain, so the cloud's visible count is what ends them.
	var lost = REMOTE.new()
	lost.setup(level, 3, "Quemado", 0)
	level.add_child(lost)
	lost.place(creature.global_position + Vector3(2.5, 0.0, 0.0), 0.0)
	level.match_net.bodies[3] = lost
	level.session.participants[3] = level.session.Life.EXPLORING
	level.sanity.minds[3] = {"sanity": 0.0, "rest": 0.0, "paid": 0.0}
	lost.set_burnt(true)
	await click_passes(echo)
	await click_passes(echo)
	check("Una mente quemada lleva sus motas encima", echo.motes.multimesh.visible_instance_count == echo.MOTE_GRAINS)
	level.session.participants[3] = level.session.Life.DEAD
	await click_passes(echo)
	check("Muerta, sus motas se van con ella", echo.motes.multimesh.visible_instance_count == 0)
	level.match_net.bodies.erase(3)
	level.session.participants.erase(3)
	level.sanity.minds.erase(3)
	lost.queue_free()
	await physics_frame

	# --- Strong reflectors ---------------------------------------------------------
	# A door in plain view answers on its own: its frame fills with grains.
	var door = null
	var stand := Vector3.ZERO
	var map: RID = level.get_world_3d().navigation_map
	for candidate in level.hotel.doors:
		var turn := Basis(Vector3.UP, candidate.closed_rotation)
		for side in [-1.0, 1.0]:
			var place: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate.doorway + turn.z * (3.2 * side))
			if place.distance_to(candidate.doorway) < 2.4: continue
			door = candidate
			stand = place
			break
		if door != null: break
	check("Hay una puerta para mirar", door != null)
	creature.global_position = stand + Vector3(0, 0.04, 0)
	var facing: Vector3 = door.doorway - stand
	creature.rotation.y = atan2(-facing.x, -facing.z)
	creature.driver.pitch = -0.1
	await frames(4)
	var slot: int = level.hotel.doors.find(door)
	var before_hits: int = echo.reflector_hits[slot]
	await click_passes(echo)
	await click_passes(echo)
	await click_passes(echo)
	check("Un marco de puerta a la vista se llena de granos", echo.reflector_hits[slot] - before_hits > 40)
	# One aimed ray that lands, then the same with a wall put in between.
	var space: PhysicsDirectSpaceState3D = creature.get_world_3d().direct_space_state
	var head: Vector3 = creature.global_position + Vector3(0, creature.driver.EYE.y, 0)
	var seen_spot := Vector3.INF
	for aim in echo.reflector_spots(echo.reflectors[slot].frame):
		if not echo.reflect(space, head, aim).is_empty():
			seen_spot = aim
			break
	var screen := StaticBody3D.new()
	var screen_shape := CollisionShape3D.new()
	var screen_box := BoxShape3D.new()
	screen_box.size = Vector3(4.0, 4.0, 0.2)
	screen_shape.shape = screen_box
	screen.add_child(screen_shape)
	level.add_child(screen)
	var blocked := false
	if seen_spot != Vector3.INF:
		screen.global_position = head.lerp(seen_spot, 0.5)
		screen.look_at(seen_spot, Vector3.UP)
		await frames(2)
		blocked = echo.reflect(space, head, seen_spot).is_empty()
	screen.queue_free()
	await frames(2)
	check("Un marco tras una pared no devuelve nada", seen_spot != Vector3.INF and blocked)
	check("Los rayos a puertas y armarios cuentan en el mismo presupuesto", echo.per_tick * (60.0 / echo.CLICK_RATE) >= echo.budget.rays + echo.budget.aimed)
	# A wardrobe is a block, and a shut door a panel, not only an outline.
	var hide_spots: int = echo.reflector_spots(echo.reflectors[level.hotel.doors.size()].frame).size() if level.hotel.hides.size() > 0 else 0
	check("Un armario se apunta como bloque entero", hide_spots == echo.WARDROBE_SPOTS)
	check("Una puerta cerrada se apunta también en su hoja", echo.reflector_spots(echo.reflectors[0].panel).size() == echo.PANEL_SPOTS)
	# Stipple, not a matrix: two clicks never aim at the same spots.
	var first: PackedVector3Array = echo.reflector_spots(echo.reflectors[0].frame)
	var second: PackedVector3Array = echo.reflector_spots(echo.reflectors[0].frame)
	check("Los puntos de un marco cambian de un clic a otro", first.size() == second.size() and first[0].distance_to(second[0]) > 0.001 and first[first.size() - 1].distance_to(second[second.size() - 1]) > 0.001)

	# --- Landmarks ----------------------------------------------------------------
	# Both faces of a door reveal: two jambs and a lintel each. A wardrobe gets
	# its two sides and a rail top and bottom.
	# Only those of its own planta: the ones under the floor would show through it.
	var per_door: int = 2 * (2 * echo.JAMB_GRAINS + echo.LINTEL_GRAINS)
	var per_hide: int = 2 * echo.JAMB_GRAINS + 2 * echo.LINTEL_GRAINS
	var own_planta: int = FLOOR.planta_of(creature.global_position.y)
	var own_doors: int = level.hotel.doors.filter(func(door): return FLOOR.planta_of(door.doorway.y) == own_planta).size()
	var own_hides: int = level.hotel.hides.filter(func(hide): return FLOOR.planta_of(hide.global_position.y) == own_planta).size()
	var wanted: int = own_doors * per_door + own_hides * per_hide
	var marks: int = echo.marks.multimesh.instance_count
	await frames(60)
	check("Conoce las puertas y armarios de su planta, con el marco entero", marks == wanted and marks > own_doors * 40 and own_doors < level.hotel.doors.size())
	check("Y esos hitos no cambian", echo.marks.multimesh.instance_count == marks)

	# --- Settings -----------------------------------------------------------------
	level.settings.set_value("reduced", true)
	level.apply_settings()
	await frames(10)
	check("Efectos reducidos quitan temblor y grano", echo.field_material.get_shader_parameter("jitter_amount") == 0.0 and echo.field_material.get_shader_parameter("grain_amount") == 0.0)
	# Reduced calms the reading; it must never leave the hunter a black screen,
	# and with the grains carrying every shape they are what must stay on.
	var quiet_grain: float = echo.wall_material.get_shader_parameter("residue")
	check("Pero no apagan la imagen", quiet_grain >= 0.3 and echo.walls.multimesh.instance_count > 0 and echo.budget.rays > 0)
	# Every preset leaves the hunter a reading to play with: Bajo has half the
	# grains of Medio at twice the size, and its doors and wardrobes lose no
	# rays; Ultra is only a little finer than Alto.
	var medium_span: float = echo.wall_material.get_shader_parameter("point_scale")
	var medium_points: int = echo.walls.multimesh.instance_count
	level.settings.set_value("reduced", false)
	level.settings.set_value("quality", 0)
	level.apply_settings()
	await frames(20)
	check("Bajo sigue leyendo la sala: la mitad de granos, del doble de tamaño", echo.walls.multimesh.instance_count * 2 == medium_points and echo.budget.rays > 0 and is_equal_approx(echo.wall_material.get_shader_parameter("point_scale"), medium_span * 2.0))
	check("Y en Bajo las puertas y armarios no pierden rayos", echo.budget.aimed >= PRESETS.PRESETS[PRESETS.MEDIUM].echo.aimed and echo.frames.multimesh.instance_count >= PRESETS.PRESETS[PRESETS.MEDIUM].echo.frames)
	level.settings.set_value("quality", 3)
	level.apply_settings()
	await frames(20)
	check("Ultra: algo más denso que Alto y con granos más pequeños", echo.walls.multimesh.instance_count > PRESETS.PRESETS[PRESETS.HIGH].echo.points and echo.wall_material.get_shader_parameter("point_scale") < medium_span)
	level.settings.set_value("quality", 1)
	level.apply_settings()
	await frames(10)

	# --- It never touches the map's randomness ------------------------------------
	var generator = GENERATOR.new()
	var again: Dictionary = generator.generate(81, level.session.roster_count)
	# The floor keeps only the sets it is played on (tv_placement.settle).
	preload("res://game/world/generation/tv_placement.gd").settle(again, level.session.roster_count)
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
