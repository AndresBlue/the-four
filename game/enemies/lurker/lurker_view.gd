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
## the objectives' machines and the coffee machines (beating while somebody is
## at one), the air plant's rotors, and the torches, hottest of all, with
## their beams warm on what they fall on. A source behind a wall warms the
## face of the wall. A lit room's floor reads over a dark one's, and where
## somebody walked the floor keeps their steps warm a while. The camera's gain
## stretches the picture between the coldest and the hottest in view, slowly;
## her sensor (lurker_thermal_sensor.gdshader) makes a recording of it and
## tints every survivor's outline by its mind, green whole to red gone.
##
## Her camera is always behind and over her (lurker_player.gd). Over the false
## ceiling this machine does not draw the ceiling of her planta (ceilings()):
## the same reading looks down into the rooms, with the T-grid faint round her,
## the cores and the building's edge standing up to the slab as what stops her
## (barriers), and nothing past her prey's reach but what burns. She herself,
## her real body and its ink, is drawn alone by a camera of her own and laid
## over the recording with a cold rim (lurker_her.gdshader), screened to a
## faint dither where it would hide her prey or, down in a room, what she
## looks at. Every survivor in reach is outlined pale, a little wider than
## its body; from over the ceiling the lit rooms' fittings glow under what
## burns (UP_FITTING, GAIN_LEAST_UP). What she hears loud (a door, somebody
## running, the typewriter) goes out as a faint wave of warmth over the
## surfaces round it, where she hears it. Her marks are in
## the world, in the reading's terms (lurker_mark.gdshader): the outline of
## the tile she would go down by, the tile she would drop by behind her prey
## (pale if the attack may go, red if not), and why not: the line of a look
## on where she would drop, or of the torch on it, or the lit room under it
## reddened; each double of hers waiting, a pin through the walls and the
## ring of its leap; while her drink is ready, the rooms it would reach.
## Crossing to the next planta the camera follows her down the trunk as it
## is (the author, 18 November 2026: no ducts of hers any more). Her disc
## over her keys (Hud) is her attack: its ring fills through her wait, whole
## and white when it may go, red when something stops it; her charge inside;
## in its middle her prey's mind in its colour, as big as an attack on it
## would still cost (less each time on the same one). Her keys are along the
## foot as the control hints draw theirs (hotel_ui.show_controls()): each key
## in its keycap and its action's name, what cannot be done now dim, a wait
## drained on its own key; a key beside the piece it works on. Sent off, the
## picture closes in a moment.
##
## What she is given of the survivors: a lit torch through the walls within
## BEACON_REACH (none she drank, none while her face is behind a shut tile or
## deep in a duct), figures within her prey's reach, and anybody whose mind
## has gone through the walls as an outline, red. Her own lit room floods the
## sensor past a few metres. flash() is a torch in her face (the host fires
## it: lurker.scare_off()): the camera saturated. All of it worked out on her
## machine from what it has: the minds are the ones the authority tells every
## machine (sanity.sanity_of()).
const SIGHT_SHADER := preload("res://game/presentation/shaders/lurker_sight.gdshader")
const SENSOR_SHADER := preload("res://game/presentation/shaders/lurker_thermal_sensor.gdshader")
const MARK_SHADER := preload("res://game/presentation/shaders/lurker_mark.gdshader")
const HER_SHADER := preload("res://game/presentation/shaders/lurker_her.gdshader")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const VISUAL := preload("res://game/enemies/lurker/lurker_visual.gd")
const STYLE := preload("res://game/ui/osd_style.gd")
const COFFEE := preload("res://game/world/interactables/coffee_machine.gd")
## The shader's source slots, and its kinds (its LAMP, TORCH, COLD).
const MOST := 96
enum Kind { LAMP = 0, TORCH = 1, COLD = 3 }
## A lit torch is a beacon through the walls this far (the author: seen from
## much further, cordura_y_edificio.md 1.8); its beam warms what it falls on
## up to BEAM_REACH (creature_sight.TORCH_REACH), over BEAM_SHARE of its
## light's cone (the bright middle). The shader's beam slots.
const BEACON_REACH := 80.0
const BEAM_REACH := 20.0
const BEAM_SHARE := 0.8
const BEAMS := 8
## A coffee machine's body, all of it (from over the ceiling its top is what
## she sees), warm: its boiler.
const COFFEE_HEAT := 0.62
## Warm steps: one every PRINT_STRIDE metres a survivor walks, PRINT_SIDE
## from its line, alternate feet; cool in PRINT_LIFE s; the nearest PRINTS
## to her eye are drawn.
const PRINTS := 48
const PRINT_STRIDE := 0.75
const PRINT_SIDE := 0.13
const PRINT_LIFE := 7.0
## A mind's colour on her sensor: gone, half, whole.
const MIND_GONE := Color(1.0, 0.16, 0.1)
const MIND_HALF := Color(1.0, 0.78, 0.18)
const MIND_WHOLE := Color(0.38, 1.0, 0.48)
## The sensor's tint slots, and how far a survivor's box reaches past its
## body (metres): its outline.
const TINTS := 24
const TINT_GROW := 0.5
## Her doubles' ring is drawn within this of her (through the furniture that
## hid it), in this many pieces, where an eye this high over the floor is
## within its leap; the rooms her drink would reach, inset this much, this pale.
const RING_REACH := 15.0
const RING_PIECES := 20
const EYE_HEIGHT := 1.6
const FOOTPRINT_IN := 0.2
## (Faint: in an open office most rooms round her are lit, so it is a grid.)
const FOOTPRINT_PALE := 0.4
## Heat (a reading): a fitting, an emergency unit, a landmark's lamp, a
## furniture lamp, an objective's machine and its lamp, a running air handler,
## a torch. A machine in use beats by BEAT.
const FITTING_HEAT := 0.72
const EMERGENCY_HEAT := 0.66
const LANDMARK_HEAT := 0.74
const ACCENT_HEAT := 0.64
const MACHINE_HEAT := 0.8
const LAMP_HEAT := 0.95
const FAN_HEAT := 0.86
const TORCH_HEAT := 1.15
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
const ELECTRIC := ["type", "take", "swipe", "lever", "switch", "door", "lift", "post", "start", "stop"]
const BUSY_REACH := 1.6
## Sources further than this are left out, and from FADE_FROM they cool a little.
const LAMP_REACH := 32.0
const FADE_FROM := 15.0
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
const TORCH_THROUGH := Vector2(0.62, 80.0)
## The camera's gain: the coldest reading at the foot of the map; the top at
## the hottest in view over GAIN_SHARE (so it burns white), the warmest patch
## of something hidden over HIDDEN_SHARE (warm, not burning), never under
## GAIN_LEAST (the walls alone stay low); it follows over GAIN_TIME.
const GAIN_LOW := 0.06
const GAIN_LEAST := 0.5
## From over the ceiling the lit rooms' fittings would be all she sees: they
## read UP_FITTING of their heat and the gain starts at GAIN_LEAST_UP, so they
## glow and the machines and torches still burn over them.
const UP_FITTING := 0.75
const GAIN_LEAST_UP := 0.85
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
## Survivors drawn as figures, lit rooms lifted.
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
## Her marks' lines this thick at least, and this share of the metres to them.
const LINE := 0.03
const LINE_SHARE := 0.0025
## Beber's wait (lurker.VERSUS_EVERY), drained on its key.
const DRINK_EVERY := 10.0
## A key not to be pressed now.
const DIM := 0.3
## What she hears shows where it is: a faint wave of warmth over the surfaces
## round it (the shader's ripples), RIPPLES at most, each RIPPLE_LIFE s, out to
## a reach by how loud. Running is heard every RUN_EVERY over RUN_SPEED m/s,
## typing every TYPE_EVERY by somebody standing at the typewriter. Heard close
## it is where it is; further, where it comes from (the opening it came
## through).
const RIPPLES := 8
const RIPPLE_LIFE := 0.9
const RUN_SPEED := 4.5
const RUN_EVERY := 0.4
const TYPE_EVERY := 0.3
const TYPE_REACH := 1.4
const RIPPLE_TRUTH := 6.0
const NOISE := preload("res://game/audio/noise_kinds.gd")
## Where her body is screened over what it hides: her prey's figure grown by
## HOLE_GROW; down in a room, the middle of the picture this wide (screen
## heights).
const HOLE_GROW := 1.35
const HOLE_MIDDLE := 0.14

