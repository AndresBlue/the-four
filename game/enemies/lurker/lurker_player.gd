extends Node
## Versus: a player is The Lurker (.claude/specs/lurker_versus.md 5, remade by
## 13 and 13.9 after the author's first two games). Reads the pad, or the keys
## and the mouse.
##
## Her place is the plenum (13.1): over the false ceiling of her planta, one
## plan, crawled by this driver itself (plenum_step()): her point moves with a
## live ramp and slides along whatever stops it, which is the edge of the
## building and the cores (rooms with no ceiling of hers); her view shows both
## standing up to the slab. One plenum a planta: no fire walls over the
## ceiling (13.9). Nothing else moves her by itself. Two paces: the normal one, heard below (her motion is hidden as
## in a duct, and lurker_voice creaks the tiles and lets dust fall in the room
## under her), and a slow silent one while lurker_sneak is held. Over a service
## gallery, with no false ceiling, she clings to the slab as on any ceiling,
## in sight (her motion's free leg).
##
## The camera is always behind and over her (13.9): over the ceiling looking
## down, lurker_view.gd drawing what is under it as if it were not there; down
## in a room, beside and under her looking where she looks, and on her prey
## through her attack, her warning and her take; in the ducts, over her as over
## the plenum. lurker_drop lets her down by the tile
## under her into the room, and back up. The
## attack (lurker_release) on her marked prey (the survivor nearest the middle
## of her view) crawls to the tile behind it, drops and asks the host for her
## warning (match_net.lurker_release(), judged as ever). lurker_double leaves
## her double lying in wait in a corner of the room she is in or over
## (match_net.lurker_double(), the author's Doppelganger of 18 November 2026,
## which replaced her trips along the ducts). Blinded or looked at in the light, the host sends her off
## (scared()): her body bolts in and comes up in the plenum; sent off half way
## through a tile, she bolts once she is on the ceiling it takes her to.
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const VISUAL := preload("res://game/enemies/lurker/lurker_visual.gd")
const PAD_FEEL := preload("res://game/player/pad_feel.gd")
const VIEW := preload("res://game/enemies/lurker/lurker_view.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
## Her paces in the plenum (m/s), and how far round her point nothing may stop.
const PACE := 4.5
const SNEAK_PACE := 1.5
const RADIUS := 0.3
## Her point this high over the tray of a false ceiling (on its tiles), easing
## between two heights this fast.
const RISE := 0.12
const CLIMB_RATE := 3.0
## The camera: this far behind and over what it looks at, which is this high
## over her; between ZOOM's ends, by the wheel or lurker_zoom's steps; tilted
## down within TILT. It may look down from over her planta's slab (the floor
## draws her planta round her ear): her ear stays under CAMERA_TOP over her
## planta's floor, where the camera was, and the floor hears and draws from
## it. Changing between over her and down in a room takes BLEND s. It looks
## LEAD metres ahead of her and LOOK_DOWN under her, so she is low in the
## picture and what she goes to is in its middle, not under her. FOV over the ceiling, narrower than
## down in a room (FOV_DOWN), so a survivor under her reads at a glance.
const DISTANCE := 4.0
const LEAD := 5.0
const LOOK_DOWN := 1.5
const CAMERA_TOP := 4.8
const FOV := 58.0
const FOV_DOWN := 74.0
## Down in a room her ceiling leaves no room over her: the camera is
## DOWN_DISTANCE behind her face, DOWN_SIDE to the side with more room and
## DOWN_UNDER under it, looking where she looks (pitch within DOWN_PITCH,
## LEAD_DOWN ahead of her face), so she sits in an upper corner of the
## picture and the room fills the rest; kept CAMERA_CLEAR off what stands
## between. In her attack, her warning and her take it frames her prey:
## STRIKE_BACK behind her from it, STRIKE_SIDE aside and STRIKE_UNDER under her
## face, she in the foreground to one side, eased in over BLEND.
const LEAD_DOWN := 3.5
const DOWN_DISTANCE := 2.6
const DOWN_SIDE := 1.0
const DOWN_UNDER := 0.7
const DOWN_PITCH := Vector2(-1.2, 0.5)
const DOWN_START := -0.35
const STRIKE_BACK := 1.6
const STRIKE_SIDE := 1.1
const STRIKE_UNDER := 0.5
const CAMERA_CLEAR := 0.25
const CAMERA_MASK := 1 | 8 | 128
const ZOOM := Vector2(3.5, 9.0)
const ZOOM_STEPS := [4.0, 6.0, 8.0]
const ZOOM_WHEEL := 0.35
const FOCUS_UP := 0.35
const TILT := Vector2(-1.4, -0.5)
const BLEND := 0.35
## Through a tile she squeezes this fast (her motion's bolt pace).
const SQUEEZE := 2.5
## Her prey: whom she sees through the ceiling (13.6 A2) within PREY_REACH, the
## one nearest the middle of her view within PREY_CONE (cosine). Its marker is
## worked out every MARK_EVERY.
const PREY_REACH := 20.0
const PREY_CONE := 0.6
const MARK_EVERY := 0.1
## The attack: the tile she drops by is behind her prey (BEHIND, cosine), this
## many metres back tried in turn, within the host's reach of its eye
## (lurker.LOOSE_REACH, CHARGED_REACH with her charge); she crawls to it from
## no further than CRAWL_REACH, at CRAWL_SPEED. Down, a guest waits RELEASE_LAG
## for the host's copy of her to land too; no warning in GIVE_UP and she stays
## down.
const BACK_STEPS := [1.8, 1.2, 2.6]
const CHARGED_STEPS := [4.0, 5.5]
const BEHIND := 0.3
const CRAWL_REACH := 6.0
const CRAWL_SPEED := 10.0
const RELEASE_LAG := 0.25
const GIVE_UP := 0.8
## Her face this far under the tile she drops by; the way she crawls to it
## looked at every CRAWL_STEP metres.
const FACE_DROP := 0.5
const CRAWL_STEP := 0.5
## The host's waits she cannot see (lurker.FLASH_WAIT, SAME_PREY) and its
## charge (CHARGE, its look off her within LOOK_OFF).
const FLASH_WAIT := 6.0
const SAME_PREY := 4.0
const CHARGE := 2.0
const LOOK_OFF := 0.8
## The pose of a peek, and of a fright, held this long; how long the picture
## closes in when she is sent off.
const PEEK_POSE := 1.2
const SCARE_POSE := 0.4
const FLED_FOR := 1.1
var pad := PAD_FEEL.new()
var view
var creature
var level
var camera: Camera3D
var ear: AudioListener3D
var yaw := 0.0
var pitch := -0.25
var tilt := -1.0
var distance := DISTANCE
## Where the camera is: "above" (over her, over the ceiling), "down" (behind
## her in a room, or under a gallery's slab), "ducts" (over her in the ducts or
## crossing to another planta); what it looks at at the last two physics
## ticks, and the blend from the transform drawn when the mode changed.
var mode := "above"
var focus_from := Vector3.INF
var focus_to := Vector3.INF
var blend_from := Transform3D.IDENTITY
var blend_left := 0.0
var drawn := Transform3D.IDENTITY
## Down: the side the camera sits on (1 her right, -1 her left), picked on the
## way down; how far it frames her prey (0..1), and whose (seat, -1 none: kept
## through her warning and her take, after her attack is over).
var side := 1.0
var strike := 0.0
var struck := -1
var struck_at := Vector3.INF
## The scripted driver (the tests) writes `axis` (left stick: x right, y back),
## `asked` and `sneak_held` itself and the devices are not read.
var scripted := false
var axis := Vector2.ZERO
var asked := {}
var sneak_held := false
var active := true
var clock := 0.0
var started := false
var sneaking := false
## Her pace in the plenum, flat (x, z).
var velocity := Vector2.ZERO
var crossing_was := false
var cue_was := false
var raise_when_out := false
## Her marked prey (seat, -1 none) and what its marker says: {ok, why
## ("wait", "look", "light", "far" or ""), wait (0..1 left), drop, charged}.
var prey := -1
var prey_info := {}
var mark_clock := 0.0
var charge := 0.0
## seat -> clock of her last attack on it; until when the host keeps her
## waiting after a flash; when she was last sent off.
var attacked := {}
## Her last attack on anybody: the host makes her wait lurker.attack_wait()
## between two, by how many are alive on her planta.
var last_attack := -INF
var flashed_until := -INF
var fled_at := -INF
## Whence she was sent off, until she is in (INF none).
var fled_from := Vector3.INF
## Her attack under way: {phase ("crawl", "drop", "land", "wait"), seat, drop, clock}.
var attack := {}
## When she last left her double (the host keeps her waiting lurker.DOUBLE_EVERY).
var doubled_at := -INF
## seat -> [her attacks on it that still count, clock of the last]: her own
## reckoning of the host's repeats (lurker.parries), for her disc.
var strikes := {}
var pose_clock := 0.0
## Room -> its plenum node (the ducts' nearest when it has none).
var plenum_nodes := {}

func setup(owner) -> void:
	creature = owner
	level = owner.level
	name = "Driver"
	camera = Camera3D.new()
	camera.name = "LurkerCamera"
	camera.fov = FOV
	camera.near = 0.05
	camera.far = 200.0
	# Not her own body nor its ink: a blot over her own eyes.
	camera.cull_mask = 0xFFFFF & ~VISUAL.LAYER
	add_child(camera)
	ear = AudioListener3D.new()
	ear.name = "Ear"
	add_child(ear)
	var cover := CanvasLayer.new()
	cover.layer = 90
	add_child(cover)
	view = VIEW.new()
	add_child(view)
	view.setup(self, cover)
	var facing: Vector3 = creature.global_basis.z
	yaw = atan2(-facing.x, -facing.z) if Vector2(facing.x, facing.z).length() > 0.1 else 0.0

func can_act() -> bool:
	return active and creature.control == "player" and level.session.state == level.session.State.PLAYING and not level.online_menu

func _unhandled_input(event: InputEvent) -> void:
	if scripted or not can_act(): return
	# The test order for the flash: F8, in a build with the debug tools.
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		view.flash(view.nearest_survivor_way())
	pad.pressed(event, level.settings)
	if event is InputEventMouseMotion:
		var sensitivity: float = level.settings.values.sensitivity
		look_by(Vector2(-event.relative.x, -event.relative.y) * sensitivity)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		distance = clampf(distance + (-ZOOM_WHEEL if event.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_WHEEL), ZOOM.x, ZOOM.y)

func look_by(amount: Vector2) -> void:
	yaw = wrapf(yaw + amount.x, -PI, PI)
	var turn: float = amount.y * (-1.0 if level.settings != null and level.settings.values.invert else 1.0)
	if mode == "down": pitch = clampf(pitch + turn, DOWN_PITCH.x, DOWN_PITCH.y)
	else: tilt = clampf(tilt + turn, TILT.x, TILT.y)

## Where the camera looks, flat.
func forward() -> Vector3: return Vector3(-sin(yaw), 0, -cos(yaw))

## The stick, flat in the world, the way the camera looks.
func push() -> Vector3:
	var ahead := forward()
	return Vector3(-ahead.z, 0, ahead.x) * axis.x - ahead * axis.y

## Her top pace down on a ceiling: the AI's unseen pace for her difficulty,
## and her scurry at least.
func top_pace() -> float: return maxf(float(creature.unseen_speed), MOTION.SCURRY_SPEED)

func now() -> float: return clock

# --- Every tick ---------------------------------------------------------------------

## Every physics tick, before her motion's (lurker.step_physics()).
func drive(delta: float) -> void:
	clock += delta
	var motion = creature.motion
	if not scripted:
		var acting := can_act()
		axis = Input.get_vector("left", "right", "forward", "backward") if acting else Vector2.ZERO
		sneak_held = acting and InputMap.has_action(&"lurker_sneak") and Input.is_action_pressed(&"lurker_sneak")
		for action in [&"lurker_double", &"lurker_drop", &"lurker_peek", &"lurker_release", &"lurker_drink", &"lurker_zoom"]:
			if acting and InputMap.has_action(action) and Input.is_action_just_pressed(action): asked[action] = true
	# The pad's zoom steps out, and from the farthest back to the nearest.
	if asked.has(&"lurker_zoom"):
		var next := float(ZOOM_STEPS[0])
		for step: float in ZOOM_STEPS:
			if step > distance + 0.05:
				next = step
				break
		distance = next
	var free: bool = (scripted or can_act()) and creature.grace <= 0.0
	motion.steering = true
	motion.free_face = forward()
	motion.free_way = Vector3.ZERO
	if motion.legs.is_empty() and motion.bolting and not motion.in_duct: motion.bolting = false
	pose_clock -= delta
	if pose_clock <= 0.0 and creature.intent_clip in ["peek", "scare"]: creature.intent_clip = ""
	var crossing: bool = not motion.transit.is_empty()
	if crossing_was and not crossing: raise_when_out = true
	crossing_was = crossing
	if not started and motion.state != null and not crossing:
		started = true
		to_plenum(motion.anchor(), motion.room())
	if crossing:
		attack = {}
		sneaking = false
	# Out of the ducts after a bolt (or a test's placing): up into her plenum.
	elif motion.in_duct and not motion.plenum and motion.legs.is_empty(): to_plenum(motion.duct_point, int(creature.ducts.exits[motion.mouth_exit].room) if motion.mouth_exit >= 0 else -1)
	elif raise_when_out and motion.surface() and motion.legs.is_empty():
		raise_when_out = false
		to_plenum(motion.anchor(), motion.room())
	if motion.on_floor and motion.legs.is_empty() and not creature.cue: motion.climb_back()
	# Her warning over, she is no longer let down as far as it took her.
	if cue_was and not creature.cue and motion.surface() and motion.state.lowered: motion.drop(false)
	cue_was = creature.cue
	# Sent off with no ceiling under her to bolt from (half way down a tile, her
	# attack's drop) or held in her take's scene: once she is on one, free and
	# with nothing under way, the bolt.
	if motion.in_duct: fled_from = Vector3.INF
	elif fled_from != Vector3.INF and motion.surface() and motion.legs.is_empty() and not creature.scene_held:
		if not motion.bolt(fled_from): motion.place_in_duct(creature.ducts.nearest_node(motion.anchor()))
		fled_from = Vector3.INF
	mark_clock -= delta
	if mark_clock <= 0.0:
		mark_clock = MARK_EVERY
		mark_prey()
	watch_charge(delta)
	if not attack.is_empty(): attack_step(delta)
	elif crossing: pass
	elif motion.plenum: plenum_step(delta, free)
	elif motion.surface() and motion.legs.is_empty(): surface_step(free)
	if not motion.plenum: sneaking = false
	asked.clear()
	# Landed for her attack she looks at her prey at once (the camera is still easing down).
	var one = body_of(int(attack.seat)) if String(attack.get("phase", "")) in ["land", "wait"] else null
	# Down, where she looks from her own face (her camera is off to a side).
	var looks: Vector3 = creature.face_point() + look_way() * 10.0 if mode == "down" else camera.global_position - camera.global_basis.z * 10.0
	if creature.visual != null: creature.visual.look_point = one.camera.global_position if one != null else looks
	if not scripted and is_instance_valid(level.get("camcorder")):
		level.camcorder.announce("%d" % int(ceil(creature.grace)) if creature.grace > 0.0 else "")

## After her motion's tick (a child's physics comes after its parent's): what
## the camera looks at now. Along the ducts it turns to her way.
func _physics_process(delta: float) -> void:
	if creature == null or creature.motion == null: return
	var was := mode
	mode = camera_mode()
	var at := focus()
	if mode == "down" and was != "down":
		pitch = DOWN_START
		side = roomier_side(at)
	strike = move_toward(strike, 1.0 if mode == "down" and strike_point() != Vector3.INF else 0.0, delta / BLEND)
	if was != mode or focus_to == Vector3.INF:
		# From the camera as last drawn: the move up into the plenum, or down into a room, is seen.
		blend_from = drawn
		blend_left = BLEND if drawn != Transform3D.IDENTITY else 0.0
		focus_from = at
	else: focus_from = focus_to
	focus_to = at

func camera_mode() -> String:
	var motion = creature.motion
	if not motion.transit.is_empty(): return "ducts"
	var squeezing: bool = not motion.legs.is_empty() and String(motion.legs[0].kind) == "squeeze"
	if motion.plenum or squeezing or String(attack.get("phase", "")) in ["crawl", "drop"]: return "above"
	# In a duct on her way up (a bolt's end): over her.
	if motion.in_duct: return "above"
	return "down"

## Over a service gallery's slab, not let down: her plenum there.
func gallery() -> bool:
	var motion = creature.motion
	if not motion.surface() or motion.state.lowered or int(creature.shell.patches[motion.state.patch].kind) != SHELL.Kind.TRAY: return false
	var room: int = motion.room()
	return room >= 0 and not OFFICE.false_ceiling(level.manifest.rooms[room])

## Whether she is in her layer (the plenum or a gallery's slab): what her
## marker and her keys go by.
func up() -> bool: return creature.motion.plenum or gallery()

## What the camera looks at: down in a room, her face; else over her.
func focus() -> Vector3:
	if mode == "down": return creature.face_point() + Vector3(0, 0.15, 0)
	return creature.motion.anchor() + Vector3(0, FOCUS_UP, 0)

## Where she looks down in a room (the mouse's pitch and yaw).
func look_way() -> Vector3: return Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD

## The camera round `at` as the mouse has it now: behind and over her, kept
## under the planta above; or down in a room beside and under her, looking
## where she looks or, in her attack, at her prey, kept off what stands between.
func camera_at(at: Vector3) -> Transform3D:
	if mode == "down":
		var ahead := forward()
		var right := Vector3(-ahead.z, 0, ahead.x)
		var look: Vector3 = at + look_way() * LEAD_DOWN
		var place: Vector3 = at - ahead * DOWN_DISTANCE + right * side * DOWN_SIDE - Vector3(0, DOWN_UNDER, 0)
		# Short of room on that side (a wall behind her): the other side,
		# straight behind or well under her, whichever leaves more, or the
		# camera ends in her body.
		var room: float = kept_clear(at, place).distance_to(at)
		if room < DOWN_DISTANCE * 0.7:
			for instead: Vector3 in [at - ahead * DOWN_DISTANCE - right * side * DOWN_SIDE - Vector3(0, DOWN_UNDER, 0), at - ahead * DOWN_DISTANCE - Vector3(0, DOWN_UNDER, 0), at - ahead * 1.2 - Vector3(0, DOWN_UNDER * 2.0, 0)]:
				var more: float = kept_clear(at, instead).distance_to(at)
				if more > room + 0.3:
					room = more
					place = instead
		if strike > 0.0 and struck_at != Vector3.INF:
			var away := Vector3(at.x - struck_at.x, 0, at.z - struck_at.z)
			away = away.normalized() if away.length() > 0.1 else -ahead
			var framed: Vector3 = at + away * STRIKE_BACK + Vector3(away.z, 0, -away.x) * side * STRIKE_SIDE - Vector3(0, STRIKE_UNDER, 0)
			var t := smoothstep(0.0, 1.0, strike)
			place = place.lerp(framed, t)
			look = look.lerp(struck_at, t)
		place = kept_clear(at, place)
		return Transform3D(Basis.looking_at(look - place), place)
	var over := Basis.from_euler(Vector3(tilt, yaw, 0.0))
	var from: Vector3 = at + over.z * distance
	return Transform3D(Basis.looking_at(at + forward() * LEAD - Vector3(0, LOOK_DOWN, 0) - from), from)

## `place` under her ceiling and short of whatever stands between it and `at`.
func kept_clear(at: Vector3, place: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = creature.get_world_3d().direct_space_state
	var lid: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.UP * 3.0, CAMERA_MASK, [creature.get_rid()]))
	if not lid.is_empty(): place.y = minf(place.y, (lid.position as Vector3).y - CAMERA_CLEAR)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at, place, CAMERA_MASK, [creature.get_rid()]))
	if not hit.is_empty(): place = at + (place - at).normalized() * maxf(at.distance_to(hit.position) - CAMERA_CLEAR, 0.1)
	return place

