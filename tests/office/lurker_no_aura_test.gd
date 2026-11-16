extends SceneTree
## The Lurker with no aura (the author, 16 November 2026): brought over the
## ceiling, unseen, to 20, 10, 5 and 2 m of walking from the listener, once
## with the aura her profile gave her before and once as she is now, and what
## of the aura, her presence and the theme plays each time, logged in
## evidence/sin_aura/. Now nothing plays at any distance and the theme does
## not move. Then what moves it: her face seen, her warning in the listener's
## own ears; and the heartbeat with a mind going and nobody near.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SEEDS := [81, 7, 2026, 11]
const TARGETS := [20.0, 10.0, 5.0, 2.0]
## Seconds she is left at each distance before it is listened to, and for how long.
const SETTLE := 2.0
const LISTEN := 3.0
var checks: Array = []
var failed := 0
var level
var lurker
var audio
var spot := Vector3.ZERO
var log_lines: PackedStringArray = []
var table: Array = []

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	var room := {}
	for seed_value in SEEDS:
		await level.start_floor(int(seed_value), false, [1], "equilibrada")
		room = listener_room()
		if not room.is_empty(): break
	lurker = level.creature
	audio = level.world_audio
	if room.is_empty() or lurker == null or lurker.kind_id() != &"lurker":
		check("Una sala con luz de la planta 1 bajo su techo, y ella en el piso", false)
		await finish()
		return
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	lurker.thinking = false
	lurker.grace = 0.0
	audio.enabled = true
	spot = FLOOR.closest(level.get_world_3d().navigation_map, FLOOR.position_of(room)) + Vector3(0, 0.04, 0)
	level.player.global_position = spot
	await frames(2)
	await route_log()
	await theme_moves()
	await heart_alone()
	await finish()

func finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/sin_aura"))
	var file := FileAccess.open("res://evidence/sin_aura/aura_por_distancia.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"rows": table, "checks": checks}, "\t"))
	var text := FileAccess.open("res://evidence/sin_aura/aura_por_distancia.txt", FileAccess.WRITE)
	if text != null: text.store_string("\n".join(log_lines) + "\n")
	var out := FileAccess.open("res://evidence/lurker_no_aura_test.json", FileAccess.WRITE)
	if out != null: out.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_NO_AURA_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	if level != null: level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

func frames(count: int) -> void:
	for i in count: await physics_frame

## A lit room of planta 1 with a ceiling of hers, not protected.
func listener_room() -> Dictionary:
	var creature = level.creature
	if creature == null or creature.get("shell") == null: return {}
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != 0 or level.off_limits_rooms().has(int(room.id)): continue
		if not creature.shell.tray_of.has(int(room.id)) or not level.hotel.lit(int(room.id)): continue
		if level.point_protected(FLOOR.position_of(room)): continue
		return room
	return {}

func walk(from: Vector3, to: Vector3) -> float:
	var path: PackedVector3Array = audio.walked_route(from, to)
	if path.size() < 2: return INF
	var metres := 0.0
	for i in range(1, path.size()): metres += path[i].distance_to(path[i - 1])
	return metres

## Points over which she can hang, by their walking distance from the listener.
func candidates() -> Array:
	var out: Array = []
	var here := FLOOR.room_at(level.manifest.rooms, spot)
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != 0 or level.off_limits_rooms().has(int(room.id)): continue
		if not lurker.shell.tray_of.has(int(room.id)): continue
		var centre := FLOOR.position_of(room)
		var points: Array = [centre]
		if int(room.id) == int(here.id):
			for d in [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2), Vector3(1.4, 0, 1.4)]: points.append(spot + d)
		for p in points:
			if lurker.shell.state_at(p + Vector3.UP) == null: continue
			out.append({"point": p, "walk": walk(spot, p)})
	return out

## What plays, every physics frame for LISTEN seconds.
func listen() -> Dictionary:
	var aura = audio.aura
	var got := {"drone_db": -INF, "drone": false, "chitters": 0, "breath": false, "heart": false, "muffle_hz": 20000.0, "presence": false, "presence_db": -INF, "caption": "", "tension": 0.0, "theme_gain": 1.0, "aura": 0.0}
	var chitter_was := false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(LISTEN * 1000.0):
		level.player.sanity = 100.0
		await physics_frame
		if aura.drone.playing:
			got.drone = true
			got.drone_db = maxf(float(got.drone_db), aura.drone.volume_db)
		if aura.chitter.playing and not chitter_was: got.chitters = int(got.chitters) + 1
		chitter_was = aura.chitter.playing
		if aura.breath.playing: got.breath = true
		if aura.heart.playing: got.heart = true
		if aura.muffle != null: got.muffle_hz = minf(float(got.muffle_hz), aura.muffle.cutoff_hz)
		if audio.presence.playing:
			got.presence = true
			got.presence_db = maxf(float(got.presence_db), audio.presence.volume_db)
		if not audio.caption_text.is_empty(): got.caption = audio.caption_text
		got.tension = maxf(float(got.tension), float(audio.mood.tension))
		got.theme_gain = minf(float(got.theme_gain), float(audio.mood.gain()))
		got.aura = maxf(float(got.aura), float(aura.intensity))
	return got

func quiet_all() -> void:
	audio.aura.reset()
	audio.mood.reset()
	audio.presence.stop()
	audio.presence_gain = 0.0
	audio.caption_text = ""
	audio.caption_cooldown = 0.0
	audio.caption_lock = 0.0

