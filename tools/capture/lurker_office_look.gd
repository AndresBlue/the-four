extends SceneTree
## The Lurker on floor 2 as it is played, to be looked at (the visual pass of
## spec_lurker_rebuild): the player's camera with the camcorder over it, her
## mind off and her motion driven from here. Over a ceiling with the torch at
## 6 and 3 m, out of a ceiling tile and out of a grille, in a dark room with no
## torch and across a lit one, her ink near and far, scared and fleeing. JPGs
## in evidence/lurker_look/<phase>/.
##   godot --path . --rendering-method forward_plus --fixed-fps 30 --script res://tools/capture/lurker_office_look.gd -- --automation --test-profile --silent [--phase=antes]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SEED := 7
## Her pace seen (lurker_brain.CRAWL_SPEED) and fleeing (FLEE_SPEED).
const SEEN_PACE := 1.35
const FLEE_PACE := 3.5
const EYE := 1.6
const CEILING_DUST := preload("res://game/enemies/lurker/ceiling_dust.gd")
var level
var lurker
var out_dir := "res://evidence/lurker_look/antes"
## --shots=v4: only the bolt, the sequences and the dust (the third pass).
var shots := ""
## --trace: a line a frame of her bolt, and only the bolts.
var trace := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): out_dir = "res://evidence/lurker_look/" + argument.trim_prefix("--phase=")
		if argument.begins_with("--shots="): shots = argument.trim_prefix("--shots=")
		if argument == "--trace": trace = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	level.ui.finish_intro()
	level.creature_scene = "lurker"
	level.set_floor(2)
	await level.start_floor(SEED, false, [1], "equilibrada")
	lurker = level.creature
	lurker.thinking = false
	lurker.grace = 0.0
	level.player.set_physics_process(false)
	level.player.set_process(false)
	level.player.set_process_input(false)
	level.player.set_process_unhandled_input(false)
	level.ui.visible = false
	var big := pick(func(r: Dictionary) -> bool: return OFFICE.false_ceiling(r))
	var tiled := pick(func(r: Dictionary) -> bool: return OFFICE.false_ceiling(r) and lurker.ducts.room_tiles.has(int(r.id)) and int(r.id) != int(big.get("id", -1)))
	var other := pick(func(r: Dictionary) -> bool: return int(r.id) != int(big.get("id", -1)) and int(r.id) != int(tiled.get("id", -1)))
	if big.is_empty() or tiled.is_empty() or other.is_empty():
		print("LOOK no rooms")
		quit(1)
		return
	print("LOOK rooms %d %d %d" % [int(big.id), int(tiled.id), int(other.id)])
	power(int(big.id), false)
	if shots == "dustgame":
		await dust_tile(tiled, false)
		await dust_plenum(tiled)
		level.queue_free()
		await process_frame
		quit()
		return
	if shots == "lab3":
		await dust_lab3(tiled)
		level.queue_free()
		await process_frame
		quit()
		return
	if shots == "dust":
		await dust_lab(tiled)
		level.queue_free()
		await process_frame
		quit()
		return
	if shots == "v4":
		await v4(big, tiled)
		level.queue_free()
		await process_frame
		quit()
		return
	# Over a ceiling, the torch on, across at 6 m and at 3 m.
	await across(big, 6.0, true, "techo_6m")
	await across(big, 3.0, true, "techo_3m")
	# Her way of going while watched, 2 s of it.
	await across(big, 4.0, true, "rafaga", 20)
	# In the dark with no torch at 4 m.
	await across(big, 4.0, false, "oscura_4m")
	# Out of a ceiling tile, and out of a grille.
	await out_of_tile(tiled)
	await out_of_grille()
	# Across a lit room.
	power(int(other.id), true)
	await across(other, 5.0, false, "luz")
	# Her ink near and far, the torch on.
	await ink(big)
	# Still on the ceiling 3 m off, staring: her tics.
	await still(big)
	# Scared, then fleeing.
	await scared(big)
	level.queue_free()
	await process_frame
	quit()