## The side of her (1 right, -1 left) where the camera has more room, right on a tie.
func roomier_side(at: Vector3) -> float:
	var ahead := forward()
	var right := Vector3(-ahead.z, 0, ahead.x)
	var room := {}
	for s: float in [1.0, -1.0]:
		var place: Vector3 = at - ahead * DOWN_DISTANCE + right * s * DOWN_SIDE - Vector3(0, DOWN_UNDER, 0)
		room[s] = kept_clear(at, place).distance_to(at)
	return 1.0 if float(room[1.0]) >= float(room[-1.0]) - 0.05 else -1.0

## Her prey's chest while the camera frames it (her attack, her warning, her
## take), INF none; let go when all of that is over.
func strike_point() -> Vector3:
	if struck < 0: return Vector3.INF
	if attack.is_empty() and not creature.cue and level.execution.is_empty():
		struck = -1
		struck_at = Vector3.INF
		return Vector3.INF
	var one = body_of(struck)
	if one != null: struck_at = one.global_position + Vector3(0, 1.1, 0)
	return struck_at

func _process(delta: float) -> void:
	if creature == null or level == null: return
	if not scripted and can_act() and level.settings != null:
		var turn := pad.look(delta, level.settings)
		if turn != Vector2.ZERO: look_by(turn)
	if focus_to == Vector3.INF: return
	# Turned at once, between the physics ticks for her place.
	var target := camera_at(focus_from.lerp(focus_to, Engine.get_physics_interpolation_fraction()))
	if blend_left > 0.0:
		blend_left = maxf(0.0, blend_left - delta)
		var t: float = smoothstep(0.0, 1.0, 1.0 - blend_left / BLEND)
		target = Transform3D(blend_from.basis.slerp(target.basis, t), blend_from.origin.lerp(target.origin, t))
	camera.global_transform = target
	camera.fov = move_toward(camera.fov, FOV_DOWN if mode == "down" else FOV, (FOV_DOWN - FOV) / BLEND * delta)
	drawn = target
	# Her ear where the camera is, kept on her planta.
	ear.global_position = Vector3(target.origin.x, minf(target.origin.y, FLOOR.planta_y(planta()) + CAMERA_TOP), target.origin.z)
	ear.global_basis = target.basis
	if camera.current and not ear.is_current(): ear.make_current()
	elif not camera.current and ear.is_current(): ear.clear_current()

