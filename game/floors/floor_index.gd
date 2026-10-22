extends RefCounted
## The floors of the building, by number: which script says what each one asks
## for (game/floors/hotel_floor.gd is the first), and what to call the ones
## that are not built yet. The records, the milestones and the boards are kept
## floor by floor and ask here; a new floor is one more line.
const KINDS := {
	1: preload("res://game/floors/hotel_floor.gd"),
}
## How many floors the building has, built or not.
const COUNT := 4

## The script of a floor; the hotel's for a number that is not built, so a
## floor asked for by mistake (--floor=7) is still a floor. Who needs to tell
## them apart asks built().
static func kind(number: int) -> GDScript:
	return KINDS.get(number, KINDS[1])

static func built(number: int) -> bool:
	return KINDS.has(number)

## "PISO 1: EL HOTEL", or "PISO 3" for one nobody has filmed.
static func title(number: int) -> String:
	return ("PISO %d: %s" % [number, String(KINDS[number].NAME)]) if KINDS.has(number) else "PISO %d" % number

## The milestones of a floor, or none.
static func milestones(number: int) -> Array:
	return KINDS[number].MILESTONES if KINDS.has(number) else []

## The numbers of the floors that are built, lowest first.
static func numbers() -> Array:
	var result: Array = KINDS.keys()
	result.sort()
	return result

## Each built floor's generator version, by number: two machines play together
## only if they agree on every one (net_session.register()).
static func versions() -> Dictionary:
	var result := {}
	for number in numbers(): result[number] = int(KINDS[number].GENERATOR_VERSION)
	return result
