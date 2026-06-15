class_name DamageEvent
extends RefCounted
# TODO seralize?

var target_entity: Entity
var source_entity: Entity

var damage: float
var knockback: Vector3

func _init(amount: float, kb: Vector3 = Vector3.ZERO) -> void:
	damage = amount
	knockback = kb
