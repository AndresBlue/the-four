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
## And it keeps count of what the team has been through (STRAIN): a hunt, the
## creature close by, somebody shut in a wardrobe with it outside. On the
## easier difficulties (`calm`) that is what a rest is measured by -- the
## more they went through, the longer they are left alone to look round --
## and enough of it earns one without a hunt ever having happened: it used to
## rest only after a chase, and whoever lost it by hiding had it back at the
## door within the minute. While such a rest lasts the creature is kept off
## the way to what they still have to do, not only far from them. Alone, the
## whole of its attention falls on one person, so everything is spaced out
## (`solo_ease`).
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
## Backstage: at least this far from everybody, and not by way of anybody
## (its walk there no more than this short of one through their room).
const BACKSTAGE_MIN := 45.0
const BY_THE_WAY := 12.0
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

## The numbers it plays by: the constants above are the game as it was (the
## difficulty "desafiante"), and the floor's difficulty writes these over
## them (game/floors/difficulty.gd, through tune()). The hard limits -- never
## anybody's room, never nearer than CLEAR_STRAIGHT and CLEAR_WALK -- are not
## among them: no difficulty moves those.
var lead_every := LEAD_EVERY
var prowl_min := PROWL_MIN
var prowl_min_dark := PROWL_MIN_DARK
var peak_max := PEAK_MAX
var peak_tense := PEAK_MAX_TENSE
var rest_chase := REST_AFTER_CHASE
var rest_death := REST_AFTER_DEATH
var death_ease := DEATH_EASE
var double_back := DOUBLE_BACK
var distract_rest := DISTRACT_REST
var burnt_every := BURNT_EVERY
## Encounters (docs/DIFFICULTY.md): after this long with no sign of the
## creature for somebody out there (run_ledger.since_sign), it is brought
## across their view; and how much it likes doing that anyway. Both nought
## for "desafiante", the director as it was.
var encounter_every := 0.0
var cross_weight := 0.0
var next_cross := 0.0
## The load on the team, and what it buys (docs/DIFFICULTY.md, section 4):
## `calm`, the seconds a full load adds to a rest (nought: rests are what they
## were, "desafiante"); `solo_ease`, how much further apart everything is
## played for somebody alone; `ambush_weight`, how much it likes waiting at
## something the team still has to do.
var calm := 0.0
var solo_ease := 1.0
var ambush_weight := 2.0
## 0 untouched, 1 as much as anybody should take in one go. A whole hunt of
## 25 s fills it; so does a minute with the creature at their heels, or half
## a minute shut in a wardrobe with it within HIDE_NEAR metres of walking.
## It ebbs away in a minute and a half of being left alone.
var strain := 0.0
const STRAIN_HUNT := 1.0 / 25.0
const STRAIN_NEAR := 1.0 / 60.0
const STRAIN_HIDE := 1.0 / 30.0
const STRAIN_EBB := 1.0 / 90.0
## Enough, hunt or no hunt: a rest is owed. And the least load a peak that
## simply ebbed away has to leave behind for it to count as an encounter.
const STRAIN_FULL := 0.85
const STRAIN_SOME := 0.35
const HIDE_NEAR := 20.0
## What is left of the load once it has been paid for with a rest.
const STRAIN_KEPT := 0.25
## How much of its hearing the creature keeps during a rest that was earned.
const REST_HEARING := 0.5
## How far (metres of walking) and how far in plain sight a crossing is put,
## and how long before another is forced.
const CROSS_NEAR := 15.0
const CROSS_FAR := 32.0
const CROSS_SIGHT := 30.0
const CROSS_REST := 30.0

func setup(owner_level, seed_value: int) -> void:
	level = owner_level
	rng.seed = hash([seed_value, "director"])
	next_lead = rng.randf_range(lead_every.x, lead_every.y)
	burnt_next = rng.randf_range(burnt_every.x, burnt_every.y)

## A profile of the difficulties (the director's part of it), given before
## setup() draws its first lead. The darkness keeps it as much further off as
## it always did.
func tune(profile: Dictionary) -> void:
	lead_every = Vector2(float(profile.lead_every[0]), float(profile.lead_every[1]))
	prowl_min = float(profile.prowl_min)
	prowl_min_dark = prowl_min + (PROWL_MIN_DARK - PROWL_MIN)
	peak_max = float(profile.peak_max)
	peak_tense = float(profile.peak_tense)
	rest_chase = float(profile.rest_chase)
	rest_death = float(profile.rest_death)
	death_ease = float(profile.death_ease)
	double_back = float(profile.double_back)
	distract_rest = float(profile.distract_rest)
	burnt_every = Vector2(float(profile.burnt_every[0]), float(profile.burnt_every[1]))
	encounter_every = float(profile.encounter_every)
	cross_weight = float(profile.cross)
	calm = float(profile.get("calm", 0.0))
	solo_ease = float(profile.get("solo_ease", 1.0))
	ambush_weight = float(profile.get("ambush", 2.0))

