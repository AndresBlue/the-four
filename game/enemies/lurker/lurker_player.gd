extends Node
## Versus: a player is The Lurker (.claude/specs/lurker_versus.md 5; phase 0,
## her body, with no net yet). Reads the pad, or the keys and the mouse, into
## her motion's free leg (lurker_motion.follow_free): the stick pushes her over
## the ceilings and along an aisle, the way the camera looks. What is not the
## stick's is an order to the AI's planner, run whole: through a door she is
## pushed at (a shut one stops her), into an aisle she is pushed along at its
## mouth, into the grille or the tile nearest where she looks (lurker_enter),
## and out of the ducts by the way out nearest where she looks (lurker_enter
## again). lurker_drop lets her down as far as the warning does, and back up.
## She has no floor and opens no door.
##
## The camera is at her face with the world's up, apart from her body, which
## it does not draw, and sees with her eyes (lurker_view.gd, phase 2). Through
## a grille, a tile or a duct it cuts to the ducts' plan; at rest in a
## grille's mouth it looks out of it.
##
## Phase 3 (lurker_versus.md 6 and 7): lurker_stalk takes her to the nearest
## place to lie in wait within STALK_REACH (lurker_stalk.gd), run whole; still
## there SETTLE s, she has settled (settled(): the host reads it in her flags
## and charges her on whom she watches). lurker_release asks the host for her
## warning (match_net.lurker_release()); lurker_peek shows her to the edge of
## somebody's view (match_net.lurker_peek()). While the warning runs she goes
## no faster than a walker. Blinded or looked at in the light, the host sends
## her off (scared()): her body bolts into the ceiling as the AI's does, and
## the stick is not hers until it is in. lurker_drink is phase 4's.
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const STALK := preload("res://game/enemies/lurker/lurker_stalk.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
## A place to lie in wait within this of her (plan metres); still this long at
## it, she has settled; off it by more than SITE_NEAR she has left it.
const STALK_REACH := 3.0
const SETTLE := 1.0
const SITE_NEAR := 0.4
## The pose of a peek, and of a fright, held this long.
const PEEK_POSE := 1.2
const SCARE_POSE := 0.4
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const VISUAL := preload("res://game/enemies/lurker/lurker_visual.gd")
const PAD_FEEL := preload("res://game/player/pad_feel.gd")
const VIEW := preload("res://game/enemies/lurker/lurker_view.gd")
var pad := PAD_FEEL.new()
var view
## Pushed at a door within this of its doorway (plan metres), this near its
## way (cosine); along an aisle the same, at its mouth.
const DOOR_REACH := 1.6
const PUSH_TOWARD := 0.6
## And the camera this near the way through (cosine).
const LOOK_THROUGH := 0.5
## A grille or a tile within this of her (plan metres), the one nearest where
## she looks; out of the ducts, a way out within LEAVE_REACH. A way off where
## she looks costs LOOK_COST metres per unit of cosine lost.
const ENTER_REACH := 3.0
const LEAVE_REACH := 25.0
const LOOK_COST := 4.0
## Out of the ducts the look comes first: this per unit of cosine lost, and
## this per metre.
const TURN_COST := 10.0
const NEAR_COST := 0.15
## Along an aisle she holds on to a shelf this high.
const AISLE_HOLD := 1.8
## Her eye kept this far off what it would have gone into.
const EYE_CLEAR := 0.12
## Looking out of a grille she rests in: this far out of it.
const GRILLE_OUT := 0.25
## On a door's band her eye kept this far off a leaf, a jamb or a wall: the
## world's, a shut door's and an open one's layers (hotel_door.gd).
const LEAF_CLEAR := 0.35
const LEAF_MASK := 1 | 8 | 128
var creature
var level
var camera: Camera3D
## Black over the picture while she has no eyes (a grille, a tile, a duct).
var blind: ColorRect
var yaw := 0.0
var pitch := -0.25
## Her eye at the last two physics ticks: the camera drawn between them.
var eye_from := Vector3.INF
var eye_to := Vector3.INF
var dark := false
## The scripted driver (tests/office/lurker_player_test.gd) writes `axis`
## (left stick: x right, y back) and `asked` itself and the devices are not read.
var scripted := false
var axis := Vector2.ZERO
var asked := {}
var active := true
## The grille or tile she was sent into: once in, the mouth she rests in.
var into_exit := -1
## The site she lies in wait at (creature.stalk_sites), -1 none; how long
## she has held still at it; how long more a pose is held.
var stalk_at := -1
var settle_clock := 0.0
var pose_clock := 0.0

func setup(owner) -> void:
	creature = owner
	level = owner.level
	name = "Driver"
	camera = Camera3D.new()
	camera.name = "LurkerCamera"
	camera.fov = 74.0
	camera.near = 0.05
	# Not her own body nor its ink: a blot over her own eyes.
	camera.cull_mask = 0xFFFFF & ~VISUAL.LAYER
	add_child(camera)
	var cover := CanvasLayer.new()
	cover.layer = 90
	add_child(cover)
	blind = ColorRect.new()
	blind.color = Color.BLACK
	blind.set_anchors_preset(Control.PRESET_FULL_RECT)
	blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blind.visible = false
	cover.add_child(blind)
	# Her eyes (lurker_view.gd): the picture her camera is drawn into, and the
	# ducts' plan over the black.
	view = VIEW.new()
	add_child(view)
	view.setup(self, cover)
	var facing: Vector3 = creature.global_basis.z
	yaw = atan2(-facing.x, -facing.z) if Vector2(facing.x, facing.z).length() > 0.1 else 0.0

func can_act() -> bool:
	return active and creature.control == "player" and level.session.state == level.session.State.PLAYING and not level.online_menu

func _unhandled_input(event: InputEvent) -> void:
	if scripted or not can_act(): return
	# The test order for the flash (phase 3 decides who fires it): F8, in a
	# build with the debug tools, from the nearest survivor or from ahead.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		view.flash(view.nearest_survivor_way())
	pad.pressed(event, level.settings)
	if event is InputEventMouseMotion:
		var sensitivity: float = level.settings.values.sensitivity
		look_by(Vector2(-event.relative.x, -event.relative.y) * sensitivity)

func look_by(amount: Vector2) -> void:
	yaw = wrapf(yaw + amount.x, -PI, PI)
	pitch = clampf(pitch + amount.y * (-1.0 if level.settings != null and level.settings.values.invert else 1.0), -1.45, 1.2)

## Where the camera looks, flat.
func forward() -> Vector3: return Vector3(-sin(yaw), 0, -cos(yaw))

## Her top pace with the stick all the way: the AI's unseen pace for her
## difficulty, and her scurry at least.
func top_pace() -> float: return maxf(float(creature.unseen_speed), MOTION.SCURRY_SPEED)

## Every physics tick, before her motion's (lurker.step_physics()).
func drive(delta: float) -> void:
	var motion = creature.motion
	if not scripted:
		axis = Input.get_vector("left", "right", "forward", "backward") if can_act() else Vector2.ZERO
		for action in [&"lurker_enter", &"lurker_drop", &"lurker_stalk", &"lurker_peek", &"lurker_release"]:
			if InputMap.has_action(action) and Input.is_action_just_pressed(action): asked[action] = true
	var free: bool = (scripted or can_act()) and creature.grace <= 0.0
	var ahead := forward()
	var push := Vector3(-ahead.z, 0, ahead.x) * axis.x - ahead * axis.y
	if into_exit >= 0 and motion.legs.is_empty():
		if motion.in_duct: motion.mouth_exit = into_exit
		into_exit = -1
	if free and asked.has(&"lurker_release"): level.match_net.lurker_release()
	if free and asked.has(&"lurker_peek"): peek()
	watch_site(delta)
	pose_clock -= delta
	if pose_clock <= 0.0 and creature.intent_clip in ["peek", "scare"]: creature.intent_clip = ""
	motion.steering = true
	motion.free_face = ahead
	# On a door's band the stick does not slide her about it: act() takes her off.
	motion.free_way = push if free and motion.legs.is_empty() and not on_band() else Vector3.ZERO
	if free and motion.legs.is_empty():
		motion.pace = top_pace() * minf(push.length(), 1.0)
		# During her warning no faster than a walker: running always saves (7).
		if creature.cue: motion.pace = minf(motion.pace, BRAIN.CUE_FOLLOW)
		act(push)
	asked.clear()
	if creature.visual != null: creature.visual.look_point = camera.global_position - camera.global_basis.z * 10.0
	if not scripted and is_instance_valid(level.get("camcorder")):
		level.camcorder.announce("LA CAZA EMPIEZA EN %d" % int(ceil(creature.grace)) if creature.grace > 0.0 else "")

## After her motion's tick (a child's physics comes after its parent's): her
## eye now, or none.
func _physics_process(_delta: float) -> void:
	if creature == null or creature.motion == null: return
	var seen := eye_now()
	dark = seen.is_empty()
	# Back to her eyes, the camera starts there: never a sweep from where it went dark.
	if dark:
		eye_to = Vector3.INF
		return
	eye_from = eye_to if eye_to != Vector3.INF else seen[0]
	eye_to = seen[0]

## [point] she sees from, or [] with no eyes: her face on a surface (short of
## whatever stands between it and her anchor: a narrow aisle's far shelf);
## resting in a grille's mouth, out of the grille.
func eye_now() -> Array:
	var motion = creature.motion
	if motion.surface():
		var at: Vector3 = motion.anchor()
		var face: Vector3 = creature.face_point()
		var space: PhysicsDirectSpaceState3D = creature.get_world_3d().direct_space_state
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at, face, 1, [creature.get_rid()]))
		if not hit.is_empty(): return [(hit.position as Vector3) + (at - face).normalized() * EYE_CLEAR]
		if int(creature.shell.patches[motion.state.patch].kind) == SHELL.Kind.BAND: face = off_leaf(space, at, face)
		return [face]
	if motion.in_duct and motion.legs.is_empty() and motion.mouth_exit >= 0:
		var exit: Dictionary = creature.ducts.exits[motion.mouth_exit]
		if String(exit.kind) != "tile": return [(exit.position as Vector3) + (exit.normal as Vector3) * GRILLE_OUT]
	return []

