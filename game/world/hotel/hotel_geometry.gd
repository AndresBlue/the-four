extends Node3D
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
var materials := {}
var batches := {}
var room_nodes: Array[Node3D] = []
## The planta each room and each door stands on (FLOOR.planta_of), in their
## build order: only the one being looked from is ever drawn.
var room_planta := PackedInt32Array()
var door_planta := PackedInt32Array()
var doors: Array = []
## The doors that lead from one wing to the next, one per stage.
var gates: Array = []
## The lift of each stage: the middle of the car standing in the lobby behind
## that refuge's door. Stepping into it is taking it -- to the next wing, or,
## for the last one, off the floor.
var lifts: Array = []
## And where each of those lifts puts people down: in front of the car in the
## cell the next wing is walked into from. Empty for the last one, which
## leaves the floor instead.
var arrivals: Array = []
## The cars' doors, to open and shut (lifts.gd): per stage, the leaves of the
## car it leaves from and of the car it arrives at, each {node, shut, open}
## with the leaf's x along the car in either state. And the middle of each
## arriving car and the way out of it.
var depart_leaves: Array = []
var arrive_leaves: Array = []
var arrival_cars: Array = []
var arrival_facing: Array = []
## Every piece of furniture with drawers or shelves, as it is dressed:
## {room, position, yaw, kind, front, note, main, things}. Four of them hide
## the numbers of the code.
var containers: Array = []
## The piece being furnished, where it is drawn (a handle from place(), for a
## piece with drawers or doors of its own: room_dressing.put), and what was
## put on it or in it (handles too: what stands on its top, its shelves' books,
## a stack's boxes). A piece gone through shows it with them
## (hotel_container.show_searched). Null while no container is being
## furnished: a store's shelves are dressed outside the stretches.
var piece_main := {}
var piece_things = null
## How far the solid piece being furnished reaches into the room, in its
## stretch's space (room_dressing.put): where a container's front is.
var piece_front := 0.0
## Where a note would sit on the piece being furnished, in its stretch's space
## (room_dressing.note_fold()): empty if it takes none.
var note_spot := {}
## The electrical panels (the fuse boxes, room_dressing), as they are dressed:
## {room, position (the middle of its front), yaw, main}. The floor's key
## opens any of them (hotel_panel.gd).
var panels: Array = []
## Where a fuse box could still hang, while the floor is dressed
## (room_dressing.fuse_boxes_left()).
var panel_spares: Array = []
## Wardrobes in build order: the same index names the same wardrobe on every
## machine in an online match (doors likewise).
var hides: Array = []
var lights: Array[OmniLight3D] = []
var manifest: Dictionary
## The palette of the floor built (FLOOR.palette()): what each room type is
## built with. room_dressing.gd and prop_factory.gd read it from the builder.
var palette: GDScript = FLOOR.palette({})
var reduced := false
## The Locust's player is looking: it does not see light, so every lamp, the
## dust, the fog and the probes are hidden. The opaque pass still writes the
## depth its acoustic view reads, but pays for no shadow map and no light
## clustering, which is where that view's budget comes from.
var echo_view := false
## Walls drawn whole, both faces panelled: for modules seen alone from outside
## (the gallery). In a floor every wall has a room on each side.
var full_walls := false
var dust: CPUParticles3D
var curtain_material: ShaderMaterial
var fog_volumes: Array[FogVolume] = []
## Every lit room's reflection probe, made only while it is among the nearest
## (update_visibility): {room, parent, height, size, every_third, probe}.
var probe_slots: Array[Dictionary] = []
# Lamp lights inside furniture; visibility is managed with the rooms.
var practicals: Array[OmniLight3D] = []
# Fluorescent fixtures that flicker (never while effects are reduced).
var flickers: Array = []
## Every fluorescent batten (service rooms), steady or failing: they hum.
var tubes: Array = []
var flicker_clock := 0.0
## Red start lamps in the reception: {light, material, energy}.
var beacons: Array = []
## The floor has lost its power (the blackout of the wing being played).
var dark := false
## Room ids whose lamps are out: the floor's `dark` rooms (map_generator.
## light_rooms()), read once in build().
var dark_ids := {}
## Rooms whose own power is cut (set_room_power()): their lamp stays out.
## Local: nothing sends or saves it (phase 1's systems will).
var unpowered := {}
## How much of each room's lamp is drained, 0 to 1 (drain()), and the energy
## it had before, so draining back to 0 gives that exact energy back.
var drains := {}
var drain_from := {}
## Drained this far, a room is dark for the rules (lit()); a passive drain
## stays under it.
const LIT_DRAIN := 0.9
## Set while a dark room's furniture is built: its lamps stay out.
var building_dark := false
## The module whose furniture is being built (prop_factory.gd), -1 otherwise.
var building_type := -1
## Glowing materials and their unlit copies (switch_off).
var unlit := {}
## What glows by itself when the floor has power -- the frosted domes, the
## lampshades, the battens, the beacon glass -- and how brightly, so a power
## cut can take it away and give it back. Filled the first time it is needed:
## these materials belong to this hotel (duplicated in _init), so nothing here
## reaches another floor. The wall lamps are meshes rather than materials of
## ours (their glow lives inside the model), so they are held apart.
var glows := {}
var lit_sconces: Array[MeshInstance3D] = []
## The exit signs, which are the one thing on the floor with a battery: they
## stay lit when the power goes, sign and green spill both, and are kept out of
## the lists the cut works through. A refuge one can still find in the dark.
var exit_panels: Array[ShaderMaterial] = []
var exit_lamps: Array[OmniLight3D] = []
## And how far one is seen from. Its own, not the furniture lamps' (which are
## off altogether on Low): an emergency light is not decoration.
const EXIT_REACH := 14.0
## The lamp in each lift car's ceiling. A car stands a hand from the wall it
## backs on to, and its lamp, without a shadow, lit the room on the other side
## of that wall: a pool on a dark room's ceiling, from nowhere.
var car_lamps: Array[OmniLight3D] = []
const MATERIALS := ["plaster", "plaster_decrepit", "wood", "panel", "door", "trim", "linen", "fabric", "bedspread", "leather", "metal", "black", "green", "screen", "leaf", "ceramic", "tile", "gold", "carpet", "ceiling", "ceiling_service", "light", "shade", "mirror", "painting", "curtain"]
## The walls' material of the room being built (build_room()).
var wall_material := "plaster"
# Batched primitive meshes. Unit size; transforms carry the dimensions.
## "plain" and "detail" are boxes like any other, batched apart: the plain
## rails and cornices the moulded kit takes the place of, and the boxes only
## the kit has (below, "The moulded kit").
const SHAPES := {"box": "", "cylinder": "@cyl", "cone": "@cone", "plain": "@plain", "detail": "@detail", "detail_cylinder": "@detail@cyl"}

## --- The moulded kit (preset detail_kit; docs/REALISM.md, phase 6) ---------
## Where a wall meets the floor, the dado and the ceiling there are plain
## boxes: a board for a skirting, a batten for a rail, two steps for a
## cornice, and a flat plank with lines drawn on it for the dado's panels.
## With the kit they are mouldings run to a section (mouldings.gd), panels
## raised out of their frames, a plaster rose round each ceiling lamp, a
## switch by each door and a grille high on a wall. Both are built, and the
## preset shows one or the other (set_kit()): a preset is changed in the
## middle of a floor. Nothing of the kit is solid.
const MOULDINGS := preload("res://game/world/hotel/mouldings.gd")
var kit := false
## What only the kit shows, and what it takes the place of.
var kit_shown: Array[GeometryInstance3D] = []
var kit_replaced: Array[GeometryInstance3D] = []
## The kit is drawn round the camera and no further: past KIT_FAR from the
## nearest of a room (KIT_NEAR for the panels, the switches and the grilles)
## the plain pieces stand in again, which from there are the same picture --
## a 2 cm bevel is under a pixel -- for a third of the triangles and none of
## the edges MSAA shades four times over. Per room: a batch is one instance,
## and Godot measures to its middle, so half the room's diagonal is added.
const KIT_NEAR := 16.0
const KIT_FAR := 26.0
## The two hand over across a metre either way in which both are drawn (the
## plain pieces are inside the moulded ones, all but a sliver), so that there
## is never a distance, nor a first frame, at which a wall has neither.
const KIT_OVERLAP := 1.0
const KIT_MARGIN := 0.5

## How far from a room's middle its kit is drawn: `reach` from its nearest.
func kit_reach(parent: Node, reach: float) -> float:
	var room: Variant = batch_roots.get(parent.get_instance_id())
	return reach + (Vector2(room.r, room.g).length() if room != null else 0.0)

## One of the kit's own batches: shown with the kit, and only from near.
func kit_piece(instance: GeometryInstance3D, parent: Node, reach: float) -> void:
	instance.visible = kit
	instance.set_meta("kit_off", not kit)
	instance.visibility_range_end = kit_reach(parent, reach) + KIT_OVERLAP
	instance.visibility_range_end_margin = KIT_MARGIN
	kit_shown.append(instance)

## A batch of the plain pieces the kit takes the place of: with the kit, it
## is what is seen from far.
func kit_plain(instance: GeometryInstance3D, parent: Node) -> void:
	instance.set_meta("kit_far", kit_reach(parent, KIT_FAR) - KIT_OVERLAP)
	instance.visibility_range_begin_margin = KIT_MARGIN
	instance.visibility_range_begin = instance.get_meta("kit_far") if kit else 0.0
	kit_replaced.append(instance)

func set_kit(on: bool) -> void:
	kit = on
	for piece in kit_shown:
		if not is_instance_valid(piece): continue
		piece.visible = on
		piece.set_meta("kit_off", not on)
	for piece in kit_replaced:
		if is_instance_valid(piece): piece.visibility_range_begin = piece.get_meta("kit_far") if on else 0.0

## A length of moulding along a wall: `kind` of mouldings.gd, centred at x,
## hung from y, on the face of the wall that looks towards face * z. The
## sections are drawn for a wall with a dado (mouldings.gd); `back` moves one
## in towards a thinner wall's own face.
func moulding(boundary: Node3D, kind: String, x: float, length: float, y: float, face: int, back := 0.0) -> void:
	var turned := Basis(Vector3.UP, 0.0 if face > 0 else PI) * Basis.from_scale(Vector3(length / MOULDINGS.UNIT, 1, 1))
	place(boundary, MOULDINGS.run(kind), Transform3D(turned, Vector3(x, y, -face * back)), true, "trim", true)

## A plaster partition of an alcove, 12 cm thick and with no dado: a skirting
## and a cornice down both its faces (the kit's alone: bare, it met the floor
## and the ceiling in a line). `frame` is the partition's own, its length
## along x.
const PARTITION_FACE := 0.06
func partition_mouldings(room_node: Node3D, frame: Transform3D, length: float, height: float, skirted := true) -> void:
	var holder := Node3D.new()
	holder.name = "Partition"
	holder.transform = frame
	room_node.add_child(holder)
	for face in [-1, 1]:
		# Each section's back just inside the plaster. (Over a doorway, the
		# cornice alone.)
		if skirted: moulding(holder, "skirting", 0.0, length, 0.0, face, 0.14 - PARTITION_FACE + 0.005)
		moulding(holder, "cornice", 0.0, length, height, face, 0.085 - PARTITION_FACE + 0.005)

## A socket in the skirting: a brass plate and its two slots.
func socket(boundary: Node3D, x: float, face: int) -> void:
	box(boundary, Vector3(x, 0.056, face * 0.175), Vector3(0.07, 0.07, 0.008), "gold", false, "detail")
	for slot in [-1, 1]: box(boundary, Vector3(x + slot * 0.012, 0.058, face * 0.1795), Vector3(0.005, 0.02, 0.002), "black", false, "detail")

## On the ceiling beside the lamp: a smoke detector, and a sprinkler's head
## where the room is a public one.
func ceiling_fittings(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	# A third of the way to the corner the room's position picks.
	var corner := Vector3(1.0 if vary(node.position, 141) < 0.5 else -1.0, 0, 1.0 if vary(node.position, 142) < 0.5 else -1.0)
	var at := Vector3(corner.x * minf(span.x * 0.17, 2.2), 0, corner.z * minf(span.y * 0.17, 2.2))
	box(node, at + Vector3(0, height - 0.006, 0), Vector3(0.14, 0.012, 0.14), "ceramic", false, "detail_cylinder")
	box(node, at + Vector3(0, height - 0.026, 0), Vector3(0.11, 0.03, 0.11), "ceramic", false, "detail_cylinder")
	if not (int(room.type) in palette.SPRINKLER_ROOMS): return
	var other := Vector3(-at.x, 0, -at.z)
	box(node, other + Vector3(0, height - 0.004, 0), Vector3(0.07, 0.008, 0.07), "metal", false, "detail_cylinder")
	box(node, other + Vector3(0, height - 0.03, 0), Vector3(0.022, 0.05, 0.022), "gold", false, "detail_cylinder")
	box(node, other + Vector3(0, height - 0.058, 0), Vector3(0.05, 0.004, 0.05), "gold", false, "detail_cylinder")

## The same moulding round a corner that sticks out into the room towards
## (-sx, -sz) (corner_posts()).
func moulding_corner(node: Node3D, kind: String, corner: Vector3, y: float, sx: int, sz: int) -> void:
	var turn: float = {Vector2i(1, 1): 0.0, Vector2i(1, -1): PI * 0.5, Vector2i(-1, -1): PI, Vector2i(-1, 1): PI * 1.5}[Vector2i(sx, sz)]
	place(node, MOULDINGS.corner(kind), Transform3D(Basis(Vector3.UP, turn), corner + Vector3(0, y, 0)), true, "trim", true)

## The dado of a stretch of wall in raised panels: as many whole ones as fit,
## in the middle, and what is left over at each end as a plain stile.
func dado_panels(boundary: Node3D, x: float, length: float, face: int) -> void:
	var width: float = MOULDINGS.PANEL_WIDTH
	var count := int(floor((length - 0.04) / width))
	var edge := (length - count * width) * 0.5
	var turned := Basis(Vector3.UP, 0.0 if face > 0 else PI)
	for k in count: place(boundary, MOULDINGS.panel(), Transform3D(turned, Vector3(x - length * 0.5 + edge + (k + 0.5) * width, 0, 0)), false, "panel_field", true)
	var tall: float = MOULDINGS.PANEL_HEAD - MOULDINGS.PANEL_FOOT
	var middle: float = (MOULDINGS.PANEL_HEAD + MOULDINGS.PANEL_FOOT) * 0.5
	# From inside the old plank (0.145 out) to the frames' face.
	var thick: float = MOULDINGS.PANEL_FRAME - 0.14
	var out: float = face * (0.14 + thick * 0.5)
	if count == 0: box(boundary, Vector3(x, middle, out), Vector3(length, tall, thick), "panel_field", false, "detail")
	elif edge > 0.001:
		for side in [-1, 1]: box(boundary, Vector3(x + side * (length - edge) * 0.5, middle, out), Vector3(edge, tall, thick), "panel_field", false, "detail")

## A brass switch plate with its toggle, on the plaster at x.
func switch_plate(boundary: Node3D, x: float, inner: int) -> void:
	box(boundary, Vector3(x, 1.26, inner * 0.094), Vector3(0.076, 0.116, 0.008), "gold", false, "detail")
	box(boundary, Vector3(x, 1.268, inner * 0.103), Vector3(0.012, 0.03, 0.012), "black", false, "detail", Vector3(inner * -0.45, 0, 0))

## A ventilation grille high on the plaster at x: a steel frame, slats
## turned down, and the dark of the duct behind them.
const GRILLE := Vector2(0.42, 0.22)
func grille(boundary: Node3D, x: float, inner: int) -> void:
	var y := 2.46
	box(boundary, Vector3(x, y, inner * 0.092), Vector3(GRILLE.x - 0.05, GRILLE.y - 0.05, 0.004), "black", false, "detail")
	for side in [-1, 1]:
		box(boundary, Vector3(x + side * (GRILLE.x - 0.03) * 0.5, y, inner * 0.098), Vector3(0.03, GRILLE.y, 0.016), "metal", false, "detail")
		box(boundary, Vector3(x, y + side * (GRILLE.y - 0.03) * 0.5, inner * 0.098), Vector3(GRILLE.x - 0.06, 0.03, 0.016), "metal", false, "detail")
	for slat in 6:
		box(boundary, Vector3(x, y - 0.065 + slat * 0.026, inner * 0.099), Vector3(GRILLE.x - 0.06, 0.004, 0.022), "metal", false, "detail", Vector3(inner * 0.6, 0, 0))
## The chandelier that hangs in the rooms with high ceilings (the lounges, the
## dining room, the indoor garden: 4.2 m and over) where the rest have a
## dome: a lamp like any other -- the room's own, with its shadow and its
## range -- from a brass chandelier of five shades, half as big again as the
## model, out in a dark room and with the power. Not in the reception, whose
## ceiling has the red lamp the way back is found by.
const CHANDELIER := preload("res://assets/props/hotel/Chandelier_02.res")
const CHANDELIER_SCALE := 1.5
const WALL_LAMP := preload("res://assets/props/wall_lamp/wall_lamp.res")
## The supplied old wooden door, baked by tools/props/build_door.gd: the leaf
## (hinge at the origin, along +X) and the casing (centred on the doorway).
const DOOR_LEAF := preload("res://assets/props/door/door_leaf.res")
const DOOR_FRAME := preload("res://assets/props/door/door_frame.res")
## Where the leaf's faces are, for the room numbers screwed onto them.
const LEAF_FACE := 0.066
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const DRESSING := preload("res://game/world/hotel/room_dressing.gd")
## The graphics preset in force (graphics_presets.gd): how far rooms are drawn
## (room_reach; a hidden room casts no shadow), where the ceiling lamps fade
## (lamp_fade) and the furniture lamps go out, dust, haze and probes. Medium
## until apply_quality() says otherwise: the staged sets use it as built.
var preset: Dictionary = PRESETS.PRESETS[PRESETS.MEDIUM]
## Source sizes of the lamps (a small bulb for PCSS penumbrae), times the
## preset's penumbra (0: plain filtering).
const LAMP_SIZE := 0.12
const PRACTICAL_SIZE := 0.2
const SCONCE_SIZE := 0.05
## Colour and profiles of the lamps (docs/REALISM.md, phase 2).
const LIGHTING := preload("res://game/world/hotel/lighting.gd")
## Lit wall lamps (preset sconce_lights) and how far away they go out.
var sconce_lights: Array[OmniLight3D] = []
const SCONCE_REACH := 24.0
## And how many of them are lit at once. Wall lamps are the many: eight to a
## public room, fifty-odd within reach standing in the middle of a floor, and
## every one of them asks for a place in the shadow atlas along with the
## ceiling and furniture lamps. Over the atlas, Godot draws what does not fit
## **without a shadow** -- and an omni light with no shadow goes straight
## through the wall: the lit room next door appearing on your side of the
## partition, a frame at a time, as you walk and the lamps round you change.
## Measured (tools/dev/light_leak.gd, seed 81): with all of them the worst
## dark room read 0.030 where it should read 0; with the nearest twelve,
## 0.00013; with sixteen it was back to 0.029. The nearest few are all
## anybody sees, and they are the ones lit.
const SCONCES_LIT := 12
## The wall lamps past those twelve (preset sconce_fill): lit all the same,
## without a shadow, each kept in its room by the room's render layer instead
## ("Light that stays in its room", below) -- which is what could not be done
## when the twelve were counted: a lamp with no shadow went through the wall.
## Nearer than SCONCE_REACH and among the twelve, a wall lamp casts and has its
## profile (a cone up, a cone down, nothing behind); further, or past the
## twelve, it is a plain glow on its wall, a little weaker, out to
## SCONCE_FILL_REACH. From that far the difference is the wall being lit or not.
const SCONCE_FILL_REACH := 40.0
const SCONCE_ENERGY := 1.6
const SCONCE_FILL_ENERGY := 0.7
## What each wall lamp is doing (sconce_lights' order).
enum {SCONCE_OUT, SCONCE_CAST, SCONCE_FILL}
var sconce_state := PackedByteArray()
## --- Light that stays in its room (preset static_light) ---------------------
##
## From Bajo up a lamp is kept in its room by its shadow. On Muy bajo no lamp
## casts one: drawing every lamp's six shadow maps, again whenever something
## near it moves, and reading them at every pixel is what an integrated GPU
## cannot pay for. Each lamp is told what it may light instead: every room is
## on one of sixteen render layers (room_layers.gd works out which), whatever
## is built in a room is on its room's layer, and a lamp's cull mask is that
## layer -- and those of the cells its room is open to, a corridor or a salon
## going on. So a dark room next to a lit one is as black as behind a shadow,
## and blacker: no light comes through an open doorway either. What walks from
## room to room (people, the creature) is moved from layer to layer as it goes. Nothing in a room shades anything else: the
## floor under a table is as lit as the table.
## On every other preset the lamps light all the layers, which then mean
## nothing.
const ROOM_LAYERS := preload("res://game/world/hotel/room_layers.gd")
var static_light := false
## Whether anything in force is kept in its room by the layers: static_light,
## the wall lamps past the twelve (sconce_fill) or the ceiling lamps past a
## count (lamps_cast). Then the doors are drawn in their halves and the bodies
## follow their rooms' layers.
var layered := false
## room_layers.assign() of this floor, {} for a staged set.
var room_layers := {}
## Every lamp of the floor, by instance id: the light, the layers it lights
## on static_light, the cull mask and whether it cast a shadow as built, and
## whether update_visibility() looks after its shadow.
var kept_lamps := {}
var body_clock := 0
## A door stands in two rooms. Whole, it would be on both rooms' layers, and
## the lamp of the room in front lit what of it shows behind, through the
## wall: the jambs, the mouldings of the leaf's panels, the edge of a brass
## plaque -- thin bright lines round a shut door in a room that is supposed to
## be black (tools/dev/light_leak.gd). So while static_light is on, a door's
## casing and its leaf are each drawn as two halves (mesh_halves.gd), made the
## first time it is: {bits: the layer of the room in front (+z of the shut
## leaf) and of the one behind, casing: its two halves, sided: [mesh, side] of
## what turns with the leaf (its halves, its plaques), open}. A casing's half
## is always on its own room's layer. What turns with the leaf is on its own
## side's while the door is shut, and on both while it is open or swinging:
## then it stands in a room with both its faces, and the doorway is open.
const HALVES := preload("res://game/world/hotel/mesh_halves.gd")
var door_halves: Array = []
## Bounce light round each lit room (preset bounce): bounce_light.gd.
const BOUNCE := preload("res://game/world/hotel/bounce_light.gd")
var bounce := BOUNCE.new()
## Reflection probes made at once, the nearest (update_visibility), and how
## far down that order a made one is kept: never more than PROBES_KEPT, well
## under the 64 places of Godot's reflection atlas.
const PROBES_SHOWN := 24
const PROBES_KEPT := 32
## Door numbers are not drawn past this: about 5 px tall there, unreadable
## through the tape filter anyway.
const NUMBER_REACH := 20.0
## Casing and jamb stop of each door in doors, hidden with it.
var door_fixtures: Array = []
## Shared meshes: seal slabs by size, and the jamb stop.
var slabs := {}
var stop_mesh: ArrayMesh

func _init() -> void:
	for key in MATERIALS:
		materials[key] = load("res://game/presentation/materials/%s.tres" % key).duplicate()
		materials[key].set_meta("lite", key)
		apply_scan(materials[key], small_maps)
	maps_small = small_maps
	maps_none = no_maps
	curtain_material = materials.curtain
	# A dead ceiling dome: same glass, no glow.
	materials["light_off"] = materials.light.duplicate()
	materials.light_off.emission_enabled = false
	materials.light_off.albedo_color = materials.light.albedo_color.darkened(0.55)
	# The dado's wood without its panels drawn on it: the kit's panels are
	# raised for real (mouldings.gd).
	materials["panel_field"] = materials.panel.duplicate()
	materials.panel_field.set_shader_parameter("panel_spacing", 0.0)
	# The big wardrobes' doors swing: their wood is drawn in the leaf's own
	# space, as a door's is, or the grain would stay where it was while the
	# leaf turned through it (hiding_place.gd).
	for pair in [["wood_leaf", "wood"], ["panel_leaf", "panel"]]:
		materials[pair[0]] = materials[pair[1]].duplicate()
		materials[pair[0]].set_shader_parameter("object_space", true)
		materials[pair[0]].set_shader_parameter("panel_spacing", 0.0)
	# A lampshade whose bulb is out does not glow either.
	materials["shade_off"] = materials.shade.duplicate()
	materials.shade_off.emission_enabled = false

## Scanned maps (docs/REALISM.md, phase 3): a material's set is its "scan"
## metadata, a folder of assets/textures/ made by tools/textures/ingest_pbr.py
## (albedo, normal, orm). Loaded once and shared by every builder; the preset
## chooses the 2048 px ones or the 1024 px ones (small_maps, set by
## hotel_main before a floor is built and by apply_quality()).
static var small_maps := false
## No scans at all: the preset draws every surface from one small picture of
## itself (surface_detail 0; surface.gdshaderinc, baked_surface()), which reads
## none of them, so they are not loaded either. The pictures are, instead:
## tools/textures/bake_lite_maps.gd makes one for each material, and lite.json
## says how many metres each covers.
static var no_maps := false
static var scans := {}
const LITE := "res://assets/textures/lite/"
static var lite := {}
static var lite_sizes := {}
## The size this builder's materials have, and whether they have any.
var maps_small := false
var maps_none := false

static func apply_scan(material: Material, small: bool) -> void:
	if not material is ShaderMaterial: return
	apply_lite(material)
	if not material.has_meta("scan"): return
	if no_maps:
		scans.clear()
		for map in ["albedo_map", "normal_map", "orm_map"]: material.set_shader_parameter(map, null)
		material.set_shader_parameter("use_maps", false)
		return
	var maps := scan_maps(material.get_meta("scan"), small)
	if maps.is_empty(): return
	material.set_shader_parameter("albedo_map", maps.albedo)
	material.set_shader_parameter("normal_map", maps.normal)
	material.set_shader_parameter("orm_map", maps.orm)
	material.set_shader_parameter("use_maps", true)

## A material's own small picture while there are no scans (its "lite"
## metadata is its name, given in _init()), and none otherwise.
static func apply_lite(material: ShaderMaterial) -> void:
	if not no_maps: lite.clear()
	var key := String(material.get_meta("lite", ""))
	var picture: Texture2D = lite_map(key) if no_maps else null
	material.set_shader_parameter("use_lite", picture != null)
	material.set_shader_parameter("lite_map", picture)
	if picture != null: material.set_shader_parameter("lite_metres", lite_sizes[key])

static func lite_map(key: String) -> Texture2D:
	if lite_sizes.is_empty() and FileAccess.file_exists(LITE + "lite.json"):
		var listed = JSON.parse_string(FileAccess.get_file_as_string(LITE + "lite.json"))
		if listed is Dictionary:
			for title in listed: lite_sizes[title] = Vector2(float(listed[title][0]), float(listed[title][1]))
	if not lite_sizes.has(key): return null
	if not lite.has(key): lite[key] = load(LITE + key + ".png")
	return lite[key]

static func scan_maps(set_name: String, small: bool) -> Dictionary:
	var key := set_name + ("_1k" if small else "")
	if not scans.has(key):
		var folder := "res://assets/textures/%s/" % set_name
		if not ResourceLoader.exists(folder + "albedo.jpg"): return {}
		# The other size goes: never both in video memory.
		scans.erase(set_name + ("" if small else "_1k"))
		var suffix := "_1k" if small else ""
		scans[key] = {}
		for kind in ["albedo", "normal", "orm"]: scans[key][kind] = load(folder + kind + suffix + ".jpg")
	return scans[key]

## The floor's share of vary(), from its seed.
static func looks_of(run_seed: int) -> float:
	return float(posmod(hash([run_seed, "looks"]), 100003)) * 0.0137

# Deterministic variation for what is only looked at (paintings, what stands
# along the walls, a flickering batten): from a position and the floor's seed
# (looks, set in build()), so every machine dresses a room the same and the
# same corner of two floors is not dressed alike. It never consumes the
# generator's randomness. Staged sets (intro, title) keep looks at 0.
var looks := 0.0
func vary(value: Vector3, salt := 0) -> float:
	return fposmod(sin(value.x * 12.9898 + value.z * 78.233 + value.y * 37.719 + salt * 11.31 + looks) * 43758.5453, 1.0)

## Nodes whose whole subtree is batched together (a room: its walls and its
## furniture). One MultiMesh per material for the room instead of one per
## wall and per piece of furniture: a fraction of the draw calls, in the
## camera pass and in every face of every shadow round it.
var batch_roots := {}

## Where a box under `parent` is batched, and its parent's transform in that
## node's space. The nodes are not in the tree yet, so the chain is walked by
## hand. Anything outside a registered room (opening scene, title set) keeps
## one batch per parent as before.
func batch_target(parent: Node3D) -> Array:
	var node: Node = parent
	var chain := Transform3D.IDENTITY
	while node != null and node != self:
		if batch_roots.has(node.get_instance_id()): return [node, chain]
		chain = (node as Node3D).transform * chain
		node = node.get_parent()
	return [parent, Transform3D.IDENTITY]

## A room's solid boxes, every one a shape of one body the room has, by the
## room's instance id: a body for each box was a fifth of the nodes of a
## floor of three whole plantas.
var solids := {}

func box(parent: Node3D, pos: Vector3, size: Vector3, material: String, solid := false, form := "box", euler := Vector3.ZERO) -> void:
	# An empty material creates only the collider (detailed visuals stay separate).
	var target := batch_target(parent)
	if not material.is_empty():
		var key: int = target[0].get_instance_id()
		if not batches.has(key): batches[key] = {"parent": target[0], "groups": {}}
		var groups: Dictionary = batches[key].groups
		var group: String = material + SHAPES[form]
		if not groups.has(group): groups[group] = []
		groups[group].append(target[1] * Transform3D(Basis.from_euler(euler) * Basis.from_scale(size), pos))
	if solid:
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = size
		shape.shape = cube
		var room: Node3D = target[0]
		if batch_roots.has(room.get_instance_id()):
			var body: StaticBody3D = solids.get(room.get_instance_id())
			if body == null:
				body = StaticBody3D.new()
				body.name = "Solid"
				room.add_child(body)
				solids[room.get_instance_id()] = body
			shape.transform = target[1] * Transform3D(Basis.IDENTITY, pos)
			body.add_child(shape)
		else:
			# Outside a room (the staged sets): a body of its own, as ever.
			var single := StaticBody3D.new()
			single.position = pos
			shape.name = "CollisionShape3D"
			single.add_child(shape)
			parent.add_child(single)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: String, euler := Vector3.ZERO) -> void:
	box(parent, pos, Vector3(radius * 2, height, radius * 2), material, false, "cylinder", euler)

