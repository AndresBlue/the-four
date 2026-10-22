extends "res://game/floors/objectives/objective.gd"
## The sets of the stage's wing, lit (game/app/televisions.gd, `level.tvs`):
## enough of them on opens the stage's door, the last one but one takes the
## wing's power, and the creature travels between the lit ones. What
## host_gate(), the lifts and the director asked of the sets, asked here; the
## sets, their RPCs and their state stay in televisions.gd.
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const NAME := "televisions"

## Which sets each stage asking for them is played on, and every other "tv"
## of the manifest built as its cabinet (tv_placement.settle()).
static func settle(manifest: Dictionary, survivors: int, kind: GDScript) -> Dictionary:
	return TV_PLACEMENT.settle(manifest, survivors, kind)

func place() -> void: level.tvs.place_televisions()

## A stage that asks for sets is played on its own wing's: each counts the
## ones standing in its wing and starts from nothing.
func progress(stage: int) -> Dictionary:
	if not level.kind.asks(stage, NAME): return idle()
	var sets: Array = level.tvs.stage_televisions(stage)
	if sets.is_empty(): return idle()
	var needed: int = TV_PLACEMENT.needed(level.session.roster_count)
	var done := 0
	for index in sets:
		if level.tvs.televisions[index].on: done += 1
	return {"ready": done >= needed, "done": done, "needed": needed, "kind": NAME, "lines": [["TELEVISORES", "%d / %d" % [done, needed]]], "extra": {"sets_done": done, "sets_needed": needed}}

## Its sets still dark.
func goal_points(stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for index in level.tvs.stage_televisions(stage):
		var set = level.tvs.televisions[index]
		if is_instance_valid(set) and not set.on: points.append(set.global_position)
	return points

## The creature's hop between lit sets, on any stage, as it always was. And
## where the stage asks for sets, their count kept in the goal and the
## blackout it trips, written before host_gate() reads the goal and in the
## order they always were: the goal is saved and sent as it stands.
func tick(delta: float) -> void:
	level.tvs.creature_channel_hop(delta)
	var session = level.session
	if not level.kind.asks(session.stage, NAME) or level.tvs.stage_televisions().is_empty(): return
	var needed: int = TV_PLACEMENT.needed(session.roster_count)
	var done: int = level.tvs.televisions_on()
	session.goal["sets_done"] = done
	session.goal["sets_needed"] = needed
	# With one set left to light, this wing loses its power and the
	# creature hunts without tiring. It is the wing's power, not the
	# floor's: the next one is found lit.
	# Not again once the floor's key has given it its lights back.
	if level.rule("blackout") == 1 and done >= needed - 1 and not session.goal.get("blackout", false) and not session.goal.get("restored", false):
		session.goal["blackout"] = true
		level.ledger.note_dark()
		session.changed.emit()

## The sets on, by their place in the floor's list (floor_save.gd's "sets").
func snapshot() -> Dictionary:
	return {"sets": level.tvs.televisions.map(func(set): return is_instance_valid(set) and set.on)}

func restore(data: Dictionary) -> void:
	var sets: Array = data.get("sets", [])
	for index in mini(sets.size(), level.tvs.televisions.size()):
		if bool(sets[index]): level.tvs.apply_television(index, true, true)
