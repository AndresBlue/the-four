extends Node
## Her eyes in Versus (.claude/specs/lurker_versus.md 4.5, remade by 13.9
## after the author's second game): a thermal camera in a very dark navy,
## where only the light and the electricity are heat. Her seat
## (presentation_rig.echo_seat) puts the floor's lamps, decals, dust and fog
## out (hotel.echo_view) and draws no lens. Over all of it a quad on her camera
## (game/presentation/shaders/lurker_sight.gdshader) reads the world from the
## depth: the bare surfaces low, even and blotched, the survivors as dark
## figures cut out by a pale rim (never as heat), and the heat from the floor's
## registers, never from what is lit, as shapes: the lenses of the lit rooms'
## fittings, the emergency units, the landmarks' and the furniture's lamps,
## the objectives' machines (beating while somebody is at one), the air
## plant's rotors, the live wires to their switches, and the torches, hottest
## of all. A source behind a wall warms the face of the wall. The camera's gain
## stretches the picture between the coldest and the hottest in view, slowly;
## her sensor (lurker_thermal_sensor.gdshader) makes a recording of it, and
## now and then it freezes a moment with a click to calibrate.
##
## Her camera is always behind and over her (lurker_player.gd). Over the false
## ceiling this machine does not draw the ceiling of her planta (ceilings()):
## the same reading looks down into the rooms, with the T-grid faint round her,
## the cores and the building's edge standing up to the slab as what stops her
## (barriers), and nothing past her prey's reach but what burns. She herself,
## her real body and its ink, is drawn alone by a camera of her own and laid
## over the recording with a cold rim (lurker_her.gdshader). Her marks are in
## the world, in the reading's terms (lurker_mark.gdshader): the outline of
## the tile she would go down by, of the way into the ducts at hand, her prey
## white (the attack may go) or red, and why not: the line of a look on where
## she would drop, or of the torch on it, or the lit room under it reddened.
## In the ducts (as The Locust between its sets) the cold goes dark purple,
## the network's tubes light up pink and its ways out stand up as columns of
## light; the one she looks at burns white. Her keys are along the foot as the
## control hints draw theirs (hotel_ui.show_controls()): each key in its
## keycap and its action's name, what cannot be done now dim, a wait drained
## on its own key; a key beside the piece it works on. Sent off, the picture
## closes in a moment.
##
## What she is given of the survivors: a lit torch through the walls within
## BEACON_REACH (none she drank, none while her face is behind a shut tile or
## deep in a duct), figures within her prey's reach, and anybody whose mind
## has gone through the walls as a cold outline. Her own lit room floods the
## sensor past a few metres. flash() is a torch in her face (the host fires
## it: lurker.scare_off()): the camera saturated. All of it local to her
## machine: nothing travels for it.
const SIGHT_SHADER := preload("res://game/presentation/shaders/lurker_sight.gdshader")
const SENSOR_SHADER := preload("res://game/presentation/shaders/lurker_thermal_sensor.gdshader")
const MARK_SHADER := preload("res://game/presentation/shaders/lurker_mark.gdshader")
const HER_SHADER := preload("res://game/presentation/shaders/lurker_her.gdshader")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const VISUAL := preload("res://game/enemies/lurker/lurker_visual.gd")
const STYLE := preload("res://game/ui/osd_style.gd")
## The shader's source and wire slots, and its kinds (its LAMP, TORCH, COLD).
const MOST := 96
const WIRES := 48
enum Kind { LAMP = 0, TORCH = 1, COLD = 3 }
## A lit torch is a beacon through the walls this far (decision A).
const BEACON_REACH := 30.0
## Heat (a reading): a fitting, an emergency unit, a landmark's lamp, a
## furniture lamp, an objective's machine and its lamp, a running air handler,
## a torch, a live wire over its surface. A machine in use beats by BEAT.
const FITTING_HEAT := 0.72
const EMERGENCY_HEAT := 0.66
const LANDMARK_HEAT := 0.74
const ACCENT_HEAT := 0.64
const MACHINE_HEAT := 0.8
const LAMP_HEAT := 0.95
const FAN_HEAT := 0.86
const TORCH_HEAT := 1.15
const WIRE_HEAT := 0.07
const BEAT := 0.35
## The half sizes of what is not a troffer (metres): an emergency unit, a lamp,
## a station's or a pilot's lamp, a rotor, a torch's head. A usable's is most
## of its focus box.
const UNIT_HALF := Vector3(0.16, 0.08, 0.08)
const LAMP_HALF := Vector3(0.15, 0.15, 0.15)
const PILOT_HALF := Vector3(0.05, 0.05, 0.05)
const ROTOR_HALF := Vector3(0.45, 0.45, 0.45)
const TORCH_HALF := Vector3(0.06, 0.06, 0.06)
const USABLE_SHARE := 0.4
## What an objective's usable does that runs on electricity; somebody this near
## one is using it.
const ELECTRIC := ["type", "take", "swipe", "lever", "red", "switch", "post", "start", "stop"]
const BUSY_REACH := 1.6
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
const GAIN_LEAST := 0.5
const GAIN_SHARE := 1.0
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
## The flash: saturated in FLASH_RISE, back in FLASH_FALL, none again for
## FLASH_RISE + FLASH_FALL + FLASH_IMMUNE; with reduced effects only half as
## far, and steady.
const FLASH_RISE := 0.15
const FLASH_FALL := 2.5
const FLASH_IMMUNE := 1.0
const REDUCED_PEAK := 0.5
## What the reading packs (lurker_sight.gdshader's FOOT and RANGE).
const FOOT := -0.4
const RANGE := 1.6
## Survivors drawn as figures, lit rooms lifted from over the ceiling.
const FIGURES := 16
const LITS := 32
const LIT_REACH := 30.0
## Over the false ceiling of her planta, not drawn on her machine: a room's
## tiles, grid and troffer housings, what hangs from them and its occluder
## (which would hide the room from above).
const CEILING_PARTS := ["Mesh_ceiling_service", "Mesh_tgrid", "Mesh_troffer_body", "CeilingHalo", "LensGhosts", "Occluder"]
const CEILING_FROM := ["Model_detector_humo", "Model_rociador", "Tile_"]
## What stops her over the ceiling, up to the slab: a core over its ceiling, the
## building's edge this thick.
const EDGE := 0.2
## The ducts: a tube's width by its kind; a way out's column, this wide (the
## one she looks at, PICKED wide); her marks' lines this thick at least, and
## this share of the metres to them.
const TUBE := {"main": 0.6, "trunk": 0.45, "express": 0.4, "drop": 0.2}
const TUBE_LEAST := 0.3
const COLUMN := 0.12
const PICKED := 0.22
const LINE := 0.03
const LINE_SHARE := 0.0025
## Beber's wait (lurker.VERSUS_EVERY), drained on its key.
const DRINK_EVERY := 25.0
## A key not to be pressed now.
const DIM := 0.3
## Into and out of the ducts' colours (per second).
const DUCTS_RATE := 3.0

