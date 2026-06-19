class_name Card
extends RefCounted

const CARD_3D_WRAPPER := preload("uid://tp7ecpbxfw28")


static var ALL_CARDS: Array[Card] = []
static var DECKS: Array[CardDeck]

static var BASE_DECK: CardDeck
static var BLOCK_DECK: CardDeck
static var TEMP_DECK: CardDeck

# TODO event hooks

const SPIDER_HUES: Array[float] = [0.97083, 0.13750, 0.30417, 0.47083, 0.63750, 0.80417]
static func spider_to_color(data: Array[float]) -> Color:
	if data.size() != 6: return Color.WHITE
	var s := 0.0
	var a := Vector2.ZERO
	for i in data.size():
		a += Vector2.RIGHT.rotated(SPIDER_HUES[i]*PI*2.0*maxf(0.0, data[i]))
		s += maxf(0.0, data[i])
	a /= s
	return Color.from_hsv(a.angle()/(PI/2.0), 1.0, 1.0)


#            INTERNAL         GREEN          YELLOW          BLUE         PURPLE
enum {RARITY_INTERNAL, RARITY_COMMON, RARITY_UNUSUAL, RARITY_RARE, RARITY_EPIC}
const RARITY_COLORS: Array[StringName] = [&"#555555", &"1ad933", &"fff200", &"33cce6", &"ff00ff"]
# NYI
enum {STYLE_INTERNAL, STYLE_BASIC}

var uuid: StringName
var name: StringName
var abbv: StringName
var rarity: int
var style: int
var spider: Array[float] # [Toughness, Sp.Def, Agility, Lethality, Ammo, Sp.Atk]
var desc: StringName
var card_effect: Callable
var display: CardDisplay
var wrapper_3d: Sprite3D


func _to_string() -> String: return &"%s[R:%s S:%s]" % [name, rarity, style]


static func get_card(card_uuid: StringName) -> Card:
	var idx := ALL_CARDS.find_custom(func(c:Card)->bool: return c.uuid == card_uuid)
	if idx == -1: return null
	return Card.ALL_CARDS[idx]


