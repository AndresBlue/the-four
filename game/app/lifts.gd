extends Node
## The lifts between the wings, the ride in them, and what each sector is
## called and asks for: the card of the ride, the notice on arriving and the
## lines the pause screen keeps. Split out of hotel_main.gd, which owns it
## (`level.lifts`) and calls ride_lifts(), ride_along() and announce_sector()
## from its own loop.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

## What a sector asks for, in the fewest words that fit on the tape's card
## (written in game/floors/hotel_floor.gd, with the rest of its rules).
## The floor explains nothing else, but nobody guesses on their own that the
## numbers of the last door are inside the furniture of that wing: a whole
## sector spent opening drawers at random is not a mystery, it is a wasted
## evening.
func stage_errand(stage: int) -> String: return String(level.kind.stage(stage).errand)

## And the same thing said whole, which is what the notice on arriving says and
## what the pause screen keeps for anybody who wants to check.
func stage_brief(stage: int) -> String: return String(level.kind.stage(stage).brief)

## How the sector is going, in the lines the pause screen shows under it:
## each of its objectives' (game/floors/objectives/), in the order the sector
## lists them: the sets that are on and the numbers found. Nothing that cannot
## be counted by looking at the floor.
func stage_progress() -> Array:
	var lines: Array = []
	for handler in level.stage_objectives(): lines.append_array(handler.progress(level.session.stage).lines)
	return lines

## The notice of a sector, once its lift has opened and the picture is back:
## six seconds of what this one wants, and then the tape lets it go.
var pending_brief := 0
var brief_wait := 0.0
func announce_sector(delta := 0.0) -> void:
	brief_wait = maxf(0.0, brief_wait - delta)
	if pending_brief <= 0 or brief_wait > 0.0 or not boarding.is_empty(): return
	if not level.match_net.local_is_locust():
		# The very first floor played on this machine says what is going on
		# before what to do: somebody new has no other way of knowing.
		if pending_brief == 1 and not bool(level.settings.values.get("first_game_done", false)) and not level.observer and not level.bot_match:
			level.ui.show_brief(level.kind.title_of(1), FIRST_BRIEF, level.kind.FIRST_LEAD, FIRST_HOLD)
			level.settings.values.first_game_done = true
			level.settings.save_settings()
		else: level.ui.show_brief(level.kind.title_of(pending_brief), stage_brief(pending_brief))
	pending_brief = 0

## What the first floor anybody plays opens with (after the floor's own
## FIRST_LEAD), and how long it stays.
const FIRST_BRIEF := "Busca refugio, escóndete y encuentra la salida."
const FIRST_HOLD := 11.0

## A stage has closed: the creature is put on the survivors' trail, instead of
## hunting a wing nobody will come back to. It is not moved anywhere, and it is
## told whether it rides lifts or not: how it follows them is its own
## (creature.follow_to_planta()). The Locust has to walk to the car out of its
## wing (creature_car()) and ride it, like they did.
func follow_players(stage: int) -> void:
	var creature = level.creature
	if level.net.is_client() or not is_instance_valid(creature) or level.manifest.is_empty(): return
	creature.follow_to_planta(stage, true)

## Seconds the car spends up there before it comes back down for whoever is
## left -- a straggler, or the creature. It is the head start the survivors
## buy by being first into it.
const LIFT_RETURN := 15.0
## Lift index -> seconds until the car is back on this floor.
var lift_away := {}

## The head start is the survivors', not the car's. When the creature reaches
## the lobby of a car they took, the car is away with its doors shut and it
## waits: it may ride CREATURE_WAIT after it walked into that lobby, and never
## sooner than CREATURE_HOLD after the car's doors opened on them down there
## (set as they press the button, with the ride's RIDE_TIME on top). Close
## behind them it waits the full CREATURE_HOLD; walked there from across the
## wing, it still stands CREATURE_WAIT at the doors. It used to take the car the
## moment it was back, LIFT_RETURN after them, whatever it had spent getting
## there. A straggler's car comes back LIFT_RETURN after the ride.
const CREATURE_WAIT := 15.0
const CREATURE_HOLD := 20.0
## This floor's (its difficulty writes them: hotel_main.apply_tuning); the
## constants are the game as it was, "desafiante".
var wait_lobby := CREATURE_WAIT
var hold_after := CREATURE_HOLD
## Lift index -> seconds before the creature may take that car (counted from
## the survivors' pressing the button, the ride included), and seconds it has stood in that car's lobby. Counted
## on every machine like lift_away: the hunter's reading shows the car as up
## there until it can take it.
var creature_hold := {}
var lobby_time := {}