var driver
var creature
var level
var camera: Camera3D
var field: MeshInstance3D
var material: ShaderMaterial
var sensor: CanvasLayer
var sensor_material: ShaderMaterial
var clock := 0.0
var gather_clock := 0.0
## The registers' heat on her planta, nearest first:
## [point, half size, yaw, heat, kind, busy, metres, in view, metres behind what hides it].
var lamps: Array = []
## Lit rooms near her: [metres, room, how lit].
var lit_rooms: Array = []
## seat -> the survivor whose torch she has as a beacon; seat -> [in view,
## metres behind what hides it] of its torch; seat -> metres to what stops
## its beam.
var beacons := {}
var torch_view := {}
var beam_reach := {}
var cold: Array = []
var dazzle := 0.0
var dazzled := false
var flash_clock := -1.0
var flash_from := Vector2.ZERO
var immune_until := -1.0
## Room -> its fittings' shapes [point, half size, yaw].
var shapes := {}
var heat_at := PackedVector4Array()
var heat_box := PackedVector4Array()
var heat_screen := PackedVector4Array()
var heat_kind := PackedVector4Array()
var placed := 0
var gain_high := GAIN_LEAST
## Where the halos are drawn from: the camera, a moment late.
var lag := Transform3D.IDENTITY
## The warm steps: [point, born]; seat -> [where its last step was, its foot].
var prints: Array = []
var strides := {}
## The rooms her drink would reach now and the room it was worked out for.
var footprint: Array = []
var footprint_of := -2
## The ceilings not drawn now (their nodes) and for which planta.
var hidden_parts: Array = []
var hidden_planta := -1
## Planta -> what stops her, as one mesh.
var walls := {}
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
## What she heard lately: [point, born, reach]; seat -> s to its next run
## heard; s to the next typing heard.
var ripples: Array = []
var run_clocks := {}
var type_clock := 0.0

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
	for kind in ["down"]:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.visible = false
		cover.add_child(holder)
		tags[kind] = holder
	heat_at.resize(MOST)
	heat_box.resize(MOST)
	heat_screen.resize(MOST)
	heat_kind.resize(MOST)
	if is_instance_valid(level.get("hotel")):
		for door in level.hotel.doors:
			if door.has_signal("noise"): door.noise.connect(on_door)

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
	her_layer.visible = on
	her_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	marks.visible = on
	marks_through.visible = on
	ceilings(planta() if up else -1)
	for p in walls: walls[p].visible = up and int(p) == planta()
	var deep := int(creature.get("deep_room")) if creature.get("deep_room") != null else -1
	if deep >= 0 and deep_was < 0: drank_at = clock
	deep_was = deep
	if not on:
		for kind in tags: tags[kind].visible = false
		return
	if up: barriers(planta())
	gather_clock -= delta
	if gather_clock <= 0.0:
		gather_clock = GATHER_EVERY
		gather()
	listen(delta)
	tread()
	dazzle = move_toward(dazzle, 1.0 if dazzled else 0.0, DAZZLE_RATE * delta)
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

