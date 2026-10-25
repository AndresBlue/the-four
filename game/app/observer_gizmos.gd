extends Node3D
## What the observer draws over the hotel: lines and marks that are not in the
## game, only in this view. Everything is one unshaded mesh redrawn each frame,
## so nothing here can change what the floor does -- it has no collision, no
## light and no shadow.
##
## The creature draws its own (creature.draw_gizmos), on the layer being
## drawn (`layer`); the way to its car and every trail are drawn here.
##
## Layers, each with its own key (see observer_view):
##   1 el camino de la criatura, su destino y lo último que supo
##   2 el rastro de cada cuerpo, los últimos segundos
##   3 los ruidos, como anillos que se apagan
##   4 las puertas (abierta, cerrada, con llave), armarios y ascensores
##   5 lo que pide el sector: televisores, cajones con número, documentos
##   6 la vista de la criatura: su cono y la línea a lo que mira
##   7 los ductos de una criatura que los tiene (The Lurker): la red de la
##     planta, sus entradas y salidas, y su camino por dentro
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Seconds a trail remembers, and how often a point is added.
const TRAIL_TIME := 12.0
const TRAIL_EVERY := 0.25
## Seconds a noise ring is drawn for.
const NOISE_TIME := 2.5
const COLOURS := {
	"path": Color(0.35, 0.85, 1.0),
	"lift_route": Color(0.2, 0.4, 1.0),
	"aim": Color(1.0, 0.45, 0.35),
	"trail": Color(0.6, 1.0, 0.6),
	"creature_trail": Color(1.0, 0.5, 0.5),
	"noise": Color(1.0, 0.9, 0.4),
	"door": Color(0.55, 0.8, 0.55),
	"shut": Color(0.9, 0.7, 0.3),
	"locked": Color(1.0, 0.35, 0.35),
	"lift": Color(0.4, 0.7, 1.0),
	"hide": Color(0.8, 0.6, 1.0),
	"tv": Color(0.5, 0.9, 1.0),
	"digit": Color(1.0, 0.85, 0.4),
	"document": Color(0.9, 0.9, 0.9),
	"sight": Color(1.0, 0.8, 0.5),
	"lead": Color(1.0, 0.35, 0.9),
	"search": Color(1.0, 0.6, 0.2),
	"shell": Color(0.75, 0.55, 1.0),
	"duct": Color(0.5, 0.5, 0.55),
	"duct_path": Color(1.0, 0.8, 0.3),
	"exit": Color(0.6, 0.8, 1.0),
	"closed": Color(1.0, 0.3, 0.3),
	"cue": Color(1.0, 0.2, 0.15),
	"drain": Color(1.0, 1.0, 0.6),
}
var level
var mesh := ImmediateMesh.new()
var trails := {}
var trail_clock := 0.0
var noises: Array = []
var shown := {"path": true, "trails": true, "noises": true, "doors": true, "errand": true, "sight": true, "ducts": true}
## Marks are drawn this much bigger, for the floor seen from above.
var scale_hint := 1.0
## The way to the car the creature has to take, while it is on a floor the
## survivors have left: what a hunter sees in blue (locust_player.lift_route),
## worked out again twice a second.
var lift_route := PackedVector3Array()
var lift_route_clock := 0.0
## The layer being drawn, for the creature's own marks: &"path", &"sight" or
## &"ducts".
var layer := &""

func setup(owner_level) -> void:
	name = "ObserverGizmos"
	level = owner_level
	# The marks are world points, and this hangs from the observer, which is
	# the camera and flies: under it they were moved and turned with the
	# camera, and over the plan they sat off by as much as the planta's middle.
	top_level = true
	var view := MeshInstance3D.new()
	view.name = "Lines"
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.no_depth_test = true
	paint.render_priority = 120
	view.material_override = paint
	add_child(view)

## A noise the floor made, to be drawn where it happened.
func note_noise(point: Vector3, radius: float) -> void:
	noises.append({"point": point, "radius": radius, "left": NOISE_TIME})

func _process(delta: float) -> void:
	# Nothing to draw over a floor that is being taken down or put up: the
	# marks of the one that went would hang over it while it is built.
	if level == null or level.manifest.is_empty() or not is_instance_valid(level.hotel) or not is_inside_tree() or level.session.state == level.session.State.LOADING:
		mesh.clear_surfaces()
		return
	remember(delta)
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	if shown.path: draw_creature()
	if shown.trails: draw_trails()
	if shown.noises: draw_noises(delta)
	if shown.doors: draw_doors()
	if shown.errand: draw_errand()
	if shown.sight: draw_sight()
	if shown.ducts: draw_ducts()
	mesh.surface_end()

## Where everybody has been, kept for a few seconds.
func remember(delta: float) -> void:
	trail_clock -= delta
	if trail_clock > 0.0: return
	trail_clock = TRAIL_EVERY
	var bodies: Array = level.survivors()
	if is_instance_valid(level.creature) and level.creature.is_inside_tree(): bodies.append(level.creature)
	for body in bodies:
		if not is_instance_valid(body): continue
		var key: int = body.get_instance_id()
		if not trails.has(key): trails[key] = {"points": [], "creature": body == level.creature}
		var points: Array = trails[key].points
		points.append(body.global_position)
		while points.size() > int(TRAIL_TIME / TRAIL_EVERY): points.pop_front()

## Only what is on the planta being looked at: the others are not drawn, and
## their marks would float in the air over this one.
func here(point: Vector3) -> bool:
	var view = level.get("observer_view")
	var planta: int = view.planta if view != null and is_instance_valid(view) else 0
	return FLOOR.planta_of(point.y) == planta

