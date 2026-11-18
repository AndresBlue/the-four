extends SceneTree
## The offices' minds (.claude/specs/cordura_y_edificio.md 3.1 and 3.3, the
## author, 18 November 2026), on the numbers alone: her wait between attacks by
## how many play, a parry costing less on the same survivor each time and
## coming back with time, nothing given back in the light, and a whole mind
## lasting under steady pressure: five minutes for a lone survivor who parries
## everything and keeps her in view, three for one of five. The play of it
## (a mind at 0 bare to her, the coffee) is in lurker_fairness_test and
## coffee_test.
const LURKER := preload("res://game/enemies/lurker/lurker.gd")
const SANITY := preload("res://game/app/sanity.gd")
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var waits := [1, 2, 3, 4, 5, 6].map(func(n: int) -> float: return snappedf(LURKER.attack_wait(n), 0.001))
	check("Espera entre ataques: 5 s con uno, 1,25 con cinco, y entre medias", is_equal_approx(float(waits[0]), 5.0) and is_equal_approx(float(waits[4]), 1.25) and is_equal_approx(float(waits[5]), 1.25) and float(waits[1]) > float(waits[2]) and float(waits[2]) > float(waits[3]), str(waits))
	var costs := [0.0, 1.0, 2.0, 10.0].map(func(s: float) -> float: return snappedf(LURKER.parried_cost(s), 0.01))
	check("Un ataque parado cuesta menos cada vez al mismo, nunca menos del 40 %", is_equal_approx(float(costs[0]), 8.0) and is_equal_approx(float(costs[1]), 6.4) and is_equal_approx(float(costs[3]), 3.2), str(costs))
	check("Y vuelve a costar más con el tiempo: un escalón cada 20 s", LURKER.parry_steps(3.0, 0.0) == 3.0 and LURKER.parry_steps(3.0, 41.0) == 1.0 and LURKER.parry_steps(1.0, 100.0) == 0.0)
	check("En las oficinas la luz no devuelve la cordura y a 0 queda expuesta", not bool(LURKER.MIND.light_heals) and bool(LURKER.MIND.spent_bare))
	var alone := simulate(300.0, float(LURKER.MIND.alone), LURKER.attack_wait(1) + 1.0)
	check("Solo, parándolo todo y viéndola sin parar, la cordura aguanta 5 minutos", alone > 0.0, "%.1f" % alone)
	var five := simulate(180.0, 1.0, LURKER.attack_wait(5) * 5.0)
	check("Con cinco, el que más sufre aguanta 3 minutos", five > 0.0, "%.1f" % five)
	var careless := simulate(600.0, float(LURKER.MIND.alone), LURKER.attack_wait(1) + 1.0)
	check("Pero no para siempre: en 10 minutos así se acaba", careless <= 0.0, "%.1f" % careless)
	print("LURKER_MIND_TEST %d fallos" % failed)
	quit(1 if failed > 0 else 0)

## A mind at 100 for `seconds` in the dark with its torch on, her in view
## looking back every second, and a warning on it every `attack_every` s,
## every one turned away: what is left.
func simulate(seconds: float, share: float, attack_every: float) -> float:
	var mind := LURKER.MIND
	var value := 100.0
	var rest := 0.0
	var paid := 0.0
	var steps := 0.0
	var last := -INF
	var next_look := 0.0
	var next_attack := attack_every
	var t := 0.0
	var dt := 0.05
	while t < seconds:
		rest = maxf(0.0, rest - dt)
		value = maxf(0.0, value - SANITY.SANITY_DARK * SANITY.SANITY_TORCH * dt)
		if t >= next_look:
			var paying := SANITY.pay(value, rest, paid, float(mind.stare) * share, float(mind.rest))
			value = paying.x
			rest = paying.y
			paid = paying.z
			next_look += 1.0
		if t >= next_attack:
			var s := LURKER.parry_steps(steps, t - last)
			steps = s + 1.0
			last = t
			var paying := SANITY.pay(value, rest, paid, LURKER.parried_cost(s) * share, float(mind.rest))
			value = paying.x
			rest = paying.y
			paid = paying.z
			next_attack += attack_every
		t += dt
	return value