static func unit_mesh(group: String) -> Mesh:
	if group.ends_with("@cyl") or group.ends_with("@cone"):
		var rounded := CylinderMesh.new()
		rounded.height = 1.0
		rounded.bottom_radius = 0.5
		rounded.top_radius = 0.28 if group.ends_with("@cone") else 0.5
		rounded.radial_segments = 20
		rounded.rings = 1
		return rounded
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	return cube

static func material_of(group: String) -> String:
	return group.get_slice("@", 0)

## Materials whose vertices move with TIME (the curtain sway). Godot redraws
## every shadow that such a caster falls in on every frame, so they cast
## through a still copy instead (a 3.5 cm sway never shows in a shadow).
const SWAYING := ["curtain"]

## Whether a batch of pieces stands in the bounce light (H4).
func bounces(_group: String) -> bool: return true

func flush() -> void:
	for batch in batches.values():
		for group in batch.groups:
			var transforms: Array = batch.groups[group]
			var mesh := unit_mesh(group)
			mesh.material = materials[material_of(group)]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			var room: Variant = batch_roots.get(batch.parent.get_instance_id())
			# A room's boxes carry the room (surface.gdshaderinc room_data), for
			# the grime where its surfaces meet.
			multi.use_custom_data = room != null
			multi.mesh = mesh
			multi.instance_count = transforms.size()
			for i in transforms.size():
				multi.set_instance_transform(i, transforms[i])
				if room != null: multi.set_instance_custom_data(i, room)
			var instance := MultiMeshInstance3D.new()
			instance.name = "Mesh_" + group.replace("@", "-")
			instance.multimesh = multi
			# Outside a room (door plaques, staged sets): no bounce light,
			# like the doors themselves.
			if room == null: instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			# A plaque 4 mm proud of its leaf has no shadow to speak of.
			if batch.parent.has_meta("side"): instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var only_kit: bool = "@detail" in group
			if only_kit:
				# A switch plate or a grille's slats have no shadow to speak of.
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				kit_piece(instance, batch.parent, KIT_NEAR)
			elif group.ends_with("@plain"): kit_plain(instance, batch.parent)
			batch.parent.add_child(instance)
			# The bounce light is baked from the plain pieces on every preset.
			if room != null and not only_kit and bounces(group): bounce.add(batch.parent.get_instance_id(), group, transforms)
			if material_of(group) in SWAYING:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var still := MultiMeshInstance3D.new()
				still.name = instance.name + "_Shadow"
				still.multimesh = multi
				still.material_override = materials.black
				still.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				batch.parent.add_child(still)
	batches.clear()
	for batch in model_batches.values():
		for entry in batch.meshes.values():
			var mesh: Mesh = entry.mesh
			var transforms: Array = entry.transforms
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = transforms.size()
			for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
			var instance := MultiMeshInstance3D.new()
			instance.name = "Model_" + mesh.resource_name
			instance.multimesh = multi
			# For the handles place() gave out: where each placement ended up.
			entry["multi"] = multi
			entry["instance"] = instance
			var size := mesh.get_aabb().size
			if entry.has("hand"):
				# Drawn as far as the clock it belongs to, and kept to be turned.
				size = (entry.body as Mesh).get_aabb().size
				clock_hands.append({"multi": multi, "hand": entry.hand, "stands": transforms})
			# The kit's pieces wear one of the hotel's own materials.
			if entry.material != "": instance.material_override = materials[entry.material]
			if entry.kit: kit_piece(instance, batch.parent, KIT_NEAR if mesh == MOULDINGS.panel() else KIT_FAR)
			# Lamps redraw their shadows whenever anything moves near them:
			# only pieces of furniture cast, never what stands on them.
			if not entry.casts or (size.y < SHADOW_MODEL and not mesh.has_meta("casts")):
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if size.y < SMALL_MODEL and maxf(size.x, size.z) < 0.8 and not entry.kit:
				# Small things are not drawn from afar.
				instance.visibility_range_end = SMALL_REACH
				instance.visibility_range_end_margin = 2.0
			batch.parent.add_child(instance)
	model_batches.clear()
	turn_hands(clock_time if clock_time >= 0 else UNTOLD)
	solids.clear()
	# What held walls, stretches and pieces of furniture only for their
	# transform while a room was built, and has nothing of its own left.
	for room in room_nodes: drop_empty(room)

## Frees the plain holders under `node` that are left with nothing in them
## (batch_target() walked through them while the room was built), from the
## deepest up.
func drop_empty(node: Node) -> void:
	for child in node.get_children():
		drop_empty(child)
		if child.get_child_count() == 0 and child.get_class() == "Node3D" and child.get_script() == null:
			node.remove_child(child)
			child.free()

## The clocks keep the camcorder's time (the author's word, 13 October 2026:
## all of them, with their second hands, and back with the tape when it is
## rewound). Every hand of every clock here is an instance of its own mesh
## -- baked pointing at twelve, turning about +Z at its origin (tools/props/
## build_catalogue.gd, CLOCKS) -- and these are their batches, with where
## each hand stands at twelve. The level says the second (tell_time); a set
## nobody tells (the opening scene, the title room) shows UNTOLD.
var clock_hands: Array = []
var clock_time := -1
const UNTOLD := 2 * 3600 + 50 * 60

## How far round its dial a hand is at a second of the day, 0 to 1. The
## second hand steps; the others creep.
static func hand_turn(hand: String, seconds: int) -> float:
	match hand:
		"second": return float(posmod(seconds, 60)) / 60.0
		"minute": return float(posmod(seconds, 3600)) / 3600.0
	return float(posmod(seconds, 43200)) / 43200.0

func tell_time(seconds: int) -> void:
	if seconds == clock_time: return
	clock_time = seconds
	turn_hands(seconds)

func turn_hands(seconds: int) -> void:
	for entry in clock_hands:
		# Clockwise, seen from in front of it.
		var turned := Transform3D(Basis(Vector3.BACK, -TAU * hand_turn(String(entry.hand), seconds)), Vector3.ZERO)
		var multi: MultiMesh = entry.multi
		var stands: Array = entry.stands
		for i in stands.size(): multi.set_instance_transform(i, stands[i] * turned)

## Baked models (assets/props/hotel, room_dressing.gd), batched per room and
## per mesh like the boxes: one MultiMesh each. Nothing under SHADOW_MODEL
## tall casts a shadow, nor anything placed with casts off (what stands on a
## top or a shelf); things under SMALL_MODEL are not drawn past SMALL_REACH.
var model_batches := {}
const SHADOW_MODEL := 0.6
const SMALL_MODEL := 0.3
const SMALL_REACH := 16.0

## How far every placed model stands off what it was put on (metres), and how
## far a wall stops short of a doorway's jamb: surfaces in one plane flicker
## into each other (tools/dev/zfight_scan.gd looks for them).
const MODEL_LIFT := 0.002
## (The door's frame is not quite centred on its opening: its jambs' faces
## are 1 mm outside it on one side and 4 mm inside on the other.)
const JAMB_GAP := 0.01
## `material` dresses the mesh in one of the hotel's own (the moulded kit's
## pieces, which have none), and `only_kit` shows it only with the kit.
## Returns where it is drawn: {entry, index, parent}, the batch, its place in
## it (its MultiMesh is entry.multi once flushed) and the room node the batch
## hangs from.
func place(parent: Node3D, mesh: Mesh, xform: Transform3D, casts := true, material := "", only_kit := false) -> Dictionary:
	var target := batch_target(parent)
	var key: int = target[0].get_instance_id()
	if not model_batches.has(key): model_batches[key] = {"parent": target[0], "meshes": {}}
	var meshes: Dictionary = model_batches[key].meshes
	var slot := "%d:%s:%s:%s" % [mesh.get_instance_id(), casts, material, only_kit]
	if not meshes.has(slot): meshes[slot] = {"mesh": mesh, "casts": casts, "material": material, "kit": only_kit, "transforms": []}
	# A hair off whatever it stands on: a model whose underside is drawn from
	# both sides (a bookcase, a rack, a bin, a crate) lay in the plane of the
	# floor under it and flickered into it.
	var stood := Transform3D(xform.basis, xform.origin + Vector3(0, MODEL_LIFT, 0))
	meshes[slot].transforms.append(target[1] * stood)
	var handle := {"entry": meshes[slot], "index": meshes[slot].transforms.size() - 1, "parent": target[0]}
	# A clock's hands, each an instance of its own mesh where the body's
	# says its axis is (tell_time turns them).
	if mesh.has_meta("hands"):
		for hand in mesh.get_meta("hands"):
			var hand_mesh: Mesh = load("%s_%s.res" % [mesh.resource_path.get_basename(), hand])
			var hand_slot := "%d:hand" % hand_mesh.get_instance_id()
			if not meshes.has(hand_slot): meshes[hand_slot] = {"mesh": hand_mesh, "casts": false, "material": "", "kit": false, "transforms": [], "hand": String(hand), "body": mesh}
			meshes[hand_slot].transforms.append(target[1] * stood * Transform3D(Basis.IDENTITY, hand_mesh.get_meta("pivot")))
	return handle

## A decal from assets/decals/ (tools/textures/ingest_dressing.py) under
## parent: projected along the transform's -Y over size, as strong as
## strength. Only on surfaces facing it, and faded out from afar. rank (0-1)
## orders a room's decals: the preset shows those under its share (decals).
func decal(parent: Node3D, name: String, xform: Transform3D, size: Vector3, strength: float, rank: float) -> void:
	var tint: Color = DECAL_TINT.get(name, Color.WHITE)
	var projector := Decal.new()
	projector.transform = xform
	projector.size = size
	projector.texture_albedo = load("res://assets/decals/%s.png" % name)
	var normal := "res://assets/decals/%s_normal.png" % name
	if ResourceLoader.exists(normal): projector.texture_normal = load(normal)
	projector.modulate = Color(tint.r, tint.g, tint.b, clampf(strength * tint.a, 0.0, 1.0))
	projector.normal_fade = 0.4
	projector.upper_fade = 0.2
	projector.lower_fade = 0.2
	projector.distance_fade_enabled = true
	projector.distance_fade_begin = DECAL_REACH
	projector.distance_fade_length = 4.0
	projector.set_meta("rank", rank)
	projector.visible = decal_shown(projector)
	parent.add_child(projector)
	decals.append(projector)

var decals: Array[Decal] = []

## Whether a decal is drawn: its share of the preset, and never while the
## floor is drawn for the creature's ears (echo_view). Forward+ stamps a
## decal on every fragment inside its box, unshaded and transparent ones
## too, and the echo field is a quad sitting on the camera that echo_field
## stretches over the whole frame: with the camera pressed against a damp
## wall (the spring arm leaves it 0.2-0.3 m off, a wall decal reaches 0.32
## m out), the stain was spread across the hunter's screen in olive streaks.
## The grains and its own body standing in a box took the stain as well.
func decal_shown(projector: Decal) -> bool:
	return projector.get_meta("rank") < float(preset.decals) and not echo_view

## Decals scanned from something else: footprints in sand made mud, a white
## handprint made grime, the smear softened.
const DECAL_TINT := {"Footsteps003": Color(0.2, 0.16, 0.11, 1.0), "Fingerprints004": Color(0.4, 0.36, 0.3, 1.0), "Smear003": Color(1, 1, 1, 0.45)}
## Decals are not drawn past this: some 20 in view at most.
const DECAL_REACH := 14.0

## Compatibility draws no decals: none are made.
func decals_drawn() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

## reach: past it the label is not drawn at all (0 keeps it at any distance).
## Engraved figures on the door plaques.
const PLAQUE_INK := Color(0.07, 0.05, 0.03)

func text(parent: Node3D, words: String, pos: Vector3, yaw := 0.0, size := 38, reach := 0.0, ink := Color("d3bd8e")) -> void:
	var label := Label3D.new()
	label.text = words
	label.position = pos
	label.rotation.y = yaw
	label.font_size = size
	label.pixel_size = 0.007
	label.modulate = ink
	label.outline_size = 0
	# Lit like everything else: an unshaded label glowed in a black room.
	label.shaded = true
	# Blended text never reaches a shadow map; saying so keeps it out of them.
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if reach > 0.0:
		label.visibility_range_end = reach
		label.visibility_range_end_margin = 1.0
	parent.add_child(label)

