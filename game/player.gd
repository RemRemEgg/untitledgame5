class_name Player
extends Entity



var cam_ax: float = 0.0
@onready var camera_root: Node3D = $camera_root as Node3D
var camera: Camera3D
var mesh: MeshInstance3D
@onready var hud: HUD = $camera_root/camera/hud as HUD
@onready var cards_menu: CardsMenu = $camera_root/camera/cards_menu as CardsMenu
@onready var proj_spawner: MultiplayerSpawner = $proj_spawner as MultiplayerSpawner

func set_data(data: Network.PlayerInfo) -> void:
	camera = $camera_root/camera as Camera3D
	camera.current = true
	mesh = $mesh
	(mesh.material_override as StandardMaterial3D).albedo_color = data.color
	($nametag as Label3D).text = data.name


var speed := 12.0
var jump := 14.0
var accel := 48.0
var is_jump: bool = 0
var is_floor: bool = 0
var cyote: float = -1
var dash_count: float = 0.0
var dash_max: float = 3.0
var dash_type: int = 0

var procgun: ProcGun
var gun: Gun


func _ready() -> void:
	team = 0b1000 << 4
	
	procgun = ProcGun.new()
	gun = Gun.new()
	
	var pproj := ProcProj.new()
	procgun.pproj = pproj
	
	procgun.add_modifier(ProcGun.MOD_SPREAD, [5, 0.1])
	
	#proj_spawner.spawn_function = Network._spawn_projectile
	Network.add_proj_spawner(proj_spawner)


func _process(delta: float) -> void:
	velocity += Vector3(0.0, -32.0, 0.0) * delta # gravity
	cyote -= delta
	if is_floor: cyote = 0.15
	dash_count = minf(dash_count + delta * (1.2 if is_floor else 0.6), dash_max) # dash recharge
	is_floor = is_on_floor()
	is_jump = Input.is_action_pressed(&"jump")
	
	var input_dir := Vector2.ZERO
	if cyote >= 0.0 && is_jump: # jump + boost
		var boost := Vector2(velocity.x, velocity.z).length()
		boost = boost / (boost + 48.0)
		velocity.y = jump * (1.0+boost)
		cyote = -1.0
	if velocity.y > 0 && is_jump: velocity -= Vector3(0.0, -32.0, 0.0) * delta * 0.35 # high jump
	input_dir = Input.get_vector(&"left", &"right", &"forward", &"backward")
	
	if is_floor || input_dir:
		var dir_3 := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var intent := Vector2(dir_3.x, dir_3.z) # flattened & transformed input direction
		movement_update_flat(self, intent, delta)
	
	move_and_slide()
	
	#for col_idx in get_slide_collision_count(): #TODO fix physics
		#var col := get_slide_collision(col_idx)
		#if col.get_collider() is RigidBody3D:
			#col.get_collider().apply_central_impulse(-col.get_normal() * 0.3)
			#col.get_collider().apply_impulse(-col.get_normal() * 0.01, col.get_position())
	
	procgun.process(gun, camera.global_transform, self, delta, Input.is_action_pressed(&"fire"))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var delta_y := deg_to_rad(-event.relative.x * 0.2)
		rotate_y(delta_y)
		var delta_x := clampf(deg_to_rad(-event.relative.y * 0.2) + cam_ax, -PI/2, PI/2) - cam_ax
		cam_ax += delta_x
		camera.rotate_x(delta_x)
		return
	if event.is_action_pressed(&"dash") && dash_count >= 1.0: return dash()
	if event is InputEventKey:
			if event.keycode == Key.KEY_TAB && event.pressed:
				var pp := camera.compositor.compositor_effects[0] as PanniniProjection
				pp.enabled = !pp.enabled
			if event.keycode == KEY_CTRL:
				wall_min_slide_angle = PI if event.pressed else deg_to_rad(15)
				floor_max_angle = 0.0 if event.pressed else deg_to_rad(45)
				floor_stop_on_slope = !event.pressed
			#if event.keycode == KEY_TAB:
				#Engine.time_scale = 0.1 if event.pressed else 1.0
				#delta_mult = 1.0/Engine.time_scale
			#if event.keycode >= 49 && event.keycode <= 52 && event.pressed: selected_item = event.keycode - 49
			if event.keycode == KEY_C:
				camera.fov = 30 if event.pressed else 110
			#if event.keycode == KEY_Q:
				#var ent := Lobby.pe.create_entity()
				#ent.global_position = global_position - global_basis.z*5.0 + Vector3(0.0, 1.0, 0.0)


func dash() -> void:
	match dash_type:
		0: velocity += (camera.global_transform.basis.z) * speed * -5.0
		1: velocity = (camera.global_transform.basis.z) * speed * -2.0
		2: velocity = (camera.global_transform.basis.z) * -velocity.length()
	dash_count -= 1
