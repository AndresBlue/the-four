extends CharacterBody3D
@export var sound_profile: Resource = preload("res://game/audio/profiles/locust.tres")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
enum Mode { PATROL, INVESTIGATE, CHASE, SEARCH, WINDUP, RECOVER }
## Perception and pacing. Distances in metres, speeds in m/s.
## It perceives the player from much farther than the player can sense it:
## anything in its wide view with a clear line is noticed, however far.
const SIGHT_RANGE := 70.0
const SIGHT_HALF_ANGLE := 60.0
## Suspicion gained per second with the player in view, near and far.
const NOTICE_NEAR := 4.5
const NOTICE_FAR := 1.4
const NOTICE_DECAY := 0.12
## Suspicion at which it stops wandering and goes to look.
const SUSPICION := 0.2
## Player noises carry this many times their base radius, along walkable routes.
const HEARING_SCALE := 2.6
## Lost sight for longer than this, the chase becomes a search.
const LOSE_AFTER := 7.0
## Faster than a sprinting player: breaking line of sight is the only escape.
const CHASE_SPEED := 6.4
## Speed while heading to the last place it saw or heard the player.
const TRACK_SPEED := 5.2
const TORCH_NOTICE_RANGE := 45.0
## Strike: starts within ATTACK_RANGE, lunges for WINDUP_TIME, kills within STRIKE_REACH.
const ATTACK_RANGE := 2.4
const STRIKE_REACH := 3.2
const WINDUP_TIME := 0.3
const RECOVER_TIME := 0.6
## Eye height of the creature for line-of-sight checks.
const EYE_HEIGHT := 2.4
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
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
	level.world_audio.apply_route(footstep, route, lerpf(-4.0, 4.0, strength), "Threat")
	footstep.pitch_scale = rng.randf_range(0.82, 1.08)
	footstep.play()

## Plays one grunt from the recording, routed like every other creature sound.
func grunt() -> void:
	if level == null or not level.world_audio.enabled: return
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return
	var segment: Array = GRUNTS.SEGMENTS[rng.randi_range(0, GRUNTS.SEGMENTS.size() - 1)]
	level.world_audio.apply_route(voice, route, 0.0, "Threat")
	voice.pitch_scale = rng.randf_range(0.85, 1.0)
	voice.play(segment[0])
	grunt_left = segment[1]

func clear_sight(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, EYE_HEIGHT, 0), point, 1 | 8 | 64)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func sees_player(ignore_concealment := false) -> bool:
	if level.in_refuge() or level.session.participants.get(1) == level.session.Life.DEAD: return false
	var player = level.player
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

## How quickly a visible player is noticed: close, lit and running players
## stand out; crouching and distance buy time to break line of sight.
func notice_rate() -> float:
	var player = level.player
	var distance: float = player.global_position.distance_to(global_position)
	var rate := lerpf(NOTICE_NEAR, NOTICE_FAR, clampf((distance - 4.0) / (SIGHT_RANGE - 4.0), 0.0, 1.0))
	if player.crouched: rate *= 0.55
	if Vector2(player.velocity.x, player.velocity.z).length() > 4.6: rate *= 1.35
	if player.torch.visible: rate *= 1.4
	return rate

## True when the player's torch beam falls on the creature from afar.
func lit_by_torch() -> bool:
	var player = level.player
	var torch: SpotLight3D = player.torch
	if not torch.visible or player.hidden or level.in_refuge(): return false
	var chest := global_position + Vector3(0, 1.6, 0)
	var offset := chest - torch.global_position
	if offset.length() > TORCH_NOTICE_RANGE or offset.length() < 5.0: return false
	if (-torch.global_basis.z).angle_to(offset) > deg_to_rad(torch.spot_angle * 0.85): return false
	var ray := PhysicsRayQueryParameters3D.create(torch.global_position, chest, 1 | 8 | 64)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func hear(point: Vector3, radius: float) -> void:
	if grace > 0 or mode in [Mode.WINDUP, Mode.RECOVER] or level.in_refuge(): return
	var reach := radius * HEARING_SCALE
	if global_position.distance_to(point) > reach: return
	# Sound travels through rooms and doorways; the walkable route must fit.
	if not clear_sight(point + Vector3(0, 1, 0)):
		var route := FLOOR.navigation_path(get_world_3d().navigation_map, position, point)
		var length := 0.0
		for i in range(1, route.size()): length += route[i].distance_to(route[i - 1])
		if route.size() < 2 or length > reach: return
	if mode == Mode.CHASE:
		# While hunting, every noise tells it where the player is.
		last_known = point
		lost_time = minf(lost_time, 1.0)
		return
	last_known = point
	set_mode(Mode.INVESTIGATE)
	destination = point

func set_mode(next: Mode) -> void:
	var previous := mode
	mode = next
	state_time = 0
	repath = 0
	pause_time = 0
	if next == Mode.CHASE and previous != Mode.CHASE:
		# A startled lunge, then it builds up to full speed.
		speed = maxf(speed, 3.5)
		grunt_clock = 0.0
	if next == Mode.WINDUP: signal_player.play()

func choose_patrol() -> void:
	var choices: Array = level.manifest.adjacency[patrol_room].filter(func(id): return id != level.manifest.exit)
	if choices.is_empty(): return
	patrol_room = choices[rng.randi_range(0, choices.size() - 1)]
	destination = FLOOR.position_of(level.manifest.rooms[patrol_room])
	repath = 0

