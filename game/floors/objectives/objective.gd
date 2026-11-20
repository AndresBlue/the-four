extends RefCounted
## One thing a stage can ask of the survivors (docs/OFICINAS.md 11.2): the
## floor's kind lists them by name (kind.OBJECTIVES) and each stage names the
## ones it asks (kind.STAGES[n].objectives). The level builds one of each with
## the floor and asks them rather than naming each: host_gate() whether the
## stage is met, the lifts the lines of the pause screen, the director where
## the team is going. The hotel's two wrap what they always were
## (televisions.gd and code_lock.gd), whose state, RPCs and saving stay theirs.

## The level that owns it (hotel_main.gd).
var level

## Before the floor is built, the same on every machine: what it fixes of the
## manifest, and what it hands the level to keep. Nothing, for one with
## nothing to choose.
static func settle(_manifest: Dictionary, _survivors: int, _kind: GDScript) -> Dictionary: return {}

func setup(owner_level) -> void: level = owner_level

## Put on the floor just built (hotel_main.populate_floor()).
func place() -> void: pass

## What a stage given back (a restart) takes back of it. Nobody calls it yet:
## revival.gd still puts the hotel's sets back itself, and the office's
## handlers wire it into revival.apply_revival() when they arrive (step 1e).
func reset() -> void: pass

## How it stands on that stage: {ready, done, needed, kind, lines, extra}. No
## kind: it does not apply there (not asked, or nothing of it on this floor),
## so it neither holds the stage's door nor names its goal; its lines are
## still the pause screen's. `extra`: keys it keeps in the session's goal.
func progress(_stage: int) -> Dictionary: return idle()

## Not applying, with whatever lines it still shows.
func idle(lines: Array = []) -> Dictionary:
	return {"ready": true, "done": 0, "needed": 0, "kind": "", "lines": lines, "extra": {}}

