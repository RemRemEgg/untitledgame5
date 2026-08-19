@tool
class_name BuildTool
extends EditorPlugin

static var inst: BuildTool

func _enable_plugin() -> void:
	pass
func _disable_plugin() -> void:
	pass
func _enter_tree() -> void:
	add_node_3d_gizmo_plugin(levelbodyplugin)
	inst = self
	print(&"build tools added to editor")
func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(levelbodyplugin)


var levelbodyplugin := LevelBodyPlugin.new()
class LevelBodyPlugin extends EditorNode3DGizmoPlugin:
	const IDENTITY_HANDLES: PackedVector3Array = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)]
	var handles: PackedVector3Array
	var init_value: Vector3
	var init_trans: Transform3D
	
	
	func _get_gizmo_name() -> String: return &"LevelBody"
	
	
	func _has_gizmo(node: Node3D) -> bool:
		return (node is LevelBody) && (node as LevelBody).mesh is BoxMesh
	
	
	func _init() -> void:
		create_handle_material(&"levelbody_handles")
		handles = IDENTITY_HANDLES
	
	
	func _redraw(gizmo: EditorNode3DGizmo) -> void:
		gizmo.clear()
		var mesh := (gizmo.get_node_3d() as LevelBody).mesh as BoxMesh
		var hndls: Array[Vector3]
		for i in 3:
			var vec := Vector3.ZERO
			vec[i] = mesh.size[i] / 2.0
			hndls.push_back(vec)
			hndls.push_back(-vec)
		
		gizmo.add_handles(hndls, get_material(&"levelbody_handles", gizmo), [])
	
	
	func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
		match handle_id:
			0, 1: return &"X Size"
			2, 3: return &"Y Size"
			4, 5: return &"Z Size"
		return &""
	
	
	func _get_handle_value(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
		#return ((gizmo.get_node_3d() as LevelBody).mesh as BoxMesh).size[handle_id]
		return ((gizmo.get_node_3d() as LevelBody).mesh as BoxMesh).size
	
	
	func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
		init_value = _get_handle_value(gizmo, handle_id, secondary) as Vector3
		init_trans = gizmo.get_node_3d().global_transform
	
	
	func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
		# mostly translated from godots built-in meshinstance3d gizmos
		var r_origin := camera.project_ray_origin(screen_pos)
		var r_dir := camera.project_ray_normal(screen_pos)
		var inv := init_trans.affine_inverse()
		var rseg: Array[Vector3] = [inv * r_origin, inv * (r_origin + r_dir*4096.0)]
		var box_size: Vector3
		var box_pos: Vector3
		
		# start helper
		var axis := int(handle_id / 2.0) # axis 0,1,2
		var asign := (handle_id%2 * -2) + 1 # sign -1,1
		var init_size := init_value
		var neg := init_size[axis] * -0.5
		var pos := init_size[axis] * 0.5
		var cpos_a := Vector3.ZERO
		cpos_a[axis] = 4096.0
		var cpos_b := Vector3.ZERO
		cpos_b[axis] = -4096.0
		var cseg := Geometry3D.get_closest_points_between_segments(cpos_a, cpos_b, rseg[0], rseg[1])
		
		# new size
		box_size = init_size
		if Input.is_key_pressed(KEY_ALT):
			box_size[axis] = cseg[0][axis] * asign * 2
		else:
			box_size[axis] = (cseg[0][axis] - neg) if (asign > 0) else (pos - cseg[0][axis])
		if EditorInterface.is_node_3d_snap_enabled():
			box_size[axis] = snappedf(box_size[axis], EditorInterface.get_node_3d_translate_snap())
		box_size[axis] = maxf(box_size[axis], 0.001)
		
		# new position
		if Input.is_key_pressed(KEY_ALT):
			box_pos = init_trans.origin
		else:
			if asign >0:
				pos = neg + box_size[axis]
			else:
				neg = pos - box_size[axis]
			var offset := Vector3.ZERO
			offset[axis] = (pos + neg) * 0.5
			box_pos = init_trans * offset
		
		var lvlb := gizmo.get_node_3d() as LevelBody
		var mesh := lvlb.mesh as BoxMesh
		mesh.size = box_size
		lvlb.position = box_pos
	
	
	func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _restore: Variant, cancel: bool) -> void:
		var lvlb := gizmo.get_node_3d() as LevelBody
		var mesh := lvlb.mesh as BoxMesh
		
		if cancel:
			mesh.size = init_value
			lvlb.position = init_trans.origin
		
		var udrd := BuildTool.inst.get_undo_redo()
		udrd.create_action(&"Change LevelBody Size")
		udrd.add_do_property(mesh, &"size", mesh.size)
		udrd.add_do_property(lvlb, &"position", lvlb.position)
		udrd.add_undo_property(mesh, &"size", init_value)
		udrd.add_undo_property(lvlb, &"position", init_trans.origin)
		udrd.commit_action()