var driver
var creature
var level
var camera: Camera3D
var field: MeshInstance3D
var material: ShaderMaterial
var sensor: CanvasLayer
var sensor_material: ShaderMaterial
var frozen: TextureRect
var click: AudioStreamPlayer
var clock := 0.0
var gather_clock := 0.0
## The registers' heat on her planta, nearest first:
## [point, half size, yaw, heat, kind, busy, metres, in view, metres behind what hides it].
var lamps: Array = []
## [from, to, heat] of the live wires near her.
var wires: Array = []
## Lit rooms near her: [metres, room, how lit].
var lit_rooms: Array = []
## seat -> the survivor whose torch she has as a beacon; seat -> [in view,
## metres behind what hides it] of its torch.
var beacons := {}
var torch_view := {}
var cold: Array = []
var dazzle := 0.0
var dazzled := false
var ducts_shade := 0.0
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
## The ceilings not drawn now (their nodes) and for which planta.
var hidden_parts: Array = []
var hidden_planta := -1
## Planta -> what stops her, as one mesh; planta -> its network of tubes.
var walls := {}
var tubes := {}
## Her marks (depth tested, and seen through everything).
var marks: MeshInstance3D
var marks_through: MeshInstance3D
var mark_material: ShaderMaterial
var through_material: ShaderMaterial
## Her body alone, by her own camera, over the recording.
var her_port: SubViewport
var her_eye: Camera3D
var her_layer: CanvasLayer
## Her keys along the foot, and the keys beside the pieces.
var keys_bar: HBoxContainer
var keys_sign := ""
var tags := {}
var hud: Control
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
	# Her marks after her reading (its priority), in its terms.
	mark_material = ShaderMaterial.new()
	mark_material.shader = MARK_SHADER
	mark_material.render_priority = 121
	var seen_through := Shader.new()
	seen_through.code = MARK_SHADER.code.replace("depth_draw_always", "depth_draw_never, depth_test_disabled")
	through_material = ShaderMaterial.new()
	through_material.shader = seen_through
	through_material.render_priority = 122
	marks = world_mesh("Marks", mark_material)
	marks_through = world_mesh("MarksThrough", through_material)
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
	setup_her()
	hud = Hud.new()
	hud.view = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	cover.add_child(hud)
	keys_bar = HBoxContainer.new()
	keys_bar.name = "Keys"
	keys_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	keys_bar.add_theme_constant_override("separation", 30)
	cover.add_child(keys_bar)
	keys_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	keys_bar.offset_top = -74
	keys_bar.offset_bottom = -36
	keys_bar.visible = false
	for kind in ["way", "down"]:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.visible = false
		cover.add_child(holder)
		tags[kind] = holder
	heat_at.resize(MOST)
	heat_box.resize(MOST)
	heat_screen.resize(MOST)
	heat_kind.resize(MOST)
	wire_a.resize(WIRES)
	wire_b.resize(WIRES)
	nuc_clock = randf_range(NUC_EVERY.x, NUC_EVERY.y)