## The creature can take that car now.
func creature_may_ride(index: int) -> bool:
	return not lift_gone(index) and float(creature_hold.get(index, 0.0)) <= 0.0 and float(lobby_time.get(index, 0.0)) >= wait_lobby

## Seconds before the creature may take that car, and the longest that wait
## can be: the car away, its hold since the survivors got out, and its own
## time at the doors, whichever is last. For the hunter's dial (camcorder_osd).
func creature_wait(index: int) -> Vector2:
	var left := maxf(float(lift_away.get(index, 0.0)), float(creature_hold.get(index, 0.0)))
	left = maxf(left, wait_lobby - float(lobby_time.get(index, 0.0)))
	return Vector2(maxf(0.0, left), RIDE_TIME + maxf(hold_after, LIFT_RETURN))

## A point in the lobby of that car: the room behind the refuge's gate, or the
## car itself.
func in_lobby(index: int, point: Vector3) -> bool:
	if level.hotel.in_car(index, point, 1.0): return true
	var gates: Array = level.manifest.get("gates", [])
	if index >= gates.size(): return false
	return int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1)) == int(gates[index].get("beyond", -2))

## True while that car is away and nobody can step into it.
func lift_gone(index: int) -> bool: return float(lift_away.get(index, 0.0)) > 0.0

## Nothing of a floor's lifts left over: a ride still counting would move the
## body to a room that no longer exists, and the last car never stops counting
## by itself -- after the floor it went on giving its full static
## (ride_static()), over the opening scene of the next game.
func reset() -> void:
	boarding = {}
	cues.clear()
	arrived.clear()
	for list in [door_state, arrival_state]: list.clear()
	leaving = -1.0
	riding.clear()
	lift_away.clear()
	creature_hold.clear()
	lobby_time.clear()
	cross_clock = 0.0

## Counted on every machine: a guest has to know the car is away as well, or
## it offers a button that does nothing.
func count_away(delta: float) -> void:
	for index in lift_away.keys():
		lift_away[index] = float(lift_away[index]) - delta
		if lift_away[index] <= 0.0: lift_away.erase(index)
	for index in creature_hold.keys():
		creature_hold[index] = float(creature_hold[index]) - delta
		if creature_hold[index] <= 0.0: creature_hold.erase(index)
	# Its time at the doors of the car it has to take, while it stands in
	# that lobby; stepping out a moment (after somebody left behind) does not
	# start it again.
	var creature = level.creature
	if not is_instance_valid(creature) or level.manifest.is_empty(): return
	var car := creature_car(level.session.stage)
	if car >= 0 and in_lobby(car, creature.global_position): lobby_time[car] = float(lobby_time.get(car, 0.0)) + delta

## The car that lets out at this point, or -1.
func car_arriving_at(point: Vector3) -> int:
	for index in level.hotel.arrivals.size():
		var arrival: Vector3 = level.hotel.arrivals[index]
		# In three dimensions: the car arriving on one planta can stand right over
		# the one leaving from the planta under it.
		if arrival != Vector3.ZERO and arrival.distance_to(point) < 2.5: return index
	return -1

## The car out of the wing the creature is standing in, while that wing is
## behind the one being played; -1 otherwise. Its own wing's car and not the
## last stage's: a creature that stayed two wings back (chasing a straggler
## through a whole stage) was aimed at a car it could never walk to. None for
## a creature that does not ride them.
func creature_car(stage: int) -> int:
	var creature = level.creature
	if not is_instance_valid(creature) or not creature.can(&"lifts"): return -1
	var here: Dictionary = FLOOR.room_at(level.manifest.rooms, creature.global_position)
	if here.is_empty(): return -1
	var wing := int(here.get("wing", 0))
	return wing if wing < stage - 1 else -1

