class_name Player
extends Entity

# TODO wallclimbing

func get_seralized_projectiles() -> Array[Dictionary]:
	return [procgun.pproj.seralize()]
func set_seralized_projectiles(info: Dictionary) -> void:
	pproj = ProcProj.deseralize(info)

var uuid: int = 0

var camera: Camera3D
var mesh: MeshInstance3D
var dingus: Node3D
var nodepth_mesh: MeshInstance3D
const NODEPTH_ALPHA: float = 0.25
@onready var hud: HUD
@onready var cards_menu: CardsMenu = $camera/ui3d_container/ui3d_vp/cards_menu as CardsMenu
@onready var proj_spawner: MultiplayerSpawner = $proj_spawner as MultiplayerSpawner
@onready var healthbar: Sprite3D = $nametag/healthbar as Sprite3D
@onready var health_gradient := (healthbar.texture as GradientTexture2D).gradient


var is_spectator: bool = false
var is_immortal: bool = true
var stasis: Vector3 = Vector3.ZERO
var time_survived: float = 0.0

func set_data(data: Network.PlayerInfo) -> void:
	camera = $camera as Camera3D
	camera.current = true
	mesh = $mesh as MeshInstance3D
	nodepth_mesh = $nodepth_mesh as MeshInstance3D
	dingus = $dingus as Node3D
	
	var mat := mesh.material_override as StandardMaterial3D
	mat.albedo_color = data.color
	set_color_recur(dingus, mat)
	
	nodepth_mesh.visible = false
	($nametag as Label3D).visible = false
	hud = $camera/hud as HUD
	uuid = data.uuid