## A mesh of hers in the world, drawn by her camera only while her view is on.
func world_mesh(title: String, with: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.top_level = true
	mesh.mesh = ArrayMesh.new()
	mesh.material_override = with
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	mesh.visible = false
	add_child(mesh)
	return mesh

## Her own camera, which draws nothing but her, and its picture over the
## recording with its rim (lurker_her.gdshader). It shares the floor's world.
func setup_her() -> void:
	her_port = SubViewport.new()
	her_port.name = "Her"
	her_port.transparent_bg = true
	her_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(her_port)
	her_eye = Camera3D.new()
	her_eye.cull_mask = VISUAL.LAYER
	var lit := Environment.new()
	lit.background_mode = Environment.BG_CLEAR_COLOR
	lit.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lit.ambient_light_color = Color(0.4, 0.5, 0.75)
	lit.ambient_light_energy = 0.8
	lit.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	her_eye.environment = lit
	her_port.add_child(her_eye)
	her_eye.current = true
	her_layer = CanvasLayer.new()
	her_layer.name = "HerLayer"
	her_layer.layer = 2
	her_layer.visible = false
	add_child(her_layer)
	var picture := TextureRect.new()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = her_port.get_texture()
	var rim := ShaderMaterial.new()
	rim.shader = HER_SHADER
	picture.material = rim
	her_layer.add_child(picture)

## Whether her camera is the picture and her seat is hers (the rig's).
func seat() -> bool:
	return camera.current and level.get("rig") != null and level.rig.echo_seat()

## Her camera over the false ceiling (the plenum, a gallery's slab or the ducts).
func above() -> bool: return driver.mode != "down"

func _process(delta: float) -> void:
	clock += delta
	var on := seat()
	var up := on and above()
	field.visible = on
	sensor.visible = on
	hud.visible = on
	keys_bar.visible = on
	her_layer.visible = on and clock >= frozen_until
	her_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	marks.visible = on
	marks_through.visible = on
	ceilings(planta() if up else -1)
	for p in walls: walls[p].visible = up and int(p) == planta()
	for p in tubes: tubes[p].visible = on and driver.mode == "ducts" and int(p) == planta()
	if click.playing and clock >= click_until: click.stop()
	var deep := int(creature.get("deep_room")) if creature.get("deep_room") != null else -1
	if deep >= 0 and deep_was < 0: drank_at = clock
	deep_was = deep
	if not on:
		for kind in tags: tags[kind].visible = false
		return
	if up: barriers(planta())
	if driver.mode == "ducts": network(planta())
	gather_clock -= delta
	if gather_clock <= 0.0:
		gather_clock = GATHER_EVERY
		gather()
	dazzle = move_toward(dazzle, 1.0 if dazzled else 0.0, DAZZLE_RATE * delta)
	ducts_shade = move_toward(ducts_shade, 1.0 if driver.mode == "ducts" else 0.0, DUCTS_RATE * delta)
	calibrate(delta)
	place(delta)
	place_marks()
	place_her()
	show_keys(rows())
	hud.queue_redraw()

func _exit_tree() -> void: ceilings(-1)

# --- What she sees down into ----------------------------------------------------------

## Hers (from over her, her camera may be above the slab).
func planta() -> int: return driver.planta()

## The ceilings of `here` not drawn on this machine (none for -1): her rooms'
## false ceilings, so her reading looks down into them. Only the drawing:
## their colliders stay, and every other machine draws them.
func ceilings(here: int) -> void:
	if here == hidden_planta: return
	for node in hidden_parts:
		if is_instance_valid(node): node.visible = true
	hidden_parts.clear()
	hidden_planta = here
	if here < 0 or level.get("hotel") == null: return
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != here or not creature.shell.tray_of.has(id) or not OFFICE.false_ceiling(room) or id >= level.hotel.room_nodes.size(): continue
		var node: Node3D = level.hotel.room_nodes[id]
		if not is_instance_valid(node): continue
		for child in node.get_children():
			var title := String(child.name)
			if not child is Node3D or not (child as Node3D).visible: continue
			if title in CEILING_PARTS or CEILING_FROM.any(func(start: String) -> bool: return title.begins_with(start)):
				(child as Node3D).visible = false
				hidden_parts.append(child)

## What stops her over the ceiling of `here`, as what it is, up to the slab
## (13.9): over each core (a room with no ceiling of hers) a block from its
## ceiling, and along the building's edge a wall. Built once.
func barriers(here: int) -> void:
	if walls.has(here): return
	var floor_y := FLOOR.planta_y(here)
	var low := floor_y + float(OFFICE.PLENUM.ceiling)
	var high := floor_y + float(OFFICE.PLENUM.slab)
	var shape := Shape.new()
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != here or FLOOR.is_void(room): continue
		var size := FLOOR.size_of(room)
		var middle := Vector3(float(room.px), (low + high) * 0.5, float(room.pz))
		if not creature.shell.tray_of.has(int(room.id)):
			shape.box(middle, Vector3(size.x * 0.5, (high - low) * 0.5, size.y * 0.5), Basis.IDENTITY, Color.BLACK)
			continue
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var reach: float = (Vector2(size.x, size.y) * 0.5 * side.abs()).length()
			var out := Vector2(float(room.px), float(room.pz)) + side * (reach + 0.15)
			var other := FLOOR.room_at(level.manifest.rooms, Vector3(out.x, floor_y + 1.0, out.y))
			if not other.is_empty() and not FLOOR.is_void(other): continue
			var along := (Vector2(size.y, size.x) * 0.5 * side.abs()).length()
			var at := Vector2(float(room.px), float(room.pz)) + side * reach
			var half := Vector3(EDGE * 0.5 if side.x != 0.0 else along, (high - low) * 0.5, along if side.x != 0.0 else EDGE * 0.5)
			shape.box(Vector3(at.x, middle.y, at.y), half, Basis.IDENTITY, Color.BLACK)
	var mesh := MeshInstance3D.new()
	mesh.name = "Barriers%d" % here
	mesh.top_level = true
	mesh.mesh = shape.mesh()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = StandardMaterial3D.new()
	add_child(mesh)
	walls[here] = mesh

## The ducts' network of `here`, its tubes (pink in her sensor), built once.
func network(here: int) -> void:
	if tubes.has(here): return
	var ducts = creature.ducts
	var shape := Shape.new()
	for edge in ducts.edges:
		var a := int(edge[0])
		var b := int(edge[1])
		if String(edge[3]) == "plenum" or ducts.node_wings[a] != here or ducts.node_wings[b] != here: continue
		shape.beam(ducts.nodes[a], ducts.nodes[b], float(TUBE.get(String(edge[3]), TUBE_LEAST)), Color(packed(0.05), 0.6, 0.0, 1.0))
	var mesh := world_mesh("Tubes%d" % here, mark_material)
	mesh.mesh = shape.mesh()
	tubes[here] = mesh

## A reading packed as her shaders pack it.
static func packed(v: float) -> float: return clampf((v - FOOT) / (RANGE - FOOT), 0.0, 1.0)

# --- The registers ---------------------------------------------------------------------

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
	lit_rooms = []
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != here or id >= hotel.lights.size() or not hotel.lit(id): continue
		var light: OmniLight3D = hotel.lights[id]
		if light.has_meta("off") or light.has_meta("void"): continue
		var left: float = 1.0 - 0.5 * float(hotel.drained(id))
		for shape in shapes_of(id): found.append([shape[0], shape[1], shape[2], FITTING_HEAT * left, Kind.LAMP, false])
		var middle := FLOOR.position_of(room)
		lit_rooms.append([Vector2(middle.x - eye.x, middle.z - eye.z).length(), id, left])
	if "emergency" in hotel:
		for e: Dictionary in hotel.emergency:
			if int(e.planta) != here or hotel.lit(int(e.room)): continue
			var unit: Node3D = e.lens if is_instance_valid(e.get("lens")) else e.light
			found.append([unit.global_position, UNIT_HALF, unit.global_rotation.y, EMERGENCY_HEAT, Kind.LAMP, false])
	if "landmark_lamps" in hotel:
		for entry: Dictionary in hotel.landmark_lamps:
			if wing_of(int(entry.room)) == here: found.append([(entry.light as Node3D).global_position, LAMP_HALF, 0.0, LANDMARK_HEAT, Kind.LAMP, false])
	if "accents" in hotel:
		for room_id: int in hotel.accents.rooms:
			if wing_of(room_id) != here or not hotel.lit(room_id): continue
			for entry: Dictionary in hotel.accents.of_room(room_id):
				if is_instance_valid(entry.get("light")): found.append([(entry.light as Node3D).global_position, LAMP_HALF, 0.0, ACCENT_HEAT, Kind.LAMP, false])
	for objective in level.objectives.values():
		if "usables" in objective:
			for usable in objective.usables:
				if is_instance_valid(usable) and String(usable.action) in ELECTRIC and FLOOR.planta_of(usable.global_position.y) == here:
					var point: Vector3 = usable.global_transform * Vector3(0, 0, usable.box.z * 0.5)
					found.append([point, usable.box * USABLE_SHARE, usable.global_rotation.y, MACHINE_HEAT, Kind.LAMP, busy(point)])
		for key in ["lamps", "pilots"]:
			if not key in objective: continue
			for lamp in objective.get(key):
				if lamp is Light3D and lamp.visible and FLOOR.planta_of(lamp.global_position.y) == here: found.append([lamp.global_position, PILOT_HALF, 0.0, LAMP_HEAT, Kind.LAMP, false])
		if "rotors" in objective and objective.running():
			for rotor in objective.rotors: found.append([(rotor as Node3D).global_position, ROTOR_HALF, 0.0, FAN_HEAT, Kind.LAMP, false])
	for entry in found:
		var d: float = eye.distance_to(entry[0])
		entry[3] = float(entry[3]) * (1.0 - 0.25 * smoothstep(FADE_FROM, LAMP_REACH, d))
		entry.append(d)
	lamps = found.filter(func(entry: Array) -> bool: return float(entry[6]) < LAMP_REACH)
	lamps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[6]) < float(b[6]))
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
	dazzled = not room.is_empty() and not above() and hotel.lit(int(room.id))

