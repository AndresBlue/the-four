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

## Its number in the building and what the boards call it.
const NUMBER := 1
const NAME := "EL HOTEL"

## The time a tape is measured against: every second under it is worth points
## to the team (game/services/run_score.gd).
const PAR := 2400.0

## What there is to have done on this floor, in the order the board shows it:
## {id, title, note, rule}. The rules are run_score.meets()'s; a milestone is
## kept, with its date, the first time a tape reaches it
## (game/services/records_service.gd), and never taken back.
const MILESTONES := [
	{"id": "out", "title": "PRIMERA CINTA", "note": "Salir del hotel.", "rule": ["won"]},
	{"id": "solo", "title": "A SOLAS", "note": "Salir del hotel sin nadie más.", "rule": ["solo"]},
	{"id": "clean", "title": "SIN BAJAS", "note": "Salir en equipo sin que caiga nadie.", "rule": ["clean"]},
	{"id": "brave", "title": "SIN ESCONDERSE", "note": "Salir sin que nadie se meta en un armario.", "rule": ["brave"]},
	{"id": "half", "title": "CINTA CORTA", "note": "Salir en menos de 30 minutos.", "rule": ["time_under", 1800]},
	{"id": "quick", "title": "CINTA DE VEINTE", "note": "Salir en menos de 20 minutos.", "rule": ["time_under", 1200]},
	{"id": "three", "title": "EQUIPO ENTERO", "note": "Salir tres o más, y todos.", "rule": ["team_out", 3]},
	{"id": "four", "title": "LOS CUATRO", "note": "Salir cuatro o más, y todos.", "rule": ["team_out", 4]},
	{"id": "again", "title": "SEGUNDA TOMA", "note": "Salir de un piso que se derrumbó una vez.", "rule": ["restarted"]},
	{"id": "sets", "title": "MANITAS", "note": "Encender tú cuatro televisores en un piso.", "rule": ["mine", "tvs", 4]},
	{"id": "code", "title": "LOS CUATRO NÚMEROS", "note": "Encontrar tú los cuatro números del código.", "rule": ["mine", "digits", 4]},
	{"id": "slip", "title": "POR LOS PELOS", "note": "Escapar tres veces de la criatura y salir.", "rule": ["mine", "escapes", 3]},
	{"id": "ghost", "title": "NI TE VIO", "note": "Salir sin que la criatura te persiga ni una vez.", "rule": ["unseen"]},
	{"id": "mvp", "title": "MÁS VALIOSO", "note": "Ser quien más aportó en un equipo que sale.", "rule": ["mvp"]},
	{"id": "first", "title": "CINTA DE PRIMERA", "note": "Salir con nota A o mejor.", "rule": ["grade", "A"]},
	{"id": "master", "title": "CINTA MAESTRA", "note": "Salir con nota S.", "rule": ["grade", "S"]},
	{"id": "hunted", "title": "A SALVO DEL CAZADOR", "note": "Salir con un jugador haciendo de The Locust.", "rule": ["versus_out"]},
	{"id": "hunter", "title": "CAZA COMPLETA", "note": "Como The Locust, no dejar salir a nadie.", "rule": ["hunter_won"]},
]

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
