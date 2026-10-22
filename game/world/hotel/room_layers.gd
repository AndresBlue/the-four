extends RefCounted
## Which render layer each room of a floor is on, for the lowest graphics
## preset (graphics_presets.gd static_light; hotel_geometry.gd, "Light that
## stays in its room").
##
## There no lamp casts a shadow, and a lamp without one shines through walls.
## So instead each lamp is told what it may light: every room has one of
## sixteen render layers (5 to 20), everything built in a room is on its
## room's layer, and a lamp lights that layer only. Two rooms may share a
## layer when no lamp of either can reach the other -- which is a map
## colouring, done here from the manifest alone, the same on every machine
## though nothing depends on that.
##
## Where a room runs on into the next with no wall between (a corridor, a
## salon), each cell's lamp lights its open neighbours as well, or every cell
## would be a pool of its own with a dark seam at its edge and a cell whose
## lamp is out would be cut off black across an open floor. That is a second
## condition on the colours (nothing else within that lamp's reach may be on
## an open neighbour's layer); the cells of one open space are given the same
## layer whenever they can be, which is what makes it easy to meet. Where it
## cannot be met the lamp just leaves that neighbour alone (`seams`). A lamp
## that could reach another room on its own layer would be a leak (`clashes`):
## tools/dev/light_layers_scan.gd looks for both over many seeds.
##
## A lift's car is a room of its own behind its lobby's wall, with its own
## lamp: the strip of the lobby cell behind the lift wall.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const FIRST := 4
const COUNT := 16
## Every bit a room can be on, and every bit there is.
const ROOMS := 0xFFFF0
const ALL := 0xFFFFF
## How far past its own cell a lamp put anywhere in a room may reach: the
## longest is a television's glow (hotel_television.RANGE).
const LATE_REACH := 8.0
## A car's lamp (hotel_geometry.box_light()), from the middle of its strip.
const CAR_REACH := 5.5

## A geometry's layers and a lamp's cull mask are never changed while Godot
## has the two paired. The renderer files which lamps reach which geometry by
## these very masks, and takes a pair out of its files only if the masks still
## match (renderer_scene_cull.cpp, _instance_pair and _instance_unpair; seen in
## 4.7.2): change one in between and the pair is never taken out -- the lamp
## keeps a pointer to a mesh, and the mesh to a lamp, after either is freed.
## It showed as "BUG, indexing did not unpair geometries from light" when a
## floor was left, and is a write into freed memory waiting for the next lamp
## whose projector changes or the next step of a body that casts shadows.
## Hidden, an instance is paired with nothing: hide, change, show. Only what
## is on layer 1 is ever touched: a body on layer 2 alone is one its own
## camera must not draw, and a room's bit would bring it into view.
static func put_on(mesh: GeometryInstance3D, bits: int) -> void:
	var layers := (mesh.layers & ~ROOMS) | bits
	if mesh.layers == layers or (mesh.layers & 1) == 0: return
	RenderingServer.instance_set_visible(mesh.get_instance(), false)
	mesh.layers = layers
	RenderingServer.instance_set_visible(mesh.get_instance(), mesh.is_visible_in_tree())

## An actor's mesh (a body's, the creature's) on a room's bits, as put_on()
## and with its protocol, also when it is not on layer 1: a mesh drawn on a
## layer of its own still takes its room's lamps on Muy bajo.
static func put_on_actor(mesh: GeometryInstance3D, bits: int) -> void:
	var layers := (mesh.layers & ~ROOMS) | bits
	if mesh.layers == layers: return
	RenderingServer.instance_set_visible(mesh.get_instance(), false)
	mesh.layers = layers
	RenderingServer.instance_set_visible(mesh.get_instance(), mesh.is_visible_in_tree())

static func light_only(light: Light3D, mask: int) -> void:
	if light.light_cull_mask == mask: return
	RenderingServer.instance_set_visible(light.get_instance(), false)
	light.light_cull_mask = mask
	RenderingServer.instance_set_visible(light.get_instance(), light.is_visible_in_tree())

## A ceiling lamp's range, from its room's footprint: it has to light the
## room's own corners.
static func lamp_range(span: Vector2) -> float:
	return maxf(10.0, maxf(span.x, span.y) * 0.85)

static func rect_of(room: Dictionary) -> Rect2:
	var span := FLOOR.size_of(room)
	var at := FLOOR.position_of(room)
	return Rect2(at.x - span.x * 0.5, at.z - span.y * 0.5, span.x, span.y)

## The strip of a lobby's cell its lift's car is in, or an empty one.
static func car_rect(room: Dictionary) -> Rect2:
	var wall := FLOOR.lift_wall(room)
	if wall == Vector2i.ZERO: return Rect2()
	var cell := rect_of(room)
	if wall.x != 0: return Rect2(cell.end.x - FLOOR.LIFT_DEPTH if wall.x > 0 else cell.position.x, cell.position.y, FLOOR.LIFT_DEPTH, cell.size.y)
	return Rect2(cell.position.x, cell.end.y - FLOOR.LIFT_DEPTH if wall.y > 0 else cell.position.y, cell.size.x, FLOOR.LIFT_DEPTH)

static func gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dz := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return Vector2(dx, dz).length()

