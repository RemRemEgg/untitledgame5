class_name World
extends Node3D

const PLAYER := preload("uid://c2wfggr4eiia1")
const P_SCRIPT = preload("uid://dqe5og2n28eku")
const L_SCRIPT = preload("uid://y4dp2cqltcrw")

@onready var enviroment: Node3D = $enviroment as Node3D
@onready var projectiles: Node3D = $projectiles as Node3D



func _ready() -> void:
	Game.world = self
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	process_mode = Node.PROCESS_MODE_DISABLED
	
	for v_p in Network.players.values():
		var pi := v_p as Network.PlayerInfo
		var p_scn := PLAYER.instantiate()
		
		p_scn.name = str(pi.uuid)
		p_scn.set_multiplayer_authority(pi.uuid, true)
		
		if pi.uuid == Network.uuid:
			p_scn.set_script(P_SCRIPT)
			var player := p_scn as Player
			player.set_data(pi)
			Game.player = player
		else:
			p_scn.set_script(L_SCRIPT)
			var lplayer := p_scn as LoboPlayer
			lplayer.set_data(pi)
		
		add_child(p_scn)
	
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = int(Time.get_unix_time_from_system())
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.domain_warp_enabled = true
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_BASIC_GRID
	noise.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_NONE
	var tgen := TerrainGen.new()
	
	
	var terrain_res: Vector2i = Vector2i(420, 420)
	tgen.quick_build(terrain_res, func(p: Vector2) -> Vector3:
		var pos := Vector3(p.x, 0.0, p.y)
		var n := noise.get_noise_2dv(p)
		pos.y = n*35.0 + 10.0
		
		var d := Vector2.ZERO.distance_squared_to(p)
		d *= d
		pos.y *= d/(d+1600.0)
		
		p *= 2.0
		if absi(p.x) == terrain_res.x || absi(p.y) == terrain_res.y:
			pos.y = -64.0
		
		return pos
		)
	
	#($StaticBody3D/Sprite2D as MeshInstance3D).mesh = tgen.mesh
	#($StaticBody3D/CollisionShape3D as CollisionShape3D).shape = tgen.mesh.create_trimesh_shape()
	
	
	Network.loaded_scene.rpc_id(1)