## A reading packed as her shaders pack it.
static func packed(v: float) -> float: return clampf((v - FOOT) / (RANGE - FOOT), 0.0, 1.0)

# --- The registers ---------------------------------------------------------------------

func wing_of(room_id: int) -> int:
	return int(level.manifest.rooms[room_id].get("wing", -1)) if room_id >= 0 and room_id < level.manifest.rooms.size() else -1

## The registers' heat on her planta, nearest first, and whether she has each
## in view; what she makes out of the survivors; whether her room dazzles her.
func gather() -> void:
	var hotel = level.hotel
	var here := planta()
	var eye := camera.global_position
	var found: Array = []
	lit_rooms = []
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != here or not glowing(id): continue
		var left: float = (1.0 - 0.5 * float(hotel.drained(id))) * (UP_FITTING if above() else 1.0)
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
	if level.get("coffee") != null:
		for machine in level.coffee.machines:
			if not is_instance_valid(machine) or FLOOR.planta_of(machine.global_position.y + 1.0) != here: continue
			var body: Vector3 = machine.global_position + Vector3(0, COFFEE.SIZE.y * 0.5, 0)
			found.append([body, COFFEE.SIZE * 0.5, machine.global_rotation.y, COFFEE_HEAT, Kind.LAMP, busy(body)])
	for entry in found:
		var d: float = eye.distance_to(entry[0])
		entry[3] = float(entry[3]) * (1.0 - 0.25 * smoothstep(FADE_FROM, LAMP_REACH, d))
		entry.append(d)
	lamps = found.filter(func(entry: Array) -> bool: return float(entry[6]) < LAMP_REACH)
	lamps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[6]) < float(b[6]))
	if lamps.size() > MOST: lamps.resize(MOST)
	for entry in lamps: entry.append_array(in_view(eye, entry[0], []))
	lit_rooms.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	look_at_survivors(eye)
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, eye)
	dazzled = not room.is_empty() and not above() and hotel.lit(int(room.id))

