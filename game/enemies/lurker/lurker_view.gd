extends Node
## Her eyes in Versus (.claude/specs/lurker_versus.md 4; phase 2): the author's
## infrared, on matplotlib's plasma map. Her seat (presentation_rig.echo_seat)
## puts the floor's lamps, decals, dust and fog out (hotel.echo_view) and
## draws no lens; this paints the picture her camera sees over all of it
## (game/presentation/shaders/lurker_sight.gdshader): the rooms out of the dark
## in deep blue and purple from the depth alone, and the heat from the floor's
## registers, never from what is lit: rooms with their light and their
## fittings, the emergency units, the landmarks' lamps, the objectives'
## machines and lamps, and the torches, hottest of all.
##
## What she is given of the survivors: a lit torch through the walls within
## BEACON_REACH (none she drank, none while her face is behind a shut tile or
## deep in a duct), a body only as her senses see it (lurker_senses.sees()),
## and anybody whose mind has gone through the walls as a cold outline. Her
## own lit room blinds her past a few metres. Noise rings out where she would
## hear it (her hear_route()): running, doors, typing, the bells, a torch's
## click. flash() is the white of a torch in her face (who fires it is phase
## 3's). Through a grille, a tile or a duct she has the ducts' plan instead.
## All of it local to her machine: nothing travels for it.
const SIGHT_SHADER := preload("res://game/presentation/shaders/lurker_sight.gdshader")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const FILES := preload("res://game/floors/objectives/files_objective.gd")
## The shader's halo slots, and its kinds.
const MOST := 128
enum Kind { GLOW, TORCH, BODY, COLD, RING }
## A lit torch is a beacon through the walls this far (decision A).
const BEACON_REACH := 30.0
## Heat (place on the map): a lit room's air, a fitting, an emergency unit, a
## landmark's lamp, a furniture lamp, an objective's machine and its lamp, a
## running air handler, a body seen, a torch.
const ROOM_HEAT := 0.5
const FITTING_HEAT := 0.72
const EMERGENCY_HEAT := 0.66
const LANDMARK_HEAT := 0.74
const ACCENT_HEAT := 0.64
const MACHINE_HEAT := 0.8
const LAMP_HEAT := 0.95
const FAN_HEAT := 0.86
const BODY_HEAT := 0.42
const TORCH_HEAT := 1.15
## What an objective's usable does that runs on electricity.
const ELECTRIC := ["type", "take", "swipe", "lever", "red", "switch", "post", "start", "stop"]
## Lamps further than this are left out, and from FADE_FROM they cool a little.
const LAMP_REACH := 45.0
const FADE_FROM := 15.0
## The registers are read this often; the halos are placed every frame.
const GATHER_EVERY := 0.1
## A halo is never drawn smaller than this (screen heights): a far lamp is a point.
const LEAST_RADIUS := 0.006
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
## The flash: up to white in FLASH_RISE, back in FLASH_FALL, none again for
## FLASH_RISE + FLASH_FALL + FLASH_IMMUNE; with reduced effects only half as
## white, and steady.
const FLASH_RISE := 0.15
const FLASH_FALL := 2.5
const FLASH_IMMUNE := 1.0
const REDUCED_PEAK := 0.5

var driver
var creature
var level
var camera: Camera3D
var field: MeshInstance3D
var material: ShaderMaterial
var plan: Control
var clock := 0.0
var gather_clock := 0.0
## [point, radius, heat] of the registers' heat on her planta, nearest first.
var lamps: Array = []
## seat -> the survivor whose torch she has as a beacon; seat -> seen.
var beacons := {}
var seen := {}
var cold: Array = []
var dazzle := 0.0
var dazzled := false
## {point, born, heat, size, kind}
var rings: Array = []
var torch_was := {}
var run_clocks := {}
var type_clock := 0.0
var requests_seen := {}
var flash_clock := -1.0
var flash_from := Vector2.ZERO
var immune_until := -1.0
## Room -> the points of its fittings (its troffers, or its lamp).
var fittings := {}
var halo_a := PackedVector4Array()
var halo_b := PackedVector4Array()
var placed := 0

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
	plan = DuctPlan.new()
	plan.view = self
	plan.set_anchors_preset(Control.PRESET_FULL_RECT)
	plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.visible = false
	cover.add_child(plan)
	halo_a.resize(MOST)
	halo_b.resize(MOST)
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
	plan.visible = on and driver.dark
	if not on: return
	if plan.visible: plan.tick(delta)
	listen(delta)
	gather_clock -= delta
	if gather_clock <= 0.0:
		gather_clock = GATHER_EVERY
		gather()
	dazzle = move_toward(dazzle, 1.0 if dazzled else 0.0, DAZZLE_RATE * delta)
	place()

