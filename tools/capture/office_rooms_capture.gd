extends SceneTree
## Each room of floor 2 that has a reference picture (docs/referencias/), lit
## and framed from its doorway (spec_rediseno 6), beside its reference in one
## picture, with the figures of criteria (a) and (b) of spec_rediseno 11; the
## same room with the game's field of view and its tape; and the building
## views. Built at Apacible with every room lit, planta 3 too. With a window:
##   godot --path . --script res://tools/capture/office_rooms_capture.gd --log-file <log> -- --automation --test-profile --silent [--seed=7] [--quality=2] [--prefix=antes]
## Writes evidence/rediseno/<prefix>/<sala>.png (reference left, clean capture
## right), <sala>_juego.png, vano_<sala>.png, edificio_pasillo.png and
## cifras.json. Quality 2 is Alto, 4 Muy bajo (graphics_presets.NAMES). A
## room's "lit" is its own lamp or battery unit shining in the picture and the
## picture not dark ("lampara", "emergencia", "a_oscuras" say which).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
## Each room with a reference: its name, its picture, and the types that are
## it (the first room found of the first type that has one).
const ROOMS := [
	["recepcion", "recepción.jpeg", [0]],
	["ventanilla", "ventanilla de personal.jpeg", [17]],
	["correo", "correo.jpeg", [14]],
	["archivo", "archivo.jpeg", [6, 13]],
	["reprografia", "reprografía y microfichas.jpeg", [7]],
	["despacho", "despacho.jpeg", [3]],
	["direccion", "despacho de dirección.jpeg", [16]],
	["secretaria", "secretaría.jpeg", [24]],
	["juntas", "sala de juntas.jpeg", [5]],
	["descanso", "sala de descanso.jpeg", [15]],
	["aseos", "sala de aseos.jpeg", [4]],
	["seguridad", "puesto de seguridad.jpeg", [21]],
	["electrico", "cuarto eléctrico.jpeg", [18]],
	["climatizacion", "sala de climatización.jpeg", [22, 23]],
	["montacargas", "salida montacargas.jpeg", [19, 10]],
]
## Rooms also looked into from the room beyond their doorway.
const THROUGH := ["seguridad", "secretaria", "montacargas"]
## Criterion (b)'s samples: rows [from, to) of the picture, as fractions, over
## the middle columns.
const BANDS := {"techo": Vector2(0.0, 0.15), "pared": Vector2(0.35, 0.55), "suelo": Vector2(0.85, 1.0)}
const COLUMNS := Vector2(0.2, 0.8)
## Criterion (a): both pictures this small, then blurred.
const SMALL := Vector2i(64, 43)
## The thresholds of decision 1: (a) a correlation of at least STRUCTURE_MIN;
## (b) a band's luma within LUMA_SHARE of the reference's and its hue within
## HUE_MAX degrees. The figures are written either way; nothing is blocked.
const STRUCTURE_MIN := 0.6
const LUMA_SHARE := 0.25
const HUE_MAX := 20.0
## A picture whose three bands are all darker than this shows no light, whatever
## the room's state says (the electrical room's lamp is built out, lamp_of).
const DARK_LUMA := 0.02
## The framing: eye height in the doorway, how far back out of the room, the
## height looked at (level: the eye's own) and the horizontal field of view.
const EYE := 1.5
const OUT := 0.2
const AIM := 1.5
const FOV := 55.0
var level
var out_dir := "res://evidence/rediseno"
var game_fov := 70.0
var game_keep: int = Camera3D.KEEP_HEIGHT
var cifras: Array = []
var faltan: Array = []

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())

## Gives every room its light. The planta 3 is in closing and its rooms are in
## dark_ids, and plantas 2 and 3 start without power: the floor is put up with
## them dark, so the captures switch them on here.
func light_all() -> void:
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		var id := int(room.id)
		if level.hotel.dark_ids.has(id):
			level.hotel.set_room_power(id, false)
			level.hotel.dark_ids.erase(id)
		level.hotel.set_room_power(id, true)

