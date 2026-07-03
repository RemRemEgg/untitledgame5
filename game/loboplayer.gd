class_name LoboPlayer
extends Player

func _init() -> void: pass

func set_data(data: Network.PlayerInfo) -> void:
	player_model = $player_model as PlayerModel
	
	var col := (data.color + Color.WHITE*0.5) / 1.5
	var mat := player_model.material as StandardMaterial3D
	mat.albedo_color = data.color
	(mat.next_pass as ShaderMaterial).set_shader_parameter(&"color", Vector3(col.r, col.g, col.b))
	
	($nametag as Label3D).text = data.name
	($nametag as Label3D).modulate = col
	uuid = data.uuid
	camera = $camera as Camera3D
	
	Util.remove_and_free(camera.get_node(^"hud"))
	Util.remove_and_free(camera.get_node(^"ui3d_container"))


func _ready() -> void:
	Network.add_proj_spawner(proj_spawner)


func _process(delta: float) -> void:
	move_and_collide(velocity * 0.85 * delta)


func _input(_event: InputEvent) -> void: pass
func _unhandled_input(_event: InputEvent) -> void: pass
func _unhandled_key_input(_event: InputEvent) -> void: pass
