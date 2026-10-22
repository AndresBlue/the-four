extends RefCounted
## The rules a room can change before a floor: the one place they are written
## down. Each has the values it can take, what each is called, and the one the
## game is played with when nobody touches anything (`default`). The host picks
## them in the room (game/ui/rules_screen.gd), they travel with the match
## (net_session.start_match puts them in its config), and every machine reads
## them through `level.rule(id)`.
##
## Only what differs from the default is kept or sent (changed()), so a room
## nobody touched says nothing, and a tape played with other rules carries
## exactly which (run_ledger.close): it goes on a board of its own
## (records_service.CUSTOM) and reaches no milestones.
##
## A new rule is a line here and the place in the game that asks for it.

## A rule that leaves it to the floor's difficulty (game/floors/difficulty.gd).
const BY_DIFFICULTY := -2

## The tabs of the screen, in order.
const GROUPS := ["EL EQUIPO", "EL PISO", "LA HOJA", "THE LOCUST"]

## {id, group (index into GROUPS), title, note, values, labels, default}.
## `versus`: only means anything with a player as the creature.
## `creature`: only on a floor whose kind has that CREATURE_KEY; `kind`: only
## on the floor whose kind has that NUMBER. A rule with neither is every
## floor's. Elsewhere it is not shown and stays at its default (applies()).
const RULES := [
	{"id": "restarts", "group": 0, "title": "Clemencia", "values": [BY_DIFFICULTY, 0, 1, 2, 3, -1], "labels": ["Según la dificultad", "Ninguna", "Una vez", "Dos veces", "Tres veces", "Sin límite"], "default": BY_DIFFICULTY,
		"note": "Veces que el piso devuelve una etapa perdida, con todos en pie otra vez en su entrada. La dificultad trae la suya (Apacible: sin límite; Equilibrada: dos; Desafiante: una; Pesadilla: ninguna)."},
	{"id": "sanity", "group": 0, "title": "Cordura", "values": [1, 0], "labels": ["Se gasta", "No se gasta"], "default": 1,
		"note": "Sin gastarse no hay alucinaciones, ni nadie se queda a la vista de la criatura por perderla."},
	{"id": "code", "group": 1, "title": "Código de la última puerta", "values": [0, 1], "labels": ["Se puede adivinar", "Hacen falta las cuatro notas"], "default": 0, "kind": 1,
		"note": "Si hacen falta las notas, el teclado no abre hasta que el equipo las tiene todas."},
	{"id": "blackout", "group": 1, "title": "Apagón", "values": [1, 0], "labels": ["Al faltar una tele", "Nunca"], "default": 1, "kind": 1,
		"note": "El ala se queda sin luz cuando solo falta un televisor por encender."},
	{"id": "plan", "group": 2, "title": "Plano en la hoja", "values": [1, 0], "labels": ["Se dibuja solo", "Sin plano"], "default": 1,
		"note": "Lo que los supervivientes van viendo queda dibujado en la hoja."},
	{"id": "plan_fade", "group": 2, "title": "El plano se borra", "values": [60, 180, 300, 600, 0], "labels": ["Al minuto", "A los 3 minutos", "A los 5 minutos", "A los 10 minutos", "Nunca"], "default": 180,
		"note": "Cuánto dura en la hoja lo que se vio por última vez."},
	{"id": "shared_sheet", "group": 2, "title": "Lo que se dibuja", "values": [1, 0], "labels": ["Lo ven todos", "Solo quien lo dibuja"], "default": 1,
		"note": "Si lo que cada uno escribe en la hoja aparece en la de los demás."},
	{"id": "onslaught", "group": 3, "title": "Embestida", "values": [0, 1], "labels": ["No", "Sí"], "default": 0, "creature": &"locust",
		"note": "Ve y oye un 25 % más lejos y no afloja: la de la máquina no baja el paso al perderte de vista, y el cazador corre sin cansarse."},
	{"id": "tv_travel", "group": 3, "title": "Viaja por los televisores", "values": [1, 0], "labels": ["Sí", "No"], "default": 1, "creature": &"locust",
		"note": "Un televisor encendido es una puerta para ella. Sin esto, solo anda."},
	{"id": "plain_sight", "group": 3, "title": "Vista del cazador", "values": [0, 1], "labels": ["Lectura acústica", "Ve como una persona"], "default": 0, "versus": true, "creature": &"locust",
		"note": "Solo con un jugador de cazador: ve el hotel iluminado en vez de reconstruirlo de oído, sin rutas ni ecos de lo que suena."},
]

static func entry(id: String) -> Dictionary:
	for rule in RULES:
		if String(rule.id) == id: return rule
	return {}

## Whether a rule means anything on a floor: one marked with a creature only
## where that creature is, one marked with a kind of floor (its NUMBER) only
## on that floor. Nothing said of the floor, every rule does (as before).
static func applies(rule: Dictionary, creature: StringName = &"", floor_number: int = 0) -> bool:
	if creature != &"" and rule.has("creature") and StringName(rule.creature) != creature: return false
	if floor_number > 0 and rule.has("kind") and int(rule.kind) != floor_number: return false
	return true

## The rules there are on a floor, in their order (the rules screen's list).
static func shown(creature: StringName = &"", floor_number: int = 0) -> Array:
	var out: Array = []
	for rule in RULES:
		if applies(rule, creature, floor_number): out.append(rule)
	return out

## Every rule at the value nobody chose.
static func defaults() -> Dictionary:
	var rules := {}
	for rule in RULES: rules[String(rule.id)] = int(rule.default)
	return rules

## What somebody said the rules are, as it may be taken: the rules there are,
## each at one of its own values, and nothing else.
static func clean(said: Variant) -> Dictionary:
	var rules := {}
	if not said is Dictionary: return rules
	for rule in RULES:
		var id := String(rule.id)
		if not said.has(id) or not (said[id] is float or said[id] is int): continue
		var value := int(said[id])
		if (rule.values as Array).has(value): rules[id] = value
	return rules

## The rules of a floor: the defaults, with what was said over them. Said of
## the floor (its creature and number), a rule that does not apply on it
## keeps its default whatever was said.
static func settled(said: Variant, creature: StringName = &"", floor_number: int = 0) -> Dictionary:
	var rules := defaults()
	var heard := clean(said)
	for rule in RULES:
		var id := String(rule.id)
		if heard.has(id) and applies(rule, creature, floor_number): rules[id] = heard[id]
	return rules

## Only what is not the default (and, said of a floor, applies on it).
static func changed(rules: Variant, creature: StringName = &"", floor_number: int = 0) -> Dictionary:
	var out := {}
	var said := clean(rules)
	for rule in RULES:
		var id := String(rule.id)
		if said.has(id) and int(said[id]) != int(rule.default) and applies(rule, creature, floor_number): out[id] = int(said[id])
	return out

## What a value of a rule is called.
static func label(id: String, value: int) -> String:
	var rule := entry(id)
	if rule.is_empty(): return ""
	var at: int = (rule.values as Array).find(value)
	return String(rule.labels[at]) if at >= 0 else ""

## The rules that were changed, one line each: "Clemencia: una vez".
static func described(rules: Variant) -> Array:
	var lines: Array = []
	var differs := changed(rules)
	for rule in RULES:
		var id := String(rule.id)
		if differs.has(id): lines.append("%s: %s" % [String(rule.title), label(id, int(differs[id])).to_lower()])
	return lines