## Somebody at a machine: using it, or about to.
func busy(point: Vector3) -> bool:
	for one in level.survivors():
		if is_instance_valid(one) and level.survivor_active(one) and absf(one.global_position.y - point.y) < BUSY_REACH + 1.0 and Vector2(one.global_position.x - point.x, one.global_position.z - point.z).length() < BUSY_REACH: return true
	return false

## [in view, metres behind what hides it] of a point from her eye. From over
## the ceiling all of it: what would hide it is not drawn.
func in_view(eye: Vector3, point: Vector3, exclude: Array) -> Array:
	if above(): return [true, 0.0]
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

## Whose torch is her beacon, whose mind has gone.
func look_at_survivors(eye: Vector3) -> void:
	beacons.clear()
	torch_view.clear()
	var senses = creature.get("senses")
	# Her face behind a shut tile, or deep in a duct: nothing; but from over
	# the ceiling she has the torches (13.6 A2).
	var eyes: bool = senses != null and (senses.eye_point() != Vector3.INF or above())
	for one in level.survivors():
		if not is_instance_valid(one) or not level.survivor_active(one) or bool(one.get("hidden")): continue
		var torch = one.get("torch")
		if not eyes or not is_instance_valid(torch) or not torch.visible or senses.drank(one): continue
		if (torch.global_position as Vector3).distance_to(eye) <= BEACON_REACH:
			beacons[int(one.slot)] = one
			torch_view[int(one.slot)] = in_view(eye, torch.global_position, [one.get_rid()] if one is CollisionObject3D else [])
	cold = level.sanity.burnt_survivors() if level.get("sanity") != null else []

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
## camera puts its halo; torches and outlines first, then the registers' heat,
## nearest first. The gain follows the hottest in view. And what the reading
## draws of the survivors and, from over the ceiling, of her rooms.
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
	for point in cold: put.call(point + Vector3(0, 0.95, 0), Vector3(0.0, 2.1, 0.0), 0.0, 0.0, Kind.COLD, false, 0.0)
	# A machine somebody is at beats.
	var beat := 1.0 - BEAT * (0.5 + 0.5 * sin(clock * 5.0))
	for entry in lamps: put.call(entry[0], entry[1], float(entry[2]), float(entry[3]) * (beat if bool(entry[5]) else 1.0), Kind.LAMP, bool(entry[7]), float(entry[8]))
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
	place_figures()
	var calm: float = REDUCED_NOISE if reduced else 1.0
	sensor_material.set_shader_parameter("noise", NOISE_HEAT / (gain_high - GAIN_LOW) * calm)
	sensor_material.set_shader_parameter("stripes", STRIPES * calm)
	sensor_material.set_shader_parameter("now", clock)
	sensor_material.set_shader_parameter("ducts", ducts_shade)

