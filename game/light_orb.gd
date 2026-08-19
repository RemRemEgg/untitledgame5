@warning_ignore("missing_tool")
class_name LightOrb
extends LevelBody


var rng: RandomNumberGenerator
var time := 0.0


func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = roundi(global_position.x + global_position.y + global_position.z)


func _process(delta: float) -> void:
	super(delta)
	
	time += delta
	if time >= 1.0:
		time -= 1.0
		apply_central_impulse(Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)) * 5.0)
	
