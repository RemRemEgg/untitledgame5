@tool
class_name LevelBody
extends RigidBody3D

@export var is_static: bool = true:
	set(value):
		is_static = value
		freeze = is_static
		update_bodytype()
enum Type {SOLID, SCAFFOLD, BREAKABLE}
@export var bodytype: Type = Type.SOLID:
	set(value):
		bodytype = value
		update_bodytype()

@export var c_shape: Shape3D

func _init() -> void:
	if Engine.is_editor_hint(): update_bodytype()

func update_bodytype() -> void:
	freeze = is_static
	if $mesh: update_mesh_look($mesh)

func update_mesh_look(mesh: MeshInstance3D) -> void:
	match bodytype:
		Type.SOLID:
			mesh.material_override = preload("res://shaders/tile.res")
		Type.SCAFFOLD:
			mesh.material_override = preload("res://shaders/overdraw.res")
		Type.BREAKABLE:
			mesh.material_override = null
