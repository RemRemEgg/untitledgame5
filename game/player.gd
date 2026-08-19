class_name Player
extends Entity

func get_seralized_projectiles() -> Array[Dictionary]:
	return [procgun.pproj.seralize()]
func set_seralized_projectiles(info: Dictionary) -> void:
	pproj = ProcProj.deseralize(info)

var uuid: int = 0

var camera: Camera3D
var player_model: PlayerModel
const NODEPTH_ALPHA: float = 0.25
@onready var hud: HUD
@onready var cards_menu: CardsMenu = $camera/ui3d_container/ui3d_vp/cards_menu as CardsMenu
@onready var proj_spawner: MultiplayerSpawner = $proj_spawner as MultiplayerSpawner
@onready var healthbar: Sprite3D = $nametag/healthbar as Sprite3D
@onready var armorbar: Sprite3D = $nametag/armorbar as Sprite3D
@onready var health_gradient := (healthbar.texture as GradientTexture2D).gradient
@onready var armor_gradient := (armorbar.texture as GradientTexture2D).gradient

var spider: PackedFloat64Array = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
var is_spectator: bool = false
var is_immortal: bool = true
var stasis: Vector3 = Vector3.ZERO
var time_survived: float = 0.0
var kills: int = 0
var deaths: int = 0
var last_damage_uuid: int
var last_damage_stamp: float

var slide_shape: CapsuleShape3D
var slide_psqp: PhysicsShapeQueryParameters3D
var slide_vfx_timer: float = 0.0
var melee_shape: SphereShape3D
var melee_psqp: PhysicsShapeQueryParameters3D
var melee_timer: float = -1.0
var melee_exclude: Array[RID]

func set_data(data: Network.PlayerInfo) -> void:
	camera = $camera as Camera3D
	camera.current = true
	player_model = $player_model as PlayerModel
	
	var col := (data.color + Color.WHITE*0.25) / 1.25
	var mat := player_model.material as StandardMaterial3D
	mat.albedo_color = data.color
	mat.emission = data.color
	(mat.next_pass as ShaderMaterial).set_shader_parameter(&"color", Vector3(col.r, col.g, col.b))
	
	($nametag as Label3D).visible = false
	hud = $camera/hud as HUD
	uuid = data.uuid


var cards: Dictionary[Card, int]
var deck_weights: Dictionary[CardDeck, float]
var stamina: float = 0.0
var armor: float = 0.0
var magic_timer: float = 0.0
var last_magic: int = 0
var armor_regen_delay: float = 0.0
var is_floor: bool = 0
var is_use: bool = false
var is_use_alt: bool = false
var is_firing: bool = false
var dash_type: int = 5
var jump_buffer: float = -1
var wall_buffer: float = 0.0
var wall_normal: Vector3
var jumps: int = 0
var bounds_ignore: float = 0.0
var can_shoot: bool = false
var procgun: ProcGun
var pproj: ProcProj
var gun: Gun

# TODO lifesteal, spread damage over mag?
# max_health speed accel
## Default false
var full_auto := false
## Default 10.0
var jump := Stat.new(&"Jump Height", 10.0, 0.5)
## Default 2
var max_jumps := Stat.new(&"Jumps", 2, 1)
## Default 1
var max_stamina := Stat.new(&"Stamina", 1.0, 0.0)
## Default 32.0
var armor_density := Stat.new(&"Armor Strength", 32.0, 0.0)
## Default 8.0
var armor_regen := Stat.new(&"Armor Regen", 8.0, 0.0)
## Default 0.7
var melee_cd := Stat.new(&"Melee CD", 0.7, 0.01, 9e9, false)
## Default 30.0
var melee_damage := Stat.new(&"Melee Damage", 30.0)
## Default 1.0
var magic_cd := Stat.new(&"All Spell CD", 1.0, 0.01, 9e9, false)
## [b]Multiplier[/b] for all spell potency. Default 1.0
var magic_potency := Stat.new(&"All Spell Potency", 1.0, 0.0, 9e9)
## All stats
var all_stats: Array[Stat] = [max_health, armor_density, armor_regen, speed, accel, jump, max_jumps, max_stamina, melee_cd, melee_damage, magic_cd, magic_potency]