static func reaches(lamp: Vector2, reach: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(lamp.x, rect.position.x, rect.end.x), clampf(lamp.y, rect.position.y, rect.end.y))
	return nearest.distance_to(lamp) < reach

## {layer: a bit per room (0 for a cell with nothing in it), mask: the bits
## each room's ceiling lamp lights, cars: room id -> the bit of its car,
## clashes, seams}.
static func assign(manifest: Dictionary) -> Dictionary:
	var rooms: Array = manifest.rooms
	# The things to colour: rooms, and after them the cars.
	var nodes: Array = []
	var node_of := {}
	for room in rooms:
		if FLOOR.is_void(room): continue
		var rect := rect_of(room)
		node_of[int(room.id)] = nodes.size()
		nodes.append({"room": int(room.id), "car": false, "planta": int(room.get("wing", 0)), "rect": rect, "lamp": rect.get_center(), "reach": lamp_range(rect.size), "open": [], "near": [], "colour": -1})
	for room in rooms:
		var strip := car_rect(room)
		if FLOOR.is_void(room) or strip.size == Vector2.ZERO: continue
		nodes.append({"room": int(room.id), "car": true, "planta": int(room.get("wing", 0)), "rect": strip, "lamp": strip.get_center(), "reach": CAR_REACH, "open": [], "near": [], "colour": -1})
	for pair in manifest.get("merged", []):
		if not node_of.has(int(pair[0])) or not node_of.has(int(pair[1])): continue
		var a: int = node_of[int(pair[0])]
		var b: int = node_of[int(pair[1])]
		nodes[a].open.append(b)
		nodes[b].open.append(a)
	# Who is within whose reach, planta by planta.
	var by_planta := {}
	for i in nodes.size():
		if not by_planta.has(nodes[i].planta): by_planta[nodes[i].planta] = []
		by_planta[nodes[i].planta].append(i)
	for planta in by_planta:
		var group: Array = by_planta[planta]
		for m in group.size():
			var a: Dictionary = nodes[group[m]]
			for n in range(m + 1, group.size()):
				var b: Dictionary = nodes[group[n]]
				if gap(a.rect, b.rect) < LATE_REACH or reaches(a.lamp, a.reach, b.rect) or reaches(b.lamp, b.reach, a.rect):
					a.near.append(group[n])
					b.near.append(group[m])
	# One open space after another, each from its lowest cell outwards, so a
	# space's cells are coloured one after the other and take the same colour.
	var order: Array = []
	var queued := {}
	for start in nodes.size():
		if queued.has(start): continue
		var queue := [start]
		queued[start] = true
		while not queue.is_empty():
			var i: int = queue.pop_front()
			order.append(i)
			for j in nodes[i].open:
				if not queued.has(j):
					queued[j] = true
					queue.append(j)
	var clashes := 0
	for v in order:
		var node: Dictionary = nodes[v]
		# Nobody in reach may be on this one's layer, unless it is one of the
		# cells it is open to.
		var hard := {}
		for k in node.near:
			if nodes[k].colour >= 0 and not k in node.open: hard[nodes[k].colour] = true
		# And for the lamps to light their open neighbours: nothing a
		# neighbour's lamp reaches may be on this layer, and this may not be
		# the layer of an open neighbour of a lamp that reaches it.
		var soft := hard.duplicate()
		for i in node.open:
			for k in nodes[i].near:
				if k != v and nodes[k].colour >= 0 and not k in nodes[i].open: soft[nodes[k].colour] = true
		for i in node.near:
			if i in node.open: continue
			for j in nodes[i].open:
				if j != v and nodes[j].colour >= 0: soft[nodes[j].colour] = true
		var wanted: Array = []
		for j in node.open:
			if nodes[j].colour >= 0 and not nodes[j].colour in wanted: wanted.append(nodes[j].colour)
		for colour in COUNT:
			if not colour in wanted: wanted.append(colour)
		for banned in [soft, hard]:
			for colour in wanted:
				if not banned.has(colour):
					node.colour = colour
					break
			if node.colour >= 0: break
		if node.colour < 0:
			# More rooms in reach than there are layers: the layer whose
			# nearest user is furthest away. A leak, and counted as one.
			clashes += 1
			var furthest := -1.0
			for colour in COUNT:
				var nearest := INF
				for k in node.near:
					if nodes[k].colour == colour: nearest = minf(nearest, gap(node.rect, nodes[k].rect))
				if nearest > furthest:
					furthest = nearest
					node.colour = colour
	var layer := PackedInt32Array()
	var mask := PackedInt32Array()
	layer.resize(rooms.size())
	mask.resize(rooms.size())
	var cars := {}
	var seams := 0
	for v in nodes.size():
		var node: Dictionary = nodes[v]
		var bit: int = 1 << (FIRST + int(node.colour))
		if node.car:
			cars[node.room] = bit
			continue
		layer[node.room] = bit
		var lit := bit
		for j in node.open:
			var free := true
			for k in node.near:
				if k != j and not k in node.open and nodes[k].colour == nodes[j].colour: free = false
			if free: lit |= 1 << (FIRST + int(nodes[j].colour))
			else: seams += 1
		mask[node.room] = lit
	return {"layer": layer, "mask": mask, "cars": cars, "clashes": clashes, "seams": seams}
