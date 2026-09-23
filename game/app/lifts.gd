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
	var index := creature_car(stage)
	if index < 0 or index >= level.hotel.lifts.size(): return
	# It is told in the only language it has: its own voice. A hunter also sees
	# the way to the car, laid out in blue in its reading for as long as it has
	# not taken it -- worked out on its own machine (locust_player.lift_route).
	level.locust.grunt()
	aim_at_lift(index)

## Seconds the car spends up there before it comes back down for whoever is
## left -- a straggler, or the creature. It is the head start the survivors
## buy by being first into it.
const LIFT_RETURN := 15.0
## Lift index -> seconds until the car is back on this floor.
var lift_away := {}

## True while that car is away and nobody can step into it.
func lift_gone(index: int) -> bool: return float(lift_away.get(index, 0.0)) > 0.0

## Counted on every machine: a guest has to know the car is away as well, or
## it offers a button that does nothing.
func count_away(delta: float) -> void:
	for index in lift_away.keys():
		lift_away[index] = float(lift_away[index]) - delta
		if lift_away[index] <= 0.0: lift_away.erase(index)

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
## through a whole stage) was aimed at a car it could never walk to.
func creature_car(stage: int) -> int:
	if not is_instance_valid(level.locust): return -1
	var here: Dictionary = FLOOR.room_at(level.manifest.rooms, level.locust.global_position)
	if here.is_empty(): return -1
	var wing := int(here.get("wing", 0))
	return wing if wing < stage - 1 else -1

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
	# Already across, or standing nowhere the floor knows about.
	var index: int = creature_car(level.session.stage)
	if index < 0 or index >= level.hotel.lifts.size() or index >= level.hotel.arrivals.size(): return
	if level.hotel.arrivals[index] == Vector3.ZERO: return
	# Never in the middle of something: a kill by the car used to go up with
	# it, the victim dragged through the walls after it. The machine hunts
	# first and rides after; a player hunting rides when it is free to.
	var busy: Array = [level.locust.Mode.EXECUTE, level.locust.Mode.WARDROBE, level.locust.Mode.WINDUP, level.locust.Mode.RECOVER]
	if level.locust.control == "ai": busy += [level.locust.Mode.CHASE, level.locust.Mode.ALERT]
	if level.locust.mode in busy: return
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
	var car := car_arriving_at(point)
	if car >= 0: lift_away[car] = LIFT_RETURN
	level.locust.global_position = point
	level.locust.velocity = Vector3.ZERO
	level.locust.net_states.clear()
	level.locust.net_clock = 0.0
	if level.locust.control == "puppet":
		level.locust.ride_point = point
		level.locust.ride_hold = 2.0
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
## Seconds a rider counts as riding once the car has gone: the ride itself
## (RIDE_TIME) and a moment to step out. Nothing takes them meanwhile.
const RIDE_REST := 3.7
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
		# Held on the blade is not in the car: the victim died in the next wing.
		if not level.execution.is_empty() and int(level.execution.seat) == seat: continue
		var reach: float = RIDE_REACH if body == level.player else RIDE_REACH + RIDE_SLACK
		if body.global_position.distance_to(level.hotel.lifts[index]) <= reach: bodies.append(body)
	return bodies

## The car this body is standing in, ready to go, or -1.
func car_at(point: Vector3) -> int:
	for index in level.hotel.lifts.size():
		if car_ready(index) and point.distance_to(level.hotel.lifts[index]) <= RIDE_REACH: return index
	return -1

## The button, on the authority. A guest asks through match_net.call_lift.
func press(index: int) -> void:
	if car_ready(index): called[index] = true

## The doors of a car, heard where the car is: once however many ride in it.
## apply_ride runs once per rider, and a team of four used to shut the same
## doors four times at the same instant. Rounded place -> when last heard.
var doors_heard := {}
const DOORS_ONCE := 0.6
func car_doors(point: Vector3, gain: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var key := "%d,%d,%d" % [roundi(point.x * 2.0), roundi(point.y * 2.0), roundi(point.z * 2.0)]
	if now - float(doors_heard.get(key, -100.0)) < DOORS_ONCE: return
	doors_heard[key] = now
	if level.world_audio.enabled: level.world_audio.play_at(level.SWITCH_SOUND, point + Vector3(0, 1.2, 0), gain)

## The lift has moved somebody: on their own machine the body goes with it, on
## the others the puppet is put where it is told. Both doors are heard, the
## one that shuts here -- at the car being left, which used to be silent -- and
## the one that opens there.
func apply_ride(seat: int, point: Vector3) -> void:
	var car := car_arriving_at(point)
	if car >= 0: lift_away[car] = LIFT_RETURN
	if car >= 0 and car < level.hotel.lifts.size(): car_doors(level.hotel.lifts[car], -6.0)
	car_doors(level.hotel.arrivals[car] if car >= 0 else point, -6.0)
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
	elif level.match_net.bodies.has(seat) and is_instance_valid(level.match_net.bodies[seat]): level.match_net.bodies[seat].ride_to(point)

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
		# Falling out of the floor from here puts it back here, on this planta.
		level.player.spawn = boarding.point
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
	# Its doors, where the car is: heard by whoever rode it and whoever stands
	# near. It used to sound at every machine's own player, wherever that was.
	if not level.hotel.lifts.is_empty(): car_doors(level.hotel.lifts[level.hotel.lifts.size() - 1], -6.0)

## Counted on every machine; the one that runs the floor ends it.
func ride_out(delta: float) -> void:
	if leaving < 0.0: return
	leaving += delta
	if leaving >= RIDE_TIME and not level.net.is_client(): level.session.finish_stage()
