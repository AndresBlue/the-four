extends SceneTree
## The whole death, staged so it can be watched as many times as you like:
## the creature stands in front of you across a room, notices you, shrieks,
## runs you down and executes you. You are the survivor and you keep the
## controls, so you can stand still and watch it or try to break its line of
## sight and see what changes.
##
##   ./tools/godot.ps1 execution -Seed 81
##
## Every beat is listed with the second it happened, which is the point of the
## tool: the scene can be read as a timeline instead of a feeling. The list is
## drawn in the window itself and written to evidence/execution_rehearsal.log,
## because the editor binary is a GUI program and its console output does not
## reach a PowerShell prompt. After you die it stages itself again a few
## seconds later, and if the creature loses you for long enough it re-stages.
##
## With "-- --shots" it takes the frames of the execution from the victim's own
## eyes into evidence/rehearsal_death_*.png and quits.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## How far apart they start, and how much room is left against each wall.
const FACING := 13.0
const MARGIN := 2.2
## Re-stage this long after a death, or after losing sight of it this long.
const AGAIN_AFTER := 4.0
const LOST_PATIENCE := 25.0
var level
var clock := 0.0
var staged := false
var last_mode := -1
var beats := {}
var seen_time := -1.0
var lost := 0.0
var shots := false
var frames_taken: Array = []
## The beats on screen, newest last, and the file they also go to.
var lines: Array = []
var board: Label
var log_file: FileAccess
const ON_SCREEN := 14

func _initialize() -> void: run.call_deferred()

func log_beat(words: String) -> void:
	var line := "[%6.2f] %s" % [clock, words]
	print(line)
	lines.append(line)
	while lines.size() > ON_SCREEN: lines.remove_at(0)
	if is_instance_valid(board): board.text = "
".join(lines)
	if log_file != null:
		log_file.store_line(line)
		log_file.flush()

## The biggest room that is not the refuge: space enough to be seen coming.
func staging_room() -> Dictionary:
	var best := {}
	var best_area := 0.0
	for room in level.manifest.rooms:
		if int(room.id) == int(level.manifest.exit): continue
		var span: Vector2 = FLOOR.size_of(room)
		var area: float = span.x * span.y
		if area > best_area:
			best_area = area
			best = room
	return best

## Both of them at either end of that room, looking at each other.
func stage() -> void:
	var room := staging_room()
	var centre: Vector3 = FLOOR.position_of(room)
	var span: Vector2 = FLOOR.size_of(room)
	var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var half: float = minf(FACING, maxf(span.x, span.y) - MARGIN * 2.0) * 0.5
	level.player.global_position = centre - along * half + Vector3(0, 0.04, 0)
	level.player.velocity = Vector3.ZERO
	level.player.rotation.y = atan2(-along.x, -along.z)
	level.player.camera.rotation.x = 0.0
	level.player.snap_torch()
	var creature = level.locust
	creature.global_position = centre + along * half + Vector3(0, 0.04, 0)
	creature.rotation.y = atan2(along.x, along.z)
	creature.grace = 0.0
	creature.detection = 0.0
	creature.lost_time = 0.0
	creature.focus = null
	creature.set_mode(creature.Mode.PATROL)
	creature.destination = creature.global_position
	# No pacing director here: an event dropping something across the floor
	# sends it off to investigate in the middle of the staging, and this tool
	# is about one thing happening at a time.
	if is_instance_valid(level.director):
		level.director.queue_free()
		level.director = null
	clock = 0.0
	beats = {}
	seen_time = -1.0
	lost = 0.0
	last_mode = creature.mode
	staged = true
	level.ui.flash("ENSAYO · %d m DE DISTANCIA" % int(half * 2.0), 3.0)
	print("STAGED room=", int(room.id), " apart=", snappedf(half * 2.0, 0.1), " m")

func mode_name(creature, mode: int) -> String:
	for key in creature.Mode.keys():
		if creature.Mode[key] == mode: return str(key)
	return str(mode)