func _physics_process(delta: float) -> void:
	if level == null or level.session.state != level.session.State.PLAYING: return
	tick(delta)

func creature():
	return level.locust if is_instance_valid(level.locust) else null

func hostile() -> bool:
	var it = creature()
	return it != null and it.mode in [it.Mode.ALERT, it.Mode.CHASE, it.Mode.WINDUP, it.Mode.RECOVER, it.Mode.EXECUTE, it.Mode.LURK]

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
	# Where rests are earned, the encounter it owes them is not owed the
	# moment the rest is over: having been left alone is the point of it.
	if calm > 0.0 and encounter_every > 0.0: next_cross = maxf(next_cross, rest_until + encounter_every * spacing() * 0.5)

## A rest for what the team has just been through: `base` seconds and, on the
## easier difficulties, up to `calm` more by how much that was; longer alone.
## The load is paid for with it.
func breathe(base: float) -> void:
	rest((base + calm * strain) * spacing())
	strain *= STRAIN_KEPT

## How much further apart everything is played for a small team: `solo_ease`
## for one, half of that for two, nothing from three up.
func spacing() -> float:
	return lerpf(solo_ease, 1.0, clampf((int(level.session.roster_count) - 1) / 2.0, 0.0, 1.0))

## The load: up with the creature near, faster with a hunt or with somebody
## hidden while it is close; down when they are left alone.
func update_strain(delta: float) -> void:
	var rise := 0.0
	if hostile(): rise = STRAIN_HUNT
	elif menace > 0.15:
		rise = menace * STRAIN_NEAR
		if pressed_in_hiding(): rise += STRAIN_HIDE
	if rise > 0.0: strain = minf(1.0, strain + rise * delta)
	else: strain = maxf(0.0, strain - STRAIN_EBB * delta)

## Somebody shut in a wardrobe with the creature within HIDE_NEAR metres of
## walking of them.
func pressed_in_hiding() -> bool:
	var it = creature()
	if it == null: return false
	var from := room_id(it.global_position)
	return active_survivors().any(func(body): return body.hidden and walk(from, room_id(body.global_position)) < HIDE_NEAR)

## The rooms the team is making for: the stage's refuge, its sets still dark
## and, on the last stage, the furniture with a number in it and the keypad.
func goal_rooms() -> Array:
	var rooms: Array = [int(level.refuge_room())]
	for index in level.stage_televisions():
		var set = level.televisions[index]
		if is_instance_valid(set) and not set.on: rooms.append(room_id(set.global_position))
	if int(level.session.stage) >= 3:
		for piece in level.containers:
			if is_instance_valid(piece) and int(piece.digit) >= 0 and not piece.searched: rooms.append(room_id(piece.global_position))
		if is_instance_valid(level.lock) and not level.code_entered: rooms.append(room_id(level.lock.global_position))
	return rooms.filter(func(id): return id >= 0)

## Whether a room stands between somebody and something they are making for:
## on a way there no more than BY_THE_WAY longer than the shortest.
func in_the_way(room: int, goals: Array) -> bool:
	for body in active_survivors():
		var theirs := room_id(body.global_position)
		for goal in goals:
			var straight := walk(theirs, int(goal))
			if straight == INF: continue
			if walk(theirs, room) + walk(room, int(goal)) < straight + BY_THE_WAY: return true
	return false

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
		breathe(rest_chase)
	was_hostile = now_hostile
	update_menace(delta)
	update_strain(delta)
	# Resting somebody who earned it, it hears half as far: the rest is for
	# looking round, and looking round is not silent.
	if it != null and calm > 0.0: it.dull = REST_HEARING if phase == Phase.RELIEF and not now_hostile else 1.0
	if silent() or now_hostile: return
	match phase:
		Phase.PEAK:
			if clock - phase_since > peak_limit(): breathe(rest_chase)
			elif menace < PEAK_MENACE * 0.6 and nearest_walk() > PEAK_NEAR * 1.5:
				# It came close and went: where a rest is measured by what
				# they went through, that was an encounter too.
				if calm > 0.0 and strain >= STRAIN_SOME: breathe(rest_chase)
				else: set_phase(Phase.BUILD)
		Phase.RELIEF:
			if clock >= rest_until:
				set_phase(Phase.BUILD)
				# After a rest that was earned, the build-up takes its time
				# to start again.
				next_lead = clock + (rng.randf_range(4.0, 10.0) if calm <= 0.0 else rng.randf_range(lead_every.x, lead_every.y) * 0.5 * spacing())
		Phase.BUILD:
			if calm > 0.0 and strain >= STRAIN_FULL: breathe(rest_chase)
			elif menace >= PEAK_MENACE or nearest_walk() < PEAK_NEAR: set_phase(Phase.PEAK)
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
			elif encounter_due(): pass
			elif force or clock >= next_lead: build()

