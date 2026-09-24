extends CharacterBody3D
@export var sound_profile: Resource = preload("res://game/audio/profiles/locust.tres")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const THREAD := preload("res://game/enemies/locust/door_threading.gd")
enum Mode { PATROL, INVESTIGATE, CHASE, SEARCH, WINDUP, RECOVER, ALERT, WARDROBE, EXECUTE }
## Perception and pacing. Distances in metres, speeds in m/s.
## It perceives the player from much farther than the player can sense it:
## anything in its wide view with a clear line is noticed, however far.
const SIGHT_RANGE := 70.0
const SIGHT_HALF_ANGLE := 60.0
## Suspicion gained per second with the player in view, near and far.
const NOTICE_NEAR := 3.2
const NOTICE_FAR := 0.9
const NOTICE_DECAY := 0.12
## Suspicion at which it stops wandering and goes to look.
const SUSPICION := 0.2
## Player noises carry this many times their base radius, along walkable routes.
const NOISE_TABLE := preload("res://game/audio/noise_kinds.gd")
const HEARING_SCALE := NOISE_TABLE.HEARING_SCALE
## Closest to itself that a noise heard round a corner is ever placed.
const APPARENT_NEAREST := 3.5
## Lost sight for longer than this, the chase becomes a search.
const LOSE_AFTER := 7.0
## Faster than a sprinting player: breaking line of sight is the only escape.
const CHASE_SPEED := 6.4
## Speed while heading to the last place it saw or heard the player.
const TRACK_SPEED := 5.2
## Making for the lift the survivors took: a lope, not a chase. A whole
## planta is a couple of hundred metres of rooms and corridors to the car,
## which walking took it two minutes and more.
const LIFT_PACE := 4.0
## On first spotting the player it freezes, turns and shrieks before it runs:
## the moment the player hears it is the moment to break line of sight.
const ALERT_TIME := 1.2
## A chase starts from this speed and builds up at CHASE_ACCELERATION.
const CHASE_START_SPEED := 2.5
const CHASE_ACCELERATION := 3.2
const TORCH_NOTICE_RANGE := 45.0
## The cone it notices a torch in, whatever the beam is drawn as: the drawn
## beam is narrower on Compatibility (hotel_player.PLAIN_BEAM), and reading it
## made a torch harder to be seen by on some machines than on others.
const TORCH_NOTICE_ANGLE := 32.0
## Strike: starts within ATTACK_RANGE, lunges for WINDUP_TIME, kills within STRIKE_REACH.
const ATTACK_RANGE := 2.4
const STRIKE_REACH := 3.2
const WINDUP_TIME := 0.3
const RECOVER_TIME := 0.6
## Eye height of the creature for line-of-sight checks.
const EYE_HEIGHT := 2.4
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
## Grunts at least this long are the full, aggressive ones; shorter pieces of
## the recording are breaths and clicks, not used as calls.
const AGGRESSIVE_GRUNT := 1.4
## Searching a wardrobe is a ritual, not a swipe in passing: it plants itself
## in front, pulls one leaf open, then the other, reaches in and only then
## moves on. Seconds from the start (see level.open_wardrobe for the leaves).
const WARDROBE_TIME := {"right": 0.85, "left": 1.3, "reach": 1.7, "done": 2.5}
## An execution: it grabs you, holds you up while it brings its mask slowly to
## your face, and then buries its arm in it. Seconds from the grab, and when
## the killing blow lands (see hotel_main.apply_execution).
const EXECUTION_TIME := 4.2
const EXECUTION_KILL := 2.8
var level
var mode := Mode.PATROL
var destination := Vector3.ZERO
var last_known := Vector3.ZERO
var observed_hide: Node3D
## 0..1+ suspicion; 1 starts a chase.
var detection := 0.0
var lost_time := 0.0
var state_time := 0.0
var grace := 15.0
var repath := 0.0
var path := PackedVector3Array()
var path_index := 0
var rng := RandomNumberGenerator.new()
var signal_player: AudioStreamPlayer3D
var visual: Node3D
var patrol_room := 0
var footstep: AudioStreamPlayer3D
## Current ground speed; accelerates toward the speed each behaviour wants.
var speed := 0.0
## Making for the car of the lift the survivors took (lifts.aim_at_lift):
## until anything else sets its mode.
var lift_bound := false
var pause_time := 0.0
var light_exposure := 0.0
var wander_clock := 0.0
## Chase vocalisations: one grunt segment at a time from the creature.
var voice: AudioStreamPlayer3D
var grunt_clock := 0.0
var grunt_left := 0.0
## Seconds between chase grunts, and the short wait after one that nobody
## could hear: out of earshot it tries again soon, so it calls the moment it
## comes round the corner instead of staying mute for another five seconds.
const GRUNT_WAIT := Vector2(2.5, 5.0)
const GRUNT_RETRY := 0.7
## No two calls closer together than this, whatever asks for them: a hunter
## tapping the sprint key restarts the chase over and over, and without this
## the creature would gabble.
const GRUNT_MIN := 1.6
## The voice is shaped by what it is saying. A shriek is brutal close up and
## then stops: past what it buys the hunter (match_net.SHRIEK_RANGE, 26 m of
## listening) it should be no use as a bearing. A chase grunt is never that
## loud but carries further, because it is meant to be heard coming.
const VOICE_SHRIEK := {"unit": 5.5, "reach": 32.0, "level": 3.0}
const VOICE_GRUNT := {"unit": 7.0, "reach": 40.0, "level": 0.0}
## A chase grunt meant for the one who hears it. In the din of a creature
## running at you -- claws, breath, drone, chitter, heart -- a grunt at the
## level of any other call was one more layer. When it is after you it is
## louder, falls off less with distance (so it sounds close, not across the
## room), keeps its top end unless a wall is in the way, and everything else
## it brings steps back while it lasts (world_audio.duck_under), so it takes
## the scene. After you means: the AI chasing this machine's survivor, or --
## where somebody else runs the creature -- it being close with you in plain
## sight.
const AIMED_GAIN := 7.0
const AIMED_UNIT := 13.0
const AIMED_REACH := 24.0
const AIMED_CUTOFF := 12000.0
var grunt_rest := 0.0
## The last grunt was aimed at this machine's survivor.
var aimed := false
## Seconds left of the bark that announces a strike (it lives inside the same
## long recording, so it has to be stopped where it ends).
var warn_left := 0.0
## How long it can go without seeing its prey before finding it again is worth
## another grunt.
const GRUNT_REGAIN := 1.5
var sight_gap := 0.0
## The hunter's shriek: aggressive grunts chained back to back for as long as
## its red lasts, then faded out with it (howl()). Seconds left including the
## fade, how long that fade is, and the level the current grunt was routed at.
var howl_left := 0.0
var howl_fade := 1.0
var howl_db := 0.0
var last_grunt := -1
## A patrol route set by the pacing director: kept until it gets there.
var guided := false
## The survivor it is watching or hunting (see level.survivors()); several
## players can be on the floor, it only ever pursues one at a time.
var focus: Node3D
## Who decides what it does. "ai": its own behaviour (offline, or the host of a
## co-op match). "puppet": it follows the state sent by the machine in charge.
## "player": a player drives it (versus, see locust_player.gd).
var control := "ai"
## Versus: the controller that reads the local player's input, and its camera.
var driver: Node
var camera: Camera3D
## The wardrobe it is searching (Mode.WARDROBE).
var wardrobe: Node3D
## Puppet: received states {time, position, yaw, velocity} and a local clock.
var net_states: Array = []
var net_clock := 0.0
var net_look := Vector3.INF
## Calls replayed here from the machine in charge (tests check they arrive),
## the kind of the last one, and how many calls this machine has made itself.
var calls_heard := 0
var last_call := ""
var calls_made := 0

