extends Node
## Pacing director for a floor. It never makes the creature stronger, never
## touches the map and never aims at the player's position. It only spaces
## out moments: after a chase there is rest, events are kept apart, and at most
## one event with consequences runs at a time. A player who stays put only
## ever gets an ambient signal, never something that brings the creature over.
##
## The Locust's events:
##  - raps:  knuckles on a door a few rooms away. Ambient only.
##  - fall:  something falls over in a nearby room; the creature goes to look.
##  - steps: the patrolling creature is sent through a room next to the player's.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Seconds without new hostile events after a chase or attack ends.
const REST_AFTER_CHASE := 30.0
## Minimum seconds between the start of two events.
const SEPARATION := 45.0
## Seconds without encounters or a newly visited room that count as staying put.
const STALL := 60.0
## Chance per second of starting an event once one is allowed.
const CHANCE := 1.0 / 25.0
const AMBIENT_CHANCE := 1.0 / 12.0
## Walking distance (metres) from the player at which events take place.
const NEAR := 9.0
const FAR := 26.0
const SOUNDS := {
	"raps": ["res://assets/audio/events/door_raps_1.wav", "res://assets/audio/events/door_raps_2.wav"],
	"fall": ["res://assets/audio/events/object_fall_1.wav", "res://assets/audio/events/object_fall_2.wav"],
}
var level
var rng := RandomNumberGenerator.new()
var clock := 0.0
var last_event := 0.0
var last_hostile := -INF
var last_new_room := 0.0
var visited := {}
## The running event: {type, started, until, point, consequence}.
var active := {}
## Every event started or cancelled, for tests and tuning.
var history: Array = []
## Tests force events to start as soon as they are allowed.
var force := false
var roll_clock := 0.0

func setup(owner_level, seed_value: int) -> void:
	level = owner_level
	rng.seed = hash([seed_value, "director"])

func _physics_process(delta: float) -> void:
	if level == null or level.session.state != level.session.State.PLAYING: return
	tick(delta)

func hostile() -> bool:
	var creature = level.locust
	return is_instance_valid(creature) and creature.mode in [creature.Mode.ALERT, creature.Mode.CHASE, creature.Mode.WINDUP, creature.Mode.RECOVER]

func stalled() -> bool:
	return clock - maxf(last_new_room, last_hostile) >= STALL

func tick(delta: float) -> void:
	clock += delta
	if hostile(): last_hostile = clock
	var room := FLOOR.room_at(level.manifest.rooms, level.pacing_anchor())
	if not room.is_empty() and not visited.has(room.id):
		visited[room.id] = true
		last_new_room = clock
	update_active()
	# The survivor it plays for, not this machine's own: a host waiting in the
	# refuge stopped every event for the ones still out there.
	if not active.is_empty() or hostile() or level.point_in_refuge(level.pacing_anchor()): return
	if clock - last_hostile < REST_AFTER_CHASE or clock - last_event < SEPARATION: return
	if is_instance_valid(level.locust) and level.locust.grace > 0.0: return
	roll_clock -= delta
	if roll_clock > 0.0 and not force: return
	roll_clock = 1.0
	if stalled():
		if force or rng.randf() < AMBIENT_CHANCE: start("raps")
	elif force or rng.randf() < CHANCE:
		start("fall" if rng.randf() < 0.5 else "steps")

func update_active() -> void:
	if active.is_empty(): return
	var creature = level.locust
	var over: bool = clock >= active.until
	match active.type:
		"fall": over = over or not is_instance_valid(creature) or creature.mode != creature.Mode.INVESTIGATE or creature.destination.distance_to(active.point) > 0.5
		"steps": over = over or not is_instance_valid(creature) or creature.mode != creature.Mode.PATROL or not creature.guided
	if over: active = {}

