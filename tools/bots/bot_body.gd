extends "res://game/net/remote_player.gd"
## A test bot's survivor: a teammate's body (remote_player) that walks on its
## own feet. Everything that takes the other survivors of a match takes it --
## the creature sees, hears and strikes it, the lifts carry it, the wardrobes
## hold it, the mind wears down in the dark -- but it is not moved by states
## sent from another machine: it moves by the same rules as the local player
## (survivor_gait.gd), colliding with walls, shut doors and open leaves, and
## every footfall is a noise the creature may hear.
##
## Its brain (bot_brain.gd) only says what it wants: a direction, a pace,
## where to look and whether the torch is on.
const MOVEMENT := preload("res://game/player/survivor_gait.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
enum Pace { STILL, CROUCH, WALK, RUN }
## What the brain wants this frame.
var wish := Vector3.ZERO
var pace := Pace.WALK
## In a crawl space (the offices' main duct), set every tick; never backing out.
var crawling := false
var crawl_back := false
var look_yaw := 0.0
var look_pitch := 0.0
var torch_wanted := false
## How fast it turns its head and body round, radians per second: a person
## turns quickly, not at once, and the sweep is what it sees.
const TURN_RATE := 7.0
# The fields survivor_gait.gd works on, named as on the player.
var body_shape: CollisionShape3D
var stamina := 100.0
var recovery_delay := 0.0
var exhausted := false
var step_phase := 0.0
var hard_floor := false
var running := false
var floor_clock := 0.0
## A footfall, and whatever else it made heard, for the recording.
signal footfall(point: Vector3, radius: float)
## Out of the floor: under the lowest planta. The watchdog puts it back.
signal fell(point: Vector3)
var headless := true

func setup(owner_level, seat: int, words: String, character: int) -> void:
	super.setup(owner_level, seat, words, character)
	name = "Bot_%d" % seat
	# The player's own mask: walls, shut doors, the creature and open leaves.
	collision_mask = 1 | 8 | 32 | 128
	body_shape = get_node("BodyShape")
	# Its own capsule: crouching rewrites it, and the resource was shared.
	body_shape.shape = body_shape.shape.duplicate()
	headless = DisplayServer.get_name() == "headless"
	floor_max_angle = deg_to_rad(46.0)

## Nothing is sent to it: it is its own owner.
func push_state(_data: Array) -> void: pass

func place(point: Vector3, yaw: float) -> void:
	super.place(point, yaw)
	look_yaw = yaw
	velocity = Vector3.ZERO

## The lift moves it like anybody's body; it stays where it is put.
func ride_to(point: Vector3) -> void:
	place(point, rotation.y)

func _physics_process(delta: float) -> void:
	clock += delta
	if level == null or not is_instance_valid(level.session): return
	sync_life()
	if dead or level.session.state != level.session.State.PLAYING:
		velocity = Vector3.ZERO
		return
	# On the blade: out of any wardrobe and held up in front of it.
	if not level.execution.is_empty() and int(level.execution.seat) == slot:
		if hidden and is_instance_valid(hiding_place): level.match_net.remote_leaves(hiding_place, self)
		# Where it is held is the scene's to say (executions.place_victim).
		velocity = Vector3.ZERO
		return
	turn(delta)
	camera.position.y = 0.9 if crouched else 1.64
	camera.rotation.x = look_pitch
	torch.visible = torch_wanted and not hidden
	if hidden or level.lifts.riding.has(slot):
		velocity = Vector3.ZERO
		running = false
		return
	floor_clock -= delta
	if floor_clock <= 0.0:
		floor_clock = 0.25
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, global_position)
		hard_floor = not room.is_empty() and FLOOR.palette(level.manifest).hard_floor(room)
	var flat := Vector3(wish.x, 0, wish.z)
	if flat.length() > 1.0: flat = flat.normalized()
	if pace == Pace.STILL: flat = Vector3.ZERO
	# On all fours in the offices' main duct: crouched by force, the crawl's pace.
	crawling = level.crawling_at(global_position)
	MOVEMENT.set_crouch(self, pace == Pace.CROUCH or crawling)
	running = MOVEMENT.tire(self, pace == Pace.RUN and flat.length() > 0.1, delta)
	MOVEMENT.accelerate(self, flat, running, delta)
	move_and_slide()
	if not headless: avatar.update_pose(velocity, crouched, delta, is_on_floor())
	stride(delta)
	if global_position.y < FLOOR.planta_y(FLOOR.PLANTAS - 1) - 3.0: fell.emit(global_position)

## Body and head towards where the brain looks, at a person's pace.
func turn(delta: float) -> void:
	var gap := wrapf(look_yaw - rotation.y, -PI, PI)
	rotation.y += clampf(gap, -TURN_RATE * delta, TURN_RATE * delta)

## Footfalls from distance covered, as on the player: one per stride, each a
## noise the creature may hear.
func stride(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar <= 0.25 or not is_on_floor(): return
	var previous := floori(step_phase / PI)
	step_phase += planar / MOVEMENT.stride(crouched, running) * PI * delta
	if floori(step_phase / PI) == previous: return
	var heard := MOVEMENT.footfall(crouched, running, hard_floor)
	level.on_noise(global_position, heard.radius, heard.kind)
	footfall.emit(global_position, heard.radius)

## Its life is the session's: dead, it is put away; raised, it is back.
## Offline nothing else tells a body (match_net only does it online).
func sync_life() -> void:
	var life = level.session.participants.get(slot, level.session.Life.DEAD)
	set_dead(life == level.session.Life.DEAD)

## Into a wardrobe as a player gets in: seen doing it, the creature knows
## which (and, unlike with a player, is no surer that somebody is in it:
## creature.saw_enter); heard doing it, it comes to look.
func enter_wardrobe(hide: Node3D) -> bool:
	if hidden or dead or not hide.has_room(): return false
	var creature = level.creature
	if is_instance_valid(creature) and creature.control == "ai" and creature.sees(self, true): creature.saw_enter(hide, false)
	level.match_net.remote_enters(hide, self)
	global_position = hide.to_global(hide.inside_of(self))
	velocity = Vector3.ZERO
	rotation.y = hide.global_rotation.y + PI
	look_yaw = rotation.y
	look_pitch = 0.0
	level.on_noise(global_position, NOISE.radius("wardrobe"), NOISE.Kind.WARDROBE)
	footfall.emit(global_position, NOISE.radius("wardrobe"))
	return true

## Out again, if there is room outside the doors.
func leave_wardrobe() -> bool:
	if not hidden or not is_instance_valid(hiding_place): return false
	var point: Vector3 = hiding_place.available_exit(self)
	if point == Vector3.INF: return false
	var hide := hiding_place
	global_position = point
	level.match_net.remote_leaves(hide, self)
	level.on_noise(point, NOISE.radius("wardrobe"), NOISE.Kind.WARDROBE)
	footfall.emit(point, NOISE.radius("wardrobe"))
	return true

func mind() -> float:
	return float(level.sanity.minds.get(slot, {"sanity": 100.0}).sanity)