## [b]TODO documentation needs rework. Most information is outdated![/b][br]
## Adds a new card to the main card pool
##[br][br][b]uuid[/b]: Internal id of the card, must be unique, only a-z,0-9,_ allowed. ex &"impact_plates"
##[br][br][b]name[/b]: Display name of the card, max 16 chars. ex &"Impact Plates"
##[br][br][b]abbv[/b]: Abbreviation, max 3 chars. ex &"IP"
##[br][br][b]rarity[/b]: One of the rarity types, determines spawn chance and border. ex RARITY_EPIC
##[br][br][b]style[/b]: TODO, set to STYLE_BASIC.
##[br][br][b]spider[/b]: Info for spider charts. [Toughness, Sp.Def, Agility, Lethality, Ammo, Sp.Atk].
## Should be proportion of how the card effects the player, ex +77% tough, -30% spd -> [.77, 0.0, -0.3, 0.0, 0.0, 0.0]
##[br][br][b]desc[/b]: Card description. Use color tags ($d, $p, $n, $s) to mark lines as description/positive/negative/special, respectively.
## Color tags will apply until another tag is specificed. Seperate lines with \n\, BBCode is enabled.
##[codeblock]&"$dConverts 35% of damage taken to knockback taken\n\
##$p+15% Max Health\n\
##$n-20% Speed\n\
##-10% Jump Height"[/codeblock]
##[br][br][b]effect[/b]: Code ran to apply card effects. Function signature is [br][code]func(player: Player, gun: ProcGun, proj: ProcProj) -> void:[/code].
##[br][param player] is the [Player] that chose this card
##[br][param gun] is the [ProcGun] that this player holds
##[br][param proj] is the [ProcProj] that the gun shoots
##[br][i]Note: These are not the gun/projectiles themselves, they are the [ProcGun]/[ProcProj]![/i]
##[codeblock]func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
##player.max_health *= 1.15
##player.speed *= 0.8
##player.jump *= 0.9
### [Event hooks go here]
##[/codeblock]
##[br][br][b]Event Hooks[/b]
##[br]Event hooks are lambdas called when the event is triggered. For specific hook signatures, look at the hook's documentation.
##[codeblock]hook(player.damage_hooks, func(de:DamageEvent) -> DamageEvent:
##		# Get percent health
##		var amount := clampf(de.damage / player.max_health, 0.0, 1.0)
##		# Increase knockback based on damage
##		de.knockback += de.knockback.normalized() * amount * 10.0
##		# Reduce damage taken
##		de.damage *= 0.65
##		# Return is required by this hook
##		return de
##)[/codeblock]
##[br]Hook List:
##[br][member Player.damage_hooks]
##[br][member ProcProj.damage_hooks]
##[br][member ProcProj.collide_hooks]
##[br][br]
##[b]Putting it all together[/b]
##[br]An example card is shown below, using the example parameters given.
##[codeblock]
##register_card(&"impact_plates", &"Impact Plates", &"IP", RARITY_EPIC, STYLE_BASIC,
##	[.77, 0.0, -0.3, 0.0, 0.0, 0.0],
##	&"$dConverts 35% of damage taken to knockback taken\n\
##	$p+15% Max Health\n\
##	$n-20% Speed\n\
##	-10% Jump Height",
##	func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
##		player.max_health *= 1.15
##		player.speed *= 0.8	
##		player.jump *= 0.9
##		hook(player.damage_hooks, func(de:DamageEvent) -> DamageEvent:
##			var amount := clampf(de.damage / player.max_health, 0.0, 1.0)
##			de.knockback += de.knockback.normalized() * amount * 10.0
##			de.damage *= 0.65
##			return de
##		)
##)
##[/codeblock]
static func register_card(deck: CardDeck, uuid_: StringName, name_: StringName, abbv_: StringName, rarity_: int, style_: int, spider_: Array[float], desc_: StringName, effect: Callable) -> void:
	Console.print(&"Loading card %s" % uuid_)
	
	var uuid_exists := ALL_CARDS.find_custom(func(c:Card)->bool: return c.uuid == uuid_) + 1
	if uuid_exists:
		Console.print_err(&"Cannot load card %s(%s), uuid is already in use" % [uuid_, name_])
		return
	
	if name_.is_empty() || name_.length() > 32:
		Console.print_err(&"Cannot load card %s(%s), name is too long or nonexistant" % [uuid_, name_])
		return
	
	if abbv_.is_empty() || abbv_.length() > 3:
		Console.print_err(&"Cannot load card %s(%s), abbv is too long or nonexistant" % [uuid_, name_])
		return
	
	if spider_.size() != 6:
		Console.print_err(&"Cannot load card %s(%s), spider must have 6 entries" % [uuid_, name_])
		return
	
	var card := new()
	card.uuid = uuid_
	card.name = name_
	card.abbv = abbv_
	card.rarity = rarity_
	card.style = style_
	card.spider = Util.normalize_array(spider_)
	card.desc = desc_.replace(&"\t", &"")\
					.replace(&"$d", &"[color=#fff]")\
					.replace(&"$p", &"[color=green]")\
					.replace(&"$n", &"[color=red]")\
					.replace(&"$s", &"[color=aqua]") + &"[/color]"
	card.card_effect = effect
	card.display = CardDisplay.from_card(card, deck)
	card.wrapper_3d = CARD_3D_WRAPPER.instantiate() as Sprite3D
	card.wrapper_3d.get_child(0).add_child(card.display)
	
	ALL_CARDS.append(card)
	deck.cards.append(card)
	Console.print(&"Loaded %s" % card)


static func register_all_decks() -> void:
	BASE_DECK = CardDeck.new(&"base", load("res://textures/cards/card_example.png") as Texture2D)
	DECKS.append(BASE_DECK)
	BLOCK_DECK = CardDeck.new(&"block", load("res://textures/cards/card_example_2.png") as Texture2D)
	DECKS.append(BLOCK_DECK)
	TEMP_DECK = CardDeck.new(&"temp", load("res://textures/cards/card_example_3.png") as Texture2D)
	DECKS.append(TEMP_DECK)



