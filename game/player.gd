class_name Player
extends Entity


func get_seralized_projectiles() -> Array[Dictionary]:
	return [procgun.pproj.seralize()]
func set_seralized_projectiles(info: Dictionary) -> void:
	pproj = ProcProj.deseralize(info)

var uuid: int = 0

var cam_ax: float = 0.0
@onready var camera_root: Node3D = $camera_root as Node3D
var camera: Camera3D
var mesh: MeshInstance3D
var nodepth_mesh: MeshInstance3D
const NODEPTH_ALPHA: float = 0.25
@onready var hud: HUD
@onready var cards_menu: CardsMenu = $camera_root/camera/ui3d_container/ui3d_vp/cards_menu as CardsMenu
@onready var proj_spawner: MultiplayerSpawner = $proj_spawner as MultiplayerSpawner
@onready var healthbar: Sprite3D = $nametag/healthbar as Sprite3D
@onready var health_gradient := (healthbar.texture as GradientTexture2D).gradient

var is_spectator: bool = false
var is_immortal: bool = true
var stasis: Vector3 = Vector3.ZERO
var time_survived: float = 0.0

func set_data(data: Network.PlayerInfo) -> void:
	camera = $camera_root/camera as Camera3D
	camera.current = true
	mesh = $mesh as MeshInstance3D
	nodepth_mesh = $nodepth_mesh as MeshInstance3D
	(mesh.material_override as StandardMaterial3D).albedo_color = data.color
	nodepth_mesh.visible = false
	($nametag as Label3D).visible = false
	hud = $camera_root/camera/hud as HUD
	uuid = data.uuid

var cards: Array[Card]
var stamina: float = 0.0
var is_jump: bool = 0
var is_floor: bool = 0
var dash_type: int = 0
var cyote: float = -1
var bounds_ignore: float = 0.0
var can_shoot: bool = false
var procgun: ProcGun
var pproj: ProcProj
var gun: Gun

func set_default_stats() -> void:
	health = 100.0
	max_health = 100.0
	speed = 12.0
	jump = 14.0
	accel = 48.0
	stamina_max = 2.0
	procgun.set_default_stats()

#modifiable stats
#health & max_health : float
var speed: float
var jump: float
var accel: float
var stamina_max: float


func _ready() -> void:
	procgun = ProcGun.new()
	gun = Gun.new()
	pproj = ProcProj.new()
	procgun.pproj = pproj
	set_default_stats()
	
	#proj_spawner.spawn_function = Network._spawn_projectile
	Network.add_proj_spawner(proj_spawner, true)


func _process(delta: float) -> void:
	update_healthbar()
	
	if is_spectator: return spectator_process(delta)
	velocity += Vector3(0.0, -32.0, 0.0) * delta # gravity
	cyote -= delta
	bounds_ignore -= delta
	if is_floor: cyote = 0.15
	stamina = minf(stamina + delta * (1.2 if is_floor else 0.6), stamina_max) # dash recharge
	is_floor = is_on_floor()
	is_jump = Input.is_action_pressed(&"jump")
	time_survived += delta
	
	if stasis:
		velocity = Vector3.ZERO
		global_position = stasis
		return
	
	# handle jump
	var input_dir := Vector2.ZERO
	if cyote >= 0.0 && is_jump: # jump + boost
		var boost := Vector2(velocity.x, velocity.z).length()
		boost = boost / (boost + 48.0)
		velocity.y = jump * (1.0+boost)
		cyote = -1.0
	if velocity.y > 0 && is_jump: velocity -= Vector3(0.0, -32.0, 0.0) * delta * 0.35 # high jump
	
	# handle movement
	input_dir = Input.get_vector(&"left", &"right", &"forward", &"backward")
	if is_floor || input_dir:
		var dir_3 := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var intent := Vector2(dir_3.x, dir_3.z) # flattened & transformed input direction
		movement_update_flat(self, intent, delta)
	
	# handle hover
	if Input.is_action_pressed(&"hover"):
		var eat := delta * 3
		var rem := minf(eat, stamina)
		velocity.y *= 1.0-(rem/eat)**3.0
		stamina -= rem
	
	move_and_slide()
	
	#for col_idx in get_slide_collision_count(): #TODO fix physics
		#var col := get_slide_collision(col_idx)
		#if col.get_collider() is RigidBody3D:
			#col.get_collider().apply_central_impulse(-col.get_normal() * 0.3)
			#col.get_collider().apply_impulse(-col.get_normal() * 0.01, col.get_position())
	for col_idx in get_slide_collision_count():
		var col := get_slide_collision(col_idx)
		var shape := col.get_collider_shape()
		if shape is CollisionShape3D:
			if shape.shape is WorldBoundaryShape3D && bounds_ignore <= 0.0:
				take_damage(max_health * 0.5)
				bounds_ignore = 0.1
				velocity += col.get_normal() * 48.0
	
	procgun.process(gun, camera.global_transform, self, delta, Input.is_action_pressed(&"fire") && can_shoot)

