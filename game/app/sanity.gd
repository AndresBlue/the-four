extends Node
## The mind of the survivor on this machine, and what the creature is told
## about the ones that have gone. Split out of hotel_main.gd, which owns it
## (`level.sanity`) and calls tick() from its own loop.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

## A meter with no bar. It falls in the dark -- shut inside a wardrobe the
## same, and well under half as fast with the torch on, because a torch is
## something to hold on to -- and it comes back in a lit room. Seeing the
## creature takes a lump out of it at once: a small one catching sight of it,
## a big one when it is looking back at you.
##
## Slow on purpose. It used to empty in two and a half minutes of dark (two in
## a wardrobe), and a blackout -- the whole wing dark at once, torches only --
## took everybody's head with it before the last set was lit.
##
## Under UNEASY the floor starts lying: doors and wardrobes open where nobody
## is, and further down the creature calls from somewhere it is not. The tape
## frays along with it, which is the only thing on screen that says any of this
## is happening.
##
## At zero the body is marked, and it takes the better part of a minute in the
## light to stop. The creature is not told where: the pacing director is, and
## now and then it sends the creature to look round that part of the floor
## (pacing_director). Nothing of it shows on the body.
##
## **The machine that runs the floor keeps everybody's mind**, like every other
## rule of a stage: it wears each survivor down from what it already knows of
## them -- where they stand, whether that room is dark, whether they are shut
## in a wardrobe, whether their torch is on and where they are looking -- and
## tells everybody, twice a second, each one's meter and who has gone out. A
## guest's own meter is the host's, and only drives what the floor makes up
## for it (the hallucinations, the tape fraying). Before, each machine judged
## its own and the host believed a flag from each guest: a modified guest
## never went out, and the creature never smelled it.
## Seven and a half minutes of dark from whole to nothing; with the torch on
## it lasts well over a quarter of an hour.
const SANITY_DARK := 100.0 / 450.0
const SANITY_TORCH := 0.4
const SANITY_LIGHT := 100.0 / 240.0
## Catching sight of it, and meeting its eyes (it is looking at you: see
## sight_of_creature). One fright per SANITY_SIGHT_REST whatever is seen in it;
## a stare inside the rest of a glimpse costs only what the glimpse did not.
const SANITY_GLIMPSE := 4.0
const SANITY_STARE := 15.0
const SANITY_SIGHT_REST := 5.0
## How near its gaze has to point at your eyes to be a stare: its head turns
## to whoever it is after (locust_visual.look_point), its body to where it walks.
const STARE_CONE := 30.0
const SANITY_UNEASY := 60.0
const SANITY_BACK := 25.0
const SANITY_SEEN := 28.0
const HALLUCINATION_WAIT := Vector2(13.0, 42.0)
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
const PHANTOM_CLIP := "res://assets/audio/sfx/chase/grunts.ogg"
const PASSAGE := preload("res://game/app/phantom_passage.gd")
const SIGHT := preload("res://game/app/phantom_sight.gd")
## Of the lies told, how often it is the creature walking past, from the top
## of UNEASY to the bottom of the meter.
const PASSAGE_SHARE := Vector2(0.2, 0.45)
## The creature walking past that is not there, and the tape's jolt when a
## thing that was not there goes (phantom_sight), easing off.
var passage
var glitch := 0.0
## The creature seen where it is not (phantom_sight): made the first time the
## mind of this machine's survivor starts to go.
var sight
## The local survivor's rest between frights, and what the fright it rests
## from cost. Everybody else's lives in minds.
var sight_rest := 0.0
var sight_paid := 0.0
## Seat -> {"sanity", "rest", "paid"} for the survivors of other machines,
## kept by the authority. The local survivor's meter is its own player.sanity.
var minds := {}
var hallucination_wait := 0.0
var phantom: AudioStreamPlayer3D
var phantom_left := 0.0

func tick(delta: float) -> void:
	glitch = maxf(0.0, glitch - delta * 2.0)
	if level.manifest.is_empty() or not is_instance_valid(level.hotel): return
	if not level.net.is_client():
		for body in level.survivors():
			# In the refuge too: it is lit, and a lit room is where a mind
			# comes back. Frozen there, nobody recovered where it was safest.
			if int(level.session.participants.get(int(body.slot), 2)) in [level.session.Life.EXPLORING, level.session.Life.REFUGE]: wear(body, delta)
	if level.match_net.local_is_locust(): return
	if not level.local_alive():
		phantom_quiet(delta)
		return
	hallucinate(delta)
	phantom_quiet(delta)
	if level.player.sanity < SANITY_UNEASY and not is_instance_valid(sight): ensure_sight()

