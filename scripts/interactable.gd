extends StaticBody3D

var kind := ""
var item_id := ""
var door_leaf: StaticBody3D
var door_shape: CollisionShape3D
var closed_position := Vector3.ZERO
var opened := false
var moving := false
var motion: Tween
var indicators: Array[MeshInstance3D] = []

func prompt(session) -> String:
	match kind:
		"fuse": return "E  RECOGER FUSIBLE"
		"door":
			if moving: return "PUERTA EN MOVIMIENTO"
			return "E  CERRAR PUERTA" if opened else "E  ABRIR  /  MANTENER E  APERTURA LENTA"
		"panel":
			if not session.carried.is_empty(): return "E  INSTALAR FUSIBLE  ·  %d EN INVENTARIO" % session.carried.size()
			if session.installed.size() == 3: return "MANTENER E  ARRANCAR ASCENSOR · 3 S"
			return "FALTAN %d FUSIBLES  ·  EXPLORA LAS SALAS" % (3 - session.installed.size())
	return ""

func activate(session, slow := false) -> bool:
	if session.state != session.State.PLAYING:
		return false
	match kind:
		"fuse":
			if not visible or not session.collect_fuse(item_id): return false
			visible = false
			collision_layer = 0
			return true
		"panel": return session.install_fuse()
		"door": return toggle_door(slow)
	return false

func doorway_occupied() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = door_shape.shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, closed_position) * door_shape.transform
	query.exclude = [get_rid(), door_leaf.get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		if hit.collider is CharacterBody3D:
			return true
	return false

func toggle_door(slow := false) -> bool:
	if moving or (opened and doorway_occupied()):
		return false
	moving = true
	var will_open := not opened
	door_shape.set_deferred("disabled", true)
	motion = create_tween()
	motion.tween_property(door_leaf, "position", closed_position + Vector3(0, 2.9 if will_open else 0.0, 0), 1.2 if slow else 0.45)
	motion.finished.connect(func():
		if not will_open and doorway_occupied():
			door_leaf.position = closed_position + Vector3(0, 2.9, 0)
			opened = true
		else:
			opened = will_open
		moving = false
		door_shape.set_deferred("disabled", opened)
	)
	return true

func reset_item() -> void:
	visible = true
	collision_layer = 1
	if kind == "door":
		if is_instance_valid(motion): motion.kill()
		opened = false
		moving = false
		door_leaf.position = closed_position
		door_shape.set_deferred("disabled", false)

func update_indicators(count: int) -> void:
	for i in indicators.size():
		var mat: StandardMaterial3D = indicators[i].material_override
		mat.albedo_color = Color(0.35, 0.8, 0.5) if i < count else Color(0.32, 0.12, 0.08)
		mat.emission = mat.albedo_color