## A room lit as she reads it: its power on and a lamp of its own on (not
## one lit only by its emergency units, whose lamp is off).
func glowing(id: int) -> bool:
	var hotel = level.hotel
	if id < 0 or id >= hotel.lights.size() or not hotel.lit(id): return false
	var light: OmniLight3D = hotel.lights[id]
	return not light.has_meta("off") and not light.has_meta("void")

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
			var mine: Array = [one.get_rid()] if one is CollisionObject3D else []
			beacons[int(one.slot)] = one
			torch_view[int(one.slot)] = in_view(eye, torch.global_position, mine)
			beam_reach[int(one.slot)] = beam_stop(torch, mine)
	cold = level.sanity.burnt_survivors() if level.get("sanity") != null else []

## How far a torch's beam goes before something stops it (BEAM_REACH at most).
func beam_stop(torch: Node3D, exclude: Array) -> float:
	var from := torch.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - torch.global_basis.z * BEAM_REACH, SIGHT.MASK)
	query.exclude = [creature.get_rid()] + exclude
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return BEAM_REACH if hit.is_empty() else from.distance_to(hit.position)

# --- What she hears --------------------------------------------------------------------

func on_door(point: Vector3, radius: float, _kind: int) -> void:
	if seat(): ripple(point, radius, 2.4)

## The loud noises she would hear, from what this machine has of them:
## survivors running, somebody at the typewriter.
func listen(delta: float) -> void:
	for one in level.survivors():
		if not is_instance_valid(one) or not "slot" in one or not level.survivor_active(one): continue
		var seat_id := int(one.slot)
		var velocity: Vector3 = one.get("velocity") if one.get("velocity") != null else Vector3.ZERO
		run_clocks[seat_id] = float(run_clocks.get(seat_id, 0.0)) - delta
		if Vector2(velocity.x, velocity.z).length() > RUN_SPEED and float(run_clocks[seat_id]) <= 0.0:
			run_clocks[seat_id] = RUN_EVERY
			ripple(one.global_position + Vector3(0, 0.05, 0), NOISE.radius("run"), 2.0)
	var files = level.objectives.get("files")
	if files == null or files.usables.is_empty(): return
	var typewriter: Vector3 = files.usables[0].global_position
	type_clock -= delta
	if type_clock > 0.0: return
	for one in level.survivors():
		if not is_instance_valid(one): continue
		var velocity: Vector3 = one.get("velocity") if one.get("velocity") != null else Vector3.ZERO
		var off: Vector3 = one.global_position - typewriter
		if Vector2(off.x, off.z).length() < TYPE_REACH and absf(off.y) < 1.5 and Vector2(velocity.x, velocity.z).length() < 0.3:
			type_clock = TYPE_EVERY
			ripple(typewriter, NOISE.radius("door_slow"), 0.9)
			return

## Where the survivors on her planta walk, a warm step every PRINT_STRIDE,
## alternate feet; the cold ones let go.
func tread() -> void:
	prints = prints.filter(func(entry: Array) -> bool: return clock - float(entry[1]) < PRINT_LIFE)
	var here := planta()
	for one in level.survivors():
		if not is_instance_valid(one) or not "slot" in one or not level.survivor_active(one) or bool(one.get("hidden")) or not SIGHT.alive(level, one): continue
		var feet: Vector3 = one.global_position
		var seat_id := int(one.slot)
		if FLOOR.planta_of(feet.y + 1.0) != here:
			strides.erase(seat_id)
			continue
		if not strides.has(seat_id): strides[seat_id] = [feet, 1.0]
		var last: Array = strides[seat_id]
		var walked: Vector3 = feet - (last[0] as Vector3)
		if Vector2(walked.x, walked.z).length() < PRINT_STRIDE: continue
		var foot := -float(last[1])
		var aside := Vector3(-walked.z, 0, walked.x).normalized() * PRINT_SIDE * foot
		strides[seat_id] = [feet, foot]
		prints.append([feet + aside, clock])

## A noise where she hears it, as she hears it, or nowhere: its wave over the
## surfaces round it, out to `reach` metres.
func ripple(point: Vector3, radius: float, reach: float) -> void:
	if not creature.has_method("hear_route"): return
	var route: Dictionary = creature.hear_route(point, radius)
	if not bool(route.get("audible", false)): return
	ripples.append([point if float(route.distance) < RIPPLE_TRUTH else route.apparent, clock, reach])
	if ripples.size() > RIPPLES: ripples.pop_front()

