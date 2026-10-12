extends SceneTree
## The creature's difficulties (game/floors/difficulty.gd): that "desafiante"
## is the game as it was, number for number; that every lever goes the same
## way from the easiest to the hardest; that a floor started on one hands its
## numbers to the creature, the director, the lifts, the sets and the session,
## keeps it in the checkpoint and the tape; that the room's mercy goes over
## it; and the screen it is chosen on. That it reaches the guests is
## tests/net/net_test.gd's.
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
const DIRECTOR := preload("res://game/director/pacing_director.gd")
const LIFTS := preload("res://game/app/lifts.gd")
const TVS := preload("res://game/app/televisions.gd")
const SESSION := preload("res://game/services/game_session.gd")
const FLOOR_DEF := preload("res://game/world/generation/floor_definition.gd")
var level
var checks: Array = []
var failed := 0

## Which way each lever of how hard it is to get out of an encounter goes as
## the difficulty rises: 1 more, -1 less. The ones that make encounters (how
## often the director leads it, how near, how long it rests) are not here:
## those stay high in all four (docs/DIFFICULTY.md, decided 4 October 2026).
const HARDER := {
	"sight_range": 1, "notice": 1, "hearing": 1, "torch_range": 1, "alert_time": -1, "chase_start": 1, "chase_accel": 1,
	"chase_speed": 1, "track_speed": 1, "lose_after": 1, "give_up": 1, "peek_chance": 1, "attack_range": 1, "windup": -1,
	"recover": -1, "wardrobe": -1, "grace": -1, "lift_wait": -1, "lift_hold": -1,
	"peak_max": 1, "peak_tense": 1, "death_ease": -1, "double_back": 1,
	"distract_rest": 1, "burnt_every": -1,
	# How it is spaced out (pressure, not how many encounters there are) and
	# how sharp its eyes are.
	"lead_every": -1, "prowl_min": -1, "rest_chase": -1, "rest_death": -1, "calm": -1, "solo_ease": -1, "ambush": 1,
	"sight_angle": 1, "cover": -1, "glimpse": -1, "tired": -1,
}

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  · " + detail) if not passed and not detail.is_empty() else "")

func frames(count: int) -> void:
	for i in count: await physics_frame

static func amount(value: Variant) -> float:
	return float(value[0]) + float(value[1]) if value is Array else float(value)

