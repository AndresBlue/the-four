extends SceneTree
## Every paper of the hotel as it is read, for the author (22 October 2026):
## the documents of the archive (the lore), held up as they are found; the
## hints of the third stage, all eight kinds, looked for over several floors
## until each has turned up (the Polaroid with its picture taken, and it and
## the "do not disturb" card also where they are found); and the pages of the
## code, the torn letter put together large and as it hangs on the sheet.
## With a window:
##   godot --path . --script res://tools/capture/notes_capture.gd -- --test-profile --automation --silent [--seeds=81,777,202]
## Shots in evidence/notas_*.png, and what each is in evidence/notas_index.json.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const LETTER := preload("res://game/ui/torn_letter.gd")
const KINDS := ["limpieza", "orden", "indicaciones", "polaroid", "calco", "plano", "nomolestar", "hoja"]
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
			await in_furniture()
		for hint in level.code.hints:
			var kind := String(hint.kind)
			if seen.has(kind): continue
			seen[kind] = true
			if kind == "polaroid":
				level.code.develop_photo(hint)
				for i in 60:
					if hint.has("photo"): break
					await process_frame
			level.ui.show_hint(hint, level.code.hint_walls())
			await shot("ayuda_" + kind, kind, "ayuda")
			level.ui.hide_document()
			if kind == "nomolestar":
				var card = level.hotel.find_children("Card_*", "Area3D", true, false).filter(func(node): return not node.blank)
				if not card.is_empty(): await in_world(card[0], card[0].global_basis.z * 0.75 + Vector3.UP * 0.05, "mundo_nomolestar", "La tarjeta en su puerta")
			if kind == "polaroid":
				var lying = level.hotel.find_children("Hint_%d" % int(hint.id), "Area3D", true, false)
				if not lying.is_empty(): await in_world(lying[0], Vector3(0.25, 0.55, 0.3), "mundo_polaroid", "La Polaroid en su mesa")
		if KINDS.all(func(kind): return seen.has(kind)): break
	var file := FileAccess.open("res://evidence/notas_index.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(index, "\t"))
	print("NOTES ", index.size(), " shots, kinds ", seen.keys())
	quit()

## A thing as it is found: a camera of its own `from` it, looking at it, with
## its rooms shown round it.
func in_world(thing: Node3D, from: Vector3, name: String, what: String) -> void:
	await in_world_at(thing.global_position + Vector3.UP * 0.02, thing.global_position + from, name, what)

func in_world_at(target: Vector3, eye: Vector3, name: String, what: String, group := "ayuda") -> void:
	var camera := Camera3D.new()
	camera.fov = 50.0
	level.add_child(camera)
	camera.look_at_from_position(eye, target, Vector3.UP)
	camera.current = true
	level.hotel.update_visibility(camera.global_position, true)
	await shot(name, what, group, 60)
	camera.queue_free()
	level.player.camera.current = true
	level.hotel.update_visibility(level.player.position, true)
	for i in 20: await process_frame

## The pieces of the letter as they are found, showing out of their furniture:
## two kinds of piece at most.
func in_furniture() -> void:
	var kinds := {}
	for piece in level.containers:
		if piece.digit < 0 or kinds.has(String(piece.kind)) or kinds.size() >= 2 or not is_instance_valid(piece.note): continue
		kinds[String(piece.kind)] = true
		var at: Vector3 = piece.note.global_position
		var out := Vector3(piece.global_basis.z.x, 0.0, piece.global_basis.z.z).normalized()
		await in_world_at(at, at + out * 0.8 + Vector3.UP * 0.3, "mundo_trozo_" + String(piece.kind), "Un trozo en " + String(piece.kind), "codigo")

## The documents of the archive, held up as they are read.
func lore() -> void:
	for item in CATALOG.for_creature("locust"):
		level.ui.show_document(item)
		await shot("lore_" + String(item.id).trim_prefix("locust_"), String(item.title), "lore")
		level.ui.hide_document()

## The pages of the code: the four pieces of the torn letter, large, a little
## apart (as they are found), and put back together on the sheet with the
## room each came out of.
func pages() -> void:
	var code: Array = DIGITS.code(level.manifest)
	var board := ColorRect.new()
	board.color = Color(0.07, 0.06, 0.05)
	board.size = root.get_visible_rect().size
	level.ui.add_child(board)
	var full: Vector2 = LETTER.CARTA.get_size()
	var grow := board.size.y * 0.86 / full.y
	var origin := (board.size - full * grow) * 0.5
	board.draw.connect(func() -> void:
		for place in range(1, DIGITS.COUNT + 1):
			var box: Rect2 = LETTER.quarter(place)
			var apart := Vector2(-1.0 if (place - 1) % 2 == 0 else 1.0, -1.0 if place <= 2 else 1.0) * 26.0
			LETTER.draw_piece(board, place, Rect2(origin + box.position * grow + apart, box.size * grow), int(code[place - 1]), "HABITACIÓN %d" % (300 + place * 7), (float(place) - 2.5) * 0.03))
	board.queue_redraw()
	await shot("codigo_paginas", "Los cuatro trozos de la carta", "codigo")
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
