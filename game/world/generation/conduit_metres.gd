extends RefCounted
## Binary-heap Dijkstra over a conduit ({nodes, edges}: ducts or tubes) and bounded walking metres
## over the door graph. Used by the office generator, its validator, office_metrics and, in 1e,
## conduit_graph.gd.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")

## One list per node of [other, metres, kind], in the order of the edges: what
## every search below walks, built once so a search does not scan the edges.
static func adjacency(conduit: Dictionary, skip_kinds: Array = []) -> Array:
	var lists: Array = []
	for _node in conduit.nodes.size(): lists.append([])
	for edge in conduit.edges:
		var kind := String(edge[3])
		if skip_kinds.has(kind): continue
		var a := int(edge[0])
		var b := int(edge[1])
		lists[a].append([b, float(edge[2]), kind])
		lists[b].append([a, float(edge[2]), kind])
	return lists

## {node: metres} of every node within reach of `from` along the conduit. A
## heap, because the generator asks it hundreds of times a planta.
static func metres(conduit: Dictionary, from: int, reach: float = INF, skip_kinds: Array = []) -> Dictionary:
	var lists := adjacency(conduit, skip_kinds)
	var best := {from: 0.0}
	var heap: Array = []
	heap_push(heap, 0.0, from)
	while not heap.is_empty():
		var top := heap_pop(heap)
		var cost: float = top[0]
		var at: int = top[1]
		if cost > float(best[at]): continue
		for link in lists[at]:
			var next: int = link[0]
			var length: float = cost + float(link[1])
			if length > reach: continue
			if not best.has(next) or length < float(best[next]) - 0.0001:
				best[next] = length
				heap_push(heap, length, next)
	return best

## How many separate pieces the given nodes make, joined only by edges whose
## two ends are among them: a duct cut in two is two pieces.
static func pieces(conduit: Dictionary, nodes: Array, skip_kinds: Array = []) -> int:
	if nodes.is_empty(): return 0
	var inside := {}
	for node in nodes: inside[int(node)] = true
	var lists := adjacency(conduit, skip_kinds)
	var seen := {}
	var count := 0
	for node in nodes:
		var start := int(node)
		if seen.has(start): continue
		count += 1
		seen[start] = true
		var open: Array = [start]
		while not open.is_empty():
			var at: int = open.pop_back()
			for link in lists[at]:
				var next: int = link[0]
				if inside.has(next) and not seen.has(next):
					seen[next] = true
					open.append(next)
	return count

## {room: metres} of the rooms within limit of `from` walking the door graph,
## measured as FLOOR.route_metres() does; a heap, where route_metres is O(n²).
static func walk_within(rooms: Array, adjacency: Array, from: int, limit: float) -> Dictionary:
	var best := {from: 0.0}
	var heap: Array = []
	heap_push(heap, 0.0, from)
	while not heap.is_empty():
		var top := heap_pop(heap)
		var cost: float = top[0]
		var at: int = top[1]
		if cost > float(best[at]): continue
		var here := FLOOR.position_of(rooms[at])
		for other in adjacency[at]:
			var next := int(other)
			var length: float = cost + here.distance_to(FLOOR.position_of(rooms[next]))
			if length > limit: continue
			if not best.has(next) or length < float(best[next]) - 0.0001:
				best[next] = length
				heap_push(heap, length, next)
	return best