## Staged sets (opening scene, title screen), built outside the floor plan.
## A papered wall between two floor points, with doorway gaps centred at the
## given distances from its start.
func set_wall(from: Vector2, to: Vector2, gaps: Array, height := 2.9) -> void:
	var direction := to - from
	var length := direction.length()
	var boundary := Node3D.new()
	var middle := (from + to) * 0.5
	boundary.position = Vector3(middle.x, 0, middle.y)
	boundary.rotation.y = atan2(-direction.y, direction.x)
	add_child(boundary)
	var cuts: Array = gaps.duplicate()
	cuts.sort()
	var start := 0.0
	var portal: float = FLOOR.PORTAL
	for centre in cuts + [length + portal * 0.5]:
		var stop: float = minf(centre - portal * 0.5, length)
		if stop - start > 0.01:
			var x := (start + stop) * 0.5 - length * 0.5
			box(boundary, Vector3(x, height / 2, 0), Vector3(stop - start, height, 0.18), "plaster", true)
			for face in [-1, 1]:
				box(boundary, Vector3(x, 0.48, face * 0.11), Vector3(stop - start, 0.96, 0.07), "panel")
				box(boundary, Vector3(x, 0.98, face * 0.15), Vector3(stop - start, 0.05, 0.035), "trim")
				box(boundary, Vector3(x, 0.07, face * 0.155), Vector3(stop - start, 0.14, 0.03), "trim")
				box(boundary, Vector3(x, height - 0.05, face * 0.12), Vector3(stop - start, 0.1, 0.06), "trim")
		if centre < length:
			var x: float = centre - length * 0.5
			box(boundary, Vector3(x, (height + 2.65) / 2, 0), Vector3(portal, height - 2.65, 0.18), "plaster", true)
			for face in [-1, 1]:
				box(boundary, Vector3(x, 2.74, face * 0.165), Vector3(portal + 0.26, 0.14, 0.035), "trim")
				for side in [-1, 1]: box(boundary, Vector3(x + side * (portal * 0.5 + 0.06), 1.36, face * 0.165), Vector3(0.14, 2.72, 0.035), "trim")
		start = centre + portal * 0.5

## A door leaf hinged at the south edge of a doorway in a wall running along Z;
## returns its hinge. A negative turn swings it towards +X. With `yaw` the
## whole door turns for walls along other directions (PI / 2: a wall along X,
## hinged at its east edge).
func set_door(centre: Vector3, number: String, yaw := 0.0) -> Node3D:
	var width: float = FLOOR.LEAF_WIDTH
	var hinge := Node3D.new()
	hinge.position = centre + Basis(Vector3.UP, yaw) * Vector3(0, 0, width * 0.5)
	hinge.rotation.y = yaw
	add_child(hinge)
	var holder := Node3D.new()
	holder.rotation.y = PI / 2
	hinge.add_child(holder)
	var leaf := MeshInstance3D.new()
	leaf.mesh = DOOR_LEAF
	holder.add_child(leaf)
	if not number.is_empty():
		text(holder, number, Vector3(width * 0.5, 1.94, LEAF_FACE), 0, 24)
		text(holder, number, Vector3(width * 0.5, 1.94, -LEAF_FACE), PI, 24)
	return hinge

## A shut door has to stop light, and a shadow map sees through a crack or
## a thin leaf. Two shadow-only pieces, never drawn and without collision:
##  - light_seal(): a slab inside the leaf that swings with it. SEAL_DEPTH is
##    under the leaf's thinnest part (its sunken panels, 3.5 cm either side of
##    the middle), or it would shade the leaf's own panels (they came out
##    blotchy while the door was shut).
##  - jamb_seal(): strips fixed in the doorway, SEAL_LIP into the opening
##    behind the edges of the leaf and SEAL_OVERLAP into the wall and header,
##    so no crack round a shut leaf lets the next room's light through. These
##    are drawn too, as the frame's door stop, so no crack can be seen through.
## Both are always there: one that appeared only once the door had finished
## closing made the room go dark all at once.
const SEAL_DEPTH := 0.04
const SEAL_OVERLAP := 0.12
const SEAL_LIP := 0.04
const OPENING_HIGH := 2.65
func light_seal(mesh: Mesh = DOOR_LEAF) -> MeshInstance3D:
	var bounds := mesh.get_aabb()
	return shadow_block("LightSeal", Vector3(bounds.size.x - 0.02, bounds.size.y - 0.02, SEAL_DEPTH), bounds.get_center() * Vector3(1, 1, 0))

func jamb_seal(center: Vector3, yaw: float, frame: Mesh = null) -> Node3D:
	var stop := door_stop(frame)
	stop.name = "JambSeal"
	stop.position = center
	stop.rotation.y = yaw
	return stop

## The jamb strips are drawn, like the stop of a real door frame: through the
## crack beside a shut leaf you saw straight into the lit room next door.
## The two sides and the head are one mesh, the same for every doorway.
func door_stop(frame: Mesh = null) -> MeshInstance3D:
	if stop_mesh == null:
		var edge := FLOOR.PORTAL * 0.5
		var side_width := SEAL_LIP + SEAL_OVERLAP
		var strips := []
		for side in [-1.0, 1.0]:
			strips.append([Vector3(side_width, OPENING_HIGH + SEAL_OVERLAP, SEAL_DEPTH), Vector3(side * (edge - SEAL_LIP + side_width * 0.5), (OPENING_HIGH + SEAL_OVERLAP) * 0.5, 0)])
		strips.append([Vector3(FLOOR.PORTAL + SEAL_OVERLAP * 2.0, SEAL_LIP + SEAL_OVERLAP, SEAL_DEPTH), Vector3(0, OPENING_HIGH - SEAL_LIP + (SEAL_LIP + SEAL_OVERLAP) * 0.5, 0)])
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for strip in strips:
			var box := BoxMesh.new()
			box.size = strip[0]
			tool.append_from(box, 0, Transform3D(Basis.IDENTITY, strip[1]))
		stop_mesh = tool.commit()
	var block := MeshInstance3D.new()
	block.name = "Stop"
	block.mesh = stop_mesh
	block.material_override = (frame if frame != null else DOOR_FRAME).surface_get_material(0)
	return block

## Each face shows the number of the room behind the door, as seen from the
## room that face looks into, on a brass plaque screwed to the leaf. A door
## into service or common space has no plaque at all. (H2: a floor kind may
## mark its doors otherwise.)
func door_plaques(door: Node3D, a: Dictionary, b: Dictionary, center: Vector3, yaw: float) -> void:
	var half := FLOOR.LEAF_WIDTH * 0.5
	var b_side := signf((FLOOR.position_of(b) - center).dot(Basis(Vector3.UP, yaw).z))
	for which in 2:
		var behind: Dictionary = a if which == 0 else b
		var number := int(behind.get("number", 0))
		if number <= 0: continue
		var side := b_side if which == 0 else -b_side
		# On a holder of its own, which says which face it is on: 0 the one
		# that looks the way the shut leaf's +z does, 1 the other
		# (door_halves).
		var plaque := Node3D.new()
		plaque.name = "Plaque_%d" % which
		plaque.set_meta("side", 0 if side > 0.0 else 1)
		door.add_child(plaque)
		box(plaque, Vector3(half, 1.94, side * (LEAF_FACE + 0.002)), Vector3(0.34, 0.19, 0.004), "gold")
		text(door, str(number), Vector3(half, 1.94, side * (LEAF_FACE + 0.005)), 0.0 if side > 0 else PI, 20, NUMBER_REACH, PLAQUE_INK)

## The leaf and the casing of the door between two rooms: a floor kind may
## hang other doors (spec_f1_geometry.md H1).
func leaf_mesh(_a: Dictionary, _b: Dictionary) -> Mesh: return DOOR_LEAF

func frame_mesh(_a: Dictionary, _b: Dictionary) -> Mesh: return DOOR_FRAME

## The power goes. Every light in the hotel dies at once: the ceilings, the
## lamps inside the furniture, the wall sconces, the service battens and the
## red lamp of the reception. The televisions are not touched (they have their
## own set) and neither is anybody's torch.
##
## It comes back the same way. The power belongs to the wing that lost it, so
## the next one is found lit: `blackout(false)` hands the ceilings back to the
## room culling (which only shows a lamp that is not marked out), and the
## battens and the beacon, that nothing else looks after, are lit here.
func blackout(on: bool) -> void:
	if dark == on: return
	dark = on
	for light in lights:
		# The lamp of a cell with nothing in it is out for good.
		if light.has_meta("void"): continue
		# A room whose own power is cut stays out (set_room_power()).
		if on: light.set_meta("off", true)
		elif not dark_ids.has(int(light.get_meta("room", -1))) and not unpowered.has(int(light.get_meta("room", -1))): light.remove_meta("off")
		light.visible = light.visible and not on
	for lamp in practicals: lamp.visible = lamp.visible and not on
	for lamp in sconce_lights: lamp.visible = lamp.visible and not on
	for entry in tubes: entry.light.visible = entry.light.visible and not on
	for entry in beacons:
		# A beacon hangs off its room and nobody shows it again frame by frame.
		entry.light.visible = not on
	# Lamps stop glowing as well as stop lighting. A dome, a shade, a batten or
	# a wall lamp is a lit surface in its own right, and one left glowing over
	# a room that nothing else lights is the only thing still visible in it:
	# the power cut ignored by the lamps it was supposed to put out.
	for material in held_glows():
		material.emission_energy_multiplier = 0.0 if on else glows[material]
	for sconce in lit_sconces:
		if on: switch_off(sconce)
		else: switch_on(sconce)
	# The bounce baked for the lit rooms would keep lighting them.
	if on and is_instance_valid(bounce): bounce.show_near(Vector3(0, -9000, 0), false)

## Every glow this floor owns, with the strength it was built at. The ones that
## are animated (the battens' flicker, the beacon's blink) are written again
## from scratch every frame once the power is back, so what is kept for them is
## only a starting point.
func held_glows() -> Array:
	if glows.is_empty():
		for key in materials:
			var surface := materials[key] as BaseMaterial3D
			if surface != null and surface.emission_enabled: glows[surface] = surface.emission_energy_multiplier
		for entry in beacons:
			if entry.has("material"): glows[entry.material] = entry.material.emission_energy_multiplier
	return glows.keys()

## Puts out whatever glows on a mesh (lamp shades, bulbs): same surfaces,
## emission off.
func switch_off(instance: MeshInstance3D) -> void:
	for surface in instance.mesh.get_surface_count():
		var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
		if material == null or not material.emission_enabled: continue
		if not unlit.has(material):
			var dark := material.duplicate() as BaseMaterial3D
			dark.emission_enabled = false
			dark.albedo_color = dark.albedo_color.darkened(0.3)
			unlit[material] = dark
		instance.set_surface_override_material(surface, unlit[material])

## The other way round: the mesh glows with its own materials again.
func switch_on(instance: MeshInstance3D) -> void:
	for surface in instance.mesh.get_surface_count(): instance.set_surface_override_material(surface, null)

func shadow_block(title: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	var block := MeshInstance3D.new()
	block.name = title
	# Every door's seal is the same slab: one mesh for all of them.
	if not slabs.has(size):
		var slab := BoxMesh.new()
		slab.size = size
		slabs[size] = slab
	block.mesh = slabs[size]
	block.position = at
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return block

## The pairs of cells with no wall between them (corridor running on, or a
## salon), by pair: looked up for every wall and every door.
var open_pairs := {}
## While a floor is put up. build() hands a frame back between plantas and
## before the navigation: a window that answers nothing for five seconds is
## "not responding" to Windows, and all in one go a floor of three whole
## plantas held it three seconds on this PC, more on a slower one. The three
## navigation bakes go together (two seconds): with a frame between them, the
## navigation took in each planta on its own and the floor was ready two
## seconds later. Meanwhile nothing of the floor is drawn: it is hidden, and
## update_visibility() leaves it be (the frames in between drew every room
## built so far, lamps and all).
var building := false

func build(data: Dictionary) -> void:
	building = true
	visible = false
	manifest = data
	palette = FLOOR.palette(data)
	looks = looks_of(int(data.get("seed", 0)))
	open_pairs.clear()
	for pair in data.get("merged", []): open_pairs[Vector2i(int(pair[0]), int(pair[1]))] = true
	decide_dark(data)
	var planta := int(data.rooms[0].get("wing", 0)) if not data.rooms.is_empty() else 0
	for room in data.rooms:
		# One planta at a time, with a frame between them.
		if int(room.get("wing", 0)) != planta:
			planta = int(room.get("wing", 0))
			await get_tree().process_frame
		var node := Node3D.new()
		node.name = "Room_%d_%s" % [room.id, palette.TYPES[room.type]]
		node.position = FLOOR.position_of(room)
		add_child(node)
		room_nodes.append(node)
		room_planta.append(FLOOR.planta_of(node.position.y))
		# A cell its planta does not use: nothing is built there. Its lamp
		# stands in the list, off, so a room's lamp is still lights[id].
		if FLOOR.is_void(room):
			var lamp := OmniLight3D.new()
			lamp.visible = false
			lamp.light_energy = 0.0
			lamp.set_meta("off", true)
			lamp.set_meta("void", true)
			lamp.set_meta("room", int(room.id))
			node.add_child(lamp)
			lights.append(lamp)
			continue
		build_room(node, room)
	DRESSING.fuse_boxes_left(self)
	hides.append_array(big_hides)
	big_hides.clear()
	route_signs.clear()
	for sign in ROUTE_SIGN.place(data): route_sign(sign)
	for edge in data.edges:
		var a: Dictionary = data.rooms[edge[0]]
		var b: Dictionary = data.rooms[edge[1]]
		# One door per connection, with a physical leaf and a stable identifier.
		if open_pairs.has(Vector2i(int(edge[0]), int(edge[1]))): continue
		# The last door of the floor, the one with the lock, is built at the
		# end so the gates keep the order of their stages.
		if gate_stage(data, int(a.id), int(b.id)) == int(data.get("wings", 3)): continue
		var spec: Dictionary = data.get("doors", {}).get("%d:%d" % [int(a.id), int(b.id)], {})
		var center := FLOOR.portal_between(a, b)
		var yaw := FLOOR.leaf_yaw(a, b, spec)
		# In each room's bounce stand-in the doorway is shut (bounce_light.gd):
		# through a hole in it the voxels there took the next room's lamps
		# and lit the leaf's face on this side, door closed.
		for room in [a, b]:
			var slab := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(FLOOR.PORTAL, 2.65, 0.12)), center - FLOOR.position_of(room) + Vector3(0, 1.325, 0))
			bounce.add(room_nodes[int(room.id)].get_instance_id(), "door", [slab])
		var door = DOOR.new()
		door.name = "Door_%d_%d" % [a.id, b.id]
		door.collision_layer = 8
		door.collision_mask = 4
		var half := FLOOR.LEAF_WIDTH * 0.5
		door.position = center + Basis(Vector3.UP, yaw) * Vector3(-half, 0, 0)
		door.rotation.y = yaw
		door.closed_rotation = yaw
		door.open_turn = DOOR.OPEN_TURN * FLOOR.leaf_turn(a, b, spec, center, yaw)
		door.doorway = center
		add_child(door)
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf"
		leaf.mesh = leaf_mesh(a, b)
		# A leaf and its casing stand in both rooms' bounce volumes: Godot
		# lit each face with both, and a shut door's far face glowed with the
		# lamps of the room behind it. Doors take no bounce light.
		leaf.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		door.add_child(leaf)
		door.add_child(light_seal(leaf.mesh))
		# The body keeps the leaf's original box: walking, the creature's reach
		# and the physical checks were all tuned against it.
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var cube := BoxShape3D.new()
		cube.size = Vector3(FLOOR.LEAF_WIDTH, 2.58, 0.07)
		shape.shape = cube
		shape.position = Vector3(half, 1.29, 0)
		door.add_child(shape)
		# The casing belongs to the wall, not the leaf: it stays when it swings.
		var casing := MeshInstance3D.new()
		casing.name = "Casing_%d_%d" % [a.id, b.id]
		casing.mesh = frame_mesh(a, b)
		casing.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		casing.position = center
		casing.rotation.y = yaw
		add_child(casing)
		var stop := jamb_seal(center, yaw, casing.mesh)
		add_child(stop)
		# They belong to the wall, but are shown only as far as the door is.
		door_fixtures.append([casing, stop])
		door_plaques(door, a, b, center, yaw)
		# The door on to the next wing is the gate of its stage: shut, locked,
		# and never open at the start.
		var stage := gate_stage(data, int(a.id), int(b.id))
		if stage > 0:
			door.gate_stage = stage
			door.locked = true
			gates.append(door)
		elif bool(spec.get("open", false)): door.open_immediately()
		doors.append(door)
	# Last, so the gates stay in the order of their stages and the doors keep
	# the indices the network knows them by.
	build_exit_door(data)
	for door in doors: door_planta.append(FLOOR.planta_of(door.doorway.y))
	build_lifts(data)
	flush()
	assign_layers()
	await get_tree().process_frame
	build_navigation()
	build_dust()
	building = false
	visible = true

## How far from a doorway's middle the middle of a painting keeps: its lamps
## (0.98 m either side) would be on the casing.
const PAINTING_CLEAR := 2.2

