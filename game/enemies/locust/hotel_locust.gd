extends CharacterBody3D
@export var sound_profile: Resource = preload("res://game/audio/profiles/locust.tres")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
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
## On first spotting the player it freezes, turns and shrieks before it runs:
## the moment the player hears it is the moment to break line of sight.
const ALERT_TIME := 1.2
## A chase starts from this speed and builds up at CHASE_ACCELERATION.
const CHASE_START_SPEED := 2.5
const CHASE_ACCELERATION := 3.2
const TORCH_NOTICE_RANGE := 45.0
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
## An execution: impaled, lifted and stabbed three times before the floor
## registers the death (see hotel_main.start_execution).
const EXECUTION_TIME := 2.9
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
var pause_time := 0.0
var light_exposure := 0.0
var wander_clock := 0.0
## Chase vocalisations: one grunt segment at a time from the creature.
var voice: AudioStreamPlayer3D
var grunt_clock := 0.0
var grunt_left := 0.0
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
## Calls replayed here from the machine in charge (tests check they arrive).
var calls_heard := 0

func _ready() -> void:
	add_to_group("hotel_actors")
	visual = $Visual
	signal_player = $Warning
	signal_player.stream = make_warning()
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
	add_child(voice)
	if level == null:
		set_physics_process(false)
		return
	rng.seed = level.manifest.seed + 71013
	destination = position
	wander_clock = rng.randf() * 100.0

static func make_warning() -> AudioStreamWAV:
	# Original short scrape/pulse; independent of music and ambient buses.
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(15435 * 2)
	for i in 15435:
		var t := float(i) / 22050.0
		var envelope := sin(PI * t / 0.7)
		var value := (sin(TAU * (190 * t + 160 * t * t)) * 0.6 + sin(TAU * 67 * t) * 0.25) * envelope
		bytes.encode_s16(i * 2, int(value * 17000))
	audio.data = bytes
	return audio

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
	level.world_audio.apply_route(footstep, route, level_db, "Threat", true)
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
	var segment: Array = GRUNTS.SEGMENTS[last_grunt]
	var pitch := rng.randf_range(0.85, 1.0)
	# Everyone else hears the same call from their own place.
	if "match_net" in level and level.match_net != null: level.match_net.creature_call("grunt", last_grunt, pitch)
	if not level.world_audio.enabled: return 0.0
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return 0.0
	level.world_audio.apply_route(voice, route, 0.0, "Threat", true)
	voice.pitch_scale = pitch
	voice.play(segment[0])
	# A lower pitch plays the segment slower: stop when it really ends.
	grunt_left = segment[1] / voice.pitch_scale
	return grunt_left

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
		if (-torch.global_basis.z).angle_to(offset) > deg_to_rad(torch.spot_angle * 0.85): continue
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

func hear(point: Vector3, radius: float) -> void:
	if control != "ai": return
	if grace > 0 or mode in [Mode.WINDUP, Mode.RECOVER]: return
	if not can_hear(point, radius): return
	if mode == Mode.CHASE:
		# While hunting, every noise tells it where the player is.
		last_known = point
		lost_time = minf(lost_time, 1.0)
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

## A sound it did not have to hear through the player: something fell, it goes
## to look. Ignored while it is already hunting.
func investigate(point: Vector3) -> void:
	if control != "ai": return
	if mode in [Mode.CHASE, Mode.ALERT, Mode.WINDUP, Mode.RECOVER]: return
	last_known = point
	set_mode(Mode.INVESTIGATE)
	destination = point

func set_mode(next: Mode) -> void:
	var previous := mode
	mode = next
	state_time = 0
	guided = false
	repath = 0
	pause_time = 0
	if next == Mode.CHASE and previous != Mode.CHASE:
		# It sets off from a stride and builds up to full speed.
		speed = maxf(speed, CHASE_START_SPEED)
		# Coming out of the alert, the next call waits for the first to finish.
		grunt_clock = grunt_left + rng.randf_range(0.8, 1.8) if previous == Mode.ALERT else 0.0
	# Spotting the player: an aggressive grunt as it turns to hunt.
	if next == Mode.ALERT: grunt()
	if next == Mode.WINDUP:
		signal_player.play()
		if "match_net" in level and level.match_net != null: level.match_net.creature_call("warning", 0, 1.0)

