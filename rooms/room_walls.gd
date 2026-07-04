class_name RoomWalls
extends Node3D


@onready var ceilingsb: LevelBody = $ceiling as LevelBody
@onready var floorsb: LevelBody = $floor as LevelBody
@onready var light_orb: LevelBody = $light_orb as LevelBody


func _ready() -> void:
	Util.remove_and_free($bounds_visualizer)
	ceilingsb.visible = true
	floorsb.visible = true


func _process(delta: float) -> void:
	if Network.is_server:
		light_orb.apply_central_impulse(Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1)) * delta*5.0)
