class_name Info
extends BoxContainer

const PLAYER_ICON = preload("uid://caqvxbw61lbnt") as PackedScene

@onready var player_list: FlowContainer = $player_list as FlowContainer

@onready var player_name: Label = $info_list/player_name as Label
@onready var team_color: ColorRect = $info_list/team_color as ColorRect
@onready var quick_stats: Label = $info_list/quick_stats as Label

@onready var spiders: Control = $info_list/spiders as Control
@onready var player_spider: SpiderGraph = $info_list/spiders/player_spider as SpiderGraph
@onready var gun_spider: SpiderGraph = $info_list/spiders/gun_spider as SpiderGraph
@onready var spell_1_spider: SpiderGraph = $info_list/spiders/spell_1_spider as SpiderGraph
@onready var spell_2_spider: SpiderGraph = $info_list/spiders/spell_2_spider as SpiderGraph

@onready var details: TabContainer = $details as TabContainer
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
		pcard.disppfp.modulate = pi.color
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
	var player := pi.linked_player
	for c in player_list.get_children() as Array[PlayerIcon]:
		c.dispname.modulate = Color.GOLD if c.id == id else Color.WHITE
	
	# overview & quick stats
	player_name.text = pi.name
	team_color.color = pi.color
	quick_stats.text = &"%s Wins | %s Kills | %s Deaths | %s:%s" % [pi.wins, player.kills, player.deaths, pi.uuid, Network.NS_NAME[pi.state]]
	
	# card icons
	Util.remove_and_free_all_children(card_list)
	for card_uuid in (pi.cards.keys() as Array[StringName]):
		var card := Card.get_card(card_uuid)
		if !card:
			Console.print_err(&"Cannot find card %s" % card_uuid)
			return
		var count := pi.cards[card_uuid]
		
		var ico := CardIcon.from_card(card, count)
		card_list.add_child(ico)
	
	player_spider.values = player.spider.slice(0, 3)
	player_spider.recalculate_graph()
	gun_spider.values = player.spider.slice(3, 6)
	gun_spider.recalculate_graph()
	spell_1_spider.values = player.spider.slice(6, 9)
	spell_1_spider.recalculate_graph()
	spell_2_spider.values = player.spider.slice(9, 12)
	spell_2_spider.recalculate_graph()
	
	# view all stats
	if id == Network.uuid:
		var txt_arr: Array[String] = []
		
		txt_arr.append(&"[b][u]Player Stats[/u][/b]")
		var p := Game.player
		for stat:Stat in p.all_stats:
			txt_arr.append(format_stat(stat))
		
		txt_arr.append(&"\n[b][u]Spell Stats[/u][/b]")
		var sps := [p.spell_1, p.spell_2] as Array[Spell]
		for i in sps.size():
			var s := sps[i]
			for stat:Stat in s.all_stats:
				txt_arr.append((&"[%s] " % (i+1)) + format_stat(stat))
		
		txt_arr.append(&"\n[b][u]Gun Stats[/u][/b]")
		var g := p.procgun
		for stat:Stat in g.all_stats:
			txt_arr.append(format_stat(stat))
		
		txt_arr.append(&"\n[b][u]Bullet Stats[/u][/b]")
		var b := g.pproj
		for stat:Stat in b.all_stats:
			txt_arr.append(format_stat(stat))
		
		stats.text = &"\n".join(txt_arr)


func format_stat(stat: Stat) -> String:
	var lin := Util.frac_to_lin(stat.value / stat.get_base_value())
	var ico := &"o"
	if lin <= -4: ico = &"⇊"
	elif lin <= -2: ico = &"↡"
	elif lin <= -1: ico = &"↓"
	elif lin >= 4: ico = &"⇈"
	elif lin >= 2: ico = &"↟"
	elif lin >= 1: ico = &"↑"
	
	var hp := Util.hp(lin * (1 if stat.is_good else -1), 2) * 0.5 + 0.5
	var col := Color(1.0-hp, hp, 0.5)
	
	return "[color=%s]%s[/color] %s: %5.1f  [color=#aaa][(%5.1f +%5.1f) *%5.2f][/color]" % [col.to_html(false), ico, stat.name, stat.value, stat.get_base_value(), stat.adder, stat.multiplier]
