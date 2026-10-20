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

## The script of a floor, or null for one that does not exist yet.
static func kind(number: int) -> GDScript:
	return KINDS.get(number)

static func built(number: int) -> bool:
	return KINDS.has(number)

## "PISO 1: EL HOTEL", or "PISO 3" for one nobody has filmed.
static func title(number: int) -> String:
	return ("PISO %d: %s" % [number, String(KINDS[number].NAME)]) if KINDS.has(number) else "PISO %d" % number

## The milestones of a floor, or none.
static func milestones(number: int) -> Array:
	return KINDS[number].MILESTONES if KINDS.has(number) else []
