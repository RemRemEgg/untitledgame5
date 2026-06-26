class_name LoboPlayer
extends Player

func _init() -> void: pass

func set_data(data: Network.PlayerInfo) -> void:
	mesh = $mesh as MeshInstance3D
	nodepth_mesh = $nodepth_mesh as MeshInstance3D
	player_model = $player_model as PlayerModel
	
	var mat := mesh.material_override as StandardMaterial3D
	mat.albedo_color = data.color
	player_model.set_color_recur(mat)
	
	var col := (data.color + Color.WHITE*0.5) / 1.5
	(nodepth_mesh.material_override as ShaderMaterial).set_shader_parameter(&"color", Vector3(col.r, col.g, col.b))
	($nametag as Label3D).text = data.name
	uuid = data.uuid
	camera = $camera as Camera3D
	
	Util.remove_and_free(camera.get_node(^"hud"))
	Util.remove_and_free(camera.get_node(^"ui3d_container"))
	Util.remove_and_free(get_node(^"light_med"))
	Util.remove_and_free(get_node(^"light_large"))

func _ready() -> void:
	Network.add_proj_spawner(proj_spawner)

func _process(_delta: float) -> void:
	update_healthbar()

func _input(_event: InputEvent) -> void: pass
func _unhandled_input(_event: InputEvent) -> void: pass
func _unhandled_key_input(_event: InputEvent) -> void: pass
