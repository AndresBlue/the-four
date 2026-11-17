extends Node
## Her eyes in Versus (.claude/specs/lurker_versus.md 4 and 4.5): what a
## thermal camera would record on matplotlib's plasma map, where the heat is
## electricity. Her seat (presentation_rig.echo_seat) puts the floor's lamps,
## decals, dust and fog out (hotel.echo_view) and draws no lens. Over all of it
## a quad on her camera (game/presentation/shaders/lurker_sight.gdshader) reads
## the world from the depth: the bare surfaces low, even and blotched, and the
## heat from the floor's registers, never from what is lit, as shapes: the
## lenses of the lit rooms' fittings, the emergency units, the landmarks' and
## the furniture's lamps, the objectives' machines and lamps, the air plant's
## rotors, the live wires to their switches, and the torches, hottest of all.
## A source behind a wall warms the face of the wall. The camera's gain
## stretches the picture between the coldest and the hottest in view, slowly:
## with nothing electric before her the walls come up grainy, with a torch or
## a lamp in view the rest sinks to dark. Her sensor
## (lurker_thermal_sensor.gdshader) makes a recording of it: few lines, soft,
## sharpened, noisy, striped, the plasma map last; now and then it freezes a
## moment with a click to calibrate, above all after it has been saturated.
## Over it the camera's own marks (Hud): the reticle, the map's bar, the rings
## of what she hears and the corners of her places to lie in wait.
##
## What she is given of the survivors: a lit torch through the walls within
## BEACON_REACH (none she drank, none while her face is behind a shut tile or
## deep in a duct), a body only as her senses see it (lurker_senses.sees()),
## and anybody whose mind has gone through the walls as a cold outline. Her
## own lit room floods the sensor past a few metres. Noise rings out where she
## would hear it (her hear_route()): running, doors, typing, the bells, a
## torch's click; and what the host says she hears (contact()). flash() is a
## torch in her face (the host fires it: lurker.scare_off()): the camera
## saturated. All of it local to her machine: nothing travels for it.
##
## From the plenum (lurker_versus.md 13.2) the quad draws lurker_xray.gdshader
## instead, over the same sensor: her planta under the false ceiling as if
## through it, from a plan of it (plan_of()), the survivors within
## driver.PREY_REACH as warm figures and their torches burning. The Hud then
## draws, crisp and in no words: her body, the objectives (a white outline and
## a diamond, pulsing while somebody is at one), the tile she would go down by,
## the ducts' ways in, her prey's marker (green and a triangle when the attack
## may go; red, a struck diamond and why not as a sign: an eye, a sun, a wait's
## arc, or small and far), her actions along the foot with their keys and their
## waits, and the picture closing in when she is sent off. In the ducts and
## crossing between plantas, the ducts' plan (DuctPlan): the ways out to pick,
## the way along them, her trip or her crossing as a line or a ring filling.
const SIGHT_SHADER := preload("res://game/presentation/shaders/lurker_sight.gdshader")
const XRAY_SHADER := preload("res://game/presentation/shaders/lurker_xray.gdshader")
const SETTINGS := preload("res://game/services/settings_service.gd")
const SENSOR_SHADER := preload("res://game/presentation/shaders/lurker_thermal_sensor.gdshader")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const FILES := preload("res://game/floors/objectives/files_objective.gd")
## The shader's source and wire slots, and its kinds.
const MOST := 96
const WIRES := 48
enum Kind { LAMP, TORCH, BODY, COLD }
## A lit torch is a beacon through the walls this far (decision A).
const BEACON_REACH := 30.0
## Heat (a reading): a fitting, an emergency unit, a landmark's lamp, a
## furniture lamp, an objective's machine and its lamp, a running air handler,
## a body seen, a torch, a live wire over its surface.
const FITTING_HEAT := 0.72
const EMERGENCY_HEAT := 0.66
const LANDMARK_HEAT := 0.74
const ACCENT_HEAT := 0.64
const MACHINE_HEAT := 0.8
const LAMP_HEAT := 0.95
const FAN_HEAT := 0.86
const BODY_HEAT := 0.3
const TORCH_HEAT := 1.15
const WIRE_HEAT := 0.07
## The half sizes of what is not a troffer (metres): an emergency unit, a lamp,
## a station's or a pilot's lamp, a rotor, a torch's head; a body's radius and
## half height. A usable's is most of its focus box.
const UNIT_HALF := Vector3(0.16, 0.08, 0.08)
const LAMP_HALF := Vector3(0.15, 0.15, 0.15)
const PILOT_HALF := Vector3(0.05, 0.05, 0.05)
const ROTOR_HALF := Vector3(0.45, 0.45, 0.45)
const TORCH_HALF := Vector3(0.06, 0.06, 0.06)
const BODY_HALF := Vector3(0.27, 0.6, 0.0)
const USABLE_SHARE := 0.4
## What an objective's usable does that runs on electricity.
const ELECTRIC := ["type", "take", "swipe", "lever", "red", "switch", "post", "start", "stop"]
## Sources further than this are left out, and from FADE_FROM they cool a little.
const LAMP_REACH := 32.0
const FADE_FROM := 15.0
## The live wires of the lit rooms whose middle is this near.
const WIRE_REACH := 16.0
## A source is in view when nothing stands between but this much round it.
const SHAPE_SLACK := 0.35
## The registers are read this often; the sources are placed every frame.
const GATHER_EVERY := 0.1
## A source's halo on the sensor (metres round its shape; a torch's), and the
## patch one behind a wall leaves (metres); never smaller than these (screen
## heights).
const HALO := 0.25
const TORCH_HALO := 0.45
const THROUGH_SIZE := 1.4
const LEAST_RADIUS := 0.006
const TORCH_LEAST := 0.025
## How far a source warms round it (the shader's STAIN_REACH).
const WARM_REACH := 1.6
## What of a hidden source reaches the face that hides it (the shader's
## LAMP_THROUGH, LAMP_THROUGH_FALL, TORCH_THROUGH, TORCH_THROUGH_FALL).
const LAMP_THROUGH := Vector2(0.3, 2.5)
const TORCH_THROUGH := Vector2(0.62, 40.0)
## The camera's gain: the coldest reading at the foot of the map; the top at
## the hottest in view over GAIN_SHARE (so it burns white), the warmest patch
## of something hidden over HIDDEN_SHARE (warm, not burning), never under
## GAIN_LEAST (the walls alone stay low); it follows over GAIN_TIME.
## (13.2: the least top went from 0.36 to 0.5, so a room's light no longer
## stretches the walls up to a pink wash.)
const GAIN_LOW := 0.06
const GAIN_LEAST := 0.5
const GAIN_SHARE := 0.8
const HIDDEN_SHARE := 1.5
const GAIN_TIME := 0.35
## The sensor's noise (a reading: the gain stretches it) and its stripes; with
## reduced effects, this share.
const NOISE_HEAT := 0.009
const STRIPES := 0.02
const REDUCED_NOISE := 0.5
## The halos lag the camera this much (per second toward it): the sensor's trail.
const LAG_RATE := 22.0
## The calibration (NUC): every so often, and NUC_AFTER after a saturation has
## passed, the picture holds still NUC_HOLD with a dry click (the start of the
## camcorder's zoom motor). Never with reduced effects.
const NUC_EVERY := Vector2(25.0, 55.0)
const NUC_AFTER := 0.25
const NUC_HOLD := 0.35
const CLICK := preload("res://assets/audio/sfx/camera/zoom_in.wav")
const CLICK_FROM := 0.02
const CLICK_LENGTH := 0.08
const CLICK_DB := -12.0
## The dazzle of her own lit room comes and goes this fast (per second).
const DAZZLE_RATE := 3.0
## Rings: how long one lasts; running is heard every RUN_EVERY over RUN_SPEED
## m/s, typing every TYPE_EVERY by somebody standing at the typewriter.
const RING_LIFE := 1.0
const RUN_SPEED := 4.5
const RUN_EVERY := 0.4
const TYPE_EVERY := 0.3
const TYPE_REACH := 1.4
## Heard close, a noise rings where it is; further, where it comes from (the
## opening it came through), as The Locust's contacts.
const RING_TRUTH := 6.0
## The flash: saturated in FLASH_RISE, back in FLASH_FALL, none again for
## FLASH_RISE + FLASH_FALL + FLASH_IMMUNE; with reduced effects only half as
## far, and steady.
const FLASH_RISE := 0.15
const FLASH_FALL := 2.5
const FLASH_IMMUNE := 1.0
const REDUCED_PEAK := 0.5
## The X-ray (13.2): the plan's pixels per metre; the fittings as dots of this
## reading and size, a torch's; the ducts drawn within DUCT_REACH, this warm;
## lit rooms within LIT_REACH; the objectives within GOAL_REACH, busy while a
## survivor is within BUSY_REACH of one; the ducts' ways in within VENT_REACH.
const PLAN_PX := 5.0
const FITTING_DOT := Vector2(0.2, 0.09)
const TORCH_DOT := Vector2(1.4, 0.07)
const DUCT_REACH := 18.0
const DUCT_LINE := 0.1
const LIT_REACH := 45.0
const LITS := 48
const BODIES := 16
const GOAL_REACH := 40.0
const BUSY_REACH := 1.6
const VENT_REACH := 15.0
## Beber's wait (lurker.VERSUS_EVERY), shown as its arc.
const DRINK_EVERY := 25.0
## What the host tells her she hears (contact()) that this machine does not
## ring itself already (listen(), on_door()).
const OWN_KINDS := [NOISE.Kind.RUN, NOISE.Kind.DOOR, NOISE.Kind.SLAM]