## Over a door head an open leaf stood at her cheek and took half the view:
## the eye moved off whatever is within LEAF_CLEAR round it, flat, just so
## far, and only where the way from her anchor stays clear.
func off_leaf(space: PhysicsDirectSpaceState3D, at: Vector3, face: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for k in 8:
		var way := Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(face, face + way * LEAF_CLEAR, LEAF_MASK, [creature.get_rid()]))
		if not hit.is_empty(): push -= way * (LEAF_CLEAR - face.distance_to(hit.position))
	if push.length() < 0.01: return face
	var moved: Vector3 = face + push.limit_length(LEAF_CLEAR)
	return moved if space.intersect_ray(PhysicsRayQueryParameters3D.create(at, moved, LEAF_MASK, [creature.get_rid()])).is_empty() else face

func _process(delta: float) -> void:
	if creature == null or level == null: return
	if not scripted and can_act() and level.settings != null:
		var turn := pad.look(delta, level.settings)
		if turn != Vector2.ZERO: look_by(turn)
	blind.visible = dark and camera.current
	if eye_to == Vector3.INF: return
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), eye_from.lerp(eye_to, Engine.get_physics_interpolation_fraction()))

## What the buttons and the push ask of her while no order runs.
func act(push: Vector3) -> void:
	var motion = creature.motion
	if push.length() >= 0.3 or asked.has(&"lurker_enter") or asked.has(&"lurker_drop"): stalk_at = -1
	if asked.has(&"lurker_stalk") and motion.surface() and not on_band():
		stalk()
		return
	if on_band():
		# Off the lintel she lies in wait on, the way the stick says: back onto
		# her room's ceiling, or through the door.
		if push.length() >= 0.3:
			var record: Dictionary = creature.shell.patches[motion.state.patch]
			motion.run_legs([{"kind": "band", "patch": motion.state.patch, "dir": 1 if push.dot(record.across) > 0.0 else -1, "v": motion.state.v}], top_pace())
		return
	if asked.has(&"lurker_drop") and motion.surface(): motion.drop(not motion.state.lowered)
	# Let down, she gets back up before any way through.
	var low: bool = motion.surface() and (motion.state.lowered or motion.state.hang > SHELL.HANG_MAX + 0.05)
	if asked.has(&"lurker_enter"):
		if motion.in_duct: leave()
		elif motion.surface() and not low: enter()
		return
	if low or push.length() < 0.3 or not motion.surface(): return
	if motion.on_channel():
		var record: Dictionary = creature.shell.patches[motion.state.patch]
		if motion.state.v <= 0.05 and push.normalized().dot(record.axis) < -PUSH_TOWARD: motion.leave_channel(top_pace())
		return
	if not through_door(push): into_aisle(push)

