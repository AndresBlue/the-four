extends RefCounted
## Her legs followed, one physics frame at a time (lurker.gd calls tick()): the
## pace eased, the heading eased, how low she hangs eased and kept clear of
## what is under her (a ray down every 0.25 s, and her body shrinking where
## the lane is short), the squeeze through a grille, the ducts at her
## difficulty's speed, the long leap from the ceiling, the way down to
## another planta, and a log of every move that is a jump on purpose (the
## route probe holds her to it). spec_f2_movement 7. Physics comes in by the
## callables lurker.gd gives (clearance, busy, bodies_ahead, left_behind),
## so the tests drive it with stubs.
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const ROUTES := preload("res://game/enemies/lurker/lurker_routes.gd")

## Her paces (OFICINAS 1): scurrying away, and backing off slowly (the
## author's C10, 0.8 m/s).
const SCURRY_SPEED := 3.5
const RETREAT_SPEED := 0.8
## vent_crawl 0.55 x 1.35: the clip's own pace, scaled when she is seen in a duct.
const VENT_CLIP_SPEED := 0.74
const SQUEEZE_SPEED := 0.6
## m/s2 (lurker_test.gd): her hands could not keep up otherwise.
const ACCEL := 5.0
## rad/s while moving on a surface, and for a turn.
const HEADING_RATE := 3.0
const TURN_RATE := 4.0
const HANG_RATE := 0.5
## Anchor to the lowest point of her trunk along +Y (tools/dev/lurker_depth_probe.gd
## measured 0.695 crawling on a ceiling; her elbows hang lower, to 1.36).
const BODY_DEPTH := 0.7
## Kept between her lowest point and whatever is under her.
const HEAD_CLEAR := 0.25
const RAY_EVERY := 0.25
## The world and the survivors (player.tscn layer 4).
const RAY_MASK := 1 | 4
## Longest she waits at a band's start for room under it; then she bans the door.
const BAND_WAIT := 4.0
## Metres: a waypoint reached.
const ARRIVE := 0.01
## Metres before a band start the heading turns to the band's.
const LOOKAHEAD := 0.8
## In a visible duct she keeps this far behind the first body ahead.
const DUCT_GAP := 1.5
## A new plan is kept only this much cheaper than the rest of the old one.
const REPLAN_GAIN := 0.05
## The author's long leap from the ceiling (M1): how far (as far as the
## warning takes from, lurker_warning.TAKE_REACH_WALKED), how long, how high.
const LEAP_REACH := 7.5
const LEAP_TIME := 0.6
const LEAP_RISE := 0.3
const CLIMB_SPEED := 1.5
## Her body shrinks under a short lane (M2), no smaller than this.
const SQUASH_MIN := 0.4
const SQUASH_RATE := 1.0
## Under this over the floor her body is at a survivor's height (their
## capsule's top is 1.81): she stops BODY_GAP short of one (M3, M4).
const SURVIVOR_TOP := 1.85
const BODY_GAP := 0.45
## Between plantas she takes what a ride takes (the author's M10, lifts.gd).
const RIDE_TIME := 8.5

signal arrived
## A tile she goes through (spec_f3_aggression): moved as she starts the
## squeeze (`open`, from below going in or from above coming out), and going
## in shut after her at its end.
signal tile_turned(room: int, tile: Vector2i, open: bool, from_below: bool)
signal blocked(why: String)

var shell
var routes
var ducts
var level
var rng := RandomNumberGenerator.new()
## On a surface; null while squeezing, in a duct, leaping or on the floor.
var state = null
var legs: Array = []
## The leg being followed and how far through it.
var leg_clock := 0.0
var travelled := 0.0
var leg_started := false
## What plan() was last asked, the node path of that plan, and the doors on it.
var goal := {}
var plan_nodes := PackedInt32Array()
var deferred := {}
var speed := 0.0
## Wanted m/s on surfaces (the brain or the order sets it).
var pace := 1.35
## Nobody sees her (lurker.gd, every frame): on a surface she goes at least
## unseen_pace, in a hidden duct at least unseen_duct (the author: "cuando no
## la ves, MUY rápido"). The visible main duct keeps its own speed.
var unseen := false
var unseen_pace := 0.0
var unseen_duct := 0.0
var hang_goal := SHELL.DEFAULT_HANG
## From the ray; and how far short the lane was at the last one (0: enough).
var hang_limit := SHELL.HANG_MAX
var clearance_short := 0.0
## 1 is her body as it is; less, shrunk under something low (M2).
var squash := 1.0
var squash_goal := 1.0
var least_squash := 1.0
## lurker.cue, copied every frame (7.3 step 0).
var cue := false
var in_duct := false
var hidden := false
var on_floor := false
var floor_point := Vector3.ZERO
var duct_point := Vector3.ZERO
var duct_dir := Vector3.FORWARD
var near_node := -1
var mouth_exit := -1
## The transform's basis and origin while not on a surface.
var basis := Basis()
var point := Vector3.ZERO
## {phase: &"leaving"|&"drop"|&"arriving", wing, left}
var transit := {}
var pending_wing := -1
## () -> bool: lurker.gd gives is_engaged() or is_hunting() or cue.
var busy := Callable()
## (from: Vector3, dir: Vector3, reach: float) -> float: metres to the first
## survivor body ahead, INF none.
var bodies_ahead := Callable()
## (anchor: Vector3, s) -> float: the most she may hang here (the ray).
var clearance := Callable()
## () -> bool: somebody alive is still on her planta (M10: she goes after
## that one before going down).
var left_behind := Callable()
## {frame, reason, from, to}
var jumps: Array = []
var jump_id := 0
var wait_clock := 0.0
var replan_clock := 0.0
var ray_clock := 0.0
var shut_seen := -1
var epoch_seen := -1
var waiting := false
## Seconds a tray leg has gone without moving her (its waypoint out of reach).
var stall := 0.0
## Heading out of a duct the fans shut.
var ejecting := false
var stuck := ""
var last_anchor := Vector3.INF
var velocity := Vector3.ZERO

