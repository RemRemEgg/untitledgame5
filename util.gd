class_name Util
extends RefCounted

const PLAYER_ICON = preload("uid://caqvxbw61lbnt")


static func cast_float(v:Variant, default:float=0.0) -> float:
	if v is float:
		var f := v as float # how is this not typesafe :c
		return f
	return default


static func split_in_same_level(text: String, blade: String) -> Array[String]:
	if !text.contains(blade) || text.is_empty(): return [text]
	var ret: Array[String] = []
	var pos: int = 0
	var dist: int = 0
	var stack: Array[String] = []
	while true:
		if pos + dist >= text.length():
			ret.append(text.substr(pos))
			return ret
		var chari: String = text[pos + dist]
		if chari == "\\":
			dist += 2
			continue
		if !stack.is_empty(): if stack[-1] == chari: 
			stack.pop_back()
			dist += 1
			continue
		if stack.is_empty() && text.substr(pos + dist).begins_with(blade):
			ret.append(text.substr(pos, dist))
			pos += dist + 1
			dist = 0
		else:
			match chari:
				"[": stack.append("]")
				"{": stack.append("}")
				"(": stack.append(")")
				"\"": stack.append("\"")
			dist += 1
	# hopefully this code never runs
	Console.print_err(&"[SISL-NACPRAV]\tinput: '%s'" % text)
	return [&"NACPRAV"]


static func format_array(a: Array, f: String = &"%s") -> String:
	var s := "["
	for i in a.size():
		if i != 0: s += ", "
		s += f % a[i]
	return s + "]"


static func vec3_inv_lerp(a: Vector3, b: Vector3, v: Vector3) -> float:
	var a1 := v - a
	var b1 := b - a
	return a1.dot(b1) / b1.dot(b1)


static func remove_and_free(node: Node) -> void:
	node.get_parent().remove_child(node)
	node.queue_free()


static func remove_and_free_all_children(node: Node) -> void:
	var chlds := node.get_children()
	for c in chlds:
		node.remove_child(c)
		c.queue_free()


static func normalize_array(arr: Array[float]) -> Array[float]:
	var smin := +100000.0
	var smax := -100000.0
	var avg := 0.0
	
	for v in arr:
		if v < smin: smin = v
		if v > smax: smax = v
		avg += v
	avg /= arr.size()
	var diff := smax-smin
	
	var normalized: Array[float] = []
	normalized.resize(arr.size())
	for i in arr.size():
		normalized[i] = (arr[i] - avg) / diff
	return normalized
