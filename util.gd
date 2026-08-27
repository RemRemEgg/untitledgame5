class_name Util
extends RefCounted

static var PLAYER_ICON_SCN: PackedScene

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
	if !node: return
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


static func has_frac(f: float) -> bool:
	return !is_zero_approx(f - roundf(f))


static func hp(x: float, a: float) -> float:
	return x / (absf(x) + a)


static func frac_to_lin(x: float) -> float: return 1.0-(1.0/x) if x <= 1.0 else x - 1.0
static func lin_to_frac(x: float) -> float: return -1.0/(x-1.0) if x <= 0.0 else x + 1.0


static func calculate_spider(spider: PackedFloat64Array, stat_groups: Array[Array]) -> void:
	var smax := 0.1
	var smin := -0.1
	
	for i in stat_groups.size():
		spider[i] = 0
		for stat:Stat in (stat_groups[i] as Array[Stat]):
			#Console.print(&"spider is at %s, adding %s" % [spider[i], stat.name])
			var frac := 0.0
			if is_zero_approx(stat.get_base_value()):
				#Console.print(&" is zero approx!!")
				frac = (stat.value+1) / (stat.get_base_value()+1)
			else:
				frac = stat.value / stat.get_base_value()
			spider[i] += hp(frac_to_lin(frac), 2.0) * (1 if stat.is_good else -1)
			#Console.print(&" spider is now %s" % spider[i])
		spider[i] /= stat_groups[i].size()
		smax = maxf(smax, spider[i])
		smin = minf(smin, spider[i])
	
	#Console.print(&"## Spider pre-fix %s" % Util.format_array(spider))
	
	smax += 0.25
	smin -= 0.25
	var r := (smax - smin) # radius
	for i in stat_groups.size():
		spider[i] = (spider[i] - smin) / r
		
	#Console.print(&"@@ Spider post-fix %s" % Util.format_array(spider))


## Adds inaccuracy to a transform, relative to its -Z axis.
## Spread is in radians off from center.
## Distribution favors the center
static func trans_inaccuracy(trans: Transform3D, spread: float) -> Transform3D:
	return trans \
		.rotated_local(Vector3.FORWARD, randf_range(0, PI*2.0)) \
		.rotated_local(Vector3.RIGHT, randf() * spread)

## Usage:
## [codeblock]if accumulate_delta([delta_buffer], [delta]):[/codeblock]
static func accumulate_delta(p_buffer: Array[float], p_delta: Array[float], cutoff: float = 1.0/8.0) -> bool:
	p_buffer[0] += p_delta[0]
	if p_buffer[0] >= cutoff:
		p_delta[0] = p_buffer[0]
		p_buffer[0] = 0.0
		return true
	return false
