class_name Player
extends Entity


func get_seralized_projectiles() -> Array[Dictionary]:
	return [procgun.pproj.seralize(Network.uuid)]
func set_seralized_projectiles(info: Dictionary) -> void:
	pproj = ProcProj.deseralize(info)


var cam_ax: float = 0.0
@onready var camera_root: Node3D = $camera_root as Node3D
var camera: Camera3D
var mesh: MeshInstance3D
var nodepth_mesh: MeshInstance3D
const NODEPTH_ALPHA := 0.25
@onready var hud: HUD
@onready var cards_menu: CardsMenu = $camera_root/camera/cards_menu as CardsMenu
@onready var proj_spawner: MultiplayerSpawner = $proj_spawner as MultiplayerSpawner

func set_data(data: Network.PlayerInfo) -> void:
	camera = $camera_root/camera as Camera3D
	camera.current = true
	mesh = $mesh as MeshInstance3D
	nodepth_mesh = $nodepth_mesh as MeshInstance3D
	(mesh.material_override as StandardMaterial3D).albedo_color = data.color
	nodepth_mesh.visible = false
	#(nodepth_mesh.material_override as StandardMaterial3D).albedo_color = (data.color + Color.BLACK*2.0) / 3.0
	#(nodepth_mesh.material_override as StandardMaterial3D).albedo_color.a = NODEPTH_ALPHA
	#($nametag as Label3D).text = data.name
	($nametag as Label3D).visible = false
	hud = $camera_root/camera/hud as HUD


var speed := 12.0
var jump := 14.0
var accel := 48.0
var is_jump: bool = 0
var is_floor: bool = 0
var cyote: float = -1
var stamina: float = 0.0
var stamina_max: float = 2.0
var dash_type: int = 0

var can_shoot: bool = false
var pproj: ProcProj
var procgun: ProcGun
var gun: Gun


func _ready() -> void:
	team = 0b1000 << 4
	
	procgun = ProcGun.new()
	gun = Gun.new()
	pproj = ProcProj.new()
	procgun.pproj = pproj
	
	#proj_spawner.spawn_function = Network._spawn_projectile
	Network.add_proj_spawner(proj_spawner, true)


func _process(delta: float) -> void:
	velocity += Vector3(0.0, -32.0, 0.0) * delta # gravity
	cyote -= delta
	if is_floor: cyote = 0.15
	stamina = minf(stamina + delta * (1.2 if is_floor else 0.6), stamina_max) # dash recharge
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
	
	if Input.is_action_pressed(&"hover"):
		var eat := delta * 3
		var rem := minf(eat, stamina)
		velocity.y *= 1.0-(rem/eat)**3.0
		print("rem %01.5f   mult %01.5f" % [rem, 0.01**rem])
		stamina -= rem
	
	move_and_slide()
	
	#for col_idx in get_slide_collision_count(): #TODO fix physics
		#var col := get_slide_collision(col_idx)
		#if col.get_collider() is RigidBody3D:
			#col.get_collider().apply_central_impulse(-col.get_normal() * 0.3)
			#col.get_collider().apply_impulse(-col.get_normal() * 0.01, col.get_position())
	
	procgun.process(gun, camera.global_transform, self, delta, Input.is_action_pressed(&"fire") && can_shoot)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var iemm := event as InputEventMouseMotion
		var delta_y := deg_to_rad(-iemm.relative.x * 0.2)
		rotate_y(delta_y)
		var delta_x := clampf(deg_to_rad(-iemm.relative.y * 0.2) + cam_ax, -PI/2, PI/2) - cam_ax
		cam_ax += delta_x
		camera.rotate_x(delta_x)
		return
	if event.is_action_pressed(&"dash") && stamina >= 1.0: return dash()
	if event is InputEventKey:
		var iek := event as InputEventKey
		if iek.keycode == Key.KEY_TAB && iek.pressed:
			var pp := camera.compositor.compositor_effects[0] as PanniniProjection
			pp.enabled = !pp.enabled
		if iek.keycode == KEY_C:
			camera.fov = 35 if iek.pressed else 130


func dash() -> void:
	match dash_type:
		0: velocity += (camera.global_transform.basis.z) * speed * -2.0
		1: velocity = (camera.global_transform.basis.z) * speed * -2.5
		2: velocity = (camera.global_transform.basis.z) * -velocity.length()
		3: velocity = (camera.global_transform.basis.z) * speed * -(1.5 + camera.global_transform.basis.z.dot(-velocity.normalized())*0.75)
	stamina -= 1
