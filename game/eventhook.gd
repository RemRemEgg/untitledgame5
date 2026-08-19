class_name EventHook
extends RefCounted

var _effects: Array[EventEffect]

func add_effect(count: int, effect: Callable) -> void:
	var idx := _effects.find_custom(func(hc:EventEffect)->bool: return hc.effect == effect)
	if idx == -1:
		if count <= 0: return
		_effects.append(EventEffect.new(effect, count))
	else:
		_effects[idx].count += count
		if _effects[idx].count <= 0:
			_effects.remove_at(idx)


func clear_effects() -> void:
	_effects.clear()


func get_effect_count() -> float:
	var t := 0.0
	for eff in _effects:
		t += eff.mult
	return t


func execute(ed: EventData) -> void:
	var ed_mult := ed.mult
	for eff: EventEffect in _effects:
		ed.mult = ed_mult * eff.mult
		ed.multi = roundi(ed.mult)
		eff.effect.call(ed)


class EventEffect extends RefCounted:
	var effect: Callable
	var mult: float = 1.0
	
	func _init(effect_: Callable, mult_: float) -> void:
		effect = effect_
		mult = mult_


class EventData:
	var mult: float = 1.0
	var multi: int
	var percent: float = 1.0
	
	var player: Player
	var gun: ProcGun
	var proj: ProcProj
	
	var position: Vector3
	var normal: Vector3
	
	var damage: DamageEvent
	var proj_inst: Projectile
	var hit_pb3d: PhysicsBody3D
	var spell: Spell
	var is_chain: bool
	
	
	static func from_player(p: Player) -> EventData:
		var ed := EventData.new()
		ed.player = p
		ed.gun = ed.player.procgun
		ed.proj = ed.gun.pproj
		ed.position = p.global_position
		ed.normal = -p.camera.global_basis.z
		return ed
