extends Node
## The lifts between the wings, the ride in them, and what each sector is
## called and asks for: the card of the ride, the notice on arriving and the
## lines the pause screen keeps. Split out of hotel_main.gd, which owns it
## (`level.lifts`) and calls ride_lifts(), ride_along() and announce_sector()
## from its own loop.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

## What a sector asks for, in the fewest words that fit on the tape's card.
## The floor explains nothing else, but nobody guesses on their own that the
## numbers of the last door are inside the furniture of that wing: a whole
## sector spent opening drawers at random is not a mystery, it is a wasted
## evening.
func stage_errand(stage: int) -> String:
	match stage:
		2: return "ENCIENDE LOS TELEVISORES"
		3: return "DESCUBRE EL CÓDIGO"
	return "ENCUENTRA LA SALIDA"

## And the same thing said whole, which is what the notice on arriving says and
## what the pause screen keeps for anybody who wants to check.
func stage_brief(stage: int) -> String:
	match stage:
		2: return "Enciende los televisores y busca la salida."
		3: return "Busca las notas con el código, enciende televisores y sal del piso."
	return "Encuentra la salida del sector."

## How the sector is going, in the lines the pause screen shows under it: the
## sets that are on from the second sector, and the numbers found from the
## third. Nothing that cannot be counted by looking at the floor.
func stage_progress() -> Array:
	var lines: Array = []
	if level.session.stage >= 2 and not level.stage_televisions().is_empty():
		lines.append(["TELEVISORES", "%d / %d" % [level.televisions_on(), level.TV_PLACEMENT.needed(level.session.roster_count)]])
	if level.session.stage >= 3:
		lines.append(["NÚMEROS DEL CÓDIGO", "%d / %d" % [level.found_digits.size(), level.DIGITS.COUNT]])
	return lines

## The notice of a sector, once its lift has opened and the picture is back:
## six seconds of what this one wants, and then the tape lets it go.
var pending_brief := 0
var brief_wait := 0.0
func announce_sector(delta := 0.0) -> void:
	brief_wait = maxf(0.0, brief_wait - delta)
	if pending_brief <= 0 or brief_wait > 0.0 or not boarding.is_empty(): return
	if not level.match_net.local_is_locust(): level.ui.show_brief("SECTOR %d" % pending_brief, stage_brief(pending_brief))
	pending_brief = 0

## A stage has closed: the creature is put on the trail of the lift the
## survivors took, instead of hunting a wing nobody will come back to. It is
## not moved anywhere -- it has to walk there and ride it, like they did.
func follow_players(stage: int) -> void:
	if level.net.is_client() or not is_instance_valid(level.locust) or level.manifest.is_empty(): return
	var index := stage - 2
	if index < 0 or index >= level.hotel.lifts.size(): return
	# It is told in the only language it has: its own voice, and the road to
	# the car laid out in its reading, from where it happens to be standing.
	level.locust.grunt()
	aim_at_lift(index)
	var road := FLOOR.navigation_path(level.get_world_3d().navigation_map, level.locust.global_position, level.hotel.lifts[index])
	if road.size() >= 2: level.match_net.tell_stage(road)

## Seconds the car spends up there before it comes back down for whoever is
## left -- a straggler, or the creature. It is the head start the survivors
## buy by being first into it.
const LIFT_RETURN := 15.0
## Lift index -> seconds until the car is back on this floor.
var lift_away := {}

## True while that car is away and nobody can step into it.
func lift_gone(index: int) -> bool: return float(lift_away.get(index, 0.0)) > 0.0

## Points the creature at a car, without taking it off anything it is already
## doing: somebody left behind in this wing comes before the lift.
func aim_at_lift(index: int) -> void:
	if level.locust.control != "ai" or index < 0 or index >= level.hotel.lifts.size(): return
	if level.locust.mode not in [level.locust.Mode.PATROL, level.locust.Mode.SEARCH, level.locust.Mode.INVESTIGATE]: return
	if level.locust.detection >= level.locust.SUSPICION: return
	var car: Vector3 = level.hotel.lifts[index]
	if level.locust.mode == level.locust.Mode.INVESTIGATE and level.locust.destination.distance_to(car) < 1.0: return
	level.locust.set_mode(level.locust.Mode.INVESTIGATE)
	level.locust.destination = car
	# Its patrolling belongs to the wing it is in; the lobby of the lift is
	# where it should be wandering while it waits for the car.
	var gates: Array = level.manifest.get("gates", [])
	if index < gates.size(): level.locust.patrol_room = int(gates[index].get("beyond", level.locust.patrol_room))
	level.locust.repath = 0