## Legs from where she is to `goal`, run whole; only a way with exactly these
## doors (`pairs`) will do.
func order(goal: Dictionary, pairs: Array, extra: Array = []) -> bool:
	var motion = creature.motion
	var from: Dictionary = motion.plan_start()
	if from.is_empty(): return false
	var found: Dictionary = creature.routes.plan(from.start, goal, from.from_state, from.from_point)
	if not bool(found.ok) or found.pairs != pairs: return false
	motion.run_legs(found.legs + extra, top_pace())
	return true

## Pushed at an open door of her room: over its head to the other side.
func through_door(push: Vector3) -> bool:
	var motion = creature.motion
	var shell = creature.shell
	var room: int = motion.room()
	var at: Vector3 = motion.anchor()
	for band in shell.bands_of.get(room, []):
		var record: Dictionary = shell.patches[int(band)]
		var pair: Vector2i = record.pair
		if pair.x < 0: continue
		var origin: Vector3 = record.origin
		var to := Vector3(origin.x - at.x, 0, origin.z - at.z)
		if to.length() > DOOR_REACH or (to.length() > 0.05 and push.normalized().dot(to.normalized()) < PUSH_TOWARD): continue
		if not creature.routes.door_open(pair): continue
		var other := int(record.rooms[1]) if int(record.rooms[0]) == room else int(record.rooms[0])
		var end: Vector3 = shell.anchor_of(shell.band_start(int(band), other))
		var out := Vector3(end.x - origin.x, 0, end.z - origin.z).normalized()
		# Through only on purpose: looking the way through as well as pushing
		# (phase 0 crossed doors she only brushed past).
		if forward().dot(out) < LOOK_THROUGH: continue
		if order({"room": other, "point": end + out * 0.6, "surface": true}, [pair]): return true
	return false

