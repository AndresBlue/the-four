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
	# Hidden counts too, at half: a team that only ever hides never gets the
	# stage done, and the creature the director keeps near keeps it hiding.
	if took: wary += delta * (0.5 if minding == "escondido" else 1.0)
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
		if straight.length() < 1.0:
			var last_step: int = owner_match.pace_for(self)
			walk_towards(straight.normalized(), BODY.Pace.CROUCH if last_step == BODY.Pace.STILL else last_step)
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
			level.switch_television(node, seat)
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
			if verdict == "right": level.match_net.use_code(seat)
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
	# Getting unstuck is steps like any others: the creature hears them the
	# same (a bot bumping about at a walking pace called it over).
	var pace: int = owner_match.pace_for(self)
	walk_towards(unstick_dir, BODY.Pace.CROUCH if pace == BODY.Pace.STILL else pace)
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
##
## What the recordings of the floors the bots lost said (37 deaths): being seen
## at all is fatal -- every alert ended in a grab -- so everything here is about
## never being in its sight, now or in the next few seconds, and never being
## heard where it can come and look. In order, each frame:
##  1. hidden: stay in until it has gone, and only come out unheard;
##  2. run down: break its line and keep going while its ears are shut (a
##     chase only hears round where it last knew you), then quiet, and a
##     wardrobe if one is well out of its search;
##  3. it is holding somebody (or opening a wardrobe): it neither hears nor
##     moves -- away, out of its line, far;
##  4. its eyes will be on this spot within SIGHT_MARGIN seconds, or it is
##     coming here: away, early, to somewhere its eyes will not be for a good
##     while and it is not going, by a way it will not see, at the quietest
##     pace it will not hear -- or into a wardrobe, if that is safer.
## They used to crouch a metre or two to cover when already in its line, freeze
## in its way, and drop to a crouch right where it had last seen them.

## Seconds of warning it wants: its eyes on this spot sooner than this is
## danger now.
const SIGHT_MARGIN := 15.0
## A place to go to is safe when its eyes will not be on it for this long.
const SAFE_FOR := 24.0
## It comes up by lift after the survivors: this near the place it comes out
## at, a bot gets away from it while it is still in the wing behind.
const LANDING_CLEAR := 26.0
## Seconds without danger before it goes back to what it was doing.
const CALM_FOR := 5.0
var calm_since := -INF
## With nowhere safe, a place its eyes get to at least this much later than
## where it stands is still worth going to.
const FALLBACK_GAIN := 4.0
## How far (walking) it looks for such a place, and for a wardrobe.
const EVADE_REACH := 35.0
const HIDE_REACH := 14.0
## Committed to a place this long before choosing again.
const EVADE_COMMIT := 5.0
## The refuge counts as a way out of a chase this near.
const REFUGE_NEAR := 30.0
## A wardrobe is only safe this far from where it will look.
const HIDE_CLEAR := 5.0
var hidden_since := -1.0
var hide_target = null
var pace_clock := 0.0
var pace_now := BODY.Pace.WALK
var wait_until := -INF
var hide_check := 0.0
## What minding the creature is doing this frame, and what it was last said
## to be doing: "", "escondido", "huye", "evita", "dispersa", "se_esconde".
var minding := ""
var minded := ""
## Where it is going to be safe, until when it keeps to it, and when it last
## asked itself whether that is still right.
var escape := Vector3.INF
var escape_until := -INF
var escape_check := -INF
var escape_kind := ""
## How long its eyes stay off the place it is going to, as it was when chosen.
var escape_time := 0.0
## Run down lately: the chase is not over until it has lost them for good.
var chased := false
var flee_clock := 0.0
var danger_clock := 0.0
var danger_now := false
var sight_in := INF
## Seconds lately spent minding the creature instead of the errand, and until
## when it goes on regardless (bold()): only when the creature is far.
var wary := 0.0
var bold_until := -INF
const WARY_LIMIT := 60.0
const BOLD_FOR := 30.0
func bold() -> bool: return clock < bold_until

