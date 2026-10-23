extends RefCounted
## What the offices ask of the survivors, stage by stage (docs/OFICINAS.md 3
## and 15; floor 2): the shape of hotel_floor.gd, every name it has. Built and
## not released (floor_index.RELEASED). Until steps 1e, 1f and 1g give it its
## objectives, every stage ends with the living in its refuge
## (game_session.can_depart()), and its creature is the null one.

## Its number in the building and what the boards call it.
const NUMBER := 2
const NAME := "LAS OFICINAS"

## How the floor is made (hotel_main.build_floor()). The geometry is the
## hotel's until office_geometry.gd (step 1d).
const GENERATOR := preload("res://game/world/generation/office_generator.gd")
const VALIDATOR := preload("res://game/world/generation/office_validator.gd")
const GEOMETRY := preload("res://game/world/office/office_geometry.gd")
## Its rooms (game/floors/palettes/); FLOOR.palette() gives the same from a
## manifest that says "floor": 2.
const PALETTE := preload("res://game/floors/palettes/office_palette.gd")
## The version of what GENERATOR draws, the palette's: a checkpoint or a match
## of another version is refused rather than rebuilt as a different floor.
const GENERATOR_VERSION := PALETTE.VERSION
## Its creature as a path (hotel_main.spawn_creature()): the null one until
## The Lurker's (phase 3). The difficulty and the rules are already the
## Lurker's.
const CREATURE := "res://game/enemies/null_creature.tscn"
const CREATURE_KEY := &"lurker"
## Who is after you, said in red over the first notice anybody gets (lifts.gd).
const FIRST_LEAD := "The Lurker acecha entre las sombras, no dejes que te atrape"
## No papers until step 1h.
const PAPERS := ""

## 45 minutes: three plantas of errands. Tuned with bots (1i) and people
## (phase 5).
const PAR := 2700.0

## What there is to have done on this floor, as the hotel's (run_score.meets()
## rules). floor_index hides them until the floor is released.
const MILESTONES := [
	{"id": "out", "title": "DADO DE ALTA", "note": "Salir de las oficinas.", "rule": ["won"]},
	{"id": "solo", "title": "SIN COMPAÑÍA", "note": "Salir de las oficinas sin nadie más.", "rule": ["solo"]},
	{"id": "clean", "title": "PLANTILLA COMPLETA", "note": "Salir en equipo sin que caiga nadie.", "rule": ["clean"]},
	{"id": "brave", "title": "NI UNA TAQUILLA", "note": "Salir sin que nadie se meta en una taquilla.", "rule": ["brave"]},
	{"id": "half", "title": "MEDIA JORNADA", "note": "Salir en menos de 30 minutos.", "rule": ["time_under", 1800]},
	{"id": "quick", "title": "SALIDA ANTICIPADA", "note": "Salir en menos de 20 minutos.", "rule": ["time_under", 1200]},
	{"id": "three", "title": "DEPARTAMENTO ENTERO", "note": "Salir tres o más, y todos.", "rule": ["team_out", 3]},
	{"id": "four", "title": "LOS CUATRO", "note": "Salir cuatro o más, y todos.", "rule": ["team_out", 4]},
	{"id": "again", "title": "SEGUNDA CONVOCATORIA", "note": "Salir de un piso que se derrumbó una vez.", "rule": ["restarted"]},
	{"id": "mvp", "title": "EMPLEADO DEL MES", "note": "Ser quien más aportó en un equipo que sale.", "rule": ["mvp"]},
	{"id": "first", "title": "EXPEDIENTE LIMPIO", "note": "Salir con nota A o mejor.", "rule": ["grade", "A"]},
	{"id": "master", "title": "EXPEDIENTE EJEMPLAR", "note": "Salir con nota S.", "rule": ["grade", "S"]},
]

## Stage by stage, from the first: {objectives, level and department (what
## the planta is), errand (the card), brief (the notice)}.
const STAGES := [
	{"objectives": ["files"], "level": "NIVEL 1", "department": "PERSONAL", "errand": "PIDE TU FICHA", "brief": "Pide tu ficha en la ventanilla de Personal, recógela en su estación y pásala por el lector del montacargas."},
	{"objectives": [], "level": "NIVEL 2", "department": "REGISTRO Y ARCHIVO", "errand": "ARRANCA EL MONTACARGAS", "brief": "Da la corriente desde el cuadro, sube la palanca roja del montacargas y baja cuando acabe el reloj."},
	{"objectives": ["air"], "level": "NIVEL 3", "department": "DIRECCIÓN", "errand": "SAL POR EL DUCTO", "brief": "Enciende la climatización desde seguridad, abre la compuerta del ducto principal y llega al pozo."},
]

## The objectives a stage can ask for, and their handlers: the card's and the
## air's so far (1f adds "power").
const OBJECTIVES := {"files": "res://game/floors/objectives/files_objective.gd", "air": "res://game/floors/objectives/air_objective.gd"}
## How the last stage leaves the floor: down the shaft's ladder, not in a car
## (lifts.begin_leaving()).
const LEAVE := "ladder"

## How many stages the floor has.
static func count() -> int: return STAGES.size()

## The stage (1 being the first), or the first one for anything out of range.
static func stage(number: int) -> Dictionary:
	return STAGES[clampi(number, 1, STAGES.size()) - 1]

## What the card, the notice and the pause call a stage (lifts.gd,
## hotel_main.gd): the offices' are levels.
static func title_of(number: int) -> String:
	return "NIVEL %d" % number

## Whether that stage asks for this objective.
static func asks(number: int, objective: String) -> bool:
	return number >= 1 and number <= STAGES.size() and STAGES[number - 1].objectives.has(objective)

## The stages that ask for some objective, in order.
static func stages_asking(objective: String) -> Array:
	var result: Array = []
	for number in range(1, STAGES.size() + 1):
		if asks(number, objective): result.append(number)
	return result