# --- The flash --------------------------------------------------------------------------

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
	place_beams()
	# The gain: the hottest in view at the top over GAIN_SHARE, slowly.
	var target := maxf(GAIN_LEAST_UP if above() else GAIN_LEAST, maxf(float(peak[0]) * GAIN_SHARE, float(peak[1]) * HIDDEN_SHARE))
	gain_high = lerpf(gain_high, target, 1.0 - exp(-delta / GAIN_TIME))
	var reduced: bool = level.settings.values.reduced
	material.set_shader_parameter("count", placed)
	material.set_shader_parameter("heat_at", heat_at)
	material.set_shader_parameter("heat_box", heat_box)
	material.set_shader_parameter("heat_screen", heat_screen)
	material.set_shader_parameter("heat_kind", heat_kind)
	material.set_shader_parameter("gain_low", GAIN_LOW)
	material.set_shader_parameter("gain_high", gain_high)
	material.set_shader_parameter("floor_y", FLOOR.planta_y(planta()))
	material.set_shader_parameter("dazzle", dazzle)
	material.set_shader_parameter("flash", flash_now())
	material.set_shader_parameter("flash_from", flash_from)
	material.set_shader_parameter("flash_peak", REDUCED_PEAK if reduced else 1.0)
	material.set_shader_parameter("now", clock)
	place_figures()
	place_tints()
	var calm: float = REDUCED_NOISE if reduced else 1.0
	sensor_material.set_shader_parameter("noise", NOISE_HEAT / (gain_high - GAIN_LOW) * calm)
	sensor_material.set_shader_parameter("stripes", STRIPES * calm)
	sensor_material.set_shader_parameter("now", clock)

## Her beacons' beams: each from its torch along its look, up to what stops it.
func place_beams() -> void:
	var at := PackedVector4Array()
	var way := PackedVector4Array()
	at.resize(BEAMS)
	way.resize(BEAMS)
	var count := 0
	for seat_id in beacons:
		var one = beacons[seat_id]
		if count >= BEAMS or not is_instance_valid(one) or not is_instance_valid(one.get("torch")): continue
		var torch: Node3D = one.torch
		var from := torch.global_position
		var look := -torch.global_basis.z
		var angle: float = float(torch.get("spot_angle")) if torch.get("spot_angle") != null else 26.0
		at[count] = Vector4(from.x, from.y, from.z, float(beam_reach.get(seat_id, BEAM_REACH)))
		way[count] = Vector4(look.x, look.y, look.z, cos(deg_to_rad(angle * BEAM_SHARE)))
		count += 1
	material.set_shader_parameter("beam_count", count)
	material.set_shader_parameter("beam_at", at)
	material.set_shader_parameter("beam_way", way)

## Every survivor she makes out and every mind gone, as a box on her screen
## tinted by its mind (her sensor's), and the warm steps nearest her eye.
func place_tints() -> void:
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var boxes := PackedVector4Array()
	var colours := PackedVector4Array()
	boxes.resize(TINTS)
	colours.resize(TINTS)
	var count := 0
	var at: Vector3 = creature.motion.anchor()
	var here := planta()
	var sanity = level.get("sanity")
	for one in level.survivors():
		if count >= TINTS or sanity == null: break
		if not is_instance_valid(one) or not "slot" in one: continue
		var spent: bool = bool(one.get("burnt")) and level.survivor_active(one)
		if not spent and not driver.markable(one, at, here): continue
		var box := screen_box(one.global_position, size)
		if box == Vector4.ZERO: continue
		var colour := mind_colour(0.0 if spent else float(sanity.sanity_of(one)))
		boxes[count] = box
		colours[count] = Vector4(colour.r, colour.g, colour.b, 1.0)
		count += 1
	sensor_material.set_shader_parameter("tint_count", count)
	sensor_material.set_shader_parameter("tint_box", boxes)
	sensor_material.set_shader_parameter("tint_colour", colours)
	var eye := camera.global_position
	var near: Array = prints.duplicate()
	if near.size() > PRINTS:
		near.sort_custom(func(a: Array, b: Array) -> bool: return eye.distance_squared_to(a[0]) < eye.distance_squared_to(b[0]))
		near.resize(PRINTS)
	var steps := PackedVector4Array()
	steps.resize(PRINTS)
	for i in near.size():
		var point: Vector3 = near[i][0]
		steps[i] = Vector4(point.x, point.y, point.z, (clock - float(near[i][1])) / PRINT_LIFE)
	material.set_shader_parameter("print_count", near.size())
	material.set_shader_parameter("print_at", steps)