## Who is alive, who died since the last look, and whether the team has been
## anywhere new lately.
func watch_team() -> void:
	for seat in level.session.participants:
		var alive: bool = int(level.session.participants[seat]) != int(level.session.Life.DEAD)
		if alive_before.get(seat, true) and not alive:
			deaths.append(clock)
			rest(rest_death)
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
	return peak_tense if level.hotel.dark or not deaths.is_empty() else peak_max

## The nearest it lets a lead come to the team.
func nearest_prowl() -> float:
	return (prowl_min_dark if level.hotel.dark else prowl_min) + death_ease * deaths.size()

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

## Whoever out there has gone longest without a sign of the creature, if it
## has been encounter_every: the creature is brought across their view.
## True when it was.
func encounter_due() -> bool:
	if encounter_every <= 0.0 or clock < next_cross: return false
	var quietest: Node3D = null
	var longest := 0.0
	for body in active_survivors():
		if body.hidden: continue
		var quiet := float(level.ledger.since_sign.get(int(body.slot), 0.0))
		if quiet > longest:
			longest = quiet
			quietest = body
	if quietest == null or longest < encounter_every * spacing(): return false
	# Brought across their view, that was the encounter, whether they looked
	# or not: somebody who never looks at it (who hides the moment they hear
	# it) was owed another every CROSS_REST for ever, and it never left their
	# side -- the same three rooms for five minutes at a time. Where rests
	# are earned, the next is a whole interval away.
	next_cross = clock + (CROSS_REST if calm <= 0.0 else maxf(CROSS_REST, encounter_every * spacing()))
	if not cross(quietest): return false
	last_kind = "cruce"
	next_lead = clock + rng.randf_range(lead_every.x, lead_every.y) * spacing()
	return true

## Across somebody's view: a room CROSS_NEAR to CROSS_FAR metres of walking
## from them, that they can see from where they stand (nothing solid between
## their eyes and it), ahead of them if there is one; it walks in there. The
## usual rules hold (validate_lead): never their room, never close -- but a
## room it has just searched will do. With nothing in sight (a room with its
## doors shut), down a corridor near them, or a prowl round them close.
func cross(target: Node3D) -> bool:
	if not "camera" in target or not is_instance_valid(target.camera): return pass_by(target)
	var eye: Vector3 = target.camera.global_position
	var ahead: Vector3 = -target.camera.global_basis.z
	ahead.y = 0.0
	if ahead.length() < 0.1: return pass_by(target)
	ahead = ahead.normalized()
	var from := room_id(target.global_position)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var in_front: Array = []
	var around: Array = []
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		var gap := walk(from, int(room.id))
		if gap == INF or gap < CROSS_NEAR or gap > CROSS_FAR: continue
		var centre := FLOOR.position_of(room)
		var look: Vector3 = centre + Vector3(0, 1.4, 0) - eye
		if look.length() > CROSS_SIGHT or not validate_lead(centre, true): continue
		var query := PhysicsRayQueryParameters3D.create(eye, eye + look, 1 | 8)
		query.exclude = [target.get_rid()]
		if not space.intersect_ray(query).is_empty(): continue
		if Vector3(look.x, 0.0, look.z).normalized().dot(ahead) > 0.5: in_front.append(centre)
		else: around.append(centre)
	var spots: Array = in_front if not in_front.is_empty() else around
	if spots.is_empty(): return pass_by(target) or prowl_round(target, (CROSS_NEAR + CROSS_FAR) * 0.5, "cruce")
	return play("cruce", spots[rng.randi_range(0, spots.size() - 1)], 4.0, true, target, 15.0)