# --- The plenum (13.1) -------------------------------------------------------------

## The room under a plan point of her planta, {} none.
func room_under(p: Vector2) -> Dictionary:
	return FLOOR.room_at(level.manifest.rooms, Vector3(p.x, FLOOR.planta_y(planta()) + 1.0, p.y))

func planta() -> int: return FLOOR.planta_of(creature.motion.anchor().y - 0.5)

## Whether her body may be over a plan point: a ceiling of hers. One plenum a
## planta, the departments' fire walls stop at the ceiling (13.9).
func open_at(p: Vector2) -> bool:
	var room := room_under(p)
	return not room.is_empty() and creature.shell.tray_of.has(int(room.id))

## Whether she may crawl straight from one plan point to another.
func open_way(from: Vector2, to: Vector2) -> bool:
	var steps := ceili(from.distance_to(to) / CRAWL_STEP)
	for k in range(1, steps + 1):
		if not open_at(from.lerp(to, float(k) / steps)): return false
	return true

## Her point's height over a room: on its false ceiling, or at its slab.
func layer_y(room: int) -> float:
	var tray: Dictionary = creature.shell.patches[int(creature.shell.tray_of[room])]
	return float(tray.y) + (RISE if OFFICE.false_ceiling(level.manifest.rooms[room]) else 0.0)