## The box a survivor standing at `feet` fills on her screen with its outline
## (uv: min x, min y, max x, max y); zero when it is behind her.
func screen_box(feet: Vector3, size: Vector2) -> Vector4:
	var low := Vector2.INF
	var high := -Vector2.INF
	var side: Vector3 = camera.global_basis.x * TINT_GROW
	for corner: Vector3 in [Vector3(0, -0.1, 0), Vector3(0, 2.1, 0)]:
		for aside in [-1.0, 1.0]:
			var point: Vector3 = feet + corner + side * aside
			if camera.is_position_behind(point): return Vector4.ZERO
			var on := camera.unproject_position(point) / size
			low = low.min(on)
			high = high.max(on)
	return Vector4(low.x, low.y, high.x, high.y)

## A mind's colour on her sensor (0 gone, 100 whole).
static func mind_colour(sanity: float) -> Color:
	var whole := clampf(sanity / 100.0, 0.0, 1.0)
	return MIND_GONE.lerp(MIND_HALF, whole * 2.0) if whole < 0.5 else MIND_HALF.lerp(MIND_WHOLE, whole * 2.0 - 1.0)

## The survivors as figures (her prey full), and from over the ceiling her
## point, the grid round her; the lit rooms.
func place_figures() -> void:
	var at: Vector3 = creature.motion.anchor()
	var here := planta()
	var info: Dictionary = driver.prey_info
	var figures := PackedVector4Array()
	figures.resize(FIGURES)
	var count := 0
	for one in level.survivors():
		if count >= FIGURES or not driver.markable(one, at, here): continue
		var mark := 1.0 if int(one.slot) == driver.prey or int(one.slot) == driver.struck else 0.0
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
	material.set_shader_parameter("lit_count", lits)
	material.set_shader_parameter("lit_rect", rects)
	material.set_shader_parameter("lit_heat", heats)
	var red := int(info.get("room", -1))
	material.set_shader_parameter("red_rect", rect_of(red) if red >= 0 and driver.prey >= 0 else Vector4.ZERO)
	var waves := PackedVector4Array()
	var reaches := PackedFloat32Array()
	waves.resize(RIPPLES)
	reaches.resize(RIPPLES)
	ripples = ripples.filter(func(entry: Array) -> bool: return clock - float(entry[1]) < RIPPLE_LIFE)
	for i in mini(ripples.size(), RIPPLES):
		var point: Vector3 = ripples[i][0]
		waves[i] = Vector4(point.x, point.y, point.z, (clock - float(ripples[i][1])) / RIPPLE_LIFE)
		reaches[i] = float(ripples[i][2])
	material.set_shader_parameter("ripple_count", mini(ripples.size(), RIPPLES))
	material.set_shader_parameter("ripple_at", waves)
	material.set_shader_parameter("ripple_reach", reaches)

## A room's floor, (min x, min z, max x, max z).
func rect_of(id: int) -> Vector4:
	var room: Dictionary = level.manifest.rooms[id]
	var half := FLOOR.size_of(room) * 0.5
	return Vector4(float(room.px) - half.x, float(room.pz) - half.y, float(room.px) + half.x, float(room.pz) + half.y)

## Her marks in the world, and the keys beside the pieces they work on: the
## tile she would go down by (or drop by on her prey) and why her prey is not hers.
func place_marks() -> void:
	var near := Shape.new()
	var far := Shape.new()
	var pale := Color(packed(0.0), 1.0, 0.0, 0.0)
	var red := Color(packed(0.0), 0.0, 1.0, 0.0)
	var down_at := Vector3.INF
	if driver.mode != "ducts" and driver.up() and driver.attack.is_empty():
		var way: Dictionary = driver.down_way()
		if not way.is_empty() and not driver.gallery():
			down_at = way.point
			outline(near, down_at, 0.3, pale)
	# Her prey: the tile she would drop by behind it, and why not.
	var info: Dictionary = driver.prey_info
	if driver.prey >= 0 and driver.mode != "ducts":
		var drop: Dictionary = info.get("drop", {})
		var ok := bool(info.get("ok", false))
		if not drop.is_empty() and driver.attack.is_empty(): outline(near, drop.point, 0.3, pale if ok else red)
		var from: Vector3 = info.get("from", Vector3.INF)
		var to: Vector3 = info.get("face", Vector3.INF)
		if from != Vector3.INF and to != Vector3.INF: line(far, from, to, red)
	place_doubles(far, pale)
	place_footprint(far)
	marks.mesh = near.mesh()
	marks_through.mesh = far.mesh()
	tag("down", down_at, "lurker_drop")

