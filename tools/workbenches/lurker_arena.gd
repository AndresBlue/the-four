extends Node
## The Lurker's bench (docs/OFICINAS.md 15, phase 2): floor 2 of a fixed seed
## with her on it and her mind running, played with the game's own player, and
## what she is doing written over the picture: her state and prey, the
## warning's clock, her route, her duct, the lamps she drinks. Keys (with
## Shift) force her states, put her behind you, switch your room's light and
## her mind. Run with the test profile: nothing of the real one is read or
## written (./tools/godot.ps1 lurker-arena).
const SEED := 7
const DIFFICULTY_ID := "equilibrada"
## Shift + the key: what it does.
const KEYS := {KEY_1: "rondar", KEY_2: "acechar", KEY_3: "acercarse", KEY_4: "huir", KEY_5: "escuchar", KEY_6: "detrás de ti", KEY_7: "luz de tu sala", KEY_8: "su mente"}
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var lurker
var label: Label

func _ready() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	get_tree().root.add_child.call_deferred(level)
	await get_tree().process_frame
	await get_tree().process_frame
	level.creature_scene = "lurker"
	level.set_floor(2)
	await level.start_floor(SEED, false, [1], DIFFICULTY_ID)
	lurker = level.creature
	lurker.grace = 0.0
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)

func _process(_delta: float) -> void:
	if label == null or not is_instance_valid(lurker) or lurker.brain == null: return
	var brain = lurker.brain
	var motion = lurker.motion
	var lines: PackedStringArray = []
	lines.append("THE LURKER  %s  (%s)%s" % [brain.state_name(), String(lurker.activity()), "" if lurker.thinking else "  mente apagada"])
	lines.append("presa %s, gracia %.1f s" % [str(brain.prey) if brain.prey >= 0 else "ninguna", lurker.grace])
	var active: Dictionary = lurker.warning.active
	if not active.is_empty():
		lines.append("AVISO %.2f de %.2f s" % [brain.clock - float(active.at), float(active.due) - float(active.at)])
	elif not lurker.warning.ledger.is_empty():
		var last: Dictionary = lurker.warning.ledger[lurker.warning.ledger.size() - 1]
		lines.append("último aviso: %s %s" % [String(last.outcome), String(last.reason)])
	var leg := String(motion.legs[0].kind) if not motion.legs.is_empty() else "parada"
	lines.append("ruta %s, %s, quedan %d tramos" % [String(motion.route_state()), leg, motion.legs.size()])
	lines.append(("en ducto, nodo %d%s" % [motion.near_node, ", oculta" if motion.hidden else ""]) if motion.in_duct else "sala %d" % motion.room())
	lines.append("bebe la luz de %d salas" % lurker.drained.size())
	var keys: PackedStringArray = []
	for key in KEYS: keys.append("Mayús+%s %s" % [OS.get_keycode_string(key), KEYS[key]])
	lines.append(", ".join(keys))
	label.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not event.shift_pressed: return
	if not is_instance_valid(lurker) or lurker.brain == null: return
	var seat := int(level.player.slot)
	match (event as InputEventKey).keycode:
		KEY_1: lurker.brain.force(&"roam")
		KEY_2: lurker.brain.force(&"stalk", {"seat": seat})
		KEY_3: lurker.brain.force(&"creep", {"seat": seat})
		KEY_4: lurker.brain.force(&"flee")
		KEY_5: lurker.brain.force(&"listen")
		KEY_6:
			# Over the ceiling 2.4 m behind you, closing in.
			var camera: Camera3D = level.player.camera
			var back := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
			lurker.place_over(level.player.global_position + back * 2.4, camera.global_position)
			lurker.brain.spurned.erase(seat)
			lurker.brain.sated_until = -INF
			lurker.brain.force(&"creep", {"seat": seat})
		KEY_7:
			var room := int(FLOOR.room_at(level.manifest.rooms, level.player.global_position).get("id", -1))
			if room >= 0: level.hotel.set_room_power(room, not level.hotel.lit(room))
		KEY_8: lurker.thinking = not lurker.thinking
