extends Node
## Versus: a player is The Locust. Drives the creature's body from this
## machine's input with a camera over its shoulder, while every other machine
## shows it as a puppet. Its strikes are only requests: the host decides who,
## if anyone, they hit (match_net.gd), with the same reach and line of sight
## the AI uses.
##
## Controls: move and look as usual; sprint hunts at full speed while its
## hunting stamina lasts; left button strikes; right button shrieks; interact
## opens doors and pulls wardrobes open. Noises survivors make within its
## hearing show in its acoustic view as clouds of grains (echo_view.gd).
const WALK_SPEED := 2.8
const HUNT_SPEED := 6.4
## Hunting lasts long and comes back quickly: a survivor cannot simply outrun
## it, only break its line of sight or hide well.
const STAMINA_DRAIN := 6.5
const STAMINA_RECOVERY := 22.0
const RECOVERY_DELAY := 0.6
## Shrieking with someone near: seconds of free hunting and stamina back.
const FRENZY_TIME := 6.0
const FRENZY_STAMINA := 30.0
## A strike: the same wind-up and recovery as the AI's.
const COOLDOWN := 1.2
const SHRIEK_COOLDOWN := 3.0
## Wardrobes within this distance can be pulled open.
const WARDROBE_REACH := 2.6
const ECHO := preload("res://game/enemies/locust/echo_view.gd")
const EYE := Vector3(0.0, 2.35, 0.0)
const ARM := 2.8
## How far to the side the camera rides. Far enough that the middle of the
## screen, where it turns to look at what it heard, is not its own head.
const SHOULDER := 1.0
## Route metres within which a noise is placed where it happened, and beyond
## which only the opening it arrived through is known. In between it slides:
## close by you know where, far away you only know which way.
const CONTACT_TRUTH := 8.0
const CONTACT_BLUR := 14.0
var creature
var level
var camera: Camera3D
## The acoustic image: everything this player actually sees (echo_view.gd).
var echo
var pivot: Node3D
var arm: SpringArm3D
var pitch := -0.2
var stamina := 100.0
var recovery := 0.0
var cooldown := 0.0
var shriek_cooldown := 0.0
var struck := false
## Heard noises, as the creature hears them:
## {id, point, apparent, at, time, strength, kind, distance, muffle, blur}.
## The id only counts up, so the acoustic view can tell which ones it has
## already turned into a puff of grains.
var heard: Array = []
var heard_count := 0
## Where the shriek placed the survivors it found, and its free hunting time.
var revealed: Array = []
var frenzy := 0.0
var active := true

func setup(owner) -> void:
	creature = owner
	level = owner.level
	name = "Driver"
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	pivot.position = EYE
	creature.add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = ARM
	arm.collision_mask = 1 | 8
	arm.margin = 0.2
	arm.position = Vector3(SHOULDER, 0, 0)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	arm.shape = sphere
	arm.add_excluded_object(creature.get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.name = "HunterCamera"
	camera.fov = 74.0
	camera.far = 95.0
	arm.add_child(camera)
	camera.position = Vector3(0, 0, ARM)
	creature.camera = camera
	# It does not see the hotel: it clicks and rebuilds it.
	echo = ECHO.new()
	add_child(echo)
	echo.setup(self)

func _unhandled_input(event: InputEvent) -> void:
	if not can_act(): return
	if event is InputEventMouseMotion:
		var sensitivity: float = level.settings.values.sensitivity
		creature.rotation.y -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity * (-1 if level.settings.values.invert else 1), -1.1, 0.6)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: strike()
		elif event.button_index == MOUSE_BUTTON_RIGHT: shriek()

func can_act() -> bool:
	return active and creature.control == "player" and level.session.state == level.session.State.PLAYING and not level.online_menu

