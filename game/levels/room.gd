class_name Room
extends Node3D

const LEVELBODY := preload("res://game/levelbody.tscn") as PackedScene

func _ready() -> void:
	var rng := Network.get_synced_rng()
	rng.seed += roundi(global_position.x*256.0 + global_position.z*2048.0)
	var mesh := BoxMesh.new()
	var coll := BoxShape3D.new()
	
	for x in 4: for z in 4: for y in rng.randi_range(0, 5):
		var lvlb := LEVELBODY.instantiate() as LevelBody
		
		lvlb.mesh = mesh
		lvlb.shape = coll
		lvlb.is_static = false
		lvlb.bodytype = LevelBody.Type.BREAKABLE if rng.randf() < 0.8 else (LevelBody.Type.SOLID if rng.randf() < 0.5 else LevelBody.Type.SCAFFOLD)
		lvlb.sleeping = true
		lvlb.name = &"box%sl%sl%s" % [x, y, z]
		
		add_child(lvlb)
		lvlb.position = Vector3((x*1.5)+8.0, (y*1.1)+2.0, (z*1.5)+8.0)

func _process(_delta: float) -> void:
	pass