## A room in steps, each a function another floor's builder can override:
## floor_surface, ceiling, walls, fittings, room_lamp and extras. The order is
## the hotel's: the walls' blockers end in the occluder, and extras retouches
## the lamp room_lamp made.
func build_room(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	# Half the floor round the room's origin, the height, and the open sides
	# of a hall (no wall, the next cell goes on): no grime gathers there.
	batch_roots[node.get_instance_id()] = Color(span.x * 0.5, span.y * 0.5, height, 0.0)
	wall_material = palette.wall_material(room)
	floor_surface(node, room)
	ceiling(node, room)
	walls(node, room)
	fittings(node, room)
	room_lamp(node, room)
	if room.hall == room.id and room.hall >= 0:
		if RenderingServer.get_current_rendering_method() == "forward_plus":
			var fog := FogVolume.new()
			fog.size = Vector3(span.x * 0.65, 0.7, span.y * 0.65)
			fog.position.y = 0.45
			var fog_mat := FogMaterial.new()
			fog_mat.density = 0.025
			fog_mat.albedo = Color("81775f")
			fog.material = fog_mat
			node.add_child(fog)
			fog_volumes.append(fog)
	# Every lit room can have a reflection probe the size of the room; the
	# preset decides which are in use (probes: every third hall, or every lit
	# room), and only the nearest exist (update_visibility). A dark room has
	# none and stays black.
	if not dark_room(room):
		probe_slots.append({"room": int(room.id), "parent": node, "height": height, "size": Vector3(span.x - 0.2, height - 0.05, span.y - 0.2), "every_third": room.hall == room.id and room.hall >= 0 and int(room.id) % 3 == 0, "probe": null})
	extras(node, room)
	build_occluder(node)

## The slab the room stands on.
func floor_surface(node: Node3D, room: Dictionary) -> void:
	var span := FLOOR.size_of(room)
	box(node, Vector3(0, -0.15, 0), Vector3(span.x, 0.3, span.y), palette.floor_finish(room), true)

## The slab over it: plaster, or the service rooms' own.
func ceiling(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	box(node, Vector3(0, height + 0.1, 0), Vector3(span.x, 0.2, span.y), "ceiling_service" if room.type in palette.SERVICE_CEILINGS else "ceiling", true)

## Its four sides: open on to a merged cell, a wall with its doorway and
## switch, a bare one with the room's grille, or the lift wall; wall_art()
## on the long ones.
func walls(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	# The wall a lift's car is behind, in the lobbies that have one.
	var lift_back := FLOOR.lift_wall(room)
	var grilled := false
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		# The cell beside it on its planta's grid (none past the edge).
		var neighbor: int = FLOOR.beside(room, direction)
		var connected: bool = neighbor >= 0 and manifest.adjacency[room.id].has(neighbor)
		if connected and open_pairs.has(Vector2i(mini(room.id, neighbor), maxi(room.id, neighbor))):
			# 1 -x, 2 +x, 4 -z, 8 +z (surface.gdshaderinc room_edge()).
			var bit: int = {Vector2i(-1, 0): 1, Vector2i(1, 0): 2, Vector2i(0, -1): 4, Vector2i(0, 1): 8}[direction]
			batch_roots[node.get_instance_id()].a += bit
			continue
		var length: float = span.y if direction.x != 0 else span.x
		var boundary := Node3D.new()
		boundary.name = "Wall_%s_%s" % [direction.x, direction.y]
		boundary.position = Vector3(direction.x * span.x * 0.5, 0, direction.y * span.y * 0.5)
		boundary.rotation.y = PI / 2 if direction.x != 0 else 0.0
		node.add_child(boundary)
		# Local face pointing into this room; a neighbour may have another height.
		var inner: int = -(direction.x + direction.y)
		if direction == lift_back and not connected:
			# The cell's own wall, bare: the lobby sees the lift wall standing
			# in front of it, with the car between the two.
			wall_core(boundary, Vector3(0, height / 2, 0), Vector3(length, height, 0.18), inner)
			lift_wall(node, room, direction, length)
			continue
		# Where the doorway is along the wall, in the wall's own x: on a wall
		# between cells side by side in x (turned a quarter) that runs the
		# other way to the world's z (FLOOR.door_offset()).
		var door_at := 0.0
		if connected:
			door_at = FLOOR.door_offset(room, neighbor) * (-1.0 if direction.x != 0 else 1.0)
			for side in [-1, 1]:
				# From the jamb on that side to the end of the wall.
				# It stops JAMB_GAP short of the opening: ending on it, the
				# plaster and the dado stood a millimetre proud of the door's
				# wooden jamb and showed through it.
				var run: float = length * 0.5 - side * door_at - FLOOR.PORTAL * 0.5 - JAMB_GAP
				if run > 0.01: wall_run(boundary, door_at + side * (FLOOR.PORTAL * 0.5 + JAMB_GAP + run * 0.5), run, height, inner)
			# Jambs, head and casing come with the door (DOOR_FRAME, in build()).
			wall_core(boundary, Vector3(door_at, (height + 2.65) / 2, 0), Vector3(FLOOR.PORTAL + JAMB_GAP * 2.0, height - 2.65, 0.18), inner)
			cornice(boundary, door_at, FLOOR.PORTAL + JAMB_GAP * 2.0, height, inner, false)
			# The switch, a hand past the casing on the side with more wall,
			# and clear of a painting's lamps.
			var beside: float = FLOOR.PORTAL * 0.5 + 0.34
			var side_of: float = -1.0 if door_at > 0.0 else 1.0
			for way: float in [side_of, -side_of]:
				var at: float = door_at + way * beside
				if absf(at) > length * 0.5 - 0.3 or (length >= 9.0 and absf(absf(at) - 3.5) < 1.3): continue
				switch_plate(boundary, at, inner)
				break
		else:
			wall_run(boundary, 0.0, length, height, inner)
			# One grille to a room, in the middle of its first wall without a
			# door: between the two paintings where there are any.
			if not grilled and length >= 3.0:
				grilled = true
				grille(boundary, 0.0, inner)
		# The end of a corridor, three or four metres across, has no room for
		# a painting either side of its middle, nor for the lamps beside one.
		if length < 9.0: continue
		for side in [-1, 1]:
			# Nor on the side a doorway was moved to.
			if connected and absf(side * 3.5 - door_at) < PAINTING_CLEAR: continue
			# Nor behind a lift wall standing across the end of this one.
			if not lift_clear(room, direction, lift_back, side * 3.5): continue
			wall_art(boundary, room, side * 3.5, inner)

## What stands in it: the corner props, a domestic room's alcoves, the
## wardrobes, the corner posts, the ceiling fittings and the dressing.
func fittings(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	for prop in room.props:
		var furniture := Node3D.new()
		furniture.name = "Prop_%d_%s" % [prop.slot, prop.kind]
		furniture.transform = prop_transform(room, prop, palette)
		node.add_child(furniture)
		building_dark = dark_room(room)
		building_type = int(room.type)
		build_prop(furniture, prop.kind)
		building_dark = false
		building_type = -1
	if palette.domestic(room):
		# Domestic alcoves interrupt the square footprint while preserving portals.
		for side in [-1, 1]:
			for end in [-1, 1]:
				if room.get("layout", 0) == 1 and side > 0: continue
				if room.get("layout", 0) == 2 and end > 0: continue
				if room.get("layout", 0) == 3 and side != end: continue
				box(node, Vector3(side * 4.4, height / 2, end * 2.8), Vector3(3.2, height, 0.12), wall_material, true)
				blocker(Transform3D.IDENTITY, Vector3(side * 4.4, height / 2, end * 2.8), Vector2(3.2, height))
				plan_wall(node, Vector3(side * 2.8, 0, end * 2.8), Vector3(side * 6.0, 0, end * 2.8))
				partition_mouldings(node, Transform3D(Basis.IDENTITY, Vector3(side * 4.4, 0, end * 2.8)), 3.2, height)
				for z in [3.2, 5.6]:
					box(node, Vector3(side * 2.8, height / 2, end * z), Vector3(0.12, height, 0.8), wall_material, true)
					plan_wall(node, Vector3(side * 2.8, 0, end * z - 0.4), Vector3(side * 2.8, 0, end * z + 0.4))
					partition_mouldings(node, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(side * 2.8, 0, end * z)), 0.8, height)
				box(node, Vector3(side * 2.8, (height + 2.55) / 2, end * 4.4), Vector3(0.12, height - 2.55, 1.6), wall_material, true)
				partition_mouldings(node, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(side * 2.8, 0, end * 4.4)), 1.6, height, false)
	# Wardrobes only in room-like modules (see the palette's WARDROBES), against the walls.
	if room.type != palette.REFUGE:
		for corner in FLOOR.hiding_positions(room):
			var hide := preload("res://game/world/interactables/hiding_place.gd").new()
			hide.name = "Wardrobe_%d" % node.get_child_count()
			hide.position = corner
			hide.rotation.y = FLOOR.hiding_yaw(corner)
			hide.skin = hide_skin(room)
			hides.append(hide)
			# The wardrobe builds its own model, frame colliders and door leaves.
			node.add_child(hide)
	# Furniture along the free walls, things, clutter and decals (phase 4).
	corner_posts(node, room)
	ceiling_fittings(node, room)
	DRESSING.dress(self, node, room)

## Its ceiling lamp: the fixture and its one shadowed light, filed in
## lights (a room's lamp is lights[id]).
func room_lamp(node: Node3D, room: Dictionary) -> void:
	lamp_light(node, room, lamp_fixture(node, room))

## The room lamp's fixture (H6): builds what is seen of it and says what its
## light is: {color, energy, profile, position, specular, tube (a fluorescent
## the blackout and the drain treat as one), failing (the material of a tube
## that flickers, or "")}. A floor kind draws its own fixtures.
func lamp_fixture(node: Node3D, room: Dictionary) -> Dictionary:
	var height: float = room.height
	# Central sightlines remain open; booths sit against the perimeter.
	var lamp: String = palette.lamp_of(room)
	var service: bool = lamp == "batten"
	var light := {"tube": service, "failing": "", "specular": 0.45 if service else 0.6}
	var failing := service and vary(node.position, 3) < 0.35
	if service:
		# Fluorescent batten: cold, even, occasionally failing.
		var tube := "light"
		if failing:
			tube = "tube_%d" % flickers.size()
			materials[tube] = materials.light.duplicate()
			materials[tube].emission = Color("d8f0dc")
			light.failing = tube
		box(node, Vector3(0, height - 0.04, 0), Vector3(1.5, 0.08, 0.32), "metal")
		for z in [-0.08, 0.08]: box(node, Vector3(0, height - 0.11, z), Vector3(0.05, 1.38, 0.05), tube, false, "cylinder", Vector3(0, 0, PI / 2))
		light.color = LIGHTING.light_color(LIGHTING.FLUORESCENT, LIGHTING.TUBE_TINT)
		light.energy = 3.4 * LIGHTING.PROFILE_GAIN
		light.profile = LIGHTING.profile("tube")
		light.position = Vector3(0, height - 0.35, 0)
	elif lamp == "chandelier":
		# A chandelier, its light among its shades.
		var drop: float = CHANDELIER.get_aabb().size.y * CHANDELIER_SCALE
		var chandelier := MeshInstance3D.new()
		chandelier.name = "Chandelier"
		chandelier.mesh = CHANDELIER
		chandelier.transform = Transform3D(Basis(Vector3.UP, vary(node.position, 150) * TAU).scaled(Vector3.ONE * CHANDELIER_SCALE), Vector3(0, height - drop, 0))
		# It hangs round its own light: its shadow would be arms across every
		# wall, and the room's whole shadow redrawn for nothing.
		chandelier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chandelier.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if dark_room(room): switch_off(chandelier)
		else: lit_sconces.append(chandelier)
		node.add_child(chandelier)
		if not (room.type in palette.SERVICE_CEILINGS): place(node, MOULDINGS.rose(), Transform3D(Basis.IDENTITY, Vector3(0, height, 0)), false, "ceiling", true)
		light.color = LIGHTING.light_color(LIGHTING.INCANDESCENT)
		light.energy = 3.6 * LIGHTING.PROFILE_GAIN
		light.profile = LIGHTING.profile("chandelier")
		light.position = Vector3(0, height - drop + 0.26 * CHANDELIER_SCALE, 0)
	else:
		# Frosted dome in a brass ring: warm pool with darker corners.
		cylinder(node, Vector3(0, height - 0.03, 0), 0.26, 0.06, "gold")
		# A plaster rose round it (the kit's), where the ceiling is plaster.
		if not (room.type in palette.SERVICE_CEILINGS): place(node, MOULDINGS.rose(), Transform3D(Basis.IDENTITY, Vector3(0, height, 0)), false, "ceiling", true)
		box(node, Vector3(0, height - 0.13, 0), Vector3(0.46, 0.16, 0.46), "light_off" if dark_room(room) else "light", false, "cone", Vector3(PI, 0, 0))
		light.color = LIGHTING.light_color(LIGHTING.INCANDESCENT)
		light.energy = 3.6 * LIGHTING.PROFILE_GAIN
		light.profile = LIGHTING.profile("dome")
		light.position = Vector3(0, height - 0.45, 0)
	return light

## The room's one shadowed light, from what its fixture says (H6): the same
## for every floor kind, as the tools and the layers read lights[id].
func lamp_light(node: Node3D, room: Dictionary, spec: Dictionary) -> OmniLight3D:
	var span := FLOOR.size_of(room)
	var service: bool = spec.tube
	var light := OmniLight3D.new()
	light.light_color = spec.color
	light.light_energy = spec.energy
	light.set_meta("profile", spec.profile)
	light.position = spec.position
	light.omni_range = ROOM_LAYERS.lamp_range(span)
	light.omni_attenuation = 1.25
	light.light_size = LAMP_SIZE * preset.penumbra
	light.light_specular = spec.specular
	light.shadow_enabled = true
	# Small biases so thin shelves and trays still block light and glints.
	# Lower ones (0.01 and 0.25 were tried) cover walls and ceilings in
	# shadow acne, rippling bands: doors are sealed with geometry instead
	# (light_seal, jamb_seal).
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 0.6
	# The shape of its light: a photometric profile as a projector
	# (lighting.gd), which only works while the light casts shadows.
	light.light_projector = light.get_meta("profile")
	# Lamps light the volumetric fog only on presets with lamp_fog, where the
	# fog is short enough (14 m) for its cells not to straddle walls: at 48 m a
	# lit room's haze glowed in the dark room next door (apply_quality).
	light.light_volumetric_fog_energy = 0.0
	# Lights and shadows fade with distance instead of switching on abruptly
	# (lamp_fade, per preset). A light keeps its shadow until the light itself
	# is gone: a shadow that faded earlier left lamps shining through walls and
	# closed doors between that distance and the light's own fade.
	light.distance_fade_enabled = true
	set_fade(light, preset.lamp_fade[0], preset.lamp_fade[1])
	node.add_child(light)
	light.set_meta("room", int(room.id))
	lights.append(light)
	# Some rooms have their lamp out: only torches and the doorways light them.
	if dark_room(room):
		light.set_meta("off", true)
		light.visible = false
	if service: tubes.append({"light": light, "energy": light.light_energy})
	if not String(spec.failing).is_empty():
		flickers.append({"light": light, "energy": light.light_energy, "phase": vary(node.position, 9) * 50.0, "material": materials[spec.failing], "glow": materials.light.emission_energy_multiplier})
	return light

## What only some rooms have: the reception's red beacon and the refuge's
## exit signs. Both retouch the lamp room_lamp() has just made.
func extras(node: Node3D, room: Dictionary) -> void:
	var height: float = room.height
	# lights.back(), not lights[id]: the module gallery builds every room as id 0.
	var light: OmniLight3D = lights.back()
	if room.type == palette.RECEPTION:
		# Where the night started: a red emergency lamp blinking over the
		# reception, the one landmark to find the way back by.
		box(node, Vector3(0, height - 0.12, 0), Vector3(0.36, 0.12, 0.2), "metal")
		var beacon_glass := StandardMaterial3D.new()
		beacon_glass.albedo_color = Color(0.5, 0.02, 0.02)
		beacon_glass.emission_enabled = true
		beacon_glass.emission = Color(1.0, 0.08, 0.04)
		beacon_glass.emission_energy_multiplier = 4.0
		var lens := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = 0.11
		dome.height = 0.14
		dome.material = beacon_glass
		lens.mesh = dome
		lens.position = Vector3(0, height - 0.22, 0)
		node.add_child(lens)
		var beacon := OmniLight3D.new()
		beacon.name = "StartBeacon"
		beacon.position = Vector3(0, height - 0.45, 0)
		beacon.light_color = Color(1.0, 0.1, 0.06)
		beacon.light_energy = 3.2
		beacon.omni_range = 10.0
		# The usual warm ceiling light is kept low so the red reads from afar.
		light.light_energy *= 0.3
		beacon.shadow_enabled = true
		beacon.light_volumetric_fog_energy = 0.0
		node.add_child(beacon)
		beacons.append({"light": beacon, "material": beacon_glass, "energy": beacon.light_energy, "room": int(room.id)})
	if room.type == palette.REFUGE:
		exit_sign(node, Vector3(0, 2.25, -2.5), 0.0, height)
		exit_sign(node, Vector3(0, 2.45, 4.8), PI, height)
		light.light_color = Color("b8d4b6")

## Where a salon or a corridor turns a corner round a cell that is not part of
## it, each of the two walls of that cell is drawn by the room on its side and
## stops at the edge of its own cell: at the corner itself nobody drew
## anything, and it showed as a notch 9 cm deep with the ends of both dados
## bare and light coming through between them. The room at the elbow puts
## the corner in: plaster, the dado and its rails, and the cornice.
func corner_posts(node: Node3D, room: Dictionary) -> void:
	var span := FLOOR.size_of(room)
	var height: float = room.height
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var a: int = FLOOR.beside(room, Vector2i(sx, 0))
			var b: int = FLOOR.beside(room, Vector2i(0, sz))
			if a < 0 or b < 0 or not opens_on(int(room.id), a) or not opens_on(int(room.id), b): continue
			var d: int = FLOOR.beside(manifest.rooms[a], Vector2i(0, sz))
			# Both walls of the cell in the corner have to be there.
			if d < 0 or opens_on(a, d) or opens_on(b, d): continue
			var corner := Vector3(sx * span.x * 0.5, 0, sz * span.y * 0.5)
			var into := Vector3(-sx, 0, -sz)
			# Each piece reaches as far into the room as its wall's does.
			box(node, corner + into * 0.045 + Vector3(0, height * 0.5, 0), Vector3(0.09, height, 0.09), wall_material)
			box(node, corner + into * 0.0725 + Vector3(0, 0.48, 0), Vector3(0.145, 0.96, 0.145), "panel")
			box(node, corner + into * 0.08375 + Vector3(0, 0.98, 0), Vector3(0.1675, 0.05, 0.1675), "trim", false, "plain")
			box(node, corner + into * 0.085 + Vector3(0, 0.07, 0), Vector3(0.17, 0.14, 0.17), "trim", false, "plain")
			box(node, corner + into * 0.075 + Vector3(0, height - 0.05, 0), Vector3(0.15, 0.1, 0.15), "trim", false, "plain")
			box(node, corner + into * 0.0575 + Vector3(0, height - 0.13, 0), Vector3(0.115, 0.06, 0.115), "trim", false, "plain")
			# The kit's: each moulding carried round the corner, and the dado
			# out to its frames' face.
			moulding_corner(node, "rail", corner, 0.96, sx, sz)
			moulding_corner(node, "skirting", corner, 0.0, sx, sz)
			moulding_corner(node, "cornice", corner, height, sx, sz)
			var frame: float = MOULDINGS.PANEL_FRAME
			box(node, corner + into * frame * 0.5 + Vector3(0, (MOULDINGS.PANEL_HEAD + MOULDINGS.PANEL_FOOT) * 0.5, 0), Vector3(frame, MOULDINGS.PANEL_HEAD - MOULDINGS.PANEL_FOOT, frame), "panel_field", false, "detail")

## Whether two cells side by side run into each other with no wall between.
func opens_on(a: int, b: int) -> bool:
	return manifest.adjacency[a].has(b) and open_pairs.has(Vector2i(mini(a, b), maxi(a, b)))

## Framed hotel art on a room's face of a wall (inner), `at` along it; vary()
## picks each canvas, by its position and the floor. It used to hang on local
## -Z, which on west and north walls is the next room's face, on top of that
## room's own prints (two frames z-fighting, this room's wall bare). Public
## spaces have a pair of cloth-shaded wall lamps beside each print.
func wall_art(boundary: Node3D, room: Dictionary, at: float, inner: int) -> void:
	hang_painting(boundary, Vector3(at, 2.02, 0), inner, int(room.variant) % 2 == 0)
	if not (room.type in palette.SCONCE_ROOMS): return
	for flank in [-1, 1]:
		var sconce := MeshInstance3D.new()
		sconce.mesh = WALL_LAMP
		# In a dark room its shade and bulb are out: an emissive shade lit the
		# walls round it by bounce light.
		if dark_room(room): switch_off(sconce)
		else: lit_sconces.append(sconce)
		sconce.position = Vector3(at + flank * 0.98, 1.6, inner * 0.09)
		# The model faces +Z: turned to face into this room.
		sconce.rotation.y = PI if inner < 0 else 0.0
		boundary.add_child(sconce)
		if not dark_room(room): sconce_light(boundary, sconce)

## Whether the print and lamps `at` along a side wall of a lobby stay clear of
## its lift wall (FLOOR.LIFT_DEPTH in from the end of it), with 10 cm to spare.
func lift_clear(room: Dictionary, direction: Vector2i, lift_back: Vector2i, at: float) -> bool:
	if lift_back == Vector2i.ZERO or direction.x * lift_back.x + direction.y * lift_back.y != 0: return true
	# A west or east wall is turned a quarter: its x runs along the world's -z.
	var along: float = -at * lift_back.y if direction.x != 0 else at * lift_back.x
	var half: float = (FLOOR.size_of(room).x if lift_back.x != 0 else FLOOR.size_of(room).y) * 0.5
	return along + 1.2 <= half - FLOOR.LIFT_DEPTH - 0.1

## The door of the last stage: in the wall the last refuge shares with the
## landing, shut and locked until its code is read in. Behind it are the back
## stairs -- a room of the floor that nothing else opens on to -- and stepping
## into them is leaving the floor. It is built after every other door so the
## gates stay in the order of their stages.
func build_exit_door(data: Dictionary) -> void:
	var gates_list: Array = data.get("gates", [])
	if gates_list.is_empty(): return
	var last: Dictionary = gates_list[gates_list.size() - 1]
	var room: Dictionary = data.rooms[int(last.room)]
	var out: Array = last.get("out", [1, 0])
	var direction := Vector2i(int(out[0]), int(out[1]))
	var span := FLOOR.size_of(room)
	var away := Vector3(direction.x, 0, direction.y)
	var centre: Vector3 = FLOOR.position_of(room) + away * (Vector2(span.x, span.y).dot(Vector2(absf(away.x), absf(away.z))) * 0.5)
	# The cell behind that door is the lift lobby, and its doorway is the wall
	# the two of them share.
	var beyond := int(last.get("beyond", -1))
	var other: Dictionary = data.rooms[beyond] if beyond >= 0 else room
	var yaw := PI / 2 if direction.x != 0 else 0.0
	var turn: float = DOOR.OPEN_TURN
	if beyond >= 0:
		centre = FLOOR.portal_between(room, data.rooms[beyond])
		# Hung like any other door (build()): it swings into the lobby.
		var a: Dictionary = data.rooms[mini(int(room.id), beyond)]
		var b: Dictionary = data.rooms[maxi(int(room.id), beyond)]
		var spec: Dictionary = data.get("doors", {}).get("%d:%d" % [int(a.id), int(b.id)], {})
		yaw = FLOOR.leaf_yaw(a, b, spec)
		turn = DOOR.OPEN_TURN * FLOOR.leaf_turn(a, b, spec, centre, yaw)
	var door = DOOR.new()
	door.name = "ExitDoor"
	door.collision_layer = 8
	door.collision_mask = 4
	var half := FLOOR.LEAF_WIDTH * 0.5
	door.position = centre + Basis(Vector3.UP, yaw) * Vector3(-half, 0, 0)
	door.rotation.y = yaw
	door.closed_rotation = yaw
	door.open_turn = turn
	door.doorway = centre
	door.locked = true
	door.gate_stage = int(last.stage)
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	leaf.mesh = leaf_mesh(room, other)
	door.add_child(leaf)
	door.add_child(light_seal(leaf.mesh))
	var shape := CollisionShape3D.new()
	# By this name the door finds it to tell whether somebody stands in the
	# leaf (hotel_door.holds_somebody); unnamed, it never found it and went
	# solid on top of whoever crowded the last door.
	shape.name = "CollisionShape3D"
	var body := BoxShape3D.new()
	body.size = Vector3(FLOOR.LEAF_WIDTH, OPENING_HIGH, 0.12)
	shape.shape = body
	shape.position = Vector3(half, OPENING_HIGH * 0.5, 0)
	door.add_child(shape)
	add_child(door)
	var casing := MeshInstance3D.new()
	casing.name = "ExitCasing"
	casing.mesh = frame_mesh(room, other)
	casing.position = centre
	casing.rotation.y = yaw
	add_child(casing)
	var stop := jamb_seal(centre, yaw, casing.mesh)
	add_child(stop)
	# Same as every other door: its casing and stop are shown with it.
	door_fixtures.append([casing, stop])
	doors.append(door)
	gates.append(door)

## The cars themselves: one waiting in the lobby behind each refuge's door,
## and one in the cell its lift arrives at. The car is "Elevator with
## Animation LOWPOLY" (EFX, CC BY), baked by tools/props/build_elevator.gd into
## its pieces at 0.8 of the model's size, every button of its panel included.
## It stands behind a wall of the hotel's own built across the lobby
## (lift_wall()), with only its doorway, its call buttons and its display in
## that wall: not a box standing in the room.
const LIFT_CAR := preload("res://assets/props/elevator/lift_car.res")
const LIFT_LEAVES := [preload("res://assets/props/elevator/lift_door_a.res"), preload("res://assets/props/elevator/lift_door_b.res")]
const LIFT_CALL := preload("res://assets/props/elevator/lift_call.res")
const LIFT_SCREEN := preload("res://assets/props/elevator/lift_screen.res")
## In the car's space (the middle of its doorway on its floor, the outer face
## of its front at z = 0, the car towards -Z), as the baking prints them: the
## inside, and the doorway (wide, high).
const CAR_INSIDE := AABB(Vector3(-2.318, 0.0, -2.035), Vector3(3.211, 2.415, 1.861))
const CAR_OPENING := Vector2(1.532, 2.23)
## How far each leaf slides open, both into the front wall on the -X side, the
## far one twice as far. The model's own animation stops them with a third of
## the doorway still covered.
const LEAF_TRAVEL := [-0.8, -1.56]
## The lobby's wall stands this much proud of the car's front, and keeps
## LIFT_RIM clear of its doorway all round: a thin edge of the car's steel
## shows between the plaster and the doors, as on the model. Its casing
## (wide, deep) is the hotel's dark wood, like every door's.
const LIFT_PROUD := 0.006
const LIFT_RIM := 0.02
const LIFT_CASING := Vector2(0.09, 0.085)
## The call buttons beside the doorway, clear of the casing, and the height of
## the display over it.
const CALL_AT := Vector2(-1.12, 1.21)
const SCREEN_AT := 2.5
## Where the display of the panel inside the car is (its glass, facing in).
const PANEL_SCREEN := Vector3(-1.4975, 2.03, -0.192)
## The floor both displays show.
const CAR_DISPLAY := "1"
## Each lift's car, its space in the world (in_car()).
var car_frames: Array = []
func build_lifts(data: Dictionary) -> void:
	for gate in data.get("gates", []):
		var out: Array = gate.get("out", [1, 0])
		var lobby := int(gate.get("beyond", -1))
		# In the lobby the car stands behind its far wall, facing the door
		# the refuge is behind.
		lifts.append(build_car(data.rooms[lobby], Vector2i(-int(out[0]), -int(out[1]))) if lobby >= 0 else Vector3.ZERO)
		car_frames.append(car_frame if lobby >= 0 else Transform3D())
		depart_leaves.append(car_leaves.duplicate() if lobby >= 0 else [])
		var arrive := int(gate.get("arrive", -1))
		if arrive < 0:
			arrivals.append(Vector3.ZERO)
			arrive_leaves.append([])
			arrival_cars.append(Vector3.ZERO)
			arrival_facing.append(Vector3.ZERO)
			continue
		# The lobby it arrives at is the one straight under this one, and the
		# car stands behind the same wall: it goes down, it does not move
		# across. That wall has no door (map_generator.gd).
		var facing := Vector2i(-int(out[0]), -int(out[1]))
		var car := build_car(data.rooms[arrive], facing)
		arrive_leaves.append(car_leaves.duplicate())
		arrival_cars.append(car)
		arrival_facing.append(Vector3(facing.x, 0, facing.y))
		# People are put down in front of it, not inside it.
		arrivals.append(car + Vector3(facing.x, 0, facing.y) * 1.8)

## The leaves and the space of the car last built, for build_lifts to file.
var car_leaves: Array = []
var car_frame := Transform3D()

## Whether a point is inside the car of that lift, or within `slack` of its
## inside (out through the doorway, then). It used to be a metre and a half
## from the car's middle; the model's car is 3.2 by 1.9 inside, its doorway
## to one side.
func in_car(index: int, point: Vector3, slack := 0.0) -> bool:
	if index < 0 or index >= car_frames.size() or lifts[index] == Vector3.ZERO: return false
	var local: Vector3 = (car_frames[index] as Transform3D).affine_inverse() * point
	var inside := CAR_INSIDE.grow(slack)
	return local.x >= inside.position.x and local.x <= inside.end.x and local.z >= inside.position.z and local.z <= inside.end.z and local.y > -1.0 and local.y < CAR_INSIDE.end.y + 0.5

## A car behind the lift wall of the cell given (lift_wall(), built with the
## room), its doorway in the middle of that wall; returns the middle of its
## floor in world space.
func build_car(room: Dictionary, facing: Vector2i) -> Vector3:
	var node: Node3D = room_nodes[int(room.id)]
	var span := FLOOR.size_of(room)
	var back := Vector3(-facing.x, 0, -facing.y)
	var depth: float = span.y if absf(back.z) > 0.5 else span.x
	var across: float = (span.x if absf(back.z) > 0.5 else span.y) * 0.5
	var car := Node3D.new()
	car.name = "Lift"
	# A room of its own for the light (assign_layers()).
	car.set_meta("car", true)
	# Its front just behind the lift wall's face, its floor a few millimetres
	# over the lobby's (the two were one plane, and fought).
	car.position = back * (depth * 0.5 - FLOOR.LIFT_DEPTH + LIFT_PROUD) + Vector3(0, 0.006, 0)
	car.rotation.y = atan2(-back.x, -back.z)
	node.add_child(car)
	car_frame = node.transform * car.transform
	car_leaves = car_body(car, room)
	# What stops a body: the lift wall has the doorway, and behind it are the
	# car's sides, back and ceiling. The rest of the space between the lift
	# wall and the cell's own is filled, so nobody is ever in it and the
	# navigation finds no floor there.
	var inside := CAR_INSIDE
	var reach: float = FLOOR.LIFT_DEPTH - LIFT_PROUD
	var height: float = room.height
	for side in [-1.0, 1.0]:
		var from: float = inside.end.x if side > 0.0 else -across
		var to: float = across if side > 0.0 else inside.position.x
		box(car, Vector3((from + to) * 0.5, height * 0.5, -reach * 0.5), Vector3(to - from, height, reach), "", true)
	box(car, Vector3(inside.get_center().x, height * 0.5, (inside.position.z - reach) * 0.5), Vector3(inside.size.x, height, inside.position.z + reach), "", true)
	box(car, Vector3(inside.get_center().x, (inside.end.y + height) * 0.5, inside.position.z * 0.5), Vector3(inside.size.x, height - inside.end.y, -inside.position.z), "", true)
	# On the plan the car is a room of its own behind its doorway.
	var corners := [Vector3(inside.position.x, 0, inside.end.z), Vector3(inside.position.x, 0, inside.position.z), Vector3(inside.end.x, 0, inside.position.z), Vector3(inside.end.x, 0, inside.end.z)]
	for i in 3: plan_wall(node, car.transform * corners[i], car.transform * corners[i + 1])
	# Its light, which is the only one it has and never goes out with the rest.
	car.add_child(box_light(Vector3(inside.get_center().x, inside.end.y - 0.25, inside.get_center().z)))
	return node.position + car.position + car.basis * Vector3(inside.get_center().x, 0, inside.get_center().z) - Vector3(0, 0.006, 0)

## What is seen of the car (H7): its model, its leaves, the call buttons and
## the floor display with their digits; returns the leaves as car_leaves
## keeps them ({node, shut, open}). A floor kind's car looks otherwise.
func car_body(car: Node3D, _room: Dictionary) -> Array:
	var body := MeshInstance3D.new()
	body.name = "Car"
	body.mesh = LIFT_CAR
	car.add_child(body)
	var leaves: Array = []
	for k in LIFT_LEAVES.size():
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf"
		leaf.mesh = LIFT_LEAVES[k]
		# Seen from the lobby and from inside: lit by both.
		leaf.set_meta("lobby_side", true)
		car.add_child(leaf)
		leaves.append({"node": leaf, "shut": 0.0, "open": LEAF_TRAVEL[k]})
	var call := MeshInstance3D.new()
	call.name = "CallButtons"
	call.mesh = LIFT_CALL
	call.position = Vector3(CALL_AT.x, CALL_AT.y, LIFT_PROUD - 0.001)
	call.set_meta("lobby_side", true)
	car.add_child(call)
	var screen := MeshInstance3D.new()
	screen.name = "Display"
	screen.mesh = LIFT_SCREEN
	screen.position = Vector3(0, SCREEN_AT, LIFT_PROUD - 0.001)
	screen.set_meta("lobby_side", true)
	car.add_child(screen)
	car_digits(screen, Vector3(0, 0, 0.027), 0.0)
	car_digits(car, PANEL_SCREEN - Vector3(0, 0, 0.003), PI)
	return leaves

## The lobby's wall with the lift in it: the width of the cell, FLOOR.LIFT_DEPTH
## in from the wall the car backs on to, finished like every other wall
## (wall_run(): plaster, the panelled dado and its rails, the cornice), with
## the doorway cut in its middle and cased in wood, and its paintings and
## lamps either side. The cell's own wall is still there behind it, bare.
func lift_wall(node: Node3D, room: Dictionary, direction: Vector2i, length: float) -> void:
	var height: float = room.height
	var span := FLOOR.size_of(room)
	var half: float = (span.x if direction.x != 0 else span.y) * 0.5
	var boundary := Node3D.new()
	boundary.name = "LiftWall"
	var reach: float = half - FLOOR.LIFT_DEPTH + 0.09
	boundary.position = Vector3(direction.x * reach, 0, direction.y * reach)
	boundary.rotation.y = PI / 2 if direction.x != 0 else 0.0
	node.add_child(boundary)
	var inner: int = -(direction.x + direction.y)
	var gap: float = CAR_OPENING.x * 0.5 + LIFT_RIM
	var top: float = CAR_OPENING.y + LIFT_RIM
	var run: float = length * 0.5 - gap
	for side in [-1, 1]: wall_run(boundary, side * (gap + run * 0.5), run, height, inner)
	wall_core(boundary, Vector3(0, (height + top) * 0.5, 0), Vector3(gap * 2.0, height - top, 0.18), inner)
	cornice(boundary, 0.0, gap * 2.0, height, inner)
	# The casing stands out past the dado and its rails, which stop against it.
	var out: float = inner * (0.09 + LIFT_CASING.y * 0.5)
	for side in [-1, 1]:
		box(boundary, Vector3(side * (gap + LIFT_CASING.x * 0.5), (top + LIFT_CASING.x) * 0.5, out), Vector3(LIFT_CASING.x, top + LIFT_CASING.x, LIFT_CASING.y), "trim")
	box(boundary, Vector3(0, top + LIFT_CASING.x * 0.5, out), Vector3(gap * 2.0, LIFT_CASING.x, LIFT_CASING.y), "trim")
	for side in [-1, 1]: wall_art(boundary, room, side * 3.5, inner)

## The car's floor number in the violet light of the model's displays, over
## the glass of one of them.
func car_digits(parent: Node3D, at: Vector3, yaw: float) -> void:
	var digits := Label3D.new()
	digits.name = "Digits"
	digits.text = CAR_DISPLAY
	digits.font_size = 64
	digits.pixel_size = 0.0016
	digits.modulate = Color(0.62, 0.55, 1.0)
	digits.shaded = false
	digits.double_sided = false
	digits.position = at
	digits.rotation.y = yaw
	parent.add_child(digits)

## The lamp in a car's ceiling, behind the model's own strips of light. It
## stays on whatever the floor is doing.
func box_light(at: Vector3) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = "CarLight"
	lamp.position = at
	lamp.light_color = Color(0.96, 0.94, 0.86)
	lamp.light_energy = 2.4
	lamp.omni_range = 5.5
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.light_volumetric_fog_energy = 0.0
	car_lamps.append(lamp)
	return lamp

## The refuge's sign: a sheet of clear acrylic lit from the diodes buried in
## its top edge, engraved SALIDA with an arrow pointing down at the room the
## floor is left from, in an aluminium channel hung from the ceiling on a
## stem. The lettering is drawn by the light the sheet guides
## (shaders/exit_panel.gdshader); the sign also throws its own green light,
## with a shadow, like every other visible lamp in the hotel.
const EXIT_PANEL := preload("res://game/presentation/shaders/exit_panel.gdshader")
const EXIT_ENGRAVING := preload("res://assets/props/exit_sign/engraving.png")
const PANEL_SIZE := Vector2(0.62, 0.31)

## `front` is what the sheet is engraved with, read from the side it faces;
## `back`, when given, what its other face says (read from there).
func exit_sign(node: Node3D, pos: Vector3, yaw: float, ceiling_y: float, front: Texture2D = EXIT_ENGRAVING, back: Texture2D = null, size := PANEL_SIZE) -> void:
	var board := Node3D.new()
	board.name = "ExitSign"
	board.position = pos
	board.rotation.y = yaw
	node.add_child(board)
	var top := size.y * 0.5
	# The channel the diodes sit in, its end clamps, and the stem and canopy
	# that hang the whole thing from the ceiling.
	box(board, Vector3(0, top + 0.03, 0), Vector3(size.x + 0.06, 0.055, 0.07), "metal")
	box(board, Vector3(0, top + 0.058, 0), Vector3(size.x + 0.062, 0.006, 0.072), "black")
	for side in [-1.0, 1.0]:
		box(board, Vector3(side * (size.x * 0.5 - 0.012), top - 0.022, 0), Vector3(0.05, 0.06, 0.034), "black")
	var drop := ceiling_y - pos.y - top - 0.06
	box(board, Vector3(0, top + 0.06 + drop * 0.5, 0), Vector3(0.016, drop, 0.016), "metal", false, "cylinder")
	box(board, Vector3(0, ceiling_y - 0.01, 0), Vector3(0.1, 0.02, 0.1), "metal")
	var glass := ShaderMaterial.new()
	glass.shader = EXIT_PANEL
	glass.set_shader_parameter("engraving", front)
	if back != null:
		glass.set_shader_parameter("two_faced", true)
		glass.set_shader_parameter("engraving_back", back)
	var sheet := MeshInstance3D.new()
	sheet.name = "Panel"
	var quad := QuadMesh.new()
	quad.size = size
	sheet.mesh = quad
	sheet.material_override = glass
	exit_panels.append(glass)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	board.add_child(sheet)
	# The light it spills: green, close, and with a shadow, so it stays in
	# this room like every other lamp (docs/REALISM.md, the bounce leak).
	var lamp := OmniLight3D.new()
	lamp.name = "ExitGlow"
	lamp.position = Vector3(0, 0.02, 0)
	lamp.light_color = Color(0.25, 1.0, 0.45)
	lamp.light_energy = 0.55
	lamp.omni_range = 2.8
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.light_size = PRACTICAL_SIZE
	lamp.light_specular = 0.3
	# No bounce: a sign hangs in the doorway's own volume as well, and the
	# rebuilt bounce would carry its green into the room next door.
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
	lamp.light_volumetric_fog_energy = 0.12
	lamp.distance_fade_enabled = true
	set_fade(lamp, EXIT_REACH - 4.0, 3.0)
	board.add_child(lamp)
	exit_lamps.append(lamp)

## The corridors' way-out signs (exit_route_signs.gd): the same lit acrylic
## as the refuge's, hung across the way most people come by, a figure running
## out of a door and an arrow on each face -- ahead, left, right or back, for
## whoever reads that face. A metre off the middle of the cell along the way
## it faces, clear of the ceiling lamp, and well over everybody's head:
## at 2.4 m, like the refuge's, it hung at the height of the players' eyes.
const ROUTE_SIGN := preload("res://game/world/generation/exit_route_signs.gd")
const WAY_ENGRAVINGS := [
	preload("res://assets/props/exit_sign/way_ahead.png"),
	preload("res://assets/props/exit_sign/way_left.png"),
	preload("res://assets/props/exit_sign/way_right.png"),
	preload("res://assets/props/exit_sign/way_back.png"),
]
const ROUTE_SIGN_OFFSET := 1.0
## A third bigger than the refuge's: it is read from down the corridor.
const ROUTE_PANEL := PANEL_SIZE * 1.35
const ROUTE_SIGN_HEIGHT := 2.65
## Where each way-out sign hangs: {room, position (world), normal, front, back}.
var route_signs: Array = []

func route_sign(sign: Dictionary) -> void:
	var room: Dictionary = manifest.rooms[int(sign.room)]
	var node: Node3D = room_nodes[int(sign.room)]
	var normal := Vector3(float(sign.normal.x), 0.0, float(sign.normal.y))
	var span := FLOOR.size_of(room)
	var reach: float = (span.x if sign.normal.x != 0 else span.y) * 0.5 - 0.45
	var height: float = float(room.height)
	var pos := normal * clampf(ROUTE_SIGN_OFFSET, 0.0, maxf(reach, 0.0)) + Vector3(0, minf(ROUTE_SIGN_HEIGHT, height - 0.45), 0)
	# The sheet's front faces +Z of its own: turned to face along the normal.
	exit_sign(node, pos, atan2(normal.x, normal.z), height, WAY_ENGRAVINGS[int(sign.front)], WAY_ENGRAVINGS[int(sign.back)], ROUTE_PANEL)
	var placed := sign.duplicate()
	placed["position"] = node.position + pos
	route_signs.append(placed)

# One straight wall segment centred at x along the boundary: plaster core,
# panelled wainscot, chair rail and skirting on both faces; cornice inside only.
## Furniture socket in room space: corners, set further in and smaller in
## domestic rooms, turned by the recipe.
## A static: who calls it without a palette gets the hotel's.
static func prop_transform(room: Dictionary, prop: Dictionary, room_palette: GDScript = null) -> Transform3D:
	var rules: GDScript = room_palette if room_palette != null else FLOOR.palette({})
	var domestic: bool = rules.domestic(room)
	var corner := 4.35 if domestic else 3.95
	var basis := Basis(Vector3.UP, prop.rotation * PI / 2).scaled(Vector3.ONE * (0.85 if domestic else 1.0))
	var at := Vector3(-corner if prop.slot % 2 == 0 else corner, 0, -corner if prop.slot < 2 else corner)
	# A floor that writes its corner sockets (room.sockets, the offices) has
	# already pulled them clear of a lift (H8); the hotel's rooms have none.
	if room.has("sockets"): return Transform3D(basis, Vector3(float(room.sockets[prop.slot][0]), 0, float(room.sockets[prop.slot][1])))
	# In a lobby with a lift the two corners at its end are in front of the
	# lift wall, not behind it (FLOOR.LIFT_DEPTH).
	var lift := FLOOR.lift_wall(room)
	if lift != Vector2i.ZERO:
		var axis := Vector3(lift.x, 0, lift.y)
		var most: float = FLOOR.size_of(room).dot(Vector2(absf(lift.x), absf(lift.y))) * 0.5 - FLOOR.LIFT_DEPTH - 0.9
		var along := at.dot(axis)
		if along > most: at -= axis * (along - most)
	return Transform3D(basis, at)

func wall_run(boundary: Node3D, x: float, length: float, height: float, inner: int) -> void:
	wall_core(boundary, Vector3(x, height / 2, 0), Vector3(length, height, 0.18), inner)
	var room_node := boundary.get_parent() as Node3D
	plan_wall(room_node, boundary.transform * Vector3(x - length * 0.5, 0, 0), boundary.transform * Vector3(x + length * 0.5, 0, 0))
	for face in ([-1, 1] if full_walls else [inner]):
		box(boundary, Vector3(x, 0.48, face * 0.11), Vector3(length, 0.96, 0.07), "panel")
		box(boundary, Vector3(x, 0.98, face * 0.15), Vector3(length, 0.05, 0.035), "trim", false, "plain")
		box(boundary, Vector3(x, 0.07, face * 0.155), Vector3(length, 0.14, 0.03), "trim", false, "plain")
		moulding(boundary, "rail", x, length, 0.96, face)
		moulding(boundary, "skirting", x, length, 0.0, face)
		dado_panels(boundary, x, length, face)
		# A socket in the skirting of the longer stretches, a third along.
		if length >= 4.0 and vary(boundary.position + Vector3(x, 0, 0), 143) < 0.55: socket(boundary, x + length * (0.17 if vary(boundary.position + Vector3(x, 0, 0), 144) < 0.5 else -0.17), face)
	cornice(boundary, x, length, height, inner)

## A wall's cornice over a stretch of it: the two plain steps, and the kit's.
## (Over a doorway only the upper step: the casing reaches up to the lower.)
func cornice(boundary: Node3D, x: float, length: float, height: float, inner: int, both := true) -> void:
	box(boundary, Vector3(x, height - 0.05, inner * 0.12), Vector3(length, 0.1, 0.06), "trim", false, "plain")
	if both: box(boundary, Vector3(x, height - 0.13, inner * 0.1), Vector3(length, 0.06, 0.03), "trim", false, "plain")
	moulding(boundary, "cornice", x, length, height, inner)

## The floor as a plan (floor_map.gd): every stretch of wall that stands on
## the floor -- the walls between cells, with their doorways left out, and the
## plaster partitions of the rooms' alcoves -- as [a, b, planta], in the plan
## (world x, z). A wall two rooms share is built twice, once from each side,
## and kept once.
var plan_walls: Array = []
var plan_seen := {}

func plan_wall(room_node: Node3D, from: Vector3, to: Vector3) -> void:
	var a := Vector2(room_node.position.x + from.x, room_node.position.z + from.z)
	var b := Vector2(room_node.position.x + to.x, room_node.position.z + to.z)
	if a.distance_to(b) < 0.05: return
	var planta := FLOOR.planta_of(room_node.position.y)
	var ends := [Vector2i(roundi(a.x * 10.0), roundi(a.y * 10.0)), Vector2i(roundi(b.x * 10.0), roundi(b.y * 10.0))]
	ends.sort()
	var key := "%d:%s:%s" % [planta, ends[0], ends[1]]
	if plan_seen.has(key): return
	plan_seen[key] = true
	plan_walls.append([a, b, planta])

## Occlusion culling: every wall of a room is also a quad of an occluder, so
## rooms and furniture hidden behind walls are not drawn by the camera. It
## never touches shadows (Godot does not occlusion-cull shadow passes), so
## light stays sealed exactly as before. Doors are left out: they move, and an
## open door must show the room behind it. Quads sit inside the wall's own
## drawn half and are 3 cm short of every edge, so nothing visible is ever
## behind them. lockers collects them while a room is built.
const BLOCKER_INSET := 0.03
var blockers: Array = []

## A vertical quad of size (width along local X, height along Y) centred at
## pos in the frame rame (a wall boundary, or the room itself).
func blocker(frame: Transform3D, pos: Vector3, size: Vector2) -> void:
	var half := Vector2(size.x * 0.5 - BLOCKER_INSET, size.y * 0.5 - BLOCKER_INSET)
	if half.x <= 0.0 or half.y <= 0.0: return
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		blockers.append(frame * (pos + Vector3(corner.x * half.x, corner.y * half.y, 0)))

## The room's occluder, from the quads its walls left in lockers.
## The stage whose gate this pair of rooms holds, or 0 for a normal door.
static func gate_stage(data: Dictionary, a: int, b: int) -> int:
	for gate in data.get("gates", []):
		var beyond := int(gate.get("beyond", -1))
		if beyond < 0: continue
		if (int(gate.room) == a and beyond == b) or (int(gate.room) == b and beyond == a): return int(gate.stage)
	return 0

## Closing a stage opens its gate for good; every machine works it out from the
## stage itself, which is already replicated, so no door message is needed.
func open_gates(stage: int, ready: bool) -> void:
	for door in gates:
		if not is_instance_valid(door) or not door.locked: continue
		# A gate only ever opens: past stages are already through, and the one
		# in hand gives way as soon as its condition is met. Once open it stays
		# open, even if somebody steps out of the refuge again.
		if door.gate_stage > stage or (door.gate_stage == stage and not ready): continue
		door.locked = false
		if not door.opened and not door.moving: door.set_state(true)

## A stage given back whole after a collapse: its door shut and locked again,
## until its condition is met again. Only a restart does this.
func relock_gate(stage: int) -> void:
	for door in gates:
		if not is_instance_valid(door) or door.gate_stage != stage or door.locked: continue
		if door.opened or door.moving: door.set_state(false)
		door.locked = true

func build_occluder(node: Node3D) -> void:
	if full_walls or blockers.is_empty(): return
	var indices := PackedInt32Array()
	for quad in blockers.size() / 4:
		var first := quad * 4
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var shape := ArrayOccluder3D.new()
	shape.set_arrays(PackedVector3Array(blockers), indices)
	var occluder := OccluderInstance3D.new()
	occluder.name = "Occluder"
	occluder.occluder = shape
	node.add_child(occluder)
	blockers.clear()

## Plaster core of a wall along its boundary. The collider is the whole 18 cm,
## as always (walking, navigation, hearing and the creature's sight are tuned
## to it). What is drawn is only this room's half, and wall_run() panels only
## this room's face: the room on the other side draws its own, so a shared
## wall is no longer drawn twice. Together the two halves are the old wall,
## in the camera and in every shadow.
func wall_core(boundary: Node3D, pos: Vector3, size: Vector3, inner: int) -> void:
	box(boundary, pos, size, "", true)
	blocker(boundary.transform, pos + Vector3(0, 0, inner * size.z * 0.25), Vector2(size.x, size.y))
	if full_walls: box(boundary, pos, size, wall_material)
	else: box(boundary, pos + Vector3(0, 0, inner * size.z * 0.25), Vector3(size.x, size.y, size.z * 0.5), wall_material)

## A wall lamp that really lights its wall (preset sconce_lights): a cone up
## and one down out of the shade, nothing behind it (lighting.gd "sconce").
## Like every lamp it casts shadows, which the profile needs anyway; without
## shadows (the Sombras switch) it stays off rather than shine through the
## wall.
func sconce_light(boundary: Node3D, sconce: MeshInstance3D) -> void:
	var lamp := OmniLight3D.new()
	var facing := Basis(Vector3.UP, sconce.rotation.y)
	lamp.transform = Transform3D(facing, sconce.position + facing.z * 0.16 + Vector3(0, 0.22, 0))
	lamp.light_color = LIGHTING.light_color(2600.0)
	lamp.light_energy = SCONCE_ENERGY
	lamp.omni_range = 3.4
	lamp.omni_attenuation = 1.6
	lamp.light_size = SCONCE_SIZE * preset.penumbra
	lamp.light_specular = 0.3
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.02
	lamp.shadow_normal_bias = 0.05
	lamp.light_volumetric_fog_energy = 0.0
	lamp.light_projector = LIGHTING.profile("sconce")
	# Out of the bounce light: a wall lamp sits 25 cm from the wall, and the
	# next room's volume (bounce_light.gd) took its light in through a half
	# wall thinner than one of its voxels, lighting the far face yellow. And
	# only the nearest twelve are lit: in the bounce, one going out took its
	# glow from its own volume alone, and the corridor came out lighter on
	# one side of a cell's edge than on the other. BAKE_DYNAMIC (Godot's
	# default) is what puts a light *in* a VoxelGI; disabled keeps it out.
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
	lamp.distance_fade_enabled = true
	set_fade(lamp, SCONCE_REACH - 8.0, 6.0)
	# Its own room's and no other's, casting or not (kept_in()). It hangs
	# 16 cm off its wall and its shadow is a soft one, whose penumbra is
	# worked out from how near the lamp whatever blocks it is: with the wall
	# that near, its light came out on the floor of the room behind -- a
	# streak along the wall, plain on the tiles of a bathroom or a service
	# room. Measured (tools/dev/leak_who.gd --behind, seed 81): that floor
	# read 0.64 with the lamp lit and 0.26 with it out; 0.26 as well with the
	# lamp a point or its shadow not blurred, and neither bias, turn nor
	# profile changed it. So the layers keep it in, as they keep a lamp with
	# no shadow at all.
	lamp.set_meta("own_room", true)
	lamp.visible = false
	boundary.add_child(lamp)
	sconce_lights.append(lamp)

## The layer of the room (or the lift's car) a point is in; 0 outside them all.
func layer_at(point: Vector3) -> int:
	if room_layers.is_empty(): return 0
	var room := FLOOR.room_at(manifest.rooms, point)
	if room.is_empty(): return 0
	var id := int(room.id)
	if room_layers.cars.has(id) and ROOM_LAYERS.car_rect(room).has_point(Vector2(point.x, point.z)): return room_layers.cars[id]
	return room_layers.layer[id]

## What a lamp standing at a point may light: its room's layer and those of
## the cells the room is open to (a car's lamp, the car alone).
func glow_at(point: Vector3) -> int:
	if room_layers.is_empty(): return 0
	var room := FLOOR.room_at(manifest.rooms, point)
	if room.is_empty(): return 0
	var id := int(room.id)
	if room_layers.cars.has(id) and ROOM_LAYERS.car_rect(room).has_point(Vector2(point.x, point.z)): return room_layers.cars[id]
	return room_layers.mask[id]

## Every room's layer, everything built so far put on its room's, and every
## lamp filed with what it may light (the head of this section). Once a floor,
## whatever the preset: the layers cost nothing while the lamps light them all.
func assign_layers() -> void:
	room_layers = ROOM_LAYERS.assign(manifest)
	if int(room_layers.clashes) > 0: push_warning("Light layers: %d rooms share a layer with a lamp in reach (Muy bajo would leak there)." % int(room_layers.clashes))
	kept_lamps.clear()
	var placed := {}
	for i in room_nodes.size():
		placed[room_nodes[i]] = true
		var bit: int = room_layers.layer[i]
		if bit != 0: lay(room_nodes[i], bit, int(room_layers.cars.get(i, bit)), room_layers.mask[i])
	# A door, its casing and its stop stand in two rooms: lit by both.
	for i in doors.size():
		var out: Vector3 = Basis(Vector3.UP, doors[i].closed_rotation).z * 0.7 + Vector3(0, 1.0, 0)
		var both: int = layer_at(doors[i].doorway + out) | layer_at(doors[i].doorway - Vector3(out.x, -out.y, out.z))
		for piece in [doors[i]] + door_fixtures[i]:
			placed[piece] = true
			if piece is GeometryInstance3D: ROOM_LAYERS.put_on(piece, both)
			lay(piece, both, both, both)
	# Whatever else stands on the floor itself: where it is.
	for child in get_children():
		if not placed.has(child) and child is Node3D: adopt(child)
	for lamp in lights + practicals + sconce_lights + exit_lamps + car_lamps:
		if kept_lamps.has(lamp.get_instance_id()): kept_lamps[lamp.get_instance_id()].looked_after = true
	apply_static_light()

## Everything under `node` on a room's layer, its lamps filed with `glow`:
## what a lamp of this room may light, its own layer and those of the cells it
## is open to. A lift's car under it is on `car`, and what of the car shows in
## the lobby on both.
func lay(node: Node, bit: int, car: int, glow: int) -> void:
	for child in node.get_children():
		var here := car if child.has_meta("car") else bit
		if child is GeometryInstance3D: ROOM_LAYERS.put_on(child, here | (car if child.has_meta("lobby_side") else 0))
		elif child is Light3D: keep_lamp(child, glow)
		# Under a car, `bit` is the car's and `car` the lobby's, and its lamp
		# lights the car alone.
		if child.has_meta("car"): lay(child, here, bit, here)
		else: lay(child, here, car, glow)

## Something on the floor itself, or put there after it was built (a
## television, a document, a lock): on the layer of the room it stands in.
func adopt(node: Node3D) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	var bit := layer_at(node.global_position + Vector3(0, 0.2, 0))
	if bit == 0: return
	var glow := glow_at(node.global_position + Vector3(0, 0.2, 0))
	if node is GeometryInstance3D: ROOM_LAYERS.put_on(node, bit)
	elif node is Light3D:
		keep_lamp(node, glow)
		light_lamp(kept_lamps[node.get_instance_id()])
	lay(node, bit, bit, glow)

func keep_lamp(light: Light3D, mask: int) -> void:
	if kept_lamps.has(light.get_instance_id()): return
	kept_lamps[light.get_instance_id()] = {"light": light, "mask": mask, "every": light.light_cull_mask, "casts": light.shadow_enabled, "looked_after": false}

## Whether a lamp is kept to its own room's layers: every lamp on
## static_light, and a wall lamp wherever the rooms have layers at all.
func kept_in(entry: Dictionary) -> bool:
	return static_light or (layered and int(entry.mask) != 0 and (entry.light as Light3D).has_meta("own_room"))

## A lamp as static_light has it, or as it was built.
func light_lamp(entry: Dictionary) -> void:
	var light: Light3D = entry.light
	ROOM_LAYERS.light_only(light, entry.mask if kept_in(entry) else entry.every)
	if entry.looked_after: return
	var casting: bool = entry.casts and not static_light
	if light.shadow_enabled != casting: light.shadow_enabled = casting

func apply_static_light() -> void:
	for id in kept_lamps.keys():
		if is_instance_valid(kept_lamps[id].light): light_lamp(kept_lamps[id])
		else: kept_lamps.erase(id)
	if layered: make_halves()
	for i in door_halves.size():
		var entry: Dictionary = door_halves[i]
		var whole := doors[i].get_node_or_null("Leaf") as Node3D
		if whole != null: whole.visible = not layered
		for item in entry.sided:
			if item[0].has_meta("half"): item[0].visible = layered
		if layered: continue
		# The whole casings come back with the next update_visibility().
		for half in entry.casing: half.visible = false
		for item in entry.sided: ROOM_LAYERS.put_on(item[0], entry.bits[0] | entry.bits[1])
		entry.open = true
	if is_inside_tree():
		for body in bodies(): body.remove_meta("room_layer")

## Every door's halves (door_halves).
func make_halves() -> void:
	if not door_halves.is_empty() or room_layers.is_empty(): return
	for i in doors.size():
		var door: Node3D = doors[i]
		var casing: MeshInstance3D = door_fixtures[i][0]
		# Each door's own meshes (leaf_mesh(), frame_mesh()): HALVES caches by mesh.
		var leaf_node := door.get_node_or_null("Leaf") as MeshInstance3D
		var casings := HALVES.of(casing.mesh)
		var leaves := HALVES.of(leaf_node.mesh if leaf_node != null else DOOR_LEAF)
		var across: Vector3 = Basis(Vector3.UP, door.closed_rotation).z * 0.7
		var bits := [layer_at(door.doorway + across + Vector3.UP), layer_at(door.doorway - across + Vector3.UP)]
		var entry := {"bits": bits, "casing": [], "sided": [], "open": true}
		for side in 2:
			var half := half_mesh(casings[side], "%s_%d" % [casing.name, side], 1 | bits[side])
			half.transform = casing.transform
			half.visible = false
			add_child(half)
			entry.casing.append(half)
			var leaf := half_mesh(leaves[side], "Leaf_%d" % side, 1 | bits[0] | bits[1])
			door.add_child(leaf)
			entry.sided.append([leaf, side])
		for plaque in door.get_children():
			if not plaque.has_meta("side"): continue
			for mesh in plaque.find_children("*", "GeometryInstance3D", true, false): entry.sided.append([mesh, int(plaque.get_meta("side"))])
		door_halves.append(entry)

func half_mesh(mesh: Mesh, title: String, layers: int) -> MeshInstance3D:
	var half := MeshInstance3D.new()
	half.name = title
	half.mesh = mesh
	half.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	half.layers = layers
	half.set_meta("half", true)
	# Where it is says nothing about which room it belongs to (late_arrival()).
	half.set_meta("laid", true)
	return half

## What is added to a floor already built is put on its room's layer too.
func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(late_arrival): get_tree().node_added.connect(late_arrival)

func late_arrival(node: Node) -> void:
	if building or room_layers.is_empty() or not (node is GeometryInstance3D or node is Light3D) or node.has_meta("laid") or not is_ancestor_of(node): return
	adopt.call_deferred(node)

## People and the creature go from layer to layer with the room they are in;
## a body rebuilt meanwhile (another character) is caught up with a few times
## a second.
func bodies() -> Array:
	return get_tree().get_nodes_in_group(&"hotel_players") + get_tree().get_nodes_in_group(&"hotel_actors")

## The room layer a body at `at` (its feet) is on: negative for none, as in a
## crawl space outside every room (H10); the hotel's is always a room's or 0.
func body_bit(at: Vector3) -> int: return layer_at(at + Vector3(0, 0.9, 0))

func follow_bodies() -> void:
	body_clock += 1
	for body in bodies():
		if not body is Node3D: continue
		var bit := body_bit((body as Node3D).global_position)
		if bit == 0 or (int(body.get_meta("room_layer", 0)) == bit and body_clock % 20 != 0): continue
		body.set_meta("room_layer", bit)
		for mesh in body.find_children("*", "GeometryInstance3D", true, false):
			# A mesh off layer 1 that asks for it (the Lurker's face) follows the
			# rooms too; a first-person body on layer 2 alone must not.
			if mesh.has_meta("follow_rooms"): ROOM_LAYERS.put_on_actor(mesh, maxi(bit, 0))
			else: ROOM_LAYERS.put_on(mesh, maxi(bit, 0))

## Something put down in a room that is nobody's body and in no group (the
## figure a frayed mind sees): on the layer of the room it stands in, once.
func light_body(body: Node3D) -> void:
	var bit := layer_at(body.global_position + Vector3(0, 0.9, 0))
	if bit == 0: return
	for mesh in body.find_children("*", "GeometryInstance3D", true, false): ROOM_LAYERS.put_on(mesh, bit)

# A lamp that really lights its surroundings (no shadows, culled by distance).
func practical(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> void:
	# In a dark room the table and floor lamps are out too: it is dark.
	if building_dark: return
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.omni_attenuation = 2.2
	lamp.light_size = PRACTICAL_SIZE * preset.penumbra
	# Floor and desk lamps stand near walls: out of the bounce light, like the
	# wall lamps (sconce_light()).
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
	lamp.light_specular = 0.25
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.shadow_normal_bias = 0.6
	lamp.light_volumetric_fog_energy = 0.0
	lamp.distance_fade_enabled = true
	# Shadows last as long as the light does (set_fade): a lamp still shining
	# without its shadow shines through walls and closed doors.
	practical_fade(lamp)
	parent.add_child(lamp)
	practicals.append(lamp)

## A furniture lamp fades over its last 10 m before furniture_lamps (it is
## hidden there), 8 m of fade and 2 m to spare.
func practical_fade(lamp: OmniLight3D) -> void:
	var out: float = preset.furniture_lamps
	if out > 0.0: set_fade(lamp, out - 10.0, 8.0)

## The planta whose bounce light is baked (or baking), -1 for none. Only one
## at a time: a planta is some 140 lit rooms and 55 ms each on one core, the
## three of them held up the start of a floor by four seconds and their
## volumes' data never went, and the others are under a slab anyway.
var bounce_planta := -1
## The planta the last look was from (update_visibility()).
var eye_planta := 0

## Bakes a planta's lit rooms' bounce light on worker threads
## (bounce_light.gd), letting the other plantas' volumes go. A room alone, or
## a hall's cells together (one volume over the hall, if it is a rectangle; an
## L-shaped hall has none: see bounce_light.gd), or a straight stretch of
## corridor (corridor_runs()) with the cells it runs on into (run_on()).
## update_visibility() asks for the planta the eye goes to.
func start_bounce(planta: int) -> void:
	if planta == bounce_planta or bounce.baking(): return
	bounce_planta = planta
	bounce.release(planta)
	var wanted := []
	var groups := bounce_groups(planta)
	for i: int in groups.alone:
		var room: Dictionary = manifest.rooms[i]
		wanted.append({"room": i, "node": room_nodes[i], "centre": Vector3.ZERO, "size": FLOOR.size_of(room), "height": float(room.height), "parts": [[room_nodes[i], Vector3.ZERO]]})
	var halls: Dictionary = groups.halls
	for hall in halls:
		var cells: Array = halls[hall]
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		var area := 0.0
		var height := 0.0
		for i in cells:
			var span := FLOOR.size_of(manifest.rooms[i])
			var at := room_nodes[i].position
			low = Vector2(minf(low.x, at.x - span.x * 0.5), minf(low.y, at.z - span.y * 0.5))
			high = Vector2(maxf(high.x, at.x + span.x * 0.5), maxf(high.y, at.z + span.y * 0.5))
			area += span.x * span.y
			height = maxf(height, float(manifest.rooms[i].height))
		var size := high - low
		if absf(size.x * size.y - area) > 0.5: continue
		var middle := Vector3((low.x + high.x) * 0.5, 0.0, (low.y + high.y) * 0.5)
		var root: Node3D = room_nodes[cells[0]]
		wanted.append({"room": cells[0], "node": root, "centre": middle - root.position, "size": size, "height": height, "parts": cells.map(func(i): return [room_nodes[i], room_nodes[i].position - middle])})
	bounce.start(wanted, unit_mesh)

## Which cells of a planta share a volume: {"halls": first cell -> its cells
## (a hall's, or a stretch of corridor's with the cells it runs on into, even
## a cell alone), "alone": the lit rooms with a volume to themselves}.
func bounce_groups(planta: int) -> Dictionary:
	var halls := {}
	var alone: Array = []
	var runs := corridor_runs(planta)
	# The stretches of corridor, a cell alone among them: by first cell.
	var stretches := {}
	for i in room_nodes.size():
		var room: Dictionary = manifest.rooms[i]
		if dark_room(room) or FLOOR.is_void(room) or room_planta[i] != planta: continue
		var hall := int(room.get("hall", -1))
		# Keyed by its first cell's index, which no hall uses (a hall is
		# keyed by one of its own cells, and a corridor is never in one).
		if hall < 0 and bool(room.get("corridor", false)):
			hall = int(runs.get(i, i))
			stretches[hall] = true
		if hall >= 0:
			if not halls.has(hall): halls[hall] = []
			halls[hall].append(i)
		else: alone.append(i)
	run_on(halls, stretches, planta)
	return {"halls": halls, "alone": alone}

## The planta's straight stretches of lit corridor, each baked as one volume
## like a hall: room index -> the index of its stretch's first cell. With a
## volume per cell, each was baked alone and lit by the lamps round it, and
## Godot does not blend one volume into the next (a surface takes the ones it
## lies in, normalised): walls, ceiling and floor were cut straight at every
## cell's edge, one side up to four times brighter (seed 81, rooms 18 and 19).
## A cell where two stretches cross goes to the longer; a stretch of one cell
## keeps its own volume. Where two stretches meet the cut remains, at a turn.
func corridor_runs(planta: int) -> Dictionary:
	var lit_rooms := {}
	for i in room_nodes.size():
		var room: Dictionary = manifest.rooms[i]
		if room_planta[i] == planta and bool(room.get("corridor", false)) and int(room.get("hall", -1)) < 0 and not dark_room(room) and not FLOOR.is_void(room): lit_rooms[i] = true
	var runs := []
	for way in [Vector2i(1, 0), Vector2i(0, 1)]:
		for i in lit_rooms:
			if open_between(i, FLOOR.beside(manifest.rooms[i], -way), lit_rooms): continue
			var run := [i]
			while open_between(run[-1], FLOOR.beside(manifest.rooms[run[-1]], way), lit_rooms): run.append(FLOOR.beside(manifest.rooms[run[-1]], way))
			if run.size() > 1: runs.append(run)
	runs.sort_custom(func(a: Array, b: Array) -> bool: return run_length(a) > run_length(b))
	var first := {}
	for run in runs:
		var piece := []
		for i in run + [-1]:
			if i >= 0 and not first.has(i):
				piece.append(i)
				continue
			if piece.size() > 1:
				for cell in piece: first[cell] = piece[0]
			piece = []
	return first

## Carries each stretch of corridor's volume on over the cell past either
## end of it, where the corridor goes on with no wall: a cell whose lamp is
## out, or the first of another stretch (a turn, a crossing).
##
## Godot does not fade a volume out at its edge: a surface takes the volumes
## it lies in, each weighed by how far inside it the point is, and divides by
## the sum -- so one volume alone is at full strength up to its last voxel
## and gone past it. Where a lit cell ran on into a dark one, the bounce of
## its lamps stopped dead at the line between them, down the walls and
## across the floor and ceiling, over an open corridor (October 2026: "the
## lights are cut"). Carried a whole cell further, the volume ends where its
## light has died away of itself; and where two volumes share a cell, each
## weighs nothing at its own edge, so one gives way to the other across the
## cell and neither ends in a line.
##
## Only along the stretch (the box stays a rectangle; a cell of another width
## or out of line is left), a single cell along the way it has more of, and
## never a third volume over one cell: Godot gives a surface two.
func run_on(halls: Dictionary, stretches: Dictionary, planta: int) -> void:
	var over := {}
	for hall in halls:
		for i in halls[hall]: over[i] = 1
	# The longest first: where there is only room for one more, it is theirs.
	var order: Array = stretches.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return run_length(halls[a]) > run_length(halls[b]) or (run_length(halls[a]) == run_length(halls[b]) and a < b))
	for hall in order:
		var cells: Array = halls[hall]
		var best: Array = []
		for way in [Vector2i(1, 0), Vector2i(0, 1)]:
			# The cells at either end of it along this way; a stretch of
			# several goes on only the way it runs.
			var first: int = cells[0]
			var last: int = cells[0]
			var runs_this_way := true
			for i in cells:
				var from_first: Vector3 = room_nodes[i].position - room_nodes[cells[0]].position
				if absf(from_first.z if way.x != 0 else from_first.x) > 0.01: runs_this_way = false
				var along: float = room_nodes[i].position.x if way.x != 0 else room_nodes[i].position.z
				if along < (room_nodes[first].position.x if way.x != 0 else room_nodes[first].position.z): first = i
				if along > (room_nodes[last].position.x if way.x != 0 else room_nodes[last].position.z): last = i
			if not runs_this_way: continue
			var found: Array = []
			for end in [[first, -way], [last, way]]:
				var from: int = end[0]
				var next: int = FLOOR.beside(manifest.rooms[from], end[1])
				if next < 0 or next in cells or room_planta[next] != planta or FLOOR.is_void(manifest.rooms[next]): continue
				if not open_pairs.has(Vector2i(mini(from, next), maxi(from, next))) or int(over.get(next, 0)) >= 2: continue
				# In line and as wide: the box over both is still theirs alone.
				var here := FLOOR.size_of(manifest.rooms[from])
				var there := FLOOR.size_of(manifest.rooms[next])
				var apart: Vector3 = room_nodes[next].position - room_nodes[from].position
				var square: bool = (is_equal_approx(here.y, there.y) and absf(apart.z) < 0.01) if way.x != 0 else (is_equal_approx(here.x, there.x) and absf(apart.x) < 0.01)
				if square: found.append(next)
			if found.size() > best.size(): best = found
		for next in best:
			cells.append(next)
			over[next] = int(over.get(next, 0)) + 1

## Two cells of corridor open on to each other, both lit.
func open_between(a: int, b: int, lit_rooms: Dictionary) -> bool:
	return b >= 0 and lit_rooms.has(b) and open_pairs.has(Vector2i(mini(a, b), maxi(a, b)))

func run_length(run: Array) -> float:
	var metres := 0.0
	for i in run:
		var span := FLOOR.size_of(manifest.rooms[i])
		metres += maxf(span.x, span.y)
	return metres

## The floor goes mid-bake: the bake is waited for, which is safe (its workers
## never wait for the main thread), and error printing comes back on.
func _exit_tree() -> void:
	bounce.finish()

func make_probe(slot: Dictionary) -> void:
	var probe := ReflectionProbe.new()
	probe.position.y = slot.height * 0.5
	probe.size = slot.size
	probe.interior = true
	probe.box_projection = true
	probe.blend_distance = 0.1
	probe.intensity = 0.6
	probe.max_distance = 30
	probe_settings(probe)
	slot.parent.add_child(probe)
	slot.probe = probe
	probes_made += 1

## Freeing it is what gives its place in the atlas back.
func drop_probe(slot: Dictionary) -> void:
	slot.probe.queue_free()
	slot.probe = null
	probes_made -= 1

## Rendered with shadows at probes 2, and there, without bounce light, its
## capture is also its room's ambient light (the bounce volumes would be
## replaced by it otherwise).
func probe_settings(probe: ReflectionProbe) -> void:
	var shadowed: bool = preset.probes >= 2
	if probe.enable_shadows != shadowed: probe.enable_shadows = shadowed
	var mode := ReflectionProbe.AMBIENT_ENVIRONMENT if shadowed and not preset.bounce else ReflectionProbe.AMBIENT_DISABLED
	if probe.ambient_mode != mode: probe.ambient_mode = mode

## Distance fade of a lamp; its shadow ends exactly where its light does.
static func set_fade(lamp: Light3D, begin: float, length: float) -> void:
	if lamp.distance_fade_begin != begin: lamp.distance_fade_begin = begin
	if lamp.distance_fade_length != length: lamp.distance_fade_length = length
	if lamp.distance_fade_shadow != begin + length: lamp.distance_fade_shadow = begin + length

## A new graphics preset (graphics_presets.gd), from hotel_main. Visibility
## follows on the next update_visibility().
func apply_quality(new_preset: Dictionary) -> void:
	preset = new_preset
	for projector in decals:
		var shown: bool = decal_shown(projector)
		if projector.visible != shown: projector.visible = shown
	small_maps = preset.small_maps
	no_maps = preset.surface_detail < 0.5
	if maps_small != small_maps or maps_none != no_maps:
		maps_small = small_maps
		maps_none = no_maps
		for key in materials: apply_scan(materials[key], small_maps)
	var layers_wanted: bool = preset.static_light or (preset.sconce_fill and preset.sconce_lights) or preset.lamps_cast > 0
	if static_light != preset.static_light or layered != layers_wanted:
		static_light = preset.static_light
		layered = layers_wanted
		apply_static_light()
	# Every wall lamp is told again what it is doing (update_visibility()).
	sconce_state.fill(SCONCE_OUT)
	glaze(preset.glazed_art)
	if kit != bool(preset.detail_kit): set_kit(preset.detail_kit)
	lacquer(preset.surface_detail > 4.5)
	for light in lights:
		set_fade(light, preset.lamp_fade[0], preset.lamp_fade[1])
		var size: float = LAMP_SIZE * preset.penumbra
		if light.light_size != size: light.light_size = size
	for lamp in practicals:
		practical_fade(lamp)
		var size: float = PRACTICAL_SIZE * preset.penumbra
		if lamp.light_size != size: lamp.light_size = size
	for lamp in exit_lamps:
		var size: float = PRACTICAL_SIZE * preset.penumbra
		if lamp.light_size != size: lamp.light_size = size
	# Baked the first time a preset asks for it, for the planta looked from
	# (only where a GPU can draw it: not headless, not Compatibility).
	if preset.bounce and RenderingServer.get_rendering_device() != null: start_bounce(maxi(eye_planta, 0))
	# Every lit room's probe, rendered with shadows, also lights its room
	# (probes 2); otherwise only reflections. The bounce volumes take over
	# from it (a probe's ambient light would replace theirs).
	for slot in probe_slots:
		if slot.probe != null: probe_settings(slot.probe)
	var fog_energy := 1.0 if preset.lamp_fog else 0.0
	for light in lights:
		if light.light_volumetric_fog_energy != fog_energy: light.light_volumetric_fog_energy = fog_energy
	for lamp in sconce_lights:
		var size: float = SCONCE_SIZE * preset.penumbra
		if lamp.light_size != size: lamp.light_size = size
	if is_instance_valid(dust) and preset.dust > 0 and dust.amount != preset.dust: dust.amount = preset.dust

func _process(delta: float) -> void:
	bounce.poll()
	if layered and not room_layers.is_empty(): follow_bodies()
	# With the power gone nothing blinks and nothing hums: the lamps are not
	# failing, they are dead.
	if dark: return
	flicker_clock += delta
	for beacon in beacons:
		# A slow emergency blink with a nervous stutter in each lit phase.
		var t: float = fposmod(flicker_clock, 1.6)
		var on := 1.0 if t < 0.8 else 0.0
		if on > 0.0 and not reduced: on *= 0.75 + 0.25 * sign(sin(flicker_clock * 37.0))
		beacon.light.light_energy = beacon.energy * (0.08 + 0.92 * on)
		beacon.material.emission_energy_multiplier = 0.4 + 3.6 * on
	if flickers.is_empty(): return
	for entry in flickers:
		var lamp: OmniLight3D = entry.light
		if not lamp.visible: continue
		var level := 1.0
		if not reduced:
			# Mostly steady, with short irregular dropouts and a faint hum.
			var t: float = flicker_clock + entry.phase
			var burst := fposmod(t, 7.3) < 0.45
			var chatter := sin(t * 71.0) * sin(t * 23.0)
			level = 0.95 + sin(t * 314.0) * 0.02
			if burst: level = 0.25 if chatter > 0.1 else 1.0
		# A drained room's tube flickers at what is left of it (drain()).
		# A lamp that is one of several (a failing troffer) moves the room light
		# by its share only (H5); the whole lamp is share 1.
		var share := float(entry.get("share", 1.0))
		var lit_level := level if share == 1.0 else 1.0 - share * (1.0 - level)
		lamp.light_energy = entry.energy * lit_level * (1.0 - drained(int(lamp.get_meta("room", -1))))
		entry.material.emission_energy_multiplier = entry.glow * level

## Public-domain paintings (assets/paintings, tools/textures/ingest_dressing.py)
## in their frames: a gold, carved frame (Poly Haven's, its own canvas taken
## out) or a plain wooden one. Portraits hang upright. Which painting hangs
## where comes from the position, like everything else.
const PAINTINGS := "res://assets/paintings/"
const CANVAS := Vector2(1.14, 0.78)
static var art: Array = []
static var carved_frame: Mesh
## Where the carved frame's opening is, in its own space: centre and size.
static var carved_opening := AABB()

static func paintings() -> Array:
	if not art.is_empty(): return art
	var entries = JSON.parse_string(FileAccess.get_file_as_string(PAINTINGS + "paintings.json"))
	for entry in entries:
		var portrait: bool = entry.aspect < 0.95
		var canvas := Vector2(CANVAS.y, CANVAS.x) if portrait else CANVAS
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(PAINTINGS + "%d.jpg" % int(entry.id))
		material.roughness = 0.62
		# Cropped to the canvas, centred; a portrait keeps its upper part.
		var ratio: float = (canvas.x / canvas.y) / float(entry.aspect)
		if ratio < 1.0:
			material.uv1_scale = Vector3(ratio, 1, 1)
			material.uv1_offset = Vector3((1.0 - ratio) * 0.5, 0, 0)
		else:
			material.uv1_scale = Vector3(1, 1.0 / ratio, 1)
			material.uv1_offset = Vector3(0, (1.0 - 1.0 / ratio) * (0.25 if portrait else 0.5), 0)
		var quad := QuadMesh.new()
		quad.size = canvas
		quad.material = material
		quad.resource_name = "painting_%d" % int(entry.id)
		art.append({"mesh": quad, "portrait": portrait})
	# The carved frame without the canvas it came with.
	var source: Mesh = load("res://assets/props/hotel/fancy_picture_frame_01.res")
	carved_frame = ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var box := AABB()
		var first := true
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			box = AABB(vertex, Vector3.ZERO) if first else box.expand(vertex)
			first = false
		if source.surface_get_name(surface).ends_with("canvas"):
			carved_opening = box
			continue
		(carved_frame as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		carved_frame.surface_set_material(carved_frame.get_surface_count() - 1, source.surface_get_material(surface))
	carved_frame.resource_name = "carved_frame"
	return art

## The wood's lacquer as a coat of its own, or not (preset surface_detail 5):
## the wood materials change shader for it, since the coat is paid for by
## whatever shader can write one (wood.gdshaderinc).
const WOOD := preload("res://game/presentation/shaders/wood.gdshader")
const WOOD_LACQUER := preload("res://game/presentation/shaders/wood_lacquer.gdshader")
func lacquer(coated: bool) -> void:
	var wanted: Shader = WOOD_LACQUER if coated else WOOD
	for key in materials:
		var material := materials[key] as ShaderMaterial
		if material != null and material.shader != wanted and material.shader in [WOOD, WOOD_LACQUER]: material.shader = wanted

## The paintings behind glass, or not (preset glazed_art): a clear coat over
## the canvas, so a lamp or the torch is seen in it as in a pane. The canvas
## under it stays as matt as it was.
static func glaze(glazed: bool) -> void:
	for entry in paintings():
		var material: StandardMaterial3D = entry.mesh.material
		if material.clearcoat_enabled == glazed: continue
		material.clearcoat_enabled = glazed
		material.clearcoat = 1.0
		# The engine's coat is a mirror at 0 and still a polished one at 1, and
		# it draws a lamp's whole disc at the lobe's peak: any sharper and a
		# wall lamp is in the glass at many times its own brightness, which
		# shuts the camera's iris on the whole corridor.
		material.clearcoat_roughness = 1.0

## A painting on a wall's inner face (inner: which side of the boundary),
## centred at pos; carved gold frame or a wooden one.
func hang_painting(boundary: Node3D, pos: Vector3, inner: int, carved: bool) -> void:
	var list := paintings()
	var pick: Dictionary = list[int(vary(boundary.position + boundary.basis * pos, 13) * list.size())]
	var canvas := Vector2(CANVAS.y, CANVAS.x) if pick.portrait else CANVAS
	var facing := Basis(Vector3.UP, PI if inner < 0 else 0.0)
	# The plaster face above the chair rail is 9 cm from the wall's centre.
	var face := 0.09
	pos += Vector3(0, 0, inner * face)
	if carved:
		# The frame is carved landscape: a portrait turns it on its side
		# rather than stretching the carving.
		var turn := Basis(Vector3.BACK, PI / 2) if pick.portrait else Basis.IDENTITY
		var scale := Vector3(CANVAS.x / carved_opening.size.x, CANVAS.y / carved_opening.size.y, 1.6)
		var local := Basis.from_scale(scale)
		var centre := turn * (local * carved_opening.get_center())
		var depth := 0.016 + 1.6 * (carved_frame.get_aabb().size.z * 0.5)
		# 2 mm off the plaster: the frame is drawn from both sides and its back
		# lay in the wall's own plane.
		place(boundary, carved_frame, Transform3D(facing * turn * local, pos + facing * Vector3(-centre.x, -centre.y, depth - 0.014)))
		place(boundary, pick.mesh, Transform3D(facing, pos + facing * Vector3(0, 0, depth - 0.014 + centre.z + 0.002)))
	else:
		var border := 0.07
		box(boundary, pos + Vector3(0, 0, inner * 0.02), Vector3(canvas.x + border * 2, canvas.y + border * 2, 0.04), "trim")
		place(boundary, pick.mesh, Transform3D(facing, pos + Vector3(0, 0, inner * 0.043)))

## The big wardrobes that are hiding places too (prop_factory.gd builds their
## carcass and asks for this): after every small one in `hides`, which a
## saved floor and the net name by their place in it.
var big_hides: Array = []

## A big wardrobe's doors and its hiding place, where prop_factory has just
## stood its carcass (`furniture`: the prop's own frame, scaled in the rooms
## with alcoves; the hiding place takes that size and is not scaled itself,
## which a physics body must not be).
func big_hide(furniture: Node3D) -> void:
	var hide := preload("res://game/world/interactables/hiding_place.gd").new()
	hide.big = true
	hide.scale_by = furniture.transform.basis.get_scale().x
	hide.materials = materials
	hide.name = "Wardrobe_big_%d" % big_hides.size()
	hide.transform = Transform3D(furniture.transform.basis.orthonormalized(), furniture.transform.origin)
	furniture.get_parent().add_child(hide)
	big_hides.append(hide)

func build_prop(node: Node3D, kind: String) -> void:
	preload("res://game/world/hotel/prop_factory.gd").build(self, node, kind)

## The lift's sounds and the fluorescent hum of this floor (H9). lifts.gd and
## world_audio.gd still name the hotel's own; they ask these once a floor has
## other sounds (1d's office ingest).
func lift_sounds() -> Dictionary:
	return {"close": "res://assets/audio/sfx/lift/doors_close.wav", "open": "res://assets/audio/sfx/lift/doors_open.wav", "descent": "res://assets/audio/sfx/lift/descent.wav", "bell": "res://assets/audio/sfx/lift/bell.wav"}

func hum_path() -> String: return "res://assets/audio/dread/fluorescent_hum.wav"

## room_dressing's hooks (R1 to R3): a floor kind's own wall picks (true when
## it placed the pick), its stretches of wall, and whether it hangs fuse boxes.
func furnish_pick(_holder: Node3D, _pick: String, _width: float, _seed_pos: Vector3, _kept: int, _room: Dictionary) -> bool: return false

func wall_stretches(room: Dictionary) -> Array: return DRESSING.stretches(room, palette)

func fuse_boxes() -> bool: return true

## The skin of a room's hiding places (hiding_place.skin): the hotel's
## wardrobe, or a floor kind's own (the offices' lockers, 9.7).
func hide_skin(_room: Dictionary) -> Dictionary: return {}

## How far from the walls the navigation keeps (H3).
func nav_agent_radius() -> float: return 0.4

func build_navigation() -> void:
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.agent_radius = nav_agent_radius()
	nav.agent_height = 1.8
	nav.agent_max_climb = 0.1
	# Four voxels to the agent's radius. At 0.2 the rasterised bake lost width
	# inside a furnished room and left the mesh cut in two, with a refuge
	# nobody could walk to (one floor in a thousand: seed 213). Finer costs
	# about half a second of the second and a half a floor takes to put up,
	# and the radius comes out exact instead of being ceiled to voxels.
	nav.cell_size = 0.1
	nav.cell_height = 0.1
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, source, self)
	# One region per planta, each baked from the floor it stands on. Nothing
	# joins them but the lift, so nothing a route could follow does either:
	# they are PITCH apart, far past where two regions' edges would meet.
	var plantas := {}
	for index in room_planta: plantas[index] = true
	# The whole plan, wherever the reception put the origin.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for room in manifest.rooms:
		var at := FLOOR.position_of(room)
		var half := FLOOR.size_of(room) * 0.5
		low = Vector2(minf(low.x, at.x - half.x), minf(low.y, at.z - half.y))
		high = Vector2(maxf(high.x, at.x + half.x), maxf(high.y, at.z + half.y))
	for planta in plantas:
		var mesh: NavigationMesh = nav.duplicate()
		mesh.filter_baking_aabb = AABB(Vector3(low.x - 2.0, FLOOR.planta_y(planta) - 0.5, low.y - 2.0), Vector3(high.x - low.x + 4.0, 3, high.y - low.y + 4.0))
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)
		keep_floor(mesh, FLOOR.planta_y(planta))
		var region := NavigationRegion3D.new()
		region.name = "Navigation_%d" % planta
		region.navigation_mesh = mesh
		add_child(region)

## How far over its floor a piece of the navigation may start and still be
## the floor's (metres). The floor's own mesh lies 0.2 over it (the bake's
## cells); the lowest furniture top, a bed's, comes out at 0.5, desks and
## dressers at 0.8 to 1.3 and wardrobes' tops at 2.7 (seed 81).
const FLOOR_ISLAND := 0.35
## And how big a piece of floor has to be, against the planta's biggest, to
## be kept.
const FLOOR_PIECE := 0.1

## Only what is walked on from the floor. Baked from the colliders, the tops of
## beds, sofas and desks came out as islands of their own, joined to nothing.
## A point is put on the walkable nearest to it (FLOOR.closest), and somebody
## standing on a bed was put on its island: a route from there to the creature
## went no further than the island's edge, a metre off, and whatever measured
## it heard the creature in the bed with them -- the aura at its fullest, its
## voice at the ear -- from across the floor (world_audio.route_source,
## dread_aura.route_to; tools/dev/hearing_probe.gd). Every piece of the mesh
## that never comes down to the floor is let go: the creature could never have
## walked up there either.
static func keep_floor(mesh: NavigationMesh, floor_y: float) -> void:
	var vertices := mesh.get_vertices()
	var count := mesh.get_polygon_count()
	# Pieces: polygons that share a corner are one.
	var piece := PackedInt32Array()
	piece.resize(count)
	for i in count: piece[i] = i
	var owner := {}
	var find := func(i: int) -> int:
		while piece[i] != i:
			piece[i] = piece[piece[i]]
			i = piece[i]
		return i
	for i in count:
		for corner in mesh.get_polygon(i):
			if not owner.has(corner):
				owner[corner] = i
				continue
			var a: int = find.call(i)
			var b: int = find.call(int(owner[corner]))
			if a != b: piece[a] = b
	var lowest := {}
	for i in count:
		var root: int = find.call(i)
		for corner in mesh.get_polygon(i): lowest[root] = minf(float(lowest.get(root, INF)), vertices[corner].y)
	# And of what is on the floor, only the floor: the pockets left between
	# furniture and a wall, too narrow for the creature to walk into, are
	# islands as well (a listener standing in one was put on it, and heard the
	# creature at its edge). The floor of a planta is one piece, thousands of
	# polygons; its pockets are a dozen at most.
	var sizes := {}
	for i in count: sizes[find.call(i)] = int(sizes.get(find.call(i), 0)) + 1
	var largest := 0
	for root in sizes:
		if float(lowest[root]) <= floor_y + FLOOR_ISLAND: largest = maxi(largest, int(sizes[root]))
	var kept: Array = []
	for i in count:
		var root: int = find.call(i)
		if float(lowest[root]) <= floor_y + FLOOR_ISLAND and int(sizes[root]) >= largest * FLOOR_PIECE: kept.append(mesh.get_polygon(i))
	if kept.size() == count: return
	mesh.clear_polygons()
	for polygon in kept: mesh.add_polygon(polygon)

## Whether this room's ceiling lamp is out (deterministic per position).
func dark_room(room: Dictionary) -> bool:
	return dark_ids.has(int(room.id))

## Which rooms are dark: the ones the floor says (it draws them by seed, so
## every machine has the same).
func decide_dark(data: Dictionary) -> void:
	dark_ids.clear()
	for room in data.rooms:
		if bool(room.get("dark", false)): dark_ids[int(room.id)] = true

## Whether a room has its light: the floor has power, the room is not one of
## its dark ones, its own power is on and its lamp is not drained past
## LIT_DRAIN. Dictionary reads only: sanity and the bots ask every frame.
func lit(room_id: int) -> bool:
	return not dark and not dark_ids.has(room_id) and not unpowered.has(room_id) and float(drains.get(room_id, 0.0)) < LIT_DRAIN

## Cuts or gives back one room's power. Its ceiling lamp goes out marked
## "off", so the room culling does not show it again, and comes back only
## where neither the blackout nor the floor's dark rooms keep it out.
func set_room_power(room_id: int, on: bool) -> void:
	if on != unpowered.has(room_id): return
	if on: unpowered.erase(room_id)
	else: unpowered[room_id] = true
	var light: OmniLight3D = lights[room_id]
	# The lamp of a cell with nothing in it is out for good.
	if light.has_meta("void"): return
	if not on:
		light.set_meta("off", true)
		light.visible = false
	elif not dark and not dark_ids.has(room_id):
		light.remove_meta("off")

## How much of a room's lamp is drained, 0 to 1.
func drained(room_id: int) -> float:
	return float(drains.get(room_id, 0.0))

## Drains a room's lamp: its energy scaled by what is left, with no new light
## and no new material. Back to 0 it has the exact energy it had before.
func drain(room_id: int, amount: float) -> void:
	var light: OmniLight3D = lights[room_id]
	var share := clampf(amount, 0.0, 1.0)
	if share <= 0.0:
		if not drains.has(room_id): return
		light.light_energy = float(drain_from[room_id])
		drains.erase(room_id)
		drain_from.erase(room_id)
		return
	if not drain_from.has(room_id): drain_from[room_id] = light.light_energy
	drains[room_id] = share
	light.light_energy = float(drain_from[room_id]) * (1.0 - share)

## reach_over: the observer looking at the whole floor from above asks for
## everything to be drawn, whatever the preset would hide (0: the preset's).
## show_all: nothing is hidden at all -- every room, every door with its
## fixtures, every lamp that is not switched off, wherever they are. It is for
## looking at a floor (--observer), never for playing one: what it costs is
## exactly what the distances above exist to avoid.
## planta: the one drawn; by default the one the eye is on. Only one ever is:
## the others are under a slab, and their lamps would light through it.
func update_visibility(player_position: Vector3, shadows: bool, reach_over := 0.0, show_all := false, planta := -1) -> void:
	for part in ROUND_PARTS: update_part(part, player_position, shadows, reach_over, show_all, planta)

## The round in three parts, which the level runs on three frames one after
## the other (hotel_main, visibility_clock): the rooms with their ceiling lamps
## and their doors, which go together -- a lamp lit among walls or doorways not
## yet drawn shines through them --; the reflection probes, which follow the
## lamps; and the rest of the lamps and the bounce. The whole of it took some
## 2 ms of one frame four times a second, a tooth in every quarter second of a
## walk (tools/dev/hitch_probe.gd); each part is about a third of that. Every
## part works from where the eye was for the first: `round_at`.
const ROUND_PARTS := 3
var round_at := {}
## How many reflection probes a part may make, when the level spreads the
## round (0: as many as are missing, for a floor just put up). Each one is the
## room drawn six times over in that frame.
var probes_at_once := 0

func update_part(part: int, player_position: Vector3, shadows: bool, reach_over := 0.0, show_all := false, planta := -1) -> void:
	if building: return
	if part == 0:
		round_at = {"position": player_position, "shadows": shadows and not static_light, "show_all": show_all, "reach": 100000.0 if show_all else maxf(preset.room_reach, reach_over), "here": planta if planta >= 0 else FLOOR.planta_of(player_position.y)}
		round_rooms()
	elif round_at.is_empty(): return
	elif part == 1: round_probes()
	else: round_lamps()

## The rooms, their ceiling lamps and their doors.
func round_rooms() -> void:
	var player_position: Vector3 = round_at.position
	var shadows: bool = round_at.shadows
	var show_all: bool = round_at.show_all
	var here: int = round_at.here
	eye_planta = here
	# The eye has gone down a planta (or the observer to another): its bounce.
	if preset.bounce and here != bounce_planta and RenderingServer.get_rendering_device() != null: start_bounce(here)
	var motion := 0.0 if reduced else 1.0
	if motion != curtain_motion:
		curtain_motion = motion
		curtain_material.set_shader_parameter("motion", motion)
	if is_instance_valid(dust):
		dust.position = player_position + Vector3(0, 1.2, 0)
		dust.emitting = preset.dust > 0 and not reduced and not echo_view
		dust.visible = dust.emitting
	# Hall haze only exists in Forward+ (the preset has it off elsewhere).
	for fog in fog_volumes: fog.visible = preset.floor_haze and not reduced and not echo_view
	var reach: float = round_at.reach
	# (On static_light nothing of the hotel's casts, whatever the switch says:
	# round_at.shadows.)
	if things_counted != [room_nodes.size(), doors.size(), sconce_lights.size(), practicals.size(), exit_lamps.size()]: index_things()
	if here != shown_planta: put_away(here)
	var things: Dictionary = things_on(here)
	var fade_end: float = preset.lamp_fade[0] + preset.lamp_fade[1]
	# Where the lamps past a count are kept in their rooms by layers (preset
	# lamps_cast), the lit ones are counted from the nearest: [distance, room].
	var counted: bool = layered and not static_light and preset.lamps_cast > 0 and not show_all
	var nearest_lamps: Array = []
	for i in things.rooms:
		var distance := room_spots[i].distance_to(player_position)
		room_nodes[i].visible = distance < reach
		var light := lights[i]
		if light.has_meta("void"): continue
		if show_all:
			# Every lamp of the floor at once, and none of them with a shadow:
			# a hundred shadowed lamps do not fit in the atlas, and what falls
			# out of it shines through the walls.
			light.visible = not light.has_meta("off") and not echo_view
			if light.shadow_enabled: light.shadow_enabled = false
			continue
		# A lamp only shines while every wall round it is still drawn: a hidden
		# room casts no shadow, and a lamp left on among hidden walls poured its
		# light into the dark rooms beside it (far walls of a shut dark room lit).
		var light_reach := minf(fade_end + 2.0, reach - light.omni_range - 2.0)
		light.visible = distance < light_reach and not light.has_meta("off") and not echo_view
		# Only when it changes: every write makes Godot redraw that shadow. A
		# profile only works on a shadowed light: without shadows it goes, or
		# the lamp would give no light at all.
		if counted:
			if light.visible: nearest_lamps.append([distance - (2.0 if light.shadow_enabled else 0.0), i])
		elif light.shadow_enabled != shadows:
			light.shadow_enabled = shadows
			light.light_projector = light.get_meta("profile") if shadows else null
	if counted:
		nearest_lamps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for place in nearest_lamps.size(): cast_or_fill(lights[nearest_lamps[place][1]], shadows and place < int(preset.lamps_cast))
	# Doors carry their light seals, casings and stops: shown as far as the
	# rooms are. No lit lamp reaches past that (its range ends inside it).
	# Where they are drawn in halves (layered), the whole casing stays hidden:
	# it used to be shown with the rest and hidden again at once, every door in
	# reach, four times a second.
	var halved: bool = layered
	for i in things.doors:
		var shown: bool = show_all or door_spots[i].distance_to(player_position) < reach
		doors[i].visible = shown
		var split: bool = halved and i < door_halves.size()
		for f in door_fixtures[i].size(): door_fixtures[i][f].visible = shown and not (split and f == 0)
		if split:
			var entry: Dictionary = door_halves[i]
			for half in entry.casing: half.visible = shown
			var open: bool = doors[i].opened or doors[i].moving
			if open != entry.open:
				entry.open = open
				for item in entry.sided: ROOM_LAYERS.put_on(item[0], entry.bits[0] | entry.bits[1] if open else entry.bits[item[1]])

## The reflection probes of the rooms whose lamps are lit.
func round_probes() -> void:
	var player_position: Vector3 = round_at.position
	# A probe captures its room once, when it is made: only while the room's
	# lamp is on, or it would keep a dark capture. Only the nearest exist.
	# Godot's reflection atlas has 64 places and a probe keeps its place until
	# it is freed, even hidden: with a probe in every lit room, exploring a big
	# floor filled the atlas, probes then showed other rooms' captures (a red
	# square on a ceiling, warm light in a tiled bathroom) and the game
	# crashed. So the nearest PROBES_SHOWN are made, one already made is kept
	# while among the nearest PROBES_KEPT (no remaking at the edge), and the
	# rest are freed. Nothing to look at on a preset without probes, once the
	# last one is gone.
	if preset.probes > 0 or probes_made > 0:
		var wanted: Array[Dictionary] = []
		for slot in probe_slots:
			var used: bool = preset.probes >= 2 or (preset.probes == 1 and slot.every_third)
			if used and not echo_view and lights[slot.room].visible:
				slot.near = (slot.spot as Vector3).distance_squared_to(player_position)
				wanted.append(slot)
			elif slot.probe != null: drop_probe(slot)
		wanted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.near < b.near)
		var made := 0
		for k in wanted.size():
			if wanted[k].probe == null and k < PROBES_SHOWN:
				if probes_at_once > 0 and made >= probes_at_once: continue
				make_probe(wanted[k])
				made += 1
			elif wanted[k].probe != null and k >= PROBES_KEPT: drop_probe(wanted[k])

