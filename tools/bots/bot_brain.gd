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
		if not nav.plan(goal, clock):
			give_up("unreachable", "sin ruta hasta %s" % describe())
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
	walk_towards(direction, owner_match.pace_for(self))
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
		if timer < DOOR_HOLD: return
		if not level.match_net.use_door(door, true, false):
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

## The torch where there is no light to see by, and never while hidden.
func wants_torch() -> bool:
	if body.hidden: return false
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, body.global_position)
	return level.hotel.dark or (not room.is_empty() and level.hotel.dark_ids.has(int(room.id)))
