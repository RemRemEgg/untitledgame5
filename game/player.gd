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
@onready var health_gradient := (healthbar.texture as GradientTexture2D).gradient


var is_spectator: bool = false
var is_immortal: bool = true
var stasis: Vector3 = Vector3.ZERO
var time_survived: float = 0.0


func set_data(data: Network.PlayerInfo) -> void:
	camera = $camera as Camera3D
	camera.current = true
	player_model = $player_model as PlayerModel
	
	var col := (data.color + Color.WHITE*0.5) / 1.5
	var mat := player_model.material as StandardMaterial3D
	mat.albedo_color = data.color
	(mat.next_pass as ShaderMaterial).set_shader_parameter(&"color", Vector3(col.r, col.g, col.b))
	
	($nametag as Label3D).visible = false
	hud = $camera/hud as HUD
	uuid = data.uuid


var cards: Dictionary[Card, int]
var deck_weights: Dictionary[CardDeck, float]
var stamina: float = 0.0
var magic_timer: float = 0.0
var melee_timer: float = -1.0
var is_floor: bool = 0
var is_use: bool = false
var is_use_alt: bool = false
var is_prep_cast: bool = false
var is_firing: bool = false
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
## Default false
var full_auto := false
## Default 8.0
var jump := Stat.new(&"Jump Height", 8.0, 0.5)
## Default 2
var max_jumps := Stat.new(&"Jumps", 2, 1)
## Default 1
var max_stamina := Stat.new(&"Stamina", 1.0, 0.0)
## Default 0.7
var melee_cd := Stat.new(&"Melee CD", 0.7, 0.01, 9e9, false)
## Default 1.0
var magic_cd := Stat.new(&"All Spell CD", 1.0, 0.01, 9e9, false)
## [b]Multiplier[/b] for all spell potency. Default 1.0
var magic_potency := Stat.new(&"All Spell Potency", 1.0, 0.0, 9e9)

## Hook for player shooting their gun
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var shooting_hook := EventHook.new()
## Hook for player taking damage. Player is [code]de.target_entity[/code].
## [codeblock]func(n:int, de:DamageEvent) -> void:[/codeblock]
var damage_hook := EventHook.new()
## Hook for player casting any spells. Called once per spell cast, not once per effect
var spell_hook := EventHook.new()
## First spell
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var spell_1 := Spell.new()
## Second spell
## [codeblock]func(n:int, p:Player) -> void:[/codeblock]
var spell_2 := Spell.new()
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
	max_stamina.reset_value()
	melee_cd.reset_value()
	magic_cd.reset_value()
	
	shooting_hook.clear_effects()
	damage_hook.clear_effects()
	spell_hook.clear_effects()
	
	procgun.reset_stats()
	spell_1.reset_stats()
	spell_2.reset_stats()


func calculate_stats() -> void:
	max_health.calculate_value()
	speed.calculate_value()
	jump.calculate_value()
	max_jumps.calculate_value()
	accel.calculate_value()
	max_stamina.calculate_value()
	melee_cd.calculate_value()
	magic_cd.calculate_value()
	
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
	
	Network.add_proj_spawner(proj_spawner, true)


func _process(delta: float) -> void:
	max_health.update(delta)
	speed.update(delta)
	jump.update(delta)
	max_jumps.update(delta)
	accel.update(delta)
	max_stamina.update(delta)
	melee_cd.update(delta)
	magic_cd.update(delta)
	
	spell_1.process(self, delta)
	spell_2.process(self, delta)
	
	if stasis:
		velocity = Vector3.ZERO
		global_position = stasis
		update_animation_data(delta)
		return
	if is_spectator: return spectator_process(delta)
	
	is_floor = is_on_floor()
	is_use = Input.is_action_pressed(&"use")
	is_use_alt = Input.is_action_pressed(&"use_alt")
	is_prep_cast = Input.is_action_pressed(&"magic")
	camera.fov = move_toward(camera.fov, (40.0) if (is_use_alt && !is_prep_cast) else (115.0), delta*800.0)
	stamina = minf(stamina + delta * (1.2 if is_floor else 0.6), max_stamina.value) # dash recharge
	time_survived += delta
	#magic_charges = minf(magic_charges + (delta / magic_cd.value), max_magic.value_int)
	magic_timer -= delta
	bounds_ignore -= delta
	melee_timer -= delta
	if is_floor: jumps = max_jumps.value_int
	
	# gravity
	velocity += Vector3(0.0, -32.0, 0.0) * delta
	
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
		Network.spawn_visual(Network.NV_PARTICLE_BURST, global_position-Vector3(0.0, 1.0, 0.0), 1.0)
	# high jump
	if velocity.y > 0 && Input.is_action_pressed(&"jump"): velocity -= Vector3(0.0, -32.0, 0.0) * delta * 0.35
	# wall jump
	if wall_cyote >= 0.0 && cyote >= 0.0:
		var wall := get_wall_normal()
		velocity += wall * jump.value * 0.8
		velocity.y = jump.value
		cyote = -1.0
		Network.spawn_visual(Network.NV_PARTICLE_BURST, global_position-Vector3(0.0, 1.0, 0.0), 1.0)
	
	
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
		
		# push objects
		var colc := col.get_collider()
		if colc is RigidBody3D:
			if (colc is LevelBody && (colc as LevelBody).is_harmful) && bounds_ignore <= 0.0:
				take_damage(maxf(max_health.value * 0.2, health * 0.5),
						col.get_normal() * (32.0 if magic_timer >= 0.0 else 16.0))
				bounds_ignore = 0.1
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
	
	# cast magic
	if is_prep_cast && (is_use || is_use_alt) && (magic_timer <= 0.0):
		(spell_2 if is_use_alt else spell_1).attempt_cast(self)
	
	# fire gun
	var b_trans := camera.global_transform
	# TODO bullets dont clip camera. Fixed?
	# TODO make bullets fire from "gun"
	b_trans.origin += Vector3(0.0, -0.2, 0.0)
	# TODO fix input processing with menus during gameplay
	is_firing = (is_use) if full_auto else (Input.is_action_just_pressed(&"use"))
	var update_gun: bool = is_firing && can_shoot && !Input.is_action_pressed(&"view_info") && !Console.visible && !is_prep_cast
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
			animation_data[ANIM_MELEE] = 0.0


