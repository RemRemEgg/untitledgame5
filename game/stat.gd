class_name Stat
extends RefCounted

var name: StringName
var is_good: bool
var _base_value: float = 1.0
var adder: float = 0.0
var multiplier: float = 1.0
var temps: Array[TempMod]

var min_val: float = 0.01
var max_val: float = 3.4028235e38
var value: float = _base_value
var value_int: int = int(_base_value)


func _init(name_: StringName, base: float, vmin: float = min_val, vmax: float = max_val, is_good_: bool = true) -> void:
	name = name_
	is_good = is_good_
	_base_value = base
	min_val = vmin
	max_val = vmax
	reset_value()


func get_base_value() -> float:
	return _base_value


func get_total_modifiers() -> Vector2:
	var c_add := adder
	var c_mult := multiplier
	for mod in temps:
		c_add += mod.adder
		c_mult *= mod.multiplier
	
	return Vector2(_base_value + c_add, c_mult)


func calculate_value() -> void:
	var c_add := adder
	var c_mult := multiplier
	for mod in temps:
		c_add += mod.adder
		c_mult *= mod.multiplier
	
	value = clampf((_base_value + c_add) * c_mult, min_val, max_val)
	value_int = int(value)


func reset_value() -> void:
	temps.clear()
	adder = 0.0
	multiplier = 1.0
	value = _base_value
	value_int = int(_base_value)


func value_with(other: Stat) -> float:
	var st := get_total_modifiers()
	var ot := other.get_total_modifiers()
	return clampf((st.x + ot.x) * (st.y * ot.y), min_val, max_val)


func update(delta: float) -> void:
	temps = temps.filter(func update_temp(mod:TempMod) -> bool:
		mod.duration -= delta
		return mod.duration > 0.0
	) as Array[TempMod]
	calculate_value()


func add_temp(amount: float, duration: float = 0.0, n: float = 1.0) -> void:
	var mod := Stat.TempMod.new()
	var sqst := n ** 0.5
	mod.duration = duration * sqst
	mod.adder += amount * sqst
	temps.append(mod)


func mult_temp(amount: float, duration: float = 0.0, n: float = 1.0) -> void:
	var mod := Stat.TempMod.new()
	mod.duration = duration
	mod.multiplier *= amount ** n
	temps.append(mod)


class TempMod:
	var adder: float = 0.0
	var multiplier: float = 1.0
	var duration: float = 0.0
