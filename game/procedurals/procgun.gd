class_name ProcGun
extends RefCounted


var pproj: ProcProj


func reset_stats() -> void:
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
	pproj.knockback.multiplier *= 1.0 / clip_size.value
	pproj.calculate_stats()


## Bullets per Second. Default 1.0
var fire_rate := Stat.new(&"Rate of Fire", 1.0)
## Bullet speed in u/s. Default 300.0
var b_speed := Stat.new(&"Bullet Speed", 300.0)
## Spread in 1/200th rad from true direction. Default 3.0. Max value is 157; approx 45 deg off of center / 90 deg cone.
var inaccuracy := Stat.new(&"Spread", 3.0, 0.0, 157, false)
## Number of bullets fired pre trigger press. Default 1
var bullets_per_shot := Stat.new(&"Bullets/Shot", 1, 1)
## Total clip size. Default 1
var clip_size := Stat.new(&"Clip Size", 1, 1)
## Reload time, in seconds. Default 1.0
var reload_time := Stat.new(&"Reload Time", 1.0, 0.01, 9e9, false)


func process(gun: Gun, trans: Transform3D, ownr: Entity, delta: float, can_fire: bool) -> void:
	if gun.reload:
		gun.reload -= delta
		if gun.reload <= 0.0:
			gun.reload = 0.0
			gun.clip = clip_size.value_int
			gun.fire_timer = 1.0
		else:return
	
	gun.fire_timer += delta * fire_rate.value
	if !can_fire:
		gun.fire_timer = minf(gun.fire_timer, 1.0)
		return
	
	while gun.fire_timer >= 1.0 && gun.clip > 0:
		if ownr is Player: (ownr as Player).run_shoot_hook()
		for __ in mini(bullets_per_shot.value_int, gun.clip):
			fire_one_bullet(trans, ownr, (gun.fire_timer - 1.0) / fire_rate.value)
			gun.clip -= 1
		gun.fire_timer -= 1.0
	
	if gun.clip <= 0:
		gun.reload = reload_time.value
		gun.fire_timer = 0.0


func fire_one_bullet(trans: Transform3D, ownr: Entity, delta: float) -> void:
	var inacc_trans := trans \
		.rotated_local(Vector3.FORWARD, randf_range(0, PI*2.0)) \
		.rotated_local(Vector3.RIGHT, randf() * inaccuracy.value/200.0)
	make_bullet(Vector3(0, 0, -b_speed.value), inacc_trans, ownr, delta)


static var dbg_proj: Dictionary
func make_bullet(vel: Vector3, trans: Transform3D, ownr: Entity, delta: float) -> void:
	var proj := Network.send_projectile(trans)
	proj.ownr = ownr
	proj.velocity = trans.basis * vel
	pproj.update(proj, delta)
