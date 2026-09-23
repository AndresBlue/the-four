extends RefCounted
## One bot's head: it takes a task from the team (bot_team.gd) and does it
## with its body -- walks there along a threaded route, opens the doors in its
## way slowly, faces what it came for and uses it the way a player's hand
## would, through the same ray from the eye (hotel_main.focused_area) --, and
## gets itself out of wherever it is stuck, step by step, saying so each time
## (the watchdog's first half; bot_watchdog.gd has the rest).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NAV := preload("res://tools/bots/bot_nav.gd")
const BODY := preload("res://tools/bots/bot_body.gd")
const CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
enum State { IDLE, MOVE, DOOR, ACT, WAIT, UNSTICK, OUT, HIDDEN, SWEEP }
const STATE_NAMES := ["quieto", "va", "puerta", "usa", "espera", "desatasca", "fuera", "escondido", "mira"]
## Looking round a room from where it stands: to one side, the other, and
## behind -- with what it saw walking in, the whole way round (its view is a
## hundred degrees wide).
const SWEEP := [-1.22, 1.22, PI]
const SWEEP_LOOK := 0.6
## The reach of a hand, as the player's (hotel_main.focused_area).
const REACH := 2.0
const REACH_MASK := 1 | 8 | 16
## Holding the door before it gives, then how long its slow swing may take.
const DOOR_HOLD := 1.0
const DOOR_SWING := 3.0
## Standing this near the spot it was sent to is being there.
const ARRIVED := 0.35
## Keys of the keypad, one after the other.
const KEY_TIME := 0.35
## Stuck: less than STUCK_GAIN metres in STUCK_STEPS[level] seconds while it
## wants to move; or the route left not shorter by LINGER_GAIN in STUCK_LINGER.
## Free again this far from where it got stuck.
const STUCK_GAIN := 0.3
const STUCK_STEPS := [1.0, 1.5, 2.0, 3.0, 4.0]
const STUCK_LINGER := 8.0
const LINGER_GAIN := 0.5
const STUCK_FREE := 2.5
const HOP := 2.0
var level
var owner_match
var body
var nav
var seat := 0
var task := {}
var state := State.IDLE
var timer := 0.0
var door = null
var door_pressed := false
var door_wait := 0.0
var typed := ""
var clock := 0.0
## Which of the task's places to stand it is trying.
var stand_index := 0
## Why the last task was given up, for the team: "", "unreachable", "stuck".
var gave_up := ""
var stuck_clock := 0.0
var stuck_anchor := Vector3.INF
var stuck_origin := Vector3.INF
var stuck_level := 0
var linger_clock := 0.0
var linger_best := INF
var unstick_dir := Vector3.ZERO
var unstick_left := 0.0
var unstick_replan := false
var walked := 0.0
var last_position := Vector3.INF
## Where and when it last gave a task up for being stuck.
var gave_up_at := Vector3.INF
var gave_up_clock := -INF
## Seconds spent in each state, for the summary: where a slow floor went.
var state_seconds := {}
var sweep_from := 0.0

func _init(owner, bot_body) -> void:
	owner_match = owner
	level = owner.level
	body = bot_body
	seat = int(bot_body.slot)
	nav = NAV.new(level, bot_body)

func alive() -> bool:
	return not body.dead and level.session.participants.get(seat, level.session.Life.DEAD) != level.session.Life.DEAD

func planta() -> int: return FLOOR.planta_of(body.global_position.y)

## Riding, held on the blade, or dead: nothing to decide.
func out_of_play() -> bool:
	if not alive(): return true
	if level.lifts.riding.has(seat): return true
	return not level.execution.is_empty() and int(level.execution.seat) == seat

## A new task, or the same one again (then nothing changes).
func set_task(next: Dictionary) -> void:
	if not task.is_empty() and not next.is_empty() and String(task.get("key", "")) == String(next.get("key", "")):
		task.merge(next, true)
		return
	task = next
	stand_index = 0
	gave_up = ""
	typed = ""
	door = null
	reset_stuck()
	if task.is_empty():
		state = State.IDLE
		nav.clear()
		return
	state = State.MOVE
	nav.clear()

func stand() -> Vector3:
	var stands: Array = task.get("stands", [])
	if stands.is_empty(): return task.get("stand", body.global_position)
	return stands[clampi(stand_index, 0, stands.size() - 1)]