## The creature crossing on its own two feet: a wing behind, it makes for the
## car, waits for it to come back down and rides it. Nothing carries it and
## nothing waits for it -- if it stops to chase somebody who stayed behind,
## the wing ahead is that much quieter for a while.
const CROSS_AIM := 2.5
var cross_clock := 0.0
func creature_crossing(delta: float) -> void:
	var creature = level.creature
	if not is_instance_valid(creature) or not creature.can(&"lifts") or level.manifest.is_empty() or level.hotel.lifts.is_empty(): return
	# Already across, or standing nowhere the floor knows about.
	var index: int = creature_car(level.session.stage)
	if index < 0 or index >= level.hotel.lifts.size() or index >= level.hotel.arrivals.size(): return
	if level.hotel.arrivals[index] == Vector3.ZERO: return
	if creature_busy(): return
	# At its doorway will do: the creature is taller than the doors.
	if level.hotel.in_car(index, creature.global_position, 0.9) and creature_may_ride(index):
		lift_away[index] = LIFT_RETURN
		level.match_net.locust_ride(level.hotel.arrivals[index] + Vector3(0, 0.04, 0))
		return
	cross_clock -= delta
	if cross_clock > 0.0: return
	cross_clock = CROSS_AIM
	creature.follow_to_planta(level.session.stage)

## Never in the middle of something: a kill by the car used to go up with it,
## the victim dragged through the walls after it. The machine hunts first and
## rides after; a player hunting rides when it is free to.
func creature_busy() -> bool:
	var creature = level.creature
	return creature.is_engaged() or (creature.control == "ai" and creature.is_hunting())

## The lift's recordings (tools/audio/prepare_lift_sfx.py): its doors running
## shut, the car going down, its doors opening where it arrives, and the bell
## as it arrives, which is heard over the whole floor when the creature is in
## it: everybody knows it has come down, and only near it where.
const DOORS_CLOSE := "res://assets/audio/sfx/lift/doors_close.wav"
const DESCENT := "res://assets/audio/sfx/lift/descent.wav"
const DOORS_OPEN := "res://assets/audio/sfx/lift/doors_open.wav"
const LIFT_DING := "res://assets/audio/sfx/lift/bell.wav"
const DING_GAIN := 0.0
const DOORS_GAIN := -4.0
const DESCENT_GAIN := -6.0

## The creature steps out of the car in the wing ahead. Applied on every
## machine, including the hunter's, which is the one that owns where it
## stands the rest of the time. Put there by teleport() (a puppet ignores the
## states still on their way from the old car; where it drives itself, its
## rounds start from the lobby it is let out in).
func apply_locust_ride(point: Vector3) -> void:
	var creature = level.creature
	if not is_instance_valid(creature) or not creature.can(&"lifts"): return
	var car := car_arriving_at(point)
	if car >= 0:
		lift_away[car] = LIFT_RETURN
		lobby_time.erase(car)
		# Its doors there open on it as it is let out.
		open_arrival(car, 0.0)
	creature.teleport(point, NAN, &"lift")
	# It looks round where the car let it out, then goes about the wing.
	if creature.control == "ai" and creature.is_roaming(): creature.search_from(point, Vector3.ZERO)
	# The bell of the car, over the whole floor: the lift has come down, which
	# is all the warning there is.
	if level.world_audio.enabled: level.world_audio.play_everywhere(LIFT_DING, point + Vector3(0, 2.2, 0), DING_GAIN)