## The wall lamps, the bounce, the furniture lamps, the exit signs and the cars.
func round_lamps() -> void:
	var player_position: Vector3 = round_at.position
	var shadows: bool = round_at.shadows
	var show_all: bool = round_at.show_all
	var here: int = round_at.here
	var things: Dictionary = things_on(here)
	# The nearest SCONCES_LIT wall lamps and no more: over the atlas they lose
	# their shadows and light the room on the other side of the wall. Not with
	# the power cut (blackout() hides them; this used to bring them back a
	# quarter of a second later, lit by nothing but the torch). One already
	# lit counts as a metre and a half nearer, so the ones round a room do not
	# swap places every time the player takes a step: a lamp going on and off
	# as you shift your weight would be worse than one lamp fewer.
	# Past the twelve, and out to SCONCE_FILL_REACH, a wall lamp still lights
	# its wall where the preset keeps it in its room by layers (sconce_fill).
	var sconces_wanted: bool = not dark and preset.sconce_lights and shadows and not echo_view
	if sconces_wanted or sconces_lit:
		var fill: bool = sconces_wanted and layered and preset.sconce_fill
		var nearest: Array = []
		for k in things.sconces:
			var distance := sconce_spots[k].distance_to(player_position)
			if sconces_wanted and distance < (SCONCE_FILL_REACH if fill else SCONCE_REACH): nearest.append([distance - (1.5 if sconce_state[k] == SCONCE_CAST else 0.0), k, distance])
			elif sconce_state[k] != SCONCE_OUT or sconce_lights[k].visible: set_sconce(k, SCONCE_OUT)
		nearest.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for place in nearest.size():
			var k: int = nearest[place][1]
			var state := SCONCE_CAST if place < SCONCES_LIT and nearest[place][2] < SCONCE_REACH else (SCONCE_FILL if fill else SCONCE_OUT)
			if sconce_state[k] != state or sconce_lights[k].visible != (state != SCONCE_OUT): set_sconce(k, state)
		sconces_lit = not nearest.is_empty()
	bounce.show_near(player_position, preset.bounce and not echo_view and not dark, here)
	for k in practicals.size():
		var lamp := practicals[k]
		var shown: bool = not dark and not echo_view and (show_all or practical_spots[k].distance_to(player_position) < preset.furniture_lamps)
		if lamp.visible != shown: lamp.visible = shown
		if lamp.shadow_enabled != shadows: lamp.shadow_enabled = shadows
	# The exit signs keep theirs through a power cut: they are the one thing
	# here that would have a battery, and the refuge stays findable.
	for k in exit_lamps.size():
		var lamp := exit_lamps[k]
		var shown: bool = not echo_view and (show_all or exit_spots[k].distance_to(player_position) < EXIT_REACH)
		if lamp.visible != shown: lamp.visible = shown
		if lamp.shadow_enabled != shadows: lamp.shadow_enabled = shadows
	# The cars' lamps keep theirs looking at the whole floor as well: there are
	# a handful, and they fit in the atlas where a hundred room lamps do not.
	var cars_cast: bool = (shadows or show_all) and not static_light
	for lamp in car_lamps:
		if lamp.shadow_enabled != cars_cast: lamp.shadow_enabled = cars_cast