## Called from the creature's physics step.
func drive(delta: float) -> void:
	creature.grace = maxf(0.0, creature.grace - delta)
	creature.state_time += delta
	cooldown = maxf(0.0, cooldown - delta)
	shriek_cooldown = maxf(0.0, shriek_cooldown - delta)
	pivot.rotation.x = pitch
	place_shoulder(delta)
	var free: bool = can_act() and creature.grace <= 0.0
	var axis := Input.get_vector("left", "right", "forward", "backward") if free else Vector2.ZERO
	frenzy = maxf(0.0, frenzy - delta)
	var hunting := free and axis.length() > 0.1 and Input.is_action_pressed("sprint") and (stamina > 0.0 or frenzy > 0.0)
	if hunting:
		if frenzy <= 0.0: stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		recovery = RECOVERY_DELAY
	else:
		recovery = maxf(0.0, recovery - delta)
		if recovery <= 0.0: stamina = minf(100.0, stamina + STAMINA_RECOVERY * delta)
	match creature.mode:
		creature.Mode.WARDROBE:
			creature.update_wardrobe(delta)
		creature.Mode.EXECUTE:
			creature.update_execution(delta)
		creature.Mode.WINDUP:
			# The lunge carries it forward; the host judges the hit at the end.
			var forward: Vector3 = -creature.global_basis.z
			creature.velocity = Vector3(forward.x * HUNT_SPEED * 1.15, -2.0, forward.z * HUNT_SPEED * 1.15)
			creature.move_and_slide()
			if creature.state_time >= creature.WINDUP_TIME and not struck:
				struck = true
				level.match_net.locust_strike(creature.global_position, -creature.global_basis.z)
				# Where this machine judges the strike, a hit has already begun
				# the execution: recovering would cut it short.
				if creature.mode == creature.Mode.WINDUP: creature.set_mode(creature.Mode.RECOVER)
		creature.Mode.RECOVER:
			creature.velocity = Vector3.ZERO
			if creature.state_time >= creature.RECOVER_TIME: creature.set_mode(creature.Mode.CHASE if hunting else creature.Mode.PATROL)
		_:
			var body_basis: Basis = creature.global_basis
			var direction := (body_basis * Vector3(axis.x, 0, axis.y)).normalized()
			var wanted: float = (HUNT_SPEED if hunting else WALK_SPEED) * minf(axis.length(), 1.0)
			creature.speed = move_toward(creature.speed, wanted, (creature.CHASE_ACCELERATION if wanted > creature.speed else 9.0) * delta)
			var heading := direction if direction.length() > 0.1 else Vector3.ZERO
			creature.velocity.x = heading.x * creature.speed
			creature.velocity.z = heading.z * creature.speed
			creature.velocity.y = -2.0 if creature.is_on_floor() else creature.velocity.y - 20.0 * delta
			creature.move_and_slide()
			var wanted_mode: int = creature.Mode.CHASE if hunting else creature.Mode.PATROL
			if creature.mode != wanted_mode: creature.mode = wanted_mode
			open_doors(hunting, heading)
	creature.update_visual(delta)
	creature.visual.look_point = camera.global_position - camera.global_basis.z * 10.0
	if is_instance_valid(echo): echo.advance(delta, hunting)
	if free and Input.is_action_just_pressed("interact") and creature.mode not in [creature.Mode.WARDROBE, creature.Mode.EXECUTE]: use()
	update_hud()
	var now := Time.get_ticks_msec() / 1000.0
	heard = heard.filter(func(entry): return now - entry.time < 1.6)

## The spring arm only guards the length behind it, so the sideways step to
## the shoulder is checked here: against a wall it comes in, never through.
func place_shoulder(delta: float) -> void:
	var from: Vector3 = pivot.global_position
	var side: Vector3 = pivot.global_basis.x * SHOULDER
	var query := PhysicsRayQueryParameters3D.create(from, from + side, 1 | 8)
	query.exclude = [creature.get_rid()]
	var hit: Dictionary = creature.get_world_3d().direct_space_state.intersect_ray(query)
	var room: float = SHOULDER if hit.is_empty() else maxf(0.0, from.distance_to(hit.position) - 0.3)
	# In at once (a wall must never be crossed), back out gently.
	arm.position.x = room if room < arm.position.x else move_toward(arm.position.x, room, 2.0 * delta)