func plenum_node(room: int, at: Vector3) -> int:
	if not plenum_nodes.has(room): plenum_nodes[room] = int(creature.ducts.plenum_node.get(room, creature.ducts.nearest_node(at)))
	return int(plenum_nodes[room])

## Up into her layer over a point (a room of hers, `hint` when the point is
## on its wall, the nearest ceiling else): the plenum, or a gallery's slab.
func to_plenum(at: Vector3, hint := -1) -> void:
	var motion = creature.motion
	var shell = creature.shell
	raise_when_out = false
	started = true
	var p := Vector2(at.x, at.z)
	var room := int(FLOOR.room_at(level.manifest.rooms, Vector3(at.x, FLOOR.planta_y(FLOOR.planta_of(at.y - 0.5)) + 1.0, at.z)).get("id", -1))
	if not shell.tray_of.has(room):
		if shell.tray_of.has(hint): room = hint
		else:
			var s = shell.state_at(at)
			if s == null: return
			room = shell.room_of(s)
	var rect: Rect2 = (shell.patches[int(shell.tray_of[room])].rect as Rect2).grow(-RADIUS - 0.05)
	p = Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	velocity = Vector2.ZERO
	var y := layer_y(room)
	if OFFICE.false_ceiling(level.manifest.rooms[room]): motion.place_in_plenum(Vector3(p.x, y, p.y), plenum_node(room, Vector3(p.x, y, p.y)))
	else: motion.place_at(Vector3(p.x, y, p.y), forward(), &"plenum")

