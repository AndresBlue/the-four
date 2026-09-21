extends SceneTree
## A rehearsal for The Locust's acoustic view: you drive the creature and three
## survivors walk the floor on their own, making the noises they would make.
## Nothing is connected; it is the local hunter preview with company, so the
## view can be judged with something actually happening in it.
##
##   ./tools/godot.ps1 rehearsal -Seed 81
##
## The survivors are the same remote_player bodies an online match builds, so
## their footsteps go through the real routing, their poses feed the silhouette
## sampling, and the creature sees and hears them exactly as it would in a
## versus match. They walk, run, crouch, open doors and jump, and every so
## often one of them walks to a free wardrobe, gets in and comes out later.
##
## Controls are the hunter's own: mouse to look, WASD to move, Shift to hunt,
## left button to strike, right button to shriek, E for doors and wardrobes.
## A survivor struck down is executed, dies and walks again six seconds later
## somewhere else. Nothing about it is written on screen (the console logs it).
## With "-- --shots" it takes a handful of frames into evidence/ and quits
## instead of handing you the controls, and with "-- --strip" it tiles one
## click's worth of frames into a single sheet, which is the only way a still
## image can show a two-per-second pulse: the front arrives, sweeps the room
## and leaves it to the memory of the points.
const REMOTE := preload("res://game/net/remote_player.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
## How often the bodies are told where they are, matching the online rate.
const STATE_RATE := 20.0
## Walking, running and crouching, and the noise each carries (hotel_player).
const GAITS := [
	{"speed": 3.8, "stride": 1.9, "noise": "walk", "kind": NOISE.Kind.FOOTSTEP, "crouched": false},
	{"speed": 6.0, "stride": 2.4, "noise": "run", "kind": NOISE.Kind.RUN, "crouched": false},
	{"speed": 2.0, "stride": 1.333, "noise": "crouch", "kind": NOISE.Kind.FOOTSTEP, "crouched": true},
]
const NAMES := ["Ana", "Bruno", "Celia"]
## Any of them, now and then, walks to a free wardrobe near it, gets in and
## later comes out again: seconds between trips, and how long it stays, both
## drawn at random each time. Getting in and out is a WARDROBE noise.
const HIDE_WAIT := Vector2(8.0, 26.0)
const HIDE_STAY := Vector2(4.0, 14.0)
## A wardrobe further than this along the floor is not worth the trip.
const HIDE_REACH := 30.0
## Seconds a killed survivor stays dead before walking again. An execution
## alone takes three, so at most two are ever down at once and the floor never
## fails for lack of survivors (the roster below asks for one alive).
const REVIVE_AFTER := 6.0

var level
var walkers: Array = []
var rng := RandomNumberGenerator.new()
var state_clock := 0.0
var shots := false
var strip := false

func _initialize() -> void: run.call_deferred()

## A room worth walking to: anywhere but the refuge, which swallows noise.
func somewhere() -> Vector3:
	for attempt in 12:
		var room: Dictionary = level.manifest.rooms[rng.randi() % level.manifest.rooms.size()]
		var point: Vector3 = FLOOR.position_of(room)
		if not level.point_in_refuge(point): return point
	return FLOOR.position_of(level.manifest.rooms[0])

func retarget(walker: Dictionary) -> void:
	walker.bound_for = null
	var map: RID = level.get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, walker.body.global_position)
	var to := NavigationServer3D.map_get_closest_point(map, somewhere())
	walker.path = FLOOR.navigation_path(map, from, to)
	walker.index = 1
	walker.gait = GAITS[rng.randi() % GAITS.size()]

func spawn() -> void:
	for i in 3:
		var seat := i + 2
		var body = REMOTE.new()
		body.setup(level, seat, NAMES[i], i % 3)
		body.process_mode = Node.PROCESS_MODE_PAUSABLE
		level.add_child(body)
		body.place(somewhere() + Vector3(0, 0.06, 0), 0.0)
		# Registered where the level looks for survivors, so the creature sees
		# and hunts them and the shriek can find them.
		level.match_net.bodies[seat] = body
		level.session.participants[seat] = level.session.Life.EXPLORING
		var walker := {"body": body, "seat": seat, "path": PackedVector3Array(), "index": 1, "gait": GAITS[0], "distance": 0.0, "hide_clock": rng.randf_range(HIDE_WAIT.x * 0.5, HIDE_WAIT.y), "hidden_left": 0.0, "bound_for": null, "dead_left": 0.0, "velocity": Vector3.ZERO, "burnt_out": false}
		retarget(walker)
		walkers.append(walker)
	# One alive is enough: striking them down is part of the rehearsal.
	level.session.roster_count = 1