## Whoever steps into a lift takes it. The stage that lift belongs to closes
## behind them -- what walking through the door used to do -- and they come
## out in front of the car at the way into the next wing; the last lift leaves
## the floor. The car stays there for the rest of the floor, so anybody left
## behind rides after them. It is the only way from one wing to the next: they
## share no wall. Stepping into it is being inside the car (hotel.in_car());
## this is still about how far its middle is from anywhere in it.
const RIDE_REACH := 1.4
## Seconds a rider counts as riding once the car has gone: the ride itself
## (RIDE_TIME) and a moment to step out. Nothing takes them meanwhile.
const RIDE_REST := RIDE_TIME + 0.5
## A guest in the car is judged on the host's copy of its body, which is a
## little behind: it is given this much more room, so pressing the button the
## moment it is in does not leave it behind.
const RIDE_SLACK := 0.5
var riding := {}
func ride_lifts() -> void:
	var delta := get_physics_process_delta_time()
	for seat in riding.keys():
		riding[seat] = riding[seat] - delta
		if riding[seat] <= 0.0: riding.erase(seat)
	# The car is a car: it goes up with whoever stepped into it and comes back
	# down a quarter of a minute later (count_away, on every machine).
	creature_crossing(delta)
	for index in called.keys():
		called.erase(index)
		if not car_ready(index) or not level.ride_allowed(index, inside(index)): continue
		# The last one does not arrive anywhere on this floor: it is a ride
		# into the dark, for everybody, and then the floor is over.
		if index >= level.hotel.arrivals.size() or level.hotel.arrivals[index] == Vector3.ZERO:
			leave_floor()
			return
		# Everybody standing in it goes, together; whoever is not in it stays
		# for the car to come back down.
		var went := false
		for body in inside(index):
			var seat := int(body.slot)
			# Inside the car down there, whose doors open on them.
			var point: Vector3 = arrival_spot(index)
			riding[seat] = RIDE_REST
			apply_ride(seat, point)
			if level.match_net.in_match(): level.match_net.ride_lift(seat, point)
			went = true
		if not went: continue
		lift_away[index] = RIDE_TIME + LIFT_RETURN
		if level.session.stage == index + 1: level.session.finish_stage()

## Somewhere to stand inside the car a ride arrives in: the doors open on
## them. Still near enough the arrival point for car_arriving_at().
func arrival_spot(index: int) -> Vector3:
	var car: Vector3 = level.hotel.arrival_cars[index] if index < level.hotel.arrival_cars.size() else Vector3.ZERO
	if car == Vector3.ZERO: return level.hotel.arrivals[index] + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6))
	var out: Vector3 = level.hotel.arrival_facing[index]
	var across := Vector3(out.z, 0, -out.x)
	return car + out * randf_range(0.0, 0.4) + across * randf_range(-0.6, 0.6) + Vector3(0, 0.1, 0)

## The car does not leave the moment somebody steps in. It has a button: it
## goes when somebody inside presses it, and takes everybody who is in it by
## then. It used to leave with the first one through its doors, and whoever
## came after rode a car later on their own -- to a card that named the wrong
## sector, because the floor had already moved on. Now a team can wait for
## each other in it. Lift index -> pressed, for ride_lifts() to act on.
var called := {}

## A car that can be ridden: its stage door open and the car down here.
func car_ready(index: int) -> bool:
	if index < 0 or index >= level.hotel.lifts.size(): return false
	var door = level.hotel.gates[index] if level.hotel.gates.size() > index else null
	return is_instance_valid(door) and not door.locked and not lift_gone(index)

## The living survivors standing in that car, not already mid-ride.
func inside(index: int) -> Array:
	var bodies: Array = []
	for body in level.survivors():
		var seat := int(body.slot)
		if riding.has(seat) or int(level.session.participants.get(seat, level.session.Life.DEAD)) == level.session.Life.DEAD: continue
		# Held on the blade is not in the car: the victim died in the next wing.
		# Nor whoever dies with it (executions.partner_of).
		if not level.execution.is_empty() and (int(level.execution.seat) == seat or int(level.execution.get("partner", -1)) == seat): continue
		if level.hotel.in_car(index, body.global_position, 0.0 if body == level.player else RIDE_SLACK): bodies.append(body)
	return bodies

