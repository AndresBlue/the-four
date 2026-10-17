extends CharacterBody3D
## Another survivor in an online match, as seen on this machine: the body the
## creature can see and strike, the doors can be blocked by, and a dead
## teammate can watch through. It follows the state its owner sends about
## twenty times a second, smoothed a little behind real time, and replays
## what others would notice: walk animation, torch beam and footsteps.
## Same fields the creature reads on the local player (slot, camera, torch,
## hidden, hiding_place, crouched, velocity).
const AVATAR := preload("res://game/player/avatars/avatar_visual.tscn")
const STEPS := preload("res://game/audio/footstep_segments.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PLAYER := preload("res://game/player/hotel_player.gd")
## Seconds behind the newest state: smooths the gaps between packets.
const DELAY := 0.1
var slot := 0
var player_name := ""
var camera: Camera3D
var torch: SpotLight3D
var avatar: Node3D
var hidden := false
var hiding_place: Node3D
var hide_index := -1
var crouched := false
var reading := false
## Holding interact in the refuge: counts towards leaving the floor.
var peek_left := 0.0
var peek_right := 0.0
var pitch := 0.0
var level
## Received states: {time, position, yaw, pitch, velocity}.
var states: Array = []
var clock := 0.0
var step_distance := 0.0
var step_voice: AudioStreamPlayer3D
## True while the owner is disconnected (the body stays, exposed).
var away := false
## Dead: no body on screen and nothing to bump into.
var dead := false

func setup(owner_level, seat: int, words: String, character: int) -> void:
	level = owner_level
	slot = seat
	player_name = words
	name = "Survivor_%d" % seat
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.91
	shape.name = "BodyShape"
	add_child(shape)
	avatar = AVATAR.instantiate()
	avatar.character = character
	avatar.first_person = false
	add_child(avatar)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 1.64
	camera.fov = 78.0
	camera.far = 95.0
	camera.cull_mask = 1048573
	add_child(camera)
	torch = SpotLight3D.new()
	torch.name = "Flashlight"
	torch.visible = false
	torch.light_color = Color(1, 0.9, 0.74)
	torch.light_energy = 8.0
	torch.spot_range = 24.0
	torch.spot_angle = 32.0
	torch.spot_attenuation = 0.85
	# A teammate's beam must stay in its own room. It was seen in the next one
	# as a round glow: not the beam itself, but the volumetric fog it lit, which
	# is worked out in cells coarse enough to straddle a wall (measured: the far
	# face of a wall brightened by two thirds with fog, not at all without).
	# The haze of your own torch stays; only you see it, on your side.
	torch.light_volumetric_fog_energy = 0.0
	# Out of the bounce light, like your own (hotel_player._ready()).
	torch.light_bake_mode = Light3D.BAKE_DISABLED
	torch.shadow_enabled = true
	torch.shadow_bias = 0.04
	torch.light_size = 0.03
	# A teammate's beam is the same lamp with the same shadow: on the
	# Compatibility renderer it stripes the walls the same way, and it is
	# shaped and biased the same way to stop it (hotel_player.PLAIN_BEAM).
	if PLAYER.plain_beam(): PLAYER.shape_plain_beam(torch)
	torch.position = Vector3(0.24, -0.3, -0.25)
	camera.add_child(torch)
	step_voice = AudioStreamPlayer3D.new()
	step_voice.bus = "Effects"
	step_voice.max_distance = 26.0
	step_voice.unit_size = 3.0
	step_voice.area_mask = 512
	add_child(step_voice)
	add_to_group("hotel_players")

## Dead players do not stand in doorways or corridors any more.
func set_dead(value: bool) -> void:
	if dead == value: return
	dead = value
	# Its body is left where it fell, as it fell (the avatar lies until it is
	# stood up again, avatar_visual.fallen), and is in nobody's way: nothing
	# collides with it, the creature least of all. Somebody counted dead who
	# never fell -- gone from the match on their feet -- leaves no body: it
	# would be one standing there.
	visible = not value or (avatar != null and avatar.fallen)
	collision_layer = 0 if value else 4
	# Up again: however an execution left the body lying, it stands.
	if not value and avatar != null: avatar.end_capture()
	if value:
		# A wardrobe it died in (dropped out while hiding) is empty again: kept
		# taken, nobody could get in and the creature kept searching it.
		if is_instance_valid(hiding_place) and hiding_place.holds(self): hiding_place.leave(self)
		hidden = false
		hiding_place = null
		torch.visible = false

## One state from the owner (see match_net.gd pack_local).
func push_state(data: Array) -> void:
	if ride_hold > 0.0:
		if (data[0] as Vector3).distance_to(ride_point) > 3.0:
			away = false
			return
		ride_hold = 0.0
	states.append({"time": clock, "position": data[0], "yaw": data[1], "pitch": data[2], "velocity": data[3]})
	while states.size() > 12: states.pop_front()
	var flags: int = data[4]
	crouched = flags & 1 != 0
	# In the creature's hands its torch is on the floor (executions.drop_torch).
	torch.visible = flags & 2 != 0 and not hidden and not (level != null and not level.execution.is_empty() and int(level.execution.seat) == slot)
	reading = flags & 8 != 0
	peek_left = data[6]
	peek_right = data[7]
	if hidden and is_instance_valid(hiding_place):
		# Past 1 it is not a peek: both doors eased open to leave quietly
		# (match_net.pack_local).
		if peek_left > 1.0:
			hiding_place.set_peek(0.0, 0.0, self)
			hiding_place.set_ease(peek_left - 1.0, self)
		else:
			hiding_place.set_ease(0.0, self)
			hiding_place.set_peek(peek_left, peek_right, self)
	away = false

## Its mind has gone, or come back. Nothing shows on the body: only the
## creature senses it.
var burnt := false
func set_burnt(on: bool) -> void:
	burnt = on

## Snap straight to a position (spawn, or a teammate returning).
func place(point: Vector3, yaw: float) -> void:
	global_position = point
	rotation.y = yaw
	states.clear()
	ride_hold = 0.0

## Carried by a lift. Its owner only moves its own body half-way through the
## ride and keeps sending the old car until then: those states are older than
## the ride and are dropped, or the puppet jumped back into the car and out
## again -- and on the host stood there to be caught.
const RIDE_HOLD := 3.0
var ride_hold := 0.0
var ride_point := Vector3.ZERO
func ride_to(point: Vector3) -> void:
	place(point, rotation.y)
	ride_point = point
	ride_hold = RIDE_HOLD

func _physics_process(delta: float) -> void:
	clock += delta
	ride_hold = maxf(0.0, ride_hold - delta)
	# In the creature's hands the body is the scene's to put and to pose
	# (executions.place_victim): the states its owner goes on sending are of a
	# body that is not its own to move.
	if level != null and not level.execution.is_empty() and int(level.execution.seat) == slot and not dead:
		velocity = Vector3.ZERO
		states.clear()
		return
	# Caught in the same wardrobe as the one in the creature's hands, it dies
	# with them, and while the scene lasts it is not seen at all: its own
	# machine plays the scene with it as the victim and goes on sending where
	# that puts it -- the same place as the one everybody else sees taken.
	if level != null and not level.execution.is_empty() and int(level.execution.get("partner", -1)) == slot and not dead:
		velocity = Vector3.ZERO
		states.clear()
		avatar.visible = false
		return
	if dead or states.is_empty():
		velocity = Vector3.ZERO
		if dead:
			visible = avatar.fallen
			avatar.visible = true
		avatar.update_pose(Vector3.ZERO, crouched, delta)
		return
	# Interpolate between the two states around (now - DELAY).
	var wanted := clock - DELAY
	var before: Dictionary = states[0]
	var after: Dictionary = states[states.size() - 1]
	for i in range(states.size() - 1):
		if states[i].time <= wanted and states[i + 1].time >= wanted:
			before = states[i]
			after = states[i + 1]
			break
	var span: float = maxf(after.time - before.time, 0.001)
	var t := clampf((wanted - before.time) / span, 0.0, 1.0)
	var previous := global_position
	var target: Vector3 = before.position.lerp(after.position, t)
	# A long jump (respawn, wardrobe) is taken at once.
	global_position = target if target.distance_to(previous) > 3.0 else target
	rotation.y = lerp_angle(before.yaw, after.yaw, t)
	pitch = lerpf(before.pitch, after.pitch, t)
	camera.position.y = 0.9 if crouched else 1.64
	camera.rotation.x = pitch
	velocity = before.velocity.lerp(after.velocity, t)
	avatar.visible = not hidden
	# A puppet has no floor under it: it is on the ground unless it is clearly
	# going up or coming down.
	avatar.update_pose(velocity if not hidden else Vector3.ZERO, crouched, delta, absf(velocity.y) < 1.2)
	update_steps(previous, delta)

## Footsteps from the distance walked, quieter crouched, louder running.
func update_steps(previous: Vector3, _delta: float) -> void:
	var moved := Vector2(global_position.x - previous.x, global_position.z - previous.z).length()
	if moved > 1.0 or hidden or dead: return
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar < 0.3: return
	var running := planar > 4.6
	step_distance += moved
	var stride := 2.0 / 1.5 if crouched else 6.0 / 2.5 if running else 3.8 / 2.0
	if step_distance < stride: return
	step_distance = 0.0
	if level == null or not level.world_audio.enabled: return
	var room := FLOOR.room_at(level.manifest.rooms, global_position)
	var hard := not room.is_empty() and int(room.type) in FLOOR.HARD_FLOORS
	var set_name := "hard_walk" if hard else "carpet_run" if running and not crouched else "carpet_walk"
	var clips: Array = STEPS.SETS[set_name]
	var clip: Array = clips[randi() % clips.size()]
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 0.2, get_rid())
	if not route.audible: return
	step_voice.stream = load(clip[0])
	# Kept under the creature's own noises: a teammate running is not a threat.
	level.world_audio.apply_route(step_voice, route, (-29.0 if crouched else -13.0 if running else -19.0) + (2.0 if hard else 0.0), "Effects")
	step_voice.play(maxf(0.0, clip[1] - 0.02))