## Caught, held on the blade, dead, and back again after a while so the
## rehearsal can go on: otherwise it walks.
func tend(walker: Dictionary, delta: float) -> void:
	var body = walker.body
	var seat: int = walker.seat
	var life = level.session.participants.get(seat, level.session.Life.DEAD)
	if not level.execution.is_empty() and int(level.execution.seat) == seat:
		# Nobody is at this body's controls to be lifted: do it here, where the
		# creature holds it, so its silhouette hangs in front of the hunter.
		# Offline nothing pulls a victim out of its wardrobe; do what the host would.
		if body.hidden and is_instance_valid(body.hiding_place): level.match_net.remote_leaves(body.hiding_place, body)
		walker.hidden_left = 0.0
		var yaw: float = level.locust.rotation.y
		var lift := clampf(float(level.execution.time) / 0.5, 0.0, 1.0)
		walker.velocity = Vector3.ZERO
		body.place(level.locust.global_position - Basis(Vector3.UP, yaw).z * 1.05 + Vector3(0, 0.1 + lift, 0), yaw + PI)
		return
	if life == level.session.Life.DEAD:
		if not body.dead:
			body.set_dead(true)
			walker.dead_left = REVIVE_AFTER
			print("REHEARSAL ", NAMES[seat - 2], " died")
		walker.dead_left -= delta
		if walker.dead_left <= 0.0: revive(walker)
		return
	walk(walker, delta)

## Back on the floor somewhere the creature is not.
func revive(walker: Dictionary) -> void:
	var body = walker.body
	var point := somewhere()
	for attempt in 8:
		if point.distance_to(level.locust.global_position) > 14.0: break
		point = somewhere()
	body.set_dead(false)
	body.place(point + Vector3(0, 0.06, 0), 0.0)
	level.session.participants[walker.seat] = level.session.Life.EXPLORING
	walker.hidden_left = 0.0
	retarget(walker)
	print("REHEARSAL ", NAMES[walker.seat - 2], " walks again")

## The end of the path: a new room, or the last step to a wardrobe's doors
## (the navigation mesh stops short of them).
func path_done(walker: Dictionary) -> void:
	var bound = walker.bound_for
	if bound == null:
		retarget(walker)
		return
	walker.path = PackedVector3Array([walker.body.global_position, bound.to_global(bound.exit_offset)])
	walker.index = 1

## The nearest free wardrobe within reach, walked to at the body's own gait.
func head_for_wardrobe(walker: Dictionary) -> void:
	var body = walker.body
	var nearest = null
	for hide in level.hotel.hides:
		if hide.occupant != null: continue
		if nearest == null or hide.global_position.distance_to(body.global_position) < nearest.global_position.distance_to(body.global_position): nearest = hide
	if nearest == null or nearest.global_position.distance_to(body.global_position) > HIDE_REACH: return
	var map: RID = level.get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, body.global_position)
	var to := NavigationServer3D.map_get_closest_point(map, nearest.to_global(nearest.exit_offset))
	walker.path = FLOOR.navigation_path(map, from, to)
	walker.index = 1
	walker.bound_for = nearest