# --- The registers ---------------------------------------------------------------------

func planta() -> int: return FLOOR.planta_of(camera.global_position.y)

func wing_of(room_id: int) -> int:
	return int(level.manifest.rooms[room_id].get("wing", -1)) if room_id >= 0 and room_id < level.manifest.rooms.size() else -1

## The registers' heat on her planta, nearest first; what she makes out of
## the survivors; whether her room dazzles her.
func gather() -> void:
	var hotel = level.hotel
	var here := planta()
	var eye := camera.global_position
	var found: Array = []
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != here or id >= hotel.lights.size() or not hotel.lit(id): continue
		var light: OmniLight3D = hotel.lights[id]
		if light.has_meta("off") or light.has_meta("void"): continue
		var left: float = 1.0 - 0.5 * float(hotel.drained(id))
		var size := FLOOR.size_of(room)
		found.append([light.global_position - Vector3(0, 0.6, 0), clampf(minf(size.x, size.y) * 0.5, 1.5, 4.0), ROOM_HEAT * left])
		for point in fittings_of(id): found.append([point, 0.4, FITTING_HEAT * left])
	if "emergency" in hotel:
		for e: Dictionary in hotel.emergency:
			if int(e.planta) == here and not hotel.lit(int(e.room)): found.append([(e.light as Node3D).global_position, 0.3, EMERGENCY_HEAT])
	if "landmark_lamps" in hotel:
		for entry: Dictionary in hotel.landmark_lamps:
			if wing_of(int(entry.room)) == here: found.append([(entry.light as Node3D).global_position, 0.45, LANDMARK_HEAT])
	if "accents" in hotel:
		for room_id: int in hotel.accents.rooms:
			if wing_of(room_id) != here or not hotel.lit(room_id): continue
			for entry: Dictionary in hotel.accents.of_room(room_id):
				if is_instance_valid(entry.get("light")): found.append([(entry.light as Node3D).global_position, 0.3, ACCENT_HEAT])
	for objective in level.objectives.values():
		if "usables" in objective:
			for usable in objective.usables:
				if is_instance_valid(usable) and String(usable.action) in ELECTRIC and FLOOR.planta_of(usable.global_position.y) == here: found.append([usable.global_position, 0.4, MACHINE_HEAT])
		for key in ["lamps", "pilots"]:
			if not key in objective: continue
			for lamp in objective.get(key):
				if lamp is Light3D and lamp.visible and FLOOR.planta_of(lamp.global_position.y) == here: found.append([lamp.global_position, 0.45, LAMP_HEAT])
		if "rotors" in objective and objective.running():
			for rotor in objective.rotors: found.append([(rotor as Node3D).global_position, 0.9, FAN_HEAT])
	for entry in found:
		var d: float = eye.distance_to(entry[0])
		entry[2] = float(entry[2]) * (1.0 - 0.25 * smoothstep(FADE_FROM, LAMP_REACH, d))
		entry.append(d)
	lamps = found.filter(func(entry: Array) -> bool: return float(entry[3]) < LAMP_REACH)
	lamps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) < float(b[3]))
	look_at_survivors(eye)
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, eye)
	dazzled = not room.is_empty() and not driver.dark and hotel.lit(int(room.id))

## A room's fittings: its troffers where it has them (office_geometry halos'
## pools), else its lamp. Found once.
func fittings_of(id: int) -> Array:
	if fittings.has(id): return fittings[id]
	var points: Array = []
	var hotel = level.hotel
	if "halos" in hotel and hotel.halos.has(id):
		for pool in hotel.halos[id].get("pools", []):
			if is_instance_valid(pool) and not "Bounce" in String(pool.name): points.append((pool as Node3D).global_position)
	if points.is_empty(): points.append(hotel.lights[id].global_position)
	fittings[id] = points
	return points

## Whose torch is her beacon, whom she sees, whose mind has gone.
func look_at_survivors(eye: Vector3) -> void:
	beacons.clear()
	seen.clear()
	var senses = creature.get("senses")
	# Her face behind a shut tile, or deep in a duct: nothing.
	var eyes: bool = senses != null and senses.eye_point() != Vector3.INF
	for one in level.survivors():
		if not is_instance_valid(one) or not level.survivor_active(one) or bool(one.get("hidden")): continue
		var sees: bool = eyes and senses.sees(one)
		if sees: seen[int(one.slot)] = one
		var torch = one.get("torch")
		if not eyes or not is_instance_valid(torch) or not torch.visible or senses.drank(one): continue
		if sees or (torch.global_position as Vector3).distance_to(eye) <= BEACON_REACH: beacons[int(one.slot)] = one
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