## What the creature makes it do before anything else. True when that took
## the frame.
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
			escape = Vector3.INF
			state = State.MOVE if not task.is_empty() else State.IDLE
		return true
	var me: Vector3 = body.global_position
	# It is coming up after them: not where the car lets it out.
	if threat.landing != Vector3.INF and FLOOR.planta_of(threat.landing.y) == planta() and flat_gap(me, threat.landing) < LANDING_CLEAR and not level.point_in_refuge(me) and String(task.get("kind", "")) != "lift":
		minding = "evita"
		if escape == Vector3.INF or escape_kind != "rellano" or clock > escape_check:
			escape_check = clock + 2.0
			escape_kind = "rellano"
			escape = away_from(threat.landing, LANDING_CLEAR + 4.0)
			owner_match.note("rellano", self, {"to": [snappedf(escape.x, 0.1), snappedf(escape.z, 0.1)] if escape != Vector3.INF else [], "landing": [snappedf(threat.landing.x, 0.1), snappedf(threat.landing.y, 0.1), snappedf(threat.landing.z, 0.1)], "here": int(FLOOR.room_at(level.manifest.rooms, me).get("id", -1))})
		go_to(escape, BODY.Pace.WALK, delta)
		return true
	if not threat.near_planta(me):
		chased = false
		escape = Vector3.INF
		return false
	if level.point_in_refuge(me) and not threat.hunted(body):
		chased = false
		escape = Vector3.INF
		return false
	if threat.hunted(body):
		chased = true
		run_away(delta)
		return true
	# The chase goes on until it has lost them: hunting still, or searching
	# near.
	if chased:
		if threat.hostile or (threat.mode == LOCUST.Mode.SEARCH and threat.route_to(me) < 25.0):
			run_away(delta)
			return true
		chased = false
		escape = Vector3.INF
	if threat.busy and (threat.visible(me) or threat.route_to(me) < 30.0):
		scatter(delta)
		return true
	danger_clock -= delta
	if danger_clock <= 0.0:
		danger_clock = 0.25
		sight_in = threat.time_to_sight(me)
		danger_now = sight_in < SIGHT_MARGIN or threat.arrival(me, 6.0) < SIGHT_MARGIN or me.distance_to(threat.destination) < 8.0
		# Bold (see WARY_LIMIT): only its eyes right now count.
		if bold() and danger_now: danger_now = sight_in < 4.0 or threat.route_to(me) < 18.0
	if danger_now: calm_since = clock
	# Back to the errand only once it has been quiet for a while: straight back
	# to it, the next look had it off again, and it paced to and fro in the
	# creature's way making noise (bot_oscila).
	if danger_now or (escape != Vector3.INF and (clock < escape_until or clock - calm_since < CALM_FOR)):
		evade(delta)
		return true
	escape = Vector3.INF
	return false

## The nearest room middle at least `least` metres (straight) from `point`,
## on this planta; INF when there is none.
func away_from(point: Vector3, least: float) -> Vector3:
	var me: Vector3 = body.global_position
	var map: RID = level.get_world_3d().navigation_map
	var here := FLOOR.room_at(level.manifest.rooms, me)
	if here.is_empty(): return Vector3.INF
	var metres: Dictionary = owner_match.walks_from(int(here.id))
	var best := Vector3.INF
	var best_walk := INF
	for key in metres:
		var room: Dictionary = level.manifest.rooms[int(key)]
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != planta() or level.off_limits_rooms().has(int(key)): continue
		var centre := FLOOR.position_of(room)
		if flat_gap(centre, point) < least or owner_match.spot_taken(centre, self): continue
		if float(metres[key]) < best_walk:
			# Only somewhere it can walk to from here: a room across a locked
			# door, or on a scrap of floor of its own, had it walking into a wall.
			var spot := FLOOR.closest(map, centre)
			var way := FLOOR.navigation_path(map, me, spot)
			if way.size() < 2 or way[way.size() - 1].distance_to(spot) > 1.0: continue
			best_walk = float(metres[key])
			best = spot
	return best

## Somebody else is being held, or a wardrobe opened: it cannot hear and does
## not move for a few seconds. Out of its line and well away, running while
## that lasts.
func scatter(delta: float) -> void:
	var threat = owner_match.threat
	minding = "dispersa"
	if escape == Vector3.INF or escape_kind != "dispersa" or clock > escape_check:
		escape_check = clock + 1.0
		escape_kind = "dispersa"
		escape = safe_place(false, 25.0)
		escape_until = clock + EVADE_COMMIT
	go_to(escape, BODY.Pace.RUN if threat.busy else quiet_pace(), delta)

