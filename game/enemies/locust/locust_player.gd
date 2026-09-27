extends Node
## Versus: a player is The Locust. Drives the creature's body from this
## machine's input with a camera over its shoulder, while every other machine
## shows it as a puppet. Its strikes are only requests: the host decides who,
## if anyone, they hit (match_net.gd), with the same reach and line of sight
## the AI uses.
##
## Controls: move and look as usual; sprint hunts at full speed while its
## hunting stamina lasts; left button (right trigger) strikes; right button
## (left trigger) shrieks; Q (the torch button) lays the way to the nearest lit
## set; interact opens doors and pulls wardrobes open. Noises survivors make
## within its hearing show in its acoustic view as clouds of grains
## (echo_view.gd), and so does what the floor guides it with: the way to the
## lift in blue, the lit sets and the way to one of them in yellow.
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
## Seconds from one shriek to the next, counted from when it starts. The cry
## lasts about six, so it can no longer be chained: at three it could, and a
## hunter holding the button never stopped crying.
const SHRIEK_COOLDOWN := 10.0
## Q: the way to the nearest lit set it can walk to, laid out in yellow for
## TRACE_TIME seconds, once every TRACE_COOLDOWN seconds from when it is asked
## for. Only a set on its own floor: one above or below is no way to walk to.
const TRACE_TIME := 15.0
const TRACE_COOLDOWN := 20.0
## Wardrobes within this distance can be pulled open.
const WARDROBE_REACH := 2.6
const ECHO := preload("res://game/enemies/locust/echo_view.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## The same pad in the hands as the survivor's (pad_feel.gd): its look, and
## the hunt flipped on with the stick's click rather than held.
const PAD_FEEL := preload("res://game/player/pad_feel.gd")
var pad := PAD_FEEL.new()
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
var trace_left := 0.0
var trace_cooldown := 0.0
## The set the trace leads to (an index into level.televisions), or -1.
var trace_target := -1
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
## Travelling by television. With the channels open the sets it could step out
## of are laid out by where they really are, relative to each other and to
## nothing else, on a compass lying on the floor (camcorder_osd). Turning its
## head picks one; interacting again steps through.
var channel_open := false
var channel_target := -1
## The farthest set sits this far in from the rim of the compass, and a map of
## sets all close by is not blown up past CHANNEL_LEAST metres to the rim.
const CHANNEL_MARGIN := 1.15
const CHANNEL_LEAST := 12.0

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
	# Open leaves (128) too: the creature walks past them, its camera does not
	# go into the wood.
	arm.collision_mask = 1 | 8 | 128
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
	# Far enough to take in the whole floor: the motes of a burnt-out mind
	# reach it from anywhere, and a clipped camera would make that a lie. The
	# reading itself still only goes as far as REACH.
	camera.far = 240.0
	arm.add_child(camera)
	camera.position = Vector3(0, 0, ARM)
	creature.camera = camera
	# It does not see the hotel: it clicks and rebuilds it.
	echo = ECHO.new()
	add_child(echo)
	echo.setup(self)

func _unhandled_input(event: InputEvent) -> void:
	if not can_act(): return
	pad.pressed(event, level.settings)
	# On a pad the torch button asks for the trace: the creature has no torch.
	if event is InputEventJoypadButton and event.pressed and event.is_action("flashlight"):
		trace()
		return
	if event is InputEventMouseMotion:
		var sensitivity: float = level.settings.values.sensitivity
		look_by(Vector2(-event.relative.x, -event.relative.y) * sensitivity)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: strike()
		elif event.button_index == MOUSE_BUTTON_RIGHT: shriek()

func can_act() -> bool:
	return active and creature.control == "player" and level.session.state == level.session.State.PLAYING and not level.online_menu

## Called from the creature's physics step.
## Turning, from the mouse or from the stick. Holding a victim, or pulling a
## wardrobe open, it does not turn: the victim hangs where it faces, and used
## to be swung round with it.
func look_by(amount: Vector2) -> void:
	if creature.mode not in [creature.Mode.EXECUTE, creature.Mode.WARDROBE]: creature.rotation.y += amount.x
	pitch = clampf(pitch + amount.y * (-1.0 if level.settings.values.invert else 1.0), -1.1, 0.6)
	if is_instance_valid(pivot): pivot.rotation.x = pitch

## The right stick, like the survivor's (hotel_player.pad_look), every drawn
## frame.
func pad_look(delta: float) -> void:
	if not can_act() or level.settings == null:
		pad.stick = Vector2.ZERO
		return
	var turn := pad.look(delta, level.settings)
	if turn != Vector2.ZERO: look_by(turn)

func _process(delta: float) -> void:
	if creature != null and level != null: pad_look(delta)

func drive(delta: float) -> void:
	creature.count_grace(delta)
	creature.state_time += delta
	cooldown = maxf(0.0, cooldown - delta)
	shriek_cooldown = maxf(0.0, shriek_cooldown - delta)
	trace_cooldown = maxf(0.0, trace_cooldown - delta)
	trace_left = maxf(0.0, trace_left - delta)
	if can_act():
		if pressed("locust_trace"): trace()
		if pressed("locust_strike"): strike()
		if pressed("locust_shriek"): shriek()
	pivot.rotation.x = pitch
	place_shoulder(delta)
	var free: bool = can_act() and creature.grace <= 0.0
	var axis := Input.get_vector("left", "right", "forward", "backward") if free else Vector2.ZERO
	frenzy = maxf(0.0, frenzy - delta)
	# With the floor dark there is no limit to the hunt: it has nothing left to
	# fear and nothing to spend.
	var free_hunt: bool = frenzy > 0.0 or level.session.goal.get("blackout", false)
	var hunting := free and axis.length() > 0.1 and pad.wants("sprint", level.settings) and (stamina > 0.0 or free_hunt)
	pad.settle(axis.length() > 0.1, not free or (stamina <= 0.0 and not free_hunt), delta)
	if hunting:
		if not free_hunt: stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
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
			# Through set_mode, not by hand: the chase's kick-off speed and its
			# voice hang off it, and assigning the mode skipped both, which is
			# why a human hunter only ever sounded when it shrieked.
			if creature.mode != wanted_mode: creature.set_mode(wanted_mode)
			# It grunts running at somebody, not running: sprinting down an empty
			# corridor it only told everybody where it was for nothing.
			if hunting and creature.seen_survivor() != null: creature.chase_voice(delta)
			open_doors(hunting, heading)
	update_channels()
	creature.update_visual(delta)
	creature.visual.look_point = camera.global_position - camera.global_basis.z * 10.0
	if is_instance_valid(echo): echo.advance(delta, hunting)
	# Not mid-strike either: E after a click stepped it out of another set and
	# the blow was judged there, on whoever had just switched that one on.
	if free and Input.is_action_just_pressed("interact") and creature.mode not in [creature.Mode.WARDROBE, creature.Mode.EXECUTE, creature.Mode.WINDUP, creature.Mode.RECOVER]: use()
	update_hud()
	var now := Time.get_ticks_msec() / 1000.0
	heard = heard.filter(func(entry): return now - entry.time < 1.6)

## The map of lit sets, laid out by where they are in the world and nothing
## else: no rooms, no walls, no numbers. It is a compass lying on the floor,
## turned with the creature: ahead is the far side of the disk, and the one it
## is looking most directly towards is the one it would step out of. The
## whole map fits inside it, the farthest set near the rim. It used to be a
## fixed 70 m to the rim, drawn flat and not turned: far sets fell off the
## screen, and the one chosen was a line going out of the picture.
func update_channels() -> void:
	if not channel_open or not can_act():
		if not channel_open: level.camcorder.show_channels([], 0.0, -1)
		channel_open = false
		return
	var here: int = level.creature_at_television()
	var lit: Array = level.lit_televisions()
	if here < 0 or lit.size() < 2:
		channel_open = false
		level.camcorder.show_channels([], 0.0, -1)
		return
	var origin: Vector3 = level.televisions[here].global_position
	var look: Vector3 = -camera.global_basis.z
	# Ahead and to the right on the floor. Looking straight down, ahead is
	# where the top of the picture points.
	var ahead := Vector2(look.x, look.z)
	if ahead.length() < 0.05: ahead = Vector2(camera.global_basis.y.x, camera.global_basis.y.z)
	ahead = ahead.normalized()
	var right := Vector2(-ahead.y, ahead.x)
	# How much of the disk is seen: none of it level with the horizon (a
	# line), all of it looking down at its feet (a circle).
	var tilt := clampf(-look.y, 0.0, 1.0)
	var span := CHANNEL_LEAST
	for index in lit:
		var offset: Vector3 = level.televisions[index].global_position - origin
		span = maxf(span, Vector2(offset.x, offset.z).length() * CHANNEL_MARGIN)
	var points: Array = []
	var best := -1.0
	channel_target = -1
	for index in lit:
		var offset: Vector3 = level.televisions[index].global_position - origin
		var plane := Vector2(offset.x, offset.z)
		# On the disk: across to the right, and up the picture for ahead.
		points.append({"index": index, "at": Vector2(plane.dot(right), -plane.dot(ahead)) / span, "here": index == here})
		if index == here: continue
		var aim: float = ahead.dot(plane.normalized())
		if aim > best:
			best = aim
			channel_target = index
	level.camcorder.show_channels(points, tilt, channel_target)

## The spring arm only guards the length behind it, so the sideways step to
## the shoulder is checked here: against a wall it comes in, never through.
func place_shoulder(delta: float) -> void:
	var from: Vector3 = pivot.global_position
	var side: Vector3 = pivot.global_basis.x * SHOULDER
	var query := PhysicsRayQueryParameters3D.create(from, from + side, 1 | 8 | 128)
	query.exclude = [creature.get_rid()]
	var hit: Dictionary = creature.get_world_3d().direct_space_state.intersect_ray(query)
	var room: float = SHOULDER if hit.is_empty() else maxf(0.0, from.distance_to(hit.position) - 0.3)
	# In at once (a wall must never be crossed), back out gently.
	arm.position.x = room if room < arm.position.x else move_toward(arm.position.x, room, 2.0 * delta)

## Walking into a closed door eases it open; hunting slams it.
func open_doors(hunting: bool, heading: Vector3) -> void:
	if heading.length() < 0.1: return
	for door in level.hotel.doors:
		# A locked one would be asked for every frame it stood near, for nothing:
		# on a guest that was a request over the network each time.
		if door.opened or door.moving or door.locked: continue
		var offset: Vector3 = door.doorway - creature.global_position
		# The door straight overhead is on another planta.
		if absf(offset.y) > 2.0: continue
		offset.y = 0.0
		if offset.length() < (2.4 if hunting else 1.8) and heading.dot(offset.normalized()) > 0.3:
			level.match_net.use_door(door, not hunting, hunting)

func strike() -> void:
	# Not out of a kill or a wardrobe either: a click there dropped what it was
	# doing and walked off with the victim held in the air.
	if cooldown > 0.0 or creature.grace > 0.0 or creature.mode in [creature.Mode.WINDUP, creature.Mode.RECOVER, creature.Mode.EXECUTE, creature.Mode.WARDROBE]: return
	cooldown = COOLDOWN
	struck = false
	creature.set_mode(creature.Mode.WINDUP)

## The shriek gives away where it is, and in exchange it listens: for a few
## seconds the survivors within earshot show on screen, and if any of them is
## near, hunting costs nothing for a while.
func shriek() -> void:
	if shriek_cooldown > 0.0 or creature.grace > 0.0 or creature.mode in [creature.Mode.WARDROBE, creature.Mode.EXECUTE]: return
	shriek_cooldown = SHRIEK_COOLDOWN
	# The cry lasts exactly as long as the red it floods the reading with, and
	# fades out with it.
	creature.howl(ECHO.SHRIEK_HOLD, 1.0 / ECHO.SHRIEK_FALL)
	# The reading floods red and one enormous shell goes out with the cry.
	if is_instance_valid(echo): echo.flash_shriek()
	level.match_net.locust_shriek()

func pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)