func _unhandled_key_input(event: InputEvent) -> void:
		var iek := event as InputEventKey
		if !Input.is_action_pressed(&"dbg_button"): return
		match iek.keycode:
			KEY_J when iek.pressed:
				var pp := camera.compositor.compositor_effects[0] as PanniniProjection
				pp.enabled = !pp.enabled
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
			KEY_I when iek.pressed:
				is_immortal = !is_immortal
			KEY_T when iek.pressed:
				update_cards()
			KEY_M when iek.pressed:
				for i in 10: add_card(Card.ALL_CARDS.pick_random() as Card)
			KEY_J when iek.pressed:
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


func melee() -> void: # TODO cleanup
	var dss: PhysicsDirectSpaceState3D = Game.world.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	var psqp := PhysicsShapeQueryParameters3D.new()
	psqp.exclude = [get_rid()]
	psqp.shape = shape
	var pos := global_position + (camera.global_basis * Vector3(0.0, 0.0, -0.85))
	psqp.transform.origin = pos
	
	# hit players
	psqp.collision_mask = 0b0010_0010
	shape.radius = 1.2
	var rest := dss.get_rest_info(psqp)
	if !rest.is_empty():
		var cid := rest[&"collider_id"] as int
		var colc := instance_from_id(cid) as PhysicsBody3D
		if colc is Player:
			var pl := colc as Player
			var dir := global_position.direction_to(pl.global_position) * 12.0
			pl.take_damage.rpc(5.0, dir + velocity*1.2)
			hud.hit_marker_timer = 0.15
		
		var norm := rest[&"normal"] as Vector3
		var point := rest[&"point"] as Vector3
		_melee_hit(point, norm)
		return
	
	# hit objects
	psqp.collision_mask = 0b0001_0001
	shape.radius = 1.0
	rest = dss.get_rest_info(psqp)
	if !rest.is_empty():
		var cid := rest[&"collider_id"] as int
		var colc := instance_from_id(cid) as PhysicsBody3D
		if colc is RigidBody3D:
			var dir := global_position.direction_to(colc.global_position) * 16.0
			(colc as RigidBody3D).apply_central_impulse.rpc(dir + velocity*1.2)
		
		var norm := rest[&"normal"] as Vector3
		var point := rest[&"point"] as Vector3
		_melee_hit(point, norm)


func _melee_hit(pos: Vector3, normal: Vector3) -> void:
	velocity = velocity.bounce(normal)
	if velocity:
		velocity *= 1.0 + maxf(velocity.normalized().dot(normal)*0.1, 0.0)
	melee_timer = -0.01
	jumps = max_jumps.value_int
	Network.spawn_visual(Network.NV_PARTICLE_BURST, pos, 4.0)


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
# TODO fix bounds, split take_hit / take_damage?
func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if !is_multiplayer_authority(): return
	
	var de := DamageEvent.new(amount, knockback)
	de.target_entity = self
	
	var ed := EventHook.EventData.from_player(self)
	for effect:EventHook.EventEffect in damage_hook:
		effect.execute(ed, de)
	
	velocity += de.knockback
	if is_immortal: return
	
	health -= de.damage
	Network.spawn_visual(Network.NV_PARTICLE_BURST, global_position, 1.0)
	hud.hurt_timer = 0.35
	if health <= 0.0 && !is_immortal:
		var rsi := multiplayer.get_remote_sender_id()
		if rsi: Network.death_message.rpc(rsi)
		Console.print(&"im so dead..... bleh")
		death()


func on_round_end(won: bool) -> void:
	respawn()
	if won:
		hud.win_lose_timer = 3.0
		hud.is_win = true


func death() -> void:
	Network.spawn_visual(Network.NV_DEATH, global_position, 1.0, uuid)
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
	gun.clip = procgun.clip_size.value_int
	gun.reload = 0.0
	health = max_health.value

#endregion

#region animations

enum {ANIM_STATE, ANIM_VELOCITY, ANIM_DIRECTION, ANIM_MELEE, ANIM_MAGIC, ANIM_RELOAD, ANIM_HEALTH, ANIM_HURT}
var animation_data: Array[float] = [0.0, 0.0, 0.0, 2.0, 0.0, 0, 0.0, 0.5, 1.0]

func update_animation_data(delta: float) -> void:
	animation_data[ANIM_STATE] = (is_floor)
	
	animation_data[ANIM_VELOCITY] = velocity.length_squared()
	animation_data[ANIM_DIRECTION] = Vector2(velocity.x, velocity.z).angle()
	animation_data[ANIM_MELEE] += delta * 3.0
	animation_data[ANIM_MAGIC] = magic_timer
	animation_data[ANIM_RELOAD] = (-gun.reload/procgun.reload_time.value) if (gun.reload) else (1.0-gun.fire_timer)
	animation_data[ANIM_HEALTH] = health / max_health.value
	animation_data[ANIM_HURT] = move_toward(animation_data[ANIM_HURT], health / max_health.value, delta*2.0)
	animation_data[ANIM_HURT] = max(animation_data[ANIM_HURT], animation_data[ANIM_HEALTH])

#endregion
