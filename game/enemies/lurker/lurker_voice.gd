extends Node
## What is heard of The Lurker as she moves (spec_f3_integration 3.4): her
## claws on what is under each hand, her knocks inside a duct, the false
## ceiling creaking where she shifts a tile, and the claws on the car's sheet
## between plantas. Each goes out by her own route to the listener
## (lurker.sound_route_from()): from a duct by its grilles, from the plenum by
## the tile under her, never through a wall. None of these is captioned (the
## author's I6: her lies are not, and a caption would tell which claws are
## real); her shriek's caption is shown here (shriek_heard()). Its players
## hang under world_audio, as The Locust's voice does, and are freed with it.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const BASE := "res://assets/audio/sfx/lurker/"
## Each set's files: tile_N, metal_N, hard_N, wood_N.
const SETS := {"tile": 6, "metal": 4, "hard": 8, "wood": 8}
const KNOCKS := 8
const STEP_DB := {"tile": -11.0, "metal": -8.0, "hard": -12.0, "wood": -11.0, "soft": -20.0}
## Carpet: the hard set, dulled.
const SOFT_CUTOFF := 1200.0
## At most one claw this often, and this many sounding at once.
const STEP_GAP := 0.09
const STEP_VOICES := 3
const KNOCK_DB := -6.0
const CREAK_DB := -10.0
## Her steps in a duct and over the tiles come in runs (the author, 25 October
## 2026: a steady pace saturates, then bores, and tells exactly where she
## comes from): RUN steps very fast, RUN_STEP apart, then RUN_REST of
## silence, then another run; RUN_DB quieter than the steady steps were.
## At the end of a run, now and then (SCRAPE_CHANCE), her claws on the metal.
const RUN := Vector2i(6, 8)
const RUN_STEP := Vector2(0.06, 0.09)
const RUN_REST := Vector2(1.2, 2.6)
const RUN_DB := -4.0
const SCRAPE_CHANCE := 0.35
const DUST_DB := -16.0
const CAR_DB := -8.0
## Seconds before a warning's due time from which nothing of hers starts on
## the victim's machine (0.5.6): the warning is heard clean.
const CLEAN := 0.5
## A gap tile this near is one she is crossing (travel()).
const GAP_NEAR := 0.6
var creature
var level
var rng := RandomNumberGenerator.new()
## This machine's clock (Time) after which nothing of hers starts here, set by
## lurker.play_cue() on the victim's machine; INF: no warning open here.
var quiet_until := INF
var players: Array = []
var step_at := -INF
var last_file := {}
var knock_clock := 0.0
var creak_clock := 0.0
var knock_turn := 0
## Steps left in the run under way (0: the next starts a run).
var run_left := 0
var last_gap := -1
## The last sound and the last 32 with their time, for the tests (written with
## world_audio off too): {"path", "point", "bus", "material", "gain", "cutoff", "time"}.
var last := {}
var history: Array = []

func setup(owner) -> void:
	creature = owner
	level = owner.level
	rng.seed = hash(["lurker voice", int(level.manifest.get("seed", 0)) if level != null else 0])

func _exit_tree() -> void:
	for p in players:
		if is_instance_valid(p): p.queue_free()
	players = []

func now() -> float: return Time.get_ticks_msec() / 1000.0

## Whether anything of hers may start here now: in play, the listener not in a
## room where nothing of her is heard, and not inside a warning's clean time.
func may_sound() -> bool:
	if level == null or level.session.state != level.session.State.PLAYING: return false
	var audio = level.get("world_audio")
	if audio == null: return false
	if level.has_method("point_protected") and level.point_protected(audio.listener_position()): return false
	return now() < quiet_until - CLEAN or quiet_until == INF

## Where she is: in a duct, in the plenum over the tiles (on a gap's drop or
## by a tile, spec_f3_aggression), or in a room.
func medium() -> StringName:
	var v: Dictionary = creature.view()
	if not bool(v.in_duct): return &"room"
	var near := int(v.near)
	if creature.ducts != null and near >= 0 and near < creature.ducts.node_kinds.size() and creature.ducts.node_kinds[near] in ["gap", "plenum"]: return &"plenum"
	return &"duct"

## The surface under a hand (3.4's table).
func material_at(point: Vector3, normal: Vector3, at: StringName) -> StringName:
	if at == &"duct": return &"metal"
	if at == &"plenum": return &"tile"
	var room := FLOOR.room_at(level.manifest.rooms, point)
	if room.is_empty(): return &"metal"
	if normal.y < -0.7: return &"tile" if OFFICE.false_ceiling(room) else &"hard"
	if normal.y > 0.7: return &"soft" if OFFICE.floor_finish(room) == "carpet" else &"hard"
	if in_archive(point): return &"metal"
	return &"wood" if OFFICE.wall_material(room) == "veneer" else &"hard"

