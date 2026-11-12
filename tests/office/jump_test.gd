extends SceneTree
## Saltar.cmd (hotel_main.jump_to, lifts.skip_stage()): a floor played with a
## sector asked for is ridden to it, one ride at a time, and stops there; a
## skip more leaves the survivor in the next sector's wing.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

## Physics frames until `done` says so, or `most` of them.
func until(done: Callable, most := 1800) -> void:
	for frame in most:
		if done.call(): return
		await physics_frame

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	level.set_floor(2)
	level.jump_to = 3
	await level.start_floor(7, false, [1], "apacible")
	check("El piso 2 tiene al menos tres sectores", level.session.stages >= 3, str(level.session.stages))
	await until(func(): return level.jump_to == 0)
	check("Pedido el sector 3, se llega al 3 y se deja de saltar", level.session.stage == 3 and level.jump_to == 0, "%d, %d" % [level.session.stage, level.jump_to])
	await until(func(): return level.jump_ready())
	var wing := int(FLOOR.room_at(level.manifest.rooms, level.player.global_position).get("wing", -1))
	check("El superviviente esta en la planta del sector 3", wing == 2, str(wing))
	print("JUMP_TEST_RESULT %d fallos" % failed)
	quit(1 if failed > 0 else 0)