## Her crawl over the false ceiling this tick: the stick's pace, ramped, each
## flat part of the step kept only where nothing stops her (she slides).
func plenum_step(delta: float, free: bool) -> void:
	var motion = creature.motion
	sneaking = free and sneak_held
	var way := push() if free else Vector3.ZERO
	var want := Vector2(way.x, way.z).limit_length(1.0) * (SNEAK_PACE if sneaking else PACE)
	velocity = velocity.move_toward(want, (MOTION.FREE_ACCEL if want.length() > velocity.length() else MOTION.FREE_BRAKE) * delta)
	var at: Vector3 = motion.point
	var p := Vector2(at.x, at.z)
	var step := velocity * delta
	if absf(step.x) > 1e-6 and not open_at(Vector2(p.x + step.x + signf(step.x) * RADIUS, p.y)):
		step.x = 0.0
		velocity.x = 0.0
	if absf(step.y) > 1e-6 and not open_at(Vector2(p.x + step.x, p.y + step.y + signf(step.y) * RADIUS)):
		step.y = 0.0
		velocity.y = 0.0
	p += step
	var room := int(room_under(p).get("id", -1))
	if room < 0 or not creature.shell.tray_of.has(room): return
	# Onto a gallery's slab: her motion's ceiling there, in sight.
	if not OFFICE.false_ceiling(level.manifest.rooms[room]):
		motion.place_at(Vector3(p.x, layer_y(room), p.y), Vector3(velocity.x, 0, velocity.y) if velocity.length() > 0.1 else forward(), &"plenum")
		return
	var y := move_toward(at.y, layer_y(room), CLIMB_RATE * delta)
	var heading := Vector3(velocity.x, 0, velocity.y) if velocity.length() > 0.1 else forward()
	motion.crawl(Vector3(p.x, y, p.y), plenum_node(room, at), heading)
	motion.speed = velocity.length()
	if not free: return
	if asked.has(&"lurker_release"): attack_now()
	elif asked.has(&"lurker_drop"): go_down()
	elif asked.has(&"lurker_double"): double()