## Within 0.25 m of an archive's shelving rows.
func in_archive(point: Vector3) -> bool:
	for archive in level.manifest.get("archives", []):
		for r in archive.get("rows", []):
			if point.x >= float(r[0]) - 0.25 and point.x <= float(r[2]) + 0.25 and point.z >= float(r[1]) - 0.25 and point.z <= float(r[3]) + 0.25: return true
	return false

## A hand landing (lurker_visual.footfall).
func footfall(point: Vector3, strength: float, normal: Vector3) -> void:
	var t := now()
	if t - step_at < STEP_GAP or not may_sound() or creature.hushed(): return
	step_at = t
	var material := material_at(point, normal, medium())
	var kind := "hard" if material == &"soft" else String(material)
	var gain: float = float(STEP_DB[String(material)]) + lerpf(-6.0, 0.0, clampf(strength, 0.0, 1.0)) + float(level.world_audio.duck_db())
	play_routed(pick(kind, int(SETS[kind])), point, gain, SOFT_CUTOFF if material == &"soft" else 20000.0, String(material))

## One of a set, never the same file twice running.
func pick(kind: String, count: int) -> String:
	var k := rng.randi_range(1, count)
	if count > 1 and last_file.get(kind, -1) == k: k = k % count + 1
	last_file[kind] = k
	return BASE + "%s_%d.wav" % [kind, k]

## Every physics frame while she is hidden in a duct or the plenum: her knocks
## and scrapes along the metal, the tiles under her in the plenum, and a tile
## shifted as she crosses a gap. Holding still she makes none.
func travel(delta: float, speed: float) -> void:
	var at := medium()
	if at == &"room" or creature.hushed():
		knock_clock = 0.0
		creak_clock = 0.0
		last_gap = -1
		return
	if speed < 0.05: return
	var point: Vector3 = creature.view().duct_point
	if at == &"duct":
		knock_clock -= delta
		if knock_clock <= 0.0:
			knock_clock = next_step()
			if may_sound():
				knock_turn = knock_turn % KNOCKS + 1
				play_routed(BASE + "knock_%d.wav" % knock_turn, point, KNOCK_DB + RUN_DB, 20000.0, "metal")
				if run_left == 0 and rng.randf() < SCRAPE_CHANCE: play_routed(BASE + "scrape_1.wav", point, KNOCK_DB + RUN_DB, 20000.0, "metal")
		return
	creak_clock -= delta
	if creak_clock <= 0.0:
		creak_clock = next_step()
		if may_sound(): play_routed(pick("tile", int(SETS.tile)), point, CREAK_DB + RUN_DB, 20000.0, "tile")
	var gap := gap_near(point)
	if gap >= 0 and gap != last_gap: tile_shift(creature.ducts.exits[gap].position)
	last_gap = gap

## The seconds to her next step: a run's short ones, and a rest after its last.
func next_step() -> float:
	if run_left <= 0: run_left = rng.randi_range(RUN.x, RUN.y)
	run_left -= 1
	return rng.randf_range(RUN_REST.x, RUN_REST.y) if run_left == 0 else rng.randf_range(RUN_STEP.x, RUN_STEP.y)

func gap_near(point: Vector3) -> int:
	var exits: Array = creature.ducts.exits
	for e in exits.size():
		if String(exits[e].kind) == "gap" and (exits[e].position as Vector3).distance_to(point) <= GAP_NEAR: return e
	return -1

## A ceiling tile moved where she goes in or out, or crosses a gap: the grid
## creaks and, with `dust`, dust falls from it a moment later.
func tile_shift(point: Vector3, dust := true) -> void:
	if not may_sound(): return
	play_routed(BASE + "tile_creak_%d.wav" % rng.randi_range(1, 3), point, CREAK_DB, 20000.0, "tile")
	if not dust: return
	var file := BASE + "dust_%d.wav" % rng.randi_range(1, 2)
	get_tree().create_timer(0.15).timeout.connect(func(): if is_instance_valid(self) and may_sound(): play_routed(file, point, DUST_DB, 20000.0, "tile"))
	puff(point)

## A one-shot of grey dust under the tile, freed after 3 s (her lies' too).
func puff(point: Vector3) -> void: dust_puff(level, point)