func line(from: Vector3, to: Vector3, colour: Color) -> void:
	mesh.surface_set_color(colour)
	mesh.surface_add_vertex(from)
	mesh.surface_set_color(colour)
	mesh.surface_add_vertex(to)

## A cross standing on the floor, so a mark is seen from above and from inside.
func mark(point: Vector3, colour: Color, plain_size := 0.5) -> void:
	var size: float = plain_size * scale_hint
	line(point + Vector3(-size, 0.05, 0), point + Vector3(size, 0.05, 0), colour)
	line(point + Vector3(0, 0.05, -size), point + Vector3(0, 0.05, size), colour)
	line(point + Vector3(0, 0.05, 0), point + Vector3(0, 0.05 + size * 2.0, 0), colour)

func ring(point: Vector3, radius: float, colour: Color, steps := 24) -> void:
	var before := point + Vector3(radius, 0.06, 0)
	for step in range(1, steps + 1):
		var angle := TAU * step / steps
		var next := point + Vector3(cos(angle), 0, sin(angle)) * radius + Vector3(0, 0.06, 0)
		line(before, next, colour)
		before = next

func draw_creature() -> void:
	var creature = level.creature
	if not is_instance_valid(creature) or not creature.is_inside_tree() or not here(creature.global_position): return
	lift_route_clock -= get_process_delta_time()
	if lift_route_clock <= 0.0:
		lift_route_clock = 0.5
		var car: int = level.lifts.creature_car(level.session.stage)
		lift_route = FLOOR.navigation_path(level.get_world_3d().navigation_map, creature.global_position, level.hotel.lifts[car]) if car >= 0 and car < level.hotel.lifts.size() else PackedVector3Array()
	for i in range(1, lift_route.size()): line(lift_route[i - 1] + Vector3(0, 0.2, 0), lift_route[i] + Vector3(0, 0.2, 0), COLOURS.lift_route)
	# Its way, where it is going and what it last knew, the director's lead.
	layer = &"path"
	creature.draw_gizmos(self)

func draw_trails() -> void:
	for key in trails:
		var points: Array = trails[key].points
		var colour: Color = COLOURS.creature_trail if trails[key].creature else COLOURS.trail
		for index in range(1, points.size()):
			if not here(points[index]) or not here(points[index - 1]): continue
			var fade: float = float(index) / maxf(float(points.size()), 1.0)
			line(points[index - 1] + Vector3(0, 0.08, 0), points[index] + Vector3(0, 0.08, 0), Color(colour, fade))

func draw_noises(delta: float) -> void:
	for entry in noises.duplicate():
		entry.left -= delta
		if entry.left <= 0.0:
			noises.erase(entry)
			continue
		var fade: float = entry.left / NOISE_TIME
		if here(entry.point): ring(entry.point, entry.radius * (1.0 - fade) + 0.4, Color(COLOURS.noise, fade), 20)

func draw_doors() -> void:
	for door in level.hotel.doors:
		if not is_instance_valid(door) or not here(door.doorway): continue
		var colour: Color = COLOURS.locked if door.locked else (COLOURS.door if door.opened else COLOURS.shut)
		mark(door.doorway, colour, 0.35)
	for hide in get_tree().get_nodes_in_group("hotel_hides"):
		if here(hide.global_position): mark(hide.global_position, Color(COLOURS.hide, 1.0 if is_instance_valid(hide.occupant) else 0.45), 0.3)
	for index in level.hotel.lifts.size():
		if here(level.hotel.lifts[index]): ring(level.hotel.lifts[index], 1.4, Color(COLOURS.lift, 0.35 if level.lifts.lift_gone(index) else 1.0), 16)
	for arrival in level.hotel.arrivals:
		if arrival != Vector3.ZERO and here(arrival): ring(arrival, 0.8, Color(COLOURS.lift, 0.6), 12)

func draw_errand() -> void:
	for index in level.televisions.size():
		var set = level.televisions[index]
		if not is_instance_valid(set) or not here(set.global_position): continue
		var stage_now: bool = int(set.stage) == int(level.session.stage)
		mark(set.global_position, Color(COLOURS.tv, 1.0 if set.on else (0.6 if stage_now else 0.2)), 0.4)
	for piece in level.containers:
		if is_instance_valid(piece) and piece.digit >= 0 and here(piece.global_position): mark(piece.global_position, Color(COLOURS.digit, 0.3 if piece.searched else 1.0), 0.35)
	for document in get_tree().get_nodes_in_group("hotel_documents"):
		if here(document.global_position): mark(document.global_position, COLOURS.document, 0.25)

## The ducts of a creature that has them (The Lurker): drawn on the planta
## looked at, wherever it is.
func draw_ducts() -> void:
	var creature = level.creature
	if not is_instance_valid(creature) or not creature.is_inside_tree(): return
	layer = &"ducts"
	creature.draw_gizmos(self)

## What the creature can see: the edges of its cone, and a line to whoever it
## is after while it can see them.
func draw_sight() -> void:
	var creature = level.creature
	# Asking what it can see is a question for the physics of a floor that is
	# being played, and it answers with rays.
	if not is_instance_valid(creature) or not creature.is_inside_tree() or not here(creature.global_position): return
	if level.session.state != level.session.State.PLAYING: return
	# Watching a recording, what it saw is what was recorded (bot_replay.gd
	# draws it): asked now, the rays would make it up from puppets.
	if level.replaying: return
	layer = &"sight"
	creature.draw_gizmos(self)
