class_name Util
extends RefCounted

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