## Hook for player shooting their gun
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var shooting_hook := EventHook.new()
## Hook for player taking damage. Player is [code]de.target_entity[/code].
## [codeblock]func(n:int, de:DamageEvent) -> void:[/codeblock]
var damage_hook := EventHook.new()
## Hook for player meleeing objects
var melee_hook := EventHook.new()
## Hook for player casting any spells. Called once per spell cast, not once per effect
var spell_hook := EventHook.new()
## Hook for player armor breaking
var armor_break_hook := EventHook.new()
## All hooks
var all_hooks: Array[EventHook] = [shooting_hook, damage_hook, melee_hook, spell_hook, armor_break_hook]

## First spell
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var spell_1 := Spell.new()
## Second spell
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var spell_2 := Spell.new()

func reset_stats() -> void:
	for deck in Card.DECKS:
		deck_weights[deck] = 1.0
	
	full_auto = false
	for stat in all_stats:
		stat.reset_value()
	
	for hook in all_hooks:
		hook.clear_effects()
	
	procgun.reset_stats()
	spell_1.reset_stats()
	spell_2.reset_stats()


func calculate_stats() -> void:
	for stat in all_stats:
		stat.calculate_value()
	
	procgun.calculate_stats()
	spell_1.calculate_stats()
	spell_2.calculate_stats()


func _ready() -> void:
	procgun = ProcGun.new()
	gun = Gun.new()
	pproj = ProcProj.new()
	procgun.pproj = pproj
	reset_stats()
	calculate_stats()
	
	melee_shape = SphereShape3D.new()
	melee_psqp = PhysicsShapeQueryParameters3D.new()
	melee_psqp.exclude = melee_exclude
	melee_psqp.shape = melee_shape
	
	slide_shape = CapsuleShape3D.new()
	slide_shape.radius = 1.3
	slide_shape.height = 4.2
	slide_psqp = PhysicsShapeQueryParameters3D.new()
	slide_psqp.exclude = [get_rid()]
	slide_psqp.shape = slide_shape
	slide_psqp.collision_mask = World.MASK_ALL
	
	Network.add_proj_spawner(proj_spawner, true)


