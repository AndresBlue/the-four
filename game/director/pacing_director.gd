extends Node
## The pacing director: the one who knows where everybody is, and plays the
## creature against them without ever telling it.
##
## It sees the whole floor -- every survivor, whether they hide, whose mind has
## gone, what is left to do (the sets still dark, the drawers with a number,
## the keypad, the refuge) -- and the creature's own state. The creature is
## never given a position. It is given *leads*: a part of the floor to go
## round for a while (hotel_locust.lead_to), a room or three wide, never the
## room anybody is in, never next to somebody hidden, never somewhere it has
## just searched. What it finds there is down to its own eyes and ears. Like
## somebody enjoying moving the beast about to tease the players, but not to
## hand it a kill.
##
## It keeps a MENACE for the team -- how near the creature is, by walking,
## with a hunt counting for more -- and plays in three phases:
##  - BUILD: a lead every LEAD_EVERY seconds, each one nearer the team than
##    the last, from PROWL_START down to its nearest (PROWL_MIN; further in a
##    blackout, and further for every death of the last few minutes).
##  - PEAK: the creature is close (PEAK_MENACE, or PEAK_NEAR metres of walk).
##    Hands off: its senses decide. At most PEAK_MAX seconds of it.
##  - RELIEF: after a chase, a death, a stage given back or too long a peak.
##    It is sent backstage -- to stale rooms far from everybody -- and, if it
##    is closing on a team that is all hidden without having seen anybody,
##    something falls over far away and it goes to look.
##
## The moves of BUILD, never the same one twice running: prowl round a room
## at the distance in hand; wait at something the team still has to do (an
## ambush, never at somebody's side); pass by down a corridor two rooms off;
## a false retreat that sometimes doubles back; knuckles on a door, which is
## only a sound; and, for a team that has not moved for a minute, a prowl at
## a respectful distance with the raps -- staying put brings it prowling, not
## an attack.
##
## A mind that has gone out (sanity at zero) is the director's to know, not
## the creature's: every BURNT_EVERY seconds it is sent to go round the rooms
## near that survivor -- never theirs -- and to open one wardrobe there, drawn.
##
## Only where the creature drives itself (offline and the co-op host); never
## in versus. Quiet during its grace, while it rides after the survivors to
## another wing, and while nobody alive is out in the wing it is in.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
enum Phase { BUILD, PEAK, RELIEF }
const PHASE_NAMES := ["acecho", "pico", "respiro"]
## Seconds between leads while building up.
const LEAD_EVERY := Vector2(25.0, 40.0)
## Metres of walking between the team and the lead: where the build-up starts,
## how much nearer each lead is, and the nearest it gets.
const PROWL_START := 40.0
const PROWL_STEP := 5.0
const PROWL_MIN := 18.0
const PROWL_MIN_DARK := 24.0
## Further, by this much, for each death of the last DEATH_MEMORY seconds.
const DEATH_EASE := 8.0
const DEATH_MEMORY := 300.0
## A lead's rooms: within this of its point, for this long.
const LEAD_RADIUS := 12.0
const LEAD_TIME := 40.0
## Menace: nothing past MENACE_FAR metres of walking, all of it at
## MENACE_NEAR; a hunt counts HOSTILE_MENACE times. It rises fast and ebbs slow.
const MENACE_FAR := 45.0
const MENACE_NEAR := 12.0
const HOSTILE_MENACE := 1.3
const MENACE_RISE := 0.2
const MENACE_EBB := 0.05
const PEAK_MENACE := 0.7
const PEAK_NEAR := 20.0
const PEAK_MAX := 25.0
const PEAK_MAX_TENSE := 15.0
## Rest (RELIEF) after a chase, a death and a stage given back.
const REST_AFTER_CHASE := 30.0
const REST_AFTER_DEATH := 45.0
const REST_AFTER_RESTART := 60.0
## Backstage: at least this far from everybody.
const BACKSTAGE_MIN := 45.0
## The hard rules of a lead (validate_lead): metres from every active survivor
## in a straight line and walking, and from any wardrobe with somebody in it.
const CLEAR_STRAIGHT := 10.0
const CLEAR_WALK := 12.0
const CLEAR_HIDDEN := 8.0
## A team hidden and the creature this near one of them, having seen nobody:
## a distraction at least DISTRACT_FAR away, no more than once a DISTRACT_REST.
const DISTRACT_NEAR := 16.0
const DISTRACT_FAR := 35.0
const DISTRACT_REST := 45.0
## Seconds between the leads towards a burnt-out mind.
const BURNT_EVERY := Vector2(30.0, 45.0)
const BURNT_RADIUS := 14.0
## Nobody has walked into a new room for this long: the team is staying put.
const STALL := 60.0
## A retreat turns round and comes back this often, this long after.
const DOUBLE_BACK := 0.4
const DOUBLE_BACK_AFTER := Vector2(20.0, 30.0)
const SOUNDS := {
	"raps": ["res://assets/audio/events/door_raps_1.wav", "res://assets/audio/events/door_raps_2.wav"],
	"fall": ["res://assets/audio/events/object_fall_1.wav", "res://assets/audio/events/object_fall_2.wav"],
}
## Every decision, as it is taken: {t, phase, kind, point, room, nearest, ok}.
signal decided(entry: Dictionary)
var level
var rng := RandomNumberGenerator.new()
var clock := 0.0
var phase := Phase.BUILD
var phase_since := 0.0
var menace := 0.0
var rest_until := 0.0
var next_lead := 0.0
var prowl := PROWL_START
var last_kind := ""
var last_hostile := -INF
var was_hostile := false
var last_distraction := -INF
var burnt_next := 0.0
var deaths: Array = []
var alive_before := {}
var last_new_room := 0.0
var visited := {}
## A retreat that will double back: {point, at}.
var coming_back := {}
## The lead in hand, as given: {kind, point, until, target}.
var current := {}
## Every decision, for tests, the observer and the bots' recorder.
var history: Array = []
## Tests: leads as soon as they are allowed, and every roll wins.
var force := false
var roll_clock := 0.0

