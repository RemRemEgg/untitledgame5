class_name Card
extends RefCounted

const CARD_DISPLAY := preload("uid://b5ava4xusp4lu")

static var ALL_CARDS: Array[Card] = []

const OUTLINE_COMMON := preload("uid://cr73ecy66f8or") as ShaderMaterial
const OUTLINE_UNUSUAL := preload("uid://b8j6y8svxyb2q") as ShaderMaterial
const OUTLINE_RARE = preload("uid://fif1sx8k4w8f") as ShaderMaterial
const OUTLINE_EPIC = preload("uid://caexkypvp4txu") as ShaderMaterial





#            INTERNAL         GREEN          YELLOW          BLUE         PURPLE
enum {RARITY_INTERNAL, RARITY_COMMON, RARITY_UNUSUAL, RARITY_RARE, RARITY_EPIC}
# NYI
enum {STYLE_INTERNAL, STYLE_BASIC}

var name: StringName
var rarity: int
var style: int
var desc: StringName
var card_effect: Callable
var display: Sprite3D


func _to_string() -> String: return &"%s[R:%s S:%s]" % [name, rarity, style]

static func register_card(name_: StringName, rarity_: int, style_: int, desc_: StringName, effect: Callable) -> void:
	Console.print(&"Loading card %s" % name_)
	var card := new()
	card.name = name_
	card.rarity = rarity_
	card.style = style_
	card.desc = desc_.replace(&"\t", &"")
	card.card_effect = effect
	card.display = build_display(card)
	
	ALL_CARDS.append(card)
	Console.print(&"Loaded %s" % card)


static func build_display(card: Card) -> Sprite3D:
	var sprite := CARD_DISPLAY.instantiate() as Sprite3D
	
	var disp := sprite.get_node("sub_vp/center/card")
	
	(disp.get_node("vbox/margin/name") as Label).text = card.name
	(disp.get_node("vbox/margin/desc") as RichTextLabel).text = card.desc
	match card.rarity:
		RARITY_COMMON: (disp.get_node("outline") as Panel).material = OUTLINE_COMMON
		RARITY_UNUSUAL:(disp.get_node("outline") as Panel).material = OUTLINE_UNUSUAL
		RARITY_RARE:(disp.get_node("outline") as Panel).material = OUTLINE_RARE
		RARITY_EPIC:(disp.get_node("outline") as Panel).material = OUTLINE_EPIC
		
	
	
	return sprite

static func register_all_cards() -> bool:
	@warning_ignore_start("unused_parameter")
	register_card(&"Free Bounce", RARITY_UNUSUAL, STYLE_BASIC,
		&"[color=green]+1 Bounce\n\
		[color=red]-1 Bitches[/color]",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		proj.bounces += 1
		)
	
	register_card(&"Heavy Hitter", RARITY_COMMON, STYLE_BASIC,
		&"[color=green]+40% Damage\n\
		[color=red]-10% Fire Rate[/color]",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		proj.damage *= 1.4
		gun.fire_rate *= 0.9
		)
	
	register_card(&"Big Bullets", RARITY_COMMON, STYLE_BASIC,
		&"[color=green]+25% Bullet Size\n\
		[color=red]-20% Bullet Speed[/color]",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		proj.scale *= 1.25
		gun.b_speed *= 0.80
		)
	
	register_card(&"Fastball", RARITY_COMMON, STYLE_BASIC,
		&"[color=green]+30% Bullet Speed\n\
		[color=red]-10% Fire Rate[/color]",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		gun.b_speed *= 1.30
		gun.fire_rate *= 0.90
		)
	
	register_card(&"Overclocked Firing Mechanism", RARITY_RARE, STYLE_BASIC,
		&"[color=green]+100% Gun Rate of Fire\n\
		+4 Clip Size\n\
		[color=red]-60% Damage\n\
		+0.5 Reload Time[/color]",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		gun.fire_rate *= 2.0
		gun.clip_size += 4
		proj.damage *= 0.4
		gun.reload_time += 0.5
		)
	
	register_card(&"Fat Fucking Chud", RARITY_EPIC, STYLE_BASIC,
		&"[color=green]+100% Health\n\
		[color=red]-10% Speed\n\
		-10% Jump Height\n\
		-10% Acceleration",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		player.max_health *= 2.0
		player.speed *= 0.9
		player.jump *= 0.9
		player.accel *= 0.9
		)
	
	register_card(&"Get Yoked", RARITY_UNUSUAL, STYLE_BASIC,
		&"[color=green]+15% Speed\n\
		+15% Jump\n\
		+15% Acceleration\n\
		+1 Max Stamina",
		func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		player.speed *= 1.15
		player.jump *= 1.15**0.5 # jump might be exp
		player.accel *= 1.15
		player.stamina_max += 1
		)
	
	#register_card(&"Get Yoked",
		#&"[color=green]+15% Speed\n\
		#+15% Jump\n\
		#+15% Acceleration\n\
		#+1 Max Stamina",
		#func(player: Player, gun: ProcGun, proj: ProcProj) -> void:
		#player.speed *= 1.15
		#player.jump *= 1.15
		#player.accel *= 1.15
		#player.stamina_max += 1
		#)
	
	@warning_ignore_restore("unused_parameter")
	return true