## The blue way: to the car it has to take while the survivors have gone on
## without it (lifts.creature_car), from where it stands. Worked out on this
## machine, which has the same floor, stage and cars as the one that runs it,
## so nothing is sent for it. Empty while it is on the floor being played.
## It replaces a road of grains sent once when the stage closed, which lasted
## three seconds and only had room for its last stretch: the hunter saw a few
## noises round the car and the last doors, and no way to them.
func lift_route() -> PackedVector3Array:
	var car: int = level.lifts.creature_car(level.session.stage)
	if car < 0 or car >= level.hotel.lifts.size(): return PackedVector3Array()
	return FLOOR.navigation_path(creature.get_world_3d().navigation_map, creature.global_position, level.hotel.lifts[car])

## The car it has to take is up there, and the route's end beats until it is
## back down for it (lifts.creature_may_ride: it waits at the doors as well).
func lift_away_now() -> bool:
	var car: int = level.lifts.creature_car(level.session.stage)
	return car >= 0 and not level.lifts.creature_may_ride(car)

## Q. Nothing lit on its floor: a dull note, and nothing spent.
func trace() -> void:
	if not can_act() or trace_cooldown > 0.0 or creature.grace > 0.0: return
	var best := nearest_lit_set()
	if best < 0:
		level.ui.keypad("wrong")
		return
	trace_target = best
	trace_left = TRACE_TIME
	trace_cooldown = TRACE_COOLDOWN