## One body's step: follow its path, make the noise it would make, and tell the
## body where it is so its own footsteps and walking pose follow.
func walk(walker: Dictionary, delta: float) -> void:
	var body = walker.body
	if walker.hidden_left > 0.0:
		walker.hidden_left -= delta
		walker.velocity = Vector3.ZERO
		if walker.hidden_left <= 0.0 and is_instance_valid(body.hiding_place):
			var hide = body.hiding_place
			level.match_net.remote_leaves(hide, body)
			body.place(hide.to_global(hide.exit_offset), body.rotation.y)
			level.on_noise(hide.global_position, NOISE.radius("wardrobe"), NOISE.Kind.WARDROBE)
			print("REHEARSAL ", NAMES[walker.seat - 2], " leaves a wardrobe")
			walker.hide_clock = rng.randf_range(HIDE_WAIT.x, HIDE_WAIT.y)
			retarget(walker)
		return
	var bound = walker.bound_for
	if bound != null:
		if bound.occupant != null:
			# Somebody got there first: carry on somewhere else.
			walker.bound_for = null
			walker.hide_clock = rng.randf_range(HIDE_WAIT.x, HIDE_WAIT.y)
			retarget(walker)
		elif body.global_position.distance_to(bound.to_global(bound.exit_offset)) < 0.9:
			# At its doors: in, and shut them.
			walker.bound_for = null
			body.global_position = bound.global_position
			level.match_net.remote_enters(bound, body)
			level.on_noise(bound.global_position, NOISE.radius("wardrobe"), NOISE.Kind.WARDROBE)
			walker.hidden_left = rng.randf_range(HIDE_STAY.x, HIDE_STAY.y)
			print("REHEARSAL ", NAMES[walker.seat - 2], " hides in a wardrobe")
			walker.velocity = Vector3.ZERO
			return
	else:
		walker.hide_clock -= delta
		if walker.hide_clock <= 0.0:
			walker.hide_clock = rng.randf_range(HIDE_WAIT.x, HIDE_WAIT.y)
			head_for_wardrobe(walker)
	if walker.index >= walker.path.size(): path_done(walker)
	if walker.path.size() < 2: return
	var target: Vector3 = walker.path[mini(walker.index, walker.path.size() - 1)]
	var here: Vector3 = body.global_position
	var step: Vector3 = target - here
	step.y = 0.0
	if step.length() < 0.45:
		walker.index += 1
		if walker.index >= walker.path.size(): path_done(walker)
		return
	var gait: Dictionary = walker.gait
	var direction := step.normalized()
	var moved: float = gait.speed * delta
	body.global_position = here + direction * moved
	body.rotation.y = atan2(-direction.x, -direction.z)
	walker.velocity = direction * float(gait.speed)
	# Footfalls from distance covered, with the same loudness the real player
	# would make, so the hunter's contacts are honest.
	walker.distance += moved
	if walker.distance >= gait.stride:
		walker.distance = 0.0
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, body.global_position)
		var hard: bool = not room.is_empty() and int(room.type) in FLOOR.HARD_FLOORS
		level.on_noise(body.global_position, NOISE.radius(gait.noise + ("_hard" if hard else "")), gait.kind)
		# Now and then somebody vaults something.
		if rng.randf() < 0.02: level.on_noise(body.global_position, NOISE.radius("jump"), NOISE.Kind.JUMP)
	# A door in the way gets opened, gently or shoved depending on the hurry.
	for door in level.hotel.doors:
		if door.opened or door.moving: continue
		var offset: Vector3 = door.doorway - body.global_position
		offset.y = 0.0
		if offset.length() < 1.6 and direction.dot(offset.normalized()) > 0.2:
			level.match_net.use_door(door, rng.randf() < 0.35, gait.speed > 5.0)
			break

## What the bodies are told, in the same shape match_net sends online.
func push_states() -> void:
	for walker in walkers:
		var body = walker.body
		var index := -1
		if body.hidden and is_instance_valid(body.hiding_place): index = level.hotel.hides.find(body.hiding_place)
		# Bit 4 is a mind that has burnt out: the state each machine sends
		# carries it, so a body only keeps its motes while its own machine
		# says so -- here, while the rehearsal says so.
		var flags := (1 if walker.gait.crouched else 0) | (4 if walker.burnt_out else 0)
		body.push_state([body.global_position, body.rotation.y, 0.0, walker.velocity, flags, index, 0.0, 0.0])