func can_attack(reach := ATTACK_RANGE) -> bool:
	var player = level.player
	if level.in_refuge() or global_position.distance_to(player.global_position) >= reach: return false
	if not clear_sight(player.camera.global_position): return false
	return not player.hidden or observed_hide == player.hiding_place or sees_player()

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

func _physics_process(delta: float) -> void:
	if level.session.state != level.session.State.PLAYING: return
	grace = maxf(0, grace - delta)
	state_time += delta
	wander_clock += delta
	if grace > 0:
		update_visual(delta)
		return
	var visible_player := sees_player()
	if visible_player:
		detection = minf(1.5, detection + delta * notice_rate())
		last_known = level.player.global_position
		lost_time = 0
	else:
		detection = maxf(0.0, detection - delta * NOTICE_DECAY)
		lost_time += delta
	# Only a player it can currently see starts a chase; memory alone does not.
	if visible_player and detection >= 1.0 and mode not in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER]:
		set_mode(Mode.CHASE)
	elif visible_player and detection >= SUSPICION and mode in [Mode.PATROL, Mode.SEARCH]:
		# Something moved: stop wandering and go look, before committing.
		set_mode(Mode.INVESTIGATE)
		destination = last_known
	# A torch beam seen from afar gives away where the player is standing.
	light_exposure = light_exposure + delta if lit_by_torch() else maxf(0.0, light_exposure - delta * 0.5)
	if light_exposure > 0.35 and mode in [Mode.PATROL, Mode.SEARCH, Mode.INVESTIGATE]:
		last_known = level.player.global_position
		if mode != Mode.INVESTIGATE or destination.distance_to(last_known) > 2.0:
			set_mode(Mode.INVESTIGATE)
			destination = last_known
		detection = maxf(detection, 0.3)
	pause_time = maxf(0.0, pause_time - delta)
	match mode:
		Mode.PATROL:
			if pause_time <= 0 and (position.distance_to(destination) < 0.6 or state_time > 14):
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
			var player = level.player
			# Reaching where it last saw or heard the player, it checks the wardrobes there.
			if lost_time > 0.5 and observed_hide == null and global_position.distance_to(last_known) < 2.5:
				observed_hide = suspect_hide(last_known)
			if player.hidden and observed_hide == player.hiding_place:
				# Goes to the wardrobe and pulls the doors open.
				destination = observed_hide.to_global(observed_hide.exit_offset)
				if global_position.distance_to(destination) < 2.2: observed_hide.force_open()
			grunt_clock -= delta
			if grunt_clock <= 0.0:
				grunt()
				grunt_clock = rng.randf_range(2.5, 5.0)
			if level.in_refuge() or lost_time > LOSE_AFTER: set_mode(Mode.SEARCH)
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
				if can_attack(STRIKE_REACH): level.session.capture(1)
				set_mode(Mode.RECOVER)
		Mode.RECOVER:
			if state_time >= RECOVER_TIME: set_mode(Mode.CHASE if visible_player else Mode.SEARCH)
	if grunt_left > 0.0:
		grunt_left -= delta
		if grunt_left <= 0.0: voice.stop()
	if mode == Mode.WINDUP:
		lunge(delta)
	elif mode == Mode.RECOVER:
		velocity = Vector3.ZERO
		speed = 0.0
		face_toward(level.player.global_position, delta, 6.0)
	else:
		move_on_path(delta)
	update_visual(delta)

## During the wind-up it keeps closing in on the player, blades raised.
func lunge(delta: float) -> void:
	var offset: Vector3 = level.player.global_position - global_position
	offset.y = 0.0
	face_toward(level.player.global_position, delta, 12.0)
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
	visual.move_velocity = velocity
	visual.aggression = move_toward(visual.aggression, 1.0 if mode == Mode.CHASE else 0.0, delta * 2.5)
	visual.attack = clampf(state_time / WINDUP_TIME, 0.0, 1.0) if mode == Mode.WINDUP else move_toward(visual.attack, 0.0, delta * 8.0)
	# Stoops under door lintels; it is taller than the doorways.
	var near_door := false
	for door in level.hotel.doors:
		if door.doorway.distance_to(global_position) < 2.6:
			near_door = true
			break
	visual.duck = move_toward(visual.duck, 1.0 if near_door else 0.0, delta * 3.0)
	visual.recovering = 1.0 if mode == Mode.RECOVER and state_time < 0.5 else move_toward(visual.recovering, 0.0, delta * 2.0)
	var player = level.player
	if mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER] or detection > 0.2 or light_exposure > 0.2:
		visual.look_point = player.camera.global_position if lost_time < 0.5 else last_known + Vector3.UP * 1.5
	elif mode in [Mode.SEARCH, Mode.PATROL] and pause_time > 0:
		# Scans the room while standing still.
		visual.look_point = global_position - global_basis.z * 4.0 + global_basis.x * sin(wander_clock * 0.9) * 4.0 + Vector3.UP * 1.6
	else:
		visual.look_point = Vector3.INF

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
	var acceleration := 7.0 if mode == Mode.CHASE else 3.5
	speed = move_toward(speed, wanted, (acceleration if wanted > speed else 9.0) * delta)
	var heading := direction if direction.length() > 0.1 else -global_basis.z
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	velocity.y = -2 if is_on_floor() else velocity.y - 20 * delta
	if direction.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * (8.0 if mode == Mode.CHASE else 4.5)))
	move_and_slide()
