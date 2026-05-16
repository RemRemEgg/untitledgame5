class_name LoboPlayer
extends Player

func _init() -> void: pass

func set_data(data: Network.PlayerInfo) -> void:
	mesh = $mesh as MeshInstance3D
	nodepth_mesh = $nodepth_mesh as MeshInstance3D
	(mesh.material_override as StandardMaterial3D).albedo_color = data.color
	var col := (data.color + Color.WHITE*0.5) / 1.5
	(nodepth_mesh.material_override as ShaderMaterial).set_shader_parameter(&"color", Vector3(col.r, col.g, col.b))
	($nametag as Label3D).text = data.name
	hud = $camera_root/camera/hud as HUD
	$camera_root/camera.remove_child(hud) #TODO remove way more from unused nodes
	$camera_root/camera.remove_child($camera_root/camera/ui3d_container)
	hud.queue_free()
	uuid = data.uuid

func _ready() -> void:
	Network.add_proj_spawner(proj_spawner)

func _process(_delta: float) -> void:
	update_healthbar()

func _input(_event: InputEvent) -> void: pass