## On a ceiling with no order running: down in a room, or over a gallery.
func surface_step(free: bool) -> void:
	var motion = creature.motion
	var on_gallery := gallery()
	var way := push()
	if free:
		motion.free_way = way
		motion.pace = (PACE if on_gallery and not sneak_held else top_pace()) * minf(way.length(), 1.0)
		if on_gallery and sneak_held: motion.pace = SNEAK_PACE * minf(way.length(), 1.0)
		# During her warning no faster than a walker: running always saves (7).
		if creature.cue: motion.pace = minf(motion.pace, BRAIN.CUE_FOLLOW)
	if not free: return
	if asked.has(&"lurker_release"): attack_now()
	if asked.has(&"lurker_drink"): level.match_net.lurker_drink()
	if asked.has(&"lurker_peek") and not on_gallery: peek()
	if asked.has(&"lurker_double"): double()
	if asked.has(&"lurker_drop"):
		if on_gallery or (motion.state.lowered and not OFFICE.false_ceiling(level.manifest.rooms[motion.room()])): motion.drop(not motion.state.lowered)
		else: go_up()
		return
	# Off a gallery's slab onto a false ceiling of her department: into its plenum.
	if on_gallery and way.length() > 0.3:
		var at: Vector3 = motion.anchor()
		var ahead := Vector2(at.x, at.z) + Vector2(way.x, way.z).normalized() * (RADIUS + 0.2)
		var room := room_under(ahead)
		if not room.is_empty() and OFFICE.false_ceiling(room) and open_at(ahead):
			velocity = Vector2(way.x, way.z).normalized() * motion.speed
			motion.place_in_plenum(Vector3(ahead.x, layer_y(int(room.id)), ahead.y), plenum_node(int(room.id), at))

# --- Down and up (13.3) -------------------------------------------------------------

## The tile she would go down by now: the one of the room under her nearest
## her, {room, tile, exit, point}; {} with none.
func down_way() -> Dictionary:
	var motion = creature.motion
	if not motion.plenum: return {}
	return tile_way(motion.point)

func tile_way(at: Vector3) -> Dictionary:
	var ducts = creature.ducts
	var room := int(room_under(Vector2(at.x, at.z)).get("id", -1))
	if room < 0 or not ducts.room_tiles.has(room) or not creature.shell.tray_of.has(room): return {}
	var e := -1
	for i in ducts.exits_of_room(room):
		if String(ducts.exits[i].kind) == "tile": e = i
	if e < 0: return {}
	var tile: Vector2i = ducts.tile_near(room, at)
	return {"room": room, "tile": tile, "exit": e, "point": ducts.tile_point(room, tile)}

## Down by a tile into its room: lifted, through, and onto its ceiling under it.
func go_down(way := {}) -> bool:
	var motion = creature.motion
	if way.is_empty(): way = down_way()
	if way.is_empty(): return false
	var shell = creature.shell
	var room := int(way.room)
	var through: Vector3 = way.point
	var s = shell.tray_state(room, through.x, through.z)
	var basis: Basis = creature.routes.tray_basis(room, Vector2(through.x, through.z), Vector2(forward().x, forward().z))
	var leg := {"kind": "squeeze", "from": motion.point, "to": shell.anchor_of(s), "into": false, "exit": int(way.exit), "basis": basis, "room": room, "tile": way.tile}
	motion.plenum = false
	raise_when_out = false
	velocity = Vector2.ZERO
	motion.run_legs([leg], top_pace())
	squeeze_fast()
	return true

## Up by the tile nearest her into the plenum over her room.
func go_up() -> bool:
	var motion = creature.motion
	var way := tile_way(motion.anchor())
	if way.is_empty():
		to_plenum(motion.anchor(), motion.room())
		return true
	var through: Vector3 = way.point
	var leg := {"kind": "squeeze", "from": motion.anchor(), "to": through + Vector3(0, RISE, 0), "into": true, "exit": int(way.exit), "basis": motion.transform().basis, "room": int(way.room), "tile": way.tile}
	motion.run_legs([leg], top_pace())
	squeeze_fast()
	return true

## Through a tile at SQUEEZE (her motion's bolt pace), not the AI's crawl.
func squeeze_fast() -> void:
	var motion = creature.motion
	motion.bolting = true
	motion.bolt_speed = SQUEEZE

# --- Her prey and the attack (13.3) -----------------------------------------------------

## The survivor nearest the middle of her view she can mark (through the
## ceiling within PREY_REACH; down, the same), and what its marker says.
func mark_prey() -> void:
	var at: Vector3 = creature.motion.anchor()
	var looks: Vector3 = -camera.global_basis.z
	var best := -1
	var best_dot := PREY_CONE
	var here := planta()
	for one in level.survivors():
		if not markable(one, at, here): continue
		var chest: Vector3 = one.global_position + Vector3(0, 1.1, 0)
		var dot: float = looks.dot((chest - camera.global_position).normalized())
		if dot > best_dot:
			best_dot = dot
			best = int(one.slot)
	if best != prey: charge = 0.0
	prey = best
	prey_info = judge_prey(body_of(prey)) if prey >= 0 else {}

func markable(one, at: Vector3, here: int) -> bool:
	if not is_instance_valid(one) or not "slot" in one or not level.survivor_active(one) or bool(one.get("hidden")) or not SIGHT.alive(level, one): return false
	if camouflaged(one, at): return false
	var feet: Vector3 = one.global_position
	return FLOOR.planta_of(feet.y + 1.0) == here and Vector2(feet.x - at.x, feet.z - at.z).length() <= PREY_REACH

