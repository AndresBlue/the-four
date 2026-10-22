extends Node
## A mind going lies with the creature itself: it walks past, a room or two
## away, and it is not there. Its claws on the floor, its presence, the aura it
## drags -- the chitter, the breath, the heart, the room going dull -- all of
## it the same as the real thing, because it is the real thing's sound fed a
## point that walks (world_audio.phantom_point, which the presence and the
## dread aura take whenever it is nearer than the creature).
##
## Local to this machine, like every lie of the floor: it is not a noise,
## nothing hears it, and nobody else does either. Never in the refuge, and
## never while the real one is close enough to be heard: the floor does not
## lie over the truth.
##
## The Locust's: its pace, its stride and its claws. Its lies make it
## (game/app/hallucinations/locust_hallucinations.gd, walk_past).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
const AURA := preload("res://game/audio/dread_aura.gd")
## Where it walks: from a spot this many metres of walking from the listener,
## past it no nearer than CLOSEST, at its patrol pace, for up to LONGEST s.
const START := Vector2(12.0, 20.0)
const CLOSEST := 8.0
const PACE := 1.9
const LONGEST := 10.0
## Seconds between its footfalls at that pace: long legs, slow steps.
const STRIDE := 0.62
## The real creature this near (walking) or its aura this strong, and there is
## no lie to tell.
const REAL_NEAR := 30.0
const REAL_AURA := 0.2
var level
var path := PackedVector3Array()
var walked := 0.0
var length := 0.0
var clock := 0.0
var step_clock := 0.0
var steps: AudioStreamPlayer3D
var rng := RandomNumberGenerator.new()

func setup(owner_level) -> void:
	level = owner_level
	name = "PhantomPassage"
	rng.randomize()
	steps = AudioStreamPlayer3D.new()
	steps.name = "PhantomSteps"
	steps.bus = "Threat"
	steps.stream = LOCUST.claw_sound()
	steps.unit_size = 6.0
	steps.max_distance = 34.0
	steps.area_mask = 512
	add_child(steps)

func walking() -> bool:
	return not path.is_empty()

## Whether a lie of this kind can be told now: the real one far and quiet.
func allowed() -> bool:
	var creature = level.creature
	if level.in_refuge() or not is_instance_valid(creature): return false
	var aura = level.world_audio.aura
	if aura != null and float(aura.intensity) > REAL_AURA: return false
	var listener: Vector3 = level.player.global_position
	var real: Vector3 = creature.global_position
	if FLOOR.planta_of(real.y) != FLOOR.planta_of(listener.y): return true
	if real.distance_to(listener) > REAL_NEAR * 1.5: return true
	var map: RID = level.get_world_3d().navigation_map
	var route := FLOOR.navigation_path(map, listener, real)
	var metres := 0.0
	for i in range(1, route.size()): metres += route[i].distance_to(route[i - 1])
	return route.size() < 2 or metres > REAL_NEAR

## Starts it walking past; false when there is nowhere out of sight for it.
func begin() -> bool:
	if walking() or not allowed(): return false
	var listener: Vector3 = level.player.global_position
	var map: RID = level.get_world_3d().navigation_map
	var here := FLOOR.room_at(level.manifest.rooms, listener)
	if here.is_empty(): return false
	var metres := FLOOR.route_metres(level.manifest, int(here.id))
	var rooms: Array = []
	for key in metres:
		var walk := float(metres[key])
		var room: Dictionary = level.manifest.rooms[int(key)]
		if walk >= START.x and walk <= START.y and not FLOOR.is_void(room) and not level.off_limits_rooms().has(int(key)): rooms.append(room)
	rooms.shuffle()
	for room in rooms.slice(0, 8):
		for other in level.manifest.adjacency[room.id]:
			var next: Dictionary = level.manifest.rooms[int(other)]
			if FLOOR.is_void(next) or level.off_limits_rooms().has(int(other)): continue
			var from := FLOOR.closest(map, FLOOR.position_of(room))
			var to := FLOOR.closest(map, FLOOR.position_of(next))
			var way := FLOOR.navigation_path(map, from, to)
			if way.size() < 2 or not clear_of(way, listener) or seen(from) or seen(to): continue
			path = way
			length = 0.0
			for i in range(1, way.size()): length += way[i].distance_to(way[i - 1])
			length = minf(length, PACE * LONGEST)
			walked = 0.0
			step_clock = rng.randf_range(0.0, STRIDE)
			return true
	return false

## Its whole way stays CLOSEST metres from the listener.
func clear_of(way: PackedVector3Array, listener: Vector3) -> bool:
	for i in range(1, way.size()):
		for part in 4:
			if way[i - 1].lerp(way[i], part / 4.0).distance_to(listener) < CLOSEST: return false
	return true

## In plain view of the listener's eyes: somewhere it would have to be seen.
func seen(point: Vector3) -> bool:
	var eye: Vector3 = level.player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(eye, point + Vector3(0, 1.6, 0), 1 | 8 | 64)
	query.exclude = [level.player.get_rid()]
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func stop() -> void:
	path = PackedVector3Array()
	level.world_audio.phantom_point = Vector3.INF

func _physics_process(delta: float) -> void:
	if level == null or not walking(): return
	# Gone as soon as the truth is near, or the floor is not being played.
	if level.session.state != level.session.State.PLAYING or not level.local_alive() or level.in_refuge():
		stop()
		return
	walked += PACE * delta
	if walked >= length:
		stop()
		return
	var point: Vector3 = AURA.along(path, walked)
	level.world_audio.phantom_point = point
	step_clock -= delta
	if step_clock <= 0.0:
		step_clock = STRIDE * rng.randf_range(0.9, 1.1)
		footfall(point)

## One of its feet, heard the way the real ones are (hotel_locust.on_footfall).
func footfall(point: Vector3) -> void:
	if not level.world_audio.enabled: return
	var route: Dictionary = level.world_audio.route_source(point + Vector3.UP * 0.2)
	if not route.audible: return
	level.world_audio.apply_route(steps, route, rng.randf_range(-7.0, -3.0) + level.world_audio.duck_db(), "Threat", true)
	steps.pitch_scale = rng.randf_range(0.82, 1.08)
	steps.play()