## Somewhere its eyes will soon be, or it is coming this way: away, early.
func evade(delta: float) -> void:
	var threat = owner_match.threat
	minding = "evita"
	var me: Vector3 = body.global_position
	if escape == Vector3.INF or clock > escape_check:
		escape_check = clock + 0.5
		# Still a good place, and still a way there it will not see: its way
		# changes (a lead, a noise), and what was out of its sight is not.
		var still_good: bool = escape != Vector3.INF and escape_kind == "evita" and threat.time_to_sight(escape) >= minf(SAFE_FOR, escape_time) and escape.distance_to(threat.destination) > 8.0 and way_left_unseen()
		if not still_good:
			hide_target = null
			escape = safe_place(true)
			escape_time = owner_match.threat.time_to_sight(escape) if escape != Vector3.INF else 0.0
			escape_kind = "evita"
			escape_until = clock + EVADE_COMMIT
			if escape != Vector3.INF: owner_match.note("evita", self, {"to": [snappedf(escape.x, 0.1), snappedf(escape.z, 0.1)], "hide": hide_target != null, "sight_in": snappedf(sight_in, 0.1)})
	if escape == Vector3.INF:
		# Nowhere better: out of its line where it stands, still, and hope.
		halt()
		return
	if hide_target != null and is_instance_valid(hide_target):
		if try_hide(): return
		hide_target = null
	if flat_gap(me, escape) < ARRIVED:
		halt()
		face(threat.position + Vector3(0, 1.5, 0))
		return
	var pace := quiet_pace()
	# Too near to be quiet enough, and it is walking right here: better heard
	# going than found standing.
	if pace == BODY.Pace.STILL and (threat.arrival(me, 4.0) < 6.0 or me.distance_to(threat.destination) < 4.0): pace = BODY.Pace.CROUCH
	go_to(escape, pace, delta)

## Run down: out of its line, and on while its ears are shut.
func run_away(delta: float) -> void:
	var threat = owner_match.threat
	var me: Vector3 = body.global_position
	minding = "huye"
	flee_clock += delta
	var seen: bool = threat.visible(me)
	if escape_kind != "huye" or escape == Vector3.INF or flat_gap(me, escape) < 1.0 or flee_clock > (1.5 if seen else 3.0):
		escape = flee_point()
		escape_kind = "huye"
		flee_clock = 0.0
		owner_match.note("huye", self, {"mode": threat.mode, "seen": seen})
	# Out of its line: a wardrobe it will not hear being got into and will not
	# open (past its earshot in a chase, or out of hearing otherwise).
	if not seen:
		if hide_target == null or not is_instance_valid(hide_target): hide_target = near_hide(10.0, threat.mode == LOCUST.Mode.CHASE)
		if hide_target != null and try_hide(): return
	# Running is heard, and in a chase every step near where it last knew
	# them is where it goes next: a trail it follows to the end. Running only
	# while seen, while it is right behind, or while its ears are shut here;
	# otherwise the quietest pace it does not hear.
	var pace := BODY.Pace.RUN
	if not seen and threat.route_to(me) > 6.0 and not (threat.deaf_to(me) and threat.lost_time < LOCUST.LOSE_AFTER - 1.5):
		pace = quiet_pace()
		if pace == BODY.Pace.STILL: pace = BODY.Pace.CROUCH
	if escape == Vector3.INF:
		halt()
		return
	go_to(escape, pace, delta)
	if pace != BODY.Pace.RUN: return
	# A door just gone through, the creature not in it yet: shut behind.
	for crossing in nav.crossings:
		var door = crossing.door
		if not is_instance_valid(door) or not door.opened or door.moving or door.locked: continue
		var gap := flat_gap(door.doorway, me)
		if gap > 1.2 and gap < 2.5 and (me - door.doorway).dot(threat.position - door.doorway) < 0.0 and threat.position.distance_to(door.doorway) > 4.0:
			level.match_net.use_door(door, false, false)
			owner_match.note("cierra", self, {"door": level.hotel.doors.find(door)})
			break