## Where what the stage still asks of it stands, for the director.
func goal_points(_stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	return points

## A recording of the offices (tools/audio/prepare_office_sfx.py) heard at
## a point; and one repeated there until stop_loop().
func sound_at(file: String, point: Vector3, gain: float) -> void:
	if level.world_audio.enabled: level.world_audio.play_at("res://assets/audio/sfx/office/" + file, point, gain)

func loop_at(file: String, point: Vector3, gain: float):
	var voice = level.world_audio.play_long("res://assets/audio/sfx/office/" + file, point, gain)
	if voice == null: return null
	voice.stream = level.world_audio.loop_stream(voice.stream)
	voice.play()
	return voice

## A looping sound that travels (a capsule in its tube): heard from `point` now.
func move_loop(voice, point: Vector3) -> void:
	if voice == null: return
	for cue in level.world_audio.long_cues:
		if cue.player == voice: cue.point = point

func stop_loop(voice) -> void:
	if voice != null: level.world_audio.stop_long(voice)

## Whether its state travels in the floor's own snapshot (catch-up, Continuar:
## spec_f1_systems 1.4). The hotel's two are carried as they always were.
func snapshotted() -> bool: return false

## How much of every sound at a point it covers, 0..1 (the offices' fans).
func sound_mask(_point: Vector3) -> float: return 0.0

## The test bots' errands on this stage (tools/bots/bot_team.gd): tasks made
## with team.office_task() or by hand. The hotel's are the team's own.
func bot_errands(_team) -> Array: return []

## The host: a survivor fell at `point` (caught, or gone for good).
func on_death(_seat: int, _point: Vector3) -> void: pass

## Every machine: a seat is on its feet again, between stages or with a stage
## given back (revival.apply_revival).
func on_return(_seat: int) -> void: pass

## A paper a usable of this handler shows when read ("read" usables).
func paper_of(_index: int) -> Dictionary: return {}

## The offices' sheet (the author's, 19 November 2026) and its size pinned to
## a wall: a letter's.
const MEMO_PAPER := preload("res://assets/hoja-oficina.png")
const MEMO_SHEET := Vector2(0.216, 0.279)
## The cork board it is pinned to (pieces/wall.gd): its size, and how far its
## cork's face stands off the wall.
const MEMO_WALL := preload("res://game/world/office/pieces/wall.gd")
const MEMO_LAYOUT := preload("res://game/world/generation/office_layout.gd")
const MEMO_FLOOR := preload("res://game/world/generation/floor_definition.gd")
const CORK := Vector3(0.3, 0.38, 0.03)
const CORK_FACE := 0.016
## A memorandum of the offices on their own sheet (game/ui/office_memo.gd):
## who sends it and to whom, its subject and its lines, typed.
static func memo(id: int, subject: String, lines: Array, sender := "Mantención", to := "Todo el personal") -> Dictionary:
	return {"id": id, "kind": "memo", "form": {"paper": "memo", "from": sender, "to": to, "subject": subject, "lines": lines, "seed": id}}

## Where a memorandum's cork board goes on the wall of `spot` (a wall spot of
## the manifest: wall, along, point, yaw), `height` over its floor: the
## stretch nearest the spot, to either side, clear of what is `taken` there
## ([from, to] along the wall from the spot), of the wall's ends, its doorways
## and its wardrobes, and of what already hangs on it. INF with no room.
func memo_place(room: Dictionary, spot: Dictionary, taken: Array, height: float) -> Vector3:
	var wall := String(spot.wall)
	var turn := Basis(Vector3.UP, float(spot.yaw))
	var origin := Vector3(float(spot.point[0]), float(spot.point[1]), float(spot.point[2]))
	# The spot's +x runs with the wall's along on north and east, against it on south and west.
	var way: float = 1.0 if wall == "north" or wall == "east" else -1.0
	var reach := CORK.x * 0.5
	for step in 150:
		for side: float in [1.0, -1.0]:
			var x: float = side * (reach + 0.02 * step)
			var along := float(spot.along) + way * x
			var free := absf(along) + reach <= MEMO_LAYOUT.wall_length(room, wall) * 0.5 - 0.06
			for span: Array in taken:
				if x + reach + 0.05 > float(span[0]) and x - reach - 0.05 < float(span[1]): free = false
			for hide in room.get("hides", []):
				var held: Dictionary = MEMO_LAYOUT.hide_wall(hide)
				if String(held.wall) == wall and absf(float(held.along) - along) < reach + 0.9: free = false
			for door in MEMO_FLOOR.doorways(room):
				if String(door.wall) == wall and absf(float(door.along) - along) < reach + 0.75: free = false
			var at := origin + turn * Vector3(x, height, 0.0)
			if free and not hung_at(at, turn, reach): return at
	return Vector3.INF

## Whether something already hangs on the wall where a cork board would go.
func hung_at(at: Vector3, turn: Basis, reach: float) -> bool:
	if not "hung" in level.hotel: return false
	for entry: Array in level.hotel.hung:
		var a: Vector3 = entry[0]
		var b: Vector3 = entry[1]
		if absf(((a + b) * 0.5 - at).dot(turn.z)) > 0.4 or float(entry[2]) > at.y + CORK.y * 0.5 or float(entry[2]) < at.y - 2.0: continue
		var from := minf((a - at).dot(turn.x), (b - at).dot(turn.x))
		var to := maxf((a - at).dot(turn.x), (b - at).dot(turn.x))
		if from < reach + 0.08 and to > -reach - 0.08: return true
	return false

## One of the offices' sheets pinned at `at` (its middle, on the wall's line),
## facing `yaw`: on its cork board with a pin through its head, or with no
## board (`corked` false) taped flat to whatever is there.
func pin_memo(at: Vector3, yaw: float, corked := true) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var off := 0.004
	if corked:
		equipment(MEMO_WALL.cork_board(level.hotel, CORK), wall_xform(CORK, at, at.y - CORK.y * 0.5, yaw))
		off = CORK_FACE + 0.003
	var sheet := MeshInstance3D.new()
	sheet.name = "Memo"
	sheet.add_to_group("office_memos")
	var quad := QuadMesh.new()
	quad.size = MEMO_SHEET
	sheet.mesh = quad
	# The offices' sheet, inside its picture's dark surround.
	var material := StandardMaterial3D.new()
	material.albedo_texture = MEMO_PAPER
	material.uv1_scale = Vector3(0.975, 0.975, 1.0)
	material.uv1_offset = Vector3(0.0125, 0.0125, 0.0)
	material.roughness = 0.9
	sheet.material_override = material
	sheet.transform = Transform3D(turn, at + turn.z * off)
	level.hotel.add_child(sheet)
	if not corked: return
	var pin := MeshInstance3D.new()
	var head := SphereMesh.new()
	head.radius = 0.006
	head.height = 0.012
	pin.mesh = head
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.08, 0.07)
	red.roughness = 0.4
	pin.material_override = red
	pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pin.position = at + Vector3(0, MEMO_SHEET.y * 0.5 - 0.016, 0) + turn.z * (off + 0.005)
	level.hotel.add_child(pin)

## The papers this seat keeps of it (TUS NOTAS), as hint dictionaries.
func own_papers(_seat: int) -> Array: return []

