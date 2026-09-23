extends Area3D
## A piece with drawers or shelves, gone through by hand. Most hold nothing;
## four of them, in the wing of the last stage, hold a number of the code.
##
## Going through one is not quiet and it is not instant: it takes a second of
## standing there with your back to the room, and it can be heard from the
## rooms next door. That is the price of looking.
signal searched_changed
const NOISE := preload("res://game/audio/noise_kinds.gd")
## Seconds of holding the interaction before it gives up what it has.
const SEARCH_TIME := 1.0
## The number it hides, or -1, and which place of the code it is (1..4).
var digit := -1
var slot := 0
var searched := false
var kind := ""
## How far the piece's front stands from its stretch's wall (room_dressing).
## The note and the hand's reach are measured from it: at a fixed half metre
## the note was buried in most pieces, and a cabinet deeper than that could
## not be searched from the front at all.
var front := 0.5
## Where the note sits on this piece, worked out by the dressing from the
## piece's own mesh (room_dressing.note_fold()): {at, yaw, skew, lie, hang,
## lie_tilt, hang_tilt}. Empty: the old place, out of the front.
var note_spot := {}

func _ready() -> void:
	add_to_group("hotel_containers")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var reach := maxf(front, 0.3) + 0.25
	box.size = Vector3(1.1, 1.2, reach + 0.2)
	shape.shape = box
	shape.position = Vector3(0, 0.6, (reach - 0.2) * 0.5)
	add_child(shape)

## Gone through. Returns whether this changed anything, so the noise and the
## notice happen once.
func set_searched(value: bool) -> bool:
	if searched == value: return false
	searched = value
	searched_changed.emit()
	return true

## Heard like a door opened slowly: enough to say somebody is in this room.
func noise_radius() -> float: return NOISE.radius("door_slow")

## The slip of paper one of the four hides, left showing, pale enough to catch
## a torch from across the room. Four numbers among two hundred pieces of
## furniture are not found by opening all of them, and this is what says which
## one is worth the second it takes.
##
## Where it is depends on the piece, as it would: shut in a drawer and hanging
## out of the slit above it, or laid on a shelf, on the top of a console or of
## the painted cupboard or on a box's lid, with its end come down over the
## edge. A sheet folded once, so the part that lies back (inside the
## drawer, under the books) and the part that hangs in front are both where
## paper would be. Put at one height out of the front of everything, it hung
## in the air under a console and in front of a bookcase's empty shelf.
##
## Taking it is going through the piece as usual; the paper leaves with it,
## which is the other half of the answer -- you can see, from the doorway,
## which rooms you have already been through.
const SHEET := Vector2(0.16, 0.21)
const THICK := 0.003
## A few lines of handwriting across it, every LINE_EVERY metres: they are what
## says a note rather than a scrap, close up.
const INK := Color(0.16, 0.15, 0.18)
const LINE_EVERY := 0.024
var note: Node3D
func plant_note() -> void:
	if is_instance_valid(note): return
	var spot := note_spot
	if spot.is_empty(): spot = {"at": Vector3(0.02, 0.56, maxf(front, 0.3) + 0.01), "yaw": 0.0, "skew": 0.0, "lie": 0.0, "hang": SHEET.y, "lie_tilt": 0.0, "hang_tilt": 0.3}
	var sheet := StandardMaterial3D.new()
	# The palest thing in the room, and no light of its own: the torch is what
	# picks it out. Lit of itself it hung in a pitch-dark room like a lamp.
	sheet.albedo_color = Color(0.96, 0.94, 0.87)
	sheet.roughness = 0.95
	var ink := StandardMaterial3D.new()
	ink.albedo_color = INK
	ink.roughness = 1.0
	note = Node3D.new()
	note.name = "Note"
	note.position = spot.at
	note.rotation.y = float(spot.yaw)
	add_child(note)
	var skew := float(spot.get("skew", 0.0))
	# Back from the fold, down by lie_tilt, askew on the surface it lies on.
	var lie := float(spot.lie)
	if lie > 0.001:
		var tilt := Basis(Vector3.UP, skew) * Basis(Vector3.RIGHT, -float(spot.lie_tilt))
		add_part("Lie", tilt, Vector3(0, THICK * 0.5, -lie * 0.5), Vector3(SHEET.x, THICK, lie), sheet, ink, Vector3(0, 0, -1), Vector3(0, 1, 0))
	# Down from the fold, its foot out by hang_tilt, askew on the face it hangs
	# against: the same turn, seen from the front.
	var hang := float(spot.hang)
	if hang > 0.001:
		var tilt := Basis(Vector3.RIGHT, -float(spot.hang_tilt)) * Basis(Vector3.BACK, skew)
		add_part("Hang", tilt, Vector3(0, -hang * 0.5, THICK * 0.5), Vector3(SHEET.x, hang, THICK), sheet, ink, Vector3(0, -1, 0), Vector3(0, 0, 1))

## One part of the folded sheet: `turn` sets it on its face, `centre` is its
## middle before the turn, measured from the fold. Its lines of writing run
## across it, away from the fold (`away`), on the face that shows (`face`).
func add_part(part_name: String, turn: Basis, centre: Vector3, size: Vector3, sheet: Material, ink: Material, away: Vector3, face: Vector3) -> void:
	var paper := BoxMesh.new()
	paper.size = size
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = paper
	part.material_override = sheet
	part.transform = Transform3D(turn, turn * centre)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	note.add_child(part)
	var length: float = absf(size.dot(away))
	var line := BoxMesh.new()
	line.size = Vector3(SHEET.x * 0.7, 0.003, 0.003)
	line.material = ink
	var written := 0
	var along := 0.018
	while along < length - 0.012:
		var stroke := MeshInstance3D.new()
		stroke.mesh = line
		# Every third line ends a sentence short; all start at one margin.
		var short: float = 0.03 if written % 3 == 2 else 0.0
		stroke.scale = Vector3(1.0 - short / (SHEET.x * 0.7), 1.0, 1.0)
		stroke.position = away * (along - length * 0.5) + face * (THICK * 0.5 + 0.0012) + Vector3(-short * 0.5, 0, 0)
		stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.add_child(stroke)
		written += 1
		along += LINE_EVERY

## Gone through: whoever did it took the paper with them.
func take_note() -> void:
	if is_instance_valid(note): note.queue_free()
	note = null