## A ceiling lamp casting, with its profile and the whole hotel to light, or
## -- past the preset's lamps_cast -- filling: no shadow, and nothing to light
## but the layers of its own room. Every shadowed lamp in view asks for a
## place in the shadow atlas, which has 88 and gives a round lamp two: on the
## highest preset, whose lamps reach furthest, there were sixty and more of
## them alight at once on a big floor, and the ones the atlas had no place
## for were drawn without their shadow, through the walls, into rooms that
## are dark (tools/dev/light_leak.gd: a dark room lit one run in two).
func cast_or_fill(light: Light3D, casts: bool) -> void:
	var entry = kept_lamps.get(light.get_instance_id())
	if entry != null: ROOM_LAYERS.light_only(light, entry.every if casts else entry.mask)
	if light.shadow_enabled == casts: return
	light.shadow_enabled = casts
	light.light_projector = light.get_meta("profile") if casts else null

## A wall lamp out, casting with its profile, or filling its wall with no
## shadow; either way with only its own room's layers to light (kept_in()).
func set_sconce(k: int, state: int) -> void:
	var lamp := sconce_lights[k]
	sconce_state[k] = state
	if state == SCONCE_OUT:
		lamp.visible = false
		return
	var casts := state == SCONCE_CAST
	var entry = kept_lamps.get(lamp.get_instance_id())
	if entry != null: ROOM_LAYERS.light_only(lamp, entry.mask if (not casts or kept_in(entry)) else entry.every)
	if lamp.shadow_enabled != casts: lamp.shadow_enabled = casts
	var profile: Texture2D = LIGHTING.profile("sconce") if casts else null
	if lamp.light_projector != profile: lamp.light_projector = profile
	lamp.light_energy = SCONCE_ENERGY if casts else SCONCE_ENERGY * SCONCE_FILL_ENERGY
	set_fade(lamp, (SCONCE_REACH if casts else SCONCE_FILL_REACH) - 8.0, 6.0)
	lamp.visible = true

