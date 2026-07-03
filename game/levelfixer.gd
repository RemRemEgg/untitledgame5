@tool
class_name LevelFixer
extends EditorScript

func to_key(v:Vector3, i:Variant) -> Vector4: return Vector4(v.x, v.y, v.z, hash(i))
func key_size(v:Vector4) -> Vector3: return Vector3(v.x, v.y, v.z)
var root: Node
var col_list: Dictionary[Vector4, Shape3D]
var mesh_list: Dictionary[Vector4, Mesh]

var mat_normal := load("res://shaders/tile.res") as ShaderMaterial

func _run() -> void:
	print(&"Fixing level...")
	root = EditorInterface.get_edited_scene_root()
	if !(root is Level || root is Room):
		printerr(&"This scene is not a level/room!")
		return
	
	scan_node(root)
	EditorInterface.mark_scene_as_unsaved()
	
	print(&"Fixer Complete")


func scan_node(node: Node) -> void:
	var is_subscene := (node != root) && (node.owner != root)
	if is_subscene || node.name == &"bounds":
		print(&"Node '%s' is subscene, skipping" % node.name)
		return
	
	if node is LevelBody:
		fix_levelbody(node as LevelBody)
		return
	
	for child in node.get_children():
		scan_node(child)


func fix_levelbody(body: LevelBody) -> void:
	var scale := body.scale
	body.scale = Vector3.ONE
	
	if !body.mesh: body.mesh = BoxMesh.new()
	
	if body.mesh is BoxMesh:
		scale *= (body.mesh as BoxMesh).size
		body.mesh = get_mesh(scale, BoxMesh)
		body.shape = get_collider(scale, BoxShape3D)
		body.mass = scale.x * scale.y * scale.z * 0.2
	
	body.update_display()

func get_mesh(size: Vector3, type: Variant) -> Mesh:
	var key := to_key(size, type)
	if mesh_list.has(key): return mesh_list[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_list[key] = mesh
	return mesh

func get_collider(size: Vector3, type: Variant) -> Shape3D:
	var key := to_key(size, type)
	if col_list.has(key): return col_list[key]
	var shape := BoxShape3D.new()
	shape.size = size
	col_list[key] = shape
	return shape