func _ready() -> void:
	add_to_group("hotel_actors")
	visual = $Visual
	signal_player = $Warning
	# The tell before a strike is its own voice, a short bark out of the same
	# recording: the synthesised sweep it used to be was a rising whoosh that
	# belonged to no animal.
	signal_player.stream = load("res://assets/audio/sfx/chase/grunts.ogg")
	footstep = $Footsteps
	footstep.stream = claw_sound()
	if visual.has_signal("footfall"): visual.footfall.connect(on_footfall)
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.bus = "Threat"
	voice.stream = load("res://assets/audio/sfx/chase/grunts.ogg")
	voice.unit_size = 7.0
	voice.max_distance = 40.0
	voice.max_db = 4.0
	voice.area_mask = 512
	# Hung where the route leaves it, like world_audio's presence: as a child of
	# the creature it dragged the call along for the rest of the segment, so a
	# grunt heard through a doorway walked away from that doorway.
	if level != null and is_instance_valid(level.world_audio): level.world_audio.add_child(voice)
	else: add_child(voice)
	if level == null:
		set_physics_process(false)
		return
	rng.seed = level.manifest.seed + 71013
	destination = position
	wander_clock = rng.randf() * 100.0

## Its voice hangs under world_audio, which outlives the floor: it has to go
## when the creature does, or the next floor starts with a mute leftover.
func _exit_tree() -> void:
	if is_instance_valid(voice) and voice.get_parent() != self: voice.queue_free()

## The short pieces of the recording, the ones too short to be calls: barks and
## breaths. One of them is the tell that a strike is coming.
func warn() -> void:
	var choices: Array = []
	for index in GRUNTS.SEGMENTS.size():
		if GRUNTS.SEGMENTS[index][1] < AGGRESSIVE_GRUNT: choices.append(index)
	if choices.is_empty() or signal_player.stream == null: return
	var segment: Array = GRUNTS.SEGMENTS[choices[rng.randi_range(0, choices.size() - 1)]]
	signal_player.pitch_scale = rng.randf_range(0.78, 0.9)
	# Routed like its grunts and its feet: behind a wall the bark comes round
	# through the doorway, or does not come at all. It used to go straight
	# through walls, the only one of its sounds that did.
	if level != null and level.world_audio.enabled:
		var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
		if route.audible: level.world_audio.apply_route(signal_player, route, 0.0, "Threat", true)
		else: signal_player.volume_db = -80.0
	signal_player.play(segment[0])
	warn_left = segment[1] / signal_player.pitch_scale

## A pointed leg striking the floor: a hard tick over a hollow knock.
static func claw_sound() -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var count := 5512
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 4401
	for i in count:
		var t := float(i) / 22050.0
		var tick := sin(TAU * 3100.0 * t) * exp(-t * 320.0) + (noise.randf() - 0.5) * exp(-t * 500.0) * 0.8
		var knock := sin(TAU * 118.0 * t) * exp(-t * 34.0) * minf(1.0, t * 900.0)
		bytes.encode_s16(i * 2, int(clampf(tick * 0.7 + knock * 0.8, -1.0, 1.0) * 30000.0))
	audio.data = bytes
	return audio

## Each pointed foot strikes the floor where the animation plants it.
func on_footfall(point: Vector3, strength: float) -> void:
	if level == null or level.session.state != level.session.State.PLAYING or not level.world_audio.enabled: return
	# Heard directly, or from the doorway it would come through; never through walls.
	var route: Dictionary = level.world_audio.route_source(point + Vector3.UP * 0.2, get_rid())
	if not route.audible: return
	# Its own feet, right under the hunter's ear, would wear it out: quieter still.
	var level_db := lerpf(-9.0, -1.0, strength) - (6.0 if control == "player" else 0.0)
	level.world_audio.apply_route(footstep, route, level_db + level.world_audio.duck_db(), "Threat", true)
	footstep.pitch_scale = rng.randf_range(0.82, 1.08)
	footstep.play()

## Plays one aggressive grunt from the recording, never the same one twice in
## a row, routed like every other creature sound. Returns how long it lasts.
func grunt() -> float:
	if level == null: return 0.0
	var choices: Array = []
	for index in GRUNTS.SEGMENTS.size():
		if GRUNTS.SEGMENTS[index][1] >= AGGRESSIVE_GRUNT and index != last_grunt: choices.append(index)
	last_grunt = choices[rng.randi_range(0, choices.size() - 1)]
	calls_made += 1
	var segment: Array = GRUNTS.SEGMENTS[last_grunt]
	var pitch := rng.randf_range(0.85, 1.0)
	# Everyone else hears the same call from their own place.
	if "match_net" in level and level.match_net != null: level.match_net.creature_call("grunt", last_grunt, pitch)
	aimed = aimed_at_local()
	# Silent runs (tests, captures) keep the cadence: the call counts as made.
	if not level.world_audio.enabled: return segment[1] / pitch
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return 0.0
	# Its own throat, right under the hunter's ear, would wear it out: quieter
	# for whoever is carrying the creature, like its feet.
	level.world_audio.apply_route(voice, route, shape_voice(false) - (6.0 if control == "player" else 0.0), "Threat", true)
	voice.pitch_scale = pitch
	voice.play(segment[0])
	# A lower pitch plays the segment slower: stop when it really ends.
	grunt_left = segment[1] / voice.pitch_scale
	aim_voice(route, grunt_left)
	return grunt_left

## Whether this machine's survivor is the one being called at.
func aimed_at_local() -> bool:
	if level == null or control == "player" or level.match_net.local_is_locust() or not level.local_alive(): return false
	var me: Node3D = level.player
	if control == "ai": return mode == Mode.CHASE and focus == me
	return global_position.distance_to(me.global_position) < AIMED_REACH and clear_sight(me.camera.global_position)

## The grunt that has just been routed, made the one that is about you.
func aim_voice(route: Dictionary, seconds: float) -> void:
	aimed = aimed_at_local()
	if not aimed: return
	voice.unit_size = AIMED_UNIT
	voice.volume_db += AIMED_GAIN
	if not route.get("echo", false): voice.attenuation_filter_cutoff_hz = maxf(voice.attenuation_filter_cutoff_hz, AIMED_CUTOFF)
	level.world_audio.duck_under(seconds)

## How far the voice carries and how loud it starts, by what it is saying.
## Returns the level to route it at.
func shape_voice(shriek: bool) -> float:
	var shape: Dictionary = VOICE_SHRIEK if shriek else VOICE_GRUNT
	voice.unit_size = shape.unit
	voice.max_distance = shape.reach
	return shape.level

## The chase has a voice, whether the AI or a player is driving: a grunt every
## few seconds while it is after someone. A shriek takes over the throat, and
## a call nobody could hear is retried soon instead of spending the whole wait.
func chase_voice(delta: float) -> void:
	if howl_left > 0.0 or grunt_left > 0.0 or grunt_rest > 0.0: return
	grunt_clock -= delta
	if grunt_clock > 0.0: return
	grunt_rest = GRUNT_MIN
	grunt_clock = rng.randf_range(GRUNT_WAIT.x, GRUNT_WAIT.y) if grunt() > 0.0 else GRUNT_RETRY