func setup(owner_level, seed_value: int) -> void:
	level = owner_level
	rng.seed = hash([seed_value, "director"])
	next_lead = rng.randf_range(LEAD_EVERY.x, LEAD_EVERY.y)
	burnt_next = rng.randf_range(BURNT_EVERY.x, BURNT_EVERY.y)

func _physics_process(delta: float) -> void:
	if level == null or level.session.state != level.session.State.PLAYING: return
	tick(delta)

func creature():
	return level.locust if is_instance_valid(level.locust) else null

func hostile() -> bool:
	var it = creature()
	return it != null and it.mode in [it.Mode.ALERT, it.Mode.CHASE, it.Mode.WINDUP, it.Mode.RECOVER, it.Mode.EXECUTE]

## Everybody out there it plays for: alive, outside the refuge, not in a car.
func active_survivors() -> Array:
	return level.survivors().filter(func(body): return level.survivor_active(body))

## A stage given back: a long rest before anything is played again.
func on_restart() -> void:
	rest(REST_AFTER_RESTART)
	coming_back = {}

func rest(seconds: float) -> void:
	rest_until = maxf(rest_until, clock + seconds)
	set_phase(Phase.RELIEF)
	prowl = PROWL_START

func set_phase(next: Phase) -> void:
	if next == phase: return
	phase = next
	phase_since = clock
	say("fase", {"phase": PHASE_NAMES[phase]})

## Nothing to direct: the creature is not its own, is waiting out its grace,
## is on its way after the survivors to another wing, or nobody alive is out
## in the wing it is in.
func silent() -> bool:
	var it = creature()
	if it == null or it.control != "ai" or it.grace > 0.0 or it.lift_bound: return true
	if level.lifts.creature_car(level.session.stage) >= 0: return true
	var wing := wing_of(it.global_position)
	return not active_survivors().any(func(body): return wing_of(body.global_position) == wing)

func wing_of(point: Vector3) -> int:
	return int(FLOOR.room_at(level.manifest.rooms, point).get("wing", -1))

func room_id(point: Vector3) -> int:
	return int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1))

## Metres of walking between two rooms (INF when there is no way).
func walk(from_room: int, to_room: int) -> float:
	var it = creature()
	if from_room < 0 or to_room < 0 or it == null: return INF
	return float(it.walk_from(from_room).get(to_room, INF))