var driver
var creature
var level
var camera: Camera3D
var field: MeshInstance3D
var material: ShaderMaterial
var sensor: CanvasLayer
var sensor_material: ShaderMaterial
var frozen: TextureRect
var hud: Control
var plan: Control
var click: AudioStreamPlayer
var clock := 0.0
var gather_clock := 0.0
## The registers' heat on her planta, nearest first:
## [point, half size, yaw, heat, kind, metres, in view, metres behind what hides it].
var lamps: Array = []
## [from, to, heat] of the live wires near her.
var wires: Array = []
## seat -> the survivor whose torch she has as a beacon; seat -> seen;
## seat -> [in view, metres behind what hides it] of a beacon's torch.
var beacons := {}
var seen := {}
var torch_view := {}
var cold: Array = []
var dazzle := 0.0
var dazzled := false
## {point, born, heat, size}
var rings: Array = []
var torch_was := {}
var run_clocks := {}
var type_clock := 0.0
var requests_seen := {}
var flash_clock := -1.0
var flash_from := Vector2.ZERO
var immune_until := -1.0
var saturated := false
## Room -> its fittings' shapes [point, half size, yaw]; room -> its wires.
var shapes := {}
var runs := {}
var heat_at := PackedVector4Array()
var heat_box := PackedVector4Array()
var heat_screen := PackedVector4Array()
var heat_kind := PackedVector4Array()
var wire_a := PackedVector4Array()
var wire_b := PackedVector4Array()
var placed := 0
var gain_high := GAIN_LEAST
## Where the halos are drawn from: the camera, a moment late.
var lag := Transform3D.IDENTITY
var nuc_clock := 30.0
var frozen_until := -1.0
var click_until := -1.0
## The X-ray: its material; planta -> [plan texture, its box]; what it draws
## ([feet, heat], [point, heat, kind, radius], [from, to, heat], [rect, heat]);
## the Hud's objectives [point, half box, yaw, busy] and ways in [point, exit].
var xray_material: ShaderMaterial
var plans := {}
var xbodies: Array = []
var xdots: Array = []
var xlines: Array = []
var xlit: Array = []
var goals: Array = []
var vents: Array = []
## When the room she drank went dark here (Beber's wait).
var drank_at := -INF
var deep_was := -1

func setup(owner_driver, cover: CanvasLayer) -> void:
	driver = owner_driver
	creature = driver.creature
	level = driver.level
	camera = driver.camera
	name = "View"
	material = ShaderMaterial.new()
	material.shader = SIGHT_SHADER
	material.render_priority = 120
	field = MeshInstance3D.new()
	field.name = "SightField"
	field.mesh = QuadMesh.new()
	field.material_override = material
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Never culled: the shader puts the quad over the whole frame itself.
	field.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	field.ignore_occlusion_culling = true
	field.visible = false
	camera.add_child(field)
	xray_material = ShaderMaterial.new()
	xray_material.shader = XRAY_SHADER
	xray_material.render_priority = 120
	# The sensor: over the 3D and under every other layer of the picture.
	sensor = CanvasLayer.new()
	sensor.name = "Sensor"
	sensor.layer = 1
	sensor.visible = false
	add_child(sensor)
	sensor_material = ShaderMaterial.new()
	sensor_material.shader = SENSOR_SHADER
	var screen := ColorRect.new()
	screen.material = sensor_material
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sensor.add_child(screen)
	frozen = TextureRect.new()
	frozen.set_anchors_preset(Control.PRESET_FULL_RECT)
	frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frozen.stretch_mode = TextureRect.STRETCH_SCALE
	frozen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frozen.visible = false
	sensor.add_child(frozen)
	click = AudioStreamPlayer.new()
	click.stream = CLICK
	click.bus = &"Effects"
	click.volume_db = CLICK_DB
	add_child(click)
	plan = DuctPlan.new()
	plan.view = self
	plan.set_anchors_preset(Control.PRESET_FULL_RECT)
	plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.visible = false
	cover.add_child(plan)
	hud = Hud.new()
	hud.view = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	cover.add_child(hud)
	heat_at.resize(MOST)
	heat_box.resize(MOST)
	heat_screen.resize(MOST)
	heat_kind.resize(MOST)
	wire_a.resize(WIRES)
	wire_b.resize(WIRES)
	nuc_clock = randf_range(NUC_EVERY.x, NUC_EVERY.y)
	if is_instance_valid(level.get("hotel")):
		for door in level.hotel.doors:
			if door.has_signal("noise"): door.noise.connect(on_door)

## Whether her camera is the picture and her seat is hers (the rig's).
func seat() -> bool:
	return camera.current and level.get("rig") != null and level.rig.echo_seat()

func _process(delta: float) -> void:
	clock += delta
	var on := seat()
	field.visible = on and not driver.dark
	field.material_override = xray_material if above() else material
	sensor.visible = field.visible
	hud.visible = field.visible and not driver.blind.visible
	plan.visible = on and driver.dark
	if click.playing and clock >= click_until: click.stop()
	var deep := int(creature.get("deep_room")) if creature.get("deep_room") != null else -1
	if deep >= 0 and deep_was < 0: drank_at = clock
	deep_was = deep
	if not on: return
	if plan.visible: plan.tick(delta)
	listen(delta)
	gather_clock -= delta
	if gather_clock <= 0.0:
		gather_clock = GATHER_EVERY
		gather()
	dazzle = move_toward(dazzle, 1.0 if dazzled else 0.0, DAZZLE_RATE * delta)
	calibrate(delta)
	place(delta)
	if above(): place_xray()
	if hud.visible: hud.queue_redraw()

## Her camera over her in the plenum (or a gallery): the X-ray.
func above() -> bool: return driver.mode == "above"

# --- The registers ---------------------------------------------------------------------

## Hers (from over her, her camera may be above the slab).
func planta() -> int: return driver.planta()

func wing_of(room_id: int) -> int:
	return int(level.manifest.rooms[room_id].get("wing", -1)) if room_id >= 0 and room_id < level.manifest.rooms.size() else -1

## The registers' heat on her planta, nearest first, and whether she has each
## in view; the live wires near her; what she makes out of the survivors;
## whether her room dazzles her.
func gather() -> void:
	var hotel = level.hotel
	var here := planta()
	var eye := camera.global_position
	var found: Array = []
	var lit_rooms: Array = []
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != here or id >= hotel.lights.size() or not hotel.lit(id): continue
		var light: OmniLight3D = hotel.lights[id]
		if light.has_meta("off") or light.has_meta("void"): continue
		var left: float = 1.0 - 0.5 * float(hotel.drained(id))
		for shape in shapes_of(id): found.append([shape[0], shape[1], shape[2], FITTING_HEAT * left, Kind.LAMP])
		var middle := FLOOR.position_of(room)
		lit_rooms.append([Vector2(middle.x - eye.x, middle.z - eye.z).length(), id, left])
	if "emergency" in hotel:
		for e: Dictionary in hotel.emergency:
			if int(e.planta) != here or hotel.lit(int(e.room)): continue
			var unit: Node3D = e.lens if is_instance_valid(e.get("lens")) else e.light
			found.append([unit.global_position, UNIT_HALF, unit.global_rotation.y, EMERGENCY_HEAT, Kind.LAMP])
	if "landmark_lamps" in hotel:
		for entry: Dictionary in hotel.landmark_lamps:
			if wing_of(int(entry.room)) == here: found.append([(entry.light as Node3D).global_position, LAMP_HALF, 0.0, LANDMARK_HEAT, Kind.LAMP])
	if "accents" in hotel:
		for room_id: int in hotel.accents.rooms:
			if wing_of(room_id) != here or not hotel.lit(room_id): continue
			for entry: Dictionary in hotel.accents.of_room(room_id):
				if is_instance_valid(entry.get("light")): found.append([(entry.light as Node3D).global_position, LAMP_HALF, 0.0, ACCENT_HEAT, Kind.LAMP])
	for objective in level.objectives.values():
		if "usables" in objective:
			for usable in objective.usables:
				if is_instance_valid(usable) and String(usable.action) in ELECTRIC and FLOOR.planta_of(usable.global_position.y) == here:
					found.append([usable.global_transform * Vector3(0, 0, usable.box.z * 0.5), usable.box * USABLE_SHARE, usable.global_rotation.y, MACHINE_HEAT, Kind.LAMP])
		for key in ["lamps", "pilots"]:
			if not key in objective: continue
			for lamp in objective.get(key):
				if lamp is Light3D and lamp.visible and FLOOR.planta_of(lamp.global_position.y) == here: found.append([lamp.global_position, PILOT_HALF, 0.0, LAMP_HEAT, Kind.LAMP])
		if "rotors" in objective and objective.running():
			for rotor in objective.rotors: found.append([(rotor as Node3D).global_position, ROTOR_HALF, 0.0, FAN_HEAT, Kind.LAMP])
	for entry in found:
		var d: float = eye.distance_to(entry[0])
		entry[3] = float(entry[3]) * (1.0 - 0.25 * smoothstep(FADE_FROM, LAMP_REACH, d))
		entry.append(d)
	lamps = found.filter(func(entry: Array) -> bool: return float(entry[5]) < LAMP_REACH)
	lamps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[5]) < float(b[5]))
	if lamps.size() > MOST: lamps.resize(MOST)
	for entry in lamps: entry.append_array(in_view(eye, entry[0], []))
	# The wires of the nearest lit rooms.
	lit_rooms.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	wires.clear()
	for room in lit_rooms:
		if float(room[0]) > WIRE_REACH: break
		for run in runs_of(int(room[1])):
			if wires.size() < WIRES: wires.append([run[0], run[1], WIRE_HEAT * float(room[2])])
	look_at_survivors(eye)
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, eye)
	dazzled = not room.is_empty() and not driver.dark and not above() and hotel.lit(int(room.id))
	if above(): gather_xray(lit_rooms)