## The shriek of a player hunting: it cries for `hold` seconds and fades over
## `fade`, the same curve as the red of its acoustic view, one grunt after
## another. A second howl while one lasts would stretch it; the hunter's own
## cooldown (locust_player.SHRIEK_COOLDOWN, longer than the cry) keeps that
## from happening. `tell` sends it to the other machines, which replay it at
## their own place.
func howl(hold: float, fade: float, tell := true) -> void:
	howl_fade = maxf(fade, 0.05)
	howl_left = maxf(howl_left, hold + howl_fade)
	if tell and "match_net" in level and level.match_net != null: level.match_net.creature_call("howl", int(round(hold * 100.0)), howl_fade)
	howl_next()

## The next grunt of the chain, never the one just heard.
func howl_next() -> void:
	var choices: Array = []
	for index in GRUNTS.SEGMENTS.size():
		if GRUNTS.SEGMENTS[index][1] >= AGGRESSIVE_GRUNT and index != last_grunt: choices.append(index)
	last_grunt = choices[rng.randi_range(0, choices.size() - 1)]
	var segment: Array = GRUNTS.SEGMENTS[last_grunt]
	var pitch := rng.randf_range(0.85, 1.0)
	# Out of earshot it still keeps time, so the chain stays in step.
	grunt_left = segment[1] / pitch
	if level == null or not level.world_audio.enabled: return
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return
	level.world_audio.apply_route(voice, route, shape_voice(true), "Threat", true)
	howl_db = voice.volume_db
	voice.pitch_scale = pitch
	voice.play(segment[0])
	update_voice(0.0)

## Stops each grunt where it ends (the file holds them all in a row), chains
## the next one while a shriek lasts, and fades the shriek out at its end.
func update_voice(delta: float) -> void:
	grunt_rest = maxf(0.0, grunt_rest - delta)
	if warn_left > 0.0:
		warn_left -= delta
		if warn_left <= 0.0: signal_player.stop()
	if howl_left > 0.0:
		howl_left -= delta
		if howl_left <= 0.0:
			howl_left = 0.0
			grunt_left = 0.0
			voice.stop()
			return
		voice.volume_db = howl_db + linear_to_db(maxf(clampf(howl_left / howl_fade, 0.0, 1.0), 0.001))
	if grunt_left > 0.0:
		grunt_left -= delta
		if grunt_left <= 0.0:
			if howl_left > 0.2: howl_next()
			else: voice.stop()

func clear_sight(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, EYE_HEIGHT, 0), point, 1 | 8 | 64)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Whether it can see this survivor right now.
func sees(player: Node3D, ignore_concealment := false) -> bool:
	if not is_instance_valid(player) or not level.survivor_active(player): return false
	var offset: Vector3 = player.global_position - global_position
	if offset.length() > SIGHT_RANGE: return false
	# It knows which wardrobe the player went into, doors shut or not.
	if player.hidden and not ignore_concealment and observed_hide == player.hiding_place: return true
	var facing := -global_basis.z
	if offset.length() > 1.5 and facing.dot(offset.normalized()) < cos(deg_to_rad(SIGHT_HALF_ANGLE)): return false
	if not clear_sight(player.camera.global_position): return false
	# Shut doors block the line above; peeking through a gap is visible.
	if player.hidden and not ignore_concealment: return player.hiding_place.ajar()
	return true

## The survivor it would react to: the one it already follows if still in
## view, otherwise the nearest one it can see. Null when nobody is in view.
func seen_survivor(ignore_concealment := false) -> Node3D:
	if sees(focus, ignore_concealment): return focus
	var best: Node3D = null
	var best_distance := INF
	for player in level.survivors():
		if not sees(player, ignore_concealment): continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best

func sees_player(ignore_concealment := false) -> bool:
	return seen_survivor(ignore_concealment) != null

## Survivor to aim an attack at: the one it hunts, else the nearest one.
func target() -> Node3D:
	if is_instance_valid(focus) and level.survivor_active(focus): return focus
	var best: Node3D = null
	var best_distance := INF
	for player in level.survivors():
		if not level.survivor_active(player): continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best

## How quickly a visible player is noticed: close, lit and running players
## stand out; crouching and distance buy time to break line of sight.
func notice_rate(player: Node3D) -> float:
	var distance: float = player.global_position.distance_to(global_position)
	var rate := lerpf(NOTICE_NEAR, NOTICE_FAR, clampf((distance - 4.0) / (SIGHT_RANGE - 4.0), 0.0, 1.0))
	if player.crouched: rate *= 0.55
	if Vector2(player.velocity.x, player.velocity.z).length() > 4.6: rate *= 1.35
	if player.torch.visible: rate *= 1.4
	return rate

## The survivor whose torch beam falls on the creature from afar, if any.
func lit_by_torch() -> Node3D:
	for player in level.survivors():
		if not level.survivor_active(player): continue
		var torch: SpotLight3D = player.torch
		if not torch.visible or player.hidden: continue
		var chest := global_position + Vector3(0, 1.6, 0)
		var offset := chest - torch.global_position
		if offset.length() > TORCH_NOTICE_RANGE or offset.length() < 5.0: continue
		if (-torch.global_basis.z).angle_to(offset) > deg_to_rad(TORCH_NOTICE_ANGLE * 0.85): continue
		var ray := PhysicsRayQueryParameters3D.create(torch.global_position, chest, 1 | 8 | 64)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return player
	return null

## Whether a noise reaches it: within its (long) hearing, along a walkable
## route through rooms and doorways, never through walls.
func can_hear(point: Vector3, radius: float) -> bool:
	return hear_route(point, radius).audible

## How a noise reaches it. With nothing solid in between it comes straight from
## the source. Otherwise it follows the walkable route and arrives through the
## last opening the creature can see, quieter and duller for the detour. This
## is the one measurement of its hearing: can_hear() is this, and the player who
## drives it paints its acoustic image from the same numbers.
##  audible   - it reaches the creature at all
##  apparent  - where it is heard from: the source, or the opening it came in by
##  distance  - straight line when direct, metres of route when it came around
##  muffle    - 0 direct, towards 1 as the detour grows
func hear_route(point: Vector3, radius: float) -> Dictionary:
	var missed := {"audible": false, "apparent": point, "distance": INF, "muffle": 1.0}
	if level.point_in_refuge(point): return missed
	var reach := radius * HEARING_SCALE
	var straight := global_position.distance_to(point)
	if straight > reach: return missed
	if clear_sight(point + Vector3(0, 1, 0)):
		return {"audible": true, "apparent": point, "distance": straight, "muffle": 0.0}
	var route := FLOOR.navigation_path(get_world_3d().navigation_map, position, point)
	if route.size() < 2: return missed
	# A route that stops short of the noise does not carry it: the mesh gives
	# the way to the nearest point it can reach, and from a scrap of floor cut
	# off from the rest that was where it stood, a noise five metres away
	# heard as if at its feet.
	var end := route[route.size() - 1]
	var near := FLOOR.floor_point(point)
	if Vector2(end.x - near.x, end.z - near.z).length() > 1.5: return missed
	var length := 0.0
	for i in range(1, route.size()): length += route[i].distance_to(route[i - 1])
	if length > reach: return missed
	# Walk the route outwards and keep the last waypoint still in plain sight:
	# that doorway or corner is the direction the sound arrives from.
	var apparent: Vector3 = route[0] + Vector3.UP * 1.5
	for i in range(1, route.size()):
		var probe: Vector3 = route[i] + Vector3.UP * 1.5
		if not clear_sight(probe): break
		apparent = probe
	# Nothing along the route in sight, not even the first turn: the opening
	# it arrives through is right here, and a contact placed on its own head
	# would swallow the camera. Put it a few metres off, the way it comes.
	var start: Vector3 = route[0] + Vector3.UP * 1.5
	if apparent.distance_to(start) < APPARENT_NEAREST:
		var way: Vector3 = route[1] - route[0]
		way.y = 0.0
		if way.length() > 0.01: apparent = start + way.normalized() * APPARENT_NEAREST
	var detour := maxf(0.0, length - global_position.distance_to(apparent))
	return {"audible": true, "apparent": apparent, "distance": length, "muffle": clampf(detour / 25.0, 0.0, 1.0)}