## The car this body is standing in, ready to go, or -1.
func car_at(point: Vector3) -> int:
	for index in level.hotel.lifts.size():
		if car_ready(index) and level.hotel.in_car(index, point): return index
	return -1

## The button, on the authority. A guest asks through match_net.call_lift.
func press(index: int) -> void:
	if car_ready(index) and level.ride_allowed(index, inside(index)): called[index] = true

## A sound of a car, heard where the car is: once however many ride in it.
## apply_ride runs once per rider, and a team of four used to shut the same
## doors four times at the same instant. Rounded place and sound -> when last
## heard.
var doors_heard := {}
const DOORS_ONCE := 0.6
func car_doors(point: Vector3, gain: float, path := DOORS_CLOSE) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var key := "%s@%d,%d,%d" % [path.get_file(), roundi(point.x * 2.0), roundi(point.y * 2.0), roundi(point.z * 2.0)]
	if now - float(doors_heard.get(key, -100.0)) < DOORS_ONCE: return
	doors_heard[key] = now
	if level.world_audio.enabled: level.world_audio.play_at(path, point + Vector3(0, 1.2, 0), gain)

## The cars' doors. A car's doors are open while it is down here and shut while
## it is away (lift_gone), and the last one's shut as it leaves the floor; a
## car that others arrive in stays shut until the first ride into it ends, and
## then stays open. Worked out on every machine from what each already counts,
## so nothing about them is sent. Stage -> how open (0 shut, 1 open).
var door_state := {}
var arrival_state := {}
## Arrival car -> seconds until its doors open (then open for good).
var arrived := {}
## Seconds the leaves take to run shut and open, as long as they are heard
## doing it in doors_close.wav and doors_open.wav; the opening is heard a
## moment before they move (DOORS_HEARD).
const DOOR_CLOSING := 1.7
const DOOR_OPENING := 1.6
const DOORS_HEARD := 0.2

## Doors of that arrival car open after `wait` seconds, with their sound.
func open_arrival(car: int, wait: float) -> void:
	# Once: every rider of the same ride brings it here, and the doors that
	# are already open stay so.
	if arrived.has(car): return
	arrived[car] = wait
	if car < level.hotel.arrival_cars.size() and level.hotel.arrival_cars[car] != Vector3.ZERO:
		cue(maxf(0.0, wait - DOORS_HEARD), DOORS_OPEN, level.hotel.arrival_cars[car], DOORS_GAIN)

## Sounds to play a little later, where they are: {at, path, point, gain}.
var cues: Array = []
func cue(wait: float, path: String, point: Vector3, gain: float) -> void:
	cues.append({"at": wait, "path": path, "point": point, "gain": gain})

## Every frame, on every machine: the doors move and the cued sounds play.
func update_cars(delta: float) -> void:
	for pending in cues.duplicate():
		pending.at = float(pending.at) - delta
		if pending.at > 0.0: continue
		cues.erase(pending)
		car_doors(pending.point, pending.gain, pending.path)
	for car in arrived.keys():
		arrived[car] = float(arrived[car]) - delta
	if not is_instance_valid(level.hotel): return
	var last: int = level.hotel.lifts.size() - 1
	for index in level.hotel.depart_leaves.size():
		var open: bool = not lift_gone(index) and not (leaving >= 0.0 and index == last)
		move_doors(level.hotel.depart_leaves[index], door_state, index, open, delta)
	for index in level.hotel.arrive_leaves.size():
		var open: bool = arrived.has(index) and float(arrived[index]) <= 0.0
		move_doors(level.hotel.arrive_leaves[index], arrival_state, index, open, delta)

func move_doors(leaves: Array, state: Dictionary, index: int, open: bool, delta: float) -> void:
	if leaves.is_empty(): return
	var was: float = float(state.get(index, 1.0 if open else 0.0))
	var now: float = move_toward(was, 1.0 if open else 0.0, delta / (DOOR_OPENING if open else DOOR_CLOSING))
	if state.has(index) and is_equal_approx(now, was): return
	state[index] = now
	var eased := now * now * (3.0 - 2.0 * now)
	for leaf in leaves:
		if not is_instance_valid(leaf.node): continue
		leaf.node.position.x = lerpf(float(leaf.shut), float(leaf.open), eased)

