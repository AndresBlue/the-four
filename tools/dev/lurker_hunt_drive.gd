extends SceneTree
## A short session of --bots-hunt on floor 2 (godot.ps1 lurker-hunt) played
## through the real devices' path: key and mouse events put into Input, as a
## person's would arrive, read by lurker_player.gd through the InputMap. What
## she did, every quarter second, and her view now and then, in
## evidence/versus/f0/sesion*.
##   godot --path . --script res://tools/dev/lurker_hunt_drive.gd -- --bots-hunt --floor=2 --bots=3 --seed=81 --test-profile
const OUT := "res://evidence/versus/f0/"
var level
var lurker
var log_lines: Array = []
var clock := 0.0
var pressed_at := -1.0
var moved_at := -1.0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 3600:
		await physics_frame
		lurker = level.get("creature")
		if is_instance_valid(lurker) and lurker.control == "player" and lurker.driver != null and level.session.state == level.session.State.PLAYING: break
	if not is_instance_valid(lurker) or lurker.control != "player":
		print("SESSION no lurker to drive")
		quit(1)
		return
	note("en sus manos; gracia %.1f s" % float(lurker.grace))
	while lurker.grace > 0.0: await tick()
	await shot("0_inicio")
	pressed_at = clock
	key(KEY_W, true)
	await wait(2.0)
	key(KEY_W, false)
	await shot("1_adelante")
	await look(Vector2(400, 0))
	key(KEY_W, true)
	key(KEY_D, true)
	await wait(1.5)
	key(KEY_W, false)
	key(KEY_D, false)
	await wait(0.6)
	await shot("2_giro")
	key(KEY_CTRL, true)
	key(KEY_CTRL, false)
	await wait(1.5)
	await shot("3_descolgada")
	key(KEY_CTRL, true)
	key(KEY_CTRL, false)
	await wait(1.0)
	key(KEY_E, true)
	key(KEY_E, false)
	await wait(3.0)
	await shot("4_dentro")
	await look(Vector2(-700, 0))
	key(KEY_E, true)
	key(KEY_E, false)
	await wait(8.0)
	await shot("5_fuera")
	key(KEY_W, true)
	await wait(3.0)
	key(KEY_W, false)
	await shot("6_otra_vez")
	var file := FileAccess.open(OUT + "sesion.txt", FileAccess.WRITE)
	if file != null:
		for line in log_lines: file.store_line(line)
	print("SESSION done, %d lines" % log_lines.size())
	quit(0)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	note("tecla %s %s" % [OS.get_keycode_string(code), "abajo" if down else "arriba"])

## The mouse moved over a quarter second, as a hand does.
func look(by: Vector2) -> void:
	for i in 15:
		var event := InputEventMouseMotion.new()
		event.relative = by / 15.0
		Input.parse_input_event(event)
		await tick()
	note("ratón %s" % str(by))

func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await tick()
		left -= 1.0 / 60.0

func tick() -> void:
	await physics_frame
	clock += 1.0 / 60.0
	var m = lurker.motion
	if pressed_at >= 0.0 and moved_at < 0.0 and m.speed > 0.1:
		moved_at = clock
		note("se mueve %.2f s después de la primera tecla" % (moved_at - pressed_at))
	if int(round(clock * 60.0)) % 15 == 0:
		var where: String = ("techo %d" % m.room()) if m.surface() else ("ducto" if m.in_duct else "paso")
		note("%s, %.2f m/s, tramo %s, cuelga %.2f, la ven %s" % [where, float(m.speed), String(m.legs[0].kind) if not m.legs.is_empty() else "libre", float(m.state.hang) if m.surface() else 0.0, str(m.watched)])

func note(words: String) -> void:
	var line := "%6.2f %s" % [clock, words]
	log_lines.append(line)
	print("SESSION ", line)

func shot(title: String) -> void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "sesion_%s.png" % title)
	note("captura sesion_%s.png" % title)
