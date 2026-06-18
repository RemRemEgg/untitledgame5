class_name Trail
extends MeshInstance3D

var _points: Array[Vector3] = []
var _life: Array[float] = []
var ppos: Vector3


func _ready() -> void:
	ppos = global_position
	mesh = ImmediateMesh.new()
	_points.append(global_position)
	_life.append(0.0)


func _process(delta: float) -> void:
	var dist := (ppos - global_position).length_squared()
	if dist > 0.01:
		_points.append(global_position)
		_life.append(0.0)
		ppos = global_position
		if dist > 128**2:
			_points.clear()
			_life.clear()
	
	var p := 0
	while p < _points.size():
		_life[p] += delta
		if _life[p] > 0.15:
			_points.remove_at(p)
			_life.remove_at(p)
		else: p += 1
	
	var imesh := mesh as ImmediateMesh
	imesh.clear_surfaces()
	if _points.size() < 2: return
	
	imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(_points.size()):
		var t := (i + 1.0) / (_points.size())
		var w := t * Vector3.UP * 0.07
		
		imesh.surface_set_uv(Vector2(0, 0))
		imesh.surface_add_vertex(to_local(_points[i] + w))
		imesh.surface_set_uv(Vector2(1, 0))
		imesh.surface_add_vertex(to_local(_points[i] - w))
	imesh.surface_end()