## The lift has moved somebody: on their own machine the body goes with it, on
## the others the puppet is put where it is told. Both doors are heard, the
## one that shuts here -- at the car being left, which used to be silent -- and
## the one that opens there.
func apply_ride(seat: int, point: Vector3) -> void:
	var car := car_arriving_at(point)
	if car >= 0:
		lift_away[car] = RIDE_TIME + LIFT_RETURN
		creature_hold[car] = RIDE_TIME + hold_after
		# The doors down there open as the ride ends, on every machine.
		open_arrival(car, RIDE_OPEN)
	# Its doors shut on them where they are; the bell and the doors opening
	# are heard down there as they arrive.
	if car >= 0 and car < level.hotel.lifts.size(): car_doors(level.hotel.lifts[car], DOORS_GAIN)
	if car >= 0 and car < level.hotel.arrival_cars.size():
		cue(RIDE_BELL, LIFT_DING, level.hotel.arrival_cars[car] + Vector3(0, 1.0, 0), DING_GAIN - 6.0)
	if seat == level.player.slot:
		# Its own ride: the doors shut, the picture goes, and it comes out
		# somewhere else. Nothing is said about how far it went.
		if level.player.hidden: level.player.force_leave_hide()
		level.player.velocity = Vector3.ZERO
		level.player.held = true
		boarding = {"point": point, "time": 0.0, "car": car}
		# The sector of the wing being arrived in, read off where the car puts
		# them -- not the stage in hand plus one, which is wrong for anybody
		# riding a car after the floor has already moved on.
		var wing := int(FLOOR.room_at(level.manifest.rooms, point).get("wing", level.session.stage))
		var arriving: int = clampi(wing + 1, 1, level.session.stages)
		level.ui.show_transit(level.kind.title_of(arriving), stage_errand(arriving), RIDE_TIME)
		pending_brief = arriving
	elif level.match_net.bodies.has(seat) and is_instance_valid(level.match_net.bodies[seat]): level.match_net.bodies[seat].ride_to(point)

## The ride itself, on the machine of whoever is taking it, timed on its
## recordings: the doors run shut (DOOR_CLOSING) and the picture goes, the car
## goes down for as long as descent.wav lasts with the card of the wing ahead
## over it, the bell, and the doors open on the lobby down there with the
## picture coming back. The riders stand inside the car there, facing out.
const RIDE_SHUT := 1.7
const RIDE_DESCENT_AT := 0.8
const RIDE_BELL := 7.3
const RIDE_OPEN := 7.7
const RIDE_TIME := 8.5
const RIDE_BLIND := 0.35
## The last car does not arrive anywhere: the doors shut, it goes down a while
## in the dark, and the floor is over.
const LEAVE_TIME := 4.0
## How much tape noise is left over the card in the middle of the ride. The
## card is recorded like everything else, so it cannot be read through a
## picture that is all snow: the tape breaks up, settles on it, breaks up
## again as the doors open.
const RIDE_CARD := 0.2
## How long the card of the first sector is held at the start of a floor.
## There is no car to ride into it, so it is its own beat.
const OPENING_CARD := 2.6
var boarding := {}
func ride_along(delta: float) -> void:
	if boarding.is_empty(): return
	boarding.time = float(boarding.time) + delta
	var span: float = float(boarding.time)
	# The car going down, heard from inside it.
	if span >= RIDE_DESCENT_AT and not boarding.get("heard", false):
		boarding["heard"] = true
		if level.world_audio.enabled: level.world_audio.play_long(DESCENT, Vector3(0, 0.5, 0), DESCENT_GAIN, RID(), true)
	# Halfway through, the body is moved: the picture is out by then.
	if span >= RIDE_TIME * 0.5 and not boarding.get("moved", false):
		boarding["moved"] = true
		level.player.global_position = boarding.point
		# Facing out of the car, at the doors that are about to open.
		var car: int = int(boarding.get("car", -1))
		if car >= 0 and car < level.hotel.arrival_facing.size() and level.hotel.arrival_facing[car] != Vector3.ZERO:
			var out: Vector3 = level.hotel.arrival_facing[car]
			level.player.rotation.y = atan2(-out.x, -out.z)
		# Falling out of the floor from here puts it back here, on this planta.
		level.player.spawn = boarding.point
		# The torch trails the camera instead of hanging from it: a body that
		# jumps has to take its light with it.
		level.player.snap_torch()
	if span < RIDE_TIME: return
	level.player.held = false
	boarding = {}
	level.ui.hide_transit()