func set_color_recur(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		set_color_recur(c, mat)


var cards: Dictionary[Card, int]
var stamina: float = 0.0
var block_timer: float = 0.0
var is_hold_jump: bool = 0
var is_floor: bool = 0
var dash_type: int = 5
var cyote: float = -1
var jumps: int = 0
var bounds_ignore: float = 0.0
var can_shoot: bool = false
var procgun: ProcGun
var pproj: ProcProj
var gun: Gun

# modifiable stats
# max_health speed accel
var jump := Stat.new(8.0, 0.5)
var max_jumps := Stat.new(2, 1)
var stamina_max := Stat.new(1.0, 0.0)
var block_cd := Stat.new(2.0, 0.01)

## Hook for player taking damage. Player is [code]de.target_entity[/code].
## [codeblock]func(n:int, de:DamageEvent) -> void:[/codeblock]
var damage_hook := EventHook.new()
## Hook for block effects (ie implode or emp)
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var block_hook := EventHook.new()
## [b]NYI[/b][br][s]Hook for block chains (ie shield charge or echo)
## Set [code]player.block_chain_delay[/code] to change delay between chains. Default 0.25 sec.
## [codeblock]func(n:int, p:Player) -> void:[/codeblock][/s]
@warning_ignore("unused_private_class_variable")
var __block_triggers := 0

func reset_stats() -> void:
	max_health.reset_value()
	health = max_health.value
	speed.reset_value()
	jump.reset_value()
	max_jumps.reset_value()
	accel.reset_value()
	stamina_max.reset_value()
	block_cd.reset_value()
	
	damage_hook.clear_effects()
	block_hook.clear_effects()
	
	procgun.reset_stats()


func calculate_stats() -> void:
	max_health.calculate_value()
	speed.calculate_value()
	jump.calculate_value()
	max_jumps.calculate_value()
	accel.calculate_value()
	stamina_max.calculate_value()
	block_cd.calculate_value()
	
	procgun.calculate_stats()


func _ready() -> void:
	procgun = ProcGun.new()
	gun = Gun.new()
	pproj = ProcProj.new()
	procgun.pproj = pproj
	reset_stats()
	calculate_stats()
	
	#proj_spawner.spawn_function = Network._spawn_projectile
	Network.add_proj_spawner(proj_spawner, true)


func _process(delta: float) -> void:
	update_healthbar()
	if is_spectator: return spectator_process(delta)
	
	stamina = minf(stamina + delta * (1.2 if is_floor else 0.6), stamina_max.value) # dash recharge
	time_survived += delta
	bounds_ignore -= delta
	cyote -= delta
	block_timer -= delta
	is_floor = is_on_floor()
	is_hold_jump = Input.is_action_pressed(&"jump")
	if Input.is_action_just_pressed(&"jump"): cyote = 0.2
	if is_floor: jumps = max_jumps.value_int
	
	if stasis:
		velocity = Vector3.ZERO
		global_position = stasis
		return
	
	velocity += Vector3(0.0, -32.0, 0.0) * delta # gravity
	# handle jump
	var input_dir := Vector2.ZERO
	if jumps > 0 && cyote >= 0.0: # jump + boost
		var boost := Vector2(velocity.x, velocity.z).length()
		boost = boost / (boost + 48.0)
		velocity.y = jump.value * (1.0+boost)
		jumps -= 1
		cyote = -1.0
	if velocity.y > 0 && is_hold_jump: velocity -= Vector3(0.0, -32.0, 0.0) * delta * 0.35 # high jump
	
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
	
	var pvel := velocity
	move_and_slide()
	
	for col_idx in get_slide_collision_count():
		var col := get_slide_collision(col_idx)
		
		var shape := col.get_collider_shape()
		if shape is CollisionShape3D: # hit bounds
			if (shape as CollisionShape3D).shape is WorldBoundaryShape3D && bounds_ignore <= 0.0:
				take_damage(maxf(max_health.value * 0.2, health * 0.5),
						col.get_normal() * (48.0 if block_timer >= 0.0 else 24.0))
				bounds_ignore = 0.1
		
		var colc := col.get_collider()
		if colc is RigidBody3D: # push boxes around
			if (colc as RigidBody3D).freeze: continue
			var impact := -col.get_normal() * pvel.length()
			(colc as RigidBody3D).apply_central_impulse.rpc(impact * 0.5)
	
	var b_trans := camera.global_transform
	# TODO bullets dont clip camera
	b_trans.origin += Vector3(0.0, -0.2, 0.0)
	procgun.process(gun, b_trans, self, delta, Input.is_action_pressed(&"fire") && can_shoot)
	#procgun.process(gun, b_trans.rotated_local(Vector3.RIGHT, 0.1), self, delta, Input.is_action_pressed(&"fire") && can_shoot)


func spectator_process(delta: float) -> void:
	if stasis:
		velocity = Vector3.ZERO
		global_position = stasis
		return
	
	var input_dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
	var h_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var v_dir := Input.get_axis(&"hover", &"jump")
	
	global_position += Vector3(h_dir.x, v_dir, h_dir.z) * delta * (80.0 if Input.is_action_pressed(&"dash") else 32.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var iemm := event as InputEventMouseMotion
		var delta_y := deg_to_rad(-iemm.relative.x * 0.2)
		rotate_y(delta_y)
		camera.rotation.x = clampf(deg_to_rad(-iemm.relative.y * 0.2) + camera.rotation.x, -PI/2, PI/2)
		return
	if !is_spectator:
		if event.is_action_pressed(&"dash") && stamina >= 1.0 && !stasis:
			dash()
			stamina -= 1.0
		if event.is_action_pressed(&"reload") && gun.reload == 0:
			gun.reload = procgun.reload_time.value
		if event.is_action_pressed(&"block") && block_timer <= -block_cd.value:
			initalize_block()
	if event is InputEventKey:
		var iek := event as InputEventKey
		match iek.keycode:
			KEY_X when iek.pressed:
				var pp := camera.compositor.compositor_effects[0] as PanniniProjection
				pp.enabled = !pp.enabled
			KEY_C:
				camera.fov = 30 if iek.pressed else 130
			KEY_K when iek.pressed:
				Console.print(&"killbinded super:%s" % Input.is_action_pressed(&"hover"))
				if Input.is_action_pressed(&"hover"):
					for player in (Network.players.values() as Array[Network.PlayerInfo]):
						(player as Network.PlayerInfo).linked_player.take_damage.rpc(float(0xd1edeadd1e)**3)
				else: take_damage(float(0xd1edeadd1e)**3)
			KEY_P when iek.pressed:
				if is_spectator: exit_spectator.rpc()
				else: enter_spectator.rpc()
			KEY_O:
				gun.clip = procgun.clip_size.value_int
				gun.reload = 0.0
				gun.fire_timer = 1.0
				can_shoot = true
			KEY_H:
				health = max_health.value
			KEY_I:
				is_immortal = !is_immortal
			KEY_T:
				update_cards()


func dash() -> void:
	match dash_type:
		0: velocity += (camera.global_transform.basis.z) * speed.value * -1.0
		1: velocity = (camera.global_transform.basis.z) * speed.value * -1.2
		2: velocity = (camera.global_transform.basis.z) * -velocity.length()
		3: velocity = (camera.global_transform.basis.z) * speed.value * -(1.5 + camera.global_transform.basis.z.dot(-velocity.normalized())*0.75)
		4:
			var dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
			var dir_3 := (camera.global_transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
			if !dir: dir_3 = -camera.global_transform.basis.z
			dir_3 *= speed.value * 1.2
			velocity = Vector3(dir_3.x, velocity.y*0.5+dir_3.y, dir_3.z)
		5:
			var dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
			if !dir: dir = Vector2(0, -1)
			var target := (camera.global_transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
			var bonus := maxf(-0.2, velocity.normalized().dot(target) * 0.9)
			velocity = velocity*bonus + Vector3(target.x, target.y, target.z)*speed.value*0.9


#region block

func initalize_block() -> void:
	block_timer = 0.5
	process_block_effects()


#func process_block_chain(delta: float) -> void: # NYI
	#block_chain_delay -= delta
	#if block_chain_delay <= 0.0 && block_chain_index < block_chain_hooks.size():
		#block_chain_delay = 0.25
		#block_chain_hooks[block_chain_index].call()
		#process_block_effects()
		#block_chain_index += 1


func process_block_effects() -> void:
	block_timer = 0.5
	for effect:EventHook.EventEffect in block_hook:
		effect.execute(self)

#endregion


func game_start() -> void:
	stasis = Vector3.ZERO
	time_survived = 0.0
	can_shoot = true
	is_immortal = false
	update_cards()


@rpc("any_peer", "call_local", "reliable")
# TODO fix bounds, split take_hit / take_damage?
func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if !is_multiplayer_authority() || block_timer >= 0.0: return
	var de := DamageEvent.new(amount, knockback)
	de.target_entity = self
	for effect:EventHook.EventEffect in damage_hook:
		effect.execute(de)
	velocity += de.knockback
	#Console.print(&"%s %08.2f damage" % [(&"ignored" if is_immortal else &"took"), de.damage])
	if is_immortal: return
	health -= de.damage
	health_update()


func update_healthbar() -> void:
	var percent := health / max_health.value
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
	health = max_health.value
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


#region cards

func add_card(card: Card, count: int = 1) -> void:
	cards[card] = cards.get(card, 0) + count
	#Network.update_card_picked.rpc(card.uuid) # TODO netsync cards
	if cards[card] <= 0:
		cards.erase(card)


func update_cards() -> void:
	reset_stats()
	for card in cards: # for each card
		card.card_effect.call(cards[card], self, procgun, procgun.pproj)
	calculate_stats()
	gun.clip = procgun.clip_size.value_int
	gun.reload = 0.0
	health = max_health.value

#endregion
