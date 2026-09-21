extends Node
## The mind of the survivor on this machine, and what the creature is told
## about the ones that have gone. Split out of hotel_main.gd, which owns it
## (`level.sanity`) and calls tick() and haunt_burnt() from its own loop.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

## A meter with no bar. It falls in the dark -- faster shut inside a wardrobe,
## and half as fast with the torch on, because a torch is something to hold on
## to -- and it comes back in a lit room. Seeing the creature takes a lump out
## of it at once.
##
## Under UNEASY the floor starts lying: doors and wardrobes open where nobody
## is, and further down the creature calls from somewhere it is not. The tape
## frays along with it, which is the only thing on screen that says any of this
## is happening.
##
## At zero the body gives off motes the creature senses from anywhere, and it
## takes the better part of a minute in the light to stop giving them off.
## Waiting a floor out inside a wardrobe is not a plan.
const SANITY_DARK := 100.0 / 150.0
const SANITY_HIDDEN := 1.3
const SANITY_TORCH := 0.45
const SANITY_LIGHT := 100.0 / 240.0
const SANITY_SIGHT := 14.0
const SANITY_SIGHT_REST := 5.0
const SANITY_UNEASY := 60.0
const SANITY_BACK := 25.0
const SANITY_SEEN := 28.0
const HALLUCINATION_WAIT := Vector2(13.0, 42.0)
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
const PHANTOM_CLIP := "res://assets/audio/sfx/chase/grunts.ogg"
var sight_rest := 0.0
var hallucination_wait := 0.0
var phantom: AudioStreamPlayer3D
var phantom_left := 0.0

func tick(delta: float) -> void:
	if level.manifest.is_empty() or not is_instance_valid(level.hotel) or level.match_net.local_is_locust(): return
	if not level.local_alive():
		phantom_quiet(delta)
		return
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, level.player.global_position)
	var lit: bool = not level.hotel.dark and not room.is_empty() and not level.hotel.dark_ids.has(int(room.id))
	if level.player.hidden or not lit:
		var rate := SANITY_DARK
		if level.player.hidden: rate *= SANITY_HIDDEN
		elif level.player.torch.visible: rate *= SANITY_TORCH
		level.player.sanity = maxf(0.0, level.player.sanity - rate * delta)
	else: level.player.sanity = minf(100.0, level.player.sanity + SANITY_LIGHT * delta)
	# A long look at it is one fright, not one a frame.
	sight_rest = maxf(0.0, sight_rest - delta)
	if sight_rest <= 0.0 and sees_creature(lit):
		sight_rest = SANITY_SIGHT_REST
		level.player.sanity = maxf(0.0, level.player.sanity - SANITY_SIGHT)
	if level.player.burnt and level.player.sanity >= SANITY_BACK:
		level.player.set_burnt(false)
	elif not level.player.burnt and level.player.sanity <= 0.0:
		level.player.set_burnt(true)
	hallucinate(delta)
	phantom_quiet(delta)

## The creature in plain view: in the picture, near enough to make out, lit by
## something, and nothing in between. In the pitch dark with the torch off
## there is nothing to see and nothing to be frightened by.
func sees_creature(lit: bool) -> bool:
	if not is_instance_valid(level.locust) or level.locust.grace > 0.0 or not is_instance_valid(level.player.camera): return false
	var eye: Vector3 = level.player.camera.global_position
	var towards: Vector3 = level.locust.global_position + Vector3(0, 1.2, 0) - eye
	var gap := towards.length()
	if gap > SANITY_SEEN or gap < 0.01: return false
	if not lit and not level.player.torch.visible and gap > 6.0: return false
	if -level.player.camera.global_basis.z.dot(towards / gap) < 0.72: return false
	var query := PhysicsRayQueryParameters3D.create(eye, eye + towards, 1)
	query.exclude = [level.player.get_rid()]
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## The floor lying: a door, a wardrobe or the creature's own call, somewhere
## nobody is. Local to this machine -- it is not a noise, nothing hears it and
## nobody else does either.
var last_lie := {}
func hallucinate(delta: float) -> void:
	if level.player.sanity > SANITY_UNEASY or level.player.reading: return
	hallucination_wait -= delta
	if hallucination_wait > 0.0: return
	var gone: float = 1.0 - level.player.sanity / SANITY_UNEASY
	hallucination_wait = lerpf(HALLUCINATION_WAIT.y, HALLUCINATION_WAIT.x, gone) * randf_range(0.7, 1.3)
	var point := hallucination_point(randf_range(4.0, 14.0))
	var voice: bool = gone > 0.5 and randf() < gone * 0.45
	last_lie = {"point": point, "voice": voice, "time": Time.get_ticks_msec() / 1000.0}
	# A silent run (tests, captures) keeps the cadence: the lie counts as told.
	if not level.world_audio.enabled: return
	if voice: false_call(point)
	else: level.world_audio.play_at(level.world_audio.choose(["close_far", "open_far", "hide_leave", "open_slow"][randi() % 4]), point, -4.0)

## Somewhere on the floor around, in a room and not inside a wall.
func hallucination_point(reach: float) -> Vector3:
	var angle := randf() * TAU
	var point: Vector3 = level.player.global_position + Vector3(sin(angle), 0, cos(angle)) * reach
	return NavigationServer3D.map_get_closest_point(level.get_world_3d().navigation_map, point)

## Its voice, from where it is not. Its own throat is elsewhere: this one has
## a level.player of its own so the real call is never cut short by a made-up one.
func false_call(point: Vector3) -> void:
	if not is_instance_valid(phantom):
		phantom = AudioStreamPlayer3D.new()
		phantom.name = "Phantom"
		phantom.bus = "Threat"
		phantom.stream = load(PHANTOM_CLIP)
		phantom.unit_size = 7.0
		phantom.max_distance = 40.0
		add_child(phantom)
	var segment: Array = GRUNTS.SEGMENTS[randi() % GRUNTS.SEGMENTS.size()]
	phantom.global_position = point + Vector3(0, 1.6, 0)
	phantom.pitch_scale = randf_range(0.8, 0.95)
	phantom.volume_db = -4.0
	phantom.play(segment[0])
	phantom_left = float(segment[1]) / phantom.pitch_scale

## A made-up call lasts as long as the piece of the recording it came from.
func phantom_quiet(delta: float) -> void:
	if not is_instance_valid(phantom) or not phantom.playing: return
	phantom_left -= delta
	if phantom_left <= 0.0: phantom.stop()

## The creature is told, over and over, where the burnt-out minds are. Only
## the machine in charge of it does this, and only while it drives itself: in
## versus the motes are on the hunter's screen instead.
const SMELL_EVERY := 1.5
var smell_rest := 0.0
func haunt_burnt(delta: float) -> void:
	smell_rest -= delta
	if smell_rest > 0.0 or not is_instance_valid(level.locust) or level.locust.control != "ai": return
	var marked := burnt_survivors()
	if marked.is_empty(): return
	smell_rest = SMELL_EVERY
	var nearest: Vector3 = marked[0]
	for point in marked:
		if level.locust.global_position.distance_to(point) < level.locust.global_position.distance_to(nearest): nearest = point
	level.locust.smell_burnt(nearest)

## Everybody whose mind has gone, wherever they are. The creature is told
## where they are however far away it is: that is what the motes are.
func burnt_survivors() -> Array:
	var marked: Array = []
	for body in level.survivors():
		if bool(body.get("burnt")): marked.append(body.global_position)
	return marked
