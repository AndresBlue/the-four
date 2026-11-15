extends SceneTree
## The real plan (.claude/specs/planta_real.md 13) built as the game builds it:
## each seed's floor 2 started in a level of its own, and whether it came out
## of the generator (validator) and of the physics check or fell to the standby
## floor, with the physics' codes.
##   godot --headless --script tools/dev/office_plan_physics.gd -- 1 40 [--survivors=N] [--real-plan]
## Seeds from the first number to the second.
const PLAN := preload("res://tools/dev/office_plan.gd")
const GEN := preload("res://game/world/generation/office_generator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var numbers: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return String(a).is_valid_int()).map(func(a): return int(a))
	var first: int = numbers[0] if numbers.size() > 0 else 1
	var last: int = numbers[1] if numbers.size() > 1 else first + 9
	var survivors := 2
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--survivors="): survivors = int(String(argument).get_slice("=", 1))
	OFFICE.real_plan_test = OS.get_cmdline_user_args().has("--real-plan")
	OFFICE.columns_test = true
	var standby := 0
	var physical := 0
	var codes := {}
	for run_seed in range(first, last + 1):
		var level = load("res://game/app/hotel.tscn").instantiate()
		root.add_child(level)
		level.creature_scene = "none"
		await physics_frame
		var slots: Array = range(1, survivors + 1)
		# What the generator gives on its own (validator included), then the game's build of it.
		var drawn: Dictionary = GEN.new().generate(run_seed, survivors)
		var generated: bool = not bool(drawn.get("fallback", false))
		var errors: Array = []
		if generated:
			level.set_floor(2)
			level.manifest = drawn
			await level.mount_geometry("")
			for i in 2: await physics_frame
			errors = level.kind.VALIDATOR.new().validate_physics(level.get_world_3d(), drawn)
		if not generated: standby += 1
		if not errors.is_empty(): physical += 1
		for code in PLAN.codes(errors): codes[code] = int(codes.get(code, 0)) + 1
		print("PHYSICS semilla %d intento %d del generador %s errores físicos %s" % [run_seed, int(drawn.get("attempt", -1)), "sí" if generated else "no (reserva)", str(errors.slice(0, 6))])
		level.queue_free()
		for i in 2: await physics_frame
	print("PHYSICS semillas %d a %d: en la de reserva %d, con errores físicos %d, códigos %s" % [first, last, standby, physical, str(codes)])
	quit()