## Before (her profile with the aura it had) and now, at each distance.
func route_log() -> void:
	var now_profile: Resource = audio.profile
	var before: Resource = now_profile.duplicate()
	before.set("aura", true)
	var options := candidates()
	log_lines.append("The Lurker sobre el techo, sin que la vean, acechando (compás stalk, sobre una taquilla para la presencia).")
	log_lines.append("Oyente en %s, sala con luz. Antes: el perfil con aura; ahora: lurker.tres sin aura." % str(spot))
	log_lines.append("dist  camino | modo   | zumbido (dB)  chasquidos  latido  ambiente (Hz)  presencia (dB)  subtítulo | música: tensión  volumen")
	var heard_before := false
	var silent_now := true
	var theme_still := true
	for target in TARGETS:
		var best: Dictionary = {}
		for c in options:
			if best.is_empty() or absf(float(c.walk) - target) < absf(float(best.walk) - target): best = c
		if best.is_empty(): continue
		for mode in ["antes", "ahora"]:
			audio.set_creature(before if mode == "antes" else now_profile)
			quiet_all()
			lurker.place_over(best.point, spot)
			lurker.word = &"wait"
			lurker.brain.beat = &"stalk"
			# Looking away from her: unseen.
			var towards: Vector3 = lurker.global_position - level.player.camera.global_position
			level.player.rotation.y = atan2(towards.x, towards.z)
			level.player.camera.rotation.x = 0.0
			await create_timer(SETTLE).timeout
			var got := await listen()
			got["target"] = target
			got["walk"] = float(best.walk)
			got["mode"] = mode
			table.append(got)
			log_lines.append("%4.0f  %5.1f  | %-6s | %s  %10d  %6s  %13.0f  %s  %s | %.2f  %.2f" % [target, float(best.walk), mode,
				("%6.1f" % float(got.drone_db)) if got.drone else "  no  ", int(got.chitters), "sí" if got.heart else "no", float(got.muffle_hz),
				("%6.1f" % float(got.presence_db)) if got.presence else "  no  ", got.caption if not String(got.caption).is_empty() else "-", float(got.tension), float(got.theme_gain)])
			if mode == "antes" and target <= 5.0 and bool(got.drone): heard_before = true
			if mode == "ahora":
				if got.drone or int(got.chitters) > 0 or got.breath or got.heart or got.presence or float(got.muffle_hz) < 19999.0 or float(got.aura) > 0.0 or not String(got.caption).is_empty(): silent_now = false
				if float(got.tension) > 0.0: theme_still = false
	audio.set_creature(now_profile)
	quiet_all()
	check("Antes, con aura, a 5 m o menos sonaba su zumbido (la prueba oye lo que había)", heard_before)
	check("Ahora, a 20, 10, 5 y 2 m sin que la vean: ni zumbido, ni chasquidos, ni latido, ni ambiente apagado, ni presencia ni su subtítulo", silent_now)
	check("Ahora la música no se mueve por su cercanía oculta", theme_still)

## Her face seen in the lit room: the theme draws in. Her warning in the
## listener's own ears: all of it.
func theme_moves() -> void:
	quiet_all()
	var ahead := spot + Vector3(0, 0, -3.0)
	if lurker.shell.state_at(ahead + Vector3.UP) == null: ahead = spot + Vector3(3.0, 0, 0)
	lurker.place_over(ahead, spot)
	lurker.word = &"stalk"
	lurker.brain.beat = &"stalk"
	await frames(2)
	var face: Vector3 = lurker.face_point()
	var to: Vector3 = face - level.player.camera.global_position
	level.player.rotation.y = atan2(-to.x, -to.z)
	level.player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await create_timer(1.5).timeout
	var seen_tension: float = audio.mood.tension
	check("Al verla, la música se aprieta", seen_tension >= 0.6, "%.2f" % seen_tension)
	# Out of sight again, far off: the warning alone.
	away()
	level.player.camera.rotation.x = 0.0
	quiet_all()
	await frames(2)
	var calm: float = audio.mood.tension
	audio.play_cue("res://assets/audio/sfx/lurker/cue_0.wav", level.player.camera.global_position + Vector3(0, 0.3, 0.4), true)
	var most := 0.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1500:
		await physics_frame
		most = maxf(most, float(audio.mood.tension))
	check("Con su aviso en los oídos, la música se aparta", calm == 0.0 and most >= 0.4, "%.2f %.2f" % [calm, most])
	audio.ears_hold = {}

## Nobody near and the mind gone: the heart beats on its own; whole, it does not.
func heart_alone() -> void:
	away()
	quiet_all()
	await frames(2)
	var beat_whole := false
	var tense := 0.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 2500:
		level.player.sanity = 100.0
		await physics_frame
		if audio.aura.heart.playing: beat_whole = true
		tense = maxf(tense, float(audio.mood.tension))
	var beat_gone := false
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 4000:
		level.player.sanity = 0.0
		level.sanity.hallucination_wait = 999.0
		await physics_frame
		if audio.aura.heart.playing: beat_gone = true
	level.player.sanity = 100.0
	log_lines.append("Latido sin ella cerca: con la cordura entera %s; con la cordura a 0 %s (pulso %.2f)." % ["suena" if beat_whole else "no suena", "suena" if beat_gone else "no suena", float(audio.aura.pulse)])
	check("Sin ella cerca, el latido sigue a la cordura: no con la cordura entera, sí con ella perdida", not beat_whole and beat_gone, "%s %s %.2f tensión %.2f" % [str(beat_whole), str(beat_gone), float(audio.aura.pulse), tense])

## Her out of the way for good: her frame stopped (it would put her back on
## her ceiling) and far under the floor.
func away() -> void:
	lurker.set_physics_process(false)
	lurker.global_position = Vector3(0, -80, 0)
