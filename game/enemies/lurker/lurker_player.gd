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
## it does not draw. Through a grille, a tile or a duct it cuts to black; at
## rest in a grille's mouth it looks out of it (the ducts' plan is phase 2's).
## lurker_stalk, lurker_release, lurker_drink and lurker_peek are declared
## (settings_service.LURKER_ACTIONS) and do nothing yet (phases 1 to 4).
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const VISUAL := preload("res://game/enemies/lurker/lurker_visual.gd")
const PAD_FEEL := preload("res://game/player/pad_feel.gd")
var pad := PAD_FEEL.new()
## Pushed at a door within this of its doorway (plan metres), this near its
## way (cosine); along an aisle the same, at its mouth.
const DOOR_REACH := 1.6
const PUSH_TOWARD := 0.6
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
	var facing: Vector3 = creature.global_basis.z
	yaw = atan2(-facing.x, -facing.z) if Vector2(facing.x, facing.z).length() > 0.1 else 0.0

func can_act() -> bool:
	return active and creature.control == "player" and level.session.state == level.session.State.PLAYING and not level.online_menu

func _unhandled_input(event: InputEvent) -> void:
	if scripted or not can_act(): return
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
func drive(_delta: float) -> void:
	var motion = creature.motion
	if not scripted:
		axis = Input.get_vector("left", "right", "forward", "backward") if can_act() else Vector2.ZERO
		for action in [&"lurker_enter", &"lurker_drop"]:
			if InputMap.has_action(action) and Input.is_action_just_pressed(action): asked[action] = true
	var free: bool = (scripted or can_act()) and creature.grace <= 0.0
	var ahead := forward()
	var push := Vector3(-ahead.z, 0, ahead.x) * axis.x - ahead * axis.y
	if into_exit >= 0 and motion.legs.is_empty():
		if motion.in_duct: motion.mouth_exit = into_exit
		into_exit = -1
	motion.steering = true
	motion.free_face = ahead
	motion.free_way = push if free and motion.legs.is_empty() else Vector3.ZERO
	if free and motion.legs.is_empty():
		motion.pace = top_pace() * minf(push.length(), 1.0)
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
		var hit: Dictionary = creature.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, face, 1, [creature.get_rid()]))
		return [face] if hit.is_empty() else [(hit.position as Vector3) + (at - face).normalized() * EYE_CLEAR]
	if motion.in_duct and motion.legs.is_empty() and motion.mouth_exit >= 0:
		var exit: Dictionary = creature.ducts.exits[motion.mouth_exit]
		if String(exit.kind) != "tile": return [(exit.position as Vector3) + (exit.normal as Vector3) * GRILLE_OUT]
	return []

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
	var motion = creature.motion
	if not motion.transit.is_empty(): return false
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
		motion.run_legs(inside.legs + out.legs, top_pace())
		return true
	return false

## A way in and out of hers: a grille, a gap or a tile of a room she has a
## ceiling in; never the survivors' hatch.
func usable(e: int) -> bool:
	var exit: Dictionary = creature.ducts.exits[e]
	return String(exit.kind) != "hatch" and int(exit.node) >= 0 and creature.shell.tray_of.has(int(exit.room)) and creature.routes.exit_usable(e)