## The floor baked its bounce light with the dark rooms as they were: bake it
## again now that light_all() has lit every room. Only the presets with bounce
## light have one (Alto and Ultra).
func bake_bounce() -> void:
	if not bool(level.hotel.preset.bounce): return
	level.hotel.bounce.release(-1)
	level.hotel.bounce_planta = -1
	level.hotel.start_bounce(FLOOR.planta_of(level.player.global_position.y))
	await level.bounce_ready()
	level.hotel.update_visibility(level.player.global_position, true)

## One picture as the game shows it: clean (no tape, no lens, no OSD) or with
## the camcorder layers, after the lit state and the bounce light are settled.
func grab(clean: bool) -> Image:
	light_all()
	level.hotel.update_visibility(level.player.global_position, true)
	# The beacon and the failing tubes blink with time: freeze them lit.
	level.hotel.flicker_clock = 0.4
	level.hotel._process(0.0)
	level.hotel.set_process(false)
	# The eye may stand on a planta whose bounce light is not baked yet (a look
	# into planta 2 or 3): wait for it, then show it with the next update.
	await level.bounce_ready()
	level.hotel.update_visibility(level.player.global_position, true)
	var screen: CanvasItem = level.get_node("Presentation/Analog/Screen")
	var lens: CanvasLayer = level.get_node("Presentation/Lens")
	var camcorder: CanvasLayer = level.get_node("Presentation/Camcorder")
	# The level shows the camcorder layer again every frame: hold it still for a clean frame.
	level.set_process(not clean)
	screen.visible = not clean
	lens.visible = not clean
	camcorder.visible = not clean
	# The interface's cards and HUD are OSD too (the objective card hangs over
	# the first pictures): out of the clean ones, back as they were after.
	var ui_shown: bool = level.ui.visible
	level.ui.visible = ui_shown and not clean
	# Long enough for the shadow atlas to settle and TAA to converge.
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1500: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	level.ui.visible = ui_shown
	return image

## Whether the room's own ceiling lamp shines in the picture just taken: not
## marked out, visible from the eye and with energy. The electrical room's lamp
## is built with no energy, so it never counts.
func lamp_shining(room_id: int) -> bool:
	var light: OmniLight3D = level.hotel.lights[room_id]
	return light.visible and not light.has_meta("off") and light.light_energy > 0.0

## Whether a battery unit of the room shines (its spot is visible): the light of
## a room with no lamp of its own, the electrical room's.
func battery_shining(room_id: int) -> bool:
	for entry in level.hotel.emergency:
		var unit: Dictionary = entry
		var spot: Light3D = unit.light
		if int(unit.room) == room_id and spot.visible: return true
	return false

## The first room, in the order of kinds, that is of one of them, is not void,
## is not dark and has doors. {} if none.
func room_of(kinds: Array) -> Dictionary:
	for kind in kinds:
		for room in level.manifest.rooms:
			if int(room.type) == int(kind) and not FLOOR.is_void(room) and not level.hotel.dark_ids.has(int(room.id)) and not room.get("doors", []).is_empty():
				return room
	return {}

## The doorway to look through: the first one that leads to a corridor, else
## the first one of the room. Its portal and the way into the room.
func door_of(room: Dictionary) -> Dictionary:
	var ways: Array = FLOOR.doorways(room)
	var pick: Dictionary = ways[0]
	for doorway in ways:
		var beyond: Dictionary = level.manifest.rooms[int(doorway.other)]
		if bool(beyond.get("corridor", false)):
			pick = doorway
			break
	var other: Dictionary = level.manifest.rooms[int(pick.other)]
	return {"other": other, "portal": FLOOR.portal_between(room, other), "inward": inward_of(room, other)}

## Normal of the wall shared by two rooms, pointing into room (the same
## criterion as portal_between).
static func inward_of(room: Dictionary, other: Dictionary) -> Vector3:
	return Vector3(signf(float(room.x) - float(other.x)), 0, 0) if int(room.x) != int(other.x) else Vector3(0, 0, signf(float(room.z) - float(other.z)))

