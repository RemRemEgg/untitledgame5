class_name Room
extends Node3D

const LEVELBODY := preload("res://game/levelbody.tscn") as PackedScene


@onready var room_walls: RoomWalls = $room_walls as RoomWalls
var is_sudden_death: bool = true


func _ready() -> void:
	Network.game_won.connect(stop_sudden_death)


func _process(delta: float) -> void:
	if !is_sudden_death: return
	room_walls.ceilingsb.position.y = maxf(room_walls.ceilingsb.position.y - delta*World.SD_SPEED, 56.0)
	room_walls.floorsb.position.y = -room_walls.ceilingsb.position.y


func stop_sudden_death(_id: int) -> void:
	#room_walls.ceilingsb.position.x = 1e5
	#room_walls.floorsb.position.x = 1e5
	is_sudden_death = false
	_stop_sudden_death_tween(room_walls.ceilingsb, 1)
	_stop_sudden_death_tween(room_walls.floorsb, -1)
func _stop_sudden_death_tween(lvlb: LevelBody, dir: float) -> void:
	var tween := lvlb.create_tween()
	tween.tween_property(lvlb, ^"position", lvlb.position + Vector3(0.0, 128*dir, 0.0), 10.0)
	tween.tween_property(lvlb, ^"position", lvlb.position + Vector3(1e5, 0.0, 0.0), 0.1)