## The survivors as figures (her prey white or red), and from over the
## ceiling her point, the grid round her and the lit rooms.
func place_figures() -> void:
	var at: Vector3 = creature.motion.anchor()
	var here := planta()
	var info: Dictionary = driver.prey_info
	var figures := PackedVector4Array()
	figures.resize(FIGURES)
	var count := 0
	for one in level.survivors():
		if count >= FIGURES or not driver.markable(one, at, here): continue
		var mark := 0.0
		# Her prey white while she may go, or while she goes (her attack, her warning).
		var going: bool = not driver.attack.is_empty() or creature.cue
		if int(one.slot) == driver.prey: mark = 1.0 if bool(info.get("ok", false)) or going else 2.0
		figures[count] = Vector4(one.global_position.x, one.global_position.y, one.global_position.z, mark)
		count += 1
	material.set_shader_parameter("figure_count", count)
	material.set_shader_parameter("figure_at", figures)
	var up := above()
	material.set_shader_parameter("up_view", 1.0 if up else 0.0)
	material.set_shader_parameter("focus", at)
	material.set_shader_parameter("grid_y", at.y - driver.RISE)
	material.set_shader_parameter("reach", driver.PREY_REACH)
	var rects := PackedVector4Array()
	var heats := PackedFloat32Array()
	rects.resize(LITS)
	heats.resize(LITS)
	var lits := 0
	for entry in lit_rooms:
		if lits >= LITS or float(entry[0]) > LIT_REACH: continue
		rects[lits] = rect_of(int(entry[1]))
		heats[lits] = float(entry[2])
		lits += 1
	material.set_shader_parameter("lit_count", lits if up else 0)
	material.set_shader_parameter("lit_rect", rects)
	material.set_shader_parameter("lit_heat", heats)
	var red := int(info.get("room", -1))
	material.set_shader_parameter("red_rect", rect_of(red) if red >= 0 and driver.prey >= 0 else Vector4.ZERO)