## One survivor's mind, one frame of it, on the authority.
func wear(body: Node3D, delta: float) -> void:
	var local: bool = body == level.player
	var mind: Dictionary = minds.get(int(body.slot), {"sanity": 100.0, "rest": 0.0, "paid": 0.0})
	var value: float = level.player.sanity if local else float(mind.sanity)
	var rest: float = sight_rest if local else float(mind.rest)
	var paid: float = sight_paid if local else float(mind.get("paid", 0.0))
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, body.global_position)
	var lit: bool = not level.hotel.dark and not room.is_empty() and not level.hotel.dark_ids.has(int(room.id))
	# The room plays without it: nothing wears a mind down, in the dark or at
	# the sight of the creature.
	var spent: bool = level.rule("sanity") == 1
	if not spent: value = 100.0
	elif body.hidden or not lit:
		var rate := SANITY_DARK
		if not body.hidden and body.torch.visible: rate *= SANITY_TORCH
		value = maxf(0.0, value - rate * delta)
	else: value = minf(100.0, value + SANITY_LIGHT * delta)
	# A long look at it is one fright, not one a frame; and a glimpse that
	# turns into its eyes on you is the bigger fright, charged once.
	rest = maxf(0.0, rest - delta)
	var sight := sight_of_creature(body, lit) if spent else 0
	if sight > 0:
		var cost: float = SANITY_STARE if sight == 2 else SANITY_GLIMPSE
		if rest <= 0.0:
			rest = SANITY_SIGHT_REST
			paid = cost
			value = maxf(0.0, value - cost)
		elif cost > paid:
			value = maxf(0.0, value - (cost - paid))
			paid = cost
	if body.burnt and value >= SANITY_BACK: body.set_burnt(false)
	elif not body.burnt and value <= 0.0: body.set_burnt(true)
	if local:
		level.player.sanity = value
		sight_rest = rest
		sight_paid = paid
	else: minds[int(body.slot)] = {"sanity": value, "rest": rest, "paid": paid}

## What the authority tells everybody: seat -> [meter, gone out].
func pack() -> Dictionary:
	var out := {}
	for body in level.survivors():
		var seat := int(body.slot)
		out[seat] = [level.player.sanity if body == level.player else float(minds.get(seat, {"sanity": 100.0}).sanity), bool(body.burnt)]
	return out

## And what a guest does with it: its own meter and mark, and everybody
## else's mark, which is what the hunter's reading shows.
func apply(told: Dictionary) -> void:
	for seat_key in told:
		var seat := int(seat_key)
		var row: Array = told[seat_key]
		if seat == int(level.player.slot):
			level.player.sanity = float(row[0])
			level.player.set_burnt(bool(row[1]))
		elif level.match_net.bodies.has(seat) and is_instance_valid(level.match_net.bodies[seat]):
			level.match_net.bodies[seat].set_burnt(bool(row[1]))

## The creature in plain view: in the picture, near enough to make out, lit by
## something, and nothing in between. In the pitch dark with the torch off
## there is nothing to see and nothing to be frightened by. Any survivor's
## body will do: a guest's puppet carries its camera, turned the way its owner
## is looking.
func sees_creature(body: Node3D, lit: bool) -> bool:
	return sight_of_creature(body, lit) > 0

