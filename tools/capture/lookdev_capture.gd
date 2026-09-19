extends SceneTree
## Look-dev shots for the photorealism work (docs/REALISM.md): the same rooms
## of the same floor (seed 81), from fixed marks, so every milestone can be put
## side by side with the last one and with the references.
##   godot --path . --rendering-method forward_plus --script res://tools/capture/lookdev_capture.gd -- --automation --test-profile --no-enemy --silent [--label=name] [--quality=2]
## Writes evidence/lookdev/<label>_q<quality>/<shot>_raw.png (no camera at all:
## no lens, sensor, tape or OSD; the scene has to stand on its own, and it
## stays comparable pixel by pixel) and <shot>_vhs.png (as played).
## --setup=path.gd runs that script's run(level) on the built floor before the
## shots: how a trial (a light recipe, probes, a material) is compared with
## the last milestone without touching the game.
##   recepcion   the reception, its red beacon and counter
##   dormitorio  a lit bedroom
##   salon       a lit lounge
##   pasillo     a corridor with its wall lamps
##   bano        a tiled bathroom under a fluorescent batten
##   servicio    a service room (laundry, storage, maintenance)
##   oscura      a dark room, the torch on
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const SIZE := Vector2i(1920, 1080)
## Which module types each shot takes the first lit room of (the dark shot
## takes the first dark one).
const SHOTS := {"recepcion": [0], "dormitorio": [1, 2, 3], "salon": [5], "pasillo": [11], "bano": [4], "servicio": [7, 8, 9], "oscura": []}
var level
var out_dir := ""

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var label := "current"
	var quality := PRESETS.HIGH
	var setup := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--setup="): setup = argument.trim_prefix("--setup=")
	out_dir = "res://evidence/lookdev/%s_q%d" % [label, quality]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.settings.set_value("quality", quality)
	# After the floor and the settings, which place the window themselves.
	DisplayServer.window_set_size(SIZE)
	level.player.set_physics_process(false)
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	if not setup.is_empty(): await load(setup).new().run(level)
	for shot in SHOTS:
		var room := pick(shot)
		if room.is_empty():
			print("LOOKDEV no room for ", shot)
			continue
		aim(room)
		level.player.torch.visible = shot == "oscura"
		await capture(shot)
	level.queue_free()
	await process_frame
	quit()

func lit(room: Dictionary) -> bool:
	return not level.hotel.lights[int(room.id)].has_meta("off")

func pick(shot: String) -> Dictionary:
	for room in level.manifest.rooms:
		if int(room.get("hall", -1)) >= 0 and int(room.hall) != int(room.id): continue
		if shot == "oscura":
			if not lit(room): return room
		elif int(room.type) in SHOTS[shot] and lit(room): return room
	return {}

## From a little inside the middle of one wall (the corners hold furniture and
## bedroom alcoves), looking across the room at an angle, slightly down, at
## eye height: two walls, floor, ceiling and furniture in frame.
func aim(room: Dictionary) -> void:
	var centre := FLOOR.position_of(room)
	var span: Vector2 = FLOOR.size_of(room)
	var from := centre + Vector3(span.x * 0.1, 0.04, span.y * 0.5 - 1.6)
	var to := centre + Vector3(-span.x * 0.3, 0.0, -span.y * 0.5)
	level.player.global_position = from
	var flat := Vector2(to.x - from.x, to.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = -0.12
	level.player.snap_torch()

func capture(shot: String) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	# The beacon and the failing tubes blink with time: freeze them lit.
	level.hotel.flicker_clock = 0.4
	level.hotel._process(0.0)
	level.hotel.set_process(false)
	# Long enough for the shadow atlas to settle and TAA to converge.
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1500: await process_frame
	var screen: CanvasItem = level.get_node("Presentation/Analog/Screen")
	var lens: CanvasLayer = level.get_node("Presentation/Lens")
	var camcorder: CanvasLayer = level.get_node("Presentation/Camcorder")
	# The level shows the camcorder layer again every frame (and with it the
	# focus brackets on a door in view): hold it still for the raw frame.
	level.set_process(false)
	screen.visible = false
	lens.visible = false
	camcorder.visible = false
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_raw.png" % shot)
	screen.visible = true
	lens.visible = true
	camcorder.visible = true
	level.set_process(true)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_vhs.png" % shot)
	level.hotel.set_process(true)
	print("LOOKDEV ", shot)
