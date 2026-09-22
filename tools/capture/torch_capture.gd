extends SceneTree
## The torch, on its own, in the four places it shows what it does wrong: down
## a corridor, up against a wall, up at a ceiling and across a big room. The
## floor's own lamps are out for all of them, so what is in the picture is the
## beam and nothing else.
##
## It is meant to be run on both renderers and compared: the beam is shaped by
## a projector texture (beam_pattern()), and the Compatibility renderer does
## not do projectors at all.
##
##   godot --path . --rendering-method gl_compatibility \
##       --script tools/capture/torch_capture.gd -- --automation --silent \
##       --prefix=compat --quality=0
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HOTEL_PLAYER := preload("res://game/player/hotel_player.gd")
var level
var prefix := "torch"

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.position = from
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation = Vector3(0, atan2(-flat.x, -flat.y), 0)
	level.player.camera.rotation = Vector3(atan2(at.y - from.y, flat.length()), 0, 0)
	level.player.snap_torch()

func shot(name: String) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s_%s.png" % [prefix, name])
	print("SHOT ", name)

func run() -> void:
	var quality := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -50, 0)
	level.settings.values.quality = quality
	level.apply_settings()
	# --set=bias:0.08,normal:1.5,atten:2.5,energy:7,angle:30,projector:0 tries
	# values on the torch without touching the game, to find them by looking.
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--set="): continue
		for pair in argument.trim_prefix("--set=").split(","):
			var parts := pair.split(":")
			if parts.size() != 2: continue
			var value := float(parts[1])
			match parts[0]:
				"bias": level.player.torch.shadow_bias = value
				"normal": level.player.torch.shadow_normal_bias = value
				"atten": level.player.torch.spot_angle_attenuation = value
				"energy":
					level.player.torch_energy = value
					level.player.torch.light_energy = value
				"angle": level.player.torch.spot_angle = value
				"range": level.player.torch.spot_range = value
				"size": level.player.torch.light_size = value
				"projector": level.player.torch.light_projector = null if value == 0.0 else HOTEL_PLAYER.beam_pattern()
		print("TORCH sesgo %.3f normal %.3f caída %.2f energía %.2f ángulo %.1f proyector %s" % [
			level.player.torch.shadow_bias, level.player.torch.shadow_normal_bias,
			level.player.torch.spot_angle_attenuation, level.player.torch_energy,
			level.player.torch.spot_angle, level.player.torch.light_projector != null])
	# Nothing but the torch: the floor's power is cut for all of these.
	level.hotel.blackout(true)
	level.player.torch.visible = true
	var corridor: Dictionary = {}
	var hall: Dictionary = {}
	for room in level.manifest.rooms:
		if corridor.is_empty() and int(room.type) in [11, 12]: corridor = room
		if hall.is_empty() and int(room.hall) == int(room.id) and int(room.hall) >= 0: hall = room
	var along := FLOOR.position_of(corridor)
	# Down the length of a corridor: the beam at its longest.
	await look(along + Vector3(0, 1.6, 5.0), along + Vector3(0, 1.4, -6.0))
	await shot("corridor")
	# Two metres from a wall, straight at it: the shape of the beam, whole.
	await look(along + Vector3(0, 1.6, 3.6), along + Vector3(0, 1.55, -1.5))
	await shot("wall")
	# Up at the ceiling from underneath, where a shadow's bias shows as bands.
	await look(along + Vector3(0, 1.6, 0), along + Vector3(0.6, 3.2, -1.2))
	await shot("ceiling")
	# And across a big room, where the beam has furthest to go.
	if not hall.is_empty():
		var wide := FLOOR.position_of(hall)
		var span := FLOOR.size_of(hall)
		await look(wide + Vector3(0, 1.6, span.y * 0.4), wide + Vector3(0, 1.3, -span.y * 0.5))
		await shot("hall")
		# Along one of its walls, close to it and nearly parallel: the wall ten
		# and fifteen metres off is lit at a grazing angle, which is where a
		# shadow with too little bias breaks into dark diagonal bands.
		await look(wide + Vector3(span.x * 0.5 - 1.0, 1.6, span.y * 0.45), wide + Vector3(span.x * 0.5 - 0.2, 1.4, -span.y * 0.45))
		await shot("graze")
	# Down a corridor that goes on into the room beyond it: the walls of the
	# far room, ten to twenty metres off, are where the bands were seen.
	var shots := 0
	for room in level.manifest.rooms:
		if shots >= 3 or not int(room.type) in [11, 12]: continue
		for other in level.manifest.adjacency[int(room.id)]:
			var here := FLOOR.position_of(room)
			var there := FLOOR.position_of(level.manifest.rooms[int(other)])
			var way := there - here
			if absf(way.x) > 0.5 and absf(way.z) > 0.5: continue
			var dir := way.normalized()
			await look(here - dir * 4.0 + Vector3(0, 1.6, 0), there + dir * 5.0 + Vector3(0, 1.3, 0))
			await shot("long_%d" % shots)
			shots += 1
			break
	level.queue_free()
	await process_frame
	quit()
