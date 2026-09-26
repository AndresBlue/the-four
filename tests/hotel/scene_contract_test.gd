extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(label: String, result: bool) -> void:
	checks += 1
	print("PASS " if result else "FAIL ", label)
	if not result: failures.append(label)
func run() -> void:
	var packed := load("res://game/app/hotel.tscn") as PackedScene
	var a := packed.instantiate()
	var b := packed.instantiate()
	check("Composition contains named authoring nodes", a.has_node("Services/Settings") and a.has_node("Services/GameSession") and a.has_node("Player/Camera/Flashlight") and a.has_node("Interface/HUD/Subtitle"))
	var capsule_a: CapsuleShape3D = a.get_node("Player/BodyShape").shape
	var capsule_b: CapsuleShape3D = b.get_node("Player/BodyShape").shape
	capsule_a.height = 1.05
	check("Crouching does not mutate another player instance", is_equal_approx(capsule_b.height, 1.8))
	var env_a: Environment = a.get_node("Presentation/WorldEnvironment").environment
	var env_b: Environment = b.get_node("Presentation/WorldEnvironment").environment
	env_a.fog_density = 0.9
	check("Environment settings stay local to a scene", is_equal_approx(env_b.fog_density, (load("res://game/presentation/hotel_environment.tres") as Environment).fog_density))
	var fx_a: ShaderMaterial = a.get_node("Presentation/Analog/Screen").material
	var fx_b: ShaderMaterial = b.get_node("Presentation/Analog/Screen").material
	check("Postprocessing state is not shared", fx_a != fx_b)
	a.free()
	b.free()
	var scene := packed.instantiate()
	root.add_child(scene)
	check("Services are assigned before children are ready", scene.player.settings == scene.settings and scene.ui.settings == scene.settings)
	check("Presentation uses AgX tone mapping and colour ambient", scene.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and scene.environment.tonemap_mode == Environment.TONE_MAPPER_AGX)
	# The tape records what the camera saw and everything written over it:
	# the OSD first, the interface on top of that, and the analog filter
	# above both, so a menu is on the tape and not on the glass.
	check("The tape records the OSD and the interface alike", scene.get_node("Presentation/Camcorder").layer < scene.ui.layer and scene.ui.layer < scene.get_node("Presentation/Analog").layer)
	# And what is outside the game -- menus, the boot -- is above it, unfilmed.
	check("Menus sit above the tape, the floor's own screens under it", scene.ui.outside.layer > scene.get_node("Presentation/Analog").layer and scene.ui.overlay.get_parent() == scene.ui.outside and scene.ui.sheet.get_parent() == scene.ui)
	# A modifier key's release can be lost by the system; the next event that
	# says the key is up lets the action go, and one that says it is down
	# does not.
	Input.action_press("sprint")
	var held := InputEventMouseMotion.new()
	held.shift_pressed = true
	Input.parse_input_event(held)
	await process_frame
	var kept := Input.is_action_pressed("sprint")
	var loose := InputEventMouseMotion.new()
	loose.shift_pressed = false
	Input.parse_input_event(loose)
	await process_frame
	check("Running stays on while Shift is down and stops when the system says it is up", kept and not Input.is_action_pressed("sprint"))
	# The pad: the same actions a key does, on the sticks and buttons, and what
	# it refuses to bind.
	var pad_settings = scene.settings
	pad_settings.apply_bindings()
	var walking: Array = InputMap.action_get_events("forward")
	check("Andar es también el stick izquierdo", walking.any(func(event): return event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value < 0.0))
	check("Y mirar es el derecho, con su zona muerta", InputMap.has_action("look_right") and InputMap.action_get_events("look_right").any(func(event): return event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_X) and is_equal_approx(InputMap.action_get_deadzone("look_right"), pad_settings.STICK_DEADZONE))
	check("Interactuar es el botón de la izquierda y saltar el de abajo", InputMap.action_get_events("interact").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X) and InputMap.action_get_events("jump").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A))
	check("La hoja es el botón pequeño de la izquierda, y el panel táctil también", InputMap.action_get_events("sheet").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK) and InputMap.action_get_events("sheet").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_TOUCHPAD))
	check("Los botones se llaman como en cada mando", pad_settings.PAD_NAMES.playstation[JOY_BUTTON_X] == "CUADRADO" and pad_settings.PAD_NAMES.nintendo[JOY_BUTTON_A] == "B" and pad_settings.PAD_NAMES.xbox[JOY_BUTTON_Y] == "Y" and pad_settings.pad_family() == "xbox")
	# Running and crouching flip on a press, and running stops on its own once
	# the stick is let go.
	var feel = preload("res://game/player/pad_feel.gd").new()
	var click := InputEventJoypadButton.new()
	click.button_index = int(pad_settings.pad_bindings.sprint)
	click.pressed = true
	feel.pressed(click, pad_settings)
	var running_on: bool = feel.wants("sprint", pad_settings)
	feel.settle(true, false, 1.0)
	var kept_moving: bool = feel.wants("sprint", pad_settings)
	feel.settle(false, false, 0.5)
	check("Correr con el mando se enciende con un toque y se apaga al soltar el stick", running_on and kept_moving and not feel.wants("sprint", pad_settings))
	var duck := InputEventJoypadButton.new()
	duck.button_index = int(pad_settings.pad_bindings.crouch)
	duck.pressed = true
	feel.pressed(duck, pad_settings)
	var crouched_on: bool = feel.wants("crouch", pad_settings)
	feel.pressed(duck, pad_settings)
	check("Y agacharse se alterna", crouched_on and not feel.wants("crouch", pad_settings))
	pad_settings.values.pad_crouch_toggle = false
	feel.pressed(duck, pad_settings)
	check("Salvo si se pide mantenerlo", not feel.wants("crouch", pad_settings))
	pad_settings.values.pad_crouch_toggle = true
	check("Un botón se puede cambiar", pad_settings.bind_pad("interact", JOY_BUTTON_RIGHT_STICK) and int(pad_settings.pad_bindings.interact) == JOY_BUTTON_RIGHT_STICK and InputMap.action_get_events("interact").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_STICK))
	check("Pero no al de menú ni a uno que ya hace otra cosa", not pad_settings.bind_pad("interact", JOY_BUTTON_START) and not pad_settings.bind_pad("interact", int(pad_settings.pad_bindings.crouch)))
	# The menus have to be usable with a pad alone: this project's ui_accept
	# came with no pad button at all, so the cross moved the highlight and
	# nothing could be chosen.
	check("Elegir en los menús es el botón de abajo", InputMap.action_get_events("ui_accept").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A))
	check("Y salir de ellos, el de la derecha", InputMap.action_get_events("ui_cancel").any(func(event): return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B))
	check("El menú se recorre con la cruceta y con el stick", InputMap.action_get_events("ui_down").any(func(event): return event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and event.axis_value > 0.0))
	# And something has to be highlighted, or a pad has no way in.
	var unfocused: Array = []
	for kind in ["main", "multiplayer", "join", "credits", "archive", "records"]:
		scene.ui.menu(kind)
		await process_frame
		if scene.get_viewport().gui_get_focus_owner() == null: unfocused.append(kind)
	scene.ui.show_characters()
	await process_frame
	if scene.get_viewport().gui_get_focus_owner() == null: unfocused.append("characters")
	check("Y toda pantalla abre con algo marcado", unfocused.is_empty())
	# Settings: down walks every row of a page before "Volver" (Godot's own
	# search went to "Volver" from the last row the page showed), and the
	# shoulders change tab.
	scene.ui.show_settings("main")
	await process_frame
	var walk_ok := true
	var ui_node = scene.ui
	for rows in ui_node.settings_rows:
		for i in rows.size():
			var control: Control = rows[i][0]
			var below: Node = control.get_node_or_null(control.focus_neighbor_bottom)
			var wanted: Node = ui_node.buttons["back"] if i == rows.size() - 1 else rows[i + 1][0]
			if below != wanted: walk_ok = false
	check("En ajustes, bajar recorre todas las filas antes de Volver", walk_ok and ui_node.settings_rows.size() == ui_node.settings_tabs.get_tab_count() and ui_node.settings_rows.all(func(rows): return rows.size() > 2))
	var before_tab: int = ui_node.settings_tabs.current_tab
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await process_frame
	var after_tab: int = ui_node.settings_tabs.current_tab
	var marked: Control = scene.get_viewport().gui_get_focus_owner()
	check("R1 pasa a la pestaña siguiente con su primera fila marcada", after_tab == (before_tab + 1) % ui_node.settings_tabs.get_tab_count() and marked == ui_node.settings_rows[after_tab][0][0])
	var shoulder_up := InputEventJoypadButton.new()
	shoulder_up.button_index = JOY_BUTTON_RIGHT_SHOULDER
	Input.parse_input_event(shoulder_up)
	scene.ui.settings_open = false
	scene.ui.menu("main")
	await process_frame
	pad_settings.reset_controls()
	check("Y restaurar controles los devuelve todos", int(pad_settings.pad_bindings.interact) == JOY_BUTTON_X and int(pad_settings.bindings.forward) == KEY_W)
	# The board of tapes that got out: what goes in which table, in what order,
	# and how much is kept.
	var records := preload("res://game/services/records_service.gd").new()
	records.save_path = "user://test_records_contract.json"
	records.runs = []
	var quick := {"floor": 1, "company": records.SOLO, "players": 1, "time": 400.0, "deaths": 0, "hides": 0, "escaped": 1}
	var slow := {"floor": 1, "company": records.SOLO, "players": 1, "time": 900.0, "deaths": 0, "hides": 0, "escaped": 1}
	var hidden_run := {"floor": 1, "company": records.SOLO, "players": 1, "time": 200.0, "deaths": 0, "hides": 3, "escaped": 1}
	var lost := {"floor": 1, "company": records.COOP, "players": 3, "time": 300.0, "deaths": 2, "hides": 0, "escaped": 2}
	for line in [slow, quick, hidden_run, lost]: records.record(line)
	var fastest: Array = records.table_of("time", 1, records.SOLO)
	check("La tabla de tiempos va del más rápido al más lento", fastest.size() == 3 and is_equal_approx(float(fastest[0].time), 200.0) and is_equal_approx(float(fastest[2].time), 900.0))
	check("Acompañado es otro tablón", records.table_of("time", 1, records.COOP).size() == 1)
	check("Quien se escondió no sale en «sin esconderse»", records.table_of("brave", 1, records.SOLO).size() == 2)
	check("Ni quien perdió a alguien en «sin bajas»", records.table_of("clean", 1, records.COOP).is_empty() and records.table_of("clean", 1, records.SOLO).size() == 3)
	check("Y una cinta lleva sus distintivos", records.badges(quick).has("SIN BAJAS") and not records.badges(hidden_run).has("SIN ESCONDERSE"))
	var places: Dictionary = records.record({"floor": 1, "company": records.SOLO, "players": 1, "time": 100.0, "deaths": 0, "hides": 0, "escaped": 1})
	check("Una marca nueva sabe en qué puesto entró", int(places.get("time", 0)) == 1 and int(places.get("brave", 0)) == 1)
	for i in records.KEPT + 4: records.record({"floor": 1, "company": records.SOLO, "players": 1, "time": 1000.0 + i, "deaths": 0, "hides": 0, "escaped": 1})
	check("El tablón no crece sin fin", records.table_of("time", 1, records.SOLO).size() == records.KEPT)
	records.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_records_contract.json"))
	# The picture settings: what the player asks for over the preset, and how
	# the drawn picture is brought up to the window.
	var presets := preload("res://game/presentation/graphics_presets.gd")
	var forward: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	check("Native resolution is drawn straight, under it FSR 2.2 takes over", presets.scaling_mode({"upscaler": "auto", "scale": 1.0}) == Viewport.SCALING_3D_MODE_BILINEAR and presets.scaling_mode({"upscaler": "auto", "scale": 0.7}) == (Viewport.SCALING_3D_MODE_FSR2 if forward else Viewport.SCALING_3D_MODE_BILINEAR))
	check("And each upscaler can be asked for by name", presets.scaling_mode({"upscaler": "fsr1", "scale": 0.7}) == (Viewport.SCALING_3D_MODE_FSR if forward else Viewport.SCALING_3D_MODE_BILINEAR) and presets.scaling_mode({"upscaler": "bilinear", "scale": 0.7}) == Viewport.SCALING_3D_MODE_BILINEAR)
	var with_fsr2: Dictionary = presets.of(presets.ULTRA, {"upscaler": "fsr2", "scale": 0.7})
	check("FSR 2.2 is the smoothing: nothing else is drawn over it", not with_fsr2.taa and not with_fsr2.fxaa and not with_fsr2.smaa and with_fsr2.msaa == Viewport.MSAA_DISABLED)
	var smoothed: Dictionary = presets.of(presets.LOW, {"aa": "smaa"})
	check("A smoothing asked for by hand replaces the preset's", smoothed.smaa and not smoothed.fxaa and not smoothed.taa)
	var heavy: Dictionary = presets.of(presets.LOW, {"ao": 1, "fog": 1, "reflections": 1, "blur": 1})
	var light: Dictionary = presets.of(presets.ULTRA, {"ao": 0, "fog": 0, "reflections": 0, "blur": 0})
	check("The heavy effects can be switched on over a modest preset", heavy.ssao >= 0 and heavy.fog_size > 0 and heavy.ssr_steps > 0 and heavy.motion_blur > 0)
	check("And off over a generous one", light.ssao < 0 and light.ssil < 0 and light.fog_size == 0 and not light.floor_haze and light.ssr_steps == 0 and light.motion_blur == 0)
	check("Left alone, a preset is its own", presets.of(presets.HIGH).ssao == presets.PRESETS[presets.HIGH].ssao)
	# The window is the picture's, and the three modes are the three ways of
	# showing it; a value from a broken file falls back to the default.
	check("The window has its three modes and they survive a bad file", scene.settings.WINDOW_MODES.size() == 3 and scene.settings.sanitize("window_mode", 9) == 2 and scene.settings.sanitize("upscaler", "dlss") == "auto" and scene.settings.sanitize("aa", "nope") == "preset")
	scene.settings.values.scale = 0.7
	scene.settings.values.upscaler = "fsr2"
	scene.settings.apply()
	scene.apply_settings()
	check("Choosing it reaches the viewport and takes TAA with it", (root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 or not forward) and not root.use_taa and is_equal_approx(root.scaling_3d_scale, 0.7))
	Input.action_release("sprint")
	scene.queue_free()
	await process_frame
	var gallery: Node = load("res://tools/workbenches/module_gallery.tscn").instantiate()
	check("Gallery contains all twenty reference modules", gallery.get_node("Modules").get_child_count() == 20)
	check("Gallery contains no runtime generator", gallery.get_node("Modules").get_script() == null)
	var floors := gallery.find_children("Mesh_carpet_*", "MeshInstance3D", true, false)
	check("Saved gallery retains nondegenerate floor geometry", floors.size() > 0 and absf(floors[0].transform.basis.determinant()) > 1.0)
	gallery.free()
	# The bought character models carry face rigs the game never uses, most
	# of their weight. They are dropped as they are imported, by a script the
	# model's .import has to name: if a model is replaced or reimported and
	# the hook is lost, this is what turns red instead of the package quietly
	# growing by 50 MB.
	var hooked := true
	var shapes := 0
	for folder in DirAccess.get_directories_at("res://assets/players"):
		var model := "res://assets/players/%s/model.fbx" % folder
		if not FileAccess.file_exists(model): continue
		var settings := ConfigFile.new()
		if settings.load(model + ".import") != OK or String(settings.get_value("params", "import_script/path", "")) != "res://tools/import/strip_blend_shapes.gd": hooked = false
		var body: Node = load(model).instantiate()
		for mesh in body.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh != null: shapes += mesh.mesh.get_blend_shape_count()
		body.free()
	check("Every character model is imported without its unused face rig", hooked and shapes == 0)
	var file := FileAccess.open("res://evidence/scene_contracts.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}, "\t"))
	file.close()
	print("SCENE_CONTRACTS ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