## How far from where it last knew its quarry to be a noise can be and still
## be taken for that quarry, mid-chase.
const CHASE_EARSHOT := 9.0
func hear(point: Vector3, radius: float) -> void:
	if control != "ai": return
	# Holding a victim or pulling a wardrobe open, it finishes what it is doing:
	# a noise used to send it off mid-kill with the victim dragged behind it.
	if grace > 0 or mode in [Mode.WINDUP, Mode.RECOVER, Mode.EXECUTE, Mode.WARDROBE]: return
	if not can_hear(point, radius): return
	if mode == Mode.CHASE:
		# While hunting, a noise near the one it is after tells it where they
		# went. Any noise at all used to: two survivors walking about kept a
		# chase alive for ever, bounced between them, after nobody.
		if point.distance_to(last_known) <= CHASE_EARSHOT:
			last_known = point
			lost_time = minf(lost_time, 1.0)
		return
	if mode == Mode.ALERT:
		# Already turning to hunt: the noise only says where. Sending it to
		# investigate restarted the alert, so a survivor who kept walking in
		# sight was never chased -- every step put it back to square one.
		last_known = point
		return
	last_known = point
	set_mode(Mode.INVESTIGATE)
	destination = point

## Walks its patrol to a given room and only then resumes wandering.
func guide(room_id: int) -> void:
	if mode != Mode.PATROL or control != "ai": return
	patrol_room = room_id
	destination = FLOOR.position_of(level.manifest.rooms[room_id])
	guided = true
	pause_time = 0.0
	state_time = 0.0
	repath = 0.0

## A mind that has gone out. The motes it gives off reach the creature from
## anywhere on the floor and through anything, so this is not hearing and does
## not care about walls or distance: it is told where, and it goes. It will
## not walk into a refuge for it, and it does not drop somebody it is already
## chasing -- it only learns where that one is.
func smell_burnt(point: Vector3) -> void:
	if control != "ai" or grace > 0: return
	if mode in [Mode.WINDUP, Mode.RECOVER, Mode.EXECUTE, Mode.WARDROBE]: return
	if level.point_in_refuge(point): return
	last_known = point
	if mode == Mode.CHASE:
		lost_time = minf(lost_time, 1.0)
		return
	if mode == Mode.ALERT: return
	# Re-aimed as the body moves, without starting the behaviour over.
	if mode != Mode.INVESTIGATE: set_mode(Mode.INVESTIGATE)
	destination = point
	guided = false

## Put somewhere else at once, having forgotten everybody, with `rest` seconds
## before it moves again. A stage given back after the team fell raises
## everybody at the stage's door, and it used to be left wherever it had last
## killed -- a metre from them, and the stage was lost again in two seconds.
func relocate(point: Vector3, rest: float) -> void:
	global_position = point
	velocity = Vector3.ZERO
	speed = 0.0
	path = PackedVector3Array()
	path_index = 0
	wardrobe = null
	focus = null
	detection = 0.0
	light_exposure = 0.0
	last_known = point
	var here := FLOOR.room_at(level.manifest.rooms, point)
	if not here.is_empty(): patrol_room = int(here.id)
	set_mode(Mode.PATROL)
	destination = point
	grace = maxf(grace, rest)

## A sound it did not have to hear through the player: something fell, it goes
## to look. Ignored while it is already hunting.
func investigate(point: Vector3) -> void:
	if control != "ai": return
	if mode in [Mode.CHASE, Mode.ALERT, Mode.WINDUP, Mode.RECOVER, Mode.EXECUTE, Mode.WARDROBE]: return
	last_known = point
	set_mode(Mode.INVESTIGATE)
	destination = point

func set_mode(next: Mode) -> void:
	var previous := mode
	mode = next
	state_time = 0
	guided = false
	lift_bound = false
	repath = 0
	pause_time = 0
	# Back on its rounds it has forgotten the wardrobe it was looking at: kept,
	# whoever hid there later was "seen" through the walls from across the floor.
	if next == Mode.PATROL: observed_hide = null
	if next == Mode.CHASE and previous != Mode.CHASE:
		# It sets off from a stride and builds up to full speed.
		speed = maxf(speed, CHASE_START_SPEED)
		# Coming out of the alert, the next call waits for the first to finish.
		grunt_clock = grunt_left + rng.randf_range(0.8, 1.8) if previous == Mode.ALERT else 0.0
	# Spotting the player: an aggressive grunt as it turns to hunt.
	if next == Mode.ALERT: grunt()
	if next == Mode.WINDUP:
		warn()
		if "match_net" in level and level.match_net != null: level.match_net.creature_call("warning", 0, 1.0)

func choose_patrol() -> void:
	# Never through a gate it cannot open, and never into the refuge that is
	# protecting the survivors this stage: it would stand at a door and wait.
	var wing: int = int(level.manifest.rooms[patrol_room].get("wing", 0))
	var refuge: int = level.refuge_room()
	# Nor into a lift lobby: its only door is the refuge's, and it would be
	# shut in there with no way on.
	var lobbies: Array = level.manifest.get("gates", []).map(func(gate): return int(gate.get("beyond", -1)))
	var choices: Array = level.manifest.adjacency[patrol_room].filter(func(id): return id != refuge and not lobbies.has(int(id)) and int(level.manifest.rooms[id].get("wing", 0)) == wing)
	if choices.is_empty(): return
	patrol_room = choices[rng.randi_range(0, choices.size() - 1)]
	destination = FLOOR.position_of(level.manifest.rooms[patrol_room])
	repath = 0

func can_attack(reach := ATTACK_RANGE) -> bool:
	var player := target()
	if player == null or global_position.distance_to(player.global_position) >= reach: return false
	if not clear_sight(player.camera.global_position): return false
	return not player.hidden or observed_hide == player.hiding_place or sees(player)

## A wardrobe it has reason to search: occupied and near where the noise was.
func suspect_hide(point: Vector3) -> Node3D:
	for hide in get_tree().get_nodes_in_group("hotel_hides"):
		if is_instance_valid(hide.occupant) and hide.global_position.distance_to(point) < 2.5: return hide
	return null

## Ground speed each behaviour aims for; patrol drifts between slow and brisk.
func desired_speed() -> float:
	match mode:
		Mode.PATROL:
			return 0.0 if pause_time > 0 else 1.9 + sin(wander_clock * 0.37) * 0.5 + sin(wander_clock * 1.13) * 0.2
		Mode.INVESTIGATE:
			# Cautious when close to what it heard; loping to a lift.
			return lerpf(1.2, LIFT_PACE if lift_bound else 2.9, clampf((position.distance_to(destination) - 1.5) / 5.0, 0.0, 1.0))
		Mode.CHASE:
			return CHASE_SPEED if lost_time < 0.4 else TRACK_SPEED
		Mode.SEARCH:
			return 0.0 if pause_time > 0 else 1.5
	return 0.0

