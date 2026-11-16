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
## saturated. Through a grille, a tile or a duct she has the ducts' plan instead.
## All of it local to her machine: nothing travels for it.
const SIGHT_SHADER := preload("res://game/presentation/shaders/lurker_sight.gdshader")
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
const GAIN_LOW := 0.06
const GAIN_LEAST := 0.36
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
## Her places to lie in wait (lurker_stalk.gd) within MARK_REACH, the
## nearest MARKS of them: a corner mark each, the one lurker_stalk would take
## now brighter.
const MARK_REACH := 8.0
const MARKS := 8
const MARK_HEAT := 0.3
const MARK_NEXT := 0.9
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
## [point, heat] of the sites marked.
var marks: Array = []

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
	sensor.visible = field.visible
	hud.visible = field.visible and not driver.blind.visible
	plan.visible = on and driver.dark
	if click.playing and clock >= click_until: click.stop()
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
	if hud.visible: hud.queue_redraw()

# --- The registers ---------------------------------------------------------------------

func planta() -> int: return FLOOR.planta_of(camera.global_position.y)

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
	marks.clear()
	for near in driver.sites_near(MARK_REACH):
		if marks.size() >= MARKS: break
		marks.append([creature.stalk_sites[int(near[1])].point, MARK_NEXT if marks.is_empty() and float(near[0]) <= driver.STALK_REACH else MARK_HEAT])
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, eye)
	dazzled = not room.is_empty() and not driver.dark and hotel.lit(int(room.id))

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
	# Her face behind a shut tile, or deep in a duct: nothing.
	var eyes: bool = senses != null and senses.eye_point() != Vector3.INF
	for one in level.survivors():
		if not is_instance_valid(one) or not level.survivor_active(one) or bool(one.get("hidden")): continue
		var sees: bool = eyes and senses.sees(one)
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

## The camera's own marks over its picture, crisp and white as a thermal
## camera prints them, never a figure: the reticle, the map's bar on the
## right, the rings of what she hears, dashed, and her places to lie in wait
## as corners (a lamp is a blot; these are the camera's).
class Hud extends Control:
	const INK := Color(1.0, 1.0, 1.0, 0.8)
	var view

	func _draw() -> void:
		var s := size.y / 720.0
		var width := maxf(1.0, 1.5 * s)
		var middle := size * 0.5
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
		for entry in view.marks:
			if camera.is_position_behind(entry[0]): continue
			var depth: float = maxf(-(camera.global_transform.affine_inverse() * (entry[0] as Vector3)).z, 0.3)
			var half: float = clampf(0.22 / depth * focal, 6.0 * s, 22.0 * s) * (1.0 if float(entry[1]) > 0.5 else 0.75)
			var leg := half * 0.45
			var at := camera.unproject_position(entry[0])
			var ink := Color(INK, float(entry[1]))
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var tip: Vector2 = at + corner * half
				draw_line(tip, tip - Vector2(corner.x * leg, 0), ink, width)
				draw_line(tip, tip - Vector2(0, corner.y * leg), ink, width)

## The ducts' plan, while she has no eyes (a grille, a tile, a duct): the
## network of her planta round her, turned as she looks, its ways out marked
## and the one lurker_enter would take now (lurker_player.way_out()) lit.
class DuctPlan extends Control:
	const FLOOR := preload("res://game/world/generation/floor_definition.gd")
	## Metres from her to the plan's edge, and how often the way out is asked.
	const REACH := 12.0
	## Past this from her the plan fades out.
	const FADE := 9.0
	const PICK_EVERY := 0.3
	var view
	var pick := -1
	var pick_clock := 0.0
	var clock := 0.0

	func tick(delta: float) -> void:
		clock += delta
		pick_clock -= delta
		if pick_clock <= 0.0:
			pick_clock = PICK_EVERY
			var way: Array = view.driver.way_out()
			pick = int(way[0]) if not way.is_empty() else -1
		queue_redraw()

	func _draw() -> void:
		var ducts = view.creature.ducts
		var middle := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), view.plasma(0.0) * Color(0.35, 0.35, 0.35))
		if ducts == null: return
		var at: Vector3 = view.creature.global_position
		var wing: int = FLOOR.planta_of(at.y + 1.0)
		var scale: float = minf(size.x, size.y) * 0.5 / REACH
		var yaw: float = view.driver.yaw
		var to_screen := func(p: Vector3) -> Vector2:
			var flat := Vector2(p.x - at.x, p.z - at.z).rotated(yaw)
			return middle + flat * scale
		var width := maxf(1.5, size.y / 360.0)
		for edge in ducts.edges:
			var a := int(edge[0])
			var b := int(edge[1])
			if ducts.node_wings[a] != wing: continue
			var plenum := String(edge[3]) == "plenum"
			var shut: bool = ducts.closed_wings[wing] != 0
			var colour: Color = view.plasma(0.18 if plenum else 0.32)
			if shut: colour = colour.darkened(0.6)
			colour.a = near(ducts.nodes[a], at)
			draw_line(to_screen.call(ducts.nodes[a]), to_screen.call(ducts.nodes[b]), colour, width * (1.0 if plenum else 2.0))
		for e in ducts.exits.size():
			var exit: Dictionary = ducts.exits[e]
			if int(exit.node) < 0 or ducts.node_wings[int(exit.node)] != wing or not view.driver.usable(e): continue
			var p: Vector2 = to_screen.call(exit.position)
			var side := width * (3.0 if e == pick else 2.0)
			var box := Rect2(p - Vector2.ONE * side, Vector2.ONE * side * 2.0)
			var mark: Color = view.plasma(0.74)
			mark.a = near(exit.position, at)
			if e == pick:
				draw_arc(p, side * (2.5 + 1.5 * (0.5 + 0.5 * sin(clock * 6.0))), 0.0, TAU, 24, view.plasma(1.0), width)
				draw_rect(box, view.plasma(1.0))
			# A tile hollow, a grille or a gap filled.
			elif String(exit.kind) == "tile": draw_rect(box, mark, false, width)
			else: draw_rect(box, mark, true)
		# Her, pointing where she looks (up the screen).
		var tip := width * 9.0
		draw_colored_polygon(PackedVector2Array([middle + Vector2(0, -tip), middle + Vector2(tip * 0.6, tip * 0.6), middle + Vector2(-tip * 0.6, tip * 0.6)]), view.plasma(0.55))
		# A flash goes on fading over the plan she bolted into (4.3: white, then
		# back over FLASH_FALL), as it would over her eyes.
		var white: float = view.flash_now() * (view.REDUCED_PEAK if view.level.settings.values.reduced else 1.0)
		if white > 0.0: draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.85, white))

	## 1 near her, to nothing past REACH (from FADE).
	func near(p: Vector3, at: Vector3) -> float:
		return 1.0 - smoothstep(FADE, REACH * 1.6, Vector2(p.x - at.x, p.z - at.z).length())
