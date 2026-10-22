extends Node
## What a floor has been, written down while it is played: what each survivor
## did (the sets they lit, the numbers they found, how far they walked, how
## long the creature was behind them, how often they got away), and the
## moments of the floor in the order they happened. Only the machine in charge
## keeps it -- the host, or the only machine there is -- because it is the one
## that decides every one of those things; when the floor ends, close() makes
## the line out of it (game/services/run_score.gd settles what it was worth),
## and that line is what every machine files and shows.
##
## Owned by hotel_main.gd (`level.ledger`). Nothing here changes the game: it
## only watches.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SCORE := preload("res://game/services/run_score.gd")
const RECORDS := preload("res://game/services/records_service.gd")
var level

## Seat -> what that survivor has done so far (of()).
var seats := {}
## The moments of the floor: {t (seconds on the tape), k (what), s (whose
## seat, 0 for nobody's), st (the sector), and what each kind adds}.
var events: Array = []
## The tape's time when each sector closed, and the floor's own counts.
var sectors: Array = []
var deaths := 0
var hides := 0
var restarts := 0
## Set index -> the seat that lit it. Counted from here when the floor ends: a
## sector given back has its sets put out, and lighting them again is not
## lighting more.
var lit_by := {}
## Who read the code into the last door.
var typed_by := 0
## The creature's chase in hand: {seat, time}.
var hunt := {}
## Seat -> a chase that was lost, waiting to count as having got away:
## {wait, time}. Found again before the wait is out, it was the same chase.
var loose := {}
## Seat -> where it stood a frame ago, the rooms it has stood in, and whether
## its mind had gone.
var trail := {}
var rooms := {}
var gone := {}
var room_clock := 0.0
## Encounters (docs/DIFFICULTY.md): seat -> how many, the seconds alive since
## the last sign of the creature, and the longest of those stretches. A sign
## is seeing it (what frightens a mind: sanity.sight_of_creature), it starting
## to notice you, or it hunting you; signs closer together than
## ENCOUNTER_GAP are the same encounter.
var encounters := {}
var since_sign := {}
var quiet := {}
var sign_clock := 0.0
const ENCOUNTER_GAP := 20.0
const SIGN_EVERY := 0.25

## A chase shorter than this is a glance, and getting out of one is nothing.
const CHASE_LEAST := 3.0
## How long the creature has to stay off somebody for the chase to be over.
const LOOSE_WAIT := 10.0
## Only an escape this long is a moment of the floor.
const ESCAPE_TOLD := 8.0
## Faster than this is not walking: a lift, a revival, a place given back.
const STRIDE_MOST := 9.0
const RUNNING := 4.8

func reset() -> void:
	seats = {}
	events = []
	sectors = []
	deaths = 0
	hides = 0
	restarts = 0
	lit_by = {}
	typed_by = 0
	hunt = {}
	loose = {}
	trail = {}
	rooms = {}
	gone = {}
	room_clock = 0.0
	called = {}
	encounters = {}
	since_sign = {}
	quiet = {}
	sign_clock = 0.0

## Everything counted so far, for a floor left half way and gone on with
## later (game/app/floor_save.gd), and back. A chase in hand is not kept: the
## creature comes back with nobody in mind, and a chase that leaving cut short
## is not one that was got out of.
const KEPT := ["seats", "events", "sectors", "deaths", "hides", "restarts", "lit_by", "typed_by", "trail", "rooms", "gone", "room_clock", "called", "encounters", "since_sign", "quiet", "sign_clock"]