func set_control(kind: String) -> void:
	control = kind
	net_states.clear()
	if kind == "player" and driver == null:
		driver = preload("res://game/enemies/locust/locust_player.gd").new()
		add_child(driver)
		driver.setup(self)
	# Only the player who drives it sees through its ears.
	if driver != null and is_instance_valid(driver.echo):
		if kind == "player": driver.echo.enable()
		else: driver.echo.disable()

## What the machine in charge sends about fifteen times a second.
func pack_state() -> Array:
	return [global_position, rotation.y, velocity, mode, grace, visual.look_point if is_instance_valid(visual) and "look_point" in visual else Vector3.INF]

## Carried by a lift on this machine: the hunter's own machine still sends
## where it stood by the old car for a moment, and those states would pull it
## back there and slide it across the floor (see remote_player.ride_to).
var ride_hold := 0.0
var ride_point := Vector3.ZERO
func push_state(data: Array) -> void:
	if data.size() < 6: return
	if ride_hold > 0.0:
		if (data[0] as Vector3).distance_to(ride_point) > 3.0: return
		ride_hold = 0.0
	net_states.append({"time": net_clock, "position": data[0], "yaw": data[1], "velocity": data[2]})
	while net_states.size() > 10: net_states.pop_front()
	var next: int = data[3]
	if next != mode:
		mode = next
		state_time = 0.0
	grace = data[4]
	net_look = data[5]

## Puppet: smoothed onto the received states, animated like the real thing.
func follow_state(delta: float) -> void:
	net_clock += delta
	ride_hold = maxf(0.0, ride_hold - delta)
	state_time += delta
	if net_states.is_empty():
		update_visual(delta)
		return
	var wanted := net_clock - 0.1
	var before: Dictionary = net_states[0]
	var after: Dictionary = net_states[net_states.size() - 1]
	for i in range(net_states.size() - 1):
		if net_states[i].time <= wanted and net_states[i + 1].time >= wanted:
			before = net_states[i]
			after = net_states[i + 1]
			break
	var t := clampf((wanted - before.time) / maxf(after.time - before.time, 0.001), 0.0, 1.0)
	global_position = before.position.lerp(after.position, t)
	rotation.y = lerp_angle(before.yaw, after.yaw, t)
	velocity = before.velocity.lerp(after.velocity, t)
	update_voice(delta)
	update_visual(delta)

## Plants itself in front of a wardrobe and searches it, which takes a while.
func begin_wardrobe(hide: Node3D) -> void:
	if not is_instance_valid(hide) or mode in [Mode.WARDROBE, Mode.EXECUTE]: return
	wardrobe = hide
	set_mode(Mode.WARDROBE)
	speed = 0.0
	if control == "ai": level.open_wardrobe(hide)

## Standing still while the ritual plays out; the leaves and whoever is inside
## are handled by the host (level.open_wardrobe).
func update_wardrobe(delta: float) -> void:
	speed = 0.0
	velocity = Vector3(0, -2.0, 0)
	move_and_slide()
	if is_instance_valid(wardrobe): face_toward(wardrobe.global_position, delta, 7.0)
	if state_time >= WARDROBE_TIME.done and control != "puppet":
		wardrobe = null
		set_mode(Mode.SEARCH if control == "ai" else Mode.PATROL)

## Holding a victim up and stabbing: it cannot move or turn away.
func begin_execution() -> void:
	set_mode(Mode.EXECUTE)
	speed = 0.0

func update_execution(delta: float) -> void:
	speed = 0.0
	velocity = Vector3(0, -2.0, 0)
	move_and_slide()
	# Once the level has let the body fall and counted the death (it holds the
	# victim 0.3 s past EXECUTION_TIME): let go earlier, it saw its still
	# living victim and roared at the corpse.
	if state_time >= EXECUTION_TIME + 0.35 and control != "puppet":
		set_mode(Mode.SEARCH if control == "ai" else Mode.PATROL)

## A call decided where the creature is controlled, replayed here.
func play_call(kind: String, segment: int, pitch: float) -> void:
	calls_heard += 1
	last_call = kind
	if kind == "warning":
		warn()
		return
	if kind == "howl":
		howl(segment / 100.0, pitch, false)
		return
	if kind != "grunt" or segment < 0 or segment >= GRUNTS.SEGMENTS.size() or not level.world_audio.enabled: return
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return
	level.world_audio.apply_route(voice, route, shape_voice(false), "Threat", true)
	voice.pitch_scale = pitch
	voice.play(GRUNTS.SEGMENTS[segment][0])
	grunt_left = GRUNTS.SEGMENTS[segment][1] / pitch
	aim_voice(route, grunt_left)

func _physics_process(delta: float) -> void:
	# Between stages, and on an online end screen, the voice still counts
	# down: left alone, a grunt ran on through the rest of its recording.
	if level.session.state != level.session.State.PLAYING:
		update_voice(delta)
		return
	if control == "puppet":
		follow_state(delta)
		return
	if control == "player":
		if is_instance_valid(driver): driver.drive(delta)
		update_voice(delta)
		return
	grace = maxf(0, grace - delta)
	state_time += delta
	wander_clock += delta
	if grace > 0:
		update_visual(delta)
		return
	var seen := seen_survivor()
	var visible_player := seen != null
	if visible_player:
		focus = seen
		detection = minf(1.5, detection + delta * notice_rate(seen))
		last_known = seen.global_position
		lost_time = 0
		# Finding them again after losing them is worth its own call.
		if mode == Mode.CHASE and sight_gap >= GRUNT_REGAIN: grunt_clock = 0.0
		sight_gap = 0.0
	else:
		detection = maxf(0.0, detection - delta * NOTICE_DECAY)
		lost_time += delta
		sight_gap += delta
	# Only a player it can currently see starts a chase; memory alone does not.
	# Busy modes are left out on purpose: holding a victim or pulling a
	# wardrobe open, it used to re-alert on the very next frame -- it can see
	# the person it is already killing -- and walk out of its own execution.
	if visible_player and detection >= 1.0 and mode not in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER, Mode.ALERT, Mode.EXECUTE, Mode.WARDROBE]:
		set_mode(Mode.ALERT)
	elif visible_player and detection >= SUSPICION and mode in [Mode.PATROL, Mode.SEARCH]:
		# Something moved: stop wandering and go look, before committing.
		set_mode(Mode.INVESTIGATE)
		destination = last_known
	# A torch beam seen from afar gives away where the player is standing.
	var lit_by := lit_by_torch()
	light_exposure = light_exposure + delta if lit_by != null else maxf(0.0, light_exposure - delta * 0.5)
	if light_exposure > 0.35 and mode in [Mode.PATROL, Mode.SEARCH, Mode.INVESTIGATE] and lit_by != null:
		focus = lit_by
		last_known = lit_by.global_position
		if mode != Mode.INVESTIGATE or destination.distance_to(last_known) > 2.0:
			set_mode(Mode.INVESTIGATE)
			destination = last_known
		detection = maxf(detection, 0.3)
	pause_time = maxf(0.0, pause_time - delta)
	match mode:
		Mode.PATROL:
			if pause_time <= 0 and (position.distance_to(destination) < 0.6 or (state_time > 14 and not guided)):
				guided = false
				# Stops now and then to listen before moving on.
				if rng.randf() < 0.45: pause_time = rng.randf_range(1.0, 3.0)
				choose_patrol()
				state_time = 0
		Mode.INVESTIGATE:
			if position.distance_to(destination) < 0.7 or state_time > 12:
				# Someone hiding right where the noise came from is found.
				var suspect := suspect_hide(destination)
				if suspect != null:
					observed_hide = suspect
					last_known = suspect.global_position
					lost_time = 0.0
					set_mode(Mode.CHASE)
				else:
					set_mode(Mode.SEARCH)
					pause_time = rng.randf_range(0.6, 1.4)
		Mode.CHASE:
			destination = last_known
			var player := focus
			# Reaching where it last saw or heard the player, it checks the wardrobes there.
			if lost_time > 0.5 and observed_hide == null and global_position.distance_to(last_known) < 2.5:
				observed_hide = suspect_hide(last_known)
			if is_instance_valid(player) and player.hidden and observed_hide == player.hiding_place:
				# Goes to the wardrobe and pulls the doors open.
				destination = observed_hide.to_global(observed_hide.exit_offset)
				if global_position.distance_to(destination) < 2.0: begin_wardrobe(observed_hide)
			chase_voice(delta)
			if not is_instance_valid(player) or not level.survivor_active(player) or lost_time > LOSE_AFTER: set_mode(Mode.SEARCH)
			elif can_attack(): set_mode(Mode.WINDUP)
		Mode.SEARCH:
			if state_time > 10:
				observed_hide = null
				patrol_room = nearest_room()
				set_mode(Mode.PATROL)
				choose_patrol()
			elif pause_time <= 0 and position.distance_to(destination) < 0.7:
				var angle := rng.randf() * TAU
				destination = FLOOR.closest(get_world_3d().navigation_map, last_known + Vector3(cos(angle), 0, sin(angle)) * 3.5)
				pause_time = rng.randf_range(0.4, 1.6)
				repath = 0
		Mode.WINDUP:
			if state_time >= WINDUP_TIME:
				# A hit starts an execution (which takes over the body).
				if can_attack(STRIKE_REACH): level.capture_survivor(target())
				if mode == Mode.WINDUP: set_mode(Mode.RECOVER)
		Mode.RECOVER:
			if state_time >= RECOVER_TIME: set_mode(Mode.CHASE if visible_player else Mode.SEARCH)
		Mode.ALERT:
			# Even if the player ducks out of view it heads for where it saw them.
			if state_time >= ALERT_TIME: set_mode(Mode.CHASE)
	update_voice(delta)
	if mode == Mode.WARDROBE:
		update_wardrobe(delta)
	elif mode == Mode.EXECUTE:
		update_execution(delta)
	elif mode == Mode.WINDUP:
		lunge(delta)
	elif mode == Mode.ALERT:
		speed = move_toward(speed, 0.0, 12.0 * delta)
		velocity = Vector3(-global_basis.z.x * speed, -2.0, -global_basis.z.z * speed)
		move_and_slide()
		face_toward(last_known, delta, 5.0)
	elif mode == Mode.RECOVER:
		velocity = Vector3.ZERO
		speed = 0.0
		if is_instance_valid(focus): face_toward(focus.global_position, delta, 6.0)
	else:
		move_on_path(delta)
	update_visual(delta)