## A room's floor, (min x, min z, max x, max z).
func rect_of(id: int) -> Vector4:
	var room: Dictionary = level.manifest.rooms[id]
	var half := FLOOR.size_of(room) * 0.5
	return Vector4(float(room.px) - half.x, float(room.pz) - half.y, float(room.px) + half.x, float(room.pz) + half.y)

## Her marks in the world, and the keys beside the pieces they work on: the
## tile she would go down by (or drop by on her prey), the way into the ducts
## at hand, why her prey is not hers; in the ducts, the ways out and the way
## along to the one she looks at.
func place_marks() -> void:
	var near := Shape.new()
	var far := Shape.new()
	var pale := Color(packed(0.0), 1.0, 0.0, 0.0)
	var red := Color(packed(0.0), 0.0, 1.0, 0.0)
	var down_at := Vector3.INF
	var way_at := Vector3.INF
	var phase := String(driver.trip.get("phase", ""))
	var ducts = creature.ducts
	if driver.mode == "ducts":
		if phase in ["pick", "ask"]:
			var pick := int(driver.trip.pick)
			for entry in driver.trip.targets:
				var e := int(entry[0])
				if e == pick: continue
				column(far, ducts.exits[e], COLUMN, Color(packed(0.9), 0.0, 0.0, 0.0))
			if pick >= 0:
				var beat := 0.5 + 0.5 * sin(clock * 6.0)
				column(far, ducts.exits[pick], PICKED * (1.0 + 0.25 * beat), Color(packed(1.25 + 0.3 * beat), 0.0, 0.0, 0.0))
				route(near, ducts.points_of(ducts.shortest(int(ducts.exits[int(driver.trip.from)].node), int(ducts.exits[pick].node)).path))
				way_at = ducts.exits[pick].position
		elif phase == "go":
			route(near, driver.trip.points)
			var points: PackedVector3Array = driver.trip.points
			if not points.is_empty(): column(far, ducts.exits[int(driver.trip.pick)], PICKED, Color(packed(1.25), 0.0, 0.0, 0.0))
	elif driver.up() and driver.attack.is_empty():
		var way: Dictionary = driver.down_way()
		if not way.is_empty() and not driver.gallery():
			down_at = way.point
			outline(near, down_at, 0.3, pale)
		var e: int = driver.entrance()
		if e >= 0:
			way_at = ducts.exits[e].position
			outline(far, way_at, 0.34, pale)
	# Her prey: the tile she would drop by behind it, and why not.
	var info: Dictionary = driver.prey_info
	if driver.prey >= 0 and driver.mode != "ducts":
		var drop: Dictionary = info.get("drop", {})
		var ok := bool(info.get("ok", false))
		if not drop.is_empty() and driver.attack.is_empty(): outline(near, drop.point, 0.3, pale if ok else red)
		var from: Vector3 = info.get("from", Vector3.INF)
		var to: Vector3 = info.get("face", Vector3.INF)
		if from != Vector3.INF and to != Vector3.INF: line(far, from, to, red)
	marks.mesh = near.mesh()
	marks_through.mesh = far.mesh()
	tag("way", way_at, "lurker_enter")
	tag("down", down_at, "lurker_drop")

