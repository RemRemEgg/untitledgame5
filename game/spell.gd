class_name Spell
extends RefCounted

var spider: PackedFloat64Array = [1.0, 1.0, 1.0]
var cards: Dictionary[Card, int]
var cast_hook: EventHook = EventHook.new()
var hold_hook: EventHook = EventHook.new()

var charges: float = 0.0
var hold_duration := 0.0

## Default 1.5
var cooldown := Stat.new(&"Spell CD", 1.5, 0.01, 9e9, false)
## Default 1
var max_charges := Stat.new(&"Spell Charges", 1.0, 1.0, 9e9)
## Default 1
var potency := Stat.new(&"Spell Potency", 1.0, 0.01, 9e9)
## All stats
var all_stats: Array[Stat] = [cooldown, max_charges, potency]

func reset_stats() -> void:
	for stat in all_stats:
		stat.reset_value()
	
	cast_hook.clear_effects()
	hold_hook.clear_effects()


func calculate_stats() -> void:
	for stat in all_stats:
		stat.calculate_value()


func process(player: Player, delta: float) -> void:
	var cd := cooldown.value_with(player.magic_cd)
	if floori(cd) < floori(cd + (delta/cd)):
		SFXHandler.play_world(SFXHandler.MAGIC_READY, player.global_position)
	charges = minf(charges + (delta / cd), max_charges.value_int)


func attempt_cast(player: Player, is_chain: bool) -> bool:
	if charges >= 1.0:
		charges -= 1.0
		player.magic_timer = 1.0
		cast(player, is_chain)
		return true
	return false


func cast(player: Player, is_chain: bool) -> void:
	VFXHandler.spawn(VFXHandler.PARTICLE_BURST, player.global_position, [3.0])
	VFXHandler.spawn(VFXHandler.PARTICLE_GENERIC, player.global_position, [1.5])
	SFXHandler.play_world(SFXHandler.WAVE, player.global_position, 2.0, 0.08)
	
	var ed := EventHook.EventData.from_player(player)
	ed.percent = 1.0 / max_charges.value
	ed.spell = self
	ed.is_chain = is_chain
	player.spell_hook.execute(ed)
	
	ed.mult = potency.value * player.magic_potency.value
	cast_hook.execute(ed)
	hold_duration = 0.0


func hold(player: Player, delta: float) -> void:
	var ed := EventHook.EventData.from_player(player)
	ed.percent = hold_duration
	ed.spell = self
	ed.mult = potency.value * player.magic_potency.value
	ed.delta = delta
	hold_hook.execute(ed)
	hold_duration += delta


func recalc_spider_graph(player: Player) -> void:
	var spells := Stat.new(&"spells", 1)
	spells.adder += cast_hook.get_effect_count()
	Util.calculate_spider(spider, [
		[potency, player.magic_potency], # strength
		[spells], # spells
		[max_charges, cooldown, player.magic_cd] # casting
	])