## During the wind-up it keeps closing in on the player, blades raised.
func lunge(delta: float) -> void:
	var player := target()
	if player == null:
		velocity = Vector3.ZERO
		return
	var offset: Vector3 = player.global_position - global_position
	offset.y = 0.0
	face_toward(player.global_position, delta, 12.0)
	if offset.length() < 0.9: velocity = Vector3.ZERO
	else:
		var heading := offset.normalized() * CHASE_SPEED * 1.15
		velocity = Vector3(heading.x, -2.0, heading.z)
	move_and_slide()

func face_toward(point: Vector3, delta: float, rate: float) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length() < 0.05: return
	rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), minf(1.0, delta * rate))

func update_visual(delta: float) -> void:
	if not is_instance_valid(visual) or not "move_velocity" in visual: return
	if control == "puppet":
		visual.move_velocity = velocity
		visual.execute = clampf(state_time / EXECUTION_TIME, 0.0, 1.0) if mode == Mode.EXECUTE else 0.0
		visual.searching = clampf(state_time / WARDROBE_TIME.done, 0.0, 1.0) if mode == Mode.WARDROBE else 0.0
		visual.aggression = move_toward(visual.aggression, 1.0 if mode in [Mode.CHASE, Mode.ALERT, Mode.EXECUTE] else 0.0, delta * 2.5)
		visual.attack = clampf(state_time / WINDUP_TIME, 0.0, 1.0) if mode == Mode.WINDUP else move_toward(visual.attack, 0.0, delta * 8.0)
		visual.recovering = 1.0 if mode == Mode.RECOVER and state_time < 0.5 else move_toward(visual.recovering, 0.0, delta * 2.0)
		visual.duck = move_toward(visual.duck, 1.0 if near_doorway() else 0.0, delta * 3.0)
		visual.look_point = net_look
		return
	visual.move_velocity = velocity
	visual.execute = clampf(state_time / EXECUTION_TIME, 0.0, 1.0) if mode == Mode.EXECUTE else 0.0
	visual.searching = clampf(state_time / WARDROBE_TIME.done, 0.0, 1.0) if mode == Mode.WARDROBE else 0.0
	visual.aggression = move_toward(visual.aggression, 1.0 if mode in [Mode.CHASE, Mode.ALERT, Mode.EXECUTE] else 0.0, delta * 2.5)
	visual.attack = clampf(state_time / WINDUP_TIME, 0.0, 1.0) if mode == Mode.WINDUP else move_toward(visual.attack, 0.0, delta * 8.0)
	# Stoops under door lintels; it is taller than the doorways.
	visual.duck = move_toward(visual.duck, 1.0 if near_doorway() else 0.0, delta * 3.0)
	visual.recovering = 1.0 if mode == Mode.RECOVER and state_time < 0.5 else move_toward(visual.recovering, 0.0, delta * 2.0)
	var player := focus
	# During an execution it stares at the face it is bringing in to its own.
	if (mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER, Mode.ALERT, Mode.EXECUTE] or detection > 0.2 or light_exposure > 0.2) and is_instance_valid(player):
		visual.look_point = player.camera.global_position if lost_time < 0.5 else last_known + Vector3.UP * 1.5
	elif mode in [Mode.SEARCH, Mode.PATROL] and pause_time > 0:
		# Scans the room while standing still.
		visual.look_point = global_position - global_basis.z * 4.0 + global_basis.x * sin(wander_clock * 0.9) * 4.0 + Vector3.UP * 1.6
	else:
		visual.look_point = Vector3.INF

func near_doorway() -> bool:
	for door in level.hotel.doors:
		if door.doorway.distance_to(global_position) < 2.6: return true
	return false

func nearest_room() -> int:
	# The room it stands in, when it stands in one; otherwise the nearest on its
	# own planta. By distance alone the room under its feet on the planta below
	# could be nearer than the middle of a big room it is in.
	var here: Dictionary = FLOOR.room_at(level.manifest.rooms, global_position)
	if not here.is_empty() and here.id != level.manifest.exit: return int(here.id)
	var best := 0
	var distance := INF
	var planta := FLOOR.planta_of(global_position.y)
	for room in level.manifest.rooms:
		if room.id == level.manifest.exit or FLOOR.is_void(room): continue
		if FLOOR.planta_of(FLOOR.position_of(room).y) != planta: continue
		var d := position.distance_squared_to(FLOOR.position_of(room))
		if d < distance:
			distance = d
			best = room.id
	return best