## Whoever sits at the security post's console is camouflaged from her
## (cordura_y_edificio.md 3.11): no outline, no beacon, no prey, till she is
## within CAMO_REACH of it in plan, as near as her coming puts a decoy out.
const CAMO_REACH := 6.0
func camouflaged(one, at: Vector3) -> bool:
	var air = level.objective(&"air") if level.has_method("objective") else null
	if air == null or not "operator" in air or not "slot" in one or int(air.operator) != int(one.slot): return false
	var feet: Vector3 = one.global_position
	return Vector2(feet.x - at.x, feet.z - at.z).length() > CAMO_REACH

## Survivors alive and in play on her planta, at least one (lurker_senses.team_here()).
func team_here() -> int:
	var here := planta()
	var count := 0
	for one in level.survivors():
		if is_instance_valid(one) and SIGHT.alive(level, one) and level.survivor_active(one) and FLOOR.planta_of(one.global_position.y + 1.0) == here: count += 1
	return maxi(1, count)

func body_of(seat: int):
	for one in level.survivors():
		if is_instance_valid(one) and "slot" in one and int(one.slot) == seat: return one
	return null

## Her charge on her prey, as the host keeps it (lurker.watch_prey()): in the
## plenum, its look off her, CHARGE s.
func watch_charge(delta: float) -> void:
	var one = body_of(prey) if prey >= 0 else null
	if one == null or not creature.motion.plenum:
		if not creature.motion.plenum and attack.is_empty(): charge = 0.0
		return
	var to: Vector3 = creature.motion.anchor() - one.camera.global_position
	if -(one.camera.global_basis.z as Vector3).dot(to.normalized()) >= LOOK_OFF: charge = 0.0
	else: charge = minf(charge + delta, CHARGE)

func charged() -> bool: return charge >= CHARGE - 1e-4

## Her attacks on `seat` that still count (lurker.parry_steps()).
func strike_steps(seat: int) -> float:
	var row: Array = strikes.get(seat, [0.0, -INF])
	return creature.parry_steps(float(row[0]), clock - float(row[1]))

## What an attack on `seat` would cost its mind now, as a share of a fresh
## one (lurker.parried_cost(): down to MIND.repeat_least on the same one).
func strike_share(seat: int) -> float:
	return creature.parried_cost(strike_steps(seat)) / float(creature.MIND.parried)

## What her marker says of `one`: whether the attack may go now, else why not
## (the first of: wait, far, look, light), how much of a wait is left, the
## tile she would drop by and her face there, and what shows why in her view:
## the eye that would see her face or the torch on it (`from`), or the lit
## room the prey stands in (`room`).
func judge_prey(one) -> Dictionary:
	var out := {"ok": false, "why": "", "wait": 0.0, "drop": {}, "charged": charged(), "face": Vector3.INF, "from": Vector3.INF, "room": -1}
	if one == null: return out
	var seat := int(one.slot)
	var waits: Array = [0.0]
	if creature.grace > 0.0: waits.append(1.0)
	if clock < flashed_until: waits.append((flashed_until - clock) / FLASH_WAIT)
	var since := clock - float(attacked.get(seat, -INF))
	if since < SAME_PREY: waits.append(1.0 - since / SAME_PREY)
	var gap: float = creature.attack_wait(team_here())
	if clock - last_attack < gap: waits.append(1.0 - (clock - last_attack) / gap)
	if creature.cue or not attack.is_empty() or not creature.motion.transit.is_empty(): waits.append(1.0)
	# Quiet after a take near it (lurker_brain.sated_on()): known only where she is judged.
	var brain = creature.brain
	if creature.in_charge_here() and brain.clock < brain.sated_until and brain.sated_point != Vector3.INF and (one.global_position as Vector3).distance_to(brain.sated_point) < brain.SATED_NEAR: waits.append((brain.sated_until - brain.clock) / maxf(brain.sated, 0.1))
	out.wait = waits.max()
	if float(out.wait) > 0.0:
		out.why = "wait"
		return out
	var eye: Vector3 = one.camera.global_position
	var face: Vector3
	if creature.motion.plenum:
		var drop := find_drop(one)
		if drop.is_empty():
			out.why = "far"
			return out
		out.drop = drop
		face = drop.face
	else:
		face = creature.face_point()
		if face.distance_to(eye) > (creature.CHARGED_REACH if creature.charged.has(seat) else creature.LOOSE_REACH):
			out.why = "far"
			return out
	out.face = face
	# A torch on where her face would be first: it is a look too, and the worse one.
	var rid: RID = creature.get_rid()
	for body in level.survivors():
		if is_instance_valid(body) and SIGHT.torch_covers(level, body, face, [rid]):
			out.why = "light"
			out.from = body.torch.global_position
			return out
	if not creature.brain.lit_takes and SIGHT.lit_point(level, eye) and not SIGHT.spent(level, one):
		out.why = "light"
		out.room = int(FLOOR.room_at(level.manifest.rooms, eye).get("id", -1))
		return out
	out.from = watcher(face, [rid])
	if out.from != Vector3.INF:
		out.why = "look"
		return out
	out.ok = true
	return out

## The eye of whoever would see `face` (as SIGHT.watched() counts it), INF none.
func watcher(face: Vector3, exclude: Array) -> Vector3:
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body) or not "camera" in body or not is_instance_valid(body.camera) or SIGHT.spent(level, body): continue
		var eye: Vector3 = body.camera.global_position
		var towards: Vector3 = face - eye
		var gap := towards.length()
		if gap > SIGHT.WATCH_REACH or gap < 0.01 or -body.camera.global_basis.z.dot(towards / gap) < SIGHT.WATCH_DOT: continue
		if SIGHT.clear(level, eye, eye + towards, [body.get_rid()] + exclude): return eye
	return Vector3.INF

