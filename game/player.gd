class_name Player
extends Entity

func get_seralized_projectiles() -> Array[Dictionary]:
	return [procgun.pproj.seralize()]
func set_seralized_projectiles(info: Dictionary) -> void:
	pproj = ProcProj.deseralize(info)

var uuid: int = 0

var camera: Camera3D
var mesh: MeshInstance3D
var player_model: PlayerModel
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
## [velocity, melee, block, flags, reload]
var animation_data: Array[float] = [0.0, 2.0, 0.0, 0, 0.0]

func set_data(data: Network.PlayerInfo) -> void:
	camera = $camera as Camera3D
	camera.current = true
	mesh = $mesh as MeshInstance3D
	nodepth_mesh = $nodepth_mesh as MeshInstance3D
	player_model = $player_model as PlayerModel
	
	var mat := mesh.material_override as StandardMaterial3D
	mat.albedo_color = data.color
	player_model.set_color_recur(mat)
	
	nodepth_mesh.visible = false
	($nametag as Label3D).visible = false
	hud = $camera/hud as HUD
	uuid = data.uuid



var cards: Dictionary[Card, int]
var deck_weights: Dictionary[CardDeck, float]
var stamina: float = 0.0
var magic_timer: float = 0.0
var melee_timer: float = -1.0
var is_floor: bool = 0
var is_ads: bool = false
var dash_type: int = 5
var cyote: float = -1
var wall_cyote: float = 0.0
var jumps: int = 0
var bounds_ignore: float = 0.0
var can_shoot: bool = false
var procgun: ProcGun
var pproj: ProcProj
var gun: Gun

# TODO lifesteal, spread damage over mag?
# max_health speed accel
var full_auto := false
## Default 9.0
var jump := Stat.new(&"Jump Height", 9.0, 0.5)
## Default 1
var max_jumps := Stat.new(&"Jumps", 1, 1)
## Default 1
var stamina_max := Stat.new(&"Stamina", 1.0, 0.0)
## Default 6.0
var magic_cd := Stat.new(&"Magic Cooldown", 6.0, 0.01, 9e9, false)
## Default 0.7
var melee_cd := Stat.new(&"Melee Cooldown", 0.7, 0.01, 9e9, false)

## Hook for player shooting their gun
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var shooting_hook := EventHook.new()
## Hook for player taking damage. Player is [code]de.target_entity[/code].
## [codeblock]func(n:int, de:DamageEvent) -> void:[/codeblock]
var damage_hook := EventHook.new()
## Hook for magic effects (ie implode or emp)
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var magic_hook := EventHook.new()
## [b]NYI[/b][br][s]Hook for magic chains (ie shield charge or echo)
## Set [code]player.magic_chain_delay[/code] to change delay between chains. Default 0.25 sec.
## [codeblock]func(n:int, p:Player) -> void:[/codeblock][/s]


func reset_stats() -> void:
	for deck in Card.DECKS:
		deck_weights[deck] = 1.0
	
	full_auto = false
	max_health.reset_value()
	health = max_health.value
	speed.reset_value()
	jump.reset_value()
	max_jumps.reset_value()
	accel.reset_value()
	stamina_max.reset_value()
	magic_cd.reset_value()
	melee_cd.reset_value()
	
	shooting_hook.clear_effects()
	damage_hook.clear_effects()
	magic_hook.clear_effects()
	
	procgun.reset_stats()