static func register_all_cards() -> void:
	@warning_ignore_start("unused_parameter")
	
	#region BASE_DECK
	
	register_card(BASE_DECK, &"rubber_bullets", &"Rubber Bullets", &"RB", RARITY_UNUSUAL, STYLE_BASIC,
		[.77, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$dBoing!\n\
		$p+1 Bullet Bounce\n\
		$n-15% Bullet Damage",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			proj.bounces.adder += n
			proj.damage.multiplier *= 0.85 ** n
	)
	
	register_card(BASE_DECK, &"heavy_hitter", &"Heavy Hitter", &"HV", RARITY_COMMON, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$p+35% Damage\n\
		$n-15% Fire Rate",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			proj.damage.multiplier *= 1.35 ** n
			gun.fire_rate.multiplier *= 0.85 ** n
	)
	
	register_card(BASE_DECK, &"big_bullets", &"Big Bullets", &"BB", RARITY_COMMON, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$p+80% Bullet Size\n\
		$n-40% Bullet Speed",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			proj.scale.multiplier *= 1.8 ** n # TODO fix: projectiles are synced before card effect applies
			gun.b_speed.multiplier *= 0.6 ** n
	)
	
	register_card(BASE_DECK, &"fastball", &"Fastball", &"FB", RARITY_UNUSUAL, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$p+30% Bullet Speed\n\
		$n-10% Fire Rate",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			gun.b_speed.multiplier *= 1.3 ** n
			gun.fire_rate.multiplier *= 0.9 ** n
	)
	
	register_card(BASE_DECK, &"overclock_fm", &"Overclocked Firing Mechanism", &"OC", RARITY_EPIC, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$p+100% Gun Rate of Fire\n\
		+4 Clip Size\n\
		$n-50% Damage\n\
		+0.5s Reload Time",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			gun.fire_rate.multiplier *= 2.0 ** n
			gun.clip_size.adder += 4 * n
			proj.damage.multiplier *= 0.5 ** n
			gun.reload_time.adder += 0.5 * n
	)
	
	register_card(BASE_DECK, &"iron_cannon", &"Iron Cannon", &"IC", RARITY_RARE, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$p+25 Knockback\n\
		+25% Bullet Size\n\
		+15% Damage\n\
		$n-50% Fire Rate\n\
		-2 Ammo",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			proj.knockback.adder += 25.0 * n
			proj.scale.multiplier *= 1.25 ** n
			proj.damage.multiplier *= 1.15 ** n
			gun.fire_rate.multiplier *= 0.5 ** n
			gun.clip_size.adder += -2 * n
	)
	
	#endregion
	
	
	#region BLOCK_DECK
	
	#var temp_block_effect := func(n:int,p:Player) -> void:
		#Console.print("block dash, n:%s" % n)
		#var vel := p.velocity
		#p.velocity = -p.camera.global_basis.z * 128.0 * n
		#vel += p.velocity * 0.125
		#p.move_and_slide()
		#p.velocity = vel
	#register_card(BLOCK_DECK, &"temp_block", &"Block Launch", &"BL", RARITY_RARE, STYLE_BASIC,
		#[0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
		#&"$dDash forward on block\n\
		#$p-50% Block Cooldown",
		#func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			#player.block_cd.multiplier *= 0.5
			#player.block_effect_hook.add_hook(temp_block_effect)
	#)
	
	
	var block_effect_dash := func block_effect_dash(n:int, p:Player) -> void:
		var vel := p.velocity
		p.velocity = -p.camera.global_basis.z * 32.0 * n
		vel += p.velocity * 0.12 * n
		p.move_and_slide()
		p.velocity = vel
	register_card(BLOCK_DECK, &"temp_block", &"Block Launch", &"Bl", RARITY_RARE, STYLE_BASIC,
		[0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
		&"$dDash forward on block\n\
		$n+30% Block Cooldown",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			player.block_cd.multiplier *= 1.30 ** n
			player.block_hook.add_effect(n, block_effect_dash)
	)
	
	register_card(BLOCK_DECK, &"impact_plates", &"Impact Plates", &"IP", RARITY_EPIC, STYLE_BASIC,
		[.77, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$dConverts 35% of damage taken to knockback taken\n\
		$p+20 Max Health\n\
		$n-20% Speed\n\
		-10% Jump Height",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			player.max_health.adder += 20.0
			player.speed.multiplier *= 0.8
			player.jump.multiplier *= 0.9
			player.damage_hook.add_effect(n, func(de:DamageEvent) -> void:
				var amount := clampf(de.damage / player.max_health.value, 0.0, 1.0)
				de.knockback += de.knockback.normalized() * amount * 10.0 * n
				de.damage *= 0.65 ** n
			)
	)
	
	register_card(BLOCK_DECK, &"fat_fucking_chud", &"Fat Fucking Chud", &"FC", RARITY_RARE, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$p+50% Health\n\
		$n-10% Speed\n\
		-10% Jump Height\n\
		-10% Acceleration",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			player.max_health.multiplier *= 1.5 ** n
			player.speed.multiplier *= 0.9 ** n
			player.jump.multiplier *= 0.9 ** n
			player.accel.multiplier *= 0.9 ** n
	)
	
	register_card(BLOCK_DECK, &"get_yoked", &"Get Yoked", &"GY", RARITY_UNUSUAL, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$p+15% Speed\n\
		+15% Jump\n\
		+15% Acceleration\n\
		+1 Max Stamina",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			player.speed.multiplier *= 1.15 ** n
			player.jump.multiplier *= 1.07238052947636087 ** n # jump might be exp
			player.accel.multiplier *= 1.15 ** n
			player.stamina_max.adder += n
	)
	
	#endregion
	
	
	#region TEMP_DECK
	
	var ultralight_effect := func ultralight_effect(n:int, de:DamageEvent) -> void:
		de.knockback *= 1.8 ** n
	register_card(TEMP_DECK, &"ultralight", &"Ultralight", &"UL", RARITY_COMMON, STYLE_BASIC,
		[-0.5, 0.0, 1.5, 0.0, 0.0, 0.0],
		&"$dNow with 10% more Speed per Speed!\n\
		$p+60% Movement Speed\n\
		+30% Acceleration\n\
		$n+80% Knockback Taken",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			player.speed.multiplier *= 1.6 ** n
			player.accel.multiplier *= 1.3 ** n
			player.damage_hook.add_effect(n, ultralight_effect)
	)
	
	#var spacial_warp_effect := func(n:int, bullet:Projectile, collider:CollisionObject3D) -> void:
		#Network.move_object.rpc(collider.get_path(), bullet.position)
	#register_card(TEMP_DECK, &"spacial_warp", &"Spacial Warp", &"SW", RARITY_EPIC, STYLE_BASIC,
		#[0.0, 0.0, 0.0, 0.0, 0.0, 1.0],
		#&"[color=green]Warp objects to projectile on hit",
		#func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			#proj.collide_hook.add_effect(n, spacial_warp_effect)
	#)
	
	var swap_effect := func(n:int, bullet:Projectile, hit_player:Player) -> void:
		if bullet.ownr:
			var pos := hit_player.position
			Network.move_object.rpc(hit_player.get_path(), bullet.ownr.position)
			bullet.ownr.position = pos
	register_card(TEMP_DECK, &"swap", &"Swap", &"SW", RARITY_RARE, STYLE_BASIC,
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$pSwap positions with a player you hit",
		func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			proj.damage_hook.add_effect(n, swap_effect)
	)
	
	
	#var scavenger_effect := func(n:int, bullet:Projectile, hit_player:Player) -> void:
		#player.gun.clip = mini(gun.clip_size.value_int, player.gun.clip+n)
	#register_card(TEMP_DECK, &"scavenger", &"Scavenger", &"SC", RARITY_UNUSUAL, STYLE_BASIC,
		#[0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		#&"$dReloads 1 bullet into your mag upon hitting another player with your bullet\n\
		#$n-50% Fire Rate[/color]",
		#func(n:int, player: Player, gun: ProcGun, proj: ProcProj) -> void:
			#gun.fire_rate.multiplier *= 0.5
			#proj.damage_hook.add_effect(n, 
			#)
	#)
	
	#endregion
	
	
	
	#seed(12354678)
	#for i in 2:
		#var a := String.chr(65+randi_range(0, 25))
		#var b := String.chr(65+randi_range(0, 25))
		#register_card(BASE_DECK, &"base_card_%s"%i, &"%sase %sard"%[a,b], &"%s%s"%[a,b], randi_range(RARITY_COMMON, RARITY_EPIC), STYLE_BASIC,
			#[-1.0, -0.5, -1.0, 1.0, 0.5, 1.0],
			#&"$dExample $sBASE$d card for debugging\n\
			#$p+0 Everything\n\
			#$n-0 Nothing",
			#func(player: Player, gun: ProcGun, proj: ProcProj) -> void: pass
		#)
	#
	#for i in 2:
		#var a := String.chr(65+randi_range(0, 25))
		#var b := String.chr(65+randi_range(0, 25))
		#register_card(BLOCK_DECK, &"block_card_%s"%i, &"%slock %sard"%[a,b], &"%s%s"%[a,b], randi_range(RARITY_COMMON, RARITY_EPIC), STYLE_BASIC,
			#[1.0, 2.0, 0.5, -1.0, -2.0, -3.0],
			#&"$dExample $sBLOCK$d card for debugging\n\
			#$p+0 Everything\n\
			#$n-0 Nothing",
			#func(player: Player, gun: ProcGun, proj: ProcProj) -> void: pass
		#)
	#
	#for i in 2:
		#var a := String.chr(65+randi_range(0, 25))
		#var b := String.chr(65+randi_range(0, 25))
		#register_card(TEMP_DECK, &"temp_card_%s"%i, &"%semp %sard"%[a,b], &"%s%s"%[a,b], randi_range(RARITY_COMMON, RARITY_EPIC), STYLE_BASIC,
			#[-1.0, 1.0, -1.0, 1.0, -1.0, 1.0],
			#&"$dExample $sTEMP$d card for debugging\n\
			#$p+0 Everything\n\
			#$n-0 Nothing",
			#func(player: Player, gun: ProcGun, proj: ProcProj) -> void: pass
		#)
	
	
	@warning_ignore_restore("unused_parameter")