## Her doubles waiting: a pin from the floor up to each head and a square
## round it, seen through the walls; near her, on its floor and through what
## stands on it, the ring within which it leaps at an eye
## (lurker_doubles.POUNCE_REACH from its head).
func place_doubles(far: Shape, pale: Color) -> void:
	var doubles = creature.get("doubles")
	if doubles == null: return
	var eye := camera.global_position
	for id in doubles.doubles:
		if String(doubles.doubles[id].get("state", "")) != "wait": continue
		var head: Vector3 = doubles.head_of(int(id))
		if head == Vector3.INF: continue
		var ground := Vector3(head.x, FLOOR.planta_y(FLOOR.planta_of(head.y - 1.5)) + 0.04, head.z)
		line(far, ground, head, pale)
		outline(far, head, 0.25, pale)
		if eye.distance_to(ground) > RING_REACH: continue
		var rise := head.y - ground.y - EYE_HEIGHT
		var reach := sqrt(maxf(doubles.POUNCE_REACH * doubles.POUNCE_REACH - rise * rise, 0.0))
		for k in RING_PIECES:
			var a := TAU * k / RING_PIECES
			var b := TAU * (k + 1) / RING_PIECES
			line(far, ground + Vector3(cos(a), 0, sin(a)) * reach, ground + Vector3(cos(b), 0, sin(b)) * reach, pale)

## While her drink is ready, the rooms it would reach (lurker.judge_drink():
## the room she is in or over and those touching it that may go dark): the
## floors of those lit outlined through the walls (the dark ones would only
## lose the torches in them; outlined, they buried the picture).
func place_footprint(far: Shape) -> void:
	var ready: bool = clock - drank_at >= DRINK_EVERY and creature.grace <= 0.0 and creature.motion.transit.is_empty() and int(creature.deep_room) < 0
	var room: int = creature.room_of_point(creature.face_point()) if ready else -1
	if room >= 0 and not creature.may_snuff(room, 0.0, false): room = -1
	if room != footprint_of:
		footprint_of = room
		footprint = [] if room < 0 else [room] + creature.touching(room).filter(func(r: int) -> bool: return creature.may_snuff(r, 0.0, false))
	var colour := Color(packed(0.0), FOOTPRINT_PALE, 0.0, 0.0)
	for id: int in footprint:
		if not glowing(id): continue
		var data: Dictionary = level.manifest.rooms[id]
		var r := rect_of(id) + Vector4(FOOTPRINT_IN, FOOTPRINT_IN, -FOOTPRINT_IN, -FOOTPRINT_IN)
		var y := float(data.get("py", 0.0)) + 0.05
		var corners := [Vector3(r.x, y, r.y), Vector3(r.z, y, r.y), Vector3(r.z, y, r.w), Vector3(r.x, y, r.w)]
		for k in 4: line(far, corners[k], corners[(k + 1) % 4], colour)

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
	# Screened where she would hide her prey (the one she goes for first) and,
	# down in a room, the middle of the picture, what she looks at.
	var holes := PackedVector4Array()
	holes.resize(3)
	var count := 0
	var seats: Array = [driver.struck, driver.prey].filter(func(s: int) -> bool: return s >= 0)
	for s: int in seats:
		var one = driver.body_of(s)
		if one == null or count >= 2: continue
		var chest: Vector3 = one.global_position + Vector3(0, 0.95, 0)
		if camera.is_position_behind(chest): continue
		var middle := camera.unproject_position(chest)
		var wide: float = (camera.unproject_position(chest + camera.global_basis.x * 0.45) - middle).length()
		var tall: float = (camera.unproject_position(one.global_position + Vector3(0, 1.85, 0)) - camera.unproject_position(one.global_position)).length() * 0.5
		var half := Vector2(wide, maxf(wide, tall)) * HOLE_GROW
		holes[count] = Vector4(middle.x / size.x, middle.y / size.y, half.x / size.x, half.y / size.y)
		count += 1
	if driver.mode == "down":
		holes[count] = Vector4(0.5, 0.5, HOLE_MIDDLE * float(size.y) / float(size.x), HOLE_MIDDLE)
		count += 1
	var rim: ShaderMaterial = (her_layer.get_child(0) as TextureRect).material
	rim.set_shader_parameter("hole_count", count)
	rim.set_shader_parameter("holes", holes)