var door_asked := -INF
## Walks (or runs, or creeps) to a point by the walkable way.
func go_to(point: Vector3, pace: int, _delta: float) -> void:
	if point == Vector3.INF:
		halt()
		return
	if nav.target.distance_to(point) > 0.4 or not nav.active() or clock - nav.planned_at > 1.0:
		# No way there: not straight at it through the wall -- choose again.
		if not nav.plan(point, clock) or nav.end_gap > 1.5:
			escape = Vector3.INF
			escape_check = -INF
			halt()
			return
	# A shut door on the way: opened, at the pace it goes -- flung open on the
	# run, eased open otherwise -- and waited for. A locked one is no way.
	# Going anywhere minding the creature used to walk into shut doors and
	# stand there: a team told to get away from the lift the creature was
	# coming up by waited at the lobby's door for it.
	var shut = nav.door_ahead()
	if shut != null:
		if shut.locked:
			escape = Vector3.INF
			escape_check = -INF
			halt()
			return
		halt()
		face(shut.doorway + Vector3(0, 1.2, 0))
		if not shut.moving and not shut.opened and clock >= door_asked + 0.5:
			door_asked = clock
			level.match_net.use_door(shut, pace != BODY.Pace.RUN, false)
		return
	var direction: Vector3 = nav.steer()
	if direction == Vector3.ZERO:
		if flat_gap(point, body.global_position) > 1.0:
			nav.clear()
			halt()
			return
		direction = Vector3(point.x - body.global_position.x, 0, point.z - body.global_position.z).normalized()
	if pace == BODY.Pace.STILL:
		halt()
		return
	walk_towards(direction, pace)

## The quietest pace it would not hear from where it is or where it will be
## in a few seconds: walking, crouched, or not a step.
func quiet_pace() -> int:
	return owner_match.pace_for(self, true)

## Where to be: of the rooms and their corners within EVADE_REACH (and, with
## `hides`, the wardrobes within HIDE_REACH), the nearest one its eyes will not
## be on for SAFE_FOR seconds, that it is not heading for or searching, and
## that is got to without crossing its sight on the way. `least`: at least
## that far (walking). INF when there is none.
func safe_place(hides: bool, least := 0.0) -> Vector3:
	var threat = owner_match.threat
	var me: Vector3 = body.global_position
	var map: RID = level.get_world_3d().navigation_map
	var rooms: Array = level.manifest.rooms
	var here := FLOOR.room_at(rooms, me)
	if here.is_empty(): return Vector3.INF
	var metres: Dictionary = owner_match.walks_from(int(here.id))
	var candidates: Array = []
	for key in metres:
		var walk := float(metres[key])
		if walk > EVADE_REACH or walk < least * 0.6: continue
		var room: Dictionary = rooms[int(key)]
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != planta() or level.off_limits_rooms().has(int(key)) and not level.point_in_refuge(FLOOR.position_of(room)): continue
		var centre := FLOOR.position_of(room)
		var span := FLOOR.size_of(room)
		candidates.append(centre)
		for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			candidates.append(centre + Vector3(corner.x * maxf(0.0, span.x * 0.5 - 1.6), 0, corner.y * maxf(0.0, span.y * 0.5 - 1.6)))
	# The refuge of the stage, known: nothing takes anybody in there.
	var refuge := Vector3.INF
	if owner_match.team.knowledge.refuges.has(int(level.session.stage) - 1):
		refuge = FLOOR.closest(map, FLOOR.position_of(rooms[int(level.refuge_room())]))
	var scored: Array = []
	for candidate in candidates:
		var point := FLOOR.closest(map, candidate)
		if point.distance_to(candidate) > 1.2: continue
		var straight := flat_gap(point, me)
		# Not where another of the team is, or is going to be: bunched up, the
		# first one found gave the rest away.
		if owner_match.spot_taken(point, self): continue
		scored.append([straight, point])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var best := Vector3.INF
	var best_score := INF
	var best_walk := INF
	# The best of the rest, when nowhere is safe for SAFE_FOR: the place its
	# eyes get to latest, well after they get here. Standing still where it
	# was about to look was the worst thing a bot did (it froze on the line the
	# creature was walking down, and was seen there).
	var fallback := Vector3.INF
	var fallback_time := maxf(sight_in, 0.0) + FALLBACK_GAIN
	var fallback_walk := INF
	var checked := 0
	for entry in scored:
		if checked >= 24: break
		var point: Vector3 = entry[1]
		var in_refuge: bool = refuge != Vector3.INF and level.point_in_refuge(point)
		var tts: float = INF if in_refuge else threat.time_to_sight(point)
		if not in_refuge:
			if tts < fallback_time: continue
			if point.distance_to(threat.destination) < 8.0 or threat.searched_near(point, 5.0): continue
		checked += 1
		var way := FLOOR.navigation_path(map, me, point)
		if way.size() < 2 or way[way.size() - 1].distance_to(point) > 1.0: continue
		var length := 0.0
		for i in range(1, way.size()): length += way[i].distance_to(way[i - 1])
		if length < least: continue
		if not way_unseen(way): continue
		if tts < SAFE_FOR or point.distance_to(threat.destination) < 10.0 or threat.searched_near(point, 6.0):
			# Not safe, but later than anywhere else so far.
			if tts > fallback_time or (is_equal_approx(tts, fallback_time) and length < fallback_walk):
				fallback_time = tts
				fallback = point
				fallback_walk = length
			continue
		# Near and away from it; the refuge is worth a detour.
		var score: float = length - point.distance_to(threat.position) * 0.3 - (15.0 if in_refuge else 0.0)
		if score < best_score:
			best_score = score
			best = point
			best_walk = length
	if best == Vector3.INF and fallback != Vector3.INF:
		best = fallback
		best_walk = fallback_walk
	if hides:
		var hide = near_hide(HIDE_REACH)
		if hide != null:
			var front: Vector3 = hide.to_global(hide.exit_offset)
			var metres_to: float = NAV.route_length(level, me, front)
			# A wardrobe got into unseen and unheard beats open floor: this
			# creature gives a search up in seconds and walks off. Open floor
			# only when it is much nearer (walking about is what it sees).
			if best == Vector3.INF or metres_to < best_walk + 8.0:
				hide_target = hide
				return front
	return best