## What the X-ray draws, from her (not her camera): the survivors within her
## prey's reach (13.6 A2) and the minds gone anywhere on her planta, the
## torches she has as beacons, the fittings low, the ducts and the lit rooms
## round her; the objectives and the ducts' ways in for the Hud.
func gather_xray(lit_rooms: Array) -> void:
	var at: Vector3 = creature.motion.anchor()
	var here := planta()
	xbodies.clear()
	for one in level.survivors():
		if driver.markable(one, at, here): xbodies.append([one.global_position, 1.0])
	for point in cold:
		if xbodies.size() < BODIES and FLOOR.planta_of(point.y + 1.0) == here: xbodies.append([point, 0.6])
	if xbodies.size() > BODIES: xbodies.resize(BODIES)
	xdots.clear()
	for seat_id in beacons:
		var one = beacons[seat_id]
		if is_instance_valid(one) and is_instance_valid(one.get("torch")): xdots.append([one.torch.global_position, TORCH_DOT.x, 1.0, TORCH_DOT.y])
	for entry in lamps:
		if xdots.size() >= MOST: break
		xdots.append([entry[0], FITTING_DOT.x, 0.0, FITTING_DOT.y])
	xlit.clear()
	for entry in lit_rooms:
		if xlit.size() >= LITS or float(entry[0]) > LIT_REACH: continue
		var room: Dictionary = level.manifest.rooms[int(entry[1])]
		var half := FLOOR.size_of(room) * 0.5
		xlit.append([Vector4(float(room.px) - half.x, float(room.pz) - half.y, float(room.px) + half.x, float(room.pz) + half.y), float(entry[2])])
	var ducts = creature.ducts
	xlines.clear()
	for edge in ducts.edges:
		var a := int(edge[0])
		var b := int(edge[1])
		if xlines.size() >= WIRES or String(edge[3]) == "plenum" or ducts.node_wings[a] != here: continue
		var middle: Vector3 = (ducts.nodes[a] + ducts.nodes[b]) * 0.5
		if Vector2(middle.x - at.x, middle.z - at.z).length() < DUCT_REACH: xlines.append([ducts.nodes[a], ducts.nodes[b], DUCT_LINE])
	goals.clear()
	for objective in level.objectives.values():
		if not "usables" in objective: continue
		for usable in objective.usables:
			if not is_instance_valid(usable) or FLOOR.planta_of(usable.global_position.y + 0.5) != here: continue
			var point: Vector3 = usable.global_transform * Vector3(0, 0, usable.box.z * 0.5)
			if Vector2(point.x - at.x, point.z - at.z).length() > GOAL_REACH: continue
			var busy := false
			for one in level.survivors():
				if is_instance_valid(one) and level.survivor_active(one) and (one.global_position as Vector3).distance_to(point) < BUSY_REACH + 1.0 and Vector2(one.global_position.x - point.x, one.global_position.z - point.z).length() < BUSY_REACH: busy = true
			goals.append([point, usable.box * 0.5, usable.global_rotation.y, busy])
	vents.clear()
	for e in ducts.exits.size():
		var exit: Dictionary = ducts.exits[e]
		if not driver.travel_exit(e) or ducts.node_wings[int(exit.node)] != here: continue
		if Vector2((exit.position as Vector3).x - at.x, (exit.position as Vector3).z - at.z).length() < VENT_REACH: vents.append([exit.position, e])

## The plan of a planta for the X-ray, worked out once: green inside the
## building, alpha over her false ceilings; red the walls (a grid cell's side
## between two ceilings that are not one); blue her fire walls, where a ceiling of hers meets one that
## is not hers or is of another department (lurker_player.open_at()).
func plan_of(here: int) -> Array:
	if plans.has(here): return plans[here]
	var rooms: Array = []
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != here or FLOOR.is_void(room): continue
		var half := FLOOR.size_of(room) * 0.5
		var rect := Rect2(Vector2(float(room.px), float(room.pz)) - half, half * 2.0)
		rooms.append([room, rect])
		low = low.min(rect.position)
		high = high.max(rect.end)
	if rooms.is_empty(): return []
	low -= Vector2.ONE
	high += Vector2.ONE
	var width := int(ceil((high.x - low.x) * PLAN_PX))
	var height := int(ceil((high.y - low.y) * PLAN_PX))
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var shell = creature.shell
	var to_px := func(p: Vector2) -> Vector2i: return Vector2i(int(round((p.x - low.x) * PLAN_PX)), int(round((p.y - low.y) * PLAN_PX)))
	for entry in rooms:
		var room: Dictionary = entry[0]
		var rect: Rect2 = entry[1]
		var a: Vector2i = to_px.call(rect.position)
		var b: Vector2i = to_px.call(rect.end)
		var hers: bool = shell.tray_of.has(int(room.id)) and OFFICE.false_ceiling(room)
		image.fill_rect(Rect2i(a, b - a), Color(0, 1, 0, 1.0 if hers else 0.0))
	for entry in rooms:
		var room: Dictionary = entry[0]
		var rect: Rect2 = entry[1]
		var a: Vector2i = to_px.call(rect.position)
		var b: Vector2i = to_px.call(rect.end)
		var mine: bool = shell.tray_of.has(int(room.id))
		var sides := [[Vector2(rect.position.x - 0.15, rect.get_center().y), true, a.x], [Vector2(rect.end.x + 0.15, rect.get_center().y), true, b.x], [Vector2(rect.get_center().x, rect.position.y - 0.15), false, a.y], [Vector2(rect.get_center().x, rect.end.y + 0.15), false, b.y]]
		for side in sides:
			var other := FLOOR.room_at(level.manifest.rooms, Vector3((side[0] as Vector2).x, FLOOR.planta_y(here) + 1.0, (side[0] as Vector2).y))
			var fire: bool = mine and (other.is_empty() or not shell.tray_of.has(int(other.id)) or int(other.get("sector", -1)) != int(room.get("sector", -1)))
			# A wall only between two ceilings that are not one (a corridor's or an open office's cells share one).
			var wall: bool = other.is_empty() or not mine or not shell.tray_of.has(int(other.id)) or int(shell.tray_of[int(other.id)]) != int(shell.tray_of[int(room.id)])
			if not wall and not fire: continue
			var line := int(side[2])
			var span := range(a.y, b.y + 1) if bool(side[1]) else range(a.x, b.x + 1)
			for along in span:
				for k in ([0, 1] if fire else [0]):
					var x: int = line + k if bool(side[1]) else along
					var y: int = along if bool(side[1]) else line + k
					if x < 0 or y < 0 or x >= width or y >= height: continue
					var c := image.get_pixel(x, y)
					if k == 0 and wall: c.r = 1.0
					if fire: c.b = 1.0
					image.set_pixel(x, y, c)
	plans[here] = [ImageTexture.create_from_image(image), Vector4(low.x, low.y, width / PLAN_PX, height / PLAN_PX)]
	return plans[here]

