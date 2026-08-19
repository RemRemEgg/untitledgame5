class_name DamageEvent
extends RefCounted

enum {TYPE_UNKNOWN, TYPE_KILLBIND, TYPE_BORDER, TYPE_BULLET, TYPE_MELEE, TYPE_MAGIC, TYPE_EXPLOSION}

var target_entity: Entity:
	set(v):
		target_entity = v
		target_uuid = 0
		if v is Player:
			target_uuid = (v as Player).uuid
var source_entity: Entity:
	set(v):
		source_entity = v
		source_uuid = 0
		if v is Player:
			source_uuid = (v as Player).uuid

var target_uuid: int
var source_uuid: int

var amount: float
var knockback: Vector3
var type: int


func _init(amount_: float, kb: Vector3 = Vector3.ZERO, type_: int = TYPE_UNKNOWN) -> void:
	amount = amount_
	knockback = kb
	type = type_

func set_knockback(kb: Vector3, add: bool = false) -> DamageEvent:
	knockback = (knockback + kb) if (add) else (knockback)
	return self


func set_type(type_: int) -> DamageEvent:
	type = type_
	return self


func seralize() -> Array[Variant]:
	return [amount, knockback, type, source_uuid, target_uuid]

static func deseralize(data: Array[Variant]) -> DamageEvent:
	var de := DamageEvent.new(data[0], data[1], data[2])
	if data[3]: de.source_entity = Network.player_from_uuid(data[3])
	if data[4]: de.target_entity = Network.player_from_uuid(data[4])
	return de


func get_death_message(target: String, source: String) -> String:
	if source && !source.is_empty():
		match type:
			TYPE_KILLBIND: return &"%s was forcefully removed by %s" % [target, source]
			TYPE_BORDER: return &"%s was thrown into the border by %s" % [target, source]
			TYPE_BULLET: return &"%s was shot to death by %s" % [target, source]
			TYPE_MELEE: return &"%s was pummeled to death by %s" % [target, source]
			TYPE_MAGIC: return &"%s was magically murdered by %s" % [target, source]
			TYPE_EXPLOSION: return &"%s was blown up by %s" % [target, source]
		return &"%s was killed by %s" % [target, source]
	else:
		match type:
			TYPE_KILLBIND: return &"%s killbinded" % [target]
			TYPE_BORDER: return &"%s fell into the border" % [target]
			TYPE_BULLET: return &"%s was shot to death" % [target]
			TYPE_MELEE: return &"%s was pummeled to death" % [target]
			TYPE_MAGIC: return &"%s was magically murdered" % [target]
			TYPE_EXPLOSION: return &"%s was blown up" % [target]
		return &"%s died" % [target]
