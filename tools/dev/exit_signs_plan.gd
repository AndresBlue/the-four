extends SceneTree
## A planta drawn from above with its way-out signs: corridors grey, other
## circulation green-grey, rooms brown, the refuge red, the way in blue, a
## yellow dot for each connection, and each sign as a green arrow the way out
## with a white bar across the way it hangs.
##   godot --headless --path . --script res://tools/dev/exit_signs_plan.gd -- --seed=81 --planta=0
## Writes evidence/signs_plan_s<seed>_p<planta>.png.
const GEN := preload("res://game/world/generation/map_generator.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SIGNS := preload("res://game/world/generation/exit_route_signs.gd")
const SCALE := 4.0
func _initialize() -> void:
	var seed_value := 81
	var planta := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed_value = int(a.trim_prefix("--seed="))
		if a.begins_with("--planta="): planta = int(a.trim_prefix("--planta="))
	var m: Dictionary = GEN.new().generate(seed_value)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for room in m.rooms:
		if int(room.wing) != planta or FLOOR.is_void(room): continue
		var p := FLOOR.position_of(room)
		var h := FLOOR.size_of(room) * 0.5
		lo = Vector2(minf(lo.x, p.x - h.x), minf(lo.y, p.z - h.y))
		hi = Vector2(maxf(hi.x, p.x + h.x), maxf(hi.y, p.z + h.y))
	var img := Image.create(int((hi.x - lo.x) * SCALE) + 20, int((hi.y - lo.y) * SCALE) + 20, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.1))
	var to_px := func(p: Vector3) -> Vector2: return Vector2((p.x - lo.x) * SCALE + 10, (p.z - lo.y) * SCALE + 10)
	var refuge := int(m.refuges[planta])
	var entry := FLOOR.entry_of(m, planta)
	for room in m.rooms:
		if int(room.wing) != planta or FLOOR.is_void(room): continue
		var p := FLOOR.position_of(room)
		var h := FLOOR.size_of(room) * 0.5
		var c := Color(0.35, 0.3, 0.25)
		if bool(room.corridor): c = Color(0.55, 0.55, 0.6)
		elif SIGNS.circulation(room): c = Color(0.45, 0.5, 0.45)
		if int(room.id) == refuge: c = Color(0.9, 0.2, 0.2)
		if int(room.id) == entry: c = Color(0.2, 0.4, 0.95)
		var a: Vector2 = to_px.call(p - Vector3(h.x, 0, h.y))
		var b: Vector2 = to_px.call(p + Vector3(h.x, 0, h.y))
		img.fill_rect(Rect2i(Vector2i(a) + Vector2i(1, 1), Vector2i(b - a) - Vector2i(2, 2)), c)
	# connections
	for id in m.adjacency.size():
		var room: Dictionary = m.rooms[id]
		if int(room.wing) != planta or FLOOR.is_void(room): continue
		for o in m.adjacency[id]:
			var other: Dictionary = m.rooms[int(o)]
			var mid: Vector2 = (to_px.call(FLOOR.position_of(room)) + to_px.call(FLOOR.position_of(other))) * 0.5
			img.fill_rect(Rect2i(Vector2i(mid) - Vector2i(2, 2), Vector2i(4, 4)), Color(0.9, 0.85, 0.5))
	for sign in SIGNS.planta_signs(m, planta):
		var at: Vector2 = to_px.call(FLOOR.position_of(m.rooms[int(sign.room)]))
		var way := Vector2(sign.way)
		for t in 40:
			var q := at + way * float(t)
			img.fill_rect(Rect2i(Vector2i(q) - Vector2i(3, 3), Vector2i(6, 6)), Color(0.1, 1.0, 0.4))
		var side := Vector2(-way.y, way.x)
		for t in 14:
			for sgn in [-1.0, 1.0]:
				var q2: Vector2 = at + way * 40.0 - way * float(t) + side * float(t) * sgn
				img.fill_rect(Rect2i(Vector2i(q2) - Vector2i(2, 2), Vector2i(4, 4)), Color(0.1, 1.0, 0.4))
		var n := Vector2(sign.normal)
		var nside := Vector2(-n.y, n.x)
		for t in range(-12, 13):
			var q3 := at + nside * float(t)
			img.fill_rect(Rect2i(Vector2i(q3) - Vector2i(1, 1), Vector2i(3, 3)), Color(1, 1, 1))
	img.save_png("res://evidence/signs_plan_s%d_p%d.png" % [seed_value, planta])
	print("ok")
	quit()
