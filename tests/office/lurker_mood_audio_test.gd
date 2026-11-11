extends SceneTree
## The Lurker's score in sound without a floor (spec_lurker_rebuild 4): the
## theme back within 6 s once she has fled (theme_mood's release), and not
## so without it; her duct runs by beat (lurker_voice.next_step()).
const THEME_MOOD := preload("res://game/audio/theme_mood.gd")
const VOICE := preload("res://game/enemies/lurker/lurker_voice.gd")
const STEP := 1.0 / 60.0
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	theme()
	runs()
	var file := FileAccess.open("res://evidence/lurker_mood_audio_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_MOOD_AUDIO_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	await process_frame
	quit(1 if failed > 0 else 0)

## Seconds from the worst until the whole theme is back, nothing felt any more.
func back_after(release: bool) -> float:
	var mood = THEME_MOOD.new()
	mood.setup()
	mood.tension = 1.0
	mood.worst = 1.0
	var t := 0.0
	while float(mood.gain()) < 0.99 and t < 60.0:
		mood.step(0.0, STEP, release)
		t += STEP
	mood.reset()
	return t

func theme() -> void:
	var fled := back_after(true)
	var calm := back_after(false)
	check("Tras espantarla, la musica vuelve en 6 s o menos", fled <= 6.0, "%.2f s" % fled)
	check("Sin espantada, la calma de siempre: mas de 6 s", calm > 6.0, "%.2f s" % calm)

## Stalking, 2 to 4 knocks and 2.5 to 5 s of silence; with no beat, 6 to 8
## and 1.2 to 2.6 s, as before; fleeing, no silence at all.
func runs() -> void:
	var voice = VOICE.new()
	voice.rng.seed = 7
	for entry in [[&"stalk", Vector2i(2, 4), Vector2(2.5, 5.0)], [&"", Vector2i(6, 8), Vector2(1.2, 2.6)]]:
		voice.beat = entry[0]
		voice.run_left = 0
		var steps: Vector2i = entry[1]
		var rest: Vector2 = entry[2]
		var ok := true
		var count := 0
		for i in 300:
			var gap: float = voice.next_step()
			count += 1
			if gap > 0.5:
				ok = ok and gap >= rest.x and gap <= rest.y and count >= steps.x and count <= steps.y
				count = 0
		check("Tandas con el compas '%s': %d a %d golpes y %.1f a %.1f s de silencio" % [String(entry[0]), steps.x, steps.y, rest.x, rest.y], ok)
	voice.beat = &"scare"
	voice.run_left = 0
	var steady := true
	for i in 100: steady = steady and float(voice.next_step()) <= 0.09
	check("Huyendo, una tanda que no para", steady)
	voice.free()