## Whether the car of that stage may leave with these riders (lifts.press):
## the offices' freight lift waits for its clock.
func allows_ride(_stage: int, _riders: Array) -> bool: return true

## Once a frame on the machine in charge, whatever the stage.
func tick(_delta: float) -> void: pass

## What a floor kept to be continued holds of it (floor_save.gd still writes
## the same keys itself, in its own order), and putting it back.
func snapshot() -> Dictionary: return {}

func restore(_data: Dictionary) -> void: pass

## The look of the equipment (spec_rediseno 12, area 5): pieces of
## game/world/office/pieces/ put after the floor is built. Nothing under this
## tall casts a shadow or is drawn farther than the building's small things
## (hotel_geometry SMALL_REACH); text on a plate stands this far off it, this
## small a pixel, in light letters or, on a light plate, dark ones.
const SHADOW_PIECE := 0.6
const EQUIPMENT_REACH := 32.0
const PLATE_OFF := 0.0015
const PLATE_PIXEL := 0.0015
const PLATE_INK := Color("e8e2cf")
const PLATE_DARK := Color("1c1b19")

## A piece at `xform` in `parent` (the floor when none), on the light layer of
## the room it stands in. No collider: nothing used is in its way.
func equipment(mesh: Mesh, xform: Transform3D, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.transform = xform
	var size: Vector3 = mesh.get_meta("size", mesh.get_aabb().size)
	if size.y < SHADOW_PIECE:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Past the torch's reach, and fading out after (hotel_geometry.fade_out).
		node.visibility_range_end = EQUIPMENT_REACH
		node.visibility_range_end_margin = 8.0
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var holder: Node3D = parent if parent != null else level.hotel
	holder.add_child(node)
	lay_on_room(node)
	return node

## Something put on the floor after it was built, on its room's light layer
## as what the floor built is (hotel_geometry.adopt()).
func lay_on_room(node: Node3D) -> void:
	if level.hotel.has_method("adopt"): level.hotel.adopt(node)

## A wall piece's transform: the middle of its back on the wall's face at
## `point`, its bottom at `bottom`, facing `yaw` (into the room).
func wall_xform(size: Vector3, point: Vector3, bottom: float, yaw: float) -> Transform3D:
	var turn := Basis(Vector3.UP, yaw)
	return Transform3D(turn, Vector3(point.x, bottom, point.z) + turn.z * (size.z * 0.5))

## Where a piece's text goes ("text_plate" metadata), just off the plate,
## in the frame of the piece's parent.
func plate_spot(node: MeshInstance3D) -> Vector3:
	var spot: Array = node.mesh.get_meta("text_plate")
	var centre: Vector3 = spot[0]
	var normal: Vector3 = spot[2]
	return node.transform * (centre + normal * PLATE_OFF)

## A door's pilot over its frame's head (the maneuver room's, the camera
## rooms'): its lens, its middle's height and how far off the wall's face.
const DOOR_PILOT := Vector3(0.03, 0.03, 0.012)
const DOOR_PILOT_Y := 2.69
const DOOR_PILOT_OUT := 0.07
const PILOT_LENS := preload("res://game/world/office/pieces/mail_equipment.gd")
const PILOT_WALL: float = preload("res://game/floors/palettes/office_palette.gd").WALL_HALF

## Its two lenses, [red, green], over a doorway on the face `away` points out
## of (a room's floor at `floor_y`): the handler shows one at a time.
func door_pilot_lenses(doorway: Vector3, floor_y: float, away: Vector3) -> Array:
	var at := Transform3D(Basis(Vector3.UP, atan2(away.x, away.z)), Vector3(doorway.x, floor_y, doorway.z) + away * (PILOT_WALL + DOOR_PILOT_OUT) + Vector3(0, DOOR_PILOT_Y - DOOR_PILOT.y * 0.5, 0))
	return [equipment(PILOT_LENS.lamp_lens(level.hotel, DOOR_PILOT, "glow_red"), at), equipment(PILOT_LENS.lamp_lens(level.hotel, DOOR_PILOT, "glow_green"), at)]

## Words on a plate, lit as the building's signs are, at `at` in `parent`'s
## frame (the floor when none), turned to `yaw`.
func plate_text(words: String, at: Vector3, yaw: float, font: int, ink := PLATE_INK, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font_size = font
	label.pixel_size = PLATE_PIXEL
	label.modulate = ink
	label.outline_size = 0
	label.shaded = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = at
	label.rotation.y = yaw
	var holder: Node3D = parent if parent != null else level.hotel
	holder.add_child(label)
	lay_on_room(label)
	return label