## A key in its keycap beside a piece (`kind` "down"), none at INF.
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
## Crossing to the next planta, none; else her six.
func rows() -> Array:
	if not creature.motion.transit.is_empty(): return []
	var up: bool = driver.up()
	var info: Dictionary = driver.prey_info
	var drink_wait: float = clampf(1.0 - (clock - drank_at) / DRINK_EVERY, 0.0, 1.0)
	var double_wait: float = clampf(1.0 - (driver.clock - driver.doubled_at) / creature.DOUBLE_EVERY, 0.0, 1.0)
	return [
		# Its wait and her charge are on her disc (Hud).
		[key_names("lurker_release"), "Atacar", bool(info.get("ok", false)) and driver.attack.is_empty(), 0.0],
		[key_names("lurker_drop"), "Bajar" if up else "Subir", not up or driver.gallery() or not driver.down_way().is_empty(), 0.0],
		[["MANTÉN"] + key_names("lurker_sneak"), "Sigilo", up, 0.0],
		[key_names("lurker_double"), "Doppelgänger", double_wait <= 0.0, double_wait],
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

## Her disc over her keys (her attack, the header's), and sent off
## (lurker_player.scared()) the picture closing in and opening again.
class Hud extends Control:
	## The disc's radius and its gap over her keys; its rings' width; its ring
	## going out when the attack comes free, this long.
	const RADIUS := 26.0
	const GAP := 16.0
	const WIDTH := 3.5
	const RING_OUT := 0.45
	const SOFT := Color(1, 1, 1, 0.16)
	const WAITING := Color(1, 1, 1, 0.55)
	const FREE := Color(1, 1, 1, 0.95)
	const STOPPED := Color(1.0, 0.16, 0.1, 0.85)
	var view
	var free_was := false
	var freed_at := -INF

	func _draw() -> void:
		disc()
		closing()

	## Her attack: the ring fills through her wait, whole and white when it
	## may go (or goes), red when something stops it; her charge inside; her
	## prey's mind in the middle, its colour, its area what an attack on it
	## would still cost.
	func disc() -> void:
		var driver = view.driver
		if not driver.creature.motion.transit.is_empty(): return
		var at := Vector2(size.x * 0.5, size.y + float(view.keys_bar.offset_top) - GAP - RADIUS)
		draw_circle(at, RADIUS + 7.0, Color(0, 0, 0, 0.45))
		draw_arc(at, RADIUS, 0.0, TAU, 48, SOFT, WIDTH, true)
		var seat: int = driver.prey if driver.prey >= 0 else driver.struck
		var info: Dictionary = driver.prey_info
		var ok: bool = driver.prey >= 0 and bool(info.get("ok", false))
		if ok and not free_was: freed_at = view.clock
		free_was = ok
		if seat < 0: return
		var top := -PI * 0.5
		var wait := clampf(float(info.get("wait", 0.0)), 0.0, 1.0)
		var why := String(info.get("why", ""))
		if ok or not driver.attack.is_empty() or driver.creature.cue: draw_arc(at, RADIUS, 0.0, TAU, 48, FREE, WIDTH, true)
		elif wait > 0.0: draw_arc(at, RADIUS, top, top + TAU * (1.0 - wait), 48, WAITING, WIDTH, true)
		# Out of reach is no stop: only a look or a light on where she would drop.
		elif why in ["look", "light"]: draw_arc(at, RADIUS, 0.0, TAU, 48, STOPPED, WIDTH, true)
		var charge: float = driver.charge / driver.CHARGE
		if charge > 0.0: draw_arc(at, RADIUS - WIDTH * 2.0, top, top + TAU * charge, 40, FREE, WIDTH * 0.7, true)
		var one = driver.body_of(seat)
		var sanity = view.level.get("sanity")
		if one != null and sanity != null:
			var mind: float = 0.0 if bool(one.get("burnt")) else float(sanity.sanity_of(one))
			draw_circle(at, (RADIUS - WIDTH * 3.2) * sqrt(driver.strike_share(seat)), view.mind_colour(mind))
		var t: float = (view.clock - freed_at) / RING_OUT
		if t < 1.0: draw_arc(at, RADIUS + 10.0 * t, 0.0, TAU, 48, Color(1, 1, 1, 1.0 - t), WIDTH * (1.0 - 0.5 * t), true)

	func closing() -> void:
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