## The X-ray's uniforms, every frame.
func place_xray() -> void:
	var here := planta()
	var drawn_plan: Array = plan_of(here)
	if drawn_plan.is_empty(): return
	var floor_y := FLOOR.planta_y(here)
	var bodies := PackedVector4Array()
	bodies.resize(BODIES)
	for i in xbodies.size(): bodies[i] = Vector4(xbodies[i][0].x, xbodies[i][0].y, xbodies[i][0].z, float(xbodies[i][1]))
	var dots_at := PackedVector4Array()
	var dots_kind := PackedVector4Array()
	dots_at.resize(MOST)
	dots_kind.resize(MOST)
	for i in xdots.size():
		dots_at[i] = Vector4(xdots[i][0].x, xdots[i][0].y, xdots[i][0].z, float(xdots[i][1]))
		dots_kind[i] = Vector4(float(xdots[i][2]), float(xdots[i][3]), 0.0, 0.0)
	var lines_a := PackedVector4Array()
	var lines_b := PackedVector4Array()
	lines_a.resize(WIRES)
	lines_b.resize(WIRES)
	for i in xlines.size():
		lines_a[i] = Vector4(xlines[i][0].x, xlines[i][0].y, xlines[i][0].z, float(xlines[i][2]))
		lines_b[i] = Vector4(xlines[i][1].x, xlines[i][1].y, xlines[i][1].z, 0.0)
	var rects := PackedVector4Array()
	var heats := PackedFloat32Array()
	rects.resize(LITS)
	heats.resize(LITS)
	for i in xlit.size():
		rects[i] = xlit[i][0]
		heats[i] = float(xlit[i][1])
	var reduced: bool = level.settings.values.reduced
	xray_material.set_shader_parameter("plan", drawn_plan[0])
	xray_material.set_shader_parameter("plan_box", drawn_plan[1])
	xray_material.set_shader_parameter("floor_y", floor_y)
	xray_material.set_shader_parameter("ceil_y", floor_y + float(OFFICE.PLENUM.ceiling))
	xray_material.set_shader_parameter("slab_y", floor_y + float(OFFICE.PLENUM.slab))
	xray_material.set_shader_parameter("lit_count", xlit.size())
	xray_material.set_shader_parameter("lit_rect", rects)
	xray_material.set_shader_parameter("lit_heat", heats)
	xray_material.set_shader_parameter("body_count", xbodies.size())
	xray_material.set_shader_parameter("body_at", bodies)
	xray_material.set_shader_parameter("dot_count", xdots.size())
	xray_material.set_shader_parameter("dot_at", dots_at)
	xray_material.set_shader_parameter("dot_kind", dots_kind)
	xray_material.set_shader_parameter("line_count", xlines.size())
	xray_material.set_shader_parameter("line_a", lines_a)
	xray_material.set_shader_parameter("line_b", lines_b)
	xray_material.set_shader_parameter("flash", flash_now())
	xray_material.set_shader_parameter("flash_from", flash_from)
	xray_material.set_shader_parameter("flash_peak", REDUCED_PEAK if reduced else 1.0)
	# The sensor as in her eyes, its noise at the X-ray's even gain.
	sensor_material.set_shader_parameter("noise", NOISE_HEAT / (GAIN_LEAST - GAIN_LOW) * (REDUCED_NOISE if reduced else 1.0))

## [in view, metres behind what hides it] of a point from her eye.
func in_view(eye: Vector3, point: Vector3, exclude: Array) -> Array:
	var query := PhysicsRayQueryParameters3D.create(eye, point, SIGHT.MASK)
	query.exclude = [creature.get_rid()] + exclude
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return [true, 0.0]
	var gap: float = (hit.position as Vector3).distance_to(point)
	return [gap < SHAPE_SLACK, gap]

## A room's fittings, as shapes: its troffers' lenses where it has them (the
## ceiling's holes, office_palette.troffers()), else its lamps' pools or its
## lamp. Found once.
func shapes_of(id: int) -> Array:
	if shapes.has(id): return shapes[id]
	var found: Array = []
	var room: Dictionary = level.manifest.rooms[id]
	var ceiling := float(room.get("py", 0.0)) + float(room.get("height", OFFICE.PLENUM.ceiling)) + 0.03
	for lamp in OFFICE.troffers(room):
		var c: Vector2 = lamp.centre
		found.append([Vector3(c.x, ceiling, c.y), Vector3(0.3, 0.07, 0.6) if bool(lamp.along_z) else Vector3(0.6, 0.07, 0.3), 0.0])
	if found.is_empty():
		var hotel = level.hotel
		if "halos" in hotel and hotel.halos.has(id):
			for pool in hotel.halos[id].get("pools", []):
				if is_instance_valid(pool) and not "Bounce" in String(pool.name): found.append([(pool as Node3D).global_position, LAMP_HALF, 0.0])
		if found.is_empty(): found.append([hotel.lights[id].global_position, LAMP_HALF, 0.0])
	shapes[id] = found
	return found

## A room's live wires, [from, to] over its ceiling: its fittings chained one
## to the next, square to the room, and from the last over to its door and down
## to the switch beside it. Laid out once.
func runs_of(id: int) -> Array:
	if runs.has(id): return runs[id]
	var room: Dictionary = level.manifest.rooms[id]
	var points: Array = shapes_of(id).map(func(shape: Array) -> Vector3: return shape[0])
	var size := FLOOR.size_of(room)
	var along_z := size.y > size.x
	# Snaking down the rows of the long way.
	points.sort_custom(func(a: Vector3, b: Vector3) -> bool: return (a.z if along_z else a.x) < (b.z if along_z else b.x) - 0.5 or (absf((a.z if along_z else a.x) - (b.z if along_z else b.x)) <= 0.5 and (a.x if along_z else a.z) < (b.x if along_z else b.z)))
	var found: Array = []
	for k in range(1, points.size()): found.append_array(square(points[k - 1], points[k]))
	var door := door_of(room)
	if door != Vector3.INF and not points.is_empty():
		var last: Vector3 = points[0]
		for point: Vector3 in points:
			if Vector2(point.x - door.x, point.z - door.z).length() < Vector2(last.x - door.x, last.z - door.z).length(): last = point
		# The switch, by the door (office_geometry.SWITCH_Y), and its run up.
		var top := Vector3(door.x, last.y, door.z)
		found.append_array(square(last, top))
		found.append([top, Vector3(door.x, float(room.get("py", 0.0)) + 1.15, door.z)])
	runs[id] = found
	return found

## From a to b along x, then along z, on a's height.
func square(a: Vector3, b: Vector3) -> Array:
	var corner := Vector3(b.x, a.y, a.z)
	return [[a, corner], [corner, Vector3(b.x, a.y, b.z)]]

## Beside the room's door nearest its middle, on the wall, a hand from the
## frame: where its switch is (office_geometry.switch_plate()); INF with none.
func door_of(room: Dictionary) -> Vector3:
	var middle := Vector2(float(room.px), float(room.pz))
	var half := FLOOR.size_of(room) * 0.5
	var best := Vector3.INF
	for door in level.hotel.doors:
		var at: Vector3 = door.doorway
		if absf(at.y - float(room.get("py", 0.0))) > 2.0: continue
		var off := Vector2(at.x, at.z) - middle
		var on_x := absf(absf(off.x) - half.x) < 0.3 and absf(off.y) < half.y
		var on_z := absf(absf(off.y) - half.y) < 0.3 and absf(off.x) < half.x
		if not on_x and not on_z: continue
		# Along the wall from the doorway, to the side nearer the room's middle.
		var along := Vector3(0, 0, -signf(off.y)) if on_x else Vector3(-signf(off.x), 0, 0)
		var point := at + along * 0.6
		if best == Vector3.INF or Vector2(point.x, point.z).distance_to(middle) < Vector2(best.x, best.z).distance_to(middle): best = point
	return best

## Whose torch is her beacon, whom she sees, whose mind has gone.
func look_at_survivors(eye: Vector3) -> void:
	beacons.clear()
	seen.clear()
	torch_view.clear()
	var senses = creature.get("senses")
	# Her face behind a shut tile, or deep in a duct: nothing; but from the
	# plenum her X-ray has the torches (13.6 A2).
	var eyes: bool = senses != null and (senses.eye_point() != Vector3.INF or above())
	for one in level.survivors():
		if not is_instance_valid(one) or not level.survivor_active(one) or bool(one.get("hidden")): continue
		var sees: bool = eyes and not above() and senses.sees(one)
		if sees: seen[int(one.slot)] = one
		var torch = one.get("torch")
		if not eyes or not is_instance_valid(torch) or not torch.visible or senses.drank(one): continue
		if sees or (torch.global_position as Vector3).distance_to(eye) <= BEACON_REACH:
			beacons[int(one.slot)] = one
			torch_view[int(one.slot)] = in_view(eye, torch.global_position, [one.get_rid()] if one is CollisionObject3D else [])
	cold = level.sanity.burnt_survivors() if level.get("sanity") != null else []

# --- What she hears --------------------------------------------------------------------

func on_door(point: Vector3, radius: float, _kind: int) -> void:
	if seat(): ring(point, radius, 0.62, 2.4)