## What is left of the way it is on, still out of its sight.
func way_left_unseen() -> bool:
	if not nav.active(): return true
	var rest := PackedVector3Array([body.global_position])
	for i in range(nav.index, nav.path.size()): rest.append(nav.path[i])
	return rest.size() < 2 or way_unseen(rest)

## A way it will not see: each bit of it, at the time this bot gets there
## (crouching), out of the line of its eyes from then until a little after.
func way_unseen(way: PackedVector3Array) -> bool:
	var threat = owner_match.threat
	var walked := 0.0
	var next := 2.0
	for i in range(1, way.size()):
		var leg: float = way[i - 1].distance_to(way[i])
		while walked + leg >= next:
			var point: Vector3 = way[i - 1].lerp(way[i], (next - walked) / maxf(leg, 0.001))
			var when := next / 2.0
			if threat.time_to_sight(point) < when + 3.0: return false
			next += 3.0
		walked += leg
	return true

## A wardrobe within `reach` (walking) it can get into before the creature
## gets near, unseen, unheard, and not where its search will look. In a chase
## (`chase`) it hears nothing away from where it last knew them
## (CHASE_EARSHOT) and opens only a wardrobe right there: one past that, got
## into out of its sight, is not found.
func near_hide(reach: float, chase := false):
	var threat = owner_match.threat
	var me: Vector3 = body.global_position
	var best = null
	var best_metres := INF
	for hide in level.hotel.hides:
		if not is_instance_valid(hide) or is_instance_valid(hide.occupant): continue
		var front: Vector3 = hide.to_global(hide.exit_offset)
		if FLOOR.planta_of(front.y) != planta() or flat_gap(front, me) > reach: continue
		if threat.searched_near(front, HIDE_CLEAR) or front.distance_to(threat.destination) < HIDE_CLEAR: continue
		if front.distance_to(threat.last_known) < (LOCUST.CHASE_EARSHOT + 2.0 if chase else HIDE_CLEAR): continue
		if owner_match.bodies.any(func(other): return other != body and not other.dead and flat_gap(other.global_position, front) < 2.5): continue
		if threat.time_to_sight(front) < (2.5 if chase else 6.0) or threat.visible(front): continue
		if not (chase and threat.deaf_to(front)) and threat.audible(front, "wardrobe"): continue
		var metres := NAV.route_length(level, me, front)
		if metres > reach: continue
		if metres < best_metres:
			best_metres = metres
			best = hide
	return best

## Into the wardrobe it is going to, when it gets there unseen and unheard.
func try_hide() -> bool:
	var threat = owner_match.threat
	if hide_target == null or not is_instance_valid(hide_target) or is_instance_valid(hide_target.occupant):
		hide_target = null
		return false
	var front: Vector3 = hide_target.to_global(hide_target.exit_offset)
	if flat_gap(front, body.global_position) < 0.6:
		# Heard getting in, or seen, is found: better keep going.
		if (threat.audible(front, "wardrobe") and not threat.deaf_to(front)) or threat.visible(front):
			hide_target = null
			return false
		if body.enter_wardrobe(hide_target):
			hidden_since = clock
			minding = "se_esconde"
			owner_match.note("se_esconde", self, {"hide": level.hotel.hides.find(hide_target)})
			hide_target = null
			return true
		hide_target = null
		return false
	go_to(front, BODY.Pace.RUN if threat.hunted(body) or threat.busy else quiet_pace(), 0.0)
	return true