func tick(delta: float) -> void:
	clock += delta
	if is_finite(last_position.x): walked += Vector2(body.global_position.x - last_position.x, body.global_position.z - last_position.z).length()
	last_position = body.global_position
	if out_of_play():
		state = State.OUT
		halt()
		return
	if state == State.OUT: state = State.MOVE if not task.is_empty() else State.IDLE
	var named: String = STATE_NAMES[state]
	state_seconds[named] = float(state_seconds.get(named, 0.0)) + delta
	body.torch_wanted = wants_torch()
	minding = ""
	var took := mind_creature(delta)
	# Minding it for most of a minute with the errand not moving on: a
	# person takes the risk sooner or later, and so does a bot, for a while.
	if took and minding != "escondido": wary += delta
	else: wary = maxf(0.0, wary - delta * 0.75)
	if wary > WARY_LIMIT:
		wary = 0.0
		bold_until = clock + BOLD_FOR
		owner_match.note("audaz", self, {})
	# What the creature made it do, said when it changes (for the recording).
	if minding != minded:
		minded = minding
		owner_match.note("mente", self, {"value": minding})
	if took:
		state_seconds["criatura"] = float(state_seconds.get("criatura", 0.0)) + delta
		return
	match state:
		State.IDLE: halt()
		State.MOVE: move(delta)
		State.DOOR: open_door(delta)
		State.ACT: act(delta)
		State.WAIT: wait()
		State.UNSTICK: unstick(delta)
		State.SWEEP: sweep(delta)

func halt() -> void:
	body.wish = Vector3.ZERO
	body.pace = BODY.Pace.STILL

## Looking the way it goes, or at a point.
func face(point: Vector3) -> void:
	var gap: Vector3 = point - body.camera.global_position
	var flat := Vector2(gap.x, gap.z)
	if flat.length() > 0.05: body.look_yaw = atan2(-gap.x, -gap.z)
	body.look_pitch = clampf(atan2(gap.y, maxf(flat.length(), 0.05)), -1.2, 1.2)

## Glancing about while it walks, as a person does: the head goes a little
## to each side of the way it walks, which is what finds a note on a
## corridor's side wall.
const GAZE := 0.7
const GAZE_PERIOD := 3.2
func walk_towards(direction: Vector3, pace: int) -> void:
	body.wish = direction
	body.pace = pace
	if direction.length() > 0.1:
		var glance: float = sin(clock * TAU / GAZE_PERIOD + float(seat)) * GAZE if pace != BODY.Pace.RUN else 0.0
		body.look_yaw = atan2(-direction.x, -direction.z) + glance
		body.look_pitch = -0.12

# --- Going somewhere ------------------------------------------------------------

func move(delta: float) -> void:
	if clock < wait_until:
		halt()
		return
	var goal := stand()
	# A place on another planta is a task from before a lift: the team gives
	# another one on its next round.
	if FLOOR.planta_of(goal.y) != planta():
		halt()
		return
	if flat_gap(body.global_position, goal) < ARRIVED and absf(body.global_position.y - goal.y) < 1.5:
		arrive()
		return
	if not nav.active() or nav.stale() or clock - nav.planned_at > 2.0 or nav.target.distance_to(goal) > 0.05:
		if not nav.plan(goal, clock, null if bold() else owner_match.threat):
			give_up("unreachable", "sin ruta hasta %s" % describe())
			return
		# Every way there goes where the creature is or is going: not now,
		# and not asked again for a second.
		if nav.blocked and String(task.get("kind", "")) != "lift":
			halt()
			nav.clear()
			wait_until = clock + 1.0
			return
		if nav.end_gap > 1.2 and not try_next_stand("la ruta se queda a %.1f m" % nav.end_gap): return
	var shut = nav.door_ahead()
	if shut != null:
		if shut.locked:
			# The door on of a stage not met yet, or a gate: nothing to do here.
			halt()
			face(shut.doorway + Vector3(0, 1.4, 0))
			match String(task.get("kind", "")):
				"lift": pass
				# A door with a lock on the way to a room to look round: that
				# room is not for now, and there is nothing wrong in that.
				"explore":
					owner_match.team.room_blocked(int(task.get("room", -1)))
					set_task({})
				_: give_up("unreachable", "puerta cerrada con llave en la ruta a %s" % describe())
			return
		door = shut
		door_pressed = false
		timer = 0.0
		state = State.DOOR
		halt()
		return
	var direction: Vector3 = nav.steer()
	if direction == Vector3.ZERO:
		# The route is walked and the spot is still a step away: go straight.
		# Farther than that, the route stopped short of it: that is being stuck
		# too, and it climbs the same ladder.
		var straight := Vector3(goal.x - body.global_position.x, 0, goal.z - body.global_position.z)
		if straight.length() < 1.0: walk_towards(straight.normalized(), BODY.Pace.WALK)
		else:
			halt()
			nav.clear()
		watch_progress(delta)
		return
	var pace: int = owner_match.pace_for(self)
	# A look before the step: a metre and a half on would be in its line, and
	# here is not. Wait, and find the way again -- round, if there is one.
	var threat = owner_match.threat
	if threat.near_planta(body.global_position) and not bold():
		var ahead: Vector3 = body.global_position + direction * 1.5
		if threat.visible(ahead) and not threat.visible(body.global_position) or ahead_watched(ahead):
			halt()
			reset_stuck()
			nav.clear()
			wait_until = clock + 0.5
			return
	# Still on purpose, so as not to be heard: waiting, not stuck.
	if pace == BODY.Pace.STILL:
		halt()
		reset_stuck()
		return
	walk_towards(direction, pace)
	watch_progress(delta)

func flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func arrive() -> void:
	halt()
	reset_stuck()
	timer = 0.0
	var kind := String(task.get("kind", ""))
	if kind == "explore":
		sweep_from = body.rotation.y
		state = State.SWEEP
		return
	state = State.WAIT if kind in ["refuge", "lift", "goto", "hold"] else State.ACT

## Round the room with its eyes, a look at a time; then the room is done.
func sweep(delta: float) -> void:
	halt()
	timer += delta
	var look := int(timer / SWEEP_LOOK)
	if look >= SWEEP.size():
		# The next place in the room to look round from, if there is one.
		var stops: Array = task.get("stops", [])
		if not stops.is_empty():
			task["stands"] = [stops[0]]
			task["stops"] = stops.slice(1)
			stand_index = 0
			nav.clear()
			state = State.MOVE
			return
		owner_match.team.room_cleared(self, int(task.get("room", -1)))
		set_task({})
		return
	body.look_yaw = sweep_from + float(SWEEP[look])
	body.look_pitch = -0.25

## The next place to stand for this task, or giving it up.
func try_next_stand(why: String) -> bool:
	var stands: Array = task.get("stands", [])
	if stand_index + 1 < stands.size():
		stand_index += 1
		nav.clear()
		return false
	if String(task.get("kind", "")) in ["refuge", "lift", "goto", "hold", "explore"]: return true
	give_up("unreachable", "%s: %s" % [describe(), why])
	return false

func give_up(why: String, words: String) -> void:
	owner_match.report("inalcanzable" if why == "unreachable" else "tarea_abandonada", "media", self, words)
	gave_up = why
	owner_match.team.drop(self, task, why)
	task = {}
	state = State.IDLE
	nav.clear()
	halt()

func describe() -> String:
	return String(task.get("label", task.get("kind", "?")))

# --- Doors ------------------------------------------------------------------------

## A shut door in the way: held a second so it swings slowly -- the quiet way,
## a noise heard at 9 m and not 45 --, then through it on a new route.
func open_door(delta: float) -> void:
	halt()
	if not is_instance_valid(door):
		state = State.MOVE
		return
	face(door.doorway + Vector3(0, 1.2, 0))
	timer += delta
	if door.opened and not door.moving:
		door = null
		nav.clear()
		state = State.MOVE
		return
	if not door_pressed:
		if door.moving:
			if timer > DOOR_SWING: owner_match.report("puerta", "leve", self, "una puerta que no termina de moverse")
			return
		# Quietly only if a door opened the ordinary way would be heard: held
		# a second, it swings slowly and carries 9 m instead of 45. If even
		# that would be heard, it waits for the creature to be elsewhere.
		var threat = owner_match.threat
		var slow: bool = threat.audible(door.doorway, "door")
		if slow and threat.audible(door.doorway, "door_slow") and timer < 20.0:
			timer = minf(timer, 0.0)
			door_wait += delta
			if door_wait < 20.0: return
		if slow and timer < DOOR_HOLD: return
		door_wait = 0.0
		if not level.match_net.use_door(door, slow, false):
			owner_match.report("puerta", "media", self, "una puerta que no se deja abrir")
			give_up("stuck", "no pudo abrir una puerta")
			return
		door_pressed = true
		timer = 0.0
		return
	if timer > DOOR_SWING + 1.0:
		owner_match.report("puerta", "media", self, "la puerta no se abrió del todo")
		door = null
		nav.clear()
		state = State.MOVE

# --- Using things -----------------------------------------------------------------

