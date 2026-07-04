class_name Card
extends RefCounted

const CARD_3D_WRAPPER := preload("uid://tp7ecpbxfw28")


static var ALL_CARDS: Array[Card] = []
static var DECKS: Array[CardDeck]

static var DECK_TEXTURE_TEST: CardDeck
static var DECK_DEBUG: CardDeck
static var DECK_INIT: CardDeck
static var DECK_GUN: CardDeck
static var DECK_MAGIC: CardDeck
static var DECK_PLAYER: CardDeck
static var DECK_ALIGN: CardDeck
static var DECK_OTHER: CardDeck

# TODO more event hooks

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
var rarity_eval: RarityEval
var use_spell_selection: bool
# TODO does not work when nested
var is_draw_once: bool

var display: CardDisplay
var wrapper_3d: Sprite3D
var deck: CardDeck


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
##[br][br][b]spider[/b]: Info for spider charts. [Sp.Def, Toughness, Agility, Ammo, Lethality, Sp.Atk].
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
static func register_card(uuid_: StringName, name_: StringName, abbv_: StringName, flavor_: StringName, deck_: CardDeck, rarity_: int, style_: int, spider_: Array[float], rarityeval: RarityEval, effect: Callable) -> void:
	Console.print(&"Loading card %s" % uuid_)
	
	var uuid_exists := ALL_CARDS.find_custom(func(c:Card)->bool: return c.uuid == uuid_) + 1
	if uuid_exists:
		Console.print_err(&"Cannot load card %s(%s), uuid is already in use" % [uuid_, name_])
		return
	
	if name_.is_empty() || name_.length() > 32:
		Console.print_err(&"Cannot load card %s(%s), name is too long or nonexistant" % [uuid_, name_])
		return
	
	if abbv_.is_empty() || abbv_.length() > 5:
		Console.print_err(&"Cannot load card %s(%s), abbv is too long or nonexistant" % [uuid_, name_])
		return
	
	if spider_.size() != 6:
		Console.print_err(&"Cannot load card %s(%s), spider must have 6 entries" % [uuid_, name_])
		return
	
	var card := Card.new()
	
	if !rarityeval:
		rarityeval = RarityEval.new(RarityEval.MODE_TRUE)
	if rarityeval == DRAW_ONCE:
		rarityeval = NOT(uuid_)
		card.is_draw_once = true
	elif rarityeval.update_draw_once(uuid_):
		card.is_draw_once = true
	
	
	var card_data := CardData.from_player(_temp_player, true)
	card.uuid = uuid_
	card.name = name_
	card.abbv = abbv_
	card.rarity = rarity_
	card.style = style_
	card.spider = Util.normalize_array(spider_)
	card.card_effect = effect
	card.card_effect.call(card_data)
	card.desc = card_data.get_description(flavor_)
	card.rarity_eval = rarityeval
	card.use_spell_selection = card_data.use_spell_selection
	
	card.display = CardDisplay.from_card(card, deck_)
	card.wrapper_3d = CARD_3D_WRAPPER.instantiate() as Sprite3D
	card.wrapper_3d.get_child(0).add_child(card.display)
	card.deck = deck_
	
	
	ALL_CARDS.append(card)
	deck_.cards.append(card)
	Console.print(&"Loaded %s" % card)


static func register_all_decks() -> void:
	DECK_TEXTURE_TEST = CardDeck.new(&"texture_test", load("res://textures/cards/deck_init.png") as Texture2D)
	DECKS.append(DECK_TEXTURE_TEST)
	DECK_DEBUG = CardDeck.new(&"debug", load("res://textures/cards/deck_debug.png") as Texture2D)
	DECKS.append(DECK_DEBUG)
	DECK_INIT = CardDeck.new(&"init", load("res://textures/cards/deck_init.png") as Texture2D)
	DECKS.append(DECK_INIT)
	DECK_GUN = CardDeck.new(&"gun", load("res://textures/cards/deck_gun.png") as Texture2D)
	DECKS.append(DECK_GUN)
	DECK_MAGIC = CardDeck.new(&"magic", load("res://textures/cards/deck_magic.png") as Texture2D)
	DECKS.append(DECK_MAGIC)
	DECK_PLAYER = CardDeck.new(&"player", load("res://textures/cards/deck_player.png") as Texture2D)
	DECKS.append(DECK_PLAYER)
	DECK_ALIGN = CardDeck.new(&"align", load("res://textures/cards/deck_init.png") as Texture2D)
	DECKS.append(DECK_ALIGN)
	DECK_OTHER = CardDeck.new(&"other", load("res://textures/cards/deck_debug.png") as Texture2D)
	DECKS.append(DECK_OTHER)

## For generating descriptions
static var _temp_player: Player
static var DRAW_ONCE := RarityEval.new(-1)