## Pushed along an aisle at its mouth: in, a metre and a half along it.
func into_aisle(push: Vector3) -> bool:
	var motion = creature.motion
	var shell = creature.shell
	var at: Vector3 = motion.anchor()
	for channel in shell.channels_of.get(motion.room(), []):
		var record: Dictionary = shell.patches[int(channel)]
		var off: Vector3 = at - (record.origin as Vector3)
		var along: float = off.dot(record.axis)
		if push.normalized().dot(record.axis) < PUSH_TOWARD or absf(off.dot(record.across)) > float(record.width) * 0.5 + 0.2 or along < -1.2 or along > 0.5: continue
		# Along it up a shelf (as her mouth does by a lamp): the batten over the
		# aisle hangs where the middle of its ceiling is.
		var mouth: Vector3 = shell.anchor_of(shell.channel_mouth(int(channel)))
		if order({"room": motion.room(), "point": mouth, "surface": true}, [], [{"kind": "into_channel", "patch": int(channel)}, {"kind": "channel", "patch": int(channel), "v_to": minf(1.5, float(record.length)), "u_goal": shell.channel_u_on_wall(int(channel), 1.0, AISLE_HOLD)}]): return true
	return false

## Into the grille or the tile of her room (or of one open to it) within
## ENTER_REACH, the one nearest where she looks.
func enter() -> bool:
	var motion = creature.motion
	var ducts = creature.ducts
	var at: Vector3 = motion.anchor()
	var ahead := forward()
	var ways: Array = []
	for e in ducts.exits.size():
		var exit: Dictionary = ducts.exits[e]
		if not usable(e) or int(ducts.node_wings[int(exit.node)]) != motion.wing(): continue
		var point: Vector3 = exit.position
		if String(exit.kind) == "tile":
			if int(exit.room) != motion.room(): continue
			point = ducts.tile_point(int(exit.room), ducts.tile_near(int(exit.room), at))
		var to := Vector3(point.x - at.x, 0, point.z - at.z)
		# Right over her (a tile, a grille): as much hers as she looks up.
		var cosine: float = ahead.dot(to.normalized()) if to.length() > 0.3 else maxf(0.5, sin(pitch))
		if to.length() <= ENTER_REACH: ways.append([to.length() + LOOK_COST * (1.0 - cosine), e])
	ways.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for way in ways:
		if order({"exit": int(way[1])}, []):
			into_exit = int(way[1])
			return true
	return false