func act(delta: float) -> void:
	halt()
	var node = task.get("node")
	var aim: Vector3 = task.get("aim", body.global_position)
	face(aim)
	timer += delta
	if timer < 0.25: return
	var kind := String(task.get("kind", ""))
	if not is_instance_valid(node):
		owner_match.team.finished(self, task)
		set_task({})
		return
	if not bool(task.get("reached", false)) and bool(task.get("unusable", false)):
		owner_match.report("sin_alcance", "grave", self, "no llega con la mano a %s desde ningún sitio%s" % [describe(), " al que se pueda llegar andando (solo desde un hueco que no se une al resto de la planta)" if bool(task.get("island", false)) else ""], {"aim": aim})
		task["reached"] = true
		timer = 0.25
	if not bool(task.get("reached", false)):
		if not in_reach(node, aim):
			var stands: Array = task.get("stands", [])
			if stand_index + 1 < stands.size():
				stand_index += 1
				nav.clear()
				state = State.MOVE
				return
			# From nowhere it can stand does the hand get to it: what a player
			# could not use either. Said, and done anyway, so the floor goes on.
			owner_match.report("sin_alcance", "grave", self, "no llega con la mano a %s desde ningún sitio" % describe(), {"aim": aim})
		task["reached"] = true
		timer = 0.25
	match kind:
		"tv":
			if timer < 0.5: return
			level.switch_television(node)
			owner_match.note("tele", self, {"index": level.televisions.find(node)})
			owner_match.team.finished(self, task)
			set_task({})
		"note":
			if timer < 0.25 + CONTAINER.SEARCH_TIME: return
			level.match_net.use_container(node, seat)
			owner_match.note("registro", self, {"index": level.containers.find(node), "digit": int(node.digit)})
			owner_match.team.finished(self, task)
			set_task({})
		"search":
			if timer < 0.25 + CONTAINER.SEARCH_TIME: return
			level.match_net.use_container(node, seat)
			owner_match.team.finished(self, task)
			set_task({})
		"code":
			var keys := int((timer - 0.25) / KEY_TIME)
			var code: String = String(task.get("code", ""))
			if keys < code.length(): return
			var verdict: String = level.code_verdict(code)
			owner_match.note("teclado", self, {"verdict": verdict})
			if verdict == "right": level.match_net.use_code()
			elif verdict == "wrong": owner_match.report("codigo", "grave", self, "el código que el equipo leyó no es el de la puerta")
			owner_match.team.finished(self, task)
			set_task({})
		_:
			state = State.WAIT

## Whether the hand gets to it from here: the ray a player's interaction
## casts, from the eye towards it, hitting it before anything else.
func in_reach(node: Node3D, aim: Vector3) -> bool:
	var eye: Vector3 = body.camera.global_position
	if eye.distance_to(aim) > REACH + 0.3: return false
	var query := PhysicsRayQueryParameters3D.create(eye, eye + (aim - eye).normalized() * REACH, REACH_MASK)
	query.collide_with_areas = true
	query.exclude = [body.get_rid()]
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == node

func wait() -> void:
	halt()
	var look = task.get("look")
	if look is Vector3: face(look)

# --- Stuck ----------------------------------------------------------------------

func reset_stuck() -> void:
	stuck_clock = 0.0
	stuck_anchor = Vector3.INF
	stuck_origin = Vector3.INF
	stuck_level = 0
	linger_clock = 0.0
	linger_best = INF

## Moving without getting anywhere: against a corner, a leaf, a piece of
## furniture or another body. Each step up the ladder is said out loud.
func watch_progress(delta: float) -> void:
	var at: Vector3 = body.global_position
	if not is_finite(stuck_anchor.x) or flat_gap(at, stuck_anchor) > STUCK_GAIN:
		stuck_anchor = at
		stuck_clock = 0.0
	if is_finite(stuck_origin.x) and flat_gap(at, stuck_origin) > STUCK_FREE:
		stuck_level = 0
		stuck_origin = Vector3.INF
	stuck_clock += minf(delta, 0.1)
	var left: float = nav.remaining()
	if left < linger_best - LINGER_GAIN:
		linger_best = left
		linger_clock = 0.0
	else: linger_clock += minf(delta, 0.1)
	if stuck_clock >= STUCK_STEPS[mini(stuck_level, STUCK_STEPS.size() - 1)] or linger_clock >= STUCK_LINGER:
		escalate()

func escalate() -> void:
	if not is_finite(stuck_origin.x): stuck_origin = body.global_position
	# Stuck again right where it just gave up: the ladder goes on from there,
	# or it gave up and was sent back for good.
	if stuck_level == 0 and clock - gave_up_clock < 60.0 and flat_gap(body.global_position, gave_up_at) < STUCK_FREE: stuck_level = 4
	stuck_level += 1
	stuck_clock = 0.0
	linger_clock = 0.0
	linger_best = INF
	var heading: Vector3 = nav.steer() if nav.active() else Vector3.ZERO
	owner_match.report("bot_atascado", "grave" if stuck_level >= 5 else "media" if stuck_level >= 3 else "leve", self, "paso %d yendo a %s%s" % [stuck_level, describe(), surroundings()], {"step": stuck_level, "next": nav.next_point()})
	match stuck_level:
		1:
			unstick_dir = free_side(heading)
			unstick_left = 0.5
			unstick_replan = false
			state = State.UNSTICK
		2:
			unstick_dir = -heading if heading != Vector3.ZERO else free_side(Vector3.FORWARD)
			unstick_left = 0.6
			unstick_replan = true
			state = State.UNSTICK
		3:
			var shut = door_at_hand()
			if shut != null:
				door = shut
				door_pressed = false
				timer = 0.0
				state = State.DOOR
				return
			unstick_dir = detour()
			unstick_left = 1.2
			unstick_replan = true
			state = State.UNSTICK
		4:
			gave_up_at = body.global_position
			gave_up_clock = clock
			give_up("stuck", "atascado yendo a %s" % describe())
		_:
			hop()
			stuck_level = 0