func _process(delta: float) -> void:
	for stat in all_stats:
		stat.update(delta)
	
	spell_1.process(self, delta)
	spell_2.process(self, delta)
	
	# inputs & fov
	is_floor = is_on_floor()
	is_use = Input.is_action_pressed(&"use")
	is_use_alt = Input.is_action_pressed(&"use_alt")
	camera.fov = move_toward(camera.fov, (40.0) if (is_use_alt) else (115.0), delta*800.0)
	
	# during world loading
	if stasis:
		velocity = Vector3.ZERO
		global_position = stasis
		update_animation_data(delta)
		return
	# during game, while dead
	if is_spectator:
		return spectator_process(delta)
	
	# sliding
	if Input.is_action_pressed(&"slide"):
		slide_vfx_timer -= delta
		var dss := get_world_3d().direct_space_state
		slide_psqp.transform = global_transform.translated(Vector3(0.0, -0.15, 0.0))
		slide_psqp.exclude = [get_rid()]
		
		for i in 2:
			var rest := dss.get_rest_info(slide_psqp)
			if rest:
				var normal := rest[&"normal"] as Vector3
				var cid := rest[&"collider_id"] as int
				var colc := instance_from_id(cid) as PhysicsBody3D
				slide_psqp.exclude = [get_rid(), colc.get_rid()]
				
				var dot := minf(velocity.dot(normal), 0.0)
				if normal.dot(Vector3.UP) >= 0.5 && dot < 0.0: is_floor = true
				
				velocity -= dot * normal
				if slide_vfx_timer <= 0.0:
					VFXHandler.spawn(VFXHandler.PLAYER_SLIDE, rest[&"point"] + normal*0.1, [uuid, velocity])
					slide_vfx_timer = 0.0
				velocity += normal * delta * 32.0
			else: break
		if slide_vfx_timer == 0.0: slide_vfx_timer = 0.5
	
	stamina = minf(stamina + delta * (2.0 if is_floor else 0.8), max_stamina.value) # dash recharge
	if armor_regen_delay <= 0.0: armor = minf(armor + delta*8.0, armor_density.value)
	time_survived += delta
	magic_timer -= delta
	armor_regen_delay -= delta
	bounds_ignore -= delta
	melee_timer -= delta
	if is_floor: jumps = max_jumps.value_int
	
	# jumps
	var g_mult := 1.0
	jump_buffer -= delta
	wall_buffer -= delta
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer = 0.2
	if is_on_wall():
		wall_buffer = 0.1
		wall_normal = get_wall_normal()
		if velocity.y <= 0.0: g_mult *= 0.25
	if jump_buffer >= 0.0:
		# wall jump
		if wall_buffer >= 0.0:
			velocity += wall_normal * jump.value * 0.8
			velocity.y = jump.value
			jumps = max_jumps.value_int
			jump_buffer = -1.0
			VFXHandler.spawn(VFXHandler.PLAYER_DUST, global_position-Vector3(0.0, 1.3, 0.0), [uuid])
			SFXHandler.play_world(SFXHandler.JUMP, global_position-Vector3(0.0, 1.3, 0.0), 0.0)
		# normal jump
		elif jumps > 0:
			# jump higher based on horizontal velocity. ground jumps only
			var boost := Vector2(velocity.x, velocity.z).length()
			boost = boost / (boost + 32.0)
			if !is_floor: boost = 0.0
			velocity.y = maxf(velocity.y, 0.0) + jump.value*(1.0+boost)
			jumps -= 1
			jump_buffer = -1.0
			VFXHandler.spawn(VFXHandler.PLAYER_DUST, global_position-Vector3(0.0, 1.3, 0.0), [uuid])
			SFXHandler.play_world(SFXHandler.JUMP, global_position-Vector3(0.0, 1.3, 0.0), 0.0)
	
	# high jump & gravity
	if velocity.y > 0.0 && Input.is_action_pressed(&"jump"):
		g_mult *= 0.65
	velocity += Vector3(0.0, -32.0, 0.0) * delta * g_mult
	
	# handle movement
	var input_dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
	if is_floor || input_dir:
		var dir_3 := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var intent := Vector2(dir_3.x, dir_3.z) # flattened & transformed input direction
		movement_update_flat(self, intent, delta)
	
	# physics processing
	var pvel := velocity
	move_and_slide()
	
	# collisions
	for col_idx in get_slide_collision_count():
		var col := get_slide_collision(col_idx)
		
		# push objects
		var colc := col.get_collider()
		if colc is RigidBody3D:
			if (colc is LevelBody && (colc as LevelBody).is_harmful) && bounds_ignore <= 0.0:
				take_damage(DamageEvent.new(maxf(max_health.value * 0.2, health * 0.5), col.get_normal() * 24.0, DamageEvent.TYPE_BORDER))
				bounds_ignore = 0.1
			if (colc as RigidBody3D).freeze: continue
			var impact := -col.get_normal() * pvel.length()
			(colc as RigidBody3D).apply_central_impulse.rpc(impact * 0.5)
		
		# push players
		if colc is Player:
			var impact := -col.get_normal() * pvel.length()
			(colc as Player).take_damage_seralized.rpc(DamageEvent.new(0.0, impact * 0.45, DamageEvent.TYPE_MELEE).seralize())
	
	# melee
	if melee_timer >= 0.0:
		melee(pvel)
	
	# cast magic
	if Input.is_action_just_pressed(&"magic_1") && ( (last_magic == 0 && magic_timer <= 0.75) || (magic_timer <= 0.0) ):
		if spell_1.attempt_cast(self, last_magic == 0 && magic_timer > 0.0):
			last_magic = 0
	if Input.is_action_just_pressed(&"magic_2") && ( (last_magic == 1 && magic_timer <= 0.75) || (magic_timer <= 0.0) ):
		if spell_2.attempt_cast(self, last_magic == 1 && magic_timer > 0.0):
			last_magic = 1
	
	# fire gun
	var b_trans := camera.global_transform
	# TODO bullets dont clip camera. Fixed?
	# TODO make bullets fire from "gun"
	b_trans.origin += Vector3(0.0, -0.1, 0.0)
	# TODO fix input processing with menus during gameplay
	is_firing = (is_use) if full_auto else (Input.is_action_just_pressed(&"use"))
	var update_gun: bool = is_firing && can_shoot && !Input.is_action_pressed(&"view_info") && !Console.visible
	procgun.process(gun, b_trans, self, delta, update_gun)
	
	update_animation_data(delta)