## Out of the ducts by a way out of her planta within LEAVE_REACH, the one
## most where she looks, the nearer of two alike; resting in one's mouth,
## looking out of it, that one.
func leave() -> bool:
	var way: Array = way_out()
	if way.is_empty(): return false
	creature.motion.run_legs(way[1], top_pace())
	return true

## The way out leave() would take now: [exit, legs], or [] with none. Her
## ducts' plan marks it (lurker_view.gd).
func way_out() -> Array:
	var motion = creature.motion
	if not motion.transit.is_empty() or not motion.in_duct: return []
	var ducts = creature.ducts
	var at: Vector3 = motion.duct_point
	var ahead := forward()
	var looks: Vector3 = Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD
	var ways: Array = []
	for e in ducts.exits.size():
		var exit: Dictionary = ducts.exits[e]
		if not usable(e) or int(ducts.node_wings[int(exit.node)]) != motion.wing(): continue
		var to := Vector3((exit.position as Vector3).x - at.x, 0, (exit.position as Vector3).z - at.z)
		if to.length() > LEAVE_REACH: continue
		var cosine: float = looks.dot(exit.normal) if e == motion.mouth_exit else (ahead.dot(to.normalized()) if to.length() > 0.3 else 0.0)
		ways.append([TURN_COST * (1.0 - cosine) + to.length() * NEAR_COST, e])
	ways.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var from: Dictionary = motion.plan_start()
	for way in ways.slice(0, 6):
		var e := int(way[1])
		# By the ducts alone to that way out (no walking round to it), then out
		# into its room.
		var inside: Dictionary = creature.routes.plan(from.start, {"exit": e, "surface": true}, null, from.from_point)
		if not bool(inside.ok): continue
		var node := int(ducts.exits[e].node)
		var p: Vector3 = creature.routes.exit_anchor(e) if String(ducts.exits[e].kind) != "tile" else ducts.exits[e].position
		var out: Dictionary = creature.routes.plan({"duct": [node, node], "metres": [0.0, 0.0], "point": ducts.nodes[node]}, {"room": int(ducts.exits[e].room), "point": p}, null, ducts.nodes[node])
		if not bool(out.ok) or not (out.pairs as Array).is_empty(): continue
		return [e, inside.legs + out.legs]
	return []

# --- Lying in wait (phase 3) -----------------------------------------------------------