## A way out of the ducts as a column of light, from it up to the slab.
func column(shape: Shape, exit: Dictionary, width: float, colour: Color) -> void:
	var at: Vector3 = exit.position
	var top := FLOOR.planta_y(FLOOR.planta_of(at.y - 0.5)) + float(OFFICE.PLENUM.slab)
	shape.box(Vector3(at.x, (at.y + top) * 0.5, at.z), Vector3(width * 0.5, (top - at.y) * 0.5, width * 0.5), Basis.IDENTITY, colour)
	outline(shape, at, 0.34, colour)

## The way along the tubes, lit over them.
func route(shape: Shape, points: PackedVector3Array) -> void:
	for k in range(1, points.size()): shape.beam(points[k - 1], points[k], 0.3, Color(packed(1.15), 0.35, 0.0, 0.0))

## A square of `half` round a point, flat: the edge of a piece.
func outline(shape: Shape, at: Vector3, half: float, colour: Color) -> void:
	var corners := [Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)]
	for k in 4: line(shape, at + corners[k], at + corners[(k + 1) % 4], colour)

## A line between two points, thick enough to be seen from her camera.
func line(shape: Shape, a: Vector3, b: Vector3, colour: Color) -> void:
	var metres := camera.global_position.distance_to((a + b) * 0.5)
	shape.beam(a, b, maxf(LINE, metres * LINE_SHARE), colour)

## Her body as her own camera draws it, where hers is.
func place_her() -> void:
	var size := Vector2i(camera.get_viewport().get_visible_rect().size)
	if her_port.size != size: her_port.size = size
	her_eye.global_transform = camera.global_transform
	her_eye.fov = camera.fov
	her_eye.near = camera.near
	her_eye.far = camera.far

## A key in its keycap beside a piece (`kind` "way" or "down"), none at INF.
func tag(kind: String, at: Vector3, action: String) -> void:
	var holder: Control = tags[kind]
	var screen := camera.get_viewport().get_visible_rect().size
	var point := camera.unproject_position(at) if at != Vector3.INF and not camera.is_position_behind(at) else Vector2.INF
	# Never over her keys along the foot.
	holder.visible = point != Vector2.INF and point.y < screen.y + keys_bar.offset_top * screen.y / 720.0
	if not holder.visible: return
	var names: Array = key_names(action)
	if String(holder.get_meta("names", "")) != str(names):
		holder.set_meta("names", str(names))
		for child in holder.get_children(): child.queue_free()
		var cap: Control = level.ui.keycap(String(names[0]), 17)
		holder.add_child(cap)
	holder.position = point + Vector2(70, -14) * screen.y / 720.0

# --- Her keys --------------------------------------------------------------------------

## An action's keys as the control hints name them (control_hints.lurker_keys()).
func key_names(action: String) -> Array:
	return level.hints.lurker_keys(action) if level.get("hints") != null else [action]