## The noises she would hear, from what this machine has of them: torches
## switched, survivors running, somebody at the typewriter, the bells.
func listen(delta: float) -> void:
	for one in level.survivors():
		if not is_instance_valid(one) or not "slot" in one: continue
		var seat_id := int(one.slot)
		var torch = one.get("torch")
		var lit: bool = is_instance_valid(torch) and torch.visible
		if torch_was.has(seat_id) and bool(torch_was[seat_id]) != lit: ring(one.camera.global_position, SENSES.TORCH_CLICK / NOISE.HEARING_SCALE, 0.9, 0.9)
		torch_was[seat_id] = lit
		var velocity: Vector3 = one.get("velocity") if one.get("velocity") != null else Vector3.ZERO
		run_clocks[seat_id] = float(run_clocks.get(seat_id, 0.0)) - delta
		if Vector2(velocity.x, velocity.z).length() > RUN_SPEED and float(run_clocks[seat_id]) <= 0.0:
			run_clocks[seat_id] = RUN_EVERY
			ring(one.global_position + Vector3(0, 0.1, 0), NOISE.radius("run"), 0.66, 2.0)
	var files = level.objectives.get("files")
	if files == null or files.usables.is_empty(): return
	var typewriter: Vector3 = files.usables[0].global_position
	type_clock -= delta
	if type_clock <= 0.0:
		for one in level.survivors():
			if not is_instance_valid(one): continue
			var velocity: Vector3 = one.get("velocity") if one.get("velocity") != null else Vector3.ZERO
			var off: Vector3 = one.global_position - typewriter
			if Vector2(off.x, off.z).length() < TYPE_REACH and absf(off.y) < 1.5 and Vector2(velocity.x, velocity.z).length() < 0.3:
				type_clock = TYPE_EVERY
				ring(typewriter, NOISE.radius("door_slow"), 0.7, 0.8)
				break
	# A request typed rings the window's bell; a card come rings its station's.
	for owner in files.requests:
		var state := int(files.requests[owner].state)
		var was := int(requests_seen.get(owner, -1))
		if was < 0: ring(typewriter, NOISE.radius("door"), 0.85, 2.2)
		elif was != state and state == FILES.Card.IN_TRAY and int(files.requests[owner].station) + 1 < files.usables.size(): ring(files.usables[int(files.requests[owner].station) + 1].global_position, NOISE.radius("door"), 0.85, 2.2)
		requests_seen[owner] = state

## A noise the host says she heard (lurker.hunter_contact()): close, where it
## was; further, where it came from.
func contact(point: Vector3, apparent: Vector3, distance: float, strength: float, kind: int) -> void:
	if not seat() or OWN_KINDS.has(kind): return
	rings.append({"point": point if distance < RING_TRUTH else apparent, "born": clock, "heat": 0.5 + 0.3 * strength, "size": 1.2 + strength})

## A noise where she hears it, as she hears it, or nowhere.
func ring(point: Vector3, radius: float, heat: float, size: float) -> void:
	if not creature.has_method("hear_route"): return
	var route: Dictionary = creature.hear_route(point, radius)
	if not bool(route.get("audible", false)): return
	var at: Vector3 = point if float(route.distance) < RING_TRUTH else route.apparent
	rings.append({"point": at, "born": clock, "heat": heat, "size": size})

# --- The flash and the calibration -----------------------------------------------------

## A torch full in her face, from `from_direction` (world, from her to it):
## the camera saturates, white from that side and black elsewhere, in
## FLASH_RISE, and its gain gives the picture back over FLASH_FALL. False
## while she is still immune to another.
func flash(from_direction: Vector3) -> bool:
	if clock < immune_until: return false
	flash_clock = clock
	immune_until = clock + FLASH_RISE + FLASH_FALL + FLASH_IMMUNE
	var local: Vector3 = camera.global_basis.inverse() * from_direction
	flash_from = Vector2(local.x, local.y).normalized() if Vector2(local.x, local.y).length() > 0.05 else Vector2.ZERO
	return true

## How saturated now, 0 to 1 (the peak is the shader's).
func flash_now() -> float:
	if flash_clock < 0.0: return 0.0
	var t := clock - flash_clock
	if t < FLASH_RISE: return smoothstep(0.0, 1.0, t / FLASH_RISE)
	var x := (t - FLASH_RISE) / FLASH_FALL
	if x >= 1.0: return 0.0
	var white := (1.0 - x) * (1.0 - x)
	# A torch's white is not steady: unless effects are reduced.
	if not level.settings.values.reduced: white *= 1.0 - 0.12 * x * (0.5 + 0.5 * sin(clock * 31.0))
	return white

## From her to the nearest survivor, or straight ahead (the test order, F8).
func nearest_survivor_way() -> Vector3:
	var eye := camera.global_position
	var best := -camera.global_basis.z
	var nearest := INF
	for one in level.survivors():
		if not is_instance_valid(one) or not "camera" in one: continue
		var d: float = (one.camera.global_position as Vector3).distance_to(eye)
		if d < nearest and d > 0.1:
			nearest = d
			best = ((one.camera.global_position as Vector3) - eye).normalized()
	return best

## The sensor calibrating itself now and then, and soon after a saturation:
## the picture held still a moment, with a click.
func calibrate(delta: float) -> void:
	frozen.visible = clock < frozen_until
	var white := flash_now()
	if white > 0.5: saturated = true
	elif saturated and white < 0.2:
		saturated = false
		nuc_clock = minf(nuc_clock, NUC_AFTER)
	nuc_clock -= delta
	if nuc_clock > 0.0: return
	nuc_clock = randf_range(NUC_EVERY.x, NUC_EVERY.y)
	# Without a screen (headless, its dummy renderer) there is no frame to hold.
	if level.settings.values.reduced or not field.visible or DisplayServer.get_name() == "headless": return
	# The last frame as it was shown, held (a read back once in a while).
	var shown := get_viewport().get_texture().get_image()
	if shown == null or shown.is_empty(): return
	frozen.texture = ImageTexture.create_from_image(shown)
	frozen.visible = true
	frozen_until = clock + NUC_HOLD
	click.play(CLICK_FROM)
	click_until = clock + CLICK_LENGTH

# --- On the screen ---------------------------------------------------------------------

## Every source to the shader: its shape in the world, and where the lagging
## camera puts its halo; torches, bodies and outlines first, then the
## registers' heat, nearest first. The gain follows the hottest in view.
func place(delta: float) -> void:
	var focal: float = 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect: float = size.x / maxf(size.y, 1.0)
	lag = camera.global_transform if lag == Transform3D.IDENTITY else lag.interpolate_with(camera.global_transform, 1.0 - exp(-LAG_RATE * delta))
	var from_eye: Transform3D = camera.global_transform.affine_inverse()
	var from_lag: Transform3D = lag.affine_inverse()
	var eye := camera.global_position
	placed = 0
	# (A lambda keeps a copy of a local: the count and the peak are the view's.)
	var peak := [0.0, 0.0]
	var put := func(point: Vector3, half: Vector3, yaw: float, heat: float, kind: int, shown: bool, gap: float) -> void:
		if placed >= MOST: return
		var metres := eye.distance_to(point)
		var depth: float = -(from_eye * point).z
		var at := Vector2(0.5, 0.5)
		var radius := 1.0e-4
		var reach := 10.0
		# Behind her or at her eye, it only warms what she sees round it.
		if depth > 0.05:
			var p: Vector3 = from_lag * point
			if -p.z < 0.05: p = from_eye * point
			at = Vector2(0.5 + p.x / -p.z * focal / aspect, 0.5 - p.y / -p.z * focal)
			var torch := kind == Kind.TORCH
			var metres_round: float = (TORCH_HALO if torch else maxf(half.x, maxf(half.y, half.z)) + HALO) if shown else THROUGH_SIZE
			radius = maxf(metres_round / depth * focal, TORCH_LEAST if torch else LEAST_RADIUS)
			if kind == Kind.COLD: radius = 0.5 / depth * focal
			# What it warms may stand nearer her than it does, and spread wider.
			var extent: float = maxf(half.x, maxf(half.y, half.z)) + WARM_REACH
			reach = maxf(radius * 2.8, extent / maxf(depth - extent, 0.3) * focal)
			if at.x < -reach or at.x > 1.0 + reach or at.y < -reach or at.y > 1.0 + reach: return
			var real: Vector3 = from_eye * point
			var in_frame := absf(real.x / -real.z * focal / aspect) < 0.5 and absf(real.y / -real.z * focal) < 0.5
			if in_frame and kind != Kind.COLD:
				var through: Vector2 = TORCH_THROUGH if torch else LAMP_THROUGH
				if shown: peak[0] = maxf(peak[0], heat)
				else: peak[1] = maxf(peak[1], heat * through.x * exp(-gap / through.y))
		else: shown = true
		heat_at[placed] = Vector4(point.x, point.y, point.z, heat)
		heat_box[placed] = Vector4(half.x, half.y, half.z, yaw)
		heat_screen[placed] = Vector4(at.x, at.y, radius, metres)
		heat_kind[placed] = Vector4(kind, 1.0 if shown else 0.0, reach, 0.0)
		placed += 1
	for seat_id in beacons:
		var one = beacons[seat_id]
		if not is_instance_valid(one) or not is_instance_valid(one.get("torch")): continue
		var view: Array = torch_view.get(seat_id, [false, 0.0])
		put.call(one.torch.global_position, TORCH_HALF, 0.0, TORCH_HEAT, Kind.TORCH, bool(view[0]), float(view[1]))
	for seat_id in seen:
		var one = seen[seat_id]
		if is_instance_valid(one): put.call(one.global_position + Vector3(0, 0.87, 0), BODY_HALF, 0.0, BODY_HEAT, Kind.BODY, true, 0.0)
	for point in cold: put.call(point + Vector3(0, 0.95, 0), Vector3(0.0, 2.1, 0.0), 0.0, 0.0, Kind.COLD, false, 0.0)
	for entry in lamps: put.call(entry[0], entry[1], float(entry[2]), float(entry[3]), Kind.LAMP, bool(entry[6]), float(entry[7]))
	for w in wires.size():
		var run: Array = wires[w]
		wire_a[w] = Vector4(run[0].x, run[0].y, run[0].z, float(run[2]))
		wire_b[w] = Vector4(run[1].x, run[1].y, run[1].z, 0.0)
	# The gain: the hottest in view at the top over GAIN_SHARE, slowly.
	var target := maxf(GAIN_LEAST, maxf(float(peak[0]) * GAIN_SHARE, float(peak[1]) * HIDDEN_SHARE))
	gain_high = lerpf(gain_high, target, 1.0 - exp(-delta / GAIN_TIME))
	var reduced: bool = level.settings.values.reduced
	material.set_shader_parameter("count", placed)
	material.set_shader_parameter("heat_at", heat_at)
	material.set_shader_parameter("heat_box", heat_box)
	material.set_shader_parameter("heat_screen", heat_screen)
	material.set_shader_parameter("heat_kind", heat_kind)
	material.set_shader_parameter("wire_count", wires.size())
	material.set_shader_parameter("wire_a", wire_a)
	material.set_shader_parameter("wire_b", wire_b)
	material.set_shader_parameter("gain_low", GAIN_LOW)
	material.set_shader_parameter("gain_high", gain_high)
	material.set_shader_parameter("floor_y", FLOOR.planta_y(planta()))
	material.set_shader_parameter("dazzle", dazzle)
	material.set_shader_parameter("flash", flash_now())
	material.set_shader_parameter("flash_from", flash_from)
	material.set_shader_parameter("flash_peak", REDUCED_PEAK if reduced else 1.0)
	material.set_shader_parameter("now", clock)
	var calm: float = REDUCED_NOISE if reduced else 1.0
	sensor_material.set_shader_parameter("noise", NOISE_HEAT / (gain_high - GAIN_LOW) * calm)
	sensor_material.set_shader_parameter("stripes", STRIPES * calm)
	sensor_material.set_shader_parameter("now", clock)