func run() -> void:
	var desafiante: Dictionary = DIFFICULTY.PROFILES.desafiante
	# The game as it was.
	var as_was := {
		"sight_range": LOCUST.SIGHT_RANGE, "torch_range": LOCUST.TORCH_NOTICE_RANGE, "alert_time": LOCUST.ALERT_TIME,
		"chase_start": LOCUST.CHASE_START_SPEED, "chase_accel": LOCUST.CHASE_ACCELERATION, "chase_speed": LOCUST.CHASE_SPEED,
		"track_speed": LOCUST.TRACK_SPEED, "lose_after": LOCUST.LOSE_AFTER, "peek_chance": LOCUST.SEARCH_PEEK_CHANCE,
		"attack_range": LOCUST.ATTACK_RANGE, "windup": LOCUST.WINDUP_TIME, "recover": LOCUST.RECOVER_TIME,
		"tv_hop": TVS.HOP_REST, "lift_wait": LIFTS.CREATURE_WAIT, "lift_hold": LIFTS.CREATURE_HOLD,
		"prowl_min": DIRECTOR.PROWL_MIN, "peak_max": DIRECTOR.PEAK_MAX, "peak_tense": DIRECTOR.PEAK_MAX_TENSE,
		"rest_chase": DIRECTOR.REST_AFTER_CHASE, "rest_death": DIRECTOR.REST_AFTER_DEATH, "death_ease": DIRECTOR.DEATH_EASE,
		"double_back": DIRECTOR.DOUBLE_BACK, "distract_rest": DIRECTOR.DISTRACT_REST, "restarts": SESSION.RESTARTS,
		"notice": 1.0, "hearing": 1.0, "wardrobe": 1.0, "grace": 15.0,
		"sight_angle": LOCUST.SIGHT_HALF_ANGLE, "cover": 0.0, "glimpse": 0.0, "calm": 0.0, "solo_ease": 1.0, "ambush": 2.0, "tired": LOCUST.TIRED_FOR,
	}
	var differs: Array = as_was.keys().filter(func(key): return not is_equal_approx(float(desafiante[key]), float(as_was[key])))
	var pairs_differ: bool = Vector2(desafiante.give_up[0], desafiante.give_up[1]) != Vector2(LOCUST.GIVE_UP, LOCUST.GIVE_UP_HARD) or Vector2(desafiante.lead_every[0], desafiante.lead_every[1]) != DIRECTOR.LEAD_EVERY or Vector2(desafiante.burnt_every[0], desafiante.burnt_every[1]) != DIRECTOR.BURNT_EVERY
	check("Desafiante es el juego de antes, número por número", differs.is_empty() and not pairs_differ, str(differs))
	check("Las cuatro tienen las mismas palancas", DIFFICULTY.ORDER.all(func(id): return DIFFICULTY.PROFILES[id].keys().size() == desafiante.keys().size() and desafiante.keys().all(func(key): return DIFFICULTY.PROFILES[id].has(key))))
	# Every lever, from the easiest to the hardest, the same way.
	var wrong: Array = []
	for key in HARDER:
		for step in range(1, DIFFICULTY.ORDER.size()):
			var before := amount(DIFFICULTY.PROFILES[DIFFICULTY.ORDER[step - 1]][key])
			var after := amount(DIFFICULTY.PROFILES[DIFFICULTY.ORDER[step]][key])
			if (after - before) * float(HARDER[key]) < 0.0: wrong.append("%s %s→%s" % [key, DIFFICULTY.ORDER[step - 1], DIFFICULTY.ORDER[step]])
	var hops: Array = DIFFICULTY.ORDER.map(func(id): return float(DIFFICULTY.PROFILES[id].tv_hop))
	var mercies: Array = DIFFICULTY.ORDER.map(func(id): return int(DIFFICULTY.PROFILES[id].restarts))
	check("Lo que cuesta salir de un encuentro va en orden de Apacible a Pesadilla", wrong.is_empty(), ", ".join(wrong))
	var easiest: Dictionary = DIFFICULTY.PROFILES.apacible
	# The easier ones space it out and keep it further off (October 2026: as
	# often and as near as Pesadilla, it was a siege), and a rest there is
	# worth what the team went through; the game as it was has none of that.
	var even: Dictionary = DIFFICULTY.PROFILES.equilibrada
	check("Apacible la espacia y la aleja más que ninguna, y un respiro vale por lo vivido", float(easiest.lead_every[0]) >= float(even.lead_every[0]) and float(even.lead_every[0]) >= float(desafiante.lead_every[0]) and float(easiest.prowl_min) >= float(desafiante.prowl_min) and float(easiest.calm) > float(even.calm) and float(even.calm) > 0.0 and float(desafiante.calm) == 0.0 and float(easiest.solo_ease) > 1.0 and float(desafiante.solo_ease) == 1.0)
	check("De quien corre se escapa corriendo en las dos fáciles, y en Apacible con margen", float(easiest.chase_speed) <= 5.0 and float(even.chase_speed) < 6.0 and float(desafiante.chase_speed) > 6.0)
	check("Las teles: Apacible no viaja, y cuanto más difícil, más a menudo", hops[0] == 0.0 and hops[1] > hops[2] and hops[2] > hops[3])
	check("La clemencia: sin límite, dos, una, ninguna", mercies == [-1, 2, 1, 0])
	var alone: Array = DIFFICULTY.ORDER.map(func(id): return int(DIFFICULTY.PROFILES[id].solo_restarts))
	check("Y a solas: sin límite, una, ninguna, ninguna", alone == [-1, 1, 0, 0])
	check("Lo que no se conoce es Desafiante", DIFFICULTY.valid("imposible") == "desafiante" and DIFFICULTY.valid(null) == "desafiante" and DIFFICULTY.valid("apacible") == "apacible" and DIFFICULTY.FIRST == "equilibrada")
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	# A settings file from before has no difficulty, and takes the default.
	check("Quien tenía el juego de antes sigue en Desafiante", String(level.settings.DEFAULTS.difficulty) == "desafiante" and level.settings.sanitize("difficulty", "desafiante") == "desafiante")
	# A floor on each, and what each piece is given.
	for id in DIFFICULTY.ORDER:
		await level.start_floor(81, false, [1], id)
		var profile: Dictionary = DIFFICULTY.PROFILES[id]
		var creature = level.locust
		var director = level.director
		var given: bool = level.difficulty == id and is_equal_approx(creature.sight_range, float(profile.sight_range)) and is_equal_approx(creature.chase_speed, float(profile.chase_speed)) and is_equal_approx(creature.alert_time, float(profile.alert_time)) and is_equal_approx(creature.give_up_hard, float(profile.give_up[1])) and is_equal_approx(creature.wardrobe_steps().done, 2.5 * float(profile.wardrobe)) and is_equal_approx(creature.grace, float(profile.grace))
		var told: bool = director != null and director.lead_every == Vector2(profile.lead_every[0], profile.lead_every[1]) and is_equal_approx(director.prowl_min, float(profile.prowl_min)) and is_equal_approx(director.rest_death, float(profile.rest_death))
		var rest: bool = is_equal_approx(level.lifts.wait_lobby, float(profile.lift_wait)) and is_equal_approx(level.lifts.hold_after, float(profile.lift_hold)) and level.session.restarts_allowed == int(profile.restarts)
		check("Un piso en %s le da sus números a la criatura, al director, al ascensor y a la clemencia" % DIFFICULTY.title(id), given and told and rest)
		var saved: Dictionary = level.session.checkpoint()
		check("Y el punto de control la guarda (%s)" % DIFFICULTY.title(id), String(saved.get("difficulty", "")) == id)
		check("Y la cinta la lleva (%s)" % DIFFICULTY.title(id), String(level.ledger.close(false).get("difficulty", "")) == id)
		if id == "apacible":
			# Its creature does not step through the sets.
			level.session.stage = 2
			await frames(3)
			var sets: Array = level.stage_televisions()
			for index in sets.slice(0, 3): level.apply_television(int(index), true)
			var lit: Array = level.lit_televisions()
			creature.set_physics_process(false)
			creature.global_position = level.television_exit(int(lit[0])) + Vector3(0, 0.04, 0)
			creature.mode = creature.Mode.SEARCH
			var stood: Vector3 = creature.global_position
			level.player.global_position = Vector3(0, -200, 0)
			level.tvs.hop_rest = 0.0
			for i in 8: level.tvs.creature_channel_hop(1.0)
			check("En Apacible no sale por otra tele", creature.global_position.distance_to(stood) < 0.1)
	# Encounters: a sign of it starts one, signs close together are the same
	# one, and the stretch without any is kept (run_ledger.gd).
	await level.start_floor(81, false, [1], "desafiante")
	var it = level.locust
	it.set_physics_process(false)
	it.grace = 0.0
	var ledger = level.ledger
	var eye: Vector3 = level.player.camera.global_position
	var ahead: Vector3 = -level.player.camera.global_basis.z
	ahead.y = 0.0
	var front: Vector3 = level.player.global_position + ahead.normalized() * 3.0
	var away := Vector3(0, -80, 0)
	it.global_position = away
	for i in 30: ledger.tick(1.0 / 60.0)
	check("Sin señal de ella no hay encuentro", int(ledger.encounters.get(1, 0)) == 0)
	it.global_position = front
	it.focus = level.player
	it.detection = 1.0
	for i in 30: ledger.tick(1.0 / 60.0)
	check("Que se fije en ti es un encuentro", int(ledger.encounters.get(1, 0)) == 1)
	for i in 120: ledger.tick(1.0 / 60.0)
	check("Y mientras siga, el mismo", int(ledger.encounters.get(1, 0)) == 1)
	it.global_position = away
	it.focus = null
	it.detection = 0.0
	for i in 60 * 25: ledger.tick(1.0 / 60.0)
	it.global_position = front
	it.focus = level.player
	it.detection = 1.0
	for i in 30: ledger.tick(1.0 / 60.0)
	check("Pasado un rato sin ella, otro, y queda cuánto duró el rato", int(ledger.encounters.get(1, 0)) == 2 and float(ledger.quiet.get(1, 0.0)) >= 24.0)
	var met_line: Dictionary = ledger.close(false)
	check("Y la cinta los lleva, por jugador", int(met_line.team[0].get("encounters", 0)) == 2 and int(met_line.team[0].get("quiet", 0)) >= 24)
	# The novice bots: the creature is there for them only once they notice it.
	var threat = load("res://tools/bots/bot_threat.gd").new(level)
	threat.novice = true
	it.focus = null
	it.detection = 0.0
	# Moving, as far as the bots are concerned (nothing below waits a frame,
	# so it does not take a step).
	it.set_physics_process(true)
	it.global_position = level.player.global_position + Vector3(200, 0, 200)
	threat.noticed_at = -INF
	threat.refresh()
	var unknown: bool = not threat.active
	it.global_position = level.player.global_position + Vector3(6.0, 0, 0)
	threat.refresh()
	check("Un bot novato no sabe de ella hasta que la ve o la oye cerca", unknown and threat.active)
	threat.novice = false
	it.global_position = level.player.global_position + Vector3(200, 0, 200)
	threat.refresh()
	check("Y uno experto la sabe siempre", threat.active)
	it.set_physics_process(false)
	# Its mind (phase 4): the doubt, tiring of a chase, the growl of losing
	# somebody, wardrobes, and the encounters the director brings about. All
	# of it off on Desafiante.
	var reference: Dictionary = DIFFICULTY.PROFILES.desafiante
	check("En Desafiante no hay duda, ni cansancio, ni gruñido, ni encuentros forzados", float(reference.doubt) == 0.0 and float(reference.chase_tire) == 0.0 and not bool(reference.lost_cry) and bool(reference.guess_hides) and float(reference.encounter_every) == 0.0 and float(reference.cross) == 0.0)
	await level.start_floor(81, false, [1], "apacible")
	var slow = level.locust
	slow.grace = 0.0
	var me: Vector3 = level.player.global_position
	var look: Vector3 = -level.player.camera.global_basis.z
	look.y = 0.0
	slow.global_position = me + look.normalized() * 8.0
	var towards: Vector3 = me - slow.global_position
	slow.rotation.y = atan2(-towards.x, -towards.z)
	slow.set_mode(slow.Mode.PATROL)
	slow.detection = 0.0
	await frames(8)
	var doubting: bool = slow.doubting > 0.0 and slow.velocity.length() < 0.3
	await frames(40)
	var still_doubting: bool = slow.mode not in [slow.Mode.ALERT, slow.Mode.CHASE]
	await frames(150)
	check("En Apacible, al distinguirte se para a mirarte, y no pasa a perseguir hasta acabar de dudar", doubting and still_doubting and slow.mode in [slow.Mode.ALERT, slow.Mode.CHASE, slow.Mode.WINDUP, slow.Mode.RECOVER])
	slow.set_physics_process(false)
	slow.global_position = me + look.normalized() * 9.0
	slow.focus = level.player
	slow.set_mode(slow.Mode.CHASE)
	slow.chase_time = slow.chase_tire + 0.5
	var calls: int = slow.calls_made
	slow.set_physics_process(true)
	await frames(3)
	var tired: bool = slow.mode == slow.Mode.PATROL and slow.leaving and slow.tired_until > slow.clock
	await frames(30)
	check("Se cansa de perseguir aunque te vea, gruñe que te perdió y un rato no se fija en nadie", tired and slow.calls_made > calls and slow.detection < slow.SUSPICION)
	check("Y solo abre el armario en el que te vio entrar", not slow.guess_hides)
	# A fresh floor: the one above has just had a chase given up next to the
	# player, and everything round it is marked as searched.
	await level.start_floor(81, false, [1], "apacible")
	slow = level.locust
	slow.set_physics_process(false)
	slow.grace = 0.0
	level.ledger.since_sign[1] = 400.0
	level.director.next_cross = 0.0
	# Somewhere far off in the wing, where it would be out of everybody's way.
	slow.global_position = level.revival.den_away(level.player.global_position, 40.0)
	var due: bool = level.director.encounter_due()
	check("Si alguien lleva mucho sin verla, el director la trae a su vista", due and String(level.director.current.get("kind", "")) in ["cruce", "pasa"], str(level.director.current))
	# What the team goes through is counted, and a rest is measured by it:
	# longer for more, longer still alone, and no forced crossing the moment
	# it is over. Nothing of that on the game as it was.
	var director = level.director
	director.strain = 0.0
	slow.set_mode(slow.Mode.CHASE)
	director.update_strain(5.0)
	var hunted: float = director.strain
	slow.set_mode(slow.Mode.PATROL)
	director.strain = 1.0
	director.rest_until = 0.0
	director.breathe(director.rest_chase)
	var long_rest: float = director.rest_until - director.clock
	var wanted: float = (float(easiest.rest_chase) + float(easiest.calm)) * float(easiest.solo_ease)
	check("Una persecución carga, y el respiro que sigue vale por la carga, más largo a solas", is_equal_approx(hunted, 5.0 * director.STRAIN_HUNT) and director.phase == director.Phase.RELIEF and absf(long_rest - wanted) < 1.0 and director.strain < 0.3 and director.next_cross > director.rest_until, "%0.1f · %0.1f" % [long_rest, wanted])
	director.strain = 0.0
	director.rest_until = 0.0
	director.breathe(director.rest_chase)
	check("Sin carga, el respiro es el de siempre", absf(director.rest_until - director.clock - float(easiest.rest_chase) * float(easiest.solo_ease)) < 1.0)
	level.session.roster_count = 3
	check("Con tres o más, nada se espacia de más", is_equal_approx(director.spacing(), 1.0))
	level.session.roster_count = 1
	check("Durante un respiro ganado, lo que tienen que alcanzar queda fuera de su camino", director.goal_rooms().has(int(level.refuge_room())) and director.in_the_way(int(level.refuge_room()), director.goal_rooms()))
	# Its eyes. A cover_box chest high between them: head and shoulders show over
	# it, and that is not enough to be taken for somebody -- until they have
	# been left in view a while.
	var watched = level.player
	var stood_at: Vector3 = watched.global_position
	var outward: Vector3 = -watched.camera.global_basis.z
	outward.y = 0.0
	outward = outward.normalized()
	slow.global_position = stood_at + outward * 8.0
	slow.rotation.y = atan2(outward.x, outward.z)
	slow.set_mode(slow.Mode.PATROL)
	var all_shown: float = slow.shown(watched)
	var cover_box := StaticBody3D.new()
	var box_shape := CollisionShape3D.new()
	box_shape.shape = BoxShape3D.new()
	box_shape.shape.size = Vector3(1.8, 1.25, 0.3)
	cover_box.add_child(box_shape)
	cover_box.collision_layer = 1
	level.hotel.add_child(cover_box)
	cover_box.global_position = stood_at + outward * 0.7 + Vector3(0, 0.625, 0)
	cover_box.rotation.y = atan2(outward.x, outward.z)
	await frames(3)
	var part_shown: float = slow.shown(watched)
	slow.peeked = {}
	var unnoticed: bool = slow.sees(watched) and slow.overlooks(watched, 1.0) and slow.noticed_survivor(1.0) == null
	var then_noticed: bool = not slow.overlooks(watched, float(easiest.glimpse)) and slow.noticed_survivor(0.1) == watched
	check("En Apacible, un cuerpo a medio tapar no se distingue hasta llevar un rato a la vista", is_equal_approx(all_shown, 1.0) and part_shown < float(easiest.cover) and part_shown > 0.2 and unnoticed and then_noticed, "%0.2f · %0.2f · %s · %s" % [all_shown, part_shown, unnoticed, then_noticed])
	slow.peeked = {}
	slow.set_mode(slow.Mode.CHASE)
	check("Pero a quien ya persigue, medio cuerpo le basta", not slow.overlooks(watched, 0.1))
	slow.set_mode(slow.Mode.PATROL)
	slow.cover = 0.0
	check("Y la criatura de siempre lo distingue al instante", not slow.overlooks(watched, 0.1) and slow.noticed_survivor(0.1) == watched)
	slow.cover = float(easiest.cover)
	cover_box.queue_free()
	# And it sees less to either side: 45 degrees, where the game as it was
	# sees 60.
	slow.rotation.y = atan2(outward.x, outward.z) + deg_to_rad(52.0)
	await frames(2)
	var beside: bool = not slow.sees(watched)
	slow.sight_half_angle = LOCUST.SIGHT_HALF_ANGLE
	check("Y ve menos hacia los lados", beside and slow.sees(watched) and is_equal_approx(float(easiest.sight_angle), 45.0))
	await level.start_floor(81, false, [1], "desafiante")
	level.ledger.since_sign[1] = 1000.0
	check("En Desafiante no fuerza encuentros", not level.director.encounter_due())
	# The room's mercy goes over the difficulty's; left alone, the difficulty's.
	level.set_rules({"restarts": 3})
	check("La clemencia de la sala manda sobre la de la dificultad", level.session.restarts_allowed == 3)
	level.set_rules({})
	check("Y sin tocarla, la de la dificultad", level.session.restarts_allowed == 1 and level.difficulty == "desafiante")
	# Continuar and Reintentar play it again.
	level.on_action("retry")
	await frames(2)
	while level.session.state == level.session.State.LOADING: await process_frame
	check("Reintentar juega la misma", level.difficulty == "desafiante")
	await level.start_floor(81, false, [1], "pesadilla")
	level.settings.values.difficulty = "equilibrada"
	level.on_action("continue")
	await frames(2)
	while level.session.state == level.session.State.LOADING: await process_frame
	check("Y Continuar, la del piso guardado aunque se haya elegido otra", level.difficulty == "pesadilla")
	# Alone, the easier difficulties give the stage back too; the game as it
	# was (Desafiante) ends the floor at the first capture, as before.
	await level.start_floor(81, false, [1], "apacible")
	var hunter = level.locust
	hunter.grace = 0.0
	hunter.set_physics_process(false)
	hunter.global_position = level.player.global_position + Vector3(1.2, 0, 0)
	level.capture_survivor(level.player)
	for i in int((hunter.EXECUTION_TIME + 0.6) * 60.0): await physics_frame
	var waiting: bool = level.session.state == level.session.State.PLAYING and level.session.restart_wait > 0.0 and level.player.held and level.lost_signal > 0.0
	for i in int((level.session.RESTART_WAIT + 1.0) * 60.0): await physics_frame
	check("A solas en Apacible, caer devuelve la etapa: la señal se pierde y se vuelve en su entrada", waiting and level.session.state == level.session.State.PLAYING and level.session.restarts == 1 and int(level.session.participants[1]) == level.session.Life.EXPLORING and not level.player.held)
	await level.start_floor(81, false, [1], "desafiante")
	var first_seed: int = level.session.run_seed
	level.session.capture(1)
	await frames(2)
	check("A solas en Desafiante, la primera captura sigue acabando el piso, y su punto de control se va", level.session.state == level.session.State.FAILED and level.session.checkpoint().is_empty())
	level.on_action("retry")
	await frames(2)
	while level.session.state == level.session.State.LOADING: await process_frame
	check("Reintentar no repite el piso: es otro", level.session.state == level.session.State.PLAYING and level.session.run_seed != first_seed and level.difficulty == "desafiante")
	# A tape from before there were difficulties.
	check("Una cinta de antes de las dificultades era Desafiante", String(level.records.clean({"floor": 1, "time": 900.0}).difficulty) == "desafiante")
	# The screen it is chosen on.
	level.settings.values.difficulty = "equilibrada"
	level.session.set_state(level.session.State.MENU)
	await frames(2)
	var asked: Array = []
	level.ui.action_requested.connect(func(what): asked.append(what), CONNECT_ONE_SHOT)
	level.ui.menu("difficulty")
	await process_frame
	check("Nueva partida pregunta la dificultad, con la última elegida marcada", level.ui.screen == "difficulty" and DIFFICULTY.ORDER.all(func(id): return level.ui.buttons.has(id)) and level.get_viewport().gui_get_focus_owner() == level.ui.buttons["equilibrada"])
	level.ui.buttons["pesadilla"].pressed.emit()
	await process_frame
	check("Elegir una la guarda y empieza la partida", String(level.settings.values.difficulty) == "pesadilla" and asked == ["begin"])
	var file := FileAccess.open("res://evidence/difficulty_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("DIFFICULTY_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
