extends RefCounted
## Optional documents found on the floors: four per creature, sixteen in all.
## They explain what the player has seen and give hints, never power.
## Only The Locust's floor exists so far; the other twelve slots stay locked.
## Those that are the hotel's own paperwork carry `form`: what is typed in the
## fields of its form around the body (game/ui/hotel_form.gd), which is how
## they are read and how they look lying on a table. The rest carry `paper`,
## the ruled paper they are typed on (game/ui/ruled_paper.gd): a letter
## folded in four, a page of a notebook.
const TOTAL := 16
const ENTRIES := [
	{
		"id": "locust_reception",
		"creature": "locust",
		"title": "Nota para el turno de noche",
		"header": "Recepción, papel con membrete del hotel",
		"body": "Tres quejas más de la planta primera. Dicen que la tele se enciende sola pasadas las tres y que en la pantalla sale alguien mirando desde muy cerca. El 107 pidió cambiar de habitación. El 112 no contestó al teléfono.\n\nYa desenchufé dos aparatos y volvieron a encenderse. No subas solo. Si oyes golpes en una puerta, no abras para ver quién es.",
		"form": {"number": "0417", "post": "RECEPCIÓN", "place": "PLANTA PRIMERA", "subject": "NOTA PARA EL TURNO DE NOCHE", "type": "incidente", "action": {"informar": "TURNO DE NOCHE"}, "priority": "alta", "state": "pendiente", "signed": true, "seed": 417},
	},
	{
		"id": "locust_maintenance",
		"creature": "locust",
		"title": "Parte de mantenimiento",
		"header": "Hoja de avería, sin firmar",
		"form": {"number": "0388", "post": "MANTENIMIENTO", "place": "HABITACIÓN 107", "subject": "PANTALLA DEL TELEVISOR ROTA", "type": "incidente", "action": {"seguimiento": true}, "priority": "urgente", "state": "pendiente", "seed": 388},
		"body": "Habitación 107: pantalla del televisor rota. Los cristales están fuera, sobre la moqueta, no dentro del tubo. Lo rompieron desde dentro.\n\nMarcas en el marco de la puerta, a más de dos metros y medio de altura, como de algo que se agacha para pasar. Arañazos en el interior de dos armarios del pasillo. Pido que alguien más venga a verlo antes de cambiar nada.",
	},
	{
		"id": "locust_letter",
		"creature": "locust",
		"title": "Carta sin enviar",
		"header": "Papel doblado en cuatro",
		"paper": "carta",
		"body": "Si alguien encuentra esto: me he pasado la noche dentro de un armario. Lo que anda por los pasillos ve muy lejos, mucho más lejos que tú. No le apuntes con la linterna, la luz lo trae.\n\nCuando se para en seco y chilla, ya sabe dónde estás. Ese segundo es lo único que tienes: sal de su vista. Y no abras las puertas del armario para mirar si lo tienes delante.",
	},
	{
		"id": "locust_guard",
		"creature": "locust",
		"title": "Registro del vigilante",
		"header": "Libreta de rondas, última página",
		"paper": "libreta",
		"body": "02:40 Pasos en la planta de arriba. No son de persona, suenan como puntas contra el suelo.\n02:55 Se oye por las puertas abiertas y por los pasillos. A través de las paredes, nada. Cierro detrás de mí.\n03:10 En la sala de la salida no entra. Me quedo aquí hasta que se haga de día.",
	},
]

static func entry(id: String) -> Dictionary:
	for item in ENTRIES:
		if item.id == id: return item
	return {}

static func for_creature(creature: String) -> Array:
	return ENTRIES.filter(func(item): return item.creature == creature)
