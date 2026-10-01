extends SceneTree
## The rules a room can change (game/floors/match_rules.gd), each one where
## the game asks for it: what may be said of them and what is kept, the
## collapses a floor forgives, the creature's mercy, a code that wants its
## notes, the plan on the sheet and how long it lasts, a mind that does not
## wear, the onslaught, the hunter's sight, the sets as doors and the power
## that stays on, the tape a floor played by other rules leaves, and the screen
## the host picks them on. That they reach the guests is tests/net/net_test.gd's.
const RULES := preload("res://game/floors/match_rules.gd")
const SESSION := preload("res://game/services/game_session.gd")
const TV := preload("res://game/world/generation/tv_placement.gd")
const DIG := preload("res://game/world/generation/digit_placement.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

func frames(count: int) -> void:
	for i in count: await physics_frame

## A team of two that loses both, `times` over, getting up in between: whether
## the floor is still going after the last of them.
func collapses(allowed: int, times: int) -> bool:
	var session = SESSION.new()
	session.keeps_checkpoint = false
	session.start(1, false, [1, 2])
	session.restarts_allowed = allowed
	for i in times:
		session.capture(1)
		session.capture(2)
		if session.state != session.State.PLAYING: break
		session.restart_wait = 0.0
		session.raise_everyone(false)
	var going: bool = session.state == session.State.PLAYING
	session.free()
	return going

func run() -> void:
	# What may be said of the rules, and what is kept of it.
	var defaults: Dictionary = RULES.defaults()
	check("Sin tocar nada, las reglas son las del juego", RULES.settled({}) == defaults and RULES.changed(defaults).is_empty() and int(defaults.restarts) == 1 and int(defaults.mercy) == 0 and int(defaults.plan_fade) == 180)
	check("De lo que se diga solo se toma lo que existe y vale", RULES.clean({"mercy": 9, "nada": 1, "restarts": -1, "sanity": "no", "plan_fade": 300.0}) == {"restarts": -1, "plan_fade": 300} and RULES.clean("reglas").is_empty())
	check("Y solo se guarda lo que cambia, con su nombre", RULES.changed({"mercy": 0, "restarts": 2}) == {"restarts": 2} and RULES.described({"restarts": 2, "code": 1}) == ["Derrumbes perdonados: dos", "Código de la última puerta: hacen falta las cuatro notas"])
	check("Cada regla tiene un nombre para cada valor, y su valor de siempre es uno de ellos", RULES.RULES.all(func(rule): return rule.values.size() == rule.labels.size() and rule.values.has(rule.default) and int(rule.group) < RULES.GROUPS.size()))
	# The collapses a floor forgives.
	check("Un derrumbe perdonado: el segundo acaba el piso", collapses(1, 1) and not collapses(1, 2))
	check("Ninguno: el primero lo acaba", not collapses(0, 1))
	check("Tres, o sin límite", collapses(3, 3) and not collapses(3, 4) and collapses(-1, 6))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	var creature = level.locust
	creature.set_physics_process(false)
	check("Un piso empieza con las reglas del juego", level.rules == defaults and level.session.restarts_allowed == 1 and is_equal_approx(level.floor_map.forget, 180.0) and is_equal_approx(creature.reach_scale, 1.0))
	# Mercy: it had somebody and lets go, once each; then it does not.
	level.set_rules({"mercy": 1})
	creature.grace = 0.0
	creature.global_position = level.player.global_position + Vector3(1.2, 0, 0)
	level.capture_survivor(level.player)
	check("Con clemencia, la primera captura se perdona: nadie cae y la criatura se va lejos", level.execution.is_empty() and int(level.executions.pardoned.get(1, 0)) == 1 and level.untouchable.has(1) and creature.global_position.distance_to(level.player.global_position) > 15.0 and creature.grace >= level.executions.PARDON_REST - 0.5)
	check("Y queda entre los momentos del piso, sin contar como caída", level.ledger.events.any(func(event): return String(event.k) == "mercy") and level.ledger.deaths == 0)
	level.untouchable.clear()
	creature.grace = 0.0
	creature.global_position = level.player.global_position + Vector3(1.2, 0, 0)
	level.capture_survivor(level.player)
	check("La segunda ya no", not level.execution.is_empty() and int(level.execution.seat) == 1)
	level.release_execution()
	await frames(4)
	creature.global_position = Vector3(0, -80, 0)
	# The code and its notes.
	var right: String = "".join(DIG.code(level.manifest).map(func(digit): return str(digit)))
	level.set_rules({"code": 1})
	check("Si hacen falta las notas, el código acertado no abre sin ellas", level.code_verdict(right) == "notes" and level.code_verdict("0000" if right != "0000" else "1111") == "wrong")
	for slot in range(1, DIG.COUNT + 1): level.found_digits[slot] = int(right[slot - 1])
	check("Y con las cuatro encontradas, sí", level.code_verdict(right) != "notes")
	level.found_digits.clear()
	level.set_rules({})
	check("Con las reglas del juego se puede adivinar", level.code_verdict(right) != "notes")
	# The plan on the sheet.
	level.set_rules({"plan": 0})
	level.floor_map.reset()
	await frames(40)
	check("Sin plano, la hoja no dibuja nada de lo que se ve", level.floor_map.live.is_empty())
	level.set_rules({"plan_fade": 0})
	await frames(40)
	var seen: Array = level.floor_map.live.keys()
	level.floor_map.clock += 100000.0
	check("Con plano que no se borra, lo visto se queda para siempre", not seen.is_empty() and is_equal_approx(level.floor_map.freshness(int(seen[0])), 1.0))
	level.set_rules({"plan_fade": 60})
	check("Y si se borra al minuto, a ese tiempo ya no está", is_equal_approx(level.floor_map.forget, 60.0) and is_equal_approx(level.floor_map.freshness(int(seen[0])), 0.0))
	# A mind that does not wear.
	level.set_rules({"sanity": 0})
	level.player.sanity = 40.0
	await frames(4)
	check("Si la cordura no se gasta, vuelve entera y se queda", is_equal_approx(level.player.sanity, 100.0))
	# The onslaught.
	level.set_rules({"onslaught": 1})
	creature.mode = creature.Mode.CHASE
	creature.lost_time = 3.0
	check("En embestida ve y oye más lejos y no afloja al perder de vista", is_equal_approx(creature.reach_scale, creature.ONSLAUGHT_REACH) and is_equal_approx(creature.desired_speed(), creature.CHASE_SPEED))
	level.set_rules({})
	check("Sin ella, afloja", is_equal_approx(creature.reach_scale, 1.0) and is_equal_approx(creature.desired_speed(), creature.TRACK_SPEED))
	creature.mode = creature.Mode.PATROL
	# The hunter's sight.
	level.solo_locust = true
	check("El cazador reconstruye el hotel de oído", level.rig.hunter_seat() and level.rig.echo_seat())
	level.set_rules({"plain_sight": 1})
	check("Salvo que la sala le deje ver como una persona", level.rig.hunter_seat() and not level.rig.echo_seat())
	level.solo_locust = false
	# The tape of a floor played by other rules.
	level.set_rules({"mercy": 2, "blackout": 0})
	var line: Dictionary = level.ledger.close(true)
	check("Una cinta jugada con otras reglas dice cuáles y va a su tablón", line.get("rules", {}) == {"mercy": 2, "blackout": 0} and String(line.company) == level.records.CUSTOM)
	check("Y no alcanza hitos", level.records.reach(level.records.clean(line), 1).is_empty() and level.records.clean(line).get("rules", {}) == {"mercy": 2, "blackout": 0})
	# The sets: the power that stays on, and no stepping through them.
	level.session.stage = 2
	await frames(4)
	var sets: Array = level.stage_televisions()
	var needed: int = TV.needed(level.session.roster_count)
	for step in needed - 1:
		level.switch_television(level.televisions[int(sets[step])])
		await frames(3)
	check("Sin apagón, a falta de una tele la luz sigue", not bool(level.session.goal.get("blackout", false)) and not level.hotel.dark)
	level.switch_television(level.televisions[int(sets[needed - 1])])
	await frames(3)
	var lit: Array = level.lit_televisions()
	level.set_rules({"tv_travel": 0})
	creature.global_position = level.television_exit(int(lit[0])) + Vector3(0, 0.04, 0)
	creature.mode = creature.Mode.SEARCH
	var stood: Vector3 = creature.global_position
	level.tvs.hop_rest = 0.0
	for i in 8: level.tvs.creature_channel_hop(1.0)
	check("Si no viaja por las teles, se queda donde está", creature.global_position.distance_to(stood) < 0.1)
	level.set_rules({})
	level.player.global_position = Vector3(0, -200, 0)
	level.tvs.hop_rest = 0.0
	for i in 8: level.tvs.creature_channel_hop(1.0)
	check("Con las reglas del juego sale por otra", creature.global_position.distance_to(stood) > 2.0)
	await frames(3)
	check("Y el apagón llega al faltar una", bool(level.session.goal.get("blackout", false)))
	# The screen the host picks them on.
	check("Abre una sala", level.net.host("Prueba", 0, 24688) == OK)
	level.session.set_state(level.session.State.MENU)
	await frames(2)
	level.ui.menu("lobby")
	level.on_action("lobby_rules")
	await process_frame
	var tabs: TabContainer = level.ui.settings_tabs
	check("Las reglas de la sala se eligen en pestañas, una fila cada una", level.ui.screen == "rules" and is_instance_valid(tabs) and tabs.get_tab_count() == RULES.GROUPS.size() and level.ui.settings_rows[0].size() == RULES.RULES.filter(func(rule): return int(rule.group) == 0).size())
	var picker: OptionButton = level.ui.settings_rows[0][0][0]
	picker.select(2)
	picker.item_selected.emit(2)
	check("Elegir un valor lo pone en la sala", level.net.options.rules == {"mercy": 2})
	level.on_action("rules_reset")
	await process_frame
	check("Y «las del juego» las devuelve todas", level.net.options.rules.is_empty() and level.ui.screen == "rules")
	level.net.shutdown("")
	var file := FileAccess.open("res://evidence/rules_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("RULES_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