## matplotlib's plasma (the shaders' fit), for what is drawn in 2D.
static func plasma(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var c := [Vector3(0.05873234392399702, 0.02333670892565664, 0.5433401826748754), Vector3(2.176514634195958, 0.2383834171260182, 0.7539604599784036), Vector3(-2.689460476458034, -7.455851135738909, 3.110799939717086), Vector3(6.130348345893603, 42.3461881477227, -28.51885465332158), Vector3(-11.10743619062271, -82.66631109428045, 60.13984767418263), Vector3(10.02306557647065, 71.41361770095349, -54.07218655560067), Vector3(-3.658713842777788, -22.93153465461149, 18.19190778539828)]
	var v: Vector3 = c[6]
	for k in range(5, -1, -1): v = c[k] + v * t
	return Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0))

## The camera's own marks over its picture, crisp, and no word but a key's
## name (the author, 16 November 2026: what she can do and why not is drawn,
## not written). Her eyes: the reticle. Always: the map's bar on the right, the
## rings of what she hears, her prey's marker, her actions along the foot and,
## sent off, the picture closing in. From the plenum: her body, the
## objectives, the tile she would go down by and the ducts' ways in.
class Hud extends Control:
	const SETTINGS := preload("res://game/services/settings_service.gd")
	const INK := Color(1.0, 1.0, 1.0, 0.85)
	const DIM := Color(1.0, 1.0, 1.0, 0.28)
	const GO := Color(0.35, 1.0, 0.5, 0.95)
	const NO := Color(1.0, 0.32, 0.26, 0.95)
	const HER := Color(0.62, 0.78, 1.0, 0.9)
	var view

	## A filled shape, unless it has folded flat on the screen.
	func fill(points: PackedVector2Array, colour: Color) -> void:
		if not Geometry2D.triangulate_polygon(points).is_empty(): draw_colored_polygon(points, colour)

	func _draw() -> void:
		var s := size.y / 720.0
		var width := maxf(1.0, 1.5 * s)
		var middle := size * 0.5
		var above: bool = view.above()
		if not above:
			var gap := 6.0 * s
			var arm := 13.0 * s
			for way in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(middle + way * gap, middle + way * (gap + arm), INK, width)
		# The map's bar, hottest at the top, with a tick at either end.
		var bar := Rect2(size.x - 40.0 * s, size.y * 0.3, 12.0 * s, size.y * 0.4)
		var steps := 48
		for k in steps:
			var y0 := bar.end.y - bar.size.y * float(k + 1) / steps
			draw_rect(Rect2(bar.position.x, y0, bar.size.x, bar.size.y / steps + 0.5), view.plasma(float(k) / (steps - 1)))
		draw_rect(bar, Color(INK, 0.5), false, maxf(1.0, s))
		for y in [bar.position.y, bar.end.y]: draw_line(Vector2(bar.position.x - 6.0 * s, y), Vector2(bar.position.x - 1.0 * s, y), INK, maxf(1.0, s))
		# A frame held still shows its own marks.
		if view.clock < view.frozen_until: return
		var camera: Camera3D = view.camera
		var focal: float = 0.5 / tan(deg_to_rad(camera.fov) * 0.5) * size.y
		for entry in view.rings:
			var age: float = (view.clock - float(entry.born)) / view.RING_LIFE
			if age >= 1.0 or camera.is_position_behind(entry.point): continue
			var depth: float = maxf(-(camera.global_transform.affine_inverse() * (entry.point as Vector3)).z, 0.3)
			var radius: float = float(entry.size) * (0.25 + 0.75 * (1.0 - (1.0 - age) * (1.0 - age))) / depth * focal
			var ink := Color(INK, INK.a * clampf(float(entry.heat), 0.0, 1.0) * (1.0 - age))
			var at := camera.unproject_position(entry.point)
			for k in 24: draw_arc(at, radius, TAU * k / 24.0, TAU * (k + 0.55) / 24.0, 3, ink, width)
		if above: draw_above(s, width)
		draw_prey(s, width)
		draw_actions(s, width)
		draw_fled(s)

	func project(point: Vector3) -> Vector2:
		return view.camera.unproject_position(point)

	func behind(point: Vector3) -> bool: return view.camera.is_position_behind(point)

	## From the plenum: the objectives, the ducts' ways in, the tile she
	## would go down by, and her body.
	func draw_above(s: float, width: float) -> void:
		var driver = view.driver
		var clock: float = view.clock
		for goal in view.goals:
			var point: Vector3 = goal[0]
			var half: Vector3 = goal[1]
			if behind(point): continue
			var turn := Basis(Vector3.UP, float(goal[2]))
			var box := Rect2(project(point), Vector2.ZERO)
			for corner in [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1)]:
				var p: Vector3 = point + turn * (half * corner)
				if not behind(p): box = box.expand(project(p))
			var pulse: float = 0.5 + 0.5 * sin(clock * 4.0) if bool(goal[3]) else 1.0
			var ink := Color(1, 1, 1, 0.55 + 0.45 * pulse)
			draw_rect(box.grow(2.0 * s), ink, false, width)
			var top: Vector3 = point + Vector3(0, half.y + 0.45, 0)
			if behind(top): continue
			var tip := project(top)
			var r := 6.0 * s
			diamond(tip, r, ink, true)
			if bool(goal[3]): draw_arc(tip, r * (1.6 + 1.2 * fmod(clock * 0.8, 1.0)), 0.0, TAU, 24, Color(1, 1, 1, 0.6 * (1.0 - fmod(clock * 0.8, 1.0))), width)
		var near: int = driver.entrance()
		for vent in view.vents:
			if behind(vent[0]): continue
			var hot: bool = int(vent[1]) == near
			var at := project(vent[0])
			icon("vent", at, (9.0 if hot else 6.0) * s, INK if hot else DIM, width)
			if hot: key_tag("lurker_enter", at + Vector2(0, 16.0 * s), s)
		var way: Dictionary = driver.down_way()
		if not way.is_empty() and not behind(way.point):
			var c: Vector3 = way.point
			var square := PackedVector2Array()
			for corner in [Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(-0.3, -0.3)]: square.append(project(c + Vector3(corner.x, 0, corner.y)))
			draw_polyline(square, INK, width * 1.5)
		# Her: a long body with four limbs, cold blue, smaller and fainter crawling slowly.
		var motion = view.creature.motion
		var at: Vector3 = motion.anchor()
		if behind(at): return
		var heading: Vector3 = motion.basis.z if motion.plenum else view.creature.global_basis.z
		heading = Vector3(heading.x, 0, heading.z).normalized() if Vector2(heading.x, heading.z).length() > 0.05 else Vector3.FORWARD
		var side := Vector3(-heading.z, 0, heading.x)
		var shade := Color(HER, HER.a * (0.55 if driver.sneaking else 1.0))
		var body := PackedVector2Array()
		for p in [heading * 0.55, heading * 0.2 + side * 0.18, -heading * 0.45 + side * 0.12, -heading * 0.6, -heading * 0.45 - side * 0.12, heading * 0.2 - side * 0.18]: body.append(project(at + p))
		# An outline only: what she is over shows through her.
		body.append(body[0])
		draw_polyline(body, shade, width)
		for k in [-1.0, 1.0]:
			for f in [0.3, -0.3]:
				var root: Vector3 = at + heading * f + side * 0.12 * k
				draw_line(project(root), project(root + (side * 0.45 * k + heading * f * 0.8)), shade, width)

	## Her prey's marker over its head: green and a triangle when the attack
	## may go, with her charge filling round it; red and a struck diamond when
	## not, beside it why: an eye (looked at), a sun (light on her or on it),
	## the wait's arc; far off, small inside a broken ring.
	func draw_prey(s: float, width: float) -> void:
		var driver = view.driver
		if driver.prey < 0: return
		var one = driver.body_of(driver.prey)
		if one == null: return
		var head: Vector3 = one.global_position + Vector3(0, 2.1, 0)
		if behind(head): return
		var at := project(head)
		var info: Dictionary = driver.prey_info
		var r := 11.0 * s
		var fill: float = driver.charge / driver.CHARGE
		if bool(info.get("ok", false)):
			fill(PackedVector2Array([at + Vector2(-r, -r * 0.7), at + Vector2(r, -r * 0.7), at + Vector2(0, r * 0.9)]), GO)
			draw_arc(at, r * 1.8, -PI / 2.0, -PI / 2.0 + TAU * fill, 32, GO, width * (2.0 if fill >= 1.0 else 1.0))
			return
		var why := String(info.get("why", ""))
		var k := 0.6 if why == "far" else 1.0
		diamond(at, r * k, NO, false, width * 1.5)
		draw_line(at + Vector2(-r, r) * 0.6 * k, at + Vector2(r, -r) * 0.6 * k, NO, width * 1.5)
		if fill > 0.0: draw_arc(at, r * 1.8 * k, -PI / 2.0, -PI / 2.0 + TAU * fill, 32, Color(GO, 0.6), width)
		var aside := at + Vector2(r * 2.4, 0)
		match why:
			"look": icon("eye", aside, r, NO, width)
			"light": icon("sun", aside, r, NO, width)
			"wait":
				draw_arc(aside, r * 0.8, 0.0, TAU, 24, Color(NO, 0.3), width)
				draw_arc(aside, r * 0.8, -PI / 2.0, -PI / 2.0 + TAU * clampf(float(info.get("wait", 0.0)), 0.0, 1.0), 24, NO, width * 2.0)
			"far":
				for q in 12: draw_arc(at, r * 1.9, TAU * q / 12.0, TAU * (q + 0.5) / 12.0, 3, NO, width)

	## Her actions along the foot: each a sign, its key, and its state:
	## ready, not now (faint), held (green), or waiting (its arc filling).
	func draw_actions(s: float, width: float) -> void:
		var driver = view.driver
		var up: bool = driver.up()
		var info: Dictionary = driver.prey_info
		var prey: bool = driver.prey >= 0
		var ok := bool(info.get("ok", false))
		var trip_wait: float = clampf((driver.trip_ready_at - driver.clock) / driver.TRIP_GAP, 0.0, 1.0)
		var drink_wait: float = clampf(1.0 - (view.clock - view.drank_at) / view.DRINK_EVERY, 0.0, 1.0)
		var slots := [
			["claw", "lurker_release", (GO if ok else NO) if prey else DIM, 0.0],
			["down" if up else "up", "lurker_drop", INK if (not up or driver.gallery() or not driver.down_way().is_empty()) else DIM, 0.0],
			["sneak", "lurker_sneak", GO if driver.sneaking else (INK if up else DIM), 0.0],
			["vent", "lurker_enter", INK if driver.entrance() >= 0 else DIM, trip_wait],
			["drink", "lurker_drink", DIM if drink_wait > 0.0 else INK, drink_wait],
			["peek", "lurker_peek", DIM if up else INK, 0.0],
		]
		var gap := 74.0 * s
		var r := 15.0 * s
		var x0 := size.x * 0.5 - gap * (slots.size() - 1) * 0.5
		var y := size.y - 70.0 * s
		for i in slots.size():
			var slot: Array = slots[i]
			var at := Vector2(x0 + gap * i, y)
			draw_circle(at, r * 1.45, Color(0, 0, 0, 0.35))
			draw_arc(at, r * 1.45, 0.0, TAU, 32, Color(slot[2], (slot[2] as Color).a * 0.6), width)
			icon(String(slot[0]), at, r, slot[2], width)
			if float(slot[3]) > 0.0: draw_arc(at, r * 1.45, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - float(slot[3])), 32, INK, width * 2.0)
			key_tag(String(slot[1]), at + Vector2(0, r * 2.4), s)

	## Sent off (lurker_player.scared()): the picture closes in and opens again.
	func draw_fled(s: float) -> void:
		var driver = view.driver
		var t: float = (driver.clock - driver.fled_at) / driver.FLED_FOR
		if t < 0.0 or t >= 1.0: return
		var shut := sin(PI * t) * minf(size.x, size.y) * 0.32
		for k in 6:
			var band := shut * (1.0 - float(k) / 6.0)
			var shade := Color(0, 0, 0, 0.16 + 0.12 * float(k))
			draw_rect(Rect2(0, 0, size.x, band), shade)
			draw_rect(Rect2(0, size.y - band, size.x, band), shade)
			draw_rect(Rect2(0, 0, band, size.y), shade)
			draw_rect(Rect2(size.x - band, 0, band, size.y), shade)

	func diamond(at: Vector2, r: float, colour: Color, filled: bool, line := 1.5) -> void:
		var points := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.75, 0), at + Vector2(0, r), at + Vector2(-r * 0.75, 0)])
		if filled: fill(points, colour)
		else:
			points.append(points[0])
			draw_polyline(points, colour, line)

	## A sign of r round: her claws, down, up, crawling slowly, a duct's
	## grille, a bulb drunk, a half-shut eye; an eye and a sun for her prey.
	func icon(kind: String, at: Vector2, r: float, colour: Color, width: float) -> void:
		match kind:
			"claw":
				for k in [-1.0, 0.0, 1.0]: draw_line(at + Vector2(k * r * 0.45 - r * 0.3, -r * 0.8), at + Vector2(k * r * 0.45 + r * 0.3, r * 0.8), colour, width * 1.6)
			"down", "up":
				var sign_y := 1.0 if kind == "down" else -1.0
				draw_line(at - Vector2(0, r * 0.8 * sign_y), at + Vector2(0, r * 0.7 * sign_y), colour, width * 1.6)
				fill(PackedVector2Array([at + Vector2(0, r * 0.95 * sign_y), at + Vector2(-r * 0.5, r * 0.3 * sign_y), at + Vector2(r * 0.5, r * 0.3 * sign_y)]), colour)
				draw_line(at + Vector2(-r * 0.9, -r * 0.95 * sign_y), at + Vector2(r * 0.9, -r * 0.95 * sign_y), colour, width)
			"sneak":
				for k in 3:
					var p := at + Vector2(-r * 0.7 + r * 0.7 * k, (r * 0.35) * (1 if k % 2 == 0 else -1))
					draw_circle(p, r * 0.22, colour)
			"vent":
				draw_arc(at, r, 0.0, TAU, 24, colour, width)
				for k in [-0.45, 0.0, 0.45]: draw_line(at + Vector2(-r * 0.7 * cos(asin(k)), r * k), at + Vector2(r * 0.7 * cos(asin(k)), r * k), colour, width)
			"drink":
				draw_arc(at + Vector2(0, -r * 0.2), r * 0.6, 0.0, TAU, 20, colour, width)
				draw_line(at + Vector2(-r * 0.3, r * 0.5), at + Vector2(r * 0.3, r * 0.5), colour, width)
				draw_line(at + Vector2(-r * 0.22, r * 0.75), at + Vector2(r * 0.22, r * 0.75), colour, width)
				draw_line(at + Vector2(-r * 0.75, -r * 0.95), at + Vector2(r * 0.75, r * 0.55), colour, width * 1.4)
			"peek":
				draw_arc(at + Vector2(0, r * 0.55), r * 0.95, PI * 1.15, PI * 1.85, 16, colour, width)
				draw_line(at + Vector2(-r, 0), at + Vector2(r, 0), colour, width)
				draw_circle(at + Vector2(0, -r * 0.12), r * 0.22, colour)
			"eye":
				draw_arc(at + Vector2(0, r * 0.55), r * 0.95, PI * 1.15, PI * 1.85, 16, colour, width)
				draw_arc(at - Vector2(0, r * 0.55), r * 0.95, PI * 0.15, PI * 0.85, 16, colour, width)
				draw_circle(at, r * 0.28, colour)
			"sun":
				draw_circle(at, r * 0.38, colour)
				for k in 8:
					var way := Vector2.RIGHT.rotated(TAU * k / 8.0)
					draw_line(at + way * r * 0.6, at + way * r, colour, width)

	## A key's name under a sign (the only words she has): a key, a pad's
	## button or trigger, or a mouse with the button lit.
	func key_tag(action: String, at: Vector2, s: float) -> void:
		var settings = view.level.settings
		var pair: Array = SETTINGS.LURKER_ACTIONS[action]
		var pad: bool = settings.using_pad and settings.pad_present()
		var text := ""
		if pad: text = settings.trigger_name(int(pair[1][0]) == JOY_AXIS_TRIGGER_RIGHT) if pair[1] is Array else settings.button_name(int(pair[1]))
		elif pair[1] is Array:
			# A mouse, its button lit.
			var box := Rect2(at - Vector2(6, 8) * s, Vector2(12, 16) * s)
			draw_rect(box, INK, false, maxf(1.0, s))
			var left := int(pair[0]) == MOUSE_BUTTON_LEFT
			draw_rect(Rect2(box.position + (Vector2.ZERO if left else Vector2(6, 0) * s), Vector2(6, 6) * s), INK)
			return
		else: text = OS.get_keycode_string(int(pair[0]))
		var font := ThemeDB.fallback_font
		var font_size := int(round(13.0 * s))
		var wide := font.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_rect(Rect2(at - Vector2(wide * 0.5 + 4.0 * s, font_size * 0.85), Vector2(wide + 8.0 * s, font_size * 1.35)), Color(1, 1, 1, 0.5), false, maxf(1.0, s))
		draw_string(font, at + Vector2(-wide * 0.5, font_size * 0.3), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)