## What is round it, for a report: the nearest door and how it stands, and
## the next point of its route.
func surroundings() -> String:
	var at: Vector3 = body.global_position
	var nearest = null
	for candidate in level.hotel.doors:
		if not is_instance_valid(candidate) or absf(candidate.doorway.y - at.y) > 1.5: continue
		if nearest == null or flat_gap(candidate.doorway, at) < flat_gap(nearest.doorway, at): nearest = candidate
	var words := ""
	if nearest != null and flat_gap(nearest.doorway, at) < 3.0:
		words += " · puerta a %.1f m, %s" % [flat_gap(nearest.doorway, at), "abierta" if nearest.opened else "cerrada"]
	if nav.active(): words += " · siguiente punto a %.1f m" % flat_gap(nav.next_point(), at)
	var shut = nav.door_ahead()
	if shut != null: words += " · ante una puerta %s" % ("con llave" if shut.locked else "que se mueve" if shut.moving else "cerrada")
	words += " · en %s" % owner_match.room_name(FLOOR.room_at(level.manifest.rooms, at))
	return words

func unstick(delta: float) -> void:
	unstick_left -= delta
	walk_towards(unstick_dir, BODY.Pace.WALK)
	if unstick_left > 0.0: return
	halt()
	if unstick_replan: nav.clear()
	state = State.MOVE if not task.is_empty() else State.IDLE

## The side with more room, across the way it was going.
func free_side(heading: Vector3) -> Vector3:
	var across := Vector3(-heading.z, 0, heading.x)
	if across.length() < 0.1: across = Vector3.RIGHT
	across = across.normalized()
	var space = level.get_world_3d().direct_space_state
	var from: Vector3 = body.global_position + Vector3(0, 0.9, 0)
	var best := across
	var best_room := -1.0
	for side in [across, -across]:
		var query := PhysicsRayQueryParameters3D.create(from, from + side * 1.5, 1 | 8 | 128)
		query.exclude = [body.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var room: float = 1.5 if hit.is_empty() else from.distance_to(hit.position)
		if room > best_room:
			best_room = room
			best = side
	return best

## Somewhere open two or three metres off, on the walkable floor.
func detour() -> Vector3:
	var map: RID = level.get_world_3d().navigation_map
	for attempt in 8:
		var angle: float = owner_match.rng.randf() * TAU
		var point: Vector3 = body.global_position + Vector3(cos(angle), 0, sin(angle)) * owner_match.rng.randf_range(2.0, 3.0)
		var snapped := FLOOR.closest(map, point)
		if flat_gap(snapped, point) < 0.3 and NAV.joined(level, snapped):
			var way := Vector3(snapped.x - body.global_position.x, 0, snapped.z - body.global_position.z)
			if way.length() > 0.5: return way.normalized()
	return free_side(Vector3.FORWARD)

func door_at_hand():
	for candidate in level.hotel.doors:
		if not is_instance_valid(candidate) or candidate.opened or candidate.moving or candidate.locked: continue
		if flat_gap(candidate.doorway, body.global_position) < 1.6 and absf(candidate.doorway.y - body.global_position.y) < 1.5: return candidate
	return null

## The last step: put two metres further along its own route, where its body
## fits -- or, got into a gap the rest of the floor does not join, onto the
## nearest floor that does. It is a finding every time.
func hop() -> void:
	var from: Vector3 = body.global_position
	var target := from
	if not NAV.joined(level, from):
		var out := NAV.nearest_joined(level, from, HOP + 1.0)
		if out != Vector3.INF:
			body.global_position = out + Vector3(0, 0.05, 0)
			body.velocity = Vector3.ZERO
			owner_match.report("bot_salto", "grave", self, "metido en un hueco sin salida para la malla; sacado %.1f m" % from.distance_to(out), {"from": from, "to": out})
			nav.clear()
			state = State.MOVE if not task.is_empty() else State.IDLE
			return
	if nav.active():
		var left := HOP
		var at := from
		for i in range(nav.index, nav.path.size()):
			var leg: float = at.distance_to(nav.path[i])
			if leg >= left:
				target = at.lerp(nav.path[i], left / maxf(leg, 0.001))
				break
			left -= leg
			at = nav.path[i]
			target = at
	if not fits(target):
		owner_match.report("bot_salto", "grave", self, "no cabía en ningún sitio de su ruta")
		give_up("stuck", "atascado sin salida yendo a %s" % describe())
		return
	body.global_position = target + Vector3(0, 0.05, 0)
	body.velocity = Vector3.ZERO
	owner_match.report("bot_salto", "grave", self, "saltó %.1f m por su ruta" % from.distance_to(target), {"from": from, "to": target})
	nav.clear()
	state = State.MOVE if not task.is_empty() else State.IDLE

func fits(point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 0.95, 0))
	query.collision_mask = 1 | 8 | 128
	query.exclude = [body.get_rid()]
	return level.get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func state_name() -> String: return STATE_NAMES[state]

# --- The creature ------------------------------------------------------------------