func spectator_process(delta: float) -> void:
	if stasis:
		velocity = Vector3.ZERO
		global_position = stasis
		return
	
	var input_dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
	var h_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var v_dir := Input.get_axis(&"hover", &"jump")
	
	global_position += Vector3(h_dir.x, v_dir, h_dir.z) * delta * (80.0 if Input.is_action_pressed(&"dash") else 32.0)

func _input(event: InputEvent) -> void: # TODO rework inputs
	if event is InputEventMouseMotion:
		var iemm := event as InputEventMouseMotion
		var delta_y := deg_to_rad(-iemm.relative.x * 0.2)
		rotate_y(delta_y)
		var delta_x := clampf(deg_to_rad(-iemm.relative.y * 0.2) + cam_ax, -PI/2, PI/2) - cam_ax
		cam_ax += delta_x
		camera.rotate_x(delta_x)
		return
	if !is_spectator:
		if event.is_action_pressed(&"dash") && stamina >= 1.0 && !stasis: return dash()
		if event.is_action_pressed(&"reload") && gun.reload == 0: gun.reload = procgun.reload_time; return
	if event is InputEventKey:
		var iek := event as InputEventKey
		match iek.keycode:
			KEY_TAB when iek.pressed:
				var pp := camera.compositor.compositor_effects[0] as PanniniProjection
				pp.enabled = !pp.enabled
			KEY_C:
				camera.fov = 35 if iek.pressed else 130
			KEY_K when iek.pressed:
				Console.print(&"killbinded super:%s" % Input.is_action_pressed(&"hover"))
				if Input.is_action_pressed(&"hover"):
					for player in (Network.players.values() as Array[Network.PlayerInfo]):
						(player as Network.PlayerInfo).linked_player.take_damage.rpc(0xD1E_D1E_D1E_D1E_D1E)
				else: take_damage(0xD1E_D1E_D1E_D1E_D1E)
			KEY_P when iek.pressed:
				if is_spectator: exit_spectator.rpc()
				else: enter_spectator.rpc()

func dash() -> void:
	match dash_type:
		0: velocity += (camera.global_transform.basis.z) * speed * -2.0
		1: velocity = (camera.global_transform.basis.z) * speed * -2.5
		2: velocity = (camera.global_transform.basis.z) * -velocity.length()
		3: velocity = (camera.global_transform.basis.z) * speed * -(1.5 + camera.global_transform.basis.z.dot(-velocity.normalized())*0.75)
	stamina -= 1


func game_start() -> void:
	stasis = Vector3.ZERO
	time_survived = 0.0
	can_shoot = true
	is_immortal = false
	set_default_stats()
	for card in cards:
		card.card_effect.call(self, procgun, procgun.pproj)
	health = max_health
	gun.clip = procgun.clip_size
	gun.reload = 0.0


@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if !is_multiplayer_authority(): return
	#knockback = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * randf_range(1.0, 25.0)
	velocity += knockback
	Console.print(&"took %08.2f damage%s" % [amount, (&", but im immortal so i dont care" if is_immortal else &". ouch!")])
	if is_immortal: return
	health -= amount
	health_update()

func update_healthbar() -> void:
	var percent := health / max_health
	health_gradient.offsets = [percent - 0.001, percent]

func health_update() -> void:
	if health <= 0.0 && !is_immortal:
		Console.print(&"im so dead..... bleh")
		die()

func die() -> void:
	can_shoot = false
	is_immortal = true
	enter_spectator.rpc()
	Network.player_died.rpc_id(1, time_survived)
func respawn() -> void:
	can_shoot = false
	is_immortal = true
	health = max_health
	exit_spectator.rpc()

@rpc("authority", "call_local", "reliable")
func enter_spectator() -> void:
	is_spectator = true
	visible = false
@rpc("authority", "call_local", "reliable")
func exit_spectator() -> void:
	is_spectator = false
	visible = true
	velocity = Vector3.ZERO