## A shut door would hide the view: the doors at the portal open at once.
func open_doors(at: Vector3) -> void:
	for door in level.hotel.doors_near(at, 1.2):
		if door.has_method("open_immediately"): door.open_immediately()

## From the corridor, OUT metres back from the doorway, looking into the room.
## wide_view: the reference's framing (55 degrees, the width kept); otherwise
## the game's own camera.
func frame(door: Dictionary, wide_view: bool) -> void:
	var from: Vector3 = door.portal - door.inward * OUT + Vector3(0, EYE, 0)
	look(from, from + door.inward * 6.0 + Vector3(0, AIM - EYE, 0))
	if wide_view:
		level.player.camera.keep_aspect = Camera3D.KEEP_WIDTH
		level.player.camera.fov = FOV
	else:
		level.player.camera.keep_aspect = game_keep
		level.player.camera.fov = game_fov

func wide() -> void:
	level.player.camera.keep_aspect = Camera3D.KEEP_WIDTH
	level.player.camera.fov = FOV

## From how far, horizontally, the ceiling (or the floor) band fills the view
## at 55 degrees of horizontal field and a horizontal look.
func reach(room: Dictionary, size: Vector2i, band_name: String) -> float:
	var half_v := atan(tan(deg_to_rad(FOV) * 0.5) * float(size.y) / float(size.x))
	var edge: float = BANDS.techo.y if band_name == "techo" else 1.0 - BANDS.suelo.x
	var low := atan(tan(half_v) * (1.0 - 2.0 * edge))
	var rise: float = OFFICE.height_of(room) - EYE if band_name == "techo" else EYE
	return rise / tan(low)

static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

static func blurred(image: Image) -> PackedFloat32Array:
	var small := image.duplicate() as Image
	small.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_LANCZOS)
	var grid := PackedFloat32Array()
	grid.resize(SMALL.x * SMALL.y)
	for y in SMALL.y:
		for x in SMALL.x: grid[y * SMALL.x + x] = luma(small.get_pixel(x, y))
	for pass_index in 2:
		var next := PackedFloat32Array()
		next.resize(grid.size())
		for y in SMALL.y:
			for x in SMALL.x:
				var total := 0.0
				var count := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var sx := x + dx
						var sy := y + dy
						if sx < 0 or sy < 0 or sx >= SMALL.x or sy >= SMALL.y: continue
						total += grid[sy * SMALL.x + sx]
						count += 1
				next[y * SMALL.x + x] = total / count
		grid = next
	return grid

## Criterion (a): how alike the two pictures' lights and darks are, from -1
## to 1 (the correlation of their blurred small lumas).
static func structure(a: Image, b: Image) -> float:
	var x := blurred(a)
	var y := blurred(b)
	var mx := 0.0
	var my := 0.0
	for i in x.size():
		mx += x[i]
		my += y[i]
	mx /= x.size()
	my /= y.size()
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in x.size():
		sxy += (x[i] - mx) * (y[i] - my)
		sxx += (x[i] - mx) * (x[i] - mx)
		syy += (y[i] - my) * (y[i] - my)
	var r: float = sxy / sqrt(sxx * syy) if sxx > 0.0 and syy > 0.0 else 0.0
	return r

## Criterion (b): a band's mean luma, hue (degrees) and saturation.
static func band(image: Image, rows: Vector2) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var sum := Color(0, 0, 0)
	var light := 0.0
	var n := 0
	for y in range(int(rows.x * h), int(rows.y * h), 4):
		for x in range(int(COLUMNS.x * w), int(COLUMNS.y * w), 4):
			var c := image.get_pixel(x, y)
			sum = Color(sum.r + c.r, sum.g + c.g, sum.b + c.b)
			light += luma(c)
			n += 1
	var mean := Color(sum.r / n, sum.g / n, sum.b / n)
	return {"l": snappedf(light / n, 0.001), "h": snappedf(mean.h * 360.0, 0.1), "s": snappedf(mean.s, 0.001)}

