class_name Card
extends RefCounted

const CARD_DISPLAY := preload("uid://b5ava4xusp4lu")
const CARD_3D_WRAPPER := preload("uid://tp7ecpbxfw28")


static var ALL_CARDS: Array[Card] = []

const OUTLINE_COMMON := preload("uid://cr73ecy66f8or") as ShaderMaterial
const OUTLINE_UNUSUAL := preload("uid://b8j6y8svxyb2q") as ShaderMaterial
const OUTLINE_RARE = preload("uid://fif1sx8k4w8f") as ShaderMaterial
const OUTLINE_EPIC = preload("uid://caexkypvp4txu") as ShaderMaterial


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
const RARITY_COLORS: Array[StringName] = [&"#555555", &"22dd66", &"ccc022", &"1177dd", &"cb22bb"]
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


static func hook(hook_arr: Array[Callable], hook_func: Callable) -> void: hook_arr.append(hook_func)
func _to_string() -> String: return &"%s[R:%s S:%s]" % [name, rarity, style]


static func get_card(card_uuid: StringName) -> Card:
	var idx := ALL_CARDS.find_custom(func(c:Card)->bool: return c.uuid == card_uuid)
	if idx == -1: return null
	return Card.ALL_CARDS[idx]


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
static func register_card(uuid_: StringName, name_: StringName, abbv_: StringName, rarity_: int, style_: int, spider_: Array[float], desc_: StringName, effect: Callable) -> void:
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
	card.display = build_display(card)
	card.wrapper_3d = CARD_3D_WRAPPER.instantiate() as Sprite3D
	card.wrapper_3d.get_child(0).add_child(card.display)
	
	ALL_CARDS.append(card)
	Console.print(&"Loaded %s" % card)


static func build_display(card: Card) -> CardDisplay: # TODO make part of carddisplay
	var cdisp := CARD_DISPLAY.instantiate() as CardDisplay
	
	(cdisp.get_node(^"content/vbox/name") as Label).text = card.name
	(cdisp.get_node(^"content/vbox/desc") as RichTextLabel).text = card.desc
	match card.rarity:
		RARITY_COMMON: (cdisp.get_node(^"extras/outline") as Panel).material = OUTLINE_COMMON
		RARITY_UNUSUAL:(cdisp.get_node(^"extras/outline") as Panel).material = OUTLINE_UNUSUAL
		RARITY_RARE:(cdisp.get_node(^"extras/outline") as Panel).material = OUTLINE_RARE
		RARITY_EPIC:(cdisp.get_node(^"extras/outline") as Panel).material = OUTLINE_EPIC
	
	var sg := cdisp.get_node(^"extras/spider_graph") as SpiderGraph
	sg.values = card.spider
	sg.data_outline_color = spider_to_color(card.spider)
	sg.recalculate_graph()
	
	return cdisp