func pack() -> Dictionary:
	var out := {}
	for key in KEPT:
		var value = get(key)
		out[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out

func unpack(data: Dictionary) -> void:
	if data.is_empty(): return
	reset()
	for key in KEPT:
		if data.has(key): set(key, data[key])

## What a seat has done so far.
func of(seat: int) -> Dictionary:
	if not seats.has(seat): seats[seat] = {"searched": 0, "escapes": 0, "chases": 0, "chased": 0.0, "sectors": 0, "deaths": 0, "hides": 0, "hidden": 0.0, "metres": 0.0, "run": 0.0, "closest": -1.0, "low": 100.0, "burnt": 0, "lifts": 0}
	return seats[seat]

## One more of something a seat does.
func add(seat: int, key: String, amount: float) -> void:
	var stats := of(seat)
	stats[key] = stats[key] + amount

## A moment of the floor.
func mark(kind: String, seat := 0, more := {}) -> void:
	if events.size() >= RECORDS.EVENTS_KEPT: return
	var entry := {"t": snappedf(level.session.elapsed, 0.1), "k": kind, "s": seat, "st": int(level.session.stage)}
	entry.merge(more, true)
	events.append(entry)

func alive(seat: int) -> bool:
	return int(level.session.participants.get(seat, level.session.Life.DEAD)) != level.session.Life.DEAD

# --- What the level tells it -------------------------------------------------------

## A set switched on by somebody.
func note_tv(seat: int, index: int) -> void:
	lit_by[index] = seat
	mark("tv", seat, {"n": level.televisions_on(), "of": level.TV_PLACEMENT.needed(level.session.roster_count)})

## A set put out again (the sector was given back).
func note_tv_out(index: int) -> void:
	lit_by.erase(index)

## A piece of furniture gone through; `slot` is the place in the code of the
## number it held, or 0.
func note_search(seat: int, slot: int, where: String) -> void:
	add(seat, "searched", 1)
	if slot > 0: mark("digit", seat, {"n": level.found_digits.size(), "w": where})

func note_code(seat: int) -> void:
	if typed_by != 0: return
	typed_by = seat
	mark("code", seat)

## The button of a car, pressed by somebody standing in it: once for each
## time the car leaves, however many times it is pressed on the way.
func note_lift(seat: int, index: int) -> void:
	if not level.lifts.car_ready(index): return
	var now: float = level.session.elapsed
	if now - float(called.get(index, -100.0)) < CALL_REST: return
	called[index] = now
	add(seat, "lifts", 1)
	mark("lift", seat)
var called := {}
const CALL_REST := 15.0

func note_hide(seat: int) -> void:
	hides += 1
	add(seat, "hides", 1)

func note_death(seat: int) -> void:
	deaths += 1
	add(seat, "deaths", 1)
	loose.erase(seat)
	if int(hunt.get("seat", 0)) == seat: hunt = {}
	mark("death", seat)

## A sector closed: its time on the tape, and one more for everybody on their
## feet when it did.
func note_sector(stage: int) -> void:
	sectors.append(level.session.elapsed)
	for seat in level.session.participants:
		if alive(int(seat)): add(int(seat), "sectors", 1)
	mark("sector", 0, {"n": stage, "st": stage})

## The floor gave the sector back: everybody up again.
func note_restart() -> void:
	restarts += 1
	hunt = {}
	loose = {}
	trail = {}
	mark("collapse")

func note_dark() -> void:
	mark("dark")

# --- What it sees for itself ---------------------------------------------------------

## Once a physics frame while the floor is played, on the machine in charge.
func tick(delta: float) -> void:
	if level.manifest.is_empty() or delta <= 0.0: return
	var creature = level.creature
	var session = level.session
	room_clock -= delta
	var look_rooms := room_clock <= 0.0
	if look_rooms: room_clock = 0.5
	sign_clock -= delta
	var look_signs := sign_clock <= 0.0
	if look_signs: sign_clock = SIGN_EVERY
	for body in level.survivors():
		var seat := int(body.slot)
		if not alive(seat):
			trail.erase(seat)
			continue
		var stats := of(seat)
		var here: Vector3 = body.global_position
		if trail.has(seat):
			var step := Vector2(here.x - trail[seat].x, here.z - trail[seat].z).length()
			var pace := step / delta
			if pace < STRIDE_MOST and not body.hidden:
				stats.metres += step
				if pace > RUNNING: stats.run += step
		trail[seat] = here
		if body.hidden: stats.hidden += delta
		if is_instance_valid(creature) and level.survivor_active(body) and absf(creature.global_position.y - here.y) < 3.0:
			var near: float = creature.global_position.distance_to(here)
			if float(stats.closest) < 0.0 or near < float(stats.closest): stats.closest = near
		var mind: float = level.player.sanity if body == level.player else float(level.sanity.minds.get(seat, {"sanity": 100.0}).sanity)
		stats.low = minf(float(stats.low), mind)
		var burnt := bool(body.burnt)
		if burnt and not bool(gone.get(seat, false)):
			stats.burnt += 1
			mark("burnt", seat)
		gone[seat] = burnt
		# Out among the rooms only: waiting in a refuge or riding a car is not
		# a stretch without the creature, it is a stretch out of its reach.
		if level.survivor_active(body):
			since_sign[seat] = float(since_sign.get(seat, 0.0)) + delta
			if look_signs and sign_of(body, creature): met(seat)
		if look_rooms:
			var room: Dictionary = FLOOR.room_at(level.manifest.rooms, here)
			if not room.is_empty():
				if not rooms.has(seat): rooms[seat] = {}
				rooms[seat][int(room.id)] = true
	follow_hunt(delta, creature)

## A sign of the creature for this survivor, now: it in sight, it noticing
## them, or it hunting them.
func sign_of(body: Node3D, creature) -> bool:
	if not is_instance_valid(creature) or creature.grace > 0.0 or absf(creature.global_position.y - body.global_position.y) >= 3.0: return false
	if creature.control == "ai" and creature.quarry() == body and (creature.noticing() or creature.is_hunting()): return true
	return level.sanity.sight_of_creature(body, level.sanity.lit_at(body.global_position)) > 0

## A sign for a seat: a new encounter, if the last one was long enough ago.
func met(seat: int) -> void:
	var gap := float(since_sign.get(seat, 0.0))
	if not encounters.has(seat) or gap >= ENCOUNTER_GAP:
		encounters[seat] = int(encounters.get(seat, 0)) + 1
		quiet[seat] = maxf(float(quiet.get(seat, 0.0)), gap)
	since_sign[seat] = 0.0

## Who the creature is after, and whether whoever it was after got away. Only
## the machine's creature chases: one driven by a player has no such thing, and
## nothing is counted for it.
func follow_hunt(delta: float, creature) -> void:
	var hunted := 0
	if is_instance_valid(creature) and creature.control == "ai" and creature.is_chasing() and is_instance_valid(creature.quarry()):
		hunted = int(creature.quarry().slot)
	if hunted != int(hunt.get("seat", 0)):
		let_go(creature)
		if hunted != 0:
			# Lost and found again within the wait: the same chase, still on.
			var before: Dictionary = loose.get(hunted, {})
			loose.erase(hunted)
			hunt = {"seat": hunted, "time": float(before.get("time", 0.0))}
			if before.is_empty(): add(hunted, "chases", 1)
	elif hunted != 0:
		hunt.time = float(hunt.time) + delta
		add(hunted, "chased", delta)
	for seat in loose.keys():
		loose[seat].wait = float(loose[seat].wait) - delta
		if float(loose[seat].wait) <= 0.0: got_away(seat)

## The chase in hand is off: its survivor waits to be counted as away, unless
## the creature has them in its hands.
func let_go(creature) -> void:
	var seat := int(hunt.get("seat", 0))
	var time := float(hunt.get("time", 0.0))
	hunt = {}
	if seat == 0 or time < CHASE_LEAST or not alive(seat): return
	var held: bool = int(level.execution.get("seat", 0)) == seat or (is_instance_valid(creature) and creature.activity() == &"capture")
	if not held: loose[seat] = {"wait": LOOSE_WAIT, "time": time}

func got_away(seat: int) -> void:
	var time := float(loose.get(seat, {}).get("time", 0.0))
	loose.erase(seat)
	if not alive(seat): return
	add(seat, "escapes", 1)
	if time >= ESCAPE_TOLD: mark("escape", seat, {"n": int(time)})

# --- The line -------------------------------------------------------------------------

## The floor is over: the line it leaves, settled. Whoever was still being
## looked for when it ended got away.
func close(won: bool) -> Dictionary:
	let_go(level.creature)
	for seat in loose.keys(): got_away(seat)
	var session = level.session
	var players: Array = session.participants.keys()
	players.sort()
	var times: Array = sectors.duplicate()
	if won:
		times.append(session.elapsed)
		mark("out")
	var team: Array = []
	var escaped := 0
	for seat_key in players:
		var seat := int(seat_key)
		var stats: Dictionary = of(seat)
		var out := won and alive(seat)
		if out: escaped += 1
		var digits := 0
		for slot in level.found_by:
			if int(level.found_by[slot]) == seat: digits += 1
		var sets := 0
		for index in lit_by:
			if int(lit_by[index]) == seat: sets += 1
		team.append({
			"seat": seat,
			"name": level.seat_name(seat),
			"escaped": out,
			"digits": digits,
			"tvs": sets,
			"code": 1 if typed_by == seat else 0,
			"searched": int(stats.searched),
			"rooms": rooms.get(seat, {}).size(),
			"escapes": int(stats.escapes),
			"chases": int(stats.chases),
			"chased": int(stats.chased),
			# The last sector too, for whoever walked out of it.
			"sectors": int(stats.sectors) + (1 if out else 0),
			"deaths": int(stats.deaths),
			"hides": int(stats.hides),
			"hidden": int(stats.hidden),
			"metres": int(stats.metres),
			"run": int(stats.run),
			"closest": snappedf(float(stats.closest), 0.1),
			"low": int(stats.low),
			"burnt": int(stats.burnt),
			"lifts": int(stats.lifts),
			"encounters": int(encounters.get(seat, 0)),
			# The longest stretch alive with no sign of it, the last one too.
			"quiet": int(maxf(float(quiet.get(seat, 0.0)), float(since_sign.get(seat, 0.0)))),
		})
	var versus: bool = level.match_net.versus()
	var line := {
		"floor": int(level.kind.NUMBER),
		"result": "won" if won else "lost",
		"mode": "versus" if versus else ("solo" if players.size() < 2 else "coop"),
		"company": RECORDS.VERSUS if versus else (RECORDS.SOLO if players.size() < 2 else RECORDS.COOP),
		"players": players.size(),
		"time": session.elapsed,
		# The mark to beat goes with the size of the floor (FLOOR.AREA).
		"par": float(level.kind.PAR) * float(level.manifest.get("area", 1.0)),
		"stage": int(session.stage),
		"sectors": times,
		"deaths": deaths,
		"hides": hides,
		"restarts": restarts,
		"escaped": escaped,
		"seed": int(session.run_seed),
		"difficulty": String(level.difficulty),
		"team": team,
		"events": events.duplicate(true),
	}
	if versus: line["hunter"] = {"seat": level.match_net.locust_seat(), "name": level.seat_name(level.match_net.locust_seat())}
	# Played by other rules than the game's own: it says which, and goes on
	# the board kept for those.
	var differs: Dictionary = level.MATCH_RULES.changed(level.rules)
	if not differs.is_empty():
		line["rules"] = differs
		line["company"] = RECORDS.CUSTOM
	return SCORE.settle(line)