func on_band() -> bool:
	var motion = creature.motion
	return motion.surface() and int(creature.shell.patches[motion.state.patch].kind) == SHELL.Kind.BAND

## Her sites on her planta within `reach` of her, nearest first: [[metres, index]].
func sites_near(reach: float) -> Array:
	var motion = creature.motion
	var out: Array = []
	if not motion.surface(): return out
	var at: Vector3 = motion.anchor()
	for i in creature.stalk_sites.size():
		var site: Dictionary = creature.stalk_sites[i]
		var d := Vector2((site.point as Vector3).x - at.x, (site.point as Vector3).z - at.z).length()
		if int(site.wing) == motion.wing() and d <= reach: out.append([d, i])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out

## To the nearest site she can reach with no door on the way.
func stalk() -> bool:
	for near in sites_near(STALK_REACH):
		if go_to_site(int(near[1])):
			stalk_at = int(near[1])
			settle_clock = 0.0
			return true
	return false

## The order to a site: onto a door's band from her room's side, held at its
## lintel; into an aisle and up its shelf; or over the ceiling to it.
func go_to_site(i: int) -> bool:
	var site: Dictionary = creature.stalk_sites[i]
	var shell = creature.shell
	var room := int(site.room)
	match String(site.kind):
		"door":
			var start: Vector3 = shell.anchor_of(shell.band_start(int(site.patch), room))
			return order({"room": room, "point": start, "surface": true}, [], [{"kind": "tray", "to": Vector2(start.x, start.z), "room": room, "hang": NAN}, {"kind": "band", "patch": int(site.patch), "dir": int(site.dir), "v": 0.0, "stop": float(site.u)}])
		"aisle":
			var mouth: Vector3 = shell.anchor_of(shell.channel_mouth(int(site.patch)))
			return order({"room": room, "point": mouth, "surface": true}, [], [{"kind": "into_channel", "patch": int(site.patch)}, {"kind": "channel", "patch": int(site.patch), "v_to": float(site.v), "u_goal": float(site.u)}])
	return order({"room": room, "point": site.point, "surface": true}, [])

## Every tick: still at her site she settles; off it, she has left it.
func watch_site(delta: float) -> void:
	var motion = creature.motion
	if stalk_at < 0 or stalk_at >= creature.stalk_sites.size():
		stalk_at = -1
		settle_clock = 0.0
		return
	if not motion.legs.is_empty():
		settle_clock = 0.0
		return
	var point: Vector3 = creature.stalk_sites[stalk_at].point
	var at: Vector3 = motion.anchor()
	if not motion.surface() or Vector2(at.x - point.x, at.z - point.z).length() > SITE_NEAR or absf(at.y - point.y) > SITE_NEAR + SHELL.HANG_MAX:
		stalk_at = -1
		settle_clock = 0.0
		return
	settle_clock += delta

func settled() -> bool: return stalk_at >= 0 and settle_clock >= SETTLE

## Shows herself at the edge of somebody's view: her peek, and the host's
## judgement of whom it frightens.
func peek() -> void:
	creature.intent_clip = "peek"
	pose_clock = PEEK_POSE
	level.match_net.lurker_peek()

## Sent off by the host (lurker.scared_here()): out of her site, and with a
## flash, her eyes white from `from`'s side.
func scared(flash: bool, from: Vector3) -> void:
	stalk_at = -1
	settle_clock = 0.0
	creature.intent_clip = "scare"
	pose_clock = SCARE_POSE
	if flash: view.flash((from - camera.global_position).normalized())

## A way in and out of hers: a grille, a gap or a tile of a room she has a
## ceiling in; never the survivors' hatch.
func usable(e: int) -> bool:
	var exit: Dictionary = creature.ducts.exits[e]
	return String(exit.kind) != "hatch" and int(exit.node) >= 0 and creature.shell.tray_of.has(int(exit.room)) and creature.routes.exit_usable(e)