func setup(source_shell, source_routes, source_ducts, source_level) -> void:
	shell = source_shell
	routes = source_routes
	ducts = source_ducts
	level = source_level
	shut_seen = routes.shut_frame
	epoch_seen = routes.door_epoch

# --- Where she is -----------------------------------------------------------------

func surface() -> bool:
	return state != null and not in_duct and not on_floor

func transform() -> Transform3D:
	if surface(): return shell.transform_of(state)
	return Transform3D(basis, point)

func anchor() -> Vector3:
	return transform().origin

func wing() -> int:
	return FLOOR.planta_of(anchor().y)

func room() -> int:
	if surface(): return shell.room_of(state)
	return int(FLOOR.room_at(shell.rooms, anchor()).get("id", -1))

func log_jump(reason: StringName, from: Vector3, to: Vector3) -> void:
	jumps.append({"frame": Engine.get_physics_frames(), "reason": reason, "from": from, "to": to})
	jump_id += 1

## Put on a surface at a point (teleport, relocate, restore): logged.
func place_at(at: Vector3, heading_world: Vector3, reason: StringName, hang := SHELL.DEFAULT_HANG) -> void:
	var from := anchor() if state != null or in_duct or on_floor else at
	clear_legs()
	transit = {}
	pending_wing = -1
	in_duct = false
	hidden = false
	on_floor = false
	mouth_exit = -1
	state = shell.state_at(at, hang)
	if state != null and heading_world.length() > 1e-6: shell.set_heading(state, heading_world)
	speed = 0.0
	last_anchor = Vector3.INF
	log_jump(reason, from, anchor())

## Inside the ducts at a node, hidden, no legs: a logged jump.
func place_in_duct(node: int) -> void:
	var from: Vector3 = anchor() if state != null or in_duct or on_floor else ducts.nodes[node]
	clear_legs()
	state = null
	in_duct = true
	hidden = true
	on_floor = false
	near_node = node
	duct_point = ducts.nodes[node]
	point = duct_point
	basis = Basis(Vector3.UP.cross(duct_dir).normalized(), Vector3.UP, duct_dir) if absf(duct_dir.y) < 0.99 else Basis()
	speed = 0.0
	last_anchor = Vector3.INF
	log_jump(&"place", from, duct_point)

func clear_legs() -> void:
	legs = []
	leg_clock = 0.0
	travelled = 0.0
	leg_started = false
	goal = {}
	deferred = {}
	plan_nodes = PackedInt32Array()
	waiting = false
	wait_clock = 0.0

# --- Orders -------------------------------------------------------------------------

## `surface`: over her surfaces only, no duct nor plenum on the way.
func go_to(at: Vector3, pace_: float, surface := false) -> bool:
	var r := int(FLOOR.room_at(shell.rooms, at).get("id", -1))
	if not shell.tray_of.has(r):
		var s = shell.state_at(at)
		if s == null: return false
		r = shell.room_of(s)
	var wanted := {"room": r, "point": at}
	if surface: wanted["surface"] = true
	return order(wanted, pace_)

func go_to_room(r: int, pace_: float) -> bool:
	return order({"room": r}, pace_)

func go_to_exit(e: int, pace_: float, mouth := false) -> bool:
	return order({"exit": e, "mouth": mouth}, pace_)

## Stops where she is (a band, a channel, a duct: anywhere).
func hold() -> void:
	clear_legs()
	speed = 0.0

