class_name Spell
extends RefCounted

var cards: Dictionary[Card, int]
var hook: EventHook = EventHook.new()

var charges: float = 0.0

## Default 1.5
var cooldown := Stat.new(&"Spell CD", 1.5, 0.01, 9e9, false)
## Default 1
var max_charges := Stat.new(&"Spell Charges", 1.0, 1.0, 9e9)
## Default 1
var potency := Stat.new(&"Spell Potency", 1.0, 0.01, 9e9)


func reset_stats() -> void:
	cooldown.reset_value()
	max_charges.reset_value()
	potency.reset_value()
	
	hook.clear_effects()


func calculate_stats() -> void:
	cooldown.calculate_value()
	max_charges.calculate_value()
	potency.calculate_value()


func process(player: Player, delta: float) -> void:
	var cd := cooldown.value_with(player.magic_cd)
	charges = minf(charges + (delta / cd), max_charges.value_int)


func attempt_cast(player: Player) -> void:
	if charges >= 1.0:
		charges -= 1.0
		player.magic_timer = 0.75
		cast(player)


func cast(player: Player) -> void:
	Network.spawn_visual(Network.NV_PARTICLE_BURST, player.global_position, 3.0)
	Network.spawn_visual(Network.NV_PARTICLE_GENERIC, player.global_position, 1.5)
	var ed := EventHook.EventData.from_player(player)
	for effect:EventHook.EventEffect in player.spell_hook:
		effect.execute(ed, self)
	var sd := SpellData.from_player(player, self)
	for effect:EventHook.EventEffect in hook:
		sd.t = effect.count * sd.p
		sd.ti = roundi(sd.t)
		effect.execute(ed, sd)


class SpellData:
	## Potency of the spell. Does not include card stacks
	var p: float = 1.0
	## Total spell strength. Equal to [potency * card stacks]
	var t: float = 1.0
	## Total spell strength, as an integer. Equal to roundi(t)
	var ti: int = 1
	
	static func from_player(player: Player, spell: Spell) -> SpellData:
		var sd := SpellData.new()
		sd.p = spell.potency.value * player.magic_potency.value
		return sd