## A noise where she hears it, as she hears it, or nowhere.
func ring(point: Vector3, radius: float, heat: float, size: float) -> void:
	if not creature.has_method("hear_route"): return
	var route: Dictionary = creature.hear_route(point, radius)
	if not bool(route.get("audible", false)): return
	var at: Vector3 = point if float(route.distance) < RING_TRUTH else route.apparent
	rings.append({"point": at, "born": clock, "heat": heat, "size": size})

# --- The flash -------------------------------------------------------------------------

## A torch full in her face, from `from_direction` (world, from her to it):
## the picture goes white from that side in FLASH_RISE and comes back over
## FLASH_FALL. False while she is still immune to another.
func flash(from_direction: Vector3) -> bool:
	if clock < immune_until: return false
	flash_clock = clock
	immune_until = clock + FLASH_RISE + FLASH_FALL + FLASH_IMMUNE
	var local: Vector3 = camera.global_basis.inverse() * from_direction
	flash_from = Vector2(local.x, local.y).normalized() if Vector2(local.x, local.y).length() > 0.05 else Vector2.ZERO
	return true

## How white now, 0 to 1 (the peak is the shader's).
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

# --- On the screen ---------------------------------------------------------------------

## Every halo to the shader, in screen space: torches, rings, bodies and
## outlines first, then the registers' heat, nearest first.
func place() -> void:
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var focal: float = 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
	var from_eye: Transform3D = camera.global_transform.affine_inverse()
	placed = 0
	# (A lambda keeps a copy of a local: the count is the view's.)
	var put := func(point: Vector3, radius: float, heat: float, kind: int, stretch := 1.0, thickness := 0.0) -> void:
		if placed >= MOST: return
		var depth: float = -(from_eye * point).z
		if depth < 0.05: return
		var at: Vector2 = camera.unproject_position(point) / size
		var r: float = maxf(radius / depth * focal, LEAST_RADIUS)
		var reach: float = r * stretch * 4.0
		if at.x < -reach or at.x > 1.0 + reach or at.y < -reach or at.y > 1.0 + reach: return
		halo_a[placed] = Vector4(at.x, at.y, r, heat)
		halo_b[placed] = Vector4(kind, stretch, thickness, camera.global_position.distance_to(point))
		placed += 1
	for seat_id in beacons:
		var one = beacons[seat_id]
		if is_instance_valid(one) and is_instance_valid(one.get("torch")): put.call(one.torch.global_position, 0.35, TORCH_HEAT, Kind.TORCH)
	rings = rings.filter(func(entry: Dictionary) -> bool: return clock - float(entry.born) < RING_LIFE)
	for entry in rings:
		var age: float = (clock - float(entry.born)) / RING_LIFE
		put.call(entry.point, float(entry.size) * (0.25 + 0.75 * (1.0 - (1.0 - age) * (1.0 - age))), float(entry.heat) * (1.0 - age), Kind.RING, 1.0, 0.12)
	for seat_id in seen:
		var one = seen[seat_id]
		if is_instance_valid(one): put.call(one.global_position + Vector3(0, 0.95, 0), 0.36, BODY_HEAT, Kind.BODY, 2.5)
	for point in cold: put.call(point + Vector3(0, 0.95, 0), 0.5, 0.3, Kind.COLD, 2.1)
	for entry in lamps: put.call(entry[0], entry[1], entry[2], Kind.GLOW)
	material.set_shader_parameter("count", placed)
	material.set_shader_parameter("halo_a", halo_a)
	material.set_shader_parameter("halo_b", halo_b)
	material.set_shader_parameter("dazzle", dazzle)
	material.set_shader_parameter("flash", flash_now())
	material.set_shader_parameter("flash_from", flash_from)
	material.set_shader_parameter("flash_peak", REDUCED_PEAK if level.settings.values.reduced else 1.0)
	material.set_shader_parameter("now", clock)

## matplotlib's plasma (the shader's fit), for what is drawn in 2D.
static func plasma(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var c := [Vector3(0.05873234392399702, 0.02333670892565664, 0.5433401826748754), Vector3(2.176514634195958, 0.2383834171260182, 0.7539604599784036), Vector3(-2.689460476458034, -7.455851135738909, 3.110799939717086), Vector3(6.130348345893603, 42.3461881477227, -28.51885465332158), Vector3(-11.10743619062271, -82.66631109428045, 60.13984767418263), Vector3(10.02306557647065, 71.41361770095349, -54.07218655560067), Vector3(-3.658713842777788, -22.93153465461149, 18.19190778539828)]
	var v: Vector3 = c[6]
	for k in range(5, -1, -1): v = c[k] + v * t
	return Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0))

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

	## 1 near her, to nothing past REACH (from FADE).
	func near(p: Vector3, at: Vector3) -> float:
		return 1.0 - smoothstep(FADE, REACH * 1.6, Vector2(p.x - at.x, p.z - at.z).length())