func tick(delta: float) -> void:
	clock += delta
	watch_team()
	var it = creature()
	var now_hostile := hostile()
	if now_hostile:
		last_hostile = clock
		set_phase(Phase.PEAK)
	elif was_hostile:
		# The hunt is over: a rest before anything else.
		rest(REST_AFTER_CHASE)
	was_hostile = now_hostile
	update_menace(delta)
	if silent() or now_hostile: return
	match phase:
		Phase.PEAK:
			if clock - phase_since > peak_limit(): rest(REST_AFTER_CHASE)
			elif menace < PEAK_MENACE * 0.6 and nearest_walk() > PEAK_NEAR * 1.5: set_phase(Phase.BUILD)
		Phase.RELIEF:
			if clock >= rest_until:
				set_phase(Phase.BUILD)
				next_lead = clock + rng.randf_range(4.0, 10.0)
		Phase.BUILD:
			if menace >= PEAK_MENACE or nearest_walk() < PEAK_NEAR: set_phase(Phase.PEAK)
	roll_clock -= delta
	if roll_clock > 0.0 and not force: return
	roll_clock = 1.0
	if it.mode != it.Mode.PATROL and it.mode != it.Mode.SEARCH: return
	if burnt_lead(): return
	match phase:
		Phase.RELIEF:
			backstage()
			distraction()
		Phase.BUILD:
			if not coming_back.is_empty() and clock >= float(coming_back.at):
				var back: Vector3 = coming_back.point
				coming_back = {}
				# Only if it is still fair now: somebody may be standing there.
				if validate_lead(back, true): play("vuelve", back, LEAD_RADIUS, true)
			elif force or clock >= next_lead: build()

## Who is alive, who died since the last look, and whether the team has been
## anywhere new lately.
func watch_team() -> void:
	for seat in level.session.participants:
		var alive: bool = int(level.session.participants[seat]) != int(level.session.Life.DEAD)
		if alive_before.get(seat, true) and not alive:
			deaths.append(clock)
			rest(REST_AFTER_DEATH)
		alive_before[seat] = alive
	while not deaths.is_empty() and clock - float(deaths[0]) > DEATH_MEMORY: deaths.pop_front()
	for body in active_survivors():
		var here := room_id(body.global_position)
		if here >= 0 and not visited.has(here):
			visited[here] = true
			last_new_room = clock

func stalled() -> bool:
	return clock - maxf(last_new_room, last_hostile) >= STALL

func peak_limit() -> float:
	return PEAK_MAX_TENSE if level.hotel.dark or not deaths.is_empty() else PEAK_MAX

## The nearest it lets a lead come to the team.
func nearest_prowl() -> float:
	return (PROWL_MIN_DARK if level.hotel.dark else PROWL_MIN) + DEATH_EASE * deaths.size()

## Metres of walking from the creature to the nearest survivor out there.
func nearest_walk() -> float:
	var it = creature()
	if it == null: return INF
	var from := room_id(it.global_position)
	var best := INF
	for body in active_survivors(): best = minf(best, walk(from, room_id(body.global_position)))
	return best

func update_menace(delta: float) -> void:
	var it = creature()
	var target := 0.0
	if it != null:
		var from := room_id(it.global_position)
		for body in active_survivors():
			var metres := walk(from, room_id(body.global_position))
			if metres == INF: continue
			target = maxf(target, clampf((MENACE_FAR - metres) / (MENACE_FAR - MENACE_NEAR), 0.0, 1.0))
		if hostile(): target = minf(1.0, target * HOSTILE_MENACE + 0.3)
	menace = move_toward(menace, target, (MENACE_RISE if target > menace else MENACE_EBB) * delta)

## The survivor the next lead is played around: somebody out and about, not
## hidden, and the less pressed the likelier -- whoever has had the easiest
## time of it gets the visit.
func pick_target() -> Node3D:
	var it = creature()
	var from := room_id(it.global_position)
	var best: Node3D = null
	var best_score := -INF
	for body in active_survivors():
		if body.hidden: continue
		var score := minf(walk(from, room_id(body.global_position)), 90.0) + rng.randf_range(0.0, 25.0)
		if score > best_score:
			best_score = score
			best = body
	return best