## The biggest room of planta 1 with a ceiling for her that `test` takes.
func pick(test: Callable, least := 5.0) -> Dictionary:
	var best := {}
	var area := 0.0
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or not lurker.shell.tray_of.has(id) or OFFICE.off_limits(room) or not test.call(room): continue
		var span: Vector2 = FLOOR.size_of(room)
		if minf(span.x, span.y) < least: continue
		if span.x * span.y > area:
			area = span.x * span.y
			best = room
	return best

func power(room: int, on: bool) -> void:
	if bool(level.hotel.lit(room)) != on: level.hotel.set_room_power(room, on)

## The room's centre on its floor, its long axis and its short one.
func frame_of(room: Dictionary) -> Array:
	var span: Vector2 = FLOOR.size_of(room)
	var centre := Vector3(float(room.px), float(room.get("py", 0.0)), float(room.pz))
	var along := Vector3.RIGHT if span.x >= span.y else Vector3.BACK
	var side := Vector3.BACK if span.x >= span.y else Vector3.RIGHT
	return [centre, along, side, maxf(span.x, span.y), minf(span.x, span.y)]

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())
	level.player.snap_torch()
	level.hotel.update_visibility(level.player.global_position, true)

func torch(on: bool) -> void:
	level.player.torch.visible = on
	level.player.snap_torch()

func save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out_dir + "/" + name + ".jpg", 0.88)

## `count` pictures, one every `every` frames (at 30 a second).
func film(name: String, count: int, every: int) -> void:
	for k in count:
		for i in every: await process_frame
		await save("%s_%02d" % [name, k])

func wait(seconds: float) -> void:
	for i in int(seconds * 30.0): await process_frame

## She crosses the room's ceiling `metres` in front of the eye, across its
## short side; four pictures 0.1 s apart once she is under way.
func across(room: Dictionary, metres: float, lamp: bool, name: String, count := 4, every := 3) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	var side: Vector3 = f[2]
	var half_long: float = float(f[3]) * 0.5
	var half_short: float = float(f[4]) * 0.5
	var eye := centre - along * minf(half_long - 0.6, metres * 0.5) + Vector3.UP * EYE
	var line := eye + along * metres
	var start := Vector3(line.x, centre.y, line.z) - side * (half_short - 0.8)
	var finish := Vector3(line.x, centre.y, line.z) + side * (half_short - 0.8)
	lurker.place_over(start, finish)
	torch(lamp)
	look(eye, Vector3(line.x, centre.y + 2.2, line.z))
	await wait(0.5)
	lurker.motion.go_to(finish, SEEN_PACE, true)
	# Under way and some way in: a third of the crossing.
	await wait(minf(1.2, (half_short - 0.8) * 0.66 / SEEN_PACE + 0.4) if count <= 4 else 0.3)
	look(eye, lurker.global_position)
	await film(name, count, every)
	print("LOOK ", name, " at %.1f m" % Vector2(lurker.global_position.x - eye.x, lurker.global_position.z - eye.z).length())

