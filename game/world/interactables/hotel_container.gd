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

func _ready() -> void:
	add_to_group("hotel_containers")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 1.2, 0.8)
	shape.shape = box
	shape.position = Vector3(0, 0.6, 0.2)
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