## A leg that has to be finished before a new plan (a band, a squeeze, a
## drop, a leap, a climb, a turn): the order waits for its end.
func committed() -> bool:
	if legs.is_empty(): return false
	return String(legs[0].kind) in ["band", "squeeze", "drop", "leap", "climb", "turn"]

func order(new_goal: Dictionary, pace_: float) -> bool:
	pace = pace_
	if committed():
		deferred = new_goal
		return true
	return replan(new_goal)

## Where a plan starts from now: {start, from_state, from_point}.
func plan_start() -> Dictionary:
	if in_duct and not legs.is_empty() and String(legs[0].kind) == "duct" and legs[0].has("point_nodes"):
		var leg: Dictionary = legs[0]
		var nodes: PackedInt32Array = leg.nodes
		var points: PackedVector3Array = leg.points
		# The two ends of the segment she is on, so she may turn round.
		var seg := segment_at(points, travelled)
		var a: int = leg.point_nodes[seg]
		var b: int = leg.point_nodes[mini(seg + 1, points.size() - 1)]
		if a == b and nodes.size() > 1: b = nodes[mini(nodes.find(a) + 1, nodes.size() - 1)]
		return {"start": {"duct": [a, b], "metres": [duct_point.distance_to(ducts.nodes[a]), duct_point.distance_to(ducts.nodes[b])], "point": duct_point}, "from_state": null, "from_point": duct_point}
	if in_duct:
		var n: int = near_node if near_node >= 0 else ducts.nearest_node(point)
		return {"start": {"duct": [n, n], "metres": [0.0, 0.0], "point": ducts.nodes[n]}, "from_state": null, "from_point": point}
	if on_floor:
		var above = shell.state_at(floor_point)
		return {"start": {"room": shell.room_of(above)}, "from_state": above, "from_point": floor_point}
	if state == null: return {}
	return {"start": {"room": shell.room_of(state)}, "from_state": state, "from_point": anchor()}

func replan(new_goal: Dictionary) -> bool:
	var from := plan_start()
	if from.is_empty():
		stuck = "sin sitio"
		return false
	var found: Dictionary = routes.plan(from.start, new_goal, from.from_state, from.from_point)
	goal = new_goal
	deferred = {}
	if not bool(found.ok):
		legs = []
		stuck = String(found.why)
		blocked.emit(stuck)
		return false
	stuck = ""
	plan_nodes = found.nodes
	set_legs(found.legs)
	return true

func set_legs(new_legs: Array) -> void:
	# A duct leg in progress is replaced from its own start point, so the
	# distance along it starts again.
	var keep: Array = []
	if on_floor:
		keep.append({"kind": "climb"})
	legs = keep + new_legs
	leg_clock = 0.0
	travelled = 0.0
	leg_started = false
	waiting = false
	wait_clock = 0.0
	mouth_exit = -1

func flee(threat: Vector3) -> bool:
	var from := plan_start()
	if from.is_empty(): return false
	var e: int = routes.flee_exit(from.start, threat, anchor())
	return e >= 0 and go_to_exit(e, SCURRY_SPEED)

## Out by the nearest exit along the ducts, even closed (the fans, 7.6).
func eject() -> void:
	if not in_duct: return
	var n: int = near_node if near_node >= 0 else ducts.nearest_node(point)
	var near: Array = ducts.nearest_exits(n, 1, Callable(), true)
	if near.is_empty(): return
	var e := int(near[0].exit)
	ejecting = true
	order({"room": int(ducts.exits[e].room)}, SCURRY_SPEED)

## The tray to an aisle's mouth, then along it (2b, the probe).
func into_channel(channel: int, v_to: float, u_goal: float, pace_: float) -> bool:
	var record: Dictionary = shell.patches[channel]
	var mouth = shell.channel_mouth(channel)
	var at: Vector3 = shell.anchor_of(mouth)
	if not go_to(at, pace_): return false
	legs.append({"kind": "into_channel", "patch": channel})
	legs.append({"kind": "channel", "patch": channel, "v_to": clampf(v_to, 0.0, float(record.length)), "u_goal": u_goal})
	return true

## The long leap from the ceiling at a point below her (M1).
func leap(to: Vector3, seconds := LEAP_TIME) -> bool:
	if not surface(): return false
	var from := anchor()
	if Vector2(to.x - from.x, to.z - from.z).length() > LEAP_REACH or to.y >= from.y: return false
	# Never past a column (spec_rediseno 9): her body would go through it.
	if shell.column_near(Vector2(from.x, from.z), Vector2(to.x, to.z), FLOOR.planta_of(from.y), SHELL.RADIUS): return false
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var forward := flat.normalized() if flat.length() > 1e-6 else Vector3.FORWARD
	var upright := Basis(Vector3.UP.cross(forward).normalized(), Vector3.UP, forward)
	legs = [{"kind": "leap", "from": from, "to": to, "seconds": maxf(seconds, 0.1), "basis_from": shell.transform_of(state).basis, "basis_to": upright}]
	leg_clock = 0.0
	leg_started = false
	goal = {}
	return true