## What update_visibility() goes through, planta by planta. Only the planta
## looked from is ever drawn, so the others' rooms, doors and wall lamps are
## put away once, when the eye changes planta (put_away()), and not looked at
## again: a floor is three plantas, and going through all of it -- 571 rooms,
## 369 doors and 624 wall lamps on seed 81, asking each node where it is --
## was 3 ms four times a second on the development PC, and more than twice
## that on a modest processor (PERFORMANCE.md, section 10). Where things are
## is kept here as well; none of them ever moves. A room or a door with no
## planta of its own (a staged set) counts as on every one.
var planta_things := {}
var things_counted: Array = []
var shown_planta := -1
var room_spots := PackedVector3Array()
var door_spots := PackedVector3Array()
var sconce_spots := PackedVector3Array()
var practical_spots := PackedVector3Array()
var exit_spots := PackedVector3Array()
## Whether any wall lamp is lit, any probe made: with none, and none wanted,
## there is nothing to go through.
var sconces_lit := false
var probes_made := 0
var curtain_motion := -1.0

func things_on(planta: int) -> Dictionary:
	if not planta_things.has(planta): planta_things[planta] = {"rooms": PackedInt32Array(), "doors": PackedInt32Array(), "sconces": PackedInt32Array()}
	return planta_things[planta]

