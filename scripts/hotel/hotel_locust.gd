extends CharacterBody3D
const FLOOR := preload("res://scripts/hotel/floor_definition.gd")
enum Mode { PATROL, INVESTIGATE, CHASE, SEARCH, WINDUP, RECOVER }
var level
var mode := Mode.PATROL
var destination := Vector3.ZERO
var last_known := Vector3.ZERO
var observed_hide: Node3D
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
var gait := 0.0
var warning := ""
var patrol_room := 0
var footstep: AudioStreamPlayer3D
var step_time := 0.0
var skeleton: Skeleton3D
var pose_bones := {}

func _ready() -> void:
	add_to_group("hotel_actors")
	collision_layer = 32
	collision_mask = 1 | 8 | 4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.97
	add_child(shape)
	visual = load("res://assets/enemies/locust.glb").instantiate()
	# 2.46 m standing height fits the hotel's 2.65 m door lintels.
	visual.scale = Vector3.ONE * 1.65
	visual.set_script(preload("res://scripts/locust_visual.gd"))
	add_child(visual)
	var rigs := visual.find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		skeleton = rigs[0]
		for side in ["L", "R"]:
			for limb in ["Thigh", "Calf", "UpperArm"]:
				var id := skeleton.find_bone("ValveBiped.Bip01_" + side + "_" + limb)
				if id >= 0: pose_bones[side + limb] = {"id": id, "rotation": skeleton.get_bone_pose_rotation(id)}
	signal_player = AudioStreamPlayer3D.new()
	signal_player.bus = "Threat"
	signal_player.max_distance = 25
	signal_player.position.y = 1.5
	signal_player.stream = make_warning()
	add_child(signal_player)
	footstep = AudioStreamPlayer3D.new()
	footstep.bus = "Threat"
	footstep.stream = preload("res://scripts/hotel/hotel_player.gd").step_sound()
	footstep.max_distance = 22
	footstep.pitch_scale = 0.65
	footstep.volume_db = -9
	add_child(footstep)
	rng.seed = level.manifest.seed + 71013
	destination = position

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

func clear_sight(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.65, 0), point, 1 | 8 | 64)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func sees_player(ignore_concealment := false) -> bool:
	if level.in_refuge() or level.session.participants.get(1) == level.session.Life.DEAD: return false
	var player = level.player
	var offset: Vector3 = player.global_position - global_position
	if offset.length() > 14: return false
	var facing := -global_basis.z
	if offset.length() > 1.2 and facing.dot(offset.normalized()) < cos(deg_to_rad(40)): return false
	if not clear_sight(player.camera.global_position): return false
	if player.hidden and not ignore_concealment:
		return observed_hide == player.hiding_place or offset.length() < 2.3
	return true

func hear(point: Vector3, radius: float) -> void:
	if grace > 0 or mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER] or level.in_refuge(): return
	# A wall attenuates sound; it never gives exact vision through geometry.
	var effective := radius if clear_sight(point + Vector3(0, 1, 0)) else radius * 0.25
	if global_position.distance_to(point) > effective: return
	last_known = point
	set_mode(Mode.INVESTIGATE)
	destination = point

func set_mode(next: Mode) -> void:
	mode = next
	state_time = 0
	repath = 0
	if next == Mode.WINDUP:
		warning = "[The Locust se tensa: ¡apártate!]"
		signal_player.play()
	else: warning = ""

func choose_patrol() -> void:
	var choices: Array = level.manifest.adjacency[patrol_room].filter(func(id): return id != level.manifest.exit)
	if choices.is_empty(): return
	patrol_room = choices[rng.randi_range(0, choices.size() - 1)]
	destination = FLOOR.position_of(level.manifest.rooms[patrol_room])
	repath = 0

func can_attack() -> bool:
	return not level.in_refuge() and global_position.distance_to(level.player.global_position) < 1.2 and clear_sight(level.player.camera.global_position) and (not level.player.hidden or observed_hide == level.player.hiding_place or sees_player())

func _physics_process(delta: float) -> void:
	if level.session.state != level.session.State.PLAYING: return
	grace = maxf(0, grace - delta)
	state_time += delta
	if grace > 0: return
	var visible_player := sees_player()
	detection = detection + delta if visible_player else 0.0
	if visible_player:
		last_known = level.player.global_position
		lost_time = 0
	else: lost_time += delta
	if detection >= 0.35 and mode not in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER]: set_mode(Mode.CHASE)
	match mode:
		Mode.PATROL:
			if position.distance_to(destination) < 0.6 or state_time > 12:
				choose_patrol()
				state_time = 0
		Mode.INVESTIGATE:
			if position.distance_to(destination) < 0.7 or state_time > 12: set_mode(Mode.SEARCH)
		Mode.CHASE:
			destination = last_known
			if level.in_refuge() or lost_time > 2.5: set_mode(Mode.SEARCH)
			elif can_attack(): set_mode(Mode.WINDUP)
		Mode.SEARCH:
			if state_time > 10:
				observed_hide = null
				patrol_room = nearest_room()
				set_mode(Mode.PATROL)
				choose_patrol()
			elif position.distance_to(destination) < 0.7:
				var angle := rng.randf() * TAU
				destination = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, last_known + Vector3(cos(angle), 0, sin(angle)) * 3.5)
				repath = 0
		Mode.WINDUP:
			if state_time >= 0.7:
				if can_attack(): level.session.capture(1)
				set_mode(Mode.RECOVER)
		Mode.RECOVER:
			if state_time >= 1.2: set_mode(Mode.CHASE if visible_player else Mode.SEARCH)
	if mode in [Mode.WINDUP, Mode.RECOVER]:
		velocity = Vector3.ZERO
		visual.rotation.x = move_toward(visual.rotation.x, -0.22 if mode == Mode.WINDUP else 0.0, delta)
		animate_pose(0)
		return
	visual.rotation.x = move_toward(visual.rotation.x, 0.0, delta)
	move_on_path(delta)

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
	var speed := 5.2 if mode == Mode.CHASE else 2.4
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -2 if is_on_floor() else velocity.y - 20 * delta
	if direction.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 8))
	move_and_slide()
	if Vector2(velocity.x, velocity.z).length() > 0.3:
		step_time += delta
		if step_time > (0.32 if mode == Mode.CHASE else 0.6):
			step_time = 0
			footstep.play()
	gait += delta * speed
	visual.position.y = sin(gait * 2) * 0.035
	visual.rotation.z = sin(gait) * 0.02
	animate_pose(Vector2(velocity.x, velocity.z).length())

func animate_pose(speed: float) -> void:
	if not is_instance_valid(skeleton): return
	for key in pose_bones:
		var data: Dictionary = pose_bones[key]
		var phase := gait * 2 + (PI if key.begins_with("R") else 0.0)
		var angle := sin(phase) * minf(speed / 5.2, 1.0) * 0.19
		if key.ends_with("Calf"): angle = maxf(0, -angle) * 1.4
		if key.ends_with("UpperArm"): angle *= -0.5
		skeleton.set_bone_pose_rotation(data.id, data.rotation * Quaternion(Vector3.RIGHT, angle))