## BUILD: a move, never the one just played.
func build() -> void:
	var target := pick_target()
	if target == null:
		next_lead = clock + 5.0
		return
	var moves: Array = []
	if stalled(): moves = [["quieto", 3.0]]
	else: moves = [["merodea", 3.0], ["emboscada", 2.0], ["pasa", 1.5], ["retirada", 1.0], ["golpes", 0.7]]
	moves = moves.filter(func(move): return move[0] != last_kind)
	var total := 0.0
	for move in moves: total += float(move[1])
	var roll := rng.randf() * total
	var kind: String = moves[0][0]
	for move in moves:
		roll -= float(move[1])
		if roll <= 0.0:
			kind = move[0]
			break
	var ok := false
	match kind:
		"merodea": ok = prowl_round(target, prowl, "merodea")
		"emboscada": ok = ambush(target)
		"pasa": ok = pass_by(target)
		"retirada": ok = retreat()
		"golpes": ok = raps(target)
		"quieto":
			ok = prowl_round(target, maxf(prowl, 25.0 + rng.randf_range(0.0, 5.0)), "quieto")
			raps(target)
	# Whatever could not be had this time, a plain prowl will do.
	if not ok and kind != "merodea": ok = prowl_round(target, prowl, "merodea")
	next_lead = clock + rng.randf_range(LEAD_EVERY.x, LEAD_EVERY.y) if ok else clock + 3.0
	if ok:
		last_kind = kind
		prowl = maxf(nearest_prowl(), prowl - PROWL_STEP)

## A room `metres` of walking from the target (give or take), the lead
## round it.
func prowl_round(target: Node3D, metres: float, kind: String) -> bool:
	var from := room_id(target.global_position)
	var candidates: Array = []
	for room in level.manifest.rooms:
		var gap := walk(from, int(room.id))
		if gap == INF or absf(gap - metres) > 7.0: continue
		var centre := FLOOR.position_of(room)
		if validate_lead(centre): candidates.append(centre)
	if candidates.is_empty(): return false
	return play(kind, candidates[rng.randi_range(0, candidates.size() - 1)], LEAD_RADIUS, false, target)

## Something the team still has to do, far enough from all of them: it waits
## there a while.
func ambush(target: Node3D) -> bool:
	var spots: Array = []
	for index in level.stage_televisions():
		var set = level.televisions[index]
		if is_instance_valid(set) and not set.on: spots.append(set.global_position)
	if int(level.session.stage) >= 3:
		for piece in level.containers:
			if is_instance_valid(piece) and int(piece.digit) >= 0 and not piece.searched: spots.append(piece.global_position)
		if is_instance_valid(level.lock) and not level.code_entered: spots.append(level.lock.global_position)
	var from := room_id(target.global_position)
	var fair: Array = []
	for spot in spots:
		var gap := walk(from, room_id(spot))
		if gap >= nearest_prowl() and gap <= 70.0 and validate_lead(spot): fair.append(spot)
	if fair.is_empty(): return false
	return play("emboscada", fair[rng.randi_range(0, fair.size() - 1)], 8.0, false, target, rng.randf_range(15.0, 25.0))

## Down a corridor a couple of rooms from the target, and on.
func pass_by(target: Node3D) -> bool:
	var from := room_id(target.global_position)
	var corridors: Array = []
	for room in level.manifest.rooms:
		if not bool(room.get("corridor", false)): continue
		var gap := walk(from, int(room.id))
		var centre := FLOOR.position_of(room)
		if gap >= maxf(nearest_prowl(), 14.0) and gap <= 28.0 and validate_lead(centre): corridors.append(centre)
	if corridors.is_empty(): return false
	return play("pasa", corridors[rng.randi_range(0, corridors.size() - 1)], 4.0, true, target)

## Away from everybody for a while -- and, now and then, back again.
func retreat() -> bool:
	var it = creature()
	var left_from: Vector3 = it.global_position
	if not far_lead("retirada"): return false
	if rng.randf() < DOUBLE_BACK and validate_lead(left_from, true): coming_back = {"point": left_from, "at": clock + rng.randf_range(DOUBLE_BACK_AFTER.x, DOUBLE_BACK_AFTER.y)}
	return true

## RELIEF: the creature to stale rooms far from everybody, once per rest.
func backstage() -> void:
	if String(current.get("kind", "")) in ["entre bastidores"] and clock < float(current.get("until", 0.0)): return
	far_lead("entre bastidores")

func far_lead(kind: String) -> bool:
	var it = creature()
	var wing := wing_of(it.global_position)
	var bodies := active_survivors()
	var candidates: Array = []
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != wing: continue
		var centre := FLOOR.position_of(room)
		var clear := true
		for body in bodies:
			if walk(room_id(body.global_position), int(room.id)) < BACKSTAGE_MIN:
				clear = false
				break
		if clear and validate_lead(centre): candidates.append(centre)
	if candidates.is_empty(): return false
	return play(kind, candidates[rng.randi_range(0, candidates.size() - 1)], LEAD_RADIUS, false, null, LEAD_TIME * 1.5)