func index_things() -> void:
	planta_things.clear()
	shown_planta = -1
	sconces_lit = true
	things_counted = [room_nodes.size(), doors.size(), sconce_lights.size(), practicals.size(), exit_lamps.size()]
	var everywhere := range(FLOOR.PLANTAS)
	room_spots.resize(room_nodes.size())
	for i in room_nodes.size():
		room_spots[i] = room_nodes[i].position
		for planta in ([room_planta[i]] if i < room_planta.size() else everywhere): things_on(planta).rooms.append(i)
	door_spots.resize(doors.size())
	for i in doors.size():
		door_spots[i] = doors[i].doorway
		for planta in ([door_planta[i]] if i < door_planta.size() else everywhere): things_on(planta).doors.append(i)
	sconce_spots.resize(sconce_lights.size())
	sconce_state.resize(sconce_lights.size())
	sconce_state.fill(SCONCE_OUT)
	for k in sconce_lights.size():
		sconce_spots[k] = sconce_lights[k].global_position
		things_on(FLOOR.planta_of(sconce_spots[k].y)).sconces.append(k)
	practical_spots.resize(practicals.size())
	for k in practicals.size(): practical_spots[k] = practicals[k].global_position
	exit_spots.resize(exit_lamps.size())
	for k in exit_lamps.size(): exit_spots[k] = exit_lamps[k].global_position
	for slot in probe_slots: slot.spot = (slot.parent as Node3D).global_position

## The doors of the planta a point is on that are within `reach` of it across
## the floor.
func doors_near(point: Vector3, reach: float) -> Array:
	if things_counted != [room_nodes.size(), doors.size(), sconce_lights.size(), practicals.size(), exit_lamps.size()]: index_things()
	var out: Array = []
	for i in things_on(FLOOR.planta_of(point.y)).doors:
		var spot := door_spots[i]
		if (spot.x - point.x) * (spot.x - point.x) + (spot.z - point.z) * (spot.z - point.z) < reach * reach: out.append(doors[i])
	return out

## Everything that is not on the planta looked from, out of sight.
func put_away(here: int) -> void:
	shown_planta = here
	for i in room_nodes.size():
		if i >= room_planta.size() or room_planta[i] == here: continue
		room_nodes[i].visible = false
		if not lights[i].has_meta("void"): lights[i].visible = false
	for i in doors.size():
		if i >= door_planta.size() or door_planta[i] == here: continue
		doors[i].visible = false
		for fixture in door_fixtures[i]: fixture.visible = false
		if i < door_halves.size():
			for half in door_halves[i].casing: half.visible = false
	for k in sconce_lights.size():
		if FLOOR.planta_of(sconce_spots[k].y) != here: sconce_lights[k].visible = false

func build_dust() -> void:
	dust = CPUParticles3D.new()
	# Its specks would never show in a shadow, and as a caster its every-frame
	# update made Godot redraw the shadow of every lamp round the player.
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.amount = maxi(1, preset.dust)
	dust.lifetime = 10
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(6, 1.2, 6)
	dust.direction = Vector3(1, 0.15, 0.3)
	dust.spread = 30
	dust.initial_velocity_min = 0.03
	dust.initial_velocity_max = 0.09
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.006
	dust.scale_amount_max = 0.017
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.73, 0.55, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = false
	mesh.material = mat
	dust.mesh = mesh
	add_child(dust)
