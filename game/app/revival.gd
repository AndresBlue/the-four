extends Node
## Coming back: everyone raised at the start of a stage that was lost (or
## when a dead player is brought back), the creature sent off to a den far
## from them, somebody back after dropping out, and -- while dead -- watching
## through a teammate's camera. Split out of hotel_main.gd, which owns it
## (`level.revival`); the level keeps delegates of what the network, the bots
## and the tests reach through it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const AVATAR := preload("res://game/player/avatars/avatar_visual.gd")
var level

## The view of a dead player, through the camera of the teammate watched.
var watch_rig: Node3D

var watch_camera: Camera3D

## Everybody is on their feet again: between stages, or because the floor gave
## this stage back after it was lost. The authority says where, and every
## machine puts the bodies there.
func on_revived(restart: bool) -> void:
	if level.net.is_client() or level.manifest.is_empty(): return
	var point := revival_point()
	var places := {}
	# Nobody for a seat lost for the floor: raised here, it was a body nobody
	# drove, counted alive and never dropped again.
	for seat in level.session.participants:
		if not level.session.dropped.has(seat): places[seat] = point + Vector3(randf_range(-1.2, 1.2), 0.1, randf_range(-1.2, 1.2))
	# A stage given back is given back whole, the creature too: it goes back
	# to where it starts that stage (its den_point()), away from the door
	# everybody is raised at and from the one they have to reach, and waits
	# there as long as it did when the floor began. Left where it stood, it was
	# often a metre from them, or camped at the way in or the way out. Whoever
	# drives it: a hunter's creature goes back too (it used to be theirs to
	# walk back, and they did not).
	var den := Vector3.INF
	if restart: level.ledger.note_restart()
	var creature = level.creature
	if restart and is_instance_valid(creature):
		den = creature.den_point(level.session.stage)
		if den == Vector3.INF: den = den_away(point, RESTART_DEN)
	apply_revival(places, restart, den)
	if level.match_net.in_match(): level.match_net.revive_everyone(places, restart, den)

## How far (metres of walking) from the stage's door the creature is put when
## a stage is given back and it has no den there (creature.den_point()), and
## the least it stands there before it moves: the difficulty's own grace, the
## one the floor began with, when that is longer (restart_grace).
const RESTART_DEN := 45.0

const RESTART_GRACE := 12.0

func restart_grace() -> float:
	return maxf(RESTART_GRACE, float(level.tuning().grace))

## A place for the creature in the wing of the stage in hand, at least `least`
## metres of walking from `away_from`: drawn among the rooms that far (the
## farthest one when none is), never a refuge, a lift lobby or the void.
## INF when there is no room to be had.
func den_away(away_from: Vector3, least: float) -> Vector3:
	var from := FLOOR.room_at(level.manifest.rooms, away_from)
	if from.is_empty(): return Vector3.INF
	var wing: int = level.session.stage - 1
	var metres := FLOOR.route_metres(level.manifest, int(from.id))
	var shut_out: Array = level.off_limits_rooms()
	var far_enough: Array = []
	var farthest := -1
	var farthest_metres := -1.0
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", 0)) != wing or shut_out.has(id) or FLOOR.is_void(room) or not metres.has(id): continue
		var walk := float(metres[id])
		if walk >= least: far_enough.append(id)
		if walk > farthest_metres:
			farthest_metres = walk
			farthest = id
	if far_enough.is_empty():
		if farthest < 0: return Vector3.INF
		far_enough.append(farthest)
	var draw := RandomNumberGenerator.new()
	draw.seed = hash([int(level.manifest.seed), "restart den", level.session.stage, level.session.restarts])
	var point := FLOOR.position_of(level.manifest.rooms[far_enough[draw.randi_range(0, far_enough.size() - 1)]])
	var map: RID = level.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0: point = FLOOR.closest(map, point)
	return point + Vector3(0, 0.04, 0)

## The creature put somewhere else at once, on every machine: where it is
## driven it forgets everybody and waits `rest` seconds -- a hunter's too,
## which cannot strike, shriek or trace while that lasts (locust_player), and
## whatever it was in the middle of where it stood is not carried over; the
## host judges its strikes by the same count (creature.relocate()). And it
## arrives stopped, a puppet dropping the states still on their way from where
## it was, or it would slide across the floor to get there (teleport(), the
## same as stepping out of a set, warp_creature).
func relocate_creature(point: Vector3, rest: float) -> void:
	var creature = level.creature
	if not is_instance_valid(creature) or point == Vector3.INF: return
	creature.relocate(point, rest)
	creature.teleport(point, NAN, &"revival")

## Where somebody who comes back after dropping is put: the place the floor
## remembers for them. Unless the floor crossed to another wing while they were
## away -- their old place is then behind a stage door with half a hotel
## between them and everybody else, and nobody would call that coming back.
## The stage in hand starts them where a revival would.
func return_place(remembered: Vector3) -> Vector3:
	if level.manifest.is_empty(): return remembered
	var wing := int(FLOOR.room_at(level.manifest.rooms, remembered).get("wing", -1))
	if wing == level.session.stage - 1: return remembered
	return revival_point() + Vector3(0, 0.1, 0)