## Starts an event of the given type; a missing valid place cancels it.
func start(type: String) -> bool:
	var ok := false
	match type:
		"raps": ok = start_raps()
		"fall": ok = start_fall()
		"steps": ok = start_steps()
	history.append({"type": type, "time": clock, "started": ok, "point": active.get("point", Vector3.INF) if ok else Vector3.INF})
	if ok: last_event = clock
	return ok

func route_length(to: Vector3) -> float:
	var map: RID = level.get_world_3d().navigation_map
	var path := FLOOR.navigation_path(map, FLOOR.closest(map, level.pacing_anchor()), FLOOR.closest(map, to))
	if path.size() < 2 or path[-1].distance_to(FLOOR.closest(map, to)) > 0.6: return INF
	var length := 0.0
	for i in range(1, path.size()): length += path[i].distance_to(path[i - 1])
	return length

## Rooms other than the player's and the refuge, at a walking distance between NEAR and FAR.
func rooms_in_range() -> Array:
	var here := FLOOR.room_at(level.manifest.rooms, level.pacing_anchor())
	var result: Array = []
	for room in level.manifest.rooms:
		if level.off_limits_rooms().has(int(room.id)) or (not here.is_empty() and room.id == here.id): continue
		var centre := FLOOR.position_of(room)
		if centre.distance_to(level.pacing_anchor()) > FAR: continue
		var length := route_length(centre)
		if length >= NEAR and length <= FAR: result.append(room)
	return result

func start_raps() -> bool:
	var planta := FLOOR.planta_of(level.pacing_anchor().y)
	var doors: Array = level.hotel.doors.filter(func(door):
		var d: float = door.doorway.distance_to(level.pacing_anchor())
		# On the planta the player is on: raps under the floor are not heard.
		return d >= NEAR and d <= FAR and FLOOR.planta_of(door.doorway.y) == planta and not level.point_in_refuge(door.doorway))
	if doors.is_empty(): return false
	var door = doors[rng.randi_range(0, doors.size() - 1)]
	var point: Vector3 = door.doorway + Vector3.UP * 1.3
	var sound := pick("raps")
	level.world_audio.play_at(sound, point, -8.0, door.get_rid(), 0.0)
	level.match_net.world_sound(sound, point, -8.0, 0.0)
	active = {"type": "raps", "started": clock, "until": clock + 3.0, "point": point, "consequence": false}
	return true

func start_fall() -> bool:
	var creature = level.locust
	if not is_instance_valid(creature) or creature.mode not in [creature.Mode.PATROL, creature.Mode.SEARCH]: return false
	var rooms := rooms_in_range()
	if rooms.is_empty(): return false
	var room: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
	var map: RID = level.get_world_3d().navigation_map
	var point := FLOOR.closest(map, FLOOR.position_of(room) + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0)))
	var sound := pick("fall")
	level.world_audio.play_at(sound, point + Vector3.UP * 0.4, -2.0, RID(), 0.0)
	level.match_net.world_sound(sound, point + Vector3.UP * 0.4, -2.0, 0.0)
	creature.investigate(point)
	active = {"type": "fall", "started": clock, "until": clock + 25.0, "point": point, "consequence": true}
	return true

func start_steps() -> bool:
	var creature = level.locust
	if not is_instance_valid(creature) or creature.mode != creature.Mode.PATROL: return false
	var here := FLOOR.room_at(level.manifest.rooms, level.pacing_anchor())
	if here.is_empty(): return false
	var neighbours: Array = rooms_in_range().filter(func(room): return level.manifest.adjacency[here.id].has(room.id) or level.manifest.adjacency[room.id].any(func(id): return level.manifest.adjacency[here.id].has(id)))
	if neighbours.is_empty(): return false
	var room: Dictionary = neighbours[rng.randi_range(0, neighbours.size() - 1)]
	var point := FLOOR.position_of(room)
	creature.guide(room.id)
	active = {"type": "steps", "started": clock, "until": clock + 35.0, "point": point, "consequence": true}
	return true

func pick(type: String) -> String:
	var options: Array = SOUNDS[type]
	return options[rng.randi_range(0, options.size() - 1)]