## The creature crossing on its own two feet: a wing behind, it makes for the
## car, waits for it to come back down and rides it. Nothing carries it and
## nothing waits for it -- if it stops to chase somebody who stayed behind,
## the wing ahead is that much quieter for a while.
const CROSS_AIM := 2.5
var cross_clock := 0.0
func creature_crossing(delta: float) -> void:
	if not is_instance_valid(level.locust) or level.manifest.is_empty() or level.hotel.lifts.is_empty(): return
	var index: int = level.session.stage - 2
	if index < 0 or index >= level.hotel.lifts.size() or index >= level.hotel.arrivals.size(): return
	if level.hotel.arrivals[index] == Vector3.ZERO: return
	var here: Dictionary = FLOOR.room_at(level.manifest.rooms, level.locust.global_position)
	# Already across, or standing nowhere the floor knows about.
	if here.is_empty() or int(here.get("wing", 0)) >= level.session.stage - 1: return
	if level.locust.global_position.distance_to(level.hotel.lifts[index]) <= RIDE_REACH + 0.6 and not lift_gone(index):
		lift_away[index] = LIFT_RETURN
		level.match_net.locust_ride(level.hotel.arrivals[index] + Vector3(0, 0.04, 0))
		return
	cross_clock -= delta
	if cross_clock > 0.0: return
	cross_clock = CROSS_AIM
	aim_at_lift(index)

## The creature steps out of the car in the wing ahead. Applied on every
## machine, including the hunter's, which is the one that owns where it
## stands the rest of the time.
func apply_locust_ride(point: Vector3) -> void:
	if not is_instance_valid(level.locust): return
	level.locust.global_position = point
	level.locust.velocity = Vector3.ZERO
	level.locust.net_states.clear()
	level.locust.net_clock = 0.0
	if level.locust.control == "ai":
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, point)
		if not room.is_empty(): level.locust.patrol_room = int(room.id)
		if level.locust.mode in [level.locust.Mode.PATROL, level.locust.Mode.SEARCH, level.locust.Mode.INVESTIGATE]:
			level.locust.set_mode(level.locust.Mode.SEARCH)
			level.locust.destination = point
	# The doors of the car: whoever is near enough in the new wing hears the
	# lift arrive, which is all the warning there is.
	if level.world_audio.enabled: level.world_audio.play_at(level.SWITCH_SOUND, point + Vector3(0, 1.2, 0), -4.0)

## Whoever steps into a lift takes it. The stage that lift belongs to closes
## behind them -- what walking through the door used to do -- and they come
## out in front of the car at the way into the next wing; the last lift leaves
## the floor. The car stays there for the rest of the floor, so anybody left
## behind rides after them. It is the only way from one wing to the next: they
## share no wall.
const RIDE_REACH := 1.4
const RIDE_REST := 3.0
var riding := {}
func ride_lifts() -> void:
	var delta := get_physics_process_delta_time()
	for seat in riding.keys():
		riding[seat] = riding[seat] - delta
		if riding[seat] <= 0.0: riding.erase(seat)
	# The car is a car: it goes up with whoever stepped into it and comes back
	# down a quarter of a minute later.
	for index in lift_away.keys():
		lift_away[index] = float(lift_away[index]) - delta
		if lift_away[index] <= 0.0: lift_away.erase(index)
	creature_crossing(delta)
	for index in called.keys():
		called.erase(index)
		if not car_ready(index): continue
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
			var point: Vector3 = level.hotel.arrivals[index] + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6))
			riding[seat] = RIDE_REST
			apply_ride(seat, point)
			if level.match_net.in_match(): level.match_net.ride_lift(seat, point)
			went = true
		if not went: continue
		lift_away[index] = LIFT_RETURN
		if level.session.stage == index + 1: level.session.finish_stage()

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
		if body.global_position.distance_to(level.hotel.lifts[index]) <= RIDE_REACH: bodies.append(body)
	return bodies

