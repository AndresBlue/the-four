extends "res://game/floors/objectives/objective.gd"
## The four numbers of the last door, found in the furniture of the stage's
## wing and read into the keypad (game/app/code_lock.gd, `level.code`). On top
## of the sets where a stage asks for both: the door gives way with the code
## in and the sets lit. The drawers, the key, the hints, their RPCs and their
## state stay in code_lock.gd (the key is placed after the documents, by
## hotel_main.populate_floor()).
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const NAME := "code"

func place() -> void: level.code.place_containers()

func progress(stage: int) -> Dictionary:
	if not level.kind.asks(stage, NAME): return idle()
	var lines: Array = [["NÚMEROS DEL CÓDIGO", "%d / %d" % [level.code.found_digits.size(), DIGITS.COUNT]]]
	# A floor with no furniture has no numbers to find: the stage is the sets'
	# or the refuge's, though the pause screen still counts them.
	if level.code.containers.is_empty(): return idle(lines)
	return {"ready": bool(level.code.code_entered), "done": level.code.found_digits.size(), "needed": DIGITS.COUNT, "kind": NAME, "lines": lines, "extra": {}}

## The furniture with a number in it not gone through yet, and the keypad
## while the code is not in.
func goal_points(_stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for piece in level.code.containers:
		if is_instance_valid(piece) and int(piece.digit) >= 0 and not piece.searched: points.append(piece.global_position)
	if is_instance_valid(level.code.lock) and not level.code.code_entered: points.append(level.code.lock.global_position)
	return points

## What floor_save.gd keeps of it: the furniture gone through and by whom, the
## panels left open, the hints read where they lie, and whether the code is in.
func snapshot() -> Dictionary:
	var searched: Array = []
	for index in level.code.containers.size():
		var piece = level.code.containers[index]
		if is_instance_valid(piece) and piece.searched: searched.append([index, int(level.code.found_by.get(piece.slot, level.player.slot))])
	return {"searched": searched, "panels": level.code.opened_panels(), "hints": level.code.hints_read.keys(), "code": level.code.code_entered}

func restore(data: Dictionary) -> void:
	level.catch_up_progress({"searched": data.get("searched", []), "code": data.get("code", false), "panels": data.get("panels", [])})
	for id in data.get("hints", []): level.code.note_read(int(id))
