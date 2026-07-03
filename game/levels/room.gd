class_name Room
extends Node3D

const LEVELBODY := preload("res://game/levelbody.tscn") as PackedScene


@onready var room_walls: RoomWalls = $room_walls as RoomWalls


func _ready() -> void:
	Network.game_won.connect(stop_sudden_death)


func _process(delta: float) -> void:
	room_walls.ceilingsb.position.y = maxf(room_walls.ceilingsb.position.y - delta*World.SD_SPEED, 56.0)
	room_walls.floorsb.position.y = -room_walls.ceilingsb.position.y


func stop_sudden_death(_id: int) -> void:
	room_walls.ceilingsb.position.x = 1e5
	room_walls.floorsb.position.x = 1e5