## The team is all hidden and the creature, having seen nobody, is walking
## up to one of them: something falls over far away, and it goes to look.
## The director plays with them; it does not hand them over.
func distraction() -> void:
	var it = creature()
	if clock - last_distraction < DISTRACT_REST or it.detection >= it.SUSPICION: return
	var bodies := active_survivors()
	if bodies.is_empty() or not bodies.all(func(body): return body.hidden): return
	var from := room_id(it.global_position)
	if not bodies.any(func(body): return walk(from, room_id(body.global_position)) < DISTRACT_NEAR): return
	var spots: Array = []
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != wing_of(it.global_position): continue
		var centre := FLOOR.position_of(room)
		if centre.distance_to(it.global_position) >= DISTRACT_FAR and walk(from, int(room.id)) < 70.0 and validate_lead(centre): spots.append(centre)
	if spots.is_empty(): return
	var map: RID = level.get_world_3d().navigation_map
	var point := FLOOR.closest(map, spots[rng.randi_range(0, spots.size() - 1)])
	var sound := pick("fall")
	level.world_audio.play_at(sound, point + Vector3.UP * 0.4, -2.0, RID(), 0.0)
	level.match_net.world_sound(sound, point + Vector3.UP * 0.4, -2.0, 0.0)
	it.investigate(point)
	last_distraction = clock
	say("distracción", {"point": point})

## Knuckles on a door on the target's planta, a room or two off. A sound, and
## nothing else: the creature is not moved by it.
func raps(target: Node3D) -> bool:
	var planta := FLOOR.planta_of(target.global_position.y)
	var doors: Array = level.hotel.doors.filter(func(door):
		var gap: float = door.doorway.distance_to(target.global_position)
		return gap >= 9.0 and gap <= 26.0 and FLOOR.planta_of(door.doorway.y) == planta and not level.point_in_refuge(door.doorway))
	if doors.is_empty(): return false
	var door = doors[rng.randi_range(0, doors.size() - 1)]
	var point: Vector3 = door.doorway + Vector3.UP * 1.3
	var sound := pick("raps")
	level.world_audio.play_at(sound, point, -8.0, door.get_rid(), 0.0)
	level.match_net.world_sound(sound, point, -8.0, 0.0)
	say("golpes", {"point": point})
	return true

## A burnt-out mind: now and then the creature goes round the rooms near that
## survivor (never theirs) and opens one wardrobe there. The one exception to
## "never towards somebody hidden": burning out is what it costs.
func burnt_lead() -> bool:
	if clock < burnt_next: return false
	var marked: Array = active_survivors().filter(func(body): return bool(body.get("burnt")))
	if marked.is_empty(): return false
	var it = creature()
	if it.mode != it.Mode.PATROL: return false
	burnt_next = clock + rng.randf_range(BURNT_EVERY.x, BURNT_EVERY.y)
	var body: Node3D = marked[rng.randi_range(0, marked.size() - 1)]
	var theirs := room_id(body.global_position)
	if theirs < 0 or wing_of(body.global_position) != wing_of(it.global_position): return false
	var near: Array = []
	for first in level.manifest.adjacency[theirs]:
		for second in [int(first)] + Array(level.manifest.adjacency[int(first)]):
			var id := int(second)
			if id != theirs and not near.has(id) and not level.off_limits_rooms().has(id) and not FLOOR.is_void(level.manifest.rooms[id]): near.append(id)
	if near.is_empty(): return false
	var point := FLOOR.position_of(level.manifest.rooms[near[rng.randi_range(0, near.size() - 1)]])
	return play("cordura", point, BURNT_RADIUS, false, body, LEAD_TIME, true)

