class_name Stat
extends RefCounted

var name: StringName
var is_good: bool
var _base_value: float = 1.0
var adder: float = 0.0
var multiplier: float = 1.0

var min_val: float = 0.0
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


func calculate_value() -> void:
	value = clampf((_base_value + adder) * multiplier, min_val, max_val)
	value_int = int(value)


func reset_value() -> void:
	adder = 0.0
	multiplier = 1.0
	value = _base_value
	value_int = int(_base_value)