## One line per beat, once each.
func watch(delta: float) -> void:
	var creature = level.locust
	if not is_instance_valid(creature): return
	clock += delta
	if creature.mode != last_mode:
		log_beat("MODO %s -> %s   (detección %.2f, distancia %.1f m)" % [mode_name(creature, last_mode), mode_name(creature, creature.mode), creature.detection, creature.global_position.distance_to(level.player.global_position)])
		last_mode = creature.mode
	var sees: bool = creature.sees_player()
	if sees and seen_time < 0.0:
		seen_time = clock
		log_beat("TE VE a %.1f m" % creature.global_position.distance_to(level.player.global_position))
	if not sees and seen_time >= 0.0:
		lost += delta
		if not beats.has("lost"):
			beats["lost"] = clock
			log_beat("TE PIERDE DE VISTA")
	elif sees:
		if beats.has("lost"):
			beats.erase("lost")
			log_beat("TE VUELVE A VER")
		lost = 0.0
	if creature.voice.playing and not beats.has("voice"):
		beats["voice"] = clock
		log_beat("GRUÑE")
	if not creature.voice.playing: beats.erase("voice")
	if level.execution.is_empty(): return
	var time: float = level.execution.time
	for beat in [["grab", 0.0, "TE AGARRA · el grito"], ["arm", level.ARM_TIME, "EL BRAZO SALE"], ["blow", level.KILL_TIME, "GOLPE · la lente ya está tapada"], ["static", level.SIGNAL_TIME, "ESTÁTICA · se va la señal"], ["body", level.DROP_TIME, "CAE EL CUERPO"]]:
		if time >= float(beat[1]) and not beats.has(beat[0]):
			beats[beat[0]] = clock
			log_beat(str(beat[2]))

## The timeline on screen, over the tape filter like every other message.
func build_board() -> void:
	if shots: return
	var layer := CanvasLayer.new()
	layer.layer = 90
	level.add_child(layer)
	board = Label.new()
	board.position = Vector2(24, 24)
	board.add_theme_font_size_override("font_size", 15)
	board.add_theme_color_override("font_color", Color(0.85, 0.87, 0.8))
	board.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	board.add_theme_constant_override("shadow_offset_x", 1)
	board.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(board)

func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/rehearsal_death_%s.png" % name_value)
	frames_taken.append(name_value)

func run() -> void:
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rehearsal-seed="): seed_value = int(argument.trim_prefix("--rehearsal-seed="))
		if argument == "--shots": shots = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(seed_value)
	level.settings.values.quality = 2
	level.apply_settings()
	build_board()
	log_file = FileAccess.open("res://evidence/execution_rehearsal.log", FileAccess.WRITE)
	stage()
	print("EXECUTION_REHEARSAL seed=", seed_value, " (cada golpe se imprime aquí con su segundo)")
	var pause := 0.0
	var pending: Array = [[0.05, "grab"], [level.ARM_TIME * 0.5, "held"], [level.ARM_TIME + 0.09, "arm"], [level.KILL_TIME + 0.02, "covered"], [level.SIGNAL_TIME + 0.25, "static"]]
	while true:
		await physics_frame
		var delta := 1.0 / 60.0
		if level.session.state == level.session.State.PLAYING:
			watch(delta)
			if shots and not level.execution.is_empty() and not pending.is_empty():
				if float(level.execution.time) >= float(pending[0][0]):
					await shot(str(pending[0][1]))
					pending.remove_at(0)
			# It gave up looking: start over rather than watch it wander.
			if lost > LOST_PATIENCE:
				log_beat("SE RINDE: se vuelve a montar la escena")
				stage()
		else:
			if shots:
				print("DEATH_SHOTS ", frames_taken)
				break
			pause += delta
			if pause >= AGAIN_AFTER:
				pause = 0.0
				await level.start_floor(level.session.run_seed)
				stage()
	level.queue_free()
	await process_frame
	quit()
