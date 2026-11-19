extends SceneTree
## What the end of a floor leaves behind (the author's two reports of 19
## November 2026).
##
## The snow on the sound: lost or won, it is heard a few seconds more and then
## fades, on the report and on whatever follows it. It used to go on through
## the report and the menu after it, until the next floor began.
##
## The torch: one the creature of a floor had put out is its owner's again
## when the next floor starts. It used to stay dark on its owner's own screen,
## lit for everybody else, until a creature put it out again and gave it back.
##
## A floor is lost here by being caught on it and won by taking its last car,
## as in a game; the sound is on (the level is told so) with the master bus
## muted, since the lift's hiss is only played where there is sound.
const SEED := 81
## The names of the players that are snow: the dead channel, the lift's hiss
## and the hiss of a camcorder lying on the floor.
const SNOW := ["DeadChannel", "RideHiss", "TapeHiss"]
## presentation_rig.OVER_HOLD + OVER_FADE, and a second over.
const SILENT_BY := 6.5
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, "" if passed or detail.is_empty() else "  [" + detail + "]")

func frames(count: int) -> void:
	for i in count: await physics_frame

func seconds(length: float) -> void:
	await frames(int(round(length * 60.0)))

## Every player under the level that is sounding now, by name.
func sounding() -> Array:
	var names: Array = []
	for node in level.find_children("*", "", true, false):
		if (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D) and node.playing: names.append(String(node.name))
	return names

func snow() -> Array:
	return sounding().filter(func(name): return name in SNOW)

func fresh_floor() -> void:
	await level.start_floor(SEED, false, [1], "pesadilla")
	level.ui.hide_transit()
	if is_instance_valid(level.director):
		level.director.queue_free()
		level.director = null
	level.locust.set_physics_process(false)
	level.locust.grace = 0.0
	level.world_audio.enabled = true
	await frames(3)

## The floor over, one way or the other: the snow there was is heard at
## first, gone by SILENT_BY, and not back in the menu.
func ends(title: String, state: int) -> void:
	var waited := 0.0
	while level.session.state != state and waited < 40.0:
		await frames(6)
		waited += 0.1
	check(title + ": el piso acaba", level.session.state == state, "tras %.1f s, estado %d" % [waited, level.session.state])
	await seconds(1.0)
	print("SOUNDING ", title, " +1 s: ", sounding())
	var heard: Array = snow()
	await seconds(SILENT_BY - 1.0)
	print("SOUNDING ", title, " +%.1f s: " % SILENT_BY, sounding())
	check(title + ": la estática calla a los pocos segundos", snow().is_empty(), "había %s, sigue %s" % [heard, snow()])
	level.on_action("main")
	await seconds(1.5)
	print("SOUNDING ", title, " en el menú: ", sounding())
	check(title + ": y no vuelve en el menú", snow().is_empty(), str(snow()))

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await frames(2)
	await fresh_floor()
	# Caught, with no stage given back in Pesadilla: the floor is lost.
	level.player.torch_dim = 0.0
	level.capture_survivor(level.player)
	await ends("Derrota", level.session.State.FAILED)
	await fresh_floor()
	check("La linterna que apagó la criatura de otro piso vuelve a su dueño al empezar uno", is_equal_approx(level.player.torch_dim, 1.0), str(level.player.torch_dim))
	# The last car.
	level.lifts.leave_floor()
	await ends("Victoria", level.session.State.WON)
	# In the menu while the snow is still up: it goes with the floor.
	await fresh_floor()
	level.lifts.leave_floor()
	await seconds(3.0)
	var riding: Array = snow()
	level.on_action("main")
	await seconds(0.5)
	check("Salir al menú con la estática puesta la corta", snow().is_empty(), "había %s, sigue %s" % [riding, snow()])
	print("FLOOR_END_SOUND_RESULT ", checks.size() - failed, "/", checks.size())
	quit(0 if failed == 0 else 1)