func calculate_stats() -> void:
	max_health.calculate_value()
	speed.calculate_value()
	jump.calculate_value()
	max_jumps.calculate_value()
	accel.calculate_value()
	stamina_max.calculate_value()
	magic_cd.calculate_value()
	melee_cd.calculate_value()
	
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
	if stasis:
		velocity = Vector3.ZERO
		global_position = stasis
		update_animation_data(delta)
		return
	if is_spectator: return spectator_process(delta)
	
	is_floor = is_on_floor()
	is_ads = Input.is_action_pressed(&"ads")
	camera.fov = 45 if is_ads else 130
	stamina = minf(stamina + delta * (1.2 if is_floor else 0.6), stamina_max.value) # dash recharge
	time_survived += delta
	bounds_ignore -= delta
	magic_timer -= delta
	melee_timer -= delta
	if is_floor: jumps = max_jumps.value_int
	
	velocity += Vector3(0.0, -32.0, 0.0) * delta # gravity
	
	# jumps
	cyote -= delta
	if Input.is_action_just_pressed(&"jump"): cyote = 0.2
	wall_cyote -= delta
	if is_on_wall(): wall_cyote = 0.1
	# normal jump
	if jumps > 0 && cyote >= 0.0: # jump + boost
		var boost := Vector2(velocity.x, velocity.z).length()
		boost = boost / (boost + 48.0)
		velocity.y = jump.value * (1.0+boost)
		jumps -= 1
		cyote = -1.0
	# high jump
	if velocity.y > 0 && Input.is_action_pressed(&"jump"): velocity -= Vector3(0.0, -32.0, 0.0) * delta * 0.35
	# wall jump
	if wall_cyote >= 0.0 && cyote >= 0.0:
		var wall := get_wall_normal()
		velocity += wall * jump.value * 0.8
		velocity.y = jump.value
		cyote = -1.0
	
	
	# handle movement
	var input_dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
	if is_floor || input_dir:
		var dir_3 := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var intent := Vector2(dir_3.x, dir_3.z) # flattened & transformed input direction
		movement_update_flat(self, intent, delta)
	
	var pvel := velocity
	move_and_slide()
	
	# collisions
	for col_idx in get_slide_collision_count():
		var col := get_slide_collision(col_idx)
		
		# hit bounds
		var shape := col.get_collider_shape()
		if shape is CollisionShape3D:
			if (shape as CollisionShape3D).shape is WorldBoundaryShape3D && bounds_ignore <= 0.0:
				take_damage(maxf(max_health.value * 0.2, health * 0.5),
						col.get_normal() * (32.0 if magic_timer >= 0.0 else 16.0))
				bounds_ignore = 0.1
		
		# push objects
		var colc := col.get_collider()
		if colc is RigidBody3D:
			if (colc as RigidBody3D).freeze: continue
			var impact := -col.get_normal() * pvel.length()
			(colc as RigidBody3D).apply_central_impulse.rpc(impact * 0.5)
		# push players
		if colc is Player:
			var impact := -col.get_normal() * pvel.length()
			(colc as Player).take_damage.rpc(0.0, impact * 0.45)
	
	# melee
	if melee_timer >= 0.0:
		melee()
	
	# fire gun
	var b_trans := camera.global_transform
	# TODO bullets dont clip camera. Fixed?
	# TODO make bullets fire from "gun"
	b_trans.origin += Vector3(0.0, -0.2, 0.0)
	# TODO fix input processing with menus during gameplay
	var is_firing := (Input.is_action_pressed(&"fire")) if full_auto else (Input.is_action_just_pressed(&"fire"))
	var update_gun: bool = is_firing && can_shoot && !Input.is_action_pressed(&"view_info") && !Console.visible
	procgun.process(gun, b_trans, self, delta, update_gun)
	#procgun.process(gun, b_trans.rotated_local(Vector3.RIGHT, 0.1), self, delta, Input.is_action_pressed(&"fire") && can_shoot)
	
	update_animation_data(delta)