## The lit set of the stage it can walk to soonest, measured along the floor,
## not through the walls; -1 when there is none it can reach from here.
func nearest_lit_set() -> int:
	var map: RID = creature.get_world_3d().navigation_map
	var best := -1
	var shortest := INF
	for index in level.lit_televisions():
		var goal := set_front(index)
		var route := FLOOR.navigation_path(map, creature.global_position, goal)
		if route.size() < 2 or route[route.size() - 1].distance_to(goal) > 1.5: continue
		var length := 0.0
		for i in range(1, route.size()): length += route[i].distance_to(route[i - 1])
		if length < shortest:
			shortest = length
			best = index
	return best

## Where it stands to use a set: in front of the screen, on floor it can
## stand on (as hotel_main.warp_creature puts it down).
func set_front(index: int) -> Vector3:
	var set = level.televisions[index]
	var facing: Vector3 = set.global_basis.z
	facing.y = 0.0
	var out: Vector3 = set.global_position + facing.normalized() * 1.6
	return FLOOR.closest(creature.get_world_3d().navigation_map, out)

## The yellow way, while it lasts: to the set it asked for, from where it
## stands. Over once it gets there, or if the set goes out.
func trace_route() -> PackedVector3Array:
	if trace_left <= 0.0 or trace_target < 0 or trace_target >= level.televisions.size(): return PackedVector3Array()
	var set = level.televisions[trace_target]
	if not is_instance_valid(set) or not set.on or set.global_position.distance_to(creature.global_position) < level.WARP_REACH:
		trace_left = 0.0
		return PackedVector3Array()
	return FLOOR.navigation_path(creature.get_world_3d().navigation_map, creature.global_position, set_front(trace_target))