## Seconds it has been hiding, the wardrobe it is going to, and when it last
## chose its pace (the ear checks cost a route each).
var hidden_since := -1.0
var hide_target = null
var pace_clock := 0.0
var pace_now := BODY.Pace.WALK
var fleeing := false
var flee_point := Vector3.INF
var flee_clock := 0.0
var seen_clock := 0.0
var wait_until := -INF
var hide_check := 0.0
var watch_clock := 0.0
## Seconds lately spent minding the creature instead of the errand, and until
## when it goes on regardless (bold()).
var wary := 0.0
var bold_until := -INF
const WARY_LIMIT := 45.0
const BOLD_FOR := 40.0
func bold() -> bool: return clock < bold_until
var cover_from := Vector3.ZERO
var cover_clock := 0.0
var cover_refused := -INF
## What minding the creature is doing this frame, and what it was last said
## to be doing: "", "escondido", "huye", "aparta", "cubre", "quieto".
var minding := ""
var minded := ""
var in_line := false
var cover := Vector3.INF
var ahead_clock := 0.0
var ahead_seen := false

## The step ahead in the line of its eyes on its way: asked five times a
## second (a ray to each of them).
func ahead_watched(ahead: Vector3) -> bool:
	ahead_clock -= 1.0 / 60.0
	if ahead_clock <= 0.0:
		ahead_clock = 0.2
		var threat = owner_match.threat
		ahead_seen = threat.watched(ahead) and not threat.watched(body.global_position)
	return ahead_seen

## What the creature makes it do before anything else: stay hidden, run, or
## get out of its sight. True when that took the frame.
func mind_creature(delta: float) -> bool:
	var threat = owner_match.threat
	if body.hidden:
		minding = "escondido"
		state = State.HIDDEN
		halt()
		hide_check -= delta
		if hide_check <= 0.0:
			hide_check = 0.5
			if leave_hide_now(): body.leave_wardrobe()
		if not body.hidden:
			hidden_since = -1.0
			state = State.MOVE if not task.is_empty() else State.IDLE
		return true
	if not threat.near_planta(body.global_position):
		fleeing = false
		return false
	if level.point_in_refuge(body.global_position) and not threat.hunted(body):
		fleeing = false
		return false
	if threat.hunted(body):
		flee(delta, true)
		return true
	# Bold for a while: on with the errand, crouched, minding only being run
	# down. Going back to cover at each look was what kept it from ever
	# getting anywhere.
	if bold():
		fleeing = false
		return false
	# In the line of its eyes, now or where it is going: out of it, crouched,
	# before it turns or gets there; then still until it has gone by.
	watch_clock -= delta
	if watch_clock <= 0.0:
		watch_clock = 0.2
		in_line = threat.watched(body.global_position, 1.64)
		if in_line and (cover == Vector3.INF or threat.watched(cover, 1.64)) and clock > cover_refused: cover = cover_point()
		if not in_line: cover = Vector3.INF
	if in_line:
		seen_clock += delta
		if cover != Vector3.INF and flat_gap(cover, body.global_position) > 0.3:
			minding = "cubre"
			# By the walkable way, not straight at it through the furniture;
			# not getting there is no cover, and something else is tried.
			if nav.target.distance_to(cover) > 0.3 or not nav.active() or clock - nav.planned_at > 1.0: nav.plan(cover, clock)
			var direction: Vector3 = nav.steer()
			if direction == Vector3.ZERO: direction = Vector3(cover.x - body.global_position.x, 0, cover.z - body.global_position.z).normalized()
			walk_towards(direction, BODY.Pace.CROUCH)
			if flat_gap(body.global_position, cover_from) > 0.4:
				cover_from = body.global_position
				cover_clock = 0.0
			cover_clock += delta
			if cover_clock < 1.5: return true
			cover = Vector3.INF
			cover_refused = clock + 3.0
			cover_clock = 0.0
		if try_hide(): return true
		# Nowhere out of its line near: away from where it is going, quietly.
		flee(delta, false)
		return true
	seen_clock = 0.0
	# Somewhere it is not seen, with the creature near or coming: still, so as
	# not to be heard, until it has gone.
	if threat.position.distance_to(body.global_position) < 20.0 or coming_for_me():
		if coming_for_me() and try_hide(): return true
		if threat.audible(body.global_position, "crouch" + ("_hard" if body.hard_floor else "")):
			fleeing = false
			minding = "quieto"
			halt()
			return true
	fleeing = false
	# Coming this way, and a wardrobe to be had in time: in it.
	if coming_for_me() and try_hide(): return true
	return false

