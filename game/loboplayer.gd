class_name LoboPlayer
extends Player

func _init() -> void: pass

func set_data(data: Network.PlayerInfo) -> void:
	mesh = $mesh as MeshInstance3D
	nodepth_mesh = $nodepth_mesh as MeshInstance3D
	(mesh.material_override as StandardMaterial3D).albedo_color = data.color
	#var col := (data.color + Color.WHITE*2.0) / 2.5
	var col := (data.color + Color.WHITE*0.5) / 1.5
	(nodepth_mesh.material_override as ShaderMaterial).set_shader_parameter(&"color", Vector3(col.r, col.g, col.b))
	#(nodepth_mesh.material_override as StandardMaterial3D).albedo_color = (data.color + Color.BLACK) / 2.0
	#(nodepth_mesh.material_override as StandardMaterial3D).albedo_color.a = NODEPTH_ALPHA
	($nametag as Label3D).text = data.name
	hud = $camera_root/camera/hud as HUD
	$camera_root/camera.remove_child(hud)
	hud.queue_free()

func _ready() -> void:
	Network.add_proj_spawner(proj_spawner)

func _process(_delta: float) -> void: pass

func _input(_event: InputEvent) -> void: pass