## From the floor back up to the ceiling over where she landed.
func climb_back(pace_ := CLIMB_SPEED) -> bool:
	if not on_floor: return false
	pace = pace_
	legs = [{"kind": "climb"}]
	leg_clock = 0.0
	leg_started = false
	return true

# --- Queries (2b's percept, spec_f2_mind 8.3) ------------------------------------------

func in_network_duct() -> bool:
	return in_duct and hidden

func duct_node() -> int:
	return near_node if in_duct else -1

func at_exit() -> int:
	return mouth_exit

func on_channel() -> bool:
	return surface() and int(shell.patches[state.patch].kind) == SHELL.Kind.CHANNEL

## Her pace on a surface now: faster unseen.
func pace_now() -> float:
	return maxf(pace, unseen_pace) if unseen else pace

func at_goal() -> bool:
	return legs.is_empty() and stuck == "" and transit.is_empty()

func in_transit() -> bool:
	return transit.get("phase", &"") in [&"drop", &"arriving"]

func hushed() -> bool:
	return transit.get("phase", &"") == &"drop"

func transit_phase() -> StringName:
	return transit.get("phase", &"")

func route_state() -> StringName:
	if not transit.is_empty(): return &"transit"
	if stuck != "": return &"blocked"
	if waiting: return &"waiting"
	return &"idle" if legs.is_empty() else &"moving"

## The doors the legs still go through.
func remaining_pairs() -> Array:
	var out: Array = []
	for leg in legs:
		if String(leg.kind) != "band": continue
		var pair: Vector2i = shell.patches[int(leg.patch)].pair
		if pair.x >= 0: out.append(pair)
	return out