## The reference at the capture's height, then the capture beside it.
static func beside(reference: Image, capture: Image) -> Image:
	var ref := reference.duplicate() as Image
	var scaled_width := roundi(float(reference.get_width()) * float(capture.get_height()) / float(reference.get_height()))
	ref.resize(scaled_width, capture.get_height(), Image.INTERPOLATE_LANCZOS)
	ref.convert(Image.FORMAT_RGB8)
	var out := Image.create(ref.get_width() + capture.get_width(), capture.get_height(), false, Image.FORMAT_RGB8)
	out.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	out.blit_rect(capture, Rect2i(Vector2i.ZERO, capture.get_size()), Vector2i(ref.get_width(), 0))
	return out

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 7
	var quality := 2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--prefix="): out_dir += "/" + argument.trim_prefix("--prefix=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Settings and floor as the bench sets them: the preset's own scale, no creature.
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(quality)
	level.creature_scene = "none"
	await level.start_floor(seed_value, false, [1], "apacible", 2)
	level.apply_settings()
	await level.bounce_ready()
	# The window is set after the settings: leaving full screen may bring the
	# old rectangle back a frame later.
	DisplayServer.window_set_size(Vector2i(1200, 800))
	for i in 30: await process_frame
	var size := root.get_texture().get_image().get_size()
	print("ROOMS_CAPTURE_SIZE %dx%d" % [size.x, size.y])
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	light_all()
	await bake_bounce()
	for i in 20: await process_frame
	game_fov = level.player.camera.fov
	game_keep = level.player.camera.keep_aspect
	for entry in ROOMS:
		var label: String = entry[0]
		var file_name: String = entry[1]
		var room: Dictionary = room_of(entry[2])
		if room.is_empty():
			faltan.append(label)
			print("ROOMS_CAPTURE_MISSING %s" % label)
			continue
		var door: Dictionary = door_of(room)
		open_doors(door.portal)
		frame(door, true)
		var capture: Image = await grab(true)
		var reference: Image = Image.load_from_file(ProjectSettings.globalize_path("res://docs/referencias/" + file_name))
		if reference == null or reference.is_empty():
			print("ROOMS_CAPTURE_NOREF %s" % label)
			capture.save_png(out_dir + "/" + label + ".png")
		else:
			var depth: float = FLOOR.size_of(room).x if absf(door.inward.x) > 0.5 else FLOOR.size_of(room).y
			var techo_visto: bool = depth + OUT >= reach(room, size, "techo")
			var suelo_visto: bool = depth + OUT >= reach(room, size, "suelo")
			var structure_value: float = snappedf(structure(capture, reference), 0.001)
			var bands := {}
			var b_ok := true
			for band_name in BANDS:
				var rows: Vector2 = BANDS[band_name]
				var cap_band: Dictionary = band(capture, rows)
				var ref_band: Dictionary = band(reference, rows)
				var dl: float = snappedf(float(cap_band.l) - float(ref_band.l), 0.001)
				var dh: float = snappedf(fposmod(float(cap_band.h) - float(ref_band.h) + 180.0, 360.0) - 180.0, 0.1)
				bands[band_name] = {"captura": cap_band, "referencia": ref_band, "dl": dl, "dh": dh}
				# Decision 2: the ceiling and the floor count only where they are seen.
				var seen: bool = true
				if band_name == "techo": seen = techo_visto
				elif band_name == "suelo": seen = suelo_visto
				if seen and (absf(dl) > LUMA_SHARE * float(ref_band.l) or absf(dh) > HUE_MAX): b_ok = false
			var a_ok: bool = structure_value >= STRUCTURE_MIN
			var techo_no_mas_oscuro: bool = float(bands.techo.captura.l) >= float(bands.pared.captura.l)
			# Lit as the picture shows it: the room's own lamp or its battery unit
			# shining, and a picture with no light in any band is dark, whatever
			# the room's state says (hotel.lit() only reads the state).
			var lamp_now: bool = lamp_shining(int(room.id))
			var battery_now: bool = battery_shining(int(room.id))
			var dark_picture: bool = maxf(maxf(float(bands.techo.captura.l), float(bands.pared.captura.l)), float(bands.suelo.captura.l)) < DARK_LUMA
			var lit_now: bool = (lamp_now or battery_now) and not dark_picture
			if dark_picture: print("ROOMS_CAPTURE_DARK %s" % label)
			cifras.append({"room": int(room.id), "type": int(room.type), "planta": int(room.wing) + 1, "lit": lit_now, "lampara": lamp_now, "emergencia": battery_now, "a_oscuras": dark_picture, "estructura": structure_value, "bandas": bands, "techo_no_mas_oscuro": techo_no_mas_oscuro, "fondo": snappedf(depth, 0.01), "techo_visto": techo_visto, "suelo_visto": suelo_visto, "veredicto": {"a": a_ok, "b": b_ok}})
			print("ROOMS_CAPTURE %s room=%d planta=%d lit=%s estructura=%.3f techo=%.3f pared=%.3f suelo=%.3f techo_visto=%s" % [label, int(room.id), int(room.wing) + 1, str(lit_now), structure_value, float(bands.techo.captura.l), float(bands.pared.captura.l), float(bands.suelo.captura.l), str(techo_visto)])
			print("ROOMS_CAPTURE_VERDICT %s a=%s b=%s" % [label, str(a_ok), str(b_ok)])
			beside(reference, capture).save_png(out_dir + "/" + label + ".png")
			frame(door, false)
			var game: Image = await grab(false)
			game.save_png(out_dir + "/" + label + "_juego.png")
			if THROUGH.has(label):
				var through_from: Vector3 = door.portal - door.inward * 2.0 + Vector3(0, EYE, 0)
				look(through_from, FLOOR.position_of(room) + Vector3(0, AIM, 0))
				wide()
				var through: Image = await grab(true)
				through.save_png(out_dir + "/vano_" + label + ".png")
	# The longest corridor of planta 1 (the most doors on a tie), its far end in view.
	var corridor: Dictionary = {}
	var best_length := -1.0
	var best_ways := -1
	for room in level.manifest.rooms:
		if int(room.type) != OFFICE.CORRIDOR or int(room.wing) != 0 or FLOOR.is_void(room): continue
		var length: float = maxf(float(room.span_x), float(room.span_z))
		var ways: int = room.get("doors", []).size()
		if length > best_length or (length == best_length and ways > best_ways):
			corridor = room
			best_length = length
			best_ways = ways
	if corridor.is_empty():
		print("ROOMS_CAPTURE_NOCORRIDOR")
	else:
		var along_x: bool = float(corridor.span_x) >= float(corridor.span_z)
		var axis: Vector3 = Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var half: float = float(corridor.span_x) * 0.5 if along_x else float(corridor.span_z) * 0.5
		var centre: Vector3 = FLOOR.position_of(corridor)
		look(centre - axis * (half - 0.5) + Vector3(0, EYE, 0), centre + axis * half + Vector3(0, AIM, 0))
		wide()
		var hall: Image = await grab(true)
		hall.save_png(out_dir + "/edificio_pasillo.png")
		print("ROOMS_CAPTURE_CORRIDOR room=%d length=%.2f doors=%d" % [int(corridor.id), best_length, best_ways])
	level.hotel.set_process(true)
	level.set_process(true)
	var file := FileAccess.open(out_dir + "/cifras.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": seed_value, "quality": quality, "renderer": RenderingServer.get_current_rendering_method(), "size": [size.x, size.y], "salas": cifras, "faltan": faltan}, "\t"))
	file.close()
	print("ROOMS_CAPTURE_DONE salas=%d faltan=%s" % [cifras.size(), ", ".join(PackedStringArray(faltan))])
	quit()
