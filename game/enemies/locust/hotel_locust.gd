extends CharacterBody3D
@export var sound_profile: Resource = preload("res://game/audio/profiles/locust.tres")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
enum Mode { PATROL, INVESTIGATE, CHASE, SEARCH, WINDUP, RECOVER }
## Perception and pacing. Distances in metres, speeds in m/s.
const SIGHT_RANGE := 16.0
const SIGHT_HALF_ANGLE := 40.0
## Suspicion gained per second with the player in view, near and far.
const NOTICE_NEAR := 3.2
const NOTICE_FAR := 0.6
const NOTICE_DECAY := 0.35
## Lost sight for longer than this, the chase becomes a search.
const LOSE_AFTER := 2.5
const CHASE_SPEED := 5.4
## Speed while heading to the last place it saw the player.
const TRACK_SPEED := 3.4
const TORCH_NOTICE_RANGE := 26.0
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

func _ready() -> void:
	add_to_group("hotel_actors")
	visual = $Visual
	signal_player = $Warning
	signal_player.stream = make_warning()
	footstep = $Footsteps
	footstep.stream = claw_sound()
	if visual.has_signal("footfall"): visual.footfall.connect(on_footfall)
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
	if level == null or level.session.state != level.session.State.PLAYING: return
	footstep.global_position = point
	footstep.volume_db = lerpf(-6.0, 3.0, strength)
	footstep.pitch_scale = rng.randf_range(0.85, 1.12)
	footstep.play()

func clear_sight(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.65, 0), point, 1 | 8 | 64)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func sees_player(ignore_concealment := false) -> bool:
	if level.in_refuge() or level.session.participants.get(1) == level.session.Life.DEAD: return false
	var player = level.player
	var offset: Vector3 = player.global_position - global_position
	if offset.length() > SIGHT_RANGE: return false
	var facing := -global_basis.z
	if offset.length() > 1.2 and facing.dot(offset.normalized()) < cos(deg_to_rad(SIGHT_HALF_ANGLE)): return false
	if not clear_sight(player.camera.global_position): return false
	if player.hidden and not ignore_concealment:
		return observed_hide == player.hiding_place or offset.length() < 2.3
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
	# A wall attenuates sound; it never gives exact vision through geometry.
	var effective := radius if clear_sight(point + Vector3(0, 1, 0)) else radius * 0.25
	if global_position.distance_to(point) > effective: return
	if mode == Mode.CHASE:
		# Loud noise keeps a chase heading the right way, but never resets
		# the time without sight: breaking line of sight still loses it.
		if radius >= 10.0 and lost_time > 0.3: last_known = point
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
		speed = maxf(speed, 3.0)
	if next == Mode.WINDUP: signal_player.play()

func choose_patrol() -> void:
	var choices: Array = level.manifest.adjacency[patrol_room].filter(func(id): return id != level.manifest.exit)
	if choices.is_empty(): return
	patrol_room = choices[rng.randi_range(0, choices.size() - 1)]
	destination = FLOOR.position_of(level.manifest.rooms[patrol_room])
	repath = 0

func can_attack() -> bool:
	return not level.in_refuge() and global_position.distance_to(level.player.global_position) < 1.2 and clear_sight(level.player.camera.global_position) and (not level.player.hidden or observed_hide == level.player.hiding_place or sees_player())

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
	elif visible_player and detection >= 0.35 and mode in [Mode.PATROL, Mode.SEARCH]:
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
				set_mode(Mode.SEARCH)
				pause_time = rng.randf_range(0.6, 1.4)
		Mode.CHASE:
			destination = last_known
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
			if state_time >= 0.7:
				if can_attack(): level.session.capture(1)
				set_mode(Mode.RECOVER)
		Mode.RECOVER:
			if state_time >= 1.2: set_mode(Mode.CHASE if visible_player else Mode.SEARCH)
	if mode in [Mode.WINDUP, Mode.RECOVER]:
		velocity = Vector3.ZERO
		speed = 0.0
		face_toward(level.player.global_position, delta, 6.0)
	else:
		move_on_path(delta)
	update_visual(delta)

func face_toward(point: Vector3, delta: float, rate: float) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length() < 0.05: return
	rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), minf(1.0, delta * rate))

func update_visual(delta: float) -> void:
	if not is_instance_valid(visual) or not "move_velocity" in visual: return
	visual.move_velocity = velocity
	visual.aggression = move_toward(visual.aggression, 1.0 if mode == Mode.CHASE else 0.0, delta * 2.5)
	visual.attack = clampf(state_time / 0.7, 0.0, 1.0) if mode == Mode.WINDUP else move_toward(visual.attack, 0.0, delta * 8.0)
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
	for door in level.hotel.doors:
		if door.doorway.distance_to(position) < 1.8 and (not door.opened or door.moving):
			if not door.moving: door.toggle(true, false)
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