## BUILD: a move, never the one just played.
func build() -> void:
	var target := pick_target()
	if target == null:
		next_lead = clock + 5.0
		return
	var moves: Array = []
	# A team that stays put brings it prowling -- but where rests are earned,
	# somebody who has not moved is likelier frightened than idle, and gets
	# the knuckles on a door and nothing else.
	if stalled() and calm > 0.0 and strain >= STRAIN_SOME:
		# Not moving because of what they have just been through: nothing at
		# all, not even the knuckles, until the load has ebbed.
		next_lead = clock + rng.randf_range(lead_every.x, lead_every.y) * spacing()
		return
	if stalled(): moves = [["quieto", 3.0]] if calm <= 0.0 else [["golpes", 1.0]]
	else: moves = [["merodea", 3.0], ["emboscada", ambush_weight], ["pasa", 1.5], ["retirada", 1.0], ["golpes", 0.7]]
	moves = moves.filter(func(move): return float(move[1]) > 0.0)
	# Where the difficulty likes it brought across somebody's view.
	if cross_weight > 0.0 and not stalled(): moves.append(["cruce", cross_weight])
	# Never the one just played -- unless it is the only one there is.
	var fresh: Array = moves.filter(func(move): return move[0] != last_kind)
	if not fresh.is_empty(): moves = fresh
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
		"cruce": ok = cross(target)
		"quieto":
			ok = prowl_round(target, maxf(prowl, 25.0 + rng.randf_range(0.0, 5.0)), "quieto")
			raps(target)
	# Whatever could not be had this time, a plain prowl will do.
	if not ok and kind != "merodea": ok = prowl_round(target, prowl, "merodea")
	next_lead = clock + rng.randf_range(lead_every.x, lead_every.y) * spacing() if ok else clock + 3.0
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
	if rng.randf() < double_back and validate_lead(left_from, true): coming_back = {"point": left_from, "at": clock + rng.randf_range(DOUBLE_BACK_AFTER.x, DOUBLE_BACK_AFTER.y)}
	return true

## RELIEF: the creature to stale rooms far from everybody, once per rest.
func backstage() -> void:
	if String(current.get("kind", "")) in ["entre bastidores"] and clock < float(current.get("until", 0.0)): return
	far_lead("entre bastidores")

## A lead far from everybody -- and got to without going by any of them: the
## way to a room far off could run straight through the team, and a rest
## that walked the creature past them was no rest (the test bots were
## caught on the way to "backstage" more than anywhere else).
func far_lead(kind: String) -> bool:
	var it = creature()
	var wing := wing_of(it.global_position)
	var from := room_id(it.global_position)
	var bodies := active_survivors()
	var candidates: Array = []
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != wing: continue
		var centre := FLOOR.position_of(room)
		var there := walk(from, int(room.id))
		var clear := true
		for body in bodies:
			var theirs := room_id(body.global_position)
			if walk(theirs, int(room.id)) < BACKSTAGE_MIN or there >= walk(from, theirs) + walk(theirs, int(room.id)) - BY_THE_WAY:
				clear = false
				break
		if clear and validate_lead(centre): candidates.append(centre)
	if candidates.is_empty(): return false
	# A rest that was earned leaves the way clear too: far from everybody is
	# not enough if it is the corridor to the refuge, or the room of a set
	# they have yet to light. (When every far room is on some way, far will
	# have to do.)
	if calm > 0.0:
		var goals := goal_rooms()
		var open: Array = candidates.filter(func(centre): return not in_the_way(room_id(centre), goals))
		if not open.is_empty(): candidates = open
	return play(kind, candidates[rng.randi_range(0, candidates.size() - 1)], LEAD_RADIUS, false, null, LEAD_TIME * 1.5)

## The team is all hidden and the creature, having seen nobody, is walking
## up to one of them: something falls over far away, and it goes to look.
## The director plays with them; it does not hand them over.
func distraction() -> void:
	var it = creature()
	if clock - last_distraction < distract_rest or it.detection >= it.SUSPICION: return
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
	burnt_next = clock + rng.randf_range(burnt_every.x, burnt_every.y)
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
	if calm > 0.0: lines.append("  carga %0.2f · un descanso vale hasta %0.0f s más" % [strain, calm * spacing()])
	if phase == Phase.RELIEF: lines.append("  descanso %0.0f s más" % maxf(0.0, rest_until - clock))
	elif phase == Phase.BUILD: lines.append("  próxima pista en %0.0f s · a %0.0f m del equipo" % [maxf(0.0, next_lead - clock), prowl])
	if not current.is_empty() and clock < float(current.until): lines.append("  %s · sala %d%s · %0.0f s" % [current.kind, room_id(current.point), (" · por " + String(current.target)) if not String(current.target).is_empty() else "", float(current.until) - clock])
	if not deaths.is_empty(): lines.append("  %d muertes recientes: más lejos" % deaths.size())
	return lines

func pick(type: String) -> String:
	var options: Array = SOUNDS[type]
	return options[rng.randi_range(0, options.size() - 1)]
