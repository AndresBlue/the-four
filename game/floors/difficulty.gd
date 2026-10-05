extends RefCounted
## The four difficulties of the creature the machine drives (docs/DIFFICULTY.md):
## the one place their numbers are written down. A difficulty is a profile, a
## value for each lever the creature, the director, the lifts and the sets
## already have, and the floor hands it to each of them when it starts
## (hotel_main.apply_tuning). Nobody asks "is this Pesadilla?": they ask how
## far the creature sees, and the profile answers.
##
## Desafiante is the game as it was before there were difficulties (October
## 2026), number for number, and stays so: it is what the rest is measured
## against, and what every test and the bots were tuned on. The other three
## are a starting point to be measured (docs/DIFFICULTY.md, phase 3), not a
## result.
##
## What a difficulty may touch: the creature and the mercy of the floor, and
## nothing else (decided 4 October 2026). The aura it is heard by, the screen,
## the mind, the blackout, the sets and the notes are the floor's rules, and
## the room changes those (game/floors/match_rules.gd).

const ORDER := ["apacible", "equilibrada", "desafiante", "pesadilla"]
## The game as it was, and what a tape from before difficulties was.
const REFERENCE := "desafiante"
## What a first start offers (settings_service.first_run).
const FIRST := "equilibrada"

const NAMES := {"apacible": "Apacible", "equilibrada": "Equilibrada", "desafiante": "Desafiante", "pesadilla": "Pesadilla"}
## What each one is like, said to whoever is choosing.
const NOTES := {
	"apacible": "Lenta de mente. La verás a menudo, pero tarda en reaccionar, corre menos que tú y se olvida pronto. Para quien no juega mucho.",
	"equilibrada": "Los mismos encuentros, pero salir de ellos pide romperle la vista, no solo correr. La de casi todo el mundo.",
	"desafiante": "Verte es casi cazarte: hay que jugar a no ser visto. Para quien ya conoce el piso.",
	"pesadilla": "Ve más, oye más, insiste más y no perdona. Para equipos que ya salen en Desafiante.",
}

## What each one is like, line by line, beside the list it is chosen from.
## Only what the numbers below already do: the behaviours of each still to
## come (docs/DIFFICULTY.md) are not promised here.
const TRAITS := {
	"apacible": ["Cuando te distingue, se para a mirarte antes de reaccionar.", "Corre menos que tú y se cansa enseguida de perseguir.", "Cuando te pierde, lo dice con un gruñido.", "Si caes, la etapa vuelve a empezar, todas las veces que haga falta."],
	"equilibrada": ["Duda un momento antes de reaccionar.", "Corre casi como tú: para escapar hay que romperle la vista.", "Se cansa de una persecución larga, y gruñe al perderte.", "Si caes, la etapa vuelve a empezar, hasta dos veces."],
	"desafiante": ["Verte es casi cazarte.", "Corre más que tú y no afloja.", "En equipo, el piso perdona una etapa perdida; a solas, ninguna."],
	"pesadilla": ["Ve y oye más lejos que ninguna.", "Reacciona al instante, insiste y registra más armarios.", "No se perdona ninguna etapa perdida."],
}