## Somewhere a step or two away the creature does not see.
func cover_point() -> Vector3:
	var threat = owner_match.threat
	var map: RID = level.get_world_3d().navigation_map
	var best := Vector3.INF
	var best_gap := INF
	for ring in [1.0, 2.0, 3.0]:
		for step in 10:
			var angle := TAU * float(step) / 10.0
			var point := FLOOR.closest(map, body.global_position + Vector3(cos(angle), 0, sin(angle)) * float(ring))
			if flat_gap(point, body.global_position) < 0.5 or threat.watched(point, 1.64): continue
			var gap: float = NAV.route_length(level, body.global_position, point)
			if gap > float(ring) * 2.5: continue
			if gap < best_gap:
				best_gap = gap
				best = point
		if best != Vector3.INF: return best
	return best

## The creature's way goes through here, or it is heading for this room.
func coming_for_me() -> bool:
	var threat = owner_match.threat
	var here := int(FLOOR.room_at(level.manifest.rooms, body.global_position).get("id", -1))
	if here < 0: return false
	if threat.path_rooms.has(here): return threat.position.distance_to(body.global_position) < 30.0
	return threat.room == here

## Run: to the refuge if it is near and not past the creature, or else away
## from it through the nearest doorway it does not see, shutting the door
## behind. A wardrobe only where it did not see it get in.
const REFUGE_NEAR := 20.0
func flee(delta: float, run: bool) -> void:
	var threat = owner_match.threat
	minding = "huye" if run else "aparta"
	if not fleeing:
		fleeing = true
		flee_clock = 0.0
		owner_match.note("huye" if run else "se_aparta", self, {"mode": threat.mode})
	flee_clock += delta
	# Out of its line and not right on top of it: running is what it hears
	# now (it listens round where it last knew it was), so the rest of the
	# way is crouched, or into a wardrobe it did not see it get into.
	var seen: bool = threat.visible(body.global_position)
	if run and not seen and threat.position.distance_to(body.global_position) > 9.0:
		if try_hide(): return
		run = false
	if flee_point == Vector3.INF or flat_gap(body.global_position, flee_point) < 1.0 or flee_clock > 3.0:
		flee_point = escape_point()
		flee_clock = 0.0
		# The refuge a few steps off beats any way out of its line: in there
		# nothing takes anybody.
		if owner_match.team.knowledge.refuges.has(int(level.session.stage) - 1):
			var inside := FLOOR.closest(level.get_world_3d().navigation_map, FLOOR.position_of(level.manifest.rooms[int(level.refuge_room())]))
			if NAV.route_length(level, body.global_position, inside) <= REFUGE_NEAR: flee_point = inside
	var way: Vector3 = flee_point
	if way == Vector3.INF:
		if try_hide(): return
		halt()
		return
	if nav.target.distance_to(way) > 0.5 or not nav.active() or clock - nav.planned_at > 0.6: nav.plan(way, clock)
	var direction: Vector3 = nav.steer()
	if direction == Vector3.ZERO: direction = Vector3(way.x - body.global_position.x, 0, way.z - body.global_position.z).normalized()
	walk_towards(direction, BODY.Pace.RUN if run else BODY.Pace.CROUCH)
	if not run: return
	# A door just gone through, the creature not in it yet: shut behind.
	for crossing in nav.crossings:
		var door = crossing.door
		if not is_instance_valid(door) or not door.opened or door.moving or door.locked: continue
		var gap := flat_gap(door.doorway, body.global_position)
		if gap > 1.2 and gap < 2.5 and (body.global_position - door.doorway).dot(threat.position - door.doorway) < 0.0 and threat.position.distance_to(door.doorway) > 4.0:
			level.match_net.use_door(door, false, false)
			owner_match.note("cierra", self, {"door": level.hotel.doors.find(door)})
			break

## Where to run: of the refuge (when near) and the rooms one and two doors
## away from the creature's side, the one whose way leaves its line soonest;
## a way that stays in its line is a way it runs down.
func escape_point() -> Vector3:
	var threat = owner_match.threat
	var rooms: Array = level.manifest.rooms
	var candidates: Array = []
	if owner_match.team.knowledge.refuges.has(int(level.session.stage) - 1):
		candidates.append(FLOOR.position_of(rooms[int(level.refuge_room())]))
	var here := int(FLOOR.room_at(rooms, body.global_position).get("id", -1))
	if here >= 0:
		for first in level.manifest.adjacency[here]:
			for second in [int(first)] + Array(level.manifest.adjacency[int(first)]):
				var room: Dictionary = rooms[int(second)]
				if int(second) == here or int(room.get("wing", -1)) != planta() or int(second) == threat.room: continue
				candidates.append(FLOOR.position_of(room))
	var map: RID = level.get_world_3d().navigation_map
	var best := Vector3.INF
	var best_score := INF
	for candidate in candidates:
		var route := FLOOR.navigation_path(map, body.global_position, candidate)
		if route.size() < 2: continue
		# Metres along it until the creature's line is left behind.
		var walked_on := 0.0
		var out_of_line := INF
		var toward := 0.0
		for i in range(1, route.size()):
			var leg: float = route[i - 1].distance_to(route[i])
			var steps := maxi(1, int(leg))
			for s in steps:
				var point: Vector3 = route[i - 1].lerp(route[i], float(s + 1) / float(steps))
				walked_on += leg / float(steps)
				if not threat.visible(point, 1.2):
					out_of_line = walked_on
					break
			if out_of_line < INF or walked_on > 20.0: break
		# A way that starts towards it is no way at all.
		var first_leg: Vector3 = route[1] - route[0]
		toward = (threat.position - body.global_position).normalized().dot(Vector3(first_leg.x, 0, first_leg.z).normalized())
		var score: float = (out_of_line if out_of_line < INF else 40.0) + maxf(toward, 0.0) * 25.0
		if score < best_score:
			best_score = score
			best = FLOOR.closest(map, candidate)
	return best