## The ducts' plan, while she is in them or crossing to another planta: the
## network of her planta round her, turned as she looks. Picking a way out
## (lurker_player.trip, "pick"), the ways out she may go to, the one most
## where she looks lit with the way along to it, her key to go beside it and
## her key back up beside her; going, the way, lit as far as she has come
## (what is left is her countdown); crossing between plantas, a ring filling.
class DuctPlan extends Control:
	const FLOOR := preload("res://game/world/generation/floor_definition.gd")
	const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
	const SETTINGS := preload("res://game/services/settings_service.gd")
	## Metres from her to the plan's edge at the least.
	const REACH := 12.0
	var view
	var clock := 0.0
	var route := PackedVector3Array()
	var route_of := -1

	func fill(points: PackedVector2Array, colour: Color) -> void:
		if not Geometry2D.triangulate_polygon(points).is_empty(): draw_colored_polygon(points, colour)

	func tick(delta: float) -> void:
		clock += delta
		queue_redraw()

	func _draw() -> void:
		var driver = view.driver
		var creature = view.creature
		var ducts = creature.ducts
		var motion = creature.motion
		var middle := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), view.plasma(0.0) * Color(0.3, 0.3, 0.3))
		if ducts == null: return
		var at: Vector3 = motion.duct_point if motion.in_duct else creature.global_position
		var wing: int = ducts.node_wings[motion.near_node] if motion.near_node >= 0 and motion.near_node < ducts.node_wings.size() else driver.planta()
		var trip: Dictionary = driver.trip
		var phase := String(trip.get("phase", ""))
		# The plan holds every way out she may pick, or her whole way.
		var span := REACH
		if phase in ["pick", "ask"]:
			for entry in trip.targets: span = maxf(span, Vector2((ducts.exits[int(entry[0])].position as Vector3).x - at.x, (ducts.exits[int(entry[0])].position as Vector3).z - at.z).length() * 1.1)
		elif phase == "go":
			for p in trip.points: span = maxf(span, Vector2(p.x - at.x, p.z - at.z).length() * 1.1)
		var scale: float = minf(size.x, size.y) * 0.45 / span
		var yaw: float = driver.yaw
		var to_screen := func(p: Vector3) -> Vector2: return middle + Vector2(p.x - at.x, p.z - at.z).rotated(yaw) * scale
		var width := maxf(1.5, size.y / 360.0)
		for edge in ducts.edges:
			var a := int(edge[0])
			if ducts.node_wings[a] != wing or String(edge[3]) == "plenum": continue
			var colour: Color = view.plasma(0.3)
			if ducts.closed_wings[wing] != 0: colour = colour.darkened(0.6)
			draw_line(to_screen.call(ducts.nodes[a]), to_screen.call(ducts.nodes[int(edge[1])]), colour, width)
		var hot: Color = view.plasma(1.0)
		var ink := Color(1, 1, 1, 0.9)
		match phase:
			"pick", "ask":
				var from := int(trip.from)
				var pick := int(trip.pick)
				if pick != route_of and pick >= 0:
					route_of = pick
					route = ducts.points_of(ducts.shortest(int(ducts.exits[from].node), int(ducts.exits[pick].node)).path)
				for k in range(1, route.size()): draw_dashed_line(to_screen.call(route[k - 1]), to_screen.call(route[k]), Color(hot, 0.8), width * 2.0, width * 4.0)
				for entry in trip.targets:
					var p: Vector2 = to_screen.call(ducts.exits[int(entry[0])].position)
					var side := width * 3.0
					if int(entry[0]) == pick: continue
					draw_rect(Rect2(p - Vector2.ONE * side, Vector2.ONE * side * 2.0), view.plasma(0.7), false, width)
				if pick >= 0:
					var p: Vector2 = to_screen.call(ducts.exits[pick].position)
					var side := width * 4.0
					var refused: bool = driver.clock - float(trip.get("refused", -INF)) < 0.6
					var colour: Color = Color(1.0, 0.32, 0.26) if refused else hot
					draw_rect(Rect2(p - Vector2.ONE * side, Vector2.ONE * side * 2.0), colour)
					draw_arc(p, side * (2.2 + 1.2 * (0.5 + 0.5 * sin(clock * 6.0))), 0.0, TAU, 24, colour, width)
					tag("lurker_enter", p + Vector2(0, side * 5.0))
				var start: Vector2 = to_screen.call(ducts.exits[from].position)
				draw_arc(start, width * 5.0, 0.0, TAU, 20, ink, width)
				# Back out where she came in: an arrow up and its key, at the foot.
				var foot := Vector2(size.x * 0.5, size.y - 90.0 * size.y / 720.0)
				var r := 12.0 * size.y / 720.0
				draw_line(foot + Vector2(0, r), foot - Vector2(0, r * 0.6), ink, width)
				fill(PackedVector2Array([foot - Vector2(0, r), foot + Vector2(-r * 0.5, -r * 0.35), foot + Vector2(r * 0.5, -r * 0.35)]), ink)
				tag("lurker_drop", foot + Vector2(0, r * 2.4))
			"go":
				var points: PackedVector3Array = trip.points
				var done: float = motion.travelled
				var walked := 0.0
				for k in range(1, points.size()):
					var a: Vector3 = points[k - 1]
					var b: Vector3 = points[k]
					var piece := a.distance_to(b)
					draw_line(to_screen.call(a), to_screen.call(b), Color(hot, 0.3), width * 2.0)
					if walked < done: draw_line(to_screen.call(a), to_screen.call(a.lerp(b, clampf((done - walked) / maxf(piece, 1e-4), 0.0, 1.0))), hot, width * 3.0)
					walked += piece
				if points.size() > 0:
					var end: Vector2 = to_screen.call(points[points.size() - 1])
					draw_arc(end, width * (5.0 + 2.0 * (0.5 + 0.5 * sin(clock * 6.0))), 0.0, TAU, 24, hot, width)
		# Crossing between plantas: a ring filling as the trunk takes her down.
		var transit: Dictionary = motion.transit
		if not transit.is_empty():
			var left := float(transit.get("left", 0.0))
			var done := 1.0 - clampf(left / MOTION.RIDE_TIME, 0.0, 1.0) if transit.get("phase", &"") == &"drop" else 1.0
			var radius := minf(size.x, size.y) * 0.18
			draw_arc(middle, radius, 0.0, TAU, 48, Color(hot, 0.25), width * 3.0)
			draw_arc(middle, radius, -PI / 2.0, -PI / 2.0 + TAU * done, 48, hot, width * 3.0)
		# Her, pointing where she looks (up the screen).
		var tip := width * 9.0
		fill(PackedVector2Array([middle + Vector2(0, -tip), middle + Vector2(tip * 0.6, tip * 0.6), middle + Vector2(-tip * 0.6, tip * 0.6)]), view.plasma(0.55))
		# A flash goes on fading over the plan she bolted into (4.3).
		var white: float = view.flash_now() * (view.REDUCED_PEAK if view.level.settings.values.reduced else 1.0)
		if white > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.85, white))

	## Her key's name, as the Hud writes it.
	func tag(action: String, at: Vector2) -> void:
		var s := size.y / 720.0
		var settings = view.level.settings
		var pair: Array = SETTINGS.LURKER_ACTIONS[action]
		var pad: bool = settings.using_pad and settings.pad_present()
		var text: String = (settings.button_name(int(pair[1])) if pad else OS.get_keycode_string(int(pair[0]))).to_upper()
		var font := ThemeDB.fallback_font
		var font_size := int(round(13.0 * s))
		var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_rect(Rect2(at - Vector2(wide * 0.5 + 4.0 * s, font_size * 0.85), Vector2(wide + 8.0 * s, font_size * 1.35)), Color(1, 1, 1, 0.5), false, maxf(1.0, s))
		draw_string(font, at + Vector2(-wide * 0.5, font_size * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9))