## Every lit set of the stage, as [screen centre, half its width, half its
## height] in the world: they burn yellow in its reading from anywhere.
func lit_screens() -> Array:
	var out: Array = []
	for index in level.lit_televisions():
		var set = level.televisions[index]
		if not is_instance_valid(set): continue
		out.append([set.screen_point(), set.global_basis.x * (set.SCREEN_SIZE.x * 0.5), set.global_basis.y * (set.SCREEN_SIZE.y * 0.5)])
	return out

## The power has gone: nothing is written on screen, the ceilings that were
## there simply come back at it in one burst, from every side at once, and the
## hunt stops costing anything (drive()).
func mark_blackout() -> void:
	if not is_instance_valid(echo): return
	var points := PackedVector3Array()
	var here: Vector3 = creature.global_position
	for i in 14:
		var angle := TAU * float(i) / 14.0
		points.append(here + Vector3(cos(angle), 0, sin(angle)) * (4.0 + float(i % 3) * 2.5) + Vector3(0, 2.6, 0))
	echo.mark_found(points)

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

## Interact: step through the channels if they are open, open them at a lit
## set, or else the door ahead or the wardrobe in front.
func use() -> void:
	if channel_open:
		if channel_target >= 0: level.match_net.locust_warp(channel_target)
		channel_open = false
		return
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * (ARM + 3.2), 1 | 8 | 16)
	query.collide_with_areas = true
	query.exclude = [creature.get_rid()]
	var space: PhysicsDirectSpaceState3D = creature.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	var target = null if hit.is_empty() else hit.collider
	if target != null and target in level.hotel.doors and target.doorway.distance_to(creature.global_position) < 3.4:
		level.match_net.use_door(target, false, false)
	elif target != null and target in level.hotel.hides and target.global_position.distance_to(creature.global_position) < WARDROBE_REACH + 0.8:
		# The ritual: it plants itself and opens the wardrobe leaf by leaf.
		creature.begin_wardrobe(target)
		level.match_net.locust_open_hide(target)
	# Nothing it is looking at to open: at a lit set, the way through it. It
	# used to come first, so beside a lit set E never opened the wardrobe it
	# was aimed at -- the one somebody had just hidden in after switching the
	# set on.
	elif level.creature_at_television() >= 0 and level.lit_televisions().size() > 1:
		channel_open = true
		channel_target = -1

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
	level.camcorder.set_cooldowns(shriek_cooldown / SHRIEK_COOLDOWN, trace_cooldown / TRACE_COOLDOWN)
	# The lift it has to take: a dial emptying until it may ride it.
	var car: int = level.lifts.creature_car(level.session.stage)
	var wait: Vector2 = level.lifts.creature_wait(car) if car >= 0 else Vector2.ZERO
	level.camcorder.set_lift_wait(wait.x / wait.y if wait.x > 0.0 and wait.y > 0.0 else 0.0, wait.x)
	level.camcorder.announce("LA CAZA EMPIEZA EN %d" % int(ceil(creature.grace)) if creature.grace > 0.0 else "")
	var now := Time.get_ticks_msec() / 1000.0
	revealed = revealed.filter(func(entry): return now - entry.time < 1.2)