## A point two rooms away, on the side away from the creature.
func away_point() -> Vector3:
	var threat = owner_match.threat
	var rooms: Array = level.manifest.rooms
	var here := int(FLOOR.room_at(rooms, body.global_position).get("id", -1))
	if here < 0: return Vector3.INF
	var best := Vector3.INF
	var best_score := -INF
	for first in level.manifest.adjacency[here]:
		for second in [int(first)] + Array(level.manifest.adjacency[int(first)]):
			var room: Dictionary = rooms[int(second)]
			if int(second) == here or int(room.get("wing", -1)) != planta() or int(second) == threat.room: continue
			var centre := FLOOR.position_of(room)
			var score: float = centre.distance_to(threat.creature.destination) + centre.distance_to(threat.position) - centre.distance_to(body.global_position) * 0.5
			if threat.path_rooms.has(int(second)): score -= 30.0
			if score > best_score:
				best_score = score
				best = FLOOR.closest(level.get_world_3d().navigation_map, centre)
	return best

## Into a wardrobe, when there is one it gets to well before the creature,
## unseen and unheard, away from where the creature is looking.
const HIDE_MARGIN := 3.5
func try_hide() -> bool:
	var threat = owner_match.threat
	if body.mind() < 40.0: return false
	if hide_target == null or not is_instance_valid(hide_target) or is_instance_valid(hide_target.occupant):
		hide_target = choose_hide()
		if hide_target == null: return false
	var front: Vector3 = hide_target.to_global(hide_target.exit_offset)
	if flat_gap(front, body.global_position) < 0.6:
		if threat.audible(front, "wardrobe") and not threat.hunted(body):
			halt()
			return true
		if body.enter_wardrobe(hide_target):
			hidden_since = clock
			owner_match.note("se_esconde", self, {"hide": level.hotel.hides.find(hide_target)})
			hide_target = null
			return true
		hide_target = null
		return false
	if nav.target.distance_to(front) > 0.3 or not nav.active(): nav.plan(front, clock)
	var direction: Vector3 = nav.steer()
	if direction == Vector3.ZERO: direction = Vector3(front.x - body.global_position.x, 0, front.z - body.global_position.z).normalized()
	walk_towards(direction, BODY.Pace.RUN if threat.hunted(body) else BODY.Pace.CROUCH)
	return true

func choose_hide():
	var threat = owner_match.threat
	var best = null
	var best_time := INF
	for hide in level.hotel.hides:
		if not is_instance_valid(hide) or is_instance_valid(hide.occupant): continue
		var front: Vector3 = hide.to_global(hide.exit_offset)
		if FLOOR.planta_of(front.y) != planta() or flat_gap(front, body.global_position) > 18.0: continue
		if flat_gap(front, threat.creature.last_known) < 2.5 or flat_gap(front, threat.creature.destination) < 2.5: continue
		if owner_match.bodies.any(func(other): return other != body and not other.dead and flat_gap(other.global_position, front) < 2.5): continue
		var metres := NAV.route_length(level, body.global_position, front)
		if metres == INF: continue
		var mine: float = metres / 2.0
		if threat.eta(front) - mine < HIDE_MARGIN: continue
		if threat.exposed(front, 1.2): continue
		if mine < best_time:
			best_time = mine
			best = hide
	return best

## Out of the wardrobe once the creature is well away and not coming, or the
## mind is going, or it has been long enough -- and only if leaving is not
## heard.
func leave_hide_now() -> bool:
	var threat = owner_match.threat
	var stayed: float = clock - hidden_since if hidden_since >= 0.0 else 0.0
	var point: Vector3 = body.global_position
	if not threat.near_planta(point): return stayed > 2.0
	if threat.audible(point, "wardrobe"): return false
	if body.mind() < 35.0: return true
	var away: float = threat.route_to(point)
	return (away > 25.0 and not threat.path_rooms.has(int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1)))) or stayed > 90.0

## The torch where there is no light to see by, never while hidden, and never
## where its beam would fall on the creature (which it notices).
func wants_torch() -> bool:
	if body.hidden: return false
	if owner_match.threat != null and owner_match.threat.torch_catches(body): return false
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, body.global_position)
	return level.hotel.dark or (not room.is_empty() and level.hotel.dark_ids.has(int(room.id)))