## 0 not seen, 1 seen, 2 seen looking back: its gaze -- the head turned to
## whoever it watches (look_point, also on a guest's puppet, which is sent
## it), else the way its body faces -- points within STARE_CONE of this
## survivor's eyes. Seeing its back across a room is not meeting its eyes.
func sight_of_creature(body: Node3D, lit: bool) -> int:
	if not is_instance_valid(level.locust) or level.locust.grace > 0.0 or not is_instance_valid(body.camera): return 0
	var eye: Vector3 = body.camera.global_position
	var towards: Vector3 = level.locust.global_position + Vector3(0, 1.2, 0) - eye
	var gap := towards.length()
	if gap > SANITY_SEEN or gap < 0.01: return 0
	if not lit and not body.torch.visible and gap > 6.0: return 0
	if -body.camera.global_basis.z.dot(towards / gap) < 0.72: return 0
	var query := PhysicsRayQueryParameters3D.create(eye, eye + towards, 1 | 8 | 64)
	query.exclude = [body.get_rid()]
	if not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return 0
	var head: Vector3 = level.locust.global_position + Vector3(0, level.locust.EYE_HEIGHT, 0)
	var gaze: Vector3 = -level.locust.global_basis.z
	var visual = level.locust.visual
	if is_instance_valid(visual) and "look_point" in visual and visual.look_point != Vector3.INF: gaze = visual.look_point - head
	var to_eye := eye - head
	if gaze.length() < 0.01 or to_eye.length() < 0.01: return 1
	return 2 if gaze.normalized().dot(to_eye.normalized()) >= cos(deg_to_rad(STARE_CONE)) else 1

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
	# The creature walking past, the whole sound of it near.
	if not voice and randf() < lerpf(PASSAGE_SHARE.x, PASSAGE_SHARE.y, gone) and walk_past():
		last_lie = {"point": passage.path[0], "voice": false, "passage": true, "time": Time.get_ticks_msec() / 1000.0}
		return
	last_lie = {"point": point, "voice": voice, "time": Time.get_ticks_msec() / 1000.0}
	# A silent run (tests, captures) keeps the cadence: the lie counts as told.
	if not level.world_audio.enabled: return
	if voice: false_call(point)
	else: level.world_audio.play_at(level.world_audio.choose(["close_far", "open_far", "hide_leave", "open_slow"][randi() % 4]), point, -4.0)

func ensure_sight():
	if not is_instance_valid(sight):
		sight = SIGHT.new()
		add_child(sight)
		sight.setup(level)
	return sight

## Starts the creature that is not there walking past (phantom_passage).
func walk_past() -> bool:
	if not is_instance_valid(passage):
		passage = PASSAGE.new()
		add_child(passage)
		passage.setup(level)
	return passage.begin()

## Somewhere on the floor around, in a room and not inside a wall.
func hallucination_point(reach: float) -> Vector3:
	var angle := randf() * TAU
	var point: Vector3 = level.player.global_position + Vector3(sin(angle), 0, cos(angle)) * reach
	return FLOOR.closest(level.get_world_3d().navigation_map, point)

## Its voice, from where it is not. Its own throat is elsewhere: this one has
## a level.player of its own so the real call is never cut short by a made-up one.
## A call, never one of the short barks: those are the tell of a strike
## (hotel_locust.warn), and the floor lies about where it is, not about that.
## And heard the way a real one would be, round through a doorway: it used to
## come straight through the walls.
func false_call(point: Vector3) -> void:
	if not is_instance_valid(phantom):
		phantom = AudioStreamPlayer3D.new()
		phantom.name = "Phantom"
		phantom.bus = "Threat"
		phantom.stream = load(PHANTOM_CLIP)
		phantom.unit_size = 7.0
		phantom.max_distance = 40.0
		add_child(phantom)
	var calls: Array = []
	for segment in GRUNTS.SEGMENTS:
		if float(segment[1]) >= LOCUST.AGGRESSIVE_GRUNT: calls.append(segment)
	if calls.is_empty(): return
	var segment: Array = calls[randi() % calls.size()]
	var route: Dictionary = level.world_audio.route_source(point + Vector3(0, 1.6, 0))
	if not route.audible: return
	level.world_audio.apply_route(phantom, route, -4.0, "Threat")
	phantom.pitch_scale = randf_range(0.8, 0.95)
	phantom.play(segment[0])
	phantom_left = float(segment[1]) / phantom.pitch_scale

## A made-up call lasts as long as the piece of the recording it came from.
func phantom_quiet(delta: float) -> void:
	if not is_instance_valid(phantom) or not phantom.playing: return
	phantom_left -= delta
	if phantom_left <= 0.0: phantom.stop()

## Everybody whose mind has gone, wherever they are: what the pacing director
## plays on (never the creature's to know) and, in versus, the motes.
func burnt_survivors() -> Array:
	# Only the living it can reach: a corpse kept pulling it back to the body
	# for the rest of the stage, and one in the refuge or riding a car took
	# the place of anybody else it could have gone after.
	var marked: Array = []
	for body in level.survivors():
		if bool(body.get("burnt")) and level.survivor_active(body): marked.append(body.global_position)
	return marked