## The doorways on its route and where it lines up with each and comes out of
## it: {door, enter, exit}, indices into `path` (door_threading.thread).
var crossings: Array = []
## The points of the route that go round an open leaf: reached, never cut.
## Taken as passed from a metre off, the corner it cut took it through the
## end of the leaf.
var rounds := {}
## How long it has been between lining up with a doorway and coming out.
var passing_time := 0.0
## A point of the route counts as reached this close to it, or once walked
## past: exactly on it (the six centimetres it used to be) was a target it
## could slide round against a corner for as long as the mode lasted.
const REACHED := 0.3
## Longest it keeps to a doorway it has started through before it lets a new
## route take over anyway.
const PASSING_MOST := 2.5

func move_on_path(delta: float) -> void:
	repath -= delta
	passing_time = passing_time + delta if passing_door() else 0.0
	if passing_time > PASSING_MOST: crossings = []
	# Half way through a doorway it finishes going through before it looks for
	# a new way: a route found from inside the frame lined it up again from
	# wherever it stood, back towards the leaf.
	if repath <= 0 and not passing_door():
		var map: RID = get_world_3d().navigation_map
		var raw := FLOOR.navigation_path(map, position, destination)
		var threaded: Dictionary = THREAD.thread(raw, level.hotel.doors, map)
		path = threaded.path
		crossings = threaded.crossings
		rounds.clear()
		for index in threaded.get("rounds", []): rounds[int(index)] = true
		path_index = 0
		repath = 0.45
		# Nowhere it can walk to (the way is another wing's, or behind a
		# locked door): it used to walk to the nearest wall and stand there
		# until the mode ran out. It gives up where it is instead.
		if not raw.is_empty() and raw[raw.size() - 1].distance_to(destination) > UNREACHABLE: give_up_route()
	advance_path()
	var direction := Vector3.ZERO
	if path_index < path.size():
		direction = path[path_index] - position
		direction.y = 0
		direction = direction.normalized()
	# Stepping round whatever it was pressed against (see watch_progress): for
	# as long as the step lasts, that is where it is going.
	if dodge_left > 0.0:
		dodge_left -= delta
		if direction.length() > 0.1 or dodge_left > 0.0: direction = dodge
	# The refuge is excluded even when the shortest path would cross it.
	if level.point_in_refuge(position + direction * 0.8):
		patrol_room = nearest_room()
		set_mode(Mode.PATROL)
		choose_patrol()
		direction = Vector3.ZERO
	# The door its route goes through, never one it merely passes: in a
	# corridor every door along it was near enough to stop for. Hunting, it
	# slams it open; otherwise it eases it and waits.
	var hunting := mode == Mode.CHASE
	var at_door := false
	var ahead = door_ahead()
	if ahead != null and Vector2(ahead.doorway.x - position.x, ahead.doorway.z - position.z).length() < (2.4 if hunting else 1.8):
		if ahead.locked:
			# A lock on its way: the mesh does not know doors and goes through,
			# but there is no way on here. A chase stands and loses the scent.
			if not hunting: give_up_route()
			direction = Vector3.ZERO
		else:
			if not ahead.moving: ahead.toggle(not hunting, false, hunting)
			direction = Vector3.ZERO
			at_door = true
	# Waiting at a door it stops there, instead of coasting on through the
	# leaf for the two metres it takes to brake.
	if at_door: speed = 0.0
	var wanted := desired_speed() if direction.length() > 0.1 else 0.0
	# Sharp turns cost speed: it has to swing its stilt legs around.
	if direction.length() > 0.1:
		wanted *= lerpf(0.35, 1.0, clampf((-global_basis.z).dot(direction) * 0.5 + 0.5, 0.0, 1.0))
	var acceleration := CHASE_ACCELERATION if mode == Mode.CHASE else 3.5
	speed = move_toward(speed, wanted, (acceleration if wanted > speed else 9.0) * delta)
	var heading := direction if direction.length() > 0.1 else -global_basis.z
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	velocity.y = -2 if is_on_floor() else velocity.y - 20 * delta
	if direction.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * (8.0 if mode == Mode.CHASE else 4.5)))
	move_and_slide()
	watch_progress(delta, direction, 0.0 if at_door else wanted)

## On to the next point of the route once this one is reached, or walked past.
func advance_path() -> void:
	while path_index < path.size():
		var point: Vector3 = path[path_index]
		var gap := Vector2(point.x - position.x, point.z - position.z)
		if gap.length() < REACHED:
			path_index += 1
			continue
		# Past it: further on than the point, along the stretch leading to it.
		if path_index > 0 and gap.length() < 1.0 and not rounds.has(path_index):
			var stretch: Vector3 = point - path[path_index - 1]
			if Vector2(stretch.x, stretch.z).dot(-gap) > 0.0:
				path_index += 1
				continue
		break

## Between lining up with a doorway and coming out past its leaf.
func passing_door() -> bool:
	for crossing in crossings:
		var leave := int(crossing.exit)
		if leave >= 0 and path_index > int(crossing.enter) and path_index <= leave: return true
	return false

## The first door of its route still to go through that is not simply open:
## shut, locked, or swinging. Null while the way is clear.
func door_ahead():
	for crossing in crossings:
		var leave := int(crossing.exit)
		if leave < 0 or leave < path_index: continue
		var door = crossing.door
		if not is_instance_valid(door) or (door.opened and not door.moving): continue
		return door
	return null

## No way on from here: behind a locked door, or so jammed that the steps
## below ran out. What it does instead depends on what it was at; a chase is
## never dropped, it only looks for its way again. Said to whoever watches
## (the test bots' watchdog): many in a row is a creature shut in somewhere.
signal route_abandoned(where: Vector3)
func give_up_route() -> void:
	route_abandoned.emit(global_position)
	crossings = []
	repath = 0.0
	match mode:
		Mode.INVESTIGATE: set_mode(Mode.SEARCH)
		Mode.PATROL:
			patrol_room = nearest_room()
			choose_patrol()
		Mode.SEARCH:
			var angle := rng.randf() * TAU
			destination = FLOOR.closest(get_world_3d().navigation_map, last_known + Vector3(cos(angle), 0, sin(angle)) * 3.5)

## How far short of where it was going a route may end and still count as
## going there: past this there is no way, and it stops trying.
const UNREACHABLE := 2.5
## Stuck: meaning to move and not getting anywhere. It used to step aside and
## take the same route again, straight back into whatever had stopped it,
## round and round for as long as the mode lasted -- the creature pressed into
## an open leaf that every playtest found. Now each time it is still stuck it
## goes one step further, and every step is written down (stuck_counts and the
## observer's log):
##   1  a step to whichever side has room
##   2  back off, and find the way again from there
##   3  open a shut door at hand; with none, a detour to open floor near by
##   4  another destination (a chase is kept: it only looks for the way again)
##   5  the last resort, and only where nobody is looking: a hop of up to two
##      metres along its own route
## Seconds without moving STUCK_GAIN before each next step.
const STUCK_STEPS := [0.6, 0.9, 1.5, 2.0, 3.0]
const STUCK_GAIN := 0.3
## Getting no nearer the end of its route is stuck too, whatever it does on
## the way: this long wanting to move without the route left to walk getting
## LINGER_GAIN shorter is another step. Rocking back and forth moves it more
## than STUCK_GAIN each swing, so the clock above never sees it (a route bent
## back and forth under a door on the planta above kept it at it for good);
## and it is not how far it wanders that tells, since going round a leaf is
## a few metres there and back in the same corner. Further than STUCK_FREE
## from where it got stuck, it is over.
const STUCK_LINGER := 5.0
const LINGER_GAIN := 0.5
const STUCK_FREE := 2.5
## How long a step aside lasts, and backing off.
const DODGE_TIME := 0.5
const BACK_TIME := 0.6
## The longest hop, and how near a shut door it may not land.
const HOP := 2.0
var dodge := Vector3.ZERO
var dodge_left := 0.0
var stuck_clock := 0.0
var stuck_linger := 0.0
var stuck_level := 0
var stuck_anchor := Vector3.ZERO
var stuck_origin := Vector3.INF
## Where the route it is measured on goes, and the least it has had left to
## walk of it.
var linger_goal := Vector3.INF
var linger_best := INF
## Which way it stepped last time, so when both sides look alike a second
## attempt tries the other one instead of rocking against the same edge.
var stuck_side := 1.0
## How many times each step (1 to 5) was reached this floor.
var stuck_counts := [0, 0, 0, 0, 0, 0]
signal stuck_escalated(step: int, where: Vector3)

