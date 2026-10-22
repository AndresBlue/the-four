extends SceneTree
## Every paper of the hotel as it is read, for the author (22 October 2026):
## the documents of the archive (the lore), held up as they are found; the
## hints of the third stage, all eight kinds, looked for over several floors
## until each has turned up; and the pages of the code, as they hang on the
## sheet and each one large. With a window:
##   godot --path . --script res://tools/capture/notes_capture.gd -- --test-profile --automation --silent [--seeds=81,777,202]
## Shots in evidence/notas_*.png, and what each is in evidence/notas_index.json.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const KINDS := ["limpieza", "orden", "indicaciones", "cartel", "calco", "plano", "tiza", "hoja"]
var level
var index: Array = []

func _initialize() -> void: run.call_deferred()

func shot(name: String, what: String, group: String, frames := 30) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/notas_%s.png" % name)
	index.append({"file": "notas_%s.png" % name, "what": what, "group": group})
	print("CAPTURE notas_%s.png  %s" % [name, what])

func settle() -> void:
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	level.settings.values.quality = 2
	for key in ["vhs", "grain", "chromatic", "scanlines"]: level.settings.values[key] = 0.0
	level.settings.values.reduced = true
	level.apply_settings()
	level.apply_lens(false, true)
	for key in ["vhs", "grain", "chromatic", "scanlines", "noise"]:
		if level.post_material.get_shader_parameter(key) != null: level.post_material.set_shader_parameter(key, 0.0)
	# What the camcorder writes over the picture is not part of a paper.
	for child in level.camcorder.get_children():
		if child is CanvasItem: child.visible = false
	# Read in the reception, its lamps behind the paper.
	var lobby: Dictionary = level.manifest.rooms[int(level.manifest.entries[0])]
	var stand := FLOOR.position_of(lobby)
	level.player.position = stand
	level.player.rotation = Vector3(0, PI * 0.5, 0)
	level.player.camera.rotation = Vector3.ZERO
	level.hotel.update_visibility(level.player.position, true)
	for i in 120: await process_frame

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var seeds := [81, 777, 202, 4242, 9001]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seen := {}
	for seed_value in seeds:
		await level.start_floor(seed_value)
		await settle()
		if seen.is_empty():
			await lore()
			await pages()
		for hint in level.code.hints:
			var kind := String(hint.kind)
			if seen.has(kind): continue
			seen[kind] = true
			level.ui.show_hint(hint, level.code.hint_walls())
			await shot("ayuda_" + kind, kind, "ayuda")
			level.ui.hide_document()
		if KINDS.all(func(kind): return seen.has(kind)): break
	var file := FileAccess.open("res://evidence/notas_index.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(index, "\t"))
	print("NOTES ", index.size(), " shots, kinds ", seen.keys())
	quit()

## The documents of the archive, held up as they are read.
func lore() -> void:
	for item in CATALOG.for_creature("locust"):
		level.ui.show_document(item)
		await shot("lore_" + String(item.id).trim_prefix("locust_"), String(item.title), "lore")
		level.ui.hide_document()

## The pages of the code: each one large, as the sheet draws it, and all four
## hanging on the sheet with the room each came out of.
func pages() -> void:
	var code: Array = DIGITS.code(level.manifest)
	var board := ColorRect.new()
	board.color = Color(0.07, 0.06, 0.05)
	board.size = root.get_visible_rect().size
	level.ui.add_child(board)
	var grow := minf(board.size.y * 0.7 / level.ui.sheet.LEAF.y, (board.size.x - 100.0) / 4.0 / level.ui.sheet.LEAF.x)
	for place in range(1, DIGITS.COUNT + 1):
		var leaf: Control = level.ui.sheet.leaf(int(code[place - 1]), place)
		leaf.scale = Vector2.ONE * grow
		leaf.position = Vector2(20.0 + (place - 1) * (board.size.x - 40.0) / 4.0 + ((board.size.x - 40.0) / 4.0 - level.ui.sheet.LEAF.x * grow) * 0.5, (board.size.y - level.ui.sheet.LEAF.y * grow) * 0.5)
		board.add_child(leaf)
	await shot("codigo_paginas", "Las cuatro páginas del código", "codigo")
	board.queue_free()
	for slot in range(1, DIGITS.COUNT + 1):
		level.found_digits[slot] = int(code[slot - 1])
		level.found_by[slot] = level.player.slot
		level.found_where[slot] = "HABITACIÓN %d" % (300 + slot * 7)
	level.toggle_sheet()
	for i in 90: await process_frame
	await shot("codigo_en_la_hoja", "Las páginas en la hoja", "codigo")
	level.toggle_sheet()
	level.found_digits.clear()
	level.found_by.clear()
	level.found_where.clear()
	for i in 10: await process_frame
