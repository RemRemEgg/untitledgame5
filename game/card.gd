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
static var DECK_SPELL: CardDeck
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
##		var amount := clampf(de.amount / player.max_health, 0.0, 1.0)
##		# Increase knockback based on damage
##		de.knockback += de.knockback.normalized() * amount * 10.0
##		# Reduce damage taken
##		de.amount *= 0.65
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
##			var amount := clampf(de.amount / player.max_health, 0.0, 1.0)
##			de.knockback += de.knockback.normalized() * amount * 10.0
##			de.amount *= 0.65
##			return de
##		)
##)
##[/codeblock]
static func register_card(uuid_: StringName, name_: StringName, flavor_: StringName, deck_: CardDeck, rarity_: int, style_: int, spider_: Array[float], rarityeval: RarityEval, effect: Callable) -> void:
	Console.print(&"Loading card %s" % uuid_)
	
	var uuid_exists := ALL_CARDS.find_custom(func(c:Card)->bool: return c.uuid == uuid_) + 1
	if uuid_exists:
		Console.print_err(&"Cannot load card %s(%s), uuid is already in use" % [uuid_, name_])
		return
	
	if name_.is_empty() || name_.length() > 32:
		Console.print_err(&"Cannot load card %s(%s), name is too long or nonexistant" % [uuid_, name_])
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
	DECK_TEXTURE_TEST = CardDeck.new(&"texture_test", load("res://textures/decks/deck_init.png") as Texture2D)
	DECKS.append(DECK_TEXTURE_TEST)
	DECK_DEBUG = CardDeck.new(&"debug", load("res://textures/decks/deck_debug.png") as Texture2D)
	DECKS.append(DECK_DEBUG)
	DECK_INIT = CardDeck.new(&"init", load("res://textures/decks/deck_init.png") as Texture2D)
	DECKS.append(DECK_INIT)
	DECK_GUN = CardDeck.new(&"gun", load("res://textures/decks/deck_gun.png") as Texture2D)
	DECKS.append(DECK_GUN)
	DECK_MAGIC = CardDeck.new(&"magic", load("res://textures/decks/deck_magic.png") as Texture2D)
	DECKS.append(DECK_MAGIC)
	DECK_SPELL = CardDeck.new(&"spell", load("res://textures/decks/deck_magic.png") as Texture2D)
	DECKS.append(DECK_SPELL)
	DECK_PLAYER = CardDeck.new(&"player", load("res://textures/decks/deck_player.png") as Texture2D)
	DECKS.append(DECK_PLAYER)
	DECK_ALIGN = CardDeck.new(&"align", load("res://textures/decks/deck_init.png") as Texture2D)
	DECKS.append(DECK_ALIGN)
	DECK_OTHER = CardDeck.new(&"other", load("res://textures/decks/deck_debug.png") as Texture2D)
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
	register_card(&"TXTR", &"Texture Unlocker", &"Adds $sTexture Debug$d cards",
		DECK_TEXTURE_TEST, RARITY_COMMON, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], NEVER(),
		func card(cd:CardData) -> void:
			cd.add_description(&"Only texture cards will be drawn", true, true)
			for wdeck in cd.player.deck_weights:
				cd.player.deck_weights[wdeck] = 0.0
			cd.player.deck_weights[DECK_TEXTURE_TEST] = 1.0
	)
	register_card(&"INTN", &"Texture Internal", &"$sTexture Debuger$d\nInternal",
		DECK_TEXTURE_TEST, RARITY_INTERNAL, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"COMN", &"Texture Common", &"$sTexture Debuger$d\nCommon",
		DECK_TEXTURE_TEST, RARITY_COMMON, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"UNUS", &"Texture Unusual", &"$sTexture Debuger$d\nUnusual",
		DECK_TEXTURE_TEST, RARITY_UNUSUAL, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"RARE", &"Texture Rare", &"$sTexture Debuger$d\nRare",
		DECK_TEXTURE_TEST, RARITY_RARE, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	register_card(&"EPIC", &"Texture Epic", &"$sTexture Debuger$d\nEpic",
		DECK_TEXTURE_TEST, RARITY_EPIC, STYLE_BASIC, [1.1, 1.0, 1.0, 1.0, 1.0, 1.0], ALL(&"texture_unlock"),
		func card(cd:CardData) -> void: pass
	)
	#endregion
	
	
	#region alignment cards
	register_card(&"RNGR", &"Ranger's Soul", &"",
		DECK_ALIGN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 1.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_description(&"Align yourself with the rangers, finding gun cards more often", true)
			cd.player.deck_weights[DECK_GUN] += 0.4
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
	)
	register_card(&"MGCN", &"Magicians's Soul", &"",
		DECK_ALIGN, RARITY_EPIC, STYLE_BASIC, [1.0, 0.0, 0.0, 0.0, 0.0, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_description(&"Align yourself with the magicians, finding magic cards more often", true)
			cd.player.deck_weights[DECK_MAGIC] += 0.4
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
	)
	register_card(&"MONK", &"Monk's Soul", &"",
		DECK_ALIGN, RARITY_EPIC, STYLE_BASIC, [0.0, 1.0, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_description(&"Align yourself with the monks, finding player cards more often", true)
			cd.player.deck_weights[DECK_PLAYER] += 0.4
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
	)
	register_card(&"PRAY", &"Pray to the Obelisk", &"Pray to the Obelisk",
		DECK_ALIGN, RARITY_RARE, STYLE_BASIC, [1.0, 1.0, 1.0, 1.0, 1.0, 1.001], ANY(&"align_gun", &"align_magic", &"align_player"),
		func card(cd:CardData) -> void:
			cd.add_description(&"Your alignments are more polarized", true)
			cd.player.deck_weights[DECK_ALIGN] *= 0.5
			for ideck in cd.player.deck_weights:
				cd.player.deck_weights[ideck] *= cd.player.deck_weights[ideck]
	)
	#endregion
	
	
	
	#region init card
	register_card(&"RFLE", &"Rifle", &"For the campers",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.2, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 1.5)
			cd.add(cd.gun.fire_rate, -10.5)
			cd.add(cd.gun.b_speed, 300)
			cd.mult(cd.gun.inaccuracy, 0.4)
			cd.add(cd.gun.clip_size, -6)
			cd.add(cd.gun.reload_time, 2.25)
	)
	register_card(&"STGN", &"Shotgun", &"must.....kill.......",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.5, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 0.25)
			cd.mult(cd.gun.inaccuracy, 3.2)
			cd.add(cd.gun.fire_rate, -11.0)
			cd.add(cd.gun.inaccuracy, 10.0)
			cd.add(cd.gun.clip_size, 10)
			cd.add(cd.gun.bullets_per_shot, 6)
			cd.add(cd.gun.reload_time, 1.0)
	)
	register_card(&"REVO", &"Revolver", &"Fires faster than you can click",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 1.2)
			cd.add(cd.gun.clip_size, -5)
			cd.add(cd.gun.reload_time, 1.5)
	)
	register_card(&"QUAD", &"Quadruple Barrel", &"4 Bullets > 1 Bullet",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add_description(&"Enables Full Auto", true, true)
			cd.player.full_auto = true
			cd.mult(cd.proj.damage, 0.3)
			cd.add(cd.gun.inaccuracy, 12)
			cd.add(cd.gun.clip_size, 14)
			cd.add(cd.gun.bullets_per_shot, 3)
			cd.add(cd.gun.fire_rate, -9.0)
			cd.add(cd.gun.reload_time, 1.0)
			cd.mult(cd.gun.b_speed, 0.65)
	)
	register_card(&"BLND", &"Blunderbuss", &"Hoist the sails!",
		DECK_INIT, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.damage, 10)
			cd.mult(cd.proj.damage, 1.3)
			cd.add(cd.proj.scale, 5.0)
			cd.add(cd.gun.clip_size, -8)
			cd.add(cd.gun.fire_rate, -11)
			cd.add(cd.gun.reload_time, 0.5)
			cd.add(cd.proj.knockback, 100.0)
			cd.mult(cd.gun.b_speed, 0.6)
	)
	register_card(&"MIGN", &"Minigun", &"\"Glorified noise-maker\"",
		DECK_INIT, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.player.full_auto = true
			cd.add_description(&"Enables Full Auto", true, true)
			cd.mult(cd.proj.damage, 0.2)
			cd.mult(cd.gun.inaccuracy, 2.5)
			cd.add(cd.gun.inaccuracy, 8.0)
			cd.add(cd.gun.clip_size, 32)
			cd.add(cd.gun.fire_rate, 1.0)
			cd.add(cd.gun.reload_time, 1.75)
			cd.add(cd.gun.b_speed, 50)
	)
	register_card(&"SMGN", &"Submachine Gun", &"bewp!",
		DECK_INIT, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.player.full_auto = true
			cd.add_description(&"small mag, high RoF", true)
			cd.mult(cd.proj.damage, 0.2, false)
			cd.add(cd.gun.inaccuracy, 10, false)
			cd.add(cd.gun.clip_size, 16, false)
			cd.add(cd.gun.fire_rate, 7, false)
			cd.add(cd.gun.reload_time, 0.25, false)
	)
	register_card(&"LMGN", &"Light Machine Gun", &"gorp!",
		DECK_INIT, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.player.full_auto = true
			cd.add_description(&"Balanced RoF, high speed and reload time", true)
			cd.mult(cd.proj.damage, 0.3, false)
			cd.add(cd.gun.inaccuracy, 1, false)
			cd.add(cd.gun.clip_size, 50, false)
			cd.add(cd.gun.fire_rate, -8, false)
			cd.add(cd.gun.b_speed, 200, false)
			cd.add(cd.gun.reload_time, 1.5, false)
	)
	register_card(&"PESH", &"Peashooter", &"pew pew pew",
		DECK_INIT, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add_description(&"Pistol", true)
	)
	#endregion
	
	
	register_card(&"LDUD", &"Dud lmao", &"Does nothing.",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.01, 0.0, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void: pass
	)
	
	
	#region deck gun
	
	
	register_card(&"GRPL", &"Grapple", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_description("Bullets pull players toward you", true)
			cd.mult(cd.proj.knockback, -1, false)
	)
	
	register_card(&"LBRL", &"Long barrel", &"me when i see femboys",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.inaccuracy, -8)
			cd.add(cd.gun.b_speed, 100)
	)
	
	register_card(&"SBRL", &"Short barrel", &"estrogen",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.inaccuracy, 10)
			cd.add(cd.proj.damage, 8)
			cd.add(cd.gun.fire_rate, 2)
	)
	
	register_card(&"WSTE", &"Wasteful", &"who needs the rest of the mag?",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.reload_time, 0.2)
			cd.add_effect(&"Reload after every shot fired", true, cd.player.shooting_hook,
				func effect(ed:EventHook.EventData) -> void:
					ed.player.gun.reload = ed.player.procgun.reload_time.value
			)
	)
	
	register_card(&"RUBB", &"Rubber Bullets", &"Boing!",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.bounces, 3)
	)
	
	register_card(&"SHRP", &"Sharper Bullets", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.damage, 11)
			cd.add(cd.gun.reload_time, 0.15)
	)
	
	register_card(&"HVHT", &"Heavy Hitter", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0], ALL(DRAW_ONCE, &"SHRP"),
		func card(cd:CardData) -> void:
			cd.add(cd.proj.damage, 25)
			cd.mult(cd.gun.fire_rate, 0.75)
	)
	
	register_card(&"CMBN", &"Combine", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.0, 1.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 1.5)
			cd.mult(cd.gun.clip_size, 0.7)
	)
	
	register_card(&"BGBU", &"Big Bullets", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 0.5, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.scale, 4.5)
			cd.mult(cd.gun.b_speed, 0.75)
	)
	
	register_card(&"FSBL", &"Fastball", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, -0.2, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.b_speed, 100)
			cd.add(cd.proj.damage, 3.0)
	)
	
	register_card(&"OCFM", &"Overclocked Firing Mechanism", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], ALL(NOT(&"OCFM"), DRAW_ONCE),
		func card(cd:CardData) -> void:
			cd.add_description(&"Enables Full Auto", true, true)
			cd.player.full_auto = true
			cd.mult(cd.gun.fire_rate, 2.2)
			cd.mult(cd.gun.clip_size, 1.5)
			cd.mult(cd.proj.damage, 0.6)
			cd.add(cd.gun.reload_time, 0.15)
			cd.add(cd.gun.inaccuracy, 3)
	)
	
	register_card(&"SAWN", &"Sawed-Off", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], ALL(NOT(&"SAWN"), DRAW_ONCE),
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.fire_rate, 1.5)
			cd.mult(cd.gun.clip_size, 1.5)
			cd.mult(cd.gun.bullets_per_shot, 2.0)
			cd.mult(cd.proj.damage, 0.6)
			cd.add(cd.gun.reload_time, 0.3)
			cd.add(cd.gun.inaccuracy, 8.5)
	)
	
	register_card(&"IRON", &"Iron Cannon", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.knockback, 50.0)
			cd.add(cd.proj.scale, 1.5)
			cd.add(cd.proj.damage, 5)
			cd.mult(cd.gun.fire_rate, 0.65)
			cd.add(cd.gun.clip_size, -2)
	)
	
	register_card(&"WD40", &"WD-40", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.reload_time, 0.75)
			cd.add(cd.gun.b_speed, 75)
			cd.mult(cd.proj.damage, 0.90)
	)
	
	register_card(&"OVLB", &"Over-Lubricated", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], ALL(&"WD40", DRAW_ONCE),
		func card(cd:CardData) -> void:
			cd.add_description(&"Enables Full Auto", true, true)
			cd.player.full_auto = true
			cd.mult(cd.gun.fire_rate, 0.75)
	)
	
	register_card(&"QCTC", &"Quick Trick", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.fire_rate, 1.15)
			cd.add(cd.gun.reload_time, -0.1)
			cd.mult(cd.gun.reload_time, 0.95)
	)
	
	register_card(&"TACH", &"Tachyon Bullets", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.5, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.b_speed, 144)
			cd.mult(cd.gun.b_speed, 14.4)
			cd.add(cd.gun.fire_rate, 1.44)
			cd.add(cd.gun.reload_time, 0.144)
	)
	
	register_card(&"SCAV", &"Scavenger", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.5, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.fire_rate, 0.575951)
			cd.add_effect(&"Reloads $s1 bullet$p into your mag upon shooting players", true, cd.proj.damage_hook,
				func effect(ed:EventHook.EventData) -> void:
					ed.player.gun.clip = mini(ed.gun.clip_size.value_int, roundi(ed.player.gun.clip + ed.multi+0.1))
			)
	)
	
	register_card(&"BCBB", &"Bloody Cold Bullets", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.1, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.clip_size, 3)
			cd.add_effect(&"Dealing ranged damage temporarily increases fire rate", true, cd.proj.damage_hook,
				func effect(ed:EventHook.EventData) -> void:
					cd.gun.fire_rate.mult_temp(1.15, 1.0*ed.mult**0.75, ed.mult)
			)
	)
	
	register_card(&"ACEL", &"Accelerator", &"Accelerator is an Understatement",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, 0.75, 0.5, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.clip_size, 1.5)
			cd.add_effect(&"Fire Rate is proportional to how empty your magazine is", true, cd.player.shooting_hook,
				func effect(ed:EventHook.EventData) -> void:
					ed.player.gun.fire_timer += 1.0 - (ed.player.gun.clip / ed.gun.clip_size.value) ** ed.mult
			)
			cd.mult(cd.gun.fire_rate, 0.85)
	)
	
	register_card(&"HKEY", &"Hawkeye", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 1.0, 0.2], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.b_speed, 200)
			cd.add(cd.proj.damage, 4.0)
			cd.add(cd.gun.inaccuracy, -12.0)
			cd.add(cd.gun.fire_rate, 0.2)
			cd.add(cd.gun.reload_time, 0.5)
	)
	
	register_card(&"BRGE", &"Barrage", &"",
		DECK_GUN, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.bullets_per_shot, 5)
			cd.add(cd.gun.clip_size, 10)
			cd.add(cd.gun.inaccuracy, 8)
			cd.mult(cd.proj.damage, 0.6)
			cd.add(cd.gun.reload_time, 0.5)
	)
	
	register_card(&"MINI", &"Mini Bullets", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.gun.clip_size, 2.0)
			cd.add(cd.gun.reload_time, -0.2)
			cd.mult(cd.proj.damage, 0.85)
			cd.mult(cd.proj.scale, 0.85)
	)
	
	register_card(&"LRGM", &"Larger Magazine", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, -0.2, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.clip_size, 3.0)
			cd.add(cd.gun.reload_time, 0.2)
	)
	
	register_card(&"GLSS", &"Glass Cannon", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 1.0, -0.5, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 1.55)
			cd.mult(cd.player.max_health, 0.65)
	)
	
	register_card(&"NLTH", &"Nonlethals", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.knockback, 25)
			cd.add(cd.proj.scale, 1.5)
			cd.mult(cd.proj.damage, 0.90)
	)
	
	register_card(&"SPNG", &"Sproing", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.proj.knockback, 10.0)
			cd.add(cd.proj.bounces, 1)
	)
	
	register_card(&"SPLD", &"Spring Loaded", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.gun.b_speed, 85)
			cd.add(cd.proj.knockback, 15)
	)
	
	register_card(&"EXBU", &"Explosive Bullets", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 0.75)
			cd.add_effect(&"Bullets explode where they land", true, cd.proj.collide_hook,
				func effect(ed:EventHook.EventData)-> void:
					var rt := ed.mult ** 0.333
					Game.world.create_explosion(ed.position, rt * 2.0, rt * 10.0, rt * 15.0, [], ed.player)
			)
	)
	
	register_card(&"MINE", &"Mines", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 0.75)
			cd.add_effect(&"Bullets leave mines where they land", true, cd.proj.collide_hook,
				func effect(ed:EventHook.EventData)-> void:
					var trans := Transform3D.IDENTITY
					trans.origin = ed.position
					var rt := sqrt(ed.mult)
					var radius := 4.0 * rt
					FieldHandler.spawn(FieldHandler.MINE, trans, radius, 15.0, rt*0.5)
			)
	)
	
	register_card(&"TRGT", &"Target Bounce", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 0.75)
			cd.add(cd.proj.bounces, 1.0)
			cd.add_effect(&"Bullets bounce towards nearby visible players", true, cd.proj.collide_hook,
				func effect(ed:EventHook.EventData)-> void:
					var players := Game.world.get_aoe_players(ed.position, ed.mult*48.0)
					for player in players:
						var s := ed.position
						var e := player.global_position
						if ed.proj_inst.velocity.dot(e-s)>0.0 && Game.world.has_line(s, e):
							var l := ed.proj_inst.velocity.length()
							ed.proj_inst.velocity = ed.position.direction_to(player.global_position) * l * 0.93
							return
			)
	)
	#endregion
	
	
	#region deck magic
	register_card(&"BLIN", &"Blood Infusion", &"A prick of the finger should suffice",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, -15)
			cd.mult(cd.player.magic_cd, 0.85)
			cd.add(cd.player.magic_potency, 0.5)
			
	)
	
	register_card(&"MEDT", &"Meditate", &"Let go or be dragged",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true;
			cd.add(cd.player.max_health, 15)
			cd.mult(cd.selected_spell.cooldown, 0.85)
			cd.add(cd.selected_spell.potency, 0.3)
	)
	
	register_card(&"BOTM", &"Blessing of the Monk", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], ALL(NOT(&"BOTM"),NOT(&"BOTW"),NOT(&"BOTN"),&"MEDT"),
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.add(cd.player.max_health, 30)
			cd.mult(cd.player.magic_potency, 1.75)
			cd.add(cd.selected_spell.max_charges,1)
	)
		
	register_card(&"BOTW", &"Blessing of the Wizard", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], ALL(NOT(&"BOTM"),NOT(&"BOTW"),NOT(&"BOTN"),&"MEDT"),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_potency, 1.25)
			cd.mult(cd.player.magic_cd, .75)
	)
	
	register_card(&"BOTN", &"Blessing of the Necromancer", &"[i]breath of the nild[/i]",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], ALL(NOT(&"BOTM"),NOT(&"BOTW"),NOT(&"BOTN"),&"MEDT"),
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, -30)
			cd.mult(cd.player.magic_potency, 1.5)
			cd.mult(cd.player.magic_cd, 0.75)
	)
	
	register_card(&"MASO", &"Masochist", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.1, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.magic_cd, 0.3)
			cd.add_effect(&"Taking damage decreases magic cd", true, cd.player.damage_hook,
				func effect(ed:EventHook.EventData) -> void:
					var amo := ed.damage.amount / ed.player.health
					cd.player.magic_cd.mult_temp(1.0 / (amo * ed.mult + 1.0), 4.0, ed.mult)
			)
	)
	
	register_card(&"APRN", &"Apprentice", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.75)
	)
	
	register_card(&"MAGE", &"Mage", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"APRN"),
		func card(cd:CardData) -> void:
			cd.add(cd.player.magic_potency, 0.5)
			cd.add(cd.player.max_health, 50)
	)
	
	register_card(&"SORC", &"Sorcerer", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"MAGE", NOT(&"WRLK")),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_potency, 0.6)
			cd.add_effect(&"Chain casting has a 50% chance to not consume charges", true, cd.player.spell_hook,
				func effect(ed:EventHook.EventData) -> void:
					if ed.is_chain && randf() > 0.5: ed.spell.cast(ed.player, true)
			)
	)
	
	register_card(&"WRLK", &"Warlock", &"",
		DECK_MAGIC, RARITY_EPIC, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"MAGE", NOT(&"SORC")),
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.5)
			cd.add(cd.player.magic_potency, 1.5)
			cd.add_effect(&"Casting costs 30% current hp", false, cd.player.spell_hook,
				func effect(ed:EventHook.EventData) -> void:
					ed.player.health *= 0.7
			)
	)
	
	register_card(&"MCHN", &"Mythical Chains", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], ALL(DRAW_ONCE, &"MAGE"),
		func card(cd:CardData) -> void:
			cd.add_description(&"Slightly lower chain casting window", false)
			cd.add_effect(&"Remove delay between chain casts", true, cd.player.spell_hook,
				func effect(ed:EventHook.EventData) -> void:
					if ed.is_chain: ed.player.magic_timer = 0.5
			)
	)
	
	register_card(&"FSRD", &"Fast Reader", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.mult(cd.selected_spell.cooldown, 0.7)
			cd.mult(cd.selected_spell.potency, 0.9)
	)
	
	register_card(&"BDUP", &"Buildup", &"",
		DECK_MAGIC, RARITY_COMMON, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.add(cd.selected_spell.potency, 0.5)
			cd.add(cd.selected_spell.cooldown, 0.2)
	)
	
	register_card(&"FOCS", &"Focus", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.add(cd.selected_spell.potency, 1.0)
			cd.add(cd.selected_spell.cooldown, 0.5)
	)
	
	register_card(&"QKCS", &"Quick Cast", &"",
		DECK_MAGIC, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.add(cd.selected_spell.max_charges, 1.0)
			cd.mult(cd.selected_spell.potency, 0.75)
	)
	
	register_card(&"DNSE", &"Condense", &"[i]condesnse![/i]",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.mult(cd.selected_spell.max_charges, 0.0)
			cd.add(cd.selected_spell.potency, 2.0)
			cd.add(cd.selected_spell.cooldown, 1.0)
	)
	
	register_card(&"BMAW", &"Blood Magic", &"Alchemical wizardry!",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.magic_cd, 0.75)
			cd.add(cd.player.max_health, -25)
	)
	
	register_card(&"TRNS", &"Transmutation", &"",
		DECK_MAGIC, RARITY_RARE, STYLE_BASIC, [1.0, 0.3, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.use_spell_selection = true
			cd.add(cd.selected_spell.max_charges, 2.0)
			cd.mult(cd.gun.clip_size, 0.5)
	)
	#endregion
	
	
	#region deck spell
	#register_card(&"PLAT", &"Platform", &"",
		#DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		#func card(cd:CardData) -> void:
			#cd.add_spell_effect(&"[Spell] Places a platorm below you", true,
				#func effect(ed:EventHook.EventData) -> void:
					#ed.player.jumps = ed.player.max_jumps.value_int
					#for x in (1.0+ed.multi*2.0): for z in (1.0+ed.multi*2.0):
						#Network.spawn_levelbody.rpc(ed.player.global_position + Vector3(x-ed.multi, -1.5, z-ed.multi),
						#LevelBody.Type.BREAKABLE, true)
			#)
	#)
	
	register_card(&"WALL", &"Wall", &"[i]thunk.[/i]",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"[Spell] Places a wall infront of you", true,
				func effect(ed:EventHook.EventData) -> void:
					var trans := ed.player.camera.global_transform
					var mi := roundi(ed.mult * 2)
					trans.basis.x *= -1.0 # ???
					trans.basis.y *= -1.0 # parts of matrix are inverted?
					for x in (1.0+mi*2.0): for y in (1.0+mi*2.0):
						Network.spawn_levelbody.rpc(trans.origin + (Vector3(x-mi, y-mi, -4.0) * trans.basis),
						LevelBody.Type.BREAKABLE, true)
			)
	)
	
	register_card(&"SNRE", &"Snare", &"",
		DECK_SPELL, RARITY_RARE, STYLE_BASIC, [1.0, 0.0, 0.0, 0.0, 0.0, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 1)
			cd.add_spell_effect(&"[Spell] Trap nearby enemies in blocks", true,
				func effect(ed:EventHook.EventData) -> void:
					for player in Game.world.get_aoe_players(ed.player.global_position, ed.mult * 4.0 + 4.0, [ed.player]):
						var ed2 := 1.0 + (ed.multi*2.0)
						for x in ed2: for y in ed2+1: for z in ed2:
							var target := Vector3(x-ed.multi, y-0.5-ed.multi, z-ed.multi)
							if !(is_zero_approx(target.x) && absf(target.y) <= 0.6 && is_zero_approx(target.z)):
								Network.spawn_levelbody.rpc(player.global_position + target,
								2-(randi_range(0, 2)%2), false)
			)
	)
	
	register_card(&"HEAL", &"Heal", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 2.0)
			cd.add_spell_effect(&"[Spell] Steal life from nearby opponents", true,
				func effect(ed:EventHook.EventData) -> void:
					for player in Game.world.get_aoe_players(ed.player.global_position, ed.mult * 4.0 + 4.0, [ed.player]):
						var amo := 6.0 * ed.mult
						var de := DamageEvent.new(amo, Vector3.ZERO, DamageEvent.TYPE_MAGIC)
						de.source_entity = ed.player
						player.take_damage_seralized.rpc(de.seralize())
						ed.player.health = minf(ed.player.health + amo*1.5, ed.player.max_health.value)
			)
	)
	
	register_card(&"SLOW", &"Slow", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 2.0)
			cd.add_spell_effect(&"[Spell] Slow nearby opponents", true,
				func effect(ed:EventHook.EventData) -> void:
					for player in Game.world.get_aoe_players(ed.player.global_position, ed.mult * 6.0 + 3.0, [ed.player]):
						Network.slow_player.rpc_id(player.uuid, 0.7, 4.0, ed.mult)
			)
	)
	
	register_card(&"WIND", &"Windwalker", &"",
		DECK_SPELL, RARITY_RARE, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 2.0)
			cd.add_spell_effect(&"[Spell] Increased agility for a short time", true,
				func effect(ed:EventHook.EventData) -> void:
					ed.player.speed.mult_temp(1.3, 3.0, ed.mult)
					ed.player.accel.mult_temp(1.3, 3.0, ed.mult)
					ed.player.jump.mult_temp(1.3, 3.0, ed.mult)
			)
	)
	
	register_card(&"INSK", &"Ironskin", &"",
		DECK_SPELL, RARITY_EPIC, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 4.0)
			cd.add_spell_effect(&"[Spell] Increased armor density and regen for a short time", true,
				func effect(ed:EventHook.EventData) -> void:
					var p := ed.player.armor / ed.player.armor_density.value
					ed.player.armor_density.mult_temp(2.0, 4.0, ed.mult)
					ed.player.armor_regen.mult_temp(2.0, 4.0, ed.mult)
					ed.player.armor = p * ed.player.armor_density.value
			)
	)
	
	register_card(&"PULT", &"Magipult", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.75)
			cd.add_spell_effect(&"[Spell] Launch yourself forward", true,
				func effect(ed:EventHook.EventData) -> void:
					var vel := ed.player.velocity
					ed.player.velocity = -ed.player.camera.global_basis.z * 96.0 * ed.mult
					vel += ed.player.velocity * ed.player.speed.value * ed.mult * (3 / 100.0)
					ed.player.move_and_slide()
					ed.player.velocity = vel
			)
	)
	
	register_card(&"WARP", &"Warp", &"woosh!",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.5)
			cd.add_spell_effect(&"[Spell] Teleport forward", true,
				func effect(ed:EventHook.EventData) -> void:
					var vel := ed.player.velocity
					ed.player.velocity = -ed.player.camera.global_basis.z * 48.0 * ed.mult
					ed.player.move_and_collide(ed.player.velocity)
					ed.player.velocity = vel
			)
	)
	
	register_card(&"FIRE", &"Fireball", &"i cast. . . $sFIREBALL$d!",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.75)
			cd.add_spell_effect(&"[Spell] Cast many small fireballs", true,
				func effect(ed:EventHook.EventData) -> void:
					var rt := ed.mult ** 0.5
					for i in (rt * 3.5)+1:
						var inacc_trans := ed.player.camera.global_transform \
							.rotated_local(Vector3.FORWARD, randf_range(0, PI*2.0)) \
							.rotated_local(Vector3.RIGHT, randf() * (0.1 + rt*0.12))
						AltProjHandler.spawn(AltProjHandler.FIREBALL, inacc_trans, Vector3(0, 0, -25 * rt), ed.player)
			)
	)
	
	register_card(&"AGRV", &"Anti-Gravity Field", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"[Spell] Spawn an anti-gravity field", true,
				func effect(ed:EventHook.EventData) -> void:
					var trans := Transform3D.IDENTITY
					var radius := 16.0 * ed.mult
					trans.origin = ed.player.global_position + ed.player.camera.global_basis.z * -0.5*(radius + 4.0)
					FieldHandler.spawn(FieldHandler.REVERSE_GRAV, trans, radius, 8.0, 0.5)
			)
	)
	
	register_card(&"WNDF", &"Wind Field", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"[Spell] Spawn a wind field that pushes objects", true,
				func effect(ed:EventHook.EventData) -> void:
					var trans := ed.player.camera.global_transform
					var rt := ed.mult ** 0.5
					var radius := 16.0 * rt
					trans.origin = ed.player.global_position + ed.player.camera.global_basis.z * -0.5*(radius + 4.0)
					FieldHandler.spawn(FieldHandler.WIND, trans, radius, 8.0, rt * 2.0)
			)
	)
	
	register_card(&"IMPF", &"Implode Field", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"[Spell] Spawn a field that pulls everything in", true,
				func effect(ed:EventHook.EventData) -> void:
					var trans := Transform3D.IDENTITY
					trans.origin = ed.position
					var rt := sqrt(ed.mult)
					var radius := 16.0 * rt
					trans.origin = ed.player.global_position + ed.player.camera.global_basis.z * -0.5*(radius + 4.0)
					FieldHandler.spawn(FieldHandler.IMPLODE, trans, radius, 4.0, rt)
			)
	)
	
	register_card(&"RUSH", &"Rush Field", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"[Spell] Spawn a field that accelerates players", true,
				func effect(ed:EventHook.EventData) -> void:
					var trans := Transform3D.IDENTITY
					trans.origin = ed.position
					var rt := sqrt(ed.mult)
					var radius := 12.0 * rt
					trans.origin = ed.player.global_position + ed.player.camera.global_basis.z * -0.5*(radius + 4.0)
					FieldHandler.spawn(FieldHandler.ACCELERATE, trans, radius, 4.0, rt*1.25)
			)
	)
	
	register_card(&"EXTP", &"Explosive Trap", &"",
		DECK_SPELL, RARITY_UNUSUAL, STYLE_BASIC, [-0.2, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 0.25)
			cd.add_spell_effect(&"[Spell] Spawn an explosive trap", true,
				func effect(ed:EventHook.EventData) -> void:
					var trans := Transform3D.IDENTITY
					trans.origin = ed.position
					var rt := sqrt(ed.mult)
					var radius := 16.0 * rt
					trans.origin = ed.player.global_position + ed.player.camera.global_basis.z * -0.5*(radius + 6.0)
					FieldHandler.spawn(FieldHandler.MINE, trans, radius, 15.0, rt)
			)
	)
	
	register_card(&"SHWV", &"Shockwave", &"",
		DECK_SPELL, RARITY_RARE, STYLE_BASIC, [1.0, 0.0, 0.0, 0.0, 0.0, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.selected_spell.cooldown, 1.3)
			cd.add_spell_effect(&"[Spell] Forcefully push everything away", true,
				func effect(ed:EventHook.EventData) -> void:
					var pos := ed.player.global_position + Vector3(0.0, -0.15, 0.0)
					# scales the cross sectional area of the sphere
					var radius := (ed.mult ** 0.5) * 8
					VFXHandler.spawn(VFXHandler.SPELL_SHOCKWAVE, pos, [radius])
					var objects := Game.world.get_aoe_objects(pos, radius, [ed.player.get_rid()])
					
					for obj in objects:
						var dir := pos.direction_to(obj.global_position)
						dir *= radius * 4.0
						
						if obj is Player:
							var de := DamageEvent.new(4.0 * ed.mult, dir, DamageEvent.TYPE_MAGIC)
							de.source_entity = ed.player
							(obj as Player).take_damage_seralized.rpc(de.seralize())
							continue
						if obj is RigidBody3D:
							if (obj as RigidBody3D).freeze: continue
							(obj as RigidBody3D).apply_central_impulse.rpc(dir * 2.0)
			)
	)
	#endregion
	
	
	#region deck player
	register_card(&"IMPL", &"Impact Plates", &"",
		DECK_PLAYER, RARITY_EPIC, STYLE_BASIC, [.77, 0.0, 0.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.armor_density, 16.0)
			cd.mult(cd.player.speed, 0.9)
			cd.mult(cd.player.jump, 0.9)
			cd.add_effect(&"Converts $s20%$p of damage taken to knockback taken", true, cd.player.damage_hook,
				func(ed:EventHook.EventData) -> void:
					var amount := clampf(ed.damage.amount / ed.player.max_health.value, 0.0, 1.0)
					ed.damage.knockback += ed.damage.knockback.normalized() * amount * 25.0 * ed.mult
					ed.damage.amount *= 0.8 ** ed.mult
			)
	)
	
	register_card(&"FFCH", &"Fat Fucking Chud", &"",
		DECK_PLAYER, RARITY_RARE, STYLE_BASIC, [0.0, 1.0, -0.5, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, 86)
			cd.mult(cd.player.speed, 0.86)
			cd.mult(cd.player.jump, 0.86)
			cd.mult(cd.player.accel, 0.86)
	)
	
	register_card(&"GTYK", &"Get Yoked", &"",
		DECK_PLAYER, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.jump, 0.15)
			cd.add(cd.player.accel, 8.0)
			cd.add(cd.player.max_stamina, 1.0)
			cd.add(cd.player.melee_damage, 15.0)
	)
	
	register_card(&"UTLI", &"Ultralight", &"Now with 10% more Speed per Speed!",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, -0.5, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.speed, 2)
			cd.add(cd.player.accel, 16)
			cd.add_effect(&"+50% Knockback Taken", false, cd.player.damage_hook,
				func effect(ed:EventHook.EventData) -> void:
					ed.damage.knockback *= 1.5 ** ed.mult
			)
	)
	
	register_card(&"BRDN", &"Burden Breaker", &"",
		DECK_PLAYER, RARITY_EPIC, STYLE_BASIC, [0.0, -0.5, 1.0, 0.0, 0.0, 0.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.speed, 2.0)
			cd.mult(cd.player.accel, 0.75)
	)
	
	register_card(&"LGDY", &"Leg Day", &"Never skip!",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.2], null,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.melee_cd, 0.75)
			cd.add(cd.player.speed, 2.5)
			cd.add(cd.player.melee_damage, 15.0)
	)
	
	register_card(&"BRAM", &"Battering Ram", &"Never skip!",
		DECK_PLAYER, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.2], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.melee_cd, 0.7)
			cd.add(cd.player.speed, 4.0)
			cd.add(cd.player.melee_damage, 30.0)
			cd.mult(cd.player.accel, 0.8)
	)
	
	register_card(&"SCRF", &"Sacrifice", &"",
		DECK_PLAYER, RARITY_RARE, STYLE_BASIC, [0.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add_description(&"Remove one card from your deck\nMust be done manually, before card is picked", true)
			cd.mult(cd.player.max_health, 1.25)
	)
	
	register_card(&"INDS", &"Industrious", &"",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, 1.0, 0.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, 1.1)
			cd.add(cd.player.max_health, 10)
			cd.mult(cd.player.speed, 1.10)
	)
	
	register_card(&"GRHM", &"Growth Hormones", &"get big.",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, 1.0, 1.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, 35)
			cd.add(cd.proj.scale, 1.2)
	)
	
	register_card(&"VTLP", &"Vertical Leap", &"",
		DECK_PLAYER, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_jumps, 1)
			cd.add(cd.player.jump, 2.0)
	)
	
	register_card(&"CMPS", &"Composed", &"",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [1.0, 0.0, 0.0, 0.0, 1.0, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.max_health, 60)
			cd.mult(cd.gun.fire_rate, 1.27)
			cd.mult(cd.player.speed, 0.85)
	)
	
	register_card(&"BING", &"Boing", &"",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 1.0], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.jump, 2.0)
			cd.add(cd.proj.knockback, 6.0)
	)
	
	register_card(&"OEDG", &"On Edge", &"",
		DECK_PLAYER, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.7], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.accel, 1.5)
			cd.add(cd.gun.reload_time, -0.15)
	)
	
	register_card(&"ANXS", &"Anxious", &"",
		DECK_PLAYER, RARITY_UNUSUAL, STYLE_BASIC, [0.0, 0.0, 1.0, 0.0, 0.0, 0.8], null,
		func card(cd:CardData) -> void:
			cd.add(cd.player.accel, 32)
			cd.add(cd.gun.fire_rate, 0.5)
			cd.add(cd.gun.inaccuracy, 4)
	)
	
	register_card(&"HYPL", &"Hyperlight", &"",
		DECK_GUN, RARITY_COMMON, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.armor_regen, 6.0)
			cd.add(cd.player.speed, 3)
	)
	
	register_card(&"TANK", &"Tank", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.armor_density, 24.0)
			cd.add(cd.player.armor_regen, 2.0)
			cd.add(cd.player.speed, -4)
	)
	
	register_card(&"MNTN", &"Mountain", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add(cd.player.armor_density, 1024)
			cd.mult(cd.player.armor_regen, 0.0)
	)
	
	register_card(&"12GS", &"12-Gauge Shoes", &"this is a great idea!",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 0.85)
			cd.add_effect(&"Kicking things causes them to explode\nStrength scales with velocity", true, cd.player.melee_hook,
				func effect(ed:EventHook.EventData)-> void:
					var boost := ed.player.velocity.length()
					boost = 1.0 + (boost * 64.0) / (boost + 128.0)
					var rt := (ed.mult ** 0.333) * boost
					Game.world.create_explosion(ed.position, rt, rt * 4.0, rt * 3.0, [ed.player.get_rid()], ed.player)
			)
	)
	
	register_card(&"RFTA", &"Reflective Armor", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.proj.damage, 0.85)
			cd.add_effect(&"Taking armor damage releases damaging shrapanel", true, cd.player.damage_hook,
				func effect(ed:EventHook.EventData)-> void:
					if ed.player.armor <= 0.0: return
					var amo := (ed.damage.amount * ed.mult) / 1.5
					var trans := Transform3D.IDENTITY
					trans.origin = ed.player.camera.global_position
					for i in amo + 1:
						trans.basis = Basis.IDENTITY.rotated(Vector3.UP, randf()*PI*2.0)
						trans = trans.rotated_local(Vector3.LEFT, randf()*PI*2.0)
						AltProjHandler.spawn(AltProjHandler.CACTUS, trans, Vector3(0, 0, -50), ed.player)
			)
	)
	
	register_card(&"OVCA", &"Overcharged Armor", &"",
		DECK_GUN, RARITY_EPIC, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.armor_regen, 0.8)
			cd.add_effect(&"When your armor breaks, release a large damaging pulse that pushes everything away", true, cd.player.armor_break_hook,
				func effect(ed:EventHook.EventData)-> void:
					var pos := ed.player.global_position + Vector3(0.0, -0.15, 0.0)
					# scales the cross sectional area of the sphere
					var radius := (ed.mult ** 0.5) * 32
					VFXHandler.spawn(VFXHandler.SPELL_SHOCKWAVE, pos, [radius])
					var objects := Game.world.get_aoe_objects(pos, radius, [ed.player.get_rid()])
					
					for obj in objects:
						var dir := pos.direction_to(obj.global_position)
						dir *= radius * 2.0
						
						if obj is Player:
							var de := DamageEvent.new(24.0 * ed.mult, dir, DamageEvent.TYPE_MAGIC)
							de.source_entity = ed.player
							(obj as Player).take_damage_seralized.rpc(de.seralize())
							continue
						if obj is RigidBody3D:
							if (obj as RigidBody3D).freeze: continue
							(obj as RigidBody3D).apply_central_impulse.rpc(dir * 2.0)
			)
	)
	
	register_card(&"MRFA", &"Micro-Refractive Armor", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.armor_density, 0.65)
			cd.add_effect(&"Damage that breaks your armor does no damage to your health", true, cd.player.armor_break_hook,
				func effect(ed:EventHook.EventData)-> void:
					ed.damage.amount = 0
			)
	)
	
	register_card(&"HPRA", &"Hyper Armor", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.armor_regen, 0.9)
			cd.add_effect(&"Gain increased movement speed for a short time after your armor breaks", true, cd.player.armor_break_hook,
				func effect(ed:EventHook.EventData)-> void:
					ed.player.speed.mult_temp(1.5, 3.0, ed.mult)
					ed.player.accel.mult_temp(1.5, 3.0, ed.mult)
					ed.player.jump.mult_temp(1.25, 3.0, ed.mult)
			)
	)
	
	register_card(&"ARCY", &"Armor Recycler", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.mult(cd.player.armor_regen, 0.9)
			cd.add_effect(&"Gain increased RoF and reload speed after your armor breaks", true, cd.player.armor_break_hook,
				func effect(ed:EventHook.EventData)-> void:
					ed.gun.reload_time.mult_temp(0.7, 3.0, ed.mult)
					ed.gun.fire_rate.mult_temp(1.3, 3.0, ed.mult)
			)
	)
	
	register_card(&"CATA", &"Catalytic Armor", &"",
		DECK_GUN, RARITY_RARE, STYLE_BASIC, [0.0, 0.0, 0.0, -0.5, 0.75, 1.0], DRAW_ONCE,
		func card(cd:CardData) -> void:
			cd.add_effect(&"Refill 1 spell charge for each spell when your armor breaks", true, cd.player.armor_break_hook,
				func effect(ed:EventHook.EventData)-> void:
					ed.player.spell_1.charges = minf(ed.player.spell_1.charges + 1, ed.player.spell_1.max_charges.value_int)
					ed.player.spell_2.charges = minf(ed.player.spell_2.charges + 1, ed.player.spell_2.max_charges.value_int)
			)
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