## The next `metres` of her way, every 0.25 m from where she is.
func ahead(metres: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var at := anchor()
	out.append(at)
	var left := metres
	for leg in legs:
		var points := PackedVector3Array()
		match String(leg.kind):
			"tray":
				var to: Vector2 = leg.to
				var y := at.y
				points.append(Vector3(to.x, y, to.y))
			"duct":
				points = leg.points
			"squeeze":
				points.append(leg.to)
			"band":
				var record: Dictionary = shell.patches[int(leg.patch)]
				var s = shell.band_start(int(leg.patch), int(record.rooms[0]), float(leg.v))
				var length: float = record.profile.length
				var steps := maxi(1, int(length / 0.25))
				for i in steps + 1:
					s.u = length * float(i) / float(steps) if int(leg.dir) > 0 else length * (1.0 - float(i) / float(steps))
					points.append(shell.anchor_of(s))
		for p in points:
			var piece := at.distance_to(p)
			var walked := 0.0
			while walked + 0.25 <= piece and left > 0.0:
				walked += 0.25
				left -= 0.25
				out.append(at.lerp(p, walked / piece))
			at = p
			if left <= 0.0: return out
	return out

# --- Between plantas (7.6, M10) ---------------------------------------------------------

func follow_to_planta(target_wing: int) -> void:
	if target_wing <= wing(): return
	pending_wing = target_wing

func ready_to_go() -> bool:
	if pending_wing < 0 or cue: return false
	if busy.is_valid() and bool(busy.call()): return false
	if left_behind.is_valid() and bool(left_behind.call()): return false
	return true

func start_transit(target_wing: int) -> void:
	pending_wing = -1
	if target_wing <= wing(): return
	transit = {"phase": &"leaving", "wing": target_wing, "left": RIDE_TIME}
	if in_duct:
		begin_drop()
		return
	var from := plan_start()
	var e: int = routes.nearest_exit(from.start) if not from.is_empty() else -1
	if e < 0 or not replan({"exit": e}):
		# Nowhere to go in: down where she is, as if by the nearest duct.
		begin_drop()

func begin_drop() -> void:
	var from := anchor()
	var target_wing := int(transit.wing)
	var to_node: int = ducts.trunk_nearest(from, target_wing)
	clear_legs()
	transit = {"phase": &"drop", "wing": target_wing, "left": RIDE_TIME, "node": to_node}
	state = null
	in_duct = true
	hidden = true
	on_floor = false
	if to_node >= 0:
		near_node = to_node
		duct_point = ducts.nodes[to_node]
		point = duct_point
	log_jump(&"planta", from, point)

func finish_drop() -> void:
	var target_wing := int(transit.wing)
	var e: int = routes.arrival_exit(target_wing, rng)
	transit = {"phase": &"arriving", "wing": target_wing}
	if e < 0:
		transit = {}
		return
	var r := int(ducts.exits[e].room)
	var clear: Vector2 = shell.clear_point(r, float(shell.rooms[r].px), float(shell.rooms[r].pz))
	var p := Vector3(clear.x, point.y, clear.y)
	if not replan({"room": r, "point": p}): transit = {}

# --- The frame ----------------------------------------------------------------------------

func tick(delta: float) -> void:
	routes.tick(delta)
	ray_clock -= delta
	if ray_clock <= 0.0:
		ray_clock = RAY_EVERY
		fans()
		ray()
	if not cue:
		watch_doors(delta)
		if ready_to_go(): start_transit(pending_wing)
	if not transit.is_empty() and transit.phase == &"drop":
		transit.left = float(transit.left) - delta
		if float(transit.left) <= 0.0: finish_drop()
	squash = move_toward(squash, squash_goal, SQUASH_RATE * delta)
	least_squash = minf(least_squash, squash)
	if not legs.is_empty(): follow(delta)
	elif surface():
		speed = move_toward(speed, 0.0, ACCEL * delta)
		ease_hang(hang_goal, delta)
	var now := anchor()
	velocity = (now - last_anchor) / delta if last_anchor != Vector3.INF and delta > 0.0 else Vector3.ZERO
	last_anchor = now

## The fans shut wing 2's ducts to her (7.6); inside a shut wing she gets out.
func fans() -> void:
	var air = level.objective(&"air") if level != null and level.has_method("objective") else null
	var shut: bool = air != null and air.has_method("ducts_closed") and bool(air.ducts_closed())
	for w in 3: ducts.closed_wings[w] = 1 if w == 2 and shut else 0
	if not in_duct: ejecting = false
	elif not cue and not ejecting and transit.is_empty() and ducts.closed_wings[wing()] != 0 and not committed(): eject()

## The ray down (7.3 step 3): how low she may hang, and her body shrunk
## where even the least hang leaves too little room (M2).
func ray() -> void:
	if not surface() or int(shell.patches[state.patch].kind) != SHELL.Kind.TRAY:
		squash_goal = 1.0
		return
	var most := SHELL.HANG_MAX
	if clearance.is_valid(): most = float(clearance.call(anchor(), state))
	clearance_short = maxf(0.0, SHELL.HANG_MIN - most)
	hang_limit = clampf(most, SHELL.HANG_MIN, SHELL.HANG_MAX)
	squash_goal = clampf((most - SHELL.HANG_MIN + BODY_DEPTH) / BODY_DEPTH, SQUASH_MIN, 1.0) if most < SHELL.HANG_MIN else 1.0

## A door shut on her way, or changed without a signal, or the lights: a
## new plan, kept only when it is cheaper by REPLAN_GAIN (no dithering).
func watch_doors(delta: float) -> void:
	if goal.is_empty() or legs.is_empty(): return
	if routes.shut_frame != shut_seen:
		shut_seen = routes.shut_frame
		if remaining_pairs().has(routes.last_shut):
			if committed(): deferred = goal
			else: replan(goal)
			return
	replan_clock -= delta
	if replan_clock > 0.0 or not surface() or committed(): return
	replan_clock = ROUTES.REPLAN_EVERY
	routes.door_signature(wing())
	if routes.door_epoch != epoch_seen:
		epoch_seen = routes.door_epoch
		for pair in remaining_pairs():
			if not routes.door_open(pair):
				replan(goal)
				return
	var from := plan_start()
	var found: Dictionary = routes.plan(from.start, goal, from.from_state, from.from_point)
	if not bool(found.ok): return
	var here := room()
	var at := plan_nodes.find(here)
	if at < 0:
		plan_nodes = found.nodes
		set_legs(found.legs)
		return
	var old_cost: float = routes.path_cost(from.start, plan_nodes.slice(at))
	if float(found.cost) < old_cost * (1.0 - REPLAN_GAIN):
		plan_nodes = found.nodes
		set_legs(found.legs)

func ease_hang(target: float, delta: float) -> void:
	if state == null: return
	state.hang = move_toward(state.hang, minf(target, hang_limit if int(shell.patches[state.patch].kind) == SHELL.Kind.TRAY else shell.max_hang(state)), HANG_RATE * delta)
	shell.clamp_state(state)

## Turns the heading towards a world direction at `rate`.
func ease_heading(world: Vector3, rate: float, delta: float) -> float:
	var f: Array = shell.frame_of(state)
	var a := world.dot(f[1])
	var b := world.dot(f[2])
	if Vector2(a, b).length() < 1e-6: return 0.0
	var want := atan2(b, a)
	var gap := wrapf(want - state.heading, -PI, PI)
	state.heading = wrapf(state.heading + clampf(gap, -rate * delta, rate * delta), -PI, PI)
	return absf(wrapf(want - state.heading, -PI, PI))

func next_leg() -> void:
	legs.pop_front()
	leg_clock = 0.0
	travelled = 0.0
	leg_started = false
	waiting = false
	wait_clock = 0.0
	if not deferred.is_empty() and not committed():
		var wanted := deferred
		deferred = {}
		replan(wanted)
		return
	if legs.is_empty():
		if not transit.is_empty() and transit.phase == &"leaving" and in_duct: begin_drop()
		elif not transit.is_empty() and transit.phase == &"arriving": transit = {}
		arrived.emit()

func follow(delta: float) -> void:
	var leg: Dictionary = legs[0]
	match String(leg.kind):
		"tray": follow_tray(leg, delta)
		"band": follow_band(leg, delta)
		"squeeze": follow_squeeze(leg, delta)
		"duct": follow_duct(leg, delta)
		"turn": follow_turn(leg, delta)
		"channel": follow_channel(leg, delta)
		"into_channel": into_channel_now(leg)
		"leap": follow_leap(leg, delta)
		"climb": follow_climb(delta)
		_: next_leg()

## What the next leg wants her heading to be at the end of this one.
func band_heading(leg: Dictionary) -> Vector3:
	var record: Dictionary = shell.patches[int(leg.patch)]
	var s = SHELL.State.new()
	s.patch = int(leg.patch)
	s.u = 0.0 if int(leg.dir) > 0 else float(record.profile.length)
	s.heading = 0.0 if int(leg.dir) > 0 else PI
	return shell.heading_vector(s)

## Whether a survivor stands in her way at their height (M3, M4).
func body_in_way(dir: Vector3, step: float) -> bool:
	if not bodies_ahead.is_valid() or state == null: return false
	var at := anchor()
	var low: Vector3 = at + shell.frame_of(state)[0] * BODY_DEPTH * squash
	var floor_y := float(shell.rooms[room()].get("py", 0.0)) if room() >= 0 else at.y - 3.0
	if low.y > floor_y + SURVIVOR_TOP: return false
	return float(bodies_ahead.call(at, dir, BODY_GAP + step)) < BODY_GAP + step

func follow_tray(leg: Dictionary, delta: float) -> void:
	if state == null or int(shell.patches[state.patch].kind) != SHELL.Kind.TRAY:
		next_leg()
		return
	var to: Vector2 = leg.to
	var here := Vector2(state.u, state.v)
	var left := here.distance_to(to)
	# A waypoint her tray cannot reach (an edge it stops short of): as near
	# as it lets her is there.
	if stall > 0.25: left = 0.0
	var next_band: bool = legs.size() > 1 and String(legs[1].kind) == "band"
	var heading_to := Vector3(to.x - here.x, 0, to.y - here.y)
	if next_band and left <= LOOKAHEAD: ease_heading(band_heading(legs[1]), HEADING_RATE, delta)
	elif heading_to.length() > 1e-6: ease_heading(heading_to, HEADING_RATE, delta)
	var hang_target: float = hang_goal if is_nan(float(leg.hang)) else float(leg.hang)
	ease_hang(hang_target, delta)
	if left <= ARRIVE:
		if next_band:
			band_switch(legs[1], delta)
			return
		speed = 0.0 if legs.size() == 1 else speed
		stall = 0.0
		next_leg()
		return
	var want := pace_now()
	if legs.size() == 1 or next_band: want = minf(want, sqrt(2.0 * ACCEL * left))
	speed = move_toward(speed, want, ACCEL * delta)
	var dir := heading_to.normalized()
	if body_in_way(dir, speed * delta):
		speed = 0.0
		return
	var step := minf(speed * delta, left)
	# Straight to the waypoint; the heading she shows eases after it.
	var shown: float = state.heading
	state.heading = atan2(dir.z, dir.x)
	var moved: float = shell.advance(state, step)
	state.heading = shown
	stall = stall + delta if step > 1e-4 and moved < 1e-5 else 0.0

## At a band's start: heading round to the band's, hang at BAND_CLEAR and
## room under the head; then onto it, or, waiting too long, the door banned.
func band_switch(band_leg: Dictionary, delta: float) -> void:
	speed = 0.0
	var off := ease_heading(band_heading(band_leg), HEADING_RATE, delta)
	ease_hang(SHELL.BAND_CLEAR, delta)
	var ready := off < 0.05 and absf(state.hang - SHELL.BAND_CLEAR) < SHELL.SEAM_TOL and hang_limit >= SHELL.BAND_CLEAR - 1e-6
	if not ready:
		waiting = hang_limit < SHELL.BAND_CLEAR - 1e-6
		wait_clock += delta
		if wait_clock > BAND_WAIT:
			var pair: Vector2i = shell.patches[int(band_leg.patch)].pair
			if pair.x >= 0: routes.ban(pair, ROUTES.BAN_TIME)
			replan(goal)
		return
	stall = 0.0
	state.hang = SHELL.BAND_CLEAR
	var on_band = shell.switch_to(state, int(band_leg.patch))
	if on_band == null:
		replan(goal)
		return
	state = on_band
	state.heading = 0.0 if int(band_leg.dir) > 0 else PI
	next_leg()

func follow_band(leg: Dictionary, delta: float) -> void:
	if state == null or state.patch != int(leg.patch):
		next_leg()
		return
	var record: Dictionary = shell.patches[int(leg.patch)]
	var length: float = record.profile.length
	var dir := int(leg.dir)
	# Its door shutting with her short of half way: back the way she came.
	var pair: Vector2i = record.pair
	if pair.x >= 0 and not bool(leg.get("turned", false)) and not routes.door_open(pair):
		var done: float = state.u / length if dir > 0 else 1.0 - state.u / length
		if done < 0.5:
			leg["turned"] = true
			leg["dir"] = -dir
			dir = -dir
			deferred = goal
	state.heading = 0.0 if dir > 0 else PI
	speed = move_toward(speed, pace_now(), ACCEL * delta)
	shell.advance(state, speed * delta)
	var at_end: bool = state.u >= length - 1e-6 if dir > 0 else state.u <= 1e-6
	if not at_end: return
	var end_room := int(record.rooms[1]) if dir > 0 else int(record.rooms[0])
	if end_room >= 0 and (dir < 0 or int(record.rooms[1]) >= 0):
		var tray = shell.switch_to(state, int(shell.tray_of[end_room]))
		if tray != null: state = tray
	next_leg()

func follow_squeeze(leg: Dictionary, delta: float) -> void:
	var from: Vector3 = leg.from
	var to: Vector3 = leg.to
	if not leg_started:
		leg_started = true
		# From the basis she has, so the turn into the grille's is seen whole.
		leg["basis_from"] = transform().basis.orthonormalized()
		point = from
		state = null
		if leg.has("tile"): tile_turned.emit(int(leg.room), leg.tile, true, bool(leg.into))
		if not bool(leg.into):
			in_duct = false
			hidden = false
			if transit.get("phase", &"") == &"arriving": transit = {}
	var length := maxf(from.distance_to(to), 1e-4)
	leg_clock += SQUEEZE_SPEED * delta
	var t := minf(leg_clock / length, 1.0)
	point = from.lerp(to, t)
	basis = (leg.basis_from as Basis).slerp((leg.basis as Basis).orthonormalized(), minf(1.0, t * 2.0))
	if t < 1.0: return
	if bool(leg.into):
		in_duct = true
		hidden = not (legs.size() > 1 and String(legs[1].kind) == "duct" and not (legs[1].kinds as PackedStringArray).is_empty() and ducts.visible_kinds.has(String(legs[1].kinds[0])))
		duct_point = to
		near_node = ducts.nearest_node(to)
		mouth_exit = int(leg.exit) if legs.size() == 1 else -1
		if leg.has("tile"): tile_turned.emit(int(leg.room), leg.tile, false, true)
	else:
		var next_is_band: bool = legs.size() > 1 and String(legs[1].kind) == "band"
		if next_is_band:
			var band := int(legs[1].patch)
			var record: Dictionary = shell.patches[band]
			var s = shell.band_start(band, int(record.rooms[0]))
			s.u = float(record.profile.length)
			s.heading = PI
			state = s
		else:
			state = shell.state_at(to)
			if state != null:
				var tray: Dictionary = shell.patches[state.patch]
				state.hang = clampf(float(tray.y) - to.y, SHELL.HANG_MIN, SHELL.HANG_MAX)
				shell.set_heading(state, basis.z)
		near_node = -1
	next_leg()

func segment_at(points: PackedVector3Array, metres: float) -> int:
	var left := metres
	for i in range(1, points.size()):
		var piece := points[i].distance_to(points[i - 1])
		if left <= piece: return i - 1
		left -= piece
	return maxi(points.size() - 2, 0)

func follow_duct(leg: Dictionary, delta: float) -> void:
	var points: PackedVector3Array = leg.points
	var kinds: PackedStringArray = leg.kinds
	if not leg_started:
		leg_started = true
		state = null
		in_duct = true
		travelled = 0.0
		# Which node each point is (the steps repeat one).
		var nodes: PackedInt32Array = leg.nodes
		var point_nodes := PackedInt32Array()
		for p in points:
			var best := -1
			var best_d := INF
			for n in nodes:
				var d := Vector2(p.x - ducts.nodes[n].x, p.z - ducts.nodes[n].z).length_squared() + absf(p.y - ducts.nodes[n].y) * 0.01
				if d < best_d:
					best_d = d
					best = n
			point_nodes.append(best)
		leg["point_nodes"] = point_nodes
	if points.size() < 2:
		next_leg()
		return
	var seg := segment_at(points, travelled)
	var kind: String = kinds[seg] if seg < kinds.size() else ""
	var visible: bool = ducts.visible_kinds.has(kind)
	hidden = not visible
	var dir := points[seg + 1] - points[seg]
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() > 1e-6: duct_dir = flat.normalized()
	var run: float = routes.segment_speed(kind)
	if unseen and not visible: run = maxf(run, unseen_duct)
	if visible and bodies_ahead.is_valid() and float(bodies_ahead.call(duct_point, duct_dir, DUCT_GAP + 1.0)) < DUCT_GAP:
		run = 0.0
	speed = run
	travelled = minf(travelled + run * delta, float(leg.length))
	duct_point = ducts.point_along(points, travelled)
	point = duct_point
	near_node = int(leg.point_nodes[mini(seg + 1, points.size() - 1)])
	var want := Basis(Vector3.UP.cross(duct_dir).normalized(), Vector3.UP, duct_dir)
	basis = basis.orthonormalized().slerp(want, minf(1.0, TURN_RATE * delta)) if visible else want
	if travelled >= float(leg.length) - 1e-6:
		near_node = int(leg.point_nodes[points.size() - 1])
		if legs.size() == 1 and goal.has("exit"): mouth_exit = int(goal.exit)
		next_leg()

func follow_turn(leg: Dictionary, delta: float) -> void:
	var want: Basis = leg.basis
	basis = basis.orthonormalized().slerp(want, minf(1.0, TURN_RATE * delta))
	if basis.is_equal_approx(want) or (basis.z - want.z).length() < 0.01: next_leg()

func into_channel_now(leg: Dictionary) -> void:
	if state == null:
		next_leg()
		return
	var entered = shell.switch_to(state, int(leg.patch))
	if entered == null:
		var mouth = shell.channel_mouth(int(leg.patch))
		var from := anchor()
		state = mouth
		log_jump(&"channel", from, anchor())
	else: state = entered
	next_leg()

func follow_channel(leg: Dictionary, delta: float) -> void:
	if state == null or state.patch != int(leg.patch):
		next_leg()
		return
	var record: Dictionary = shell.patches[int(leg.patch)]
	var length: float = record.profile.length
	var v_to := float(leg.v_to)
	var u_goal := float(leg.u_goal)
	speed = move_toward(speed, pace_now(), ACCEL * delta)
	var dv := clampf(v_to - state.v, -speed * delta, speed * delta)
	state.v += dv
	var du := wrapf(u_goal - state.u, -length / 2.0, length / 2.0)
	state.u = fposmod(state.u + clampf(du, -0.7 * delta, 0.7 * delta), length)
	state.hang = move_toward(state.hang, SHELL.CH_HANG, HANG_RATE * delta)
	state.heading = PI / 2.0 if v_to >= state.v else -PI / 2.0
	shell.clamp_state(state)
	if absf(state.v - v_to) < ARRIVE and absf(wrapf(u_goal - state.u, -length / 2.0, length / 2.0)) < ARRIVE: next_leg()

func follow_leap(leg: Dictionary, delta: float) -> void:
	if not leg_started:
		leg_started = true
		state = null
		in_duct = false
		hidden = false
	leg_clock += delta
	var t := minf(leg_clock / float(leg.seconds), 1.0)
	var from: Vector3 = leg.from
	var to: Vector3 = leg.to
	point = from.lerp(to, t) + Vector3.UP * LEAP_RISE * 4.0 * t * (1.0 - t)
	var b_from: Basis = leg.basis_from
	var b_to: Basis = leg.basis_to
	basis = b_from.slerp(b_to, minf(1.0, t * 3.0))
	speed = from.distance_to(to) / float(leg.seconds)
	if t < 1.0: return
	on_floor = true
	floor_point = to
	speed = 0.0
	next_leg()

func follow_climb(delta: float) -> void:
	var above = shell.state_at(floor_point)
	if above == null:
		next_leg()
		return
	above.hang = SHELL.DEFAULT_HANG
	var top: Vector3 = shell.anchor_of(above)
	if not leg_started:
		leg_started = true
		point = floor_point
	var length := maxf(floor_point.distance_to(top), 1e-4)
	leg_clock += CLIMB_SPEED * delta
	var t := minf(leg_clock / length, 1.0)
	point = floor_point.lerp(top, t)
	basis = basis.orthonormalized().slerp(shell.transform_of(above).basis, minf(1.0, TURN_RATE * delta))
	speed = CLIMB_SPEED
	if t < 1.0: return
	on_floor = false
	state = above
	speed = 0.0
	next_leg()