## Walking metres from one room's middle to another's as a person walks them:
## to the middle of a doorway, straight across each room from doorway to
## doorway, and on to the other's middle; INF past limit or out of reach. A
## loose duct link is measured against this (OFICINAS 11.3), not walk_within's
## centre to centre, which zigzags through every room on the way.
static func door_metres(rooms: Array, adjacency: Array, from: int, to: int, limit: float = INF) -> float:
	if from == to: return 0.0
	var doors: Array = []
	var index := {}
	var door_at := func(a: int, b: int) -> int:
		var key := mini(a, b) * 65536 + maxi(a, b)
		if not index.has(key):
			index[key] = doors.size()
			doors.append([mini(a, b), maxi(a, b), FLOOR.portal_between(rooms[mini(a, b)], rooms[maxi(a, b)])])
		return int(index[key])
	var target := FLOOR.position_of(rooms[to])
	var best := {}
	var heap: Array = []
	var start := FLOOR.position_of(rooms[from])
	for n in adjacency[from]:
		var d: int = door_at.call(from, int(n))
		var cost := start.distance_to(doors[d][2])
		if cost <= limit and cost < float(best.get(d, INF)):
			best[d] = cost
			heap_push(heap, cost, d)
	while not heap.is_empty():
		var top := heap_pop(heap)
		var cost: float = top[0]
		var at: int = top[1]
		if at < 0: return cost
		if cost > float(best.get(at, INF)): continue
		var here: Vector3 = doors[at][2]
		for room in [int(doors[at][0]), int(doors[at][1])]:
			if room == to:
				var done := cost + here.distance_to(target)
				if done <= limit: heap_push(heap, done, -1)
			for n in adjacency[room]:
				var d: int = door_at.call(room, int(n))
				if d == at: continue
				var step := cost + here.distance_to(doors[d][2])
				if step <= limit and step < float(best.get(d, INF)) - 0.0001:
					best[d] = step
					heap_push(heap, step, d)
	return INF

## The doors of a floor once, for door_metres_all(): {doors: [[a, b, point]],
## of: [door ids of each room]}, every middle of a doorway where
## FLOOR.portal_between() puts it.
static func door_graph(rooms: Array, adjacency: Array) -> Dictionary:
	var doors: Array = []
	var of: Array = []
	var index := {}
	for room in rooms: of.append([])
	for a in adjacency.size():
		for n in adjacency[a]:
			var b := int(n)
			var key := mini(a, b) * 65536 + maxi(a, b)
			if not index.has(key):
				index[key] = doors.size()
				doors.append([mini(a, b), maxi(a, b), FLOOR.portal_between(rooms[mini(a, b)], rooms[maxi(a, b)])])
			of[a].append(int(index[key]))
	return {"doors": doors, "of": of}

## door_metres() from one room to every room within limit, at once, over a
## door_graph(): {room: metres}, the room itself at 0.
static func door_metres_all(rooms: Array, graph: Dictionary, from: int, limit: float = INF) -> Dictionary:
	var doors: Array = graph.doors
	var of: Array = graph.of
	var centres := {}
	var reached := {from: 0.0}
	var best := {}
	var heap: Array = []
	var start := FLOOR.position_of(rooms[from])
	for d in of[from]:
		var cost := start.distance_to(doors[d][2])
		if cost <= limit and cost < float(best.get(d, INF)):
			best[d] = cost
			heap_push(heap, cost, d)
	while not heap.is_empty():
		var top := heap_pop(heap)
		var cost: float = top[0]
		var at: int = top[1]
		if cost > float(best.get(at, INF)): continue
		var here: Vector3 = doors[at][2]
		for side in 2:
			var room: int = doors[at][side]
			if not centres.has(room): centres[room] = FLOOR.position_of(rooms[room])
			var there := cost + here.distance_to(centres[room])
			if there <= limit and there < float(reached.get(room, INF)): reached[room] = there
			for d in of[room]:
				if d == at: continue
				var step := cost + here.distance_to(doors[d][2])
				if step <= limit and step < float(best.get(d, INF)) - 0.0001:
					best[d] = step
					heap_push(heap, step, d)
	return reached

## Puts [cost, id] on the heap; ties go to the lower id, so searches are the
## same on every machine.
static func heap_push(heap: Array, cost: float, id: int) -> void:
	heap.append([cost, id])
	var at := heap.size() - 1
	while at > 0:
		var parent := (at - 1) / 2
		if not before(heap[at], heap[parent]): break
		var held: Array = heap[at]
		heap[at] = heap[parent]
		heap[parent] = held
		at = parent

## Takes the cheapest [cost, id] off the heap.
static func heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty(): return top
	heap[0] = last
	var at := 0
	while true:
		var left := at * 2 + 1
		var right := left + 1
		var least := at
		if left < heap.size() and before(heap[left], heap[least]): least = left
		if right < heap.size() and before(heap[right], heap[least]): least = right
		if least == at: break
		var held: Array = heap[at]
		heap[at] = heap[least]
		heap[least] = held
		at = least
	return top

## (cost, id) in lexicographic order.
static func before(a: Array, b: Array) -> bool:
	return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1]))