## The tile behind `one` she would drop by: within the host's reach of its eye
## (more with her charge), behind its look, nothing between her face there and
## its eye, and within CRAWL_REACH of her, straight over her ceilings. {} none.
func find_drop(one) -> Dictionary:
	var feet: Vector3 = one.global_position
	var eye: Vector3 = one.camera.global_position
	var look: Vector3 = -one.camera.global_basis.z
	var back := -Vector2(look.x, look.z).normalized()
	var at: Vector3 = creature.motion.point
	var reach: float = creature.CHARGED_REACH if charged() else creature.LOOSE_REACH
	for metres in BACK_STEPS + (CHARGED_STEPS if charged() else []):
		var aim := Vector2(feet.x, feet.z) + back * float(metres)
		var way := tile_way(Vector3(aim.x, at.y, aim.y))
		if way.is_empty(): continue
		var tile: Vector3 = way.point
		var face := tile - Vector3(0, FACE_DROP, 0)
		var off := Vector2(tile.x - feet.x, tile.z - feet.z)
		if face.distance_to(eye) > reach or off.length() < 0.3 or off.normalized().dot(back) < BEHIND: continue
		if Vector2(tile.x - at.x, tile.z - at.z).length() > CRAWL_REACH or not open_way(Vector2(at.x, at.z), Vector2(tile.x, tile.z)): continue
		if not SIGHT.clear(level, face, eye, [creature.get_rid(), one.get_rid()]): continue
		way["face"] = face
		return way
	return {}

## Attack: from the plenum, the crawl to the tile behind her prey and the drop;
## down, the host is asked at once.
func attack_now() -> void:
	if prey < 0 or not bool(prey_info.get("ok", false)): return
	attacked[prey] = clock
	strikes[prey] = [strike_steps(prey) + 1.0, clock]
	last_attack = clock
	struck = prey
	if creature.motion.plenum:
		attack = {"phase": "crawl", "seat": prey, "drop": prey_info.drop, "clock": 0.0}
		return
	level.match_net.lurker_release()
	attack = {"phase": "wait", "seat": prey, "drop": {}, "clock": 0.0}

func attack_step(delta: float) -> void:
	var motion = creature.motion
	attack.clock = float(attack.clock) + delta
	var one = body_of(int(attack.seat))
	match String(attack.phase):
		"crawl":
			var to: Vector3 = attack.drop.point
			var at: Vector3 = motion.point
			var flat := Vector2(to.x - at.x, to.z - at.z)
			var step := minf(flat.length(), CRAWL_SPEED * delta)
			var p := Vector2(at.x, at.z) + (flat.normalized() * step if flat.length() > 1e-4 else Vector2.ZERO)
			motion.crawl(Vector3(p.x, at.y, p.y), motion.near_node, Vector3(flat.x, 0, flat.y))
			if flat.length() - step < 0.05:
				go_down(attack.drop)
				attack.phase = "drop"
		"drop":
			if motion.surface() and motion.legs.is_empty():
				attack.phase = "land"
				attack.clock = 0.0
		"land":
			# Her look on it, as the host's copy of her will have it (lurker.gaze()).
			if one != null: look_at_point(one.camera.global_position)
			# A tick for her look to be hers here; RELEASE_LAG for the host's copy of her to land.
			var on_host: bool = level.match_net.in_charge()
			if float(attack.clock) >= (2.0 / Engine.physics_ticks_per_second if on_host else RELEASE_LAG):
				level.match_net.lurker_release()
				attack.phase = "wait"
				attack.clock = 0.0
		"wait":
			if creature.cue or float(attack.clock) >= GIVE_UP: attack = {}

func look_at_point(point: Vector3) -> void:
	var to: Vector3 = point - creature.face_point()
	yaw = atan2(-to.x, -to.z)
	pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), DOWN_PITCH.x, DOWN_PITCH.y)

# --- The host's word on her ---------------------------------------------------------

## Kept for her flags and the drain (lurker.settled()): the places to lie in
## wait are her ways down now (13.6 E2), and nobody settles at them.
func settled() -> bool: return false

## Her double left in a corner (lurker.judge_double() on the host).
func double() -> void:
	if clock - doubled_at < creature.DOUBLE_EVERY: return
	doubled_at = clock
	level.match_net.lurker_double()

## Shows herself at the edge of somebody's view: her peek, and the host's
## judgement of whom it frightens.
func peek() -> void:
	creature.intent_clip = "peek"
	pose_clock = PEEK_POSE
	level.match_net.lurker_peek()

## Sent off by the host (lurker.scared_here()): with a flash, her eyes white
## from `from`'s side; the picture closes in while her body bolts in.
func scared(flash: bool, from: Vector3) -> void:
	creature.intent_clip = "scare"
	pose_clock = SCARE_POSE
	fled_at = clock
	fled_from = from
	attack = {}
	struck = -1
	struck_at = Vector3.INF
	if flash:
		flashed_until = clock + FLASH_WAIT
		view.flash((from - camera.global_position).normalized())

## A way in and out of hers: a grille, a gap or a tile of a room she has a
## ceiling in; never the survivors' hatch.
func usable(e: int) -> bool:
	var exit: Dictionary = creature.ducts.exits[e]
	return String(exit.kind) != "hatch" and int(exit.node) >= 0 and creature.shell.tray_of.has(int(exit.room)) and creature.routes.exit_usable(e)
