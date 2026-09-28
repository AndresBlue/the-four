extends RefCounted
## What a floor of the hotel asks of the survivors, stage by stage: the one
## place the rules of a floor are written down. Every stage ends with the
## living in its refuge (game_session.can_depart()); on top of that each asks
## for the objectives it lists, and the card of the ride and the notice on
## arriving say it in its own words.
##
## A floor of another kind is another script of this shape: its stages, their
## objectives and texts. The objectives it can ask for are the ones the game
## knows how to run -- "televisions" (the sets of the stage's wing, lit; the
## last one but one takes the power: game/app/televisions.gd) and "code" (the
## four numbers read into the keypad of the last door: game/app/code_lock.gd).
## A stage is played on the planta of the same number (FLOOR.PLANTAS), and
## game_session.STAGES has to agree with the list (tests/hotel/hotel_test.gd).

## Stage by stage, from the first: {objectives, errand (the card, in the fewest
## words that fit on it), brief (the notice, said whole)}.
const STAGES := [
	{"objectives": [], "errand": "ENCUENTRA LA SALIDA", "brief": "Encuentra la salida del sector."},
	{"objectives": ["televisions"], "errand": "ENCIENDE LOS TELEVISORES", "brief": "Enciende los televisores y busca la salida."},
	{"objectives": ["televisions", "code"], "errand": "DESCUBRE EL CÓDIGO", "brief": "Busca las notas con el código, enciende televisores y sal del piso."},
]

## How many stages the floor has.
static func count() -> int: return STAGES.size()

## The stage (1 being the first), or the first one for anything out of range.
static func stage(number: int) -> Dictionary:
	return STAGES[clampi(number, 1, STAGES.size()) - 1]

## Whether that stage asks for this objective.
static func asks(number: int, objective: String) -> bool:
	return number >= 1 and number <= STAGES.size() and STAGES[number - 1].objectives.has(objective)

## The stages that ask for some objective, in order: the ones whose sets are
## chosen when the floor is built (tv_placement.settle()), for instance.
static func stages_asking(objective: String) -> Array:
	var result: Array = []
	for number in range(1, STAGES.size() + 1):
		if asks(number, objective): result.append(number)
	return result
