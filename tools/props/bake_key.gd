extends SceneTree
## The key of the electrical panels (the author's download, 22 October 2026:
## Sketchfab, "Key chain"): its FBX in source_assets/props/key_chain/ (outside
## git, with its 2048 maps; tools/props/prepare_key_textures.py brings them
## down to 512 in assets/props/hotel/key_chain/, the occlusion, roughness and
## metal packed in one, as the other models are). Baked into
## assets/props/hotel/key_chain.res:
## the key and its ring in one mesh, lying flat with its blade along +Z from
## the ring, the ring's middle at the origin, and as long as a real one (the
## download is a few centimetres short of a fingertip).
##   godot --headless --path . --script res://tools/props/bake_key.gd
const SOURCE := "res://source_assets/props/key_chain/KeyChain.FBX"
const TARGET := "res://assets/props/hotel/key_chain.res"
const FOLDER := "res://assets/props/hotel/key_chain/"
## From the far side of the ring to the tip of the blade, in metres.
const LENGTH := 0.075

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var document := FBXDocument.new()
	var state := FBXState.new()
	if document.append_from_file(ProjectSettings.globalize_path(SOURCE), state) != OK:
		print("KEY_FAILED (fbx)")
		quit(1)
		return
	var nodes: Array = state.get_nodes()
	var meshes: Array = state.get_meshes()
	# Each node's place, through its parents.
	var placed := {}
	var parts := {}
	for index in nodes.size():
		var node: GLTFNode = nodes[index]
		if node.mesh < 0: continue
		var xform: Transform3D = node.xform
		var parent := node.parent
		while parent >= 0:
			xform = (nodes[parent] as GLTFNode).xform * xform
			parent = (nodes[parent] as GLTFNode).parent
		placed[String(node.original_name)] = [(meshes[node.mesh] as GLTFMesh).mesh.get_mesh(), xform]
	if not placed.has("Key") or not placed.has("KeyRing"):
		print("KEY_FAILED (parts) ", placed.keys())
		quit(1)
		return
	# Where the ring and the blade are, as the download has them.
	var ring := bounds(placed.KeyRing[0], placed.KeyRing[1])
	var whole := ring.merge(bounds(placed.Key[0], placed.Key[1]))
	var along: Vector3 = (whole.get_center() - ring.get_center()).normalized()
	# Turned so the blade runs along +Z from the ring, lying flat, scaled to
	# LENGTH, the ring's middle at the origin.
	var turn := Basis(Quaternion(along, Vector3.BACK)) if along.length() > 0.5 else Basis.IDENTITY
	var size := whole.size
	var fit := LENGTH / maxf(size.x, maxf(size.y, size.z))
	var to_origin := Transform3D(turn.scaled(Vector3.ONE * fit), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -ring.get_center())
	var material := ORMMaterial3D.new()
	material.albedo_texture = load(FOLDER + "key_chain_albedo.jpg")
	material.orm_texture = load(FOLDER + "key_chain_orm.jpg")
	material.normal_enabled = true
	material.normal_texture = load(FOLDER + "key_chain_normal.png")
	ResourceSaver.save(material, FOLDER + "key_chain.tres")
	material = load(FOLDER + "key_chain.tres")
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for name in ["Key", "KeyRing"]:
		var mesh: Mesh = placed[name][0]
		for surface in mesh.get_surface_count(): tool.append_from(mesh, surface, to_origin * (placed[name][1] as Transform3D))
	tool.index()
	tool.generate_tangents()
	tool.set_material(material)
	var result := tool.commit()
	result.resource_name = "key_chain"
	ResourceSaver.save(result, TARGET)
	print("KEY size=%s blade=%s" % [result.get_aabb().size, along])
	quit(0)

static func bounds(mesh: Mesh, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for surface in mesh.get_surface_count():
		for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = xform * vertex
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box
