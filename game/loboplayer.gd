class_name LoboPlayer
extends Entity

var mesh: MeshInstance3D
@onready var proj_spawner: MultiplayerSpawner = $proj_spawner as MultiplayerSpawner

func set_data(data: Network.PlayerInfo) -> void:
	mesh = $mesh
	(mesh.material_override as StandardMaterial3D).albedo_color = data.color
	($nametag as Label3D).text = data.name
	var hud := $camera_root/camera/hud
	$camera_root/camera.remove_child(hud)
	hud.queue_free()
	Network.add_proj_spawner(proj_spawner)
