@tool
class_name LevelFixer
extends EditorScript

var root: Node
var col_list: Dictionary[Vector3, Shape3D]
var mesh_list: Dictionary[Vector3, Mesh]

var mat_normal := load("res://shaders/tile.res") as ShaderMaterial

func _run() -> void:
	print(&"Fixing level...")
	root = EditorInterface.get_edited_scene_root()
	if root is not Level:
		printerr(&"This scene is not a level!")
		return
	
	scan_node(root)
	EditorInterface.mark_scene_as_unsaved()
	
	print(&"Fixer Complete")


func scan_node(node: Node) -> void:
	var is_subscene := (node != root) && (node.owner != root)
	if is_subscene || node.name == &"bounds":
		print(&"Node '%s' is subscene, skipping" % node.name)
		return
	
	for child in node.get_children():
		scan_node(child)
	
	if node is LevelBody:
		var lvlb := node as LevelBody
		var meshes := node.find_children(&"*", &"MeshInstance3D")
		if meshes.size() > 1:
			push_warning(&"Node '%s' has too many mesh children, cannot fix" % node.name)
			return
		if meshes.size() == 0: return
		var meshnode := meshes[0] as MeshInstance3D
		var mesh := meshnode.mesh
		var p_basis := lvlb.transform * meshnode.transform
		meshnode.transform = Transform3D.IDENTITY
		lvlb.transform = p_basis
		lvlb.scale = Vector3.ONE
		if mesh is BoxMesh:
			var size: Vector3 = p_basis.basis.get_scale() * (mesh as BoxMesh).size
			size = size.snapped(Vector3.ONE * 0.01)
			meshnode.mesh = get_mesh(size)
			lvlb.update_mesh_look(meshnode)
			var cols := lvlb.find_children(&"*", &"CollisionShape3D")
			for col in cols:
				lvlb.remove_child(col)
				col.free()
			var coll := get_collider(size)
			lvlb.add_child(coll)
			coll.owner = root
		else:
			push_warning(&"Node '%s' has mesh of type '%s' which cannot be fixed" % [node.name, mesh.get_class()])
	


func get_mesh(size: Vector3) -> Mesh:
	if mesh_list.has(size): return mesh_list[size]
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_list[size] = mesh
	return mesh

func get_collider(size: Vector3) -> CollisionShape3D:
	var coll := CollisionShape3D.new()
	coll.name = &"collider"
	if col_list.has(size): 
		coll.shape = col_list[size]
		return coll
	var shape := BoxShape3D.new()
	shape.size = size
	coll.shape = shape
	col_list[size] = shape
	return coll
