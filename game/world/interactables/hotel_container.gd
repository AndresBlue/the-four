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

## The slip of paper one of the four hides, left showing: a corner of it out of
## the drawer, pale enough to catch a torch from across the room. Four numbers
## among two hundred pieces of furniture are not found by opening all of them,
## and this is what says which one is worth the second it takes.
##
## Taking it is going through the piece as usual; the paper leaves with it,
## which is the other half of the answer -- you can see, from the doorway,
## which rooms you have already been through.
var note: MeshInstance3D
func plant_note() -> void:
	if is_instance_valid(note): return
	var paper := BoxMesh.new()
	paper.size = Vector3(0.16, 0.21, 0.004)
	var sheet := StandardMaterial3D.new()
	sheet.albedo_color = Color(0.9, 0.87, 0.78)
	sheet.roughness = 0.95
	# Barely lit of its own: enough to be picked out in a dark room without
	# turning a drawer into a lamp.
	sheet.emission_enabled = true
	sheet.emission = Color(0.85, 0.82, 0.7)
	sheet.emission_energy_multiplier = 0.5
	note = MeshInstance3D.new()
	note.name = "Note"
	note.mesh = paper
	note.material_override = sheet
	# Out of the front of the piece, about drawer height, leaning out the way
	# a sheet caught in one does. Not on top of it: a commode, a bookcase and
	# a stack of boxes are all "a piece with drawers" here, their tops stand
	# between half a metre and two, and a paper laid on one would be buried in
	# the wood on one piece and out of sight above the head on the next. On
	# the front it is the same height on all of them, and in the eye.
	note.position = Vector3(0.02, 0.46, maxf(front, 0.3) + 0.012)
	note.rotation = Vector3(-0.32, 0.0, 0.11)
	note.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(note)

## Gone through: whoever did it took the paper with them.
func take_note() -> void:
	if is_instance_valid(note): note.queue_free()
	note = null