static func dust_puff(level, point: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 40
	dust.lifetime = 1.6
	dust.explosiveness = 0.6
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.25, 0.02, 0.25)
	dust.gravity = Vector3(0, -1.5, 0)
	dust.initial_velocity_min = 0.0
	dust.initial_velocity_max = 0.2
	dust.scale_amount_min = 0.01
	dust.scale_amount_max = 0.03
	dust.color = Color(0.62, 0.6, 0.57, 0.8)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	dust.mesh = mesh
	level.add_child(dust)
	dust.global_position = point + Vector3(0, -0.05, 0)
	if level.get("hotel") != null and level.hotel.has_method("adopt"): level.hotel.adopt(dust)
	dust.emitting = true
	dust.get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(dust): dust.queue_free())

## Her shriek, heard: its caption within CAPTION_NEAR of the listener (the
## sound is the brain's scream(), on every machine).
const SHRIEK_CAPTION := "[Un chillido]"
const CAPTION_NEAR := 16.0
func shriek_heard(point: Vector3) -> void:
	var audio = level.get("world_audio")
	if audio == null or audio.listener_position().distance_to(point) > CAPTION_NEAR: return
	if level.has_method("point_protected") and level.point_protected(audio.listener_position()): return
	audio.show_caption(SHRIEK_CAPTION, false)

## Her claws on the car's sheet while this machine's player rides it between
## plantas: through the sheet on purpose, the one sound of hers not routed.
var car_side := 1.0
func outside_car() -> void:
	var lifts = level.get("lifts")
	if lifts == null or lifts.boarding.is_empty() or not lifts.boarding.has("point"): return
	var camera: Camera3D = level.world_audio.listener_camera()
	var forward := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
	var side := Vector3(-forward.z, 0, forward.x) * car_side
	car_side = -car_side
	var at: Vector3 = (lifts.boarding.point as Vector3) + side * 1.3 + Vector3.UP * rng.randf_range(1.0, 2.4)
	var file := BASE + ("scrape_1.wav" if rng.randf() < 0.25 else "metal_%d.wav" % rng.randi_range(1, 4))
	play_direct(file, at, CAR_DB)

## A sound of hers by her route to the listener: nothing when it does not
## reach them.
func play_routed(path: String, point: Vector3, gain: float, cutoff := 20000.0, material := "") -> void:
	var audio = level.world_audio
	var route: Dictionary = creature.sound_route_from(point, audio.listener_position())
	note(path, route.get("position", point), String(route.get("bus", "")), material, gain, cutoff)
	audio.last_event = {"path": path, "position": point}
	if not bool(route.get("audible", false)) or not audio.enabled or audio.hush: return
	var player := voice_player(path)
	audio.apply_route(player, route, gain + audio.mask_db(point), "Threat", true)
	if route.has("bus"): player.bus = route.bus
	player.attenuation_filter_cutoff_hz = minf(player.attenuation_filter_cutoff_hz, cutoff)
	history[history.size() - 1]["bus"] = String(player.bus)
	history[history.size() - 1]["point"] = player.global_position
	last = history[history.size() - 1]
	player.play()

## Straight from a point on a bus of the creature's, not routed.
func play_direct(path: String, point: Vector3, gain: float, bus := &"Creature") -> void:
	var audio = level.world_audio
	note(path, point, String(bus), "", gain, 20000.0)
	if not audio.enabled or audio.hush: return
	var player := voice_player(path)
	player.global_position = point
	player.bus = bus
	player.panning_strength = 0.0
	player.volume_db = gain
	player.play()

func note(path: String, point: Vector3, bus: String, material: String, gain: float, cutoff: float) -> void:
	last = {"path": path, "point": point, "bus": bus, "material": material, "gain": gain, "cutoff": cutoff, "time": now()}
	history.append(last)
	if history.size() > 32: history.pop_front()

## A player of its own for each sound, at most STEP_VOICES at once (the
## oldest stops), freed when it ends.
func voice_player(path: String) -> AudioStreamPlayer3D:
	players = players.filter(func(p): return is_instance_valid(p))
	while players.size() >= STEP_VOICES:
		var oldest: AudioStreamPlayer3D = players.pop_front()
		oldest.stop()
		oldest.queue_free()
	var player := AudioStreamPlayer3D.new()
	player.name = "LurkerVoice"
	player.stream = load(path)
	player.unit_size = 6.0
	player.max_distance = 40.0
	player.max_db = 4.0
	player.area_mask = level.world_audio.ACOUSTIC_MASK
	player.pitch_scale = rng.randf_range(0.9, 1.08)
	level.world_audio.add_child(player)
	players.append(player)
	player.finished.connect(func():
		players.erase(player)
		player.queue_free())
	return player