func out_of_tile(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	var goal := centre + along * 1.0
	var eye := centre - along * 2.0 + Vector3.UP * EYE
	torch(true)
	var node: int = int(lurker.ducts.plenum_node[int(room.id)])
	lurker.motion.place_in_duct(node)
	lurker.apply_motion()
	look(eye, goal + Vector3.UP * 2.4)
	await wait(0.5)
	lurker.motion.go_to(goal, SEEN_PACE)
	await film("placa", 24, 3)

func out_of_grille(name := "rejilla", count := 24, every := 3) -> void:
	var exit := -1
	for e in lurker.ducts.exits.size():
		var ex: Dictionary = lurker.ducts.exits[e]
		var r: int = int(ex.room)
		if String(ex.kind) == "ceiling" and lurker.shell.tray_of.has(r) and int(level.manifest.rooms[r].get("wing", -1)) == 0:
			exit = e
			break
	if exit < 0:
		print("LOOK no grille")
		return
	var at: Vector3 = lurker.ducts.exits[exit].position
	var room: Dictionary = level.manifest.rooms[int(lurker.ducts.exits[exit].room)]
	var floor_y := float(room.get("py", 0.0))
	var to_centre := Vector3(float(room.px) - at.x, 0, float(room.pz) - at.z)
	var away := to_centre.normalized() if to_centre.length() > 0.5 else Vector3.RIGHT
	power(int(room.id), false)
	torch(true)
	lurker.place_in_exit(exit)
	look(Vector3(at.x, floor_y + EYE, at.z) + away * 3.0, at)
	await wait(0.5)
	lurker.motion.go_to(Vector3(at.x, floor_y, at.z) + away * 1.5, SEEN_PACE)
	await film(name, count, every)

func ink(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	torch(true)
	var eye := centre + Vector3.UP * EYE
	lurker.place_over(centre + along * 1.0, eye)
	look(eye, lurker.global_position)
	await wait(1.0)
	await save("tinta_cerca")
	var far := centre - along * (float(f[3]) * 0.5 - 0.6) + Vector3.UP * EYE
	look(far, lurker.global_position)
	await wait(1.0)
	await save("tinta_lejos")

func still(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	torch(true)
	var eye := centre - along * 1.5 + Vector3.UP * EYE
	lurker.place_over(centre + along * 1.3, eye)
	look(eye, lurker.global_position)
	await wait(0.5)
	await film("quieta", 20, 3)

func scared(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	torch(true)
	var eye := centre - along * 1.5 + Vector3.UP * EYE
	lurker.place_over(centre + along * 1.5, eye)
	look(eye, lurker.global_position)
	await wait(0.5)
	lurker.apply_intent({"do": &"hold", "clip": "scare", "look": level.player.camera.global_position})
	await film("espanto", 8, 3)
	var away := centre + along * (float(f[3]) * 0.5 - 0.8)
	lurker.apply_intent({"do": &"go", "to": away, "speed": FLEE_PACE, "clip": "crawl_fast"})
	await film("huida", 8, 3)

# --- The third pass (v4): her bolt measured, sequences, the dust --------------------------

func v4(big: Dictionary, tiled: Dictionary) -> void:
	# Her bolt, lit at 4 m: under a false ceiling, under one with no tiles,
	# in the middle of a corridor.
	var bare := pick(func(r: Dictionary) -> bool: return not OFFICE.false_ceiling(r), 3.0)
	var hall := corridor()
	for site in [["placa", big], ["sin_placa", bare], ["pasillo", hall]]:
		if (site[1] as Dictionary).is_empty():
			print("LOOK huida %s: no room" % site[0])
			continue
		await bolt_shot(site[1], String(site[0]))
	lurker.thinking = false
	if trace: return
	# Sequences: along a ceiling, from the ceiling down a wall, across a door
	# head, and still.
	await across(big, 3.5, true, "seq_techo", 30, 1)
	await wall_down()
	await door_cross()
	await still(big)
	# The dust: a tile opening with the torch and with the room's light, her
	# crawling the plenum over the eye, a grille.
	await dust_tile(tiled, false)
	power(int(tiled.id), true)
	await dust_tile(tiled, true)
	power(int(tiled.id), false)
	await dust_plenum(tiled)
	await out_of_grille("polvo_rejilla", 10, 2)

## The longest narrow room of planta 1 with a ceiling for her.
func corridor() -> Dictionary:
	var best := {}
	var length := 0.0
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or not lurker.shell.tray_of.has(id) or OFFICE.off_limits(room): continue
		var span: Vector2 = FLOOR.size_of(room)
		if minf(span.x, span.y) > 3.0 or maxf(span.x, span.y) < 7.0: continue
		if maxf(span.x, span.y) > length:
			length = maxf(span.x, span.y)
			best = room
	return best

## Whether the eye sees her: shown, in the picture and nothing solid between.
func seen() -> bool:
	if not lurker.visual.visible: return false
	var camera: Camera3D = level.player.camera
	var at: Vector3 = lurker.visual.global_position
	if not camera.is_position_in_frustum(at): return false
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, at, 1)
	return space.intersect_ray(query).is_empty()

## On the ceiling 4 m off, her mind on and after the eye; the torch on her
## face; the frames (30 a second) until she is out of sight.
func bolt_shot(room: Dictionary, name: String) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	var half_long: float = float(f[3]) * 0.5
	var eye := centre - along * minf(half_long - 0.5, 2.0) + Vector3.UP * EYE
	power(int(room.id), false)
	torch(false)
	lurker.place_over(eye + along * 4.0 - Vector3.UP * EYE, eye)
	look(eye, lurker.face_point())
	var seat := int(level.player.slot)
	lurker.thinking = true
	lurker.brain.spurned.erase(seat)
	lurker.brain.sated_until = -INF
	# A torch she drank earlier frightens her no more (iteration 2): a fresh one.
	if "drunk" in lurker: lurker.drunk.clear()
	lurker.brain.force(&"stalk", {"seat": seat})
	await wait(0.2)
	look(eye, lurker.face_point())
	torch(true)
	var frames := 0
	while frames < 60 and seen():
		# The torch kept on her face, as whoever lit her would.
		look(eye, lurker.face_point())
		await process_frame
		frames += 1
		if frames <= 14:
			await save("huida_%s_%02d" % [name, frames])
		if trace: print("LOOK  %d %s bolt=%s v=%.1f legs=%d duct=%s %s" % [frames, lurker.brain.state_name(), str(lurker.motion.bolting), lurker.motion.speed, lurker.motion.legs.size(), str(lurker.motion.in_duct), String(lurker.motion.legs[0].kind) if not lurker.motion.legs.is_empty() else "-"])
	print("LOOK huida %s: %d frames (%.2f s), %s" % [name, frames, frames / 30.0, "dentro" if lurker.motion.in_duct else "fuera"])
	lurker.thinking = false
	torch(false)
	await wait(0.5)

## From her ceiling down a wall to a grille in it.
func wall_down() -> void:
	var exit := -1
	for e in lurker.ducts.exits.size():
		var ex: Dictionary = lurker.ducts.exits[e]
		if String(ex.kind) == "wall" and lurker.shell.tray_of.has(int(ex.room)) and int(level.manifest.rooms[int(ex.room)].get("wing", -1)) == 0:
			exit = e
			break
	if exit < 0:
		print("LOOK no wall grille")
		return
	var ex: Dictionary = lurker.ducts.exits[exit]
	var room: Dictionary = level.manifest.rooms[int(ex.room)]
	var at: Vector3 = ex.position
	var inward := Vector3(float(room.px) - at.x, 0, float(room.pz) - at.z).normalized()
	power(int(room.id), false)
	torch(true)
	var start := Vector3(at.x, float(room.get("py", 0.0)), at.z) + inward * 2.2
	lurker.place_over(start, at)
	var eye := Vector3(at.x, float(room.get("py", 0.0)) + EYE, at.z) + inward * 3.2 + Vector3(inward.z, 0, -inward.x) * 1.4
	look(eye, at + Vector3.UP * 0.6)
	await wait(0.3)
	lurker.motion.go_to_exit(exit, SEEN_PACE)
	await film("seq_pared", 30, 2)

## Across a door head into the next room.
func door_cross() -> void:
	for pair in lurker.shell.band_of_pair:
		var a: int = pair.x
		var b: int = pair.y
		if int(level.manifest.rooms[a].get("wing", -1)) != 0 or not lurker.routes.door_open(pair): continue
		var band: int = lurker.shell.band_of_pair[pair]
		var record: Dictionary = lurker.shell.patches[band]
		var door: Vector3 = record.origin
		var across_v: Vector3 = record.across
		power(a, false)
		power(b, false)
		torch(true)
		lurker.place_over(door - across_v * 2.0, door)
		var eye := door - across_v * 3.0 + Vector3(across_v.z, 0, -across_v.x) * 1.6 + Vector3.UP * EYE
		look(eye, door + Vector3.UP * 2.4)
		await wait(0.3)
		lurker.motion.go_to(door + across_v * 2.0, SEEN_PACE, true)
		await film("seq_dintel", 30, 2)
		return
	print("LOOK no open door")

func dust_tile(room: Dictionary, lit: bool) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	var goal := centre + along * 1.0
	var eye := centre - along * 1.6 + Vector3.UP * EYE
	torch(not lit)
	lurker.motion.place_in_duct(int(lurker.ducts.plenum_node[int(room.id)]))
	lurker.apply_motion()
	look(eye, goal + Vector3.UP * 2.3)
	await wait(0.4)
	lurker.motion.go_to(goal, SEEN_PACE)
	# The tile goes as she starts down through it: wait for that, then ten.
	var waited := 0
	while waited < 90 and lurker.motion.in_duct:
		await process_frame
		waited += 1
	await film("polvo_placa_%s" % ("luz" if lit else "linterna"), 10, 2)

## Her in the plenum crossing over the eye: threads down the joints.
func dust_plenum(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	torch(true)
	var eye := centre + Vector3.UP * EYE
	look(eye, centre + along * 1.2 + Vector3.UP * 2.6)
	# Her weight over the tiles there, as her steps shake it down.
	var ceiling: float = float(lurker.ducts.tile_height.get(int(room.id), float(room.get("py", 0.0)) + 2.6))
	for k in 3:
		CEILING_DUST.seep(level, Vector3(centre.x, ceiling, centre.z) + along * (0.6 + 0.6 * k), ceiling)
		await wait(0.25)
	await film("polvo_pleno", 10, 2)

## The dust alone, away from her, as the author would see it: a fall 2.5 m
## off at eye height, by the torch alone, by the room's light alone, by both;
## eight pictures 0.13 s apart from the moment it falls, then four 1.5 s apart
## (the veil hanging).
func dust_lab(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	var side: Vector3 = Vector3(along.z, 0, -along.x)
	# Her far away, in a duct, drinking no light here.
	var far := 0
	for n in lurker.ducts.nodes.size():
		if (lurker.ducts.nodes[n] as Vector3).distance_to(centre) > (lurker.ducts.nodes[far] as Vector3).distance_to(centre): far = n
	lurker.motion.place_in_duct(far)
	lurker.apply_motion()
	var ceiling: float = float(lurker.ducts.tile_height.get(int(room.id), float(room.get("py", 0.0)) + 2.6))
	print("LOOK volumetric fog %s lamp_fog %s fog_size %s" % [level.environment.volumetric_fog_enabled, level.hotel.preset.get("lamp_fog"), level.hotel.preset.get("fog_size")])
	var cases := [["linterna", true, false], ["sala", false, true], ["ambas", true, true]]
	for i in cases.size():
		var at := Vector3(centre.x, ceiling, centre.z) + along * 1.2 + side * (float(i) - 1.0) * 0.6
		var eye := Vector3(at.x, float(room.get("py", 0.0)) + EYE, at.z) - along * 2.5
		torch(bool(cases[i][1]))
		# The room's own lamp (a dark room's stays out by power alone).
		var lamp: OmniLight3D = level.hotel.lights[int(room.id)]
		lamp.visible = bool(cases[i][2])
		if lamp.visible: lamp.remove_meta("off")
		look(eye, at + Vector3.DOWN * 0.7)
		await wait(1.0)
		CEILING_DUST.fall(level, at, true)
		await film("banco_%s" % cases[i][0], 8, 4)
		await film("banco_%s_tarde" % cases[i][0], 4, 45)
		await wait(4.0)
	power(int(room.id), false)

## Four emitters of the dust shader side by side, steady: [size, min_pixels].
func dust_lab3(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	lurker.motion.place_in_duct(0)
	lurker.apply_motion()
	power(int(room.id), false)
	torch(true)
	var ceiling: float = float(lurker.ducts.tile_height.get(int(room.id), float(room.get("py", 0.0)) + 2.6))
	var at := Vector3(centre.x, ceiling - 0.6, centre.z) + along * 1.5
	var eye := centre - along * 1.0 + Vector3.UP * EYE
	look(eye, at + Vector3.DOWN * 0.3)
	var side: Vector3 = Vector3(along.z, 0, -along.x)
	var cases := [[0.05, 0.0], [0.01, 0.0], [0.003, 0.0], [0.003, 3.0]]
	for i in cases.size():
		var p := ParticleProcessMaterial.new()
		p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.1, 0.1, 0.1)
		p.gravity = Vector3(0, -0.1, 0)
		p.scale_min = float(cases[i][0])
		p.scale_max = float(cases[i][0])
		p.color = Color(1, 1, 1, 1)
		CEILING_DUST.emitter(level, at + side * (0.9 - 0.6 * i), p, null, true, 40, 4.0, false, 0.0, {"scatter": 1.0, "min_pixels": float(cases[i][1]), "twinkle": 0.0})
	await wait(1.0)
	await film("lab3", 1, 3)
