class_name Trail
extends MeshInstance3D

var _points: Array[Vector3] = []
var _life: Array[float] = []
var ppos: Vector3
var kill_when_gone: bool = false


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
	if kill_when_gone && _points.is_empty():
		Util.remove_and_free(self)
	
	var imesh := mesh as ImmediateMesh
	imesh.clear_surfaces()
	if _points.size() < 2: return
	
	imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var ps := _points.size()
	for i in ps:
		var t := (i * 2.0) / (ps - 1.0)
		imesh.surface_set_uv(Vector2(1, t))
		imesh.surface_add_vertex(to_local(_points[i]))
		imesh.surface_set_uv(Vector2(-1, -t))
		imesh.surface_add_vertex(to_local(_points[i]))
	imesh.surface_end()


func unbind() -> void:
	kill_when_gone = true
	var p := get_parent()
	if p:
		p.remove_child(self)
		owner = null
		Game.world.visuals.add_child(self)
		global_position = ppos