## Where to run: of the refuge (when near and not past it) and the rooms one
## to three doors away, the one whose way leaves its line soonest, away from
## it, and not on along the way it saw this bot going (its search looks
## there first).
func flee_point() -> Vector3:
	var threat = owner_match.threat
	var me: Vector3 = body.global_position
	var rooms: Array = level.manifest.rooms
	var map: RID = level.get_world_3d().navigation_map
	var candidates: Array = []
	if owner_match.team.knowledge.refuges.has(int(level.session.stage) - 1):
		var inside := FLOOR.closest(map, FLOOR.position_of(rooms[int(level.refuge_room())]))
		if NAV.route_length(level, me, inside) <= REFUGE_NEAR: candidates.append(inside)
	var here := int(FLOOR.room_at(rooms, me).get("id", -1))
	if here >= 0:
		var metres: Dictionary = owner_match.walks_from(here)
		for key in metres:
			var walk := float(metres[key])
			var room: Dictionary = rooms[int(key)]
			if int(key) == here or walk > 40.0 or walk < 8.0 or int(room.get("wing", -1)) != planta() or int(key) == threat.room or FLOOR.is_void(room): continue
			if level.off_limits_rooms().has(int(key)) and not level.point_in_refuge(FLOOR.position_of(room)): continue
			candidates.append(FLOOR.closest(map, FLOOR.position_of(room)))
	var heading := Vector3(body.velocity.x, 0, body.velocity.z)
	var seen: bool = threat.visible(me)
	var best := Vector3.INF
	var best_score := INF
	for candidate in candidates:
		var route := FLOOR.navigation_path(map, me, candidate)
		if route.size() < 2: continue
		# Metres along it until the creature's line is left behind.
		var walked_on := 0.0
		var out_of_line := INF
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
		var first_leg: Vector3 = route[1] - route[0]
		first_leg.y = 0.0
		var toward: float = (threat.position - me).normalized().dot(first_leg.normalized())
		var score: float = (out_of_line if out_of_line < INF else 40.0) + maxf(toward, 0.0) * 30.0 - candidate.distance_to(threat.position) * 0.2
		# Out of its sight already: not on along the same way (its search
		# follows the way it last saw somebody going).
		if not seen and heading.length() > 0.5 and first_leg.normalized().dot(heading.normalized()) > 0.7: score += 12.0
		if threat.searched_near(candidate, 6.0): score += 15.0
		if level.point_in_refuge(candidate): score -= 20.0
		if score < best_score:
			best_score = score
			best = candidate
	return best

## Out of the wardrobe once the creature has gone -- walked off from a search
## it gave up, or far and not coming -- and only if leaving is not heard; or
## with the mind going, or after long enough.
func leave_hide_now() -> bool:
	var threat = owner_match.threat
	var stayed: float = clock - hidden_since if hidden_since >= 0.0 else 0.0
	var point: Vector3 = body.global_position
	if not threat.near_planta(point): return stayed > 2.0
	if threat.audible(point, "wardrobe") or threat.hostile or threat.busy: return false
	var away: float = threat.route_to(point)
	if bool(threat.creature.leaving) and away > 20.0: return true
	if away > 25.0 and threat.arrival(point, 10.0) == INF and threat.time_to_sight(point) > 8.0: return true
	if body.mind() < 20.0 and away > 20.0: return true
	return stayed > 150.0

## The step ahead in the line of its eyes on its way: asked five times a
## second (a ray to each of them).
var ahead_clock := 0.0
var ahead_seen := false
func ahead_watched(ahead: Vector3) -> bool:
	ahead_clock -= 1.0 / 60.0
	if ahead_clock <= 0.0:
		ahead_clock = 0.2
		var threat = owner_match.threat
		ahead_seen = threat.watched(ahead) and not threat.watched(body.global_position)
	return ahead_seen

## The torch where there is no light to see by, never while hidden, and never
## where its beam would fall on the creature (which it notices).
func wants_torch() -> bool:
	if body.hidden: return false
	if owner_match.threat != null and owner_match.threat.torch_catches(body): return false
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, body.global_position)
	return level.hotel.dark or (not room.is_empty() and level.hotel.dark_ids.has(int(room.id)))