func watch_progress(delta: float, direction: Vector3, wanted: float) -> void:
	if stuck_origin != Vector3.INF and position.distance_to(stuck_origin) > STUCK_FREE:
		stuck_level = 0
		stuck_origin = Vector3.INF
		stuck_linger = 0.0
	# Standing to listen, waiting at a door, or already stepping round: not
	# stuck, and nothing counts.
	if direction.length() < 0.1 or wanted < 0.05 or dodge_left > 0.0:
		stuck_clock = 0.0
		stuck_anchor = position
		return
	# A long frame is not a long time stuck: one hitch (or a test stepping it
	# seven seconds at once) counted whole took it straight to backing off.
	var step := minf(delta, 0.1)
	if position.distance_to(stuck_anchor) >= STUCK_GAIN:
		stuck_anchor = position
		stuck_clock = 0.0
	else: stuck_clock += step
	var left := route_left()
	if destination.distance_to(linger_goal) > 1.0 or left < linger_best - LINGER_GAIN:
		linger_goal = destination
		linger_best = left
		stuck_linger = 0.0
	else: stuck_linger += step
	if stuck_clock >= float(STUCK_STEPS[mini(stuck_level, STUCK_STEPS.size() - 1)]) or stuck_linger >= STUCK_LINGER: escalate(direction)

## How far it still has to go along its route, from where it stands.
func route_left() -> float:
	if path_index >= path.size(): return 0.0
	var left := Vector2(path[path_index].x - position.x, path[path_index].z - position.z).length()
	for index in range(path_index + 1, path.size()):
		left += Vector2(path[index].x - path[index - 1].x, path[index].z - path[index - 1].z).length()
	return left

func escalate(direction: Vector3) -> void:
	stuck_level = mini(stuck_level + 1, 5)
	stuck_counts[stuck_level] += 1
	if stuck_origin == Vector3.INF: stuck_origin = position
	stuck_clock = 0.0
	stuck_linger = 0.0
	stuck_anchor = position
	stuck_escalated.emit(stuck_level, global_position)
	var view = level.get("observer_view") if level != null else null
	if view != null and is_instance_valid(view): view.note("atasco · paso %d · %0.0f, %0.0f · %s" % [stuck_level, position.x, position.z, Mode.keys()[mode]])
	match stuck_level:
		1:
			dodge = (free_side(direction) + direction * 0.45).normalized()
			dodge_left = DODGE_TIME
		2:
			dodge = -direction
			dodge_left = BACK_TIME
			crossings = []
			repath = BACK_TIME
		3:
			var door = shut_door_at_hand()
			if door != null: door.toggle(mode != Mode.CHASE, false, mode == Mode.CHASE)
			else: detour(direction)
		4:
			if mode == Mode.CHASE:
				crossings = []
				repath = 0.0
			else: give_up_route()
		_:
			hop()
			stuck_level = 0
			stuck_origin = Vector3.INF

## The side with more room before a wall or a shut leaf; when there is no
## telling them apart, the other side from last time.
func free_side(direction: Vector3) -> Vector3:
	var right := Vector3(-direction.z, 0, direction.x)
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP
	var room := {}
	for side in [1.0, -1.0]:
		var query := PhysicsRayQueryParameters3D.create(from, from + right * side * 1.5, 1 | 8)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		room[side] = 1.5 if hit.is_empty() else from.distance_to(hit.position)
	if absf(float(room[1.0]) - float(room[-1.0])) < 0.2: stuck_side = -stuck_side
	else: stuck_side = 1.0 if float(room[1.0]) > float(room[-1.0]) else -1.0
	return right * stuck_side

func shut_door_at_hand():
	for door in level.hotel.doors:
		if door.locked or door.opened or door.moving: continue
		if absf(door.doorway.y - position.y) < 2.0 and Vector2(door.doorway.x - position.x, door.doorway.z - position.z).length() < 1.6: return door
	return null

## Open floor a couple of metres off, not the way it was pushing: it walks
## there, and looks for its way again from a new place.
func detour(direction: Vector3) -> bool:
	var map: RID = get_world_3d().navigation_map
	var space := get_world_3d().direct_space_state
	for attempt in 10:
		var angle := rng.randf() * TAU
		var way := Vector3(cos(angle), 0, sin(angle))
		if way.dot(direction) > 0.3: continue
		var point: Vector3 = FLOOR.closest(map, position + way * rng.randf_range(2.0, 3.0))
		if point.distance_to(position) < 1.2 or absf(point.y - position.y) > 1.0: continue
		var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP, point + Vector3.UP, 1 | 8)
		query.exclude = [get_rid()]
		if not space.intersect_ray(query).is_empty(): continue
		path = PackedVector3Array([position, point])
		path_index = 1
		crossings = []
		rounds.clear()
		repath = 1.5
		return true
	return false

## The last resort: up to HOP metres along its own route, onto open floor,
## never through a shut door, into the refuge or onto another planta, and only
## where no survivor can see where it was or where it lands. Only the machine
## that runs it does this; the others see it move the way they see any move.
func hop() -> bool:
	if control != "ai" or path_index >= path.size(): return false
	var line := PackedVector3Array([position])
	var left := HOP
	for i in range(path_index, path.size()):
		var from: Vector3 = line[line.size() - 1]
		var step: float = from.distance_to(path[i])
		if step >= left:
			line.append(from + (path[i] - from).normalized() * left)
			break
		left -= step
		line.append(path[i])
	var target: Vector3 = FLOOR.closest(get_world_3d().navigation_map, line[line.size() - 1])
	if target.distance_to(position) < 0.5 or absf(target.y - position.y) > 1.0 or level.point_in_refuge(target): return false
	for door in level.hotel.doors:
		if door.opened and not door.moving: continue
		for i in range(1, line.size()):
			if THREAD.crossing(door, line[i - 1], line[i]) >= 0.0: return false
	if not body_fits(target) or watched(position) or watched(target): return false
	global_position = target + Vector3(0, 0.04, 0)
	velocity = Vector3.ZERO
	speed = 0.0
	crossings = []
	repath = 0.0
	return true

func body_fits(point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 2.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 1.26, 0))
	query.collision_mask = 1 | 8
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## Whether any survivor, from where its eyes are and the way it is looking,
## has this spot in view.
func watched(point: Vector3) -> bool:
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body) or not "camera" in body or not is_instance_valid(body.camera): continue
		var eye: Vector3 = body.camera.global_position
		var towards: Vector3 = point + Vector3(0, 1.2, 0) - eye
		var gap := towards.length()
		if gap > SIGHT_RANGE or gap < 0.01: continue
		if -body.camera.global_basis.z.dot(towards / gap) < 0.35: continue
		var query := PhysicsRayQueryParameters3D.create(eye, eye + towards, 1 | 8 | 64)
		query.exclude = [body.get_rid(), get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return true
	return false
