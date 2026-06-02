class_name ProcGun
extends RefCounted


var pproj: ProcProj


func reset_stats() -> void:
	mod_stack = []
	mod_data = []
	fire_rate.reset_value()
	b_speed.reset_value()
	inaccuracy.reset_value()
	bullets_per_shot.reset_value()
	clip_size.reset_value()
	reload_time.reset_value()
	pproj.reset_stats()

func calculate_stats() -> void:
	fire_rate.calculate_value()
	b_speed.calculate_value()
	inaccuracy.calculate_value()
	bullets_per_shot.calculate_value()
	clip_size.calculate_value()
	reload_time.calculate_value()
	pproj.calculate_stats()

enum {MOD_LINE, MOD_SHOTGUN, MOD_SPREAD}
var mod_stack: PackedInt32Array
var mod_data: PackedFloat32Array
var fire_rate := Stat.new(2.0)
var b_speed := Stat.new(32.0)
var inaccuracy := Stat.new(0.0) #TODO NYI
var bullets_per_shot := Stat.new(1, 1) #TODO NYI
var clip_size := Stat.new(6, 1)
var reload_time := Stat.new(1.2)

func _init() -> void:
	mod_stack = []
	mod_data = []

func add_modifier(type: int, data: Array[float]) -> void:
	mod_stack.append(type)
	mod_data.append_array(data)

# TODO cleanup, bullets_per_shot
func process(gun: Gun, trans: Transform3D, ownr: Entity, delta: float, can_fire: bool) -> void:
	if gun.reload:
		gun.reload -= delta
		if gun.reload <= 0.0:
			gun.reload = 0.0
			gun.clip = clip_size.value_int
			gun.fire_timer = 1.0
	if gun.reload: return
	gun.fire_timer += delta * fire_rate.value
	if !can_fire:
		gun.fire_timer = minf(gun.fire_timer, 1.0)
		return
	while gun.fire_timer >= 1.0:
		if gun.clip <= 0:
			gun.reload = reload_time.value
			gun.fire_timer = 0.0
			return
		fire(gun, trans, ownr, (gun.fire_timer - 1.0) / fire_rate.value)
		gun.fire_timer -= 1.0
		gun.clip -= 1
	if gun.clip <= 0:
		gun.reload = reload_time.value
		gun.fire_timer = 0.0
		return

#func __process(gun: Gun, trans: Transform2D, entity: Entity, delta: float) -> int:
	#var fire_count := 0
	#trans = trans.translated_local(Vector2.RIGHT * front_dist)
	#match style:
		#STYLE_GUN:
			#gun.fire_timer += delta * fire_rate
			#while gun.fire_timer >= 1.0:
				#fire(gun, trans, entity, (gun.fire_timer - 1.0) / fire_rate)
				#fire_count += 1
				#gun.fire_timer -= 1.0
		#STYLE_REPEATER:
			#if gun.fire_timer < 0:
				#var inc: float = gun.fire_timer + delta * style_data_f
				#var vop: int = absi(int(minf(inc, 0.0)) - int(gun.fire_timer))
				#while vop > 0:
					#fire(gun, trans, entity, (inc - floorf(inc) + vop - 1) / style_data_f)
					#fire_count += 1
					#vop -= 1
				#gun.fire_timer = minf(inc, 0.0)
			#else:
				#gun.fire_timer += delta * fire_rate
				#if gun.fire_timer >= 1.0: gun.fire_timer = -style_data_i
	#return fire_count


func fire(_gun: Gun, trans: Transform3D, ownr: Entity, delta: float) -> void:
	process_modifier(Vector3(0, 0, -b_speed.value), Vector2i.ZERO, trans, ownr, delta)


func process_modifier(vel: Vector3, i: Vector2i, trans: Transform3D, ownr: Entity, delta: float) -> void:
	#make_bullets(vel, trans, ownr, delta)
	if i.x >= mod_stack.size(): return make_bullets(vel, trans, ownr, delta)
	match mod_stack[i.x]:
		#MOD_LINE: # [ count, dist ]
			#var o := (mod_data[i.y]-1) / 2.0
			#for j in int(mod_data[i.y]):
				#process_modifier(trans.translated_local(Vector2.DOWN * (j - o) * mod_data[i.y+1]), i+Vector2i(1, 1), ownr, delta)
				
		#MOD_SHOTGUN: # [ count, spread ]
			#for __ in int(mod_data[i.y]):
				##process_modifier(trans.rotated_local((randf()-0.5)*mod_data[i.y+1]), i+Vector2i(1, 2), ownr, delta)
				#process_modifier(vel.rotated(V), i+Vector2i(1, 2), trans, ownr, delta)
		MOD_SPREAD: # [ count, angle ]
			var o := (mod_data[i.y]-1) / 2.0
			for j in int(mod_data[i.y]):
				#process_modifier(trans.rotated_local((j - o) * mod_data[i.y+1]), i+Vector2i(1, 1), ownr, delta)
				process_modifier(vel.rotated(Vector3.UP, (j - o) * mod_data[i.y+1]), i+Vector2i(1, 2), trans, ownr, delta)
		#MOD_SURROUND: # [ count ]
			#for s in mod_data[i.y]:
				#process_modifier(trans.rotated_local(s*((2*PI)/mod_data[i.y])), i+Vector2i(1, 1), ownr, delta)



func make_bullets(vel: Vector3, trans: Transform3D, ownr: Entity, delta: float) -> void:
	var proj := Network._send_projectile(trans)
	proj.ownr = ownr
	proj.velocity = trans.basis * vel
	pproj.update(proj, delta)
