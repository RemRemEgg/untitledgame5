class_name ProcGun
extends RefCounted




var fire_rate := 10.0

enum {MOD_LINE, MOD_SHOTGUN, MOD_SPREAD}
var mod_stack: PackedInt32Array
var mod_data: PackedFloat32Array

var pproj: ProcProj
var inaccuracy: float = 0.0
var b_speed := 32.0

func _init() -> void:
	mod_stack = []
	mod_data = []

func add_modifier(type: int, data: Array[float]) -> void:
	mod_stack.append(type)
	mod_data.append_array(data)


func process(gun: Gun, trans: Transform3D, ownr: Entity, delta: float, can_fire: bool) -> void:
	gun.fire_timer += delta * fire_rate
	if !can_fire:
		gun.fire_timer = minf(gun.fire_timer, 1.0)
		return
	while gun.fire_timer >= 1.0:
		fire(gun, trans, ownr, (gun.fire_timer - 1.0) / fire_rate)
		gun.fire_timer -= 1.0

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
	process_modifier(Vector3(0, 0, -b_speed), Vector2i.ZERO, trans, ownr, delta)


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
	#print("making bullet at %s" % trans)
	var pp := pproj.create_projectile()
	#pp.global_transform = trans.rotated_local(Vector3.BACK, randf() * PI*2).rotated_local(Vector3.UP, randf()*inaccuracy)
	pp.global_position = trans.origin
	pp.ownr = ownr
	pp.team = ownr.team
	#pp.velocity = vel * pp.global_basis
	pp.velocity = trans.basis * vel
	pproj.update(pp, delta)
	#trans = trans.rotated_local((randf()-0.5) * inaccuracy)
	#var pp := pproj.create_pprojectile()
	#pp.trans = trans
	#trans.origin = Vector2.ZERO
	#pp.vel = trans*Vector2.RIGHT
	#pp.vel *= pproj.speed
	#pp.ownr = ownr
	#pp.team = ownr.team
	#pproj.update(pp, delta)