static func register_all_cards() -> void:
	_temp_player = Player.new()
	_temp_player.procgun = ProcGun.new()
	_temp_player.procgun.pproj = ProcProj.new()
	_temp_player.reset_stats()
	@warning_ignore_start("unused_parameter")
	
	#register_card(&"debug_unlock", &"Debug Unblocker", &"DEBG", &"Adds $sDebug$d cards",
		#DECK_DEBUG, RARITY_COMMON, STYLE_BASIC, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
		#DRAW_ONCE,
		#func card(cd:CardData) -> void:
			#cd.add(cd.player.max_health, 25.0)
	#)
	
	
	#region texture debugging
	register_card(&"texture_unlock", &"Texture Unlocker", &"TXTR", &"Adds $sTexture Debug$d cards",
		DECK_TEXTURE_TEST, RARITY_COMMON, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], NEVER(),
		func card(cd:CardData) -> void:
			cd.add_description(&"Only texture cards will be drawn", true, true)
			for wdeck in cd.player.deck_weights:
				cd.player.deck_weights[wdeck] = 0.0
			cd.player.deck_weights[DECK_TEXTURE_TEST] = 1.0
	)
	register_card(&"texture_internal", &"Texture Internal", &"INTN", &"$sTexture Debuger$d\nInternal",
		DECK_TEXTURE_TEST, RARITY_INTERNAL, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"texture_common", &"Texture Common", &"COMN", &"$sTexture Debuger$d\nCommon",
		DECK_TEXTURE_TEST, RARITY_COMMON, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"texture_unusual", &"Texture Unusual", &"UNUS", &"$sTexture Debuger$d\nUnusual",
		DECK_TEXTURE_TEST, RARITY_UNUSUAL, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"texture_rare", &"Texture Rare", &"RARE", &"$sTexture Debuger$d\nRare",
		DECK_TEXTURE_TEST, RARITY_RARE, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"texture_epic", &"Texture Epic", &"EPIC", &"$sTexture Debuger$d\nEpic",
		DECK_TEXTURE_TEST, RARITY_EPIC, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	#endregion
	
	
	#region alignment cards
	register_card(&"align_gun", &"Ranger's Soul", &"RNGR", &"",
		DECK_ALIGN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 1.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_description(&"Align yourself with the rangers, finding gun cards more often", true)
			cd.player.deck_weights[DECK_GUN] += 0.25
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
	)
	register_card(&"align_magic", &"Magicians's Soul", &"MGCN", &"",
		DECK_ALIGN, RARITY_EPIC, STYLE_BASIC, [1.0, 0.0, 0.0, 0.0, 0.0, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_description(&"Align yourself with the magicians, finding magic cards more often", true)
			cd.player.deck_weights[DECK_MAGIC] += 0.25
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
	)
	register_card(&"align_player", &"Monk's Soul", &"MONK", &"",
		DECK_ALIGN, RARITY_EPIC, STYLE_BASIC, [0.0, 1.0, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_description(&"Align yourself with the monks, finding player cards more often", true)
			cd.player.deck_weights[DECK_PLAYER] += 0.25
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
	)
	register_card(&"align_obelisk", &"Pray to the Obelisk", &"PRAY", &"Pray to the Obelisk",
		DECK_ALIGN, RARITY_RARE, STYLE_BASIC, [1.0, 1.0, 1.0, 1.0, 1.0, 1.001], ANY(&"align_gun", &"align_magic", &"align_player"),
		func card(cd:CardData) -> void:
			cd.add_description(&"Your alignments are more polarized", true)
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
			for ideck in cd.player.deck_weights:
				cd.player.deck_weights[ideck] *= cd.player.deck_weights[ideck]
	)
	#endregion
	
	
	#region init card
	register_card(&"init_rifle", &"Rifle", &"RFLE", &"For the campers",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.2, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 2.8)
			cd.mult(cd.gun.fire_rate, 0.75)
			cd.add(cd.gun.b_speed, 250)
			cd.mult(cd.gun.inaccuracy, 0.5)
			cd.add(cd.gun.clip_size, 2)
			cd.mult(cd.gun.reload_time, 1.75)
	)
	register_card(&"init_shotgun", &"Shotgun", &"STGN", &"must.....kill.......",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.5, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 0.25)
			cd.mult(cd.gun.inaccuracy, 3.2)
			cd.add(cd.gun.inaccuracy, 10.0)
			cd.add(cd.gun.clip_size, 13)
			cd.add(cd.gun.bullets_per_shot, 6)
			cd.add(cd.gun.reload_time, 0.75)
	)
	register_card(&"init_revolver", &"Revolver", &"REVO", &"Fires faster than you can click",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 1.15)
			cd.add(cd.gun.clip_size, 5)
			cd.add(cd.gun.fire_rate, 10.0)
			cd.add(cd.gun.reload_time, 1.25)
	)
	register_card(&"init_triple", &"Triple Barrel", &"TRPL", &"3 Bullets > 1 Bullet",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add_description(&"Enables Full Auto", true, true)
			cd.player.full_auto = true
			cd.mult(cd.proj.damage, 0.25)
			cd.add(cd.gun.inaccuracy, 10.0)
			cd.add(cd.gun.clip_size, 20)
			cd.add(cd.gun.bullets_per_shot, 2)
			cd.mult(cd.gun.fire_rate, 2.5)
			cd.add(cd.gun.reload_time, 0.75)
	)
	register_card(&"init_minigun", &"Minigun", &"MIGN", &"\"Glorified noise-maker\"",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add_description(&"Enables Full Auto", true, true)
			cd.player.full_auto = true
			cd.mult(cd.proj.damage, 0.2)
			cd.mult(cd.gun.inaccuracy, 2.5)
			cd.add(cd.gun.inaccuracy, 12.0)
			cd.add(cd.gun.clip_size, 42)
			cd.add(cd.gun.fire_rate, 14.0)
			cd.add(cd.gun.reload_time, 1.5)
	)
	#endregion
	
	
	#region deck gun
	register_card(&"rubber_bullets", &"Rubber Bullets", &"RUBB", &"Boing!",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.bounces, 3)
	)
	
	register_card(&"heavy_hitter", &"Heavy Hitter", &"HVHT", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.damage, 12)
			cd.mult(cd.gun.fire_rate, 0.8)
	)
	
	register_card(&"sharper_bullets", &"Sharper Bullets", &"SHRP", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.damage, 6)
			cd.mult(cd.gun.reload_time, 1.05)
	)
	
	register_card(&"combine", &"Combine", &"CMBN", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 1.5)
			cd.mult(cd.gun.clip_size, 0.75)
	)
	
	register_card(&"big_bullets", &"Big Bullets", &"BGBU", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.5, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.scale, 3.0)
			cd.mult(cd.gun.b_speed, 0.8)
	)
	
	register_card(&"fastball", &"Fastball", &"FSBL", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, -0.2, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.b_speed, 1.3)
			cd.mult(cd.gun.fire_rate, 0.9)
	)
	
	register_card(&"ocfm", &"Overclocked Firing Mechanism", &"OCFM", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], ALL(NOT(&"ocfm"), NOT(&"sawed_off")),
		func card(cd:CardData) -> void:
			cd.add_description(&"Enables Full Auto", true, true)
			cd.player.full_auto = true
			cd.mult(cd.gun.fire_rate, 2.2)
			cd.mult(cd.gun.clip_size, 1.5)
			cd.mult(cd.proj.damage, 0.45)
			cd.add(cd.gun.reload_time, 0.75)
			cd.add(cd.gun.inaccuracy, 3.5)
	)
	
	register_card(&"sawed_off", &"Sawed-Off", &"SAWN", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], ALL(NOT(&"ocfm"), NOT(&"sawed_off")),
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.fire_rate, 0.5)
			cd.mult(cd.gun.clip_size, 1.5)
			cd.mult(cd.gun.bullets_per_shot, 2.0)
			cd.mult(cd.proj.damage, 0.5)
			cd.add(cd.gun.reload_time, 0.75)
			cd.add(cd.gun.inaccuracy, 3.5)
	)
	
	register_card(&"iron_cannon", &"Iron Cannon", &"IRON", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.knockback, 20.0)
			cd.add(cd.proj.scale, 1.5)
			cd.add(cd.proj.damage, 5)
			cd.mult(cd.gun.fire_rate, 0.65)
			cd.add(cd.gun.clip_size, -2)
	)
	
	register_card(&"wd_40", &"WD-40", &"WD40", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.reload_time, 0.7)
			cd.mult(cd.gun.b_speed, 1.25)
			cd.mult(cd.proj.damage, 0.90)
	)
	
	register_card(&"slick_trick", &"Quick Trick", &"QCTC", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.fire_rate, 1.15)
			cd.add(cd.gun.reload_time, -0.2)
	)
	
	register_card(&"tachyon_bullets", &"Tachyon Bullets", &"TACH", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.fire_rate, 1.33)
			cd.mult(cd.gun.b_speed, 1.33)
			cd.mult(cd.gun.reload_time, 1.33)
	)
	
	register_card(&"scavenger", &"Scavenger", &"SCAV", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.5, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.fire_rate, 0.4)
			cd.add_effect(&"Reloads $s1 bullet$p into your mag upon shooting players", true, cd.proj.damage_hook,
				func effect(ed:EventHook.EventData, pl:Player) -> void:
					ed.player.gun.clip = mini(ed.gun.clip_size.value_int, ed.player.gun.clip + ed.n)
			)
	)
	
	#register_card(&"blood_recycler", &"Blood Recycler", &"BDRE", &"",
		#DECK_OTHER, RARITY_UNUSUAL, STYLE_BASIC, [0.0, -0.5, 0.0, 0.0, 1.0, 0.0], null,
		#func card(cd:CardData) -> void:
			#cd.mult(cd.player.max_health, 1.15)
			#cd.add_effect(&"Shooting players gives $s20HP", true, cd.proj.damage_hook,
				#func effect(ed:EventHook.EventData, pl:Player) -> void:
					#ed.player.health = minf(ed.player.max_health.value, ed.player.health + 20.0*ed.n)
			#)
			#cd.add_effect(&"Firing costs $s10HP", false, cd.player.shooting_hook, 
				#func effect(ed:EventHook.EventData) -> void:
					#ed.player.health = maxf(1, ed.player.health - 10.0*ed.n)
			#)
	#)
	
	register_card(&"accelerator", &"Accelerator", &"ACEL", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 0.75, 0.5, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_effect(&"[Bugged] Fire Rate is proportional to how empty your magazine is", true, cd.player.shooting_hook,
				func effect(ed:EventHook.EventData) -> void:
					ed.player.gun.fire_timer += 1.0 - (ed.player.gun.clip / ed.gun.clip_size.value)**ed.n
			)
			cd.mult(cd.gun.fire_rate, 0.75)
	)
	
	register_card(&"hawkeye", &"Hawkeye", &"HKEY", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 1.0, 0.2], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.b_speed, 150)
			cd.mult(cd.proj.damage, 1.2)
			cd.add(cd.gun.inaccuracy, -8.0)
			cd.mult(cd.gun.fire_rate, 0.5)
			cd.add(cd.gun.reload_time, 0.5)
	)
	
	register_card(&"barrage", &"Barrage", &"BRGE", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.bullets_per_shot, 5)
			cd.add(cd.gun.clip_size, 10)
			cd.add(cd.gun.inaccuracy, 20)
			cd.mult(cd.proj.damage, 0.3)
			cd.add(cd.gun.reload_time, 0.5)
	)
	
	register_card(&"mini_bullets", &"Mini Bullets", &"MINI", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.clip_size, 2.0)
			cd.mult(cd.proj.damage, 0.75)
			cd.mult(cd.proj.scale, 0.75)
	)
	
	register_card(&"cuber", &"Cuber", &"CUBE", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 0.75, 0.5, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add_effect(&"Spawns blocks where your bullets land", true, cd.proj.collide_hook,
				func effect(ed:EventHook.EventData, body:PhysicsBody3D) -> void:
					for i in ed.n: Network.spawn_levelbody.rpc(ed.position, randi_range(1, 2))
			)
	)
	
	register_card(&"glass_cannon", &"Glass Cannon", &"GLSS", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 1.0, -0.5, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 1.5)
			cd.mult(cd.player.max_health, 0.6)
	)
	#endregion
	
	
	#region deck magic
	register_card(&"windwalker", &"Windwalker", &"WIND", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.75)
			cd.add_spell_effect(&"Spell that gives increased agility", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					ed.player.speed.mult_temp(1.2, 3.0*sd.t**0.75, sd.t)
					ed.player.accel.mult_temp(1.2, 3.0*sd.t**0.75, sd.t)
					ed.player.jump.mult_temp(1.2, 3.0*sd.t**0.75, sd.t)
			)
	)
	
	register_card(&"ironskin", &"Ironskin", &"INSK", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 1.6)
			cd.add_spell_effect(&"Spell that significantly increases max life for a short time", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					ed.player.max_health.add_temp(50, 2.0*sd.t**0.75, sd.t)
					ed.player.max_health.mult_temp(1.5, 2.0*sd.t**0.75, sd.t)
			)
	)
	
	register_card(&"headrush", &"Headrush", &"HDRS", &"broken, maybe",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 1.15)
			cd.add_effect(&"Increase agility for a short time after casting", true, cd.player.spell_hook,
				func effect(ed:EventHook.EventData) -> void:
					ed.player.speed.mult_temp(1.25, 4.0*ed.n**0.75, ed.n)
					ed.player.accel.mult_temp(1.25, 4.0*ed.n**0.75, ed.n)
					ed.player.jump.mult_temp(1.25, 4.0*ed.n**0.75, ed.n)
			)
	)
	
	register_card(&"magipult", &"Magipult", &"PULT", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"Spell that launches you forward", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					var vel := ed.player.velocity
					ed.player.velocity = -ed.player.camera.global_basis.z * 64.0 * sd.t
					vel += ed.player.velocity * ed.player.speed.value * sd.t * (2.5 / 100.0)
					ed.player.move_and_slide()
					ed.player.velocity = vel
			)
	)
	
	register_card(&"warp", &"Warp", &"WARP", &"woosh!",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"Spell that teleports you forward", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					var vel := ed.player.velocity
					ed.player.velocity = -ed.player.camera.global_basis.z * 48.0 * sd.t
					ed.player.move_and_collide(ed.player.velocity)
					ed.player.velocity = vel
			)
	)
	
	register_card(&"shockwave", &"Shockwave", &"SHWV", &"[Visuals NYI]",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.0, 0.0, 0.0, 0.0, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 1.3)
			cd.add_spell_effect(&"Spell that pushes everything away", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					var dss: PhysicsDirectSpaceState3D = ed.player.get_world_3d().direct_space_state
					var shape := SphereShape3D.new()
					# scales the cross sectional area of the sphere
					shape.radius = (sd.t ** 0.5) * 4.0
					Network.spawn_visual(Network.NV_SHOCKWAVE, ed.player.global_position, shape.radius)
					var psqp := PhysicsShapeQueryParameters3D.new()
					psqp.exclude = [ed.player.get_rid()]
					psqp.shape = shape
					psqp.transform.origin = ed.player.global_position + Vector3(0.0, -0.15, 0.0)
					psqp.collision_mask = 0b0011_0011
					var hits := dss.intersect_shape(psqp, 64)
					
					for hit in hits:
						var colc := hit[&"collider"] as PhysicsBody3D
						var dir := psqp.transform.origin.direction_to(colc.global_position)
						var mag := shape.radius * 5.0
						dir *= mag
						
						if colc is Player:
							var pl := colc as Player
							pl.take_damage.rpc(20.0, dir)
							continue
						if colc is RigidBody3D:
							if (colc as RigidBody3D).freeze: continue
							(colc as RigidBody3D).apply_central_impulse.rpc(dir * 2.0)
			)
	)
	
	register_card(&"turtle", &"Turtle", &"TURT", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 0.1, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.5)
			cd.add_spell_effect(&"Spell that summons blocks around you", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					for x in (1.0+sd.ti*2.0): for y in (2.0+sd.ti*2.0): for z in (1.0+sd.ti*2.0):
						Network.spawn_levelbody.rpc(ed.player.global_position + Vector3(x-sd.ti, y-0.5-sd.ti, z-sd.ti),
						randi_range(1, 2))
			)
	)
	
	# TODO
	#register_card(&"masochist", &"Masochist", &"MASO", &"",
		#DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.1, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		#func card(cd:CardData) -> void:
			#cd.mult(cd.player.magic_cd, 1.25)
			#cd.add_effect(&"Taking damage regenerates magic", true, cd.player.damage_hook,
				#func effect(ed:EventHook.EventData, de:DamageEvent) -> void:
					#var amo := de.damage / ed.player.health
					#if ed.player.magic_timer <= 0.0: ed.player.magic_timer -= amo * sd.t
			#)
	#)
	
	register_card(&"platform", &"Platform", &"PLAT", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"Casting places a platform below you", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					ed.player.jumps = ed.player.max_jumps.value_int
					for x in (1.0+sd.ti*2.0): for z in (1.0+sd.ti*2.0):
						Network.spawn_levelbody.rpc(ed.player.global_position + Vector3(x-sd.ti, -1.5, z-sd.ti),
						LevelBody.Type.BREAKABLE, true)
			)
	)
	
	register_card(&"wall", &"Wall", &"WALL", &"[i]thunk.[/i]",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"Casting places a wall infront of you", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					var trans := ed.player.camera.global_transform
					trans.basis.x *= -1.0 # ???
					trans.basis.y *= -1.0 # parts of matrix are inverted?
					for x in (1.0+sd.ti*2.0): for y in (1.0+sd.ti*2.0):
						Network.spawn_levelbody.rpc(trans.origin + (Vector3(x-sd.ti, y-sd.ti, -4.0) * trans.basis),
						LevelBody.Type.BREAKABLE, true)
			)
	)
	
	register_card(&"snare", &"Snare", &"SNRE", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.0, 0.0, 0.0, 0.0, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 1.5)
			cd.add_spell_effect(&"Trap nearby enemies in blocks", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					var dss: PhysicsDirectSpaceState3D = ed.player.get_world_3d().direct_space_state
					var shape := SphereShape3D.new()
					shape.radius = sd.t * 4.0 + 4.0
					var psqp := PhysicsShapeQueryParameters3D.new()
					psqp.exclude = [ed.player.get_rid()]
					psqp.shape = shape
					psqp.transform.origin = ed.player.global_position + Vector3(0.0, -0.15, 0.0)
					psqp.collision_mask = 0b0010_0010
					var hits := dss.intersect_shape(psqp)
					
					for hit in hits:
						var colc := hit[&"collider"] as PhysicsBody3D
						
						if colc is Player:
							var pl := colc as Player
							var ed2 := 1.0 + (sd.ti*2.0)
							for x in ed2: for y in ed2+1: for z in ed2:
								var target := Vector3(x-sd.ti, y-0.5-sd.ti, z-sd.ti)
								if !(is_zero_approx(target.x) && absf(target.y) <= 0.6 && is_zero_approx(target.z)):
									Network.spawn_levelbody.rpc(pl.global_position + target,
									2-(randi_range(0, 2)%2), false)
			)
	)
	
	register_card(&"heal", &"Heal", &"HEAL", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 2.0)
			cd.add_spell_effect(&"Spell that steals life from nearby players", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					var dss: PhysicsDirectSpaceState3D = ed.player.get_world_3d().direct_space_state
					var shape := SphereShape3D.new()
					shape.radius = sd.t * 4.0 + 4.0
					var psqp := PhysicsShapeQueryParameters3D.new()
					psqp.exclude = [ed.player.get_rid()]
					psqp.shape = shape
					psqp.transform.origin = ed.player.global_position + Vector3(0.0, -0.15, 0.0)
					psqp.collision_mask = 0b0010_0010
					var hits := dss.intersect_shape(psqp)
					
					for hit in hits:
						var colc := hit[&"collider"] as PhysicsBody3D
						
						if colc is Player:
							var pl := colc as Player
							var amo := 20.0 * sd.t
							pl.take_damage.rpc(amo)
							ed.player.health = minf(ed.player.health + amo, ed.player.max_health.value)
			)
	)
	
	register_card(&"slow", &"Slow", &"SLOW", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 2.0)
			cd.add_spell_effect(&"Spell that slows nearby players", true,
				func effect(ed:EventHook.EventData, sd:Spell.SpellData) -> void:
					var dss: PhysicsDirectSpaceState3D = ed.player.get_world_3d().direct_space_state
					var shape := SphereShape3D.new()
					shape.radius = sd.t * 3.0 + 3.0
					var psqp := PhysicsShapeQueryParameters3D.new()
					psqp.exclude = [ed.player.get_rid()]
					psqp.shape = shape
					psqp.transform.origin = ed.player.global_position + Vector3(0.0, -0.15, 0.0)
					psqp.collision_mask = 0b0010_0010
					var hits := dss.intersect_shape(psqp)
					
					for hit in hits:
						var colc := hit[&"collider"] as PhysicsBody3D
						if colc is Player:
							var pl := colc as Player
							Network.slow_player.rpc_id(pl.uuid, 0.75, 3.0*sd.t**0.75, sd.t)
			)
	)
	
	register_card(&"apprentice", &"Apprentice", &"APRN", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.9)
			cd.mult(cd.player.magic_potency, 1.1)
	)
	
	register_card(&"mage", &"Mage", &"MAGE", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"apprentice"),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.85)
			cd.mult(cd.player.magic_potency, 1.15)
	)
	
	register_card(&"wizard", &"Wizard", &"WZRD", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"mage"),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.8)
			cd.mult(cd.player.magic_potency, 1.2)
	)
	
	register_card(&"wizard_light", &"Sorcerer", &"SORC", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"wizard", NOT(&"wizard_dark")),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.75)
			cd.mult(cd.player.magic_potency, 0.4)
			cd.add_effect(&"Casting has a 50% chance to instantly cast again, without consuming charges\nIs able to chain", true, cd.player.spell_hook,
				func effect(ed:EventHook.EventData, sp:Spell) -> void:
					if randf() > 0.5: sp.cast(ed.player)
			)
	)
	
	register_card(&"wizard_dark", &"Warlock", &"WRLK", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"wizard", NOT(&"wizard_light")),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.25)
			cd.mult(cd.player.magic_potency, 1.25)
			cd.add_effect(&"Casting costs 35% current hp", false, cd.player.spell_hook,
				func effect(ed:EventHook.EventData, sp:Spell) -> void:
					ed.player.health *= 0.65
			)
	)
	
	register_card(&"study", &"Study", &"STDY", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(&"apprentice"),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.9)
			cd.mult(cd.player.magic_potency, 1.1)
	)
	
	register_card(&"fast_reader", &"Fast Reader", &"FSRD", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.mult(cd.selected_spell.cooldown, 0.80)
			cd.mult(cd.selected_spell.potency, 0.9)
	)
	
	register_card(&"buildup", &"Buildup", &"BDUP", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.mult(cd.selected_spell.potency, 1.2)
			cd.mult(cd.selected_spell.cooldown, 1.15)
	)
	
	register_card(&"focus", &"Focus", &"FOCS", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.add(cd.selected_spell.max_charges, 1.0)
			cd.add(cd.selected_spell.cooldown, 1.2)
	)
	
	register_card(&"quick_cast", &"Quick Cast", &"QKCS", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.mult(cd.selected_spell.max_charges, 2.0)
			cd.mult(cd.selected_spell.potency, 0.55)
	)
	
	register_card(&"condense", &"Condesnse", &"DNSE", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.mult(cd.selected_spell.max_charges, 0.0)
			cd.add(cd.selected_spell.potency, 2.0)
			cd.add(cd.selected_spell.cooldown, 2.0)
	)
	
	register_card(&"blood_magic", &"Blood Magic", &"BMAW", &"Alchemical wizardry!",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.5)
			cd.mult(cd.player.max_health, 0.5)
	)
	
	register_card(&"transmutation", &"Transmutation", &"TRNS", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.add(cd.selected_spell.max_charges, 1.0)
			cd.mult(cd.gun.clip_size, 0.5)
	)
	
	register_card(&"spell_mastery", &"Spell Mastery", &"SPMS", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.mult(cd.selected_spell.cooldown, 0.25)
			cd.mult(cd.player.magic_cd, 2.0)
	)
	#endregion
	
	
	#region deck player
	register_card(&"impact_plates", &"Impact Plates", &"IMPL", &"",
		DECK_PLAYER, RARITY_EPIC, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, 25.0)
			cd.mult(cd.player.speed, 0.8)
			cd.mult(cd.player.jump, 0.9)
			cd.add_effect(&"Converts $s25%$p of damage taken to knockback taken", true, cd.player.damage_hook,
				func(ed:EventHook.EventData, de:DamageEvent) -> void:
					var amount := clampf(de.damage / ed.player.max_health.value, 0.0, 1.0)
					de.knockback += de.knockback.normalized() * amount * 10.0 * ed.n
					de.damage *= 0.75 ** ed.n
			)
	)
	
	register_card(&"fat_fucking_chud", &"Fat Fucking Chud", &"FFCH", &"",
		DECK_PLAYER, RARITY_RARE, STYLE_BASIC, [0.0, 1.0, -0.5, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, 40)
			cd.mult(cd.player.speed, 0.9)
			cd.mult(cd.player.jump, 0.9)
			cd.mult(cd.player.accel, 0.9)
	)
	
	register_card(&"get_yoked", &"Get Yoked", &"GTYK", &"",
		DECK_PLAYER, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.jump, 1.1)
			cd.add(cd.player.max_jumps, 1)
			cd.mult(cd.player.accel, 1.2)
			cd.add(cd.player.max_stamina, 1.0)
	)
	
	register_card(&"ultralight", &"Ultralight", &"UTLI", &"Now with 10% more Speed per Speed!",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, -0.5, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.speed, 3)
			cd.mult(cd.player.accel, 1.3)
			cd.add_effect(&"x1.8 Knockback Taken", false, cd.player.damage_hook,
				func effect(ed:EventHook.EventData, de:DamageEvent) -> void:
					de.knockback *= 1.8 ** ed.n
			)
	)
	
	register_card(&"burden_breaker", &"Burden Breaker", &"BRDN", &"",
		DECK_PLAYER, RARITY_EPIC, STYLE_BASIC, [0.0, -0.5, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.speed, 4)
			cd.mult(cd.player.accel, 0.35)
	)
	
	register_card(&"leg_day", &"Leg Day", &"LGDY", &"Never skip!",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.2], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.melee_cd, 0.75)
			cd.add(cd.player.speed, 1.5)
	)
	
	register_card(&"sacrifice", &"Sacrifice", &"SCRF", &"",
		DECK_PLAYER, RARITY_RARE, STYLE_BASIC, [0.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add_description(&"Remove one card from your deck\nMust be done manually, before card is picked", true)
			cd.add(cd.player.max_health, 1.15)
	)
	#endregion
	
	@warning_ignore_restore("unused_parameter")
	_temp_player = null


func get_weight(player: Player) -> float:
	var weight := 1.0
	match rarity:
		Card.RARITY_COMMON: weight = 2**2.1
		Card.RARITY_UNUSUAL: weight = 2**1.4
		Card.RARITY_RARE: weight = 2**0.7
		Card.RARITY_EPIC: weight = 2**0.0
	weight *= player.deck_weights.get(deck, 1.0)
	return weight


class CardData:
	var n: int
	## Stats: [code]max_health, speed, accel, jump, max_jumps, max_stamina, magic_cd, melee_cd[/code][br]Hooks: [code]shooting_hook, damage_hook, spell_hook[/code]
	var player: Player
	## Stats: [code]fire_rate, b_speed, inaccuracy, bullets_per_shot, clip_size, reload_time[/code]
	var gun: ProcGun
	## Stats: [code]time, scale, damage, bounces, knockback[/code][br]Hooks: [code]collide_hook, damage_hook[/code]
	var proj: ProcProj
	## Stats: [code]cooldown, max_charges[/code]
	var selected_spell: Spell
	var use_spell_selection: bool = false
	var positive_desc: Array[StringName]
	var negative_desc: Array[StringName]
	
	
	static func from_player(p: Player, add_dummy_spell: bool = false) -> CardData:
		var cd := CardData.new()
		cd.player = p
		cd.gun = cd.player.procgun
		cd.proj = cd.gun.pproj
		if add_dummy_spell: cd.selected_spell = Spell.new()
		return cd
	
	
	func format(f: float) -> String:
		return (&"%s%s" % [(&"+" if f>0.0 else &""), f]).trim_suffix(&".0")
	
	
	func add_description(desc: StringName, is_good: bool, priority: bool = false) -> void:
		var arr := positive_desc if is_good else negative_desc
		arr.insert(0 if priority else arr.size(), desc)
	
	
	func get_description(flavor: StringName) -> StringName:
		var dsc: StringName = &""
		if !flavor.is_empty():
			dsc = &"[color=#f5f5f5]%s\n" %\
				flavor.replace(&"$d", &"[color=#eee]").replace(&"$s", &"[color=#acf]")
		if !positive_desc.is_empty():
			dsc += &"[color=#5f5]%s\n" % (&"\n".join(positive_desc))
		if !negative_desc.is_empty():
			dsc += &"[color=#f55]%s\n" % (&"\n".join(negative_desc))
		return dsc.trim_suffix(&"\n")
	
	
	func add(stat:Stat, amount:float, add_desc: bool = true) -> void:
		stat.adder += amount * n
		if add_desc: add_description(&"%s %s" % [format(amount), stat.name], (stat.is_good) == (amount >= 0.0))
	
	
	func mult(stat:Stat, amount:float, add_desc: bool = true) -> void:
		stat.multiplier *= amount ** n
		if !add_desc: return
		if amount < 2.0: # formatted as +50% Stat
			add_description(&"%s%% %s" % [format(100*(amount-1.0)), stat.name], (stat.is_good) == (amount >= 1.0))
		else: # formatted as x2.5 Stat
			add_description(&"%s %s" % [format(amount).replace(&"+", &"x"), stat.name], stat.is_good)
	
	
	func add_effect(desc: StringName, is_good: bool, hook: EventHook, effect: Callable) -> void:
		hook.add_effect(n, effect)
		if !desc.is_empty(): add_description(desc, is_good, true)
	
	
	func add_spell_effect(desc: StringName, is_good: bool, effect: Callable) -> void:
		use_spell_selection = true
		if !desc.is_empty(): add_description(desc, is_good, true)
		if !selected_spell: return
		selected_spell.hook.add_effect(n, effect)


class RarityEval:
	enum {MODE_TRUE, MODE_ALL, MODE_ANY}
	var mode: int = MODE_TRUE
	var inverted: bool = false
	var evals: Array[RarityEval] = []
	var card_ids: Array[StringName] = []
	var cards: Array[Card] = []
	
	
	func _init(mode_: int) -> void:
		mode = mode_
	
	
	func update_draw_once(id: StringName) -> bool:
		var ido := false
		for i in evals.size():
			if evals[i] == Card.DRAW_ONCE:
				evals[i] = Card.NOT(id)
				ido = true
			else:
				ido = ido || evals[i].update_draw_once(id)
		return ido
	
	
	func add_requirement(req: Variant) -> void:
		if req is RarityEval:
			evals.append(req)
		if req is StringName || req is String:
			card_ids.append(req as StringName)
	
	
	func can_draw(player: Player) -> bool:
		if !card_ids.is_empty():
			for id in card_ids:
				cards.append(Card.get_card(id))
			card_ids.clear()
		
		match mode:
			MODE_ALL:
				var re_all := evals.all(func(re:RarityEval)->bool:return re.can_draw(player))
				var cd_all := cards.all(func(card:Card)->bool:return player.cards.has(card))
				return (re_all && cd_all) != inverted
			MODE_ANY:
				var re_any := evals.any(func(re:RarityEval)->bool:return re.can_draw(player))
				var cd_any := cards.any(func(card:Card)->bool:return player.cards.has(card))
				return (re_any || cd_any) != inverted
			MODE_TRUE, _:
				return !inverted


static func NOT(arg: Variant) -> RarityEval:
	if arg == null: return null
	var re: RarityEval = (arg as RarityEval) if (arg is RarityEval) else ALL(arg)
	re.inverted = !re.inverted
	return re


## Requires that all arguments return true. Evaluates to true if no arguments are passed.
static func ALL(...args: Array) -> RarityEval:
	var re := RarityEval.new(RarityEval.MODE_ALL)
	for arg:Variant in args:
		re.add_requirement(arg)
	return re


## Requires that at least one argument returns true. Evaluates to false if no arguments are passed.
static func ANY(...args: Array) -> RarityEval:
	var re := RarityEval.new(RarityEval.MODE_ANY)
	for arg:Variant in args:
		re.add_requirement(arg)
	return re


## Always returns false
static func NEVER() -> RarityEval:
	var re := RarityEval.new(RarityEval.MODE_TRUE)
	re.inverted = true
	return re