## Her keys now: [keys, name, whether it can be done now, its wait left (0..1)].
## Picking a way out of the ducts, go or back; on her way, none; else her six.
func rows() -> Array:
	var phase := String(driver.trip.get("phase", ""))
	if not creature.motion.transit.is_empty() or phase == "go": return []
	if phase in ["pick", "ask"]:
		return [[key_names("lurker_enter") + key_names("lurker_release"), "Ir", phase == "pick" and int(driver.trip.pick) >= 0, 0.0], [key_names("lurker_drop"), "Volver", true, 0.0]]
	var up: bool = driver.up()
	var info: Dictionary = driver.prey_info
	var wait := clampf(float(info.get("wait", 0.0)), 0.0, 1.0)
	# Out of reach and charging: how much of her charge is still to come.
	if driver.prey >= 0 and String(info.get("why", "")) == "far" and driver.charge > 0.0: wait = 1.0 - driver.charge / driver.CHARGE
	var drink_wait: float = clampf(1.0 - (clock - drank_at) / DRINK_EVERY, 0.0, 1.0)
	var trip_wait: float = clampf((driver.trip_ready_at - driver.clock) / driver.TRIP_GAP, 0.0, 1.0)
	return [
		[key_names("lurker_release"), "Atacar", bool(info.get("ok", false)) and driver.attack.is_empty(), wait if driver.prey >= 0 else 0.0],
		[key_names("lurker_drop"), "Bajar" if up else "Subir", not up or driver.gallery() or not driver.down_way().is_empty(), 0.0],
		[["MANTÉN"] + key_names("lurker_sneak"), "Sigilo", up, 0.0],
		[key_names("lurker_enter"), "Ductos", driver.entrance() >= 0, trip_wait],
		[key_names("lurker_drink"), "Beber la luz", drink_wait <= 0.0, drink_wait],
		[key_names("lurker_peek"), "Asomarse", not up, 0.0],
	]

## Her keys along the foot as the control hints draw theirs: built again only
## when what they say changes; dim when not now, a wait drained on its key.
func show_keys(list: Array) -> void:
	var sign := str(list.map(func(row: Array) -> Array: return [row[0], row[1]]))
	if sign != keys_sign:
		keys_sign = sign
		for child in keys_bar.get_children():
			keys_bar.remove_child(child)
			child.queue_free()
		var ui = level.get("ui")
		if ui == null: return
		for row in list:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			keys_bar.add_child(line)
			for name in row[0]:
				if name == "MANTÉN":
					ui.outlined(ui.label(line, "MANTÉN", 16), STYLE.SOFT)
					continue
				var cap: Control = ui.keycap(String(name), 17)
				var fill := Fill.new()
				fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cap.add_child(fill)
				cap.move_child(fill, 0)
				line.add_child(cap)
			ui.outlined(ui.label(line, String(row[1]), 19), STYLE.INK)
			for piece: Control in line.get_children(): piece.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in mini(list.size(), keys_bar.get_child_count()):
		var line: Control = keys_bar.get_child(i)
		line.modulate.a = 1.0 if bool(list[i][2]) else DIM
		for cap in line.get_children():
			for fill in cap.get_children():
				if fill is Fill and not is_equal_approx(fill.share, float(list[i][3])):
					fill.share = float(list[i][3])
					fill.queue_redraw()

## A wait on its key: the share still to go, from the bottom.
class Fill extends Control:
	var share := 0.0

	func _draw() -> void:
		if share > 0.0: draw_rect(Rect2(0, size.y * (1.0 - share), size.x, size.y * share), Color(1, 1, 1, 0.3))

## Sent off (lurker_player.scared()): the picture closes in and opens again.
class Hud extends Control:
	var view

	func _draw() -> void:
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

## Boxes into one mesh: a vertex colour each (what lurker_mark.gdshader packs).
class Shape:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()

	## A box of `half` round `centre`, turned by `turn`.
	func box(centre: Vector3, half: Vector3, turn: Basis, colour: Color) -> void:
		for axis in 3:
			for side in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[axis] = side
				var u := Vector3.ZERO
				u[(axis + 1) % 3] = 1.0
				var v := Vector3.ZERO
				v[(axis + 2) % 3] = 1.0
				var c := n * half
				var du := u * half
				var dv := v * half
				var quad := [c - du - dv, c + du - dv, c + du + dv, c - du + dv]
				for k in [0, 1, 2, 0, 2, 3]:
					points.append(centre + turn * quad[k])
					normals.append(turn * n)
					colours.append(colour)

	## A square bar `width` across from a to b.
	func beam(a: Vector3, b: Vector3, width: float, colour: Color) -> void:
		var along := b - a
		if along.length() < 1e-4: return
		var z := along.normalized()
		var x := z.cross(Vector3.UP if absf(z.y) < 0.9 else Vector3.RIGHT).normalized()
		box((a + b) * 0.5, Vector3(width * 0.5, width * 0.5, along.length() * 0.5 + width * 0.5), Basis(x, z.cross(x), z), colour)

	func mesh() -> ArrayMesh:
		var out := ArrayMesh.new()
		if points.is_empty(): return out
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return out