## The hard rules of a lead, all of them tested: in the creature's wing, not a
## refuge or a lift lobby, not in anybody's room and clear of everybody by
## CLEAR_STRAIGHT and CLEAR_WALK, clear of anybody hidden by CLEAR_HIDDEN, and
## not in the rooms it has just searched (a retreat's way back may be).
func validate_lead(point: Vector3, allow_searched := false) -> bool:
	var it = creature()
	if it == null: return false
	var room := FLOOR.room_at(level.manifest.rooms, point)
	if room.is_empty() or FLOOR.is_void(room) or level.off_limits_rooms().has(int(room.id)): return false
	if int(room.get("wing", -1)) != wing_of(it.global_position): return false
	for body in level.survivors():
		if int(level.session.participants.get(int(body.slot), level.session.Life.DEAD)) == int(level.session.Life.DEAD): continue
		var theirs := room_id(body.global_position)
		if theirs == int(room.id): return false
		if body.global_position.distance_to(point) < CLEAR_STRAIGHT: return false
		if walk(theirs, int(room.id)) < CLEAR_WALK: return false
		if body.hidden and body.global_position.distance_to(point) < CLEAR_HIDDEN + LEAD_RADIUS: return false
	if not allow_searched and float(it.searched_until.get(int(room.id), -INF)) > it.clock: return false
	return true

## The rooms of a lead nobody is standing in, and none next to a hidden
## survivor (unless the lead is for a burnt-out mind).
func lead_rooms_to_avoid(burnt: bool) -> Array:
	var avoid: Array = []
	for body in level.survivors():
		if int(level.session.participants.get(int(body.slot), level.session.Life.DEAD)) == int(level.session.Life.DEAD): continue
		var theirs := room_id(body.global_position)
		if theirs < 0: continue
		if not burnt or not bool(body.get("burnt")): avoid.append(theirs)
		if body.hidden and not burnt:
			for other in level.manifest.adjacency[theirs]: avoid.append(int(other))
	return avoid

## Gives the creature the lead, and says so.
func play(kind: String, point: Vector3, radius: float, once: bool, target: Node3D = null, seconds := LEAD_TIME, sniff := false) -> bool:
	var it = creature()
	if it == null: return false
	var ok: bool = it.lead_to(point, radius, seconds, kind, once, lead_rooms_to_avoid(sniff), sniff)
	if ok: current = {"kind": kind, "point": point, "until": clock + seconds, "target": String(target.name) if target != null else ""}
	say(kind, {"point": point, "ok": ok, "target": String(target.name) if target != null else ""})
	return ok

func say(kind: String, data := {}) -> void:
	var entry := {"t": clock, "phase": PHASE_NAMES[phase], "kind": kind, "menace": snappedf(menace, 0.01)}
	entry.merge(data, true)
	if data.has("point"):
		var room := FLOOR.room_at(level.manifest.rooms, data.point)
		entry["room"] = int(room.get("id", -1))
		entry["nearest"] = snappedf(nearest_to(data.point), 0.1)
	history.append(entry)
	decided.emit(entry)
	var view = level.get("observer_view")
	if view != null and is_instance_valid(view) and kind != "fase": view.note("director · %s%s" % [kind, (" → sala %d" % int(entry.get("room", -1))) if entry.has("room") else ""])
	elif view != null and is_instance_valid(view): view.note("director · %s" % String(data.get("phase", "")))

## Metres in a straight line from a point to the nearest survivor alive.
func nearest_to(point: Vector3) -> float:
	var best := INF
	for body in level.survivors():
		if int(level.session.participants.get(int(body.slot), level.session.Life.DEAD)) != int(level.session.Life.DEAD): best = minf(best, body.global_position.distance_to(point))
	return best

## What the observer's panel shows of it.
func status_lines() -> Array:
	var lines: Array = ["DIRECTOR · %s · amenaza %0.2f%s" % [PHASE_NAMES[phase], menace, " · callado" if silent() else ""]]
	if phase == Phase.RELIEF: lines.append("  descanso %0.0f s más" % maxf(0.0, rest_until - clock))
	elif phase == Phase.BUILD: lines.append("  próxima pista en %0.0f s · a %0.0f m del equipo" % [maxf(0.0, next_lead - clock), prowl])
	if not current.is_empty() and clock < float(current.until): lines.append("  %s · sala %d%s · %0.0f s" % [current.kind, room_id(current.point), (" · por " + String(current.target)) if not String(current.target).is_empty() else "", float(current.until) - clock])
	if not deaths.is_empty(): lines.append("  %d muertes recientes: más lejos" % deaths.size())
	return lines

func pick(type: String) -> String:
	var options: Array = SOUNDS[type]
	return options[rng.randi_range(0, options.size() - 1)]
