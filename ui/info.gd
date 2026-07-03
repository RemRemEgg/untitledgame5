class_name Info
extends BoxContainer

const CARD_ICON := preload("uid://ba8bixelqjeyx") as PackedScene
const PLAYER_ICON = preload("uid://caqvxbw61lbnt") as PackedScene

@onready var player_list: FlowContainer = $player_list as FlowContainer

@onready var player_name: Label = $info_list/player_name as Label
@onready var team_color: ColorRect = $info_list/team_color as ColorRect
@onready var quick_stats: Label = $info_list/quick_stats as Label
@onready var spider_graph: SpiderGraph = $info_list/spider_graph as SpiderGraph

@onready var details: VBoxContainer = $details as VBoxContainer
@onready var card_list: FlowContainer = $details/card_list as FlowContainer
@onready var stats: RichTextLabel = $details/stats as RichTextLabel

@onready var card_disp_handler: CanvasLayer = $card_disp_handler as CanvasLayer

var hovered_icon: CardIcon
var card_display: CardDisplay


func _ready() -> void:
	for p in Network.players:
		var pi := (Network.players[p] as Network.PlayerInfo)
		
		var pcard := Util.PLAYER_ICON_SCN.instantiate() as PlayerIcon
		player_list.add_child(pcard)
		pcard.pressed.connect(swap_to_player)
		pcard.dispname.text = pi.name
		pcard.dispcolor.color = pi.color
		pcard.id = p


func _process(_delta: float) -> void:
	var mouse := get_global_mouse_position()
	var margin := 12.0
	var current_hover: CardIcon
	for ico:CardIcon in card_list.get_children():
		if (mouse.x > ico.global_position.x + margin && mouse.y > ico.global_position.y + margin &&\
				mouse.x < ico.global_position.x + ico.size.x - margin && mouse.y < ico.global_position.y + ico.size.y - margin):
			ico.modulate = Color.WHITE
			current_hover = ico
		else:
			ico.modulate = Color.LIGHT_GRAY
	if current_hover != hovered_icon: # change card hover
		Util.remove_and_free_all_children(card_disp_handler)
		if current_hover && current_hover.card: # is hovering
			hovered_icon = current_hover
			card_display = CardDisplay.from_card(hovered_icon.card, hovered_icon.card.deck)
			card_disp_handler.add_child(card_display)
	elif !card_display: hovered_icon = null
	if card_display: card_display.position = get_global_mouse_position() - Vector2(128.0, 0.0)


func swap_to_player(id: int) -> void:
	var pi := (Network.players[id] as Network.PlayerInfo)
	for c in player_list.get_children() as Array[PlayerIcon]:
		c.dispname.modulate = Color.GOLD if c.id == id else Color.WHITE
	
	player_name.text = pi.name
	team_color.color = pi.color
	quick_stats.text = &"%s Wins | %s:%s" % [pi.wins, pi.uuid, Network.NS_NAME[pi.state]]
	
	var spider: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	
	Util.remove_and_free_all_children(card_list)
	for card_uuid in (pi.cards.keys() as Array[StringName]):
		var card := Card.get_card(card_uuid)
		if !card:
			Console.print_err(&"Cannot find card %s" % card_uuid)
			return
		var count := pi.cards[card_uuid]
		
		for i:int in 6: spider[i] += card.spider[i]*count
		
		var ico := CARD_ICON.instantiate() as CardIcon
		ico.card = card
		var bg := ico.get_node(^"background") as ColorRect
		var abbv := bg.get_node(^"abbv") as Label
		var mult := bg.get_node(^"mult") as Label
		var d_once := bg.get_node(^"draw_once") as Panel
		bg.color = Color(Card.RARITY_COLORS[card.rarity])
		abbv.text = card.abbv
		mult.text = StringName("x%s" % count) if count>1 else &""
		d_once.visible = card.is_draw_once
		card_list.add_child(ico)
	
	var smin := +1000000.0
	var smax := -1000000.0
	for v in spider:
		if v < smin: smin = v
		if v > smax: smax = v
	smin -= 0.5
	smax += 0.5
	spider_graph.data_min = smin
	spider_graph.data_max = smax
	spider_graph.values = spider
	spider_graph.recalculate_graph()
	
	if id == Network.uuid:
		var txt_arr: Array[String] = []
		
		txt_arr.append(&"[b][u]Player Stats[/u][/b]")
		var p := Game.player
		for stat:Stat in [p.max_health, p.speed, p.accel, p.jump, p.max_jumps, p.max_stamina, p.melee_cd, p.magic_cd, p.magic_potency]:
			txt_arr.append(format_stat(stat))
		
		txt_arr.append(&"\n[b][u]Spell Stats[/u][/b]")
		var sps := [p.spell_1, p.spell_2] as Array[Spell]
		for i in sps.size():
			var s := sps[i]
			for stat:Stat in [s.cooldown, s.max_charges, s.potency]:
				txt_arr.append((&"[%s] " % (i+1)) + format_stat(stat))
		
		txt_arr.append(&"\n[b][u]Gun Stats[/u][/b]")
		var g := p.procgun
		for stat:Stat in [g.fire_rate, g.bullets_per_shot, g.clip_size, g.reload_time, g.inaccuracy, g.b_speed]:
			txt_arr.append(format_stat(stat))
		
		txt_arr.append(&"\n[b][u]Bullet Stats[/u][/b]")
		var b := g.pproj
		for stat:Stat in [b.damage, b.bounces, b.scale, b.knockback]:
			txt_arr.append(format_stat(stat))
		
		stats.text = &"\n".join(txt_arr)


func format_stat(stat: Stat) -> String:
	return "%s: %5.1f  [color=#aaa][(%5.1f +%5.1f) *%5.2f][/color]" % [stat.name, stat.value, stat._base_value, stat.adder, stat.multiplier]