## Walking into a closed door eases it open; hunting slams it.
func open_doors(hunting: bool, heading: Vector3) -> void:
	if heading.length() < 0.1: return
	for door in level.hotel.doors:
		if door.opened or door.moving: continue
		var offset: Vector3 = door.doorway - creature.global_position
		offset.y = 0.0
		if offset.length() < (2.4 if hunting else 1.8) and heading.dot(offset.normalized()) > 0.3:
			level.match_net.use_door(door, not hunting, hunting)

func strike() -> void:
	if cooldown > 0.0 or creature.grace > 0.0 or creature.mode in [creature.Mode.WINDUP, creature.Mode.RECOVER]: return
	cooldown = COOLDOWN
	struck = false
	creature.set_mode(creature.Mode.WINDUP)

## The shriek gives away where it is, and in exchange it listens: for a few
## seconds the survivors within earshot show on screen, and if any of them is
## near, hunting costs nothing for a while.
func shriek() -> void:
	if shriek_cooldown > 0.0 or creature.grace > 0.0 or creature.mode in [creature.Mode.WARDROBE, creature.Mode.EXECUTE]: return
	shriek_cooldown = SHRIEK_COOLDOWN
	creature.grunt()
	# The reading floods red and one enormous shell goes out with the cry.
	if is_instance_valid(echo): echo.flash_shriek()
	level.match_net.locust_shriek()

## Survivors the shriek found, from the host.
func reveal(points: PackedVector3Array) -> void:
	revealed = []
	var now := Time.get_ticks_msec() / 1000.0
	for point in points: revealed.append({"point": point, "time": now})
	# Marked in the image with a cloud that outlasts the cry by seconds.
	if is_instance_valid(echo): echo.mark_found(points)
	if not points.is_empty() and frenzy <= 0.0:
		frenzy = FRENZY_TIME
		stamina = minf(100.0, stamina + FRENZY_STAMINA)

## Interact: the door ahead, or the wardrobe in front.
func use() -> void:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * (ARM + 3.2), 1 | 8 | 16)
	query.collide_with_areas = true
	query.exclude = [creature.get_rid()]
	var space: PhysicsDirectSpaceState3D = creature.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty(): return
	var target = hit.collider
	if target in level.hotel.doors and target.doorway.distance_to(creature.global_position) < 3.4:
		level.match_net.use_door(target, false, false)
	elif target in level.hotel.hides and target.global_position.distance_to(creature.global_position) < WARDROBE_REACH + 0.8:
		# The ritual: it plants itself and opens the wardrobe leaf by leaf.
		creature.begin_wardrobe(target)
		level.match_net.locust_open_hide(target)

## A survivor's noise within its hearing, from the host (or measured locally
## when this machine is in charge). See match_net.tell_hunter.
func hear_contact(point: Vector3, apparent: Vector3, distance: float, strength: float, kind: int, muffle: float) -> void:
	# Where the image places it: the real spot up close, the opening it came
	# through further away, sliding between the two so nothing ever jumps.
	var blur := clampf((distance - CONTACT_TRUTH) / (CONTACT_BLUR - CONTACT_TRUTH), 0.0, 1.0)
	heard_count += 1
	heard.append({
		"id": heard_count, "point": point, "apparent": apparent, "at": point.lerp(apparent, blur),
		"time": Time.get_ticks_msec() / 1000.0, "strength": strength,
		"kind": kind, "distance": distance, "muffle": muffle, "blur": blur,
	})

## Older two-argument callers (and the tests): treated as a direct footstep.
func hear_noise(point: Vector3, radius: float) -> void:
	hear_contact(point, point, creature.global_position.distance_to(point), clampf(radius / 16.0, 0.25, 1.0), 0, 0.0)

func update_hud() -> void:
	# A clear view: no controls and no tape, only its hunting stamina and the
	# count to the start of the hunt, both in the camcorder's lettering and
	# under the same analog filter as the image (camcorder_osd.gd).
	level.ui.hint.text = ""
	level.camcorder.set_stamina(stamina / 100.0, stamina <= 0.0)
	level.camcorder.announce("LA CAZA EMPIEZA EN %d" % int(ceil(creature.grace)) if creature.grace > 0.0 else "")
	var now := Time.get_ticks_msec() / 1000.0
	revealed = revealed.filter(func(entry): return now - entry.time < 1.2)