func choose_patrol() -> void:
	var choices: Array = level.manifest.adjacency[patrol_room].filter(func(id): return id != level.manifest.exit)
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
			# Cautious when close to what it heard.
			return lerpf(1.2, 2.9, clampf((position.distance_to(destination) - 1.5) / 5.0, 0.0, 1.0))
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

func push_state(data: Array) -> void:
	if data.size() < 6: return
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
	if grunt_left > 0.0:
		grunt_left -= delta
		if grunt_left <= 0.0: voice.stop()
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
	if state_time >= EXECUTION_TIME and control != "puppet":
		set_mode(Mode.SEARCH if control == "ai" else Mode.PATROL)

## A call decided where the creature is controlled, replayed here.
func play_call(kind: String, segment: int, pitch: float) -> void:
	calls_heard += 1
	if kind == "warning":
		signal_player.play()
		return
	if kind != "grunt" or segment < 0 or segment >= GRUNTS.SEGMENTS.size() or not level.world_audio.enabled: return
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return
	level.world_audio.apply_route(voice, route, 0.0, "Threat", true)
	voice.pitch_scale = pitch
	voice.play(GRUNTS.SEGMENTS[segment][0])
	grunt_left = GRUNTS.SEGMENTS[segment][1] / pitch

func _physics_process(delta: float) -> void:
	if level.session.state != level.session.State.PLAYING: return
	if control == "puppet":
		follow_state(delta)
		return
	if control == "player":
		if is_instance_valid(driver): driver.drive(delta)
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
	else:
		detection = maxf(0.0, detection - delta * NOTICE_DECAY)
		lost_time += delta
	# Only a player it can currently see starts a chase; memory alone does not.
	if visible_player and detection >= 1.0 and mode not in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER, Mode.ALERT]:
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
			grunt_clock -= delta
			if grunt_clock <= 0.0:
				grunt()
				grunt_clock = rng.randf_range(2.5, 5.0)
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
				destination = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, last_known + Vector3(cos(angle), 0, sin(angle)) * 3.5)
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
	if grunt_left > 0.0:
		grunt_left -= delta
		if grunt_left <= 0.0: voice.stop()
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
	if (mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER, Mode.ALERT] or detection > 0.2 or light_exposure > 0.2) and is_instance_valid(player):
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
	var best := 0
	var distance := INF
	for room in level.manifest.rooms:
		if room.id == level.manifest.exit: continue
		var d := position.distance_squared_to(FLOOR.position_of(room))
		if d < distance:
			distance = d
			best = room.id
	return best

func move_on_path(delta: float) -> void:
	repath -= delta
	if repath <= 0:
		path = FLOOR.navigation_path(get_world_3d().navigation_map, position, destination)
		path_index = 0
		repath = 0.45
	while path_index < path.size() and Vector2(path[path_index].x - position.x, path[path_index].z - position.z).length() < 0.06: path_index += 1
	var direction := Vector3.ZERO
	if path_index < path.size():
		direction = path[path_index] - position
		direction.y = 0
		direction = direction.normalized()
	# The refuge is excluded even when the shortest path would cross it.
	if level.point_in_refuge(position + direction * 0.8):
		patrol_room = nearest_room()
		set_mode(Mode.PATROL)
		choose_patrol()
		direction = Vector3.ZERO
	# Hunting, it slams doors open; otherwise it eases them and waits.
	var hunting := mode == Mode.CHASE
	for door in level.hotel.doors:
		if door.doorway.distance_to(position) < (2.4 if hunting else 1.8) and (not door.opened or door.moving):
			if not door.moving: door.toggle(not hunting, false, hunting)
			direction = Vector3.ZERO
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