func shot(name: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/rehearsal_%s.png" % name)
	print("SHOT ", name, " sees=", level.locust.sees(nearest_body()), " at=", snappedf(level.locust.global_position.distance_to(nearest_body().global_position), 0.1))

## Whichever of the three is closest to the creature right now.
func nearest_body() -> Node3D:
	var best: Node3D = walkers[0].body
	for walker in walkers:
		if walker.body.global_position.distance_to(level.locust.global_position) < best.global_position.distance_to(level.locust.global_position): best = walker.body
	return best

## Stand the creature a few metres behind somebody, looking at them. Only for
## the capture pass: while playing you walk there yourself.
func approach(body: Node3D, span: float) -> void:
	var map: RID = level.get_world_3d().navigation_map
	var behind: Vector3 = body.global_position + body.global_basis.z * span
	level.locust.global_position = NavigationServer3D.map_get_closest_point(map, behind) + Vector3(0, 0.04, 0)
	var offset: Vector3 = body.global_position - level.locust.global_position
	level.locust.rotation.y = atan2(-offset.x, -offset.z)
	level.locust.driver.pitch = -0.12

## One click across eight frames, tiled into a single sheet. At two clicks a
## second a still frame catches the room either lit by the passing front or
## dark between fronts, and neither one alone is what it looks like.
func contact_sheet() -> void:
	var target: Node3D = nearest_body()
	approach(target, 7.0)
	for i in 120: await physics_frame
	var frames: Array = []
	var echo = level.locust.driver.echo
	# Start right after a click so the sheet covers one whole sweep.
	var seen: int = echo.clicks
	while echo.clicks == seen: await physics_frame
	for shot_index in 8:
		for i in 4: await physics_frame
		await RenderingServer.frame_post_draw
		frames.append(root.get_texture().get_image())
	var columns := 4
	var rows := 2
	var cell: Image = frames[0]
	var wide := cell.get_width() / 2
	var high := cell.get_height() / 2
	var sheet := Image.create(wide * columns, high * rows, false, cell.get_format())
	for i in frames.size():
		var one: Image = frames[i]
		one.resize(wide, high, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(one, Rect2i(0, 0, wide, high), Vector2i((i % columns) * wide, (i / columns) * high))
	sheet.save_png("res://evidence/rehearsal_pulse.png")
	print("SHEET rehearsal_pulse ", frames.size(), " frames")

func run() -> void:
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		# Its own flag: --playtest-seed is read by hotel_main itself, and both
		# would build a floor at once.
		if argument.begins_with("--rehearsal-seed="): seed_value = int(argument.trim_prefix("--rehearsal-seed="))
		if argument == "--shots": shots = true
		if argument == "--strip": strip = true
	rng.seed = seed_value + 5501
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The tape screen plays over everything for its first seconds and these
	# shots are about what is behind it.
	level.ui.finish_intro()
	await level.take_locust(seed_value)
	level.settings.values.quality = 2
	level.apply_settings()
	# The hunter's own body has no survivor: park it and let the three walk.
	level.player.global_position = Vector3(0, -80, 0)
	level.session.participants.erase(level.player.slot)
	spawn()
	approach(walkers[0].body, 9.0)
	level.ui.flash("ENSAYO - TRES SUPERVIVIENTES EN EL PISO", 5.0)
	print("REHEARSAL walkers=", walkers.size(), " seed=", seed_value)
	# Unattended, a stray click on the window would strike someone and spoil
	# the frames: the controls belong to a person only.
	if shots or strip: level.locust.driver.set_process_unhandled_input(false)
	if strip:
		await contact_sheet()
		paused = false
		level.queue_free()
		await process_frame
		quit()
		return
	var clock := 0.0
	var next_shot := 0
	var when := [4.0, 9.0, 14.0, 19.0, 24.0, 29.0]
	while true:
		await physics_frame
		var delta := 1.0 / 60.0
		clock += delta
		if level.session.state != level.session.State.PLAYING: continue
		for walker in walkers: tend(walker, delta)
		state_clock -= delta
		if state_clock <= 0.0:
			state_clock = 1.0 / STATE_RATE
			push_states()
		if not shots: continue
		if next_shot < when.size() and clock >= when[next_shot]:
			# Walk up behind whoever is nearest and keep a frame of it.
			var target: Node3D = nearest_body()
			if next_shot == 4:
				# The wardrobe one: look at whoever is hidden, if anybody is.
				for walker in walkers:
					if walker.hidden_left > 0.0: target = walker.body
			approach(target, [7.0, 11.0, 4.5, 9.0, 3.2, 6.0][next_shot])
			if next_shot == 5:
				# A mind that has gone out, seen from the far end of the wing:
				# the motes come through the hotel and do not shrink, so the
				# body is put right down the creature's line of sight and far
				# enough away that nothing else of it reads.
				for walker in walkers: walker.burnt_out = walker.body == target
				var map: RID = level.get_world_3d().navigation_map
				var down_the_line: Vector3 = level.locust.global_position - level.locust.global_basis.z * 34.0
				target.place(NavigationServer3D.map_get_closest_point(map, down_the_line) + Vector3(0, 0.1, 0), 0.0)
				# The states are sent from the loop, and the loop is not
				# running while this shot is being set up.
				push_states()
			if next_shot == 3: level.locust.driver.shriek()
			# Two or three clicks so the reading has swept it.
			for i in 18: await physics_frame
			await shot(["walking", "noises", "chase", "shriek", "wardrobe", "burnt"][next_shot])
			next_shot += 1
		elif next_shot >= when.size():
			break
	if shots:
		paused = false
		level.queue_free()
		await process_frame
		quit()
