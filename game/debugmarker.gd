class_name DebugMarker
extends MeshInstance3D

static var MESH: SphereMesh

static func _static_init() -> void:
	MESH = SphereMesh.new()
	MESH.height = 0.5
	MESH.radius = 0.25
	MESH.radial_segments = 8
	MESH.rings = 4


static func mark_location(pos: Vector3, color: Color = Color.AQUA, duration: float = 4.0) -> DebugMarker:
	var dm := DebugMarker.new(pos, color, duration)
	Game.world.add_child(dm)
	return dm


var time: float = 0.0

func _init(pos: Vector3, color: Color, duration: float) -> void:
	global_position = pos
	time = duration
	mesh = MESH
	var sm := StandardMaterial3D.new()
	sm.albedo_color = color
	material_override = sm


func _process(delta: float) -> void:
	time -= delta
	if time <= 0.0:
		Util.remove_and_free(self)