## The levers, by difficulty. Each key is said where it is used:
##  creature  sight_range (m), notice (x its 3.2/0.9 a second), hearing (x the
##            table of noises), torch_range (m), alert_time (s before a
##            chase), chase_start (m/s) and chase_accel (m/s2), chase_speed
##            and track_speed (m/s), lose_after (s without seeing you),
##            give_up ([s, s] without a clue), peek_chance (a wardrobe opened
##            on a guess), attack_range (m), windup and recover (s),
##            wardrobe (x the time a wardrobe takes), grace (s at the start),
##            tv_hop (s between steps through a set; 0: never)
##  lifts     lift_wait (s in the lobby) and lift_hold (s since the doors
##            opened on them down there)
##  director  lead_every ([s, s]), prowl_min (m), peak_max and peak_tense (s),
##            rest_chase and rest_death (s), death_ease (m), double_back
##            (share), distract_rest (s), burnt_every ([s, s])
##  behaviour doubt (s it stands and stares the first moment it makes you out;
##            0: none), chase_tire (s of chasing after which it tires and
##            lets go even seeing you; 0: never), lost_cry (a low growl when
##            it gives up on somebody it was after), guess_hides (opens a
##            wardrobe it did not see anybody get into); and the director's
##            encounter_every (s without a sign of it after which it brings it
##            across somebody's view; 0: never) and cross (how much it likes
##            doing that anyway; 0: not a move it makes)
##  mercy     restarts: stages a team's floor gives back (-1: as many as it
##            takes; the room's rule "restarts" goes over it); solo_restarts:
##            the same, played alone. Desafiante gives none alone, as before.
const PROFILES := {
	"apacible": {
		"sight_range": 55.0, "notice": 0.6, "hearing": 0.85, "torch_range": 35.0,
		"alert_time": 2.0, "chase_start": 2.0, "chase_accel": 2.0, "chase_speed": 5.6, "track_speed": 4.6,
		"lose_after": 3.0, "give_up": [4.0, 6.0], "peek_chance": 0.0,
		"attack_range": 1.8, "windup": 0.5, "recover": 1.0, "wardrobe": 1.28,
		"grace": 25.0, "tv_hop": 0.0, "lift_wait": 25.0, "lift_hold": 30.0,
		"lead_every": [20.0, 30.0], "prowl_min": 14.0, "peak_max": 15.0, "peak_tense": 10.0,
		"rest_chase": 20.0, "rest_death": 40.0, "death_ease": 10.0, "double_back": 0.0,
		"distract_rest": 30.0, "burnt_every": [60.0, 90.0],
		"doubt": 1.2, "chase_tire": 12.0, "lost_cry": true, "guess_hides": false, "encounter_every": 90.0, "cross": 4.0,
		"restarts": -1, "solo_restarts": -1,
	},
	"equilibrada": {
		"sight_range": 60.0, "notice": 0.8, "hearing": 0.9, "torch_range": 40.0,
		"alert_time": 1.5, "chase_start": 2.3, "chase_accel": 2.8, "chase_speed": 6.1, "track_speed": 5.0,
		"lose_after": 5.5, "give_up": [7.0, 9.0], "peek_chance": 0.1,
		"attack_range": 2.2, "windup": 0.35, "recover": 0.7, "wardrobe": 1.12,
		"grace": 20.0, "tv_hop": 40.0, "lift_wait": 20.0, "lift_hold": 25.0,
		"lead_every": [25.0, 35.0], "prowl_min": 16.0, "peak_max": 20.0, "peak_tense": 12.0,
		"rest_chase": 30.0, "rest_death": 50.0, "death_ease": 9.0, "double_back": 0.2,
		"distract_rest": 45.0, "burnt_every": [45.0, 60.0],
		"doubt": 0.6, "chase_tire": 25.0, "lost_cry": true, "guess_hides": true, "encounter_every": 120.0, "cross": 1.5,
		"restarts": 2, "solo_restarts": 2,
	},
	"desafiante": {
		"sight_range": 70.0, "notice": 1.0, "hearing": 1.0, "torch_range": 45.0,
		"alert_time": 1.2, "chase_start": 2.5, "chase_accel": 3.2, "chase_speed": 6.4, "track_speed": 5.2,
		"lose_after": 7.0, "give_up": [8.0, 10.0], "peek_chance": 0.2,
		"attack_range": 2.4, "windup": 0.3, "recover": 0.6, "wardrobe": 1.0,
		"grace": 15.0, "tv_hop": 25.0, "lift_wait": 15.0, "lift_hold": 20.0,
		"lead_every": [25.0, 40.0], "prowl_min": 18.0, "peak_max": 25.0, "peak_tense": 15.0,
		"rest_chase": 30.0, "rest_death": 45.0, "death_ease": 8.0, "double_back": 0.4,
		"distract_rest": 45.0, "burnt_every": [30.0, 45.0],
		"doubt": 0.0, "chase_tire": 0.0, "lost_cry": false, "guess_hides": true, "encounter_every": 0.0, "cross": 0.0,
		"restarts": 1, "solo_restarts": 0,
	},
	"pesadilla": {
		"sight_range": 85.0, "notice": 1.3, "hearing": 1.2, "torch_range": 55.0,
		"alert_time": 0.8, "chase_start": 3.0, "chase_accel": 4.0, "chase_speed": 6.7, "track_speed": 5.6,
		"lose_after": 10.0, "give_up": [12.0, 15.0], "peek_chance": 0.5,
		"attack_range": 2.6, "windup": 0.25, "recover": 0.5, "wardrobe": 0.8,
		"grace": 10.0, "tv_hop": 12.0, "lift_wait": 10.0, "lift_hold": 12.0,
		"lead_every": [18.0, 30.0], "prowl_min": 14.0, "peak_max": 35.0, "peak_tense": 22.0,
		"rest_chase": 20.0, "rest_death": 30.0, "death_ease": 4.0, "double_back": 0.7,
		"distract_rest": 90.0, "burnt_every": [20.0, 30.0],
		"doubt": 0.0, "chase_tire": 0.0, "lost_cry": false, "guess_hides": true, "encounter_every": 90.0, "cross": 0.5,
		"restarts": 0, "solo_restarts": 0,
	},
}

## A difficulty there is, or the reference for anything else (a tape or a
## checkpoint from before there were difficulties says nothing: it was this).
static func valid(id: Variant) -> String:
	return String(id) if id is String and PROFILES.has(String(id)) else REFERENCE

static func profile(id: Variant) -> Dictionary:
	return PROFILES[valid(id)]

static func value(id: Variant, key: String) -> Variant:
	return profile(id).get(key, PROFILES[REFERENCE][key])

static func title(id: Variant) -> String:
	return String(NAMES[valid(id)])

## Where it stands from the easiest (0) to the hardest.
static func rank(id: Variant) -> int:
	return ORDER.find(valid(id))
