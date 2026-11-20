extends "res://game/floors/objectives/objective.gd"
## The four numbers of the last door, found in the furniture of the stage's
## wing and read into the keypad (game/app/code_lock.gd, `level.code`). On top
## of the sets where a stage asks for both: the door gives way with the code
## in and the sets lit. The drawers, the key, the hints, their RPCs and their
## state stay in code_lock.gd (the key is placed after the documents, by
## hotel_main.populate_floor()).
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const NAME := "code"
## What the network knows it by, and what a guest may ask of it: to pick up a
## thing somebody let fall (code_lock.gd, `fallen`).
const ID := &"code"
const ACTIONS := ["pick"]
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
const CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
const PICK_TIME := 1.0
const USE_REACH := 2.5
const SLACK := 0.5
## How far from where their holder fell things lie, so no two are one on the
## other; and how big a fallen key is drawn: its own size, it is not seen.
const SPREAD := 0.2
## One reach takes all that lies this near what is picked up: what somebody
## let fall is a heap, not five things to bend down for.
const HEAP := 0.5
const KEY_SCALE := 2.0
const SLIP := Vector3(0.12, 0.003, 0.16)

func place() -> void: level.code.place_containers()

func alive(seat: int) -> bool:
	return int(level.session.participants.get(seat, level.session.Life.DEAD)) != level.session.Life.DEAD

func word_of(_usable, seat: int) -> String: return "RECOGER" if alive(seat) else ""

func hold_of(_usable, _seat: int) -> float: return PICK_TIME

func begin_use(_usable, _seat: int) -> void: pass

func holding(_usable, _seat: int, _fraction: float) -> void: pass

func cancel_use(_usable, _seat: int) -> void: pass

func refused(_action: String, _index: int, _seat: int) -> void: pass

## What the host checks before anybody's use is applied.
func allow(action: String, index: int, seat: int, body) -> bool:
	if action != "pick" or body == null or not alive(seat) or bool(body.get("hidden")): return false
	var lying = level.code.fallen.get(index)
	return is_instance_valid(lying) and body.global_position.distance_to(lying.global_position) <= USE_REACH + SLACK

## Applied on every machine: a thing let fall where the host says, or picked up.
func apply(action: String, index: int, seat: int, data: Dictionary, _quiet: bool) -> Dictionary:
	match action:
		"drop": level.code.let_fall(index, lay(index, data.get("at", Vector3.ZERO)))
		"pick":
			var lying = level.code.fallen.get(index)
			if not is_instance_valid(lying): return data
			var here: Vector3 = lying.get_meta("at")
			for thing in level.code.fallen.keys():
				var other = level.code.fallen[thing]
				if is_instance_valid(other) and (other.get_meta("at") as Vector3).distance_to(here) <= HEAP: level.code.picked(int(thing), seat)
	return data

## The host: whoever falls lets go of the keys and the slips they hold, round
## where they fell and on what is under them, told to everyone.
func on_death(seat: int, point: Vector3) -> void:
	if level.net.is_client(): return
	var things: Array = level.code.carried(seat)
	if things.is_empty(): return
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0.5, 0), point - Vector3(0, 2.0, 0), 1)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(ray)
	var ground: Vector3 = (hit.position as Vector3) + Vector3(0, 0.01, 0) if not hit.is_empty() else point
	for i in things.size():
		var at := ground + (Vector3(SPREAD, 0, 0).rotated(Vector3.UP, TAU * float(i) / float(things.size())) if things.size() > 1 else Vector3.ZERO)
		apply("drop", int(things[i]), seat, {"at": at}, false)
		level.match_net.tell_office(ID, "drop", int(things[i]), seat, {"at": at})

## And is on its feet again, with what it let fall.
func on_return(seat: int) -> void: level.code.give_back(seat)

## A thing lying where its holder fell: the key as it hangs from its drawer,
## bigger, or a slip as pale as the papers are (and, as them, with no light of
## its own: the torch picks it out); a usable to pick it up, its box wide
## enough for the brackets to come up on a look towards it.
func lay(thing: int, at: Vector3) -> Node3D:
	var usable := USABLE.new()
	usable.name = "Fallen_%d" % thing
	usable.level = level
	usable.handler = self
	usable.index = thing
	usable.action = "pick"
	usable.box = Vector3(0.7, 0.4, 0.7)
	usable.position = at - Vector3(0, 0, 0.35)
	usable.set_meta("at", at)
	level.hotel.add_child(usable)
	var shown := MeshInstance3D.new()
	if thing >= 0:
		shown.mesh = CONTAINER.KEY_MESH
		shown.scale = Vector3.ONE * KEY_SCALE
	else:
		var slip := BoxMesh.new()
		slip.size = SLIP
		shown.mesh = slip
		var paper := StandardMaterial3D.new()
		paper.albedo_color = Color(0.86, 0.8, 0.68)
		paper.roughness = 0.95
		shown.material_override = paper
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.position = Vector3(0, 0.004, 0.35)
	# Turned as it fell, the same on every machine.
	shown.rotation.y = fposmod(float(thing) * 2.4 + at.x * 7.0 + at.z * 3.0, TAU)
	usable.add_child(shown)
	lay_on_room(shown)
	return usable

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