func spectator_process(delta: float) -> void:
	var input_dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
	var h_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var v_dir := Input.get_axis(&"slide", &"jump")
	
	global_position += Vector3(h_dir.x, v_dir, h_dir.z) * delta * (96.0 if Input.is_action_pressed(&"dash") else 32.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var iemm := event as InputEventMouseMotion
		var sens := 0.333 if is_ads else 1.0
		var delta_y := deg_to_rad(-iemm.relative.x * 0.2 * sens)
		rotate_y(delta_y)
		camera.rotation.x = clampf(deg_to_rad(-iemm.relative.y * 0.2 * sens) + camera.rotation.x, -PI/2, PI/2)
		return
	if !is_spectator && !stasis:
		if event.is_action_pressed(&"dash") && stamina >= 1.0:
			dash()
			stamina -= 1.0
		if event.is_action_pressed(&"reload") && gun.reload == 0:
			gun.reload = procgun.reload_time.value
		if event.is_action_pressed(&"magic") && magic_timer <= -magic_cd.value:
			initalize_magic()
		if event.is_action_pressed(&"melee") && melee_timer <= -melee_cd.value:
			melee_timer = 0.333
			animation_data[1] = 0.0

func _unhandled_key_input(event: InputEvent) -> void:
		var iek := event as InputEventKey
		match iek.keycode:
			KEY_J when iek.pressed:
				var pp := camera.compositor.compositor_effects[0] as PanniniProjection
				pp.enabled = !pp.enabled
			KEY_C:
				camera.fov = 30 if iek.pressed else 130
			KEY_K when iek.pressed:
				if hud.info_holder.visible && !hud.info.player_name.text.is_empty():
					for pi:Network.PlayerInfo in Network.players.values():
						if pi.name == hud.info.player_name.text:
							Console.print(&"killbinded '%s'" % pi.name)
							pi.linked_player.take_damage.rpc(float(0xd1edeadd1e)**3)
				else:
					Console.print(&"killbinded")
					take_damage(float(0xd1edeadd1e)**3)
			KEY_P when iek.pressed:
				if is_spectator: exit_spectator.rpc()
				else: enter_spectator.rpc()
			KEY_O:
				gun.clip = procgun.clip_size.value_int
				gun.reload = 0.0
				gun.fire_timer = 1.0
				can_shoot = true
			KEY_N:
				health = max_health.value
			KEY_I:
				is_immortal = !is_immortal
			KEY_T:
				update_cards()
			#KEY_M:
				#for i in 10: add_card(Card.ALL_CARDS.pick_random() as Card)
			KEY_J:
				full_auto = !full_auto


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


func run_shoot_hook() -> void:
	var ed := EventHook.EventData.from_player(self)
	for effect:EventHook.EventEffect in shooting_hook:
		effect.execute(ed)


#region magic

func initalize_magic() -> void:
	magic_timer = 0.75
	process_magic_effects()


#func process_magic_chain(delta: float) -> void: # NYI
	#magic_chain_delay -= delta
	#if magic_chain_delay <= 0.0 && magic_chain_index < magic_chain_hooks.size():
		#magic_chain_delay = 0.25
		#magic_chain_hooks[magic_chain_index].call()
		#process_magic_effects()
		#magic_chain_index += 1


func process_magic_effects() -> void:
	var ed := EventHook.EventData.from_player(self)
	for effect:EventHook.EventEffect in magic_hook:
		effect.execute(ed)

#endregion


func melee() -> void:
	var dss: PhysicsDirectSpaceState3D = Game.world.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var psqp := PhysicsShapeQueryParameters3D.new()
	psqp.exclude = [get_rid()]
	psqp.shape = shape
	var pos := global_position + (camera.global_basis * Vector3(0.0, 0.0, -0.7))
	psqp.transform.origin = pos
	
	psqp.collision_mask = 0b0010_0010
	var rest := dss.get_rest_info(psqp)
	if !rest.is_empty():
		var cid := rest[&"collider_id"] as int
		var colc := instance_from_id(cid) as PhysicsBody3D
		if colc is Player:
			var pl := colc as Player
			var dir := global_position.direction_to(pl.global_position) * 12.0
			pl.take_damage.rpc(0.0, dir + velocity*1.2)
			melee_timer = -0.01
		return
	
	psqp.collision_mask = 0b0001_0001
	rest = dss.get_rest_info(psqp)
	if !rest.is_empty():
		var norm := rest.get(&"normal", -velocity.normalized()) as Vector3
		velocity = velocity.bounce(norm)
		melee_timer = -0.01


func game_start() -> void:
	stasis = Vector3.ZERO
	time_survived = 0.0
	can_shoot = true
	is_immortal = false
	update_cards()


@rpc("any_peer", "call_local", "reliable")
# TODO fix bounds, split take_hit / take_damage?
func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if !is_multiplayer_authority() || magic_timer >= 0.0: return
	var de := DamageEvent.new(amount, knockback)
	de.target_entity = self
	var ed := EventHook.EventData.from_player(self)
	for effect:EventHook.EventEffect in damage_hook:
		effect.execute(ed, de)
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


func on_round_end(won: bool) -> void:
	respawn()
	if won:
		hud.win_lose_timer = 3.0
		hud.is_win = true


func die() -> void:
	can_shoot = false
	is_immortal = true
	enter_spectator.rpc()
	Network.player_died.rpc_id(1, time_survived)
	hud.win_lose_timer = 3.1
	hud.is_win = false


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
	Network.update_card_picked.rpc(card.uuid, count) # TODO netsync cards
	if cards[card] <= 0:
		cards.erase(card)


func update_cards() -> void:
	reset_stats()
	var cd := Card.CardData.from_player(self)
	for card in cards: # for each card
		cd.n = cards[card]
		card.card_effect.call(cd)
	calculate_stats()
	gun.clip = procgun.clip_size.value_int
	gun.reload = 0.0
	health = max_health.value

#endregion

func update_animation_data(delta: float) -> void:
	animation_data[0] = velocity.length_squared()
	animation_data[1] += delta * 3.0
	animation_data[2] = (magic_timer) if (magic_timer >= 0.0) else (magic_timer / magic_cd.value)
	animation_data[3] = (is_floor)
	animation_data[4] = (-gun.reload/procgun.reload_time.value) if (gun.reload) else (1.0-gun.fire_timer)