func spectator_process(delta: float) -> void:
	var input_dir := Input.get_vector(&"left", &"right", &"forward", &"backward")
	var h_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var v_dir := Input.get_axis(&"slide", &"jump")
	
	global_position += Vector3(h_dir.x, v_dir, h_dir.z) * delta * (96.0 if Input.is_action_pressed(&"dash") else 32.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var iemm := event as InputEventMouseMotion
		var sens := 0.333 if is_use_alt else 1.0
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
		if event.is_action_pressed(&"melee") && melee_timer <= -melee_cd.value:
			melee_timer = 0.333
			melee_exclude = [get_rid()]
			animation_data[ANIM_MELEE] = 0.0


func _unhandled_key_input(event: InputEvent) -> void:
		var iek := event as InputEventKey
		if !Input.is_action_pressed(&"dbg_button"): return
		match iek.keycode:
			KEY_J when iek.pressed:
				var pp := camera.compositor.compositor_effects[0] as PanniniProjection
				pp.enabled = !pp.enabled
			KEY_K when iek.pressed:
				var de := DamageEvent.new(float(0xd1edeadd1e)**3, Vector3.ZERO, DamageEvent.TYPE_KILLBIND)
				if hud.info_holder.visible && !hud.info.player_name.text.is_empty():
					for pi:Network.PlayerInfo in Network.players.values():
						if pi.name == hud.info.player_name.text:
							Console.print(&"killbinded '%s'" % pi.name)
							de.source_entity = self
							pi.linked_player.take_damage_seralized.rpc(de.seralize())
				else:
					Console.print(&"killbinded")
					take_damage(de)
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
				armor = armor_density.value
			KEY_I when iek.pressed:
				is_immortal = !is_immortal
			KEY_T when iek.pressed:
				update_cards()
			KEY_M when iek.pressed:
				for i in 10: add_card(Card.ALL_CARDS.pick_random() as Card)
			KEY_J when iek.pressed:
				full_auto = !full_auto
			KEY_A when iek.pressed:
				var trans := camera.global_transform
				var radius := 16.0 * 1.0
				trans.origin = global_position + camera.global_basis.z * -0.5*(radius + 4.0)
				FieldHandler.spawn(FieldHandler.WIND, trans, radius, 8.0, 2.0)


func dash() -> void:
	SFXHandler.play_world(SFXHandler.DASH, global_position)
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
			var bonus := maxf(0.1, velocity.normalized().dot(target) * 0.9)
			velocity = velocity*bonus + Vector3(target.x, target.y, target.z)*speed.value*0.85


func melee(vel: Vector3) -> void: # TODO cleanup
	var dss: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var pos := global_position + (camera.global_basis * Vector3(0.0, 0.0, -1.3))
	melee_psqp.transform.origin = pos
	melee_psqp.exclude = melee_exclude
	
	# hit players
	melee_psqp.collision_mask = 0b0010_0010
	var bonus := velocity.length_squared()
	bonus = bonus / (bonus + (64.0**2))
	melee_shape.radius = 1.2 + bonus*1.2
	var rest := dss.get_rest_info(melee_psqp)
	if !rest.is_empty():
		var cid := rest[&"collider_id"] as int
		var colc := instance_from_id(cid) as PhysicsBody3D
		melee_exclude.append(colc.get_rid())
		if colc is Player:
			var pl := colc as Player
			var dir := global_position.direction_to(pl.global_position) * 12.0
			var de := DamageEvent.new(melee_damage.value, dir + vel*1.2, DamageEvent.TYPE_MELEE)
			de.source_entity = self
			pl.take_damage_seralized.rpc(de.seralize())
			hud.hit_marker_timer = 0.15
			SFXHandler.play_world_local(SFXHandler.HIT, pl.global_position, -0.15, 1.0, true)
		
		var norm := (rest[&"normal"] as Vector3).slerp(camera.global_basis.z, 0.5)
		var point := rest[&"point"] as Vector3
		_melee_hit(vel, point, norm, colc)
		return
	
	# hit objects
	melee_psqp.collision_mask = 0b0001_0001
	melee_shape.radius = 0.75
	while _melee_test_objects(dss, vel):
		melee_psqp.exclude = melee_exclude
		vel = velocity


func _melee_test_objects(dss: PhysicsDirectSpaceState3D, vel: Vector3) -> bool:
	var rest := dss.get_rest_info(melee_psqp)
	if !rest.is_empty():
		var cid := rest[&"collider_id"] as int
		var colc := instance_from_id(cid) as PhysicsBody3D
		melee_exclude.append(colc.get_rid())
		
		if colc is LevelBody:
			var dir := global_position.direction_to(colc.global_position) * 16.0
			var ipos := rest.get(&"position", colc.global_position) as Vector3
			var dmg := melee_damage.value * (1.0 + Util.hp(velocity.length_squared(), 32.0**2))
			(colc as LevelBody).take_proj_hit.rpc_id(1, dmg, dir, ipos)
			# kick through breakable levelbodies
			if (colc as LevelBody).bodytype == LevelBody.Type.BREAKABLE && (colc as LevelBody).health-dmg <= 0.0:
				_melee_hit(vel, rest[&"point"] as Vector3, Vector3.ZERO, colc)
				melee_timer = minf(0.3333, melee_timer + 0.1111)
				animation_data[ANIM_MELEE] = 1.0 - (melee_timer * 3.0)
				return true
		
		elif colc is RigidBody3D:
			var dir := global_position.direction_to(colc.global_position) * melee_damage.value * 4.0
			(colc as RigidBody3D).apply_central_impulse.rpc(dir + vel*1.2)
		
		var norm := (rest[&"normal"] as Vector3).slerp(camera.global_basis.z, 0.15)
		var point := rest[&"point"] as Vector3
		_melee_hit(vel, point, norm, colc)
		return true
	return false



func _melee_hit(vel: Vector3, pos: Vector3, normal: Vector3, pb3d: PhysicsBody3D) -> void:
	if normal && vel.dot(normal) < 0.0:
		velocity = vel.bounce(normal)
		if velocity:
			velocity *= 1.0 + maxf(velocity.normalized().dot(normal)*0.1, 0.0)
	jumps = max_jumps.value_int
	
	var ed := EventHook.EventData.from_player(self)
	ed.position = pos
	ed.normal = normal
	ed.hit_pb3d = pb3d
	melee_hook.execute(ed)
	
	VFXHandler.spawn(VFXHandler.PLAYER_DUST, pos, [uuid, 4.0])
	SFXHandler.play_world(SFXHandler.KICK, pos, -15)


func game_start() -> void:
	stasis = Vector3.ZERO
	time_survived = 0.0
	can_shoot = true
	update_cards()
	await get_tree().create_timer(1.0).timeout
	is_immortal = false
	if (!Network.is_server && Console.CLIENT_DUMMY):
		enter_spectator()


@rpc("any_peer", "call_local", "reliable")
func take_damage_seralized(data: Array[Variant]) -> void:
	if !is_multiplayer_authority(): return
	var de := DamageEvent.deseralize(data)
	take_damage(de)

func take_damage(de: DamageEvent) -> void:
	de.target_entity = self
	
	var hp := armor_density.value
	hp = hp / (hp + 64)
	var dr := lerpf(0.75, 1.0-(hp*0.95), armor/armor_density.value)
	if armor > 0.0: de.amount *= dr
	
	var ed := EventHook.EventData.from_player(self)
	ed.damage = de
	damage_hook.execute(ed)
	
	velocity += de.knockback
	
	if is_immortal: return
	if de.source_entity:
		last_damage_uuid = de.source_uuid
		last_damage_stamp = time_survived
	
	
	var armor_broke := armor > 0.0 && armor-de.amount <= 0.0
	armor = maxf(armor - de.amount, 0.0)
	if armor_broke:
		ed = EventHook.EventData.from_player(self)
		ed.damage = de
		armor_break_hook.execute(ed)
	health -= de.amount
	armor_regen_delay = 1.0
	
	VFXHandler.spawn(VFXHandler.PLAYER_DUST, global_position, [uuid])
	SFXHandler.play_user(SFXHandler.HURT, -0.5)
	hud.hurt_timer = 0.35
	if health <= 0.0 && !is_immortal:
		if !de.source_uuid && (time_survived - last_damage_stamp) <= 4.0:
			de.source_uuid = last_damage_uuid
			de.source_entity = Network.player_from_uuid(de.source_uuid)
		Network.death_message.rpc(de.seralize())
		
		if de.source_entity && de.source_entity is Player:
			(de.source_entity as Player)._on_player_kill.rpc()
		
		Console.print(&"im so dead :c bleh")
		death()


func on_round_end(won: bool) -> void:
	respawn()
	if won:
		hud.win_lose_timer = 3.0
		hud.is_win = true
		SFXHandler.play_user(SFXHandler.POWERUP, 0.0)
	else:
		SFXHandler.play_user(SFXHandler.LOSE, 0.0)


func death() -> void:
	sync_kd.rpc(kills, deaths + 1)
	VFXHandler.spawn(VFXHandler.PLAYER_DEATH, global_position, [uuid])
	SFXHandler.play_world(SFXHandler.DEATH, global_position, 1.0)
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
	armor = armor_density.value
	exit_spectator.rpc()
	scale = Vector3.ONE


@rpc("authority", "call_local", "reliable")
func enter_spectator() -> void:
	is_spectator = true
	visible = false
@rpc("authority", "call_local", "reliable")
func exit_spectator() -> void:
	is_spectator = false
	visible = true
	velocity = Vector3.ZERO


@rpc("any_peer", "call_local", "reliable")
func _on_player_kill() -> void:
	sync_kd.rpc(kills + 1, deaths)
	health += 0.5 * (max_health.value - health)
@rpc("authority", "call_local", "reliable")
func sync_kd(k: int, d: int) -> void:
	kills = k
	deaths = d


#region cards

func _card_adder(deck: Dictionary[Card, int], card: Card, count: int = 1, netsync: bool = true) -> void:
	count = deck.get(card, 0) + count
	deck[card] = count
	if netsync: Network.update_card_picked.rpc(card.uuid, count) # TODO netsync cards
	if count <= 0: deck.erase(card)


func add_card(card: Card, count: int = 1) -> void:
	_card_adder(cards, card, count)


func add_spell_card(card: Card, spell: Spell, count: int = 1) -> void:
	_card_adder(cards, card, count)
	_card_adder(spell.cards, card, count, false)


func update_cards() -> void:
	reset_stats()
	var cd := Card.CardData.from_player(self)
	
	for card in cards: # for each card
		if card.use_spell_selection: continue
		cd.n = cards[card]
		card.card_effect.call(cd)
	
	cd.selected_spell = spell_1
	for card in spell_1.cards: # for each card spell 1
		if !card.use_spell_selection: continue
		cd.n = spell_1.cards[card]
		card.card_effect.call(cd)
	
	cd.selected_spell = spell_2
	for card in spell_2.cards: # for each card spell 2
		if !card.use_spell_selection: continue
		cd.n = spell_2.cards[card]
		card.card_effect.call(cd)
	
	calculate_stats()
	update_spider_graphs()
	gun.clip = procgun.clip_size.value_int
	gun.reload = 0.0
	health = max_health.value
	armor = armor_density.value

#endregion

#region animations

enum {ANIM_STATE, ANIM_VELOCITY, ANIM_DIRECTION, ANIM_MELEE, ANIM_MAGIC, ANIM_RELOAD, ANIM_HEALTH, ANIM_HURT, ANIM_ARMOR}
var animation_data: Array[float] = [0.0, 0.0, 0.0, 2.0, 0.0, 0, 0.0, 0.5, 1.0, 0.0]

func update_animation_data(delta: float) -> void:
	animation_data[ANIM_STATE] = (is_floor)
	
	animation_data[ANIM_VELOCITY] = velocity.length_squared()
	animation_data[ANIM_DIRECTION] = Vector2(velocity.x, velocity.z).angle()
	animation_data[ANIM_MELEE] += delta * 3.0
	animation_data[ANIM_MAGIC] = magic_timer
	animation_data[ANIM_RELOAD] = (gun.reload*PI*2.0/procgun.reload_time.value) if (gun.reload) else (1.0-gun.fire_timer)**3.0*2.0
	animation_data[ANIM_HEALTH] = health / max_health.value
	animation_data[ANIM_HURT] = move_toward(animation_data[ANIM_HURT], health / max_health.value, delta*2.0)
	animation_data[ANIM_HURT] = max(animation_data[ANIM_HURT], animation_data[ANIM_HEALTH])
	animation_data[ANIM_ARMOR] = armor / armor_density.value


func update_spider_graphs() -> void:
	recalc_spider_graph()
	procgun.recalc_spider_graph()
	spell_1.recalc_spider_graph(self)
	spell_2.recalc_spider_graph(self)
	spider = [
		spider[0],
		spider[1],
		spider[2],
		procgun.spider[0],
		procgun.spider[1],
		procgun.spider[2],
		spell_1.spider[0],
		spell_1.spider[1],
		spell_1.spider[2],
		spell_2.spider[0],
		spell_2.spider[1],
		spell_2.spider[2],
	] as PackedFloat64Array
	_sync_spider_graph.rpc(spider)


func recalc_spider_graph() -> void:
	var melee_hk := Stat.new(&"melee_hk", 1)
	melee_hk.adder += melee_hook.get_effect_count()
	Util.calculate_spider(spider, [
		[melee_hk, melee_cd, melee_damage], # melee
		[speed, accel, jump, max_jumps, max_stamina], # agility
		[max_health, armor_density, armor_regen] # defense
	])


@rpc("authority", "call_remote", "reliable")
func _sync_spider_graph(data: PackedFloat64Array) -> void:
	spider = data


#endregion
