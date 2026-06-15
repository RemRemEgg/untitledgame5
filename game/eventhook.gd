class_name EventHook
extends RefCounted

var _effects: Array[EventEffect]
var _idx: int


func add_effect(count: int, effect: Callable) -> void:
	Console.print("adding effect n:%s  e:%s" % [count, effect])
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


func _iter_init(__:Array) -> bool:
	_idx = 0
	return _idx < _effects.size()


func _iter_next(__:Array) -> bool:
	_idx += 1
	return _idx < _effects.size()


func _iter_get(__:Variant) -> EventEffect:
	return _effects[_idx]


class EventEffect extends RefCounted:
	var effect: Callable
	var count: int
	
	
	func _init(effect_: Callable, count_: int) -> void:
		effect = effect_
		count = count_
	
	
	func execute(...args: Array) -> void:
		args.push_front(count)
		effect.callv(args)