## The car this body is standing in, ready to go, or -1.
func car_at(point: Vector3) -> int:
	for index in level.hotel.lifts.size():
		if car_ready(index) and point.distance_to(level.hotel.lifts[index]) <= RIDE_REACH: return index
	return -1

## The button, on the authority. A guest asks through match_net.call_lift.
func press(index: int) -> void:
	if car_ready(index): called[index] = true

## The lift has moved somebody: on their own machine the body goes with it, on
## the others the puppet is put where it is told. Both doors are heard, the
## one that shuts here and the one that opens there.
func apply_ride(seat: int, point: Vector3) -> void:
	if level.world_audio.enabled: level.world_audio.play_at(level.SWITCH_SOUND, point + Vector3(0, 1.2, 0), -6.0)
	if seat == level.player.slot:
		# Its own ride: the doors shut, the picture goes, and it comes out
		# somewhere else. Nothing is said about how far it went.
		if level.player.hidden: level.player.force_leave_hide()
		level.player.velocity = Vector3.ZERO
		level.player.held = true
		boarding = {"point": point, "time": 0.0}
		# The sector of the wing being arrived in, read off where the car puts
		# them -- not the stage in hand plus one, which is wrong for anybody
		# riding a car after the floor has already moved on.
		var wing := int(FLOOR.room_at(level.manifest.rooms, point).get("wing", level.session.stage))
		var arriving: int = clampi(wing + 1, 1, level.session.STAGES)
		level.ui.show_transit("SECTOR %d" % arriving, stage_errand(arriving), RIDE_TIME)
		pending_brief = arriving
	elif level.match_net.bodies.has(seat) and is_instance_valid(level.match_net.bodies[seat]): level.match_net.bodies[seat].place(point, 0.0)

## The ride itself, on the machine of whoever is taking it: a second and a bit
## with the doors shut and no picture, which is all a lift is from inside. It
## has no sound of its own yet -- what is heard is the door, the one that
## shuts here and the one that opens there.
## Long enough to be a cut and not a hiccup: the picture goes, the card of the
## wing ahead is read, and the picture comes back somewhere else. It used to be
## a second and a half, which was only ever a stutter.
const RIDE_TIME := 3.2
const RIDE_BLIND := 0.35
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
	# Halfway through, the body is moved: the picture is out by then.
	if span >= RIDE_TIME * 0.5 and not boarding.get("moved", false):
		boarding["moved"] = true
		level.player.global_position = boarding.point
		# The torch trails the camera instead of hanging from it: a body that
		# jumps has to take its light with it.
		level.player.snap_torch()
		if level.world_audio.enabled: level.world_audio.play_at(level.SWITCH_SOUND, boarding.point + Vector3(0, 1.2, 0), -8.0)
	if span < RIDE_TIME: return
	level.player.held = false
	boarding = {}
	level.ui.hide_transit()

## How much of the picture the ride is taking: it goes as the doors shut and
## comes back as they open.
func ride_static() -> float:
	if leaving >= 0.0: return clampf(leaving / RIDE_BLIND, 0.0, 1.0)
	if boarding.is_empty(): return 0.0
	var span: float = float(boarding.time)
	if span < RIDE_BLIND: return span / RIDE_BLIND
	if span < RIDE_BLIND * 2.0: return lerpf(1.0, RIDE_CARD, (span - RIDE_BLIND) / RIDE_BLIND)
	if span > RIDE_TIME - RIDE_BLIND: return maxf(0.0, (RIDE_TIME - span) / RIDE_BLIND)
	if span > RIDE_TIME - RIDE_BLIND * 2.0: return lerpf(RIDE_CARD, 1.0, (span - (RIDE_TIME - RIDE_BLIND * 2.0)) / RIDE_BLIND)
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
	if level.world_audio.enabled: level.world_audio.play_at(level.SWITCH_SOUND, level.player.global_position + Vector3(0, 1.2, 0), -6.0)

## Counted on every machine; the one that runs the floor ends it.
func ride_out(delta: float) -> void:
	if leaving < 0.0: return
	leaving += delta
	if leaving >= RIDE_TIME and not level.net.is_client(): level.session.finish_stage()