static func register_all_cards() -> bool:
	@warning_ignore_start("unused_parameter")
	register_card(&"impact_plates", &"Impact Plates", &"IP", RARITY_EPIC, STYLE_BASIC,
		[.77, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$dConverts 35% of damage taken to knockback taken\n\
		$p+20 Max Health\n\
		$n-20% Speed\n\
		-10% Jump Height",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
			player.max_health.adder += 20.0
			player.speed.multiplier -= 0.2
			player.jump.multiplier -= 0.1
			hook(player.damage_hooks, func(de:DamageEvent) -> DamageEvent:
				var amount := clampf(de.damage / player.max_health.value, 0.0, 1.0)
				de.knockback += de.knockback.normalized() * amount * 10.0
				de.damage *= 0.65
				return de
			)
	)
	
	register_card(&"rubber_bullets", &"Rubber Bullets", &"RB", RARITY_UNUSUAL, STYLE_BASIC,
		[.77, 0.0, 0.0, 0.0, 0.0, 0.0],
		&"$dBoing!\n\
		$p+1 Bullet Bounce\n\
		$n-15% Bullet Damage",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
			proj.bounces.adder += 1
			proj.damage.multiplier -= 0.15
	)
	
	register_card(&"ultralight", &"Ultralight", &"UL", RARITY_RARE, STYLE_BASIC,
		[-0.5, 0.0, 1.5, 0.0, 0.0, 0.0],
		&"$dNow with 10% more Speed per Speed!\n\
		$p+100% Movement Speed\n\
		+50% Acceleration\n\
		$n+100% Knockback Taken",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
			player.speed.multiplier += 1.0
			player.accel.multiplier += 0.5
			player.damage_hooks.append(func(de:DamageEvent) -> DamageEvent:
				de.knockback *= 2.0
				return de
			)
	)
	
	seed(12354678)
	for i in 2:
		var a := String.chr(65+randi_range(0, 25))
		var b := String.chr(65+randi_range(0, 25))
		register_card(&"impact_plates_%s"%i, &"%smpact %slates"%[a,b], &"%s%s"%[a,b], randi_range(RARITY_COMMON, RARITY_EPIC), STYLE_BASIC,
			[.77, 0.0, 0.0, 0.0, 0.0, 0.0],
			&"$dConverts 35% of damage taken to knockback taken\n\
			$p+20 Max Health\n\
			$n-20% Speed\n\
			-10% Jump Height",
			func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
				player.max_health.adder += 20.0
				player.speed.multiplier -= 0.2
				player.jump.multiplier -= 0.1
				hook(player.damage_hooks, func(de:DamageEvent) -> DamageEvent:
					var amount := clampf(de.damage / player.max_health.value, 0.0, 1.0)
					de.knockback += de.knockback.normalized() * amount * 10.0
					de.damage *= 0.65
					return de
				)
		)
	
	
	
	#register_card(&"Free Bounce", RARITY_UNUSUAL, STYLE_BASIC,
		#&"[color=green]+1 Bounce\n\
		#[color=red]-1 Bitches[/color]",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#proj.bounces += 1
		#)
	
	#register_card(&"Heavy Hitter", RARITY_COMMON, STYLE_BASIC,
		#&"[color=green]+40% Damage\n\
		#[color=red]-10% Fire Rate[/color]",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#proj.damage *= 1.4
		#gun.fire_rate *= 0.9
		#)
	#
	#register_card(&"Big Bullets", RARITY_COMMON, STYLE_BASIC,
		#&"[color=green]+100% Bullet Size\n\
		#[color=red]-40% Bullet Speed[/color]",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#proj.scale *= 2.0 # TODO fix: projectiles are synced before card effect applies
		#gun.b_speed *= 0.60
		#)
	#
	#register_card(&"Fastball", RARITY_COMMON, STYLE_BASIC,
		#&"[color=green]+30% Bullet Speed\n\
		#[color=red]-10% Fire Rate[/color]",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#gun.b_speed *= 1.30
		#gun.fire_rate *= 0.90
		#)
	#
	#register_card(&"Overclocked Firing Mechanism", RARITY_RARE, STYLE_BASIC,
		#&"[color=green]+100% Gun Rate of Fire\n\
		#+4 Clip Size\n\
		#[color=red]-60% Damage\n\
		#+0.5 Reload Time[/color]",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#gun.fire_rate *= 2.0
		#gun.clip_size += 4
		#proj.damage *= 0.4
		#gun.reload_time += 0.5
		#)
	#
	#register_card(&"Fat Fucking Chud", RARITY_EPIC, STYLE_BASIC,
		#&"[color=green]+100% Health\n\
		#[color=red]-10% Speed\n\
		#-10% Jump Height\n\
		#-10% Acceleration",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#player.max_health *= 2.0
		#player.speed *= 0.9
		#player.jump *= 0.9
		#player.accel *= 0.9
		#)
	#
	#register_card(&"Get Yoked", RARITY_UNUSUAL, STYLE_BASIC,
		#&"[color=green]+15% Speed\n\
		#+15% Jump\n\
		#+15% Acceleration\n\
		#+1 Max Stamina",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#player.speed *= 1.15
		#player.jump *= 1.15**0.5 # jump might be exp
		#player.accel *= 1.15
		#player.stamina_max += 1
		#)
	#
	#register_card(&"Spacial Warp", RARITY_EPIC, STYLE_BASIC,
		#&"[color=green]Warp objects to projectile on hit",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#proj.collide_hooks.append(func(bullet:Projectile,collider:CollisionObject3D) -> void:
			#Network.move_object.rpc(collider.get_path(), bullet.position)
			#)
		#)
	#
	#register_card(&"Swap", RARITY_RARE, STYLE_BASIC,
		#&"[color=green]Swap positions with a player you hit",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#proj.damage_hooks.append(func(bullet:Projectile,hit_player:Player) -> void:
			#var pos := hit_player.position
			#Network.move_object.rpc(hit_player.get_path(), player.position)
			#player.position = pos
			#)
		#)
	#
	#register_card(&"Scavenger", RARITY_RARE, STYLE_BASIC,
		#&"[color=green]Reloads 1 bullet into your mag upon player hit\n\
		#[color=red]-50% Fire Rate[/color]",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#gun.fire_rate *= 0.5
		#proj.damage_hooks.append(func(bullet:Projectile,hit_player:Player) -> void:
			#player.gun.clip = mini(gun.clip_size, player.gun.clip+1)
			#)
		#)
	#
	#register_card(&"Ultralight", RARITY_RARE, STYLE_BASIC,
		#&"[color=green]2x Movement Speed\n\
		#[color=red]2x Knockback taken",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#player.speed *= 2.0
		#player.damage_hooks.append(func(de:DamageEvent) -> DamageEvent:
			#de.knockback *= 2.0
			#return de
			#)
		#)
	#
	#register_card(&"Iron Cannon", RARITY_UNUSUAL, STYLE_BASIC,
		#&"[color=green]+25 Knockback\n\
		#+25% Bullet Size\n\
		#+15% Damage\n\
		#[color=red]-50% Fire Rate\n\
		#-2 Ammo[/color]",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#proj.knockback += 25.0
		#proj.scale *= 1.25
		#proj.damage *= 1.15
		#gun.fire_rate *= 0.5
		#gun.clip_size -= 2
		#)
	
	@warning_ignore_restore("unused_parameter")
	return true