## How much of the picture the ride is taking: it goes as the doors shut and
## comes back as they open.
## The doors are seen shutting first (RIDE_SHUT), and opening down there at
## the end (RIDE_OPEN): the picture is out only between.
func ride_static() -> float:
	if leaving >= 0.0: return clampf((leaving - RIDE_SHUT) / RIDE_BLIND, 0.0, 1.0)
	if boarding.is_empty(): return 0.0
	var span: float = float(boarding.time) - RIDE_SHUT
	var back: float = RIDE_OPEN - RIDE_SHUT
	if span < 0.0: return 0.0
	if span < RIDE_BLIND: return span / RIDE_BLIND
	if span < RIDE_BLIND * 2.0: return lerpf(1.0, RIDE_CARD, (span - RIDE_BLIND) / RIDE_BLIND)
	if span > back: return maxf(0.0, 1.0 - (span - back) / RIDE_BLIND)
	if span > back - RIDE_BLIND: return lerpf(RIDE_CARD, 1.0, (span - (back - RIDE_BLIND)) / RIDE_BLIND)
	return RIDE_CARD

## The last car. Whoever steps into it takes the floor with them, as before --
## but not in the same frame any more: the doors shut, the picture goes to
## black and static for as long as any other ride, on every machine at once,
## and only then is the floor over. No card: there is no sector to arrive in.
## Seconds into that ride, or -1 while nobody has taken it.
var leaving := -1.0

## The authority's side: once, however many step in together.
func leave_floor() -> void:
	if leaving >= 0.0: return
	begin_leaving()
	if level.match_net.in_match(): level.match_net.leave_floor()

## Every machine's side: hold the body and let the picture go.
func begin_leaving() -> void:
	if leaving >= 0.0: return
	leaving = 0.0
	if level.player.hidden: level.player.force_leave_hide()
	level.player.velocity = Vector3.ZERO
	level.player.held = true
	# Down a ladder (the offices' shaft): no car, no doors; the body goes down
	# the rungs in ride_out().
	leave_from = level.player.global_position
	if by_ladder(): return
	# Its doors, where the car is: heard by whoever rode it and whoever stands
	# near. It used to sound at every machine's own player, wherever that was.
	# Then the car going down, from inside.
	if not level.hotel.lifts.is_empty(): car_doors(level.hotel.lifts[level.hotel.lifts.size() - 1], DOORS_GAIN)
	if level.world_audio.enabled: level.world_audio.play_long(DESCENT, Vector3(0, 0.5, 0), DESCENT_GAIN, RID(), true)

## Whether this floor's last stage is left by a ladder (kind.LEAVE).
func by_ladder() -> bool:
	return String(level.kind.get_script_constant_map().get("LEAVE", "")) == "ladder"

## Where the body was when it started down, and how far a ladder takes it
## while the picture goes.
var leave_from := Vector3.ZERO
const LADDER_DROP := 1.4

## Counted on every machine; the one that runs the floor ends it.
func ride_out(delta: float) -> void:
	if leaving < 0.0: return
	leaving += delta
	if by_ladder():
		level.player.global_position = leave_from - Vector3(0, LADDER_DROP * minf(1.0, leaving / LEAVE_TIME), 0)
		level.player.camera.rotation.x = move_toward(level.player.camera.rotation.x, -1.0, delta * 1.5)
	if leaving >= LEAVE_TIME and not level.net.is_client(): level.session.finish_stage()