## Where a stage starts: just inside the wing it is played in.
func revival_point() -> Vector3:
	var gates_list: Array = level.manifest.get("gates", [])
	# A negative index wraps round in GDScript, so the first stage asking for
	# this would have been sent to the last gate of the floor.
	var index: int = level.session.stage - 2
	if index < 0 or index >= gates_list.size(): return Vector3(0, 0.04, 0)
	var gate: Dictionary = gates_list[index]
	var arrive := int(gate.get("arrive", -1))
	if arrive < 0: return FLOOR.position_of(level.manifest.rooms[level.refuge_room()])
	return FLOOR.position_of(level.manifest.rooms[arrive])

## Applied on every machine: the local body comes back where it is told, the
## others are placed, and a stage that was lost starts again as it was found.
func apply_revival(places: Dictionary, restart: bool, creature_at := Vector3.INF) -> void:
	# The message itself says these seats are up. A guest's session is pushed
	# twice a second, so waiting for it to say so leaves up to half a second in
	# which the body is put away again every frame -- and its torch with it,
	# because the light hangs off the camera: hidden for its owner and lit for
	# everybody else.
	var raised := false
	for seat_key in places:
		var seat := int(seat_key)
		if level.session.participants.get(seat, level.session.Life.DEAD) == level.session.Life.DEAD:
			level.session.participants[seat] = level.session.Life.EXPLORING
			raised = true
	if raised: level.session.changed.emit()
	for seat_key in places:
		var seat := int(seat_key)
		if seat == level.player.slot: restore_local_player(places[seat_key])
		elif level.match_net.bodies.has(seat) and is_instance_valid(level.match_net.bodies[seat]):
			# Out of any wardrobe first, as its owner is on its own machine:
			# moved while still "inside", it went invisible and kept the
			# wardrobe taken for the rest of the floor.
			var body = level.match_net.bodies[seat]
			if body.hidden and is_instance_valid(body.hiding_place): level.match_net.remote_leaves(body.hiding_place, body)
			body.place(places[seat_key], 0.0)
			# Its head clear too, the same as the local one's.
			level.sanity.minds.erase(seat)
			level.match_net.bodies[seat].set_burnt(false)
	if restart:
		# Its door too: shut and locked again, or the stage given back could
		# be walked out of without doing it again.
		level.hotel.relock_gate(level.session.stage)
		# The stage as it was found: its own wing's sets go out again. What was
		# lit in the wings behind is not this stage's to undo.
		for index in level.stage_televisions():
			if level.televisions[index].on:
				level.apply_television(index, false)
				level.ledger.note_tv_out(index)
				if not level.net.is_client() and level.match_net.in_match(): level.match_net.television_state.rpc(index, false)
		# And the power with them: the cut came with the sets, and a stage
		# given back is given back whole. The authority says so, as always.
		if not level.net.is_client() and bool(level.session.goal.get("blackout", false)):
			level.session.goal["blackout"] = false
			level.session.changed.emit()
		relocate_creature(creature_at, restart_grace())
		if level.director != null and level.director.has_method("on_restart"): level.director.on_restart()
		# And nothing lying where somebody was caught: it has not happened.
		level.executions.clear_leavings()
		# The tape goes back to where the stage began, for whoever films it.
		level.begin_rewind()

## The inverse of watching a teammate: its own body, its own camera.
func restore_local_player(point: Vector3) -> void:
	# On its feet again with its head clear: what it went through belonged to
	# the stage it lost.
	level.player.sanity = 100.0
	level.player.set_burnt(false)
	level.player.active = level.session.state == level.session.State.PLAYING and not level.online_menu and not level.match_net.local_is_locust()
	level.player.velocity = Vector3.ZERO
	level.player.reset_handheld()
	level.player.global_position = point
	# Whoever closed the stage is put on their feet by the session at the same
	# moment their lift is carrying them: the ride keeps the hold and the
	# picture until the doors open.
	level.player.held = not level.lifts.boarding.is_empty() or level.lifts.leaving >= 0.0
	if level.player.hidden: level.player.force_leave_hide()
	# On its feet, however an execution left it lying.
	level.player.avatar.end_capture()
	stop_watching()
	level.clear_screen_cues()
	# Put somewhere else: a cut, with the rooms there shown at once.
	level.visibility_clock = 1.0
	level.camera_cut()
	# A sheet opened while dead was opened to look at only: up again, it is
	# theirs to write on.
	if level.ui.sheet.visible and not level.ui.sheet.editable: level.ui.sheet.open(true, level.settings.prompt_name("sheet"), level.notes_found())

