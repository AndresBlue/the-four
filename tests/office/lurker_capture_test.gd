extends SceneTree
## The Lurker's capture on a built floor 2 (spec_f3_integration 5): forced on
## the player under a false ceiling, from behind. What the host sends (where
## she hangs, how high she can lift them, the tile over her), her hanging head
## down through the scene with her hands on the shoulders and her face upside
## down, the victim lifted no higher than the ceiling allows and let fall where
## they stood, the swinging tile, the bite at her face, and the scene over at
## her own length with her let go and the capture written down.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SCORE := preload("res://game/app/capture_styles/lurker_score.gd")
const HOTEL_SCORE := preload("res://game/app/capture_score.gd")
const SEEDS := [7, 2026, 11]
var checks: Array = []
var failed := 0
var level

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	parity()
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	var room := {}
	for seed_value in SEEDS:
		await level.start_floor(int(seed_value), false, [1], "equilibrada")
		room = find_room()
		if not room.is_empty(): break
	var lurker = level.creature
	if room.is_empty() or lurker == null:
		check("Una sala con falso techo y ella en el piso", false)
		finish()
		return
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	lurker.thinking = false
	lurker.grace = 0.0
	level.world_audio.enabled = true
	var player = level.player
	var at := FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	player.global_position = at
	player.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	lurker.place_over(at + Vector3(0, 0, 0.5), at)
	for i in 5: await physics_frame
	level.executions.forced = {"entry": "back", "glance": false, "seed": 4242, "side": 1.0}
	level.capture_survivor(player)
	var execution: Dictionary = level.executions.execution
	var extra: Dictionary = execution.get("extra", {})
	check("Se la coge, y el anfitrión manda dónde cuelga, cuánto la puede levantar y la placa", not execution.is_empty() and extra.has("hang") and float(extra.get("lift", -1.0)) > 0.3 and float(extra.lift) <= SCORE.LIFT_HEIGHT and not (extra.get("tile", []) as Array).is_empty(), str(extra))
	if execution.is_empty():
		finish()
		return
	var from: Vector3 = execution.from
	var lift: float = float(extra.lift)
	var down := true
	var gripped := false
	var upside := true
	var highest := 0.0
	var tile_seen := false
	var bite := false
	var clock := 0.0
	while not level.executions.execution.is_empty() and clock < 7.0:
		await physics_frame
		clock += 1.0 / 60.0
		var t := float(level.executions.execution.get("time", 0.0)) if not level.executions.execution.is_empty() else clock
		if level.executions.execution.is_empty(): break
		if lurker.global_basis.y.normalized().dot(Vector3.DOWN) < 0.99: down = false
		if t > 0.4 and t < SCORE.DROP_TIME - 0.1 and lurker.visual.limbs.grips.size() == 2: gripped = true
		if t > 0.5 and t < SCORE.face_end("back") and lurker.visual.limbs.upright_share != 0.0: upside = false
		highest = maxf(highest, player.global_position.y - from.y)
		for child in level.hotel.get_children():
			if String(child.name) == "SwingingTile": tile_seen = true
		if String(level.world_audio.last_event.get("path", "")).contains("lurker/bite_"): bite = true
	check("Cuelga cabeza abajo toda la escena, con las manos en los hombros y la cara boca abajo", down and gripped and upside, "%s %s %s" % [str(down), str(gripped), str(upside)])
	check("Levanta a la víctima tanto como deja el techo, no más", highest > lift * 0.9 and highest <= lift + 0.02, "%.2f de %.2f" % [highest, lift])
	check("La placa se balancea donde entró, y el mordisco suena", tile_seen and bite)
	check("La escena dura lo suyo y la suelta", clock >= SCORE.CUT_TIME and clock <= SCORE.CUT_TIME + 0.6 and not lurker.scene_held and lurker.visual.limbs.grips.is_empty() and lurker.visual.limbs.upright_share == 1.0, "%.2f s" % clock)
	check("La captura queda apuntada", lurker.takes.size() == 1 and bool(lurker.takes[0].forced) and int(lurker.takes[0].seat) == int(player.slot), str(lurker.takes))
	check("La víctima cae donde estaba", Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length() < 1.6)
	finish()

## Her score has every name of the hotel's, and GRAB.
func parity() -> void:
	var her_script: Script = SCORE
	var hotel_script: Script = HOTEL_SCORE
	var hers: Dictionary = her_script.get_script_constant_map()
	var hotel: Dictionary = hotel_script.get_script_constant_map()
	var missing: Array = hotel.keys().filter(func(k): return not hers.has(k))
	var methods := func(script: Script) -> Array: return script.get_script_method_list().map(func(m): return String(m.name))
	var lacking: Array = methods.call(hotel_script).filter(func(m): return not methods.call(her_script).has(m))
	check("Su partitura tiene cada nombre de la del hotel, y GRAB", missing.is_empty() and lacking.is_empty() and hers.has("GRAB"), "%s %s" % [str(missing), str(lacking)])

## A room of planta 1 under a false ceiling, not too high, with her ceiling.
func find_room() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	for r in level.manifest.rooms:
		if FLOOR.is_void(r) or int(r.get("wing", -1)) != 0 or off.has(int(r.id)) or bool(r.get("corridor", false)): continue
		if not OFFICE.false_ceiling(r) or OFFICE.height_of(r) > 3.0 or not level.creature.shell.tray_of.has(int(r.id)): continue
		if minf(float(r.span_x), float(r.span_z)) < 4.0: continue
		return r
	return {}

func finish() -> void:
	var file := FileAccess.open("res://evidence/lurker_capture_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_CAPTURE_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	if level != null: level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