## Back behind its own eyes. Everything watching a teammate did to the body --
## hidden, without collision, with somebody else's camera in front -- is undone
## here, and the torch is brought back to the hand: it is not parented to the
## camera but trails it, so a body that jumps leaves its own light behind.
## Called on a revival and again from the loop, because a single frame spent
## believing it was dead would otherwise leave the body away for the rest of
## the floor.
func stop_watching() -> void:
	var hunter: bool = level.match_net.local_is_locust()
	level.player.visible = not hunter
	level.player.collision_layer = 0 if hunter else 4
	if is_instance_valid(level.player.camera): level.player.camera.current = not hunter
	if is_instance_valid(watch_camera): watch_camera.current = false
	if is_instance_valid(watch_rig):
		watch_rig.queue_free()
		watch_rig = null
		watch_camera = null
	level.match_net.watching = 0
	# The body it watched through is drawn again for everybody's camera.
	if is_instance_valid(watched_body): own_sight(watched_body, true)
	watched_body = null
	level.player.snap_torch()

## Dead online: the view follows a living teammate; a click switches to the next.
func watch_teammates() -> void:
	level.player.active = false
	# Its own body stays where it fell, for whoever it watches through to
	# come upon -- and for itself, now that it sees with another's camera,
	# which draws what its own did not (avatar_visual.show_to_owner).
	level.player.visible = level.player.avatar != null and level.player.avatar.fallen
	if level.player.visible: level.player.avatar.show_to_owner(true)
	level.player.collision_layer = 0
	var body: Node3D = level.match_net.watched_body()
	level.camcorder.focus("")
	if body == null:
		level.ui.hint.text = "HAS MUERTO"
		return
	watch_over(body)
	level.ui.hint.text = "HAS MUERTO, OBSERVANDO A %s, %s PARA CAMBIAR" % [body.player_name.to_upper(), (level.settings.button_name(JOY_BUTTON_A) if level.settings.using_pad and level.settings.pad_present() else "CLIC")]

## Through the teammate's own camera: what it sees, as it sees it. Where its
## camera is and which way it looks comes from its owner (match_net.pack_local)
## with every sway, lean, peek and step in it; the lens is zoomed as theirs is
## and bent as much (presentation_rig.update_zoom_lens), and focused where
## theirs is. Its own body is not in the picture while the camera is at its
## head, as it is not in its own; its shadow is. (Until 18 October 2026 this
## was a camera on an arm behind the teammate's shoulder.)
func watch_over(body: Node3D) -> void:
	if not is_instance_valid(watch_rig):
		watch_rig = Node3D.new()
		watch_rig.name = "WatchRig"
		level.add_child(watch_rig)
		watch_camera = Camera3D.new()
		watch_camera.name = "WatchCamera"
		var own: Camera3D = level.player.camera
		watch_camera.fov = own.fov
		watch_camera.near = own.near
		watch_camera.far = own.far
		watch_camera.cull_mask = own.cull_mask
		watch_rig.add_child(watch_camera)
	# Somebody else to watch is a cut: the rooms round them are shown at once,
	# and no blur or combing is smeared across from the last view.
	if watched_body != body:
		if is_instance_valid(watched_body): own_sight(watched_body, true)
		watched_body = body
		level.visibility_clock = 1.0
		level.camera_cut()
	var view: Transform3D = body.smooth_view() if body.has_method("smooth_view") else body.camera.global_transform
	watch_camera.global_transform = view
	own_sight(body, not near_head(body, view.origin))
	# Its focus, on this machine's lens settings (the depth of field is a
	# graphics preset's).
	if level.player.autofocus and "focus" in body:
		if not watch_camera.attributes is CameraAttributesPractical:
			var lens := CameraAttributesPractical.new()
			lens.dof_blur_amount = level.player.FOCUS_BLUR
			watch_camera.attributes = lens
		level.player.lens_focus(watch_camera.attributes, float(body.focus))
	elif watch_camera.attributes != null: watch_camera.attributes = null
	if not watch_camera.current: watch_camera.current = true

## Whether a body is drawn for the camera watching through it: not while that
## camera is at its head (hair, hat and the inside of its face), and again once
## it is away from it, thrown from its hands in the creature's.
func own_sight(body: Node3D, shown: bool) -> void:
	if not "avatar" in body or body.avatar == null: return
	for mesh in body.avatar.meshes:
		if not is_instance_valid(mesh): continue
		if shown and (mesh.layers & 1) == 0: AVATAR.put_on_layers(mesh, 1)
		elif not shown and mesh.layers != 2: AVATAR.put_on_layers(mesh, 2)

const AT_HEAD := 0.5
func near_head(body: Node3D, point: Vector3) -> bool:
	var avatar = body.avatar if "avatar" in body else null
	if avatar == null or avatar.rig == null or int(avatar.bones.get("head", -1)) < 0: return point.distance_to(body.global_position + Vector3(0, 1.5, 0)) < AT_HEAD
	return avatar.bone_point(int(avatar.bones.head)).distance_to(point) < AT_HEAD

## A cut (a new floor, the opening scene): the iris jumps to the new light
## instead of adjusting across it.
var watched_body: Node3D
